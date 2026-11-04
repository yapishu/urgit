import { useState } from 'react'
import { addCandidates, filterCandidates, policyRows } from '../branchPolicy'

// one branch policy as a short list of the chosen branches with an Add
// branch picker (see branchPolicy.js). Adding and removing call the same
// ship actions the per-branch checkboxes called; removing asks first.
export default function BranchPolicyList({ part, title, description, chosen, refs, busy, disabled, rowNote, rowMessages, emptyText, removeConfirm, confirm, onAdd, onRemove }) {
  const [adding, setAdding] = useState(false)
  const [query, setQuery] = useState('')
  const rows = policyRows(chosen, refs)
  const candidates = addCandidates(chosen, refs)
  const { shown, more, total } = filterCandidates(candidates, query)
  async function add(ref) {
    setAdding(false); setQuery('')
    await onAdd(ref)
  }
  async function remove(row) {
    if (confirm && !await confirm({ ...removeConfirm(row.label), confirmLabel: 'Remove' })) return
    await onRemove(row.ref)
  }
  return (
    <div className="subsection branch-policy" data-part={part}>
      <div className="section-title"><div><h3>{title}</h3><p>{description}</p></div></div>
      <div className="branch-policy-list">
        {rows.map((row) => (
          <div className="branch-policy-row" key={row.ref} data-part="branch-policy-row">
            <span className="branch-policy-name"><strong>{row.label}</strong>{row.deleted && <small className="status warn">branch deleted</small>}</span>
            <span className="branch-policy-note"><small className="quiet">{rowNote}</small>{(rowMessages?.(row.ref) || []).map((m) => <small key={m.text} className={m.className}>{m.text}</small>)}</span>
            <button type="button" className="button small" disabled={busy || disabled} aria-label={`Remove ${row.label} from ${title.toLowerCase()}`} onClick={() => remove(row)}>Remove</button>
          </div>
        ))}
        {!rows.length && <small className="quiet" data-part="branch-policy-empty">{emptyText}</small>}
      </div>
      {!adding && <div className="form-actions"><button type="button" className="button small" data-part="branch-policy-add" disabled={busy || disabled || !candidates.length} onClick={() => setAdding(true)}>Add branch</button>{!candidates.length && <small className="quiet">{refs?.some((r) => r.name.startsWith('refs/heads/')) ? 'Every branch is already listed.' : 'No branches yet.'}</small>}</div>}
      {adding && (
        <div className="branch-picker" data-part="branch-picker">
          <div className="branch-picker-head">
            <input type="search" autoFocus placeholder={`Filter ${candidates.length} branch${candidates.length === 1 ? '' : 'es'}`} aria-label="Filter branches" value={query} onChange={(e) => setQuery(e.target.value)} />
            <button type="button" className="text-button" onClick={() => { setAdding(false); setQuery('') }}>Cancel</button>
          </div>
          <div className="branch-picker-list" role="listbox" aria-label={`Branches to add to ${title.toLowerCase()}`}>
            {shown.map((c) => <button type="button" role="option" aria-selected="false" className="branch-picker-option" key={c.ref} disabled={busy} onClick={() => add(c.ref)}>{c.label}</button>)}
            {!total && <small className="quiet">No branch matches “{query.trim()}”.</small>}
          </div>
          {more > 0 && <small className="quiet">{more} more not shown: type more of the name to narrow the list.</small>}
        </div>
      )}
    </div>
  )
}
