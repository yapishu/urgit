import test from 'node:test'
import assert from 'node:assert/strict'
import { arm, armsNamed, deskText, gaps, importClosure, imports, type, wireArm } from './hoonSource.js'

const backend = deskText('app/urgit.hoon')
const peerTypes = deskText('sur/git-peer.hoon')
// the peer-transfer types, limits and fragment rules live in the library the
// agent imports them from, not in the agent
const transferLib = deskText('lib/git-peer-transfer.hoon')
if (!imports('app/urgit.hoon').includes('lib/git-peer-transfer.hoon')) {
  throw new Error('%urgit does not import lib/git-peer-transfer')
}

// the poke handlers are arms of on-poke's core, and each arvo wire has its own
// arm, which on-arvo's table must send that wire to
const poke = (name) => arm(backend, `on-poke/${name}`)
const onArvo = arm(backend, 'on-arvo')

const onInit = arm(backend, 'on-init')
const onSave = arm(backend, 'on-save')
const onLoad = arm(backend, 'on-load')
const handlePeer = poke('handle-peer')
const peerTransferYawns = poke('peer-transfer-yawns')
const peerServeLifetime = arm(transferLib, 'peer-serve-lifetime')
// no ++peer-directed, at any depth, in the agent or any library it imports
const peerDirected = [backend, ...importClosure('app/urgit.hoon', ['lib/skeleton.hoon']).map(([, text]) => text)]
  .flatMap((text) => armsNamed(text, 'peer-directed'))
  .join('\n')
const peerObjectPages = poke('peer-object-pages')
const peerObjectBatchCount = poke('peer-object-batch-count')
const peerObjectBatch = poke('peer-object-batch')
const peerPrepare = poke('peer-prepare')
const objectBranchAt = peerPrepare.indexOf('=/  pages=@ud  stream-pages')
if (objectBranchAt === -1) throw new Error('missing the object branch of ++peer-prepare')
const peerObjectPrepare = peerPrepare.slice(objectBranchAt)
const peerStreamNext = poke('peer-stream-next')
const peerStreamGrown = poke('peer-stream-grown')
const peerArchiveReady = poke('peer-archive-ready')
const peerArchiveAccept = poke('peer-archive-accept')
const peerBegin = poke('peer-begin')
const peerBeginObjects = poke('peer-begin-objects')
const peerRelease = poke('peer-release')
const peerArchive = poke('peer-archive')
const peerSnapshotFail = poke('peer-snapshot-fail')
// the page handler hands every page to ++assemble-peer-fragments, the rules
// upstream extracted into the library: both are the handler's text
const pageHandler = poke('peer-object-fragments')
const peerObjectFragments = [pageHandler, arm(transferLib, 'assemble-peer-fragments')].join('\n')
const peerSnapshot = poke('peer-snapshot')
const fineHandler = wireArm(backend, '[%peer %fine @ @ ~]', 'peer-fine')
const serveTimeout = wireArm(backend, '[%peer %serve-timeout @ ~]', 'peer-serve-timeout')
const prepareTimeout = wireArm(backend, '[%peer %prepare-timeout @ ~]', 'peer-prepare-timeout')
const archiveTimeout = wireArm(backend, '[%peer %archive-timeout @ ~]', 'peer-archive-timeout')
const rateHandler = wireArm(backend, '[%peer %rate @ @ ~]', 'peer-rate')

test('raw-object streaming adds a new begin packet and authenticated self packets', () => {
  assert.match(peerTypes, /\+\$  begin\s+[\s\S]*?revision=@ud[\s\S]*?objects=@ud[\s\S]*?pages=@ud/)
  assert.match(peerTypes, /\+\$  begin-objects\s+[\s\S]*?revision=@ud[\s\S]*?objects=@ud[\s\S]*?pages=@ud/)
  assert.match(peerTypes, /\[%begin begin=begin\]/)
  assert.match(peerTypes, /\[%begin-objects begin-objects=begin-objects\]/)
  assert.match(peerTypes, /\[%stream-next transfer=@uv\]/)
  assert.match(peerTypes, /\[%stream-grown transfer=@uv\]/)
  assert.match(peerTypes, /\+\$  archive-ready[\s\S]*?objects=@ud[\s\S]*?bytes=@ud/)
  assert.match(peerTypes, /\[%archive-ready archive-ready=archive-ready\]/)
  assert.match(peerTypes, /\[%archive-accept transfer=@uv\]/)
  assert.match(handlePeer, /%begin-objects\s+\(peer-begin-objects begin-objects\.packet\)/)
  assert.match(handlePeer, /%archive-ready\s+\(peer-archive-ready archive-ready\.packet\)/)
  assert.match(handlePeer, /%archive-accept\s+\(peer-archive-accept transfer\.packet\)/)
  assert.match(handlePeer, /%stream-next\s+\(peer-stream-next transfer\.packet\)/)
  assert.match(handlePeer, /%stream-grown\s+\(peer-stream-grown transfer\.packet\)/)
  assert.match(peerStreamNext, /=\(src\.bowl our\.bowl\)/)
  assert.match(peerStreamGrown, /=\(src\.bowl our\.bowl\)/)
})

test('transfer-id capability negotiation preserves the legacy request wire and pack fallback', () => {
  assert.match(peerTypes, /\+\$  request\s+[\s\S]*?transfer=@uv[\s\S]*?repository=@t[\s\S]*?haves=\(set oid:git\)/)
  assert.doesNotMatch(peerTypes, /\+\$  request[\s\S]*?capabilit/)
  assert.match(transferLib, /\+\+  peer-object-capability\s+0x7572\.6769\.742d\.6132/)
  assert.match(arm(transferLib, 'peer-object-capable'), /\+\+  peer-object-capable[\s\S]*?\(cut 0 \[128 64\] transfer\)/)
  assert.match(arm(transferLib, 'peer-object-transfer'), /\+\+  peer-object-transfer[\s\S]*?\(mix \(cut 0 \[0 128\] transfer\) \(lsh \[0 128\] peer-object-capability\)\)/)
  assert.match(backend, /=\/  raw-transfer=@uv[\s\S]*?=\/  transfer=@uv\s+\(peer-object-transfer raw-transfer\)/)
  assert.match(peerPrepare, /capable=\?/)
  assert.match(peerPrepare, /capable=\?\s+\(peer-object-capable transfer\.req\)/)
  assert.match(peerPrepare, /object-count=@ud\s+\(lent objects\)/)
  // Serving is chunked unconditionally: there is no %archive branch and no
  // routing heuristic in front of it. %archive survives only on the receive
  // side, for peers that still serve it.
  assert.doesNotMatch(peerPrepare, /directed=\?/)
  assert.doesNotMatch(peerPrepare, /peer-directed/)
  assert.doesNotMatch(peerPrepare, /%archive-ready/)
  assert.match(peerPrepare, /\?\.  streamable[\s\S]*?peer-object-pages objects/)
  assert.match(peerPrepare, /flight=peer-serve[\s\S]*?%pack/)
  assert.match(arm(transferLib, 'peer-fine-name'), /\+\+  peer-fine-name[\s\S]*?\(cut 0 \[0 64\] transfer\)/)
  assert.equal(peerDirected, '')
})

test('transfer modes and stream jobs are transient and reset on init and load', () => {
  assert.match(type(transferLib, 'peer-transfer-mode'), /\+\$  peer-transfer-mode\s+\?\(%archive %pack %objects\)/)
  assert.match(type(transferLib, 'peer-serve'), /\+\$  peer-serve[\s\S]*?mode=peer-transfer-mode/)
  assert.match(type(transferLib, 'peer-serve'), /\+\$  peer-serve[\s\S]*?bytes=@ud[\s\S]*?sent=\?/)
  assert.match(
    type(transferLib, 'peer-object-assembly'),
    /\+\$  peer-object-assembly\s+\[kind=object-kind:git total=@ud next=@ud data=octs\]/,
  )
  assert.match(
    type(transferLib, 'peer-receive'),
    /\+\$  peer-receive[\s\S]*?mode=peer-transfer-mode[\s\S]*?expected-bytes=@ud[\s\S]*?pending-pages=\(map @ud \(list object-fragment:git-peer\)\)[\s\S]*?assemblies=\(map oid:git peer-object-assembly\)/,
  )
  assert.match(
    type(transferLib, 'peer-stream-job'),
    /\+\$  peer-stream-job[\s\S]*?target=ship[\s\S]*?transfer=@uv[\s\S]*?repository=@t[\s\S]*?head=@t[\s\S]*?refs=\(map @t oid:git\)[\s\S]*?expected=@ud[\s\S]*?pages=@ud[\s\S]*?revision=@ud[\s\S]*?remaining=\(list \[oid:git object:git\]\)[\s\S]*?offset=@ud[\s\S]*?begun=\?/,
  )
  assert.match(backend, /=\/  peer-stream-jobs\s+\*\(map @uv peer-stream-job\)/)
  assert.match(onInit, /peer-stream-jobs ~/)
  assert.match(gaps(onLoad), /(?:^|  )peer-stream-jobs  ~(?=  |$)/)
  assert.equal(onSave.trimEnd(), '++  on-save\n  !>(state)\n::')
  assert.doesNotMatch(onSave, /peer-stream-jobs/)
})

test('transfer constructors explicitly retain their transport mode', () => {
  const serveConstructors = [...backend.matchAll(/=\/  flight=peer-serve\s+([^\n]+)/g)]
  assert.ok(serveConstructors.length >= 1)
  assert.ok(serveConstructors.some(({ 1: fields }) => /\[target transfer\.req repository\.req %objects/.test(fields)))
  // No %archive serve constructor: the serving side never mints one.
  assert.doesNotMatch(peerPrepare, /archive-flight=peer-serve/)

  const receiveConstructors = [...backend.matchAll(/=\/  flight=peer-receive\s*\n\s+:\*([\s\S]*?)\n\s+==/g)]
  assert.equal(receiveConstructors.length, 2)
  for (const constructor of receiveConstructors) {
    assert.match(constructor[1], /\s+%pack\s+/)
  }
})

test('object page v2 uses a list of bounded fragments instead of a map', () => {
  assert.match(
    peerTypes,
    /\+\$  object-fragment\s+\[oid=oid:git kind=object-kind:git total=@ud offset=@ud data=octs\]/,
  )
  assert.match(
    peerTypes,
    /\[%object-fragments transfer=@uv revision=@ud fragments=\(list object-fragment\)\]/,
  )
  assert.match(peerObjectBatch, /batch=\(list object-fragment:git-peer\)/)
  assert.doesNotMatch(peerObjectBatch, /batch=\(map oid:git object:git\)/)
  assert.match(peerStreamNext, /noun\+!>\(batch\.taken\)/)
})

test('batch helpers enforce one-MiB fragments and one-MiB pages lazily', () => {
  assert.match(transferLib, /\+\+  peer-stream-page-max-fragments\s+512/)
  assert.match(transferLib, /\+\+  peer-stream-page-max-bytes\s+1\.048\.576/)
  assert.match(peerObjectBatchCount, /\|=  objects=\(list \[oid:git object:git\]\)/)
  assert.match(peerObjectBatchCount, /=\(count peer-stream-page-max-fragments\)/)
  assert.match(peerObjectBatchCount, /1\.048\.576/)
  assert.match(peerObjectBatchCount, /=\(bytes peer-stream-page-max-bytes\)/)
  assert.match(peerObjectBatchCount, /sub total offset/)
  assert.match(peerObjectBatchCount, /fragment-length=@ud[\s\S]*?\(min 1\.048\.576 \(sub total offset\)\)/)
  assert.match(peerObjectBatchCount, /page-room=@ud[\s\S]*?\(sub peer-stream-page-max-bytes bytes\)/)
  assert.match(peerObjectBatchCount, /\(gth fragment-length page-room\)/)
  assert.doesNotMatch(peerObjectBatchCount, /object-fragment:git-peer|\[oid kind total offset/)

  assert.match(peerObjectBatch, /\|=  \[objects=\(list \[oid:git object:git\]\) offset=@ud\]/)
  assert.match(peerObjectBatch, /batch=\(list object-fragment:git-peer\)/)
  assert.match(peerObjectBatch, /remaining=\(list \[oid:git object:git\]\)/)
  assert.match(peerObjectBatch, /offset=@ud/)
  assert.match(peerObjectBatch, /=\(count peer-stream-page-max-fragments\)/)
  assert.match(peerObjectBatch, /1\.048\.576/)
  assert.match(peerObjectBatch, /=\(bytes peer-stream-page-max-bytes\)/)
  assert.match(peerObjectBatch, /slice:git-codec data\.object offset length/)
  assert.match(peerObjectBatch, /fragment-length=@ud[\s\S]*?\(min 1\.048\.576 \(sub total offset\)\)/)
  assert.match(peerObjectBatch, /\(gth fragment-length page-room\)/)
  assert.match(peerObjectBatch, /\[oid kind total offset fragment-data\]/)
  assert.match(peerObjectBatch, /\(flop batch\)/)

  const streamedSource = [
    peerObjectBatchCount,
    peerObjectBatch,
    peerObjectPrepare,
    peerStreamNext,
    peerStreamGrown,
  ].join('\n')
  assert.doesNotMatch(streamedSource, /encode-pack:git-pack|peer-object-pages/)
})

test('stream preparation stores an object job and schedules its first event without pre-growing', () => {
  assert.match(peerPrepare, /peer-object-batch-count objects/)
  assert.match(peerObjectPrepare, /flight=peer-serve[\s\S]*?%objects/)
  assert.match(peerObjectPrepare, /job=peer-stream-job/)
  assert.match(peerObjectPrepare, /peer-stream-jobs\s+\(~\(put by peer-stream-jobs\) transfer\.req job\)/)
  assert.match(gaps(peerObjectPrepare), /%\^  peer-card  our\.bowl  [\s\S]*?\[%stream-next transfer\.req\]/)
  assert.match(peerObjectPrepare, /\/peer\/serve-timeout\//)
  assert.doesNotMatch(peerObjectPrepare, /(?:\[|:\*\s+)%ready\s+transfer\.req|%grow\s+snapshot-path/)
})

test('each stream-next builds and grows exactly one bounded fragment list then yields', () => {
  assert.match(peerStreamNext, /~\(get by peer-stream-jobs\) transfer/)
  assert.match(peerStreamNext, /~\(get by peer-serving\) transfer/)
  assert.match(peerStreamNext, /=\(%objects mode\.u\.serving\)/)
  assert.match(peerStreamNext, /peer-object-batch remaining\.job offset\.job/)
  assert.equal((peerStreamNext.match(/peer-object-batch remaining\.job offset\.job/g) || []).length, 1)
  assert.equal((peerStreamNext.match(/%grow/g) || []).length, 1)
  assert.match(peerStreamNext, /\/fine\/\(peer-fine-name transfer\)/)
  assert.match(peerStreamNext, /noun\+!>\(batch\.taken\)/)
  assert.match(peerStreamNext, /remaining remaining\.taken/)
  assert.match(peerStreamNext, /offset offset\.taken/)
  const grow = peerStreamNext.indexOf('%grow')
  const grown = peerStreamNext.indexOf('[%stream-grown transfer]')
  assert.ok(grow !== -1 && grown > grow, 'stream-grown self poke must follow the grow card')
})

test('stream-grown advances the job and announces begin-objects only after page one', () => {
  assert.match(peerStreamGrown, /~\(get by peer-stream-jobs\) transfer/)
  assert.match(peerStreamGrown, /~\(get by peer-serving\) transfer/)
  assert.match(peerStreamGrown, /=\(%objects mode\.u\.serving\)/)
  assert.doesNotMatch(peerStreamGrown, /peer-object-batch|%grow/)
  assert.match(peerStreamGrown, /revision \+\(revision\.job\)/)
  assert.match(peerStreamGrown, /begun %.y/)
  assert.match(gaps(peerStreamGrown), /:\*  %begin-objects  transfer  repository\.job  revision\.job  head\.job  refs\.job  expected\.job  pages\.job  ==/)
  assert.match(peerStreamGrown, /peer-card our\.bowl[\s\S]*?\[%stream-next transfer\]/)
  assert.match(peerStreamGrown, /peer-stream-jobs\s+\(~\(put by peer-stream-jobs\) transfer next\)/)
  assert.doesNotMatch(peerStreamGrown, /%behn|%wait/)
})

test('begin-objects mirrors begin validation, selects object mode, and fills the receive window', () => {
  assert.match(peerBeginObjects, /=\(src\.bowl source\.u\.found\)/)
  assert.match(peerBeginObjects, /=\(repository\.msg source-repository\.u\.found\)/)
  assert.match(peerBeginObjects, /\(gth pages\.msg 0\)/)
  assert.doesNotMatch(peerBeginObjects, /\(lte pages\.msg \(max 1 objects\.msg\)\)/)
  assert.match(gaps(peerBeginObjects), /(?:^|  )mode  %objects(?=  |$)/)
  assert.match(transferLib, /\+\+  peer-stream-window\s+8/)
  assert.match(peerBeginObjects, /turn\s+\(gulf 1 \(min pages\.msg peer-stream-window\)\)/)
  assert.match(peerBeginObjects, /\/g\/x\/\(scot %ud revision\)\/urgit\/\/1\/fine/)
  assert.match(peerBeginObjects, /%keen %.n src\.bowl scry-path/)
  assert.match(peerBeginObjects, /peer-snapshot transfer\.msg \(silt objects\.u\.serving\)/)
})

test('pack begin remains sequential and explicitly preserves pack mode', () => {
  assert.match(gaps(peerBegin), /(?:^|  )mode  %pack(?=  |$)/)
  assert.match(peerBegin, /\/g\/x\/1\/urgit\/\/1\/fine/)
  assert.match(peerBegin, /%keen %.n src\.bowl scry-path/)
})

test('Fine molds object fragment lists while retaining the exact pack fallback', () => {
  assert.match(fineHandler, /=\(%objects mode\.u\.found\)/)
  assert.match(fineHandler, /;;\(\(list object-fragment:git-peer\) \+\.q\.q\.sage\)/)
  assert.match(fineHandler, /\[%object-fragments u\.transfer u\.revision u\.fragments\]/)
  assert.match(fineHandler, /\+\(u\.revision\)/)

  assert.match(peerObjectPages, /encode-pack:git-pack/)
  assert.match(fineHandler, /=\(%pack mode\.u\.found\)/)
  assert.match(fineHandler, /;;\(octs \+\.q\.q\.sage\)/)
  assert.match(fineHandler, /decode-pack:git-pack-decode u\.packed/)
  assert.match(fineHandler, /\[%snapshot u\.transfer objects\.u\.decoded\]/)
})

test('release, snapshot failure, supersede, and serve timeout delete stream jobs', () => {
  assert.match(gaps(peerRelease), /(?:^|  )peer-stream-jobs  \(~\(del by peer-stream-jobs\) transfer\)/)
  assert.match(peerSnapshotFail, /peer-stream-jobs\s+\(~\(del by peer-stream-jobs\) transfer\)/)
  assert.match(peerPrepare, /peer-stream-jobs[\s\S]*?superseded-ids/)
  assert.match(peerPrepare, /~\(del by peer-stream-jobs\)/)
  assert.match(gaps(serveTimeout), /(?:^|  )peer-stream-jobs  \(~\(del by peer-stream-jobs\) u\.transfer\)/)
})

test('stream handlers no-op if either their job or object serving flight disappeared', () => {
  for (const streamArm of [peerStreamNext, peerStreamGrown]) {
    assert.match(streamArm, /~\(get by peer-stream-jobs\) transfer/)
    assert.match(streamArm, /\?~  found  `this/)
    assert.match(streamArm, /~\(get by peer-serving\) transfer/)
    assert.match(streamArm, /=\(%objects mode\.u\.serving\)/)
  }
})

test('both Fine modes reuse peer-snapshot OID validation and atomic finish', () => {
  assert.match(fineHandler, /\[%snapshot u\.transfer objects\.u\.decoded\]/)
  assert.match(peerSnapshot, /object-oid:git-codec kind\.object data\.object/)
  assert.match(peerSnapshot, /merge-objects objects\.flight incoming/)
  assert.match(peerSnapshot, /\?\.  =\(received\.next expected\.next\)\s+`this/)
  assert.match(peerSnapshot, /peer-finish transfer/)
})

test('fragment pages reject malformed bounds and duplicate oid/offset pairs before accounting', () => {
  assert.match(
    peerObjectFragments,
    /\|=  \[transfer=@uv revision=@ud fragments=\(list object-fragment:git-peer\)\]/,
  )
  // every page that passes the handler's own bounds goes through the extracted rules
  assert.match(pageHandler, /\(assemble-peer-fragments flight fragments\)/)
  assert.match(peerObjectFragments, /=\(\(lent fragments\) 0\)/)
  assert.match(peerObjectFragments, /\(gth \(lent fragments\) peer-stream-page-max-fragments\)/)
  assert.match(peerObjectFragments, /\(gth page-bytes peer-stream-page-max-bytes\)/)
  assert.match(peerObjectFragments, /\(gth total\.fragment 0\)/)
  assert.match(peerObjectFragments, /\(lth offset\.fragment total\.fragment\)/)
  assert.match(peerObjectFragments, /\(gth p\.data\.fragment 0\)/)
  assert.match(peerObjectFragments, /\(lte \(add offset\.fragment p\.data\.fragment\) total\.fragment\)/)
  assert.match(peerObjectFragments, /seen=\(set \[oid:git @ud\]\)/)
  assert.match(peerObjectFragments, /~\(has in seen\) \[oid\.fragment offset\.fragment\]/)
  assert.match(peerObjectFragments, /~\(put in seen\) \[oid\.fragment offset\.fragment\]/)
})

test('zero-length Git objects use one metadata-only fragment and remain content-addressed', () => {
  assert.match(peerObjectBatchCount, /=\(total 0\)/)
  assert.match(peerObjectBatch, /\[oid kind 0 0 \[0 0\]\]/)
  assert.match(peerObjectFragments, /=\(total\.fragment 0\)/)
  assert.match(peerObjectFragments, /=\(offset\.fragment 0\)/)
  assert.match(peerObjectFragments, /=\(p\.data\.fragment 0\)/)
  assert.match(peerObjectFragments, /=\(q\.data\.fragment 0\)/)
  assert.match(peerObjectFragments, /object-oid:git-codec kind\.fragment full-data/)
})

test('fragment reassembly is duplicate-safe, contiguous, metadata-stable, and content addressed', () => {
  assert.match(peerObjectFragments, /~\(has by objects\.next\) oid\.fragment/)
  assert.match(peerObjectFragments, /=\(kind\.fragment kind\.current\)/)
  assert.match(peerObjectFragments, /=\(total\.fragment total\.current\)/)
  assert.match(peerObjectFragments, /=\(offset\.fragment next\.current\)/)
  assert.match(peerObjectFragments, /join:git-codec data\.current data\.fragment/)
  assert.match(peerObjectFragments, /object-oid:git-codec kind\.fragment full-data/)
  assert.match(peerObjectFragments, /~\(put by assemblies\.next\) oid\.fragment/)
  assert.match(peerObjectFragments, /~\(del by assemblies\.next\) oid\.fragment/)
  assert.match(peerObjectFragments, /~\(put by objects\.next\) oid\.fragment \[kind\.fragment full-data\]/)
})

test('received counts only completed unique objects and final import remains atomic', () => {
  const completion = peerObjectFragments.indexOf('=(next-offset total.fragment)')
  const increment = peerObjectFragments.search(/received\s+\+\(received\.next\)/)
  assert.ok(completion !== -1 && increment > completion)
  assert.equal((peerObjectFragments.match(/received\s+\+\(received\.next\)/g) || []).length, 1)
  assert.match(peerObjectFragments, /\(lth received\.next expected\.next\)/)
  assert.match(peerObjectFragments, /all-pages=\?\s+=\(revision pages\.next\)/)
  assert.match(peerObjectFragments, /all-pages[\s\S]*?!=\(received\.next expected\.next\)[\s\S]*?\?=\(\^ assemblies\.next\)[\s\S]*?peer-finish transfer/)
  assert.match(peerObjectFragments, /next-request=@ud\s+\(add revision peer-stream-window\)/)
  assert.match(peerObjectFragments, /peer-finish transfer/)
})

test('out-of-order pages are cached and drained sequentially without reopening the transfer', () => {
  assert.match(peerObjectFragments, /expected-revision=@ud\s+\+\(~\(wyt in completed\.flight\)\)/)
  assert.match(peerObjectFragments, /pending-pages\.flight[\s\S]*?~\(put by pending-pages\.flight\) revision fragments/)
  assert.match(peerObjectFragments, /~\(get by pending-pages\.next\) next-revision/)
  assert.match(peerObjectFragments, /~\(del by pending-pages\.next\) next-revision/)
  assert.match(peerObjectFragments, /\/peer\/object-drain\/[\s\S]*?\[%object-fragments transfer next-revision u\.cached\]/)
})

test('hostile object announcements and partial assembly state have hard limits', () => {
  assert.match(transferLib, /\+\+  peer-stream-max-objects\s+25\.000/)
  assert.match(transferLib, /\+\+  peer-stream-max-pages\s+65\.536/)
  assert.match(transferLib, /\+\+  peer-stream-max-object-bytes\s+67\.108\.864/)
  assert.match(transferLib, /\+\+  peer-stream-max-assembly-bytes\s+67\.108\.864/)
  assert.match(transferLib, /\+\+  peer-archive-max-objects\s+250\.000/)
  assert.match(transferLib, /\+\+  peer-archive-max-bytes\s+1\.073\.741\.824/)
  assert.match(transferLib, /\+\+  peer-archive-max-object-bytes\s+536\.870\.912/)
  assert.match(type(transferLib, 'peer-receive'), /\+\$  peer-receive[\s\S]*?assemblies=\(map oid:git peer-object-assembly\)[\s\S]*?assembly-bytes=@ud/)
  assert.match(type(transferLib, 'peer-receive'), /\+\$  peer-receive[\s\S]*?assembly-bytes=@ud[\s\S]*?assembly-count=@ud/)
  assert.match(peerPrepare, /stream-pages=@ud\s+\(peer-object-batch-count objects\)/)
  assert.match(peerPrepare, /\(lte object-count peer-stream-max-objects\)/)
  assert.match(peerPrepare, /\(lte stream-pages peer-stream-max-pages\)/)
  assert.match(peerPrepare, /\(lte p\.data\.\+\.entry peer-stream-max-object-bytes\)/)
  // The archive bounds now guard only the receive side: a peer may still serve
  // us an %archive, and those limits are what keep an announcement honest.
  assert.doesNotMatch(peerPrepare, /peer-archive-max/)
  assert.match(peerArchiveReady, /\(gth objects\.msg peer-archive-max-objects\)/)
  assert.match(peerArchiveReady, /\(gth bytes\.msg peer-archive-max-bytes\)/)
  assert.match(peerArchive, /\(lte p\.data\.\+\.entry peer-archive-max-object-bytes\)/)
  assert.match(peerBeginObjects, /\(lte objects\.msg peer-stream-max-objects\)/)
  assert.match(peerBeginObjects, /\(lte pages\.msg peer-stream-max-pages\)/)
  // the reviewed peer correction (P4 stage 2, part C): an announced object takes
  // at most peer-stream-max-object-pages pages, ceil(64 MiB / 1 MiB), not 16
  assert.match(peerBeginObjects, /\(lte pages\.msg \(mul objects\.msg peer-stream-max-object-pages\)\)/)
  assert.doesNotMatch(peerBeginObjects, /\(mul objects\.msg 16\)/)
  assert.match(
    arm(transferLib, 'peer-stream-max-object-pages'),
    /\(div \(add peer-stream-max-object-bytes \(dec 1\.048\.576\)\) 1\.048\.576\)/,
  )
  assert.match(peerBeginObjects, /=\(revision\.msg 1\)/)
  assert.match(peerObjectFragments, /\(lte total\.fragment peer-stream-max-object-bytes\)/)
  assert.match(peerObjectFragments, /assembly-bytes\.next/)
  assert.match(peerObjectFragments, /peer-stream-max-assembly-bytes/)
  assert.match(peerObjectFragments, /assembly-count\.next/)
  assert.doesNotMatch(peerObjectFragments, /lent ~\(tap by assemblies\.next\)/)
  assert.match(peerObjectFragments, /assembly-bytes/)
  assert.match(peerObjectFragments, /\(lth next-offset total\.fragment\)[\s\S]*?!=\(p\.data\.fragment 1\.048\.576\)/)
})

test('Fine cancellation follows its mode while Mesa archives have no scries to cancel', () => {
  assert.match(peerTransferYawns, /mode=peer-transfer-mode/)
  assert.match(peerTransferYawns, /=\(%archive mode\)\s+~/)
  assert.match(peerTransferYawns, /=\(%objects mode\)/)
  assert.match(peerTransferYawns, /\(gulf 1 pages\)/)
  const objectBranch = peerTransferYawns.slice(
    peerTransferYawns.indexOf('=(%objects mode)'),
    peerTransferYawns.indexOf('=/  pending-pages'),
  )
  assert.match(objectBranch, /\(gulf 1 pages\)/)
  assert.match(objectBranch, /\(lte revision peer-stream-window\)/)
  assert.match(objectBranch, /\(sub revision peer-stream-window\)/)
  assert.match(objectBranch, /\?\.  issued  ~/)
})

test('streamed snapshots scale their source lifetime while Fine rates do not hide page stalls', () => {
  assert.match(peerServeLifetime, /mode=peer-transfer-mode/)
  assert.match(peerServeLifetime, /=\(%archive mode\)\s+~d1/)
  assert.match(peerServeLifetime, /=\(%objects mode\)/)
  assert.match(peerServeLifetime, /\(min ~d1 \(add ~m10 \(mul pages ~m2\)\)\)/)
  // %archive keeps its lifetime for inbound transfers; the serving side only
  // ever schedules the two chunked lifetimes.
  assert.doesNotMatch(peerPrepare, /peer-serve-lifetime %archive/)
  assert.match(peerPrepare, /peer-serve-lifetime %pack/)
  assert.match(peerPrepare, /peer-serve-lifetime %objects/)
  assert.match(rateHandler, /fine-progress/)
  assert.doesNotMatch(rateHandler, /progress-at now\.bowl/)
  assert.match(onArvo, /Fine repository read stalled without fragment progress/)
})

test('Mesa archives retain a distinct mode and validate negotiated object bounds', () => {
  assert.match(peerArchiveReady, /accepted\.flight/)
  assert.match(peerArchiveReady, /=\('' head\.flight\)/)
  assert.match(peerArchiveReady, /\(gth objects\.msg peer-archive-max-objects\)/)
  assert.match(peerArchiveReady, /\(gth bytes\.msg peer-archive-max-bytes\)/)
  assert.match(gaps(peerArchiveReady), /%=  flight  mode  %archive  [\s\S]*?expected  objects\.msg  [\s\S]*?expected-bytes  bytes\.msg/)
  assert.match(peerArchiveReady, /\[%archive-accept transfer\.msg\]/)
  assert.match(peerArchiveReady, /\/peer\/archive-timeout\//)
  assert.match(peerArchiveReady, /\(add now\.bowl ~d1\)/)

  assert.match(peerArchiveAccept, /=\(src\.bowl target\.flight\)/)
  assert.match(peerArchiveAccept, /=\(%archive mode\.flight\)/)
  assert.match(peerArchiveAccept, /=\(%\.n sent\.flight\)/)
  assert.match(peerArchiveAccept, /flight\(sent %\.y\)/)
  assert.match(peerArchiveAccept, /\[%archive transfer repository\.flight objects\.flight\]/)

  assert.match(peerArchive, /\(peer-object-capable transfer\)/)
  assert.match(peerArchive, /=\(%archive mode\.flight\)/)
  assert.match(peerArchive, /=\(count expected\.flight\)/)
  assert.match(peerArchive, /=\(bytes expected-bytes\.flight\)/)
  assert.match(peerArchive, /\(lte p\.data\.\+\.entry peer-archive-max-object-bytes\)/)
  assert.match(peerArchive, /incoming-map=\(map oid:git object:git\)\s+\(malt incoming\)/)
  assert.match(peerArchive, /=\(count \(lent ~\(tap by incoming-map\)\)\)/)
  assert.doesNotMatch(peerArchive, /peer-stream-max-objects|peer-stream-max-object-bytes/)
})

test('Mesa handshake separates preparation from bulk delivery timeouts', () => {
  // The serving side no longer announces an archive; %archive-ready is a
  // message we receive, not one we send.
  assert.doesNotMatch(peerPrepare, /(?:\[|:\*\s+)%archive-ready\s+transfer\.req/)
  assert.doesNotMatch(peerPrepare, /(?:\[|:\*\s+)%archive\s+transfer\.req/)
  assert.match(prepareTimeout, /accepted\.u\.found/)
  assert.match(prepareTimeout, /=\('' head\.u\.found\)/)
  assert.match(archiveTimeout, /=\(%archive mode\.u\.found\)/)
  assert.match(archiveTimeout, /repository archive transfer did not complete within one day/)
})
