// The Runners panel's legacy recovery, rendered (legacy-recovery UI ruling
// 01; runner/launcher/INTEGRATION.md §11.12). The modal lists the runner's
// retentions by job, attempt and time. The operator inspects one: what it
// withholds and why, how its slot returns, and for a legacy retention its
// evidence and every condition. A release is offered only for a legacy
// retention its runner reports as releasable. It is confirmed separately:
// the exact entry, revision and evidence are restated and acknowledged,
// and the confirmation holds only while they still match the runner's
// latest report. Each command's state is shown as the ship recorded the
// runner's answer. The element factory h is React.createElement in the
// panel and a plain tree builder in the tests; the same function renders
// both. A runner whose execution history is incomplete shows its history
// first, and its transition is confirmed here too (legacy-replay-upgrade
// ruling 01; runnerHistoryView.js).

import { relativeTime } from './format.js'
import { canRelease, capacityText, commandState, mayPost, retentionRows, shortAttempt, shortDigest, staleReason } from './runnerRecovery.js'
import { historyOperation, historyRow, transitionState } from './runnerHistory.js'
import { renderHistory, renderTransitionConfirmation } from './runnerHistoryView.js'

const pipClass = { completed: 'good', refused: 'bad', expired: 'bad', uncertain: 'warn', pending: 'warn', queued: 'warn', unknown: 'warn' }

const stamp = (seconds) => (Number(seconds) > 0 ? new Date(Number(seconds) * 1000).toISOString().replace('.000Z', 'Z') : '(not recorded)')

function fact(h, label, value) {
  if (value === null || value === undefined || value === '') return null
  return h('div', { key: label }, h('dt', null, label), h('dd', null, value))
}

function contextText(context) {
  if (!context) return ''
  const job = [context.workflow, context.job].filter(Boolean).join(' · ')
  return `${context.repo || 'unknown repository'}${context.ref ? ` ${context.ref}` : ''}${job ? ` · ${job}` : ''} — ${context.kind || 'attempt'} ${context.status || ''}`.trim()
}

function commandLine(h, state, command, now) {
  if (!state) return null
  return h('div', { className: 'ci-recovery-command', 'data-part': 'command-state', 'data-state': state.state },
    h('span', { className: `status ${pipClass[state.state] || ''}` }, h('span', { className: `ci-pip ${pipClass[state.state] || ''}` }), ` ${state.label}`),
    h('small', null, ` ${state.detail}`),
    command ? h('small', { className: 'quiet' }, ` · requested ${relativeTime(command.requested, now) || stamp(command.requested)}${command.delivered ? ` · fetched ${relativeTime(command.delivered, now) || stamp(command.delivered)}` : ''}`) : null)
}

function inspection(h, row, props, actions) {
  const { state, now } = props
  const legacy = row.kind === 'legacy'
  const releasable = canRelease(row)
  return h('section', { className: 'ci-recovery-inspection', 'data-part': 'inspection', 'data-selection': row.selection },
    h('h3', null, row.labelText),
    h('dl', { className: 'ci-facts' },
      fact(h, 'Attempt', row.attempt),
      fact(h, 'The ship', contextText(row.context)),
      fact(h, 'Withholds', `one slot of this runner: ${row.identity}`),
      fact(h, 'Since', row.retained ? `${stamp(row.retained)} (${relativeTime(row.retained, now) || 'just now'})` : ''),
      fact(h, 'Why', row.reason),
      fact(h, 'Returns', `${row.releaseText}. ${row.explanation}`),
      fact(h, 'Provenance', row.legacy ? `legacy: in a state file an earlier runner wrote last (format ${row.legacy.format}), first loaded at ${stamp(row.legacy.found)}` : ''),
      fact(h, 'Revision', String(row.revision))),
    legacy ? h('ul', { className: 'ci-recovery-conditions', 'data-part': 'conditions' },
      row.conditions.map((c) => h('li', { key: c.name, 'data-part': 'condition', 'data-name': c.name, 'data-met': c.met ? 'yes' : 'no', className: c.met ? 'good' : 'bad' },
        h('span', { className: `ci-pip ${c.met ? 'good' : 'bad'}` }), ` ${c.label}: `, h('small', null, c.detail)))) : null,
    legacy && row.facts ? h('dl', { className: 'ci-facts', 'data-part': 'facts' },
      fact(h, 'Launcher', row.facts.error ? `could not answer: ${row.facts.error}` : `${row.facts.launcher || 'unknown'} at ${row.facts.socket || 'unknown'}, protocol ${row.facts.protocol}`),
      fact(h, 'Inventory', row.facts.error ? '' : `${row.facts.records} record(s) of this runner`),
      fact(h, 'Of its attempt', row.facts.error ? '' : (row.facts.held?.length ? row.facts.held.join(', ') : 'nothing')),
      fact(h, 'Evidence', row.evidence ? shortDigest(row.evidence) : '')) : null,
    commandLine(h, row.commandState, row.command, now),
    releasable
      ? h('div', { className: 'form-actions' }, h('button', { type: 'button', className: 'button danger', 'data-part': 'open-confirm', disabled: state.posting || Boolean(state.confirming) || Boolean(state.historyConfirming), onClick: () => actions.openConfirm() }, 'Release this retention…'))
      : h('p', { className: 'quiet', 'data-part': 'not-releasable' },
        legacy
          ? (row.commandState?.open ? 'A command for it is open: its answer comes first.' : `Not releasable now: ${row.unmet.join('; ') || 'the runner does not report it releasable'}. The slot stays withheld.`)
          : `${row.releaseText}.`))
}

function confirmation(h, props, actions) {
  const { runner, state, now } = props
  const b = state.confirming
  const stale = staleReason(b, state.view, now)
  const ready = mayPost(state, now)
  return h('section', { className: 'modal-card confirm-card ci-recovery-confirm', role: 'alertdialog', 'aria-modal': 'true', 'aria-label': 'Confirm the release', 'data-part': 'confirmation' },
    h('header', null, h('div', null, h('span', { className: 'eyebrow' }, 'Confirm'), h('h1', null, 'Release this legacy retention?'))),
    h('div', { className: 'modal-body' },
      h('p', { 'data-part': 'restated' }, `Release the legacy retention of ${b.label} (attempt ${shortAttempt(b.attempt)}) on runner ${String(runner.id).slice(0, 12)}: revision ${b.revision}, on the evidence inspected at ${stamp(b.at)} (digest ${shortDigest(b.evidence)}).`),
      h('small', null, 'The runner checks all of this again when it carries the release out, and refuses if anything changed. Its slot returns only once the runner has saved the release durably.'),
      stale ? h('small', { className: 'field-error', 'data-part': 'stale' }, stale) : null,
      h('label', { className: 'check-row compact' },
        h('input', { type: 'checkbox', 'data-part': 'acknowledge', checked: state.acknowledged, disabled: Boolean(stale) || state.posting, onChange: (e) => actions.acknowledge(e.target.checked) }),
        h('span', null, 'I inspected this evidence: this entry was written by a runner before settled admission, and the launcher holds nothing of its attempt.')),
      state.postError ? h('small', { className: 'field-error', 'data-part': 'post-error' }, state.postError) : null,
      h('div', { className: 'form-actions' },
        h('button', { type: 'button', className: 'button ghost', 'data-part': 'cancel', disabled: state.posting, onClick: () => actions.cancel() }, 'Cancel'),
        h('button', { type: 'button', className: 'button danger', 'data-part': 'release', disabled: !ready, onClick: () => actions.release() }, state.posting ? 'Requesting…' : 'Release'))))
}

// renderRecovery is the whole modal for props {runner, state, now}.
export function renderRecovery(h, props, actions) {
  const { runner, state, now } = props
  const view = state.view
  const rows = retentionRows(view, now)
  const selected = rows.find((r) => r.selection === state.selected) || null
  const commands = Array.isArray(view?.commands) ? view.commands : []
  // a runner waiting for its history transition is opened for it
  const title = historyRow(view, now)?.paused ? 'Execution paused' : 'Withheld slots'
  return h('div', { className: 'modal-backdrop', onMouseDown: (event) => { if (event?.target === event?.currentTarget) actions.close() } },
    h('section', { className: 'modal-card ci-recovery', role: 'dialog', 'aria-modal': 'true', 'aria-label': title },
      h('header', null,
        h('div', null, h('span', { className: 'eyebrow' }, `Runner ${String(runner.id).slice(0, 12)}`), h('h1', null, title)),
        h('button', { type: 'button', className: 'icon-button', 'aria-label': 'Close', 'data-part': 'close', onClick: () => actions.close() }, '×')),
      h('div', { className: 'modal-body' },
        state.loadError ? h('small', { className: 'field-error', 'data-part': 'load-error' }, `Retentions unavailable: ${state.loadError}`) : null,
        !view && !state.loadError ? h('p', { 'data-part': 'loading' }, 'Reading the runner’s retentions…') : null,
        view && !view.report ? h('p', { className: 'quiet', 'data-part': 'no-report' }, 'This runner has not reported its retentions: it runs a version before Urgit recovery, or has not polled since. Nothing can be released from here until it does.') : null,
        view?.report ? h('p', { className: 'quiet', 'data-part': 'capacity' }, `${capacityText(view)} — reported ${relativeTime(view.reported, now) || 'just now'}.`) : null,
        state.notice ? h('small', { className: 'quiet', 'data-part': 'notice' }, state.notice) : null,
        view?.report ? renderHistory(h, props, actions) : null,
        view?.report && !rows.length ? h('p', { className: 'quiet', 'data-part': 'none' }, 'It withholds no slot.') : null,
        rows.length ? h('div', { className: 'ci-list', 'data-part': 'retentions' },
          rows.map((row) => h('button', { key: row.selection, type: 'button', className: `ci-recovery-row${row.selection === state.selected ? ' selected' : ''}`, 'data-part': 'retention', 'data-kind': row.kind, 'aria-pressed': row.selection === state.selected ? 'true' : 'false', onClick: () => actions.select(row.selection) },
            h('span', null, h('strong', null, row.labelText), h('small', { className: 'quiet' }, ` · attempt ${shortAttempt(row.attempt)}`)),
            h('span', { className: `status${row.kind === 'legacy' ? ' warn' : ''}` }, row.kindText),
            h('small', { className: 'quiet' }, row.retained ? relativeTime(row.retained, now) || 'just now' : '—'),
            h('small', null, row.commandState ? row.commandState.label : row.kind === 'legacy' ? (row.eligible ? 'releasable' : 'not releasable now') : row.releaseText)))) : null,
        selected ? inspection(h, selected, props, actions) : null,
        commands.length ? h('details', { className: 'ci-recovery-history', 'data-part': 'commands' },
          h('summary', null, `Recovery commands (${commands.length})`),
          commands.map((c) => h('div', { key: c.id, 'data-part': 'command', 'data-id': c.id },
            h('small', null, `${c.label || c.selection} · `), commandLine(h, c.operation === historyOperation ? transitionState(c, now) : commandState(c, now), c, now)))) : null,
        h('div', { className: 'form-actions split' },
          h('small', { className: 'quiet' }, 'A release comes from here only for a legacy retention, and only on its evidence; every other retention returns its slot as its line says.'),
          h('button', { type: 'button', className: 'text-button', 'data-part': 'refresh', onClick: () => actions.refresh() }, 'Refresh')))),
    state.confirming ? h('div', { className: 'modal-backdrop ci-recovery-confirm-backdrop' }, confirmation(h, props, actions)) : null,
    state.historyConfirming ? h('div', { className: 'modal-backdrop ci-recovery-confirm-backdrop' }, renderTransitionConfirmation(h, props, actions)) : null)
}
