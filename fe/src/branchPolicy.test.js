import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, readFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { addCandidates, branchLabel, filterCandidates, policyRows } from './branchPolicy.js'

// Branch policy lists (hands-on review, 2026-10-19: one row per branch
// was unreadable for a repository with 160 branches). The model, then the
// component through real React (vite's SSR loader, as other render tests).

const refs = [
  { name: 'refs/heads/master', oid: 'a' }, { name: 'refs/heads/dev', oid: 'b' },
  { name: 'refs/heads/erpit/t_43c7-row-4a', oid: 'c' }, { name: 'refs/heads/Feature-X', oid: 'd' },
  { name: 'refs/tags/v1', oid: 'e' },
]

test('rows are the chosen branches only, sorted, deleted ones kept and marked', () => {
  const rows = policyRows(['refs/heads/master', 'refs/heads/gone', 'refs/heads/dev', 'refs/heads/master'], refs)
  assert.deepEqual(rows.map((r) => [r.label, r.deleted]), [['dev', false], ['gone', true], ['master', false]])
  assert.deepEqual(policyRows([], refs), [])
  assert.deepEqual(policyRows(undefined, refs), [])
  assert.deepEqual(policyRows(['refs/tags/v1'], refs), [], 'a tag is never a branch policy row')
})

test('candidates are every branch not already chosen, never tags', () => {
  const c = addCandidates(['refs/heads/master'], refs)
  assert.deepEqual(c.map((x) => x.label), ['dev', 'erpit/t_43c7-row-4a', 'Feature-X'])
  assert.ok(c.every((x) => x.ref.startsWith('refs/heads/')))
  assert.equal(addCandidates(refs.map((r) => r.name), refs).length, 0)
})

test('the filter is case-insensitive substring, bounded, and reports the rest', () => {
  const all = addCandidates([], refs)
  assert.deepEqual(filterCandidates(all, 'ROW-4').shown.map((x) => x.label), ['erpit/t_43c7-row-4a'])
  assert.deepEqual(filterCandidates(all, ' feature ').shown.map((x) => x.label), ['Feature-X'])
  assert.equal(filterCandidates(all, 'nothing').total, 0)
  const many = Array.from({ length: 160 }, (_, i) => ({ ref: `refs/heads/b${i}`, label: `b${i}` }))
  const f = filterCandidates(many, '')
  assert.equal(f.shown.length, 50); assert.equal(f.more, 110); assert.equal(f.total, 160)
  assert.equal(branchLabel('refs/heads/x/y'), 'x/y')
})

test('Settings no longer renders one row per branch', () => {
  const src = readFileSync(new URL('./components/RepositoryView.jsx', import.meta.url), 'utf8')
  assert.doesNotMatch(src, /refs \|\| \[\]\)\.filter\(\(entry\) => entry\.name\.startsWith\('refs\/heads\/'\)\)\.map/)
  assert.equal((src.match(/<BranchPolicyList/g) || []).length, 2)
  assert.match(src, /part="protected-branches"/)
  assert.match(src, /part="ci-required-branches"/)
  assert.match(src, /onAdd=\{\(ref\) => ciRequiredToggle\(ref, true\)\}/)
  assert.match(src, /onRemove=\{\(ref\) => ciRequiredToggle\(ref, false\)\}/)
  assert.match(src, /api\.setProtected\(repo\.name, ref, true\)/)
  assert.match(src, /api\.setProtected\(repo\.name, ref, false\)/)
})

let deps = null
try {
  const [react, server, vite] = await Promise.all([import('react'), import('react-dom/server'), import('vite')])
  deps = { React: react.default ?? react, renderToStaticMarkup: server.renderToStaticMarkup, createServer: vite.createServer }
} catch { deps = null }
const skip = deps ? false : 'fe/node_modules is not installed: the React render is NOT RUN here'

test('the list renders the chosen branches, messages, empty text and a disabled add when nothing is left', { skip }, async () => {
  const { React, renderToStaticMarkup, createServer } = deps
  const cacheDir = mkdtempSync(join(tmpdir(), 'urgit-bpl-'))
  const server = await createServer({ root: new URL('..', import.meta.url).pathname, cacheDir, logLevel: 'silent', server: { middlewareMode: true, hmr: false }, appType: 'custom', optimizeDeps: { noDiscovery: true, include: [] } })
  try {
    const { default: BranchPolicyList } = await server.ssrLoadModule('/src/components/BranchPolicyList.jsx')
    const base = { part: 'p', title: 'Protected branches', description: 'd', refs, rowNote: 'Fast-forward updates only.', emptyText: 'No protected branches.', removeConfirm: () => ({}), onAdd() {}, onRemove() {} }
    const html = renderToStaticMarkup(React.createElement(BranchPolicyList, { ...base, chosen: ['refs/heads/master', 'refs/heads/gone'], rowMessages: (ref) => ref === 'refs/heads/master' ? [{ text: 'no object store', className: 'field-error' }] : [] }))
    assert.equal((html.match(/data-part="branch-policy-row"/g) || []).length, 2)
    assert.match(html, /<strong>gone<\/strong><small class="status warn">branch deleted<\/small>/)
    assert.match(html, /no object store/)
    assert.match(html, /aria-label="Remove master from protected branches"/)
    assert.match(html, /data-part="branch-policy-add"/)
    assert.doesNotMatch(html, /<strong>dev<\/strong>/, 'unchosen branches are not listed')
    const empty = renderToStaticMarkup(React.createElement(BranchPolicyList, { ...base, chosen: [] }))
    assert.match(empty, /data-part="branch-policy-empty">No protected branches\./)
    const full = renderToStaticMarkup(React.createElement(BranchPolicyList, { ...base, chosen: refs.map((r) => r.name) }))
    assert.match(full, /data-part="branch-policy-add" disabled=""/)
    assert.match(full, /Every branch is already listed\./)
  } finally {
    await server.close()
    rmSync(cacheDir, { recursive: true, force: true })
  }
})
