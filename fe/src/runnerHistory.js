// The Runners panel's execution-history transition (legacy-replay-upgrade
// ruling 01; runner/launcher/INTEGRATION.md §11.15): the pure model the
// panel renders. A runner whose history is incomplete — upgraded from a
// version without the execution ledger, or its history unreadable — runs
// nothing until the owner confirms its transition. Its history comes from
// its latest report; what the ship holds of its authorizations, from the
// ship. A transition is offered only while the runner reports its history
// waiting, with an evidence digest to bind, and no transition command of it
// open; its body is bound to exactly the history's revision and evidence as
// inspected. A command's state is the ship's record of the runner's own
// answer: completed only on that answer, never on the ship's receipt of the
// request. Nothing here fetches.

import { commandState, initialRecoveryState, recoveryReducer } from './runnerRecovery.js'

export const historyOperation = 'confirm-history'

// the view's transition commands, newest first as the ship answers them
export function historyCommands(view) {
  const list = Array.isArray(view?.commands) ? view.commands : []
  return list.filter((c) => c && c.operation === historyOperation)
}

// a transition command's state: commandState's, told as a transition
export function transitionState(command, nowSeconds) {
  const s = commandState(command, nowSeconds)
  if (!s) return null
  switch (s.state) {
    case 'completed':
      return { ...s, label: 'Transitioned', detail: command.detail || 'The runner recorded its transition durably, and runs new work again.' }
    case 'refused':
      return { ...s, detail: `${command.detail || 'The runner refused it.'} The runner keeps waiting, and runs nothing.` }
    case 'pending':
      return { ...s, detail: 'The runner has the command and is checking its history again. It runs nothing until it answers.' }
    case 'uncertain':
      return { ...s, detail: `The runner has no final answer recorded yet, so it keeps waiting and runs nothing. The ship hands the command over again until it has one. ${command.detail || ''}`.trim() }
    case 'expired':
      return { ...s, detail: command.detail || 'The runner did not fetch it within fifteen minutes, so nothing was done: it keeps waiting.' }
    default:
      return s
  }
}

const number = (v) => (Number.isFinite(Number(v)) ? Number(v) : 0)

// a completed transition the runner's latest report does not show yet: the
// report came before the ship recorded the runner's answer (the runner
// reports right after it answers). Until one comes after it, no second
// transition is offered, and the panel reads the ship again.
function awaitingReport(h, view, command) {
  if (!command || command.status !== 'completed' || h.paused !== true) return false
  return !(number(view?.reported) > number(command.finished))
}

// the runner's history as the panel reads it, or null when its latest
// report shows none (a runner before the ledger, or one not reported yet)
export function historyRow(view, nowSeconds) {
  const h = view?.report?.history
  if (!h || typeof h !== 'object') return null
  const command = historyCommands(view)[0] || null
  const ship = view?.history && typeof view.history === 'object' ? view.history : null
  return {
    selection: typeof h.selection === 'string' ? h.selection : '',
    revision: number(h.revision),
    since: number(h.since),
    known: h.known === true,
    complete: h.complete === true,
    paused: h.paused === true,
    epoch: number(h.epoch),
    stateFormat: number(h.stateFormat),
    evidence: typeof h.evidence === 'string' ? h.evidence : '',
    transition: h.transition && typeof h.transition === 'object' ? { epoch: number(h.transition.epoch), command: h.transition.command || '', at: number(h.transition.at) } : null,
    // a record the runner's state file holds that is no transition: why, and
    // the record as the file holds it (INTEGRATION.md §11.16)
    invalid: h.invalidTransition && typeof h.invalidTransition === 'object' ? { problem: String(h.invalidTransition.problem || ''), record: String(h.invalidTransition.record || '') } : null,
    explanation: h.explanation || '',
    ship: ship ? { epoch: number(ship.epoch), next: number(ship.next) || number(ship.epoch) + 1, assignments: number(ship.assignments), running: Array.isArray(ship.running) ? ship.running : [] } : null,
    command,
    commandState: transitionState(command, nowSeconds),
    awaitingReport: awaitingReport(h, view, command),
  }
}

// what the history says, as its line reads
export function historyState(row) {
  if (!row) return null
  if (row.complete) return { state: 'complete', label: 'Complete', detail: 'Its ledger began with this runner’s enrollment: every attempt it took is recorded, and it needs no transition.' }
  if (row.transition) return { state: 'transitioned', label: `Epoch ${row.transition.epoch}`, detail: `Its transition to authorization epoch ${row.transition.epoch} is recorded: it refuses every assignment its ship signed before, and runs new work.` }
  if (row.awaitingReport) return { state: 'transitioned', label: 'Transitioned', detail: 'The runner answered that it recorded its transition durably. Its report after that answer has not come yet: it shows its new epoch.' }
  if (row.paused && row.invalid) {
    return {
      state: 'waiting',
      label: 'Execution paused',
      detail: `Its state file holds a transition record that is no transition (${row.invalid.problem}). It is kept as the file holds it, and not taken for one: the runner advertises no capacity and runs nothing until its transition is confirmed.`,
    }
  }
  if (row.paused) {
    return {
      state: 'waiting',
      label: 'Execution paused',
      detail: row.known
        ? 'Its history began with a state file kept before its execution ledger: what it ran before is not known. It advertises no capacity and runs nothing until its transition is confirmed.'
        : 'Its history cannot be read, and an unreadable history is no proof of a fresh runner. It advertises no capacity and runs nothing until its transition is confirmed.',
    }
  }
  return { state: 'unknown', label: 'Not known', detail: row.explanation || 'The runner reports its history neither complete nor waiting.' }
}

// a transition is offered only while the runner reports its history
// waiting, with an evidence digest to bind, and no transition command open
export function canTransition(row) {
  if (!row || row.paused !== true) return false
  if (!/^[0-9a-f]{64}$/.test(row.evidence)) return false
  if (row.commandState?.open) return false
  if (row.awaitingReport) return false
  return true
}

// what the owner confirms: the exact history, revision and evidence the
// panel showed, the epoch the ship would name, and when it was inspected
export function transitionBinding(row, atSeconds) {
  return { selection: row.selection, revision: row.revision, evidence: row.evidence, epoch: row.ship ? row.ship.next : null, at: atSeconds }
}

// why a binding no longer holds against the latest view, or '' when it does
export function transitionStaleReason(binding, view, nowSeconds) {
  if (!binding) return 'nothing is being confirmed'
  const row = historyRow(view, nowSeconds)
  if (!row) return 'The runner no longer reports its history. Inspect it again.'
  if (row.selection !== binding.selection || row.revision !== binding.revision) return 'The runner’s history changed since you inspected it. Inspect it again.'
  if (row.evidence !== binding.evidence) return 'The evidence changed since you inspected it. Inspect it again.'
  if (row.commandState?.open) return 'A transition command for this runner is already open.'
  if (row.awaitingReport) return 'The runner already answered that it recorded its transition.'
  if (!canTransition(row)) return 'The runner no longer reports its history waiting for a transition.'
  return ''
}

// the body POST ci/action takes for the confirmation: the runner, and the
// history's revision and evidence exactly as inspected — nothing typed
export function transitionBody(runnerId, binding) {
  return { action: 'request-history-transition', id: runnerId, revision: binding.revision, evidence: binding.evidence }
}

// what the transition does, and why no earlier authorization can run after
// it, as the owner reads it before confirming
export function transitionProof(row) {
  const next = row?.ship ? row.ship.next : null
  const running = row?.ship ? row.ship.running.length : 0
  return [
    'Every assignment this ship ever signed carries a nonce below 2^128: its nonces are sixteen bytes.',
    next
      ? `From your confirmation on, every assignment the ship signs for this runner carries authorization epoch ${next} above bit 128.`
      : 'From your confirmation on, every assignment the ship signs for this runner carries its next authorization epoch above bit 128.',
    'The runner records the epoch durably before it answers, and from then on refuses every assignment below it — whatever its spelling, expiry or clock — so nothing authorized before the transition can run there.',
    running
      ? `${running} attempt${running === 1 ? '' : 's'} still running on it at the ship ${running === 1 ? 'is' : 'are'} given back when delivered again, and offered again as a new attempt or closed.`
      : 'No attempt is running on it at the ship.',
    'Its retentions stay withheld. Nothing is released, reset or re-enrolled, and its history before is not rewritten: it stays unknown.',
    ...(row?.invalid ? ['The record its state file holds that is no transition is kept: the transition you confirm supersedes it, and the runner keeps it as the file held it.'] : []),
  ]
}

// the transition's part of the panel's state, and its reducer: events
// named history-*
export function initialHistoryState() {
  return { historyConfirming: null, historyAcknowledged: false }
}

export function historyReducer(state, event) {
  switch (event.type) {
    case 'history-confirm-open': {
      const row = historyRow(state.view, event.now)
      // one confirmation at a time: a release being confirmed comes first
      if (state.confirming || !canTransition(row)) return state
      return { ...state, historyConfirming: transitionBinding(row, event.now), historyAcknowledged: false, postError: '', notice: '' }
    }
    case 'history-acknowledge':
      return state.historyConfirming ? { ...state, historyAcknowledged: event.value === true } : state
    case 'history-confirm-cancel':
      return { ...state, historyConfirming: null, historyAcknowledged: false }
    case 'history-post-start':
      return { ...state, posting: true, postError: '', notice: '' }
    case 'history-post-done':
      return { ...state, posting: false, historyConfirming: null, historyAcknowledged: false, notice: 'The ship recorded the transition request. The runner keeps waiting until it answers.' }
    case 'history-post-failed':
      return event.lost
        ? { ...state, posting: false, historyConfirming: null, historyAcknowledged: false, notice: 'The request may or may not have reached the ship. Reading it again shows whether a command exists.' }
        : { ...state, posting: false, postError: event.error || 'the ship refused the request' }
    default:
      return state
  }
}

// whether the transition may be posted now: an acknowledged binding that
// still holds, and no post in flight
export function mayTransition(state, nowSeconds) {
  return Boolean(state.historyConfirming) && state.historyAcknowledged === true && !state.posting && transitionStaleReason(state.historyConfirming, state.view, nowSeconds) === ''
}

// the whole panel's state and reducer: the transition's events (history-*)
// go to historyReducer, every other to the recovery's; one confirmation is
// open at a time
export function initialPanelState() {
  return { ...initialRecoveryState(), ...initialHistoryState() }
}

export function panelReducer(state, event) {
  if (String(event?.type).startsWith('history-')) return historyReducer(state, event)
  if (event?.type === 'confirm-open' && state.historyConfirming) return state
  return recoveryReducer(state, event)
}

// whether the panel reads the ship again for the transition: a command of
// it open, or its completion not reported yet
export function historyPending(view, nowSeconds) {
  const row = historyRow(view, nowSeconds)
  return Boolean(row && (row.commandState?.open || row.awaitingReport))
}
