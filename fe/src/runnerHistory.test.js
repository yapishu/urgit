import test from 'node:test'
import assert from 'node:assert/strict'
import { canTransition, historyPending, historyReducer, historyRow, historyState, initialPanelState, mayTransition, panelReducer, transitionBody, transitionProof, transitionStaleReason, transitionState } from './runnerHistory.js'
import { NOW, RUNNER, legacyEntry } from './runnerRecoveryFixtures.js'
import { HISTORY_EVIDENCE, SINCE, completeHistory, historyCommand, historyView, transitionedHistory, unreadableHistory, waitingHistory } from './runnerHistoryFixtures.js'

// the Runners panel's history transition, its pure model (legacy-replay-
// upgrade ruling 01): what the runner's report says of its history, when a
// transition is offered, what its confirmation is bound to and posts, when
// that binding no longer holds, and the command's state — Transitioned only
// on the runner's own answer

const loaded = (view) => panelReducer(initialPanelState(), { type: 'loaded', view })
const reduce = (state, events) => events.reduce(panelReducer, state)

test('the runner\'s history is read as its report says it, with what the ship holds of its authorizations; none when the report shows none', () => {
  const row = historyRow(historyView(waitingHistory(), { ship: { epoch: 2, next: 3, assignments: 1, running: ['0v4.att'] } }), NOW)
  assert.equal(row.selection, `history/${SINCE}`)
  assert.equal(row.revision, SINCE)
  assert.equal(row.paused, true)
  assert.equal(row.known, true)
  assert.equal(row.complete, false)
  assert.equal(row.evidence, HISTORY_EVIDENCE)
  assert.deepEqual(row.ship, { epoch: 2, next: 3, assignments: 1, running: ['0v4.att'] })
  assert.equal(historyRow(historyView(null), NOW), null, 'A REPORT WITHOUT A HISTORY WAS READ AS ONE')
  assert.equal(historyRow({ report: { history: 'x' } }, NOW), null)
  assert.equal(historyRow(null, NOW), null)
})

test('each history is told apart: waiting after an upgrade, waiting on a history it cannot read, complete, and transitioned', () => {
  const states = {
    waiting: historyView(waitingHistory()),
    unreadable: historyView(unreadableHistory()),
    complete: historyView(completeHistory()),
    transitioned: historyView(transitionedHistory(2)),
  }
  const seen = new Set()
  for (const [name, view] of Object.entries(states)) {
    const s = historyState(historyRow(view, NOW))
    seen.add(`${s.state}/${s.label}/${s.detail}`)
    if (name === 'waiting') {
      assert.equal(s.state, 'waiting')
      assert.match(s.detail, /state file kept before its execution ledger.*runs nothing until its transition is confirmed/)
    }
    if (name === 'unreadable') {
      assert.equal(s.state, 'waiting', 'A RUNNER WHOSE HISTORY CANNOT BE READ WAS NOT SHOWN WAITING')
      assert.match(s.detail, /an unreadable history is no proof of a fresh runner/)
    }
    if (name === 'complete') assert.equal(s.state, 'complete')
    if (name === 'transitioned') {
      assert.equal(s.state, 'transitioned')
      assert.match(s.label, /Epoch 2/)
    }
  }
  assert.equal(seen.size, 4)
})

test('a transition is offered only to a runner its report shows waiting, with evidence to bind, and no transition command open', () => {
  assert.equal(canTransition(historyRow(historyView(waitingHistory()), NOW)), true, 'A WAITING RUNNER WAS OFFERED NO TRANSITION')
  assert.equal(canTransition(historyRow(historyView(unreadableHistory()), NOW)), true, 'A RUNNER WHOSE HISTORY CANNOT BE READ WAS OFFERED NO TRANSITION')
  for (const [name, view] of Object.entries({
    complete: historyView(completeHistory()),
    transitioned: historyView(transitionedHistory()),
    'no evidence': historyView(waitingHistory({ evidence: '' })),
    'malformed evidence': historyView(waitingHistory({ evidence: 'C'.repeat(64) })),
  })) {
    assert.equal(canTransition(historyRow(view, NOW)), false, `A RUNNER NOT WAITING WAS OFFERED A TRANSITION (${name})`)
  }
  for (const status of ['queued', 'delivered', 'uncertain']) {
    assert.equal(canTransition(historyRow(historyView(waitingHistory(), { commands: [historyCommand(status)] }), NOW)), false, `A SECOND TRANSITION WAS OFFERED WHILE ONE IS OPEN (${status})`)
  }
  for (const status of ['refused']) {
    assert.equal(canTransition(historyRow(historyView(waitingHistory(), { commands: [historyCommand(status)] }), NOW)), true, `no new transition after a ${status} one`)
  }
  // a queued command past its time is expired: a new one may be requested
  assert.equal(canTransition(historyRow(historyView(waitingHistory(), { commands: [historyCommand('queued', { expires: NOW - 1 })] }), NOW)), true)
})

test('a completed transition the runner\'s report does not show yet offers no second one, and the panel reads the ship until a report after it comes', () => {
  const done = historyCommand('completed', { finished: NOW - 20 })
  const before = historyView(waitingHistory(), { commands: [done], reported: NOW - 25 })
  const row = historyRow(before, NOW)
  assert.equal(row.awaitingReport, true)
  assert.equal(canTransition(row), false, 'A SECOND TRANSITION WAS OFFERED BEFORE THE RUNNER\'S REPORT CAME')
  assert.equal(historyState(row).state, 'transitioned')
  assert.equal(historyPending(before, NOW), true, 'THE PANEL STOPPED READING BEFORE THE TRANSITION WAS REPORTED')
  // a report in the same second as the answer may have come before it
  assert.equal(historyRow(historyView(waitingHistory(), { commands: [done], reported: NOW - 20 }), NOW).awaitingReport, true)
  // a report after it that still shows the runner waiting: it lost its record, and may be transitioned again
  const after = historyView(waitingHistory(), { commands: [done], reported: NOW - 19 })
  assert.equal(historyRow(after, NOW).awaitingReport, false)
  assert.equal(canTransition(historyRow(after, NOW)), true)
  assert.equal(historyPending(after, NOW), false)
  assert.equal(historyPending(historyView(transitionedHistory(), { commands: [done], reported: NOW - 19 }), NOW), false)
  assert.equal(historyPending(historyView(waitingHistory(), { commands: [historyCommand('delivered')] }), NOW), true)
})

test('the confirmation is bound to the history, revision and evidence inspected and the epoch the ship names; its body is exactly that binding, nothing typed', () => {
  const state = reduce(loaded(historyView(waitingHistory(), { ship: { epoch: 4, next: 5, assignments: 0, running: [] } })), [{ type: 'history-confirm-open', now: NOW }])
  assert.deepEqual(state.historyConfirming, { selection: `history/${SINCE}`, revision: SINCE, evidence: HISTORY_EVIDENCE, epoch: 5, at: NOW })
  assert.equal(state.historyAcknowledged, false)
  assert.deepEqual(transitionBody(RUNNER, state.historyConfirming), { action: 'request-history-transition', id: RUNNER, revision: SINCE, evidence: HISTORY_EVIDENCE }, 'THE TRANSITION BODY IS NOT THE INSPECTED BINDING')
})

test('a transition confirmation opens only for a runner waiting for one', () => {
  for (const view of [historyView(completeHistory()), historyView(transitionedHistory()), historyView(waitingHistory(), { commands: [historyCommand('queued')] }), historyView(null)]) {
    const state = reduce(loaded(view), [{ type: 'history-confirm-open', now: NOW }])
    assert.equal(state.historyConfirming, null, 'A TRANSITION CONFIRMATION OPENED FOR A RUNNER NOT WAITING')
  }
})

test('a transition may be posted only acknowledged, not stale, and not while a post is in flight', () => {
  const open = reduce(loaded(historyView(waitingHistory())), [{ type: 'history-confirm-open', now: NOW }])
  assert.equal(mayTransition(open, NOW), false, 'A TRANSITION MAY BE POSTED WITHOUT ITS ACKNOWLEDGMENT')
  const acknowledged = panelReducer(open, { type: 'history-acknowledge', value: true })
  assert.equal(mayTransition(acknowledged, NOW), true)
  assert.equal(mayTransition(panelReducer(acknowledged, { type: 'history-post-start' }), NOW), false)
  const changed = panelReducer(acknowledged, { type: 'loaded', view: historyView(waitingHistory({ evidence: 'f'.repeat(64) })) })
  assert.equal(mayTransition(changed, NOW), false, 'A STALE TRANSITION MAY BE POSTED')
  // an acknowledgment without a confirmation open is nothing
  assert.equal(panelReducer(loaded(historyView(waitingHistory())), { type: 'history-acknowledge', value: true }).historyAcknowledged, false)
})

test('a binding the runner\'s latest report no longer supports is stale, and says why', () => {
  const binding = { selection: `history/${SINCE}`, revision: SINCE, evidence: HISTORY_EVIDENCE, epoch: 1, at: NOW }
  assert.equal(transitionStaleReason(binding, historyView(waitingHistory()), NOW), '')
  assert.match(transitionStaleReason(binding, historyView(waitingHistory({ evidence: 'f'.repeat(64) })), NOW), /evidence changed/, 'CHANGED HISTORY EVIDENCE WAS NOT STALE')
  assert.match(transitionStaleReason(binding, historyView(waitingHistory({ selection: 'history/1790000001', revision: SINCE + 1 })), NOW), /history changed/)
  assert.match(transitionStaleReason(binding, historyView(transitionedHistory()), NOW), /no longer reports its history waiting/)
  assert.match(transitionStaleReason(binding, historyView(waitingHistory(), { commands: [historyCommand('queued')] }), NOW), /already open/)
  assert.match(transitionStaleReason(binding, historyView(null), NOW), /no longer reports its history/)
  assert.match(transitionStaleReason(null, historyView(waitingHistory()), NOW), /nothing is being confirmed/)
})

test('one confirmation at a time: a release being confirmed keeps the transition closed, and a transition being confirmed keeps the release closed', () => {
  const both = historyView(waitingHistory(), { retentions: [legacyEntry()] })
  const releasing = reduce(loaded(both), [{ type: 'select', selection: legacyEntry().selection }, { type: 'confirm-open', now: NOW }])
  assert.ok(releasing.confirming)
  assert.equal(panelReducer(releasing, { type: 'history-confirm-open', now: NOW }).historyConfirming, null, 'TWO CONFIRMATIONS WERE OPEN AT ONCE')
  const transitioning = reduce(loaded(both), [{ type: 'select', selection: legacyEntry().selection }, { type: 'history-confirm-open', now: NOW }])
  assert.ok(transitioning.historyConfirming)
  assert.equal(panelReducer(transitioning, { type: 'confirm-open', now: NOW }).confirming, null, 'TWO CONFIRMATIONS WERE OPEN AT ONCE')
  // every other event is the recovery's, unchanged
  assert.equal(panelReducer(initialPanelState(), { type: 'load-failed', error: 'x' }).loadError, 'x')
  assert.equal(panelReducer(transitioning, { type: 'history-confirm-cancel' }).historyConfirming, null)
})

test('a post whose answer never came is said to be unknown, never taken for a refusal or a success; the ship\'s refusal is kept in its words', () => {
  const open = reduce(loaded(historyView(waitingHistory())), [{ type: 'history-confirm-open', now: NOW }, { type: 'history-acknowledge', value: true }, { type: 'history-post-start' }])
  const lost = historyReducer(open, { type: 'history-post-failed', error: 'Failed to fetch', lost: true })
  assert.match(lost.notice, /may or may not have reached the ship/, 'A LOST TRANSITION POST WAS NOT SAID TO BE UNKNOWN')
  assert.equal(lost.historyConfirming, null)
  assert.equal(lost.postError, '')
  const refused = historyReducer(open, { type: 'history-post-failed', error: 'the history evidence changed since it was inspected: inspect it again', lost: false })
  assert.equal(refused.postError, 'the history evidence changed since it was inspected: inspect it again')
  assert.ok(refused.historyConfirming)
  const done = historyReducer(open, { type: 'history-post-done' })
  assert.match(done.notice, /The runner keeps waiting until it answers/)
  assert.equal(done.posting, false)
})

test('a transition command\'s state: Transitioned only on the runner\'s own answer; a receipt, a delivery or a doubt keeps the runner waiting', () => {
  const seen = new Set()
  for (const [status, want] of Object.entries({ queued: 'queued', delivered: 'pending', uncertain: 'uncertain', completed: 'completed', refused: 'refused' })) {
    const s = transitionState(historyCommand(status, { detail: status === 'completed' ? 'recorded the transition to authorization epoch 1' : '' }), NOW)
    assert.equal(s.state, want)
    seen.add(s.label)
    if (status !== 'completed') assert.doesNotMatch(s.label, /Transitioned/, `A ${status.toUpperCase()} TRANSITION WAS READ AS DONE`)
    if (['delivered', 'uncertain', 'refused'].includes(status)) assert.match(s.detail, /runs nothing/)
    assert.equal(s.open, ['queued', 'delivered', 'uncertain'].includes(status))
  }
  assert.equal(transitionState(historyCommand('completed'), NOW).label, 'Transitioned')
  assert.equal(transitionState(historyCommand('queued', { expires: NOW - 1 }), NOW).state, 'expired')
  assert.equal(transitionState(historyCommand('bogus'), NOW).open, true, 'AN UNKNOWN ANSWER WAS TAKEN FOR A RESULT')
  assert.equal(transitionState(null, NOW), null)
  assert.equal(seen.size, 5)
})

test('the proof the owner reads names the epoch the ship will sign with, and that nothing is released, reset or re-enrolled', () => {
  const lines = transitionProof(historyRow(historyView(waitingHistory(), { ship: { epoch: 1, next: 2, assignments: 3, running: ['0v4.att', '0v5.att'] } }), NOW)).join('\n')
  assert.match(lines, /below 2\^128/)
  assert.match(lines, /authorization epoch 2 above bit 128/)
  assert.match(lines, /records the epoch durably before it answers/)
  assert.match(lines, /2 attempts still running on it/)
  assert.match(lines, /Nothing is released, reset or re-enrolled/)
})
