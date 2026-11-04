import test from 'node:test'
import assert from 'node:assert/strict'
import { canTransition, historyRow, historyState, initialPanelState, panelReducer, transitionProof } from './runnerHistory.js'
import { renderRecovery } from './runnerRecoveryView.js'
import { NOW, RUNNER, h, part, text } from './runnerRecoveryFixtures.js'
import { historyView, waitingHistory } from './runnerHistoryFixtures.js'

// Independent review 12, R12-1 (runner/launcher/INTEGRATION.md §11.16): a
// runner whose state file holds a transition record that is no transition
// waits, and its report says why, with the record as the file holds it. The
// panel shows the runner waiting, says why the record is none and shows it,
// and offers the owner's transition, which supersedes the record and keeps
// it.

const PROBLEM = 'its authorization epoch is 0: a transition takes a runner to epoch 1 or more'
const RECORD = '{"epoch":0,"command":"0v5hist","evidence":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","at":1790000000}'
const invalidHistory = () => waitingHistory({ invalidTransition: { problem: PROBLEM, record: RECORD } })

const noop = { select() {}, openConfirm() {}, acknowledge() {}, cancel() {}, release() {}, openTransition() {}, acknowledgeTransition() {}, cancelTransition() {}, transition() {}, refresh() {}, close() {} }
const render = (view) => renderRecovery(h, { runner: { id: RUNNER }, state: panelReducer(initialPanelState(), { type: 'loaded', view }), now: NOW }, noop)

test('a record that is no transition is read from the report: the runner waits, and says why', () => {
  const row = historyRow(historyView(invalidHistory()), NOW)
  assert.deepEqual(row.invalid, { problem: PROBLEM, record: RECORD }, 'A RECORD THAT IS NO TRANSITION WAS NOT READ FROM THE REPORT')
  const s = historyState(row)
  assert.equal(s.state, 'waiting')
  assert.match(s.detail, /holds a transition record that is no transition \(its authorization epoch is 0/)
  assert.match(s.detail, /kept as the file holds it/)
  assert.equal(canTransition(row), true, 'A RUNNER WITH A RECORD THAT IS NO TRANSITION WAS OFFERED NO TRANSITION')
  assert.match(transitionProof(row).join('\n'), /supersedes it, and the runner keeps it/)
  // no invalid record: none read, and the detail is the history's own
  const plain = historyRow(historyView(waitingHistory()), NOW)
  assert.equal(plain.invalid, null)
  assert.doesNotMatch(historyState(plain).detail, /no transition/)
  assert.doesNotMatch(transitionProof(plain).join('\n'), /supersedes/)
})

test('the panel shows the record that is no transition, as the file holds it, and why', () => {
  const tree = render(historyView(invalidHistory()))
  assert.equal(part(tree, 'history').props['data-state'], 'waiting')
  const facts = text(part(tree, 'history-facts'))
  assert.match(facts, /Transition recordno transition: its authorization epoch is 0/, 'A RECORD THAT IS NO TRANSITION WAS NOT SHOWN')
  assert.ok(facts.includes(RECORD), 'THE RECORD WAS NOT SHOWN AS THE FILE HOLDS IT')
  assert.ok(part(tree, 'open-transition'))
  assert.doesNotMatch(text(render(historyView(waitingHistory()))), /Transition record/)
})
