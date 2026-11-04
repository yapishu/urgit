// Runs as the candidate route answers them (CI-CONCURRENCY-1): the
// `concurrency`, `cancellations`, `canCancel` and `cancelAuthority` fields
// in the shape desk/app/urgit-ci.hoon +concurrency-json, +group-json,
// +run-ref-json and +cancellation-json write, and with the ship's own
// reason texts (lib/ci-concurrency). They are a MODEL of
// the agent's answers, labelled as such; ciConcurrencyWire.test.js checks
// the keys and words against the agent's source, and the agent's own
// answers are the parent's live recipe.

export const AUTHORITY = 'only the repository\'s owner, or a ship holding its ci-policy role, cancels a run'
export const UNREAD = 'concurrency not read for this lock: resolve or promote again to apply it'
export const TRIAL = 'a trial twin takes part in no concurrency group: it would evaluate its required twin\'s group and cancel it'

const older = { id: '0v1.older', label: 'push of 1a2b3c4d to main' }
const newer = { id: '0v1.newer', label: 'push of 5e6f7a8b to main' }
const newest = { id: '0v1.newest', label: 'push of 9c0d1e2f to main' }

export const member = (place, over = {}) => ({ kind: 'member', text: 'deploy-main', cancelInProgress: false, place, behind: null, since: 1792378800, ...over })

const run = (over = {}) => ({
  id: '0v1.run',
  repo: 'demo',
  ref: 'refs/heads/main',
  status: 'pending',
  mode: 'required',
  verdictReason: null,
  canCancel: true,
  cancelAuthority: null,
  cancellations: [],
  ...over,
})

const joined = (workflows) => ({ state: 'joined', reason: null, joined: 1792378800, workflows })

// a newcomer with cancel-in-progress false waits behind the run in progress
export const waitingRun = run({
  concurrency: joined([
    { workflow: 'deploy.yml', name: 'Deploy', group: member('waiting', { behind: older }), cancelled: null, finished: false },
    { workflow: 'ci.yml', name: 'CI', group: { kind: 'free' }, cancelled: null, finished: false },
  ]),
})

// the same run as a ship without the ci-policy role sees it
export const noAuthorityRun = run({ ...waitingRun, canCancel: false, cancelAuthority: AUTHORITY })

// the run in progress in its group, and one workflow of it finished
export const holdingRun = run({
  concurrency: joined([
    { workflow: 'deploy.yml', name: 'Deploy', group: member('holding', { cancelInProgress: true }), cancelled: null, finished: false },
    { workflow: 'lint.yml', name: 'Lint', group: member('released', { text: 'lint-main' }), cancelled: null, finished: true },
  ]),
})

const superseded = {
  at: 1792378900,
  started: true,
  cause: 'superseded',
  reason: `cancelled: the newer run (${newer.label}) joined group deploy-main with cancel-in-progress`,
  actor: null,
  by: newer,
  group: 'deploy-main',
}

// a running run cancelled by a newcomer with cancel-in-progress: finished
export const supersededRun = run({
  status: 'cancelled',
  canCancel: false,
  verdictReason: `deploy.yml: ${superseded.reason}`,
  concurrency: joined([
    { workflow: 'deploy.yml', name: 'Deploy', group: member('released', { cancelInProgress: true, since: 1792378950 }), cancelled: superseded, finished: true },
  ]),
  cancellations: [{ ...superseded, workflow: 'deploy.yml' }],
})

// the same cancellation while the run's always() jobs still run
export const stoppingRun = run({
  concurrency: joined([
    { workflow: 'deploy.yml', name: 'Deploy', group: member('holding', { cancelInProgress: true }), cancelled: superseded, finished: false },
  ]),
  cancellations: [{ ...superseded, workflow: 'deploy.yml' }],
})

const displaced = {
  at: 1792379000,
  started: false,
  cause: 'displaced',
  reason: `cancelled: a newer run (${newest.label}) is waiting in group deploy-main`,
  actor: null,
  by: newest,
  group: 'deploy-main',
}

// an older waiting run displaced by a newer arrival: it never started
export const displacedRun = run({
  status: 'cancelled',
  canCancel: false,
  verdictReason: `deploy.yml: ${displaced.reason}`,
  concurrency: joined([
    { workflow: 'deploy.yml', name: 'Deploy', group: member('released', { since: 1792379000 }), cancelled: displaced, finished: true },
  ]),
  cancellations: [{ ...displaced, workflow: 'deploy.yml' }],
})

const byOperator = {
  at: 1792379100,
  started: true,
  cause: 'operator',
  reason: 'cancelled by ~zod: cancelled from the CI tab',
  actor: '~zod',
  by: null,
  group: null,
}

// the whole run cancelled from the CI tab while a cleanup job runs
export const operatorRun = run({
  canCancel: false,
  concurrency: joined([
    { workflow: 'ci.yml', name: 'CI', group: { kind: 'free' }, cancelled: byOperator, finished: false },
  ]),
  cancellations: [{ ...byOperator, workflow: '' }],
})

// a group that cannot be evaluated refuses that workflow's run
export const refusedRun = run({
  concurrency: joined([
    { workflow: 'deploy.yml', name: 'Deploy', group: { kind: 'refused', reason: 'the concurrency group \'${{ inputs.group }}\' evaluated to the empty text' }, cancelled: null, finished: false },
    { workflow: 'ci.yml', name: 'CI', group: { kind: 'free' }, cancelled: null, finished: false },
  ]),
})

// a lock compiled before concurrency was read: unknown, never "no group"
export const oldLockRun = run({
  concurrency: { state: 'unknown', reason: UNREAD, joined: null, workflows: [{ workflow: 'ci.yml', name: 'ci.yml', group: null, cancelled: null, finished: false }] },
})

// a joined run whose catalog does not list one of its workflows
export const unknownWorkflowRun = run({
  concurrency: joined([
    { workflow: 'ci.yml', name: 'ci.yml', group: { kind: 'unknown', reason: UNREAD }, cancelled: null, finished: false },
  ]),
})

export const trialRun = run({
  mode: 'trial',
  concurrency: { state: 'exempt', reason: TRIAL, joined: null, workflows: [] },
})

// a run that has not joined yet (not materialized)
export const joiningRun = run({
  concurrency: { state: 'pending', reason: null, joined: null, workflows: [] },
})

// a manual run, advisory
export const manualWaitingRun = run({ ...waitingRun, id: '0v1.manual', mode: 'manual' })
