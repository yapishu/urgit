import test from 'node:test'
import assert from 'node:assert/strict'
import {
  applyBlock,
  canManage,
  commitProblem,
  diffSections,
  importBlock,
  inFlight,
  lostPost,
  noAuthority,
  recoveryActions,
  recoveryReducer,
  initialRecoveryView,
  replicaFact,
  writtenFact,
} from './ciRecovery.js'
import { checkpoint, staged, viewOf } from './ciRecoveryFixtures.js'

// The model of Settings → CI recovery (CI-RECOVERY-1): the action bodies
// the ship parses (app/urgit-ci +parse-web-action), the two separate facts
// of a checkpoint, and when each control is offered.

test('the action bodies are exactly what the ship parses: no actor, no repository, the reviewed id', () => {
  assert.deepEqual(recoveryActions.checkpointNow(), { action: 'checkpoint-now' })
  assert.deepEqual(recoveryActions.pause('  a drill  '), { action: 'pause-ci', reason: 'a drill' })
  assert.deepEqual(recoveryActions.pause(''), { action: 'pause-ci', reason: '' })
  assert.deepEqual(recoveryActions.resume(), { action: 'resume-ci' })
  assert.deepEqual(recoveryActions.importCheckpoint(''), { action: 'import-checkpoint' })
  assert.deepEqual(recoveryActions.importCheckpoint(` ${'c'.repeat(40)} `), { action: 'import-checkpoint', commit: 'c'.repeat(40) })
  assert.deepEqual(recoveryActions.discard(), { action: 'discard-checkpoint' })
  assert.deepEqual(recoveryActions.apply('cp-1'), { action: 'apply-checkpoint', checkpoint: 'cp-1' })
  for (const body of [recoveryActions.checkpointNow(), recoveryActions.pause('x'), recoveryActions.apply('cp-1')]) {
    assert.equal('actor' in body, false, 'the ship takes the actor from the session, never the body')
  }
})

test('"written" and "replica" are two facts: written with a failed push is written and a failed backup', () => {
  const c = checkpoint({ replica: { state: 'failed', at: 1, route: 'GitHub owner/backup', reason: 'GitHub rejected the branch update' } })
  assert.equal(writtenFact(c).state, 'written')
  assert.equal(writtenFact(c).tone, 'good')
  const r = replicaFact(c)
  assert.equal(r.state, 'failed')
  assert.equal(r.label, 'Backup failed')
  assert.equal(r.tone, 'bad', 'A FAILED PUSH WAS NOT SHOWN AS A FAILED BACKUP')
  assert.notEqual(r.tone, 'warn', 'a failed push is never a warning')
  assert.equal(r.detail, 'GitHub rejected the branch update', 'the replica\'s own words')
})

test('only the replica\'s acceptance reads as confirmed: no path, a skipped push and an unknown state do not', () => {
  assert.equal(replicaFact(checkpoint()).label, 'Replica confirmed')
  assert.equal(replicaFact(checkpoint()).tone, 'good')
  const none = replicaFact(checkpoint({ replica: { state: 'unconfigured', reason: 'no replica is configured' } }))
  assert.equal(none.label, 'Replica not confirmed')
  assert.equal(none.tone, 'bad')
  assert.equal(replicaFact(checkpoint({ replica: { state: 'skipped', reason: 'the checkpoint was not written' } })).tone, 'bad')
  assert.equal(replicaFact(checkpoint({ replica: {} })).tone, 'bad', 'an unknown state claims nothing')
  assert.equal(replicaFact(checkpoint({ replica: { state: 'pushing', route: 'GitHub o/r' } })).tone, 'warn')
  for (const state of ['unconfigured', 'skipped', 'failed', 'waiting', 'pushing', 'nonsense']) {
    assert.notEqual(replicaFact(checkpoint({ replica: { state } })).label, 'Replica confirmed', `${state} reads as confirmed`)
  }
})

test('a refused write is not written, in the forge\'s words, and a pending one is writing', () => {
  const refused = writtenFact(checkpoint({ written: { state: 'failed', at: 1, reason: 'the checkpoint branch moved after the checkpoint was built, so nothing was written' } }))
  assert.equal(refused.label, 'Not written')
  assert.equal(refused.tone, 'bad')
  assert.match(refused.detail, /the checkpoint branch moved/)
  assert.equal(writtenFact(checkpoint({ written: { state: 'pending' } })).label, 'Writing')
})

test('the ship reads again while a checkpoint is being written or pushed, and stops after', () => {
  assert.equal(inFlight(viewOf()), false)
  assert.equal(inFlight(viewOf({ checkpoints: [checkpoint({ written: { state: 'pending' }, replica: { state: 'waiting' } })] })), true)
  assert.equal(inFlight(viewOf({ checkpoints: [checkpoint({ replica: { state: 'pushing' } })] })), true)
  assert.equal(inFlight(viewOf({ checkpoints: [checkpoint({ replica: { state: 'failed', reason: 'x' } })] })), false)
})

test('permission: the controls are the ship\'s grant, and a 401 or 403 is no authority', () => {
  assert.equal(canManage(viewOf()), true)
  assert.equal(canManage(viewOf({ authority: { manage: false } })), false)
  assert.equal(canManage(viewOf({ authority: undefined })), false, 'no answer is no grant')
  assert.equal(noAuthority(Object.assign(new Error('session required'), { status: 401 })), true)
  assert.equal(noAuthority(Object.assign(new Error('nope'), { status: 403 })), true)
  assert.equal(noAuthority(Object.assign(new Error('refused'), { status: 409 })), false)
  assert.equal(lostPost(new TypeError('Failed to fetch')), true)
  assert.equal(lostPost(Object.assign(new Error('refused'), { status: 409 })), false)
})

test('import needs the pause, apply needs the pause, a staged checkpoint and no running attempt', () => {
  assert.match(importBlock(viewOf()), /Pause CI first/)
  assert.equal(importBlock(viewOf({ paused: { at: 1, actor: '~zod', reason: 'drill' } })), '')
  assert.match(applyBlock(viewOf({ paused: { at: 1 } })), /Import a checkpoint first/)
  assert.match(applyBlock(viewOf({ staged: staged() })), /Pause CI first/)
  assert.match(applyBlock(viewOf({ staged: staged(), paused: { at: 1 }, running: 2 })), /2 attempts are still running/)
  assert.equal(applyBlock(viewOf({ staged: staged(), paused: { at: 1 }, running: 0 })), '')
})

test('a commit to import from is forty lowercase hex digits, or nothing for the tip', () => {
  assert.equal(commitProblem(''), '')
  assert.equal(commitProblem('a'.repeat(40)), '')
  assert.match(commitProblem('A'.repeat(40)), /40 lowercase hex/)
  assert.match(commitProblem('abc'), /40 lowercase hex/)
})

test('the diff is grouped by section in the ship\'s order, every line kept', () => {
  const groups = diffSections(staged().diff)
  assert.deepEqual(groups.map((g) => g.section), ['policy', 'access', 'credentials', 'runners', 'signing'])
  assert.equal(groups.reduce((n, g) => n + g.lines.length, 0), staged().diff.length)
})

test('the reducer: a pause clears its reason only once accepted, a refusal keeps the ship\'s words, an apply closes its confirmation', () => {
  let s = initialRecoveryView()
  s = recoveryReducer(s, { type: 'loaded', view: viewOf() })
  s = recoveryReducer(s, { type: 'reason', value: 'drill' })
  s = recoveryReducer(s, { type: 'post-start', action: 'pause-ci' })
  assert.equal(s.busy, 'pause-ci')
  s = recoveryReducer(s, { type: 'post-failed', error: 'CI is already paused', lost: false })
  assert.equal(s.refusal, 'CI is already paused')
  assert.equal(s.reason, 'drill', 'a refused pause keeps the reason to retry')
  s = recoveryReducer(s, { type: 'post-done', action: 'pause-ci', notice: 'ok' })
  assert.equal(s.reason, '')
  s = recoveryReducer(s, { type: 'confirm-open' })
  s = recoveryReducer(s, { type: 'acknowledge', value: true })
  assert.equal(s.acknowledged, true)
  s = recoveryReducer(s, { type: 'post-done', action: 'apply-checkpoint' })
  assert.equal(s.confirming, false)
  assert.equal(s.acknowledged, false)
})
