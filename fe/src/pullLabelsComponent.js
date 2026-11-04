// A pull request's labels (%urgit state-5), written against an injected
// React so the same component runs on the pull request page and in the
// tests. Everyone sees the labels. Only a viewer the ship says may change
// them (labelsEditable: the owner, or a writer browsing from its own ship)
// gets the editor. Every refusal is shown in the ship's own words.

import { changeSummary, eventsNote, initialLabels, labelEvents, labelsReducer, sortLabels } from './pullLabels.js'

export function makePullLabels(React) {
  const { createElement: h, useEffect, useReducer, useRef } = React
  return function PullLabels({ labels = [], editable = false, onSave, onSaved }) {
    const [state, dispatch] = useReducer(labelsReducer, labels, initialLabels)
    const live = useRef(true)
    const shown = sortLabels(labels).join('\n')
    useEffect(() => { dispatch({ type: 'load', labels }) }, [shown])
    useEffect(() => () => { live.current = false }, [])
    const events = labelEvents(state.saved, state.draft)
    async function save() {
      const draft = state.draft
      dispatch({ type: 'saving' })
      try {
        const answer = await onSave(draft)
        const next = Array.isArray(answer?.labels) ? answer.labels : draft
        if (live.current) dispatch({ type: 'saved', labels: next })
        onSaved?.(next)
      } catch (cause) {
        if (live.current) dispatch({ type: 'failed', message: String(cause?.message || cause) })
      }
    }
    const chips = editable ? state.draft : state.saved
    return h('section', { className: 'pull-labels', 'data-part': 'pull-labels', 'aria-label': 'Labels' },
      h('strong', null, 'Labels'),
      chips.length
        ? h('ul', { className: 'label-chips', 'data-part': 'label-list' },
          chips.map((label) => h('li', { key: label, className: 'label-chip', 'data-part': 'label-chip' },
            h('span', null, label),
            editable && h('button', {
              type: 'button', className: 'label-remove', 'data-part': 'label-remove', 'aria-label': `Remove label ${label}`,
              disabled: state.saving, onClick: () => dispatch({ type: 'remove', label }),
            }, '×'))))
        : h('small', { className: 'quiet', 'data-part': 'labels-none' }, 'None'),
      editable && h('form', {
        className: 'label-editor', 'data-part': 'label-editor',
        onSubmit: (event) => { event?.preventDefault?.(); dispatch({ type: 'add' }) },
      },
      h('input', {
        'data-part': 'label-input', 'aria-label': 'New label', placeholder: 'Add a label', value: state.input,
        disabled: state.saving, 'aria-invalid': state.problem ? 'true' : 'false',
        onChange: (event) => dispatch({ type: 'input', value: event.target.value }),
      }),
      h('button', { type: 'submit', className: 'button', 'data-part': 'label-add', disabled: state.saving || !state.input.trim() }, 'Add')),
      editable && state.problem && h('div', { className: 'inline-error', role: 'alert', 'data-part': 'label-problem' }, state.problem),
      editable && events.length > 0 && h('div', { className: 'label-pending', 'data-part': 'label-pending' },
        h('p', { 'data-part': 'label-summary' }, changeSummary(events)),
        h('p', { className: 'quiet' }, eventsNote),
        h('div', { className: 'form-actions' },
          h('button', { type: 'button', className: 'text-button', 'data-part': 'label-reset', disabled: state.saving, onClick: () => dispatch({ type: 'reset' }) }, 'Cancel'),
          h('button', { type: 'button', className: 'button primary', 'data-part': 'label-save', disabled: state.saving, onClick: save }, state.saving ? 'Saving…' : 'Save labels'))),
      editable && state.refusal && h('div', { className: 'inline-error', role: 'alert', 'data-part': 'label-refusal' }, state.refusal))
  }
}
