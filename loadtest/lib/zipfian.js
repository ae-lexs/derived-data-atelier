// Deterministic Zipfian key generator for the OLTP point-query load.
// At init we precompute the inverse-CDF over [1, N]; at runtime each
// sample is one uniform draw + one binary search over the CDF.
// Two VUs seeded identically produce identical key sequences.

const LCG_A = 1664525;
const LCG_C = 1013904223;

function lcg(seed) {
  let state = seed >>> 0;
  return function next() {
    state = (Math.imul(state, LCG_A) + LCG_C) >>> 0;
    return state / 0x100000000; // [0, 1)
  };
}

function buildCDF(N, theta) {
  let zetaN = 0;
  for (let k = 1; k <= N; k++) zetaN += 1 / Math.pow(k, theta);
  const cdf = new Float64Array(N);
  let running = 0;
  for (let k = 1; k <= N; k++) {
    running += 1 / Math.pow(k, theta) / zetaN;
    cdf[k - 1] = running;
  }
  return cdf;
}

export function zipfianSampler(seed, N, theta) {
  const rand = lcg(seed);
  const cdf = buildCDF(N, theta);

  return function sample() {
    const u = rand();
    let lo = 0, hi = N - 1;
    while (lo < hi) {
      const mid = (lo + hi) >>> 1;
      if (cdf[mid] < u) lo = mid + 1;
      else hi = mid;
    }
    return lo + 1; // keys are 1-indexed (matches o_orderkey)
  };
}
