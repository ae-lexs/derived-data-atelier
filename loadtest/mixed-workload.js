import http from 'k6/http';
import { check, sleep } from 'k6';
import { zipfianSampler } from './lib/zipfian.js';

const SEED                = 0xdda20260501;
const NUM_ORDERS          = 1500000;   // TPC-H SF1 orders table cardinality
const SKEW                = 0.99;      // Zipfian theta (YCSB default)
const BASE_URL            = __ENV.BASE_URL || 'http://localhost:8080';
const OLAP_QUERIES        = ['q1', 'q3', 'q5', 'q10'];
const OLAP_WINDOW_SECONDS = 60;        // each OLAP window holds steady contention for 60s

const sample = zipfianSampler(SEED, NUM_ORDERS, SKEW);

export const options = {
  scenarios: {
    oltp: {
      executor: 'constant-arrival-rate',
      rate: 200, timeUnit: '1s', duration: '30m',
      preAllocatedVUs: 50, maxVUs: 100,
      exec: 'oltpPointQuery',
    },
    olap_trigger: {
      executor: 'per-vu-iterations',
      vus: 1, iterations: 3,
      startTime: '5m', maxDuration: '20m',
      exec: 'olapWindow',
    },
  },
  thresholds: {
    'http_req_duration{scenario:oltp}': ['p(99)<500'],
    'http_req_failed{scenario:oltp}':   ['rate<0.01'],
  },
};

export function oltpPointQuery() {
  const key = sample();
  const res = http.get(`${BASE_URL}/orders/${key}`, {
    tags: { scenario: 'oltp', endpoint: 'orders_get' },
  });
  check(res, { 'status 200 or 404': (r) => r.status === 200 || r.status === 404 });
}

export function olapWindow() {
  // Each iteration drives one OLAP-active window of OLAP_WINDOW_SECONDS.
  // Issued queries rotate through the catalog deterministically by __ITER.
  const q = OLAP_QUERIES[__ITER % OLAP_QUERIES.length];
  const deadline = Date.now() + OLAP_WINDOW_SECONDS * 1000;
  while (Date.now() < deadline) {
    const res = http.get(`${BASE_URL}/analytics/${q}`, {
      tags: { scenario: 'olap', endpoint: `analytics_${q}` },
      timeout: '60s',
    });
    check(res, { 'olap returned': (r) => r.status === 200 });
  }
  sleep(1);
}
