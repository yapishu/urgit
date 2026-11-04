import test from 'node:test'
import assert from 'node:assert/strict'
import { makeRunnerRecovery } from './runnerRecoveryComponent.js'
import { NOW, RUNNER, hooksRuntime, manualSchedule, part, parts, settle, text } from './runnerRecoveryFixtures.js'
import { HISTORY_EVIDENCE, SINCE, completeHistory, modelHistoryShip, unreadableHistory, waitingHistory } from './runnerHistoryFixtures.js'

// the history transition through the component itself (legacy-replay-upgrade
// ruling 01): its hooks run in a small runtime and it renders the element
// tree. Its ci API is a model of the ship's transition contract. It is
// driven the way the owner does: inspect the paused runner, confirm,
// acknowledge, transition. The ship records the command and names the
// epoch; the runner's answer and its report come back through the ship.

async function mount(options = {}, { onChanged } = {}) {
  const ship = modelHistoryShip(options)
  const schedule = manualSchedule()
  const rt = hooksRuntime()
  const Recovery = makeRunnerRecovery(rt.React, { ci: ship, now: () => NOW, schedule, pollEvery: 3000 })
  rt.mount(Recovery, { runner: { id: RUNNER }, onClose() {}, onChanged })
  await settle()
  return { ship, schedule, rt, tree: () => rt.tree() }
}

const click = async (node) => {
  assert.ok(node, 'the element to click is not rendered')
  node.props.onClick()
  await settle()
}

async function toTransition(m) {
  await click(part(m.tree(), 'open-transition'))
  part(m.tree(), 'transition-acknowledge').props.onChange({ target: { checked: true } })
  await settle()
}

const historyState = (m) => part(m.tree(), 'history')?.props['data-state']
const commandLine = (m) => part(part(m.tree(), 'history'), 'history-command')

test('the whole path: inspected, confirmed; the post is exactly the inspected binding; queued, pending, transitioned — the runner shown waiting until its own answer, and the panel reading until its report shows the epoch', async () => {
  let changed = 0
  const m = await mount({}, { onChanged: () => changed++ })
  assert.equal(historyState(m), 'waiting')
  assert.match(text(m.tree()), /Execution paused/)
  await toTransition(m)
  assert.match(text(part(m.tree(), 'transition-restated')), /authorization epoch 1/)
  assert.equal(part(m.tree(), 'transition').props.disabled, false)
  await click(part(m.tree(), 'transition'))
  assert.deepEqual(m.ship.posts, [{ action: 'request-history-transition', id: RUNNER, revision: SINCE, evidence: HISTORY_EVIDENCE }], 'THE POSTED TRANSITION IS NOT THE INSPECTED BINDING')
  assert.equal(m.ship.commands[0].evidence, `epoch 1 history ${HISTORY_EVIDENCE}`)
  assert.equal(changed, 1)
  assert.equal(part(m.tree(), 'transition-confirmation'), null)
  assert.match(text(part(m.tree(), 'notice')), /The runner keeps waiting until it answers/)
  assert.equal(commandLine(m).props['data-state'], 'queued', 'THE SHIP\'S RECEIPT WAS NOT SHOWN AS QUEUED')
  assert.equal(historyState(m), 'waiting', 'A RUNNER WAS SHOWN TRANSITIONED ON THE SHIP\'S RECEIPT')
  assert.equal(part(m.tree(), 'open-transition'), null, 'A SECOND TRANSITION WAS OFFERED WHILE ONE IS OPEN')
  assert.equal(m.schedule.pending(), 1, 'THE PANEL DOES NOT READ THE SHIP AGAIN WHILE A TRANSITION IS OPEN')
  m.ship.deliver()
  m.schedule.run()
  await settle()
  assert.equal(commandLine(m).props['data-state'], 'pending')
  assert.equal(historyState(m), 'waiting')
  m.ship.answerHistory('completed', 'recorded the transition to authorization epoch 1: this runner refuses every assignment its ship signed before it, and runs new work again; its retentions stay withheld (capacity 2)')
  m.schedule.run()
  await settle()
  assert.equal(commandLine(m).props['data-state'], 'completed')
  assert.equal(historyState(m), 'transitioned')
  assert.equal(part(m.tree(), 'open-transition'), null, 'A SECOND TRANSITION WAS OFFERED BEFORE THE RUNNER\'S REPORT CAME')
  assert.equal(m.schedule.pending(), 1, 'THE PANEL STOPPED READING BEFORE THE TRANSITION WAS REPORTED')
  m.ship.reportAfter()
  m.schedule.run()
  await settle()
  assert.equal(historyState(m), 'transitioned')
  assert.match(text(part(m.tree(), 'history-facts')), /Transition.*epoch 1/)
  assert.doesNotMatch(text(m.tree()), /Execution paused/)
  assert.equal(m.schedule.pending(), 0, 'THE PANEL KEPT READING AFTER THE TRANSITION WAS REPORTED')
  assert.equal(m.ship.posts.length, 1)
  m.rt.unmount()
})

test('a double click posts one transition', async () => {
  const m = await mount()
  await toTransition(m)
  const button = part(m.tree(), 'transition')
  button.props.onClick()
  button.props.onClick() // the same render's button, clicked again before it re-rendered
  await settle()
  assert.equal(m.ship.posts.length, 1, 'A DOUBLE CLICK POSTED TWO TRANSITIONS')
  assert.equal(m.ship.commands.length, 1)
})

test('the ship\'s refusal is shown in its own words, and nothing is recorded: a stale confirmation, and an actor who is not the owner', async () => {
  const m = await mount()
  await toTransition(m)
  // the runner restarted on another history after the panel read it
  m.ship.history = waitingHistory({ evidence: 'f'.repeat(64) })
  await click(part(m.tree(), 'transition'))
  assert.equal(m.ship.commands.length, 0)
  assert.equal(text(part(m.tree(), 'post-error')), 'the history evidence changed since it was inspected: inspect it again', 'THE SHIP\'S REFUSAL WAS NOT SHOWN IN ITS OWN WORDS')
  assert.match(text(part(m.tree(), 'transition-stale')), /evidence changed since you inspected it/)
  assert.equal(part(m.tree(), 'transition').props.disabled, true)
  const other = await mount({ owner: false })
  await toTransition(other)
  await click(part(other.tree(), 'transition'))
  assert.equal(other.ship.commands.length, 0, 'A TRANSITION WAS RECORDED FOR AN ACTOR WHO IS NOT THE OWNER')
  assert.equal(text(part(other.tree(), 'post-error')), 'only the ship\'s owner confirms a runner\'s history transition')
  assert.equal(historyState(other), 'waiting')
})

test('a lost reply is not a success: the panel says it does not know, reads the ship, and shows the command the ship recorded', async () => {
  const m = await mount()
  await toTransition(m)
  m.ship.loseNext = true
  await click(part(m.tree(), 'transition'))
  assert.equal(m.ship.commands.length, 1)
  assert.match(text(part(m.tree(), 'notice')), /may or may not have reached the ship/, 'A LOST TRANSITION REPLY WAS NOT SAID TO BE UNKNOWN')
  assert.equal(commandLine(m).props['data-state'], 'queued')
  assert.equal(historyState(m), 'waiting')
  assert.equal(part(m.tree(), 'open-transition'), null)
})

test('the runner\'s refusal and its doubt come back through the ship: it keeps waiting and runs nothing; after a refusal a new transition can be confirmed, at the next epoch', async () => {
  const m = await mount()
  await toTransition(m)
  await click(part(m.tree(), 'transition'))
  m.ship.deliver()
  m.ship.answerHistory('uncertain', 'its transition may or may not be recorded (sync: input/output error): this runner keeps waiting, runs nothing, and the answer follows once the state file is durable again')
  m.schedule.run()
  await settle()
  assert.equal(commandLine(m).props['data-state'], 'uncertain')
  assert.match(text(commandLine(m)), /keeps waiting and runs nothing/)
  assert.equal(historyState(m), 'waiting', 'AN UNCERTAIN TRANSITION WAS SHOWN DONE')
  assert.equal(part(m.tree(), 'open-transition'), null, 'A SECOND TRANSITION WAS OFFERED WHILE ONE IS UNCERTAIN')
  assert.equal(m.schedule.pending(), 1)
  m.ship.answerHistory('refused', 'not applied: its outcome was uncertain, and it was not recorded when the state file was durable again; this runner keeps waiting')
  m.schedule.run()
  await settle()
  assert.equal(commandLine(m).props['data-state'], 'refused')
  assert.match(text(commandLine(m)), /The runner keeps waiting, and runs nothing/)
  assert.equal(historyState(m), 'waiting')
  assert.equal(m.schedule.pending(), 0)
  await toTransition(m)
  assert.match(text(part(m.tree(), 'transition-restated')), /authorization epoch 2/, 'THE NEXT TRANSITION DOES NOT NAME THE NEXT EPOCH')
  await click(part(m.tree(), 'transition'))
  assert.equal(m.ship.commands.length, 2)
  assert.equal(m.ship.commands[1].evidence, `epoch 2 history ${HISTORY_EVIDENCE}`)
})

test('a runner whose history cannot be read is transitioned the same way, bound to its own evidence', async () => {
  const m = await mount({ history: unreadableHistory() })
  assert.equal(historyState(m), 'waiting')
  await toTransition(m)
  await click(part(m.tree(), 'transition'))
  assert.deepEqual(m.ship.posts, [{ action: 'request-history-transition', id: RUNNER, revision: 0, evidence: 'd'.repeat(64) }])
})

test('a complete runner is offered no transition, and a stale handler posts nothing', async () => {
  const m = await mount({ history: completeHistory() })
  assert.equal(historyState(m), 'complete')
  assert.equal(part(m.tree(), 'open-transition'), null)
  assert.equal(part(m.tree(), 'transition'), null)
  assert.equal(m.ship.posts.length, 0)
  assert.equal(parts(m.tree(), 'retention').length, 0)
})
