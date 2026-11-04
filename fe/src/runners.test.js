import test from 'node:test'
import assert from 'node:assert/strict'
import { clockOffset, configSnippet, enrolledCount, historyOf, mergeRunnerFact, retentionsOf, retentionsText, rowActions, runnerActions, runnerRow, runnerState } from './runners.js'

const minted = { id: '0v5.abcde.fghij.klmno.pqrst.uvwxy', capacity: 1, sandbox: '', labels: [], repos: null, minted: 1000, enrolled: null, lastSeen: null, running: 0, revoked: null, refused: null, state: 'minted' }
const healthy = { ...minted, id: '0v6.h', enrolled: 1010, lastSeen: 1090, capacity: 3, running: 1, sandbox: 'docker-rootless', labels: ['big-mem', 'linux'], state: 'healthy' }

test('the pip is re-derived on the clock: healthy within stale-after (one number, ~m5), stale beyond even at capacity, and the record\'s own revoked/refused/minted first', () => {
  assert.equal(runnerState(minted, 1100), 'minted')
  assert.equal(runnerState(healthy, 1100), 'healthy')
  assert.equal(runnerState(healthy, 1389), 'healthy')
  assert.equal(runnerState(healthy, 1390), 'stale')
  assert.equal(runnerState({ ...healthy, running: 3 }, 9999), 'stale')
  assert.equal(runnerState(healthy, 1140, 50), 'stale')
  assert.equal(runnerState({ ...healthy, refused: 'assignment refused: signature does not verify' }, 1100), 'refused')
  assert.equal(runnerState({ ...healthy, revoked: 1200, refused: 'x' }, 1100), 'revoked')
  assert.equal(runnerState({ ...healthy, lastSeen: null }, 1100), 'stale')
})

test('a row carries the short id, labels and binding text, and the actions its state allows', () => {
  const row = runnerRow(healthy, 1100)
  assert.equal(row.shortId, '0v6.h')
  assert.equal(row.labelsText, 'big-mem, linux')
  assert.equal(row.reposText, 'any')
  assert.deepEqual(row.actions, ['revoke'])
  assert.equal(runnerRow({ ...healthy, repos: ['ci-p3'] }, 1100).reposText, 'only ci-p3')
  assert.equal(runnerRow({ ...healthy, repos: ['a', 'b'] }, 1100).reposText, 'only 2 named')
  assert.equal(runnerRow(minted, 1100).labelsText, 'none declared')
  assert.deepEqual(rowActions('minted'), ['expire'])
  assert.deepEqual(rowActions('revoked'), ['remove'])
  assert.deepEqual(rowActions('refused'), ['revoke'])
})

test('a runner fact replaces its row by id, a new id is prepended, runner-gone drops it, runners replaces the list', () => {
  const list = [minted, healthy]
  const patched = mergeRunnerFact(list, { kind: 'runner', id: healthy.id, patch: { ...healthy, running: 2 } })
  assert.equal(patched[1].running, 2)
  assert.equal(patched.length, 2)
  const added = mergeRunnerFact(list, { kind: 'runner', id: '0v9', patch: { ...minted, id: '0v9' } })
  assert.equal(added[0].id, '0v9')
  assert.equal(mergeRunnerFact(list, { kind: 'runner-gone', id: minted.id }).length, 1)
  assert.deepEqual(mergeRunnerFact(list, { kind: 'runners', runners: [healthy] }), [healthy])
  assert.deepEqual(mergeRunnerFact(list, { kind: 'candidate', id: 'x', patch: {} }), list)
  assert.deepEqual(mergeRunnerFact(undefined, null), [])
})

test('the action bodies name the poke, and the binding is null or a list', () => {
  assert.deepEqual(runnerActions.expire('0v1'), { action: 'expire-token', id: '0v1' })
  assert.deepEqual(runnerActions.revoke('0v1'), { action: 'revoke-daemon', id: '0v1' })
  assert.deepEqual(runnerActions.setRepos('0v1', null), { action: 'set-daemon-repos', id: '0v1', repos: null })
  assert.deepEqual(runnerActions.setRepos('0v1', new Set(['a'])), { action: 'set-daemon-repos', id: '0v1', repos: ['a'] })
  assert.deepEqual(runnerActions.rotate(), { action: 'rotate-ci-key' })
})

test('the config snippet is the ship\'s, or the same three keys built from the answer', () => {
  assert.equal(configSnippet({ configSnippet: 'ship_url = "x"\n' }), 'ship_url = "x"\n')
  assert.equal(configSnippet({ shipUrl: 'http://s', token: '0v1' }), 'ship_url = "http://s"\nenroll_token = "0v1"\nsandbox = "docker-rootless"\n')
})

test('the clock offset is the ship\'s now against the client\'s, and the enrolled count skips minted and revoked records', () => {
  assert.equal(clockOffset(1000, 1010), -10)
  assert.equal(clockOffset(null, 1010), 0)
  assert.equal(enrolledCount([minted, healthy, { ...healthy, revoked: 1 }]), 1)
})

test('a row carries what the runner\'s latest retention report says it withholds, and none when it reported none (legacy-recovery UI ruling 01)', () => {
  assert.equal(runnerRow(healthy, 1100).retentions, null)
  assert.equal(retentionsText(null), 'not reported')
  const reported = runnerRow({ ...healthy, retentions: { reported: 1090, total: 2, legacy: 1, eligible: 1 } }, 1100)
  assert.deepEqual(reported.retentions, { reported: 1090, total: 2, legacy: 1, eligible: 1 })
  assert.equal(retentionsText(reported.retentions), '2 withheld · 1 legacy, 1 releasable')
  assert.equal(retentionsText(retentionsOf({ retentions: { reported: 1, total: 0, legacy: 0, eligible: 0 } })), 'none')
  assert.equal(retentionsText(retentionsOf({ retentions: { reported: 1, total: 3, legacy: 1, eligible: 0 } })), '3 withheld · 1 legacy')
  assert.equal(retentionsOf({ retentions: 'x' }), null)
  // the actions its state allows are unchanged by what it withholds
  assert.deepEqual(reported.actions, ['revoke'])
})

test('a row carries whether the runner\'s latest report shows it waiting for its history transition, and nothing when it reported no history (legacy-replay-upgrade ruling 01)', () => {
  assert.equal(runnerRow(healthy, 1100).history, null)
  const paused = runnerRow({ ...healthy, history: { paused: true, revision: 1790000000 } }, 1100)
  assert.deepEqual(paused.history, { paused: true, revision: 1790000000 }, 'A PAUSED RUNNER WAS NOT MARKED PAUSED')
  assert.deepEqual(historyOf({ history: { paused: false, revision: 7 } }), { paused: false, revision: 7 })
  assert.deepEqual(historyOf({ history: { paused: 'yes', revision: 'x' } }), { paused: false, revision: 0 })
  assert.equal(historyOf({ history: 'x' }), null)
  // a paused runner keeps its state and the actions its state allows
  assert.equal(paused.state, 'healthy')
  assert.deepEqual(paused.actions, ['revoke'])
})
