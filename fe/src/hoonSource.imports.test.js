// hoonSource's import reading: every /- and /+ entry, transitively, once; and
// a missing, ambiguous or unsupported import, or a misused external, fails
// closed instead of shortening the closure. The desks under
// fixtures/hoon-reader/desks parse with the pinned hoon-lint, except
// unsupported-entry, whose entry the parser rejects too.
import test from 'node:test'
import assert from 'node:assert/strict'
import { gaps, importClosure, imports } from './hoonSource.js'

const desk = (name) => new URL(`fixtures/hoon-reader/desks/${name}/`, import.meta.url)
const closure = (name, external = []) => importClosure('app/a.hoon', external, desk(name)).map(([rel]) => rel)

test('the closure follows every /- and /+ import, transitively, once', () => {
  assert.deepEqual(imports('app/a.hoon', desk('complete')), ['sur/s.hoon', 'lib/x.hoon', 'lib/y.hoon', 'lib/w.hoon'])
  assert.deepEqual(closure('complete'), ['sur/s.hoon', 'lib/x.hoon', 'lib/v.hoon', 'lib/y.hoon', 'lib/w.hoon'])
})

test('a library imported twice is read once', () => {
  assert.deepEqual(closure('duplicate'), ['lib/m.hoon'])
})

test('a comment on an import line is not an entry', () => {
  assert.deepEqual(closure('comment'), ['lib/x.hoon'])
})

test('a missing import fails closed', () => {
  assert.throws(() => closure('missing'), /missing import lib\/gone\.hoon/)
})

test('the named external is allowed only while the desk lacks it and something imports it', () => {
  assert.deepEqual(closure('external', ['lib/skeleton.hoon']), ['lib/d.hoon'])
  assert.throws(() => closure('external'), /missing import lib\/skeleton\.hoon/)
  assert.throws(() => closure('external-carried', ['lib/skeleton.hoon']), /named external, but the desk carries it/)
  assert.throws(() => closure('unused-external', ['lib/skeleton.hoon']), /named external, but nothing imports it/)
})

test('a Ford rune other than /- and /+ fails closed', () => {
  assert.throws(() => closure('unsupported-rune'), /a Ford import this reader does not read/)
})

test('a malformed import entry fails closed', () => {
  assert.throws(() => closure('unsupported-entry'), /an import entry this reader does not read: '9lives'/)
})

test('a name the desk could also read as a hyphen-split path is ambiguous', () => {
  assert.throws(() => closure('ambiguous'), /lib\/foo-bar\.hoon is ambiguous: the desk also has lib\/foo\/bar\.hoon/)
})

// Delivery 1C: %urgit imports lib/ci-changes (the changed paths of its own
// objects, for %urgit-ci's peeks) and lib/ci-forge (the report of each
// persisted write); the closure is otherwise unchanged
test("the agent's closure is exactly its 36 libraries and 3 sur files, each of which lexes", () => {
  const files = importClosure('app/urgit.hoon', ['lib/skeleton.hoon'])
  assert.deepEqual(files.map(([rel]) => rel).sort(), [
    'lib/ci-candidate.hoon', 'lib/ci-changes.hoon', 'lib/ci-forge.hoon', 'lib/ci-writer.hoon', 'lib/dbug.hoon', 'lib/default-agent.hoon', 'lib/git-access.hoon',
    'lib/git-archive.hoon', 'lib/git-blame.hoon', 'lib/git-catalog.hoon', 'lib/git-clay-history.hoon',
    'lib/git-clay-view.hoon', 'lib/git-clay.hoon', 'lib/git-codec.hoon', 'lib/git-delta.hoon', 'lib/git-format.hoon',
    'lib/git-github.hoon', 'lib/git-graph.hoon', 'lib/git-gzip.hoon', 'lib/git-http.hoon', 'lib/git-inflate.hoon',
    'lib/git-json.hoon', 'lib/git-lfs.hoon', 'lib/git-migrate.hoon', 'lib/git-pack-decode.hoon', 'lib/git-pack.hoon',
    'lib/git-peer-transfer.hoon', 'lib/git-profile.hoon', 'lib/git-protocol.hoon', 'lib/git-repository.hoon',
    'lib/git-storage.hoon', 'lib/git-tree.hoon', 'lib/git-upload.hoon', 'lib/git-webhook.hoon', 'lib/git-zlib.hoon',
    'lib/server.hoon', 'sur/ci.hoon', 'sur/git-peer.hoon', 'sur/git.hoon',
  ])
  for (const [rel, text] of files) assert.ok(gaps(text).length > 0, `${rel} lexes`)
})
