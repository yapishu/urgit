// The CI tab's job details (Delivery 1B): what the ship decided for a job
// (run it, skip it or refuse it at its condition) and, apart from that,
// what the attempt shows happened; the prerequisites it saw with their
// results, the declared outputs it published and the step outputs it
// recorded. The ship decides and records all of it; this file only labels
// it. Nothing is invented: an output the ship did not resolve says why, a
// redacted value says so, a refused condition never reads as a pass, a
// decision to run never reads as a run, and a run nothing reported never
// reads as one that did not happen. Labels come first; attempt identifiers
// sit in a technical section.

export const resultLabel = { success: 'succeeded', failure: 'failed', skipped: 'skipped', cancelled: 'cancelled' }

// the ship's scheduling decision, labelled as a decision (correction 01):
// a job the ship decided to run can still be refused by its runner, so a
// decision is never past tense and never green; what happened is the
// outcome below
const verdicts = {
  run: { label: 'Run', tone: '' },
  skip: { label: 'Skip', tone: '' },
  error: { label: 'Refuse: its condition could not be evaluated', tone: 'bad' },
  // CI-CONCURRENCY-1: its workflow's run was cancelled and the job does
  // not run under cancelled()
  cancel: { label: 'Cancel: its workflow\'s run was cancelled', tone: '' },
}

// what the attempt itself shows happened, by its status and the evidence
// of its run. The ship creates an attempt and stamps its start when it
// assigns it, and counts events only as it accepts lines of the job's run:
// so events report that the job ran, and none is no report, never proof
// that it did not run (correction 02). Neither admission nor a start time
// is execution
const outcomes = {
  passed: () => ['Passed', 'good'],
  failed: (execution) => (execution === 'reported' ? ['Failed', 'bad'] : execution === 'not-run' ? ['Not run', 'bad'] : ['Failed before any of its run was reported', 'bad']),
  running: (execution) => (execution === 'reported' ? ['Running', 'warn'] : ['Assigned; no runner has reported yet', 'warn']),
  'infrastructure-error': (execution) => (execution === 'reported' ? ['Infrastructure error after it started', 'bad'] : execution === 'not-run' ? ['Not executed: infrastructure error', 'bad'] : ['No execution reported: infrastructure error', 'bad']),
  reoffered: () => ['Given back and offered again', 'warn'],
  cancelled: (execution) => (execution === 'not-run' ? ['Cancelled: not run', ''] : execution === 'reported' ? ['Cancelled after it started', ''] : ['Cancelled', '']),
  skipped: () => ['Skipped: not run', ''],
}

// the reason the ship records for an attempt whose runner refused its
// assignment before any work: `abandoned: ` and the refusal prefix the ship
// and runner share (refusal-prefix in desk/app/urgit-ci.hoon; the runner
// sends it only when the assignment fails verification)
const refusedBeforeWork = 'abandoned: assignment refused: '

// the evidence of an attempt's run: 'reported' once the ship accepted a
// line of it; 'not-run' when it is known not to have run, as the ship never
// assigned it (a skip, a refused condition, or a cancel: its workflow's run
// was cancelled) or its runner refused the assignment before any work; else
// 'unreported', as nothing shows either
function executionEvidence(attempt) {
  if (Number(attempt.events) > 0) return 'reported'
  if (attempt.status === 'skipped' || attempt.decision?.verdict === 'error' || attempt.decision?.verdict === 'cancel') return 'not-run'
  return str(attempt.reason).startsWith(refusedBeforeWork) ? 'not-run' : 'unreported'
}

export function outcomeView(attempt) {
  const execution = executionEvidence(attempt)
  const [label, tone] = outcomes[attempt.status]?.(execution) || [str(attempt.status), '']
  return { status: str(attempt.status), label, tone, execution, reason: str(attempt.reason) }
}

const waitingVerdicts = {
  wait: 'Waiting',
  run: 'Ready to run',
  skip: 'Skip being recorded',
  error: 'Refusal being recorded',
  cancel: 'Cancel being recorded',
}

const str = (v) => (v == null ? '' : String(v))

// a job's condition as the workflow wrote it, and where; a state-3 plan's
// gate (legacy) has no place
export function conditionView(planJob) {
  const c = planJob?.if
  if (!c || typeof c !== 'object') return null
  const where = c.line != null && c.col != null ? `line ${c.line}, column ${c.col}` : ''
  return { text: str(c.text), where, legacy: Boolean(c.legacy), refusal: str(c.refusal) }
}

// the prerequisites a decision saw: each need's job, its result as
// expressions read it, and the attempt it came from
export function needRows(needs) {
  if (!Array.isArray(needs)) return []
  return needs.map((n) => {
    const infra = n.status === 'infrastructure-error'
    return {
      job: str(n.job),
      result: str(n.result),
      status: str(n.status),
      label: infra ? 'infrastructure error (read as failure)' : resultLabel[n.result] || str(n.result),
      tone: n.result === 'failure' ? 'bad' : n.result === 'success' ? 'good' : '',
      attempt: str(n.attempt),
      outputs: Array.isArray(n.outputs) ? n.outputs.map((o) => ({ name: str(o.name), value: str(o.value), cut: Boolean(o.cut) })) : [],
    }
  })
}

// declared outputs as the ship resolved them when the attempt closed
export function outputRows(jobOutputs) {
  if (!Array.isArray(jobOutputs)) return []
  return jobOutputs.map((o) => {
    if (o.error != null) return { name: str(o.name), state: 'error', text: str(o.error) }
    const value = str(o.value)
    const state = o.redacted ? 'redacted' : o.cut ? 'cut' : value === '' ? 'empty' : 'value'
    return { name: str(o.name), state, text: value }
  })
}

// step outputs under the step act named: a composite action's own step is
// shown under its action
export function stepOutputRows(stepOutputs) {
  if (!Array.isArray(stepOutputs)) return []
  return stepOutputs.map((o) => ({
    step: Array.isArray(o.step) && o.step.length ? o.step.map(str).join(' › ') : '(no step recorded)',
    name: str(o.name),
    value: str(o.value),
    cut: Boolean(o.cut),
    redacted: Boolean(o.redacted),
  }))
}

// why the outputs list is what it is, '' when it holds what was published
function outputsNote(attempt, planJob) {
  if (Array.isArray(attempt.jobOutputs)) return attempt.jobOutputs.length ? '' : 'This job declares no outputs.'
  if (planJob && planJob.outputs === null) return 'This plan was saved before declared outputs were read.'
  if (planJob && Array.isArray(planJob.outputs) && !planJob.outputs.length) return 'This job declares no outputs.'
  if (attempt.status === 'running') return 'Resolved when the job finishes.'
  return 'Not resolved: the job had no result.'
}

// everything the details area shows for one job attempt
export function jobDetailsModel(attempt, planJob) {
  if (!attempt || attempt.kind !== 'job') return null
  if (!('decision' in attempt) || !('needs' in attempt)) {
    return { unavailable: true, note: 'Decision details are not available from this ship.' }
  }
  const d = attempt.decision
  const decision = d && typeof d === 'object'
    ? { verdict: str(d.verdict), label: verdicts[d.verdict]?.label || str(d.verdict), tone: verdicts[d.verdict]?.tone || '', reason: str(d.reason), value: d.value == null ? '' : str(d.value) }
    : null
  return {
    unavailable: false,
    attempt: str(attempt.attempt),
    decision,
    decisionNote: decision ? '' : 'No decision was recorded for this attempt.',
    outcome: outcomeView(attempt),
    condition: conditionView(planJob),
    needs: needRows(attempt.needs),
    outputs: outputRows(attempt.jobOutputs),
    outputsNote: outputsNote(attempt, planJob),
    stepOutputs: stepOutputRows(attempt.stepOutputs),
    moreSteps: Math.max(0, Number(attempt.stepOutputCount || 0) - (Array.isArray(attempt.stepOutputs) ? attempt.stepOutputs.length : 0)),
  }
}

// the plan's jobs with no attempt yet, in a pending run, with the ship's
// live decision for each
export function waitingRows(candidate) {
  if (!candidate || candidate.status !== 'pending' || !Array.isArray(candidate.plan)) return []
  return candidate.plan
    .filter((job) => job && job.decision && typeof job.decision === 'object')
    .map((job) => ({ id: str(job.id), workflow: str(job.workflow), verdict: str(job.decision.verdict), label: waitingVerdicts[job.decision.verdict] || str(job.decision.verdict), reason: str(job.decision.reason) }))
}

const outputText = (row) => ({
  value: row.text,
  empty: '(empty string)',
  cut: `${row.text}… (cut at 1 KiB)`,
  redacted: `${row.text} (redacted: a stored credential's value was replaced by ***)`,
  error: `could not be resolved: ${row.text}`,
})[row.state]

// the details area under a job's row: a <details> so the two-line job
// cell stays as it is. h is React.createElement in the tab and a plain
// tree builder in the tests
export function renderJobDetails(h, model) {
  if (!model) return null
  if (model.unavailable) return h('div', { className: 'ci-job-details quiet', 'data-part': 'job-details' }, model.note)
  const d = model.decision
  const o = model.outcome
  return h('details', { className: 'ci-job-details', 'data-part': 'job-details' },
    h('summary', null,
      h('span', { 'data-part': 'decision' },
        ...(d ? [h('span', { className: 'quiet' }, 'Decision: '), h('strong', { className: `status ${d.tone}` }, d.label), ' ', h('small', { className: 'quiet' }, d.reason)] : [h('small', { className: 'quiet' }, model.decisionNote)])),
      h('span', { className: 'ci-job-outcome' }, h('span', { className: 'quiet' }, 'Outcome: '), h('strong', { className: `status ${o.tone}`, 'data-part': 'outcome' }, o.label))),
    o.reason && o.reason !== d?.reason && h('div', { className: 'ci-job-section', 'data-part': 'outcome-detail' },
      h('span', { className: 'quiet' }, 'Outcome '), h('small', null, o.reason)),
    model.condition && h('div', { className: 'ci-job-condition', 'data-part': 'condition' },
      h('span', null, 'Condition '), h('code', null, model.condition.text),
      model.condition.where && h('small', { className: 'quiet' }, ` at ${model.condition.where}`),
      model.condition.legacy && h('small', { className: 'quiet' }, ' (a gate of a plan saved before Delivery 1B, kept at its meaning)'),
      model.condition.refusal && h('small', { className: 'field-error' }, ` refused: ${model.condition.refusal}`),
      d && d.value && h('small', { className: 'quiet', 'data-part': 'value' }, ` evaluated to ${d.value}`)),
    h('div', { className: 'ci-job-section', 'data-part': 'needs' },
      h('span', { className: 'quiet' }, 'Prerequisites'),
      model.needs.length
        ? h('ul', null, model.needs.map((n) => h('li', { key: n.job },
          h('span', { 'data-part': 'need' }, h('strong', null, n.job), ' ', h('span', { className: `status ${n.tone}` }, n.label)),
          n.outputs.length > 0 && h('ul', null, n.outputs.map((o) => h('li', { key: o.name, 'data-part': 'need-output' },
            h('code', null, o.name), ' ', o.value === '' ? h('small', { className: 'quiet' }, '(empty string)') : h('code', null, o.cut ? `${o.value}…` : o.value)))))))
        : h('small', { className: 'quiet' }, ' none')),
    h('div', { className: 'ci-job-section', 'data-part': 'outputs' },
      h('span', { className: 'quiet' }, 'Declared outputs'),
      model.outputs.length
        ? h('ul', null, model.outputs.map((o) => h('li', { key: o.name, 'data-part': 'output', className: o.state === 'error' ? 'field-error' : '' },
          h('code', null, o.name), ' ', o.state === 'value' ? h('code', null, o.text) : h('small', { className: o.state === 'error' ? '' : 'quiet' }, outputText(o)))))
        : h('small', { className: 'quiet' }, ` ${model.outputsNote}`)),
    model.stepOutputs.length > 0 && h('details', { className: 'ci-job-section', 'data-part': 'step-outputs' },
      h('summary', null, `Step outputs (${model.stepOutputs.length + model.moreSteps})`),
      h('ul', null, model.stepOutputs.map((o, i) => h('li', { key: i, 'data-part': 'step-output' },
        h('small', { className: 'quiet' }, o.step), ' ', h('code', null, o.name), ' ',
        o.value === '' ? h('small', { className: 'quiet' }, '(empty string)') : h('code', null, o.cut ? `${o.value}…` : o.value),
        o.redacted && h('small', { className: 'quiet' }, ' (redacted)')))),
      model.moreSteps > 0 && h('small', { className: 'quiet' }, `${model.moreSteps} more not listed`)),
    h('details', { className: 'ci-job-section', 'data-part': 'identifiers' },
      h('summary', null, 'Technical identifiers'),
      h('dl', { className: 'ci-facts' },
        h('div', null, h('dt', null, 'Attempt'), h('dd', null, h('code', null, model.attempt))),
        model.needs.map((n) => h('div', { key: n.job }, h('dt', null, `${n.job} attempt`), h('dd', null, h('code', null, n.attempt)))))))
}

// where an attempt row's reason is shown (correction 03): the status badge
// holds the status alone, and the ship's reason, complete and in its own
// case, is shown once outside it. A job's decision details show it when
// it is the decision's reason, in the summary line that stays visible
// while the details are closed. Any other reason (a plan's, a resolver's,
// an infrastructure record's, a job attempt's own outcome, or a job whose
// ship sent no decision details) is a full-width line under the row, and
// the details do not repeat it.
export function attemptReason(row) {
  const reason = str(row?.reason)
  const details = row?.details || null
  const open = Boolean(details) && !details.unavailable
  if (!reason || (open && details.decision?.reason === reason)) return { line: '', details }
  const shown = open && details.outcome?.reason === reason ? { ...details, outcome: { ...details.outcome, reason: '' } } : details
  return { line: reason, details: shown }
}

// the full-width reason line under an attempt row: plain text, wrapped,
// never cut and never cased by the badge's style
export function renderAttemptReason(h, line) {
  if (!line) return null
  return h('div', { className: 'ci-attempt-reason', 'data-part': 'attempt-reason' },
    h('span', { className: 'quiet' }, 'Reason: '), h('span', { className: 'ci-attempt-reason-text' }, line))
}

// the plan's jobs that have no attempt yet, with the ship's live decision
export function renderWaitingJobs(h, rows) {
  if (!rows.length) return null
  return h('div', { className: 'ci-list ci-waiting-jobs', 'data-part': 'waiting-jobs' },
    h('div', { className: 'table-head ci-waiting-row' }, h('span', null, 'Job'), h('span', null, 'State'), h('span', null, 'Why')),
    rows.map((r) => h('div', { key: `${r.workflow}/${r.id}`, className: 'ci-waiting-row', 'data-part': 'waiting-job' },
      h('strong', null, r.id), ' ', h('span', { 'data-label': 'State' }, r.label), ' ', h('small', { className: 'quiet', 'data-label': 'Why' }, r.reason))))
}
