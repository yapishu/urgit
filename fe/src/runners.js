// The Runners panel's pure helpers (BRIEF-CI-P3 D1-D3): the shapes the
// panel derives from GET ci/runners and its facts, the state pip re-derived
// on the client's clock between facts, the action bodies the buttons post,
// and the merge of a runner fact into the list. Nothing here fetches.

export const shortId = (id) => (id ? String(id).slice(0, 12) : '—')

// the pip the ship computed at read time, re-derived here against the
// client's clock so a daemon that stops polling reads stale without a
// fact: revoked, refused and minted are the record's own; healthy is one
// seen within staleAfter seconds, the scheduler's own window (rider 2:
// one number; the daemon polls at capacity too, so last-seen is liveness)
export function runnerState(runner, nowSeconds, staleAfter = 300) {
  if (!runner) return 'minted'
  if (runner.revoked) return 'revoked'
  if (runner.refused) return 'refused'
  if (!runner.enrolled) return 'minted'
  const seen = Number(runner.lastSeen)
  if (!Number.isFinite(seen) || seen <= 0) return 'stale'
  return nowSeconds - seen < staleAfter ? 'healthy' : 'stale'
}

export const stateLabel = {
  minted: 'minted',
  healthy: 'healthy',
  stale: 'stale',
  refused: 'refused',
  revoked: 'revoked',
}

export const stateHint = {
  minted: 'A token was minted; no daemon has enrolled with it yet.',
  healthy: 'Polling within the last five minutes.',
  stale: 'Not seen for five minutes: the scheduler hands it nothing, and work it never fetched is re-offered.',
  refused: 'It refused an assignment over its pinned CI key and is offered no work until it re-enrolls.',
  revoked: 'Revoked: its next poll was refused and it exited. Remove the record when you are done with it.',
}

// what the panel can do with a row: expire a minted record, revoke an
// enrolled daemon (healthy, stale or refused), remove a revoked record
export function rowActions(state) {
  if (state === 'minted') return ['expire']
  if (state === 'revoked') return ['remove']
  return ['revoke']
}

// one row of the table
export function runnerRow(runner, nowSeconds = Date.now() / 1000, staleAfter = 300) {
  const state = runnerState(runner, nowSeconds, staleAfter)
  const labels = Array.isArray(runner.labels) ? runner.labels : []
  const repos = Array.isArray(runner.repos) ? runner.repos : null
  return {
    id: runner.id,
    shortId: shortId(runner.id),
    capacity: Number(runner.capacity) || 0,
    sandbox: runner.sandbox || '',
    labels,
    labelsText: labels.length ? labels.join(', ') : 'none declared',
    repos,
    reposText: repos === null ? 'any' : repos.length === 1 ? `only ${repos[0]}` : `only ${repos.length} named`,
    enrolled: runner.enrolled || null,
    lastSeen: runner.lastSeen || null,
    running: Number(runner.running) || 0,
    refused: runner.refused || '',
    revoked: runner.revoked || null,
    state,
    actions: rowActions(state),
    retentions: retentionsOf(runner),
    history: historyOf(runner),
  }
}

// whether a runner's latest report shows it waiting for its execution-
// history transition (legacy-replay-upgrade ruling 01): null when it has
// reported no history. A paused runner advertises no capacity and runs
// nothing until its transition is confirmed.
export function historyOf(runner) {
  const h = runner?.history
  if (!h || typeof h !== 'object') return null
  return { paused: h.paused === true, revision: Number.isFinite(Number(h.revision)) ? Number(h.revision) : 0 }
}

// what a runner's latest retention report says it withholds (legacy-
// recovery UI ruling 01): null when it has reported none
export function retentionsOf(runner) {
  const r = runner?.retentions
  if (!r || typeof r !== 'object') return null
  const n = (v) => (Number.isFinite(Number(v)) ? Number(v) : 0)
  return { reported: n(r.reported) || null, total: n(r.total), legacy: n(r.legacy), eligible: n(r.eligible) }
}

// the row's retention cell: how many slots it withholds, and how many a
// release from here could return now
export function retentionsText(retentions) {
  if (!retentions) return 'not reported'
  if (!retentions.total) return 'none'
  const legacy = retentions.legacy ? ` · ${retentions.legacy} legacy${retentions.eligible ? `, ${retentions.eligible} releasable` : ''}` : ''
  return `${retentions.total} withheld${legacy}`
}

// the ship's clock against the client's: facts and reads carry the ship's
// `now`; ages are measured on the ship's clock, so the client keeps the
// offset and adds it to its own clock between facts
export const clockOffset = (shipNow, clientNow = Date.now() / 1000) =>
  Number.isFinite(Number(shipNow)) && Number(shipNow) > 0 ? Number(shipNow) - clientNow : 0

// a runner fact merged into the list by id: replace, append, or drop
export function mergeRunnerFact(runners, fact) {
  const list = Array.isArray(runners) ? runners : []
  if (!fact || typeof fact !== 'object') return list
  if (fact.kind === 'runners' && Array.isArray(fact.runners)) return fact.runners
  if (fact.kind === 'runner-gone') return list.filter((r) => r.id !== fact.id)
  if (fact.kind === 'runner' && fact.patch && fact.patch.id) {
    const at = list.findIndex((r) => r.id === fact.patch.id)
    if (at < 0) return [fact.patch, ...list]
    return list.map((r, i) => (i === at ? fact.patch : r))
  }
  return list
}

// the bodies POST ci/action takes for the panel's buttons
export const runnerActions = {
  expire: (id) => ({ action: 'expire-token', id }),
  revoke: (id) => ({ action: 'revoke-daemon', id }),
  setRepos: (id, repos) => ({ action: 'set-daemon-repos', id, repos: repos === null ? null : [...repos] }),
  rotate: () => ({ action: 'rotate-ci-key' }),
}

// the config lines the operator pastes: the ship's answer when it gave
// one, else built from the same three keys
export function configSnippet(answer) {
  if (answer?.configSnippet) return answer.configSnippet
  return `ship_url = "${answer?.shipUrl || ''}"\nenroll_token = "${answer?.token || ''}"\nsandbox = "docker-rootless"\n`
}

// how many daemons could take work at all (D7): enrolled, not revoked
export const enrolledCount = (runners = []) => runners.filter((r) => r.enrolled && !r.revoked).length
