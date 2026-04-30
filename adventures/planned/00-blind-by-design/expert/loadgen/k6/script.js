// k6 script that hits the demo's GET / with random species values, but only
// when the OpenFeature flag `loadgen_active` is true. Flip the flag in the
// running flagd's flags.json (defaultVariant: "off" → "on") and the script
// starts hammering within seconds. Flip it back and it goes idle.
//
// The script targets one app instance via BASE_URL — point it at :8080 of
// whichever folder you're running. FLAGD_URL is flagd's eval endpoint on
// :8013 (the gRPC port also serves HTTP/JSON via gRPC-Gateway, so a plain
// curl-style POST works against the same port the SDK uses).

import http from 'k6/http';
import { sleep } from 'k6';

export const options = {
  vus: 5,           // five virtual users; modest load, dashboard stays readable
  duration: '24h',  // run forever — toggle the flag to start/stop traffic
};

const BASE_URL = __ENV.BASE_URL || 'http://host.docker.internal:8080';
const FLAGD_URL = __ENV.FLAGD_URL || 'http://host.docker.internal:8013';

// Pool of subject species. Empty string means "no query parameter" — exercises
// the country-fallback or default branch. The mix is deliberately uneven so the
// variant distribution panel in Grafana looks like real traffic, not a flat split.
const SPECIES = ['zyklop', 'zyklop', 'human', 'human', 'human', 'orc', 'elf', 'goblin', ''];

// Generate a random user id per request. The Phase 3 `vision_amplifier_v2` flag
// uses a fractional rollout that buckets on the OpenFeature targetingKey, so
// without a stable per-request id every request would land in the same bucket.
function randomUserId() {
  return `user-${Math.floor(Math.random() * 100000)}`;
}

function isLoadgenActive() {
  const res = http.post(
    `${FLAGD_URL}/flagd.evaluation.v1.Service/ResolveBoolean`,
    JSON.stringify({ flagKey: 'loadgen_active', context: {} }),
    { headers: { 'Content-Type': 'application/json' }, timeout: '2s' },
  );
  if (res.status !== 200) return false;
  try {
    return JSON.parse(res.body).value === true;
  } catch {
    return false;
  }
}

export default function () {
  if (!isLoadgenActive()) {
    // Flag is off — idle gently. Two seconds is short enough to feel responsive
    // when the flag flips on, long enough not to thrash flagd.
    sleep(2);
    return;
  }

  const species = SPECIES[Math.floor(Math.random() * SPECIES.length)];
  const userId = randomUserId();
  const params = [`userId=${userId}`];
  if (species) params.push(`species=${species}`);
  const url = `${BASE_URL}/?${params.join('&')}`;
  http.get(url, { tags: { species: species || 'default' } });
  sleep(0.1);
}
