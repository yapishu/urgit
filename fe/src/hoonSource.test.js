import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { actionArm, arm, deskText, enclosingArms, gaps, importClosure, imports, routeArm, type, wireArm } from './hoonSource.js'

const fixture = (rel) => readFileSync(new URL(`fixtures/hoon-reader/${rel}`, import.meta.url), 'utf8')

// a door with a nested core, then a helper core composed after it (=>)
const door = [
  '|%',
  '++  first',
  '  1',
  '++  outer',
  '  |^  inner',
  '  ++  inner',
  '    2',
  '  ++  other',
  '    3',
  '  --',
  '++  last',
  '  4',
  '--',
  '=>',
  '  |%',
  '  ++  helper',
  '    5',
  '  --',
].join('\n')

test('arm reads an arm by its enclosing chain, to the next arm or core end at its depth', () => {
  assert.equal(arm(door, 'first'), '++  first\n  1')
  assert.equal(arm(door, 'outer/inner'), '  ++  inner\n    2')
  assert.equal(arm(door, 'outer/other'), '  ++  other\n    3')
  assert.equal(arm(door, 'last'), '++  last\n  4')
  assert.equal(arm(door, 'helper'), '  ++  helper\n    5')
  assert.deepEqual(enclosingArms(door, door.split('\n').indexOf('    2')), ['outer', 'inner'])
  // a closed core above ends the walk: the helper core's arm is enclosed by nothing
  assert.deepEqual(enclosingArms(door, door.split('\n').indexOf('    5')), ['helper'])
})

test('arm fails closed: a missing, misplaced or duplicated arm throws', () => {
  assert.throws(() => arm(door, 'inner'), /missing arm inner/)
  assert.throws(() => arm(door, 'outer/absent'), /missing arm outer\/absent/)
  assert.throws(() => arm(`${door}\n++  first\n  6`, 'first'), /ambiguous arm first/)
})

test('type reads a column-0 +$ by its whole name and fails closed', () => {
  const sur = ['|%', '+$  mode  ?(%a %b)', '+$  serve', '  $:  a=@', '      b=@', '  ==', '+$  serve-debug  @', '--'].join('\n')
  assert.equal(type(sur, 'mode'), '+$  mode  ?(%a %b)')
  assert.equal(type(sur, 'serve'), '+$  serve\n  $:  a=@\n      b=@\n  ==')
  assert.throws(() => type(sur, 'absent'), /missing type absent/)
  assert.throws(() => type(`${sur}\n+$  mode  @`, 'mode'), /ambiguous type mode/)
  assert.throws(() => type('|%\n  +$  mode  @\n--', 'mode'), /missing type mode/)
})

test('gaps folds whitespace and comment runs to one gap and keeps aces, cords and tapes', () => {
  assert.equal(gaps('?:  a\n      b  :: why\n    c'), '?:  a  b  c')
  assert.equal(gaps('(f a b)'), '(f a b)')
  // a call form is not layout: the two calls stay different
  assert.notEqual(gaps('%+  f  a  b'), gaps('(f a b)'))
  assert.equal(gaps("x  'a  b'  'c\\'  d'"), "x  'a  b'  'c\\'  d'")
  assert.equal(gaps('"x {(trip \'a  b\')}  y"'), '"x {(trip \'a  b\')}  y"')
  assert.equal(gaps("'::  kept'"), "'::  kept'")
  assert.throws(() => gaps("x  'open"), /unterminated cord/)
})

test('dispatches requires the exact entry that names the arm', () => {
  // read from the switch handle-action's |^ core runs: one line, or tall
  assert.match(actionArm(fixture('action/exact-one-line.hoon'), 'set-ref'), /^ {4}\+\+  set-ref\n/)
  assert.match(actionArm(fixture('action/exact-tall.hoon'), 'set-ref'), /^ {4}\+\+  set-ref\n/)
  assert.throws(() => actionArm(fixture('action/exact-other-arm.hoon'), 'set-ref'), /does not dispatch/)
  // %del names ++delete: a name that is a prefix of the branch's arm is not it
  assert.throws(() => actionArm(fixture('action/exact-one-line.hoon'), 'del'), /does not dispatch/)
})

test('the agent imports its libraries whole, and one the desk does not carry fails closed', () => {
  assert.ok(imports('app/urgit.hoon').includes('lib/git-peer-transfer.hoon'))
  const closure = importClosure('app/urgit.hoon', ['lib/skeleton.hoon']).map(([rel]) => rel)
  assert.ok(closure.includes('lib/git-repository.hoon'))
  // skeleton is base-dev's, staged at install: unnamed, it is a missing file
  assert.throws(() => importClosure('app/urgit.hoon'), /missing import lib\/skeleton\.hoon/)
})

test("the agent's actions, routes and wires are reached only through their entries", () => {
  const agent = deskText('app/urgit.hoon')
  assert.match(actionArm(agent, 'set-ref'), /\?>  \?=\(%set-ref -\.act\)/)
  assert.throws(() => actionArm(agent, 'no-such-action'), /does not dispatch/)
  const tags = '[%apps %urgit %api %repository @ %tags ~]'
  assert.match(routeArm(agent, 'repository-settings-api', 'post-repository-tags', 'POST', tags), /\+\+  post-repository-tags/)
  assert.throws(() => routeArm(agent, 'repository-settings-api', 'post-repository-tags', 'DELETE', tags), /does not route/)
  assert.match(wireArm(agent, '[%github @ ~]', 'github-response'), /\+\+  github-response/)
  assert.throws(() => wireArm(agent, '[%github @ ~]', 'clay-report'), /does not dispatch/)
})
