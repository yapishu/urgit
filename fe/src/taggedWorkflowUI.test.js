import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { createServer } from 'vite'
import { modeLabel, waitExplanation } from './ciProvenance.js'
import { eventRows } from './ciDispatch.js'
import { forgeEventRows, runEventSummary } from './ciEvents.js'
import { renderEventLog } from './ciEventsView.js'
import { hooksRuntime, parts, text } from './runnerRecoveryFixtures.js'

// Private UI fixtures model the controller JSON. No browser or ship runs.
const source = 'a'.repeat(40)
const object = 'b'.repeat(40)
const lock = 'c'.repeat(64)
const ref = 'refs/tags/v1.2.3'
const candidate = {
  mode: 'event', workflowAuthority: 'tagged-revision', ref,
  head: source, candidate: source, baseline: source, lock, status: 'pending',
  event: { name: 'push', kind: 'push', workflowAuthority: 'tagged-revision', ref,
    before: null, after: object, source, revision: source, actor: '~zod', inputs: [] },
}

test('tag run explains tagged YAML and advisory authority without a promotion claim', () => {
  const mode = modeLabel(candidate)
  assert.match(mode.detail, /tagged revision/i)
  assert.doesNotMatch(mode.detail, /promoted baseline/)
  assert.match(mode.detail, /no credentials/)
  assert.match(mode.detail, /required checks/)
  assert.equal(eventRows(candidate).workflowAuthority, 'tagged-revision')
  assert.match(runEventSummary(candidate.event).label, /Tag/)
})

test('pending tag resolution explains automatic resumption without a hidden promotion step', () => {
  const why = waitExplanation('pending: tagged revision waits for a live resolver-capable runner')
  assert.match(why, /automatically/)
  assert.match(why, /same revision/)
  assert.doesNotMatch(why, /[Pp]romote/)
})

test('tag resolution explains reoffer and missing fetch policy without promotion advice', () => {
  const retry = waitExplanation('pending: tagged revision resolver was re-offered; waiting for another eligible runner')
  assert.match(retry, /another eligible resolver/)
  assert.match(retry, /same captured revision/)
  const refusal = waitExplanation('refused: tagged revision resolution: download: automatic tag resolution has no external-input policy')
  assert.match(refusal, /refused without fetching/)
  assert.match(refusal, /job network profile does not authorize/)
  assert.doesNotMatch(refusal, /[Pp]romote/)
})

test('event view renders captured source, workflow and lock plus filter outcomes', () => {
  const answer = { events: [{ id: 'event-1', kind: 'push', ref, before: null, after: object,
    actor: '~zod', route: 'tag API', received: 1, outcome: 'filtered out: no matching tag', runs: ['run-1'],
    workflowProvenance: { authority: 'tagged-revision', source, revision: source, lock, resolution: 'resolved' },
    selection: { basis: 'tagged revision', outcomes: [{ workflow: 'release.yml', name: 'Release checks', verdict: 'excluded', reason: 'tag is excluded' }] },
  }] }
  const rows = forgeEventRows(answer)
  assert.equal(rows[0].kindText, 'new tag')
  const rt = hooksRuntime()
  const tree = renderEventLog(rt.React.createElement, { phase: 'ready', rows, repo: 'demo' }, { openRun() {}, refresh() {} })
  const shown = text(tree)
  assert.match(shown, /Tagged revision/)
  assert.match(shown, /Release checks/)
  assert.match(shown, /tag is excluded/)
  assert.ok(shown.includes(source) && shown.includes(lock))
  assert.doesNotMatch(shown, /promoted baseline/)
  assert.equal(parts(tree, 'tag-provenance').length, 1)
})

test('historical tag events and branch/manual/required authority remain promoted', () => {
  const historical = { ...candidate, workflowAuthority: 'promoted-baseline' }
  assert.match(modeLabel(historical).detail, /promoted baseline/)
  for (const mode of ['required', 'manual']) {
    assert.match(modeLabel({ mode, baseline: source }).detail, /promoted baseline/)
  }
})

test('the real candidate components render pending, resolved and refused tagged provenance', async () => {
  const cacheDir = mkdtempSync(join(tmpdir(), 'urgit-tag-ui-'))
  const server = await createServer({ root: fileURLToPath(new URL('../', import.meta.url)), configLoader: 'native', cacheDir,
    server: { middlewareMode: true, ws: false, hmr: false, watch: null }, appType: 'custom' })
  try {
    const { EventFacts } = await server.ssrLoadModule('/src/components/CiTab.jsx')
    const { CandidateProvenance } = await server.ssrLoadModule('/src/components/CiProvenance.jsx')
    for (const resolution of ['pending', 'resolved', 'refused', 'cancelled', 'superseded']) {
      const c = { ...candidate, sandbox: 'vm', bindingsCurrent: false, landable: false,
        workflowProvenance: { authority: 'tagged-revision', source, revision: source,
          lock: resolution === 'resolved' ? lock : null, resolution } }
      const facts = renderToStaticMarkup(React.createElement(EventFacts, { candidate: c, repo: { name: 'demo' } }))
      assert.match(facts, /Tagged revision workflows/)
      assert.match(facts, new RegExp(resolution === 'resolved' ? 'Dependencies resolved' : `Dependency resolution ${resolution}`))
      assert.ok(facts.includes(source))
      assert.doesNotMatch(facts, /from the promoted baseline/)
      const panel = renderToStaticMarkup(React.createElement(CandidateProvenance, { data: { candidate: c }, busy: '' }))
      assert.match(panel, /Workflow revision/)
      assert.match(panel, /captured at tag admission/)
      assert.match(panel, /not landable/)
      assert.doesNotMatch(panel, /from the promoted baseline/)
    }
    const historical = { ...candidate, workflowAuthority: 'promoted-baseline', event: { ...candidate.event, workflowAuthority: 'promoted-baseline' } }
    const html = renderToStaticMarkup(React.createElement(EventFacts, { candidate: historical }))
    assert.match(html, /from the promoted baseline/)
  } finally {
    await server.close()
    rmSync(cacheDir, { recursive: true, force: true })
  }
})

test('real candidate panel shows immutable admission, resolution and input receipts', async () => {
  const cacheDir = mkdtempSync(join(tmpdir(), 'urgit-input-ui-'))
  const server = await createServer({ root: fileURLToPath(new URL('../', import.meta.url)), configLoader: 'native', cacheDir,
    server: { middlewareMode: true, ws: false, hmr: false, watch: null }, appType: 'custom' })
  try {
    const { CandidateProvenance } = await server.ssrLoadModule('/src/components/CiProvenance.jsx')
    const c = { ...candidate, workflowProvenance: {
      acquisition: 'cached prior resolution; no new external fetch authorized', inputPolicyId: 'admission-identity', inputPolicyRecorded: true,
      inputPolicy: { version: 1, sources: ['https://inputs.example/tool'] },
      inputEvidence: { policyId: 'resolution-identity', ceilingId: 'owner-identity', acquisitions: [{ url: 'https://inputs.example/tool', resolvedUrl: 'https://cdn.example/tool', sha256: 'f'.repeat(64), size: 15 }] },
    } }
    const shown = renderToStaticMarkup(React.createElement(CandidateProvenance, { data: { candidate: c }, busy: '' }))
    for (const value of ['cached prior resolution', 'admission-identity', 'resolution-identity', 'owner-identity', 'https://cdn.example/tool', 'f'.repeat(64), '15']) assert.ok(shown.includes(value), value)
    assert.match(shown, /never satisfies protected required checks/)
  } finally { await server.close(); rmSync(cacheDir, { recursive: true, force: true }) }
})
