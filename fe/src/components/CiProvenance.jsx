import React, { useCallback, useEffect, useState } from 'react'
import { makeAutomaticInputs } from '../automaticInputsComponent'
import { inputProvenanceText } from '../automaticInputs'
import { ci } from '../api'
import { approvalRows, auditRows, backendTable, lockDiff, modeLabel, nodeIdentity, overrideConfirmation, overrideRows, waitRows, parseMappings, parsePaths, parseShips, provenanceActions, refusalMessage, waitExplanation } from '../ciProvenance'
import { exactTime } from '../format'

// The CI policy surface (BRIEF-CI-P4 S5; riders 02-04): the Settings
// section for baselines, locks, harness paths, the sandbox requirement,
// roles, environments and network policies — every write an explicit,
// audited action of the session's ship (a delegate on another ship
// posts the same body through its own ship's peer route) — and the
// candidate page's provenance panel: required against trial, the
// baseline and lock identities, the sandbox need, environment approvals,
// the override confirmation, and the guidance a waiting candidate
// shows. Every displayed string is printed as text.

const AutomaticInputs = makeAutomaticInputs(React, ci)

const short = (s, n = 12) => (s ? String(s).slice(0, n) : '—')

function LockView({ repo, digest, other }) {
  const [lock, setLock] = useState(null)
  const [otherLock, setOtherLock] = useState(null)
  const [error, setError] = useState('')
  useEffect(() => {
    let live = true
    setLock(null); setOtherLock(null); setError('')
    if (!digest) return undefined
    ci.lock(repo, digest).then((l) => { if (live) setLock(l) }).catch((cause) => { if (live) setError(refusalMessage(cause)) })
    if (other) ci.lock(repo, other).then((l) => { if (live) setOtherLock(l) }).catch(() => {})
    return () => { live = false }
  }, [repo, digest, other])
  if (!digest) return null
  if (error) return <small className="field-error">Lock unavailable: {error}</small>
  if (!lock) return <small className="quiet">Loading lock…</small>
  const diff = otherLock ? lockDiff(otherLock, lock) : null
  return (
    <div className="ci-lock">
      <small className="quiet">Lock <code>{short(lock.digest, 16)}</code> · revision <code>{short(lock.revision)}</code> · resolved {exactTime(lock.resolved)} by <code>{short(lock.resolver, 10)}</code> · {lock.nodes.length} nodes · {lock.bytes} bytes of metadata</small>
      <p className="ci-input-provenance">{lock.automaticInputEvidence ? `Automatic resolution policy ${lock.automaticInputEvidence.policyId}; runner ceiling ${lock.automaticInputEvidence.ceilingId}. These identities belong to this resolution; reuse performs no new external acquisition.` : 'Prior import or resolution: no automatic acquisition evidence recorded. Reusing this exact lock does not authorize a new external fetch.'}</p>
      {lock.automaticInputEvidence?.acquisitions?.map((a, i) => <p className="ci-input-provenance" key={i}><code>{a.url}</code> → <code>{a.resolvedUrl}</code> · SHA-256 <code>{a.sha256}</code> · {a.size} bytes</p>)}
      {diff && !diff.same && <div className="ci-lock-diff">
        <strong>Changes from the baseline's lock</strong>
        {diff.changed.map((c) => <div key={c.uses}><code>{c.uses}</code>: {c.from} → {c.to}</div>)}
        {diff.added.map((n) => <div key={n.uses}>added <code>{n.uses}</code> ({nodeIdentity(n)})</div>)}
        {diff.removed.map((n) => <div key={n.uses}>removed <code>{n.uses}</code></div>)}
      </div>}
      {diff && diff.same && <small className="quiet">Same identities as the baseline's lock{diff.remirrored.length ? ` (re-mirrored: ${diff.remirrored.join(', ')})` : ''}.</small>}
      <div className="ci-list">
        <div className="table-head ci-lock-row"><span>Dependency</span><span>Kind</span><span>Identity</span><span>Mirror</span><span>License</span></div>
        {lock.nodes.map((n, i) => (
          <div className={`ci-lock-row${n.refusal ? ' bad' : ''}`} key={`${n.uses}-${i}`} title={n.refusal || ''}>
            <span><code>{n.uses}</code><small className="quiet"> {n.workflow}/{n.job} step {n.step}</small>{n.refusal && <small className="field-error"> refused: {n.refusal}</small>}</span>
            <span data-label="Kind">{n.kind}</span>
            <span data-label="Identity"><code>{nodeIdentity(n) || '—'}</code></span>
            <span data-label="Mirror">{n.mirror ? <code>{n.mirror}{n['mirror-commit'] ? `@${short(n['mirror-commit'], 8)}` : ''}</code> : <small className="quiet">—</small>}</span>
            <span data-label="License">{n.license || <small className="quiet">none read</small>}</span>
          </div>
        ))}
      </div>
      {lock.notices?.length > 0 && <details><summary>{lock.notices.length} notice(s)</summary><ul>{lock.notices.map((t, i) => <li key={i}>{t}</li>)}</ul></details>}
    </div>
  )
}

export function CiPolicySection({ repo, policy, onChanged }) {
  const repoName = repo.name
  const [busy, setBusy] = useState('')
  const [error, setError] = useState('')
  const [audit, setAudit] = useState([])
  const [revision, setRevision] = useState('')
  const [mappings, setMappings] = useState('')
  const [reason, setReason] = useState('')
  const [promoteRef, setPromoteRef] = useState('refs/heads/master')
  const [promoteLock, setPromoteLock] = useState('')
  const [harness, setHarness] = useState((policy?.harnessPaths || ['.github/']).join(' '))
  const [role, setRole] = useState({ role: 'ci-policy', ships: '', scope: '' })
  const [env, setEnv] = useState({ name: '', automation: 'manual', credentials: '', description: '' })
  const [net, setNet] = useState({ workflow: '', job: '', profile: '', destinations: '', environment: '' })
  const [viewLock, setViewLock] = useState('')
  const loadAudit = useCallback(async () => {
    try { const a = await ci.audit(repoName); setAudit(auditRows(a.audit || [])) } catch (cause) { setAudit([]) }
  }, [repoName])
  useEffect(() => { loadAudit() }, [loadAudit, policy])
  useEffect(() => { setHarness((policy?.harnessPaths || ['.github/']).join(' ')) }, [policy])
  async function act(label, body) {
    setBusy(label); setError('')
    try { await ci.action(body); await onChanged?.(); await loadAudit() } catch (cause) { setError(refusalMessage(cause)) } finally { setBusy('') }
  }
  const baselines = policy?.baselines || []
  const locks = policy?.locks || []
  const roles = policy?.roles || []
  const environments = policy?.environments || []
  const networkPolicies = policy?.networkPolicies || []
  const parsedMappings = parseMappings(mappings)
  return (
    <div className="subsection ci-policy">
      <div className="section-title"><div><h3>CI policy</h3><p>Required checks run the promoted baseline's harness with its resolved lock; the candidate's own YAML is not evidence. Every change here is an audited action and moves the policy generation (generation <strong>{policy?.generation ?? '—'}</strong>, incarnation <code>{short(policy?.incarnation, 10)}</code>).</p></div></div>
      {error && <small className="field-error">{error}</small>}
      <AutomaticInputs repo={repoName} policy={policy} onChanged={onChanged} />
      <div className="ci-policy-block">
        <strong>Sandbox requirement</strong>
        <div className="ci-radio">
          {[['vm', 'VM (Firecracker + jailer)', 'The default: a fresh microVM per job; every privileged, trial, shadow and untrusted job runs here regardless.'], ['container', 'Container compatibility', 'Explicit trusted-compatibility opt-in: a rootless Docker sandbox that is not a VM boundary; never used for privileged, trial, shadow or untrusted work.']].map(([value, label, detail]) => (
            <label className="check-row compact" key={value}><input type="radio" name={`sandbox-${repoName}`} value={value} checked={(policy?.sandboxRequirement || 'vm') === value} disabled={busy !== ''} onChange={() => act('sandbox', provenanceActions.setSandbox(repoName, value))} /><span>{label} <small className="quiet">{detail}</small></span></label>
          ))}
        </div>
      </div>
      <div className="ci-policy-block">
        <strong>Baselines</strong>
        {baselines.map((b) => (
          <div key={b.ref} className="ci-baseline">
            <code>{b.ref}</code> → revision <code>{short(b.revision)}</code>, lock <code>{b.lock ? short(b.lock, 16) : 'none'}</code>, harness {(b.harnessPaths || []).join(', ')}, generation {b.generation}, promoted by {b.actor} ({b.reason})
            <div className="form-actions"><button className="text-button" onClick={() => setViewLock(viewLock === b.lock ? '' : b.lock)}>{viewLock === b.lock ? 'Hide lock' : 'Lock'}</button><button className="text-button danger-text" disabled={busy !== ''} onClick={() => act('revoke', provenanceActions.revoke(repoName, b.ref, 'revoked from settings'))}>Revoke</button></div>
          </div>
        ))}
        {!baselines.length && <small className="quiet">No baseline promoted: required checks cannot run until a harness revision is resolved and promoted.</small>}
        {viewLock && <LockView repo={repoName} digest={viewLock} />}
      </div>
      <div className="ci-policy-block">
        <strong>Import (resolve) and promote</strong>
        <small className="quiet">Explicit imports walk the revision's workflows and mirror dependencies into this ship. Ordinary tags use their tagged YAML without promotion. Automatic HTTPS downloads require both the repository allowlist and the runner owner's ceiling. Git/action and registry acquisition remain unsupported automatically; dependency-free workflows and an existing lock for the exact revision are supported. Promotion adopts a revision and its lock as a branch baseline.</small>
        <label><span>Revision (40 hex)</span><input value={revision} onChange={(e) => setRevision(e.target.value.trim())} placeholder="a6d15edd…" /></label>
        <label><span>Explicit mappings (optional, one per line: from -&gt; http(s)://to)</span><textarea rows={2} value={mappings} onChange={(e) => setMappings(e.target.value)} /></label>
        {parsedMappings.error && <small className="field-error">{parsedMappings.error}</small>}
        <div className="form-actions"><button className="button" disabled={busy !== '' || !/^[0-9a-f]{40}$/.test(revision) || Boolean(parsedMappings.error)} onClick={() => act('resolve', provenanceActions.resolve(repoName, revision, parsedMappings.mappings))}>{busy === 'resolve' ? 'Resolving…' : 'Resolve dependencies'}</button></div>
        <div className="three-fields">
          <label><span>Ref</span><input value={promoteRef} onChange={(e) => setPromoteRef(e.target.value.trim())} /></label>
          <label><span>Lock (optional digest; the newest for the revision otherwise)</span><select value={promoteLock} onChange={(e) => setPromoteLock(e.target.value)}><option value="">newest for the revision</option>{locks.filter((l) => l.revision === revision).map((l) => <option key={l.digest} value={l.digest}>{short(l.digest, 16)} · {exactTime(l.resolved)}</option>)}</select></label>
          <label><span>Reason</span><input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="why this revision" /></label>
        </div>
        <div className="form-actions"><button className="button primary" disabled={busy !== '' || !/^[0-9a-f]{40}$/.test(revision) || !reason.trim()} onClick={() => act('promote', provenanceActions.promote(repoName, promoteRef, revision, reason.trim(), promoteLock))}>{busy === 'promote' ? 'Promoting…' : 'Promote as baseline'}</button></div>
        {locks.length > 0 && <details><summary>{locks.length} resolved lock(s)</summary>{locks.map((l) => <div key={l.digest}><code>{short(l.digest, 16)}</code> revision <code>{short(l.revision)}</code> · {exactTime(l.resolved)} · {(l.nodes || []).length} nodes <button className="text-button" onClick={() => setViewLock(l.digest)}>view</button>{baselines[0]?.lock && baselines[0].lock !== l.digest && <button className="text-button" onClick={() => setViewLock(`${l.digest}|${baselines[0].lock}`)}>diff vs baseline</button>}</div>)}</details>}
        {viewLock.includes('|') && <LockView repo={repoName} digest={viewLock.split('|')[0]} other={viewLock.split('|')[1]} />}
      </div>
      <div className="ci-policy-block">
        <strong>Harness paths</strong>
        <small className="quiet">Paths a required run takes from the baseline, byte for byte, whatever the candidate changed there.</small>
        <div className="form-actions split"><input value={harness} onChange={(e) => setHarness(e.target.value)} /><button className="button" disabled={busy !== '' || !parsePaths(harness).length} onClick={() => act('harness', provenanceActions.setHarnessPaths(repoName, parsePaths(harness)))}>Save paths</button></div>
      </div>
      <div className="ci-policy-block">
        <strong>Roles</strong>
        <small className="quiet">The owner holds every role implicitly. A bound ship acts from its own ship's UI; its request is judged here and audited under its name.</small>
        {roles.map((r, i) => <div key={i}><code>{r.role}</code>{r.scope ? <> ({r.scope})</> : null}: {(r.ships || []).join(', ')} <button className="text-button danger-text" disabled={busy !== ''} onClick={() => act('clear-role', provenanceActions.clearRole(repoName, r.role, r.scope))}>Clear</button></div>)}
        <div className="three-fields">
          <label><span>Role</span><select value={role.role} onChange={(e) => setRole({ ...role, role: e.target.value })}><option value="ci-policy">ci-policy</option><option value="environment-approver">environment-approver</option><option value="override">override</option></select></label>
          <label><span>Ships</span><input value={role.ships} onChange={(e) => setRole({ ...role, ships: e.target.value })} placeholder="~syd, ~nec" /></label>
          <label><span>Scope (environment / branch)</span><input value={role.scope} onChange={(e) => setRole({ ...role, scope: e.target.value })} placeholder="prod or refs/heads/master" /></label>
        </div>
        <div className="form-actions"><button className="button" disabled={busy !== '' || !parseShips(role.ships).length} onClick={() => act('set-role', provenanceActions.setRole(repoName, role.role, parseShips(role.ships), role.scope.trim()))}>Bind role</button></div>
      </div>
      <div className="ci-policy-block">
        <strong>Environments</strong>
        <small className="quiet">A job that names an environment is privileged: it needs an approval (fifteen minutes, single use) or the environment's automation rule, runs in the VM, and receives only the environment's credentials the approval released.</small>
        {environments.map((e) => <div key={e.name}><code>{e.name}</code> · {e.automation} · credentials {(e.credentials || []).join(', ') || 'none'} {e.description && <small className="quiet">— {e.description}</small>} <button className="text-button danger-text" disabled={busy !== ''} onClick={() => act('delete-env', provenanceActions.deleteEnvironment(repoName, e.name))}>Delete</button></div>)}
        <div className="three-fields">
          <label><span>Name</span><input value={env.name} onChange={(e) => setEnv({ ...env, name: e.target.value })} placeholder="production" /></label>
          <label><span>Automation</span><select value={env.automation} onChange={(e) => setEnv({ ...env, automation: e.target.value })}><option value="manual">manual approval</option><option value="automatic">automatic (admits without a click)</option></select></label>
          <label><span>Credentials</span><input value={env.credentials} onChange={(e) => setEnv({ ...env, credentials: e.target.value })} placeholder="DEPLOY_KEY, REGISTRY_TOKEN" /></label>
        </div>
        <div className="form-actions"><button className="button" disabled={busy !== '' || !env.name.trim()} onClick={() => act('set-env', provenanceActions.setEnvironment(repoName, env.name.trim(), env.automation, parsePaths(env.credentials), env.description))}>Save environment</button></div>
      </div>
      <div className="ci-policy-block">
        <strong>Network policies</strong>
        <small className="quiet">Locked is the default. A policy lets one job of one workflow use a runner profile toward these destinations (tcp:&lt;ip or DNS name&gt;:&lt;port&gt;, for example tcp:archive.ubuntu.com:80); labels select runners and never grant. The effective access is bounded by this policy, the runner's declared profile and the launcher's ceiling. A DNS name is allowed by the addresses it resolves to when the job starts. Other sites on those addresses, such as sites on a shared CDN, are reachable on that port too.</small>
        {networkPolicies.map((n, i) => <div key={i}><code>{n.workflow}/{n.job}</code> → {n.profile} [{(n.destinations || []).join(', ')}]{n.environment ? ` (${n.environment})` : ''} <button className="text-button danger-text" disabled={busy !== ''} onClick={() => act('clear-net', provenanceActions.clearNetworkPolicy(repoName, n.workflow, n.job))}>Clear</button></div>)}
        <div className="three-fields">
          <label><span>Workflow file</span><input value={net.workflow} onChange={(e) => setNet({ ...net, workflow: e.target.value })} placeholder="ci.yml" /></label>
          <label><span>Job</span><input value={net.job} onChange={(e) => setNet({ ...net, job: e.target.value })} placeholder="integration" /></label>
          <label><span>Profile</span><input value={net.profile} onChange={(e) => setNet({ ...net, profile: e.target.value })} placeholder="egress" /></label>
        </div>
        <label><span>Destinations</span><input value={net.destinations} onChange={(e) => setNet({ ...net, destinations: e.target.value })} placeholder="tcp:140.82.112.3:443 tcp:1.1.1.1:443" /></label>
        <div className="form-actions"><button className="button" disabled={busy !== '' || !net.workflow || !net.job || !net.profile || !parsePaths(net.destinations).length} onClick={() => act('set-net', provenanceActions.setNetworkPolicy(repoName, net.workflow.trim(), net.job.trim(), net.profile.trim(), parsePaths(net.destinations), net.environment.trim()))}>Set policy</button></div>
      </div>
      <div className="ci-policy-block">
        <strong>Backends</strong>
        <div className="ci-list">
          <div className="table-head ci-backend-row"><span>Backend</span><span>Boundary</span><span>Required work</span><span>Network</span><span>Note</span></div>
          {backendTable.map((r) => <div className="ci-backend-row" key={r.backend}><span>{r.backend}</span><span data-label="Boundary">{r.boundary}</span><span data-label="Required work">{r.required}</span><span data-label="Network">{r.network}</span><span data-label="Note">{r.note}</span></div>)}
        </div>
        <small className="quiet">Labels are placement, not containment: a label picks which enrolled runner may take a job; only the runner's sandbox backend and the ship's sandbox requirement decide what contains it.</small>
      </div>
      <div className="ci-policy-block">
        <strong>Audit</strong>
        <div className="ci-audit">{audit.slice(0, 40).map((e, i) => <div key={i}><small className="quiet">{exactTime(e.at)}</small> <code>{e.actor}</code> <strong>{e.kind}</strong> {e.detail}</div>)}{!audit.length && <small className="quiet">Nothing recorded yet.</small>}</div>
      </div>
    </div>
  )
}

// the candidate page's provenance panel
export function CandidateProvenance({ data, tip, onAct, busy, confirm }) {
  const c = data.candidate
  const mode = modeLabel(c)
  const [approval, setApproval] = useState({ job: '', environment: '', credentials: '' })
  const [overrideReason, setOverrideReason] = useState('')
  const privileged = (c.plan || []).filter((j) => j.environment)
  const explanation = c.status === 'pending' ? waitExplanation(c.verdictReason) : ''
  const now = Date.now() / 1000
  const approvals = approvalRows(c.approvals || [], now)
  const overrides = overrideRows(c.overrides || [], now)
  async function recordOverride() {
    const conf = overrideConfirmation(c, tip, overrideReason)
    if (!conf.ok) return
    if (confirm && !(await confirm({ title: 'Override the required evidence?', message: conf.text, confirmLabel: 'Record override and land' }))) return
    onAct('override', provenanceActions.recordOverride(c.repo, c.ref, c.id, c.candidate, tip, overrideReason.trim()))
  }
  return (
    <div className="ci-provenance">
      <dl className="ci-facts">
        <div><dt>Mode</dt><dd><strong>{mode.label}</strong> <small className="quiet">{mode.detail}</small></dd></div>
        <div><dt>{c.workflowAuthority === 'tagged-revision' ? 'Workflow revision' : 'Baseline'}</dt><dd><code>{c.baseline || 'none'}</code></dd></div>
        <div><dt>Lock</dt><dd><code>{c.lock || 'none'}</code></dd></div>
        <div><dt>Generation</dt><dd>{c.generation}{c.currentGeneration != null && c.currentGeneration !== c.generation && <small className="field-error"> (policy is at {c.currentGeneration}: this evidence is stale)</small>}</dd></div>
        <div><dt>Sandbox</dt><dd>{c.sandbox === 'vm' ? 'VM (Firecracker)' : 'container compatibility'}{c.harnessDiffers && <small className="quiet"> · the candidate's harness differs from the baseline's (a trial twin runs it)</small>}</dd></div>
        <div><dt>Bindings</dt><dd>{c.workflowAuthority === 'tagged-revision' ? 'captured at tag admission' : c.bindingsCurrent ? 'current' : <span className="field-error">not current</span>} · {c.landable ? 'landable' : 'not landable'}</dd></div>
      </dl>
      {c.workflowProvenance && <div className="ci-input-provenance" data-part="input-provenance"><p>{inputProvenanceText(c.workflowProvenance)}</p>{c.workflowProvenance.inputPolicy?.sources?.map((s) => <p key={s}><code>{s}</code></p>)}{c.workflowProvenance.inputEvidence?.acquisitions?.map((a, i) => <p key={i}><code>{a.url}</code> → <code>{a.resolvedUrl}</code> · SHA-256 <code>{a.sha256}</code> · {a.size} bytes</p>)}</div>}
      {explanation && <div className="empty ci-first-run">{explanation}</div>}
      {waitRows(c).length > 0 && (
        <ul className="ci-waits">
          {waitRows(c).map((w) => <li key={w.key}><code>{w.label}</code> waits: {w.reason}{w.explanation ? <small className="quiet"> — {w.explanation}</small> : null}</li>)}
        </ul>
      )}
      {privileged.length > 0 && c.mode === 'required' && (
        <div className="ci-policy-block">
          <strong>Environment approvals</strong>
          {approvals.map((a) => <div key={a.id}><code>{a.job}</code> → {a.environment} [{a.credentials.join(', ')}] by {a.approver} · <span className={`status ${a.state === 'valid' ? 'good' : a.state === 'consumed' ? 'quiet' : 'bad'}`}>{a.state}</span> <small className="quiet">{a.detail}</small></div>)}
          <div className="three-fields">
            <label><span>Job</span><select value={approval.job} onChange={(e) => { const j = privileged.find((x) => x.id === e.target.value); setApproval({ job: e.target.value, environment: j?.environment || '', credentials: approval.credentials }) }}><option value="">choose</option>{privileged.map((j) => <option key={j.id} value={j.id}>{j.workflow}/{j.id} → {j.environment}</option>)}</select></label>
            <label><span>Credentials to release</span><input value={approval.credentials} onChange={(e) => setApproval({ ...approval, credentials: e.target.value })} placeholder="DEPLOY_KEY" /></label>
            <span className="form-actions"><button className="button" disabled={busy !== '' || !approval.job || !parsePaths(approval.credentials).length} onClick={() => { const j = privileged.find((x) => x.id === approval.job); onAct('approve-env', provenanceActions.approveEnvironment(c.id, j.workflow, j.id, j.environment, parsePaths(approval.credentials))) }}>Approve environment</button></span>
          </div>
        </div>
      )}
      {c.mode === 'required' && c.candidate && c.verdictReason !== 'landed' && (
        <div className="ci-policy-block">
          <strong>Override</strong>
          <small className="quiet">Advances the branch to this exact object without the missing evidence; recorded with your name, the reason and what was missing; the candidate's status stays what it is. Requires the override role for the branch.</small>
          {overrides.map((o) => <div key={o.id}><code>{short(o.oid)}</code> over <code>{short(o.expected)}</code> by {o.actor}: {o.reason} <small className="quiet">missing: {o.missing}</small> · <span className={`status ${o.state === 'valid' ? 'good' : o.state === 'consumed' ? 'quiet' : 'bad'}`}>{o.state}</span> <small className="quiet">{o.detail}</small></div>)}
          <div className="form-actions split"><input value={overrideReason} onChange={(e) => setOverrideReason(e.target.value)} placeholder="reason (recorded)" /><button className="button danger" disabled={busy !== '' || !overrideConfirmation(c, tip, overrideReason).ok} onClick={recordOverride}>Override…</button></div>
        </div>
      )}
    </div>
  )
}
