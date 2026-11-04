import { useEffect, useState } from 'react'
import { api } from '../api'
import CiRecovery from './CiRecovery'

const themes = ['system', 'light', 'dark']

export default function Settings({ theme, onThemeChange, onImport, onBack, repositoryCount, peerCount }) {
  const [status, setStatus] = useState(null)
  const [token, setToken] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  const load = () => api.githubStatus().then(setStatus).catch((cause) => setError(cause.message))
  useEffect(() => { load() }, [])

  async function save() {
    setBusy(true); setError('')
    try { await api.setGithubToken(token); setToken(''); await load() } catch (cause) { setError(cause.message) } finally { setBusy(false) }
  }

  async function clear() {
    setBusy(true); setError('')
    try { await api.clearGithubToken(); await load() } catch (cause) { setError(cause.message) } finally { setBusy(false) }
  }

  return (
    <main className="content settings-page">
      <button className="text-button back-link" onClick={onBack}>← Repositories</button>
      <header className="page-header"><div><h1>Settings</h1></div></header>
      {error && <div className="inline-error">{error}</div>}
      <div className="settings-columns">
        <div className="settings-stack">
          <section className="panel">
            <div className="section-title"><div><h2>Appearance</h2><p>Use the system color scheme or choose a fixed theme.</p></div></div>
            <div className="segmented theme-options" aria-label="Color theme">
              {themes.map((option) => <button key={option} className={theme === option ? 'active' : ''} onClick={() => onThemeChange(option)}>{option}</button>)}
            </div>
          </section>
          <section className="panel">
            <div className="section-title"><div><h2>Application</h2><p>Local repositories and saved Ames peers.</p></div></div>
            <dl className="settings-summary">
              <div><dt>Repositories</dt><dd>{repositoryCount}</dd></div>
              <div><dt>Peers</dt><dd>{peerCount}</dd></div>
            </dl>
          </section>
        </div>
        <section className="panel github-settings-panel">
          <div className="section-title"><div><h2>GitHub</h2><p>Connect GitHub for private imports, synchronization, issues, and pull requests.</p></div><span className={status?.tokenSet ? 'status good' : 'status'}>{status?.tokenSet ? 'connected' : 'optional'}</span></div>
          <label><span>Personal access token</span><div className="inline-field"><input type="password" value={token} onChange={(event) => setToken(event.target.value)} placeholder={status?.tokenSet ? 'Token is stored' : 'github_pat_…'} /><button className="button" disabled={busy || !token} onClick={save}>Save</button></div></label>
          <p className="field-help">Use a fine-grained token with repository Contents access. Pull-request operations also need Pull requests access.</p>
          <div className="settings-actions">
            <button className="button primary" onClick={onImport}>Import repository</button>
            {status?.tokenSet && <button className="text-button danger-text" disabled={busy} onClick={clear}>Disconnect GitHub</button>}
          </div>
        </section>
        <CiRecovery />
      </div>
    </main>
  )
}
