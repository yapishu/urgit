import { useCallback, useEffect, useMemo, useState } from 'react'
import { api, ci, waitForPeerBrowse, waitForPeerTransfer } from '../api'
import CiTab, { useStorageProbe } from './CiTab'
import { CiPolicySection } from './CiProvenance'
import RunnersSection from './Runners'
import BranchPolicyList from './BranchPolicyList'
import { probeMessage } from '../storageProbe'
import { ciActions, credentialFormError, parseEnvs, stagedEditNote, stagedPublishNote } from '../ci'
import { exactBytes, formatBytes } from '../format'
import { comparisonPatch } from '../patch'
import FileTree from './FileTree'
import { useConfirm } from './ConfirmDialog'
import { HighlightedCode, HighlightedEditor } from './HighlightedCode'
import { CopyIcon } from './Icons'
import PullLabels from './PullLabels'
import Readme from './Readme'
import MarkdownDocument from './MarkdownDocument'
import { clearLocalDraft, readLocalDraft, saveLocalDraft, useLocalDraft } from '../useLocalDraft'
import { describeGroup, describeHost, describeRole, findGroup, policyFlag, roleOptions } from '../groupPolicy'

const shortOid = (oid) => oid ? oid.slice(0, 8) : '—'
const pullRefLabel = (ref, oid) => `${ref ? ref.replace('refs/heads/', '') : 'unknown branch'} · ${shortOid(oid)}`
const historyId = (commit) => commit?.kind === 'clay' ? `r${commit.revision}` : shortOid(commit?.oid)
const identityLabel = (identity) => identity?.name || identity?.email || 'Unknown author'
const commitDate = (identity) => {
  const value = Number(identity?.timestamp) * 1000
  return Number.isFinite(value) && value > 0 ? new Date(value) : null
}
const dateLabel = (identity) => commitDate(identity)?.toLocaleString() || ''
const githubDate = (value) => {
  const date = value ? new Date(value) : null
  return date && Number.isFinite(date.getTime()) ? date.toLocaleString() : ''
}

const notificationEvents = [
  ['issue', 'New issues', 'An issue is opened from another ship.'],
  ['issue-comment', 'Issue comments', 'Another ship comments on a native issue.'],
  ['pull-request', 'New pull requests', 'A native pull request arrives from another ship.'],
  ['pull-comment', 'Pull request comments', 'Another ship comments on a native pull request.'],
]

const groupCapabilities = ['none', 'read', 'write']
const capabilityLabels = { none: 'No access', read: 'Read', write: 'Write (implies read)' }
const groupRoleRows = (policy) => Object.entries(policy?.roles || {}).map(([role, capability]) => ({ role, capability }))

function CopyableHash({ value }) {
  return <span className="tako-chip"><code title={value}>{value}</code><button type="button" className="hash-copy" title="Copy revision hash" aria-label="Copy revision hash" onClick={() => navigator.clipboard.writeText(value)}><CopyIcon /></button></span>
}
const validTabs = new Set(['code', 'issues', 'pulls', 'branches', 'tags', 'releases', 'commits', 'ci', 'webhooks', 'settings'])

function parseLineRange(value) {
  const match = /^(\d+)(?:-(\d+))?$/.exec(value || '')
  if (!match) return { lineStart: null, lineEnd: null }
  const first = Number(match[1])
  const second = Number(match[2] || match[1])
  if (first < 1 || second < 1) return { lineStart: null, lineEnd: null }
  return { lineStart: Math.min(first, second), lineEnd: Math.max(first, second) }
}

function routeForRepository(repo) {
  const [rawPath, rawQuery = ''] = location.hash.replace(/^#\/?/, '').split('?')
  let name = ''
  try { name = decodeURIComponent(rawPath) } catch { /* malformed hash */ }
  const params = new URLSearchParams(rawQuery)
  const tab = validTabs.has(params.get('tab')) ? params.get('tab') : 'code'
  const lines = name === repo.name && tab === 'code' && params.get('file') ? parseLineRange(params.get('line')) : { lineStart: null, lineEnd: null }
  return {
    tab,
    branch: name === repo.name && params.get('branch') ? params.get('branch') : repo.head,
    filePath: name === repo.name && tab === 'code' ? params.get('file') || '' : '',
    searchQuery: name === repo.name && tab === 'code' ? params.get('search') || '' : '',
    ...lines,
    commitOid: name === repo.name && tab === 'commits' ? params.get('commit') || '' : '',
    branchCreate: name === repo.name && tab === 'branches' && params.get('new') === 'branch',
    tagTarget: name === repo.name && tab === 'tags' ? params.get('target') || '' : '',
    tagKind: name === repo.name && tab === 'tags' ? params.get('targetKind') || '' : '',
    // a native pull request opened by number (the CI tab links to it)
    pull: name === repo.name && tab === 'pulls' ? Number(params.get('pull')) || 0 : 0,
  }
}

function repositoryHash(repo, route) {
  const params = new URLSearchParams()
  if (route.tab !== 'code') params.set('tab', route.tab)
  if (route.branch && route.branch !== repo.head) params.set('branch', route.branch)
  if (route.filePath) params.set('file', route.filePath)
  if (route.searchQuery) params.set('search', route.searchQuery)
  if (route.filePath && route.lineStart) params.set('line', route.lineEnd && route.lineEnd !== route.lineStart ? `${route.lineStart}-${route.lineEnd}` : String(route.lineStart))
  if (route.commitOid) params.set('commit', route.commitOid)
  if (route.tab === 'branches' && route.branchCreate) params.set('new', 'branch')
  if (route.tab === 'tags' && route.tagTarget) params.set('target', route.tagTarget)
  if (route.tab === 'tags' && route.tagKind) params.set('targetKind', route.tagKind)
  if (route.tab === 'pulls' && route.pull) params.set('pull', String(route.pull))
  const query = params.toString()
  return `#/${encodeURIComponent(repo.name)}${query ? `?${query}` : ''}`
}

const decodeBase64 = (content) => {
  const raw = atob(content)
  const bytes = Uint8Array.from(raw, (char) => char.charCodeAt(0))
  let text = null
  try { text = new TextDecoder('utf-8', { fatal: true }).decode(bytes) } catch { /* binary */ }
  return { bytes, text }
}

const encodeBase64 = (text) => {
  const bytes = new TextEncoder().encode(text)
  let raw = ''
  for (let offset = 0; offset < bytes.length; offset += 0x8000) {
    raw += String.fromCharCode(...bytes.subarray(offset, offset + 0x8000))
  }
  return btoa(raw)
}

async function syncGithubMetadata(repository, kind, page) {
  const before = await api.githubStatus()
  const prior = new Set((before.jobs || []).map((job) => job.job))
  await api.githubMetadata(repository, kind, page)
  for (let attempt = 0; attempt < 120; attempt += 1) {
    await new Promise((resolve) => setTimeout(resolve, 500))
    const status = await api.githubStatus()
    const matching = (status.jobs || []).filter((job) => !prior.has(job.job) && job.repository === repository && job.kind === kind)
    if (!matching.length || matching.some((job) => job.active)) continue
    const failed = matching.find((job) => !job.ok)
    if (failed) throw new Error(failed.message)
    return matching[0]
  }
  throw new Error('GitHub metadata sync did not finish in time')
}

const githubReceivedCount = (job) => {
  const match = /· (\d+) received$/.exec(job?.message || '')
  return match ? Number(match[1]) : null
}

const imageType = (path) => {
  const leaf = path.split('/').filter(Boolean).pop() || ''
  const extension = (leaf.includes('.') ? leaf.split('.').pop() : leaf).toLowerCase()
  return ({ png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', gif: 'image/gif', webp: 'image/webp', svg: 'image/svg+xml' })[extension]
}

function Files({ data, commit, loading, onOpen, onOpenCommit, loadFile }) {
  if (loading) return <div className="empty">Loading tree…</div>
  if (!data?.files?.length) return <div className="empty">This repository has no files yet.</div>
  const header = commit ? <div className="latest-commit"><span className="commit-avatar">{identityLabel(commit.author).slice(0, 1).toUpperCase()}</span><span><strong>{commit.subject || 'Untitled commit'}</strong><small>{identityLabel(commit.author)}{dateLabel(commit.committer) ? ` · ${dateLabel(commit.committer)}` : ''}</small></span><button className="commit-hash" title={`View ${commit.kind === 'clay' ? `revision ${commit.revision}` : commit.oid}`} onClick={() => onOpenCommit?.(commit)} disabled={!onOpenCommit}><code>{historyId(commit)}</code></button></div> : null
  return <><FileTree files={data.files} header={header} onOpen={onOpen} onOpenCommit={onOpenCommit} />{loadFile && <Readme files={data.files} loadFile={loadFile} onOpen={onOpen} />}</>
}

function SearchResults({ data, query, loading, error, onOpen }) {
  if (loading) return <div className="empty">Searching repository…</div>
  if (error) return <div className="inline-error">{error}</div>
  if (!data) return null
  if (!data.results?.length) return <div className="empty">No matches for <code>{query}</code> on this branch.</div>
  return <div className="code-search-results">
    <div className="search-summary"><span><b>{data.matchCount}</b> matches in {data.filesScanned} files</span>{data.truncated && <span>Showing the first 100 matches</span>}</div>
    {data.results.map((result, index) => {
      const hit = result.preview.indexOf(query)
      return <button key={`${result.path}-${result.line}-${index}`} className="code-search-result" onClick={() => onOpen(result)}>
        <span><strong>{result.path}</strong><small>Line {result.line}, column {result.column}</small></span>
        <code>{hit < 0 ? result.preview : <>{result.preview.slice(0, hit)}<mark>{result.preview.slice(hit, hit + query.length)}</mark>{result.preview.slice(hit + query.length)}</>}</code>
      </button>
    })}
  </div>
}

function FileView({ repository, path, branch, githubOrigin, lineStart, lineEnd, onSelectLine, onOpenCommit, editable, onBack, onSaved, onDeleted, client = api }) {
  const confirmAction = useConfirm()
  const [file, setFile] = useState(null)
  const [history, setHistory] = useState(null)
  const [view, setView] = useState('file')
  const [text, setText] = useState('')
  const [original, setOriginal] = useState('')
  const [message, setMessage] = useState(() => readLocalDraft(`file:${repository}:${branch}:${path}:message`, `Edit ${path}`))
  const [editing, setEditing] = useState(false)
  const [busy, setBusy] = useState(true)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [revision, setRevision] = useState(branch)
  const [upstream, setUpstream] = useState(null)
  const [upstreamBusy, setUpstreamBusy] = useState(false)
  const [blame, setBlame] = useState(null)
  const [blameBusy, setBlameBusy] = useState(false)
  const contentDraftKey = `file:${repository}:${branch}:${path}:content`
  const messageDraftKey = `file:${repository}:${branch}:${path}:message`

  useEffect(() => { setRevision(branch); setHistory(null); setUpstream(null); setView('file'); setNotice('') }, [branch, path])
  useEffect(() => { setMessage(readLocalDraft(messageDraftKey, `Edit ${path}`)); setEditing(false) }, [messageDraftKey, path])
  useEffect(() => { setBlame(null) }, [revision, path])

  useEffect(() => {
    let active = true
    setBusy(true)
    setError('')
    client.file(repository, path, revision).then((data) => {
      if (!active) return
      const decoded = decodeBase64(data.content)
      setFile({ ...data, ...decoded })
      setText(readLocalDraft(contentDraftKey, decoded.text ?? ''))
      setOriginal(decoded.text ?? '')
    }).catch((cause) => active && setError(cause.message)).finally(() => active && setBusy(false))
    return () => { active = false }
  }, [repository, path, revision, client, contentDraftKey])

  useEffect(() => {
    if (view !== 'history' || history) return
    client.fileHistory(repository, path, branch).then(setHistory).catch((cause) => setError(cause.message))
  }, [view, history, repository, path, branch, client])

  async function save() {
    setBusy(true)
    setError('')
    setNotice('')
    try {
      const answer = await api.saveFile(repository, path, encodeBase64(text), message.trim(), branch)
      // a CI-protected branch stages the edit and keeps its tip (Q4)
      const staged = stagedEditNote(answer, branch, 'This edit')
      if (staged) setText(original)
      else setOriginal(text)
      setNotice(staged)
      clearLocalDraft(contentDraftKey); clearLocalDraft(messageDraftKey)
      setEditing(false)
      await onSaved()
    } catch (cause) {
      setError(cause.message)
    } finally {
      setBusy(false)
    }
  }

  async function remove() {
    if (!await confirmAction({ title: 'Delete file?', message: path, detail: 'This creates a commit that removes the file from the selected branch.', confirmLabel: 'Delete file' })) return
    setBusy(true)
    setError('')
    setNotice('')
    try {
      const answer = await api.deleteFile(repository, path, `Delete ${path}`, branch)
      // a CI-protected branch stages the deletion; the file is still there (Q4)
      const staged = stagedEditNote(answer, branch, 'This deletion')
      if (staged) { setNotice(staged); setBusy(false); await onSaved(); return }
      await onDeleted()
    } catch (cause) {
      setError(cause.message)
      setBusy(false)
    }
  }

  async function showUpstream() {
    if (view === 'upstream') { setView('file'); return }
    setView('upstream')
    if (upstream) return
    setUpstreamBusy(true)
    setError('')
    try {
      const ref = branch.replace(/^refs\/heads\//, '')
      const data = await api.githubFile(repository, path, ref)
      setUpstream({ ...data, ...decodeBase64(data.content) })
    } catch (cause) { setError(cause.message) } finally { setUpstreamBusy(false) }
  }

  async function showBlame() {
    if (view === 'blame') { setView('file'); return }
    setView('blame')
    if (blame?.head === revision) return
    setBlameBusy(true)
    setError('')
    try {
      setBlame(await client.fileBlame(repository, path, revision))
    } catch (cause) { setError(cause.message) } finally { setBlameBusy(false) }
  }

  const blamedLines = useMemo(() => blame?.lines?.map((line) => blame.sources?.[line.source]) || null, [blame])

  const mime = imageType(path)
  const objectUrl = file && mime ? `data:${mime};base64,${file.content}` : null
  const downloadUrl = file ? `data:application/octet-stream;base64,${file.content}` : null

  return (
    <div className="file-view">
      <div className="file-toolbar">
        <button className="text-button file-back" onClick={onBack}>← Files</button>
        <code>{path} · {revision === branch ? branch.replace('refs/heads/', '') : shortOid(revision)}</code>
        <div className="file-actions">
          {downloadUrl && <a className="button link-button" href={downloadUrl} download={path.split('/').pop()}>Download</a>}
          {githubOrigin && revision === branch && !editing && <button className={view === 'upstream' ? 'button active' : 'button'} onClick={showUpstream}>{view === 'upstream' ? 'Local file' : 'Upstream'}</button>}
          {file?.text !== null && !editing && <button className={view === 'blame' ? 'button active' : 'button'} onClick={showBlame}>{view === 'blame' ? 'View file' : 'Blame'}</button>}
          <button className={view === 'history' ? 'button active' : 'button'} onClick={() => setView(view === 'history' ? 'file' : 'history')}>{view === 'history' ? 'View file' : 'History'}</button>
          {revision !== branch && <button className="button" onClick={() => { setRevision(branch); setView('file') }}>Latest</button>}
          {editable && revision === branch && file && file.text !== null && !editing && view === 'file' && <button className="button" onClick={() => setEditing(true)}>Edit</button>}
          {editable && revision === branch && file && !editing && view === 'file' && <button className="button danger-text" disabled={busy} onClick={remove}>Delete</button>}
        </div>
      </div>
      {error && <div className="inline-error">{error}</div>}
      {notice && <div className="field-note">{notice}</div>}
      {view === 'history' ? (
        !history ? <div className="empty">Loading file history…</div> : !history.commits?.length ? <div className="empty">No changes found for this file.</div> : <Commits data={history} loading={false} onSelect={(commit) => { if (commit.present) { setRevision(commit.oid); setView('file') } }} />
      ) : view === 'blame' ? (
        blameBusy ? <div className="empty">Tracing line history…</div> : blame && file?.text !== null ? <><div className="blame-summary"><span>{blame.sourceCount} {blame.historyKind === 'clay' ? 'revisions' : 'commits'} traced across {blame.lineCount} lines</span>{blame.truncated && <span>Attribution stops after 200 snapshots</span>}</div><HighlightedCode code={file.text} path={path} selectedStart={lineStart} selectedEnd={lineEnd} onSelectLine={onSelectLine} blame={blamedLines} onSelectBlame={onOpenCommit} /></> : null
      ) : view === 'upstream' ? (
        upstreamBusy ? <div className="empty">Reading file from GitHub…</div> : upstream ? <><div className="upstream-file-meta"><span>GitHub · <code>{shortOid(upstream.sha)}</code> · {formatBytes(upstream.size)}</span>{upstream.url && <a href={upstream.url} target="_blank" rel="noreferrer">Open on GitHub ↗</a>}</div>{upstream.text !== null ? <HighlightedCode code={upstream.text} path={path} selectedStart={lineStart} selectedEnd={lineEnd} onSelectLine={onSelectLine} /> : <div className="empty" title={exactBytes(upstream.size)}>Binary file · {formatBytes(upstream.size)}</div>}</> : null
      ) : busy && !file ? <div className="empty">Loading file…</div> : editing ? (
        <div className="editor-panel">
          <HighlightedEditor value={text} path={path} onChange={(event) => { setText(event.target.value); saveLocalDraft(contentDraftKey, event.target.value) }} />
          <div className="editor-footer">
            <input value={message} onChange={(event) => { setMessage(event.target.value); saveLocalDraft(messageDraftKey, event.target.value) }} aria-label="Commit message" />
            <button className="button" onClick={() => { clearLocalDraft(contentDraftKey); clearLocalDraft(messageDraftKey); setText(original); setMessage(`Edit ${path}`); setEditing(false) }}>Cancel</button>
            <button className="button primary" disabled={busy || !message.trim() || text === original} onClick={save}>{busy ? 'Committing…' : 'Commit changes'}</button>
          </div>
        </div>
      ) : objectUrl ? (
        <div className="image-view"><img src={objectUrl} alt={path} /></div>
      ) : file?.text !== null ? (
        /\.(?:md|markdown)$/i.test(path) ? <section className="readme-panel standalone"><header><span>{path.replace(/^\/+/, '')}</span></header><MarkdownDocument>{file.text}</MarkdownDocument></section> : <HighlightedCode code={file?.text} path={path} selectedStart={lineStart} selectedEnd={lineEnd} onSelectLine={onSelectLine} />
      ) : file ? (
        <div className="empty" title={exactBytes(file.size)}>Binary file · {formatBytes(file.size)}</div>
      ) : null}
    </div>
  )
}

function NewFile({ repository, branch, onCancel, onCreated }) {
  const [path, setPath, clearPath] = useLocalDraft(`new-file:${repository}:${branch}:path`)
  const [content, setContent, clearContent] = useLocalDraft(`new-file:${repository}:${branch}:content`)
  const [message, setMessage, clearMessage] = useLocalDraft(`new-file:${repository}:${branch}:message`, 'Create file')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const normalized = `/${path.trim().replace(/^\/+/, '')}`
  async function create() {
    setBusy(true); setError(''); setNotice('')
    try {
      const answer = await api.saveFile(repository, normalized, encodeBase64(content), message.trim(), branch)
      clearPath(); clearContent(); clearMessage()
      // a CI-protected branch stages the new file; it is not there yet (Q4)
      const staged = stagedEditNote(answer, branch, 'This new file')
      if (staged) { setNotice(staged); setBusy(false); return }
      await onCreated(normalized)
    } catch (cause) { setError(cause.message); setBusy(false) }
  }
  return <div className="new-file-panel">
    <div className="file-toolbar"><button className="text-button file-back" onClick={onCancel}>← Files</button><strong>New file</strong></div>
    {error && <div className="inline-error">{error}</div>}
    {notice && <div className="field-note">{notice}</div>}
    <label><span>Path</span><input autoFocus value={path} onChange={(event) => setPath(event.target.value)} placeholder="lib/example.hoon" /></label>
    <HighlightedEditor value={content} path={normalized} onChange={(event) => setContent(event.target.value)} />
    <div className="editor-footer"><input value={message} onChange={(event) => setMessage(event.target.value)} aria-label="Commit message" /><button className="button" onClick={onCancel}>Cancel</button><button className="button primary" disabled={busy || !path.trim() || !message.trim()} onClick={create}>{busy ? 'Committing…' : 'Create file'}</button></div>
  </div>
}

function downloadComparison(repo, base, head, patch) {
  const blob = new Blob([patch], { type: 'text/x-diff;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const anchor = document.createElement('a')
  anchor.href = url
  anchor.download = `${repo}-${base.replace('refs/heads/', '')}-to-${head.replace('refs/heads/', '')}.patch`
  anchor.click()
  setTimeout(() => URL.revokeObjectURL(url), 0)
}

function Branches({ repo, publicMode, onBrowse, onMutate, client = api, initialCreate = false, initialSource = '', onCreateConsumed }) {
  const confirmAction = useConfirm()
  const branches = (repo.refs || []).filter((ref) => ref.name.startsWith('refs/heads/'))
  const [creating, setCreating] = useState(initialCreate)
  const [name, setName] = useState('')
  const [source, setSource] = useState(initialSource || repo.head || branches[0]?.name || '')
  const [busy, setBusy] = useState('')
  const [error, setError] = useState('')
  const [comparing, setComparing] = useState(false)
  const [base, setBase] = useState(repo.head || branches[0]?.name || '')
  const [head, setHead] = useState(branches.find((branch) => branch.name !== (repo.head || branches[0]?.name))?.name || repo.head || '')
  const [comparison, setComparison] = useState(null)

  useEffect(() => {
    if (!initialCreate) return
    setCreating(true)
    onCreateConsumed?.()
  }, [initialCreate])

  async function create() {
    setBusy('create'); setError('')
    try {
      await api.createBranch(repo.name, name.trim(), source)
      setName(''); setCreating(false)
      await onMutate?.()
    } catch (cause) { setError(cause.message) } finally { setBusy('') }
  }

  async function remove(branch) {
    const label = branch.replace('refs/heads/', '')
    if (!await confirmAction({ title: 'Delete branch?', message: label, detail: 'The branch reference will be removed. Objects reachable from other refs remain available.', confirmLabel: 'Delete branch' })) return
    setBusy(branch); setError('')
    try { await api.deleteBranch(repo.name, label); await onMutate?.() } catch (cause) { setError(cause.message) } finally { setBusy('') }
  }

  async function makeDefault(branch) {
    const label = branch.replace('refs/heads/', '')
    setBusy(branch); setError('')
    try { await api.setDefaultBranch(repo.name, label); await onMutate?.() } catch (cause) { setError(cause.message) } finally { setBusy('') }
  }

  async function compare() {
    if (!base || !head || base === head) return
    setBusy('compare'); setError(''); setComparison(null)
    try { setComparison(await client.compare(repo.name, base, head)) } catch (cause) { setError(cause.message) } finally { setBusy('') }
  }

  const patch = useMemo(() => comparison ? comparisonPatch(comparison) : null, [comparison])

  return <div className="branches-view">
    <div className="forge-toolbar"><div><strong>Branches</strong><p className="quiet">Browse branch tips and compare their complete trees.</p></div><div className="forge-toolbar-actions">{branches.length > 1 && <button className="button" onClick={() => { setComparing(!comparing); setComparison(null); setError('') }}>{comparing ? 'Close comparison' : 'Compare branches'}</button>}{!publicMode && <button className="button primary" disabled={!branches.length} onClick={() => setCreating(!creating)}>{creating ? 'Cancel' : 'New branch'}</button>}</div></div>
    {comparing && <section className="panel compare-composer">
      <div className="compare-controls"><label><span>Base</span><select value={base} onChange={(event) => { setBase(event.target.value); setComparison(null) }}>{branches.map((branch) => <option key={branch.name} value={branch.name}>{branch.name.replace('refs/heads/', '')} · {shortOid(branch.oid)}</option>)}</select></label><b>←</b><label><span>Compare</span><select value={head} onChange={(event) => { setHead(event.target.value); setComparison(null) }}>{branches.map((branch) => <option key={branch.name} value={branch.name}>{branch.name.replace('refs/heads/', '')} · {shortOid(branch.oid)}</option>)}</select></label><button className="button primary" disabled={busy === 'compare' || !base || !head || base === head} onClick={compare}>{busy === 'compare' ? 'Comparing…' : 'Compare'}</button></div>
      {error && <div className="inline-error">{error}</div>}
      {comparison && <><div className="compare-result-toolbar"><span><b>{comparison.changedCount}</b> files changed</span>{patch === null ? <span className="quiet">Patch download is unavailable for binary or large files and comparisons over 1,000 paths.</span> : <button className="button" onClick={() => downloadComparison(repo.name, base, head, patch)}>Download patch</button>}</div><DiffView diff={comparison} /></>}
    </section>}
    {creating && <section className="panel branch-composer">
      <label><span>Branch name</span><input autoFocus value={name} maxLength="200" onChange={(event) => setName(event.target.value)} placeholder="feature/name" /></label>
      <label><span>Source</span><select value={source} onChange={(event) => setSource(event.target.value)}>{branches.map((branch) => <option key={branch.name} value={branch.name}>{branch.name.replace('refs/heads/', '')} · {shortOid(branch.oid)}</option>)}</select></label>
      {error && <div className="inline-error">{error}</div>}
      <div className="form-actions"><button className="button primary" disabled={busy || !name.trim() || !source} onClick={create}>{busy ? 'Creating…' : 'Create branch'}</button></div>
    </section>}
    {error && !creating && !comparing && <div className="inline-error">{error}</div>}
    {!branches.length ? <div className="empty">No branches yet. Create a file to make the initial commit.</div> : <div className={`table branch-table branch-management-table${publicMode ? ' public' : ''}`}>
      <div className="table-head"><span>Branch</span><span>Commit</span>{!publicMode && <span />}</div>
      {branches.map((branch) => {
        const label = branch.name.replace('refs/heads/', '')
        const isDefault = branch.name === repo.head
        const isProtected = (repo.protectedRefs || []).includes(branch.name)
        const isBound = repo.binding?.bound && repo.binding.branch === branch.name
        return <div className="table-row" key={branch.name}>
          <button className="branch-link" onClick={() => onBrowse(branch.name)}><strong>{label}</strong>{isDefault && <small className="default-label">default</small>}{isProtected && <small className="default-label">protected</small>}{isBound && <small className="default-label">Clay</small>}</button>
          <code title={branch.oid}>{shortOid(branch.oid)}</code>
          {!publicMode && <span className="branch-actions">{!isDefault && <button className="text-button" disabled={busy === branch.name} onClick={() => makeDefault(branch.name)}>Make default</button>}<button className="text-button danger" disabled={busy === branch.name || isDefault || isProtected || isBound} title={isDefault ? 'The default branch cannot be deleted' : isProtected ? 'Protected branches cannot be deleted' : isBound ? 'Clay-linked branches cannot be deleted' : 'Delete branch'} onClick={() => remove(branch.name)}>{busy === branch.name ? 'Working…' : 'Delete'}</button></span>}
        </div>
      })}
    </div>}
  </div>
}

function Tags({ repo, publicMode, onMutate, initialTarget = '', initialKind = '', onTargetConsumed }) {
  const confirmAction = useConfirm()
  const tags = (repo.refs || []).filter((ref) => ref.name.startsWith('refs/tags/'))
  const branches = (repo.refs || []).filter((ref) => ref.name.startsWith('refs/heads/'))
  const defaultKind = repo.binding?.bound ? 'revision' : 'commit'
  const [creating, setCreating] = useState(Boolean(initialTarget))
  const [name, setName] = useState('')
  const [targetKind, setTargetKind] = useState(initialKind || defaultKind)
  const [target, setTarget] = useState(initialTarget)
  const [message, setMessage] = useState('')
  const [busy, setBusy] = useState('')
  const [error, setError] = useState('')

  useEffect(() => {
    if (!initialTarget) return
    setTarget(initialTarget)
    setTargetKind(initialKind || defaultKind)
    setCreating(true)
    onTargetConsumed?.()
  }, [initialTarget, initialKind])

  function chooseTargetKind(kind) {
    setTargetKind(kind)
    setTarget(kind === 'branch' ? branches[0]?.name || '' : kind === 'tag' ? tags[0]?.name || '' : '')
  }

  function toggleComposer() {
    if (creating) { setCreating(false); return }
    setName(''); setMessage(''); setError('')
    chooseTargetKind(defaultKind)
    setCreating(true)
  }

  const normalizedTarget = (() => {
    const value = target.trim()
    if (!value) return ''
    if (targetKind === 'revision') return /^r\d+$/.test(value) ? value : /^\d+$/.test(value) ? `r${value}` : value
    return value
  })()

  async function create() {
    setBusy('create'); setError('')
    try {
      await api.createTag(repo.name, name.trim(), normalizedTarget, message.trim())
      setName(''); setMessage(''); setCreating(false)
      await onMutate?.()
    } catch (cause) { setError(cause.message) } finally { setBusy('') }
  }

  async function remove(tag) {
    if (!await confirmAction({ title: 'Delete tag?', message: tag, detail: 'The referenced commit or Clay revision is not deleted.', confirmLabel: 'Delete tag' })) return
    setBusy(tag); setError('')
    try { await api.deleteTag(repo.name, tag); await onMutate?.() } catch (cause) { setError(cause.message) } finally { setBusy('') }
  }

  return <div className="tags-view">
    {!publicMode && <div className="forge-toolbar"><div><strong>Tags</strong><p className="quiet">Mark a commit or Clay revision with a lightweight tag, or add an annotation.</p></div><button className="button primary" disabled={!branches.length && !repo.binding?.bound && !tags.length} onClick={toggleComposer}>{creating ? 'Cancel' : 'New tag'}</button></div>}
    {creating && <section className="panel tag-composer">
      <label><span>Tag name</span><input autoFocus value={name} maxLength="200" onChange={(event) => setName(event.target.value)} placeholder="v1.0.0" /></label>
      <div className="tag-target-field"><label><span>Target type</span><select value={targetKind} onChange={(event) => chooseTargetKind(event.target.value)}><option value="commit">Commit</option>{repo.binding?.bound && <option value="revision">Clay revision</option>}<option value="branch">Branch</option>{tags.length > 0 && <option value="tag">Tag</option>}</select></label><label><span>{targetKind === 'revision' ? 'Revision number' : targetKind === 'commit' ? 'Commit hash' : targetKind === 'branch' ? 'Branch' : 'Tag'}</span>{targetKind === 'branch' ? <select value={target} onChange={(event) => setTarget(event.target.value)}>{branches.map((branch) => <option key={branch.name} value={branch.name}>{branch.name.replace('refs/heads/', '')} · {shortOid(branch.oid)}</option>)}</select> : targetKind === 'tag' ? <select value={target} onChange={(event) => setTarget(event.target.value)}>{tags.map((tag) => <option key={tag.name} value={tag.name}>{tag.name.replace('refs/tags/', '')} · {shortOid(tag.targetOid || tag.oid)}</option>)}</select> : <input value={target} maxLength={40} onChange={(event) => setTarget(event.target.value.trim())} placeholder={targetKind === 'revision' ? '160 or r160' : '1a2b3c4d'} />}</label></div>
      <label><span>Annotation <small>(optional)</small></span><textarea value={message} maxLength="4000" onChange={(event) => setMessage(event.target.value)} placeholder="Release notes" /></label>
      {error && <div className="inline-error">{error}</div>}
      <div className="form-actions"><button className="button primary" disabled={busy || !name.trim() || !normalizedTarget} onClick={create}>{busy ? 'Creating…' : 'Create tag'}</button></div>
    </section>}
    {error && !creating && <div className="inline-error">{error}</div>}
    {!tags.length ? <div className="empty">No tags yet.</div> : <div className="table branch-table tag-table">
      <div className="table-head"><span>Tag</span><span>Object</span><span /></div>
      {tags.map((tag) => { const label = tag.name.replace('refs/tags/', ''); return <div className="table-row" key={tag.name}><span><strong>{label}</strong>{tag.clayRevision > 0 && <small className="default-label">r{tag.clayRevision}</small>}</span><code title={tag.targetOid || tag.oid}>{shortOid(tag.targetOid || tag.oid)}</code>{!publicMode ? <button className="text-button danger" disabled={busy === label} onClick={() => remove(label)}>{busy === label ? 'Deleting…' : 'Delete'}</button> : <span />}</div> })}
    </div>}
  </div>
}

function Releases({ repo, publicMode, onMutate, client = api }) {
  const confirmAction = useConfirm()
  const tags = (repo.refs || []).filter((ref) => ref.name.startsWith('refs/tags/')).map((ref) => ref.name.replace('refs/tags/', ''))
  const used = new Set((repo.releases || []).map((release) => release.tag))
  const available = tags.filter((tag) => !used.has(tag))
  const [details, setDetails] = useState({})
  const [creating, setCreating] = useState(false)
  const [tag, setTag] = useState(available[0] || '')
  const [title, setTitle] = useState('')
  const [notes, setNotes] = useState('')
  const [busy, setBusy] = useState('')
  const [error, setError] = useState('')

  useEffect(() => {
    let active = true
    Promise.all((repo.releases || []).map(async (release) => {
      try { return [release.tag, await client.release(repo.name, release.tag)] } catch { return [release.tag, release] }
    })).then((entries) => { if (active) setDetails(Object.fromEntries(entries)) })
    return () => { active = false }
  }, [client, repo.name, repo.releases])

  async function create() {
    setBusy('create'); setError('')
    try {
      await api.createRelease(repo.name, tag, title.trim(), notes.trim())
      setCreating(false); setTitle(''); setNotes('')
      await onMutate?.()
    } catch (cause) { setError(cause.message) } finally { setBusy('') }
  }

  async function remove(releaseTag) {
    if (!await confirmAction({ title: 'Delete release?', message: releaseTag, detail: 'Release notes are removed; the Git tag remains.', confirmLabel: 'Delete release' })) return
    setBusy(releaseTag); setError('')
    try { await api.deleteRelease(repo.name, releaseTag); await onMutate?.() } catch (cause) { setError(cause.message) } finally { setBusy('') }
  }

  return <div className="releases-view">
    {!publicMode && <div className="forge-toolbar"><div><strong>Releases</strong><p className="quiet">Publish notes and a deterministic source archive from an existing tag.</p></div><button className="button primary" disabled={!available.length} onClick={() => { setTag(available[0] || ''); setCreating(!creating) }}>{creating ? 'Cancel' : 'New release'}</button></div>}
    {creating && <section className="panel tag-composer">
      <label><span>Tag</span><select value={tag} onChange={(event) => setTag(event.target.value)}>{available.map((item) => <option key={item}>{item}</option>)}</select></label>
      <label><span>Title</span><input autoFocus value={title} maxLength="200" onChange={(event) => setTitle(event.target.value)} placeholder={tag || 'Release title'} /></label>
      <label><span>Notes</span><textarea value={notes} maxLength="65536" onChange={(event) => setNotes(event.target.value)} placeholder="What changed?" /></label>
      {error && <div className="inline-error">{error}</div>}
      <div className="form-actions"><button className="button primary" disabled={busy || !tag || !title.trim()} onClick={create}>{busy ? 'Publishing…' : 'Publish release'}</button></div>
    </section>}
    {error && !creating && <div className="inline-error">{error}</div>}
    {!(repo.releases || []).length ? <div className="empty">No releases yet.</div> : <div className="release-list">{(repo.releases || []).map((summary) => { const release = details[summary.tag] || summary; return <article className="panel release-card" key={release.tag}><header><div><h2>{release.title}</h2><p><code>{release.tag}</code> · {release.author} · <span title={release.created}>{release.created}</span></p></div><div className="release-actions"><a className="button link-button" href={client.archiveUrl(repo.name, `refs/tags/${release.tag}`)}>Download source</a>{!publicMode && <button className="text-button danger" disabled={busy === release.tag} onClick={() => remove(release.tag)}>{busy === release.tag ? 'Deleting…' : 'Delete release'}</button>}</div></header>{release.notes && <p className="release-notes">{release.notes}</p>}</article> })}</div>}
  </div>
}

const webhookEvents = [
  ['push', 'Push'], ['tag', 'Tag'], ['pull-request', 'Pull request'],
  ['issue', 'Issue'], ['release', 'Release'], ['clay-sync', 'Clay sync'],
]

function Webhooks({ repo, onMutate }) {
  const [url, setUrl] = useState('')
  const [secret, setSecret] = useState('')
  const [events, setEvents] = useState(new Set(['push', 'tag', 'clay-sync']))
  const [incomingSecret, setIncomingSecret] = useState('')
  const [busy, setBusy] = useState('')
  const [error, setError] = useState('')
  const [status, setStatus] = useState('')
  const incomingUrl = `${window.location.origin}/apps/urgit/api/hooks/${encodeURIComponent(repo.name)}`

  function toggleEvent(event) {
    setEvents((current) => {
      const next = new Set(current)
      if (next.has(event)) next.delete(event); else next.add(event)
      return next
    })
  }

  async function create() {
    setBusy('create'); setError(''); setStatus('')
    try {
      await api.createWebhook(repo.name, url.trim(), secret, [...events])
      setUrl(''); setSecret(''); setStatus('Webhook added.'); await onMutate?.()
    } catch (cause) { setError(cause.message) } finally { setBusy('') }
  }

  async function remove(id) {
    setBusy(`delete-${id}`); setError('')
    try { await api.deleteWebhook(repo.name, id); await onMutate?.() } catch (cause) { setError(cause.message) } finally { setBusy('') }
  }

  async function test(id) {
    setBusy(`test-${id}`); setError(''); setStatus('')
    try { await api.testWebhook(repo.name, id); setStatus('Test delivery queued.'); setTimeout(() => onMutate?.(), 900) } catch (cause) { setError(cause.message) } finally { setBusy('') }
  }

  async function saveIncoming() {
    setBusy('incoming'); setError(''); setStatus('')
    try { await api.setIncomingHook(repo.name, incomingSecret); setIncomingSecret(''); setStatus('Incoming hook enabled.'); await onMutate?.() } catch (cause) { setError(cause.message) } finally { setBusy('') }
  }

  async function clearIncoming() {
    setBusy('incoming'); setError('')
    try { await api.clearIncomingHook(repo.name); await onMutate?.() } catch (cause) { setError(cause.message) } finally { setBusy('') }
  }

  async function syncUpstream(update) {
    setBusy(`sync-${update.id}`); setError(''); setStatus('')
    try {
      if (!repo.githubOrigin) throw new Error('This repository has no GitHub origin configured')
      const before = await api.githubStatus()
      const prior = new Set((before.jobs || []).map((job) => job.job))
      await api.githubImport(repo.githubOrigin.owner, repo.githubOrigin.repository, repo.name, repo.publicRead)
      for (let attempt = 0; attempt < 120; attempt += 1) {
        await new Promise((resolve) => setTimeout(resolve, 800))
        const github = await api.githubStatus()
        const matching = (github.jobs || []).filter((job) => !prior.has(job.job) && job.repository === repo.name && ['import', 'update'].includes(job.kind))
        const active = matching.find((job) => job.active)
        if (active) { setStatus(active.message); continue }
        const failed = matching.find((job) => !job.ok)
        if (failed) throw new Error(failed.message)
        if (matching.length) {
          await api.dismissUpstreamUpdate(repo.name, update.id)
          setStatus(matching[matching.length - 1].message)
          await onMutate?.()
          return
        }
      }
      throw new Error('GitHub upstream sync did not finish in time')
    } catch (cause) { setError(cause.message) } finally { setBusy('') }
  }

  async function dismiss(update) {
    setBusy(`dismiss-${update.id}`); setError('')
    try { await api.dismissUpstreamUpdate(repo.name, update.id); await onMutate?.() } catch (cause) { setError(cause.message) } finally { setBusy('') }
  }

  return <div className="automation-view">
    {error && <div className="inline-error">{error}</div>}{status && <div className="transfer-status success">{status}</div>}
    {(repo.upstreamUpdates || []).length > 0 && <section className="panel automation-section"><div className="section-title"><div><h2>Upstream updates</h2><p>Signed push notifications waiting for review.</p></div><span className="status">{repo.upstreamUpdates.length} pending</span></div><div className="delivery-list">{repo.upstreamUpdates.map((update) => <div className="upstream-update-item" key={update.id}><div><strong>{update.source}</strong><small>{update.ref} · {shortOid(update.before)} → {shortOid(update.after)}</small></div><div className="row-actions">{repo.githubOrigin && <button className="button primary" disabled={busy} onClick={() => syncUpstream(update)}>{busy === `sync-${update.id}` ? 'Starting…' : 'Pull upstream'}</button>}<button className="text-button" disabled={busy} onClick={() => dismiss(update)}>Dismiss</button></div></div>)}</div></section>}
    <section className="panel automation-section"><div className="section-title"><div><h2>Incoming webhook</h2><p>Receive signed GitHub events. Pushes become upstream prompts; pull-request events refresh the linked PR list.</p></div><span className={`status ${repo.incomingHookConfigured ? 'good' : ''}`}>{repo.incomingHookConfigured ? 'enabled' : 'off'}</span></div><label><span>Payload URL</span><div className="inline-field"><input readOnly value={incomingUrl} /><button className="button" onClick={() => navigator.clipboard.writeText(incomingUrl)}>Copy</button></div></label><label><span>{repo.incomingHookConfigured ? 'Rotate secret' : 'Secret'}</span><input type="password" value={incomingSecret} maxLength="256" onChange={(event) => setIncomingSecret(event.target.value)} placeholder="Use the same secret in GitHub" /></label><p className="field-note">Content type: application/json. Events: push and pull request. Signature: X-Hub-Signature-256.</p><div className="form-actions split">{repo.incomingHookConfigured ? <button className="button danger" disabled={busy} onClick={clearIncoming}>Disable</button> : <span />}{<button className="button primary" disabled={busy || !incomingSecret} onClick={saveIncoming}>{busy === 'incoming' ? 'Saving…' : repo.incomingHookConfigured ? 'Rotate secret' : 'Enable incoming hook'}</button>}</div></section>
    <section className="panel automation-section"><div className="section-title"><div><h2>Outgoing webhooks</h2><p>POST signed repository events to external CI, deployment, or automation endpoints.</p></div></div><div className="webhook-form"><label><span>Payload URL</span><input value={url} maxLength="2048" onChange={(event) => setUrl(event.target.value)} placeholder="https://ci.example/hooks/git" /></label><label><span>Secret</span><input type="password" value={secret} maxLength="256" onChange={(event) => setSecret(event.target.value)} /></label><div className="event-grid">{webhookEvents.map(([event, label]) => <label className="check-row compact" key={event}><input type="checkbox" checked={events.has(event)} onChange={() => toggleEvent(event)} /><span>{label}</span></label>)}</div><div className="form-actions"><button className="button primary" disabled={busy || !url.trim() || !secret || events.size === 0} onClick={create}>{busy === 'create' ? 'Adding…' : 'Add webhook'}</button></div></div>{!(repo.webhooks || []).length ? <div className="empty compact">No outgoing webhooks.</div> : <div className="webhook-list">{repo.webhooks.map((hook) => <div className="webhook-row" key={hook.id}><div><strong>{hook.url}</strong><small>{hook.events.join(' · ')}</small></div><div className="row-actions"><button className="button" disabled={busy} onClick={() => test(hook.id)}>{busy === `test-${hook.id}` ? 'Sending…' : 'Test'}</button><button className="text-button danger" disabled={busy} onClick={() => remove(hook.id)}>Delete</button></div></div>)}</div>}</section>
    <section className="panel automation-section"><div className="section-title"><div><h2>Recent deliveries</h2><p>The latest 100 attempts are retained.</p></div></div>{!(repo.webhookDeliveries || []).length ? <div className="empty compact">No deliveries yet.</div> : <div className="delivery-list">{repo.webhookDeliveries.map((delivery) => <div className="delivery-row" key={delivery.id}><span className={`activity-dot ${delivery.status === 'success' ? 'success' : delivery.status === 'failure' ? 'failure' : 'active'}`} /><div><strong>{delivery.event}</strong><small title={delivery.created}>hook #{delivery.hook} · {delivery.message}{delivery.statusCode ? ` · HTTP ${delivery.statusCode}` : ''}</small></div><span className={`status ${delivery.status === 'success' ? 'good' : ''}`}>{delivery.status}</span></div>)}</div>}</section>
  </div>
}

function PullRequests({ repo, onMutate, onOpenOrigin, initialPull = 0, onPullConsumed }) {
  const [busy, setBusy] = useState(0)
  const [error, setError] = useState('')
  const [filter, setFilter] = useState('open')
  const [query, setQuery] = useState('')
  const [selected, setSelected] = useState(null)
  const [diff, setDiff] = useState(null)
  const [creating, setCreating] = useState(false)
  const [title, setTitle, clearTitle] = useLocalDraft(`new-pull:${repo.name}:title`)
  const [submitBusy, setSubmitBusy] = useState(false)
  const [submitStatus, setSubmitStatus] = useState('')
  const branchRefs = (repo.refs || []).filter((ref) => ref.name.startsWith('refs/heads/'))
  const [sourceBranch, setSourceBranch] = useState(branchRefs.find((ref) => ref.name !== repo.head)?.name || branchRefs[0]?.name || '')
  const [targetRepository, setTargetRepository] = useState(repo.peerOrigin ? 'origin' : 'local')
  const [targetBranch, setTargetBranch] = useState(repo.head || branchRefs[0]?.name || '')
  const [originBranches, setOriginBranches] = useState([])
  const [originHead, setOriginHead] = useState('')
  const [originBranchStatus, setOriginBranchStatus] = useState('')
  const [commentBody, setCommentBody, clearCommentBody] = useLocalDraft(selected ? `pull-comment:${repo.name}:${selected.number}` : '')
  const [commentTarget, setCommentTarget] = useState(null)
  const [commentBusy, setCommentBusy] = useState(false)
  const [githubPage, setGithubPage] = useState(1)
  const [githubBusy, setGithubBusy] = useState(false)
  const [githubSyncKey, setGithubSyncKey] = useState('')
  const [githubDetail, setGithubDetail] = useState(null)
  const [githubDiff, setGithubDiff] = useState(null)
  const [githubHasMore, setGithubHasMore] = useState((repo.githubPulls || []).length >= 100)
  const pulls = repo.pullRequests || []
  async function merge(number) {
    setBusy(number)
    setError('')
    try { await api.mergePull(repo.name, number); await onMutate() } catch (cause) { setError(cause.message) } finally { setBusy(0) }
  }
  async function setPullState(number, state) {
    setBusy(number); setError('')
    try {
      await api.setPullState(repo.name, number, state)
      setSelected((current) => current ? { ...current, state } : current)
      await onMutate?.()
    } catch (cause) { setError(cause.message) } finally { setBusy(0) }
  }
  const githubPulls = repo.githubPulls || []
  const entries = useMemo(() => [
    ...pulls.map((pull) => ({ ...pull, native: true })),
    ...githubPulls.map((pull) => ({ ...pull, native: false })),
  ], [pulls, githubPulls])
  const visible = entries.filter((pull) => (filter === 'all' || pull.state === filter) && (!query.trim() || pull.title.toLowerCase().includes(query.trim().toLowerCase())))

  async function syncGithubPulls(page) {
    setGithubBusy(true); setError('')
    try {
      const job = await syncGithubMetadata(repo.name, 'pulls', page)
      const received = githubReceivedCount(job)
      setGithubPage(page)
      setGithubHasMore(received === 100 && page < 5)
      await onMutate?.()
    } catch (cause) { setError(cause.message) } finally { setGithubBusy(false) }
  }

  useEffect(() => {
    if (!repo.githubOrigin || githubSyncKey === repo.name) return
    setGithubSyncKey(repo.name)
    void syncGithubPulls(1)
  }, [repo.name, repo.githubOrigin?.owner, repo.githubOrigin?.repository, githubSyncKey])

  async function loadMoreGithubPulls() {
    await syncGithubPulls(Math.min(5, githubPage + 1))
  }

  async function beginPullRequest() {
    const nextSource = branchRefs.find((ref) => ref.name !== repo.head)?.name || branchRefs[0]?.name || ''
    setSourceBranch(nextSource)
    setSubmitStatus('')
    setError('')
    setCreating(true)
    setTargetRepository(repo.peerOrigin ? 'origin' : 'local')
    if (!repo.peerOrigin) {
      setTargetBranch(repo.head || branchRefs[0]?.name || '')
      return
    }
    setOriginBranches([])
    setOriginHead('')
    setTargetBranch('')
    setOriginBranchStatus('Loading origin branches…')
    let request = ''
    try {
      const started = await api.peerBrowse(repo.peerOrigin.ship, repo.peerOrigin.repository)
      request = started.request
      const found = await waitForPeerBrowse(started.request)
      if (!found.ok) throw new Error(found.message || 'Could not load origin branches')
      const origin = found.result?.repository
      const branches = (origin?.refs || []).filter((ref) => ref.name.startsWith('refs/heads/'))
      if (!branches.length) throw new Error('Could not load origin branches')
      setOriginBranches(branches)
      setOriginHead(origin.head || branches[0].name)
      setTargetBranch(origin.head || branches[0].name)
      setOriginBranchStatus('')
    } catch (cause) {
      setOriginBranchStatus(`Could not load origin branches: ${cause.message}`)
    } finally {
      if (request) await api.peerDeleteBrowse(request).catch(() => {})
    }
  }

  function chooseTargetRepository(next) {
    setTargetRepository(next)
    setTargetBranch(next === 'local' ? repo.head || branchRefs[0]?.name || '' : originHead || originBranches[0]?.name || '')
  }

  async function openNativePull() {
    const targetsOrigin = Boolean(repo.peerOrigin && targetRepository === 'origin')
    setSubmitBusy(true); setError(''); setSubmitStatus(targetsOrigin ? 'Offering changes to the origin…' : 'Opening pull request…')
    try {
      if (!repo.peerOrigin || targetRepository === 'local') {
        const opened = await api.createPull(repo.name, title.trim(), sourceBranch, targetBranch)
        setSubmitStatus(`Pull request #${opened.number} opened`)
        clearTitle(); setCreating(false)
        await onMutate?.()
        return
      }
      const started = await api.peerPullRequest(repo.name, title.trim(), sourceBranch, targetBranch)
      const transfer = await waitForPeerTransfer(started.transfer, {
        onProgress: (current) => current.message && setSubmitStatus(current.message),
      })
      await api.peerDeleteTransfer(started.transfer).catch(() => {})
      if (!transfer.ok) throw new Error(transfer.message)
      setSubmitStatus(transfer.message || 'Pull request opened')
      clearTitle()
      return
    } catch (cause) {
      setError(cause.message); setSubmitStatus('')
    } finally {
      setSubmitBusy(false)
    }
  }

  // a pull request named by the route (a CI run's link) opens once, by its
  // number among the native pull requests, and the route then forgets it
  useEffect(() => {
    if (!initialPull) return
    const found = pulls.find((pull) => Number(pull.number) === Number(initialPull))
    if (found) inspect({ ...found, native: true })
    else setError(`Pull request #${initialPull} is not a native pull request of this repository.`)
    onPullConsumed?.()
  }, [initialPull])

  async function inspect(pull) {
    setSelected(pull); setDiff(null); setGithubDetail(null); setGithubDiff(null); setError(''); setCommentTarget(null)
    try {
      if (pull.native) setDiff(await api.pull(repo.name, pull.number))
      else {
        const [detailResult, diffResult] = await Promise.allSettled([
          api.githubPullDetail(repo.name, pull.number),
          api.githubPullDiff(repo.name, pull.number),
        ])
        if (detailResult.status === 'rejected') throw detailResult.reason
        setGithubDetail(detailResult.value)
        if (diffResult.status === 'fulfilled') {
          const decoded = decodeBase64(diffResult.value.content || '')
          setGithubDiff(decoded.text || '')
        } else setError(`Diff unavailable: ${diffResult.reason?.message || 'GitHub request failed'}`)
      }
    } catch (cause) { setError(cause.message) }
  }
  async function addComment() {
    if (!commentBody.trim()) return
    setCommentBusy(true); setError('')
    try {
      await api.addPullComment(repo.name, selected.number, commentBody.trim(), commentTarget?.path || '', commentTarget?.line || 0, commentTarget?.side || '')
      clearCommentBody(); setCommentTarget(null)
      setDiff(await api.pull(repo.name, selected.number))
      await onMutate?.()
    } catch (cause) { setError(cause.message) } finally { setCommentBusy(false) }
  }
  async function setCommentResolved(comment, resolved) {
    setCommentBusy(true); setError('')
    try {
      await api.resolvePullComment(repo.name, selected.number, comment.id, resolved)
      setDiff(await api.pull(repo.name, selected.number))
      await onMutate?.()
    } catch (cause) { setError(cause.message) } finally { setCommentBusy(false) }
  }
  if (selected && !selected.native) return <GithubDetail detail={githubDetail} diff={githubDiff} fallback={selected} kind="Pull request" error={error} onBack={() => { setSelected(null); setGithubDetail(null); setGithubDiff(null); setError('') }} />
  if (selected) return <div className="pull-detail">
    <button className="text-button file-back" onClick={() => { setSelected(null); setDiff(null); setCommentTarget(null) }}>← Pull requests</button>
    <header className="pull-detail-header"><div><h2>#{selected.number} {selected.title}</h2><p><span className={`status ${selected.state === 'open' ? 'good' : ''}`}>{selected.state}</span> <code>{selected.sourceShip}/{selected.sourceRepository}</code> proposes <code>{pullRefLabel(selected.sourceRef, selected.head)}</code> into <code>{pullRefLabel(selected.targetRef, selected.base)}</code></p></div><div className="pr-actions">{selected.state === 'closed' && <button className="button" disabled={busy} onClick={() => setPullState(selected.number, 'open')}>{busy === selected.number ? 'Reopening…' : 'Reopen'}</button>}{selected.state === 'open' && <><button className="button" disabled={busy} onClick={() => setPullState(selected.number, 'closed')}>{busy === selected.number ? 'Closing…' : 'Close'}</button><button className="button primary" disabled={busy} onClick={() => merge(selected.number)}>{busy === selected.number ? 'Validating…' : 'Merge pull request'}</button></>}</div></header>
    {error && <div className="inline-error">{error}</div>}
    <PullLabels labels={diff?.labels || selected.labels || []} editable={Boolean(diff?.labelsEditable)} onSave={(labels) => api.setPullLabels(repo.name, selected.number, labels)} onSaved={async () => { setDiff(await api.pull(repo.name, selected.number)); await onMutate?.() }} />
    {!diff ? <div className="empty">Loading diff…</div> : <>
      <DiffView diff={diff} onCommentTarget={setCommentTarget} />
      <section className="review-discussion">
        <h3>Discussion <span>{diff.comments?.length || 0}</span></h3>
        {(diff.comments || []).map((comment) => <article className={`review-comment ${comment.resolved ? 'resolved' : ''}`} key={comment.id}><header><strong>{comment.author}</strong><span>{comment.path ? <code>{comment.path} · {comment.side === 'base' ? 'base ' : ''}L{comment.line}</code> : 'General review'} · <time title={comment.created}>{comment.created}</time></span><button className="text-button" disabled={commentBusy} onClick={() => setCommentResolved(comment, !comment.resolved)}>{comment.resolved ? 'Reopen' : 'Resolve'}</button></header><p>{comment.body}</p></article>)}
        {!diff.comments?.length && <div className="empty compact">No review comments yet. Click a changed line to anchor a comment.</div>}
        <div className="review-composer"><div className="review-target"><strong>{commentTarget ? `${commentTarget.path} · ${commentTarget.side === 'base' ? 'base ' : ''}L${commentTarget.line}` : 'General comment'}</strong>{commentTarget && <button className="text-button" onClick={() => setCommentTarget(null)}>Clear line</button>}</div><textarea value={commentBody} maxLength="16384" onChange={(event) => setCommentBody(event.target.value)} placeholder={commentTarget ? 'Comment on this line…' : 'Leave a review comment…'} /><div className="form-actions"><button className="button primary" disabled={commentBusy || !commentBody.trim()} onClick={addComment}>{commentBusy ? 'Commenting…' : 'Comment'}</button></div></div>
      </section>
    </>}
  </div>
  return <>
    <div className="forge-toolbar"><div className="segmented"><button className={filter === 'open' ? 'active' : ''} onClick={() => setFilter('open')}>Open</button><button className={filter === 'closed' ? 'active' : ''} onClick={() => setFilter('closed')}>Closed</button><button className={filter === 'all' ? 'active' : ''} onClick={() => setFilter('all')}>All</button></div><div className="forge-toolbar-actions"><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Filter pull requests…" />{repo.githubOrigin && <button className="button" disabled={githubBusy} onClick={() => syncGithubPulls(1)}>{githubBusy ? 'Syncing…' : 'Sync GitHub'}</button>}{repo.githubOrigin && githubHasMore && <button className="button" disabled={githubBusy} onClick={loadMoreGithubPulls}>{githubBusy ? 'Loading…' : 'Load more'}</button>}{(repo.peerOrigin ? branchRefs.length > 0 : branchRefs.length > 1) && <button className="button primary" onClick={beginPullRequest}>New pull request</button>}</div></div>
    {creating && <section className="panel pr-composer">
      <div className="section-title"><div><h2>Open a pull request</h2><p>Select the source branch and the branch that will receive the merge.</p></div><button className="text-button" disabled={submitBusy} onClick={() => { setCreating(false); setSubmitStatus(''); setError('') }}>Cancel</button></div>
      <div className="pr-compare">
        <div><span>Source</span><strong>{repo.owner}/{repo.name}</strong><select value={sourceBranch} onChange={(event) => setSourceBranch(event.target.value)}>{branchRefs.map((branch) => <option key={branch.name} value={branch.name}>{pullRefLabel(branch.name, branch.oid)}</option>)}</select></div>
        <b>→</b>
        <div><span>Target</span>{repo.peerOrigin && <select value={targetRepository} onChange={(event) => chooseTargetRepository(event.target.value)}><option value="local">This repository</option><option value="origin">Origin repository</option></select>}<strong>{repo.peerOrigin && targetRepository === 'origin' ? `${repo.peerOrigin.ship}/${repo.peerOrigin.repository}` : `${repo.owner}/${repo.name}`}</strong><select value={targetBranch} disabled={Boolean(targetRepository === 'origin' && originBranchStatus)} onChange={(event) => setTargetBranch(event.target.value)}>{(targetRepository === 'origin' ? originBranches : branchRefs).map((branch) => <option key={branch.name} value={branch.name}>{pullRefLabel(branch.name, branch.oid)}</option>)}</select></div>
      </div>
      {targetRepository === 'origin' && originBranchStatus && <div className={originBranchStatus.startsWith('Could not') ? 'inline-error' : 'transfer-status'}>{originBranchStatus}</div>}
      <label><span>Title</span><input autoFocus value={title} maxLength="200" onChange={(event) => setTitle(event.target.value)} onKeyDown={(event) => { if (event.key === 'Enter' && title.trim() && !submitBusy) openNativePull() }} placeholder="Summarize the changes" /></label>
      {error && <div className="inline-error">{error}</div>}
      {submitStatus && <div className={`transfer-status ${!submitBusy ? 'success' : ''}`}>{submitBusy && <span className="spinner" />}{submitStatus}</div>}
      <div className="form-actions split"><small className="quiet">The selected branch tips are fixed when the review opens.</small><div className="pr-actions">{repo.peerOrigin && targetRepository === 'origin' && submitStatus && !submitBusy && <button className="button" onClick={() => onOpenOrigin?.(repo.peerOrigin.ship, repo.peerOrigin.repository)}>View origin</button>}<button className="button primary" disabled={submitBusy || !title.trim() || !sourceBranch || !targetBranch || (targetRepository === 'local' && sourceBranch === targetBranch) || Boolean(targetRepository === 'origin' && originBranchStatus) || (!!submitStatus && !error)} onClick={openNativePull}>{submitBusy ? 'Opening…' : 'Create pull request'}</button></div></div>
    </section>}
    {!entries.length ? <div className="empty compact">{repo.peerOrigin ? 'No pull requests opened from this repository yet.' : 'No pull requests.'}</div> : !visible.length ? <div className="empty compact">No pull requests match this filter.</div> : <div className="pull-list">
    {error && <div className="inline-error">{error}</div>}
    {visible.map((pull) => pull.native ? <article className="pull-row clickable" key={`native-${pull.number}`} onClick={() => inspect(pull)}>
      <div><span className={`status ${pull.state === 'open' ? 'good' : ''}`}>{pull.state}</span><h3>#{pull.number} {pull.title}</h3><p><code>{pull.sourceShip}/{pull.sourceRepository}</code> proposes <code>{pullRefLabel(pull.sourceRef, pull.head)}</code> into <code>{pullRefLabel(pull.targetRef, pull.base)}</code></p>{(pull.labels || []).length > 0 && <div className="issue-labels inline" aria-label="Labels">{pull.labels.map((label) => <span key={label}>{label}</span>)}</div>}</div>
      {pull.state === 'open' && <button className="button primary" disabled={busy} onClick={(event) => { event.stopPropagation(); merge(pull.number) }}>{busy === pull.number ? 'Validating…' : 'Merge'}</button>}
    </article> : <button className="pull-row forge-link clickable row-button" key={`github-${pull.number}`} onClick={() => inspect(pull)}>
      <div><span className={`status ${pull.state === 'open' ? 'good' : ''}`}>{pull.draft ? 'draft' : pull.state}</span><h3>#{pull.number} {pull.title}</h3><p>opened by <strong>{pull.author}</strong> on GitHub</p></div><span className="external-arrow">↗</span>
    </button>)}
    </div>}
  </>
}

export function DiffView({ diff, onCommentTarget }) {
  return <div className="diff-view"><div className="diff-overview"><b>{diff.changedCount || 0}</b> files changed <code>{shortOid(diff.base)}..{shortOid(diff.head)}</code></div>{(diff.changes || []).map((change) => <FileDiff key={change.path} change={change} onCommentTarget={onCommentTarget} />)}</div>
}

function FileDiff({ change, onCommentTarget }) {
  if (change.truncated) return <section className="file-diff"><header><code>{change.path}</code><span>{change.status}</span></header><div className="empty compact">{change.oldSize || change.newSize ? 'Diff omitted because this file exceeds 256 KiB.' : 'Diff body omitted from this revision summary.'}</div></section>
  let oldText = '', newText = ''
  try { oldText = change.oldContent ? decodeBase64(change.oldContent).text ?? '' : ''; newText = change.newContent ? decodeBase64(change.newContent).text ?? '' : '' } catch { /* binary */ }
  if ((change.oldContent && !oldText) || (change.newContent && !newText)) return <section className="file-diff"><header><code>{change.path}</code><span>{change.status}</span></header><div className="empty compact">Binary file changed.</div></section>
  const before = oldText.split('\n'), after = newText.split('\n')
  let prefix = 0
  while (prefix < before.length && prefix < after.length && before[prefix] === after[prefix]) prefix += 1
  let suffix = 0
  while (suffix < before.length - prefix && suffix < after.length - prefix && before[before.length - 1 - suffix] === after[after.length - 1 - suffix]) suffix += 1
  const rows = []
  before.slice(Math.max(0, prefix - 3), prefix).forEach((line, index) => rows.push({ type: 'context', line, old: Math.max(0, prefix - 3) + index + 1, next: Math.max(0, prefix - 3) + index + 1 }))
  before.slice(prefix, before.length - suffix).forEach((line, index) => rows.push({ type: 'delete', line, old: prefix + index + 1, next: '' }))
  after.slice(prefix, after.length - suffix).forEach((line, index) => rows.push({ type: 'add', line, old: '', next: prefix + index + 1 }))
  after.slice(after.length - suffix, Math.min(after.length, after.length - suffix + 3)).forEach((line, index) => rows.push({ type: 'context', line, old: before.length - suffix + index + 1, next: after.length - suffix + index + 1 }))
  return <section className="file-diff"><header><code>{change.path}</code><span>{change.status} · {change.oldSize} → {change.newSize} B</span></header><div className="hunk-head">@@ -{prefix + 1} +{prefix + 1} @@</div><pre>{rows.map((row, index) => { const side = row.type === 'delete' ? 'base' : 'head'; const line = side === 'base' ? row.old : row.next; return <span className={`diff-line ${row.type} ${onCommentTarget && line ? 'commentable' : ''}`} key={index} onClick={() => line && onCommentTarget?.({ path: change.path, line, side })}><i>{row.old}</i><i>{row.next}</i><b>{row.type === 'add' ? '+' : row.type === 'delete' ? '-' : ' '}</b><code>{row.line}</code></span> })}</pre></section>
}

function IssueText({ text = '' }) {
  const parts = text.split(/(~[a-z0-9-]+\/[A-Za-z0-9._-]+#\d+)/g)
  return <>{parts.map((part, index) => {
    const match = /^(~[a-z0-9-]+)\/([A-Za-z0-9._-]+)#(\d+)$/.exec(part)
    return match ? <a key={index} className="issue-reference" href={`/apps/urgit/#/peer/${encodeURIComponent(match[1])}/${encodeURIComponent(match[2])}`} title={`Issue #${match[3]} on ${match[1]}/${match[2]}`}>{part}</a> : part
  })}</>
}

function NativeIssueDetail({ repo, issue: initialIssue, publicMode, client, onBack, onMutate }) {
  const [issue, setIssue] = useState(initialIssue)
  const [comment, setComment, clearComment] = useLocalDraft(`issue-comment:${repo.name}:${initialIssue.number}`)
  const [labels, setLabels] = useState((initialIssue.labels || []).join(', '))
  const [assignees, setAssignees] = useState((initialIssue.assignees || []).join(', '))
  const [busy, setBusy] = useState('')
  const [error, setError] = useState('')
  async function reload() {
    const next = await client.issue(repo.name, issue.number)
    setIssue(next); setLabels((next.labels || []).join(', ')); setAssignees((next.assignees || []).join(', '))
  }
  async function act(kind, operation) {
    setBusy(kind); setError('')
    try { await operation(); await reload(); await onMutate?.(); return true } catch (cause) { setError(cause.message); return false } finally { setBusy('') }
  }
  async function addComment() {
    const body = comment.trim()
    if (!body) return
    if (await act('comment', () => api.addIssueComment(repo.name, issue.number, body))) clearComment()
  }
  const parseList = (value) => [...new Set(value.split(',').map((item) => item.trim()).filter(Boolean))]
  return <div className="issue-detail">
    <button className="text-button file-back" onClick={onBack}>← Issues</button>
    <header className="pull-detail-header"><div><h2>#{issue.number} {issue.title}</h2><p><span className={`status ${issue.state === 'open' ? 'good' : ''}`}>{issue.state}</span> opened by <strong>{issue.author}</strong> <span title={issue.created}>· {issue.created}</span></p></div>{!publicMode && <button className="button" disabled={busy} onClick={() => act('state', () => api.setIssueState(repo.name, issue.number, issue.state === 'open' ? 'closed' : 'open'))}>{busy === 'state' ? 'Saving…' : issue.state === 'open' ? 'Close issue' : 'Reopen issue'}</button>}</header>
    {error && <div className="inline-error">{error}</div>}
    <div className="issue-layout"><div className="issue-thread">
      <article className="review-comment"><header><strong>{issue.author}</strong><span title={issue.created}>{issue.created}</span></header><p><IssueText text={issue.body || 'No description provided.'} /></p></article>
      {(issue.comments || []).map((entry) => <article className="review-comment" key={entry.id}><header><strong>{entry.author}</strong><span title={entry.created}>{entry.created}</span></header><p><IssueText text={entry.body} /></p></article>)}
      {!publicMode && <div className="review-composer"><textarea value={comment} maxLength="16384" onChange={(event) => setComment(event.target.value)} placeholder="Add a comment…" /><div className="form-actions"><button className="button primary" disabled={busy || !comment.trim()} onClick={addComment}>{busy === 'comment' ? 'Commenting…' : 'Comment'}</button></div></div>}
    </div><aside className="issue-sidebar">
      <section><strong>Labels</strong>{!publicMode ? <><input value={labels} maxLength="1300" onChange={(event) => setLabels(event.target.value)} placeholder="bug, help wanted" /><button className="text-button" disabled={busy} onClick={() => act('labels', () => api.setIssueLabels(repo.name, issue.number, parseList(labels)))}>Save labels</button></> : null}<div className="issue-labels">{(issue.labels || []).map((label) => <span key={label}>{label}</span>)}{!(issue.labels || []).length && <small>None</small>}</div></section>
      <section><strong>Assignees</strong>{!publicMode ? <><input value={assignees} maxLength="600" onChange={(event) => setAssignees(event.target.value)} placeholder="~sampel-palnet" /><button className="text-button" disabled={busy} onClick={() => act('assignees', () => api.setIssueAssignees(repo.name, issue.number, parseList(assignees)))}>Save assignees</button></> : null}<div>{(issue.assignees || []).map((ship) => <code key={ship}>{ship}</code>)}{!(issue.assignees || []).length && <small>Unassigned</small>}</div></section>
    </aside></div>
  </div>
}

function Issues({ repo, onMutate, publicMode = false, client = api }) {
  const [filter, setFilter] = useState('open')
  const [query, setQuery] = useState('')
  const [page, setPage] = useState(1)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [selected, setSelected] = useState(null)
  const [detail, setDetail] = useState(null)
  const [creating, setCreating] = useState(false)
  const [title, setTitle, clearTitle] = useLocalDraft(`new-issue:${repo.name}:title`)
  const [body, setBody, clearBody] = useLocalDraft(`new-issue:${repo.name}:body`)
  const [githubHasMore, setGithubHasMore] = useState((repo.githubIssues || []).length >= 100)
  const nativeIssues = repo.nativeIssues || []
  const githubIssues = repo.githubIssues || []
  const issues = [...nativeIssues.map((issue) => ({ ...issue, source: 'native' })), ...githubIssues.map((issue) => ({ ...issue, source: 'github' }))]
  const visible = issues.filter((issue) => (filter === 'all' || issue.state === filter) && (!query.trim() || issue.title.toLowerCase().includes(query.trim().toLowerCase())))
  async function sync(targetPage) {
    setBusy(true); setError('')
    try {
      const job = await syncGithubMetadata(repo.name, 'issues', targetPage)
      const received = githubReceivedCount(job)
      setPage(targetPage)
      setGithubHasMore(received === 100 && targetPage < 5)
      await onMutate?.()
    } catch (cause) { setError(cause.message) } finally { setBusy(false) }
  }
  async function inspect(issue) {
    setSelected(issue); setDetail(null); setError('')
    if (issue.source === 'github') {
      if (publicMode && issue.url) { window.open(issue.url, '_blank', 'noopener,noreferrer'); setSelected(null); return }
      try { setDetail(await api.githubIssue(repo.name, issue.number)) } catch (cause) { setError(cause.message) }
      return
    }
    try { setDetail(await client.issue(repo.name, issue.number)) } catch (cause) { setError(cause.message) }
  }
  if (selected?.source === 'github') return <GithubDetail detail={detail} fallback={selected} kind="Issue" error={error} onBack={() => { setSelected(null); setDetail(null); setError('') }} />
  if (selected) return detail ? <NativeIssueDetail repo={repo} issue={detail} publicMode={publicMode} client={client} onMutate={onMutate} onBack={() => { setSelected(null); setDetail(null); setError('') }} /> : <div className="empty">{error || 'Loading issue…'}</div>
  async function createIssue() {
    if (!title.trim()) return
    setBusy(true); setError('')
    try { const created = await api.createIssue(repo.name, title.trim(), body.trim()); setCreating(false); clearTitle(); clearBody(); await onMutate?.(); await inspect({ ...created, source: 'native' }) } catch (cause) { setError(cause.message) } finally { setBusy(false) }
  }
  return <>{!publicMode && creating && <section className="panel issue-composer"><div className="section-title"><div><h2>New issue</h2><p className="quiet">Open an issue under your ship identity.</p></div><button className="text-button" onClick={() => setCreating(false)}>Cancel</button></div><label><span>Title</span><input autoFocus value={title} maxLength="200" onChange={(event) => setTitle(event.target.value)} /></label><label><span>Description</span><textarea value={body} maxLength="65536" onChange={(event) => setBody(event.target.value)} placeholder="Describe the problem or proposal…" /></label><div className="form-actions"><button className="button primary" disabled={busy || !title.trim()} onClick={createIssue}>{busy ? 'Opening…' : 'Open issue'}</button></div></section>}
    <div className="forge-toolbar"><div className="segmented"><button className={filter === 'open' ? 'active' : ''} onClick={() => setFilter('open')}>Open</button><button className={filter === 'closed' ? 'active' : ''} onClick={() => setFilter('closed')}>Closed</button><button className={filter === 'all' ? 'active' : ''} onClick={() => setFilter('all')}>All</button></div><div className="forge-toolbar-actions"><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Filter issues…" />{!publicMode && repo.githubOrigin && <button className="button" disabled={busy} onClick={() => sync(1)}>{busy ? 'Syncing…' : 'Sync GitHub'}</button>}{!publicMode && repo.githubOrigin && githubHasMore && <button className="button" disabled={busy} onClick={() => sync(page + 1)}>{busy ? 'Loading…' : 'Load more'}</button>}{!publicMode && <button className="button primary" onClick={() => setCreating(!creating)}>New issue</button>}</div></div>{error && <div className="inline-error">{error}</div>}{!issues.length ? <div className="empty compact">No issues.</div> : !visible.length ? <div className="empty compact">No issues match this filter.</div> : <div className="issue-list">{visible.map((issue) => <button className="issue-row forge-link row-button" key={`${issue.source}-${issue.number}`} onClick={() => inspect(issue)}><span className={`issue-icon ${issue.state}`}>◉</span><div><h3>{issue.title}</h3><p>#{issue.number} · {issue.state} · {issue.author}{issue.source === 'github' ? ' · GitHub' : ` · ${issue.commentCount || 0} comments`}</p><div className="issue-labels inline">{(issue.labels || []).map((label) => <span key={label}>{label}</span>)}</div></div><span className="external-arrow">{issue.source === 'github' ? '↗' : '›'}</span></button>)}</div>}</>
}

function parseUnifiedDiff(text) {
  const files = []
  let file = null
  let oldLine = 0
  let newLine = 0
  for (const line of (text || '').split('\n')) {
    if (line.startsWith('diff --git ')) {
      file = { path: line.replace(/^diff --git a\/.+ b\//, ''), lines: [] }
      files.push(file)
      continue
    }
    if (!file) continue
    if (line.startsWith('+++ b/')) { file.path = line.slice(6); continue }
    if (line.startsWith('--- ') || line.startsWith('index ') || line.startsWith('new file ') || line.startsWith('deleted file ') || line.startsWith('similarity index ') || line.startsWith('rename from ') || line.startsWith('rename to ')) {
      file.lines.push({ type: 'meta', text: line, old: '', next: '' })
      continue
    }
    const hunk = /^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/.exec(line)
    if (hunk) {
      oldLine = Number(hunk[1]); newLine = Number(hunk[2])
      file.lines.push({ type: 'hunk', text: line, old: '', next: '' })
      continue
    }
    if (line.startsWith('+')) file.lines.push({ type: 'add', text: line.slice(1), old: '', next: newLine++ })
    else if (line.startsWith('-')) file.lines.push({ type: 'delete', text: line.slice(1), old: oldLine++, next: '' })
    else if (line.startsWith(' ')) file.lines.push({ type: 'context', text: line.slice(1), old: oldLine++, next: newLine++ })
    else if (line) file.lines.push({ type: 'meta', text: line, old: '', next: '' })
  }
  return files
}

function GithubDiff({ text }) {
  const files = useMemo(() => parseUnifiedDiff(text), [text])
  if (!text) return <div className="empty compact">No textual diff returned.</div>
  return <div className="github-diff">{files.map((file, fileIndex) => <section className="file-diff" key={`${file.path}-${fileIndex}`}><header><code>{file.path || 'Changed file'}</code></header><pre>{file.lines.map((line, index) => line.type === 'hunk' ? <span className="hunk-head" key={index}>{line.text}</span> : <span className={`diff-line ${line.type}`} key={index}><i>{line.old}</i><i>{line.next}</i><b>{line.type === 'add' ? '+' : line.type === 'delete' ? '-' : ' '}</b><code>{line.text}</code></span>)}</pre></section>)}</div>
}

function GithubDetail({ detail, diff, fallback, kind, error, onBack }) {
  const item = detail || fallback
  return <div className="github-detail">
    <button className="text-button file-back" onClick={onBack}>← {kind === 'Issue' ? 'Issues' : 'Pull requests'}</button>
    <header className="pull-detail-header"><div><h2>#{item.number} {item.title}</h2><p><span className={`status ${item.state === 'open' ? 'good' : ''}`}>{item.draft ? 'draft' : item.merged ? 'merged' : item.state}</span> opened by <strong>{item.author}</strong>{githubDate(item.created) ? ` · ${githubDate(item.created)}` : ''}</p></div>{item.url && <a className="button link-button github-open-link" href={item.url} target="_blank" rel="noreferrer">Open on GitHub ↗</a>}</header>
    {error && <div className="inline-error">{error}</div>}
    {!detail && !error ? <div className="empty">Loading from GitHub…</div> : detail && <>
      {detail.pullRequest && <div className="github-detail-stats"><code>{detail.head || 'head'}</code><span>→</span><code>{detail.base || 'base'}</code><b className="added">+{detail.additions}</b><b className="deleted">−{detail.deletions}</b><span>{detail.changedFiles} files</span></div>}
      <article className="panel github-detail-body"><header><strong>{detail.author}</strong><span>{githubDate(detail.updated) ? `updated ${githubDate(detail.updated)}` : ''}</span></header>{detail.body ? <p>{detail.body}</p> : <div className="empty compact">No description provided.</div>}</article>
      {detail.pullRequest && <GithubDiff text={diff} />}
      <p className="quiet github-detail-footer">{detail.comments} comments{detail.pullRequest && detail.mergeableKnown ? ` · ${detail.mergeable ? 'mergeable' : 'not mergeable'}` : ''}</p>
    </>}
  </div>
}

function Commits({ data, loading, loadingMore, onLoadMore, onSelect, onCreateTag }) {
  if (loading) return <div className="empty">Loading history…</div>
  if (!data?.commits?.length) return <div className="empty">No history yet.</div>
  return (
    <div className="commit-list">
      {data.commits.map((commit) => {
        const clay = commit.kind === 'clay'
        return <div className="commit-row" key={commit.oid}>
          <span className="commit-avatar">{identityLabel(commit.author).slice(0, 1).toUpperCase()}</span>
          <div><strong>{clay ? `Revision ${commit.revision}` : commit.subject || 'Untitled commit'}</strong><small>{commit.author ? identityLabel(commit.author) : (commit.parent ? `parent ${shortOid(commit.parent)}` : 'root commit')}{dateLabel(commit.committer || commit.author) ? ` · ${dateLabel(commit.committer || commit.author)}` : ''}{clay && commit.gitCommit ? ` · Git ${shortOid(commit.gitCommit)}` : ''}</small></div>
          <span className="commit-links">{onCreateTag && <button className="text-button commit-tag-action" onClick={() => onCreateTag(commit)}>Create tag</button>}{clay && commit.gitCommit && <button className="commit-hash mapped-commit" title={`View mapped Git commit ${commit.gitCommit}`} onClick={() => onSelect?.({ oid: commit.gitCommit })}><code>{shortOid(commit.gitCommit)}</code></button>}<button className="commit-hash" title={`View ${commit.oid}`} onClick={() => onSelect?.(commit)} disabled={!onSelect}><code>{historyId(commit)}</code></button></span>
        </div>
      })}
      {data.hasMore && <div className="history-load-more"><button className="button" disabled={loadingMore} onClick={onLoadMore}>{loadingMore ? 'Loading…' : 'Load 50 more'}</button></div>}
    </div>
  )
}

export function CommitDetail({ data, onBack, onOpenGit, onCreateTag }) {
  if (!data) return <div className="empty">Loading commit…</div>
  const commit = data.commit
  const clay = data.historyKind === 'clay' || commit.kind === 'clay'
  return <div className="commit-detail">
    <button className="text-button file-back" onClick={onBack}>← {clay ? 'Revision history' : 'Commit history'}</button>
    <section className="panel commit-summary with-actions"><div className="commit-avatar large">{identityLabel(commit.author).slice(0, 1).toUpperCase()}</div><div><h2>{clay ? `Revision ${commit.revision}` : commit.subject || 'Untitled commit'}</h2><p>{identityLabel(commit.author)} {clay ? 'committed this Clay revision' : `authored · ${identityLabel(commit.committer)} committed`} <span title={dateLabel(commit.committer)}>{dateLabel(commit.committer)}</span></p>{clay ? <div className="clay-revision-meta"><code title="Clay revision">r{commit.revision}</code><code title="Canonical Clay timestamp">{commit.timestampCase}</code><CopyableHash value={commit.tako} />{commit.gitCommit && <button className="commit-hash mapped-commit" title={commit.gitCommit} onClick={() => onOpenGit?.(commit.gitCommit)}><code>Git {shortOid(commit.gitCommit)}</code></button>}</div> : <code>{commit.oid}</code>}</div>{onCreateTag && <button className="button commit-detail-tag" onClick={() => onCreateTag(commit)}>Create tag</button>}</section>
    {!clay && data.message && data.message !== commit.subject && <pre className="commit-message">{data.message}</pre>}
    <DiffView diff={{ changedCount: data.changedCount, base: commit.parent, head: commit.oid, changes: data.changes || [] }} />
  </div>
}

function Settings({ repo, onMutate }) {
  const confirmAction = useConfirm()
  const publicUrl = `${window.location.origin}/apps/urgit/public/${encodeURIComponent(repo.name)}`
  const [description, setDescription] = useState(repo.description || '')
  const [desk, setDesk] = useState(repo.binding?.desk || '')
  const [branch, setBranch] = useState(repo.binding?.branch || repo.head || 'refs/heads/main')
  const [message, setMessage] = useState('Publish Clay desk')
  // a publication to a CI-protected branch is staged, not committed (Q5)
  const [publishNote, setPublishNote] = useState('')
  const [token, setToken] = useState('')
  const [writer, setWriter] = useState('')
  const [reader, setReader] = useState('')
  const [groupFlag, setGroupFlag] = useState(policyFlag(repo.groupPolicy))
  const [groupBase, setGroupBase] = useState(repo.groupPolicy?.base || 'none')
  const [groupRoles, setGroupRoles] = useState(groupRoleRows(repo.groupPolicy))
  const [groups, setGroups] = useState(null) // groups this ship is in; null until the Groups scry answers
  const [groupsError, setGroupsError] = useState('')
  const [busy, setBusy] = useState('')
  const [error, setError] = useState('')
  // the CI policy (which branches require CI, what untrusted revisions
  // get) and the credential names come from %urgit-ci's own routes
  const [ciPolicy, setCiPolicy] = useState(null)
  const [ciError, setCiError] = useState('')
  const [credentials, setCredentials] = useState([])
  // CI-RECOVERY-1: the credential names a restore brought back with no
  // value, which need re-entry
  const [reentry, setReentry] = useState([])
  const [credForm, setCredForm] = useState({ name: '', value: '', scope: 'job', envs: '', multiline: false })
  const [credError, setCredError] = useState('')
  const loadCi = useCallback(async () => {
    try {
      const [policy, creds] = await Promise.all([ci.policy(repo.name), ci.credentials(repo.name)])
      setCiPolicy(policy); setCredentials(creds.credentials || []); setReentry(creds.needsReentry || []); setCiError('')
    } catch (cause) { setCiError(cause.message) }
  }, [repo.name])
  useEffect(() => { loadCi() }, [loadCi])
  async function ciAct(label, body) {
    setBusy(label); setError(''); setCredError('')
    try { await ci.action(body); await loadCi(); await onMutate() } catch (cause) { setError(cause.message) } finally { setBusy('') }
  }
  // the CI required toggle (P3 D5 b, D7): a refusal (no object store, no
  // tip, a desk-linked repository) is shown at the toggle itself; turning
  // it on runs the storage probe, and a red probe is a warning under the
  // toggle, not a refusal — the daemon may still reach the store
  const storageProbe = useStorageProbe()
  const [toggleError, setToggleError] = useState({})
  const [toggleWarning, setToggleWarning] = useState({})
  async function ciRequiredToggle(ref, on) {
    setBusy(`ci-${ref}`); setToggleError((e) => ({ ...e, [ref]: '' })); setToggleWarning((w) => ({ ...w, [ref]: '' }))
    try {
      await ci.action(ciActions.setCiProtected(repo.name, ref, on))
      await loadCi(); await onMutate()
      if (on) {
        const state = await storageProbe.run()
        if (state === 'unreachable' || state === 'cors') setToggleWarning((w) => ({ ...w, [ref]: probeMessage(state, storageProbe.host) }))
      }
    } catch (cause) { setToggleError((e) => ({ ...e, [ref]: cause.message })) } finally { setBusy('') }
  }
  async function addCredential(event) {
    event.preventDefault()
    const problem = credentialFormError(credForm)
    if (problem) { setCredError(problem); return }
    setBusy('credential'); setError(''); setCredError('')
    try {
      await ci.action(ciActions.setCredential(repo.name, credForm.name.trim(), credForm.value, credForm.scope, parseEnvs(credForm.envs)))
      await loadCi()
    } catch (cause) { setCredError(cause.message) } finally {
      // the value never outlives the submit: the field is cleared whatever happened
      setCredForm((form) => ({ ...form, value: '' }))
      setBusy('')
    }
  }
  const [syncResult, setSyncResult] = useState('')
  const [githubTitle, setGithubTitle] = useState('')
  const [githubHead, setGithubHead] = useState('')
  const [githubBase, setGithubBase] = useState((repo.head || 'refs/heads/main').replace('refs/heads/', ''))
  const [githubBranch, setGithubBranch] = useState(repo.head || 'refs/heads/main')
  const [bridgeStatus, setBridgeStatus] = useState(null)
  const [lfsGc, setLfsGc] = useState(null)

  useEffect(() => {
    setDescription(repo.description || '')
    setDesk(repo.binding?.desk || '')
    setBranch(repo.binding?.branch || repo.head || 'refs/heads/main')
    setGithubBranch(repo.head || 'refs/heads/main')
    setGroupFlag(policyFlag(repo.groupPolicy))
    setGroupBase(repo.groupPolicy?.base || 'none')
    setGroupRoles(groupRoleRows(repo.groupPolicy))
  }, [repo])

  useEffect(() => {
    let stale = false
    setGroups(null)
    setGroupsError('')
    api.listGroups(repo.owner).then(
      (list) => { if (!stale) setGroups(list) },
      (cause) => { if (!stale) setGroupsError(cause.message) },
    )
    return () => { stale = true }
  }, [repo.owner])

  const groupsReady = Boolean(groups) && !groupsError
  const selectedGroup = findGroup(groups, groupFlag)
  const savedGroup = findGroup(groups, policyFlag(repo.groupPolicy))
  const nextRole = roleOptions(selectedGroup, groupRoles)[0]
  const staleRoles = selectedGroup ? groupRoles.filter((row) => !selectedGroup.roles.some((role) => role.id === row.role)) : []
  const canSaveGroupPolicy = groupsReady && Boolean(selectedGroup) && !staleRoles.length

  // switching groups drops the role rows: ids belong to one group; the saved rows come back with the saved group
  function chooseGroup(flag) {
    setGroupFlag(flag)
    setGroupRoles(flag && flag === policyFlag(repo.groupPolicy) ? groupRoleRows(repo.groupPolicy) : [])
  }

  function updateGroupRole(index, patch) {
    setGroupRoles((rows) => rows.map((row, at) => (at === index ? { ...row, ...patch } : row)))
  }

  function saveGroupPolicy() {
    const roles = Object.fromEntries(groupRoles.filter((row) => row.role).map((row) => [row.role, row.capability]))
    return act('group-policy', () => api.setGroupPolicy(repo.name, { host: selectedGroup.host, group: selectedGroup.slug, base: groupBase, roles }))
  }

  async function loadBridgeStatus() {
    if (!repo.binding?.bound) { setBridgeStatus(null); return }
    try {
      setBridgeStatus(await api.clayStatus(repo.name))
    } catch {
      setBridgeStatus(null)
    }
  }

  useEffect(() => {
    loadBridgeStatus()
  }, [repo.name, repo.binding?.bound, repo.binding?.desk, repo.binding?.branch, repo.binding?.lastClay, repo.binding?.lastGit])

  async function act(label, fn) {
    setBusy(label)
    setError('')
    try {
      await fn()
      await onMutate()
      await loadBridgeStatus()
    } catch (cause) {
      setError(cause.message)
    } finally {
      setBusy('')
    }
  }

  async function pushToOrigin() {
    setBusy('peer-push')
    setError('')
    setSyncResult('Offering update to origin…')
    try {
      const started = await api.peerPush(repo.name)
      const transfer = await waitForPeerTransfer(started.transfer, {
        onProgress: (current) => current.message && setSyncResult(current.message),
      })
      await api.peerDeleteTransfer(started.transfer).catch(() => {})
      if (!transfer.ok) throw new Error(transfer.message)
      setSyncResult(transfer.message)
      await onMutate()
      return
    } catch (cause) {
      setError(cause.message)
      setSyncResult('')
    } finally {
      setBusy('')
    }
  }

  async function pullFromOrigin() {
    setBusy('peer-pull')
    setError('')
    setSyncResult('Requesting the latest origin snapshot…')
    try {
      const started = await api.peerFork(repo.peerOrigin.ship, repo.peerOrigin.repository, repo.name, repo.publicRead)
      const transfer = await waitForPeerTransfer(started.transfer, {
        onProgress: (current) => current.message && setSyncResult(current.message),
      })
      await api.peerDeleteTransfer(started.transfer).catch(() => {})
      if (!transfer.ok) throw new Error(transfer.message)
      setSyncResult(transfer.message || 'Fork updated from its origin.')
      await onMutate()
    } catch (cause) {
      setError(cause.message)
      setSyncResult('')
    } finally {
      setBusy('')
    }
  }

  async function githubAction(label, start, kinds) {
    setBusy(label); setError(''); setSyncResult('Starting GitHub request…')
    try {
      const before = await api.githubStatus()
      const prior = new Set((before.jobs || []).map((job) => job.job))
      await start()
      for (let attempt = 0; attempt < 90; attempt += 1) {
        await new Promise((resolve) => setTimeout(resolve, 800))
        const status = await api.githubStatus()
        const matching = (status.jobs || []).filter((job) => !prior.has(job.job) && job.repository === repo.name && kinds.includes(job.kind))
        if (matching.some((job) => job.active)) { setSyncResult(matching.find((job) => job.active)?.message || 'Working…'); continue }
        const failed = matching.find((job) => !job.ok)
        if (failed) throw new Error(failed.message)
        if (matching.length) { setSyncResult(matching.map((job) => job.message).join(' · ')); await onMutate(); return }
      }
      throw new Error('GitHub operation did not finish in time')
    } catch (cause) { setError(cause.message); setSyncResult('') } finally { setBusy('') }
  }

  async function scanLfs() {
    setBusy('lfs-scan'); setError('')
    try { setLfsGc(await api.lfsGcPreview(repo.name)) } catch (cause) { setError(cause.message) } finally { setBusy('') }
  }

  async function collectLfs() {
    if (!await confirmAction({ title: 'Delete unreferenced LFS objects?', message: `${lfsGc?.candidateCount || 0} object${lfsGc?.candidateCount === 1 ? '' : 's'} will be removed from ship storage.`, detail: 'Only payloads not reachable from an advertised ref are eligible.', confirmLabel: 'Delete objects' })) return
    setBusy('lfs-gc'); setError('')
    try {
      const started = await api.lfsGc(repo.name)
      setSyncResult(`${started.scheduled} object deletions scheduled`)
      for (let attempt = 0; attempt < 20; attempt += 1) {
        await new Promise((resolve) => setTimeout(resolve, 500))
        const preview = await api.lfsGcPreview(repo.name)
        setLfsGc(preview)
        if (preview.candidateCount === 0) break
      }
      await onMutate()
    } catch (cause) { setError(cause.message) } finally { setBusy('') }
  }

  return (
    <div className="settings-grid">
      {error && <div className="inline-error">{error}</div>}
      <section className="panel">
        <div className="section-title"><div><h2>Repository details</h2><p>Shown on this ship and when other ships browse the repository.</p></div></div>
        <label><span>Description</span><div className="inline-field"><input maxLength="500" value={description} onChange={(event) => setDescription(event.target.value)} placeholder="What is this repository for?" /><button className="button" disabled={busy || description === (repo.description || '')} onClick={() => act('description', () => api.setDescription(repo.name, description.trim()))}>{busy === 'description' ? 'Saving…' : 'Save'}</button></div></label>
      </section>
      <section className="panel">
        <div className="section-title"><div><h2>Notifications</h2></div><span className={(repo.notificationEvents || []).length ? 'status good' : 'status'}>{(repo.notificationEvents || []).length ? `${repo.notificationEvents.length} enabled` : 'muted'}</span></div>
        <div className="event-grid notification-event-grid">
          {notificationEvents.map(([eventName, label, detail]) => {
            const checked = (repo.notificationEvents || []).includes(eventName)
            return <label className="check-row compact" key={eventName}><input type="checkbox" disabled={!!busy} checked={checked} onChange={(event) => {
              const next = new Set(repo.notificationEvents || [])
              if (event.target.checked) next.add(eventName); else next.delete(eventName)
              act(`notification-${eventName}`, () => api.setNotifications(repo.name, [...next]))
            }} /><span><strong>{label}</strong><small>{detail}</small></span></label>
          })}
        </div>
        <small className="quiet">Uncheck all to mute.</small>
      </section>
      {repo.peerOrigin && <section className="panel">
        <div className="section-title"><div><h2>Native origin</h2><p>Forked from <code>{repo.peerOrigin.ship}/{repo.peerOrigin.repository}</code> over the Urbit network.</p></div></div>
        <div className="form-actions split"><small className="quiet">{syncResult || 'Pull the latest snapshot, or push changes when the origin grants this ship write access.'}</small><div className="row-actions"><button className="button" disabled={busy} onClick={pullFromOrigin}>{busy === 'peer-pull' ? 'Pulling…' : 'Pull from origin'}</button><button className="button primary" disabled={busy} onClick={pushToOrigin}>{busy === 'peer-push' ? 'Syncing…' : 'Push to origin'}</button></div></div>
      </section>}
      {repo.githubOrigin && <section className="panel github-panel">
        <div className="section-title"><div><h2>GitHub origin</h2><p>Linked to <a href={`https://github.com/${repo.githubOrigin.owner}/${repo.githubOrigin.repository}`} target="_blank" rel="noreferrer">{repo.githubOrigin.owner}/{repo.githubOrigin.repository}</a>. Code is fetched with Git Smart HTTP; forge data uses GitHub’s API.</p></div><span className="status good">linked</span></div>
        <label><span>Branch</span><select value={githubBranch} onChange={(event) => setGithubBranch(event.target.value)}>{(repo.refs || []).filter((ref) => ref.name.startsWith('refs/heads/')).map((ref) => <option value={ref.name} key={ref.name}>{ref.name.replace('refs/heads/', '')}</option>)}</select></label>
        <div className="github-action-grid">
          <button className="button" disabled={busy} onClick={() => githubAction('github-pull', () => api.githubImport(repo.githubOrigin.owner, repo.githubOrigin.repository, repo.name, repo.publicRead), ['import', 'update'])}>{busy === 'github-pull' ? 'Pulling…' : 'Pull from GitHub'}</button>
          <button className="button primary" disabled={busy || !githubBranch} onClick={() => githubAction('github-push', () => api.githubPush(repo.name, githubBranch), ['push', 'push-send'])}>{busy === 'github-push' ? 'Pushing…' : 'Push to GitHub'}</button>
          <button className="button" disabled={busy} onClick={() => githubAction('github-meta', () => Promise.all([api.githubMetadata(repo.name, 'issues'), api.githubMetadata(repo.name, 'pulls')]), ['issues', 'pulls'])}>{busy === 'github-meta' ? 'Syncing…' : 'Sync issues & PRs'}</button>
          <button className="button" disabled={busy} onClick={() => githubAction('github-fork', () => api.githubFork(repo.name), ['fork'])}>{busy === 'github-fork' ? 'Requesting…' : 'Fork on GitHub'}</button>
        </div>
        <div className="subsection"><div className="section-title"><div><h3>Open GitHub pull request</h3><p>The head must already exist on GitHub, such as <code>your-name:branch</code>.</p></div></div>
          <div className="three-fields"><label><span>Title</span><input value={githubTitle} onChange={(event) => setGithubTitle(event.target.value)} /></label><label><span>Head</span><input value={githubHead} onChange={(event) => setGithubHead(event.target.value)} placeholder="you:feature" /></label><label><span>Base</span><input value={githubBase} onChange={(event) => setGithubBase(event.target.value)} /></label></div>
          <div className="form-actions"><button className="button primary" disabled={busy || !githubTitle.trim() || !githubHead.trim() || !githubBase.trim()} onClick={() => githubAction('github-pr', () => api.githubPull(repo.name, githubTitle.trim(), githubHead.trim(), githubBase.trim(), ''), ['open-pull'])}>{busy === 'github-pr' ? 'Opening…' : 'Open on GitHub'}</button></div>
        </div>
        {syncResult && <div className="transfer-status">{syncResult}</div>}
      </section>}
      <section className="panel">
        <div className="section-title"><div><h2>Clay bridge</h2><p>Keep a Git branch and a Clay desk synchronized in either direction.</p></div><span className={repo.binding?.bound ? 'status good' : 'status'}>{repo.binding?.bound ? 'bound' : 'unbound'}</span></div>
        {repo.binding?.bound ? (
          <>
            <div className="binding-card"><span>Desk</span><code>{repo.binding.desk}</code><span>Branch</span><code>{repo.binding.branch}</code></div>
            {bridgeStatus && <div className={`bridge-state ${bridgeStatus.relation}`}>
              <div><span className="bridge-state-label">{({ 'in-sync': 'In sync', 'git-ahead': 'Git ahead', 'clay-ahead': 'Clay ahead', diverged: 'Diverged', unmapped: 'Not synchronized' })[bridgeStatus.relation] || bridgeStatus.relation}</span><small>{bridgeStatus.contentsMatch ? 'The branch and desk contain the same bytes.' : bridgeStatus.canonicalDifference ? 'Synchronized; Clay canonicalized one or more file representations.' : 'The branch and desk contain different files.'}</small></div>
              <dl><div><dt>Clay</dt><dd><code>r{bridgeStatus.clayRevision}</code></dd></div><div><dt>Git</dt><dd><code title={bridgeStatus.branchCommit}>{bridgeStatus.branchCommit ? shortOid(bridgeStatus.branchCommit) : 'no head'}</code></dd></div></dl>
            </div>}
            {!!repo.binding.history?.length && <div className="clay-history"><div className="table-head"><span>Clay revision ↔ Git commit</span><span>Direction</span></div>{repo.binding.history.map((link) => <button type="button" className="table-row" key={`${link.clayRevision}-${link.commit}`} title={link.when}><span><b>r{link.clayRevision}</b><code>{shortOid(link.commit)}</code></span><span className="quiet">{link.direction === 'clay-to-git' ? 'Clay → Git' : 'Git → Clay'}</span></button>)}</div>}
            <label><span>Commit message</span><input value={message} onChange={(e) => setMessage(e.target.value)} /></label>
            <div className="bridge-actions">
              <button className="button" disabled={busy || bridgeStatus?.contentsMatch || !bridgeStatus?.canApply} onClick={() => act('apply-clay', () => api.applyToClay(repo.name))}>{busy === 'apply-clay' ? 'Applying…' : 'Apply branch to desk'}</button>
              <button className="button primary" disabled={busy || !message.trim() || bridgeStatus?.contentsMatch} onClick={() => act('publish', async () => { setPublishNote(''); setPublishNote(stagedPublishNote(await api.publish(repo.name, message.trim()))) })}>{busy === 'publish' ? 'Publishing…' : 'Publish desk to branch'}</button>
            </div>
            {publishNote && <div className="field-note">{publishNote}</div>}
            <div className="form-actions split bridge-footer">
              <small className="quiet">Clay rejects invalid desk updates and returns the build trace.</small>
              <button className="button ghost danger-text" disabled={busy} onClick={() => act('unbind', () => api.unbind(repo.name))}>Unbind</button>
            </div>
          </>
        ) : (
          <>
            <div className="two-fields">
              <label><span>Desk</span><input value={desk} onChange={(e) => setDesk(e.target.value)} placeholder="my-desk" /></label>
              <label><span>Branch ref</span><input value={branch} onChange={(e) => setBranch(e.target.value)} /></label>
            </div>
            <div className="form-actions"><button className="button primary" disabled={busy || !desk.trim() || !branch.trim()} onClick={() => act('bind', () => api.bind(repo.name, desk.trim(), branch.trim()))}>{busy === 'bind' ? 'Binding…' : 'Bind desk'}</button></div>
          </>
        )}
      </section>
      <section className="panel">
        <div className="section-title"><div><h2>Access</h2><p>Public controls clone/fetch. A token permits authenticated pushes over Smart HTTP.</p></div></div>
        <label className="check-row">
          <input type="checkbox" checked={repo.publicRead} onChange={(e) => act('public', () => api.setPublic(repo.name, e.target.checked))} />
          <span><strong>Public read access</strong><small>{repo.publicRead ? 'Clone and fetch are open.' : 'Urbit authentication is required.'}</small></span>
        </label>
        {repo.publicRead && <div className="form-actions split"><code className="public-url">{publicUrl}</code><div><button className="button" onClick={() => navigator.clipboard.writeText(publicUrl)}>Copy public link</button> <a className="button link-button" href={publicUrl} target="_blank" rel="noreferrer">Open</a></div></div>}
        <label><span>Write token</span><div className="inline-field"><input type="password" value={token} onChange={(e) => setToken(e.target.value)} placeholder={repo.writeTokenSet ? 'Token is set' : 'Set a Git password'} /><button className="button" disabled={busy || !token} onClick={() => act('token', async () => { await api.setToken(repo.name, token); setToken('') })}>Save</button></div></label>
        {repo.writeTokenSet && <button className="text-button danger-text" onClick={() => act('clear-token', () => api.clearToken(repo.name))}>Clear write token</button>}
        <div className="subsection">
          <div className="section-title"><div><h3>Ship readers</h3><p>Readers can discover, browse, and fork this private repository through Urgit, but cannot send updates. Writers already have read access.</p></div></div>
          <div className="inline-field"><input value={reader} onChange={(e) => setReader(e.target.value)} placeholder="~sampel-palnet" /><button className="button" disabled={busy || !reader.trim()} onClick={() => act('reader', async () => { await api.setReader(repo.name, reader.trim(), true); setReader('') })}>Grant</button></div>
          <div className="writer-list">
            {(repo.readers || []).map((ship) => <div key={ship}><code>{ship}</code><button className="text-button danger-text" onClick={() => act(`reader-${ship}`, () => api.setReader(repo.name, ship, false))}>Revoke</button></div>)}
            {!repo.readers?.length && <small className="quiet">No remote readers.</small>}
          </div>
        </div>
        <div className="subsection">
          <div className="section-title"><div><h3>Ship writers</h3><p>Authorized ships can send verified, fast-forward updates from native forks.</p></div></div>
          <div className="inline-field"><input value={writer} onChange={(e) => setWriter(e.target.value)} placeholder="~sampel-palnet" /><button className="button" disabled={busy || !writer.trim()} onClick={() => act('writer', async () => { await api.setWriter(repo.name, writer.trim(), true); setWriter('') })}>Grant</button></div>
          <div className="writer-list">
            {(repo.writers || []).map((ship) => <div key={ship}><code>{ship}</code><button className="text-button danger-text" onClick={() => act(`writer-${ship}`, () => api.setWriter(repo.name, ship, false))}>Revoke</button></div>)}
            {!repo.writers?.length && <small className="quiet">No remote writers.</small>}
          </div>
        </div>
        <div className="subsection">
          <div className="section-title"><div><h3>Group access</h3><p>Members of a group this ship is in, hosted here or elsewhere, can read or send fast-forward updates by role. Members with no roles get the base capability. Explicit readers and writers still apply.</p></div>{repo.groupPolicy && <span className={`status ${groupsReady && !savedGroup ? 'warn' : 'good'}`}>{describeGroup(groups, repo.groupPolicy)}</span>}</div>
          {repo.groupPolicy && <p className="group-policy-saved">Saved: <strong>{describeGroup(groups, repo.groupPolicy)}</strong> · members with no roles: {capabilityLabels[repo.groupPolicy.base]}{groupRoleRows(repo.groupPolicy).map((row) => <span key={row.role}> · {describeRole(savedGroup, row.role)}: {capabilityLabels[row.capability]}</span>)}</p>}
          {groupsError && <small className="field-error">{groupsError.startsWith('Groups unavailable') ? groupsError : `Groups unavailable: ${groupsError}`}</small>}
          <label><span>Group</span><select value={groupFlag} disabled={!groupsReady} onChange={(e) => chooseGroup(e.target.value)}>
            <option value="">{groupsError ? 'Groups unavailable' : !groups ? 'Loading groups…' : groups.length ? 'Choose a group this ship is in' : 'This ship is in no groups'}</option>
            {groupFlag && !selectedGroup && <option value={groupFlag}>{groupsReady ? `missing group \`${groupFlag}\`` : groupFlag}</option>}
            {(groups || []).map((group) => <option key={group.flag} value={group.flag}>{group.title} ({group.flag}, {describeHost(group)})</option>)}
          </select></label>
          <label><span>Members with no roles</span><select value={groupBase} onChange={(e) => setGroupBase(e.target.value)}>{groupCapabilities.map((capability) => <option key={capability} value={capability}>{capabilityLabels[capability]}</option>)}</select></label>
          <div className="writer-list group-role-list">
            {groupRoles.map((row, index) => {
              const options = roleOptions(selectedGroup, groupRoles, row.role)
              return <div key={index}>
                <select value={row.role} disabled={!groupsReady} onChange={(e) => updateGroupRole(index, { role: e.target.value })}>
                  {!options.some((role) => role.id === row.role) && <option value={row.role}>{describeRole(selectedGroup, row.role)}</option>}
                  {options.map((role) => <option key={role.id} value={role.id}>{role.title} ({role.id})</option>)}
                </select>
                <select value={row.capability} onChange={(e) => updateGroupRole(index, { capability: e.target.value })}>{groupCapabilities.map((capability) => <option key={capability} value={capability}>{capabilityLabels[capability]}</option>)}</select>
                <button className="text-button danger-text" onClick={() => setGroupRoles((rows) => rows.filter((_, at) => at !== index))}>Remove</button>
              </div>
            })}
            {!groupRoles.length && <small className="quiet">No roles mapped; unmapped roles grant nothing.</small>}
            {staleRoles.length > 0 && <small className="field-error">Remove the missing roles before saving.</small>}
          </div>
          <div className="form-actions split"><button className="text-button" disabled={!nextRole} onClick={() => setGroupRoles((rows) => [...rows, { role: nextRole.id, capability: 'read' }])}>Add role</button><div>{repo.groupPolicy && <button className="text-button danger-text" onClick={() => act('clear-group-policy', () => api.setGroupPolicy(repo.name, null))}>Clear</button>} <button className="button" disabled={busy || !canSaveGroupPolicy} onClick={saveGroupPolicy}>{busy === 'group-policy' ? 'Saving…' : 'Save'}</button></div></div>
        </div>
        <RunnersSection />
        <BranchPolicyList
          part="protected-branches"
          title="Protected branches"
          description="Protected branches accept fast-forward updates, but reject force-pushes and deletion."
          chosen={repo.protectedRefs || []}
          refs={repo.refs || []}
          busy={busy !== ''}
          rowNote="Fast-forward updates only."
          emptyText="No protected branches. Force-push and deletion are allowed on every branch."
          confirm={confirmAction}
          removeConfirm={(label) => ({ title: 'Remove protection?', message: label, detail: 'Force-pushes and deletion of this branch will be allowed again.' })}
          onAdd={(ref) => act(`protected-${ref}`, () => api.setProtected(repo.name, ref, true))}
          onRemove={(ref) => act(`protected-${ref}`, () => api.setProtected(repo.name, ref, false))}
        />
        <BranchPolicyList
          part="ci-required-branches"
          title="CI-required branches"
          description="Pushes and merges to these branches are staged as candidates and land only when the checks pass."
          chosen={ciPolicy?.ciProtected || []}
          refs={repo.refs || []}
          busy={busy !== ''}
          disabled={!ciPolicy}
          rowNote="Lands only when the checks pass."
          rowMessages={(ref) => [
            toggleError[ref] && { text: toggleError[ref], className: 'field-error' },
            toggleWarning[ref] && { text: toggleWarning[ref], className: 'field-error ci-toggle-warning' },
          ].filter(Boolean)}
          emptyText="No branch requires CI. Pushes land without checks."
          confirm={confirmAction}
          removeConfirm={(label) => ({ title: 'Stop requiring CI?', message: label, detail: 'Pushes and merges to this branch will land at once, without checks.' })}
          onAdd={(ref) => ciRequiredToggle(ref, true)}
          onRemove={(ref) => ciRequiredToggle(ref, false)}
        />
        {ciError && <small className="field-error">CI settings unavailable: {ciError}</small>}
        {Object.entries(toggleError).filter(([ref, text]) => text && !(ciPolicy?.ciProtected || []).includes(ref)).map(([ref, text]) => <small key={ref} className="field-error" data-part="ci-add-error">Could not require CI on {ref.replace('refs/heads/', '')}: {text}</small>)}
        <div className="subsection">
          <div className="section-title"><div><h3>Untrusted revisions</h3><p>A revision from a ship that cannot write this repository, such as a fork pull request, is untrusted.</p></div></div>
          <div className="ci-radio">
            {[['approval', 'Wait for approval', 'It runs nothing until a writer approves it on the CI tab.'], ['restricted', 'Run restricted checks', 'It runs at once with no credentials and can never land; approval still runs it trusted.']].map(([value, title, detail]) => (
              <label className="check-row compact" key={value}><input type="radio" name={`untrusted-${repo.name}`} value={value} checked={(ciPolicy?.untrusted || repo.ciUntrustedPolicy || 'approval') === value} disabled={busy !== '' || !ciPolicy} onChange={() => ciAct('untrusted', ciActions.setUntrustedPolicy(repo.name, value))} /><span><strong>{title}</strong><small>{detail}</small></span></label>
            ))}
          </div>
        </div>
        <div className="subsection">
          <div className="section-title"><div><h3>Credentials</h3><p>Released to trusted jobs only, as secrets. A job-scoped credential reaches every trusted job; an env-scoped one only jobs whose <code>environment</code> is listed. Values are never shown again.</p></div></div>
          <div className="writer-list">
            {credentials.map((cred) => <div key={cred.name}><code>{cred.name}</code><small className="quiet">{cred.scope}{cred.scope === 'env' ? `: ${(cred.envs || []).join(', ')}` : ''}</small><button className="text-button danger-text" disabled={busy !== ''} onClick={() => ciAct(`cred-${cred.name}`, ciActions.deleteCredential(repo.name, cred.name))}>Delete</button></div>)}
            {reentry.map((cred) => <div key={`reentry-${cred.name}`} data-part="credential-reentry"><code>{cred.name}</code><small className="field-error">needs re-entry: a restore brought back its name with no value</small></div>)}
            {!credentials.length && !reentry.length && <small className="quiet">No credentials stored.</small>}
          </div>
          <form className="ci-credential-form" onSubmit={addCredential} autoComplete="off">
            <div className="three-fields">
              <label><span>Name</span><input value={credForm.name} onChange={(e) => setCredForm({ ...credForm, name: e.target.value })} placeholder="NPM_TOKEN" /></label>
              <label><span>Value</span>{credForm.multiline ? <textarea rows={4} className="ci-secret" value={credForm.value} autoComplete="off" spellCheck={false} onChange={(e) => setCredForm({ ...credForm, value: e.target.value })} /> : <input type="password" value={credForm.value} autoComplete="new-password" onChange={(e) => setCredForm({ ...credForm, value: e.target.value })} />}<small className="quiet"><label className="check-row compact"><input type="checkbox" checked={credForm.multiline} onChange={(e) => setCredForm({ ...credForm, multiline: e.target.checked })} /><span>Multi-line value (a PEM key pastes as is; every line is masked in logs)</span></label></small></label>
              <label><span>Scope</span><select value={credForm.scope} onChange={(e) => setCredForm({ ...credForm, scope: e.target.value })}><option value="job">Every trusted job</option><option value="env">Named environments</option></select></label>
            </div>
            {credForm.scope === 'env' && <label><span>Environments</span><input value={credForm.envs} onChange={(e) => setCredForm({ ...credForm, envs: e.target.value })} placeholder="staging, production" /></label>}
            {credError && <small className="field-error">{credError}</small>}
            <div className="form-actions"><button className="button" type="submit" disabled={busy !== ''}>{busy === 'credential' ? 'Storing…' : 'Add credential'}</button></div>
          </form>
        </div>
        {ciPolicy && <CiPolicySection repo={repo} policy={ciPolicy} onChanged={async () => { await loadCi(); await onMutate() }} />}
      </section>
      <section className="panel">
        <div className="section-title"><div><h2>Git LFS storage</h2><p>Locks protect shared binary paths. Cleanup removes verified payloads that no advertised ref can reach.</p></div><span className="status">{repo.lfsLockCount || 0} locks</span></div>
        {lfsGc && <div className="binding-card"><span>Unreferenced objects</span><strong>{lfsGc.candidateCount}</strong><span>Bytes eligible</span><strong title={`${lfsGc.candidateBytes} bytes`}>{formatBytes(lfsGc.candidateBytes)}</strong></div>}
        <div className="form-actions split"><small className="quiet">Cleanup is explicit and deletes at most 100 object-store payloads per run.</small><div><button className="button" disabled={busy} onClick={scanLfs}>{busy === 'lfs-scan' ? 'Scanning…' : 'Scan'}</button>{lfsGc?.candidateCount > 0 && <button className="button danger" disabled={busy} onClick={collectLfs}>{busy === 'lfs-gc' ? 'Deleting…' : 'Delete unreferenced'}</button>}</div></div>
      </section>
      <section className="panel danger-zone">
        <div><h2>Delete repository</h2><p>Remove refs, Git objects, binding metadata, and LFS pointers held by this repository.</p></div>
        <button className="button danger" onClick={async () => { if (await confirmAction({ title: 'Delete repository?', message: repo.name, detail: 'Refs, Git objects, binding metadata, and LFS pointers held by this repository will be removed.', confirmLabel: 'Delete repository' })) act('delete', () => api.remove(repo.name)) }}>Delete</button>
      </section>
    </div>
  )
}

export default function RepositoryView({ repo, onRefresh, onOpenOrigin, publicMode = false, client = api }) {
  const initialRoute = routeForRepository(repo)
  const [tab, setTab] = useState(initialRoute.tab)
  const [filePath, setFilePath] = useState(initialRoute.filePath)
  const [lineStart, setLineStart] = useState(initialRoute.lineStart)
  const [lineEnd, setLineEnd] = useState(initialRoute.lineEnd)
  const [branch, setBranch] = useState(initialRoute.branch)
  const [commitOid, setCommitOid] = useState(initialRoute.commitOid)
  const [branchCreate, setBranchCreate] = useState(initialRoute.branchCreate)
  const [tagTarget, setTagTarget] = useState(initialRoute.tagTarget)
  const [tagKind, setTagKind] = useState(initialRoute.tagKind)
  const [pull, setPull] = useState(initialRoute.pull)
  const [searchQuery, setSearchQuery] = useState(initialRoute.searchQuery)
  const [searchDraft, setSearchDraft] = useState(initialRoute.searchQuery)
  const [searchData, setSearchData] = useState(null)
  const [searchLoading, setSearchLoading] = useState(false)
  const [searchError, setSearchError] = useState('')
  const [creatingFile, setCreatingFile] = useState(false)
  const [detail, setDetail] = useState(null)
  const [loading, setLoading] = useState(true)
  const [commitDetail, setCommitDetail] = useState(null)
  const [commitLoading, setCommitLoading] = useState(false)
  const [historyLoadingMore, setHistoryLoadingMore] = useState(false)
  const cloneUrl = `${window.location.origin}/git/${repo.name}.git`
  const historyData = tab === 'code' ? detail?.commits : tab === 'commits' ? detail : null
  const clayHistory = historyData?.historyKind === 'clay' || (repo.binding?.bound && branch === repo.binding.branch)
  const revisionCount = historyData?.revisionCount
  const loadReadme = useCallback((path) => client.file(repo.name, path, branch), [client, repo.name, branch])

  function applyRoute(route) {
    setTab(route.tab)
    setBranch(route.branch)
    setFilePath(route.filePath)
    setLineStart(route.lineStart)
    setLineEnd(route.lineEnd)
    setCommitOid(route.commitOid)
    setBranchCreate(route.branchCreate)
    setTagTarget(route.tagTarget)
    setTagKind(route.tagKind)
    setPull(route.pull || 0)
    setSearchQuery(route.searchQuery)
    setSearchDraft(route.searchQuery)
  }

  function navigate(changes, replace = false) {
    const route = { tab, branch, filePath, lineStart, lineEnd, commitOid, branchCreate, tagTarget, tagKind, pull, searchQuery, ...changes }
    if (Object.hasOwn(changes, 'filePath') && changes.filePath !== filePath && !Object.hasOwn(changes, 'lineStart')) { route.lineStart = null; route.lineEnd = null }
    if (route.tab !== 'code') { route.filePath = ''; route.lineStart = null; route.lineEnd = null; route.searchQuery = '' }
    if (!route.filePath) { route.lineStart = null; route.lineEnd = null }
    if (route.tab !== 'commits') route.commitOid = ''
    if (route.tab !== 'branches') route.branchCreate = false
    if (route.tab !== 'tags') { route.tagTarget = ''; route.tagKind = '' }
    if (route.tab !== 'pulls') route.pull = 0
    history[replace ? 'replaceState' : 'pushState']({}, '', repositoryHash(repo, route))
    applyRoute(route)
  }

  useEffect(() => {
    let active = true
    setLoading(true)
    setDetail(null)
    const branchExists = (repo.refs || []).some((ref) => ref.name === branch)
    const emptyCommits = { repository: repo.name, head: branch, commits: [] }
    const emptyFiles = { repository: repo.name, head: branch, commit: '', files: [] }
    const load = !branchExists
      ? Promise.resolve(tab === 'commits' ? emptyCommits : tab === 'code' ? { files: emptyFiles, commits: emptyCommits } : null)
      : tab === 'commits'
        ? client.commits(repo.name, branch, 0, 50)
        : tab === 'code'
          ? Promise.all([client.files(repo.name, branch), client.commits(repo.name, branch, 0, 1)]).then(([files, commits]) => ({ files, commits }))
          : Promise.resolve(null)
    load.then((data) => active && setDetail(data)).finally(() => active && setLoading(false))
    return () => { active = false }
  }, [repo.name, repo.refs, tab, branch, client])

  useEffect(() => {
    let active = true
    setSearchData(null)
    setSearchError('')
    if (tab !== 'code' || searchQuery.length < 2) { setSearchLoading(false); return () => { active = false } }
    setSearchLoading(true)
    client.search(repo.name, searchQuery, branch)
      .then((data) => active && setSearchData(data))
      .catch((cause) => active && setSearchError(cause.message))
      .finally(() => active && setSearchLoading(false))
    return () => { active = false }
  }, [repo.name, tab, branch, searchQuery, client])

  useEffect(() => {
    const restore = () => applyRoute(routeForRepository(repo))
    restore()
    addEventListener('popstate', restore)
    return () => removeEventListener('popstate', restore)
  }, [repo.name, repo.head])

  useEffect(() => {
    let active = true
    setCommitDetail(null)
    if (!commitOid || tab !== 'commits') return () => { active = false }
    setCommitLoading(true)
    client.commit(repo.name, commitOid)
      .then((data) => active && setCommitDetail(data))
      .finally(() => active && setCommitLoading(false))
    return () => { active = false }
  }, [repo.name, tab, commitOid, client])

  function browseBranch(ref) {
    setCreatingFile(false)
    navigate({ branch: ref, filePath: '', tab: 'code', commitOid: '' })
  }

  function openCommit(commit) {
    navigate({ tab: 'commits', filePath: '', commitOid: commit.oid })
  }

  function createTagFrom(commit) {
    const clay = commit.kind === 'clay' || Number(commit.revision) > 0
    navigate({ tab: 'tags', filePath: '', commitOid: '', tagKind: clay ? 'revision' : 'commit', tagTarget: clay ? `r${commit.revision}` : commit.oid })
  }

  async function mutate() {
    await onRefresh?.(repo.name)
  }

  async function loadMoreHistory() {
    if (historyLoadingMore || !detail?.hasMore) return
    setHistoryLoadingMore(true)
    try {
      const next = await client.commits(repo.name, branch, detail.nextOffset || detail.commits?.length || 0, 50)
      setDetail((current) => ({
        ...next,
        commits: [...(current?.commits || []), ...(next.commits || [])],
      }))
    } finally {
      setHistoryLoadingMore(false)
    }
  }

  return (
    <main className="content">
      <header className="repo-header">
        <div><div className="repo-breadcrumb"><span>{repo.owner}</span><b>/</b><h1>{repo.name}</h1><span className="visibility-badge">{repo.publicRead ? 'Public' : 'Private'}</span></div>{repo.description && <p className="repo-description">{repo.description}</p>}{repo.githubOrigin && <a className="origin-link" href={`https://github.com/${repo.githubOrigin.owner}/${repo.githubOrigin.repository}`} target="_blank" rel="noreferrer">GitHub · {repo.githubOrigin.owner}/{repo.githubOrigin.repository} ↗</a>}</div>
        <div className="clone-box"><code>{cloneUrl}</code><button className="icon-button" title="Copy clone URL" onClick={() => navigator.clipboard.writeText(cloneUrl)}><CopyIcon /></button></div>
      </header>
      <div className="repo-meta">
        <span><b>{repo.fileCount || 0}</b> files</span>{clayHistory ? <span><b>{revisionCount ?? '—'}</b> revisions</span> : <span><b>{repo.commitCount || 0}</b> commits</span>}<span><b>{repo.branchCount || 0}</b> branches</span><span><b>{repo.tagCount || 0}</b> tags</span><span title="Large file payloads in ship object storage"><b>{repo.lfsObjectCount || 0}</b> LFS files</span>
        {repo.binding?.bound && <span className="clay-chip">Clay · {repo.binding.desk}</span>}
      </div>
      {!publicMode && (repo.upstreamUpdates || []).length > 0 && <button className="upstream-banner" onClick={() => navigate({ tab: 'webhooks', filePath: '', commitOid: '' })}><span className="activity-dot active" /><span><strong>Upstream has new commits</strong><small>{repo.upstreamUpdates[0].source} pushed {repo.upstreamUpdates[0].ref}</small></span><b>Review and pull →</b></button>}
      <nav className="tabs">
        {(publicMode ? [['code', 'Code'], ['issues', 'Issues', repo.nativeIssues?.length], ['branches', 'Branches', (repo.refs || []).filter((ref) => ref.name.startsWith('refs/heads/')).length], ['tags', 'Tags', repo.tagCount], ['releases', 'Releases', repo.releases?.length], ['commits', clayHistory ? 'Revisions' : 'Commits']] : [['code', 'Code'], ['issues', 'Issues', (repo.nativeIssues?.length || 0) + (repo.githubIssues?.length || 0)], ['pulls', 'Pull requests', (repo.pullRequests?.length || 0) + (repo.githubPulls?.length || 0)], ['branches', 'Branches', (repo.refs || []).filter((ref) => ref.name.startsWith('refs/heads/')).length], ['tags', 'Tags', repo.tagCount], ['releases', 'Releases', repo.releases?.length], ['commits', clayHistory ? 'Revisions' : 'Commits'], ['ci', 'CI'], ['webhooks', 'Webhooks', (repo.upstreamUpdates?.length || 0)], ['settings', 'Settings']]).map(([name, label, count]) => <button key={name} className={tab === name ? 'active' : ''} onClick={() => navigate({ tab: name, filePath: '', commitOid: '' })}><span>{label}</span>{count > 0 && <b className="tab-count">{count}</b>}</button>)}
      </nav>
      <section className="repo-body">
        {tab === 'code' && <div className="branch-context"><select value={branch} onChange={(event) => browseBranch(event.target.value)}>{(repo.refs || []).filter((ref) => ref.name.startsWith('refs/heads/')).map((ref) => <option key={ref.name} value={ref.name}>{ref.name.replace('refs/heads/', '')}</option>)}</select><span>{detail?.files?.files?.length || 0} files</span>{branch !== repo.head && <button className="text-button" onClick={() => browseBranch(repo.head)}>Default branch</button>}{!publicMode && !filePath && !creatingFile && <><button className="button" onClick={() => navigate({ tab: 'branches', filePath: '', branchCreate: true })}>New branch</button><button className="button new-file-button" onClick={() => { setCreatingFile(true); navigate({ searchQuery: '' }, true) }}>New file</button></>}<form className="code-search" onSubmit={(event) => { event.preventDefault(); const query = searchDraft.trim(); if (!query || query.length >= 2) { setCreatingFile(false); navigate({ filePath: '', lineStart: null, lineEnd: null, searchQuery: query }) } }}><input value={searchDraft} maxLength={200} onChange={(event) => setSearchDraft(event.target.value)} placeholder="Search code" aria-label="Search repository code" />{searchQuery && <button type="button" className="text-button" onClick={() => navigate({ searchQuery: '', filePath: '' })}>Clear</button>}</form></div>}
        {tab === 'code' && (creatingFile
          ? <NewFile repository={repo.name} branch={branch} onCancel={() => setCreatingFile(false)} onCreated={async (path) => { setCreatingFile(false); await mutate(); navigate({ filePath: path, searchQuery: '', lineStart: null, lineEnd: null }) }} />
          : filePath
          ? <FileView repository={repo.name} path={filePath} branch={branch} githubOrigin={!publicMode ? repo.githubOrigin : null} lineStart={lineStart} lineEnd={lineEnd} onSelectLine={(selected, extend, dragAnchor) => { const anchor = extend ? (dragAnchor || lineStart || selected) : selected; navigate({ lineStart: Math.min(anchor, selected), lineEnd: Math.max(anchor, selected) }) }} onOpenCommit={(commit) => commit && navigate({ tab: 'commits', filePath: '', commitOid: commit.oid })} editable={!publicMode} onBack={() => navigate({ filePath: '' })} onSaved={mutate} onDeleted={async () => { await mutate(); navigate({ filePath: '', lineStart: null, lineEnd: null }) }} client={client} />
          : searchQuery ? <SearchResults data={searchData} query={searchQuery} loading={searchLoading} error={searchError} onOpen={(result) => navigate({ tab: 'code', filePath: result.path, lineStart: result.line, lineEnd: result.line, commitOid: '' })} />
            : <Files data={detail?.files} commit={branch === repo.head ? detail?.commits?.commits?.[0] : null} loading={loading} onOpen={(path) => navigate({ tab: 'code', filePath: path, commitOid: '' })} onOpenCommit={openCommit} loadFile={loadReadme} />)}
        {tab === 'issues' && <Issues repo={repo} publicMode={publicMode} client={client} onMutate={mutate} />}
        {tab === 'branches' && <Branches repo={repo} publicMode={publicMode} onBrowse={browseBranch} onMutate={mutate} client={client} initialCreate={branchCreate} initialSource={branch} onCreateConsumed={() => navigate({ branchCreate: false }, true)} />}
        {tab === 'tags' && <Tags repo={repo} publicMode={publicMode} onMutate={mutate} initialTarget={tagTarget} initialKind={tagKind} onTargetConsumed={() => navigate({ tagTarget: '', tagKind: '' }, true)} />}
        {tab === 'releases' && <Releases repo={repo} publicMode={publicMode} onMutate={mutate} client={client} />}
        {tab === 'commits' && (commitOid ? commitLoading || !commitDetail ? <div className="empty">Loading commit…</div> : <CommitDetail data={commitDetail} onBack={() => navigate({ commitOid: '' })} onOpenGit={(oid) => navigate({ commitOid: oid })} onCreateTag={!publicMode ? createTagFrom : null} /> : <Commits data={detail} loading={loading} loadingMore={historyLoadingMore} onLoadMore={loadMoreHistory} onSelect={openCommit} onCreateTag={!publicMode ? createTagFrom : null} />)}
        {tab === 'pulls' && <PullRequests repo={repo} onMutate={mutate} onOpenOrigin={onOpenOrigin} initialPull={pull} onPullConsumed={() => navigate({ pull: 0 }, true)} />}
        {tab === 'ci' && <CiTab repo={repo} onMutate={mutate} onOpenPull={(number) => navigate({ tab: 'pulls', pull: number, filePath: '', commitOid: '' })} onSettings={() => navigate({ tab: 'settings', filePath: '', commitOid: '' })} />}
        {tab === 'webhooks' && <Webhooks repo={repo} onMutate={mutate} />}
        {tab === 'settings' && <Settings repo={repo} onMutate={mutate} />}
      </section>
    </main>
  )
}
