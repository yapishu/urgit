// Test fixtures of Settings → CI recovery (CI-RECOVERY-1), shared by its
// tests and imported by nothing else:
// - the ship's recovery answer (GET ci/recovery), as app/urgit-ci writes
//   it in +recovery-section-json;
// - a model of the ship's recovery contract: the pause, the import that
//   refuses a corrupt checkpoint whole, the apply that names the staged id
//   and needs a pause, and the forge's and replica's later answers. Its
//   refusals are the ship's own words, copied from lib/ci-checkpoint and
//   app/urgit-ci (ciRecoverySource.test.js checks that they still are).
// It is a MODEL of the contract, not the controller: the producer of every
// answer here is this file.

export const NOW = 1_800_000_000
export const FIRST = '20261021t115500z-0002-zod'
export const STAGED = '20261020t090000z-0007-zod'

const sha = (c) => c.repeat(64)
const oid = (c) => c.repeat(40)

export const sections = (counts = {}) => ['policy', 'locks', 'access', 'runners', 'credentials', 'signing', 'runs', 'audit'].map((name, i) => ({
  name, file: `${name}.json`, count: counts[name] ?? i, sha256: sha(String(i)), bytes: 100 + i,
}))

export const checkpoint = (over = {}) => ({
  id: FIRST,
  at: NOW - 300,
  cause: 'policy change: set-environment (demo)',
  actor: '~zod',
  repository: 'ci-checkpoints',
  ref: 'refs/heads/main',
  commit: oid('a'),
  parent: oid('9'),
  manifest: sha('b'),
  sections: sections(),
  written: { state: 'written', at: NOW - 299 },
  replica: { state: 'confirmed', at: NOW - 290, route: 'GitHub owner/backup' },
  ...over,
})

export const staged = (over = {}) => ({
  id: STAGED,
  commit: oid('c'),
  imported: NOW - 10,
  actor: '~zod',
  manifest: {
    id: STAGED, ship: '~zod', desk: 'urgit', revision: 42, created: NOW - 86_400,
    cause: 'operator: checkpoint now', sections: sections({ credentials: 2, runners: 1 }),
    excluded: ['repository objects', 'credential values', 'private keys', 'the GitHub token'],
  },
  diff: [
    { section: 'policy', repo: 'demo', kind: 'add', text: 'CI required on refs/heads/main' },
    { section: 'access', repo: 'demo', kind: 'add', text: 'grants environment-approver (prod) for ~bud' },
    { section: 'credentials', repo: 'demo', kind: 'history', text: 'DEPLOY_KEY: comes back with no value and needs re-entry' },
    { section: 'runners', repo: '', kind: 'history', text: 'runner 0v1.daemn comes back as a record: it must re-enroll' },
    { section: 'signing', repo: '', kind: 'history', text: 'the checkpoint key 77 becomes history: this ship keeps its own key 42' },
  ],
  ...over,
})

export const viewOf = (over = {}) => ({
  authority: { manage: true, ship: '~zod' },
  paused: null,
  repository: {
    name: 'ci-checkpoints', readable: true, exists: true, private: true, linked: false,
    branch: 'refs/heads/main', tip: oid('a'), replica: 'GitHub owner/backup', replicaProblem: null,
  },
  checkpoints: [checkpoint()],
  staged: null,
  restores: [],
  history: { keys: [], runners: [], credentials: [], runs: 0, authorizations: 0, audit: 0 },
  running: 0,
  now: NOW,
  ...over,
})

const clone = (v) => JSON.parse(JSON.stringify(v))
const refusal = (message) => Object.assign(new Error(message), { status: 409 })

// the ship's recovery contract, modelled
export function modelShip(initial = viewOf()) {
  const ship = { view: clone(initial), posts: [], reads: 0, loseNext: false, failReads: false, deny: false, corrupt: false, next: 3 }
  ship.recoveryState = async () => {
    ship.reads++
    if (ship.deny) throw Object.assign(new Error('session required'), { status: 401 })
    if (ship.failReads) throw new TypeError('Failed to fetch')
    return clone(ship.view)
  }
  ship.action = async (body) => {
    ship.posts.push(clone(body))
    const lose = ship.loseNext
    ship.loseNext = false
    const v = ship.view
    switch (body.action) {
      case 'checkpoint-now': {
        const id = `20261021t120000z-000${ship.next++}-zod`
        v.checkpoints.unshift(checkpoint({ id, at: NOW, cause: 'operator: checkpoint now', written: { state: 'pending' }, replica: { state: 'waiting' } }))
        break
      }
      case 'pause-ci':
        if (v.paused) throw refusal('CI is already paused')
        v.paused = { at: NOW, actor: '~zod', reason: body.reason || 'paused for a restore' }
        break
      case 'resume-ci':
        if (!v.paused) throw refusal('CI is not paused')
        v.paused = null
        break
      case 'import-checkpoint':
        if (!v.paused) throw refusal('pause CI before importing a checkpoint: an import into a running CI is refused')
        if (ship.corrupt) throw refusal('corrupt checkpoint: the sha-256 of policy.json is not the one its manifest lists')
        v.staged = staged(body.commit ? { commit: body.commit } : {})
        break
      case 'discard-checkpoint':
        if (!v.staged) throw refusal('no checkpoint is staged')
        v.staged = null
        break
      case 'apply-checkpoint':
        if (!v.paused) throw refusal('pause CI before applying a checkpoint: an apply to a running CI is refused')
        if (!v.staged) throw refusal('no checkpoint is staged: import one first')
        if (body.checkpoint !== v.staged.id) throw refusal(`the staged checkpoint is ${v.staged.id}, not ${body.checkpoint}: review the staged one, then apply it`)
        if (v.running > 0) throw refusal(`${v.running} attempts are still running: wait for them to finish or cancel them, then apply`)
        v.restores.unshift({ id: v.staged.id, commit: v.staged.commit, at: NOW, actor: '~zod', repos: ['demo'], skipped: ['demo: CI was not required on refs/heads/release: it has no tip on this ship, so push the repository first, then require CI'], cancelled: 0 })
        v.history.credentials = [{ repo: 'demo', name: 'DEPLOY_KEY', scope: 'env' }]
        v.history.runners = [{ id: '0v1.daemn', labels: ['linux'], repos: ['demo'] }]
        v.history.keys = [{ pub: '77'.repeat(32), ship: '~zod', created: NOW - 86_400 }]
        v.staged = null
        break
      default:
        throw refusal('unknown action')
    }
    if (lose) throw new TypeError('Failed to fetch')
    return { ok: true, action: body.action }
  }
  // the forge's answer to the newest write, and the replica's to its push
  ship.written = () => { Object.assign(ship.view.checkpoints[0], { written: { state: 'written', at: NOW + 1 }, replica: { state: 'pushing', at: NOW + 1, route: 'GitHub owner/backup' } }) }
  ship.pushFailed = (reason) => { Object.assign(ship.view.checkpoints[0], { replica: { state: 'failed', at: NOW + 2, route: 'GitHub owner/backup', reason } }) }
  ship.pushConfirmed = () => { Object.assign(ship.view.checkpoints[0], { replica: { state: 'confirmed', at: NOW + 2, route: 'GitHub owner/backup' } }) }
  return ship
}
