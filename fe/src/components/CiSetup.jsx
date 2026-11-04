import { useEffect, useState } from 'react'
import { api } from '../api'
import { agentBrief, briefFilename, setupComplete, setupSteps, workflowFiles } from '../ciSetup'

// The CI tab's setup checklist (see ciSetup.js): each step read from the
// ship's state, with where to do it. Folds to one line once everything is
// done. "Set up with an agent" downloads a brief with no secrets in it.
export function CiSetupPanel({ repo, storage, storageChecked, runners, policy, ship, onGuide, onSettings }) {
  const [files, setFiles] = useState(undefined)
  const [open, setOpen] = useState(null)
  useEffect(() => {
    let live = true
    setFiles(undefined)
    api.files(repo.name, repo.head).then((r) => { if (live) setFiles(r.files || []) }).catch(() => { if (live) setFiles(null) })
    return () => { live = false }
  }, [repo.name, repo.head])
  // nothing is shown as done or to do until THIS repository's policy, its
  // file list and the storage check have answered: a policy still held
  // from the previous repository must not tick (or untick) a step, and the
  // agent file must not carry another repository's state
  const ready = files !== undefined && Boolean(policy) && policy.repo === repo.name && storageChecked
  const workflows = files === null ? null : workflowFiles(files || [])
  const steps = setupSteps({ repo: repo.name, storage, runners, policy, workflows })
  const complete = ready && setupComplete(steps)
  const expanded = ready && (open === null ? !complete : open)
  function download() {
    if (!ready) return
    const text = agentBrief({ origin: window.location.origin, ship: ship || repo.owner || 'your ship', repo: repo.name, steps })
    const url = URL.createObjectURL(new Blob([text], { type: 'text/markdown' }))
    const a = document.createElement('a')
    a.href = url; a.download = briefFilename(repo.name)
    document.body.appendChild(a); a.click(); a.remove()
    setTimeout(() => URL.revokeObjectURL(url), 1000)
  }
  const remaining = steps.filter((s) => s.status === 'todo').length
  return (
    <div className={`ci-setup${complete ? ' complete' : ''}`} data-part="ci-setup">
      <div className="ci-setup-head">
        {ready
          ? <button type="button" className="text-button" aria-expanded={expanded} onClick={() => setOpen(!expanded)}>
              <strong>{complete ? 'CI is set up' : 'Set up CI'}</strong>{!complete && <small className="quiet"> · {remaining} step{remaining === 1 ? '' : 's'} left</small>}
            </button>
          : <span className="quiet" data-part="ci-setup-loading">Checking CI setup…</span>}
        <span className="ci-setup-tools">
          <button type="button" className="button small" onClick={onGuide}>Setup guide</button>
          <button type="button" className="button small" data-part="ci-agent-brief" disabled={!ready} onClick={download} title="A Markdown file for a coding agent. It holds no token or other secret.">Set up with an agent</button>
        </span>
      </div>
      {expanded && (
        <ol className="ci-setup-steps">
          {steps.map((s) => (
            <li key={s.id} className={`ci-setup-step ${s.status}`} data-part="ci-setup-step" data-step={s.id} data-status={s.status}>
              <span className={`ci-setup-mark ${s.status}`} aria-label={{ done: 'done', todo: 'to do', unknown: 'unknown', info: 'note' }[s.status]}>{{ done: '✓', todo: '○', unknown: '?', info: 'i' }[s.status]}</span>
              <span className="ci-setup-text"><strong>{s.title}</strong><small>{s.detail}</small></span>
              {s.status !== 'done' && s.action?.kind === 'settings' && <button type="button" className="text-button" onClick={onSettings}>Open Settings</button>}
              {s.status !== 'done' && s.action?.kind === 'guide' && <button type="button" className="text-button" onClick={() => onGuide(s.action.anchor)}>How</button>}
            </li>
          ))}
        </ol>
      )}
      {expanded && <small className="quiet ci-setup-note">The agent file names this ship's address and what is left to do. It never contains the enrollment token: mint it in Settings → Runners and paste it into the runner's config file yourself.</small>}
    </div>
  )
}
