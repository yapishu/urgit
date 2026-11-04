// Test fixtures of the Run workflow form (Delivery 1A), shared by its tests
// and imported by nothing else:
// - the dispatch inventory as GET ci/repository/<name>/dispatch answers it;
// - a MODEL of the ship's dispatch contract (POST ci/repository/<name>/
//   dispatch): the same refusals the controller answers, so the component's
//   handling can be driven. It is a model of the unit boundary, not the
//   controller: the controller's own enforcement is exercised on the fake
//   ship (VERIFY.md).

export const TIP = '3a63ba27d64d70dfd63c170f16f44f7554e6df5a'
export const BASELINE = 'e59cde8e301c9368c1ec486edad767ed23520ea8'

export const manualInputs = () => [
  { id: 'dry_run', type: 'boolean', description: 'Rehearse without publishing', required: false, default: 'false', options: [] },
  { id: 'count', type: 'number', description: 'How many artifacts to build', required: true, default: '0', options: [] },
  { id: 'level', type: 'choice', description: 'Log level', required: false, default: 'warning', options: ['info', 'warning', 'debug'] },
  { id: 'note', type: 'string', description: 'A note for the run record', required: false, default: 'hello', options: [] },
  { id: 'target', type: 'environment', description: 'Where to publish', required: false, default: null, options: [] },
]

export const inventory = (over = {}) => ({
  repo: 'demo', generation: 7, authorized: true, authority: null, environments: ['production', 'staging'],
  refs: [
    {
      ref: 'refs/heads/main', tip: TIP, baseline: BASELINE, lock: 'c'.repeat(64), available: true, reason: null,
      workflows: [
        { workflow: 'manual.yml', name: 'Manual release', refusal: null, inputs: manualInputs() },
        { workflow: 'release.yml', name: 'Release', refusal: null, inputs: [{ id: 'version', type: 'string', description: 'The version to publish', required: true, default: null, options: [] }] },
        { workflow: 'matrix.yml', name: 'Matrix', refusal: 'job a: a matrix strategy is not supported in this release', inputs: [] },
      ],
    },
    {
      ref: 'refs/heads/old', tip: 'd'.repeat(40), baseline: 'e'.repeat(40), lock: 'f'.repeat(64), available: false,
      reason: "the baseline's lock was resolved before manual runs were listed: resolve and promote its revision again to list its manual workflows",
      workflows: [],
    },
  ],
  ...over,
})

export const repo = () => ({
  name: 'demo', head: 'refs/heads/main',
  refs: [{ name: 'refs/heads/main', oid: TIP }, { name: 'refs/heads/old', oid: 'd'.repeat(40) }, { name: 'refs/heads/feature', oid: '9'.repeat(40) }],
})

const clone = (v) => JSON.parse(JSON.stringify(v))
const refusal = (status, error, fields = {}) => Object.assign(new Error(error), { status, fields })

// the run the ship answers with: the candidate JSON of a manual run
export const runOf = (id, body) => ({
  id, repo: 'demo', ref: body.ref, head: body.tip, base: body.tip, candidate: body.tip, status: 'pending', mode: 'manual', trust: 'trusted', actor: '~zod',
  event: { name: 'workflow_dispatch', workflow: body.workflow, workflowName: 'Manual release', request: body.request, actor: '~zod', ref: body.ref, source: body.tip, revision: BASELINE, payload: '{}', payloadSha256: 'a'.repeat(64), inputs: [] },
  attempts: [],
})

// the dispatch contract, modelled: the inventory read, and a dispatch the
// model checks the way the controller does (tip, generation, inputs), so a
// client whose validation is bypassed sees the server's refusal
export function modelShip(inv = inventory()) {
  const ship = { inv: clone(inv), reads: 0, posts: [], runs: new Map(), failRead: false, loseNext: false, refuseNext: null, next: 1 }
  ship.dispatchInventory = async (name) => {
    ship.reads++
    if (ship.failRead) throw new TypeError('Failed to fetch')
    if (name !== 'demo') throw refusal(404, 'no such repository')
    return clone(ship.inv)
  }
  ship.dispatch = async (name, body) => {
    ship.posts.push(clone(body))
    if (ship.refuseNext) { const r = ship.refuseNext; ship.refuseNext = null; throw r }
    const ref = ship.inv.refs.find((r) => r.ref === body.ref)
    if (!ref || !ref.available) throw refusal(409, ref ? ref.reason : `no promoted baseline for ${body.ref}`)
    if (body.tip !== ref.tip) throw refusal(409, `${body.ref} moved since the form was loaded: its tip is now ${ref.tip}; reload and dispatch again`)
    if (body.generation !== ship.inv.generation) throw refusal(409, `the CI policy of demo changed since the form was loaded (generation ${body.generation}, now ${ship.inv.generation}): reload the workflow's inputs and dispatch again`)
    const wf = ref.workflows.find((w) => w.workflow === body.workflow)
    if (!wf) throw refusal(409, `workflow ${body.workflow} does not declare workflow_dispatch at the baseline revision of ${body.ref}`)
    const fields = {}
    for (const [id, value] of Object.entries(body.inputs || {})) {
      const input = wf.inputs.find((i) => i.id === id)
      if (!input) fields[id] = 'is not an input of this workflow'
      else if (input.type === 'boolean' && typeof value !== 'boolean') fields[id] = 'must be true or false'
      else if (input.type === 'number' && typeof value !== 'number') fields[id] = 'must be a number'
      else if (input.type === 'choice' && !input.options.includes(value)) fields[id] = `must be one of ${input.options.join(', ')}`
    }
    for (const input of wf.inputs) if (input.required && input.default === null && !(input.id in (body.inputs || {}))) fields[input.id] = 'is required'
    if (Object.keys(fields).length) throw refusal(422, `${Object.keys(fields).length} inputs refused: ${Object.entries(fields).map(([k, v]) => `${k} ${v}`).join('; ')}`, fields)
    const id = ship.runs.get(body.request)?.id || `0v${ship.next++}.run`
    const run = runOf(id, body)
    ship.runs.set(body.request, run)
    if (ship.loseNext) { ship.loseNext = false; throw new TypeError('Failed to fetch') }
    return { run: clone(run), fresh: true }
  }
  return ship
}
