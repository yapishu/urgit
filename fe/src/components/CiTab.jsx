import { Fragment, createElement, useCallback, useEffect, useRef, useState } from 'react'
import { ci, publicApi } from '../api'
import { approveHint, attemptRows, candidateRow, candidateStatusLabel, ciActions, lineText, noRunnerMessage, pinnedNote, renderLog, shortOid } from '../ci'
import { attemptReason, renderAttemptReason, renderJobDetails, renderWaitingJobs, waitingRows } from '../ciJobs'
import { eventRows } from '../ciDispatch'
import { pullHref, selectionModel } from '../ciEvents'
import { renderSelection, renderTagProvenance } from '../ciEventsView'
import { applyCandidateFactToPage, feedPip, mergeCandidateFact, mergeRunnerCount } from '../ciLive'
import { probeClass, probeMessage, probeStore } from '../storageProbe'
import { watchAgent } from '../channel'
import { exactTime, relativeTime } from '../format'
import SetupGuide from './SetupGuide'
import { CiSetupPanel } from './CiSetup'
import { CandidateProvenance } from './CiProvenance'
import { useConfirm } from './ConfirmDialog'
import RunWorkflow from './RunWorkflow'
import { EventLog, Schedules } from './CiEvents'
import { RunConcurrency } from './CiConcurrency'

// The repository page's CI tab (BRIEF-CI-P2 D6; P3 D4/D7), read-first
// and then live: the candidate list (ref, head, actor, status, age,
// attempt pips), the candidate page (plan jobs as rows with runs-on and a
// log link when the ship recorded one, the verdict reason, the landing
// result) and the log view, rendered client-side from the raw jsonl the
// store serves. The tab subscribes to %urgit-ci's /ci/repository/<name>
// through Eyre's channel (P3 D4): the first fact is the list, every later
// one a changed candidate's full row, replaced by id; Refresh and a
// polling timer carry the tab while the channel is down, and a pip says
// which. Approve and re-run are the two actions the page offers, and
// (CI-CONCURRENCY-1) Cancel, for the whole run or one workflow of it, in
// its concurrency panel.

// a cancelled run or attempt is neutral: neither failed nor an
// infrastructure error
const statusClass = (status) => ({ passed: 'good', failed: 'bad', 'infrastructure-error': 'bad', unknown: 'warn', running: 'warn', reoffered: 'warn', pending: '', cancelled: '' })[status] || ''

function Pips({ pips }) {
  if (!pips.length) return <small className="quiet">no jobs yet</small>
  return <span className="ci-pips">{pips.map((pip) => <span key={pip.id} className={`ci-pip ${statusClass(pip.status)}`} title={`${pip.job}: ${pip.statusText}`} />)}</span>
}

// the storage pip (P3 D5): the ship names the store's endpoint and a probe
// URL; this browser fetches it and says whether logs will open here
export function useStorageProbe() {
  const [probe, setProbe] = useState({ state: 'unknown', host: '' })
  const run = useCallback(async () => {
    try {
      const answer = await ci.storageProbe()
      if (!answer.configured) { setProbe({ state: 'unconfigured', host: '' }); return 'unconfigured' }
      const state = await probeStore(answer.url)
      setProbe({ state, host: answer.host || '' })
      return state
    } catch (cause) { setProbe({ state: 'unknown', host: '', error: cause.message }); return 'unknown' }
  }, [])
  useEffect(() => { run() }, [run])
  return { ...probe, run }
}

export function StoragePip({ probe }) {
  const text = probe.state === 'unknown' && probe.error ? `Storage check unavailable: ${probe.error}` : probeMessage(probe.state, probe.host)
  return <span className={`ci-storage status ${probeClass(probe.state)}`} title={text}><span className={`ci-pip ${probeClass(probe.state)}`} /> store {probe.host ? <code>{probe.host}</code> : probe.state}</span>
}

// the ship's own name, for the channel subscription
function useShip() {
  const [ship, setShip] = useState('')
  useEffect(() => { let live = true; publicApi.profile().then((p) => { if (live) setShip(p.ship || '') }).catch(() => {}); return () => { live = false } }, [])
  return ship
}

// the live feed for one repository: the raw candidate list, the runner
// list, the channel status; a read on demand (Refresh, the polling
// fallback) merges the same way a fact does
function useRepositoryFeed(repoName) {
  const ship = useShip()
  const [raw, setRaw] = useState(null)
  const [runners, setRunners] = useState([])
  const [status, setStatus] = useState('')
  const [error, setError] = useState('')
  const [more, setMore] = useState(false)
  const load = useCallback(async (before) => {
    try {
      const answer = await ci.candidates(repoName, before)
      setRaw((current) => before && current ? [...current, ...(answer.candidates || [])] : (answer.candidates || []))
      setMore(Boolean(answer.more))
      if (!before) {
        try { const r = await ci.runners(); setRunners(r.runners || []) } catch { /* the message needs it; the list does not */ }
      }
      setError('')
    } catch (cause) { setError(cause.message) }
  }, [repoName])
  useEffect(() => { setRaw(null); setStatus(''); load('') }, [load])
  useEffect(() => {
    if (!ship) return undefined
    const channel = watchAgent({
      ship,
      app: 'urgit-ci',
      path: `/ci/repository/${repoName}`,
      onFact: (fact) => {
        setRaw((current) => mergeCandidateFact(current, fact))
        setRunners((current) => mergeRunnerCount(current, fact))
        if (fact?.kind === 'candidates') { setMore(Boolean(fact.more)); setError('') }
      },
      onStatus: setStatus,
    })
    return () => { channel.close(); setStatus('') }
  }, [ship, repoName])
  // while the channel is down the list polls, as the App does for transfers
  useEffect(() => {
    if (status === 'open') return undefined
    const timer = setInterval(() => load(''), 10000)
    return () => clearInterval(timer)
  }, [status, load])
  return { raw, runners, status, error, more, load }
}

function CandidateList({ feed, onOpen }) {
  const { raw, error, more, load } = feed
  const rows = raw ? raw.map((candidate) => candidateRow(candidate, Date.now() / 1000)) : null
  const cursor = raw?.length ? raw[raw.length - 1].id : ''
  if (error && !rows) return <div className="empty">CI unavailable: {error}</div>
  if (!rows) return <div className="empty">Loading candidates…</div>
  if (!rows.length) return <div className="empty">No CI candidates yet. Protect a branch with CI required in Settings, then push or merge to it.</div>
  return (
    <div className="ci-list">
      <div className="table-head ci-row"><span>Ref</span><span>Head</span><span>Actor</span><span>Status</span><span>Age</span><span>Jobs</span></div>
      {rows.map((row) => (
        <button type="button" className="ci-row ci-candidate" key={row.id} onClick={() => onOpen(row.id)}>
          <span><strong>{row.ref}</strong>{row.pull != null && <small className="quiet"> · PR #{row.pull}</small>}{row.manual && <small className="quiet ci-manual-tag" title="A manual run: it never lands"> · manual: {row.workflowName}</small>}{row.event && <small className="quiet ci-manual-tag" title="An automatic run: advisory, it never lands"> · {row.event}</small>}{row.evidenceAbsent && <small className="ci-evidence-tag" title="A required workflow was not selected: the branch stays blocked until an override"> · required evidence absent</small>}{row.groupWait && <small className="quiet ci-group-tag" data-part="group-wait" title={row.groupWait.title}> · {row.groupWait.text}</small>}</span>
          <code data-label="Head">{row.head}</code>
          <span data-label="Actor">{row.actor}{row.trust === 'untrusted' && <small className="quiet"> · untrusted</small>}</span>
          <span className={`status ${statusClass(row.status)}`} title={row.reason}>{row.statusText}{row.status === 'pending' && row.reason && <small className="quiet"> · {row.reason}</small>}</span>
          <span title={row.reason} data-label="Age">{relativeTime(Date.now() / 1000 - row.ageSeconds)}</span>
          <span data-label="Jobs"><Pips pips={row.pips} /></span>
        </button>
      ))}
      {more && <div className="form-actions"><button className="text-button" onClick={() => load(cursor)}>Older candidates</button></div>}
    </div>
  )
}

function LogView({ attempt, onClose }) {
  const [groups, setGroups] = useState(null)
  const [error, setError] = useState('')
  useEffect(() => {
    let live = true
    ci.log(attempt).then((text) => { if (live) setGroups(renderLog(text)) }).catch((cause) => { if (live) setError(cause.message) })
    return () => { live = false }
  }, [attempt])
  return (
    <div className="ci-log">
      <div className="form-actions split"><strong>Log of attempt <code>{attempt}</code></strong><div><a className="text-button" href={ci.logUrl(attempt)} target="_blank" rel="noreferrer">Raw</a> <button className="text-button" onClick={onClose}>Close</button></div></div>
      {error && <div className="empty">Log unavailable: {error}{/NetworkError|Failed to fetch/i.test(error) && <small className="quiet"> — the object store the ship signed a link into is not reachable from this browser; see the storage pip at the top of the tab.</small>}</div>}
      {!error && !groups && <div className="empty">Loading log…</div>}
      {groups && groups.map((group, index) => (
        <details key={index} open={!group.title || index === groups.length - 1}>
          <summary>{group.title || 'output'} <small className="quiet">{group.lines.length} lines</small></summary>
          <pre className="ci-log-lines">{group.lines.map((line, at) => <span key={at} className={line.result ? `ci-line ${statusClass(line.result === 'success' ? 'passed' : 'failed')}` : 'ci-line'}>{lineText(line)}{'\n'}</span>)}</pre>
        </details>
      ))}
    </div>
  )
}

// the event a run is for, as the ship admitted it (Delivery 1A): the event,
// who triggered it, the branch and source, the workflow and its revision,
// and every input with its typed value and how it was decided; technical
// identifiers in details. Text only. An automatic run (Delivery 1C) adds
// its activity, how it arrived, its tips, its native pull request (opened
// by number in the Pull requests tab) or its occurrence.
export function EventFacts({ candidate, repo, onOpenPull }) {
  const e = eventRows(candidate)
  if (!e) return null
  return (
    <div className="ci-event" data-part="event">
      {renderTagProvenance(createElement, candidate.workflowProvenance)}
      <dl className="ci-facts">
        <div><dt>Event</dt><dd><strong>{e.label}</strong> <small className="quiet">{e.name}{e.activity ? ` · ${e.activity}` : ''}</small></dd></div>
        {e.workflow && <div><dt>Workflow</dt><dd>{e.workflowName} <small className="quiet">{e.workflow}{e.revision ? ` at ${shortOid(e.revision)}` : ''}</small></dd></div>}
        {!e.workflow && e.revision && e.workflowAuthority !== 'tagged-revision' && <div><dt>Workflows</dt><dd><small className="quiet">from the promoted baseline at <code>{shortOid(e.revision)}</code></small></dd></div>}
        <div><dt>Triggered by</dt><dd>{e.triggeredBy || e.actor}{e.route && <small className="quiet"> · {e.route}</small>}</dd></div>
        <div><dt>Source</dt><dd>{e.branch} <code>{shortOid(e.source)}</code></dd></div>
        {e.kind === 'push' && <div><dt>Moved</dt><dd><code>{e.before ? shortOid(e.before) : 'new ref'}</code> → <code>{shortOid(e.after)}</code></dd></div>}
        {e.labelChange && <div><dt>Label</dt><dd data-part="event-label"><strong>{e.labelChange.label}</strong> {e.labelChange.verb} by {e.labelChange.by}</dd></div>}
        {e.labels.length > 0 && <div><dt>Labels</dt><dd data-part="event-labels">{e.labels.join(', ')} <small className="quiet">after this event</small></dd></div>}
        {e.pull && <div><dt>Pull request</dt><dd><a href={pullHref(repo?.name || '', e.pull.number)} onClick={(event) => { if (onOpenPull) { event.preventDefault(); onOpenPull(e.pull.number) } }}>#{e.pull.number} {e.pull.title}</a> <small className="quiet">{e.pull.headBranch} <code>{shortOid(e.pull.head)}</code> → {e.pull.baseBranch} <code>{shortOid(e.pull.base)}</code> · by {e.pull.author}</small></dd></div>}
        {e.occurrence && <div><dt>Occurrence</dt><dd>{e.occurrence.entry} <code>{e.occurrence.cron}</code> <small className="quiet">{e.occurrence.zone}</small></dd></div>}
        {e.occurrence && <div><dt>Due</dt><dd>{e.occurrence.due?.local} <small className="quiet">{e.occurrence.due?.utc}</small></dd></div>}
        {e.occurrence && <div><dt>Admitted</dt><dd>{e.occurrence.admitted?.local} <small className="quiet">{e.occurrence.lateText}</small></dd></div>}
      </dl>
      {e.inputs.length > 0 && (
        <div className="ci-list ci-inputs-table">
          <div className="table-head ci-input-row"><span>Input</span><span>Type</span><span>Value</span><span>Decided by</span></div>
          {e.inputs.map((i) => <div className="ci-input-row" key={i.id}><code>{i.id}</code><span data-label="Type">{i.type}</span><code data-label="Value">{i.text}</code><span className="quiet" data-label="Decided by">{i.sourceLabel}</span></div>)}
        </div>
      )}
      {(e.name === 'workflow_dispatch' || e.payload) && (
        <details>
          <summary>Technical identifiers</summary>
          <dl className="ci-facts">
            {e.request && <div><dt>Request</dt><dd><code>{e.request}</code></dd></div>}
            {e.eventId && <div><dt>Event id</dt><dd><code>{e.eventId}</code></dd></div>}
            {e.trigger && <div><dt>Signed trigger</dt><dd><code>{e.trigger}</code></dd></div>}
            <div><dt>Source</dt><dd><code>{e.source}</code></dd></div>
            <div><dt>Revision</dt><dd><code>{e.revision || 'none'}</code></dd></div>
            <div><dt>Payload sha-256</dt><dd><code>{e.payloadSha256}</code></dd></div>
          </dl>
          <pre className="ci-log-lines">{e.payload}</pre>
        </details>
      )}
    </div>
  )
}

// one attempt of a candidate page: its row, the addresses pinned for it,
// its reason and its job details. The status badge holds the status alone;
// the reason, complete and in its own case, is under the row or in the
// job's decision details (attemptReason, correction 03)
export function AttemptRow({ row, onLog }) {
  const { line, details } = attemptReason(row)
  return (
    <Fragment>
      <div className={`ci-attempt-row${row.pinned.length ? ' has-pins' : ''}`}>
        <span className="ci-job-cell"><strong>{row.job}</strong>{(row.workflow || row.runsOn.length > 0) && <small className="quiet ci-job-meta">{row.workflow}{row.workflow && row.runsOn.length > 0 && ' · '}{row.runsOn.length > 0 && <span className="ci-runs-on" title="runs-on">{row.runsOn.join(', ')}</span>}</small>}</span>
        <code data-label="Daemon">{row.daemon}</code>
        <span className={`status ${statusClass(row.status)}`}>{row.statusText}</span>
        <span data-label="Started">{row.started ? exactTime(row.started) : '—'}</span>
        <span data-label="Finished">{row.finished ? `${exactTime(row.finished)}${row.elapsed ? ` (${row.elapsed})` : ''}` : '—'}</span>
        <span data-label="Log">{row.hasLog ? <button className="text-button" onClick={() => onLog(row.id)}>log</button> : <small className="quiet">—</small>}</span>
      </div>
      {row.pinned.length > 0 && (
        <div className="ci-attempt-pins" title={pinnedNote}>
          <small className="quiet">Pinned for this run</small>
          {row.pinned.map((pin) => <small key={pin.name}><strong>{pin.name}</strong> → <span className="ci-pin-addrs">{pin.addrs.join(', ')}</span></small>)}
        </div>
      )}
      {renderAttemptReason(createElement, line)}
      {/* what the ship decided for the job and, apart from it, what the
          attempt shows happened, its prerequisites and outputs (Delivery
          1B): a details area below the row, so the job cell keeps its two
          lines */}
      {details && renderJobDetails(createElement, details)}
    </Fragment>
  )
}

function CandidatePage({ id, live, policy, repo, onBack, onMutate, onOpenPull }) {
  const confirm = useConfirm()
  const [data, setData] = useState(null)
  const [error, setError] = useState('')
  const [busy, setBusy] = useState('')
  const [log, setLog] = useState('')
  const load = useCallback(async () => {
    try { setData(await ci.candidate(id)); setError('') } catch (cause) { setError(cause.message) }
  }, [id])
  useEffect(() => { load() }, [load])
  // the feed's row for this candidate refreshes the page as it changes
  useEffect(() => {
    if (!live) return
    setData((current) => current ? applyCandidateFactToPage(current, { kind: 'candidate', id: live.id, patch: live }) : current)
  }, [live])
  async function act(label, body) {
    setBusy(label); setError('')
    try { await ci.action(body); await load(); await onMutate?.() } catch (cause) { setError(cause.message) } finally { setBusy('') }
  }
  if (error && !data) return <div className="empty">{error} <button className="text-button" onClick={onBack}>Back</button></div>
  if (!data) return <div className="empty">Loading candidate…</div>
  const c = data.candidate
  const rows = attemptRows(data.attempts || [], c.plan || [])
  return (
    <div className="ci-candidate-page">
      <div className="form-actions split"><button className="text-button" onClick={onBack}>← Candidates</button><span className={`status ${statusClass(c.status)}`}>{candidateStatusLabel[c.status] || c.status}</span></div>
      <dl className="ci-facts">
        <div><dt>Ref</dt><dd>{c.ref}{c.pull != null && <> · pull request #{c.pull}</>}</dd></div>
        <div><dt>Head</dt><dd><code>{c.head}</code></dd></div>
        <div><dt>Base</dt><dd><code>{c.base}</code></dd></div>
        <div><dt>Candidate</dt><dd><code>{c.candidate || 'not materialized'}</code></dd></div>
        <div><dt>Actor</dt><dd>{c.actor} · {c.via} · {c.trust}</dd></div>
        <div><dt>Staged</dt><dd>{exactTime(c.created)}</dd></div>
        {c.verdictReason && <div><dt>{c.status === 'pending' ? 'Waiting' : 'Verdict'}</dt><dd>{c.verdictReason}</dd></div>}
      </dl>
      {error && <small className="field-error">{error}</small>}
      <EventFacts candidate={c} repo={repo} onOpenPull={onOpenPull} />
      {renderSelection(createElement, selectionModel(c))}
      <RunConcurrency candidate={c} confirm={confirm} onChanged={async () => { await load(); await onMutate?.() }} />
      <CandidateProvenance data={data} tip={(repo?.refs || []).find((r) => r.name === c.ref)?.oid || ''} onAct={act} busy={busy} confirm={confirm} />
      <div className="form-actions">
        {c.trust === 'untrusted' && c.status !== 'skipped' && <button className="button primary" disabled={busy !== ''} title={approveHint(policy)} onClick={() => act('approve', ciActions.approve(c.id))}>{busy === 'approve' ? 'Approving…' : 'Approve and run trusted'}</button>}
        {c.status !== 'pending' && c.mode !== 'manual' && c.mode !== 'event' && <button className="button" disabled={busy !== ''} onClick={() => act('rerun', ciActions.rerun(c.id))}>{busy === 'rerun' ? 'Staging…' : 'Re-run'}</button>}
        {c.mode === 'manual' && <small className="quiet">A manual run is not re-run in place: run the workflow again from Run workflow, which admits its inputs under the policy now.</small>}
        {c.mode === 'event' && <small className="quiet">An automatic run is fixed to its event and never re-run in place: a new push, pull request activity or occurrence admits a new run.</small>}
      </div>
      {renderWaitingJobs(createElement, waitingRows(c))}
      <div className="ci-list">
        <div className="table-head ci-attempt-row"><span>Job</span><span>Daemon</span><span>Status</span><span>Started</span><span>Finished</span><span>Log</span></div>
        {rows.map((row) => <AttemptRow key={row.id} row={row} onLog={setLog} />)}
        {!rows.length && <div className="empty">No attempts yet{c.trust === 'untrusted' ? ': an untrusted revision waits for approval unless the repository runs restricted checks.' : '.'}</div>}
      </div>
      {log && <LogView attempt={log} onClose={() => setLog('')} />}
    </div>
  )
}

export default function CiTab({ repo, onMutate, onOpenPull, onSettings }) {
  const [open, setOpen] = useState('')
  const [view, setView] = useState('candidates')
  const [guide, setGuide] = useState(false)
  const [running, setRunning] = useState(false)
  const [policy, setPolicy] = useState(null)
  const feed = useRepositoryFeed(repo.name)
  const probe = useStorageProbe()
  const ship = useShip()
  const pip = feedPip(feed.status)
  useEffect(() => { setOpen(''); setRunning(false); setView('candidates') }, [repo.name])
  useEffect(() => { let live = true; setPolicy(null); ci.policy(repo.name).then((p) => { if (live) setPolicy(p) }).catch(() => {}); return () => { live = false } }, [repo.name])
  const firstRun = noRunnerMessage(policy?.ciProtected || [], feed.runners)
  const liveCandidate = open ? (feed.raw || []).find((c) => c.id === open) || null : null
  return (
    <section className="panel ci-tab">
      <div className="section-title">
        <div><h2>CI</h2><p>Candidates staged for the CI-protected branches of this repository and the runs its automatic events and schedules admitted, newest first. A candidate lands its branch when every required job passes; an event run never lands.</p></div>
        <div className="ci-tab-tools">
          <StoragePip probe={probe} />
          <span className={`ci-feed ci-feed-${pip}`} title={pip === 'live' ? 'Subscribed: the ship pushes every change.' : pip === 'polling' ? 'The channel is down: the list re-reads every 10 s; Refresh reads now.' : 'Connecting to the ship.'}><span className={`ci-pip ${pip === 'live' ? 'good' : pip === 'polling' ? 'warn' : ''}`} /> {pip}</span>
          {!open && view === 'candidates' && <button className="text-button" onClick={() => { feed.load(''); probe.run() }}>Refresh</button>}
          {!open && !running && <button className="button" onClick={() => setRunning(true)}>Run workflow</button>}
        </div>
      </div>
      {(probe.state === 'unreachable' || probe.state === 'cors') && <div className="empty ci-first-run ci-storage-warning">{probeMessage(probe.state, probe.host)}</div>}
      {firstRun && <div className="empty ci-first-run">{firstRun} <button type="button" className="text-button" onClick={() => setGuide(true)}>Setup guide</button></div>}
      {!open && <CiSetupPanel repo={repo} storage={probe.state} storageChecked={probe.state !== 'unknown' || Boolean(probe.error)} runners={feed.runners} policy={policy} ship={ship} onGuide={() => setGuide(true)} onSettings={onSettings} />}
      {!open && (
        <div className="ci-view-switch" role="tablist" aria-label="CI views">
          <button type="button" role="tab" data-part="ci-view-candidates" aria-selected={view === 'candidates'} className={view === 'candidates' ? 'active' : ''} onClick={() => setView('candidates')}>Candidates</button>
          <button type="button" role="tab" data-part="ci-view-events" aria-selected={view === 'events'} className={view === 'events' ? 'active' : ''} onClick={() => setView('events')}>Events</button>
          <button type="button" role="tab" data-part="ci-view-schedules" aria-selected={view === 'schedules'} className={view === 'schedules' ? 'active' : ''} onClick={() => setView('schedules')}>Schedules</button>
        </div>
      )}
      {running && !open && <RunWorkflow repo={repo} onClose={() => setRunning(false)} onCreated={(id) => { setRunning(false); setOpen(id); feed.load('') }} />}
      {open
        ? <CandidatePage id={open} live={liveCandidate} policy={policy?.untrusted} repo={repo} onBack={() => { setOpen(''); feed.load('') }} onMutate={onMutate} onOpenPull={onOpenPull} />
        : view === 'events' ? <EventLog repo={repo} onOpenRun={setOpen} onOpenPull={onOpenPull} />
          : view === 'schedules' ? <Schedules repo={repo} onOpenRun={setOpen} />
            : <CandidateList feed={feed} onOpen={setOpen} />}
      {guide && <SetupGuide onClose={() => setGuide(false)} />}
    </section>
  )
}
