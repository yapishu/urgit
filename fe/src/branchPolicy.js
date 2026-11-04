// Branch policy lists (hands-on review, 2026-10-19): Settings listed one
// row per branch with two checkboxes, so a repository with 160 branches
// showed 160 rows. Protected and CI-required branches are now two short
// lists of the chosen branches, each with an Add branch picker. This module
// is the pure model the component renders.

export const branchLabel = (ref) => String(ref).replace(/^refs\/heads\//, '')

// the chosen refs as rows, sorted by name; a chosen ref whose branch no
// longer exists stays listed (a leftover rule must not hide) and says so
export function policyRows(chosen = [], refs = []) {
  const live = new Set((refs || []).map((r) => r.name))
  return [...new Set(chosen || [])]
    .filter((ref) => String(ref).startsWith('refs/heads/'))
    .sort((a, b) => branchLabel(a).localeCompare(branchLabel(b)))
    .map((ref) => ({ ref, label: branchLabel(ref), deleted: !live.has(ref) }))
}

// the branches that can still be added: every branch not already chosen
export function addCandidates(chosen = [], refs = []) {
  const taken = new Set(chosen || [])
  return (refs || [])
    .filter((r) => r.name.startsWith('refs/heads/') && !taken.has(r.name))
    .map((r) => ({ ref: r.name, label: branchLabel(r.name) }))
    .sort((a, b) => a.label.localeCompare(b.label))
}

// the picker's matches for a filter: case-insensitive substring, at most
// `limit` shown, with the count left out so the picker can say so
export function filterCandidates(candidates = [], query = '', limit = 50) {
  const q = String(query).trim().toLowerCase()
  const matches = q ? candidates.filter((c) => c.label.toLowerCase().includes(q)) : candidates
  return { shown: matches.slice(0, limit), more: Math.max(0, matches.length - limit), total: matches.length }
}
