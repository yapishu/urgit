// The views of Delivery 1C's CI surfaces, over an injected createElement so
// the same views render in the CI tab and in the tests: a run's selection
// (on the candidate page), the recorded source events, and the schedules.
// Text only: every server string is a child, never markup. Times are the
// ship's: an event's recorded instant formatted for this browser, a
// schedule's next and last occurrences exactly as the ship rendered them
// (UTC and the zone's wall clock from its pinned table).

import { exactTime } from './format.js'
import { pullHref } from './ciEvents.js'

// a run's selection: what was compared, every workflow's verdict and
// reason, and for a required run what the selection means for its checks
export function renderSelection(h, model) {
  if (!model) return null
  return h('div', { className: 'ci-selection', 'data-part': 'selection' },
    h('div', { className: 'ci-selection-head' },
      h('strong', null, 'Selection'),
      h('small', { className: 'quiet', 'data-part': 'selection-basis' }, model.basis)),
    model.note && h('small', { className: 'quiet ci-selection-note', 'data-part': 'selection-note' }, model.note),
    model.required && h('div', { className: `ci-required status ${model.required.tone}`, 'data-part': 'required-evidence' }, model.required.text),
    h('div', { className: 'ci-list' },
      h('div', { className: 'table-head ci-selection-row' }, h('span', null, 'Workflow'), h('span', null, 'Verdict'), h('span', null, 'Reason')),
      model.rows.map((r) => h('div', { className: 'ci-selection-row', key: r.workflow, 'data-part': 'selection-row' },
        h('span', { className: 'ci-job-cell' }, h('strong', null, r.name), h('small', { className: 'quiet ci-job-meta' }, r.workflow)),
        h('span', { className: `status ${r.tone}`, 'data-part': 'selection-verdict' }, r.verdictText),
        h('small', { className: 'quiet ci-selection-reason', 'data-label': 'Reason' }, r.reason))),
      !model.rows.length && h('div', { className: 'empty' }, 'No workflow in this revision declares this event.')))
}

const panelHead = (h, note, refreshPart, onRefresh, busy) =>
  h('div', { className: 'form-actions split' },
    h('small', { className: 'quiet' }, note),
    h('button', { type: 'button', className: 'text-button', 'data-part': refreshPart, disabled: busy, onClick: onRefresh }, busy ? 'Reading…' : 'Refresh'))

function selectionDetails(h, selection) {
  const c = selection.counts
  return h('details', { className: 'ci-event-selection', 'data-part': 'event-selection' },
    h('summary', null, `${c.selected} selected · ${c.excluded} filtered out · ${c.error} in error`),
    selection.basis && h('small', { className: 'quiet' }, selection.basis),
    selection.note && h('small', { className: 'quiet' }, selection.note),
    selection.rows.map((r) => h('div', { className: 'ci-event-outcome', key: r.workflow },
      h('span', { className: `status ${r.tone}` }, r.verdictText), ' ',
      h('strong', null, r.name), ' ', h('small', { className: 'quiet' }, r.reason))))
}

function eventRow(h, row, repo, actions) {
  return h('div', { className: 'ci-event-row', key: row.id, 'data-part': 'event-row' },
    h('span', { className: 'ci-job-cell' },
      h('strong', null, row.kindText),
      h('small', { className: 'quiet ci-job-meta' }, row.branch, row.move ? ` · ${row.move}` : '')),
    h('span', { className: 'ci-job-cell', 'data-label': 'Actor · route' },
      h('span', null, row.actor),
      h('small', { className: 'quiet ci-job-meta' }, row.route)),
    h('span', { className: 'ci-event-outcome-cell', 'data-label': 'Outcome' },
      h('span', { className: `status ${row.tone}` }, row.outcome),
      row.pull && h('small', { className: 'ci-event-pull' },
        h('a', { href: pullHref(repo, row.pull.number), 'data-part': 'open-pull', onClick: (event) => { event?.preventDefault?.(); actions.openPull(row.pull.number) } }, `#${row.pull.number}`), ' ',
        h('span', { 'data-part': 'pull-title' }, row.pull.title),
        h('span', { className: 'quiet' }, ` · ${row.pull.headBranch} → ${row.pull.baseBranch} · ${row.pull.author}`)),
      row.runs.map((id) => h('button', { type: 'button', className: 'text-button', key: id, 'data-part': 'open-run', onClick: () => actions.openRun(id) }, `open run ${id}`)),
      renderTagProvenance(h, row.workflowProvenance),
      row.selection && selectionDetails(h, row.selection)),
    h('span', { title: 'recorded by the ship', 'data-label': 'Recorded' }, exactTime(row.received)))
}

// the recorded source events: every write the forge persisted on a
// repository with CI, newest first, with what it selected and the runs it
// made; a refusal or a write that ran nothing keeps its reason
export function renderEventLog(h, { phase, error, rows, repo }, actions) {
  const head = panelHead(h, 'Writes the forge persisted, newest first, as the ship recorded them: what each selected and why, and the runs it made.', 'events-refresh', actions.refresh, phase === 'loading' && Boolean(rows))
  let body
  if (phase === 'error') {
    body = h('div', { className: 'empty', 'data-part': 'events-error' }, `Events unavailable: ${error} `,
      h('button', { type: 'button', className: 'text-button', 'data-part': 'events-retry', onClick: actions.retry }, 'Retry'))
  } else if (!rows) {
    body = h('div', { className: 'empty', 'data-part': 'events-loading' }, 'Loading recorded events…')
  } else if (!rows.length) {
    body = h('div', { className: 'empty', 'data-part': 'events-empty' }, 'No source event is recorded for this repository yet. A push, a branch or tag change, a pull request activity or a default-branch move on a repository with CI is recorded here with what it selected.')
  } else {
    body = h('div', { className: 'ci-list' },
      h('div', { className: 'table-head ci-event-row' }, h('span', null, 'Event'), h('span', null, 'Actor · route'), h('span', null, 'Outcome'), h('span', null, 'Recorded')),
      rows.map((row) => eventRow(h, row, repo, actions)))
  }
  return h('div', { className: 'ci-events', 'data-part': 'events' }, head, body)
}

// a schedule's row; its last occurrence wraps rather than truncating
// (ci-schedule-last, not ci-job-meta), so the open run after it stays in
// the cell
function scheduleRow(h, row, actions) {
  const last = row.lastAdmitted
  return h('div', { className: 'ci-schedule-row', key: row.key, 'data-part': 'schedule-row' },
    h('span', { className: 'ci-job-cell' },
      h('strong', { 'data-part': 'schedule-title' }, row.title, h('small', { className: 'quiet' }, ` · ${row.entry}`)),
      h('small', { className: 'quiet ci-job-meta' }, h('code', { 'data-part': 'schedule-cron' }, row.cron), ' · ', h('span', { 'data-part': 'schedule-zone' }, row.zone))),
    h('span', { className: 'ci-job-cell' },
      h('span', { className: `status ${row.tone}` }, row.stateText),
      row.reason && h('small', { className: 'quiet ci-job-meta' }, row.reason)),
    h('span', { className: 'ci-job-cell' },
      row.next
        ? h('span', { 'data-part': 'schedule-next' }, `next ${row.next.local}`, h('small', { className: 'quiet' }, ` · ${row.next.utc}`))
        : h('small', { className: 'quiet' }, 'no next occurrence'),
      (row.lastDue || last) && h('small', { className: 'quiet ci-schedule-last', 'data-part': 'schedule-last' },
        row.lastDue ? `last due ${row.lastDue.local}` : '',
        last ? ` · admitted ${last.at?.local || ''} (${last.lateText}) ` : '',
        last?.run && h('button', { type: 'button', className: 'text-button', 'data-part': 'open-run', onClick: () => actions.openRun(last.run) }, 'open run'))),
    h('span', { className: 'ci-job-cell' },
      h('small', { 'data-part': 'schedule-provenance' }, `${row.provenance} · from ${row.definitionRef}`),
      row.missed.length > 0 && h('small', { className: 'quiet ci-job-meta', 'data-part': 'schedule-missed' }, row.missed.map((m) => m.text).join('; ')),
      row.staleWakes > 0 && h('small', { className: 'quiet ci-job-meta' }, `${row.staleWakes} stale wake${row.staleWakes === 1 ? '' : 's'} ignored`)))
}

// the schedules of the default branch's promoted baseline, by title, with
// the ship's own next and last occurrences; refresh says what the ship
// needs before anything is scheduled
export function renderSchedules(h, { phase, error, model }, actions) {
  const head = panelHead(h, 'Schedules come from the YAML of the default branch\'s promoted baseline; edit them there. The ship arms each one and computes every time shown.', 'schedules-refresh-button', actions.refresh, phase === 'loading' && Boolean(model))
  let body
  if (phase === 'error') {
    body = h('div', { className: 'empty', 'data-part': 'schedules-error' }, `Schedules unavailable: ${error} `,
      h('button', { type: 'button', className: 'text-button', 'data-part': 'schedules-retry', onClick: actions.retry }, 'Retry'))
  } else if (!model) {
    body = h('div', { className: 'empty', 'data-part': 'schedules-loading' }, 'Loading schedules…')
  } else {
    body = h('div', null,
      h('small', { className: 'quiet', 'data-part': 'schedules-as-of' }, `As the ship computed them at ${model.asOf}${model.defaultBranch ? `, for the default branch ${model.defaultBranch}` : ''}.`),
      model.refresh && h('div', { className: 'empty ci-first-run', 'data-part': 'schedules-refresh' }, `Nothing new is scheduled: ${model.refresh}`),
      model.rows.length
        ? h('div', { className: 'ci-list ci-schedule-list' },
          h('div', { className: 'table-head ci-schedule-row' }, h('span', null, 'Schedule'), h('span', null, 'State'), h('span', null, 'Next · last'), h('span', null, 'Provenance')),
          model.rows.map((row) => scheduleRow(h, row, actions)))
        : h('div', { className: 'empty', 'data-part': 'schedules-empty' }, 'No schedule is registered for this repository\'s default branch. A workflow with on.schedule at the promoted baseline of the default branch is listed here once the ship arms it.'))
  }
  return h('div', { className: 'ci-schedules', 'data-part': 'schedules' }, head, body)
}

// Captured provenance, supplied by the controller. Identifiers stay in
// details, while names and the resolution state remain visible.
export function renderTagProvenance(h, p) {
  if (p?.authority !== 'tagged-revision') return null
  const state = p.resolution === 'resolved' ? 'Dependencies resolved' : `Dependency resolution ${p.resolution || 'unknown'}`
  return h('div', { 'data-part': 'tag-provenance' },
    h('strong', null, 'Tagged revision workflows'),
    h('small', { className: 'quiet' }, ` · ${state}. Advisory only. No credentials, landing, or required-check credit.`),
    h('details', null,
      h('summary', null, 'Source, workflow and lock details'),
      h('dl', { className: 'ci-facts' },
        h('div', null, h('dt', null, 'Source commit'), h('dd', null, h('code', null, p.source || 'unavailable'))),
        h('div', null, h('dt', null, 'Workflow revision'), h('dd', null, h('code', null, p.revision || 'unavailable'))),
        h('div', null, h('dt', null, 'Dependency lock'), h('dd', null, h('code', null, p.lock || 'not resolved'))))))
}
