import test from 'node:test'
import assert from 'node:assert/strict'
import { makeCiRecovery } from './ciRecoveryComponent.js'
import { renderCiRecovery } from './ciRecoveryView.js'
import { recoveryReducer, initialRecoveryView } from './ciRecovery.js'
import { FIRST, NOW, STAGED, checkpoint, modelShip, staged, viewOf } from './ciRecoveryFixtures.js'
import { h, hooksRuntime, manualSchedule, part, parts, settle, text } from './runnerRecoveryFixtures.js'

// Settings → CI recovery (CI-RECOVERY-1), the component itself: its hooks
// run in a small runtime and it renders the element tree. Its ci API is a
// MODEL of the ship's contract (ciRecoveryFixtures.js), never the
// controller. It is driven the way an operator does: read, pause, import,
// review, apply, resume, checkpoint now.

async function mount(view, setup = () => {}) {
  const ship = modelShip(view)
  setup(ship)
  const schedule = manualSchedule()
  const rt = hooksRuntime()
  const Recovery = makeCiRecovery(rt.React, { ci: ship, now: () => NOW, schedule, pollEvery: 3000 })
  rt.mount(Recovery, {})
  await settle()
  return { ship, schedule, rt, tree: () => rt.tree() }
}

const click = async (node) => {
  assert.ok(node, 'the element to click is not rendered')
  assert.ok(!node.props.disabled, 'the element to click is disabled')
  node.props.onClick()
  await settle()
}

const type = async (node, value) => {
  assert.ok(node, 'the field is not rendered')
  node.props.onChange({ target: { value } })
  await settle()
}

test('the whole drill: pause with a reason, import, review the manifest and diff, apply the reviewed id, resume', async () => {
  const m = await mount(viewOf())
  assert.equal(m.ship.reads, 1)
  assert.equal(part(m.tree(), 'ci-state').props.className, 'status good')
  // the import waits for the pause, and says so
  assert.equal(part(m.tree(), 'import').props.disabled, true)
  assert.match(text(part(m.tree(), 'import-blocked')), /Pause CI first/)
  await type(part(m.tree(), 'pause-reason'), 'a restore drill')
  await click(part(m.tree(), 'pause'))
  assert.deepEqual(m.ship.posts.at(-1), { action: 'pause-ci', reason: 'a restore drill' })
  const banner = part(m.tree(), 'paused-banner')
  assert.ok(banner, 'PAUSING IS NOT VISIBLE')
  assert.match(text(banner), /CI is paused for a restore/)
  assert.match(text(banner), /No run is admitted, no runner is offered work, no schedule admits a run and nothing lands/)
  assert.match(text(banner), /Reason: a restore drill/)
  assert.equal(part(m.tree(), 'ci-state').props.className, 'status bad')
  assert.equal(part(m.tree(), 'pause'), null)
  assert.ok(part(m.tree(), 'resume'))
  // import the tip, then review
  await click(part(m.tree(), 'import'))
  assert.deepEqual(m.ship.posts.at(-1), { action: 'import-checkpoint' })
  const stagedNode = part(m.tree(), 'staged')
  assert.equal(stagedNode.props['data-id'], STAGED)
  assert.equal(parts(stagedNode, 'manifest-section').length, 8)
  assert.match(text(part(stagedNode, 'manifest')), /urgit, revision 42/)
  assert.match(text(part(stagedNode, 'excluded')), /credential values/)
  const lines = parts(stagedNode, 'diff-line')
  assert.equal(lines.length, staged().diff.length)
  assert.ok(lines.some((l) => l.props['data-kind'] === 'add' && /grants environment-approver \(prod\) for ~bud/.test(text(l))), 'A GRANT IS NOT ITS OWN LINE')
  assert.ok(lines.some((l) => /needs re-entry/.test(text(l))))
  // apply only after the confirmation is acknowledged
  assert.equal(part(m.tree(), 'apply'), null, 'Apply is offered before its confirmation')
  await click(part(m.tree(), 'open-apply'))
  const confirm = part(m.tree(), 'apply-confirm')
  assert.equal(confirm.props.role, 'alertdialog')
  assert.match(text(confirm), /Credential references come back with no value and need re-entry/)
  assert.match(text(confirm), /This ship keeps its own signing key/)
  assert.match(text(confirm), /Nothing runs until you resume CI/)
  assert.equal(part(m.tree(), 'apply').props.disabled, true, 'APPLY IS PRESSABLE BEFORE THE ACKNOWLEDGEMENT')
  part(m.tree(), 'apply-acknowledge').props.onChange({ target: { checked: true } })
  await settle()
  await click(part(m.tree(), 'apply'))
  assert.deepEqual(m.ship.posts.at(-1), { action: 'apply-checkpoint', checkpoint: STAGED }, 'THE APPLY DOES NOT NAME THE REVIEWED CHECKPOINT')
  assert.equal(part(m.tree(), 'staged'), null)
  assert.match(text(part(m.tree(), 'notice')), /CI stays paused until you resume it/)
  assert.ok(part(m.tree(), 'paused-banner'), 'an apply never resumes CI')
  // what the restore brought back is listed to act on
  assert.match(text(part(m.tree(), 'reentry')), /DEPLOY_KEY/)
  assert.match(text(part(m.tree(), 're-enroll')), /0v1\.daemn/)
  assert.match(text(part(m.tree(), 'restore-skipped')), /refs\/heads\/release/)
  // resume is its own action
  await click(part(m.tree(), 'resume'))
  assert.deepEqual(m.ship.posts.at(-1), { action: 'resume-ci' })
  assert.equal(part(m.tree(), 'paused-banner'), null)
  assert.deepEqual(m.ship.posts.map((p) => p.action), ['pause-ci', 'import-checkpoint', 'apply-checkpoint', 'resume-ci'])
  m.rt.unmount()
})

test('the last checkpoint shows "written" and "replica" apart: written with a failed push is a failed backup', async () => {
  const failed = checkpoint({ replica: { state: 'failed', at: NOW - 1, route: 'GitHub owner/backup', reason: 'GitHub rejected the branch update' } })
  const m = await mount(viewOf({ checkpoints: [failed] }))
  const last = part(m.tree(), 'last-checkpoint')
  assert.equal(last.props['data-id'], FIRST)
  const written = part(last, 'written-fact')
  const replica = part(last, 'replica-fact')
  assert.ok(written && replica, 'THE TWO FACTS ARE NOT SHOWN SEPARATELY')
  assert.equal(written.props['data-state'], 'written')
  assert.equal(written.props['data-tone'], 'good')
  assert.equal(replica.props['data-state'], 'failed')
  assert.equal(replica.props['data-tone'], 'bad', 'A FAILED PUSH IS SHOWN AS A WARNING')
  assert.match(text(replica), /Backup: Backup failed/)
  assert.match(text(replica), /GitHub rejected the branch update/)
  m.rt.unmount()
})

test('checkpoint now: written, then pushed, then confirmed, each read from the ship; the reads stop after', async () => {
  const m = await mount(viewOf())
  await click(part(m.tree(), 'checkpoint-now'))
  assert.deepEqual(m.ship.posts, [{ action: 'checkpoint-now' }])
  let last = part(m.tree(), 'last-checkpoint')
  assert.equal(part(last, 'written-fact').props['data-state'], 'pending')
  assert.equal(part(last, 'replica-fact').props['data-state'], 'waiting')
  assert.notEqual(part(last, 'replica-fact').props['data-state'], 'confirmed')
  assert.equal(m.schedule.pending(), 1, 'THE SECTION DOES NOT READ THE SHIP AGAIN WHILE A CHECKPOINT IS ON ITS WAY')
  m.ship.written()
  m.schedule.run()
  await settle()
  last = part(m.tree(), 'last-checkpoint')
  assert.equal(part(last, 'written-fact').props['data-state'], 'written')
  assert.equal(part(last, 'replica-fact').props['data-state'], 'pushing', 'written is not confirmed')
  m.ship.pushFailed('no answer from the push path within fifteen minutes: the replica is not confirmed')
  m.schedule.run()
  await settle()
  last = part(m.tree(), 'last-checkpoint')
  assert.equal(part(last, 'replica-fact').props['data-tone'], 'bad')
  assert.equal(part(last, 'written-fact').props['data-state'], 'written', 'a failed backup leaves the checkpoint written')
  assert.equal(m.schedule.pending(), 0, 'THE SECTION KEPT READING AFTER THE PUSH ANSWERED')
  m.rt.unmount()
})

test('every refusal is the ship\'s own words, and a corrupt checkpoint stages nothing', async () => {
  const m = await mount(viewOf({ paused: { at: NOW - 5, actor: '~zod', reason: 'drill' } }), (ship) => { ship.corrupt = true })
  await click(part(m.tree(), 'import'))
  assert.match(text(part(m.tree(), 'refusal')), /^The ship refused: corrupt checkpoint: the sha-256 of policy\.json is not the one its manifest lists$/)
  assert.equal(part(m.tree(), 'staged'), null, 'A REFUSED IMPORT STAGED SOMETHING')
  assert.equal(m.ship.view.staged, null)
  m.rt.unmount()
})

test('apply is not offered while unpaused or while an attempt runs, and says why', async () => {
  const unpaused = await mount(viewOf({ staged: staged() }))
  assert.equal(part(unpaused.tree(), 'open-apply').props.disabled, true)
  assert.match(text(part(unpaused.tree(), 'apply-blocked')), /Pause CI first\. An apply to a running CI is refused\./)
  unpaused.rt.unmount()
  const busy = await mount(viewOf({ staged: staged(), paused: { at: NOW, actor: '~zod', reason: 'x' }, running: 1 }))
  assert.equal(part(busy.tree(), 'open-apply').props.disabled, true)
  assert.match(text(part(busy.tree(), 'apply-blocked')), /1 attempt is still running/)
  busy.rt.unmount()
})

test('a double click posts one action', async () => {
  const m = await mount(viewOf())
  const pause = part(m.tree(), 'pause')
  pause.props.onClick()
  pause.props.onClick() // the same render's button, clicked again before it re-rendered
  await settle()
  assert.equal(m.ship.posts.length, 1, 'A DOUBLE CLICK POSTED TWICE')
  m.rt.unmount()
})

test('a lost answer is said to be lost and the ship is read again, never taken for a success', async () => {
  const m = await mount(viewOf(), (ship) => { ship.loseNext = true })
  const before = m.ship.reads
  await click(part(m.tree(), 'pause'))
  assert.match(text(part(m.tree(), 'refusal')), /No answer came from the ship/)
  assert.equal(m.ship.reads, before + 1)
  // the ship did record it: the reread shows the pause
  assert.ok(part(m.tree(), 'paused-banner'))
  m.rt.unmount()
})

test('permission: a viewer the ship does not grant sees the state and no control', async () => {
  const m = await mount(viewOf({ authority: { manage: false }, paused: { at: NOW, actor: '~zod', reason: 'drill' }, staged: staged() }))
  assert.ok(part(m.tree(), 'no-authority'))
  for (const name of ['checkpoint-now', 'pause', 'resume', 'import', 'import-commit', 'open-apply', 'apply', 'discard']) {
    assert.equal(part(m.tree(), name), null, `${name} IS OFFERED WITHOUT AUTHORITY`)
  }
  assert.ok(part(m.tree(), 'paused-banner'), 'the pause is still visible')
  assert.ok(part(m.tree(), 'diff'), 'the diff is still readable')
  m.rt.unmount()
})

test('permission: a session the ship refuses (401) gets the owner\'s message and no control', async () => {
  const m = await mount(viewOf(), (ship) => { ship.deny = true })
  assert.match(text(part(m.tree(), 'no-authority')), /belongs to the ship's owner/)
  assert.equal(part(m.tree(), 'load-error'), null)
  for (const name of ['checkpoint-now', 'pause', 'import']) assert.equal(part(m.tree(), name), null)
  m.rt.unmount()
})

test('the repository line names the replica, or says plainly that there is none', () => {
  const render = (view) => renderCiRecovery(h, { state: recoveryReducer(initialRecoveryView(), { type: 'loaded', view }), now: NOW }, {})
  const confirmed = render(viewOf())
  assert.match(text(part(confirmed, 'replica-route')), /Replica: GitHub owner\/backup\./)
  const none = render(viewOf({ repository: { ...viewOf().repository, replica: null, replicaProblem: 'no replica is configured: ci-checkpoints has no GitHub origin and is no fork of another ship\'s repository. Clone it over Smart HTTP to hold a copy' } }))
  const line = part(none, 'replica-route')
  assert.equal(line.props['data-tone'], 'bad')
  assert.match(text(line), /No replica: no replica is configured/)
  const empty = render(viewOf({ checkpoints: [] }))
  assert.match(text(part(empty, 'no-checkpoint')), /No checkpoint has been written yet/)
})
