// The Run workflow form's pure helpers (Delivery 1A): the ship's dispatch
// inventory (GET ci/repository/<name>/dispatch) as the workflow and branch
// choices with the reason each unavailable one cannot run, the control
// each declared input type gets, the checks the ship makes in the ship's
// own words, the typed request body, the classification of the ship's
// answer, the form's state, and the rows a run's admitted event is shown
// with. The inventory is the ship's — the workflows its resolver read at
// each branch's promoted baseline — never a catalog of this page's own.
// Nothing here fetches or renders markup.

import { branchLabel } from './ci.js'
import { instant, labelChange, lateText, pullActivity } from './ciEvents.js'

// a number as the ship admits it: plain decimal text, no exponent, no
// leading zero, at most 32 characters
const NUMBER = /^-?(0|[1-9][0-9]*)(\.[0-9]+)?$/

// the workflows the ship lists, by name: one is available when some branch
// can run it now; a refused one keeps the ship's reason
export function workflowChoices(inventory) {
  const byFile = new Map()
  for (const ref of inventory?.refs || []) {
    for (const w of ref.workflows || []) {
      const usable = Boolean(ref.available) && !w.refusal
      const seen = byFile.get(w.workflow)
      if (!seen) byFile.set(w.workflow, { workflow: w.workflow, name: w.name || w.workflow, available: usable, refusal: w.refusal || '' })
      else {
        seen.available = seen.available || usable
        if (!w.refusal) seen.refusal = ''
      }
    }
  }
  return [...byFile.values()]
    .map((c) => ({ ...c, reason: c.available ? '' : c.refusal ? `cannot run manually: ${c.refusal}` : 'no branch can run it now' }))
    .sort((a, b) => a.name.localeCompare(b.name) || a.workflow.localeCompare(b.workflow))
}

// every branch by name, with whether it can run the workflow now and, when
// it cannot, why: no promoted baseline, the ship's own reason, a baseline
// whose workflow does not declare workflow_dispatch, or a refused workflow
export function refChoices(inventory, workflow, repoRefs = []) {
  const listed = new Map((inventory?.refs || []).map((r) => [r.ref, r]))
  const names = new Set([...(repoRefs || []).map((r) => r.name).filter((n) => String(n).startsWith('refs/heads/')), ...listed.keys()])
  return [...names]
    .sort((a, b) => branchLabel(a).localeCompare(branchLabel(b)))
    .map((ref) => {
      const label = branchLabel(ref)
      const entry = listed.get(ref)
      const tip = entry?.tip || (repoRefs || []).find((r) => r.name === ref)?.oid || ''
      const unavailable = (reason) => ({ ref, label, tip, available: false, reason })
      if (!entry) return unavailable(`no promoted baseline for ${label}: promote a harness revision (Settings → CI policy) to run its workflows manually`)
      if (!entry.available) return unavailable(entry.reason || `${label} cannot run a workflow now`)
      const declared = (entry.workflows || []).find((w) => w.workflow === workflow)
      if (!declared) return unavailable(`${workflow} does not declare workflow_dispatch at ${label}'s promoted baseline`)
      if (declared.refusal) return unavailable(`cannot run manually: ${declared.refusal}`)
      return { ref, label, tip, available: true, reason: '' }
    })
}

// the declaration a dispatch is admitted against: the workflow as the
// branch's baseline lock lists it, or null when the branch cannot run now
export function definitionFor(inventory, ref, workflow) {
  const entry = (inventory?.refs || []).find((r) => r.ref === ref)
  if (!entry || !entry.available) return null
  return (entry.workflows || []).find((w) => w.workflow === workflow) || null
}

// the control each declared type gets
export function controlKind(input) {
  switch (input?.type) {
    case 'boolean': return 'toggle'
    case 'choice': case 'environment': return 'select'
    case 'number': return 'number'
    default: return 'text'
  }
}

// a select's options: the declared options or the repository's
// environments, after an empty first option that leaves the input to its
// default (or unsupplied)
export function optionList(input, environments = []) {
  const values = input?.type === 'environment' ? [...environments] : [...(input?.options || [])]
  const first = input?.default != null ? `default: ${input.default}` : input?.type === 'environment' ? 'choose an environment' : 'choose an option'
  return [{ value: '', label: first }, ...values.map((v) => ({ value: v, label: v }))]
}

// whether the form offers sending empty text in place of an input's
// default: a text input whose default is not empty, where an empty field
// leaves the default to apply and an explicit "" is a different value
export function emptyChoice(input) {
  return controlKind(input) === 'text' && input.default != null && input.default !== ''
}

// the number a valid number field sends, as the request's JSON writes it
// (12.50 is sent as 12.5), or '' when the field holds no valid number
export function numberSent(text) {
  const t = String(text ?? '')
  return t !== '' && NUMBER.test(t) && t.length <= 32 ? JSON.stringify(Number(t)) : ''
}

// a toggle starts at its default; every other field starts empty, its
// default shown beside it
export function initialValues(inputs = []) {
  const out = {}
  for (const input of inputs) out[input.id] = input.type === 'boolean' ? input.default === 'true' : ''
  return out
}

// the ship's checks, in the ship's words: a required input with no
// default, a number in plain decimal, a choice among its options, an
// environment the repository defines. (A value holding a stored
// credential is refused by the ship alone: this page never holds one.)
// An explicit empty text is a value its input takes.
export function fieldErrors(inputs = [], values = {}, environments = [], empties = {}) {
  const errors = {}
  for (const input of inputs) {
    if (input.type === 'boolean' || (empties[input.id] && emptyChoice(input))) continue
    const text = String(values[input.id] ?? '')
    if (text === '') {
      if (input.required && input.default == null) errors[input.id] = 'is required'
      continue
    }
    if (input.type === 'number' && (!NUMBER.test(text) || text.length > 32)) errors[input.id] = 'must be a plain decimal number, like 12 or -0.5'
    if (input.type === 'choice' && !(input.options || []).includes(text)) errors[input.id] = `must be one of ${(input.options || []).join(', ')}`
    if (input.type === 'environment' && !environments.includes(text)) {
      errors[input.id] = environments.length ? `must be an environment of this repository: ${[...environments].sort().join(', ')}` : 'must name an environment, and this repository defines none'
    }
  }
  return errors
}

// the dispatch's inputs, typed as declared: a toggle is a JSON boolean
// (false is a value), a number a JSON number (zero is a value), the rest
// text; an empty field is not supplied, so the ship applies its default,
// unless the operator asked for empty text, which is sent as ""
export function dispatchBody(base, inputs = [], values = {}, empties = {}) {
  const typed = {}
  for (const input of inputs) {
    const value = values[input.id]
    if (input.type === 'boolean') { typed[input.id] = Boolean(value); continue }
    if (empties[input.id] && emptyChoice(input)) { typed[input.id] = ''; continue }
    const text = String(value ?? '')
    if (text === '') continue
    typed[input.id] = input.type === 'number' ? Number(text) : text
  }
  return { ...base, inputs: typed }
}

// the ship's answer to a dispatch, classified by its status; an answer
// that never came is not a refusal: the run may have been recorded, and
// the same request is answered with the same run
export function submitError(cause) {
  const status = cause?.status
  const message = String(cause?.message || cause || '')
  if (!Number.isFinite(status)) {
    return { kind: 'lost', message: `The ship's answer never arrived (${message}). The run may have been recorded: Retry sends the same request, which the ship answers with the same run.`, fields: {} }
  }
  if (status === 401 || status === 403) return { kind: 'unauthorized', message, fields: {} }
  if (status === 422) return { kind: 'invalid', message, fields: cause.fields || {} }
  if (status === 409 && /moved since the form was loaded|changed since the form was loaded/.test(message)) return { kind: 'stale', message, fields: {} }
  if (status === 409 || status === 400) return { kind: 'refused', message, fields: cause.fields || {} }
  return { kind: 'failure', message, fields: {} }
}

// the operator's idempotency key for one submission: a retry of the same
// submission sends it again
export function newRequestId(now = Date.now(), random = Math.random) {
  return `run-${Math.floor(now).toString(36)}-${Math.floor(random() * 36 ** 8).toString(36)}`
}

const SOURCE = { supplied: 'supplied', default: 'default', absent: 'not supplied' }

export function inputValueText(value) {
  if (value === null || value === undefined) return '—'
  if (typeof value === 'boolean') return value ? 'true' : 'false'
  if (typeof value === 'number') return String(value)
  const text = String(value)
  return text === '' ? '"" (empty)' : text
}

// a run's event as the ship admitted it, for the run page: the event,
// who triggered it, the branch and exact source, the workflow revision,
// and each input with its typed value and how it was decided. Text only.
export function eventRows(candidate) {
  const event = candidate?.event
  if (!event || !event.name) return null
  const manual = event.name === 'workflow_dispatch'
  // an automatic run's event (Delivery 1C): its kind, how it arrived, its
  // tips, its pull request or its occurrence; a scheduled run is the system
  // timer's, authorized by the promotion that armed it, never a click
  const kind = String(event.kind || '')
  const pull = event.pull && typeof event.pull === 'object' ? event.pull : null
  const occurrence = event.occurrence && typeof event.occurrence === 'object' ? event.occurrence : null
  return {
    label: manual ? 'Manual run' : kind === 'pull-request' ? 'Pull request' : kind === 'schedule' ? 'Schedule' : event.name === 'push' ? 'Push' : String(event.name),
    kind,
    route: String(event.route || ''),
    trigger: String(event.trigger || ''),
    eventId: String(event.eventId || ''),
    before: String(event.before || ''),
    after: String(event.after || ''),
    activity: pull ? pullActivity(pull) : '',
    // a label event's label and who changed it, and the labels after it
    labelChange: labelChange(pull, event.actor),
    labels: pull && Array.isArray(pull.labels) ? pull.labels.map(String) : [],
    pull: pull ? { number: Number(pull.number), title: String(pull.title || ''), head: String(pull.head || ''), base: String(pull.base || ''), headBranch: branchLabel(pull.headRef), baseBranch: branchLabel(pull.baseRef), author: String(pull.sourceShip || ''), merged: Boolean(pull.merged) } : null,
    occurrence: occurrence ? { cron: String(occurrence.cron || ''), zone: String(occurrence.timezone || 'UTC (default)'), entry: `${occurrence.workflow} #${occurrence.index}`, due: instant(occurrence.due), admitted: instant(occurrence.admitted), late: Boolean(occurrence.late), lateText: lateText(occurrence.late, occurrence.lateSeconds), promoter: String(occurrence.promoter || '') } : null,
    triggeredBy: kind === 'schedule' ? `the system timer, authorized by ${String(occurrence?.promoter || event.actor || '')}'s promotion` : String(event.actor || ''),
    name: String(event.name),
    actor: String(event.actor || ''),
    ref: String(event.ref || ''),
    branch: branchLabel(event.ref),
    source: String(event.source || ''),
    revision: String(event.revision || ''),
    workflowAuthority: String(event.workflowAuthority || 'promoted-baseline'),
    workflow: String(event.workflow || ''),
    workflowName: String(event.workflowName || event.workflow || ''),
    request: String(event.request || ''),
    payloadSha256: String(event.payloadSha256 || ''),
    payload: String(event.payload || ''),
    inputs: (Array.isArray(event.inputs) ? event.inputs : []).map((i) => ({
      id: String(i.id),
      type: String(i.type || ''),
      text: i.source === 'absent' ? '—' : inputValueText(i.value),
      source: String(i.source || ''),
      sourceLabel: SOURCE[i.source] || String(i.source || ''),
    })),
  }
}

// the form's state: the inventory read, the workflow and branch chosen,
// the values, the inputs asked to send empty text, which fields were
// touched, whether a submission was attempted, the one submission in
// flight, its failure, and the request a retry repeats
export const initialRunForm = () => ({ phase: 'loading', loadError: '', inventory: null, repoRefs: [], head: '', workflow: '', ref: '', values: {}, empties: {}, touched: {}, attempted: false, submitting: false, failure: null, request: null, done: null })

function chooseRef(inventory, workflow, repoRefs, preferred) {
  const refs = refChoices(inventory, workflow, repoRefs)
  for (const ref of preferred) if (ref && refs.some((r) => r.ref === ref && r.available)) return ref
  return (refs.find((r) => r.available) || refs[0] || { ref: '' }).ref
}

function fresh(state, workflow, ref) {
  const definition = definitionFor(state.inventory, ref, workflow)
  return { ...state, workflow, ref, values: initialValues(definition?.inputs || []), empties: {}, touched: {}, attempted: false, failure: null, request: null }
}

// a changed field clears the ship's refusal of that field, and makes the
// next submission a new request
function changed(state, id, next) {
  const failure = state.failure?.kind === 'invalid'
    ? { ...state.failure, fields: Object.fromEntries(Object.entries(state.failure.fields || {}).filter(([k]) => k !== id)) }
    : null
  return { ...state, ...next, touched: { ...state.touched, [id]: true }, failure, request: null }
}

export function runFormReducer(state, action) {
  switch (action.type) {
    case 'loading': return { ...state, phase: state.inventory ? state.phase : 'loading', loadError: '', failure: null }
    case 'load-failed': return { ...state, phase: 'error', loadError: action.error }
    case 'loaded': {
      const base = { ...state, phase: 'ready', inventory: action.inventory, repoRefs: action.repoRefs || [], head: action.head || '' }
      const choices = workflowChoices(action.inventory)
      const workflow = (choices.find((c) => c.workflow === state.workflow && c.available) || choices.find((c) => c.available) || choices[0] || { workflow: '' }).workflow
      const ref = chooseRef(action.inventory, workflow, base.repoRefs, [state.ref, base.head])
      return fresh(base, workflow, ref)
    }
    case 'pick-workflow': return fresh(state, action.workflow, chooseRef(state.inventory, action.workflow, state.repoRefs, [state.ref, state.head]))
    case 'pick-ref': return fresh(state, state.workflow, action.ref)
    case 'set': return changed(state, action.id, { values: { ...state.values, [action.id]: action.value } })
    // asking for empty text empties the field; turning it off leaves the
    // field empty, so the default applies again
    case 'set-empty': {
      const empties = { ...(state.empties || {}) }
      if (action.on) empties[action.id] = true
      else delete empties[action.id]
      return changed(state, action.id, { values: { ...state.values, [action.id]: '' }, empties })
    }
    case 'attempted': return { ...state, attempted: true }
    case 'submit-start': return { ...state, attempted: true, submitting: true, failure: null, request: action.request }
    case 'submit-failed': return { ...state, submitting: false, failure: action.failure, request: action.failure.kind === 'lost' ? state.request : null }
    case 'submit-done': return { ...state, submitting: false, done: action.run }
    default: return state
  }
}

// what a submission would post now, or the errors that keep it back, or
// that nothing can be posted (no authority, no runnable workflow here)
export function submission(state) {
  const inventory = state.inventory
  const definition = definitionFor(inventory, state.ref, state.workflow)
  const ref = (inventory?.refs || []).find((r) => r.ref === state.ref)
  if (!inventory || !inventory.authorized || !definition || definition.refusal || !ref) return { blocked: true }
  const empties = state.empties || {}
  const errors = fieldErrors(definition.inputs, state.values, inventory.environments || [], empties)
  if (Object.keys(errors).length) return { errors }
  return { body: dispatchBody({ ref: state.ref, workflow: state.workflow, tip: ref.tip, generation: inventory.generation }, definition.inputs, state.values, empties) }
}
