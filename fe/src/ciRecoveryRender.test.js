import test from 'node:test'
import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import assert from 'node:assert/strict'
import { renderCiRecovery } from './ciRecoveryView.js'
import { initialRecoveryView, recoveryReducer } from './ciRecovery.js'
import { NOW, checkpoint, staged, viewOf } from './ciRecoveryFixtures.js'

// Settings → CI recovery through real React (CI-RECOVERY-1). It renders the
// view in its states, and the component and the Settings page as the app
// loads them: vite's SSR loader in middleware mode, with no listener. It
// needs fe/node_modules (react, react-dom and vite, from package.json).
// Where they are not installed it is skipped and says so, which is NOT RUN,
// not a pass. It is not a browser either: the parent checks it in one.

let deps = null
try {
  const [react, server, vite] = await Promise.all([import('react'), import('react-dom/server'), import('vite')])
  deps = { React: react.default ?? react, renderToStaticMarkup: server.renderToStaticMarkup, createServer: vite.createServer }
} catch {
  deps = null
}
const skip = deps ? false : 'fe/node_modules is not installed (react, react-dom, vite): the React render is NOT RUN here'

const noop = {
  checkpointNow() {}, pause() {}, resume() {}, importCheckpoint() {}, discard() {}, apply() {},
  openApply() {}, cancel() {}, acknowledge() {}, reason() {}, commit() {}, refresh() {},
}
const stateWith = (view, events = []) => events.reduce(recoveryReducer, recoveryReducer(initialRecoveryView(), { type: 'loaded', view }))

test('every state of the section renders through React', { skip }, () => {
  const { React, renderToStaticMarkup } = deps
  const html = (view, events) => renderToStaticMarkup(renderCiRecovery(React.createElement, { state: stateWith(view, events), now: NOW }, noop))
  const running = html(viewOf())
  assert.match(running, /CI recovery/)
  assert.match(running, /data-part="written-fact" data-state="written" data-tone="good"/)
  assert.match(running, /data-part="replica-fact" data-state="confirmed" data-tone="good"/)
  assert.match(running, /data-part="pause"/)
  const failed = html(viewOf({ checkpoints: [checkpoint({ replica: { state: 'failed', at: NOW, route: 'GitHub o/r', reason: 'GitHub rejected the branch update' } })] }))
  assert.match(failed, /data-part="replica-fact" data-state="failed" data-tone="bad"/)
  assert.match(failed, /class="status bad"/)
  assert.doesNotMatch(failed, /data-part="replica-fact"[^>]*data-tone="warn"/)
  const paused = html(viewOf({ paused: { at: NOW, actor: '~zod', reason: 'drill' }, staged: staged() }), [{ type: 'confirm-open' }])
  assert.match(paused, /data-part="paused-banner"/)
  assert.match(paused, /data-part="resume"/)
  assert.match(paused, /role="alertdialog"/)
  assert.match(paused, /data-part="apply" disabled=""/)
  assert.equal((paused.match(/data-part="manifest-section"/g) || []).length, 8)
  const denied = renderToStaticMarkup(renderCiRecovery(React.createElement, { state: recoveryReducer(initialRecoveryView(), { type: 'load-failed', error: 'session required', denied: true }), now: NOW }, noop))
  assert.match(denied, /data-part="no-authority"/)
  assert.doesNotMatch(denied, /data-part="(pause|import|checkpoint-now)"/)
})

test('the component and the Settings page load and render through the app\'s own JSX pipeline', { skip }, async () => {
  const { React, renderToStaticMarkup, createServer } = deps
  const cacheDir = mkdtempSync(join(tmpdir(), 'urgit-ssr-'))
  const server = await createServer({ configLoader: 'native', cacheDir, server: { middlewareMode: true, ws: false, hmr: false, watch: null }, appType: 'custom' })
  try {
    const { default: CiRecovery } = await server.ssrLoadModule('/src/components/CiRecovery.jsx')
    const first = renderToStaticMarkup(React.createElement(CiRecovery))
    assert.match(first, /CI recovery/)
    assert.match(first, /data-part="loading"/)
    const { default: Settings } = await server.ssrLoadModule('/src/components/Settings.jsx')
    const page = renderToStaticMarkup(React.createElement(Settings, { theme: 'system', onThemeChange() {}, onImport() {}, onBack() {}, repositoryCount: 0, peerCount: 0 }))
    assert.match(page, /<h1>Settings<\/h1>/)
    assert.match(page, /data-part="recovery"/, 'THE SETTINGS PAGE HAS NO RECOVERY SECTION')
    assert.match(page, /class="panel ci-backup"/)
  } finally {
    await server.close()
    rmSync(cacheDir, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 })
  }
})
