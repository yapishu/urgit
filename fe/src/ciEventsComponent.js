// The CI tab's Events and Schedules panels (Delivery 1C), written against
// an injected React so the same components run in the tab and in the
// tests. Each reads the ship's route once on mount and again on Refresh
// or Retry; loading, a failed read and an empty answer are three states,
// none of them a success. Nothing ticks: the ship computes every time.

import { forgeEventRows, scheduleModel } from './ciEvents.js'
import { renderEventLog, renderSchedules } from './ciEventsView.js'

const initial = { phase: 'loading', error: '', answer: null }

export function panelReducer(state, action) {
  switch (action.type) {
    case 'loading': return state.phase === 'loading' ? state : { ...state, phase: 'loading', error: '' }
    case 'loaded': return { phase: 'ready', error: '', answer: action.answer }
    case 'failed': return { ...state, phase: 'error', error: action.error }
    default: return state
  }
}

function makePanel(React, read, render) {
  const { createElement, useCallback, useEffect, useReducer, useRef } = React
  return function Panel({ repo, onOpenRun, onOpenPull }) {
    const [state, dispatch] = useReducer(panelReducer, initial)
    const live = useRef(true)
    const load = useCallback(async () => {
      dispatch({ type: 'loading' })
      try {
        const answer = await read(repo.name)
        if (live.current) dispatch({ type: 'loaded', answer })
      } catch (cause) {
        if (live.current) dispatch({ type: 'failed', error: String(cause?.message || cause) })
      }
    }, [repo.name])
    useEffect(() => {
      live.current = true
      load()
      return () => { live.current = false }
    }, [load])
    const actions = { refresh: load, retry: load, openRun: (id) => onOpenRun?.(id), openPull: (number) => onOpenPull?.(number) }
    return render(createElement, state, actions, repo.name)
  }
}

export function makeEventLog(React, { ci }) {
  return makePanel(React, (name) => ci.events(name), (h, state, actions, repo) =>
    renderEventLog(h, { phase: state.phase, error: state.error, rows: state.answer ? forgeEventRows(state.answer) : null, repo }, actions))
}

export function makeSchedules(React, { ci }) {
  return makePanel(React, (name) => ci.schedules(name), (h, state, actions) =>
    renderSchedules(h, { phase: state.phase, error: state.error, model: state.answer ? scheduleModel(state.answer) : null }, actions))
}
