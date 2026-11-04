import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { ci } from './api.js'

// Delivery 1C's surfaces are wired where the operator works: the CI tab
// switches between candidates, recorded events and schedules; its pull
// request links open the native pull request through the repository
// view's own navigation; the candidate page shows the selection; and the
// API reads the ship's routes. STATIC checks are on the source.

const source = (file) => readFileSync(new URL(file, import.meta.url), 'utf8')
// a failed match names what is missing, never prints the whole file
const has = (text, pattern, what) => assert.ok(pattern.test(text), `missing: ${what}`)

test('the events and schedules routes are the ship\'s, with the session', async () => {
  const seen = []
  globalThis.fetch = async (url, options = {}) => {
    seen.push({ url, method: options.method || 'GET', credentials: options.credentials })
    return { ok: true, status: 200, text: async () => '{"repo":"my repo","events":[],"schedules":[]}' }
  }
  await ci.events('my repo')
  await ci.schedules('my repo')
  assert.deepEqual(seen, [
    { url: '/apps/urgit/api/ci/repository/my%20repo/events', method: 'GET', credentials: 'same-origin' },
    { url: '/apps/urgit/api/ci/repository/my%20repo/schedules', method: 'GET', credentials: 'same-origin' },
  ])
})

test('STATIC: the CI tab switches between candidates, events and schedules, and shows a run\'s selection', () => {
  const tab = source('./components/CiTab.jsx')
  has(tab, /<EventLog repo=\{repo\}/, '/<EventLog repo=\\{repo\\}/')
  has(tab, /<Schedules repo=\{repo\}/, '/<Schedules repo=\\{repo\\}/')
  has(tab, /data-part="ci-view-candidates"/, '/data-part="ci-view-candidates"/')
  has(tab, /data-part="ci-view-events"/, '/data-part="ci-view-events"/')
  has(tab, /data-part="ci-view-schedules"/, '/data-part="ci-view-schedules"/')
  has(tab, /renderSelection\(createElement, selectionModel\(c\)/, '/renderSelection\\(createElement, selectionModel\\(c\\)/')
  has(tab, /onOpenPull/, '/onOpenPull/')
})

test('STATIC: a pull request link opens it by number in the repository view', () => {
  const view = source('./components/RepositoryView.jsx')
  has(view, /params\.get\('pull'\)/, "/params\\.get\\('pull'\\)/")
  has(view, /params\.set\('pull'/, "/params\\.set\\('pull'/")
  has(view, /<PullRequests repo=\{repo\}[^>]*initialPull=\{pull\}/, '/<PullRequests repo=\\{repo\\}[^>]*initialPull=\\{pull\\}/')
  has(view, /<CiTab repo=\{repo\}[^>]*onOpenPull=/, '/<CiTab repo=\\{repo\\}[^>]*onOpenPull=/')
})
