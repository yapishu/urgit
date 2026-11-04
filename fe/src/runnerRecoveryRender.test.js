import test from 'node:test'
import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import assert from 'node:assert/strict'
import { initialRecoveryState, recoveryReducer } from './runnerRecovery.js'
import { renderRecovery } from './runnerRecoveryView.js'
import { NOW, RUNNER, command, legacyEntry, viewOf } from './runnerRecoveryFixtures.js'

// The recovery panel through real React (legacy-recovery UI ruling 01). It
// renders the view in its states, and the component and the Runners panel
// as the app loads them: vite's SSR loader in middleware mode, with no
// listener. It needs fe/node_modules (react, react-dom and vite, from
// package.json). Where they are not installed it is skipped and says so,
// which is NOT RUN, not a pass.

let deps = null
try {
  const [react, server, vite] = await Promise.all([import('react'), import('react-dom/server'), import('vite')])
  deps = { React: react.default ?? react, renderToStaticMarkup: server.renderToStaticMarkup, createServer: vite.createServer }
} catch {
  deps = null
}
const skip = deps ? false : 'fe/node_modules is not installed (react, react-dom, vite): the React render is NOT RUN here'

const noop = { select() {}, openConfirm() {}, acknowledge() {}, cancel() {}, release() {}, refresh() {}, close() {} }
const stateWith = (view, events = []) => events.reduce(recoveryReducer, recoveryReducer(initialRecoveryState(), { type: 'loaded', view }))

test('every state of the panel renders through React', { skip }, () => {
  const { React, renderToStaticMarkup } = deps
  const html = (state) => renderToStaticMarkup(renderRecovery(React.createElement, { runner: { id: RUNNER }, state, now: NOW }, noop))
  const select = { type: 'select', selection: legacyEntry().selection }
  const inspected = html(stateWith(viewOf([legacyEntry()]), [select]))
  assert.match(inspected, /data-part="inspection"/)
  assert.equal((inspected.match(/data-part="condition"/g) || []).length, 6)
  assert.match(inspected, /data-part="open-confirm"/)
  const confirming = html(stateWith(viewOf([legacyEntry()]), [select, { type: 'confirm-open', now: NOW }]))
  assert.match(confirming, /role="alertdialog"/)
  assert.match(confirming, /data-part="release" disabled=""/)
  for (const [status, state] of [['queued', 'queued'], ['delivered', 'pending'], ['uncertain', 'uncertain'], ['completed', 'completed'], ['refused', 'refused']]) {
    assert.match(html(stateWith(viewOf([legacyEntry()], [command(status)]), [select])), new RegExp(`data-state="${state}"`))
  }
})

test('the component and the Runners panel load and render through the app\'s own JSX pipeline', { skip }, async () => {
  const { React, renderToStaticMarkup, createServer } = deps
  const cacheDir = mkdtempSync(join(tmpdir(), 'urgit-ssr-'))
  const server = await createServer({ configLoader: 'native', cacheDir, server: { middlewareMode: true, ws: false, hmr: false, watch: null }, appType: 'custom' })
  try {
    const { default: RunnerRecovery } = await server.ssrLoadModule('/src/components/RunnerRecovery.jsx')
    const first = renderToStaticMarkup(React.createElement(RunnerRecovery, { runner: { id: RUNNER }, onClose() {} }))
    assert.match(first, /Withheld slots/)
    assert.match(first, /data-part="loading"/)
    const { default: Runners } = await server.ssrLoadModule('/src/components/Runners.jsx')
    const { ConfirmProvider } = await server.ssrLoadModule('/src/components/ConfirmDialog.jsx')
    const panel = renderToStaticMarkup(React.createElement(ConfirmProvider, null, React.createElement(Runners)))
    assert.match(panel, /Runners/)
  } finally {
    await server.close()
    rmSync(cacheDir, { recursive: true, force: true })
  }
})
