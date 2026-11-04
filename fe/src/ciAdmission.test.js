import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// STATIC, on the agents' source (Delivery 1C): what may start a workflow
// run. An automatic event comes only from a write %urgit persisted,
// re-checked against %urgit's state; dependency resolution and its mirror
// repositories are maintenance, never a trigger, and the resolver's
// synthetic record is never planned, re-planned or re-run; a pull
// request's head follows its source branch in the event that moved it,
// and only the peer that opened a pull request updates it. These pin the
// guards; the native vectors (desk/gen/ci-*-vector) and the parent's live
// recipe exercise the behaviour.

const desk = (rel) => readFileSync(new URL(`../../desk/${rel}`, import.meta.url), 'utf8')
const controller = desk('app/urgit-ci.hoon')
const backend = desk('app/urgit.hoon')
const forge = desk('lib/ci-forge.hoon')

// the text of one arm: from `++  name` to the next arm at the same indent
function arm(source, name, indent = '') {
  const start = source.indexOf(`\n${indent}++  ${name}\n`)
  assert.notEqual(start, -1, `missing ++${name}`)
  const rest = source.slice(start + 1)
  const next = rest.slice(1).search(new RegExp(`\\n${indent}\\+[+$*]  `))
  return next === -1 ? rest : rest.slice(0, next + 1)
}
const has = (text, pattern, what) => assert.ok(pattern.test(text), `missing: ${what}`)
const before = (text, first, second, what) => {
  const a = text.indexOf(first)
  const b = text.indexOf(second)
  assert.ok(a !== -1 && b !== -1 && a < b, `out of order: ${what}`)
}

test('the resolver\'s synthetic record is no run: never planned, reset by a policy change or re-run', () => {
  has(arm(controller, 'resolver-record'), /=\('refs\/ci\/resolve' ref\.c\)/, 'the record is told by its refs/ci/resolve ref')
  has(controller, /%resolve-dependencies[\s\S]*?'refs\/ci\/resolve'/, 'resolve-dependencies records its resolve on refs/ci/resolve')
  has(arm(controller, 'schedule'), /!\(resolver-record candidate\)/, 'schedule never plans a resolve record')
  const bump = arm(controller, 'bump-generation')
  before(bump, '?:  (resolver-record c)  [cards.acc state]', '(reset-candidate c why)', 'a policy change skips the resolve record before any reset')
  const rerun = controller.slice(controller.indexOf('      %rerun-candidate\n'))
  before(rerun, '?:  (resolver-record old)', '(rerun-id repo.old ref.old head.old base.old)', 're-run refuses a resolve record')
  // an explicitly admitted shadow run plans as before: shadow is no proof
  assert.doesNotMatch(arm(controller, 'schedule'), /%shadow mode\.candidate/, 'schedule does not decide by shadow mode')
})

test('forge events come from persisted writes of a CI repository, never from a resolver\'s mirrors, and are checked against the ref now', () => {
  const admit = arm(controller, 'admit-forge-events')
  before(admit, '?.  (~(has by incarnations) repo.act)  (emit ~)', '(admit-push repo.act u actor.act route.act at.act)', 'an unconfigured repository records nothing')
  before(admit, '?:  (mirror-repository repo.act)  (emit ~)', '(admit-push repo.act u actor.act route.act at.act)', 'a mirror records nothing')
  const mirror = arm(controller, 'mirror-repository')
  has(mirror, /mirror-tokens/, 'a resolve in flight names its mirrors')
  has(mirror, /mirror\.n/, 'a lock names its mirrors')
  const push = arm(controller, 'admit-push')
  before(push, '?:  (~(has by event-ids) id.u)  [~ state]', '(verify-push repo u)', 'a replayed event is admitted once')
  before(push, '(verify-push repo u)', '(event-candidate id repo ref.u', 'a push is checked against the ref now before it runs')
  const pull = arm(controller, 'admit-pull')
  before(pull, '?:  (~(has by event-ids) id.p)  [~ state]', '(verify-pull repo p)', 'a replayed activity is admitted once')
  before(pull, '(verify-pull repo p)', '%:  event-candidate', 'an activity is checked against the record now before it runs')
  // the reports are %urgit's: scratch refs are never events
  has(arm(forge, 'ref-updates'), /\?:  \(scratch ref\)  ~/, 'refs/ci/ scratch refs are never reported')
})

test('synchronize: a local pull request follows its source branch in every event wrapper; a peer updates only its own open pull request', () => {
  const wrappers = backend.split('(follow-source-branches:ci-forge repos-before =>(next repositories) our.bowl)').length - 1
  assert.equal(wrappers, 3, 'on-poke, on-agent and on-arvo each sync before reporting')
  assert.equal(backend.split('(forge-cards:hc repos-before =>(synced repositories)').length - 1, 3, 'every report reads the synced repositories')
  assert.equal(backend.split('(forge-cards:hc repos-before =>(+.result repositories)').length - 1, 0, 'no report reads the unsynced ones')
  const follow = arm(forge, 'follow-source-branches')
  has(follow, /=\(%open state\.p\) =\(our source-ship\.p\) =\(name source-repository\.p\)/, 'only an open pull request this ship opened from this repository')
  has(follow, /\?:  =\(\(~\(get by refs\.u\.was\) source-ref\.p\) tip\)  p/, 'only a move this event made')
  has(follow, /\?~  tip  p/, 'a deleted branch leaves the head')
  const finish = backend.slice(backend.indexOf('      ++  finish-pull\n'), backend.indexOf('      ++  finish-push\n'))
  has(finish, /%:  open-pull-from:ci-forge\n\s+native-pulls\.u\.existing  source\.flight  source-repository\.flight/, 'the peer is the flight\'s Ames-authenticated source')
  before(finish, '?^  prior', '=/  number=@ud  (add 1 (lent native-pulls.u.existing))', 'an update is decided before a new pull request is numbered')
  // pull request labels added labeled and unlabeled after synchronize
  has(desk('lib/ci-trigger.hoon'), /\+\+  native-pull-types\n  `\(set @t\)`\(silt ~\['opened' 'reopened' 'closed' 'synchronize' 'labeled' 'unlabeled'\]\)/, 'synchronize, labeled and unlabeled are native activities now')
})
