import test from 'node:test'
import assert from 'node:assert/strict'
import { initialPanelState, panelReducer } from './runnerHistory.js'
import { renderRecovery } from './runnerRecoveryView.js'
import { NOW, RUNNER, command, h, legacyEntry, part, parts, text } from './runnerRecoveryFixtures.js'
import { SINCE, completeHistory, historyCommand, historyView, transitionedHistory, unreadableHistory, waitingHistory } from './runnerHistoryFixtures.js'

// the history transition as the panel renders it (legacy-replay-upgrade
// ruling 01): the same renderRecovery the component calls, with a plain
// element factory — the history, the proof, the confirmation, and every
// command state, each told apart

const noop = { select() {}, openConfirm() {}, acknowledge() {}, cancel() {}, release() {}, openTransition() {}, acknowledgeTransition() {}, cancelTransition() {}, transition() {}, refresh() {}, close() {} }
const render = (state) => renderRecovery(h, { runner: { id: RUNNER }, state, now: NOW }, noop)
const stateWith = (view, events = []) => events.reduce(panelReducer, panelReducer(initialPanelState(), { type: 'loaded', view }))

test('a waiting runner\'s panel opens on its paused execution: its history, the proof its transition stands on, and a transition offered', () => {
  const tree = render(stateWith(historyView(waitingHistory(), { ship: { epoch: 0, next: 1, assignments: 2, running: ['0v4.att'] } })))
  assert.equal(part(tree, 'history')?.props['data-state'], 'waiting', 'A WAITING RUNNER WAS NOT SHOWN WAITING')
  assert.match(text(tree), /Execution paused/)
  assert.match(text(part(tree, 'history-facts')), /History since.*2026-09-21T14:13:20Z/)
  assert.match(text(part(tree, 'history-facts')), /format 1/)
  assert.match(text(part(tree, 'history-facts')), /2 assignments held for it; 1 attempt running on it; its epoch 0/)
  assert.match(text(part(tree, 'history-facts')), /Evidence.*cccccccccccc/)
  const proof = text(part(tree, 'proof'))
  assert.match(proof, /not on anyone’s word/)
  assert.match(proof, /authorization epoch 1 above bit 128/)
  assert.ok(part(tree, 'open-transition'), 'A WAITING RUNNER WAS OFFERED NO TRANSITION')
  assert.match(text(part(tree, 'capacity')), /0 advertised/)
})

test('a runner whose history cannot be read is shown waiting on that, never as fresh', () => {
  const tree = render(stateWith(historyView(unreadableHistory())))
  assert.equal(part(tree, 'history').props['data-state'], 'waiting', 'A RUNNER WHOSE HISTORY CANNOT BE READ WAS NOT SHOWN WAITING')
  assert.match(text(part(tree, 'history-facts')), /not recorded: its HISTORY cannot be read/)
  assert.match(text(part(tree, 'history-state')), /no proof of a fresh runner/)
  assert.ok(part(tree, 'open-transition'))
})

test('a complete or transitioned runner is offered no transition, and its panel is its withheld slots', () => {
  const complete = render(stateWith(historyView(completeHistory())))
  assert.equal(part(complete, 'history').props['data-state'], 'complete')
  assert.equal(part(complete, 'open-transition'), null, 'A COMPLETE RUNNER WAS OFFERED A TRANSITION')
  assert.equal(part(complete, 'proof'), null)
  assert.doesNotMatch(text(complete), /Execution paused/)
  const transitioned = render(stateWith(historyView(transitionedHistory(3, '0v7.hist'))))
  assert.equal(part(transitioned, 'history').props['data-state'], 'transitioned')
  assert.match(text(part(transitioned, 'history-facts')), /Transition.*epoch 3, recorded .* by command 0v7\.hist/)
  assert.equal(part(transitioned, 'open-transition'), null, 'A TRANSITIONED RUNNER WAS OFFERED A TRANSITION')
  // a runner before the ledger reports no history: nothing is shown of it
  assert.equal(part(render(stateWith(historyView(null))), 'history'), null)
})

test('the transition\'s confirmation restates the exact history, revision, epoch and evidence, and waits for the acknowledgment', () => {
  const events = [{ type: 'history-confirm-open', now: NOW }]
  const tree = render(stateWith(historyView(waitingHistory(), { ship: { epoch: 2, next: 3, assignments: 0, running: [] } }), events))
  const confirmation = part(tree, 'transition-confirmation')
  assert.ok(confirmation, 'NO SEPARATE TRANSITION CONFIRMATION WAS SHOWN')
  assert.equal(confirmation.props.role, 'alertdialog')
  const restated = text(part(confirmation, 'transition-restated'))
  assert.match(restated, /authorization epoch 3/)
  assert.match(restated, new RegExp(`history history/${SINCE}, revision ${SINCE}`))
  assert.match(restated, /digest cccccccccccc/)
  assert.equal(part(tree, 'transition').props.disabled, true, 'A TRANSITION COULD BE CONFIRMED WITHOUT ITS ACKNOWLEDGMENT')
  assert.equal(part(tree, 'open-transition').props.disabled, true)
  const acknowledged = render(stateWith(historyView(waitingHistory(), { ship: { epoch: 2, next: 3, assignments: 0, running: [] } }), [...events, { type: 'history-acknowledge', value: true }]))
  assert.equal(part(acknowledged, 'transition').props.disabled, false)
  assert.equal(part(acknowledged, 'transition-stale'), null)
})

test('a transition confirmation the runner\'s latest report no longer supports is stale: said, and its button disabled', () => {
  const events = [{ type: 'history-confirm-open', now: NOW }, { type: 'history-acknowledge', value: true }]
  for (const [view, why] of [
    [historyView(waitingHistory({ evidence: 'f'.repeat(64) })), /evidence changed since you inspected it/],
    [historyView(transitionedHistory()), /no longer reports its history waiting/],
    [historyView(waitingHistory(), { commands: [historyCommand('queued')] }), /already open/],
  ]) {
    const tree = render(stateWith(historyView(waitingHistory()), [...events, { type: 'loaded', view }]))
    assert.match(text(part(tree, 'transition-stale')), why, 'A STALE TRANSITION CONFIRMATION WAS NOT SAID')
    assert.equal(part(tree, 'transition').props.disabled, true, 'A STALE TRANSITION COULD BE CONFIRMED')
  }
})

test('every transition command state is shown apart, and a completed transition is never called a release', () => {
  const seen = new Set()
  for (const [status, want] of Object.entries({ queued: 'queued', delivered: 'pending', uncertain: 'uncertain', completed: 'completed', refused: 'refused' })) {
    const history = status === 'completed' ? transitionedHistory() : waitingHistory()
    const tree = render(stateWith(historyView(history, { commands: [historyCommand(status, { detail: status === 'completed' ? 'recorded the transition to authorization epoch 1' : '' })], reported: NOW })))
    const line = part(part(tree, 'history'), 'history-command')
    assert.equal(line.props['data-state'], want, `THE ${want.toUpperCase()} TRANSITION STATE WAS NOT SHOWN AS ITSELF`)
    seen.add(text(line))
    const listed = part(parts(tree, 'command')[0], 'command-state')
    assert.doesNotMatch(text(listed), /Released/, 'A TRANSITION WAS SHOWN AS A RELEASE')
    if (status === 'completed') assert.match(text(listed), /Transitioned/)
    assert.equal(Boolean(part(tree, 'open-transition')), status === 'refused', `THE TRANSITION OFFER AFTER A ${status.toUpperCase()} COMMAND IS WRONG`)
  }
  assert.equal(seen.size, 5)
  // a release command in the same list is still a release
  const mixed = render(stateWith(historyView(completeHistory(), { commands: [command('completed', { detail: 'released' })], retentions: [] })))
  assert.match(text(part(parts(mixed, 'command')[0], 'command-state')), /Released/)
})

test('a completed transition not reported yet is shown done, and no second one is offered', () => {
  const tree = render(stateWith(historyView(waitingHistory(), { commands: [historyCommand('completed', { finished: NOW - 20 })], reported: NOW - 25 })))
  assert.equal(part(tree, 'history').props['data-state'], 'transitioned')
  assert.equal(part(tree, 'open-transition'), null, 'A SECOND TRANSITION WAS OFFERED BEFORE THE RUNNER\'S REPORT CAME')
  assert.match(text(part(tree, 'no-transition')), /its next report shows it/)
})

test('a release being confirmed keeps the transition closed', () => {
  const view = historyView(waitingHistory(), { retentions: [legacyEntry()] })
  const tree = render(stateWith(view, [{ type: 'select', selection: legacyEntry().selection }, { type: 'confirm-open', now: NOW }]))
  assert.ok(part(tree, 'confirmation'))
  assert.equal(part(tree, 'open-transition').props.disabled, true, 'A TRANSITION COULD BE OPENED OVER A RELEASE BEING CONFIRMED')
  const other = render(stateWith(view, [{ type: 'select', selection: legacyEntry().selection }, { type: 'history-confirm-open', now: NOW }]))
  assert.equal(part(other, 'open-confirm').props.disabled, true, 'A RELEASE COULD BE OPENED OVER A TRANSITION BEING CONFIRMED')
})
