// The storage reachability probe (BRIEF-CI-P3 D5): whether THIS browser
// can reach the object store the ship signs log links into. The ship
// answers the store's endpoint and one unsigned probe URL under the CI
// prefix; the browser fetches it. Any HTTP answer — the store's 403 for
// an unsigned read, a 404 — proves the endpoint reachable; a fetch that
// rejects does not. A rejection is then tried again with no-cors: a
// response there means the store answers but refuses this origin's
// cross-origin read (no CORS rule), which breaks the log view the same
// way. Nothing here renders; the components do.

export async function probeStore(url, fetchImpl = globalThis.fetch) {
  if (!url) return 'unknown'
  try {
    await fetchImpl(url, { method: 'GET', mode: 'cors', credentials: 'omit', cache: 'no-store' })
    return 'reachable'
  } catch {
    // unreachable, or reachable without CORS: the opaque fetch tells them apart
  }
  try {
    await fetchImpl(url, { method: 'GET', mode: 'no-cors', credentials: 'omit', cache: 'no-store' })
    return 'cors'
  } catch {
    return 'unreachable'
  }
}

// the sentence the pip carries, D5's own words for the red case
export function probeMessage(state, host) {
  switch (state) {
    case 'reachable':
      return `Your browser can reach the object store at ${host}. Logs and artifacts open here.`
    case 'unreachable':
      return `Your browser cannot reach the object store at ${host}. Logs and artifacts will not open. The endpoint must be reachable from every viewer's network, not only from the ship's host.`
    case 'cors':
      return `Your browser reaches the object store at ${host}, but the store refuses cross-origin reads from this page: add a CORS rule on the bucket allowing GET and HEAD from this origin, or logs and artifacts will not open.`
    case 'unconfigured':
      return 'The ship has no object store configured (%storage). CI cannot be enabled until it names an S3-compatible endpoint, bucket and credentials.'
    default:
      return 'Checking whether this browser can reach the object store…'
  }
}

export const probeClass = (state) => ({ reachable: 'good', unreachable: 'bad', cors: 'bad', unconfigured: 'warn' })[state] || ''
