// The candidate page's concurrency panel and its Cancel control
// (CI-CONCURRENCY-1), written against an injected React so the same
// component runs in the tab and in the tests. Cancel asks first, then
// posts the one cancel-run action the ship applies by the path a
// concurrency group cancels by, and reads the run again; a refusal is
// shown in the ship's own words and changes nothing here. The ship alone
// decides who may cancel: the control is offered only when it says this
// ship may, and the ship refuses anyone else whatever this page offers.

import { ciActions } from './ci.js'
import { cancelConfirmation, concurrencyModel, renderConcurrency } from './ciConcurrency.js'
import { refusalMessage } from './ciProvenance.js'

const idle = { busy: '', error: '', done: '' }

export function cancelReducer(state, action) {
  switch (action.type) {
    case 'start': return { busy: action.target, error: '', done: '' }
    case 'done': return { busy: '', error: '', done: action.text }
    case 'failed': return { busy: '', error: action.error, done: '' }
    default: return state
  }
}

export function makeRunConcurrency(React, { ci }) {
  const { createElement, useEffect, useReducer, useRef } = React
  return function RunConcurrency({ candidate, confirm, onChanged }) {
    const [state, dispatch] = useReducer(cancelReducer, idle)
    const live = useRef(true)
    useEffect(() => {
      live.current = true
      return () => { live.current = false }
    }, [])
    const model = concurrencyModel(candidate)
    const id = candidate?.id
    const cancel = async (workflow) => {
      const row = workflow ? (model?.rows || []).find((r) => r.workflow === workflow) || null : null
      if (confirm && !(await confirm(cancelConfirmation(model, row)))) return
      dispatch({ type: 'start', target: workflow || 'run' })
      try {
        await ci.action(ciActions.cancelRun(id, workflow))
      } catch (cause) {
        if (live.current) dispatch({ type: 'failed', error: refusalMessage(cause) })
        return
      }
      if (live.current) dispatch({ type: 'done', text: workflow ? `Cancel recorded for ${row?.name || workflow}: its running jobs are being closed.` : 'Cancel recorded: the run\'s running jobs are being closed.' })
      // the page reads the run again; a failed read is the page's own error
      try { await onChanged?.() } catch { /* shown by the page */ }
    }
    return renderConcurrency(createElement, model, { busy: state.busy, error: state.error, done: state.done, cancel })
  }
}
