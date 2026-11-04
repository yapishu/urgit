// Test fixtures of the Runners panel's history transition (legacy-replay-
// upgrade ruling 01), shared by its tests and imported by nothing else:
// - a runner's history as the daemon reports it (runner/internal/daemon/
//   history.go historyReport): waiting after an upgrade, waiting on a
//   history it cannot read, complete, and transitioned;
// - a model of the ship's transition contract (desk/app/urgit-ci.hoon,
//   %request-history-transition): the owner only; bound to the revision,
//   the waiting and the evidence of the runner's latest report; one open
//   transition per runner; the epoch it names; delivery, the runner's
//   answer, and the runner's report after it.

import { NOW, RUNNER, modelShip } from './runnerRecoveryFixtures.js'

export const HISTORY_EVIDENCE = 'c'.repeat(64)
export const SINCE = 1_790_000_000

export const waitingHistory = (over = {}) => ({
  selection: `history/${SINCE}`, revision: SINCE, since: SINCE, known: true, complete: false, stateFormat: 1, paused: true, epoch: 0, evidence: HISTORY_EVIDENCE,
  explanation: 'what it ran before its ledger began (2026-09-21T14:13:20Z) is not known (a state file kept before its ledger): it runs nothing until its transition is confirmed',
  ...over,
})

// a runner whose HISTORY cannot be read: no time it began, still waiting
export const unreadableHistory = (over = {}) => waitingHistory({
  selection: 'history/0', revision: 0, since: 0, known: false, stateFormat: 0, evidence: 'd'.repeat(64),
  explanation: 'its history cannot be read: it is not taken for a fresh runner, and it runs nothing until its transition is confirmed',
  ...over,
})

export const completeHistory = (over = {}) => waitingHistory({
  complete: true, paused: false, stateFormat: 2, evidence: 'e'.repeat(64),
  explanation: 'complete: its ledger began with this runner\'s enrollment, and every attempt it took is recorded',
  ...over,
})

export const transitionedHistory = (epoch = 1, command = '0v1.hist', over = {}) => waitingHistory({
  paused: false, epoch, transition: { epoch, command, at: NOW + 2 },
  explanation: `what it ran before its ledger began is not known; its transition to authorization epoch ${epoch} is recorded: it refuses every assignment its ship signed before, and runs new work`,
  ...over,
})

// a transition command as the ship shows it
export const historyCommand = (status, over = {}) => ({
  id: '0v1.hist', operation: 'confirm-history', selection: `history/${SINCE}`, revision: SINCE, evidence: `epoch 1 history ${HISTORY_EVIDENCE}`,
  label: 'execution history transition', status, requested: NOW - 60, expires: NOW + 840, delivered: status === 'queued' ? null : NOW - 30,
  detail: '', finished: ['completed', 'refused'].includes(status) ? NOW - 20 : null, ...over,
})

// the ship's view of a runner with its history, as GET ci/runners/<id>/
// recovery answers it
export const historyView = (history, { commands = [], retentions = [], ship = { epoch: 0, next: 1, assignments: 0, running: [] }, reported = NOW - 5 } = {}) => ({
  runner: { id: RUNNER, history: history ? { paused: history.paused, revision: history.revision } : null }, now: NOW, reported,
  report: { capacity: { configured: 2, withheld: retentions.length, held: 0, running: 0, advertised: history?.paused ? 0 : Math.max(0, 2 - retentions.length) }, retentions, released: [], ...(history ? { history } : {}) },
  commands, history: ship, attempts: {},
})

const clone = (v) => JSON.parse(JSON.stringify(v))
const refusal = (message) => Object.assign(new Error(message), { status: 409 })
const open = (c) => ['queued', 'delivered', 'uncertain'].includes(c.status)

// the ship's transition contract, modelled on the recovery one (modelShip):
// what it binds a request to, what it records, the epoch it names, how it
// hands the command over, takes the runner's answer, and hears its report
export function modelHistoryShip({ history = waitingHistory(), retentions = [], owner = true, epoch = 0 } = {}) {
  const ship = modelShip(retentions)
  const release = ship.action
  Object.assign(ship, { history: clone(history), owner, before: epoch, reported: NOW - 5, clock: NOW })
  // the ship's epoch for the runner: every transition command it recorded,
  // whatever became of it (epoch-at)
  ship.epoch = () => ship.before + ship.commands.filter((c) => c.operation === 'confirm-history').length
  ship.recovery = async (id) => {
    ship.reads++
    if (ship.failReads) throw new TypeError('Failed to fetch')
    if (id !== RUNNER) throw Object.assign(new Error('no such runner'), { status: 404 })
    const e = ship.epoch()
    return clone(historyView(ship.history, { commands: [...ship.commands].reverse(), retentions: ship.retentions, ship: { epoch: e, next: e + 1, assignments: 0, running: [] }, reported: ship.reported }))
  }
  ship.action = async (body) => {
    if (body.action !== 'request-history-transition') return release(body)
    ship.posts.push(clone(body))
    const lose = ship.loseNext
    ship.loseNext = false
    if (!ship.owner) throw refusal('only the ship\'s owner confirms a runner\'s history transition')
    if (body.id !== RUNNER) throw refusal('no such runner')
    const h = ship.history
    if (!h) throw refusal('the runner\'s latest report shows no execution history')
    if (h.revision !== body.revision) throw refusal('the runner\'s history changed since it was inspected: inspect it again')
    if (h.paused !== true) throw refusal('the runner\'s latest report does not show its history waiting for a transition')
    if (h.evidence !== body.evidence) throw refusal('the history evidence changed since it was inspected: inspect it again')
    if (!ship.commands.some((c) => c.operation === 'confirm-history' && open(c))) {
      const next = ship.epoch() + 1
      ship.commands.push({ id: `0v${ship.next++}.hist`, operation: 'confirm-history', selection: h.selection, revision: body.revision, evidence: `epoch ${next} history ${body.evidence}`, label: 'execution history transition', status: 'queued', requested: NOW, expires: NOW + 900, delivered: null, deliveries: 0, detail: '', finished: null })
    }
    if (lose) throw new TypeError('Failed to fetch')
    return { ok: true, action: body.action }
  }
  // the runner's answer to its latest transition command, as the ship
  // records it (answer-command): completed stands; a refusal or a doubt
  // changes only an open command
  ship.answerHistory = (status, detail) => {
    const c = [...ship.commands].reverse().find((x) => x.operation === 'confirm-history')
    if (c.status === 'completed') return c
    if (!open(c) && status !== 'completed') return c
    ship.clock += 1
    Object.assign(c, { status, detail, finished: status === 'uncertain' ? c.finished : ship.clock })
    return c
  }
  // the runner's report after its answer: a recorded transition shows
  ship.reportAfter = () => {
    ship.clock += 1
    ship.reported = ship.clock
    const done = [...ship.commands].reverse().find((x) => x.operation === 'confirm-history' && x.status === 'completed')
    if (done && ship.history?.paused) {
      const e = Number(done.evidence.split(' ')[1])
      ship.history = { ...ship.history, paused: false, epoch: e, transition: { epoch: e, command: done.id, at: done.finished } }
    }
  }
  return ship
}
