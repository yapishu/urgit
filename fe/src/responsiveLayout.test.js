import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, readFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { attemptRows } from './ci.js'
import { concurrencyModel, renderConcurrency } from './ciConcurrency.js'
import { waitingRun } from './ciConcurrencyFixtures.js'
import { renderSelection } from './ciEventsView.js'
import { renderWaitingJobs } from './ciJobs.js'
import { all, h } from './runnerRecoveryFixtures.js'

// Narrow layouts (UI-N1/N2/N3). A real browser at 390px showed:
//  N1: the settings grid's implicit auto track grew to 576px, so every
//      settings panel, the automatic-input panel among them, overflowed;
//  N2: with Repositories, Peers and Groups expanded in the 38vh sidebar,
//      the repository list (a flex item) shrank to 0px and its rows were
//      unclickable;
//  N3: CI rows kept six desktop columns, so cells overlapped or left the
//      viewport, and the CI header's description became a one-word column.
// These tests read the stylesheet's own rules and the views' markup. They
// are NOT a browser: the parent rechecks geometry in Chromium.

const css = readFileSync(new URL('./style.css', import.meta.url), 'utf8').replace(/\/\*[\s\S]*?\*\//g, '')

// the declarations of every rule whose selector list contains `selector`,
// inside the block opened by `within` (an at-rule prelude) or at top level
function blocks(source) {
  const out = []
  let depth = 0, start = 0, prelude = []
  for (let i = 0; i < source.length; i++) {
    const c = source[i]
    if (c === '{') { prelude.push(source.slice(start, i).trim()); depth++; start = i + 1 }
    else if (c === '}') {
      const sel = prelude.pop()
      if (!sel.startsWith('@')) out.push({ selector: sel, body: source.slice(start, i), within: prelude.filter((p) => p.startsWith('@')).at(-1) || null })
      depth--; start = i + 1
    } else if (c === ';' && depth === 0) start = i + 1
  }
  return out
}
const rules = blocks(css)
function decls(selector, within = null) {
  const found = rules.filter((r) => r.within === within && r.selector.split(',').map((s) => s.trim()).includes(selector))
  const map = {}
  for (const r of found) for (const d of r.body.split(';')) {
    const at = d.indexOf(':'); if (at < 0) continue
    map[d.slice(0, at).trim()] = d.slice(at + 1).trim()
  }
  return map
}
const narrow = '@media (max-width: 760px)'
const ciNarrow = '@container ci-list (max-width: 36rem)'

test('N1: the settings grid has one track no wider than its container', () => {
  assert.equal(decls('.settings-grid')['grid-template-columns'], 'minmax(0, 1fr)')
  assert.equal(decls('.settings-grid > *')['min-width'], '0')
})

test('N1: the automatic-input URL field is styled like every other text field', () => {
  assert.equal(decls('input[type="url"]').width, '100%')
  assert.equal(decls('input[type="url"]').height, '39px')
})

test('N2: the capped narrow sidebar scrolls as a whole and its sections never shrink', () => {
  const sidebar = decls('.sidebar', narrow)
  assert.equal(sidebar['max-height'], '38vh', 'the cap stays')
  assert.equal(sidebar['overflow-y'], 'auto')
  assert.equal(decls('.sidebar > *', narrow)['flex-shrink'], '0')
})

test('N2: the sidebar filters stretch inside their margins, never wider than the sidebar', () => {
  assert.equal(decls('.repo-search').margin, '2px 5px 8px')
  assert.equal(decls('.sidebar .repo-search').width, 'auto')
})

test('N3: a section title wraps its tools below a text column of a readable measure', () => {
  assert.equal(decls('.section-title')['flex-wrap'], 'wrap')
  assert.equal(decls('.section-title > div:first-child').flex, '1 1 18rem')
  assert.equal(decls('.ci-tab-tools')['flex-wrap'], 'wrap')
})

test('N3: a narrow CI list stacks each row, hides the column head and labels every value', () => {
  assert.equal(decls('.ci-list:not(.ci-schedule-list)').container, 'ci-list / inline-size')
  assert.equal(decls('.ci-list > .table-head', ciNarrow).display, 'none')
  for (const row of ['.ci-row', '.ci-attempt-row', '.ci-selection-row', '.ci-input-row', '.ci-event-row', '.ci-waiting-row', '.ci-runner-row', '.ci-lock-row', '.ci-backend-row', '.ci-concurrency-row']) {
    assert.equal(decls(row, ciNarrow)['grid-template-columns'], 'minmax(0, 1fr)', `${row} stacks`)
    assert.equal(decls(`${row} > *`)['min-width'], '0', `${row}'s cells may shrink`)
  }
  assert.equal(decls('[data-label]::before', ciNarrow).content, 'attr(data-label)')
})

test('N3: the schedules list keeps its own container and stacking rule (correction 05)', () => {
  assert.equal(decls('.ci-schedule-list').container, 'ci-schedule-list / inline-size')
  assert.equal(decls('.ci-schedule-row', '@container ci-schedule-list (max-width: 45.75rem)')['grid-template-columns'], 'minmax(0, 1fr)')
})

test('N3: the CI views label their values in markup, never the status badge', () => {
  const selection = renderSelection(h, { basis: 'b', note: null, required: null, rows: [{ workflow: 'a.yml', name: 'A', tone: 'good', verdictText: 'selected', reason: 'why' }] })
  const reason = all(selection, (n) => /ci-selection-reason/.test(n.props?.className || ''))
  assert.equal(reason.length, 1); assert.equal(reason[0].props['data-label'], 'Reason')
  const waiting = renderWaitingJobs(h, [{ workflow: 'a.yml', id: 'build', label: 'waiting', reason: 'needs plan' }])
  const labels = all(waiting, (n) => n.props?.['data-label']).map((n) => n.props['data-label'])
  assert.deepEqual(labels, ['State', 'Why'])
  for (const tree of [selection, waiting]) {
    for (const badge of all(tree, (n) => /\bstatus\b/.test(n.props?.className || ''))) assert.equal(badge.props['data-label'], undefined, 'a badge names itself')
  }
})

test('N3 (CI-CONCURRENCY-1): the concurrency panel wraps its head and Cancel, stacks its rows and lets long group names wrap', () => {
  assert.equal(decls('.ci-concurrency-head')['flex-wrap'], 'wrap', 'Cancel run wraps below the summary')
  assert.equal(decls('.ci-concurrency-head small')['min-width'], '0')
  assert.equal(decls('.ci-concurrency-row', ciNarrow)['grid-template-columns'], 'minmax(0, 1fr)')
  for (const cls of ['.ci-concurrency-state', '.ci-concurrency-fine', '.ci-concurrency-note', '.ci-group-tag']) assert.equal(decls(cls)['overflow-wrap'], 'anywhere', `${cls} wraps`)
  // the rows sit in a .ci-list, so the narrow container rule applies to them
  const tree = renderConcurrency(h, concurrencyModel(waitingRun))
  const list = all(tree, (n) => /(^|\s)ci-list(\s|$)/.test(n.props?.className || ''))
  assert.equal(list.length, 1)
  assert.equal(all(list[0], (n) => n.props?.['data-part'] === 'concurrency-row').length, 2)
})

let deps = null
try {
  const [react, server, vite] = await Promise.all([import('react'), import('react-dom/server'), import('vite')])
  deps = { React: react.default ?? react, renderToStaticMarkup: server.renderToStaticMarkup, createServer: vite.createServer }
} catch {
  deps = null
}
const skip = deps ? false : 'fe/node_modules is not installed (react, react-dom, vite): the React render is NOT RUN here'

test('N3: an attempt row labels daemon, times and log; its badge stays the status alone', { skip }, async () => {
  const { React, renderToStaticMarkup, createServer } = deps
  const cacheDir = mkdtempSync(join(tmpdir(), 'urgit-ssr-'))
  const server = await createServer({ configLoader: 'native', cacheDir, server: { middlewareMode: true, ws: false, hmr: false, watch: null }, appType: 'custom' })
  try {
    const { AttemptRow } = await server.ssrLoadModule('/src/components/CiTab.jsx')
    const [row] = attemptRows([{ attempt: '0v1.abc', kind: 'job', workflow: 'w.yml', job: 'probe', status: 'passed', daemon: '0v3.vd3vb', started: 1792378812, finished: 1792378817, log: { key: 'k', size: 1, sha256: 'x' }, pinned: [], needs: [], decision: { verdict: 'run', reason: 'no prerequisites', value: null }, jobOutputs: [], stepOutputs: [], outcome: 'known' }], [])
    const html = renderToStaticMarkup(React.createElement(AttemptRow, { row, onLog() {} }))
    for (const label of ['Daemon', 'Started', 'Finished', 'Log']) assert.ok(html.includes(`data-label="${label}"`), `labelled ${label}`)
    assert.match(html, /<span class="status [^"]*">[^<]*<\/span>/, 'the badge holds text only, with no label')
  } finally {
    await server.close()
    rmSync(cacheDir, { recursive: true, force: true })
  }
})

// Pull request labels at 320px: below 760px the content keeps 20px each
// side and the labels panel 12px, so the editor has 256px. The input's
// 12rem basis fits, the Add button takes its own row, and a 64-byte label
// with no space wraps inside its chip. Read from the stylesheet, NOT a
// browser: the parent rechecks geometry in Chromium.
test('labels: the chips, the editor and the pending change wrap at 320px', () => {
  assert.equal(decls('.content', narrow).padding, '34px 20px 60px')
  assert.equal(decls('.pull-labels', narrow).padding, '10px 12px')
  assert.equal(decls('.pull-labels')['min-width'], '0')
  assert.equal(decls('.label-chips')['flex-wrap'], 'wrap')
  assert.equal(decls('.label-chip')['max-width'], '100%')
  assert.equal(decls('.label-chip')['min-width'], '0')
  assert.equal(decls('.label-chip > span')['overflow-wrap'], 'anywhere')
  assert.equal(decls('.label-editor')['flex-wrap'], 'wrap')
  assert.equal(decls('.label-editor input').flex, '1 1 12rem')
  assert.equal(decls('.label-editor input')['min-width'], '0')
  assert.equal(decls('.label-editor > .button', narrow).flex, '1 1 100%')
  assert.equal(decls('.label-pending p')['overflow-wrap'], 'anywhere')
  assert.equal(decls('.label-pending .form-actions')['flex-wrap'], 'wrap')
  assert.equal(decls('.pull-labels .inline-error')['overflow-wrap'], 'anywhere', 'a refusal in the ship\'s words wraps')
  // a remove control is a touch target, not a glyph
  assert.equal(decls('.label-remove')['min-width'], '26px')
  assert.equal(decls('.label-remove')['min-height'], '26px')
  // the lists: a long label wraps inside its chip and the row text shrinks
  assert.equal(decls('.issue-labels')['flex-wrap'], 'wrap')
  assert.equal(decls('.issue-labels span')['overflow-wrap'], 'anywhere')
  assert.equal(decls('.issue-labels span')['max-width'], '100%')
  assert.equal(decls('.pull-row > div')['min-width'], '0')
  // 320 - 2 * 20 - 2 * 12 = 256px for the editor; 12rem is 192px
  assert.ok(320 - 2 * 20 - 2 * 12 >= 12 * 16)
})
