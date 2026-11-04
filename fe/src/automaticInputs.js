// Exact input grammar: kept deliberately narrow and shared with ci-input.hoon
// and inputpolicy.URL. These checks improve feedback; the controller and runner
// independently validate authority and spelling.
export function inputURLProblem(value) {
  if (typeof value !== 'string' || value.length > 512 || !/^https:\/\/[a-z0-9.-]+\/[A-Za-z0-9/_.~-]*$/.test(value)) return 'Use an exact https://DNS-host/path URL without credentials, ports, queries, fragments or escapes.'
  const host = value.slice(8).split('/')[0]
  const labels = host.split('.')
  if (host.length > 253 || labels.length < 2 || !/^[a-z]/.test(labels.at(-1)) || labels.some((s) => !/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(s))) return 'Use a lower-case DNS host with at least two labels; IP literals and wildcard hosts are refused.'
  const path = value.slice(8 + host.length)
  if (path.includes('//') || path.split('/').some((s) => s === '.' || s === '..')) return 'Remove repeated slashes and dot path segments.'
  return ''
}
export function inputEdit(repo, policy, sources) {
  if (!policy?.canEditAutomaticInputs) throw new Error('CI policy permission is required to edit automatic inputs.')
  if (!Number.isSafeInteger(policy.generation) || policy.generation < 0) throw new Error('Reload the policy before editing.')
  if (sources.length > 16 || new Set(sources).size !== sources.length) throw new Error('Choose at most 16 distinct exact URLs.')
  for (const url of sources) { const problem = inputURLProblem(url); if (problem) throw new Error(problem) }
  return { action: 'set-automatic-inputs', repo, generation: policy.generation, sources: [...sources].sort() }
}
export function inputSupport(policy, url) {
  const runners = policy?.automaticResolvers || []
  const capable = runners.filter((r) => r.live && r.reported && (r.sources || []).includes(url))
  if (capable.length) return `Within the reported ceiling of ${capable.map((r) => r.name).join(', ')}. DNS, redirects and transport are checked when fetched.`
  return 'No live resolver reports this URL in its owner ceiling. Saving repository permission alone does not make it usable.'
}
export function inputProvenanceText(provenance) {
  if (!provenance) return ''
  const evidence = provenance.inputEvidence
  const origin = provenance.acquisition || 'Prior resolution; no new automatic fetch is implied.'
  return `${origin}. Admitted policy ${(provenance.inputPolicyRecorded === false ? '' : provenance.inputPolicyId) || 'unrecorded (no new authority)'}. ${evidence ? `Resolution policy ${evidence.policyId}; runner ceiling ${evidence.ceilingId}.` : 'Prior import or resolution: no automatic acquisition evidence recorded.'}`
}
