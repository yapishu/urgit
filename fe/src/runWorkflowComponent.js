// The Run workflow component (Delivery 1A), written against an injected
// React so the same component runs in the CI tab and in the tests. It reads
// the ship's dispatch inventory, keeps the form's state, and posts one
// dispatch at a time: a second click while one is in flight posts nothing.
// A refusal shows the ship's reason (each refused input beside its field).
// A post whose answer never came is said to be unknown, and Retry sends the
// same request, which the ship answers with the same run. Only the run the
// ship returned is opened: nothing is shown as started before it answers.

import { initialRunForm, newRequestId, runFormReducer, submission, submitError } from './ciDispatch.js'
import { renderRunWorkflow } from './runWorkflowView.js'

export function makeRunWorkflow(React, { ci, newRequest = () => newRequestId() }) {
  const { createElement, useCallback, useEffect, useReducer, useRef } = React
  return function RunWorkflow({ repo, onClose, onCreated }) {
    const [state, dispatch] = useReducer(runFormReducer, undefined, initialRunForm)
    const live = useRef(true)
    const inFlight = useRef(false)
    const current = useRef(state)
    current.current = state
    const load = useCallback(async () => {
      dispatch({ type: 'loading' })
      try {
        const inventory = await ci.dispatchInventory(repo.name)
        if (live.current) dispatch({ type: 'loaded', inventory, repoRefs: repo.refs || [], head: repo.head || '' })
      } catch (cause) {
        if (live.current) dispatch({ type: 'load-failed', error: String(cause?.message || cause) })
      }
    }, [repo.name])
    useEffect(() => {
      live.current = true
      load()
      return () => { live.current = false }
    }, [load])
    const submit = useCallback(async () => {
      if (inFlight.current) return
      const now = current.current
      const plan = submission(now)
      if (plan.blocked) return
      if (plan.errors) { dispatch({ type: 'attempted' }); return }
      inFlight.current = true
      const request = now.request || newRequest()
      dispatch({ type: 'submit-start', request })
      try {
        const answer = await ci.dispatch(repo.name, { ...plan.body, request })
        if (live.current) dispatch({ type: 'submit-done', run: answer.run })
        onCreated?.(answer.run.id, answer.run)
      } catch (cause) {
        if (live.current) dispatch({ type: 'submit-failed', failure: submitError(cause) })
      } finally {
        inFlight.current = false
      }
    }, [repo.name, onCreated])
    const actions = {
      pickWorkflow: (workflow) => dispatch({ type: 'pick-workflow', workflow }),
      pickRef: (ref) => dispatch({ type: 'pick-ref', ref }),
      set: (id, value) => dispatch({ type: 'set', id, value }),
      setEmpty: (id, on) => dispatch({ type: 'set-empty', id, on }),
      submit,
      retry: submit,
      reload: load,
      close: () => onClose?.(),
    }
    return renderRunWorkflow(createElement, { repo, state }, actions)
  }
}
