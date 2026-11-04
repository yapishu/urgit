import test from 'node:test'
import assert from 'node:assert/strict'
import { applyCandidateFactToPage, feedPip, mergeCandidateFact, mergeRunnerCount } from './ciLive.js'

const a = { id: '0va', status: 'pending', attempts: [] }
const b = { id: '0vb', status: 'passed', attempts: [{ attempt: '0v1', status: 'passed' }] }

test('the first fact is the list; a candidate fact replaces its row by id or prepends a new one; other kinds are ignored', () => {
  assert.deepEqual(mergeCandidateFact(undefined, { kind: 'candidates', candidates: [a, b] }), [a, b])
  const patched = mergeCandidateFact([a, b], { kind: 'candidate', id: '0va', patch: { ...a, status: 'passed' } })
  assert.equal(patched[0].status, 'passed')
  assert.equal(patched.length, 2)
  assert.equal(mergeCandidateFact([a], { kind: 'candidate', id: '0vc', patch: { id: '0vc' } })[0].id, '0vc')
  assert.deepEqual(mergeCandidateFact([a], { kind: 'runner', id: 'x', patch: { id: 'x' } }), [a])
  assert.deepEqual(mergeCandidateFact([a], null), [a])
})

test('the open page takes the patch for its own id only, attempts included', () => {
  const page = { candidate: a, attempts: [] }
  const next = applyCandidateFactToPage(page, { kind: 'candidate', id: '0va', patch: { ...a, status: 'passed', attempts: [{ attempt: '0v9', status: 'running' }] } })
  assert.equal(next.candidate.status, 'passed')
  assert.equal(next.attempts[0].attempt, '0v9')
  assert.equal(applyCandidateFactToPage(page, { kind: 'candidate', id: '0vb', patch: b }), page)
  assert.equal(applyCandidateFactToPage(null, { kind: 'candidate' }), null)
})

test('the runner count follows the initial fact and every runner fact', () => {
  const r1 = { id: 'r1', enrolled: 1 }
  assert.deepEqual(mergeRunnerCount([], { kind: 'candidates', candidates: [], runners: [r1] }), [r1])
  assert.equal(mergeRunnerCount([r1], { kind: 'runner', id: 'r2', patch: { id: 'r2' } }).length, 2)
  assert.equal(mergeRunnerCount([r1], { kind: 'runner-gone', id: 'r1' }).length, 0)
  assert.equal(mergeRunnerCount([r1], { kind: 'runner', id: 'r1', patch: { id: 'r1', enrolled: 2 } })[0].enrolled, 2)
})

test('the pip reads live, polling or connecting', () => {
  assert.equal(feedPip('open'), 'live')
  assert.equal(feedPip('closed'), 'polling')
  assert.equal(feedPip(''), 'connecting')
})
