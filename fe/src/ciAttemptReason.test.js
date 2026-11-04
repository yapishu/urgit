import test from 'node:test'
import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { attemptRows } from './ci.js'
import { attemptReason, renderAttemptReason, renderJobDetails } from './ciJobs.js'
import { h, part, text } from './runnerRecoveryFixtures.js'

// The attempt rows of a candidate page (correction 03): the status badge
// holds the status alone, and every record's reason (a refused condition,
// a skip, a job's own failure, an infrastructure record, a job from a ship
// that sends no decision details, a plan, a resolver) is shown once,
// complete and in its own case, outside it. The attempts are a MODEL of the
// ship's candidate JSON (attempt-summary-json in desk/app/urgit-ci.hoon);
// the real page is rechecked in a browser by the parent. AttemptRow renders
// through the app's own JSX pipeline (vite's SSR loader in middleware mode,
// no listener), as in runnerRecoveryRender.test.js; where fe/node_modules
// is absent that part is skipped and says so, which is NOT RUN, not a pass.

let deps = null
try {
  const [react, server, vite] = await Promise.all([import('react'), import('react-dom/server'), import('vite')])
  deps = { React: react.default ?? react, renderToStaticMarkup: server.renderToStaticMarkup, createServer: vite.createServer }
} catch {
  deps = null
}
const skip = deps ? false : 'fe/node_modules is not installed (react, react-dom, vite): the React render is NOT RUN here'

// long, mixed-case reasons: a badge in capitals would misreport them
const long = (head) => `${head}: ${Array.from({ length: 6 }, (_, i) => `step ${i + 1} of BuildMatrix read inputs.Text and found 'MixedCase-Value_${i}', kept exactly as written`).join('; ')}`
const refusal = `if "inputs.text == 'École'" could not be evaluated: comparing text without case is not supported for non-ASCII letters: 'éCOLE' and 'École' differ only where a non-ASCII letter may match without case (the ship decides case for ASCII letters only; GitHub does not document how it cases non-ASCII letters)`
const skipReason = `if "false && inputs.text == 'École'" is false`

const plan = [
  { id: 'compare', workflow: 'manual.yml', runsOn: ['ubuntu-latest'], if: { text: "inputs.text == 'École'", line: 13, col: 9, legacy: false, refusal: null }, outputs: [] },
  { id: 'short_false', workflow: 'manual.yml', runsOn: ['ubuntu-latest'], if: { text: "false && inputs.text == 'École'", line: 20, col: 9, legacy: false, refusal: null }, outputs: [] },
  { id: 'build', workflow: 'manual.yml', runsOn: ['ubuntu-latest'], if: null, outputs: [] },
]
const job = (over) => ({
  attempt: '0v1.job', kind: 'job', workflow: 'manual.yml', job: 'build', status: 'failed', trust: 'trusted', daemon: null, events: 0,
  reason: null, started: 1_800_000_000, finished: 1_800_000_007, log: null, pinned: [],
  decision: { verdict: 'run', reason: 'no prerequisites', value: null }, needs: [], stepOutputs: [], stepOutputCount: 0, jobOutputs: [], ...over,
})
const older = job({ attempt: '0v1.older', reason: long('the job failed on a ship that sends no decision details') })
delete older.decision
delete older.needs
const records = [
  ['refused', job({ attempt: '0v1.refused', job: 'compare', reason: refusal, decision: { verdict: 'error', reason: refusal, value: null } })],
  ['skipped', job({ attempt: '0v1.skipped', job: 'short_false', status: 'skipped', reason: skipReason, decision: { verdict: 'skip', reason: skipReason, value: 'false' } })],
  ['failed', job({ attempt: '0v1.failed', daemon: '0v7.daemon.abcdef', events: 31, reason: long('the job failed'), log: { size: 10, sha256: 'ab' } })],
  ['infrastructure', job({ attempt: '0v1.infra', status: 'infrastructure-error', reason: long('abandoned: assignment refused: the manifest named') })],
  ['older', older],
  ['plan', { attempt: '0v1.plan', kind: 'plan', workflow: null, job: null, status: 'failed', trust: 'trusted', daemon: '0v7.daemon.abcdef', reason: long('the plan was refused: .github/workflows/Manual.yml'), started: 1, finished: 2, log: null, pinned: [] }],
  ['resolver', { attempt: '0v1.resolve', kind: 'resolve', workflow: null, job: null, status: 'infrastructure-error', trust: 'trusted', daemon: '0v7.daemon.abcdef', reason: long('the dependencies could not be resolved: Actions/Checkout@V4'), started: 1, finished: 2, log: null, pinned: [] }],
  ['passed', job({ attempt: '0v1.passed', status: 'passed', daemon: '0v7.daemon.abcdef', events: 12 })],
]
const modelled = attemptRows(records.map(([, a]) => a), plan)
const rows = new Map(records.map(([name], i) => [name, modelled[i]]))
const lined = ['failed', 'infrastructure', 'older', 'plan', 'resolver']
const count = (haystack, needle) => haystack.split(needle).length - 1

test('every record keeps its reason, complete and in its own case, once and outside the badge', () => {
  for (const [name, row] of rows) {
    const { line, details } = attemptReason(row)
    const tree = h('div', null, renderAttemptReason(h, line), details && renderJobDetails(h, details))
    const shown = text(tree)
    if (!row.reason) {
      assert.equal(line, '', name)
      assert.equal(part(tree, 'attempt-reason'), null, name)
      continue
    }
    assert.equal(count(shown, row.reason), 1, `${name}: the reason is shown once`)
    if (lined.includes(name)) {
      assert.equal(text(part(tree, 'attempt-reason')), `Reason: ${row.reason}`, `${name}: a full-width line holds the whole reason`)
      assert.equal(part(tree, 'outcome-detail'), null, `${name}: the details do not repeat it`)
    } else {
      assert.equal(part(tree, 'attempt-reason'), null, `${name}: the decision details hold it`)
      assert.ok(text(part(tree, 'decision')).includes(row.reason), `${name}: in the summary, visible while closed`)
    }
  }
})

test('a refusal, a skip, a run that failed and an infrastructure record stay apart', () => {
  const view = (name) => {
    const tree = renderJobDetails(h, attemptReason(rows.get(name)).details)
    return { decision: text(part(tree, 'decision')), outcome: text(part(tree, 'outcome')) }
  }
  assert.ok(view('refused').decision.startsWith('Decision: Refuse: its condition could not be evaluated if '))
  assert.equal(view('refused').outcome, 'Not run')
  assert.ok(view('skipped').decision.startsWith('Decision: Skip if '))
  assert.equal(view('skipped').outcome, 'Skipped: not run')
  assert.equal(view('failed').decision, 'Decision: Run no prerequisites')
  assert.equal(view('failed').outcome, 'Failed')
  assert.equal(view('infrastructure').outcome, 'Not executed: infrastructure error')
  assert.equal(text(renderJobDetails(h, attemptReason(rows.get('older')).details)), 'Decision details are not available from this ship.')
  assert.equal(attemptReason(rows.get('plan')).details, null)
  assert.equal(attemptReason(rows.get('resolver')).details, null)
})

// what React escapes in text and attributes
const escape = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#x27;')

test('the attempt row renders through the app\'s JSX: the badge is the status, the job cell keeps its two lines', { skip }, async () => {
  const { React, renderToStaticMarkup, createServer } = deps
  const cacheDir = mkdtempSync(join(tmpdir(), 'urgit-ssr-'))
  const server = await createServer({ configLoader: 'native', cacheDir, server: { middlewareMode: true, ws: false, hmr: false, watch: null }, appType: 'custom' })
  try {
    const { AttemptRow } = await server.ssrLoadModule('/src/components/CiTab.jsx')
    for (const [name, row] of rows) {
      const html = renderToStaticMarkup(React.createElement(AttemptRow, { row, onLog() {} }))
      const start = html.indexOf('<div class="ci-attempt-row')
      const rowHtml = html.slice(start, html.indexOf('</div>', start) + '</div>'.length)
      const badge = rowHtml.match(/<span class="status [^"]*">([^<]*)<\/span>/)
      assert.ok(badge, `${name}: the badge holds text only`)
      assert.equal(badge[1], row.statusText, `${name}: the badge is the status`)
      assert.ok(row.statusText.length <= 12, `${name}: a short status`)
      if (row.reason) {
        assert.equal(count(html, escape(row.reason)), 1, `${name}: the reason is in the page once, as written`)
        assert.ok(!rowHtml.includes(escape(row.reason)), `${name}: not in the row, nor in a tooltip on it`)
      }
      assert.equal(html.includes('data-part="attempt-reason"'), lined.includes(name), `${name}: a reason line exactly where no decision shows it`)
      if (row.runsOn.length) {
        assert.ok(rowHtml.includes(`<span class="ci-job-cell"><strong>${row.job}</strong><small class="quiet ci-job-meta">manual.yml · <span class="ci-runs-on" title="runs-on">ubuntu-latest</span></small></span>`), `${name}: the two-line job cell`)
      }
    }
    const failed = renderToStaticMarkup(React.createElement(AttemptRow, { row: rows.get('failed'), onLog() {} }))
    assert.match(failed, /<button class="text-button">log<\/button>/, 'the log stays a button')
  } finally {
    await server.close()
    rmSync(cacheDir, { recursive: true, force: true })
  }
})

test('the reason line wraps the whole text in its own case; the badge style is unchanged', () => {
  const css = readFileSync(new URL('./style.css', import.meta.url), 'utf8')
  const rule = (selector) => (css.match(new RegExp(`^${selector.replace(/[.]/g, '\\.')} \\{([^}]*)\\}`, 'm')) || [])[1] || ''
  assert.match(rule('.ci-attempt-reason'), /overflow-wrap: anywhere/)
  assert.doesNotMatch(rule('.ci-attempt-reason') + rule('.ci-attempt-reason-text'), /text-transform|text-overflow|nowrap|max-height/)
  assert.match(rule('.ci-attempt-reason-text'), /white-space: pre-wrap/)
  assert.match(rule('.status'), /text-transform: uppercase/)
})
