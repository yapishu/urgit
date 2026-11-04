import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { gaps } from './hoonSource.js'

const backend = readFileSync(
  new URL('../../desk/app/urgit.hoon', import.meta.url),
  'utf8',
)

const schema = readFileSync(
  new URL('../../desk/sur/git.hoon', import.meta.url),
  'utf8',
)

function arm(name, next) {
  const start = backend.indexOf(`++  ${name}`)
  const end = backend.indexOf(`++  ${next}`, start)
  assert.notEqual(start, -1, `missing ++  ${name}`)
  assert.notEqual(end, -1, `missing ++  ${next} after ++  ${name}`)
  return backend.slice(start, end)
}

const onInit = arm('on-init', 'on-save')
const onSave = arm('on-save', 'on-load')
const onLoad = arm('on-load', 'on-poke')
const peerRequest = arm('peer-request', 'peer-accepted')
const peerRelease = arm('peer-release', 'peer-snapshot-fail')
const onArvo = backend.slice(backend.indexOf('++  on-arvo'))

// the path a new request takes through ++peer-request. The arm's tall ?: on
// whether the transfer is already served or queued answers a retried request
// in its first branch, the lines indented past the ?:, and continues at the
// ?:'s own column with what a new request runs: it queues the request, then
// answers with its cards
function newRequestPath(armText) {
  const lines = armText.split('\n')
  const pending = /^ *\?:  \|\(\(~\(has by peer-serving\) transfer\.req\) \(~\(has by peer-prepare-queue\) transfer\.req\)\)$/
  assert.equal(lines.filter((line) => pending.test(line)).length, 1, 'one already-served-or-queued test')
  const at = lines.findIndex((line) => pending.test(line))
  const column = lines[at].search(/\S/)
  let next = at + 1
  while (next < lines.length && (!lines[next].trim() || lines[next].trim().startsWith('::') || lines[next].search(/\S/) > column)) {
    next += 1
  }
  assert.ok(next > at + 1, 'the already-served-or-queued test has an early-return branch')
  assert.equal(next < lines.length ? lines[next].search(/\S/) : -1, column, 'the new-request path continues at the test\'s column')
  const path = lines.slice(next).join('\n')
  assert.match(path, /^ *=\.  peer-prepare-queue\n/, 'the new-request path begins by queueing the request')
  return path
}

test('the fork preparation queue is persisted, so a reload cannot strand a requester', () => {
  // It is a field of the saved state, not a transient =/ binding beside it.
  assert.doesNotMatch(backend, /=\/  peer-prepare-queue/)
  assert.match(schema, /peer-prepare-queue=\(map @uv peer-prepare-entry\)/)
  assert.equal(onSave.trimEnd(), '++  on-save\n  !>(state)\n::')

  // on-load keeps the queue and re-arms the ~s1 build timer for each entry.
  assert.doesNotMatch(onLoad, /peer-prepare-queue\s+~/)
  assert.match(onLoad, /~\(tap by peer-prepare-queue\.loaded\)/)
  assert.match(
    onLoad,
    /\/peer\/prepare-start\/\(scot %uv transfer\.entry\) %arvo %b %wait \(add now\.bowl ~s1\)/,
  )

  // The genuinely transient maps are still wiped.
  assert.match(gaps(onLoad), /(?:^|  )peer-stream-jobs  ~(?=  |$)/)
  assert.match(gaps(onLoad), /(?:^|  )peer-serving  ~(?=  |$)/)
  assert.match(onInit, /this\(peer-prepare-queue ~, peer-stream-jobs ~, peer-browse-prepare-queue ~\)/)
})

test('peer request acceptance never immediately starts synchronous pack preparation', () => {
  assert.doesNotMatch(
    peerRequest,
    /%agent\s+\[our\.bowl %urgit\]\s+%poke\s+%git-peer\s+!>\(\[%prepare/,
  )
})

test('new peer requests queue preparation and schedule it one second after acceptance', () => {
  assert.match(
    peerRequest,
    /\|\(\(~\(has by peer-serving\) transfer\.req\) \(~\(has by peer-prepare-queue\) transfer\.req\)\)/,
  )
  assert.match(
    peerRequest,
    /peer-prepare-queue\s+\(~\(put by peer-prepare-queue\) transfer\.req \[src\.bowl req\]\)/,
  )

  // the order that matters is the new request's: the early return before it
  // answers a retried request with the same accepted card, so a search of the
  // whole arm would find that card first
  const fresh = newRequestPath(peerRequest)
  const accepted = gaps(fresh).indexOf(
    '%^  peer-card  src.bowl  /peer/accepted/(scot %uv transfer.req)',
  )
  const wake = gaps(fresh).indexOf(
    '[%pass /peer/prepare-start/(scot %uv transfer.req) %arvo %b %wait (add now.bowl ~s1)]',
  )
  assert.notEqual(accepted, -1, 'missing accepted response card')
  assert.notEqual(wake, -1, 'missing deferred prepare-start wake')
  assert.ok(accepted < wake, 'accepted response must precede prepare-start scheduling')
})

test('prepare-start wake consumes the queue before emitting a self prepare poke', () => {
  assert.match(onArvo, /\[%peer %prepare-start @ ~\]/)
  assert.match(
    onArvo,
    /queued=[\s\S]*?~\(get by peer-prepare-queue\) u\.transfer[\s\S]*peer-prepare-queue\s+\(~\(del by peer-prepare-queue\) u\.transfer\)/,
  )
  assert.match(
    gaps(onArvo),
    /%agent  \[our\.bowl %urgit\]  %poke  %git-peer  !>\(\[%prepare target\.u\.queued req\.u\.queued\]\)/,
  )
})

test('peer release authenticates and cancels queued preparation before serving lookup', () => {
  const queuedLookup = peerRelease.indexOf('~(get by peer-prepare-queue) transfer')
  const servingLookup = peerRelease.indexOf('~(get by peer-serving) transfer')
  assert.notEqual(queuedLookup, -1, 'missing queued preparation lookup')
  assert.notEqual(servingLookup, -1, 'missing serving transfer lookup')
  assert.ok(queuedLookup < servingLookup, 'queued cancellation must run before serving lookup')
  assert.match(peerRelease, /=\(src\.bowl target\.u\.queued\)/)
  assert.match(
    peerRelease,
    /peer-prepare-queue\s+\(~\(del by peer-prepare-queue\) transfer\)/,
  )
})
