import test from 'node:test'
import assert from 'node:assert/strict'
import { attemptRows, candidateRow } from './ci.js'
import { conditionView, jobDetailsModel, needRows, outcomeView, outputRows, renderJobDetails, renderWaitingJobs, stepOutputRows, waitingRows } from './ciJobs.js'
import { h, part, parts, text } from './runnerRecoveryFixtures.js'
import { capturedConsumer, capturedPlan, capturedProducer, capturedStoppedConsumer } from './ciJobsCaptured.js'

// The job details of the CI tab (Delivery 1B). The attempts and plan jobs
// below are a MODEL of the ship's candidate JSON (attempt-summary-json and
// candidate-json in desk/app/urgit-ci.hoon), field for field; the ship's own
// answers are checked on the fake ship, not here.

const planJob = (over = {}) => ({
  id: 'consumer', workflow: 'outputs.yml', name: 'Outputs across jobs', stage: 1, needs: ['producer'], runsOn: ['ubuntu-latest'], timeoutMinutes: null,
  if: { text: "needs.producer.outputs.verdict == 'go' && needs.producer.result == 'success'", line: 38, col: 9, legacy: false, refusal: null },
  outputs: [], decision: null, ...over,
})

const attempt = (over = {}) => ({
  attempt: '0v1.cons', kind: 'job', workflow: 'outputs.yml', job: 'consumer', status: 'passed', trust: 'trusted', daemon: '0v1.daemon', events: 12,
  reason: null, started: 1_800_000_000, finished: 1_800_000_030, log: null, generation: 1, mode: 'required', manifest: '0v2', sandbox: 'vm', network: 'locked', approval: null, outcome: 'known', pinned: [],
  decision: { verdict: 'run', reason: 'if "needs.producer.outputs.verdict == \'go\' && needs.producer.result == \'success\'" is true', value: 'true' },
  needs: [{ job: 'producer', attempt: '0v9.prod', status: 'passed', result: 'success', outputs: [{ name: 'verdict', value: 'go', cut: false }, { name: 'empty', value: '', cut: false }] }],
  stepOutputs: [], stepOutputCount: 0, jobOutputs: [],
  ...over,
})

const outcomeOf = (o) => [o.label, o.tone, o.execution]

// correction 01 (R2): the ship's scheduling decision is a decision — run,
// skip or refuse — never proof that the job executed; the attempt's own
// outcome is shown beside it
test('a decision is labelled as a decision, its reason and value beside it; the attempt\'s outcome is kept apart', () => {
  const run = jobDetailsModel(attempt(), planJob())
  assert.equal(run.decision.label, 'Run')
  assert.equal(run.decision.tone, '')
  assert.equal(run.decision.value, 'true')
  assert.match(run.decision.reason, /is true$/)
  assert.deepEqual(outcomeOf(run.outcome), ['Passed', 'good', 'reported'])
  const refused = jobDetailsModel(attempt({ status: 'failed', daemon: null, events: 0, decision: { verdict: 'error', reason: 'if "fromJSON(\'not json\').ready" could not be evaluated: fromJSON: \'not json\' is not JSON', value: null } }), planJob())
  assert.equal(refused.decision.label, 'Refuse: its condition could not be evaluated')
  assert.deepEqual(outcomeOf(refused.outcome), ['Not run', 'bad', 'not-run'])
  const skipped = jobDetailsModel(attempt({ status: 'skipped', daemon: null, events: 0, decision: { verdict: 'skip', reason: 'skipped: build failed', value: null } }), planJob({ if: null }))
  assert.equal(skipped.decision.label, 'Skip')
  assert.deepEqual(outcomeOf(skipped.outcome), ['Skipped: not run', '', 'not-run'])
  assert.equal(skipped.condition, null)
})

test('an outcome is what the attempt shows: no execution is inferred from admission or a start time', () => {
  const outcome = (over) => jobDetailsModel(attempt(over), planJob()).outcome
  assert.deepEqual(outcomeOf(outcome({ status: 'running', events: 0, finished: null })), ['Assigned; no runner has reported yet', 'warn', 'unreported'])
  assert.deepEqual(outcomeOf(outcome({ status: 'running', events: 4, finished: null })), ['Running', 'warn', 'reported'])
  assert.deepEqual(outcomeOf(outcome({ status: 'infrastructure-error', events: 0 })), ['No execution reported: infrastructure error', 'bad', 'unreported'])
  assert.deepEqual(outcomeOf(outcome({ status: 'infrastructure-error', events: 9 })), ['Infrastructure error after it started', 'bad', 'reported'])
  assert.deepEqual(outcomeOf(outcome({ status: 'failed', events: 30 })), ['Failed', 'bad', 'reported'])
  assert.deepEqual(outcomeOf(outcome({ status: 'reoffered', events: 0 })), ['Given back and offered again', 'warn', 'unreported'])
  assert.deepEqual(outcomeOf(outcome({ status: 'cancelled', events: 0 })), ['Cancelled', '', 'unreported'])
  assert.equal(outcome({ status: 'infrastructure-error', events: 0, reason: 'abandoned: x' }).reason, 'abandoned: x')
  assert.equal(outcome({ status: 'passed' }).reason, '')
})

// the parent's real run, verbatim (ciJobsCaptured.js): the consumer the
// ship decided to run and whose assignment its runner refused
test('the captured refused consumer reads as decided to run and not executed, never as ran', () => {
  const consumerPlan = capturedPlan.find((j) => j.id === 'consumer')
  const model = jobDetailsModel(capturedConsumer, consumerPlan)
  assert.deepEqual([model.decision.label, model.decision.value], ['Run', 'true'])
  assert.deepEqual([...outcomeOf(model.outcome), model.outcome.reason], ['Not executed: infrastructure error', 'bad', 'not-run', 'abandoned: assignment refused: signature does not verify'])
  const tree = renderJobDetails(h, model)
  assert.ok(!/\bRan\b/.test(text(tree)), text(tree))
  assert.match(text(part(tree, 'decision')), /^Decision: Run/)
  assert.equal(text(part(tree, 'outcome')), 'Not executed: infrastructure error')
  assert.match(text(part(tree, 'outcome-detail')), /abandoned: assignment refused: signature does not verify/)
  assert.deepEqual(parts(tree, 'need').map((n) => text(n)), ['producer succeeded'])
  const producer = jobDetailsModel(capturedProducer, capturedPlan.find((j) => j.id === 'producer'))
  assert.deepEqual([producer.decision.label, ...outcomeOf(producer.outcome)], ['Run', 'Passed', 'good', 'reported'])
  const stopped = jobDetailsModel(capturedStoppedConsumer, capturedPlan.find((j) => j.id === 'stopped-consumer'))
  assert.deepEqual([stopped.decision.label, ...outcomeOf(stopped.outcome)], ['Skip', 'Skipped: not run', '', 'not-run'])
})

// correction 02: an accepted event is a report that the job ran; none is no
// report, never proof that it did not run. The parent's source
// counterexample, verbatim (parent-review-02/UI-UNCERTAINTY-FINDING.json): a
// generic infrastructure error with no events and an unavailable result
const finding = { status: 'infrastructure-error', events: 0, decision: { verdict: 'run' }, reason: 'result unavailable' }

test('a zero-event infrastructure error with an unavailable result reads as no execution reported, never as not executed', () => {
  const o = outcomeView(finding)
  assert.deepEqual([o.label, o.tone, o.execution, o.reason], ['No execution reported: infrastructure error', 'bad', 'unreported', 'result unavailable'])
  assert.ok(!('executed' in o), 'no flag reads "no accepted events" as "did not run"')
  const tree = renderJobDetails(h, jobDetailsModel(attempt(finding), planJob()))
  assert.match(text(part(tree, 'decision')), /^Decision: Run/)
  assert.equal(text(part(tree, 'outcome')), 'No execution reported: infrastructure error')
  assert.match(text(part(tree, 'outcome-detail')), /result unavailable/)
  assert.ok(!/not executed|not run/i.test(text(tree)), text(tree))
})

// the controls: nonexecution is known only where something shows it — the
// ship never assigned the job, or its runner refused the assignment before
// any work — and lines of the run, once accepted, are reported execution
test('only a refusal before any work, or a job never assigned, is known not to have run; accepted events are reported execution', () => {
  assert.equal(outcomeView(capturedConsumer).execution, 'not-run')
  assert.equal(outcomeView({ status: 'reoffered', events: 0, decision: { verdict: 'run' }, reason: 'abandoned: assignment refused: signature does not verify; re-offered' }).execution, 'not-run')
  // a runner that took the attempt before and was stopped may have run part of it
  const interrupted = outcomeView({ ...finding, reason: "abandoned: not run again: this runner took attempt 0v1.cons for execution before, and a stop interrupted it (or an earlier version's state names it); an assignment runs at most once on a runner" })
  assert.deepEqual([interrupted.label, interrupted.execution], ['No execution reported: infrastructure error', 'unreported'])
  // a privileged job its runner gave up: the ship records its outcome unknown, whatever the runner said
  const privileged = outcomeView({ ...finding, outcome: 'unknown', reason: 'abandoned by the daemon during a privileged job: assignment refused: signature does not verify; the external side effect may have happened: needs review' })
  assert.deepEqual([privileged.label, privileged.execution], ['No execution reported: infrastructure error', 'unreported'])
  const started = outcomeView({ ...finding, events: 3 })
  assert.deepEqual([...outcomeOf(started), started.reason], ['Infrastructure error after it started', 'bad', 'reported', 'result unavailable'])
  assert.deepEqual(outcomeOf(outcomeView(capturedProducer)), ['Passed', 'good', 'reported'])
})

test('an attempt from before decisions were recorded, and a ship that sends none, say so', () => {
  const old = jobDetailsModel(attempt({ decision: null, needs: [], jobOutputs: null }), planJob())
  assert.equal(old.decision, null)
  assert.equal(old.decisionNote, 'No decision was recorded for this attempt.')
  const unavailable = jobDetailsModel({ attempt: '0v1', kind: 'job', status: 'passed' }, planJob())
  assert.equal(unavailable.unavailable, true)
})

test('the condition shows its text and place; a state-3 gate and a refusal are named', () => {
  assert.deepEqual(conditionView(planJob()), { text: "needs.producer.outputs.verdict == 'go' && needs.producer.result == 'success'", where: 'line 38, column 9', legacy: false, refusal: '' })
  assert.deepEqual(conditionView(planJob({ if: { text: "needs.a.outputs.go == 'true'", line: null, col: null, legacy: true, refusal: null } })), { text: "needs.a.outputs.go == 'true'", where: '', legacy: true, refusal: '' })
  assert.equal(conditionView(planJob({ if: null })), null)
})

test('prerequisites show the job and its result first; an infrastructure error reads as failure and says so', () => {
  const rows = needRows([
    { job: 'build', attempt: '0v1.b', status: 'failed', result: 'failure', outputs: [] },
    { job: 'test', attempt: '0v2.t', status: 'skipped', result: 'skipped', outputs: [] },
    { job: 'lint', attempt: '0v3.l', status: 'infrastructure-error', result: 'failure', outputs: [] },
  ])
  assert.deepEqual(rows.map((r) => [r.job, r.label, r.tone]), [['build', 'failed', 'bad'], ['test', 'skipped', ''], ['lint', 'infrastructure error (read as failure)', 'bad']])
  assert.equal(rows[0].attempt, '0v1.b')
})

test('declared outputs: a value, an empty string, a cut value, a redacted one and one that could not be resolved', () => {
  const rows = outputRows([
    { name: 'verdict', value: 'go', error: null, cut: false, redacted: false },
    { name: 'empty', value: '', error: null, cut: false, redacted: false },
    { name: 'long', value: 'x'.repeat(1024), error: null, cut: true, redacted: false },
    { name: 'token', value: 'Bearer ***', error: null, cut: false, redacted: true },
    { name: 'broken', value: null, error: 'format: {2} has no value', cut: false, redacted: false },
  ])
  assert.deepEqual(rows.map((r) => [r.name, r.state]), [['verdict', 'value'], ['empty', 'empty'], ['long', 'cut'], ['token', 'redacted'], ['broken', 'error']])
  assert.equal(rows[4].text, 'format: {2} has no value')
  assert.equal(rows[1].text, '')
})

test('no output is invented: a running job, a job without a result, a state-3 plan and a job that declares none each say why there is none', () => {
  const note = (a, p) => jobDetailsModel(attempt(a), planJob(p)).outputsNote
  assert.equal(note({ status: 'running', jobOutputs: null }, { outputs: [{ name: 'v', text: 'x', line: 1, col: 1 }] }), 'Resolved when the job finishes.')
  assert.equal(note({ status: 'infrastructure-error', jobOutputs: null }, { outputs: [{ name: 'v', text: 'x', line: 1, col: 1 }] }), 'Not resolved: the job had no result.')
  assert.equal(note({ jobOutputs: null }, { outputs: null }), 'This plan was saved before declared outputs were read.')
  assert.equal(note({ jobOutputs: [] }, { outputs: [] }), 'This job declares no outputs.')
  assert.equal(note({ jobOutputs: [{ name: 'v', value: 'x', error: null, cut: false, redacted: false }] }, {}), '')
})

test('step outputs keep their step: a composite action\'s own step is shown under its action, an output of no named step says so', () => {
  const rows = stepOutputRows([
    { step: ['one'], name: 'same', value: 'from-one', cut: false, redacted: false },
    { step: ['two'], name: 'same', value: 'from-two', cut: false, redacted: false },
    { step: ['emit', 'inner'], name: 'raw', value: 'x', cut: false, redacted: false },
    { step: [], name: 'go', value: 'true', cut: false, redacted: false },
  ])
  assert.deepEqual(rows.map((r) => [r.step, r.name]), [['one', 'same'], ['two', 'same'], ['emit › inner', 'raw'], ['(no step recorded)', 'go']])
})

test('the attempt rows carry their job details; the plan attempt carries none', () => {
  const rows = attemptRows([attempt(), { attempt: '0v1.plan', kind: 'plan', status: 'passed' }], [planJob()])
  assert.equal(rows[0].details.decision.label, 'Run')
  assert.equal(rows[0].details.outcome.label, 'Passed')
  assert.equal(rows[1].details, null)
})

test('the details area renders labels first and identifiers inside a technical section', () => {
  const tree = renderJobDetails(h, jobDetailsModel(attempt({ jobOutputs: [{ name: 'verdict', value: 'go', error: null, cut: false, redacted: false }] }), planJob()))
  assert.equal(tree.type, 'details')
  assert.match(text(part(tree, 'decision')), /^Decision: Run/)
  assert.equal(text(part(tree, 'outcome')), 'Passed')
  assert.match(text(part(tree, 'condition')), /line 38, column 9/)
  assert.deepEqual(parts(tree, 'need').map((n) => text(n)), ['producer succeeded'])
  assert.deepEqual(parts(tree, 'need-output').map((n) => text(n)), ['verdict go', 'empty (empty string)'])
  assert.deepEqual(parts(tree, 'output').map((n) => text(n)), ['verdict go'])
  assert.ok(!text(part(tree, 'decision')).includes('0v9.prod'))
  assert.ok(text(part(tree, 'identifiers')).includes('0v9.prod'))
})

test('a redacted and an unresolved output render as such, never as a value', () => {
  const tree = renderJobDetails(h, jobDetailsModel(attempt({ jobOutputs: [
    { name: 'token', value: 'Bearer ***', error: null, cut: false, redacted: true },
    { name: 'broken', value: null, error: 'format: {2} has no value', cut: false, redacted: false },
  ] }), planJob()))
  const [token, broken] = parts(tree, 'output')
  assert.match(text(token), /redacted/)
  assert.match(text(broken), /could not be resolved: format: \{2\} has no value/)
})

test('jobs with no attempt yet show their live decision: waiting for a need, about to run, or a skip about to be recorded', () => {
  const candidate = { status: 'pending', plan: [
    planJob({ id: 'test', decision: { verdict: 'wait', reason: 'waiting for build' } }),
    planJob({ id: 'build', decision: { verdict: 'run', reason: 'no prerequisites' } }),
    planJob({ id: 'done', decision: null }),
  ] }
  const rows = waitingRows(candidate)
  assert.deepEqual(rows.map((r) => [r.id, r.label, r.reason]), [['test', 'Waiting', 'waiting for build'], ['build', 'Ready to run', 'no prerequisites']])
  const tree = renderWaitingJobs(h, rows)
  assert.deepEqual(parts(tree, 'waiting-job').map((n) => text(n)), ['test Waiting waiting for build', 'build Ready to run no prerequisites'])
  assert.deepEqual(waitingRows({ status: 'passed', plan: candidate.plan }), [])
})

// correction 01 (R2): a job with no attempt shows the ship's live decision
// and nothing more — waiting, ready, or a skip or refusal being recorded,
// never an outcome — and a pending run with no attempt reads pending, as
// the parent's manual run did when its runner had been refused
test('a pending run keeps its honest states: waiting, ready, a skip or a refusal being recorded, and pending with no attempt', () => {
  const candidate = { status: 'pending', plan: [
    planJob({ id: 'w', decision: { verdict: 'wait', reason: 'waiting for producer' } }),
    planJob({ id: 'r', decision: { verdict: 'run', reason: 'no prerequisites' } }),
    planJob({ id: 's', decision: { verdict: 'skip', reason: 'skipped: producer failed' } }),
    planJob({ id: 'e', decision: { verdict: 'error', reason: 'if "x" could not be evaluated' } }),
  ] }
  assert.deepEqual(waitingRows(candidate).map((r) => [r.id, r.label]), [['w', 'Waiting'], ['r', 'Ready to run'], ['s', 'Skip being recorded'], ['e', 'Refusal being recorded']])
  const manual = candidateRow({ id: '0v1.manual', status: 'pending', created: 1, attempts: [], event: { name: 'workflow_dispatch', workflow: 'outputs.yml' } }, 2)
  assert.deepEqual([manual.statusText, manual.pips, manual.manual], ['pending', [], true])
})
