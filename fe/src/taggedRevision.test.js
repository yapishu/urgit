import test from 'node:test'
import assert from 'node:assert/strict'
import { arm, deskText } from './hoonSource.js'

// Private SOURCE checks. These inspect the real producer path, not a
// running controller. Native admission and upgrade remain parent checks.
const controller = deskText('app/urgit-ci.hoon')

test('a new ordinary tag reaches tagged YAML without any exact-tag promotion', () => {
  const push = arm(controller, 'admit-push')
  const tag = push.indexOf('(admit-tag base u.new.u)')
  assert.ok(tag >= 0, 'ordinary tags still fall through to the exact-tag promotion guard')
  assert.ok(tag < push.indexOf('(governing repo ref.u)'), 'promotion must not gate ordinary tag admission')
  assert.match(push.slice(0, tag), /\(tag-ref:ci-tag ref\.u\)/)
})

test('a release with different YAML cannot borrow the default branch catalog', () => {
  const push = arm(controller, 'admit-push')
  assert.ok(push.includes('(admit-tag base u.new.u)'), 'the tagged revision must have its own admission path')
  const tag = arm(controller, 'admit-tag')
  assert.match(tag, /\(tag-commit repo\.e object\)/, 'peel the event object, never today\'s branch')
  assert.match(tag, /\(cached-lock:ci-tag locks repo\.e p\.peeled\)/)
  assert.doesNotMatch(tag, /\(governing |\(ref-tip |get by baselines/)
})

test('the actual completion binds its exact attempt and the scheduler excludes unresolved tags', () => {
  assert.match(arm(controller, 'handle-lock'), /\(complete-tag-resolve id\.u\.found p\.verdict\)/)
  assert.match(arm(controller, 'complete-tag-resolve'), /\(accepts:ci-resolve state id attempt\)/)
  assert.match(arm(controller, 'schedule'), /advance-tags/)
  assert.match(arm(controller, 'schedule'), /\?\|\(!\(tagged-run candidate\) \(ready:ci-tag candidate\)\)/)
  assert.doesNotMatch(arm(controller, 'advance-tags'), /\(ref-tip |\(governing |cached-lock/)
  assert.match(arm(controller, 'advance-tags'), /\(fail-tag c why\.decision\)/)
  assert.match(arm(controller, 'advance-tags'), /\(bind-attempt:ci-resolve state c -\.made\)/)
})

test('API producers expose tag provenance and filtered runs release their scratch refs', () => {
  assert.match(arm(controller, 'candidate-json'), /workflow-provenance-json candidate/)
  assert.match(arm(controller, 'forge-event-json'), /workflow-provenance-json/)
  assert.match(arm(controller, 'handle-lock'), /\(tag-resolve-releases id\.u\.found\)/)
})

test('cancelled tag resolution updates the recorded event instead of leaving it pending', () => {
  assert.match(arm(controller, 'cancel-run'), /\(note-tag-event c reason\)/)
})

test('authentic tag replay stays deduplicated after the recent event window expires', () => {
  const push = arm(controller, 'admit-push')
  const durable = push.indexOf('(~(has by tag-runs) (sham [%ci-event-run id.u]))')
  assert.ok(durable >= 0 && durable < push.indexOf('(verify-push repo u)'))
  assert.match(arm(controller, 'bind-tag-lock'), /=\(%pending status\.c\).*\?=\(~ selected\.c\)/)
  assert.match(arm(controller, 'on-save'), /!>\(state\)/)
  assert.match(arm(controller, 'on-load'), /!<\(state-0:ci old\)/)
})

test('tag authority is narrow and leaves the promoted and privileged paths guarded', () => {
  const push = arm(controller, 'admit-push')
  assert.ok(push.indexOf('?~  new.u') < push.indexOf('(admit-tag base u.new.u)'))
  assert.ok(push.indexOf('has in ci-protected') < push.indexOf('(admit-tag base u.new.u)'))
  assert.match(push, /\(governing repo ref\.u\)/)
  // the agent lands through lib/ci-concurrency, which its vector reads too
  // (CI-CONCURRENCY-1): the guards are held there
  assert.match(arm(controller, 'landable'), /\(landable:ci-concurrency state c\)/)
  assert.match(arm(controller, 'bindings-current'), /\(bindings-current:ci-concurrency state c\)/)
  assert.match(arm(deskText('lib/ci-concurrency.hoon'), 'landable'), /=\(%required mode\.c\)/)
  assert.match(arm(deskText('lib/ci-concurrency.hoon'), 'bindings-current'), /get by baselines/)
  assert.match(arm(controller, 'assignment-json'), /=\(%required mode\.candidate\)/)
  assert.match(arm(controller, 'sandbox-for'), /!=\(%required mode\.candidate\)/)
  assert.match(arm(controller, 'schedule'), /\?\|\(=\(%trusted trust\.candidate\) \(restricted repo\.candidate\)\)/)
  const actions = arm(controller, 'handle-action')
  const approval = actions.slice(actions.indexOf('      %approve-candidate'), actions.indexOf('      %rerun-candidate'))
  assert.match(approval, /\(approve:ci-resolve state old approved now\.bowl\)/)
  assert.match(approval, /\(twin:ci-resolve old fresh\)/)
  const twin = arm(deskText('lib/ci-resolve.hoon'), 'twin')
  for (const field of ['baseline', 'lock', 'generation', 'incarnation']) {
    assert.ok(twin.includes(`${field}  ${field}.old`), `approval must keep ${field}`)
  }
})

// Wiring only; executable ci-resolve-vector exercises these shared transitions.
test('resolver producer and consumers use the tested authority and lifecycle gates', () => {
  for (const name of ['deliver', 'read-allowed', 'handle-lock', 'handle-upload']) assert.match(arm(controller, name), /active:ci-resolve/)
  assert.match(arm(controller, 'emit'), /sweep:ci-resolve/)
  assert.match(arm(controller, 'cancel-run'), /cancel:ci-resolve/)
  assert.match(arm(controller, 'reoffer-attempt'), /reoffer:ci-resolve/)
  assert.match(arm(controller, 'advance-tags'), /next:ci-resolve/)
  assert.match(arm(controller, 'select-resolver-excluding'), /choose:ci-resolve/)
  assert.match(arm(controller, 'manifest-of'), /purpose:ci-resolve/)
  assert.match(arm(controller, 'manifest-of'), /%tag  'resolve-tag'/)
})
