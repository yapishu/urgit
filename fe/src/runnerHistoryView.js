// The Runners panel's execution-history transition, rendered (legacy-
// replay-upgrade ruling 01; runner/launcher/INTEGRATION.md §11.15). The
// runner's history is shown as its report says it: complete, waiting for
// its transition, or transitioned to an authorization epoch; with its
// evidence, and what the ship holds of its authorizations. While it waits,
// the owner inspects the proof the transition stands on and confirms it
// separately: the exact history, revision and evidence are restated and
// acknowledged, and the confirmation holds only while they still match the
// runner's latest report. The transition command's state is the ship's
// record of the runner's answer. The element factory h is
// React.createElement in the panel and a plain tree builder in the tests.

import { relativeTime } from './format.js'
import { shortDigest } from './runnerRecovery.js'
import { canTransition, historyRow, historyState, mayTransition, transitionProof, transitionStaleReason } from './runnerHistory.js'

const pipClass = { complete: 'good', transitioned: 'good', waiting: 'bad', unknown: 'warn', completed: 'good', refused: 'bad', expired: 'bad', uncertain: 'warn', pending: 'warn', queued: 'warn' }

const stamp = (seconds) => (Number(seconds) > 0 ? new Date(Number(seconds) * 1000).toISOString().replace('.000Z', 'Z') : '(not recorded)')

function fact(h, label, value) {
  if (value === null || value === undefined || value === '') return null
  return h('div', { key: label }, h('dt', null, label), h('dd', null, value))
}

// renderHistory is the history's section of the panel for props {runner,
// state, now}, or null when the runner reports no history.
export function renderHistory(h, props, actions) {
  const { state, now } = props
  const row = historyRow(state.view, now)
  if (!row) return null
  const status = historyState(row)
  const command = row.command
  const cs = row.commandState
  return h('section', { className: 'ci-history', 'data-part': 'history', 'data-state': status.state },
    h('h3', null, 'Execution history'),
    h('p', { 'data-part': 'history-state' },
      h('span', { className: `status ${pipClass[status.state] || ''}` }, h('span', { className: `ci-pip ${pipClass[status.state] || ''}` }), ` ${status.label}`),
      h('small', null, ` ${status.detail}`)),
    h('dl', { className: 'ci-facts', 'data-part': 'history-facts' },
      fact(h, 'History since', row.known ? `${stamp(row.since)} (${relativeTime(row.since, now) || 'just now'})` : 'not recorded: its HISTORY cannot be read'),
      fact(h, 'State file', row.complete ? '' : `format ${row.stateFormat}${row.stateFormat === 0 ? ' (an earlier version’s)' : ''}`),
      fact(h, 'Authorization epoch', String(row.epoch)),
      fact(h, 'Transition', row.transition ? `epoch ${row.transition.epoch}, recorded ${stamp(row.transition.at)} by command ${String(row.transition.command).slice(0, 14)}` : ''),
      fact(h, 'Transition record', row.invalid ? `no transition: ${row.invalid.problem}. Kept as the state file holds it: ${row.invalid.record}` : ''),
      fact(h, 'Evidence', row.evidence ? shortDigest(row.evidence) : ''),
      fact(h, 'The ship', row.ship ? `${row.ship.assignments} assignment${row.ship.assignments === 1 ? '' : 's'} held for it; ${row.ship.running.length} attempt${row.ship.running.length === 1 ? '' : 's'} running on it; its epoch ${row.ship.epoch}` : '')),
    cs ? h('div', { className: 'ci-recovery-command', 'data-part': 'history-command', 'data-state': cs.state },
      h('span', { className: `status ${pipClass[cs.state] || ''}` }, h('span', { className: `ci-pip ${pipClass[cs.state] || ''}` }), ` ${cs.label}`),
      h('small', null, ` ${cs.detail}`),
      command ? h('small', { className: 'quiet' }, ` · requested ${relativeTime(command.requested, now) || stamp(command.requested)}`) : null) : null,
    row.paused ? h('div', { 'data-part': 'proof' },
      h('p', null, 'Its transition stands on what the software checks, not on anyone’s word:'),
      h('ul', null, transitionProof(row).map((line, i) => h('li', { key: i }, line)))) : null,
    canTransition(row)
      ? h('div', { className: 'form-actions' }, h('button', { type: 'button', className: 'button danger', 'data-part': 'open-transition', disabled: state.posting || Boolean(state.historyConfirming) || Boolean(state.confirming), onClick: () => actions.openTransition() }, 'Confirm its transition…'))
      : row.paused
        ? h('p', { className: 'quiet', 'data-part': 'no-transition' },
          cs?.open ? 'A transition command is open: its answer comes first.'
            : row.awaitingReport ? 'The runner answered that it recorded its transition; its next report shows it.'
              : 'No transition can be confirmed now: the runner reports no evidence to bind.')
        : null)
}

// renderTransitionConfirmation is the confirmation of the transition being
// confirmed (state.historyConfirming).
export function renderTransitionConfirmation(h, props, actions) {
  const { runner, state, now } = props
  const b = state.historyConfirming
  const stale = transitionStaleReason(b, state.view, now)
  const ready = mayTransition(state, now)
  return h('section', { className: 'modal-card confirm-card ci-recovery-confirm', role: 'alertdialog', 'aria-modal': 'true', 'aria-label': 'Confirm the transition', 'data-part': 'transition-confirmation' },
    h('header', null, h('div', null, h('span', { className: 'eyebrow' }, 'Confirm'), h('h1', null, 'Transition this runner?'))),
    h('div', { className: 'modal-body' },
      h('p', { 'data-part': 'transition-restated' }, `Take runner ${String(runner.id).slice(0, 12)} to authorization epoch ${b.epoch ?? 'next'}: its history ${b.selection}, revision ${b.revision}, on the evidence inspected at ${stamp(b.at)} (digest ${shortDigest(b.evidence)}).`),
      h('small', null, 'The runner checks all of this again when it carries the transition out, and refuses if anything changed. It runs new work only once it has recorded the transition durably; until then it keeps waiting.'),
      stale ? h('small', { className: 'field-error', 'data-part': 'transition-stale' }, stale) : null,
      h('label', { className: 'check-row compact' },
        h('input', { type: 'checkbox', 'data-part': 'transition-acknowledge', checked: state.historyAcknowledged, disabled: Boolean(stale) || state.posting, onChange: (e) => actions.acknowledgeTransition(e.target.checked) }),
        h('span', null, 'I inspected its history: from this transition on, nothing its ship authorized before runs on this runner, and new work does.')),
      state.postError ? h('small', { className: 'field-error', 'data-part': 'post-error' }, state.postError) : null,
      h('div', { className: 'form-actions' },
        h('button', { type: 'button', className: 'button ghost', 'data-part': 'transition-cancel', disabled: state.posting, onClick: () => actions.cancelTransition() }, 'Cancel'),
        h('button', { type: 'button', className: 'button danger', 'data-part': 'transition', disabled: !ready, onClick: () => actions.transition() }, state.posting ? 'Requesting…' : 'Transition'))))
}
