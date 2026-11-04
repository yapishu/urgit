import test from 'node:test'
import assert from 'node:assert/strict'
import { armsNamed, deskText, gaps, type } from './hoonSource.js'
import { AUTHORITY, TRIAL, UNREAD } from './ciConcurrencyFixtures.js'

// The concurrency panel reads the candidate route's fields by name and
// shows the ship's reasons as the ship words them (CI-CONCURRENCY-1). The
// fixtures are a MODEL of those answers; this file holds them to the
// agent's own source: every key the panel reads is one the agent writes,
// every place, kind and cause is one the types define, and every reason
// the fixtures quote is the ship's cord. Source reading, not a run of the
// agent: the parent's live recipe reads its answers.

const agent = deskText('app/urgit-ci.hoon')
const sur = deskText('sur/ci.hoon')
const lib = deskText('lib/ci-concurrency.hoon')

const one = (text, name) => {
  const found = armsNamed(text, name)
  assert.equal(found.length, 1, `exactly one ++${name}`)
  return gaps(found[0])
}
const cord = (s) => `'${s.replace(/\\/g, '\\\\').replace(/'/g, "\\'")}'`

test('every field the panel reads is one the candidate route writes', () => {
  const concurrency = one(agent, 'concurrency-json')
  for (const key of ['state', 'reason', 'joined', 'workflows', 'workflow', 'name', 'group', 'cancelled', 'finished']) {
    assert.ok(concurrency.includes(`['${key}' `) || concurrency.includes(`'${key}'  `), `concurrency-json writes ${key}`)
  }
  const group = one(agent, 'group-json')
  for (const kind of ['free', 'unknown', 'refused', 'member']) assert.ok(group.includes(`['kind' s+'${kind}']`), `group-json writes kind ${kind}`)
  for (const key of ['text', 'cancelInProgress', 'place', 'behind', 'since', 'reason']) assert.ok(group.includes(`['${key}' `), `group-json writes ${key}`)
  const ref = one(agent, 'run-ref-json')
  for (const key of ['id', 'label']) assert.ok(ref.includes(`['${key}' `), `run-ref-json writes ${key}`)
  const cancellation = one(agent, 'cancellation-json')
  for (const key of ['at', 'started', 'cause', 'reason', 'actor', 'by', 'group']) assert.ok(cancellation.includes(`['${key}' `), `cancellation-json writes ${key}`)
  const candidate = one(agent, 'candidate-json')
  for (const key of ['concurrency', 'canCancel']) assert.ok(candidate.includes(`['${key}' `), `candidate-json writes ${key}`)
  for (const key of ['cancellations', 'cancelAuthority']) assert.ok(candidate.includes(`:-  '${key}'`), `candidate-json writes ${key}`)
  assert.ok(candidate.includes("(~(put by p.base) 'workflow' s+workflow)"), 'each cancellation names its workflow')
})

test('the places, kinds, causes and states the panel words are the ones the types define; cancelled is no bunt', () => {
  assert.match(gaps(type(sur, 'group-place')), /\?\(%holding %waiting %released\)/)
  const cause = gaps(type(sur, 'cancel-cause'))
  for (const tag of ['%operator', '%superseded', '%displaced']) assert.ok(cause.includes(`[${tag} `), `cancel-cause has ${tag}`)
  const state = gaps(type(sur, 'run-concurrency'))
  for (const tag of ['%pending', '%exempt', '%unknown', '%joined']) assert.ok(state.includes(`[${tag} `), `run-concurrency has ${tag}`)
  const group = gaps(type(sur, 'workflow-group'))
  for (const tag of ['%free', '%unknown', '%refused', '%member']) assert.ok(group.includes(tag), `workflow-group has ${tag}`)
  // a defaulted status stays %unknown, the last of the list: %cancelled is
  // not the bunt
  assert.match(gaps(type(sur, 'candidate-status')), /\?\(%passed %failed %pending %skipped %cancelled %unknown\)/)
})

test('the reasons the fixtures quote are the ship\'s own words', () => {
  assert.ok(one(lib, 'unread').includes(cord(UNREAD)), 'unread')
  assert.ok(one(lib, 'exempt').includes(cord(TRIAL)), 'a trial twin')
  assert.ok(one(agent, 'no-cancel-authority').includes(cord(AUTHORITY)), 'the authority')
  const join = one(lib, 'join')
  assert.ok(join.includes("~['cancelled: the newer run (' label ') joined group ' named ' with cancel-in-progress']"), 'a newcomer with cancel-in-progress')
  assert.ok(join.includes("~['cancelled: a newer run (' label ') is waiting in group ' named]"), 'a displaced waiting run')
  // the panel words a waiting run as the job decision's reason words it
  assert.ok(one(lib, 'waiting-text').includes("~['waiting for run ' (label-of s u.behind.g) ' in group ' text.g]"), 'waiting for run X in group G')
})

test('the cancel-run body the panel posts is the one the agent parses', () => {
  const parse = one(agent, 'parse-web-action')
  const at = parse.indexOf('%cancel-run')
  assert.ok(at >= 0, 'parse-web-action has %cancel-run')
  const arm = parse.slice(at, parse.indexOf('%request-legacy-release', at))
  assert.ok(arm.includes("(string-at 'workflow' jon)"), 'workflow')
  assert.ok(arm.includes("(string-at 'reason' jon)"), 'reason')
  assert.ok(arm.includes("?~  id  [%| 'id must be a run id']"), 'id')
})
