import { useCallback, useEffect, useState } from 'react'
import { api, waitForPeerBrowse, waitForPeerForge } from '../api'
import FileTree from './FileTree'
import { CommitDetail, DiffView } from './RepositoryView'
import { HighlightedCode } from './HighlightedCode'
import MarkdownDocument from './MarkdownDocument'
import Readme from './Readme'
import PullLabels from './PullLabels'
import { exactBytes, formatBytes } from '../format'
import { peerTransferPresentation } from '../peerTransfer'
import { useLocalDraft } from '../useLocalDraft'

const shortOid = (oid) => oid ? oid.slice(0, 8) : '—'
const formatDate = (timestamp) => {
  const value = Number(timestamp) * 1000
  return Number.isFinite(value) && value > 0 ? new Date(value).toLocaleString() : ''
}
const decodeBase64 = (content) => {
  const raw = atob(content)
  const bytes = Uint8Array.from(raw, (char) => char.charCodeAt(0))
  let text = null
  try { text = new TextDecoder('utf-8', { fatal: true }).decode(bytes) } catch { /* binary */ }
  return { bytes, text }
}
const imageType = (path) => ({ png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', gif: 'image/gif', webp: 'image/webp', svg: 'image/svg+xml' })[(path.split('.').pop() || '').toLowerCase()]

const remoteRoute = () => {
  const query = location.hash.split('?')[1] || ''
  const params = new URLSearchParams(query)
  const requested = params.get('tab')
  const tab = ['code', 'issues', 'pulls', 'commits', 'branches'].includes(requested) ? requested : 'code'
  const issue = Number(params.get('issue'))
  const pull = Number(params.get('pull'))
  const commitOid = tab === 'commits' ? params.get('commit') || '' : ''
  const filePath = tab === 'code' ? params.get('file') || '' : ''
  if (tab === 'issues' && Number.isInteger(issue) && issue > 0) return { tab, kind: 'issue', number: issue, filePath: '', commitOid: '' }
  if (tab === 'pulls' && Number.isInteger(pull) && pull > 0) return { tab, kind: 'pull', number: pull, filePath: '', commitOid: '' }
  return { tab, kind: '', number: 0, filePath, commitOid }
}

export default function RemoteRepositoryView({ ship, repository, repositories, data, cacheState, onRefresh, onFork, onCancelTransfer }) {
  const repo = data?.repository
  const [tab, setTab] = useState(() => remoteRoute().tab)
  const [selected, setSelected] = useState(null)
  const [filePath, setFilePath] = useState(() => remoteRoute().filePath)
  const [commitOid, setCommitOid] = useState(() => remoteRoute().commitOid)
  const [commitDetail, setCommitDetail] = useState(null)
  const [commitLoading, setCommitLoading] = useState(false)
  const [commitError, setCommitError] = useState('')
  const [detail, setDetail] = useState(null)
  const [detailError, setDetailError] = useState('')
  const commentKey = selected ? `peer-comment:${ship}:${repository}:${selected.kind}:${selected.item.number}` : ''
  const [comment, setComment, clearComment] = useLocalDraft(commentKey)
  const [commentBusy, setCommentBusy] = useState(false)
  const [commentCounts, setCommentCounts] = useState({})
  const [createdIssues, setCreatedIssues] = useState([])
  const [issueCreating, setIssueCreating] = useState(false)
  const [issueTitle, setIssueTitle, clearIssueTitle] = useLocalDraft(`peer-issue:${ship}:${repository}:title`)
  const [issueBody, setIssueBody, clearIssueBody] = useLocalDraft(`peer-issue:${ship}:${repository}:body`)
  const [issueBusy, setIssueBusy] = useState(false)
  const [issueError, setIssueError] = useState('')
  const [forking, setForking] = useState(false)
  const [cancelling, setCancelling] = useState(false)
  const [transfer, setTransfer] = useState('')
  const [progress, setProgress] = useState(null)
  const [forkDialog, setForkDialog] = useState(false)
  const [localName, setLocalName] = useState(repository)
  const [forkTarget, setForkTarget] = useState(repository)
  const [publicRead, setPublicRead] = useState(true)
  async function inspect(kind, item, pushHistory = true) {
    if (!item) return
    setSelected({ kind, item }); setFilePath(''); setCommitOid(''); setCommitDetail(null); setCommitError(''); setDetail(null); setDetailError('')
    if (pushHistory) {
      const key = kind === 'issue' ? 'issue' : 'pull'
      history.pushState({}, '', `#/peer/${encodeURIComponent(ship)}/${encodeURIComponent(repository)}?tab=${kind === 'issue' ? 'issues' : 'pulls'}&${key}=${item.number}`)
    }
    let request = ''
    try {
      const started = await api.peerDetail(ship, repository, kind, item.number)
      request = started.request
      const found = await waitForPeerBrowse(request)
      if (!found.ok) throw new Error(found.message || `Could not load ${kind}`)
      const result = found.result?.[kind]
      setDetail(result ? { ...result, labelsEditable: kind === 'pull' && found.result.labelsEditable === true } : null)
    } catch (cause) {
      setDetailError(cause.message)
    } finally {
      if (request) api.peerDeleteBrowse(request).catch(() => {})
    }
  }
  async function saveLabels(labels) {
    let request = ''
    try {
      const started = await api.peerPullLabels(ship, repository, selected.item.number, labels)
      request = started.request
      const found = await waitForPeerForge(request)
      if (!found.ok) throw new Error(found.message || 'The repository owner refused the labels')
      if (found.result) setDetail({ ...found.result, labelsEditable: true })
      return { labels: found.result?.labels || labels }
    } finally {
      if (request) api.peerDeleteForgeRequest(request).catch(() => {})
    }
  }
  async function inspectCommit(commit, pushHistory = true) {
    const oid = typeof commit === 'string' ? commit : commit?.oid
    if (!oid) return
    setTab('commits'); setSelected(null); setFilePath(''); setCommitOid(oid); setCommitDetail(null); setCommitError(''); setCommitLoading(true)
    if (pushHistory) history.pushState({}, '', `#/peer/${encodeURIComponent(ship)}/${encodeURIComponent(repository)}?tab=commits&commit=${encodeURIComponent(oid)}`)
    let request = ''
    try {
      const started = await api.peerCommit(ship, repository, oid)
      request = started.request
      const found = await waitForPeerBrowse(request)
      if (!found.ok) throw new Error(found.message || 'Could not load commit')
      if (!found.result?.commit) throw new Error('Peer returned an invalid commit response')
      setCommitDetail(found.result)
    } catch (cause) {
      setCommitError(cause.message)
    } finally {
      if (request) api.peerDeleteBrowse(request).catch(() => {})
      setCommitLoading(false)
    }
  }
  useEffect(() => {
    const restore = () => {
      const route = remoteRoute()
      setTab(route.tab)
      setFilePath(route.filePath)
      if (route.commitOid) { setSelected(null); setDetail(null); setDetailError(''); void inspectCommit(route.commitOid, false); return }
      setCommitOid(''); setCommitDetail(null); setCommitError(''); setCommitLoading(false)
      if (!route.kind) { setSelected(null); setDetail(null); setDetailError(''); return }
      const source = route.kind === 'issue' ? [...createdIssues, ...(repo?.nativeIssues || [])] : (repo?.pullRequests || [])
      const item = source.find((candidate) => candidate.number === route.number)
      if (item) void inspect(route.kind, item, false)
    }
    addEventListener('popstate', restore)
    const initial = remoteRoute()
    if (initial.kind) restore()
    return () => removeEventListener('popstate', restore)
  }, [ship, repo?.name, createdIssues])
  function chooseTab(next) {
    const query = next === 'code' ? '' : `?tab=${encodeURIComponent(next)}`
    history.pushState({}, '', `#/peer/${encodeURIComponent(ship)}/${encodeURIComponent(repo.name)}${query}`)
    setTab(next); setFilePath(''); setCommitOid(''); setCommitDetail(null); setCommitError(''); setSelected(null); setDetail(null); setDetailError('')
  }
  async function addComment() {
    const body = comment.trim()
    if (!body || !selected || commentBusy) return
    setCommentBusy(true); setDetailError('')
    let request = ''
    try {
      const started = await api.peerForgeComment(ship, repository, selected.kind, selected.item.number, body)
      request = started.request
      const found = await waitForPeerForge(request)
      if (!found.ok) throw new Error(found.message || 'Comment was rejected by the repository owner')
      setDetail(found.result)
      clearComment()
      setCommentCounts((current) => ({ ...current, [`${selected.kind}-${selected.item.number}`]: found.result?.comments?.length || 0 }))
    } catch (cause) {
      setDetailError(cause.message)
    } finally {
      if (request) api.peerDeleteForgeRequest(request).catch(() => {})
      setCommentBusy(false)
    }
  }
  async function createIssue(event) {
    event.preventDefault()
    const title = issueTitle.trim()
    if (!title || issueBusy) return
    setIssueBusy(true); setIssueError('')
    let request = ''
    try {
      const started = await api.peerCreateIssue(ship, repository, title, issueBody.trim())
      request = started.request
      const found = await waitForPeerForge(request)
      if (!found.ok) throw new Error(found.message || 'Issue was rejected by the repository owner')
      const created = found.result
      if (!created?.number) throw new Error('Repository owner returned an invalid issue')
      setCreatedIssues((current) => [created, ...current.filter((issue) => issue.number !== created.number)])
      setIssueCreating(false); clearIssueTitle(); clearIssueBody()
      setSelected({ kind: 'issue', item: created }); setDetail(created); setDetailError('')
      history.pushState({}, '', `#/peer/${encodeURIComponent(ship)}/${encodeURIComponent(repository)}?tab=issues&issue=${created.number}`)
    } catch (cause) {
      setIssueError(cause.message)
    } finally {
      if (request) api.peerDeleteForgeRequest(request).catch(() => {})
      setIssueBusy(false)
    }
  }
  const existing = repositories.find((item) => item.name === localName.trim())
  const sameOrigin = existing?.peerOrigin?.ship === ship && existing?.peerOrigin?.repository === repository && !existing?.binding?.bound
  const blockedCollision = Boolean(existing && !sameOrigin)
  async function fork(event) {
    event.preventDefault()
    if (forking) return
    const target = localName.trim()
    setForkDialog(false)
    setForking(true)
    setForkTarget(target)
    setProgress({ stage: 'request' })
    const complete = await onFork(ship, repository, target, publicRead, setProgress, setTransfer)
    if (!complete) { setForking(false); setCancelling(false); setTransfer(''); setProgress(null) }
  }
  async function cancelFork() {
    if (!transfer || cancelling) return
    setCancelling(true)
    await onCancelTransfer(transfer)
  }
  const loadPeerFile = useCallback(async (path) => {
    let request = ''
    try {
      const started = await api.peerFile(ship, repository, path)
      request = started.request
      const found = await waitForPeerBrowse(request)
      if (!found.ok) throw new Error(found.message || `Could not load ${path}`)
      if (!found.result?.file) throw new Error('Peer returned an invalid file response')
      return found.result.file
    } finally {
      if (request) api.peerDeleteBrowse(request).catch(() => {})
    }
  }, [ship, repository])
  function openFile(path, pushHistory = true) {
    if (pushHistory) history.pushState({}, '', `#/peer/${encodeURIComponent(ship)}/${encodeURIComponent(repository)}?file=${encodeURIComponent(path)}`)
    setTab('code'); setSelected(null); setCommitOid(''); setCommitDetail(null); setCommitError(''); setDetail(null); setDetailError(''); setFilePath(path)
  }
  if (!repo) return <main className="content"><div className="empty">Repository data is unavailable.</div></main>
  const commits = data.commits?.commits || []
  const nativePulls = repo.pullRequests || []
  const githubPulls = repo.githubPulls || []
  const pulls = [
    ...nativePulls.map((pull) => ({ ...pull, source: 'native' })),
    ...githubPulls.map((pull) => ({ ...pull, source: 'github' })),
  ]
  const nativeIssues = repo.nativeIssues || []
  const githubIssues = repo.githubIssues || []
  const issues = [
    ...createdIssues.filter((created) => !nativeIssues.some((issue) => issue.number === created.number)).map((issue) => ({ ...issue, source: 'native' })),
    ...nativeIssues.map((issue) => ({ ...issue, source: 'native' })),
    ...githubIssues.map((issue) => ({ ...issue, source: 'github' })),
  ]
  const commitCountValue = repo.commitCount || commits.length || 0
  const commitCountLabel = repo.commitCountExact === false ? `${commitCountValue}+` : commitCountValue
  return <main className="content">
    <header className="repo-header"><div><div className="repo-breadcrumb"><span>{ship}</span><b>/</b><h1>{repository}</h1><span className="visibility-badge">Peer</span></div>{repo.description && <p className="repo-description">{repo.description}</p>}</div><div className="row-actions">{cacheState?.newer && <span className="status good">Update available</span>}{cacheState?.checkFailed && <span className="quiet">Unable to fetch updates</span>}<button className="button" onClick={onRefresh}>Refresh</button><button className={`button primary ${forking ? 'is-busy' : ''}`} disabled={forking} onClick={() => { setLocalName(repository); setForkDialog(true) }}>{forking && <span className="spinner" />}{forking ? 'Forking to my ship…' : 'Fork to my ship'}</button></div></header>
    {forking && <TransferProgress ship={ship} repository={repository} localName={forkTarget} progress={progress} cancelling={cancelling} onCancel={cancelFork} />}
    <div className="repo-meta"><span><b>{repo.fileCount || 0}</b> files</span><span><b>{commitCountLabel}</b> commits</span><span><b>{repo.branchCount || 0}</b> branches</span><span><b>{repo.tagCount || 0}</b> tags</span></div>
    <nav className="tabs"><button className={tab === 'code' ? 'active' : ''} onClick={() => chooseTab('code')}>Code</button><button className={tab === 'issues' ? 'active' : ''} onClick={() => chooseTab('issues')}>Issues <span className="tab-count">{issues.length}</span></button><button className={tab === 'pulls' ? 'active' : ''} onClick={() => chooseTab('pulls')}>Pull requests <span className="tab-count">{pulls.length}</span></button><button className={tab === 'commits' ? 'active' : ''} onClick={() => chooseTab('commits')}>Commits <span className="tab-count">{commitCountLabel}</span></button><button className={tab === 'branches' ? 'active' : ''} onClick={() => chooseTab('branches')}>Branches <span className="tab-count">{repo.branchCount || 0}</span></button></nav>
    <section className="repo-body">
      {tab === 'code' && (filePath ? <RemoteFileView path={filePath} loadFile={loadPeerFile} onBack={() => history.back()} /> : <><FileTree files={data.files?.files || []} onOpen={openFile} onOpenCommit={inspectCommit} /><Readme files={data.files?.files || []} loadFile={loadPeerFile} onOpen={openFile} /></>)}
      {tab === 'commits' && (commitOid ? commitLoading ? <div className="empty"><span className="spinner" /> Loading commit from peer…</div> : commitError ? <div className="inline-error">{commitError}</div> : <CommitDetail data={commitDetail} onBack={() => history.back()} /> : <div className="commit-list">{commits.map((commit) => { const date = formatDate(commit.committer?.timestamp); return <div className="commit-row" key={commit.oid}><span className="commit-avatar">{(commit.author?.name || '?').slice(0, 1).toUpperCase()}</span><div><strong>{commit.subject || 'Untitled commit'}</strong><small>{commit.author?.name || commit.author?.email || 'Unknown author'}{date ? ` committed ${date}` : ''}</small></div><button className="commit-hash" title={`View ${commit.oid}`} onClick={() => inspectCommit(commit)}><code>{shortOid(commit.oid)}</code></button></div> })}</div>)}
      {selected && <RemoteForgeDetail selected={selected} detail={detail} error={detailError} comment={comment} commentBusy={commentBusy} onCommentChange={setComment} onComment={addComment} onSaveLabels={saveLabels} onBack={() => history.back()} />}
      {!selected && tab === 'issues' && <>{issueCreating && <form className="panel issue-composer" onSubmit={createIssue}><div className="section-title"><div><h2>New issue</h2><p className="quiet">Open an issue on {ship}/{repository} as this ship.</p></div><button type="button" className="text-button" onClick={() => { setIssueCreating(false); setIssueError('') }}>Cancel</button></div><label><span>Title</span><input autoFocus required value={issueTitle} maxLength="200" onChange={(event) => setIssueTitle(event.target.value)} /></label><label><span>Description</span><textarea value={issueBody} maxLength="65536" onChange={(event) => setIssueBody(event.target.value)} placeholder="Describe the problem or proposal…" /></label>{issueError && <div className="inline-error">{issueError}</div>}<div className="form-actions"><button className="button primary" disabled={issueBusy || !issueTitle.trim()}>{issueBusy ? 'Opening…' : 'Open issue'}</button></div></form>}<div className="forge-toolbar"><span>{issues.length} issues</span><div className="forge-toolbar-actions"><button className="button primary" disabled={issueBusy} onClick={() => { setIssueCreating(!issueCreating); setIssueError('') }}>New issue</button></div></div>{!issues.length ? <div className="empty compact">No issues.</div> : <div className="issue-list">{issues.map((issue) => issue.source === 'github' ? <a className="issue-row forge-link" href={issue.url} target="_blank" rel="noreferrer" key={`github-${issue.number}`}><span className={`issue-icon ${issue.state}`}>◉</span><div><h3>{issue.title}</h3><p>#{issue.number} · {issue.state} · {issue.author} · GitHub</p></div><span className="external-arrow">↗</span></a> : <button type="button" className="issue-row remote-forge-row" onClick={() => inspect('issue', issue)} key={`native-${issue.number}`}><span className={`issue-icon ${issue.state}`}>◉</span><div><h3>{issue.title}</h3><p>#{issue.number} · {issue.state} · {issue.author} · {commentCounts[`issue-${issue.number}`] ?? issue.commentCount ?? 0} comments</p><div className="issue-labels inline">{(issue.labels || []).map((label) => <span key={label}>{label}</span>)}</div></div></button>)}</div>}</>}
      {!selected && tab === 'pulls' && (!pulls.length ? <div className="empty compact">No pull requests.</div> : <div className="pull-list">{pulls.map((pull) => pull.source === 'github' ? <a className="pull-row forge-link" href={pull.url} target="_blank" rel="noreferrer" key={`github-${pull.number}`}><div><span className={`status ${pull.state === 'open' ? 'good' : ''}`}>{pull.draft ? 'draft' : pull.state}</span><h3>#{pull.number} {pull.title}</h3><p>opened by <strong>{pull.author}</strong> on GitHub</p></div><span className="external-arrow">↗</span></a> : <button type="button" className="pull-row remote-forge-row" onClick={() => inspect('pull', pull)} key={`native-${pull.number}`}><div><span className={`status ${pull.state === 'open' ? 'good' : ''}`}>{pull.state}</span><h3>#{pull.number} {pull.title}</h3><p><code>{pull.sourceShip}/{pull.sourceRepository}</code> proposes <code>{shortOid(pull.head)}</code> into <code>{shortOid(pull.base)}</code> · {commentCounts[`pull-${pull.number}`] ?? pull.commentCount ?? 0} comments</p>{(pull.labels || []).length > 0 && <div className="issue-labels inline" aria-label="Labels">{pull.labels.map((label) => <span key={label}>{label}</span>)}</div>}</div></button>)}</div>)}
      {tab === 'branches' && <div className="table"><div className="table-head"><span>Branch</span><span>Commit</span></div>{(repo.refs || []).filter((ref) => ref.name.startsWith('refs/heads/')).map((ref) => <div className="table-row" key={ref.name}><strong>{ref.name.replace('refs/heads/', '')}</strong><code>{shortOid(ref.oid)}</code></div>)}</div>}
    </section>
    {forkDialog && <div className="modal-backdrop" onMouseDown={(event) => event.target === event.currentTarget && setForkDialog(false)}><section className="modal-card" role="dialog" aria-modal="true" aria-label="Fork repository"><header><div><span className="eyebrow">Fork</span><h1>{ship}/{repository}</h1></div><button type="button" className="icon-button" onClick={() => setForkDialog(false)} aria-label="Close">×</button></header><form onSubmit={fork}><label><span>Local repository name</span><input autoFocus required pattern="[A-Za-z0-9._-]+" maxLength="100" value={localName} onChange={(event) => setLocalName(event.target.value)} /></label>{sameOrigin && <small className="field-note">This updates the existing fork from the same origin.</small>}{blockedCollision && <small className="field-error">That name belongs to another repository. Choose a different local name.</small>}<label className="check-row"><input type="checkbox" checked={publicRead} onChange={(event) => setPublicRead(event.target.checked)} /><span><strong>Public local fork</strong><small>Allow other ships and Git clients to fetch this copy.</small></span></label><div className="form-actions"><button type="button" className="button ghost" onClick={() => setForkDialog(false)}>Cancel</button><button className="button primary" disabled={blockedCollision || !localName.trim()}>{sameOrigin ? 'Update fork' : 'Fork repository'}</button></div></form></section></div>}
  </main>
}

function RemoteFileView({ path, loadFile, onBack }) {
  const [file, setFile] = useState(null)
  const [error, setError] = useState('')
  useEffect(() => {
    let active = true
    setFile(null); setError('')
    loadFile(path).then((data) => active && setFile({ ...data, ...decodeBase64(data.content) })).catch((cause) => active && setError(cause.message))
    return () => { active = false }
  }, [path, loadFile])
  const mime = imageType(path)
  const markdown = /\.(?:md|markdown)$/i.test(path)
  return <div className="file-view">
    <div className="file-toolbar"><button className="text-button file-back" onClick={onBack}>← Files</button><code>{path.replace(/^\/+/, '')}</code></div>
    {error ? <div className="inline-error">{error}</div> : !file ? <div className="empty"><span className="spinner" /> Reading file from peer…</div> : mime ? <div className="image-view"><img src={`data:${mime};base64,${file.content}`} alt={path} /></div> : file.text !== null ? markdown ? <section className="readme-panel standalone"><header><span>{path.replace(/^\/+/, '')}</span></header><MarkdownDocument>{file.text}</MarkdownDocument></section> : <HighlightedCode code={file.text} path={path} /> : <div className="empty" title={exactBytes(file.size)}>Binary file · {formatBytes(file.size)}</div>}
  </div>
}

function RemoteForgeDetail({ selected, detail, error, comment, commentBusy, onCommentChange, onComment, onSaveLabels, onBack }) {
  const kind = selected.kind
  const fallback = selected.item
  const item = detail || fallback
  const comments = detail?.comments || []
  return <div className={kind === 'issue' ? 'issue-detail' : 'pull-detail'}>
    <button className="text-button file-back" onClick={onBack}>← {kind === 'issue' ? 'Issues' : 'Pull requests'}</button>
    <header className="pull-detail-header"><div><h2>#{item.number} {item.title}</h2><p><span className={`status ${item.state === 'open' ? 'good' : ''}`}>{item.state}</span> {kind === 'issue' ? <>opened by <strong>{item.author}</strong></> : <><code>{item.sourceShip}/{item.sourceRepository}</code> proposes <code>{shortOid(item.head)}</code> into <code>{shortOid(item.base)}</code></>}</p></div></header>
    {error && <div className="inline-error">{error}</div>}
    {kind === 'pull' && <PullLabels labels={detail?.labels || fallback.labels || []} editable={Boolean(detail?.labelsEditable)} onSave={onSaveLabels} />}
    {!detail && !error ? <div className="empty"><span className="spinner" /> Loading discussion from {fallback.sourceShip || fallback.author || 'peer'}…</div> : detail && <>
      {kind === 'issue' ? <div className="issue-layout"><div className="issue-thread"><article className="review-comment"><header><strong>{detail.author}</strong><span title={detail.created}>{detail.created}</span></header><p>{detail.body || 'No description provided.'}</p></article><RemoteDiscussion comments={comments} /><RemoteCommentComposer value={comment} busy={commentBusy} onChange={onCommentChange} onSubmit={onComment} /></div><aside className="issue-sidebar"><section><strong>Labels</strong><div className="issue-labels">{(detail.labels || []).map((label) => <span key={label}>{label}</span>)}{!(detail.labels || []).length && <small>None</small>}</div></section><section><strong>Assignees</strong><div>{(detail.assignees || []).map((assignee) => <code key={assignee}>{assignee}</code>)}{!(detail.assignees || []).length && <small>Unassigned</small>}</div></section></aside></div> : <><DiffView diff={detail} /><section className="review-discussion"><h3>Discussion <span>{comments.length}</span></h3><RemoteDiscussion comments={comments} pull /><RemoteCommentComposer value={comment} busy={commentBusy} onChange={onCommentChange} onSubmit={onComment} /></section></>}
    </>}
  </div>
}

function RemoteDiscussion({ comments, pull = false }) {
  if (!comments.length) return <div className="empty compact">No comments yet.</div>
  return <>{comments.map((entry) => <article className={`review-comment ${entry.resolved ? 'resolved' : ''}`} key={entry.id}><header><strong>{entry.author}</strong><span>{pull && entry.path ? <><code>{entry.path} · {entry.side === 'base' ? 'base ' : ''}L{entry.line}</code> · </> : null}<time title={entry.created}>{entry.created}</time></span></header><p>{entry.body}</p></article>)}</>
}

function RemoteCommentComposer({ value, busy, onChange, onSubmit }) {
  return <div className="review-composer"><div className="review-target"><strong>Comment as this ship</strong></div><textarea value={value} maxLength="16384" onChange={(event) => onChange(event.target.value)} placeholder="Add a comment on the origin repository…" /><div className="form-actions"><button className="button primary" disabled={busy || !value.trim()} onClick={onSubmit}>{busy ? 'Commenting…' : 'Comment'}</button></div></div>
}

function TransferProgress({ ship, repository, localName, progress, cancelling, onCancel }) {
  const view = peerTransferPresentation(progress)
  return <div className="peer-transfer-progress" role="status" aria-live="polite">
    <div><strong>Forking {ship}/{repository} → {localName}</strong><span>{view.label}</span></div>
    {view.determinate ? <progress max={view.max} value={view.value} /> : <div className="progress-track indeterminate"><i /></div>}
    <div className="peer-transfer-footer"><small>You can leave this view and follow the transfer from peer activity.</small><button className="text-button" disabled={cancelling} onClick={onCancel}>{cancelling ? 'Cancelling…' : 'Cancel transfer'}</button></div>
  </div>
}
