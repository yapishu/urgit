import { jobDetailsModel } from './ciJobs.js'
import { runEventSummary } from './ciEvents.js'
import { groupWaitTag } from './ciConcurrency.js'

// The CI tab's pure helpers (BRIEF-CI-P2 D6): the log renderer over the
// raw act jsonl the store serves, the shapes the candidate list and the
// candidate page derive from the ci/* routes, and the action bodies the
// settings controls post. Nothing here fetches; the components do.

export const shortOid = (oid) => (oid ? String(oid).slice(0, 8) : '—')

export const branchLabel = (ref) => (ref ? String(ref).replace('refs/heads/', '') : '—')

// the candidate statuses and the one word the list shows for each: a
// candidate skipped was superseded by a newer one for its ref; a run
// cancelled (CI-CONCURRENCY-1) by its concurrency group or by an operator
// is neither failed nor an infrastructure error
export const candidateStatusLabel = {
  passed: 'passed',
  failed: 'failed',
  pending: 'pending',
  skipped: 'superseded',
  cancelled: 'cancelled',
  unknown: 'unknown',
}

// a job attempt's statuses (correction 01): an attempt skipped was not run,
// its condition false or a need not met, and is never "superseded"
export const attemptStatusLabel = {
  passed: 'passed',
  failed: 'failed',
  skipped: 'skipped',
  running: 'running',
  reoffered: 're-offered',
  cancelled: 'cancelled',
  'infrastructure-error': 'infra error',
}

// the Approve button's tooltip names the repository's policy for
// untrusted revisions (P3 D7)
export const approveHint = (policy) => policy === 'restricted'
  ? 'Policy: run restricted checks. This candidate ran with no credentials and cannot land; approving stages the same head as trusted and runs it again with credentials.'
  : 'Policy: wait for approval. An untrusted revision runs nothing until a writer approves it; approving stages the same head as trusted.'

// the first-run message (P3 D7): CI is required somewhere in this
// repository and no runner could take the work
export const noRunnerMessage = (protectedRefs = [], runners = []) =>
  protectedRefs.length > 0 && !runners.some((r) => r.enrolled && !r.revoked)
    ? 'No runner is enrolled. Mint a token in Settings → Runners and install the daemon; every candidate staged for a CI-required branch waits until one polls.'
    : ''

// a web edit to a CI-protected branch is staged, not committed (Q4): the
// ship answers 202 with the candidate, and the branch keeps its tip until
// the candidate's checks pass and it lands. '' for an applied write
export const stagedEditNote = (answer, ref, what = 'This change') =>
  answer?.staged
    ? `${what} was staged as CI candidate ${answer.candidate}, not committed: ${ref ? branchLabel(ref) : 'the branch'} is CI-protected and keeps its current tip until the candidate's checks pass and it lands. Follow it in the CI tab.`
    : ''

// a publication to a CI-protected bound branch is staged, not committed
// (Q5): the ship answers 202 with staged and the branch, and stages the
// desk's snapshot as a candidate once it has read the desk. '' when the
// publication goes straight to the branch
export const stagedPublishNote = (answer) => {
  if (!answer?.staged) return ''
  const branch = answer.ref ? branchLabel(answer.ref) : 'the branch'
  return `Publishing to ${branch} stages a CI candidate instead of committing: ${branch} is CI-protected and keeps its current tip until the candidate's checks pass and it lands. Follow it in the CI tab.`
}

// the pips under a candidate: one per job attempt (plans are the ship's
// own step and are not shown), newest attempts last
export function attemptPips(attempts = []) {
  return attempts
    .filter((attempt) => attempt.kind === 'job')
    .slice()
    .reverse()
    .map((attempt) => ({ id: attempt.attempt, status: attempt.status, statusText: attemptStatusLabel[attempt.status] || attempt.status, job: attempt.job || '' }))
}

// one row of the candidate list
export function candidateRow(candidate, nowSeconds = Date.now() / 1000) {
  const ageSeconds = Math.max(0, Math.floor(nowSeconds - Number(candidate.created || 0)))
  return {
    id: candidate.id,
    ref: branchLabel(candidate.ref),
    head: shortOid(candidate.head),
    actor: candidate.actor || '',
    status: candidate.status,
    statusText: candidateStatusLabel[candidate.status] || candidate.status,
    trust: candidate.trust,
    pull: candidate.pull ?? null,
    reason: candidate.verdictReason || '',
    ageSeconds,
    pips: attemptPips(candidate.attempts || []),
    // a manual run (Delivery 1A) is listed with the workflow it ran
    manual: candidate.event?.name === 'workflow_dispatch',
    workflowName: candidate.event?.workflowName || candidate.event?.workflow || '',
    // an automatic run (Delivery 1C) with the event it was for; it is
    // advisory: it never lands and never satisfies a required check
    event: runEventSummary(candidate.event)?.short || '',
    advisory: candidate.mode === 'event',
    // a required run whose selection left a push workflow out: its
    // required evidence is absent, never a pass
    evidenceAbsent: Boolean(candidate.requiredEvidence?.evaluated && candidate.requiredEvidence.complete === false),
    // a workflow of the run waits in its concurrency group (CI-CONCURRENCY-1)
    groupWait: groupWaitTag(candidate),
  }
}

// a duration between two unix-second stamps, or '' while the second is
// missing
export function duration(started, finished) {
  const a = Number(started)
  const b = Number(finished)
  if (!Number.isFinite(a) || !Number.isFinite(b) || b < a || a <= 0) return ''
  const total = Math.floor(b - a)
  if (total < 60) return `${total}s`
  const minutes = Math.floor(total / 60)
  const seconds = total % 60
  if (minutes < 60) return `${minutes}m ${seconds}s`
  return `${Math.floor(minutes / 60)}h ${minutes % 60}m`
}

// the candidate page's job rows: the plan attempts first (the ship's
// planning step), then every job attempt newest first, each with the
// fields the table shows, the job's runs-on from the plan (P3 D2b),
// whether a log can be opened, and (Delivery 1B) its job details: why it
// ran or did not, its prerequisites and its outputs
export function attemptRows(attempts = [], plan = []) {
  const jobs = Array.isArray(plan) ? plan : []
  const runsOn = new Map(jobs.map((job) => [`${job.workflow}/${job.id}`, Array.isArray(job.runsOn) ? job.runsOn : []]))
  const planned = new Map(jobs.map((job) => [`${job.workflow}/${job.id}`, job]))
  return attempts.map((attempt) => ({
    id: attempt.attempt,
    kind: attempt.kind,
    job: attempt.kind === 'plan' ? 'plan' : attempt.job || '',
    workflow: attempt.workflow || '',
    runsOn: attempt.kind === 'job' ? runsOn.get(`${attempt.workflow}/${attempt.job}`) || [] : [],
    daemon: attempt.daemon ? String(attempt.daemon).slice(0, 12) : (attempt.status === 'skipped' ? '—' : ''),
    status: attempt.status,
    statusText: attemptStatusLabel[attempt.status] || attempt.status,
    trust: attempt.trust,
    started: attempt.started || null,
    finished: attempt.finished || null,
    elapsed: duration(attempt.started, attempt.finished),
    reason: attempt.reason || '',
    hasLog: Boolean(attempt.log),
    pinned: pinnedRows(attempt.pinned),
    details: attempt.kind === 'job' ? jobDetailsModel(attempt, planned.get(`${attempt.workflow}/${attempt.job}`) || null) : null,
  }))
}

// what the launcher pinned each granted DNS name to for this run
// (CI-P4-NET-1, pinned addresses shown per run): one row per name with its
// addresses, text only; anything that is not a list of {name, addrs} is
// dropped, never guessed
export function pinnedRows(pinned) {
  if (!Array.isArray(pinned)) return []
  return pinned
    .filter((p) => p && typeof p.name === 'string' && Array.isArray(p.addrs))
    .map((p) => ({ name: p.name, addrs: p.addrs.filter((a) => typeof a === 'string') }))
}

// the note a pinned row carries: a name is allowed by its addresses, so
// other sites on the same addresses are reachable on that port too
export const pinnedNote = 'Pinned when this run started. Other sites on these addresses, such as sites on a shared CDN, were reachable on the granted port too.'

// the raw act jsonl rendered client-side as `[job] step: msg` lines,
// grouped by the group/endgroup commands act emits; a line that is not
// an event line is shown as itself under no group. nothing is trusted:
// every field is coerced to text.
export function renderLog(text) {
  const groups = []
  let current = { title: '', lines: [] }
  const flush = () => {
    if (current.lines.length || current.title) groups.push(current)
    current = { title: '', lines: [] }
  }
  for (const raw of String(text || '').split('\n')) {
    if (!raw.trim()) continue
    let event = null
    try {
      event = raw[0] === '{' ? JSON.parse(raw) : null
    } catch {
      event = null
    }
    if (!event || typeof event !== 'object') {
      current.lines.push({ job: '', step: '', msg: raw, level: '' })
      continue
    }
    const command = typeof event.command === 'string' ? event.command : ''
    if (command === 'group') {
      flush()
      current = { title: String(event.arg ?? event.msg ?? ''), lines: [] }
      continue
    }
    if (command === 'endgroup') {
      flush()
      continue
    }
    current.lines.push({
      job: String(event.jobID ?? event.job ?? ''),
      step: String(event.step ?? ''),
      msg: String(event.msg ?? ''),
      level: String(event.level ?? ''),
      result: typeof event.jobResult === 'string' ? event.jobResult : typeof event.stepResult === 'string' ? event.stepResult : '',
    })
  }
  flush()
  return groups
}

export const lineText = (line) => `${line.job ? `[${line.job}] ` : ''}${line.step ? `${line.step}: ` : ''}${line.msg}`

// the bodies POST ci/action takes: the poke as JSON, one shape per action
export const ciActions = {
  approve: (id) => ({ action: 'approve-candidate', id }),
  rerun: (id) => ({ action: 'rerun-candidate', id }),
  // CI-CONCURRENCY-1: cancel the whole run, or one workflow of it
  cancelRun: (id, workflow) => ({ action: 'cancel-run', id, ...(workflow ? { workflow } : {}) }),
  setCiProtected: (repo, ref, protectedRef) => ({ action: 'set-ci-protected', repo, ref, protected: Boolean(protectedRef) }),
  setUntrustedPolicy: (repo, policy) => ({ action: 'set-untrusted-policy', repo, policy }),
  setCredential: (repo, name, value, scope, envs = []) => ({ action: 'set-credential', repo, name, value, scope, envs }),
  deleteCredential: (repo, name) => ({ action: 'delete-credential', repo, name }),
}

// a credential form's validity: a name, a value of at least eight
// characters (the ship's rule), and environments only for %env. A value
// may span lines (P3 D9: a PEM key pastes as is; every line of at least
// eight characters is scrubbed on both sides).
export function credentialFormError({ name, value, scope, envs }) {
  if (!String(name || '').trim()) return 'A name is required.'
  if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(String(name).trim())) return 'Names are letters, digits and underscores, like GITHUB_TOKEN.'
  if (String(value || '').length < 8) return 'Values must be at least 8 characters.'
  if (scope === 'env' && !parseEnvs(envs).length) return 'Name at least one environment for the env scope.'
  return ''
}

export const parseEnvs = (text) => String(text || '').split(/[\s,]+/).map((s) => s.trim()).filter(Boolean)
