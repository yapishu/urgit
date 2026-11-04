import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { arm, deskText, gaps } from './hoonSource.js'

// CI-RECOVERY-1 (R5.2-A): the Hoon wiring, read from source. These are
// SOURCE-PATTERN assertions: they prove each guard is present, in order,
// in the arm that runs it. They do not run Hoon. The behaviour is run by
// desk/gen/ci-checkpoint-vector and desk/gen/ci-recovery-pause-vector on a
// ship, which are the parent's and NOT RUN here.

const controller = deskText('app/urgit-ci.hoon')
const forge = deskText('app/urgit.hoon')
const lib = deskText('lib/ci-checkpoint.hoon')
const fixtures = readFileSync(new URL('./ciRecoveryFixtures.js', import.meta.url), 'utf8')

// one case of handle-action's switch: from its tag to the next case
function actionCase(tag) {
  const actions = arm(controller, 'handle-action')
  const start = actions.indexOf(`\n      %${tag}\n`)
  assert.ok(start >= 0, `handle-action has no case %${tag}`)
  const rest = actions.slice(start + 1)
  const next = rest.slice(1).search(/\n {6}%[a-z]|\n {4}%[a-z]|\n {6}:: /)
  const body = next < 0 ? rest : rest.slice(0, next + 1)
  // the case ends at its last line of code, not at the comment rule after it
  return body.replace(/(\n\s*::[^\n]*)+\s*$/, '\n')
}

const before = (text, first, second, label) => {
  const a = text.indexOf(first)
  const b = text.indexOf(second)
  assert.ok(a >= 0, `${label}: missing ${first}`)
  assert.ok(b >= 0, `${label}: missing ${second}`)
  assert.ok(a < b, `${label}: ${first} must come before ${second}`)
}

test('paused: the scheduler does nothing and sends no card, before it re-offers, resolves, joins or plans', () => {
  const schedule = arm(controller, 'schedule')
  before(schedule, '?:  ci-paused  [~ state polls]', '=.  state  reoffer-unfetched', 'schedule')
  before(schedule, '?:  ci-paused  [~ state polls]', 'advance-tags', 'schedule')
  before(schedule, '?:  ci-paused  [~ state polls]', '(create-attempt', 'schedule')
  assert.match(arm(controller, 'ci-paused'), /\?=\(\^ paused\.recovery\)/)
})

test('paused: no assignment is handed out, by delivery or by a poll, not even one made before the pause', () => {
  before(arm(controller, 'deliver'), '?:  ci-paused  [~ state polls]', '(give-json eyre-id.u.waiting 200', 'deliver')
  const poll = arm(controller, 'handle-assignment-poll')
  assert.match(gaps(poll), /=\/ {2}pending=\(list assignment:ci\) {2}\?: {2}ci-paused {2}~ {2}%\+ {2}skim/)
  before(poll, '?:  ci-paused  ~', '(assignment-json assignment candidate attempt)', 'handle-assignment-poll')
})

test('paused: nothing lands, by settle, by the landing peeks %urgit reads, or by an override', () => {
  const settle = arm(controller, 'settle')
  before(settle, '?:  ci-paused', '(emit (snoc (land-cards next) release))', 'settle')
  const paused = settle.slice(settle.indexOf('?:  ci-paused'), settle.indexOf('(emit (snoc (land-cards next) release))'))
  assert.doesNotMatch(paused, /land-cards/, 'the paused branch lands nothing')
  assert.match(paused, /Push the same commit again after CI resumes to land it/)
  assert.match(gaps(arm(controller, 'eligible')), /\^- {2}\? {2}\?: {2}ci-paused {2}%\.n {2}=\/ {2}repo=@t/)
  assert.match(gaps(arm(controller, 'landing-for')), /\?: {2}ci-paused {2}~ {2}=\/ {2}repo=@t/)
  before(actionCase('record-override'), '?:  ci-paused  ~|(paused-refusal:ci-checkpoint !!)', '[%land-candidate', '%record-override')
})

test('paused: every admission is refused with the pause reason before it records or sends anything', () => {
  for (const tag of ['stage-candidate', 'approve-candidate', 'rerun-candidate', 'assign', 'resolve-dependencies', 'approve-environment', 'stage-shadow', 'dispatch-workflow']) {
    const body = actionCase(tag)
    const guard = body.indexOf('?:  ci-paused  ~|(paused-refusal:ci-checkpoint !!)')
    assert.ok(guard >= 0, `%${tag} has no pause refusal`)
    for (const effect of ['=.  candidates', 'urgit-poke', 'urgit-git-poke', 'create-attempt', '(emit', 'schedule']) {
      const at = body.indexOf(effect)
      if (at >= 0) assert.ok(guard < at, `%${tag}: ${effect} comes before the pause refusal`)
    }
  }
  before(arm(controller, 'handle-dispatch'), '?:  ci-paused', '(admit-dispatch p.parsed)', 'handle-dispatch')
  assert.match(arm(lib, 'paused-refusal'), /'CI is paused for a restore: no run is admitted, offered or landed until it resumes'/)
})

test('paused: a schedule wake admits nothing, records why, and arms the next occurrence', () => {
  const wake = arm(controller, 'schedule-wake')
  before(wake, '?:  ci-paused', '(due-problem k e)', 'schedule-wake')
  const branch = wake.slice(wake.indexOf('?:  ci-paused'), wake.indexOf('(due-problem k e)'))
  assert.match(branch, /CI was paused for a restore/)
  assert.match(branch, /\[timers state polls\]/)
  assert.doesNotMatch(branch, /candidates|urgit-git-poke|schedule\n/, 'the paused wake creates no run and sends no poke')
})

test('paused: a forge event is recorded and remembered, and runs nothing; the checkpoint repository never runs anything', () => {
  const admit = arm(controller, 'admit-forge-events')
  before(admit, '?:  =(repository:ci-checkpoint repo.act)  (emit ~)', '(admit-push repo.act u actor.act route.act at.act)', 'admit-forge-events')
  before(admit, '?:  ci-paused  (paused-events act)', '(admit-push repo.act u actor.act route.act at.act)', 'admit-forge-events')
  const paused = arm(controller, 'paused-events')
  assert.match(paused, /=\.  event-ids  \(remember-id id\.u\)/)
  assert.match(paused, /=\.  event-ids  \(remember-id id\.p\)/)
  assert.doesNotMatch(paused, /candidates|urgit-poke|urgit-git-poke|schedule/)
  assert.match(paused, /\[~ state polls\]$/m)
})

test('the recovery actions are the owner\'s, are never delegable, and none but Checkpoint now sends a card', () => {
  for (const tag of ['checkpoint-now', 'pause-ci', 'resume-ci', 'import-checkpoint', 'discard-checkpoint', 'apply-checkpoint']) {
    const body = actionCase(tag)
    assert.match(body, new RegExp(`%${tag}\\n {4}\\?\\. {2}=\\(our\\.bowl actor\\.act\\) {2}~\\|\\(owner-refusal !!\\)`), `%${tag} is not the owner's first`)
    if (tag !== 'checkpoint-now') {
      assert.match(body.trimEnd(), /\[~ state polls\]$/, `%${tag} answers no card`)
      assert.doesNotMatch(body, /\(emit|urgit-poke|urgit-git-poke|%pass/, `%${tag} sends a card`)
    }
  }
  const delegated = actionCase('delegated')
  for (const tag of ['checkpoint-now', 'pause-ci', 'resume-ci', 'import-checkpoint', 'discard-checkpoint', 'apply-checkpoint', 'replica-result']) {
    assert.doesNotMatch(delegated, new RegExp(`%${tag}\\b`), `%${tag} is delegable`)
  }
  assert.doesNotMatch(gaps(arm(controller, 'parse-web-action')), /%replica-result/, '%urgit\'s answer is no web action')
})

test('import and apply are refused unless paused, and apply names the reviewed id and waits for running attempts', () => {
  before(actionCase('import-checkpoint'), '(import-refusal:ci-checkpoint state)', '(import:ci-checkpoint (malt found))', '%import-checkpoint')
  before(actionCase('apply-checkpoint'), '(apply-refusal:ci-checkpoint state id.act)', '(apply:ci-checkpoint state here actor.act now.bowl eny.bowl)', '%apply-checkpoint')
  const refusal = arm(lib, 'apply-refusal')
  before(refusal, '?~  paused.recovery.s', '?~  staged.recovery.s', 'apply-refusal')
  before(refusal, '?.  =(id staged-id)', '(running-attempts s)', 'apply-refusal')
  assert.match(arm(lib, 'import-refusal'), /\?~ {2}paused\.recovery\.s/)
})

test('an apply never rewinds authority: no live approval, override, daemon, attempt, assignment, capability or credential value', () => {
  const apply = arm(lib, 'apply') + arm(lib, 'apply-repo')
  for (const field of ['daemons', 'attempts', 'assignments', 'read-capabilities', 'mirror-tokens', 'credentials.s', 'signing.s', 'schedules']) {
    assert.doesNotMatch(apply, new RegExp(`=\\. {2}${field.replace('.', '\\.')}\\b`), `an apply writes ${field}`)
  }
  // the only writes to approvals and overrides invalidate this ship's own unused ones
  for (const field of ['approvals.s', 'overrides.s']) {
    const at = apply.indexOf(`=.  ${field}`)
    assert.ok(at >= 0)
    assert.match(apply.slice(at, at + 260), /\(invalidated `reason\)/)
  }
  const history = arm(lib, 'apply')
  assert.match(history, /=\.  history\.recovery\.s/)
  assert.match(history, /\(merge-credentials s credentials\.content\)/)
  assert.match(history, /\(merge-runners runners\.history\.recovery\.s runners\.content\)/)
  assert.match(history, /\?:  \?&\(\?=\(\^ signing\.s\) =\(pub\.u\.signing\.s pub\.u\.key\.content\)\)  ~/)
  assert.match(arm(lib, 'merge-credentials'), /\(skip new \|=\(r=credential-ref:ci \(~\(has by credentials\.s\) \[repo\.r name\.r\]\)\)\)/)
})

test('the export reads no secret: credential values only to scrub them, never a private key, bearer, token hash, capability or mirror token', () => {
  const exporting = ['project', 'policy-of', 'locks-of', 'environments-of', 'bindings-of', 'runners-of', 'credentials-of', 'key-of', 'runs-of', 'authorizations-of', 'audit-of', 'export']
    .map((name) => arm(lib, name)).join('\n')
  assert.doesNotMatch(exporting, /value\.c\b/, 'the projection reads a credential value')
  assert.match(arm(lib, 'secret-forms'), /value\.c/)
  for (const secret of ['sek', 'bearer-hash', 'token-hash', 'read-capabilities', 'mirror-tokens', 'github-token']) {
    assert.doesNotMatch(lib, new RegExp(`\\b${secret}\\b`), `lib/ci-checkpoint names ${secret}`)
  }
  assert.match(arm(lib, 'runners-of'), /\[id\.d labels repos enrolled\.d revoked\.d\]/)
  assert.match(arm(lib, 'authorizations-of'), /\(approval-in-force a now\)/)
})

test('the checkpoint is written through %urgit, never into its state, and the replica is the repository\'s own origin', () => {
  const write = arm(controller, 'write-checkpoint')
  assert.match(write, /\[%write-recovery-commit repo ref parent commit\.u\.snapped objects\]/)
  assert.match(write, /\(urgit-git-poke \/checkpoint-repo \[%create repo %\.n\]\)/, 'a missing repository is created private')
  before(write, 'public.u.existing', 'urgit-git-poke', 'a public repository is refused before any write')
  assert.match(arm(controller, 'start-push'), /\[%push-recovery-replica repository\.u\.next ref\.u\.next ticket\]/)
  assert.match(arm(controller, 'start-push'), /\/replica-timeout\//)
  const push = arm(forge, 'on-poke/handle-action/push-recovery-replica')
  assert.match(push, /\?\^  github-origin\.u\.found/)
  assert.match(push, /\?\^  peer-origin\.u\.found/)
  assert.match(push, /\/peer\/offer-timeout\/\(scot %uv transfer\)/)
  const told = arm(forge, 'recovery-told')
  assert.match(told, /\?&\(status\.u\.r =\('fast-forward update accepted' message\.u\.r\)\)/, 'a staged peer answer confirms nothing')
  assert.match(told, /\?:  active\.u\.r  ~/)
  assert.match(forge, /\?=\(\^ github-token\)\n/, 'the peek says whether a token is stored, never the token')
})

test('%urgit refuses every CI-protected write while CI is paused', () => {
  const gate = arm(forge, 'ci-ref-protected')
  before(gate, '?.  p.protected  [%& %.n]', '/recovery-paused/noun', 'ci-ref-protected')
  assert.match(gate, /CI is paused for a restore, so a CI-protected ref moves only after it resumes/)
  assert.match(controller, /\[%x %recovery-paused ~\]\n {6}``noun\+!>\(`\?`ci-paused:hc\)/)
})

test('the model ship\'s refusals are the ship\'s own words', () => {
  for (const words of [
    'pause CI before importing a checkpoint: an import into a running CI is refused',
    'pause CI before applying a checkpoint: an apply to a running CI is refused',
    'no checkpoint is staged: import one first',
    'corrupt checkpoint: the sha-256 of ',
    ' is not the one its manifest lists',
    'CI is already paused',
    'CI is not paused',
  ]) {
    assert.ok(lib.includes(words), `lib/ci-checkpoint does not say: ${words}`)
    assert.ok(fixtures.includes(words), `the model does not say: ${words}`)
  }
})

test('the vectors the parent runs exist and report passed=N of=M', () => {
  for (const vector of ['gen/ci-checkpoint-vector.hoon', 'gen/ci-recovery-pause-vector.hoon']) {
    const text = deskText(vector)
    assert.match(text, /NOT RUN in the source stage that wrote it: it needs a ship\./)
    assert.match(text, /~&  \(crip "passed=\{<passed>\} of=\{<\(lent cases\)>\}"\)\n\?=\(~ failed\)\n$/)
  }
})
