import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { api } from './api.js'
import { arm, deskText, gaps, type } from './hoonSource.js'

const backend = readFileSync(
  new URL('../../desk/app/urgit.hoon', import.meta.url),
  'utf8',
)
const peerSurface = readFileSync(
  new URL('../../desk/sur/git-peer.hoon', import.meta.url),
  'utf8',
)
const repositoryView = readFileSync(
  new URL('./components/RepositoryView.jsx', import.meta.url),
  'utf8',
)

function sourceBlock(source, start, end) {
  const startAt = source.indexOf(start)
  assert.notEqual(startAt, -1, `missing ${start}`)
  const endAt = source.indexOf(end, startAt + start.length)
  assert.notEqual(endAt, -1, `missing ${end} after ${start}`)
  return source.slice(startAt, endAt)
}

async function captureRequest(operation) {
  const originalFetch = globalThis.fetch
  let captured
  globalThis.fetch = async (url, options) => {
    captured = { url, options }
    return { ok: true, status: 200, text: async () => '{"ok":true}' }
  }
  try {
    await operation()
  } finally {
    globalThis.fetch = originalFetch
  }
  return captured
}

test('local pull client posts explicit source and target branches', async () => {
  const request = await captureRequest(() => api.createPull(
    'project',
    'Compare release',
    'refs/heads/release',
    'refs/heads/staging',
  ))

  assert.equal(request.url, '/apps/urgit/api/repository/project/pulls')
  assert.equal(request.options.method, 'POST')
  assert.deepEqual(JSON.parse(request.options.body), {
    title: 'Compare release',
    sourceBranch: 'refs/heads/release',
    targetBranch: 'refs/heads/staging',
  })
})

test('peer pull client posts explicit source and target branches', async () => {
  const request = await captureRequest(() => api.peerPullRequest(
    'fork',
    'Offer topic',
    'refs/heads/topic',
    'refs/heads/integration',
  ))

  assert.equal(request.url, '/apps/urgit/api/peer/pull-request')
  assert.equal(request.options.method, 'POST')
  assert.deepEqual(JSON.parse(request.options.body), {
    name: 'fork',
    title: 'Offer topic',
    sourceBranch: 'refs/heads/topic',
    targetBranch: 'refs/heads/integration',
  })
})

test('peer pull wire and receive state carry selected refs', () => {
  const legacyOffer = sourceBlock(peerSurface, '+$  offer', '+$  offer-branches')
  assert.doesNotMatch(legacyOffer, /source-ref=@t/)
  assert.doesNotMatch(legacyOffer, /target-ref=@t/)
  const branchOffer = sourceBlock(peerSurface, '+$  offer-branches', '+$  packet')
  assert.match(branchOffer, /source-ref=@t/)
  assert.match(branchOffer, /target-ref=@t/)

  // the receive state is lib/git-peer-transfer's, which the agent imports
  const receive = type(deskText('lib/git-peer-transfer.hoon'), 'peer-receive')
  assert.match(receive, /source-ref=@t/)
  assert.match(receive, /target-ref=@t/)
})

test('peer pull API validates selected refs and offers both to the origin', () => {
  const handler = sourceBlock(
    backend,
    "?=([%apps %urgit %api %peer %pull-request ~] site)",
    "?=([%apps %urgit %api %repositories ~] site)",
  )
  assert.match(handler, /string-at 'sourceBranch'/)
  assert.match(handler, /string-at 'targetBranch'/)
  assert.equal([...handler.matchAll(/starts-with 'refs\/heads\/'/g)].length, 2)
  assert.equal([...handler.matchAll(/valid-ref:git-protocol/g)].length, 2)
  assert.match(handler, /~\(get by refs\.u\.found\) u\.source-ref/)
  assert.match(handler, /source branch not found/)
  assert.match(gaps(handler), /:\*  %offer-branches  transfer  repository\.u\.peer-origin\.u\.found  u\.name  u\.source-ref  u\.target-ref  %.y  u\.title  ==/)
})

test('origin validates target and pins selected source and target tips', () => {
  const offer = sourceBlock(backend, '++  peer-offer', '++  peer-result-received')
  assert.match(offer, /repository-readable u\.found src\.bowl/)
  assert.match(offer, /ship is not authorized to read this repository/)
  assert.match(offer, /valid-ref:git-protocol source-ref\.offer/)
  assert.match(offer, /valid-ref:git-protocol target-ref\.offer/)
  assert.match(offer, /~\(get by refs\.u\.found\) target-ref\.offer/)
  assert.match(offer, /target branch not found/)
  assert.match(offer, /source-ref\.offer/)
  assert.match(offer, /target-ref\.offer/)

  const finish = sourceBlock(backend, '++  peer-finish', '++  peer-push-finish')
  assert.match(finish, /selected-source-ref=@t[\s\S]*source-ref\.flight/)
  assert.match(finish, /~\(get by refs\.flight\) selected-source-ref/)
  assert.match(finish, /~\(get by refs\.u\.existing\) target-ref\.flight/)
  assert.match(finish, /selected branches have identical tips/)
  assert.match(finish, /source-ref\.flight/)
  assert.match(finish, /target-ref\.flight/)
})

test('legacy peer offers remain decodable during a rolling upgrade', () => {
  const dispatch = sourceBlock(backend, '++  handle-peer', '++  peer-catalog-request')
  assert.match(dispatch, /%offer\s+\(peer-offer-legacy offer\.packet\)/)
  assert.match(dispatch, /%offer-branches\s+\(peer-offer offer-branches\.packet\)/)
  const push = sourceBlock(
    backend,
    "?=([%apps %urgit %api %peer %push ~] site)",
    "?=([%apps %urgit %api %peer %pull-request ~] site)",
  )
  assert.match(push, /\[%offer transfer repository\.u\.peer-origin\.u\.found u\.name %.n ''\]/)
})

test('incomplete push and pull graphs return a terminal result to the source', () => {
  const finish = sourceBlock(backend, '++  peer-finish', '=/  existing=(unit repository:git)')
  assert.match(finish, /peer-push-finish flight transfer %.n 'received repository graph is incomplete'/)
})

test('local pull creation validates and pins explicit source and target refs', () => {
  const create = sourceBlock(
    backend,
    "?=([%apps %urgit %api %repository @ %pulls ~] site)",
    "?=([%apps %urgit %api %repository @ %pulls @ ~] site)",
  )
  assert.match(create, /string-at 'sourceBranch'/)
  assert.match(create, /string-at 'targetBranch'/)
  assert.equal([...create.matchAll(/starts-with 'refs\/heads\/'/g)].length, 2)
  assert.equal([...create.matchAll(/valid-ref:git-protocol/g)].length, 2)
  assert.match(create, /~\(get by refs\.u\.found\) u\.source-ref/)
  assert.match(create, /~\(get by refs\.u\.found\) u\.target-ref/)
  assert.match(create, /selected branches have identical tips/)
  // a new pull request has no comments and, since state-5, no labels
  assert.match(create, /\[number our\.bowl name u\.source-ref u\.target-ref u\.title %open u\.incoming u\.base ~ ~\]/)
})

test('merge advances only the recorded target ref and gates Clay only for that ref', () => {
  const merge = sourceBlock(
    backend,
    "?=([%apps %urgit %api %repository @ %pulls @ %merge ~] site)",
    '++  on-arvo',
  )
  assert.match(merge, /~\(get by refs\.u\.found\) target-ref\.pull/)
  assert.match(gaps(merge), /(?:^|  )refs  \(~\(put by refs\.u\.found\) target-ref\.pull merge-oid\)/)
  assert.match(merge, /=\(target-ref\.pull branch\.u\.binding\.applied\)/)
  assert.doesNotMatch(merge, /refs\s+\(~\(put by refs\.u\.found\) head\.u\.found merge-oid\)/)
})

test('pull summary and detail JSON expose sourceRef and targetRef', () => {
  // the repository and pull JSON is lib/git-json's, which the agent imports
  const json = deskText('lib/git-json.hoon')
  const summary = sourceBlock(json, '++  repository-json', '++  repositories-json')
  assert.match(summary, /\['sourceRef' s\+source-ref\.pull\]/)
  assert.match(summary, /\['targetRef' s\+target-ref\.pull\]/)

  const detail = arm(json, 'native-pull-detail-json')
  assert.match(detail, /'sourceRef' s\+source-ref\.pull/)
  assert.match(detail, /'targetRef' s\+target-ref\.pull/)

  const localDetail = sourceBlock(
    backend,
    "?=([%apps %urgit %api %repository @ %pulls @ ~] site)",
    "?=([%apps %urgit %api %repository @ %pulls @ %comments ~] site)",
  )
  assert.match(localDetail, /native-pull-detail-json name u\.found pull/)
})

test('pull composer selects both branches and discovers peer target refs', () => {
  const pulls = sourceBlock(repositoryView, 'function PullRequests', 'export function DiffView')
  assert.match(pulls, /branchRefs = \(repo\.refs \|\| \[\]\)\.filter\(\(ref\) => ref\.name\.startsWith\('refs\/heads\/'\)\)/)
  assert.match(pulls, /const \[targetRepository, setTargetRepository\] = useState/)
  assert.match(pulls, /<option value="local">This repository<\/option>/)
  assert.match(pulls, /<option value="origin">Origin repository<\/option>/)
  assert.match(pulls, /value=\{sourceBranch\}/)
  assert.match(pulls, /value=\{targetBranch\}/)
  assert.match(pulls, /!repo\.peerOrigin \|\| targetRepository === 'local'/)
  assert.match(pulls, /api\.createPull\(repo\.name, title\.trim\(\), sourceBranch, targetBranch\)/)
  assert.match(pulls, /api\.peerPullRequest\(repo\.name, title\.trim\(\), sourceBranch, targetBranch\)/)
  assert.match(pulls, /api\.peerBrowse\(repo\.peerOrigin\.ship, repo\.peerOrigin\.repository\)/)
  assert.match(pulls, /waitForPeerBrowse\(started\.request/)
  assert.match(pulls, /Loading origin branches/)
  assert.match(pulls, /Could not load origin branches/)
  assert.match(pulls, /pullRefLabel\(selected\.sourceRef, selected\.head\)/)
  assert.match(pulls, /pullRefLabel\(pull\.sourceRef, pull\.head\)/)
})
