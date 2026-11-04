import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { arm, deskText } from './hoonSource.js'
import { api } from './api.js'

const repositoryView = readFileSync(
  new URL('./components/RepositoryView.jsx', import.meta.url),
  'utf8',
)
const peerActivityView = readFileSync(
  new URL('./components/PeerActivity.jsx', import.meta.url),
  'utf8',
)
const backend = readFileSync(
  new URL('../../desk/app/urgit.hoon', import.meta.url),
  'utf8',
)
// the browse and transfer JSON and the offer record are lib/git-json's and
// lib/git-peer-transfer's, which the agent imports
const json = deskText('lib/git-json.hoon')
const transferLib = deskText('lib/git-peer-transfer.hoon')
// the text from `start` to `end`, both of which must be there, in that order
function between(source, start, end) {
  const startAt = source.indexOf(start)
  const endAt = source.indexOf(end, startAt + 1)
  if (startAt === -1 || endAt === -1) throw new Error(`missing ${startAt === -1 ? start : end}`)
  return source.slice(startAt, endAt)
}
const settings = repositoryView.slice(
  repositoryView.indexOf('function Settings'),
  repositoryView.indexOf('export default function RepositoryView'),
)
const peerBrowse = between(backend, '++  peer-browse-request', '++  peer-browse-ready')
const peerBrowseJson = arm(json, 'peer-repository-browse-json')
const publicScries = between(backend, '++  on-peek', '++  on-watch')
const peerError = between(backend, '++  peer-error', '++  handle-peer')
const peerResultReceived = between(backend, '++  peer-result-received', '++  peer-request')
const peerPrepare = between(backend, '++  peer-prepare', '++  peer-ready')
const peerRelease = between(backend, '++  peer-release', '++  peer-snapshot-fail')
const peerResultsJson = arm(transferLib, 'peer-ui-transfers-json')

test('setReader posts the ship reader permission to the encoded repository route', async () => {
  const originalFetch = globalThis.fetch
  let request
  globalThis.fetch = async (url, options) => {
    request = { url, options }
    return { ok: true, status: 200, text: async () => '{}' }
  }

  try {
    await api.setReader('private repo', '~sampel-palnet', true)
  } finally {
    globalThis.fetch = originalFetch
  }

  assert.equal(request.url, '/apps/urgit/api/repository/private%20repo/readers')
  assert.equal(request.options.method, 'POST')
  assert.deepEqual(JSON.parse(request.options.body), {
    ship: '~sampel-palnet',
    allowed: true,
  })
})

test('repository access settings manage readers separately from writers', () => {
  assert.match(settings, /const \[reader, setReader\] = useState\(''\)/)
  assert.match(settings, /<h3>Ship readers<\/h3>/)
  assert.match(settings, /Readers can discover, browse, and fork this private repository through Urgit, but cannot send updates\. Writers already have read access\./)
  assert.match(settings, /value=\{reader\}/)
  assert.match(settings, /api\.setReader\(repo\.name, reader\.trim\(\), true\)/)
  assert.match(settings, /\(repo\.readers \|\| \[\]\)\.map/)
  assert.match(settings, /api\.setReader\(repo\.name, ship, false\)/)
})

test('native peer browse responses hide repository administration fields', () => {
  assert.match(peerBrowseJson, /\['repository' \(public-repository-json-up-to name repo 50\)\]/)
  assert.doesNotMatch(peerBrowse, /\(repository-json repository u\.found\)/)
  assert.equal(
    [...peerBrowse.matchAll(/\(public-repository-json-up-to repository u\.found 50\)/g)].length,
    3,
  )
})

test('public repository scries hide repository administration fields', () => {
  assert.match(publicScries, /\(public-repositories-json visible\)/)
  assert.match(publicScries, /\(public-repository-json name u\.found\)/)
  assert.match(publicScries, /\(peer-repository-browse-json name u\.found\)/)
  assert.doesNotMatch(publicScries, /\(repositories-json visible\)/)
  assert.doesNotMatch(publicScries, /\(repository-json name u\.found\)/)
  assert.doesNotMatch(publicScries, /\(repository-browse-json name u\.found\)/)
})

test('early peer errors finish tracked outgoing offers', () => {
  assert.match(peerError, /outgoing=.*~\(get by peer-outgoing\) transfer/)
  assert.match(peerError, /=\(src\.bowl peer\.u\.outgoing\)/)
  assert.match(peerError, /peer-outgoing-finish transfer %.n message/)
  assert.doesNotMatch(peerError, /skim\s+peer-activities/)
})

test('snapshot service activity does not replace its outgoing offer', () => {
  assert.match(peerPrepare, /peer-serve-activity-id transfer\.req/)
  assert.match(peerRelease, /peer-serve-activity-id transfer/)
})

test('outgoing offers remain active until authoritative state is consumed', () => {
  assert.match(transferLib, /\+\$  peer-offer-flight/)
  assert.match(backend, /=\/  peer-outgoing\s+\*\(map @uv peer-offer-flight\)/)
  assert.match(peerResultsJson, /offer=\(unit peer-offer-flight\).*~\(get by outgoing\.ui\) transfer/)
  assert.match(peerResultsJson, /\['active' b\+\|\(\?=\(\^ flight\) \?=\(\^ offer\)\)\]/)
})

test('peer results authenticate and consume one active outgoing offer', () => {
  assert.match(peerResultReceived, /outgoing=.*~\(get by peer-outgoing\) transfer/)
  assert.match(peerResultReceived, /=\(src\.bowl peer\.u\.outgoing\)/)
  assert.match(peerResultReceived, /peer-outgoing-finish transfer ok message/)
})

test('outgoing offers have a terminal timeout independent of activity history', () => {
  // every offer arms its own timeout: the push, the pull request, and the
  // checkpoint replica's push (CI-RECOVERY-1)
  const offers = [...backend.matchAll(/\/peer\/offer\/\(scot %uv transfer\)/g)].length
  assert.equal(offers, 3)
  assert.equal([...backend.matchAll(/\/peer\/offer-timeout\/\(scot %uv transfer\)/g)].length, offers)
  assert.match(backend, /\[%peer %offer-timeout @ ~\]/)
  assert.match(backend, /peer-outgoing\s+\(~\(del by peer-outgoing\) u\.transfer\)/)
  assert.match(backend, /peer-results\s+[\s\S]*\[%.n message repository\.u\.outgoing\]/)
  const clearActivity = between(
    backend,
    "?=([%apps %urgit %api %peer %activity ~] site)",
    "?=([%apps %urgit %api %peer %transfers ~] site)",
  )
  assert.doesNotMatch(clearActivity, /peer-outgoing/)
})

test('only cancellable fork transfers show a cancel action', () => {
  assert.match(peerActivityView, /event\.status === 'active' && event\.kind === 'fork'/)
})
