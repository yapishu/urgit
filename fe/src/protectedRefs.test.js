// Q5 (restart 01): every writer of a CI-protected ref, traced to its actual
// mutation, and the push landing path (PUSH-LANDING-SCOPE-01). These are
// SOURCE-PATTERN assertions over the Hoon: they prove each writer's gate is
// present, in order, with its refusal and staging branches, and that no
// writer outside the census appears. They do not run Hoon. The on-ship rows
// that exercise the behavior are authored separately and NOT RUN under the
// restored-host hold, and so is desk/gen/ci-writer-vector, the offline
// fixtures for the gate's pure rules in desk/lib/ci-writer. The one behavior
// test here is the frontend helper.
import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import * as ci from './ci.js'
import { actionArm, arm, enclosingArms, entryGuard, gaps, importClosure, routeArm, wireArm } from './hoonSource.js'

const backend = readFileSync(new URL('../../desk/app/urgit.hoon', import.meta.url), 'utf8')
const controller = readFileSync(new URL('../../desk/app/urgit-ci.hoon', import.meta.url), 'utf8')
const repositoryView = readFileSync(new URL('./components/RepositoryView.jsx', import.meta.url), 'utf8')
// lib/ci-writer and its vector are read inside the tests that need them, so a
// missing file fails those tests alone
const readDesk = (rel) => readFileSync(new URL(`../../desk/${rel}`, import.meta.url), 'utf8')

function block(source, start, end, from = 0) {
  const startAt = source.indexOf(start, from)
  assert.notEqual(startAt, -1, `missing ${start}`)
  const endAt = source.indexOf(end, startAt + start.length)
  assert.notEqual(endAt, -1, `missing ${end} after ${start}`)
  return source.slice(startAt, endAt)
}

// `first` occurs in `text` and comes before `second`
function precedes(text, first, second, label) {
  const a = text.indexOf(first)
  const b = text.indexOf(second)
  assert.notEqual(a, -1, `${label}: missing ${first}`)
  assert.notEqual(b, -1, `${label}: missing ${second}`)
  assert.ok(a < b, `${label}: ${first} must come before ${second}`)
}

const count = (text, needle) => text.split(needle).length - 1

// the helper core's arms (the => core before the agent door), by name; a name
// is matched whole (`ci-stage` is a prefix of `ci-stages`)
const helper = (name) => arm(backend, name)

// every writer below is located by its arm and by the switch and guard that
// reach it; a missing one throws here, before any test runs
const setRef = actionArm(backend, 'set-ref')
const deleteRef = actionArm(backend, 'delete-ref')
// CI-RECOVERY-1: %urgit-ci's checkpoint commit
const writeRecovery = actionArm(backend, 'write-recovery-commit')
const publishDesk = actionArm(backend, 'publish-desk')
const branchCreate = routeArm(backend, 'repository-settings-api', 'post-repository-branches', 'POST', '[%apps %urgit %api %repository @ %branches ~]')
const branchDelete = routeArm(backend, 'repository-settings-api', 'delete-repository-branches', 'DELETE', '[%apps %urgit %api %repository @ %branches ~]')
const tagCreate = routeArm(backend, 'repository-settings-api', 'post-repository-tags', 'POST', '[%apps %urgit %api %repository @ %tags ~]')
const tagDelete = routeArm(backend, 'repository-settings-api', 'delete-repository-tags', 'DELETE', '[%apps %urgit %api %repository @ %tags ~]')
const publishRoute = routeArm(backend, 'repository-settings-api', 'post-repository-publish', 'POST', '[%apps %urgit %api %repository @ %publish ~]')
const peerFinish = arm(backend, 'on-poke/peer-finish')
// peer-finish sends a pull and a push to its own arms first; the fork install
// and refresh is the core's body, before those arms
const peerPush = arm(backend, 'on-poke/peer-finish/finish-push')
const forkAt = peerFinish.indexOf('|^')
const pullAt = peerFinish.indexOf('++  finish-pull')
if (forkAt === -1 || pullAt < forkAt) throw new Error('missing the |^ body of ++peer-finish')
const peerFork = peerFinish.slice(forkAt, pullAt)
if (!gaps(peerFork).includes('?:  =(%pull purpose.flight)  finish-pull  ?:  =(%push purpose.flight)  finish-push')) {
  throw new Error('++peer-finish does not send a pull and a push to their arms before the fork')
}
const clayPublish = wireArm(backend, '[%clay-publish ~]', 'clay-publish')
const clayReport = wireArm(backend, '[%clay-report ~]', 'clay-report')
const github = wireArm(backend, '[%github @ ~]', 'github-response')
const pushGate = arm(backend, 'on-poke/ci-gate-error')
const receivePack = arm(backend, 'on-poke/handle-receive-pack')
// the agent and every library and sur file it imports: a ref writer, or a
// caller of the shared writers, there is still %urgit's (apply-receive is
// lib/git-repository's); skeleton is base-dev's, staged at install
const deskSources = [['app/urgit.hoon', backend], ...importClosure('app/urgit.hoon', ['lib/skeleton.hoon'])]
const allSource = deskSources.map(([, text]) => text).join('\n')

// the writer a mutation on line i of `text` belongs to, in the census's words:
// a library or sur arm by name; on-poke's arms by name, except an action and
// an API route, named by the guard their arm asserts first and checked to be
// reached by it through the switches that run; an arvo handler by the wire
// its arm asserts first, checked the same way
function writerOf(rel, text, i) {
  const chain = enclosingArms(text, i)
  if (rel !== 'app/urgit.hoon') return chain[0]
  const [top, ...rest] = chain
  if (top === 'on-arvo') {
    const handler = arm(text, `on-arvo/${rest[0]}`)
    const { wire } = entryGuard(handler) ?? {}
    if (!wire || wireArm(text, wire, rest[0]) !== handler) throw new Error(`++${rest[0]} is not reached by the wire it asserts`)
    return `on-arvo ${wire}`
  }
  if (top !== 'on-poke') return top
  if (rest[0] === 'handle-action') {
    const action = arm(text, `on-poke/handle-action/${rest[1]}`)
    const { tag } = entryGuard(action) ?? {}
    if (!tag || actionArm(text, tag) !== action) throw new Error(`++${rest[1]} is not reached by the tag it asserts`)
    return `handle-action %${tag}`
  }
  if (rest[0] === 'handle-api') {
    // a route is handle-api's core's arm, handle-api/<core>/<route>; an arm
    // nested deeper is a helper in the route's own text (PR18's commit-merge
    // in post-repository-pulls-merge), reached only from inside it, so its
    // write is the route's
    const route = rest.slice(0, 3)
    const writer = arm(text, ['on-poke', ...route].join('/'))
    if (!writer.includes(arm(text, ['on-poke', ...rest].join('/')))) throw new Error(`++${rest.at(-1)} is not inside ++${route.at(-1)}`)
    const { method, path } = entryGuard(writer) ?? {}
    if (!method || routeArm(text, route.at(-2), route.at(-1), method, path) !== writer) {
      throw new Error(`++${route.at(-1)} is not reached by the route it asserts`)
    }
    return `handle-api ${method} ${path}`
  }
  return rest[0]
}

test('census: every ref mutation in %urgit belongs to a writer this test gates', () => {
  const sites = []
  for (const [rel, text] of deskSources) {
    text.split('\n').forEach((line, i) => {
      // a field assignment, never a read: `peer-valid-refs refs.flight` is not a write
      const mutation =
        /refs\s+\(~\((?:put|del) by refs\./.test(line) ||
        /(?:^|[\s(,])refs\s+(?:refs\.flight|next-refs|working)\b/.test(line) ||
        /^\s+(?:refs\.flight|next-refs)$/.test(line)
      if (mutation) sites.push(writerOf(rel, text, i))
    })
  }
  assert.deepEqual(sites.sort(), [
    'land-onto-current',
    'publish-repository',
    'peer-finish', 'peer-finish', 'peer-finish',
    'handle-action %set-ref',
    'handle-action %delete-ref',
    'handle-action %write-recovery-commit',
    'handle-api POST [%apps %urgit %api %repository @ %file *]',
    'handle-api DELETE [%apps %urgit %api %repository @ %file *]',
    'handle-api POST [%apps %urgit %api %repository @ %tags ~]',
    'handle-api POST [%apps %urgit %api %repository @ %tags ~]',
    'handle-api DELETE [%apps %urgit %api %repository @ %tags ~]',
    'handle-api POST [%apps %urgit %api %repository @ %pulls @ %merge ~]',
    'apply-receive',
    'materialize-candidate',
    'materialize-run',
    'on-arvo [%github @ ~]', 'on-arvo [%github @ ~]',
  ].sort())
})

// Delivery 1C: a pull request run is tested on an integration object
// %urgit builds and keeps under the run's own scratch ref. Its writer is
// reached only by this ship's own %urgit-ci, and the one ref it writes is
// computed from the run's id under refs/ci/run/, never the ref the poke
// names; scratch refs are never reported as forge events (lib/ci-forge)
test('census: materialize-run writes only the run\'s own scratch ref, for our own %urgit-ci', () => {
  const run = arm(backend, 'on-poke/materialize-run')
  assert.match(run, /=\/  scratch=@t  \(rap 3 ~\['refs\/ci\/run\/' \(scot %uv id\)\]\)/)
  assert.match(run, /refs  \(~\(put by refs\.u\.found\) scratch candidate\.outcome\)/)
  assert.equal(count(run, '(~(put by refs.'), 1, 'the run writes one ref')
  assert.equal(count(run, '(~(del by refs.'), 0, 'the run deletes no ref')
  const gate = block(backend, '          %ci-action\n', '          %handle-http-request')
  precedes(gate, '?>  =(src.bowl our.bowl)', '(materialize-run id.act repo.act ref.act head.act base.act)', 'only this ship pokes it')
  assert.match(readDesk('lib/ci-forge.hoon'), /\?:  \(scratch ref\)  ~/, 'a scratch ref is never reported as an event')
})

test('census: the shared ref-writing helpers are reached only from gated callers', () => {
  assert.equal(count(allSource, '(apply-receive '), 2)
  assert.equal(count(allSource, '(land-onto-current '), 2)
  assert.equal(count(allSource, '(publish-repository '), 2)
  assert.equal(count(receivePack, '(apply-receive '), 1)
  assert.equal(count(arm(backend, 'on-poke/land-through'), '(apply-receive '), 1)
  assert.equal(count(clayReport, '(land-onto-current '), 2)
  assert.equal(count(publishDesk, '(publish-repository '), 1)
  assert.equal(count(clayPublish, '(publish-repository '), 1)
})

test('the gate helpers read %urgit-ci behind its liveness guard and never advance a protected ref', () => {
  const protectedRead = helper('ci-ref-protected')
  precedes(protectedRead, '.^(? %gu (weld prefix /$))', '/ci-protected/(scot %t repo-name)/(scot %t ref)/noun', 'liveness before membership')
  assert.match(protectedRead, /\[%\| 'ci: %urgit-ci is not running; protected-ref writes are refused until it is'\]/)
  assert.match(protectedRead, /\[%\| 'ci: protection could not be read; the write is refused'\]/)

  // the rules are lib/ci-writer's; the helpers hand them this ship's reading
  const verdict = helper('ci-write-verdict')
  assert.match(verdict, /\^-  ci-write\n\s+%\+  classify:ci-writer  changes\n\s+\|=\(ref=@t \(ci-ref-protected repo-name ref\)\)\n/, 'every writer asks %urgit-ci, per ref, through the guarded read')
  assert.doesNotMatch(verdict, /eligible/, 'a writer never advances a protected ref itself, even for an eligible object')
  const refusal = helper('ci-write-refusal')
  assert.match(refusal, /\(refusal:ci-writer \(ci-write-verdict repo-name changes\)\)/)

  const stage = helper('ci-stage')
  assert.match(stage, /\?:\(\(repository-writable repo actor\) %trusted %untrusted\)/)
  assert.match(stage, /\(sham \[repo-name ref head base\]\)/)
  assert.match(stage, /\(sham \[repo-name ref head base %untrusted\]\)/)
  assert.match(stage, /\[%stage-candidate repo-name ref head base actor via ~\]/)

  const completion = helper('ci-completion-refusal')
  assert.match(completion, /\?:  =\(`new current\)  ~/, 'a completion that moves nothing is not gated')
  assert.match(completion, /\(ci-ref-protected repo-name ref\)/)
  assert.doesNotMatch(completion, /eligible/, 'a parked write that is not a landing never advances a protected ref')
})

test('lib/ci-writer: a protected change is staged or refused, never let through, and %urgit uses it', () => {
  // under their own faces, wherever they stand in the /+ lines
  const importEntries = backend.split('\n').filter((line) => line.startsWith('/+')).flatMap((line) => line.slice(2).split(',').map((entry) => entry.trim()))
  assert.ok(importEntries.includes('ci-candidate') && importEntries.includes('ci-writer'), '%urgit imports the lib')
  assert.match(backend, /\n\+\$  ci-write  ci-write:ci-writer\n/)
  assert.match(backend, /\n\+\+  ref-changes  ref-changes:ci-writer\n/)
  assert.match(backend, /\n\+\+  commit-contains  commit-contains:ci-writer\n/)
  const lib = readDesk('lib/ci-writer.hoon')
  assert.doesNotMatch(lib, /\.\^\(|%pass|card/, 'the rules read no ship and move nothing')
  const changes = block(lib, '++  ref-changes', '++  classify')
  assert.match(changes, /`\[before `tip ref\]/, 'a ref whose tip differs is a change; a new ref a creation')
  assert.match(changes, /\?:  \(~\(has by new\) ref\)  ~\n\s+`\[`tip ~ ref\]/, 'a ref the new map lacks is a deletion')
  const classify = block(lib, '++  classify', '++  refusal')
  assert.match(classify, /protection=\$-\(@t \(each \? @t\)\)/)
  assert.match(classify, /\?:  =\(old\.change new\.change\)\n\s+\$\(changes t\.changes\)/, 'an unchanged ref is not asked about')
  precedes(classify, '?:  =(old.change new.change)', '(protection ref.change)', 'unchanged skipped before the question')
  assert.match(classify, /\[%refuse 503 p\.protected\]/, 'an unreadable answer refuses the whole write')
  precedes(classify, '?~  new.change', '?~  old.change', 'deletion checked before creation')
  assert.match(classify, /\[%refuse 409 \(rap 3 ~\['ci-protected ref cannot be deleted: ' ref\.change\]\)\]/)
  assert.match(classify, /\[%refuse 409 \(rap 3 ~\['ci-protected ref has no tip to stage a candidate against: ' ref\.change\]\)\]/)
  assert.match(classify, /\$\(changes t\.changes, stages \[\[ref\.change u\.new\.change u\.old\.change\] stages\]\)/, 'a protected advance is staged against its tip')
  assert.match(classify, /\?~  stages  \[%open ~\]\n\s+\[%stage \(flop stages\)\]/)
  assert.doesNotMatch(classify, /eligible/, 'a writer never advances a protected ref itself, even for an eligible object')
  const refusal = block(lib, '++  refusal', '++  commit-contains')
  assert.match(refusal, /%open\s+~/)
  assert.match(refusal, /%refuse\s+`\[status\.gate message\.gate\]/)
  assert.match(refusal, /`\[409 \(rap 3 ~\['ci-protected ref advances only by landing a CI candidate or a recorded override: ' ref\]\)\]/, 'a writer that cannot stage refuses a protected advance')
})

test('W7 %set-ref: an owner poke never sets a CI-protected ref', () => {
  precedes(setRef, '(ci-write-refusal:hc repository.act ~[[old `oid.act ref.act]])', 'refs (~(put by refs.u.found) ref.act oid.act)', '%set-ref')
  assert.match(setRef, /\?\^  refusal  ~\|\(message\.u\.refusal !!\)/)
})

test('W20 %write-recovery-commit (CI-RECOVERY-1): a checkpoint commit passes the gate, moves only from its expected tip, and sends no webhook', () => {
  precedes(writeRecovery, '(ci-write-refusal:hc repository.act ~[[current `commit.act ref.act]])', 'refs (~(put by refs.u.found) ref.act commit.act)', '%write-recovery-commit')
  assert.match(writeRecovery, /\?\^  refusal  ~\|\(message\.u\.refusal !!\)/)
  precedes(writeRecovery, '?.  =(current expected.act)', 'refs (~(put by refs.u.found) ref.act commit.act)', 'the compare-and-swap')
  precedes(writeRecovery, '?:  public-read.u.found', 'refs (~(put by refs.u.found) ref.act commit.act)', 'a public repository is refused')
  precedes(writeRecovery, '(reachable:git-graph merged (silt ~[commit.act]))', 'refs (~(put by refs.u.found) ref.act commit.act)', 'the commit reaches a complete tree')
  assert.doesNotMatch(writeRecovery, /dispatch-webhooks/, 'a recovery write sends no webhook')
})

test('W8 %delete-ref: an owner poke never deletes a CI-protected ref', () => {
  precedes(deleteRef, '(ci-write-refusal:hc repository.act ~[[old ~ ref.act]])', '(~(del by refs.u.found) ref.act)', '%delete-ref')
  assert.match(deleteRef, /\?\^  refusal  ~\|\(message\.u\.refusal !!\)/)
})

test('W5/W6 web branches: a CI-protected branch is neither created nor deleted', () => {
  precedes(branchCreate, '(ci-write-refusal:hc name ~[[~ `u.source branch-ref]])', '(api-with-action eyre-id 201 [%set-ref name branch-ref u.source])', 'branch create')
  assert.match(branchCreate, /\(api-error eyre-id status\.u\.refusal message\.u\.refusal\)/)
  precedes(branchDelete, '(ci-write-refusal:hc name ~[[(~(get by refs.u.found) branch-ref) ~ branch-ref]])', '(api-with-action eyre-id 200 [%delete-ref name branch-ref])', 'branch delete')
  assert.match(branchDelete, /\(api-error eyre-id status\.u\.refusal message\.u\.refusal\)/)
})

test('W9/W10 web tags: a CI-protected tag is neither created nor deleted', () => {
  precedes(tagCreate, '(ci-write-refusal:hc name ~[[~ (~(get by refs.applied) tag-ref) tag-ref]])', '=.  repositories  (~(put by repositories) name applied)', 'tag create')
  assert.match(tagCreate, /\(api-error eyre-id status\.u\.refusal message\.u\.refusal\)/)
  precedes(tagDelete, '(ci-write-refusal:hc name ~[[(~(get by refs.u.found) tag-ref) ~ tag-ref]])', '(~(del by refs.u.found) tag-ref)', 'tag delete')
  assert.match(tagDelete, /\(api-error eyre-id status\.u\.refusal message\.u\.refusal\)/)
})

test('W11/W12 publication: a CI-protected bound branch is staged, never written', () => {
  // the route: unreadable CI refuses now; a protected branch says staged
  precedes(publishRoute, '(ci-ref-protected:hc name branch)', '(handle-action [%publish-desk name u.message])', 'publish route')
  assert.match(publishRoute, /\(api-error eyre-id 503 p\.protected\)/)
  assert.match(publishRoute, /\['staged' b\+p\.protected\]/)
  assert.doesNotMatch(publishRoute, /api-with-action eyre-id 202 \[%publish-desk/)
  // the immediate publication (an empty desk) and the completion, in the
  // event that writes
  for (const [label, text, repo, current] of [
    ['immediate', publishDesk, 'repository.job', 'u.found'],
    ['completion', clayPublish, 'repository.next-job', 'u.current'],
  ]) {
    precedes(text, `ci-write-verdict:hc  ${repo}`, `(~(put by repositories) ${repo} u.published)`, label)
    assert.match(text, new RegExp(`\\(ci-stages:hc ${repo.replace('.', '\\.')} ${current.replace('.', '\\.')} stages\\.gate our\\.bowl %session\\)`), `${label} stages as this ship`)
    assert.match(text, new RegExp(`${current.replace('.', '\\.')}\\(objects objects\\.u\\.published\\)`), `${label} keeps the snapshot's objects, not its ref`)
  }
})

test('W13 peer push: a CI-protected default branch is staged with the pushing ship as actor', () => {
  precedes(peerPush, "'update is not a fast-forward'", '(ci-write-verdict:hc local-repository.flight ~[[previous `u.incoming head.u.existing]])', 'fast-forward first')
  precedes(peerPush, '(ci-write-verdict:hc local-repository.flight ~[[previous `u.incoming head.u.existing]])', '=/  updated=repository:git', 'peer push gate before the write')
  assert.match(peerPush, /\(peer-push-finish flight transfer %\.n message\.gate\)/)
  assert.match(peerPush, /\(ci-stages:hc local-repository\.flight u\.existing stages\.gate source\.flight %session\)/)
  assert.match(peerPush, /u\.existing\(objects \(merge-objects objects\.u\.existing objects\.flight\)\)/)
})

test('W14 fork install and refresh: gated whole, protected updates staged, nothing else moves', () => {
  precedes(peerFork, '(ref-changes ?~(existing ~ refs.u.existing) refs.flight)', '=/  repo=repository:git', 'fork gate before the install')
  assert.match(peerFork, /\[%\.n message\.gate local-repository\.flight\]/)
  assert.match(peerFork, /\(ci-stages:hc local-repository\.flight u\.existing stages\.gate our\.bowl %session\)/)
  assert.match(peerFork, /u\.existing\(objects \(merge-objects objects\.u\.existing objects\.flight\)\)/)
})

test('W15 GitHub import and update: gated whole, protected updates staged, nothing else moves', () => {
  precedes(github, '=/  next-refs=(map @t oid:git)', '(ref-changes ?~(existing ~ refs.u.existing) next-refs)', 'next-refs first')
  precedes(github, '(ref-changes ?~(existing ~ refs.u.existing) next-refs)', 'u.existing(head head.u.context, refs next-refs', 'github gate before the write')
  assert.match(github, /\(fail message\.gate\)/)
  assert.match(github, /\(ci-stages:hc repository\.u\.context u\.existing stages\.gate our\.bowl %session\)/)
  assert.match(github, /u\.existing\(objects combined\)/)
})

test('W19 the parked non-CI completion refuses a branch that became CI-protected', () => {
  const ciBranch = block(clayReport, '?^  ci-land', '=/  refusal=(unit @t)')
  precedes(clayReport, '=/  refusal=(unit @t)', '?.  ok.result  repositories', 'refusal before the write')
  assert.match(clayReport, /ci-completion-refusal:hc/)
  assert.match(clayReport, /=\?  result  \?=\(\^ refusal\)  \^-\(\[ok=\? message=@t\] \[%\.n u\.refusal\]\)/)
  assert.ok(ciBranch.length > 0)
})

test('W1 push: a protected advance lands only through the landing path, alone, from its exact authority', () => {
  assert.doesNotMatch(pushGate, /eligible-at/, 'the push gate no longer lets an eligible command through the receive path')
  assert.match(pushGate, /\/landing-for\/\(scot %t repo-name\)\/\(scot %t ref\.command\)/)
  assert.match(pushGate, /;;\(\(unit \[id=@uv pull=\(unit @ud\)\]\)/)
  precedes(pushGate, '.^(? %gu (weld prefix /$))', '/landing-for/', 'liveness before the authority read')
  assert.match(pushGate, /\?\.  \?=\(\[\* ~\] commands\)/, 'a landing must be the push\'s only command')
  assert.match(pushGate, /\[%land id\.u\.p\.authority pull\.u\.p\.authority ref\.command u\.new\.command u\.old\.command\]/)
  assert.match(pushGate, /\[%refuse 'ci-protected branch cannot be deleted'\]/)
  assert.match(pushGate, /\[%refuse 'ci-protected branch has no tip to stage a candidate against'\]/)
  // the caller: staged objects join the store, the branch rules still hold,
  // and the landing path answers the push
  precedes(receivePack, '(ci-gate-error repo-name u.found commands.u.parsed)', '?:  ?=(%land -.gate)', 'push gate first')
  const land = block(receivePack, '?:  ?=(%land -.gate)', '=/  policy-error=(unit @t)')
  precedes(land, '(receive-policy-error u.found commands.u.parsed u.staged)', '(land-through id.gate repo-name ref.gate new.gate old.gate pull.gate `eyre-id)', 'branch rules before the landing')
})

test('the landing path binds the tip, requires descent, answers a push, and records the landing', () => {
  const landCandidate = arm(backend, 'on-poke/land-candidate')
  assert.match(landCandidate, /\(land-through id repo-name ref candidate expected pull ~\)/)
  const through = arm(backend, 'on-poke/land-through')
  precedes(through, '/eligible-at/', '=(`expected (~(get by refs.u.found) ref))', 'eligibility then the tip')
  precedes(through, '=(`expected (~(get by refs.u.found) ref))', '(commit-contains objects.u.found candidate expected)', 'the tip then descent')
  precedes(through, '(commit-contains objects.u.found candidate expected)', '(apply-receive u.found commands ~)', 'descent before the write')
  assert.equal(count(through, '(accept-receive push repo-name commands landed '), 2, 'both same-event landings answer the push')
  assert.match(through, /\(fall push ''\)/, 'a parked landing carries the push to its completion')
  assert.match(through, /\[%land-refused id reason\]/)
  assert.match(through, /\[%landed id\]/)
  // the parked completion: the same predicate, the tip, and descent, in the
  // event that moves the ref; the push is answered there
  const ciBranch = block(clayReport, '?^  ci-land', '=/  refusal=(unit @t)')
  precedes(ciBranch, '=(`expected.land (~(get by refs.u.current) branch.pending))', '/eligible-at/', 'tip then predicate')
  precedes(ciBranch, '/eligible-at/', '(commit-contains objects.applied.pending new-oid.pending expected.land)', 'predicate then descent')
  precedes(ciBranch, '(commit-contains objects.applied.pending new-oid.pending expected.land)', '(land-onto-current u.current applied.pending branch.pending new-oid.pending pull.land)', 'descent before the write')
  assert.match(ciBranch, /\?:  =\('' eyre-id\.pending\)  ~/)
  assert.match(ciBranch, /\(receive-payload 'ok' \(receive-results commands\.pending \?=\(~ reason\) \(fall reason ''\)\)\)/)
  const dropped = block(clayReport, '=/  dropped', '?^  error.sign-arvo')
  assert.match(dropped, /eyre-id\.pending/, 'a dropped parked push landing still answers the push')
})

test('commit-contains walks parent links and stops at the tip', () => {
  const contains = block(readDesk('lib/ci-writer.hoon'), '++  commit-contains', '\n--')
  assert.match(contains, /commit-parents:ci-candidate objects i\.pending/)
  assert.match(contains, /\?:  =\(ancestor i\.pending\)  %\.y/)
  assert.match(contains, /\?~  parents  %\.n/, 'a missing or malformed commit refuses')
})

test('ci-writer-vector: offline fixtures for the gate, imports and forks, with intentionally false cases', () => {
  const vector = readDesk('gen/ci-writer-vector.hoon')
  assert.match(vector, /^\/\+  ci-writer, git-codec$/m)
  assert.doesNotMatch(vector, /\.\^\(|%iris|github\.com|https?:/, 'no ship read and no network: offline fixtures only')
  for (const arm of ['ref-changes', 'classify', 'refusal', 'commit-contains']) {
    assert.match(vector, new RegExp(`\\(${arm}:ci-writer `), `the vector exercises ${arm}`)
  }
  for (const fixture of [
    'a protected deletion is refused',
    'a protected creation is refused: it has no tip to stage against',
    'an outage refuses an unprotected change too',
    'GitHub update fixture: the protected fast-forward is staged, the new branch is not',
    'fork refresh fixture: a protected branch the origin lacks refuses the refresh',
    'fork install fixture: a protection left on the name refuses the install',
    'a walk through a missing parent finds the tip',
  ]) assert.ok(vector.includes(`'${fixture}'`) || vector.includes(`'intentionally false: ${fixture}'`), `fixture: ${fixture}`)
  const falseCases = vector.split('\n').filter((line) => line.includes("'intentionally false: "))
  assert.equal(falseCases.length, 9, 'nine intentionally false cases')
  for (const line of falseCases) assert.match(line, /'intentionally false: [^']*' %\.n /, `expects refusal: ${line.trim()}`)
  assert.match(vector, /\?:\(=\(expect got\) ~ `name\)/, 'a case fails when its verdict differs from the one it names')
  assert.match(vector, /~&  \(crip "passed=\{<passed>\} of=\{<\(lent cases\)>\}"\)\n\?=\(~ failed\)\n$/)
})

test('%urgit-ci: one tip-bound predicate and the exact landing authority', () => {
  const landingFor = block(controller, '++  landing-for', '++  live-override')
  assert.match(landingFor, /=\(u\.tip base\.c\)/, 'a candidate lands only onto its own base')
  assert.match(landingFor, /\(landable c\)/)
  assert.match(landingFor, /=\(u\.oid u\.candidate\.c\)/)
  assert.match(landingFor, /=\(repo repo\.c\)/)
  assert.match(landingFor, /=\(ref ref\.c\)/)
  assert.match(landingFor, /\(live-override repo ref u\.oid u\.tip\)/)
  const eligibleAt = block(controller, '++  eligible-at', '++  landing-for')
  assert.match(eligibleAt, /\?=\(\^ \(landing-for repo-segment ref-segment oid-segment tip-segment\)\)/)
  assert.doesNotMatch(eligibleAt, /\(eligible repo-segment/, 'the tip-independent rule is no longer a landing predicate')
  assert.match(controller, /\[%x %landing-for @ @ @ @ ~\]\n\s+``noun\+!>\(\(landing-for:hc /)
})

test('the publication answer reads as staged in the UI, never as committed', () => {
  assert.equal(typeof ci.stagedPublishNote, 'function', 'ci.js exports stagedPublishNote')
  const { stagedPublishNote } = ci
  const staged = { ok: true, staged: true, ref: 'refs/heads/main' }
  assert.match(stagedPublishNote(staged), /^Publishing to main stages a CI candidate instead of committing: main is CI-protected/)
  assert.match(stagedPublishNote(staged), /until the candidate's checks pass and it lands/)
  assert.match(stagedPublishNote({ ok: true, staged: true }), /the branch is CI-protected/)
  assert.equal(stagedPublishNote({ ok: true, staged: false, ref: 'refs/heads/main' }), '')
  assert.equal(stagedPublishNote({ ok: true }), '')
  assert.equal(stagedPublishNote(null), '')
  const settings = block(repositoryView, 'function Settings', 'export default function RepositoryView')
  assert.match(settings, /stagedPublishNote\(await api\.publish\(repo\.name, message\.trim\(\)\)\)/)
  assert.match(settings, /\{publishNote && <div className="field-note">\{publishNote\}<\/div>\}/)
})
