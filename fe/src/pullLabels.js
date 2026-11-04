// Pull request labels (%urgit state-5): free text the repository owner and
// its writers set, at most 20, each non-empty and at most 64 bytes, as an
// issue's. The ship decides every edit (lib/ci-forge label-edit) and says
// why it refuses. These checks use its limits only to spare a round trip.
// Each label an edit adds or removes is one labeled or unlabeled event,
// which can start CI. Text only.

export const MAX_LABELS = 20
export const MAX_LABEL_BYTES = 64

const encoder = new TextEncoder()
export const labelBytes = (label) => encoder.encode(String(label)).length

// byte order, shorter first: the order Hoon's aor gives cords, which the
// ship lists labels in
export function compareLabels(a, b) {
  const x = encoder.encode(String(a))
  const y = encoder.encode(String(b))
  for (let i = 0; i < Math.min(x.length, y.length); i++) if (x[i] !== y[i]) return x[i] - y[i]
  return x.length - y.length
}

export const sortLabels = (labels) => [...new Set((labels || []).map(String))].sort(compareLabels)

// why one more label cannot join a draft, or ''
export function labelProblem(label, draft = []) {
  const text = String(label)
  if (!text.trim()) return 'A label cannot be empty.'
  const bytes = labelBytes(text)
  if (bytes > MAX_LABEL_BYTES) return `A label is at most ${MAX_LABEL_BYTES} bytes. This one is ${bytes} bytes.`
  if (draft.includes(text)) return `The pull request already has the label ${text}.`
  if (draft.length >= MAX_LABELS) return `A pull request has at most ${MAX_LABELS} labels.`
  return ''
}

// what saving a draft reports, as the ship documents it: each name added
// or removed is one event, in name order, and each lists the labels after it
export function labelEvents(saved, draft) {
  const before = new Set(saved)
  const after = new Set(draft)
  const changed = sortLabels([...saved.filter((l) => !after.has(l)), ...draft.filter((l) => !before.has(l))])
  const current = new Set(saved)
  return changed.map((label) => {
    const added = after.has(label)
    if (added) current.add(label)
    else current.delete(label)
    return { action: added ? 'labeled' : 'unlabeled', label, labels: sortLabels([...current]) }
  })
}

const list = (names) => (names.length < 2 ? names.join('') : `${names.slice(0, -1).join(', ')} and ${names.at(-1)}`)

// a pending edit in one sentence
export function changeSummary(events) {
  const added = events.filter((e) => e.action === 'labeled').map((e) => e.label)
  const removed = events.filter((e) => e.action === 'unlabeled').map((e) => e.label)
  if (added.length && removed.length) return `Saving adds ${list(added)} and removes ${list(removed)}.`
  if (added.length) return `Saving adds ${list(added)}.`
  if (removed.length) return `Saving removes ${list(removed)}.`
  return ''
}

export const eventsNote = 'Each label added or removed is one labeled or unlabeled event, which can start CI.'

// the editor: the labels the ship holds, the draft, the text being typed,
// a local problem, the ship's refusal in its own words, and a save in flight
export const initialLabels = (labels = []) => {
  const saved = sortLabels(labels)
  return { saved, draft: saved, input: '', problem: '', refusal: '', saving: false }
}

const same = (a, b) => a.length === b.length && a.every((v, i) => v === b[i])

export function labelsReducer(state, action) {
  switch (action.type) {
    // the ship's labels again: a draft with no change follows them
    case 'load': {
      const saved = sortLabels(action.labels)
      if (same(saved, state.saved)) return state
      return same(state.draft, state.saved) && !state.saving ? { ...state, saved, draft: saved } : { ...state, saved }
    }
    case 'input': return { ...state, input: String(action.value), problem: '' }
    case 'add': {
      const text = state.input.trim()
      const problem = labelProblem(text, state.draft)
      if (problem) return { ...state, problem }
      return { ...state, draft: sortLabels([...state.draft, text]), input: '', problem: '', refusal: '' }
    }
    case 'remove': return { ...state, draft: state.draft.filter((l) => l !== action.label), problem: '', refusal: '' }
    case 'reset': return { ...state, draft: state.saved, input: '', problem: '', refusal: '' }
    case 'saving': return { ...state, saving: true, refusal: '' }
    case 'saved': return initialLabels(action.labels)
    case 'failed': return { ...state, saving: false, refusal: String(action.message || 'The ship refused the labels.') }
    default: return state
  }
}
