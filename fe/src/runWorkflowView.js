// The Run workflow form, rendered (Delivery 1A). The operator chooses a
// workflow and a branch by name from the ship's inventory — an unavailable
// one shows why — and fills each declared input with the control its type
// gets: a toggle, a select of the options or of the repository's
// environments, a decimal field, a text field, and beside a text field
// whose default is not empty a checkbox that sends empty text instead.
// Each field shows the ship's own reason when it would be refused; the
// ship checks again. The element factory h is React.createElement in the
// tab and a plain tree builder in the tests; the same function renders
// both.

import { controlKind, definitionFor, emptyChoice, fieldErrors, numberSent, optionList, refChoices, workflowChoices } from './ciDispatch.js'

const short = (oid) => (oid ? String(oid).slice(0, 8) : '')

function frame(h, actions, ...body) {
  return h('section', { className: 'panel ci-run-workflow', 'data-part': 'run-workflow' },
    h('div', { className: 'section-title' },
      h('div', null,
        h('h3', null, 'Run workflow'),
        h('p', null, 'Run a workflow that declares workflow_dispatch at a branch\'s promoted baseline, on that branch\'s current tip, with the inputs it declares. A manual run never lands and receives no credentials.')),
      h('button', { type: 'button', className: 'text-button', 'data-part': 'close', onClick: () => actions.close?.() }, 'Close')),
    ...body)
}

function control(h, input, value, environments, disabled, actions) {
  const id = input.id
  const required = Boolean(input.required) && input.default == null
  const common = { 'data-part': 'control', 'data-id': id, disabled, 'aria-label': id }
  switch (controlKind(input)) {
    case 'toggle':
      return h('input', { ...common, type: 'checkbox', checked: Boolean(value), onChange: (e) => actions.set(id, Boolean(e.target.checked)) })
    case 'select':
      return h('select', { ...common, value: value ?? '', required, onChange: (e) => actions.set(id, e.target.value) },
        optionList(input, environments).map((o) => h('option', { key: o.value || '-', value: o.value }, o.label)))
    case 'number':
      return h('input', { ...common, type: 'text', inputMode: 'decimal', value: value ?? '', required, placeholder: input.default != null ? `default: ${input.default}` : required ? 'required' : 'not supplied when empty', onChange: (e) => actions.set(id, e.target.value) })
    default:
      return h('input', { ...common, type: 'text', value: value ?? '', required, placeholder: input.default != null ? `default: ${input.default}` : required ? 'required' : 'not supplied when empty', onChange: (e) => actions.set(id, e.target.value) })
  }
}

// what the field sends, in words
function hintOf(input, value, empty) {
  if (input.type === 'environment') return 'Names an environment in the run\'s inputs; it releases none of that environment\'s credentials.'
  if (input.type === 'boolean') return `Sent as ${value ? 'true' : 'false'}.`
  if (empty) return `Sends empty text: the default ${input.default} does not apply.`
  const number = input.type === 'number' ? numberSent(value) : ''
  if (number) return `Sent as the number ${number}.`
  if (input.default != null) return `Left empty, the default ${input.default === '' ? '(empty text)' : input.default} applies.`
  return input.required ? 'Required.' : 'Left empty, it is not supplied.'
}

function inputRow(h, input, state, environments, disabled, clientErrors, actions) {
  const id = input.id
  const server = state.failure?.kind === 'invalid' ? state.failure.fields?.[id] : ''
  const client = state.touched[id] || state.attempted ? clientErrors[id] : ''
  const error = server || client
  const offersEmpty = emptyChoice(input)
  const empty = offersEmpty && Boolean(state.empties?.[id])
  return h('div', { key: id, className: 'ci-input', 'data-part': 'input', 'data-id': id },
    h('label', { className: 'ci-input-field' },
      h('span', { className: 'ci-input-name' }, h('code', null, id), input.required ? ' *' : '', h('small', { className: 'quiet' }, ` ${input.type}`)),
      control(h, input, empty ? '' : state.values[id], environments, disabled || empty, actions)),
    input.description ? h('small', { className: 'quiet' }, input.description) : null,
    offersEmpty
      ? h('label', { className: 'ci-input-empty' },
        h('input', { type: 'checkbox', 'data-part': 'empty', 'data-id': id, checked: empty, disabled, onChange: (e) => actions.setEmpty(id, Boolean(e.target.checked)) }),
        ' Send empty text instead of the default')
      : null,
    h('small', { className: 'quiet', 'data-part': 'hint', 'data-id': id }, hintOf(input, state.values[id], empty)),
    error ? h('small', { className: 'field-error', 'data-part': 'field-error', 'data-id': id }, error) : null)
}

export function renderRunWorkflow(h, { repo, state }, actions) {
  if (state.phase === 'loading') return frame(h, actions, h('div', { className: 'empty', 'data-part': 'loading' }, 'Loading the manual workflows…'))
  if (state.phase === 'error') {
    return frame(h, actions, h('div', { className: 'empty', 'data-part': 'load-error' }, `Manual workflows unavailable: ${state.loadError} `,
      h('button', { type: 'button', className: 'text-button', 'data-part': 'retry-load', onClick: () => actions.reload() }, 'Retry')))
  }
  const inventory = state.inventory || { refs: [] }
  const choices = workflowChoices(inventory)
  const environments = inventory.environments || []
  if (!choices.length) {
    const blocked = (inventory.refs || []).filter((r) => !r.available)
    return frame(h, actions, h('div', { className: 'empty ci-first-run', 'data-part': 'no-workflows' },
      `No workflow of ${repo?.name || inventory.repo} declares workflow_dispatch at a promoted baseline. Add on.workflow_dispatch to a workflow, then resolve and promote that revision for a branch (Settings → CI policy).`,
      blocked.length ? h('ul', null, blocked.map((r) => h('li', { key: r.ref }, h('code', null, r.ref), `: ${r.reason}`))) : null))
  }
  const refs = refChoices(inventory, state.workflow, state.repoRefs)
  const chosenWorkflow = choices.find((c) => c.workflow === state.workflow)
  const chosenRef = refs.find((r) => r.ref === state.ref)
  const definition = definitionFor(inventory, state.ref, state.workflow)
  const disabled = state.submitting || !inventory.authorized
  const clientErrors = definition ? fieldErrors(definition.inputs, state.values, environments, state.empties || {}) : {}
  const canSubmit = Boolean(inventory.authorized && definition && !definition.refusal && chosenRef?.available)
  const failure = state.failure
  const outstanding = state.attempted && Object.keys(clientErrors).length > 0
  return frame(h, actions,
    inventory.authorized ? null : h('div', { className: 'empty ci-first-run', 'data-part': 'unauthorized' }, inventory.authority || 'This ship cannot run this repository\'s workflows manually.'),
    h('div', { className: 'three-fields ci-run-choice' },
      h('label', null, h('span', null, 'Workflow'),
        h('select', { 'data-part': 'workflow', value: state.workflow, disabled: state.submitting, onChange: (e) => actions.pickWorkflow(e.target.value) },
          choices.map((c) => h('option', { key: c.workflow, value: c.workflow, disabled: !c.available }, `${c.name} (${c.workflow})${c.available ? '' : ` — ${c.reason}`}`)))),
      h('label', null, h('span', null, 'Branch'),
        h('select', { 'data-part': 'ref', value: state.ref, disabled: state.submitting, onChange: (e) => actions.pickRef(e.target.value) },
          refs.map((r) => h('option', { key: r.ref, value: r.ref, disabled: !r.available }, `${r.label}${r.tip ? ` · ${short(r.tip)}` : ''}${r.available ? '' : ` — ${r.reason}`}`)))),
      h('div', { className: 'ci-run-source' }, h('small', { className: 'quiet' },
        chosenRef?.available ? `Runs on ${chosenRef.label} at ${short(chosenRef.tip)} with the workflow of its promoted baseline, under policy generation ${inventory.generation}.` : ''))),
    chosenWorkflow && !chosenWorkflow.available ? h('small', { className: 'field-error', 'data-part': 'workflow-reason' }, chosenWorkflow.reason) : null,
    chosenRef && !chosenRef.available ? h('small', { className: 'field-error', 'data-part': 'ref-reason' }, chosenRef.reason) : null,
    definition && definition.inputs.length
      ? h('div', { className: 'ci-inputs', 'data-part': 'inputs' }, definition.inputs.map((input) => inputRow(h, input, state, environments, disabled, clientErrors, actions)))
      : definition ? h('small', { className: 'quiet', 'data-part': 'no-inputs' }, 'This workflow declares no inputs.') : null,
    outstanding ? h('small', { className: 'field-error', 'data-part': 'form-error' }, 'Correct the marked inputs; nothing was sent.') : null,
    failure ? h('div', { className: `empty ci-first-run ci-submit-${failure.kind}`, 'data-part': 'submit-error', 'data-kind': failure.kind },
      failure.message, ' ',
      failure.kind === 'stale' ? h('button', { type: 'button', className: 'text-button', 'data-part': 'reload', onClick: () => actions.reload() }, 'Reload the form') : null,
      failure.kind === 'lost' ? h('button', { type: 'button', className: 'text-button', 'data-part': 'retry', onClick: () => actions.retry() }, 'Retry') : null) : null,
    h('div', { className: 'form-actions' },
      h('button', { type: 'button', className: 'button primary', 'data-part': 'submit', disabled: !canSubmit || state.submitting, onClick: () => actions.submit() }, state.submitting ? 'Starting…' : 'Run workflow')))
}
