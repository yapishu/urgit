// The CI tab's live feed (BRIEF-CI-P3 D4): how the facts %urgit-ci gives
// on /ci/repository/<name> fold into the candidate list and the open
// candidate page, and the pip that says whether the tab is live or
// polling. The client replaces rows by id — a patch is the changed
// candidate's full row, never a diff. Nothing here subscribes; CiTab does.

// the first fact carries the list (the same JSON as GET candidates); every
// later one carries one candidate's row; runner facts ride the same path
// so the tab knows whether any runner is enrolled (D7)
export function mergeCandidateFact(rows, fact) {
  const list = Array.isArray(rows) ? rows : []
  if (!fact || typeof fact !== 'object') return list
  if (fact.kind === 'candidates' && Array.isArray(fact.candidates)) return fact.candidates
  if (fact.kind === 'candidate' && fact.patch && fact.patch.id) {
    const at = list.findIndex((c) => c.id === fact.patch.id)
    if (at < 0) return [fact.patch, ...list]
    return list.map((c, i) => (i === at ? fact.patch : c))
  }
  return list
}

// the open candidate page reads {candidate, attempts}; a fact for its id
// refreshes both from the patch (the row carries the attempt summaries)
export function applyCandidateFactToPage(page, fact) {
  if (!page || !fact || fact.kind !== 'candidate' || !fact.patch) return page
  if (fact.patch.id !== page.candidate?.id) return page
  return { ...page, candidate: fact.patch, attempts: Array.isArray(fact.patch.attempts) ? fact.patch.attempts : page.attempts }
}

// the runner count the tab shows the first-run message on (D7): from the
// initial fact's runners, then every runner fact
export function mergeRunnerCount(runners, fact) {
  const list = Array.isArray(runners) ? runners : []
  if (!fact || typeof fact !== 'object') return list
  if (fact.kind === 'candidates' && Array.isArray(fact.runners)) return fact.runners
  if (fact.kind === 'runners' && Array.isArray(fact.runners)) return fact.runners
  if (fact.kind === 'runner-gone') return list.filter((r) => r.id !== fact.id)
  if (fact.kind === 'runner' && fact.patch && fact.patch.id) {
    const at = list.findIndex((r) => r.id === fact.patch.id)
    if (at < 0) return [fact.patch, ...list]
    return list.map((r, i) => (i === at ? fact.patch : r))
  }
  return list
}

// live while the channel is open; polling while it is down (Refresh and
// the timer carry the tab); connecting before the first status
export const feedPip = (status) => (status === 'open' ? 'live' : status === 'closed' ? 'polling' : 'connecting')
