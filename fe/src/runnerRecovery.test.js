import test from 'node:test'
import assert from 'node:assert/strict'
import { bindingOf, canRelease, commandState, initialRecoveryState, mayPost, openCommands, recoveryReducer, releaseBody, retentionRows, staleReason } from './runnerRecovery.js'
import { EVIDENCE, NOW, command, legacyEntry, viewOf } from './runnerRecoveryFixtures.js'

// the legacy recovery's model (legacy-recovery UI ruling 01): rows from the
// runner's report, command states, the bound action body, the reducer

test('a row carries the retention as reported, what the ship knows of its attempt, and its latest command', () => {
  const view = viewOf([legacyEntry(), legacyEntry({ selection: 'ci-0v6.x/microvm/t-6/i/3/3//1700000001/0', handle: 'ci-0v6.x', attempt: '0v6.x', kind: 'vm', release: 'cli', eligible: false, evidence: '', conditions: undefined, legacy: null, label: '' })], [command('refused', { detail: 'the evidence changed' })])
  const [legacy, vm] = retentionRows(view, NOW)
  assert.equal(legacy.kind, 'legacy')
  assert.equal(legacy.context.status, 'failed')
  assert.equal(legacy.conditions.length, 6)
  assert.equal(legacy.command.id, '0v5.cmd')
  assert.equal(legacy.commandState.state, 'refused')
  assert.equal(vm.labelText, 'no job label recorded')
  assert.equal(vm.commandState, null)
  assert.match(vm.releaseText, /urgit-runner -recover/)
})

test('a command reads completed only on the runner\'s answer: the ship\'s receipt is queued, delivery is pending, and a queued command past its time is expired', () => {
  assert.equal(commandState(command('queued'), NOW).state, 'queued', 'A RECEIPT WAS READ AS MORE THAN QUEUED')
  assert.equal(commandState(command('queued'), NOW).open, true)
  assert.equal(commandState(command('delivered'), NOW).state, 'pending', 'A DELIVERY WAS READ AS A RESULT')
  assert.equal(commandState(command('uncertain'), NOW).state, 'uncertain')
  assert.equal(commandState(command('uncertain'), NOW).open, true, 'AN UNCERTAIN RELEASE WAS TAKEN FOR A FINAL ONE')
  assert.equal(commandState(command('completed'), NOW).state, 'completed')
  assert.equal(commandState(command('refused'), NOW).open, false)
  assert.equal(commandState(command('queued', { expires: NOW - 1 }), NOW).state, 'expired', 'A QUEUED COMMAND PAST ITS TIME WAS NOT READ EXPIRED')
  assert.equal(commandState(command('something-new'), NOW).state, 'unknown', 'AN UNKNOWN ANSWER WAS TAKEN FOR A RESULT')
  assert.equal(commandState(command('something-new'), NOW).open, true)
  for (const status of ['queued', 'delivered', 'uncertain', 'expired', 'refused', 'something-new']) {
    assert.notEqual(commandState(command(status), NOW).state, 'completed', `A ${status.toUpperCase()} COMMAND WAS READ AS COMPLETED`)
  }
  assert.equal(openCommands(viewOf([legacyEntry()], [command('delivered')]), NOW), true)
  assert.equal(openCommands(viewOf([legacyEntry()], [command('completed')]), NOW), false)
})

test('a release is offered only for a legacy retention reported releasable, with a digest, and no command of it open', () => {
  const row = (entry, cmds = []) => retentionRows(viewOf([entry], cmds), NOW)[0]
  assert.equal(canRelease(row(legacyEntry())), true)
  assert.equal(canRelease(row(legacyEntry({ eligible: false }))), false, 'AN INELIGIBLE RETENTION WAS OFFERED A RELEASE')
  assert.equal(canRelease(row(legacyEntry({ kind: 'vm' }))), false, 'A RETENTION OF ANOTHER KIND WAS OFFERED A RELEASE')
  assert.equal(canRelease(row(legacyEntry({ evidence: '' }))), false, 'A RELEASE WITHOUT EVIDENCE TO BIND WAS OFFERED')
  assert.equal(canRelease(row(legacyEntry({ evidence: 'z'.repeat(64) }))), false)
  assert.equal(canRelease(row(legacyEntry(), [command('queued')])), false, 'A SECOND RELEASE WAS OFFERED WHILE ONE IS OPEN')
  assert.equal(canRelease(row(legacyEntry(), [command('refused')])), true)
})

test('the action body is the binding exactly as inspected: the entry, its revision and its evidence — nothing recomputed from a later report', () => {
  const view = viewOf([legacyEntry()])
  const binding = bindingOf(retentionRows(view, NOW)[0], NOW)
  const body = releaseBody('0v1.daemon', binding)
  assert.deepEqual(body, { action: 'request-legacy-release', id: '0v1.daemon', selection: legacyEntry().selection, revision: 1, evidence: EVIDENCE }, 'THE ACTION BODY IS NOT THE INSPECTED BINDING')
  assert.deepEqual(Object.keys(body).sort(), ['action', 'evidence', 'id', 'revision', 'selection'])
})

test('a binding goes stale when the runner reports its entry changed, its evidence changed, or gone, or a command of it opened', () => {
  const view = viewOf([legacyEntry()])
  const binding = bindingOf(retentionRows(view, NOW)[0], NOW)
  assert.equal(staleReason(binding, view, NOW), '')
  assert.match(staleReason(binding, viewOf([legacyEntry({ revision: 2, selection: legacyEntry().selection })]), NOW), /changed since you inspected/, 'A CHANGED REVISION WAS NOT STALE')
  assert.match(staleReason(binding, viewOf([legacyEntry({ evidence: 'b'.repeat(64) })]), NOW), /evidence changed/, 'CHANGED EVIDENCE WAS NOT STALE')
  assert.match(staleReason(binding, viewOf([]), NOW), /no longer reports/, 'A GONE ENTRY WAS NOT STALE')
  assert.match(staleReason(binding, viewOf([legacyEntry()], [command('delivered')]), NOW), /already open/)
  assert.match(staleReason(binding, viewOf([legacyEntry({ eligible: false })]), NOW), /no longer reports this retention as releasable/)
})

test('the reducer: a confirmation opens only on a releasable selection, needs its acknowledgment, posts once, and a lost post is not a success', () => {
  let s = recoveryReducer(initialRecoveryState(), { type: 'loaded', view: viewOf([legacyEntry(), legacyEntry({ selection: 's2/x', handle: 'ci-0v7', kind: 'admission', eligible: false, evidence: '' })]) })
  s = recoveryReducer(s, { type: 'select', selection: 's2/x' })
  s = recoveryReducer(s, { type: 'confirm-open', now: NOW })
  assert.equal(s.confirming, null, 'A CONFIRMATION OPENED FOR A RETENTION NOT RELEASABLE')
  s = recoveryReducer(s, { type: 'select', selection: legacyEntry().selection })
  s = recoveryReducer(s, { type: 'confirm-open', now: NOW })
  assert.equal(s.confirming.selection, legacyEntry().selection)
  assert.equal(mayPost(s, NOW), false, 'A CONFIRMATION MAY BE POSTED WITHOUT ITS ACKNOWLEDGMENT')
  s = recoveryReducer(s, { type: 'acknowledge', value: true })
  assert.equal(mayPost(s, NOW), true)
  // a later report changes the entry: the confirmation no longer holds
  const stale = recoveryReducer(s, { type: 'loaded', view: viewOf([legacyEntry({ evidence: 'b'.repeat(64) })]) })
  assert.equal(mayPost(stale, NOW), false, 'A STALE CONFIRMATION MAY BE POSTED')
  s = recoveryReducer(s, { type: 'post-start' })
  assert.equal(mayPost(s, NOW), false, 'A CONFIRMATION MAY BE POSTED TWICE')
  const refused = recoveryReducer(s, { type: 'post-failed', error: 'the evidence changed since it was inspected: inspect it again', lost: false })
  assert.equal(refused.postError, 'the evidence changed since it was inspected: inspect it again')
  assert.equal(refused.posting, false)
  const lost = recoveryReducer(s, { type: 'post-failed', error: 'Failed to fetch', lost: true })
  assert.match(lost.notice, /may or may not have reached the ship/, 'A LOST POST WAS NOT SAID TO BE UNKNOWN')
  assert.equal(lost.confirming, null)
  const done = recoveryReducer(s, { type: 'post-done' })
  assert.match(done.notice, /Nothing is released until the runner answers/, 'THE SHIP\'S RECEIPT WAS SHOWN AS A RELEASE')
  // selecting another entry leaves no confirmation behind
  const other = recoveryReducer(s, { type: 'select', selection: 's2/x' })
  assert.equal(other.confirming, null)
})
