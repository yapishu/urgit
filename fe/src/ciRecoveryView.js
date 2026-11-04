// CI-RECOVERY-1 (R5.2-A): Settings → CI recovery, rendered. The element
// factory h is React.createElement in the app and a plain tree builder in
// the tests. The same function renders both.
//
// The last checkpoint shows "written" and "replica" as two separate facts.
// A failed or unconfigured replica is an error, never a warning. The
// controls are offered only when the ship grants the viewer authority. A
// staged checkpoint shows its manifest and its diff before Apply, and Apply
// restates what a restore never brings back before it can be pressed.

import { relativeTime } from './format.js'
import {
  applyBlock,
  canManage,
  commitProblem,
  diffSections,
  importBlock,
  isPaused,
  kindWord,
  lastCheckpoint,
  replicaFact,
  shortOid,
  writtenFact,
} from './ciRecovery.js'

const stamp = (seconds) => (Number(seconds) > 0 ? new Date(Number(seconds) * 1000).toISOString().replace('.000Z', 'Z') : '(not recorded)')
const when = (seconds, now) => `${stamp(seconds)}${relativeTime(seconds, now) ? ` (${relativeTime(seconds, now)})` : ''}`

function fact(h, label, value) {
  if (value === null || value === undefined || value === '') return null
  return h('div', { key: label }, h('dt', null, label), h('dd', null, value))
}

// one fact of a checkpoint: its state, tone, label and detail
function factLine(h, part, title, f) {
  return h('div', { className: `ci-backup-fact ${f.tone}`, 'data-part': part, 'data-state': f.state, 'data-tone': f.tone },
    h('span', { className: `status ${f.tone}` }, h('span', { className: `ci-pip ${f.tone}` }), ` ${title}: ${f.label}`),
    h('small', null, ` ${f.detail}`))
}

function checkpointFacts(h, checkpoint) {
  return h('div', { className: 'ci-backup-facts' },
    factLine(h, 'written-fact', 'Checkpoint', writtenFact(checkpoint)),
    factLine(h, 'replica-fact', 'Backup', replicaFact(checkpoint)))
}

function lastBlock(h, view, now) {
  const last = lastCheckpoint(view)
  if (!last) {
    return h('div', { className: 'ci-backup-block', 'data-part': 'last-checkpoint' },
      h('h3', null, 'Last checkpoint'),
      h('p', { className: 'quiet', 'data-part': 'no-checkpoint' }, 'No checkpoint has been written yet. A change of CI policy writes one, and so does Checkpoint now.'))
  }
  return h('div', { className: 'ci-backup-block', 'data-part': 'last-checkpoint', 'data-id': last.id },
    h('h3', null, 'Last checkpoint'),
    h('dl', { className: 'ci-facts' },
      fact(h, 'Id', h('code', null, last.id)),
      fact(h, 'Taken', when(last.at, now)),
      fact(h, 'Cause', last.cause)),
    checkpointFacts(h, last))
}

function repositoryBlock(h, view) {
  const repo = view?.repository || {}
  let where
  if (!repo.readable) where = 'The forge cannot be read, so the checkpoint repository cannot be checked.'
  else if (!repo.exists) where = `${repo.name || 'ci-checkpoints'} does not exist yet. The first checkpoint creates it as a private repository.`
  else where = `${repo.name} is ${repo.private ? 'private' : 'PUBLIC, so no checkpoint is written to it'}, on ${repo.branch || 'its default branch'}.`
  const replica = repo.replica
    ? h('p', { 'data-part': 'replica-route', 'data-tone': 'good' }, `Replica: ${repo.replica}.`)
    : h('p', { className: 'field-error', 'data-part': 'replica-route', 'data-tone': 'bad' }, `No replica: ${repo.replicaProblem || 'none is configured'}.`)
  return h('div', { className: 'ci-backup-block', 'data-part': 'repository' },
    h('p', null, where),
    repo.exists ? replica : null)
}

function pausedBanner(h, view, now) {
  if (!isPaused(view)) return null
  const p = view.paused
  return h('div', { className: 'inline-error ci-backup-paused', role: 'status', 'data-part': 'paused-banner' },
    h('strong', null, 'CI is paused for a restore.'),
    ' No run is admitted, no runner is offered work, no schedule admits a run and nothing lands. ',
    h('small', null, `Paused by ${p.actor || 'the owner'} at ${when(p.at, now)}${p.reason ? `. Reason: ${p.reason}` : ''}.`))
}

function controls(h, props, actions) {
  const { state, view } = props
  const busy = Boolean(state.busy)
  const paused = isPaused(view)
  return h('div', { className: 'ci-backup-controls', 'data-part': 'controls' },
    h('button', { type: 'button', className: 'button', 'data-part': 'checkpoint-now', disabled: busy, onClick: actions.checkpointNow }, state.busy === 'checkpoint-now' ? 'Checkpointing…' : 'Checkpoint now'),
    paused
      ? h('button', { type: 'button', className: 'button primary', 'data-part': 'resume', disabled: busy, onClick: actions.resume }, state.busy === 'resume-ci' ? 'Resuming…' : 'Resume CI')
      : h('div', { className: 'ci-backup-pause' },
        h('input', { type: 'text', 'data-part': 'pause-reason', value: state.reason, placeholder: 'Reason (optional)', 'aria-label': 'Reason for the pause', onChange: (e) => actions.reason(e.target.value) }),
        h('button', { type: 'button', className: 'button danger', 'data-part': 'pause', disabled: busy, onClick: actions.pause }, state.busy === 'pause-ci' ? 'Pausing…' : 'Pause CI')))
}

function sectionRow(h, s) {
  return h('tr', { key: s.name, 'data-part': 'manifest-section', 'data-name': s.name },
    h('td', null, s.file),
    h('td', null, String(s.count)),
    h('td', null, String(s.bytes)),
    h('td', null, h('code', { title: s.sha256 }, shortOid(s.sha256))))
}

function diffBlock(h, diff) {
  const groups = diffSections(diff)
  if (!groups.length) return h('p', { className: 'quiet', 'data-part': 'diff-empty' }, 'The checkpoint matches the current configuration.')
  return h('div', { className: 'ci-backup-diff', 'data-part': 'diff' },
    groups.map((g) => h('div', { key: g.section, 'data-part': 'diff-section', 'data-section': g.section },
      h('h5', null, g.section),
      h('ul', null, g.lines.map((line, i) => h('li', { key: i, className: `ci-backup-${line.kind}`, 'data-part': 'diff-line', 'data-kind': line.kind },
        h('span', { className: 'ci-backup-kind' }, kindWord[line.kind] || line.kind),
        ' ',
        line.repo ? h('code', null, line.repo) : null,
        line.repo ? ' ' : null,
        line.text))))))
}

function applyConfirmation(h, props, actions) {
  const { state, view } = props
  const id = view.staged.id
  return h('div', { className: 'ci-backup-confirm', role: 'alertdialog', 'aria-label': `Apply checkpoint ${id}`, 'data-part': 'apply-confirm' },
    h('p', null, h('strong', null, `Apply checkpoint ${id}?`)),
    h('ul', null,
      h('li', null, 'Its policy, baselines, locks, environments and role bindings replace the current ones of each repository it names.'),
      h('li', null, 'Credential references come back with no value and need re-entry.'),
      h('li', null, 'Approvals and overrides come back as inert history only.'),
      h('li', null, 'Runners come back as records that must re-enroll.'),
      h('li', null, 'This ship keeps its own signing key. The old public key is kept as history.'),
      h('li', null, 'Run summaries come back as history and can land nothing.'),
      h('li', null, 'Nothing runs until you resume CI.')),
    h('label', { className: 'check-row compact' },
      h('input', { type: 'checkbox', 'data-part': 'apply-acknowledge', checked: state.acknowledged, onChange: (e) => actions.acknowledge(e.target.checked) }),
      h('span', null, 'I reviewed the manifest and the diff.')),
    h('div', { className: 'form-actions' },
      h('button', { type: 'button', className: 'button ghost', 'data-part': 'apply-cancel', onClick: actions.cancel }, 'Cancel'),
      h('button', { type: 'button', className: 'button danger', 'data-part': 'apply', disabled: !state.acknowledged || Boolean(state.busy), onClick: actions.apply }, state.busy === 'apply-checkpoint' ? 'Applying…' : 'Apply')))
}

function stagedBlock(h, props, actions) {
  const { state, view, now, manage } = props
  const staged = view?.staged
  if (!staged) return null
  const m = staged.manifest || {}
  const blocked = applyBlock(view)
  return h('section', { className: 'ci-backup-staged', 'data-part': 'staged', 'data-id': staged.id },
    h('h4', null, `Staged checkpoint ${staged.id}`),
    h('dl', { className: 'ci-facts', 'data-part': 'manifest' },
      fact(h, 'Ship', m.ship),
      fact(h, 'Desk', m.desk ? `${m.desk}, revision ${m.revision}` : ''),
      fact(h, 'Taken', when(m.created, now)),
      fact(h, 'Cause', m.cause),
      fact(h, 'Commit', h('code', null, staged.commit)),
      fact(h, 'Imported', `${when(staged.imported, now)} by ${staged.actor}`)),
    h('div', { className: 'ci-backup-table' },
      h('table', null,
        h('thead', null, h('tr', null, h('th', null, 'File'), h('th', null, 'Records'), h('th', null, 'Bytes'), h('th', null, 'sha-256'))),
        h('tbody', null, (m.sections || []).map((s) => sectionRow(h, s))))),
    (m.excluded || []).length ? h('p', { className: 'quiet', 'data-part': 'excluded' }, `Never in a checkpoint: ${m.excluded.join(', ')}.`) : null,
    h('h5', null, 'What an apply changes'),
    diffBlock(h, staged.diff),
    manage
      ? h('div', { className: 'ci-backup-controls' },
        blocked ? h('p', { className: 'field-error', 'data-part': 'apply-blocked' }, blocked) : null,
        state.confirming ? null : h('button', { type: 'button', className: 'button danger', 'data-part': 'open-apply', disabled: Boolean(blocked) || Boolean(state.busy), onClick: actions.openApply }, 'Apply…'),
        h('button', { type: 'button', className: 'button ghost', 'data-part': 'discard', disabled: Boolean(state.busy), onClick: actions.discard }, state.busy === 'discard-checkpoint' ? 'Discarding…' : 'Discard'))
      : null,
    manage && state.confirming && !blocked ? applyConfirmation(h, props, actions) : null)
}

function restoreBlock(h, props, actions) {
  const { state, view, manage } = props
  const blocked = importBlock(view)
  const problem = commitProblem(state.commit)
  return h('div', { className: 'ci-backup-block', 'data-part': 'restore' },
    h('h3', null, 'Restore'),
    h('ol', { className: 'ci-backup-steps' },
      h('li', null, 'Pause CI.'),
      h('li', null, 'Push the replica into ci-checkpoints with git push.'),
      h('li', null, 'Import the checkpoint, then review its manifest and diff.'),
      h('li', null, 'Apply it, re-enter credentials, re-enroll runners, then resume CI.')),
    manage
      ? h('div', { className: 'ci-backup-import' },
        h('input', { type: 'text', 'data-part': 'import-commit', value: state.commit, placeholder: 'Commit (optional, 40 hex)', 'aria-label': 'Commit to import from', onChange: (e) => actions.commit(e.target.value) }),
        h('button', { type: 'button', className: 'button', 'data-part': 'import', disabled: Boolean(blocked) || Boolean(problem) || Boolean(state.busy), onClick: actions.importCheckpoint }, state.busy === 'import-checkpoint' ? 'Importing…' : 'Import'),
        blocked ? h('small', { className: 'field-error', 'data-part': 'import-blocked' }, blocked) : null,
        problem ? h('small', { className: 'field-error', 'data-part': 'commit-problem' }, problem) : null)
      : null,
    stagedBlock(h, props, actions))
}

function historyBlock(h, view, now) {
  const older = (view?.checkpoints || []).slice(1)
  const restores = view?.restores || []
  const history = view?.history || {}
  const runners = history.runners || []
  const credentials = history.credentials || []
  const keys = history.keys || []
  return h('details', { className: 'ci-backup-history', 'data-part': 'history' },
    h('summary', null, `Earlier checkpoints and restores (${older.length + restores.length})`),
    older.length ? h('ul', null, older.map((c) => h('li', { key: c.id, 'data-part': 'checkpoint-row', 'data-id': c.id },
      h('code', null, c.id), ` ${c.cause}`, checkpointFacts(h, c)))) : null,
    restores.length ? h('ul', null, restores.map((r) => h('li', { key: `${r.id}-${r.at}`, 'data-part': 'restore-row' },
      `Applied ${r.id} at ${when(r.at, now)} by ${r.actor}: ${r.repos.length} repositories, ${r.cancelled} open runs cancelled.`,
      r.skipped.length ? h('ul', null, r.skipped.map((s, i) => h('li', { key: i, className: 'field-error', 'data-part': 'restore-skipped' }, s))) : null))) : null,
    credentials.length ? h('div', { 'data-part': 'reentry' },
      h('h5', null, 'Credentials to re-enter'),
      h('ul', null, credentials.map((c) => h('li', { key: `${c.repo}/${c.name}` }, h('code', null, c.name), ` in ${c.repo}: re-enter it in the repository's settings.`)))) : null,
    runners.length ? h('div', { 'data-part': 're-enroll' },
      h('h5', null, 'Runners to re-enroll'),
      h('ul', null, runners.map((r) => h('li', { key: r.id }, h('code', null, r.id), ` ${r.labels.join(', ') || 'no labels'}${r.repos ? `, bound to ${r.repos.join(', ')}` : ''}: mint a new token for it.`)))) : null,
    keys.length ? h('div', { 'data-part': 'old-keys' },
      h('h5', null, 'Earlier CI public keys (history only)'),
      h('ul', null, keys.map((k) => h('li', { key: k.pub }, h('code', null, k.pub), ` of ${k.ship}`)))) : null)
}

export function renderCiRecovery(h, props, actions) {
  const { state, now } = props
  const view = state.view
  const manage = canManage(view)
  const body = { ...props, view, manage }
  return h('section', { className: 'panel ci-backup', 'data-part': 'recovery', 'aria-label': 'CI recovery' },
    h('div', { className: 'section-title' },
      h('div', null, h('h2', null, 'CI recovery'), h('p', null, 'Checkpoints of the CI configuration, a replica of them, and a paused restore.')),
      view ? h('span', { className: `status ${isPaused(view) ? 'bad' : 'good'}`, 'data-part': 'ci-state' }, isPaused(view) ? 'paused' : 'running') : null),
    state.loading && !view ? h('p', { className: 'quiet', 'data-part': 'loading' }, 'Reading the ship…') : null,
    state.denied ? h('p', { className: 'field-error', 'data-part': 'no-authority' }, 'CI recovery belongs to the ship\'s owner, who holds every CI role.') : null,
    state.error && !state.denied ? h('div', { className: 'inline-error', 'data-part': 'load-error' }, `The ship could not be read: ${state.error}`) : null,
    view && !manage ? h('p', { className: 'field-error', 'data-part': 'no-authority' }, 'The ship does not grant this viewer the recovery actions.') : null,
    view ? pausedBanner(h, view, now) : null,
    state.refusal ? h('div', { className: 'inline-error', role: 'alert', 'data-part': 'refusal' }, state.lost ? `No answer came from the ship: ${state.refusal}. Reading the ship again.` : `The ship refused: ${state.refusal}`) : null,
    state.notice ? h('p', { className: 'quiet', role: 'status', 'data-part': 'notice' }, state.notice) : null,
    view ? lastBlock(h, view, now) : null,
    view ? repositoryBlock(h, view) : null,
    view && manage ? controls(h, body, actions) : null,
    view ? restoreBlock(h, body, actions) : null,
    view ? historyBlock(h, view, now) : null)
}
