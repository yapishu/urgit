// Delivery 1C's operator models: what an automatic run was for, what its
// event selected and why, the source events %urgit-ci recorded, and the
// schedules of the default branch with their next, last and missed
// occurrences. Every value is the ship's: an instant is shown as the ship
// rendered it (UTC and the schedule zone's wall clock from its pinned
// table), never computed from this browser's clock or zone. A selection
// says which workflows an event chose and why; it is never a job's
// result, which only an attempt records. Nothing here fetches; the
// components do. Text only. (No import: ci.js reads runEventSummary.)

const text = (v) => (v === null || v === undefined ? '' : String(v))
const list = (v) => (Array.isArray(v) ? v : [])
const short = (oid) => (oid ? String(oid).slice(0, 8) : '—')
const branch = (ref) => (ref ? String(ref).replace('refs/heads/', '') : '—')

// a native pull request opened by its number in the repository's tab
export const pullHref = (repo, number) => `#/${encodeURIComponent(repo)}?tab=pulls&pull=${encodeURIComponent(number)}`

// a pull request activity as one phrase: `closed (merged)` for a merge,
// `labeled ci:fixtures` for a label change
export const pullActivity = (pull) => (pull ? `${text(pull.action)}${pull.label ? ` ${text(pull.label)}` : ''}${pull.merged ? ' (merged)' : ''}` : '')

// a label event's change for the run page: the label added or removed,
// and who changed it (the event's actor, the payload's sender), or null
export function labelChange(pull, actor) {
  if (!pull || !pull.label) return null
  const verb = pull.action === 'unlabeled' ? 'removed' : 'added'
  return { label: text(pull.label), verb, by: text(actor), text: `${text(pull.label)} ${verb} by ${text(actor)}` }
}

// a lateness: on time within the minute the ship allows, else how late
export function lateText(late, seconds) {
  if (!late) return 'on time'
  const total = Math.max(0, Math.floor(Number(seconds) || 0))
  const hours = Math.floor(total / 3600)
  const minutes = Math.floor((total % 3600) / 60)
  const rest = total % 60
  if (hours > 0) return `late by ${hours}h ${minutes}m`
  if (minutes > 0) return `late by ${minutes}m ${rest}s`
  return `late by ${rest}s`
}

// an instant as the ship rendered it, or null
export const instant = (i) => (i && typeof i === 'object' ? { local: text(i.local), utc: text(i.utc) } : null)

// what an automatic run (mode event) was for, or null for any other run:
// a staged push and a manual run have their own facts
export function runEventSummary(event) {
  if (!event || !event.kind) return null
  switch (event.kind) {
    case 'push':
      if (String(event.ref || '').startsWith('refs/tags/')) return { kind: 'push', label: 'Tag push', short: event.before ? 'tag update' : 'new tag' }
      return { kind: 'push', label: 'Push', short: event.before ? 'push' : 'push (new branch)' }
    case 'pull-request':
      return { kind: 'pull-request', label: 'Pull request', short: event.pull ? `PR #${event.pull.number} ${pullActivity(event.pull)}` : 'pull request' }
    case 'schedule':
      return { kind: 'schedule', label: 'Schedule', short: event.occurrence ? `scheduled: ${event.occurrence.workflow} #${event.occurrence.index}` : 'scheduled' }
    default:
      return null
  }
}

const VERDICT = { selected: 'selected', excluded: 'filtered out', error: 'trigger error' }
const TONE = { selected: 'good', excluded: 'quiet', error: 'bad' }

function outcomeRows(outcomes) {
  return list(outcomes).map((o) => ({
    workflow: text(o.workflow),
    name: text(o.name || o.workflow),
    verdict: text(o.verdict),
    verdictText: VERDICT[o.verdict] || text(o.verdict),
    tone: TONE[o.verdict] || '',
    reason: text(o.reason),
  }))
}

const countOf = (rows) => ({
  selected: rows.filter((r) => r.verdict === 'selected').length,
  excluded: rows.filter((r) => r.verdict === 'excluded').length,
  error: rows.filter((r) => r.verdict === 'error').length,
})

// a run's selection: the basis (what was compared), a note the whole
// selection carries, every workflow's verdict and reason, and for a
// required run what its selection means for the required checks: an
// excluded or refused push workflow is required evidence absent (the
// branch stays blocked and only a recorded override lands it); a full
// selection is coverage only — the checks are the jobs' own results
export function selectionModel(candidate) {
  const s = candidate?.selection
  if (!s || typeof s !== 'object') return null
  const rows = outcomeRows(s.outcomes)
  const r = candidate.requiredEvidence
  let required = null
  if (r && typeof r === 'object') {
    const missing = outcomeRows(r.missing)
    if (!r.evaluated) {
      required = { complete: Boolean(r.complete), evaluated: false, missing, tone: 'warn', text: `Filters not evaluated: every push workflow is planned as before. ${text(s.note)}`.trim() }
    } else if (missing.length) {
      const named = missing.map((m) => `${m.workflow} was not selected (${m.reason})`).join('; ')
      required = { complete: false, evaluated: true, missing, tone: 'bad', text: `Required evidence absent: ${named}. No attempt stands for it; the branch stays blocked, and only a recorded override lands it.` }
    } else {
      required = { complete: true, evaluated: true, missing, tone: '', text: 'Every push workflow of the baseline was selected for this run. Selection is not a result: the required checks are the job attempts below.' }
    }
  }
  return { basis: text(s.basis), note: text(s.note), rows, counts: countOf(rows), required }
}

// a ref by its short name: a branch as itself, a tag as `tag <name>`
const refLabel = (ref) => (String(ref || '').startsWith('refs/tags/') ? `tag ${String(ref).slice(10)}` : branch(ref))

// one recorded source event's kind as a phrase
function eventKind(e) {
  if (e.kind === 'pull-request') return e.pull ? `PR #${e.pull.number} ${pullActivity(e.pull)}` : 'pull request'
  if (e.kind === 'default-branch') return 'default branch'
  if (String(e.ref || '').startsWith('refs/tags/')) return !e.after ? 'tag deletion' : !e.before ? 'new tag' : 'tag update'
  if (!e.before) return 'new branch'
  if (!e.after) return 'deletion'
  return 'push'
}

// what the outcome means: a run made, a refusal, or a record of an event
// that ran nothing (its reason the ship's own words)
function outcomeTone(outcome) {
  if (/^refused/.test(outcome)) return 'bad'
  if (/selected: run /.test(outcome)) return 'good'
  return 'quiet'
}

// the recorded source events of a repository, newest first as the ship
// sent them
export function forgeEventRows(answer) {
  return list(answer?.events).map((e) => {
    const outcome = text(e.outcome)
    const selection = e.selection && typeof e.selection === 'object' ? selectionModel({ selection: e.selection }) : null
    return {
      id: text(e.id),
      kind: text(e.kind),
      kindText: eventKind(e),
      ref: text(e.ref),
      branch: refLabel(e.ref),
      move: e.kind === 'pull-request' || e.kind === 'default-branch' ? '' : !e.before ? `new at ${short(e.after)}` : !e.after ? `deleted (was ${short(e.before)})` : `${short(e.before)} → ${short(e.after)}`,
      pull: e.pull && typeof e.pull === 'object'
        ? { number: Number(e.pull.number), title: text(e.pull.title), activity: pullActivity(e.pull), head: text(e.pull.head), headBranch: branch(e.pull.headRef), baseBranch: branch(e.pull.baseRef), author: text(e.pull.sourceShip), labels: list(e.pull.labels).map(text), label: labelChange(e.pull, e.actor) }
        : null,
      actor: text(e.actor),
      route: text(e.route),
      at: Number(e.at) || 0,
      received: Number(e.received) || 0,
      outcome,
      tone: outcomeTone(outcome),
      selection,
      workflowProvenance: e.workflowProvenance || null,
      counts: selection ? selection.counts : null,
      runs: list(e.runs).map(text),
    }
  })
}

const STATE = { active: 'good', refused: 'bad', retired: 'quiet' }

// the schedules of a repository's default branch, by workflow and entry,
// with what the ship needs to register them (refresh)
export function scheduleModel(answer) {
  const rows = list(answer?.schedules).map((s) => {
    const admitted = s.lastAdmitted && typeof s.lastAdmitted === 'object'
      ? { due: instant(s.lastAdmitted.due), at: instant(s.lastAdmitted.at), run: text(s.lastAdmitted.run), late: Boolean(s.lastAdmitted.late), lateText: lateText(s.lastAdmitted.late, s.lastAdmitted.lateSeconds) }
      : null
    return {
      key: `${text(s.workflow)}#${text(s.index)}`,
      title: text(s.name || s.workflow),
      entry: `${text(s.workflow)} #${text(s.index)}`,
      workflow: text(s.workflow),
      index: Number(s.index) || 0,
      cron: text(s.cron),
      zone: text(s.timezoneLabel || s.timezone || 'UTC (default)'),
      state: text(s.state),
      stateText: text(s.state),
      tone: STATE[s.state] || '',
      reason: text(s.reason),
      refusal: text(s.refusal),
      next: s.state === 'active' ? instant(s.next) : null,
      lastDue: instant(s.lastDue),
      lastAdmitted: admitted,
      missed: list(s.missed).map((m) => ({
        count: Number(m.count) || 0,
        first: instant(m.first),
        last: instant(m.last),
        text: `${Number(m.count) || 0} occurrence${Number(m.count) === 1 ? '' : 's'} missed, ${text(m.first?.local)} to ${text(m.last?.local)}: not run`,
      })),
      staleWakes: Number(s.staleWakes) || 0,
      definitionRef: branch(s.ref),
      provenance: `promoted by ${text(s.promoter)} · baseline ${short(s.baseline)} · lock ${short(s.lock)}`,
      promoted: Number(s.promoted) || 0,
      registered: Number(s.registered) || 0,
      definition: text(s.definition),
    }
  })
  return {
    asOf: text(answer?.nowUtc),
    defaultBranch: answer?.defaultBranch ? branch(answer.defaultBranch) : '',
    refresh: text(answer?.refresh),
    rows,
  }
}
