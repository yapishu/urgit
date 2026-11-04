// CI-RECOVERY-1 (R5.2-A): the Settings → CI recovery component, written
// against an injected React so the same component runs in the app and in
// the tests.
//
// It reads the ship (GET ci/recovery). While a checkpoint is written or
// pushed it reads the ship again. The answers come from the forge and the
// replica, through the ship. It posts one action at a time: a second click
// while one is in flight posts nothing. A refusal is shown in the ship's
// own words. A post whose answer never came is said to be lost, and the
// ship is read again, never taken for a success.

import { doneNotice, inFlight, lostPost, noAuthority, recoveryActions, recoveryReducer, initialRecoveryView } from './ciRecovery.js'
import { renderCiRecovery } from './ciRecoveryView.js'

const defaultSchedule = (fn, ms) => {
  const timer = setTimeout(fn, ms)
  return () => clearTimeout(timer)
}

export function makeCiRecovery(React, { ci, now = () => Date.now() / 1000, schedule = defaultSchedule, pollEvery = 3000 }) {
  const { createElement, useCallback, useEffect, useReducer, useRef } = React
  return function CiRecovery() {
    const [state, dispatch] = useReducer(recoveryReducer, undefined, initialRecoveryView)
    const live = useRef(true)
    const posting = useRef(false)
    const current = useRef(state)
    current.current = state
    const load = useCallback(async () => {
      try {
        const view = await ci.recoveryState()
        if (live.current) dispatch({ type: 'loaded', view })
      } catch (cause) {
        if (live.current) dispatch({ type: 'load-failed', error: cause?.message || String(cause), denied: noAuthority(cause) })
      }
    }, [])
    useEffect(() => {
      live.current = true
      load()
      return () => { live.current = false }
    }, [load])
    // a checkpoint on its way: read the ship again until it is written and
    // its replica has answered
    const waiting = inFlight(state.view)
    useEffect(() => {
      if (!waiting) return undefined
      return schedule(() => { load() }, pollEvery)
    }, [waiting, state.view, load])
    const post = useCallback(async (body) => {
      // one post at a time, whatever this render believed
      if (posting.current) return
      posting.current = true
      dispatch({ type: 'post-start', action: body.action })
      try {
        await ci.action(body)
        dispatch({ type: 'post-done', action: body.action, notice: doneNotice[body.action] })
      } catch (cause) {
        dispatch({ type: 'post-failed', error: cause?.message || String(cause), lost: lostPost(cause) })
      } finally {
        posting.current = false
      }
      await load()
    }, [load])
    const actions = {
      checkpointNow: () => post(recoveryActions.checkpointNow()),
      pause: () => post(recoveryActions.pause(current.current.reason)),
      resume: () => post(recoveryActions.resume()),
      importCheckpoint: () => post(recoveryActions.importCheckpoint(current.current.commit)),
      discard: () => post(recoveryActions.discard()),
      apply: () => {
        const s = current.current
        // only the checkpoint that was reviewed, and only once acknowledged
        if (!s.acknowledged || !s.view?.staged) return undefined
        return post(recoveryActions.apply(s.view.staged.id))
      },
      openApply: () => dispatch({ type: 'confirm-open' }),
      cancel: () => dispatch({ type: 'confirm-cancel' }),
      acknowledge: (value) => dispatch({ type: 'acknowledge', value }),
      reason: (value) => dispatch({ type: 'reason', value }),
      commit: (value) => dispatch({ type: 'commit', value }),
      refresh: load,
    }
    return renderCiRecovery(createElement, { state, now: now() }, actions)
  }
}
