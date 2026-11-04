// The CI policy and provenance surface's pure helpers (BRIEF-CI-P4 S5):
// the action bodies the settings and candidate controls post, the lock
// diff, the required/trial/shadow distinction, the wait explanations a
// pending candidate shows, the approval and override rows with their
// fifteen-minute clocks, the override confirmation text, the audit
// rows, and the mapping text parser. Nothing here fetches or renders
// markup: every displayed string is data the components print as text,
// so hostile metadata (a license line, a notice, a reason) stays text.

export const provenanceActions = {
  resolve: (repo, revision, mappings = []) => ({ action: 'resolve-dependencies', repo, revision, ...(mappings.length ? { mappings } : {}) }),
  promote: (repo, ref, revision, reason, lock) => ({ action: 'promote-baseline', repo, ref, revision, reason, ...(lock ? { lock } : {}) }),
  revoke: (repo, ref, reason) => ({ action: 'revoke-baseline', repo, ref, reason }),
  setHarnessPaths: (repo, paths) => ({ action: 'set-harness-paths', repo, paths }),
  setSandbox: (repo, need) => ({ action: 'set-sandbox-requirement', repo, need }),
  setRole: (repo, role, ships, scope) => ({ action: 'set-role', repo, role, ships, ...(scope ? { scope } : {}) }),
  clearRole: (repo, role, scope) => ({ action: 'clear-role', repo, role, ...(scope ? { scope } : {}) }),
  setEnvironment: (repo, name, automation, credentials, description = '') => ({ action: 'set-environment', repo, name, automation, credentials, description }),
  deleteEnvironment: (repo, name) => ({ action: 'delete-environment', repo, name }),
  approveEnvironment: (id, workflow, job, environment, credentials) => ({ action: 'approve-environment', id, workflow, job, environment, credentials }),
  recordOverride: (repo, ref, id, oid, expected, reason) => ({ action: 'record-override', repo, ref, id, oid, expected, reason }),
  setNetworkPolicy: (repo, workflow, job, profile, destinations, environment) => ({ action: 'set-network-policy', repo, workflow, job, profile, destinations, ...(environment ? { environment } : {}) }),
  clearNetworkPolicy: (repo, workflow, job) => ({ action: 'clear-network-policy', repo, workflow, job }),
  stageShadow: (repo, ref, head, base, event, external = '') => ({ action: 'stage-shadow', repo, ref, head, base, event, external }),
  compareShadow: (shadow, oid, event, verdict, jobs) => ({ action: 'compare-shadow', shadow, oid, event, verdict, jobs }),
  cancelAttempt: (id, reason) => ({ action: 'cancel-attempt', id, reason }),
}

export const isOid = (s) => /^[0-9a-f]{40}$/.test(String(s || ''))
export const isDigest = (s) => /^[0-9a-f]{64}$/.test(String(s || ''))

// the one immutable identity a lock node carries, by kind
export function nodeIdentity(node = {}) {
  switch (node.kind) {
    case 'js': case 'composite': case 'local': return node.commit ? `${node.commit}${node.tree ? ` tree ${node.tree}` : ''}` : (node.kind === 'local' ? 'in the candidate tree' : '')
    case 'container': return node.digest || ''
    case 'download': return node.sha256 ? `sha256 ${node.sha256}${node.size ? ` (${node.size} bytes)` : ''}` : ''
    default: return ''
  }
}

// the diff of two locks by `uses`: what an explicit update changed. a
// node's identity is its commit/digest/sha256; a changed mirror alone
// is not a change of what runs, and is reported apart
export function lockDiff(before = {}, after = {}) {
  const key = (n) => `${n.kind}:${n.uses}${n.subpath ? `/${n.subpath}` : ''}`
  const a = new Map((before.nodes || []).map((n) => [key(n), n]))
  const b = new Map((after.nodes || []).map((n) => [key(n), n]))
  const added = [], removed = [], changed = [], remirrored = []
  for (const [k, n] of b) {
    if (!a.has(k)) { added.push(n); continue }
    const o = a.get(k)
    if (nodeIdentity(o) !== nodeIdentity(n)) changed.push({ uses: n.uses, kind: n.kind, from: nodeIdentity(o), to: nodeIdentity(n) })
    else if ((o.mirror || '') !== (n.mirror || '') || (o['mirror-commit'] || '') !== (n['mirror-commit'] || '')) remirrored.push(n.uses)
  }
  for (const [k, n] of a) if (!b.has(k)) removed.push(n)
  return { added, removed, changed, remirrored, same: !added.length && !removed.length && !changed.length }
}

// required / trial / shadow: what the run means for landing
export function modeLabel(candidate = {}) {
  switch (candidate.mode) {
    case 'trial': return { label: 'trial', detail: `Runs the candidate's own harness, unprivileged, always in the VM; its evidence never lands and never replaces required evidence${candidate.trialOf ? ` (a twin of ${candidate.trialOf})` : ''}.` }
    case 'shadow': return { label: 'shadow', detail: 'A comparison run for an external event; it never lands and never deploys.' }
    case 'event':
      if (candidate.workflowAuthority === 'tagged-revision') return { label: 'tag run', detail: 'Runs the workflows stored in the tagged revision. This advisory run never lands, never satisfies protected required checks and receives no credentials.' }
      return { label: 'event', detail: `An automatic run for a push, a pull request activity or a schedule, admitted from the trigger definitions of the promoted baseline${candidate.baseline ? ` (${String(candidate.baseline).slice(0, 12)})` : ''}; it never lands, never satisfies the required checks and receives no credentials.` }
    case 'manual': return { label: 'manual', detail: `Runs the promoted baseline's workflow${candidate.baseline ? ` (${String(candidate.baseline).slice(0, 12)})` : ''} on this branch's tip because an operator dispatched it, with the inputs shown; it never lands, never satisfies the required checks and receives no credentials.` }
    default: return { label: 'required', detail: candidate.baseline ? `Runs the promoted baseline's harness (${String(candidate.baseline).slice(0, 12)}) against this exact checkout under policy generation ${candidate.generation ?? '?'}.` : 'Required checks come from a promoted baseline; none is promoted for this branch yet.' }
  }
}

// what a waiting candidate needs, from the reason the ship recorded
// the per-job waits of a pending candidate (the ship's `waits`: admission
// first, then the runner that would take the job), each with its
// explanation; nothing for a candidate that is not pending
export function waitRows(candidate = {}) {
  if (candidate.status !== 'pending') return []
  return (candidate.waits || []).map((w) => ({
    key: `${w.workflow}/${w.job}`,
    label: `${w.workflow} · ${w.job}`,
    reason: String(w.reason || ''),
    explanation: waitExplanation(w.reason),
  }))
}

export function waitExplanation(reason = '') {
  const r = String(reason)
  if (!r) return ''
  if (/runner owner automatic input ceiling/.test(r)) return 'The repository permission exceeds this runner’s owner-configured automatic_inputs ceiling. A job network profile cannot widen it.'
  if (/automatic Git\/action and registry\/image acquisition is unsupported/.test(r)) return 'Automatic Git/action and registry acquisition cannot yet enforce the input boundary. This transport is refused before external acquisition; HTTPS downloads are supported.'
  if (/automatic input (DNS|redirect|.*requires)/.test(r)) return 'The automatic input boundary refused this address or redirect. Every input and redirect needs an exact public HTTPS permission and runner ceiling.'
  if (/automatic tag resolution has no external-input policy/.test(r)) return 'Automatic dependency fetching has no approved input policy. This dependency was refused without fetching; the captured source revision is unchanged. A job network profile does not authorize resolver fetches.'
  if (/^pending:.*tagged revision.*re-offered/.test(r)) return 'Resolution is waiting for another eligible resolver. It will resume automatically at the same captured revision; the previous attempt cannot complete this run.'
  if (/^pending:.*tagged revision/.test(r)) return 'Dependency resolution resumes automatically on a resolver-capable runner, using the same revision captured at admission. See Settings → Runners.'
  if (/^refused: tagged revision resolution:/.test(r)) return 'Resolution failed. This run keeps its original source and cannot switch to another revision. Read the resolver attempt and its refusal.'
  if (/no promoted baseline/.test(r)) return 'Promote a harness revision for this branch in Settings → CI policy; the candidate\'s own YAML is not evidence.'
  if (/sandbox requirement vm/.test(r)) return 'This work needs a VM runner (Firecracker); the container compatibility profile never runs privileged, trial, shadow or untrusted work. Enroll a microvm runner.'
  if (/no runner supports network profile/.test(r)) return 'The job\'s network policy names a profile no enrolled runner declares; enroll a runner with that profile or change the policy.'
  if (/needs an approval/.test(r)) return 'A privileged job waits for an environment approval (fifteen minutes, single use) or an automation rule on the environment.'
  if (/is not defined/.test(r)) return 'The job names an environment the repository has no record of; define it in Settings → CI policy.'
  if (/unresolved dependency|lock refused|is not mirrored|does not hold commit|no mirror/.test(r)) return 'A dependency is missing or refused: resolve the revision\'s dependencies (Settings → CI policy → Resolve) and read the lock\'s refusals.'
  if (/policy generation/.test(r)) return 'The policy changed under this candidate; its evidence was reset and it runs again under the new generation.'
  if (/tip|destination moved/.test(r)) return 'The branch moved since this candidate was staged; rebase and push again.'
  if (/no runner/.test(r)) return 'No enrolled runner can take this work; see Settings → Runners.'
  return ''
}

// an approval or override row with its fifteen-minute clock
export function grantState(record = {}, nowSeconds = Date.now() / 1000) {
  if (record.consumed) return { state: 'consumed', detail: typeof record.consumed === 'string' ? `used by attempt ${record.consumed}` : 'used' }
  if (record.invalidated) return { state: 'invalidated', detail: String(record.invalidated) }
  const left = Math.floor(Number(record.expires || 0) - nowSeconds)
  if (left <= 0) return { state: 'expired', detail: 'expired (fifteen minutes)' }
  return { state: 'valid', detail: `${Math.floor(left / 60)}m ${left % 60}s left` }
}

export function approvalRows(approvals = [], nowSeconds = Date.now() / 1000) {
  return approvals.map((a) => ({ id: a.id, job: `${a.workflow}/${a.job}`, environment: a.environment, credentials: a.credentials || [], approver: a.approver, generation: a.generation, ...grantState(a, nowSeconds) }))
}

export function overrideRows(overrides = [], nowSeconds = Date.now() / 1000) {
  return overrides.map((o) => ({ id: o.id, oid: o.oid, expected: o.expected, actor: o.actor, reason: o.reason, missing: o.missing, generation: o.generation, ...grantState(o, nowSeconds) }))
}

// the override confirmation: the exact object, the tip it replaces, the
// evidence that is missing, and what the record will say
export function overrideConfirmation(candidate = {}, tip = '', reason = '') {
  const missing = candidate.status === 'passed' ? (candidate.bindingsCurrent === false ? 'bindings not current' : 'nothing (a landing refused for another reason)') : `status ${candidate.status}${candidate.verdictReason ? ` (${candidate.verdictReason})` : ''}`
  return {
    ok: Boolean(isOid(candidate.candidate) && isOid(tip) && String(reason).trim()),
    object: candidate.candidate || '',
    expected: tip,
    missing,
    text: `Advance ${candidate.ref || '?'} from ${String(tip).slice(0, 12)} to ${String(candidate.candidate || '').slice(0, 12)} by override. Missing evidence: ${missing}. The record will name you, this reason and the missing evidence; the candidate's status does not change. The override is single-use and expires in fifteen minutes.`,
  }
}

export function auditRows(entries = []) {
  return entries.map((e) => ({ at: e.at, actor: e.actor, kind: e.kind, detail: String(e.detail || '') }))
}

// mappings as text, one per line: `from -> to`; the target is http(s)
export function parseMappings(text = '') {
  const lines = String(text).split('\n').map((l) => l.trim()).filter(Boolean)
  const mappings = []
  for (const line of lines) {
    const m = line.match(/^(\S+)\s*->\s*(\S+)$/)
    if (!m || !/^https?:\/\//.test(m[2])) return { error: `Not a mapping: "${line}" (write "from -> http(s)://to")`, mappings: [] }
    mappings.push({ from: m[1], to: m[2] })
  }
  return { error: '', mappings }
}

export const parseShips = (text) => String(text || '').split(/[\s,]+/).map((s) => s.trim()).filter(Boolean).map((s) => (s.startsWith('~') ? s : `~${s}`))

export const parsePaths = (text) => String(text || '').split(/[\s,]+/).map((s) => s.trim()).filter(Boolean)

// a refusal as the ship words it (409 carries the ~| message), or the
// transport's own error
export const refusalMessage = (cause) => {
  const text = String(cause?.message || cause || '')
  return /^\d{3}\b/.test(text) ? text.replace(/^\d{3}\s*/, '') : text
}

// the backend table of README §6, as data: the same rows the settings
// page prints so the two never disagree
export const backendTable = [
  { backend: 'microvm (Firecracker + jailer)', boundary: 'VM', required: 'default; every privileged, trial, shadow and untrusted job', network: 'locked by default; profiles enforced per destination by the launcher', note: 'the product path' },
  { backend: 'docker-rootless', boundary: 'container (not a VM boundary)', required: 'only a repository opted in by set-sandbox-requirement container', network: 'locked = an --internal bridge; a profile = NAT egress whole (destinations are not narrowed)', note: 'explicit trusted compatibility; never selected for VM-required work' },
]
