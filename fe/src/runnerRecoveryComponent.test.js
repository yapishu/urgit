import test from 'node:test'
import assert from 'node:assert/strict'
import { makeRunnerRecovery } from './runnerRecoveryComponent.js'
import { EVIDENCE, NOW, RUNNER, hooksRuntime, legacyEntry, manualSchedule, modelShip, part, parts, settle, text, unmetEntry } from './runnerRecoveryFixtures.js'

// the legacy recovery component itself (legacy-recovery UI ruling 01): its
// hooks run in a small runtime and it renders the element tree. Its ci API
// is a model of the ship's contract. It is driven the way an operator does:
// list, select, inspect, confirm, acknowledge, release. The ship records the
// command, and the runner's answer comes back through the ship.

async function mount(retentions, { onChanged } = {}) {
  const ship = modelShip(retentions)
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

// the operator's path to the confirmation of the only retention
async function toConfirmation(m) {
  await click(parts(m.tree(), 'retention')[0])
  await click(part(m.tree(), 'open-confirm'))
  part(m.tree(), 'acknowledge').props.onChange({ target: { checked: true } })
  await settle()
}

test('the whole path: listed, inspected, confirmed; the post is exactly the inspected binding; queued, then pending, then released — each shown as it is, the slot reported returned only on the runner\'s answer', async () => {
  let changed = 0
  const m = await mount([legacyEntry()], { onChanged: () => changed++ })
  assert.equal(m.ship.reads, 1)
  assert.equal(parts(m.tree(), 'retention').length, 1)
  await toConfirmation(m)
  assert.equal(part(m.tree(), 'release').props.disabled, false)
  await click(part(m.tree(), 'release'))
  assert.deepEqual(m.ship.posts, [{ action: 'request-legacy-release', id: RUNNER, selection: legacyEntry().selection, revision: 1, evidence: EVIDENCE }], 'THE POSTED ACTION IS NOT THE INSPECTED BINDING')
  assert.equal(changed, 1)
  assert.equal(part(m.tree(), 'confirmation'), null)
  assert.match(text(part(m.tree(), 'notice')), /Nothing is released until the runner answers/)
  const queued = part(part(m.tree(), 'inspection'), 'command-state')
  assert.equal(queued.props['data-state'], 'queued', 'THE SHIP\'S RECEIPT WAS NOT SHOWN AS QUEUED')
  assert.equal(parts(m.tree(), 'retention').length, 1, 'A RETENTION WAS SHOWN RELEASED ON THE SHIP\'S RECEIPT')
  // while the command is open the panel reads the ship again
  assert.equal(m.schedule.pending(), 1, 'THE PANEL DOES NOT READ THE SHIP AGAIN WHILE A COMMAND IS OPEN')
  m.ship.deliver()
  m.schedule.run()
  await settle()
  assert.equal(part(part(m.tree(), 'inspection'), 'command-state').props['data-state'], 'pending')
  m.ship.answer('completed', 'released ci-0v4.att (owner/repo · ci.yml · build) from Urgit\'s command: its slot returns; advertised capacity now 2')
  m.schedule.run()
  await settle()
  assert.equal(parts(m.tree(), 'retention').length, 0)
  const history = parts(m.tree(), 'command')
  assert.equal(history.length, 1)
  assert.equal(part(history[0], 'command-state').props['data-state'], 'completed')
  assert.match(text(history[0]), /advertised capacity now 2/)
  assert.equal(m.schedule.pending(), 0, 'THE PANEL KEPT READING AFTER THE LAST COMMAND CLOSED')
  m.rt.unmount()
})

test('a double click posts one request', async () => {
  const m = await mount([legacyEntry()])
  await toConfirmation(m)
  const release = part(m.tree(), 'release')
  release.props.onClick()
  release.props.onClick() // the same render's button, clicked again before it re-rendered
  await settle()
  assert.equal(m.ship.posts.length, 1, 'A DOUBLE CLICK POSTED TWICE')
  assert.equal(m.ship.commands.length, 1)
})

test('the ship\'s refusal is shown in its own words, and nothing is recorded', async () => {
  const m = await mount([legacyEntry()])
  await toConfirmation(m)
  // the runner's latest report changed after the panel read it
  m.ship.retentions = [legacyEntry({ evidence: 'b'.repeat(64) })]
  await click(part(m.tree(), 'release'))
  assert.equal(m.ship.posts.length, 1)
  assert.equal(m.ship.commands.length, 0)
  const tree = m.tree()
  // the ship's own words; the panel read it again, and the binding is stale
  assert.equal(text(part(tree, 'post-error')), 'the evidence changed since it was inspected: inspect it again', 'THE SHIP\'S REFUSAL WAS NOT SHOWN IN ITS OWN WORDS')
  assert.match(text(part(tree, 'stale')), /evidence changed since you inspected it/)
  assert.equal(part(tree, 'release').props.disabled, true)
  assert.equal(part(tree, 'command-state'), null, 'A REFUSED REQUEST WAS SHOWN AS A COMMAND')
})

test('a lost reply is not a success: the panel says it does not know, reads the ship, and shows the command the ship recorded', async () => {
  const m = await mount([legacyEntry()])
  await toConfirmation(m)
  m.ship.loseNext = true
  await click(part(m.tree(), 'release'))
  assert.equal(m.ship.commands.length, 1)
  assert.match(text(part(m.tree(), 'notice')), /may or may not have reached the ship/, 'A LOST REPLY WAS NOT SAID TO BE UNKNOWN')
  assert.equal(part(part(m.tree(), 'inspection'), 'command-state').props['data-state'], 'queued', 'THE COMMAND THE SHIP RECORDED WAS NOT SHOWN AFTER A LOST REPLY')
  assert.equal(part(m.tree(), 'open-confirm'), null, 'A SECOND RELEASE WAS OFFERED WHILE THE FIRST MAY BE OPEN')
})

test('the runner\'s refusal comes back through the ship: refused, the slot stays withheld, and a new release can be confirmed', async () => {
  const m = await mount([legacyEntry()])
  await toConfirmation(m)
  await click(part(m.tree(), 'release'))
  m.ship.deliver()
  m.ship.answer('refused', 'its release is not proven now: attempt: the launcher holds t-4 (quarantined) of attempt 0v4.att')
  m.schedule.run()
  await settle()
  const line = part(part(m.tree(), 'inspection'), 'command-state')
  assert.equal(line.props['data-state'], 'refused')
  assert.match(text(line), /the launcher holds t-4.*The slot stays withheld/)
  assert.equal(parts(m.tree(), 'retention').length, 1)
  assert.ok(part(m.tree(), 'open-confirm'))
})

test('a retention without its proof offers no release, and posts nothing', async () => {
  const m = await mount([unmetEntry('inventory')])
  await click(parts(m.tree(), 'retention')[0])
  assert.equal(part(m.tree(), 'open-confirm'), null)
  // a stale handler cannot post either: no confirmation is open
  assert.equal(part(m.tree(), 'release'), null)
  assert.equal(m.ship.posts.length, 0)
})

test('a read that fails is said, and nothing is offered', async () => {
  const ship = modelShip([legacyEntry()])
  ship.failReads = true
  const rt = hooksRuntime()
  const Recovery = makeRunnerRecovery(rt.React, { ci: ship, now: () => NOW, schedule: manualSchedule() })
  rt.mount(Recovery, { runner: { id: RUNNER }, onClose() {} })
  await settle()
  assert.match(text(part(rt.tree(), 'load-error')), /Retentions unavailable: Failed to fetch/)
  assert.equal(parts(rt.tree(), 'retention').length, 0)
})
