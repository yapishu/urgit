import { useCallback, useEffect, useRef, useState } from 'react'
import { api, ci, publicApi } from '../api'
import { clockOffset, configSnippet, mergeRunnerFact, retentionsText, runnerActions, runnerRow, stateHint, stateLabel } from '../runners'
import { feedPip } from '../ciLive'
import { watchAgent } from '../channel'
import { relativeTime } from '../format'
import { useConfirm } from './ConfirmDialog'
import SetupGuide from './SetupGuide'
import RunnerRecovery from './RunnerRecovery'

// Settings → Runners (BRIEF-CI-P3 D3): the daemon records as a table with
// a state pip, Mint token (the token shown once beside the config lines),
// Expire / Revoke / Remove per row, the repository binding per row, and
// Rotate CI key. Every button is one POST the ship answers 200 or a 409
// with its reason; the table is re-read after each. A runner that withholds
// slots has a Retentions button: its withheld slots, and the release of a
// legacy retention from here (legacy-recovery UI ruling 01). A runner whose
// execution history is incomplete is marked paused, and its button opens the
// same panel on its history and transition (legacy-replay-upgrade ruling 01).

const stateClass = (state) => ({ healthy: 'good', stale: 'warn', refused: 'bad', revoked: 'bad', minted: '' })[state] || ''

function CopyField({ label, value, multiline = false }) {
  const [copied, setCopied] = useState(false)
  const copy = async () => {
    try { await navigator.clipboard.writeText(value); setCopied(true); setTimeout(() => setCopied(false), 1500) } catch { /* the field is selectable */ }
  }
  return (
    <label className="copy-field">
      <span>{label}</span>
      <div className="inline-field">
        {multiline ? <textarea readOnly rows={3} value={value} onFocus={(e) => e.target.select()} /> : <input readOnly value={value} onFocus={(e) => e.target.select()} />}
        <button type="button" className="button" onClick={copy}>{copied ? 'Copied' : 'Copy'}</button>
      </div>
    </label>
  )
}

function RepoPicker({ repositories, value, onChange, disabled }) {
  // value: null (any repository) or an array of names
  const any = value === null
  const chosen = new Set(value || [])
  return (
    <div className="ci-repo-picker">
      <label className="check-row compact"><input type="radio" checked={any} disabled={disabled} onChange={() => onChange(null)} /><span><strong>Any repository</strong><small>The pool: this runner takes every job, including fork pull requests run as restricted checks.</small></span></label>
      <label className="check-row compact"><input type="radio" checked={!any} disabled={disabled} onChange={() => onChange([])} /><span><strong>Only these repositories</strong><small>The ship never hands it a job of any other repository. Set here, never by the daemon.</small></span></label>
      {!any && <div className="ci-repo-list">
        {repositories.map((name) => <label className="check-row compact" key={name}><input type="checkbox" checked={chosen.has(name)} disabled={disabled} onChange={(e) => { const next = new Set(chosen); if (e.target.checked) next.add(name); else next.delete(name); onChange([...next]) }} /><span>{name}</span></label>)}
        {!repositories.length && <small className="quiet">No repositories on this ship yet.</small>}
      </div>}
    </div>
  )
}

function MintModal({ repositories, onClose, onMinted }) {
  const [answer, setAnswer] = useState(null)
  const [error, setError] = useState('')
  const [repos, setRepos] = useState(null)
  const [binding, setBinding] = useState('')
  useEffect(() => {
    let live = true
    ci.mint().then((a) => { if (live) { setAnswer(a); onMinted?.() } }).catch((cause) => { if (live) setError(cause.message) })
    return () => { live = false }
  }, [])
  async function bind() {
    if (!answer) return
    setBinding('saving')
    try { await ci.action(runnerActions.setRepos(answer.id, repos)); setBinding('saved'); onMinted?.() } catch (cause) { setBinding(''); setError(cause.message) }
  }
  return <div className="modal-backdrop" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
    <section className="modal-card" role="dialog" aria-modal="true" aria-label="Enrollment token">
      <header><div><span className="eyebrow">Runners</span><h1>Enrollment token</h1></div><button type="button" className="icon-button" onClick={onClose} aria-label="Close">×</button></header>
      <div className="modal-body ci-mint">
        {error && <small className="field-error">{error}</small>}
        {!answer && !error && <p>Minting…</p>}
        {answer && <>
          <p><strong>Shown once.</strong> The ship keeps only a hash of this token. Copy it now; closing this dialog is the last time it is readable. If you lose it, expire the record and mint another.</p>
          <CopyField label="Token" value={answer.token} />
          <CopyField label="Config lines for urgit-runner.toml" value={configSnippet(answer)} multiline />
          <small className="quiet">Paste the lines into the daemon's config, start it, and this row flips from <em>minted</em> to <em>healthy</em>. The daemon forgets the token after its first start.</small>
          <div className="subsection">
            <div className="section-title"><div><h3>Repositories this runner may take</h3><p>Optional. The default is the pool.</p></div></div>
            <RepoPicker repositories={repositories} value={repos} onChange={setRepos} disabled={binding === 'saving'} />
            <div className="form-actions split"><small className="quiet">{binding === 'saved' ? 'Binding saved.' : ''}</small><button type="button" className="button" disabled={binding === 'saving' || (repos !== null && !repos.length)} onClick={bind}>{binding === 'saving' ? 'Saving…' : 'Save binding'}</button></div>
          </div>
          <div className="form-actions"><button type="button" className="button primary" onClick={onClose}>Done — I copied it</button></div>
        </>}
      </div>
    </section>
  </div>
}

function BindModal({ row, repositories, onClose, onSaved }) {
  const [repos, setRepos] = useState(row.repos)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  async function save() {
    setBusy(true); setError('')
    try { await ci.action(runnerActions.setRepos(row.id, repos)); onSaved(); onClose() } catch (cause) { setError(cause.message) } finally { setBusy(false) }
  }
  return <div className="modal-backdrop" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
    <section className="modal-card" role="dialog" aria-modal="true" aria-label="Repositories">
      <header><div><span className="eyebrow">Runner {row.shortId}</span><h1>Repositories</h1></div><button type="button" className="icon-button" onClick={onClose} aria-label="Close">×</button></header>
      <div className="modal-body">
        <RepoPicker repositories={repositories} value={repos} onChange={setRepos} disabled={busy} />
        {error && <small className="field-error">{error}</small>}
        <div className="form-actions"><button type="button" className="button ghost" onClick={onClose}>Cancel</button><button type="button" className="button primary" disabled={busy || (repos !== null && !repos.length)} onClick={save}>{busy ? 'Saving…' : 'Save'}</button></div>
      </div>
    </section>
  </div>
}

export default function RunnersSection() {
  const confirm = useConfirm()
  const [data, setData] = useState(null)
  const [error, setError] = useState('')
  const [actionError, setActionError] = useState('')
  const [busy, setBusy] = useState('')
  const [minting, setMinting] = useState(false)
  const [binding, setBinding] = useState(null)
  const [guide, setGuide] = useState(false)
  // the runner whose withheld slots are open (legacy-recovery UI ruling 01)
  const [recovering, setRecovering] = useState(null)
  const [repositories, setRepositories] = useState([])
  const [tick, setTick] = useState(0)
  const [status, setStatus] = useState('')
  const offset = useRef(0)
  const load = useCallback(async () => {
    try {
      const answer = await ci.runners()
      offset.current = clockOffset(answer.now)
      setData(answer); setError('')
    } catch (cause) { setError(cause.message) }
  }, [])
  useEffect(() => { load() }, [load])
  // the ship pushes every record change on /ci/runners (P3 D4): a row
  // flips minted → healthy as the daemon enrolls, with no Refresh
  useEffect(() => {
    let channel = null
    let live = true
    ;(async () => {
      let ship = ''
      try { ship = (await publicApi.profile()).ship } catch { return }
      if (!live || !ship) return
      channel = watchAgent({
        ship,
        app: 'urgit-ci',
        path: '/ci/runners',
        onFact: (fact) => {
          if (fact?.kind === 'runners') { offset.current = clockOffset(fact.now); setData(fact); return }
          setData((current) => current ? { ...current, runners: mergeRunnerFact(current.runners, fact) } : current)
        },
        onStatus: setStatus,
      })
    })()
    return () => { live = false; channel?.close() }
  }, [])
  const onGuide = () => setGuide(true)
  useEffect(() => { api.repositories().then((r) => setRepositories((r.repositories || []).map((x) => x.name).sort())).catch(() => {}) }, [])
  // the ages and the pip age on the client's clock between reads
  useEffect(() => { const timer = setInterval(() => setTick((t) => t + 1), 10000); return () => clearInterval(timer) }, [])
  async function act(label, body, question) {
    if (question && !(await confirm(question))) return
    setBusy(label); setActionError('')
    try { await ci.action(body); await load() } catch (cause) { setActionError(cause.message) } finally { setBusy('') }
  }
  const now = Date.now() / 1000 + offset.current
  const rows = (data?.runners || []).map((r) => runnerRow(r, now, data?.staleAfter || 300))
  void tick
  return (
    <div className="subsection ci-runners">
      <div className="section-title"><div><h3>Runners</h3><p>The daemons that run this ship's CI jobs. Mint a token, paste the config lines into <code>urgit-runner.toml</code>, start the daemon. {onGuide && <button type="button" className="text-button" onClick={onGuide}>Setup guide</button>}</p></div><div><button type="button" className="button" disabled={busy !== ''} onClick={() => setMinting(true)}>Mint token</button></div></div>
      {error && <small className="field-error">Runners unavailable: {error}</small>}
      {actionError && <small className="field-error">{actionError}</small>}
      {data && !rows.length && <small className="quiet">No runner yet. Mint a token to enroll one.</small>}
      {rows.length > 0 && <div className="ci-list">
        <div className="table-head ci-runner-row"><span>Runner</span><span>Labels</span><span>Repositories</span><span>Enrolled</span><span>Last seen</span><span>Running</span><span>State</span><span></span></div>
        {rows.map((row) => (
          <div className="ci-runner-row" key={row.id}>
            <span><code title={row.id}>{row.shortId}</code><small className="quiet"> · cap {row.capacity}{row.sandbox ? ` · ${row.sandbox}` : ''}</small></span>
            <span className="quiet" title={row.labels.join(', ')} data-label="Labels">{row.labelsText}</span>
            <span data-label="Repositories" className="ci-runner-repos"><span>{row.reposText}</span>{row.state !== 'revoked' && <button type="button" className="button small" aria-label={`Choose the repositories runner ${row.shortId} may take`} disabled={busy !== ''} onClick={() => setBinding(row)}>Repositories…</button>}</span>
            <span data-label="Enrolled">{row.enrolled ? relativeTime(row.enrolled, now) : '—'}</span>
            <span data-label="Last seen">{row.lastSeen ? relativeTime(row.lastSeen, now) : '—'}</span>
            <span data-label="Running">{row.running}</span>
            <span className={`status ${stateClass(row.state)}`} title={row.refused || stateHint[row.state]}><span className={`ci-pip ${stateClass(row.state)}`} /> {stateLabel[row.state]}{row.refused && <small className="quiet"> · {row.refused}</small>}{row.history?.paused && <small className="status bad" title="What it ran before its execution ledger is not known: it advertises no capacity and runs nothing until its transition is confirmed."> · execution paused</small>}</span>
            <span>
              {row.history?.paused && <button type="button" className="text-button danger-text" title="Inspect its history and confirm its transition" disabled={busy !== ''} onClick={() => setRecovering(row)}>Transition…</button>}
              {row.retentions?.total > 0 && <button type="button" className="text-button" title={retentionsText(row.retentions)} disabled={busy !== ''} onClick={() => setRecovering(row)}>{row.retentions.eligible > 0 ? `Retentions (${row.retentions.total}, ${row.retentions.eligible} releasable)` : `Retentions (${row.retentions.total})`}</button>}
              {row.actions.includes('expire') && <button type="button" className="text-button danger-text" disabled={busy !== ''} onClick={() => act(`expire-${row.id}`, runnerActions.expire(row.id), { title: 'Expire this token?', message: `The minted token for ${row.shortId} stops enrolling anything. A daemon started with it will be refused.`, confirmLabel: 'Expire' })}>{busy === `expire-${row.id}` ? 'Expiring…' : 'Expire'}</button>}
              {row.actions.includes('revoke') && <button type="button" className="text-button danger-text" disabled={busy !== ''} onClick={() => act(`revoke-${row.id}`, runnerActions.revoke(row.id), { title: 'Revoke this runner?', message: `Its next poll is refused and the daemon exits. ${row.running ? `Its ${row.running} running job${row.running === 1 ? '' : 's'} are offered to another runner.` : 'It is running nothing right now.'} To bring it back, mint a new token and re-enroll it.`, confirmLabel: 'Revoke' })}>{busy === `revoke-${row.id}` ? 'Revoking…' : 'Revoke'}</button>}
              {row.actions.includes('remove') && <button type="button" className="text-button" disabled={busy !== ''} onClick={() => act(`remove-${row.id}`, runnerActions.expire(row.id), { title: 'Remove this record?', message: `The revoked record of ${row.shortId} is deleted from the ship.`, confirmLabel: 'Remove', danger: false })}>{busy === `remove-${row.id}` ? 'Removing…' : 'Remove'}</button>}
            </span>
          </div>
        ))}
      </div>}
      <div className="form-actions split">
        <small className="quiet">Labels come from each daemon's <code>labels = […]</code> and match a job's <code>runs-on</code>; every runner also stands for {(data?.implicitLabels || []).join(', ') || 'the implicit set'}.</small>
        <div><span className={`ci-feed ci-feed-${feedPip(status)}`} title="live: the ship pushes every change; polling: Refresh reads it"><span className={`ci-pip ${status === 'open' ? 'good' : 'warn'}`} /> {feedPip(status)}</span> <button type="button" className="text-button" disabled={busy !== ''} onClick={load}>Refresh</button> <button type="button" className="button ghost danger-text" disabled={busy !== ''} onClick={() => act('rotate', runnerActions.rotate(), { title: 'Rotate the CI signing key?', message: 'Every enrolled runner pinned the current key. After the rotation each one refuses its next assignment, is listed here as refused, and takes no work until you re-enroll it with a fresh token (delete its state file first). Jobs already running finish.', confirmLabel: 'Rotate key' })}>{busy === 'rotate' ? 'Rotating…' : 'Rotate CI key'}</button></div>
      </div>
      {minting && <MintModal repositories={repositories} onClose={() => { setMinting(false); load() }} onMinted={load} />}
      {binding && <BindModal row={binding} repositories={repositories} onClose={() => setBinding(null)} onSaved={load} />}
      {guide && <SetupGuide onClose={() => setGuide(false)} />}
      {recovering && <RunnerRecovery runner={recovering} onClose={() => { setRecovering(null); load() }} onChanged={load} />}
    </div>
  )
}
