// Why each negative control is refused: the reason must be the binding the
// fixture breaks (or the form the reader does not read), not some unrelated
// failure that happens to carry the same prefix.
import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { actionArm, arm, entryGuard, routeArm, wireArm } from './hoonSource.js'

const fixture = (rel) => readFileSync(new URL(`fixtures/hoon-reader/${rel}`, import.meta.url), 'utf8')
const tags = '[%apps %urgit %api %repository @ %tags ~]'
const route = (rel) => routeArm(fixture(rel), 'settings-api', 'post-repository-tags', 'POST', tags)
const fine = (rel) => wireArm(fixture(rel), '[%peer %fine @ @ ~]', 'peer-fine')
const message = (fn) => {
  try {
    fn()
  } catch (e) {
    return e.message
  }
  assert.fail('expected a refusal')
}

test('a misleading action entry is refused because the switch that runs sends the tag elsewhere', () => {
  const why = 'handle-action does not dispatch %set-ref to ++set-ref: its switch sends %set-ref to ++wrong'
  for (const rel of ['parent/miswired.hoon', 'parent/miswired-with-unused-decoy.hoon', 'action/literal-decoy.hoon',
    'action/tape-decoy.hoon', 'action/comment-decoy.hoon', 'action/nested-switch-decoy.hoon', 'action/shadowed.hoon']) {
    assert.equal(message(() => actionArm(fixture(rel), 'set-ref')), why, rel)
  }
  assert.equal(message(() => actionArm(fixture('action/exact-other-arm.hoon'), 'set-ref')),
    'handle-action does not dispatch %set-ref to ++set-ref: its switch sends %set-ref to ++delete')
  assert.equal(message(() => actionArm(fixture('action/exact-one-line.hoon'), 'del')),
    'handle-action does not dispatch %del to ++del: its switch sends %del to ++delete')
})

test('a misleading wire case is refused because the case that takes the wire is another', () => {
  const why = 'on-arvo does not dispatch [%peer %fine @ @ ~] to ++peer-fine: its switch sends it to ++other'
  for (const rel of ['wire/shadowed.hoon', 'wire/nested-decoy.hoon', 'wire/literal-decoy.hoon']) {
    assert.equal(message(() => fine(rel)), why, rel)
  }
  assert.equal(message(() => fine('wire/partial.hoon')),
    'on-arvo does not dispatch [%peer %fine @ @ ~] to ++peer-fine: case [%peer %fine %x @ ~] takes only part of what the switch is given')
})

test('a misrouted request is refused where it ends up, and a misplaced guard as no first assertion', () => {
  const prefix = `handle-api does not route POST ${tags} to ++post-repository-tags: `
  const view = 'the request reaches ++view-api, which dispatches no further (the dispatching expression is not a ?- or ?+ switch)'
  assert.equal(message(() => route('route/upper-miswired.hoon')), prefix + view)
  assert.equal(message(() => route('route/default-miswired.hoon')), prefix + view)
  for (const rel of ['route/guard-in-tape.hoon', 'route/guard-in-unused-arm.hoon', 'route/guard-not-first.hoon']) {
    assert.equal(message(() => route(rel)), `${prefix}its first assertion is not that route`, rel)
  }
})

test('a form the reader does not read is refused as that, not misread', () => {
  const prefix = 'handle-action does not dispatch %set-ref to ++set-ref: '
  assert.equal(message(() => actionArm(fixture('unsupported/body-prefix.hoon'), 'set-ref')),
    `${prefix}=/ where a wide expression belongs: a form this reader does not read`)
  assert.equal(message(() => actionArm(fixture('unsupported/wide-switch.hoon'), 'set-ref')),
    `${prefix}the dispatching expression is not a ?- or ?+ switch`)
  assert.equal(message(() => fine('unsupported/union-pattern.hoon')),
    'on-arvo does not dispatch [%peer %fine @ @ ~] to ++peer-fine: a pattern this reader does not read: [%peer ?(%fine %rate) @ @ ~]')
})

test('entryGuard reads only the first assertion, after the cast', () => {
  const routeText = fixture('route/correct.hoon')
  const tagsArm = arm(routeText, 'on-poke/handle-api/settings-api/post-repository-tags')
  assert.deepEqual(entryGuard(tagsArm), { method: 'POST', path: tags })
  assert.deepEqual(entryGuard(arm(fixture('wire/correct.hoon'), 'on-arvo/peer-fine')), { wire: '[%peer %fine @ @ ~]' })
  assert.equal(entryGuard(arm(fixture('route/guard-in-tape.hoon'), 'on-poke/handle-api/settings-api/post-repository-tags')).method, 'GET')
  for (const rel of ['route/guard-in-unused-arm.hoon', 'route/guard-not-first.hoon']) {
    assert.equal(entryGuard(arm(fixture(rel), 'on-poke/handle-api/settings-api/post-repository-tags')), null, rel)
  }
  assert.equal(entryGuard(arm(fixture('parent/correct.hoon'), 'on-poke/handle-action/set-ref')), null)
})
