import test from 'node:test'
import assert from 'node:assert/strict'
import { probeClass, probeMessage, probeStore } from './storageProbe.js'

const answers = (plan) => async (url, options) => {
  const step = plan.shift()
  if (step === 'ok') return { status: 403 }
  if (step === 'opaque') { assert.equal(options.mode, 'no-cors'); return { status: 0, type: 'opaque' } }
  throw new TypeError('Failed to fetch')
}

test('any HTTP answer is reachable; a rejected cors fetch that resolves opaque is a CORS refusal; two rejections are unreachable', async () => {
  assert.equal(await probeStore('http://s/b/ci/_probe', answers(['ok'])), 'reachable')
  assert.equal(await probeStore('http://s/b/ci/_probe', answers(['fail', 'opaque'])), 'cors')
  assert.equal(await probeStore('http://s/b/ci/_probe', answers(['fail', 'fail'])), 'unreachable')
  assert.equal(await probeStore('', answers([])), 'unknown')
})

test('the red sentence is D5\'s, naming the host', () => {
  assert.equal(probeMessage('unreachable', '127.0.0.1:8392'), "Your browser cannot reach the object store at 127.0.0.1:8392. Logs and artifacts will not open. The endpoint must be reachable from every viewer's network, not only from the ship's host.")
  assert.match(probeMessage('cors', 'h'), /CORS rule/)
  assert.match(probeMessage('reachable', 'h'), /can reach/)
  assert.equal(probeClass('unreachable'), 'bad')
  assert.equal(probeClass('reachable'), 'good')
  assert.equal(probeClass('unknown'), '')
})
