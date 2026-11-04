// CI-RECOVERY-1 (R5.2-A): the model of Settings → CI recovery.
//
// The ship writes a checkpoint of its CI configuration to the private
// repository ci-checkpoints, then pushes it to that repository's own
// replica. "Written" and "replica confirmed" are two separate facts, and
// only the replica's own acceptance confirms a backup. A failed push is a
// failed backup, shown as an error and never as a warning.
//
// A restore is paused, imported, reviewed and applied by the owner, one
// action at a time. Every refusal is shown in the ship's own words.

export const recoveryActions = {
  checkpointNow: () => ({ action: 'checkpoint-now' }),
  pause: (reason) => ({ action: 'pause-ci', reason: (reason || '').trim() }),
  resume: () => ({ action: 'resume-ci' }),
  importCheckpoint: (commit) => {
    const value = (commit || '').trim()
    return value ? { action: 'import-checkpoint', commit: value } : { action: 'import-checkpoint' }
  },
  discard: () => ({ action: 'discard-checkpoint' }),
  apply: (checkpoint) => ({ action: 'apply-checkpoint', checkpoint }),
}

export const shortOid = (oid) => (typeof oid === 'string' && oid.length >= 12 ? oid.slice(0, 12) : oid || '')

// the written fact of a checkpoint, in words
export function writtenFact(checkpoint) {
  const w = checkpoint?.written || {}
  switch (w.state) {
    case 'written':
      return { state: 'written', tone: 'good', label: 'Written', detail: `commit ${shortOid(checkpoint.commit)} on ${checkpoint.ref || 'its branch'}` }
    case 'failed':
      return { state: 'failed', tone: 'bad', label: 'Not written', detail: w.reason || 'The forge refused the write.' }
    case 'pending':
      return { state: 'pending', tone: 'warn', label: 'Writing', detail: 'The forge has not answered the write yet.' }
    default:
      return { state: 'unknown', tone: 'bad', label: 'Write unknown', detail: 'The ship sent no write state.' }
  }
}

// the replica fact of a checkpoint, in words: only "confirmed" is a backup
export function replicaFact(checkpoint) {
  const r = checkpoint?.replica || {}
  switch (r.state) {
    case 'confirmed':
      return { state: 'confirmed', tone: 'good', label: 'Replica confirmed', detail: r.route ? `Accepted by ${r.route}.` : 'Accepted by the replica.' }
    case 'failed':
      return { state: 'failed', tone: 'bad', label: 'Backup failed', detail: r.reason || 'The push failed.' }
    case 'unconfigured':
      return { state: 'unconfigured', tone: 'bad', label: 'Replica not confirmed', detail: r.reason || 'No replica is configured.' }
    case 'pushing':
      return { state: 'pushing', tone: 'warn', label: 'Pushing to the replica', detail: r.route ? `To ${r.route}.` : 'The push has started.' }
    case 'waiting':
      return { state: 'waiting', tone: 'warn', label: 'Waiting to push', detail: 'It is pushed once the write and any push in flight are done.' }
    case 'skipped':
      return { state: 'skipped', tone: 'bad', label: 'Nothing pushed', detail: r.reason || 'The checkpoint was not written.' }
    default:
      return { state: 'unknown', tone: 'bad', label: 'Replica unknown', detail: 'The ship sent no replica state.' }
  }
}

// whether the ship's answer grants this viewer the recovery actions
export const canManage = (view) => view?.authority?.manage === true
export const isPaused = (view) => Boolean(view?.paused)
export const lastCheckpoint = (view) => (view?.checkpoints || [])[0] || null

// whether a checkpoint is still on its way: read the ship again until not
export function inFlight(view) {
  return (view?.checkpoints || []).some((c) => c?.written?.state === 'pending' || ['waiting', 'pushing'].includes(c?.replica?.state))
}

// a commit to import from, when one is named: forty lowercase hex digits
export const commitProblem = (text) => {
  const value = (text || '').trim()
  if (!value) return ''
  return /^[0-9a-f]{40}$/.test(value) ? '' : 'A commit is 40 lowercase hex digits. Leave it empty to import the tip.'
}

// why Import is not offered now, or '' when it is
export function importBlock(view) {
  if (!isPaused(view)) return 'Pause CI first. An import into a running CI is refused.'
  return ''
}

// why Apply is not offered now, or '' when it is
export function applyBlock(view) {
  if (!view?.staged) return 'Import a checkpoint first.'
  if (!isPaused(view)) return 'Pause CI first. An apply to a running CI is refused.'
  const running = Number(view?.running) || 0
  if (running > 0) return `${running} ${running === 1 ? 'attempt is' : 'attempts are'} still running. Wait for them or cancel them, then apply.`
  return ''
}

// the staged checkpoint's diff, by section, in the order the ship wrote it
export function diffSections(diff) {
  const order = []
  const bySection = new Map()
  for (const line of diff || []) {
    if (!bySection.has(line.section)) {
      bySection.set(line.section, [])
      order.push(line.section)
    }
    bySection.get(line.section).push(line)
  }
  return order.map((section) => ({ section, lines: bySection.get(section) }))
}

export const kindWord = { add: 'adds', remove: 'removes', change: 'changes', history: 'history' }

// a post whose answer never came: the network failed, not the ship (a
// refusal carries the ship's status)
export const lostPost = (cause) => !(cause && Number.isFinite(cause.status))

// a read the ship refused for want of authority
export const noAuthority = (cause) => Boolean(cause) && (cause.status === 401 || cause.status === 403)

export const initialRecoveryView = () => ({
  view: null,
  loading: true,
  error: '',
  denied: false,
  busy: '',
  refusal: '',
  lost: false,
  notice: '',
  reason: '',
  commit: '',
  confirming: false,
  acknowledged: false,
})

export function recoveryReducer(state, event) {
  switch (event.type) {
    case 'loaded':
      return { ...state, view: event.view, loading: false, error: '', denied: false }
    case 'load-failed':
      return { ...state, loading: false, error: event.error, denied: Boolean(event.denied) }
    case 'reason':
      return { ...state, reason: event.value }
    case 'commit':
      return { ...state, commit: event.value }
    case 'post-start':
      return { ...state, busy: event.action, refusal: '', lost: false, notice: '' }
    case 'post-done':
      return { ...state, busy: '', notice: event.notice || '', confirming: false, acknowledged: false, reason: event.action === 'pause-ci' ? '' : state.reason }
    case 'post-failed':
      return { ...state, busy: '', refusal: event.error || 'The action failed.', lost: Boolean(event.lost) }
    case 'confirm-open':
      return { ...state, confirming: true, acknowledged: false, refusal: '' }
    case 'confirm-cancel':
      return { ...state, confirming: false, acknowledged: false }
    case 'acknowledge':
      return { ...state, acknowledged: Boolean(event.value) }
    default:
      return state
  }
}

// what an action leaves the operator to read, once the ship accepted it
export const doneNotice = {
  'checkpoint-now': 'Checkpoint requested. Written and replica are shown separately below.',
  'pause-ci': 'CI is paused. Nothing runs, is offered or lands until you resume it.',
  'resume-ci': 'CI resumed. Resuming ran nothing and landed nothing.',
  'import-checkpoint': 'Checkpoint staged. Review its manifest and diff before you apply it.',
  'discard-checkpoint': 'The staged checkpoint was discarded.',
  'apply-checkpoint': 'Checkpoint applied. CI stays paused until you resume it.',
}
