// The Runners panel's legacy recovery (legacy-recovery UI ruling 01;
// runner/launcher/INTEGRATION.md §11.12): the pure model the panel renders.
// A runner's retentions come from its latest report, each with how its slot
// returns; a legacy retention also carries its evidence and every condition.
// Each recovery command has a state: completed only on the runner's own
// answer, never on the ship's receipt of the request. The action body a
// confirmation posts is bound to exactly the inspected entry, revision and
// evidence. Nothing here fetches.

export const conditionLabel = {
  provenance: 'Written by a runner before settled admission',
  backend: 'A launcher reservation of this runner',
  protocol: 'The launcher refuses every request without a token',
  inventory: 'The launcher answered a complete inventory',
  attempt: 'The launcher holds nothing of its attempt',
  idle: 'Its attempt is not running here',
}

export const kindLabel = {
  legacy: 'legacy',
  admission: 'unsettled reserve request',
  vm: 'launcher reservation',
  docker: 'Docker sandbox',
  'unknown-backend': 'backend not recorded',
  unmarked: 'no request, not legacy',
}

export const releaseLabel = {
  urgit: 'Released from here, on its evidence',
  settlement: 'Returns by itself once the launcher settles its request',
  cli: 'Released with urgit-runner -recover, the daemon stopped',
  none: 'Stays withheld: nothing can prove its release',
}

const shortText = (text, n = 12) => (text ? String(text).slice(0, n) : '—')
export const shortDigest = (digest) => shortText(digest, 12)
export const shortAttempt = (attempt) => shortText(attempt, 14)

// a command's state as the operator reads it; open states forbid a new
// request for the same entry. A queued command past its time is expired.
export function commandState(command, nowSeconds) {
  if (!command) return null
  const expired = command.status === 'queued' && Number(command.expires) <= nowSeconds
  const status = expired ? 'expired' : command.status
  switch (status) {
    case 'queued':
      return { state: 'queued', label: 'Queued', open: true, detail: 'The ship has the request. The runner has not fetched it yet: it polls about every 25 seconds, and the request expires unfetched after fifteen minutes.' }
    case 'delivered':
      return { state: 'pending', label: 'Pending', open: true, detail: 'The runner has the command and is checking its evidence again. Nothing is released until it answers.' }
    case 'uncertain':
      return { state: 'uncertain', label: 'Uncertain', open: true, detail: `The runner has no final answer recorded yet, so nothing is released and the slot stays withheld. The ship hands the command over again until it has one. ${command.detail || ''}`.trim() }
    case 'completed':
      return { state: 'completed', label: 'Released', open: false, detail: command.detail || 'The runner released the retention durably, and its slot returned.' }
    case 'refused':
      return { state: 'refused', label: 'Refused', open: false, detail: `${command.detail || 'The runner refused it.'} The slot stays withheld.` }
    case 'expired':
      return { state: 'expired', label: 'Expired', open: false, detail: command.detail || 'The runner did not fetch it within fifteen minutes, so nothing was done.' }
    default:
      // an answer this panel does not know: never taken for a result
      return { state: 'unknown', label: String(status || 'unknown'), open: true, detail: command.detail || '' }
  }
}

// the view's commands, newest first as the ship answers them
const commandsOf = (view) => (Array.isArray(view?.commands) ? view.commands : [])

// the latest command for an entry, by its selection
export function latestCommand(view, selection) {
  return commandsOf(view).find((c) => c.selection === selection) || null
}

// whether any command of the view is still open: the panel reads the ship
// again while one is
export function openCommands(view, nowSeconds) {
  return commandsOf(view).some((c) => commandState(c, nowSeconds)?.open)
}

// the rows of the panel: every retention of the latest report, with what
// the ship knows of its attempt and its latest command
export function retentionRows(view, nowSeconds) {
  const list = Array.isArray(view?.report?.retentions) ? view.report.retentions : []
  const attempts = view?.attempts && typeof view.attempts === 'object' ? view.attempts : {}
  return list.map((entry) => {
    const command = latestCommand(view, entry.selection)
    const conditions = Array.isArray(entry.conditions) ? entry.conditions : []
    return {
      selection: entry.selection,
      revision: Number(entry.revision),
      handle: entry.handle || '',
      attempt: entry.attempt || '',
      label: entry.label || '',
      labelText: entry.label || 'no job label recorded',
      kind: entry.kind || '',
      kindText: kindLabel[entry.kind] || entry.kind || 'unknown',
      release: entry.release || 'none',
      releaseText: releaseLabel[entry.release] || releaseLabel.none,
      explanation: entry.explanation || '',
      identity: entry.identity || '',
      reason: entry.reason || '',
      retained: Number(entry.retained) || null,
      legacy: entry.legacy || null,
      eligible: entry.eligible === true,
      evidence: typeof entry.evidence === 'string' ? entry.evidence : '',
      conditions: conditions.map((c) => ({ name: c.name, label: conditionLabel[c.name] || c.name, met: c.met === true, detail: c.detail || '' })),
      unmet: conditions.filter((c) => c.met !== true).map((c) => conditionLabel[c.name] || c.name),
      facts: entry.facts || null,
      context: attempts[entry.attempt] || null,
      command,
      commandState: commandState(command, nowSeconds),
    }
  })
}

// a release is offered only for a legacy retention the runner's report
// shows releasable, with an evidence digest to bind, and no command of it
// still open
export function canRelease(row) {
  if (!row) return false
  if (row.kind !== 'legacy' || row.eligible !== true) return false
  if (!/^[0-9a-f]{64}$/.test(row.evidence)) return false
  if (row.commandState?.open) return false
  return true
}

// what the operator confirms: the exact entry, revision and evidence the
// panel showed, and when it was inspected
export function bindingOf(row, atSeconds) {
  return { selection: row.selection, revision: row.revision, evidence: row.evidence, label: row.labelText, attempt: row.attempt, at: atSeconds }
}

// why a binding no longer holds against the latest view, or '' when it
// does: the entry gone, changed, not releasable, or a command of it open
export function staleReason(binding, view, nowSeconds) {
  if (!binding) return 'nothing is being confirmed'
  const row = retentionRows(view, nowSeconds).find((r) => r.selection === binding.selection)
  if (!row) return 'The runner no longer reports this retention: it was released or changed. Inspect again.'
  if (row.revision !== binding.revision) return 'The retention changed since you inspected it. Inspect it again.'
  if (row.evidence !== binding.evidence) return 'The evidence changed since you inspected it. Inspect it again.'
  if (row.commandState?.open) return 'A command for this retention is already open.'
  if (!canRelease(row)) return 'The runner no longer reports this retention as releasable.'
  return ''
}

// the body POST ci/action takes for the confirmation: the runner, and the
// binding exactly as inspected — nothing typed, nothing recomputed
export function releaseBody(runnerId, binding) {
  return { action: 'request-legacy-release', id: runnerId, selection: binding.selection, revision: binding.revision, evidence: binding.evidence }
}

// the capacity line of a report
export function capacityText(view) {
  const c = view?.report?.capacity
  if (!c) return ''
  return `${c.configured} slot${c.configured === 1 ? '' : 's'} configured · ${c.withheld} withheld by retentions · ${c.held || 0} held for orphans · ${c.running || 0} running · ${c.advertised} advertised`
}

// the panel's state, and its reducer
export function initialRecoveryState() {
  return { view: null, loadError: '', selected: null, confirming: null, acknowledged: false, posting: false, postError: '', notice: '' }
}

export function recoveryReducer(state, event) {
  switch (event.type) {
    case 'loaded':
      return { ...state, view: event.view, loadError: '' }
    case 'load-failed':
      return { ...state, loadError: event.error || 'the ship could not be read' }
    case 'select':
      return { ...state, selected: event.selection, confirming: state.confirming?.selection === event.selection ? state.confirming : null, acknowledged: state.confirming?.selection === event.selection ? state.acknowledged : false, postError: '' }
    case 'confirm-open': {
      const row = retentionRows(state.view, event.now).find((r) => r.selection === state.selected)
      if (!canRelease(row)) return state
      return { ...state, confirming: bindingOf(row, event.now), acknowledged: false, postError: '', notice: '' }
    }
    case 'acknowledge':
      return state.confirming ? { ...state, acknowledged: event.value === true } : state
    case 'confirm-cancel':
      return { ...state, confirming: null, acknowledged: false }
    case 'post-start':
      return { ...state, posting: true, postError: '', notice: '' }
    case 'post-done':
      return { ...state, posting: false, confirming: null, acknowledged: false, notice: 'The ship recorded the request. Nothing is released until the runner answers.' }
    case 'post-failed':
      return event.lost
        ? { ...state, posting: false, confirming: null, acknowledged: false, notice: 'The request may or may not have reached the ship. Reading it again shows whether a command exists.' }
        : { ...state, posting: false, postError: event.error || 'the ship refused the request' }
    default:
      return state
  }
}

// whether the confirmation may be posted now: an acknowledged binding that
// still holds, and no post in flight
export function mayPost(state, nowSeconds) {
  return Boolean(state.confirming) && state.acknowledged === true && !state.posting && staleReason(state.confirming, state.view, nowSeconds) === ''
}
