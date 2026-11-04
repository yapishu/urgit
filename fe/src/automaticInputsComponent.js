import { inputEdit, inputSupport, inputURLProblem } from './automaticInputs.js'

// The mounted product control is also exercised by the offline hooks fixture.
export function makeAutomaticInputs(React, ci) {
  const { createElement: h, useState, useEffect, useRef } = React
  return function AutomaticInputs({ repo, policy, onChanged }) {
    const [view, setView] = useState(policy)
    const [url, setURL] = useState('')
    const [error, setError] = useState('')
    const [notice, setNotice] = useState('')
    const [busy, setBusy] = useState(false)
    const pending = useRef(false)
    useEffect(() => { setView(policy) }, [policy, repo])
    const sources = view?.automaticInputs?.sources || []
    const allowed = view?.canEditAutomaticInputs === true
    const problem = url ? inputURLProblem(url) : ''
    async function save(next) {
      if (pending.current || !allowed) return
      let body
      try { body = inputEdit(repo, view, next) } catch (cause) { setError(cause.message); return }
      pending.current = true; setBusy(true); setError(''); setNotice('')
      try {
        await ci.action(body)
        const readback = await ci.policy(repo)
        setView(readback); setURL('')
        setNotice('Policy saved and read back. Pending runs under the previous generation are retired; external effects already in flight may have occurred.')
        await onChanged?.()
      } catch (cause) {
        setError(`${cause.message || 'Policy update failed'}. Reload to verify the current policy before retrying.`)
      } finally { pending.current = false; setBusy(false) }
    }
    async function reload() {
      try { setView(await ci.policy(repo)); setError(''); setNotice('Policy read back.') } catch (cause) { setError(cause.message) }
    }
    return h('section', { className: 'ci-policy-block ci-automatic-inputs', 'aria-label': 'Automatic dependency inputs' },
      h('strong', null, 'Automatic dependency inputs'),
      h('p', null, 'Default deny. Each permission names one exact public HTTPS input and applies across tags. Repository YAML and job network profiles cannot grant resolver access.'),
      h('p', null, 'Supported: HTTPS downloads with a DNS host and simple path. Git/actions and registry/images are unsupported for automatic acquisition. Redirect targets need their own exact permission and runner ceiling; query URLs are refused.'),
      h('small', { className: 'quiet', 'data-part': 'policy-id' }, `Repository policy ${view?.automaticPolicyId || 'not recorded'} · generation ${view?.generation ?? 'unknown'}`),
      !allowed && h('p', { 'data-part': 'read-only' }, 'Read only: CI policy permission is required to edit these sources.'),
      sources.length ? h('ul', { className: 'ci-input-list' }, sources.map((source) => h('li', { key: source, 'data-part': 'source' },
        h('code', null, source), h('p', { className: 'quiet', 'data-part': 'effective' }, inputSupport(view, source)),
        allowed && h('button', { type: 'button', className: 'text-button danger-text', disabled: busy, 'aria-label': `Remove ${source}`, 'data-part': 'remove', onClick: () => save(sources.filter((s) => s !== source)) }, 'Remove'))))
        : h('p', { 'data-part': 'empty' }, 'No sources allowed. New automatic external downloads are denied. Dependency-free workflows and approved exact-revision cached locks remain usable.'),
      allowed && h('div', { className: 'ci-input-add' },
        h('label', null, h('span', null, 'Exact source URL'), h('input', { type: 'url', value: url, disabled: busy, placeholder: 'https://downloads.example/tool.tar.gz', 'data-part': 'url', onChange: (e) => setURL(e.target.value.trim()), 'aria-invalid': Boolean(problem) })),
        problem && h('small', { className: 'field-error', 'data-part': 'validation' }, problem),
        h('button', { type: 'button', className: 'button', 'data-part': 'add', disabled: busy || !url || Boolean(problem) || sources.includes(url) || sources.length >= 16, onClick: () => save([...sources, url]) }, busy ? 'Saving…' : 'Allow source')),
      h('details', null, h('summary', null, 'Runner owner limits'),
        h('p', null, 'A resolver owner must independently set automatic_inputs in its runner configuration. These are reported limits, not a reachability guarantee. Removing permission rejects obsolete completion; it cannot undo an external request already made.'),
        (view?.automaticResolvers || []).map((runner) => h('div', { key: runner.id, 'data-part': 'runner' }, h('strong', null, runner.name), ` · ${runner.live ? 'live' : 'unavailable'} · ${runner.reported ? 'ceiling reported' : 'ceiling unknown'}`, h('ul', null, (runner.sources || []).map((s) => h('li', { key: s }, h('code', null, s))))))),
      error && h('p', { role: 'alert', className: 'field-error', 'data-part': 'error' }, error),
      notice && h('p', { role: 'status', 'data-part': 'notice' }, notice),
      h('button', { type: 'button', className: 'text-button', disabled: busy, 'data-part': 'reload', onClick: reload }, 'Reload policy'))
  }
}
