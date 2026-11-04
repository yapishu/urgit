import test from 'node:test'
import assert from 'node:assert/strict'
import { ci } from './api.js'
import { lostPost } from './runnerRecoveryComponent.js'

// the recovery's calls on the same-origin ci API (legacy-recovery UI ruling
// 01): the runner's view, the release through the action route, and a
// refusal told apart from a lost reply — the ship's answer carries its
// status, a failed request carries none

test('the view and the release go to their routes, the session\'s cookie with them', async () => {
  const seen = []
  globalThis.fetch = async (url, options = {}) => {
    seen.push({ url, method: options.method || 'GET', credentials: options.credentials, body: options.body })
    return { ok: true, status: 200, text: async () => '{"ok":true}' }
  }
  await ci.recovery('0v1.daemon')
  await ci.action({ action: 'request-legacy-release', id: '0v1.daemon', selection: 's/1', revision: 1, evidence: 'e' })
  assert.deepEqual(seen[0], { url: '/apps/urgit/api/ci/runners/0v1.daemon/recovery', method: 'GET', credentials: 'same-origin', body: undefined })
  assert.equal(seen[1].url, '/apps/urgit/api/ci/action')
  assert.equal(seen[1].method, 'POST')
  assert.equal(seen[1].credentials, 'same-origin')
  assert.deepEqual(JSON.parse(seen[1].body), { action: 'request-legacy-release', id: '0v1.daemon', selection: 's/1', revision: 1, evidence: 'e' })
})

test('the ship\'s refusal carries its status and its words; a request that failed carries none, and is a lost reply', async () => {
  globalThis.fetch = async () => ({ ok: false, status: 409, text: async () => '{"error":"the evidence changed since it was inspected: inspect it again"}' })
  const refusal = await ci.action({ action: 'request-legacy-release' }).catch((e) => e)
  assert.equal(refusal.message, 'the evidence changed since it was inspected: inspect it again')
  assert.equal(refusal.status, 409, 'A REFUSAL CARRIED NO STATUS')
  assert.equal(lostPost(refusal), false, 'A REFUSAL WAS TAKEN FOR A LOST REPLY')
  globalThis.fetch = async () => { throw new TypeError('Failed to fetch') }
  const lost = await ci.action({ action: 'request-legacy-release' }).catch((e) => e)
  assert.equal(lostPost(lost), true, 'A FAILED REQUEST WAS TAKEN FOR THE SHIP\'S ANSWER')
})
