import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, readFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { agentBrief, briefFilename, runnersFor, setupComplete, setupSteps, workflowFiles } from './ciSetup.js'

// The CI tab's setup checklist and agent brief (hands-on review,
// 2026-10-19). The model, the brief's secret-free contract, the guide's
// sections, and the panel through real React.

const NOW = 1_800_000_000
const healthy = (over = {}) => ({ id: '0v1.r', enrolled: NOW - 100, lastSeen: NOW - 10, repos: null, ...over })
const bare = { repo: 'demo', storage: 'unconfigured', runners: [], policy: { repo: 'demo', baselines: [], ciProtected: [], networkPolicies: [] }, workflows: [], nowSeconds: NOW }
const byId = (steps) => Object.fromEntries(steps.map((s) => [s.id, s.status]))

test('workflow files are the YAML directly under .github/workflows', () => {
  const files = [{ path: '/.github/workflows/ci.yml' }, { path: '/.github/workflows/b.yaml' }, { path: '/.github/workflows/sub/x.yml' },
    { path: '/.github/workflows/notes.md' }, { path: '/README.md' }, '.github/workflows/a.yml']
  assert.deepEqual(workflowFiles(files), ['.github/workflows/a.yml', '.github/workflows/b.yaml', '.github/workflows/ci.yml'])
  assert.deepEqual(workflowFiles(undefined), [])
})

test('a fresh repository has every decidable step to do and network as a note', () => {
  const s = setupSteps(bare)
  assert.deepEqual(byId(s), { workflows: 'todo', storage: 'todo', runner: 'todo', binding: 'todo', baseline: 'todo', required: 'todo', network: 'info' })
  assert.equal(setupComplete(s), false)
})

test('each step ticks from its own state', () => {
  const done = setupSteps({ ...bare, storage: 'reachable', runners: [healthy()], workflows: ['.github/workflows/ci.yml'],
    policy: { baselines: [{ ref: 'refs/heads/master', revision: 'a' }], ciProtected: ['refs/heads/master'], networkPolicies: [] } })
  assert.deepEqual(byId(done), { workflows: 'done', storage: 'done', runner: 'done', binding: 'done', baseline: 'done', required: 'done', network: 'info' })
  assert.equal(setupComplete(done), true)
  assert.match(done.find((s) => s.id === 'required').detail, /master/)
})

test('a runner bound to other repositories, a stale runner and unreadable files are not done', () => {
  const other = setupSteps({ ...bare, runners: [healthy({ repos: ['elsewhere'] })] })
  assert.equal(byId(other).runner, 'done'); assert.equal(byId(other).binding, 'todo')
  assert.match(other.find((s) => s.id === 'binding').detail, /Repositories…/)
  const stale = setupSteps({ ...bare, runners: [healthy({ lastSeen: NOW - 900 })] })
  assert.equal(byId(stale).runner, 'todo')
  assert.match(stale.find((s) => s.id === 'runner').detail, /not healthy/)
  assert.equal(byId(setupSteps({ ...bare, workflows: null })).workflows, 'unknown')
  assert.equal(byId(setupSteps({ ...bare, storage: 'unknown' })).storage, 'unknown')
  assert.equal(setupComplete(setupSteps({ ...bare, storage: 'unknown' })), false)
  assert.equal(runnersFor('demo', [healthy({ revoked: NOW }), healthy({ repos: ['demo'] })], NOW).length, 1)
})

test('a configured store this browser cannot reach is set up, with the reason', () => {
  const s = setupSteps({ ...bare, storage: 'cors' }).find((x) => x.id === 'storage')
  assert.equal(s.status, 'done'); assert.match(s.detail, /cannot read/)
})

test('the agent brief names the ship and repository, the state, and the rules, and holds no secret', () => {
  const steps = setupSteps({ ...bare, runners: [healthy({ id: '0v7.daemon' })] })
  const md = agentBrief({ origin: 'https://ship.example', ship: '~zod', repo: 'demo', steps, generated: '2026-10-19T00:00:00Z' })
  assert.match(md, /^# Set up urgit CI for `demo`/)
  assert.match(md, /Ship web address: https:\/\/ship\.example/)
  assert.match(md, /Git remote: https:\/\/ship\.example\/git\/demo/)
  assert.match(md, /- \[x\] \*\*A runner is installed\*\*/)
  assert.match(md, /- \[ \] \*\*Object store configured\*\*/)
  assert.match(md, /Never run sudo or any command as root/)
  assert.match(md, /Never ask for, read, print or store a secret/)
  assert.match(md, /enroll_token = "PASTE-THE-TOKEN-HERE"/)
  assert.match(md, /Do not paste the token to me\./)
  assert.match(md, /## Step 6: prepare the repository/)
  assert.match(md, /strategy\.matrix/)
  // workflow-level concurrency runs (CI-CONCURRENCY-1); job-level is refused
  assert.match(md, /What runs:[^]*workflow-level\s+`concurrency` with `cancel-in-progress`[^]*Refused with the reason:/)
  assert.match(md, /Refused with the reason:[^]*job-level `concurrency`[^]*Read but ignored/)
  // pull request labels: labeled and unlabeled are supported, never refused
  assert.match(md, /What runs:[^]*Pull request activities include\s+`labeled` and `unlabeled`[^]*Refused with the reason:/)
  assert.doesNotMatch(md.slice(md.indexOf('Refused with the reason:'), md.indexOf('2. **Actions**')), /labeled/)
  assert.doesNotMatch(md.slice(md.indexOf('Read but ignored'), md.indexOf('2. **Actions**')), /concurrency/)
  assert.match(md, /99ad0f5cd0514a88aad0e9ae8cfdb3cc3b4ab9d190e1194602406c786b5de7a5/)
  // nothing that looks like a minted token, a daemon id, a bearer or a +code
  assert.doesNotMatch(md, /0v[0-9a-v]+\.[0-9a-v]{5}/)
  assert.doesNotMatch(md, /0v7\.daemon/)
  assert.doesNotMatch(md, /bearer\s*[=:]\s*\S/i)
  assert.doesNotMatch(md, /[a-z]{6}-[a-z]{6}-[a-z]{6}-[a-z]{6}/)
  assert.equal(briefFilename('my repo/x'), 'urgit-ci-setup-my-repo-x.md')
})

test('the brief takes no token argument at all', () => {
  const src = readFileSync(new URL('./ciSetup.js', import.meta.url), 'utf8')
  const sig = src.slice(src.indexOf('export function agentBrief('), src.indexOf(') {', src.indexOf('export function agentBrief(')))
  assert.doesNotMatch(sig, /token|bearer|code|secret|credential/i)
})

test('the setup guide covers repository preparation and the VM runner, not Docker as the only backend', () => {
  const guide = readFileSync(new URL('../../docs/ci-setup-guide.md', import.meta.url), 'utf8')
  for (const h of ['## Prepare your repository', '## 3. Install the runner', '## 4. Approve the workflows and require CI']) assert.ok(guide.includes(h), h)
  assert.match(guide, /urgit-vm-launcher/)
  assert.match(guide, /Not supported yet/)
  // workflow-level concurrency is supported (CI-CONCURRENCY-1) and the
  // job-level key refused with the reason; neither is listed as ignored,
  // as concurrency was before (hands-on review, 2026-10-19)
  const supported = guide.slice(guide.indexOf('**Supported**'), guide.indexOf('Not supported yet: refused'))
  const refused = guide.slice(guide.indexOf('Not supported yet: refused'), guide.indexOf('Not supported yet: ignored'))
  const ignored = guide.slice(guide.indexOf('Not supported yet: ignored'), guide.indexOf('**Network.**'))
  assert.ok(supported.length > 0 && refused.length > 0 && ignored.length > 0, 'the guide separates supported, refused and ignored keys')
  assert.match(supported, /Workflow-level `concurrency`, as a group name or as `group` and `cancel-in-progress`/)
  assert.match(supported, /result is \*\*cancelled\*\*/)
  assert.match(refused, /`concurrency` at job level/)
  // pull request labels: the two activities are supported and explained,
  // and neither is listed as refused or ignored
  assert.match(supported, /`pull_request` \(`opened`, `synchronize`, `closed`, `reopened`, `labeled`, `unlabeled`\)/)
  assert.match(supported, /Each label added or removed is one `labeled` or `unlabeled` event/)
  assert.match(supported, /`pull_request\.labels`/)
  assert.doesNotMatch(refused, /labeled/)
  assert.doesNotMatch(ignored, /labeled/)
  assert.doesNotMatch(ignored, /concurrency/)
  assert.match(guide, /Network policies/)
  assert.match(guide, /CI-required branches/)
  assert.doesNotMatch(guide, /the one backend in this release/)
  assert.doesNotMatch(guide, /turn on \*\*CI required\*\*/)
})

test('the CI tab shows the panel and Settings is one click away', () => {
  const tab = readFileSync(new URL('./components/CiTab.jsx', import.meta.url), 'utf8')
  assert.match(tab, /<CiSetupPanel repo=\{repo\} storage=\{probe\.state\} storageChecked=\{probe\.state !== 'unknown' \|\| Boolean\(probe\.error\)\} runners=\{feed\.runners\} policy=\{policy\}/)
  assert.match(tab, /setPolicy\(null\); ci\.policy\(repo\.name\)/)
  const view = readFileSync(new URL('./components/RepositoryView.jsx', import.meta.url), 'utf8')
  assert.match(view, /onSettings=\{\(\) => navigate\(\{ tab: 'settings'/)
})

let deps = null
try {
  const [react, server, vite] = await Promise.all([import('react'), import('react-dom/server'), import('vite')])
  deps = { React: react.default ?? react, renderToStaticMarkup: server.renderToStaticMarkup, createServer: vite.createServer }
} catch { deps = null }
const skip = deps ? false : 'fe/node_modules is not installed: the React render is NOT RUN here'

test('the panel renders its steps and the agent button through React', { skip }, async () => {
  const { React, renderToStaticMarkup, createServer } = deps
  const cacheDir = mkdtempSync(join(tmpdir(), 'urgit-setup-'))
  const server = await createServer({ configLoader: 'native', cacheDir, logLevel: 'silent', server: { middlewareMode: true, ws: false, hmr: false, watch: null }, appType: 'custom' })
  try {
    const { CiSetupPanel } = await server.ssrLoadModule('/src/components/CiSetup.jsx')
    // the first render has no file list yet: it says it is checking, shows
    // no step and offers no download
    const props = { repo: { name: 'demo', head: 'refs/heads/main' }, storage: 'unconfigured', storageChecked: true, runners: [], policy: bare.policy, ship: '~zod', onGuide() {}, onSettings() {} }
    const first = renderToStaticMarkup(React.createElement(CiSetupPanel, props))
    assert.match(first, /data-part="ci-setup-loading"/)
    assert.equal((first.match(/data-part="ci-setup-step"/g) || []).length, 0)
    assert.match(first, /data-part="ci-agent-brief" disabled=""/)
    // a policy still held from another repository is never shown as this one's
    const stale = renderToStaticMarkup(React.createElement(CiSetupPanel, { ...props, policy: { ...bare.policy, repo: 'other' } }))
    assert.match(stale, /data-part="ci-setup-loading"/)
    const { setupSteps: steps } = await server.ssrLoadModule('/src/ciSetup.js')
    const html = renderToStaticMarkup(React.createElement('ol', null, steps(bare).map((s) => React.createElement('li', { key: s.id, 'data-part': 'ci-setup-step', 'data-step': s.id, 'data-status': s.status }))))
    assert.equal((html.match(/data-part="ci-setup-step"/g) || []).length, 7)
    assert.match(html, /data-step="storage" data-status="todo"/)
    assert.match(html, /data-step="network" data-status="info"/)
    assert.match(first, /data-part="ci-agent-brief"/)
  } finally {
    await server.close()
    rmSync(cacheDir, { recursive: true, force: true })
  }
})
