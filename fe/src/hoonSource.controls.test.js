// Negative and positive controls for hoonSource's binding and header readers:
// misleading text in nested unused arms, comments and literals, earlier or
// partial cases, upper hops, guards that are not the arm's first assertion,
// and forms the reader does not read. Every fixture parses with the pinned
// hoon-lint; the parent/ ones are the review's own. These use only the
// reader's original exports, so the same file runs against either revision.
import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { actionArm, arm, armsNamed, enclosingArms, routeArm, type, wireArm } from './hoonSource.js'

const fixture = (rel) => readFileSync(new URL(`fixtures/hoon-reader/${rel}`, import.meta.url), 'utf8')
const tags = '[%apps %urgit %api %repository @ %tags ~]'
const route = (rel) => routeArm(fixture(rel), 'settings-api', 'post-repository-tags', 'POST', tags)
const fine = (rel) => wireArm(fixture(rel), '[%peer %fine @ @ ~]', 'peer-fine')

test("the review's correct dispatch is accepted", () => {
  assert.equal(actionArm(fixture('parent/correct.hoon'), 'set-ref'), '    ++  set-ref\n      0')
})

test("the review's miswired dispatch is refused", () => {
  assert.throws(() => actionArm(fixture('parent/miswired.hoon'), 'set-ref'), /does not dispatch/)
})

test("the review's miswired dispatch beside an unused decoy arm is refused", () => {
  assert.throws(() => actionArm(fixture('parent/miswired-with-unused-decoy.hoon'), 'set-ref'), /does not dispatch/)
})

test('a dispatch entry inside a cord block is not the dispatch', () => {
  assert.throws(() => actionArm(fixture('action/literal-decoy.hoon'), 'set-ref'), /does not dispatch/)
})

test('a dispatch entry inside a tape block is not the dispatch', () => {
  assert.throws(() => actionArm(fixture('action/tape-decoy.hoon'), 'set-ref'), /does not dispatch/)
})

test('a dispatch entry in a comment is not the dispatch', () => {
  assert.throws(() => actionArm(fixture('action/comment-decoy.hoon'), 'set-ref'), /does not dispatch/)
})

test('a switch nested in another case is not the dispatch', () => {
  assert.throws(() => actionArm(fixture('action/nested-switch-decoy.hoon'), 'set-ref'), /does not dispatch/)
})

test('an earlier case that takes the tag decides its dispatch', () => {
  assert.throws(() => actionArm(fixture('action/shadowed.hoon'), 'set-ref'), /does not dispatch/)
})

test('a tall case, and comments between cases, still bind', () => {
  assert.equal(actionArm(fixture('action/tall-entry.hoon'), 'set-ref'), '    ++  set-ref\n      0')
  assert.equal(actionArm(fixture('action/comments-between.hoon'), 'set-ref'), '    ++  set-ref\n      0')
})

test('a wire its case sends to the handler is accepted', () => {
  assert.match(fine('wire/correct.hoon'), /^ {2}\+\+  peer-fine\n/)
})

test('an earlier wire case that takes the wire decides it', () => {
  assert.throws(() => fine('wire/shadowed.hoon'), /does not dispatch/)
})

test('a case that takes only part of the wire is refused', () => {
  assert.throws(() => fine('wire/partial.hoon'), /does not dispatch/)
})

test('a wire case in an unused arm or a literal is not the dispatch', () => {
  assert.throws(() => fine('wire/nested-decoy.hoon'), /does not dispatch/)
  assert.throws(() => fine('wire/literal-decoy.hoon'), /does not dispatch/)
})

test('a route followed from handle-api through every hop is accepted', () => {
  assert.match(route('route/correct.hoon'), /^ {6}\+\+  post-repository-tags\n/)
})

test('a route an upper switch sends elsewhere is refused', () => {
  assert.throws(() => route('route/upper-miswired.hoon'), /does not route/)
})

test('a route its method choice sends elsewhere is refused', () => {
  assert.throws(() => route('route/default-miswired.hoon'), /does not route/)
})

test("a route's guard counts only as its arm's first assertion", () => {
  assert.throws(() => route('route/guard-in-tape.hoon'), /does not route/)
  assert.throws(() => route('route/guard-in-unused-arm.hoon'), /does not route/)
  assert.throws(() => route('route/guard-not-first.hoon'), /does not route/)
})

test('a header or core end inside a cord or tape block is not one', () => {
  for (const rel of ['lexical/ghost-arm.hoon', 'lexical/ghost-in-tape.hoon']) {
    const text = fixture(rel)
    assert.throws(() => arm(text, 'real/ghost'), /missing arm real\/ghost/)
    assert.deepEqual(armsNamed(text, 'ghost'), [])
    assert.deepEqual(enclosingArms(text, text.split('\n').indexOf('  --')), ['real'])
    assert.match(arm(text, 'real'), /\+\+  ghost\n {2}--\n/)
  }
})

test('a header in a comment is not an arm', () => {
  const text = fixture('lexical/ghost-in-comment.hoon')
  assert.throws(() => arm(text, 'real/ghost'), /missing arm real\/ghost/)
  assert.deepEqual(armsNamed(text, 'ghost'), [])
})

test('type reads past a literal that mentions a type', () => {
  const text = fixture('lexical/types.hoon')
  assert.equal(type(text, 'serve'), '+$  serve\n  $:  a=@\n      b=@\n  ==')
  assert.throws(() => type(text, 'ghost'), /missing type ghost/)
  assert.equal(type(text, 'serve-debug'), '+$  serve-debug  @')
})

test('a dispatching body that is more than one switch is refused, not read', () => {
  assert.throws(() => actionArm(fixture('unsupported/body-prefix.hoon'), 'set-ref'), /does not dispatch/)
})

test('a wide-form switch is refused', () => {
  assert.throws(() => actionArm(fixture('unsupported/wide-switch.hoon'), 'set-ref'), /does not dispatch/)
})

test('a case pattern the reader does not read is refused, not skipped', () => {
  assert.throws(() => fine('unsupported/union-pattern.hoon'), /does not dispatch/)
})
