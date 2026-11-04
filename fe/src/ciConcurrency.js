// The CI tab's concurrency surface (CI-CONCURRENCY-1): a run's workflow
// concurrency groups as the ship records them, in plain words, and its
// Cancel control. The ship decides every place and every cancellation and
// words every reason; this file only labels them. A run is named by its
// label, its id kept for the fine print. Unknown is never none: a workflow
// whose concurrency was not read says so and why, and a run that takes
// part in no group says why. Nothing here fetches; every string is data
// the view prints as text.

import { exactTime } from './format.js'

const str = (v) => (v == null ? '' : String(v))

// another run, by its label and, for the fine print, its id
export function runRef(ref) {
  if (!ref || typeof ref !== 'object') return null
  return { label: str(ref.label) || 'a run', id: str(ref.id) }
}

// a workflow's cancellation, or the whole run's: who or what cancelled it,
// the ship's words for why, and whether it had started
export function cancellationView(c) {
  if (!c || typeof c !== 'object') return null
  return {
    cause: str(c.cause),
    reason: str(c.reason) || 'cancelled',
    started: c.started !== false,
    at: c.at ?? null,
    actor: str(c.actor),
    by: runRef(c.by),
    group: str(c.group),
  }
}

// a run's state in brief, above its workflows: a run that has not joined
// yet, one that takes part in no group by rule and why, one whose groups
// are unknown and why
function runSummary(state, reason, rows) {
  switch (state) {
    case 'pending': return 'Not joined yet: the run joins its workflows\' concurrency groups once its revision is materialized and its workflows are known.'
    case 'exempt': return `Takes part in no concurrency group: ${reason}`
    case 'unknown': return `Concurrency unknown: ${reason}`
    case 'joined': {
      const members = rows.filter((r) => r.kind === 'member').length
      if (!rows.length) return 'Joined: this run has no workflow to place in a group.'
      if (!members) return 'No workflow of this run declares a concurrency group.'
      return `${members} of ${rows.length} workflow${rows.length === 1 ? '' : 's'} in a concurrency group`
    }
    default: return state ? `Concurrency ${state}${reason ? `: ${reason}` : ''}` : ''
  }
}

// one workflow's run: its group, its state in plain words with a badge,
// the fine print (run ids, times, the flag), and whether it may be
// cancelled from here
export function workflowRow(w, canCancel = false) {
  const workflow = str(w?.workflow)
  const g = w?.group && typeof w.group === 'object' ? w.group : null
  const kind = g ? str(g.kind) : 'none'
  const stop = cancellationView(w?.cancelled)
  const finished = Boolean(w?.finished)
  const group = kind === 'member' ? str(g.text) : ''
  const behind = kind === 'member' ? runRef(g.behind) : null
  let badge = finished ? 'finished' : 'in progress'
  let tone = ''
  let text = finished ? 'finished' : 'not finished'
  if (kind === 'refused') {
    badge = 'refused'; tone = 'bad'
    text = `refused: its concurrency could not be evaluated: ${str(g.reason)}`
  } else if (stop) {
    badge = 'cancelled'
    text = stop.reason
    if (stop.started && !finished) text += ' — stopping: a job whose condition holds when the run is cancelled, such as always(), still runs'
    if (!stop.started) text += ' — it had not started, so none of its jobs runs'
  } else if (kind === 'member') {
    const place = str(g.place)
    if (place === 'waiting') {
      badge = 'waiting'; tone = 'warn'
      text = behind ? `waiting for run ${behind.label} in group ${group}` : `waiting in group ${group}`
    } else if (place === 'holding') {
      badge = 'in progress'
      text = `in progress in group ${group}`
    } else {
      badge = finished ? 'finished' : 'left its group'
      text = finished ? `finished; it left group ${group}` : `left group ${group}`
    }
  } else if (kind === 'free') {
    text = 'no concurrency group: the workflow declares none'
  } else if (kind === 'unknown') {
    badge = 'unknown'; tone = 'warn'
    text = `concurrency unknown: ${str(g.reason)}`
  }
  const fine = []
  if (kind === 'member') fine.push(g.cancelInProgress ? 'cancel-in-progress: true' : 'cancel-in-progress: false')
  if (kind === 'member' && g.since) fine.push(`${str(g.place) || 'placed'} since ${exactTime(g.since)}`)
  if (behind?.id) fine.push(`behind run ${behind.id}`)
  if (stop?.by?.id) fine.push(`cancelled by run ${stop.by.id}`)
  if (stop?.at) fine.push(`cancelled ${exactTime(stop.at)}`)
  const open = !finished && !stop && kind !== 'refused'
  return {
    workflow,
    name: str(w?.name) || workflow,
    kind,
    group: kind === 'member' ? group : kind === 'none' ? '—' : kind === 'free' ? 'none' : kind,
    badge,
    tone,
    text,
    fine: fine.join(' · '),
    finished,
    cancelled: Boolean(stop),
    open,
    canCancel: Boolean(canCancel) && open,
  }
}

// everything the candidate page's concurrency panel shows for a run, or
// null for a ship that sends no concurrency
export function concurrencyModel(candidate) {
  const c = candidate?.concurrency
  if (!candidate || !c || typeof c !== 'object') return null
  const can = candidate.canCancel === true
  const rows = (Array.isArray(c.workflows) ? c.workflows : []).map((w) => workflowRow(w, can))
  const whole = cancellationView((Array.isArray(candidate.cancellations) ? candidate.cancellations : []).find((x) => x && x.workflow === ''))
  const pending = candidate.status === 'pending'
  return {
    id: str(candidate.id),
    state: str(c.state),
    reason: str(c.reason),
    summary: runSummary(str(c.state), str(c.reason), rows),
    joined: c.joined ? exactTime(c.joined) : '',
    rows,
    whole,
    // the whole run may be cancelled while any workflow of it is open, or
    // before any is known (the ship then cancels the run itself)
    cancelRun: can && (!rows.length || rows.some((r) => r.open)),
    // why there is no Cancel: this ship does not hold the authority
    authority: !can && pending && candidate.cancelAuthority ? str(candidate.cancelAuthority) : '',
    required: candidate.mode === 'required',
  }
}

// the waiting tag a candidate list row shows: a workflow of the run waits
// in its group, and for which run
export function groupWaitTag(candidate) {
  const workflows = Array.isArray(candidate?.concurrency?.workflows) ? candidate.concurrency.workflows : []
  const w = workflows.find((x) => x?.group?.kind === 'member' && x.group.place === 'waiting' && !x.cancelled)
  if (!w) return null
  const behind = runRef(w.group.behind)
  return {
    text: `waiting in group ${str(w.group.text)}`,
    title: behind ? `${str(w.name) || str(w.workflow)} waits for run ${behind.label} in group ${str(w.group.text)}` : `${str(w.name) || str(w.workflow)} waits in group ${str(w.group.text)}`,
  }
}

// the confirmation a Cancel asks for: what stops, what still runs, and
// that a cancelled run is not a pass
export function cancelConfirmation(model, row = null) {
  const landing = model?.required ? ' A cancelled run never lands and does not satisfy the branch\'s required checks.' : ''
  const common = ' Running jobs are stopped and jobs that have not started do not run, except a job whose condition holds when the run is cancelled, such as always(). A running privileged job closes as unknown and needs review: its side effect may already have happened.'
  if (row) {
    return {
      title: `Cancel ${row.name}?`,
      message: `Cancel this run's ${row.name} workflow (${row.workflow}). Only its jobs stop; the run's other workflows keep running.${common} Its result is cancelled, not failed.${landing}`,
      confirmLabel: `Cancel ${row.name}`,
      cancelLabel: 'Keep running',
    }
  }
  return {
    title: 'Cancel this run?',
    message: `Cancel every workflow of this run that has not finished; a finished workflow keeps its result.${common} The run's result is cancelled, not failed.${landing}`,
    confirmLabel: 'Cancel run',
    cancelLabel: 'Keep running',
  }
}

// the panel: the run's state, the Cancel control when this ship may
// cancel (else why not), a refusal in the ship's words, and one row per
// workflow run. h is React.createElement in the tab and a plain tree
// builder in the tests
export function renderConcurrency(h, model, actions = {}) {
  if (!model) return null
  const busy = str(actions.busy)
  return h('div', { className: 'ci-concurrency', 'data-part': 'concurrency' },
    h('div', { className: 'ci-concurrency-head' },
      h('strong', null, 'Concurrency'),
      h('small', { className: 'quiet', 'data-part': 'concurrency-summary' }, model.summary),
      model.cancelRun && h('button', { type: 'button', className: 'button danger', 'data-part': 'cancel-run', disabled: busy !== '', onClick: () => actions.cancel?.('') }, busy === 'run' ? 'Cancelling…' : 'Cancel run')),
    model.whole && h('div', { className: 'ci-concurrency-whole', 'data-part': 'run-cancelled' }, `The whole run: ${model.whole.reason}`),
    model.authority && h('small', { className: 'quiet ci-concurrency-note', 'data-part': 'cancel-authority' }, `No Cancel here: ${model.authority}.`),
    actions.error && h('small', { className: 'field-error ci-concurrency-note', role: 'alert', 'data-part': 'cancel-refused' }, `Not cancelled: ${actions.error}`),
    actions.done && h('small', { className: 'quiet ci-concurrency-note', 'data-part': 'cancel-done' }, actions.done),
    model.rows.length > 0 && h('div', { className: 'ci-list' },
      h('div', { className: 'table-head ci-concurrency-row' }, h('span', null, 'Workflow'), h('span', null, 'Group'), h('span', null, 'State'), h('span', null, '')),
      model.rows.map((r) => h('div', { className: 'ci-concurrency-row', key: r.workflow, 'data-part': 'concurrency-row' },
        h('span', { className: 'ci-job-cell' }, h('strong', null, r.name), h('small', { className: 'quiet ci-job-meta' }, r.workflow)),
        h('span', { 'data-label': 'Group', 'data-part': 'group-name' }, r.group),
        h('span', { className: 'ci-concurrency-state', 'data-label': 'State' },
          h('span', { className: `status ${r.tone}`, 'data-part': 'group-state' }, r.badge), ' ',
          h('span', { 'data-part': 'state-text' }, r.text),
          r.fine && h('small', { className: 'quiet ci-concurrency-fine', 'data-part': 'fine-print' }, r.fine)),
        h('span', { className: 'ci-concurrency-action' },
          r.canCancel && h('button', { type: 'button', className: 'text-button', 'data-part': 'cancel-workflow', disabled: busy !== '', title: `Cancel only ${r.name}`, onClick: () => actions.cancel?.(r.workflow) }, busy === r.workflow ? 'Cancelling…' : 'Cancel'))))))
}
