// The Runners panel's legacy recovery component (legacy-recovery UI ruling
// 01; runner/launcher/INTEGRATION.md §11.12), written against an injected
// React so the same component runs in the panel and in the tests.
//
// It reads the runner's retentions from the ship (GET ci/runners/<id>/
// recovery). While any command is open it reads them again, since the
// answer comes from the runner through the ship. It posts one confirmation
// at a time: a second click while one is in flight posts nothing. A post the
// ship refused shows its reason. A post whose answer never came is said to
// be unknown, and the ship is read again, never taken for a success.
//
// A runner waiting for its history transition is transitioned from the same
// panel, the same way (legacy-replay-upgrade ruling 01): its confirmation is
// bound to the history, revision and evidence inspected, posted once, and
// read back until the runner's report shows it (runnerHistory.js).

import { mayPost, openCommands, releaseBody } from './runnerRecovery.js'
import { historyPending, initialPanelState, mayTransition, panelReducer, transitionBody } from './runnerHistory.js'
import { renderRecovery } from './runnerRecoveryView.js'

const defaultSchedule = (fn, ms) => {
  const timer = setTimeout(fn, ms)
  return () => clearTimeout(timer)
}

// a post whose answer never came: the network failed, not the ship (a
// refusal carries the ship's status)
export const lostPost = (cause) => !(cause && Number.isFinite(cause.status))

export function makeRunnerRecovery(React, { ci, now = () => Date.now() / 1000, schedule = defaultSchedule, pollEvery = 3000 }) {
  const { createElement, useCallback, useEffect, useReducer, useRef } = React
  return function RunnerRecovery({ runner, onClose, onChanged }) {
    const [state, dispatch] = useReducer(panelReducer, undefined, initialPanelState)
    const live = useRef(true)
    const inFlight = useRef(false)
    const current = useRef(state)
    current.current = state
    const load = useCallback(async () => {
      try {
        const view = await ci.recovery(runner.id)
        if (live.current) dispatch({ type: 'loaded', view })
      } catch (cause) {
        if (live.current) dispatch({ type: 'load-failed', error: cause.message })
      }
    }, [runner.id])
    useEffect(() => {
      live.current = true
      load()
      return () => { live.current = false }
    }, [load])
    // the runner's answer comes through the ship: read it again while a
    // command is open, or a transition's completion is not reported yet
    const open = openCommands(state.view, now()) || historyPending(state.view, now())
    useEffect(() => {
      if (!open) return undefined
      return schedule(() => { load() }, pollEvery)
    }, [open, state.view, load])
    const release = useCallback(async () => {
      // one post at a time, whatever this render believed
      if (inFlight.current || !mayPost(current.current, now())) return
      inFlight.current = true
      const body = releaseBody(runner.id, current.current.confirming)
      dispatch({ type: 'post-start' })
      try {
        await ci.action(body)
        dispatch({ type: 'post-done' })
      } catch (cause) {
        dispatch({ type: 'post-failed', error: cause.message, lost: lostPost(cause) })
      } finally {
        inFlight.current = false
      }
      await load()
      onChanged?.()
    }, [runner.id, load, onChanged])
    const transition = useCallback(async () => {
      // one post at a time, whatever this render believed
      if (inFlight.current || !mayTransition(current.current, now())) return
      inFlight.current = true
      const body = transitionBody(runner.id, current.current.historyConfirming)
      dispatch({ type: 'history-post-start' })
      try {
        await ci.action(body)
        dispatch({ type: 'history-post-done' })
      } catch (cause) {
        dispatch({ type: 'history-post-failed', error: cause.message, lost: lostPost(cause) })
      } finally {
        inFlight.current = false
      }
      await load()
      onChanged?.()
    }, [runner.id, load, onChanged])
    const actions = {
      select: (selection) => dispatch({ type: 'select', selection }),
      openConfirm: () => dispatch({ type: 'confirm-open', now: now() }),
      acknowledge: (value) => dispatch({ type: 'acknowledge', value }),
      cancel: () => dispatch({ type: 'confirm-cancel' }),
      release,
      openTransition: () => dispatch({ type: 'history-confirm-open', now: now() }),
      acknowledgeTransition: (value) => dispatch({ type: 'history-acknowledge', value }),
      cancelTransition: () => dispatch({ type: 'history-confirm-cancel' }),
      transition,
      refresh: load,
      close: () => onClose?.(),
    }
    return renderRecovery(createElement, { runner, state, now: now() }, actions)
  }
}
