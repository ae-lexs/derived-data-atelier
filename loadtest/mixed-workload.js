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

// One discrete OLAP-active window: a single iteration that holds 60s of
// analytical contention, scheduled at an absolute offset from test start.
// Spacing the windows (vs k6's per-vu-iterations running them back-to-back)
// isolates each window's OLTP p99 impact and matches the annotation guidance
// in queries/p99-during-vs-outside-olap.cwli. qIndex pins one catalog query
// per window — separate single-iteration scenarios all see __ITER=0, so the
// query is selected via scenario env instead.
function olapWindowAt(startTime, qIndex) {
  return {
    executor: 'per-vu-iterations',
    vus: 1, iterations: 1,
    startTime, maxDuration: '2m',
    exec: 'olapWindow',
    env: { OLAP_Q_INDEX: String(qIndex) },
  };
}

export const options = {
  scenarios: {
    oltp: {
      executor: 'constant-arrival-rate',
      rate: 200, timeUnit: '1s', duration: '30m',
      preAllocatedVUs: 50, maxVUs: 100,
      exec: 'oltpPointQuery',
    },
    // Three OLAP-active windows spaced 5 min apart (T+5m, T+10m, T+15m), each
    // 60s, each pinning one catalog query (q1, q3, q5) so windows are
    // comparable run-to-run and across Modules 03-05.
    olap_window_1: olapWindowAt('5m', 0),
    olap_window_2: olapWindowAt('10m', 1),
    olap_window_3: olapWindowAt('15m', 2),
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
  // One OLAP-active window of OLAP_WINDOW_SECONDS. The query is pinned per
  // scenario via OLAP_Q_INDEX (set in each olap_window_* scenario's env), so
  // each spaced window hammers a single, deterministic catalog query.
  const q = OLAP_QUERIES[Number(__ENV.OLAP_Q_INDEX || 0) % OLAP_QUERIES.length];
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
