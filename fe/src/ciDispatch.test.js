import test from 'node:test'
import assert from 'node:assert/strict'
import { controlKind, definitionFor, dispatchBody, eventRows, fieldErrors, initialRunForm, initialValues, inputValueText, newRequestId, optionList, refChoices, runFormReducer, submission, submitError, workflowChoices } from './ciDispatch.js'
import { candidateRow } from './ci.js'
import { modeLabel } from './ciProvenance.js'
import { BASELINE, TIP, inventory, manualInputs, repo } from './runWorkflowFixtures.js'

test('the workflows come from the ship\'s inventory, by name; a refused one is listed unavailable with its reason', () => {
  const choices = workflowChoices(inventory())
  assert.deepEqual(choices.map((c) => [c.workflow, c.name, c.available]), [['manual.yml', 'Manual release', true], ['matrix.yml', 'Matrix', false], ['release.yml', 'Release', true]])
  assert.equal(choices[1].reason, 'cannot run manually: job a: a matrix strategy is not supported in this release')
  assert.deepEqual(workflowChoices({ refs: [] }), [])
})

test('every branch is offered by name, an unavailable one with the actionable reason', () => {
  const refs = refChoices(inventory(), 'manual.yml', repo().refs)
  assert.deepEqual(refs.map((r) => [r.label, r.available]), [['feature', false], ['main', true], ['old', false]])
  assert.match(refs[0].reason, /^no promoted baseline for feature: promote a harness revision \(Settings → CI policy\)/)
  assert.match(refs[2].reason, /resolve and promote its revision again/)
  assert.equal(refs[1].tip, TIP)
  const other = refChoices(inventory(), 'other.yml', repo().refs).find((r) => r.label === 'main')
  assert.equal(other.available, false)
  assert.equal(other.reason, "other.yml does not declare workflow_dispatch at main's promoted baseline")
})

test('each declared type gets its control: a toggle, a select of the options or environments, a number field, a text field', () => {
  const [flag, count, level, note, target] = manualInputs()
  assert.deepEqual([flag, count, level, note, target].map(controlKind), ['toggle', 'number', 'select', 'text', 'select'])
  assert.deepEqual(optionList(level, []).map((o) => o.value), ['', 'info', 'warning', 'debug'])
  assert.equal(optionList(level, [])[0].label, 'default: warning')
  assert.deepEqual(optionList(target, ['production', 'staging']).map((o) => o.value), ['', 'production', 'staging'])
  assert.equal(optionList(target, ['production'])[0].label, 'choose an environment')
  assert.deepEqual(initialValues(manualInputs()), { dry_run: false, count: '', level: '', note: '', target: '' })
  assert.equal(initialValues([{ id: 'on', type: 'boolean', default: 'true' }]).on, true)
})

test('the form checks what the ship checks, in the ship\'s words', () => {
  const inputs = [...manualInputs(), { id: 'version', type: 'string', required: true, default: null, options: [] }]
  const values = { ...initialValues(inputs), count: '1e3', level: 'verbose', target: 'nowhere' }
  assert.deepEqual(fieldErrors(inputs, values, ['production', 'staging']), {
    count: 'must be a plain decimal number, like 12 or -0.5',
    level: 'must be one of info, warning, debug',
    target: 'must be an environment of this repository: production, staging',
    version: 'is required',
  })
  assert.deepEqual(fieldErrors(manualInputs(), { ...initialValues(manualInputs()), count: '05' }, []), { count: 'must be a plain decimal number, like 12 or -0.5' })
  assert.deepEqual(fieldErrors(manualInputs(), { ...initialValues(manualInputs()), count: '-0.5', target: 'x' }, []), { target: 'must name an environment, and this repository defines none' })
  assert.deepEqual(fieldErrors(manualInputs(), initialValues(manualInputs()), ['production']), {})
})

test('the request carries typed values: a false toggle and a zero are values; an empty field is not supplied, so its default applies', () => {
  const body = dispatchBody({ ref: 'refs/heads/main', workflow: 'manual.yml', tip: TIP, generation: 7 }, manualInputs(), { dry_run: false, count: '0', level: '', note: '', target: '' })
  assert.deepEqual(body, { ref: 'refs/heads/main', workflow: 'manual.yml', tip: TIP, generation: 7, inputs: { dry_run: false, count: 0 } })
  assert.equal(typeof body.inputs.dry_run, 'boolean')
  assert.equal(body.inputs.count, 0)
  const chosen = dispatchBody({ ref: 'r', workflow: 'w', tip: TIP, generation: 1 }, manualInputs(), { dry_run: true, count: '-2.5', level: 'debug', note: 'ship it', target: 'production' })
  assert.deepEqual(chosen.inputs, { dry_run: true, count: -2.5, level: 'debug', note: 'ship it', target: 'production' })
})

test('missing, the default\'s own text and an explicit empty text are three requests: "" is sent only when the operator asks for it', () => {
  const base = { ref: 'refs/heads/main', workflow: 'manual.yml', tip: TIP, generation: 7 }
  const values = { dry_run: false, count: '0', level: '', note: '', target: '' }
  // missing: not supplied, the ship applies the default hello
  assert.equal('note' in dispatchBody(base, manualInputs(), values).inputs, false)
  // the default's text, typed: supplied
  assert.equal(dispatchBody(base, manualInputs(), { ...values, note: 'hello' }).inputs.note, 'hello')
  // asked for empty: supplied as "", which the ship records as supplied
  const empty = dispatchBody(base, manualInputs(), values, { note: true })
  assert.equal(empty.inputs.note, '')
  assert.deepEqual(fieldErrors(manualInputs(), values, [], { note: true }), {})
})

test('the form keeps an explicit empty apart from the text: asking for it empties the field, turning it off leaves the default, a new branch forgets it', () => {
  let state = runFormReducer(initialRunForm(), { type: 'loaded', inventory: inventory(), repoRefs: repo().refs, head: 'refs/heads/main' })
  state = runFormReducer(state, { type: 'set', id: 'note', value: 'typed first' })
  state = runFormReducer(state, { type: 'set-empty', id: 'note', on: true })
  assert.equal(state.values.note, '')
  assert.deepEqual(state.empties, { note: true })
  assert.equal(submission(state).body.inputs.note, '')
  const off = runFormReducer(state, { type: 'set-empty', id: 'note', on: false })
  assert.equal('note' in submission(off).body.inputs, false)
  assert.deepEqual(runFormReducer(state, { type: 'pick-ref', ref: 'refs/heads/main' }).empties, {})
})

test('a refusal is classified by the ship\'s status; a lost answer is not a refusal', () => {
  assert.deepEqual(submitError(Object.assign(new Error('2 inputs refused: a b; c d'), { status: 422, fields: { a: 'b', c: 'd' } })), { kind: 'invalid', message: '2 inputs refused: a b; c d', fields: { a: 'b', c: 'd' } })
  assert.equal(submitError(Object.assign(new Error('refs/heads/main moved since the form was loaded: its tip is now x; reload and dispatch again'), { status: 409 })).kind, 'stale')
  assert.equal(submitError(Object.assign(new Error('the CI policy of demo changed since the form was loaded (generation 1, now 2): reload'), { status: 409 })).kind, 'stale')
  assert.equal(submitError(Object.assign(new Error('workflow x does not declare workflow_dispatch'), { status: 409 })).kind, 'refused')
  assert.equal(submitError(Object.assign(new Error('session required'), { status: 401 })).kind, 'unauthorized')
  assert.equal(submitError(Object.assign(new Error('only the repository\'s owner'), { status: 403 })).kind, 'unauthorized')
  assert.equal(submitError(new TypeError('Failed to fetch')).kind, 'lost')
  assert.match(newRequestId(1_800_000_000_000, () => 0.5), /^run-[a-z0-9]+-[a-z0-9]+$/)
  assert.ok(newRequestId().length <= 64)
})

test('a run\'s event is shown as admitted: the manual event, actor, ref, source, revision, workflow and every input with how it was decided', () => {
  const run = {
    id: '0v1.run', mode: 'manual', head: TIP, ref: 'refs/heads/main', actor: '~zod',
    event: { name: 'workflow_dispatch', workflow: 'manual.yml', workflowName: 'Manual release', request: 'run-1', actor: '~zod', ref: 'refs/heads/main', source: TIP, revision: BASELINE, payload: '{"inputs":{}}', payloadSha256: 'a'.repeat(64),
      inputs: [{ id: 'dry_run', type: 'boolean', source: 'supplied', value: false }, { id: 'count', type: 'number', source: 'supplied', value: 0 }, { id: 'level', type: 'choice', source: 'default', value: 'warning' }, { id: 'note', type: 'string', source: 'supplied', value: '' }, { id: 'target', type: 'environment', source: 'absent', value: null }] },
  }
  const rows = eventRows(run)
  assert.equal(rows.label, 'Manual run')
  assert.equal(rows.name, 'workflow_dispatch')
  assert.equal(rows.branch, 'main')
  assert.equal(rows.workflowName, 'Manual release')
  assert.deepEqual(rows.inputs.map((i) => [i.id, i.text, i.sourceLabel]), [['dry_run', 'false', 'supplied'], ['count', '0', 'supplied'], ['level', 'warning', 'default'], ['note', '"" (empty)', 'supplied'], ['target', '—', 'not supplied']])
  assert.equal(eventRows({ event: { name: 'push', actor: '~zod', ref: 'refs/heads/main', source: TIP, revision: null, workflow: null, inputs: [] } }).label, 'Push')
  // a push shows the payload its jobs read, signed by its digest, as a manual run does
  const push = eventRows({ event: { name: 'push', actor: '~zod', ref: 'refs/heads/main', source: TIP, revision: null, workflow: null, inputs: [], payload: '{"after":"x"}', payloadSha256: 'b'.repeat(64) } })
  assert.deepEqual([push.payload, push.payloadSha256, push.request], ['{"after":"x"}', 'b'.repeat(64), ''])
  assert.equal(eventRows({}), null)
  assert.equal(inputValueText(true), 'true')
  const row = candidateRow({ id: '0v1.run', ref: 'refs/heads/main', head: TIP, actor: '~zod', status: 'pending', created: 1, attempts: [], event: run.event }, 2)
  assert.equal(row.manual, true)
  assert.equal(row.workflowName, 'Manual release')
  assert.equal(candidateRow({ id: '0v2', ref: 'refs/heads/main', head: TIP, created: 1, attempts: [], event: { name: 'push' } }, 2).manual, false)
  assert.equal(modeLabel({ mode: 'manual' }).label, 'manual')
  assert.match(modeLabel({ mode: 'manual' }).detail, /never lands/)
})

test('the inventory\'s definition for a ref and workflow, or none', () => {
  assert.equal(definitionFor(inventory(), 'refs/heads/main', 'manual.yml').inputs.length, 5)
  assert.equal(definitionFor(inventory(), 'refs/heads/old', 'manual.yml'), null)
  assert.equal(definitionFor(null, 'refs/heads/main', 'manual.yml'), null)
})

// Delivery 1C: an automatic run's facts, as the candidate page shows them:
// the event and its activity, how it arrived, its tips or its pull request
// or its occurrence, and the signed trigger; a scheduled run is the system
// timer's, authorized by a promotion, never a person's click
test('the facts of an automatic push, a pull request activity and a scheduled occurrence', async () => {
  const { pullRun, pushRun, scheduleRun, oid } = await import('./ciEventsFixtures.js')
  const push = eventRows(pushRun)
  assert.equal(push.label, 'Push')
  assert.equal(push.route, 'smart-http push (write token)')
  assert.equal(push.before, oid('b'))
  assert.equal(push.after, oid('c'))
  assert.equal(push.triggeredBy, '~zod')
  assert.match(push.trigger, /^push refs\/heads\/main /)
  assert.equal(push.eventId, '0v5.eeeee')
  const pr = eventRows(pullRun)
  assert.equal(pr.label, 'Pull request')
  assert.equal(pr.name, 'pull_request')
  assert.equal(pr.activity, 'opened')
  assert.deepEqual([pr.pull.number, pr.pull.title, pr.pull.headBranch, pr.pull.baseBranch, pr.pull.author], [7, 'Add <b>x</b>', 'feature', 'main', '~nec'])
  assert.equal(pr.pull.head, oid('d'))
  assert.equal(pr.pull.base, oid('b'))
  const merged = eventRows({ ...pullRun, event: { ...pullRun.event, pull: { ...pullRun.event.pull, action: 'closed', merged: true } } })
  assert.equal(merged.activity, 'closed (merged)')
  const sched = eventRows(scheduleRun)
  assert.equal(sched.label, 'Schedule')
  assert.equal(sched.triggeredBy, 'the system timer, authorized by ~zod\'s promotion')
  assert.deepEqual([sched.occurrence.cron, sched.occurrence.zone, sched.occurrence.entry], ['30 5 * * 1-5', 'America/New_York', 'nightly.yml #0'])
  assert.equal(sched.occurrence.due.local, '2026-10-16 05:30 UTC-04:00')
  assert.equal(sched.occurrence.admitted.utc, '2026-10-16T09:32:05Z')
  assert.equal(sched.occurrence.lateText, 'late by 2m 5s')
  // a staged push and a manual run keep their facts as before
  assert.equal(eventRows({ event: { name: 'push', actor: '~zod', ref: 'refs/heads/main', source: TIP, revision: null, workflow: null, inputs: [] } }).kind, '')
})
