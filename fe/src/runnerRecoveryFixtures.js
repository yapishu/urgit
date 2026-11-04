// Test fixtures of the Runners panel's legacy recovery (legacy-recovery UI
// ruling 01), shared by its tests and imported by nothing else:
// - a runner's report as the daemon posts it, and the ship's view of it;
// - a model of the ship's recovery contract (specs/ci-execution-contract.md
//   §8b): the binding checks, one open command per entry, delivery and the
//   runner's answer, a lost reply;
// - a small hooks runtime that renders the real component with its hooks,
//   and queries over the element tree it renders.

export const NOW = 1_800_000_000
export const EVIDENCE = 'a'.repeat(64)
export const RUNNER = '0v1.daemon'

const condition = (name, met = true) => ({ name, met, detail: `${name} detail` })

export const legacyEntry = (over = {}) => ({
  selection: 'ci-0v4.att/microvm///0/0//1700000000/1', revision: 1, handle: 'ci-0v4.att', attempt: '0v4.att', label: 'owner/repo · ci.yml · build',
  backend: 'microvm', kind: 'legacy', identity: 'a launcher reservation whose identity was never learnt', reason: 'reserve answer lost', retained: 1_700_000_000,
  legacy: { format: 0, found: 1_790_000_000 }, release: 'urgit', explanation: 'released from Urgit, by this daemon, on its evidence', eligible: true, evidence: EVIDENCE,
  conditions: ['provenance', 'backend', 'protocol', 'inventory', 'attempt', 'idle'].map((n) => condition(n)),
  facts: { socket: '/run/l.sock', launcher: 'v1', protocol: 4, records: 0, held: [] },
  ...over,
})

export const unmetEntry = (name, over = {}) => legacyEntry({
  eligible: false,
  conditions: ['provenance', 'backend', 'protocol', 'inventory', 'attempt', 'idle'].map((n) => condition(n, n !== name)),
  ...over,
})

export const vmEntry = (over = {}) => legacyEntry({
  selection: 'ci-0v6.vm/microvm/t-6/iiii/3/3//1700000001/0', revision: 0, handle: 'ci-0v6.vm', attempt: '0v6.vm', label: '', kind: 'vm', release: 'cli',
  explanation: 'released with urgit-runner -recover, the daemon stopped', eligible: false, evidence: '', conditions: undefined, facts: undefined, legacy: null, ...over,
})

export const viewOf = (retentions, commands = [], extra = {}) => ({
  runner: { id: RUNNER }, now: NOW, reported: NOW - 5,
  report: { capacity: { configured: 2, withheld: retentions.length, held: 0, running: 0, advertised: Math.max(0, 2 - retentions.length) }, retentions, released: [] },
  commands, attempts: { '0v4.att': { repo: 'owner/repo', ref: 'refs/heads/master', workflow: 'ci.yml', job: 'build', kind: 'job', status: 'failed' } }, ...extra,
})

export const command = (status, over = {}) => ({
  id: '0v5.cmd', selection: legacyEntry().selection, revision: 1, evidence: EVIDENCE, label: 'owner/repo · ci.yml · build', status,
  requested: NOW - 60, expires: NOW + 840, delivered: status === 'queued' ? null : NOW - 30, detail: '', ...over,
})

const clone = (v) => JSON.parse(JSON.stringify(v))
const refusal = (message) => Object.assign(new Error(message), { status: 409 })

// the ship's recovery contract, modelled: what it binds a request to, what
// it records, how it hands a command over and takes the runner's answer
export function modelShip(retentions) {
  const ship = { retentions: clone(retentions), released: [], commands: [], posts: [], reads: 0, loseNext: false, failReads: false, next: 1 }
  const open = (c) => ['queued', 'delivered', 'uncertain'].includes(c.status)
  ship.recovery = async (id) => {
    ship.reads++
    if (ship.failReads) throw new TypeError('Failed to fetch')
    if (id !== RUNNER) throw Object.assign(new Error('no such runner'), { status: 404 })
    return clone({ ...viewOf(ship.retentions, [...ship.commands].reverse()), report: { capacity: { configured: 2, withheld: ship.retentions.length, held: 0, running: 0, advertised: 2 - ship.retentions.length }, retentions: ship.retentions, released: ship.released } })
  }
  ship.action = async (body) => {
    ship.posts.push(clone(body))
    const lose = ship.loseNext
    ship.loseNext = false
    if (body.action !== 'request-legacy-release' || body.id !== RUNNER) throw refusal('unknown action')
    const entry = ship.retentions.find((e) => e.selection === body.selection)
    if (!entry) throw refusal('the runner\'s latest report does not show this retention: inspect it again')
    if (entry.revision !== body.revision) throw refusal('the retention changed since it was inspected: inspect it again')
    if (entry.kind !== 'legacy') throw refusal('the retention is not a legacy retention')
    if (!entry.eligible) throw refusal('the runner\'s latest report does not show this retention as releasable')
    if (entry.evidence !== body.evidence) throw refusal('the evidence changed since it was inspected: inspect it again')
    if (!ship.commands.some((c) => c.selection === body.selection && open(c))) {
      ship.commands.push({ id: `0v${ship.next++}.cmd`, selection: body.selection, revision: body.revision, evidence: body.evidence, label: entry.label, status: 'queued', requested: NOW, expires: NOW + 900, delivered: null, deliveries: 0, detail: '' })
    }
    if (lose) throw new TypeError('Failed to fetch')
    return { ok: true, action: body.action }
  }
  // the daemon's poll takes the oldest open command
  ship.deliver = () => {
    const c = ship.commands.find((x) => x.status === 'queued')
    if (c) Object.assign(c, { status: 'delivered', delivered: NOW + 1, deliveries: c.deliveries + 1 })
    return c
  }
  // the daemon's answer; completed releases the entry from its report
  ship.answer = (status, detail) => {
    const c = ship.commands[ship.commands.length - 1]
    if (c.status === 'completed') return c
    if (!open(c) && status !== 'completed') return c
    Object.assign(c, { status, detail })
    if (status === 'completed') {
      const at = ship.retentions.findIndex((e) => e.selection === c.selection)
      if (at >= 0) ship.released.push({ ...ship.retentions.splice(at, 1)[0], command: c.id })
    }
    return c
  }
  return ship
}

// a scheduler the test runs by hand
export function manualSchedule() {
  const pending = new Set()
  const schedule = (fn) => {
    const job = { fn }
    pending.add(job)
    return () => pending.delete(job)
  }
  schedule.pending = () => pending.size
  schedule.run = () => {
    const jobs = [...pending]
    pending.clear()
    for (const j of jobs) j.fn()
    return jobs.length
  }
  return schedule
}

// a small hooks runtime: createElement, useReducer, useRef, useCallback and
// useEffect as the component uses them; state changes batched into one
// render at the end of the current task, as React batches them (so a
// handler called twice in one task sees the render before both); effects
// after each render when their deps change, cleanups on unmount
export function hooksRuntime() {
  const slots = []
  let index = 0
  let component = null
  let props = null
  let tree = null
  let rendering = false
  let dirty = false
  let effects = []
  let renders = 0
  const createElement = (type, p, ...children) => ({ type, props: p || {}, children: children.flat(Infinity).filter((c) => c !== null && c !== undefined && c !== false && c !== true && c !== '') })
  const same = (a, b) => Array.isArray(a) && Array.isArray(b) && a.length === b.length && a.every((v, i) => Object.is(v, b[i]))
  function useReducer(reducer, arg, init) {
    const i = index++
    if (!slots[i]) {
      const slot = { state: init ? init(arg) : arg }
      slot.dispatch = (action) => {
        const next = reducer(slot.state, action)
        if (next !== slot.state) {
          slot.state = next
          later()
        }
      }
      slots[i] = slot
    }
    return [slots[i].state, slots[i].dispatch]
  }
  function useRef(initial) {
    const i = index++
    if (!slots[i]) slots[i] = { current: initial }
    return slots[i]
  }
  function useCallback(fn, deps) {
    const i = index++
    if (slots[i] && same(slots[i].deps, deps)) return slots[i].fn
    slots[i] = { fn, deps }
    return fn
  }
  function useEffect(fn, deps) {
    const i = index++
    const prev = slots[i]
    if (prev && same(prev.deps, deps)) return
    if (!prev) slots[i] = { deps: undefined, cleanup: undefined }
    effects.push(() => {
      const s = slots[i]
      if (typeof s.cleanup === 'function') s.cleanup()
      s.deps = deps
      s.cleanup = fn()
    })
  }
  function renderOnce() {
    rendering = true
    index = 0
    effects = []
    tree = component(props)
    renders++
    rendering = false
    const run = effects
    effects = []
    for (const e of run) e()
  }
  let queued = false
  function later() {
    if (queued) return
    queued = true
    queueMicrotask(() => {
      queued = false
      update()
    })
  }
  function update() {
    if (!component) return
    if (rendering) {
      dirty = true
      return
    }
    renderOnce()
    let guard = 0
    while (dirty && guard++ < 100) {
      dirty = false
      renderOnce()
    }
  }
  return {
    React: { createElement, useReducer, useRef, useCallback, useEffect },
    mount(c, p) { component = c; props = p; update() },
    tree: () => tree,
    renders: () => renders,
    unmount() {
      for (const s of slots) if (s && typeof s.cleanup === 'function') s.cleanup()
      component = null
    },
  }
}

// every promise the component awaits has settled
export async function settle() {
  for (let i = 0; i < 10; i++) await new Promise((resolve) => setImmediate(resolve))
}

// queries over a rendered tree
export function all(node, pred, out = []) {
  if (!node || typeof node !== 'object') return out
  if (pred(node)) out.push(node)
  for (const c of node.children || []) all(c, pred, out)
  return out
}
export const parts = (tree, name) => all(tree, (n) => n.props?.['data-part'] === name)
export const part = (tree, name) => parts(tree, name)[0] || null
export const text = (node) => (typeof node === 'string' || typeof node === 'number' ? String(node) : (node?.children || []).map(text).join(''))

// a plain element factory for the view alone
export const h = (type, p, ...children) => ({ type, props: p || {}, children: children.flat(Infinity).filter((c) => c !== null && c !== undefined && c !== false && c !== true && c !== '') })
