import test from 'node:test'
import assert from 'node:assert/strict'
import { approvalRows, auditRows, backendTable, grantState, lockDiff, modeLabel, nodeIdentity, overrideConfirmation, overrideRows, waitRows, parseMappings, parsePaths, parseShips, provenanceActions, refusalMessage, waitExplanation } from './ciProvenance.js'

const checkout = { uses: 'actions/checkout@v4', kind: 'js', commit: '11d5960a326750d5838078e36cf38b85af677262', tree: 'f8a7b72dc00648d050099727d25ca92a43ad1162', mirror: 'ci-mirror-actions-checkout', 'mirror-commit': '7fcfc62a9d93ce747310f9535b43c86ca615250d' }
const fixture = { uses: 'fixture/action@v1', kind: 'composite', commit: 'aaaa000000000000000000000000000000000001', tree: 'bbbb000000000000000000000000000000000001', mirror: 'ci-mirror-fixture-action', 'mirror-commit': 'cccc000000000000000000000000000000000001' }
const pill = { uses: 'https://bootstrap.urbit.org/urbit-v4.6.pill', kind: 'download', sha256: 'c0ffee'.padEnd(64, '0'), size: 210249590, mirror: 'store' }

test('the action bodies name the P4 actions exactly; optional fields are absent when empty', () => {
  assert.deepEqual(provenanceActions.resolve('r', 'a'.repeat(40)), { action: 'resolve-dependencies', repo: 'r', revision: 'a'.repeat(40) })
  assert.deepEqual(provenanceActions.resolve('r', 'a'.repeat(40), [{ from: 'https://github.com/x/y', to: 'http://127.0.0.1:8471/git/y' }]).mappings.length, 1)
  assert.deepEqual(provenanceActions.promote('r', 'refs/heads/master', 'a'.repeat(40), 'why'), { action: 'promote-baseline', repo: 'r', ref: 'refs/heads/master', revision: 'a'.repeat(40), reason: 'why' })
  assert.equal(provenanceActions.promote('r', 'refs/heads/master', 'a'.repeat(40), 'why', 'd'.repeat(64)).lock, 'd'.repeat(64))
  assert.deepEqual(provenanceActions.setRole('r', 'override', ['~syd'], 'refs/heads/master'), { action: 'set-role', repo: 'r', role: 'override', ships: ['~syd'], scope: 'refs/heads/master' })
  assert.equal('scope' in provenanceActions.setRole('r', 'ci-policy', ['~syd']), false)
  assert.deepEqual(provenanceActions.approveEnvironment('0vc', 'ci.yml', 'deploy', 'prod', ['DEPLOY_KEY']), { action: 'approve-environment', id: '0vc', workflow: 'ci.yml', job: 'deploy', environment: 'prod', credentials: ['DEPLOY_KEY'] })
  assert.deepEqual(provenanceActions.recordOverride('r', 'refs/heads/master', '0vc', 'a'.repeat(40), 'b'.repeat(40), 'hotfix').action, 'record-override')
  assert.deepEqual(provenanceActions.setSandbox('r', 'container'), { action: 'set-sandbox-requirement', repo: 'r', need: 'container' })
})

test('a lock diff names added, removed and changed nodes by identity; a re-mirror alone is not a change', () => {
  const before = { nodes: [checkout, fixture, pill] }
  const moved = { ...fixture, commit: 'aaaa000000000000000000000000000000000002', tree: 'bbbb000000000000000000000000000000000002', 'mirror-commit': 'cccc000000000000000000000000000000000002' }
  const after = { nodes: [checkout, moved, { ...pill, mirror: 'store' }, { uses: 'actions/cache@v4', kind: 'js', commit: '2'.repeat(40), tree: '3'.repeat(40) }] }
  const d = lockDiff(before, after)
  assert.equal(d.same, false)
  assert.deepEqual(d.added.map((n) => n.uses), ['actions/cache@v4'])
  assert.deepEqual(d.removed, [])
  assert.deepEqual(d.changed.map((c) => c.uses), ['fixture/action@v1'])
  assert.match(d.changed[0].from, /aaaa0+1 tree bbbb0+1/)
  assert.match(d.changed[0].to, /aaaa0+2/)
  const remirror = lockDiff({ nodes: [checkout] }, { nodes: [{ ...checkout, 'mirror-commit': '9'.repeat(40) }] })
  assert.equal(remirror.same, true)
  assert.deepEqual(remirror.remirrored, ['actions/checkout@v4'])
  assert.equal(lockDiff(before, before).same, true)
  assert.equal(nodeIdentity(pill), `sha256 ${'c0ffee'.padEnd(64, '0')} (210249590 bytes)`)
  assert.equal(nodeIdentity({ kind: 'container', digest: 'sha256:ab' }), 'sha256:ab')
})

test('required, trial and shadow are told apart, and a trial says it never replaces required evidence', () => {
  assert.equal(modeLabel({ mode: 'required', baseline: 'e'.repeat(40), generation: 3 }).label, 'required')
  assert.match(modeLabel({ mode: 'required', baseline: 'e'.repeat(40), generation: 3 }).detail, /generation 3/)
  assert.match(modeLabel({ mode: 'required' }).detail, /none is promoted/)
  const trial = modeLabel({ mode: 'trial', trialOf: '0vreq' })
  assert.equal(trial.label, 'trial')
  assert.match(trial.detail, /never lands and never replaces required evidence/)
  assert.match(trial.detail, /0vreq/)
  assert.match(modeLabel({ mode: 'shadow' }).detail, /never lands and never deploys/)
})

test('a waiting candidate gets guidance for each of the ship\'s reasons, and none for an unknown one', () => {
  assert.match(waitExplanation('no promoted baseline for refs/heads/master; promote a harness revision'), /Promote a harness revision/)
  assert.match(waitExplanation('no runner satisfies sandbox requirement vm'), /VM runner/)
  assert.match(waitExplanation('no runner supports network profile egress'), /network policy/)
  assert.match(waitExplanation('environment prod needs an approval for job deploy'), /environment approval/)
  assert.match(waitExplanation('environment staging is not defined for r; the job waits'), /no record of/)
  assert.match(waitExplanation('plan-invalid: lock refused: unresolved dependency actions/x@v1'), /resolve the revision/)
  assert.match(waitExplanation('policy generation 4: baseline promoted'), /runs again under the new generation/)
  assert.match(waitExplanation('destination moved; rebase and push again'), /rebase/)
  assert.equal(waitExplanation('something new'), '')
  assert.equal(waitExplanation(''), '')
  // per-job waits: only a pending candidate's, each with its explanation
  const waits = [{ workflow: 'ci.yml', job: 'deploy', reason: 'environment prod needs an approval for job deploy' }, { workflow: 'ci.yml', job: 'staging', reason: 'environment staging is not defined for r; the job waits' }]
  const rows = waitRows({ status: 'pending', waits })
  assert.equal(rows.length, 2)
  assert.equal(rows[0].key, 'ci.yml/deploy')
  assert.equal(rows[0].label, 'ci.yml · deploy')
  assert.match(rows[0].explanation, /environment approval/)
  assert.match(rows[1].explanation, /no record of/)
  assert.deepEqual(waitRows({ status: 'passed', waits }), [])
  assert.deepEqual(waitRows({ status: 'pending' }), [])
})

test('approvals and overrides show their fifteen-minute clock, consumed, invalidated and expired states', () => {
  const now = 1_000_000
  const fresh = { id: '0va', workflow: 'ci.yml', job: 'deploy', environment: 'prod', credentials: ['DEPLOY_KEY'], approver: '~syd', generation: 3, at: now, expires: now + 900 }
  assert.equal(grantState(fresh, now + 100).state, 'valid')
  assert.equal(grantState(fresh, now + 100).detail, '13m 20s left')
  assert.equal(grantState(fresh, now + 900).state, 'expired')
  assert.equal(grantState({ ...fresh, consumed: '0vatt' }, now).state, 'consumed')
  assert.match(grantState({ ...fresh, consumed: '0vatt' }, now).detail, /0vatt/)
  assert.equal(grantState({ ...fresh, invalidated: 'policy generation 4: role bound' }, now).state, 'invalidated')
  assert.equal(approvalRows([fresh], now)[0].job, 'ci.yml/deploy')
  const over = overrideRows([{ id: '0vo', oid: 'a'.repeat(40), expected: 'b'.repeat(40), actor: '~tyv', reason: 'hotfix', missing: 'status failed', generation: 3, at: now, expires: now + 900, consumed: now + 1 }], now + 2)
  assert.equal(over[0].state, 'consumed')
  assert.equal(over[0].missing, 'status failed')
})

test('the override confirmation names the exact object, the tip, the missing evidence and the single-use clock; it refuses without an oid, a tip or a reason', () => {
  const c = { ref: 'refs/heads/master', candidate: 'a'.repeat(40), status: 'failed', verdictReason: 'job check in ci.yml failed' }
  const ok = overrideConfirmation(c, 'b'.repeat(40), 'hotfix')
  assert.equal(ok.ok, true)
  assert.equal(ok.missing, 'status failed (job check in ci.yml failed)')
  assert.match(ok.text, /single-use and expires in fifteen minutes/)
  assert.match(ok.text, /status does not change/)
  assert.equal(overrideConfirmation(c, 'b'.repeat(40), '').ok, false)
  assert.equal(overrideConfirmation({ ...c, candidate: null }, 'b'.repeat(40), 'x').ok, false)
  assert.equal(overrideConfirmation(c, 'not-a-tip', 'x').ok, false)
  assert.equal(overrideConfirmation({ ...c, status: 'passed', bindingsCurrent: false }, 'b'.repeat(40), 'x').missing, 'bindings not current')
})

test('hostile displayed metadata stays text: reasons, notices and licenses are never markup', () => {
  const hostile = '<script>alert(1)</script> & "quotes" <img onerror=x>'
  assert.equal(auditRows([{ at: 1, actor: '~syd', kind: 'promote-baseline', detail: hostile }])[0].detail, hostile)
  assert.equal(waitExplanation(hostile), '')
  assert.equal(modeLabel({ mode: 'trial', trialOf: hostile }).detail.includes(hostile), true)
  assert.equal(nodeIdentity({ kind: 'container', digest: hostile }), hostile)
  assert.equal(refusalMessage(new Error(`409 ${hostile}`)), hostile)
})

test('mappings, ships and paths parse from text; a malformed mapping refuses the whole list', () => {
  assert.deepEqual(parseMappings('https://github.com/fixture/action -> http://127.0.0.1:8471/git/fixture-action\n\nhttps://bootstrap.urbit.org/ -> https://mirror.example/'), { error: '', mappings: [{ from: 'https://github.com/fixture/action', to: 'http://127.0.0.1:8471/git/fixture-action' }, { from: 'https://bootstrap.urbit.org/', to: 'https://mirror.example/' }] })
  assert.match(parseMappings('github.com/x -> ftp://y').error, /Not a mapping/)
  assert.match(parseMappings('just words').error, /Not a mapping/)
  assert.deepEqual(parseMappings('').mappings, [])
  assert.deepEqual(parseShips('~syd, nec bus'), ['~syd', '~nec', '~bus'])
  assert.deepEqual(parsePaths('.github/ bin/,tests/'), ['.github/', 'bin/', 'tests/'])
  assert.equal(refusalMessage(new Error('409 ~syd does not hold ci-policy for r')), '~syd does not hold ci-policy for r')
  assert.equal(refusalMessage('Failed to fetch'), 'Failed to fetch')
})

test('the backend table says what each backend is and is not', () => {
  const docker = backendTable.find((r) => r.backend.startsWith('docker'))
  assert.match(docker.boundary, /not a VM boundary/)
  assert.match(docker.note, /never selected for VM-required work/)
  assert.match(docker.network, /destinations are not narrowed/)
  const vm = backendTable.find((r) => r.backend.startsWith('microvm'))
  assert.match(vm.required, /default/)
})

// Delivery 1C: an automatic event's run is advisory
test('an event run is labelled as advisory: it never lands, never satisfies a required check and holds no credentials', () => {
  const m = modeLabel({ mode: 'event', baseline: 'e'.repeat(40) })
  assert.equal(m.label, 'event')
  assert.match(m.detail, /never lands/)
  assert.match(m.detail, /never satisfies the required checks/)
  assert.match(m.detail, /no credentials/)
})
