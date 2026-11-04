import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, readFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { createServer } from 'vite'
import { changeSummary, labelBytes, labelEvents, labelProblem, sortLabels } from './pullLabels.js'
import { makePullLabels } from './pullLabelsComponent.js'
import { eventRows } from './ciDispatch.js'
import { forgeEventRows } from './ciEvents.js'
import { hooksRuntime, part, parts, settle, text } from './runnerRecoveryFixtures.js'

// Pull request labels (%urgit state-5). The component is the production
// one, mounted in the small hooks runtime and rendered through React. Its
// save is a MODEL of the ship's labels route: it answers what the ship
// answers (the labels it holds) or refuses with the ship's own words,
// copied from lib/ci-forge label-edit. No ship or browser runs here.

const OWNER_REFUSAL = 'only the repository owner and its writers may change pull request labels, because a label change can start CI'
const LIMIT_REFUSAL = 'labels must be an array of at most 20 non-empty strings, each at most 64 bytes'

function mountLabels(props) {
  const rt = hooksRuntime()
  const PullLabels = makePullLabels(rt.React)
  rt.mount(PullLabels, props)
  return { rt, tree: () => rt.tree() }
}

const type = async (m, value) => {
  part(m.tree(), 'label-input').props.onChange({ target: { value } })
  await settle()
  part(m.tree(), 'label-editor').props.onSubmit({ preventDefault() {} })
  await settle()
}
const click = async (node) => { assert.ok(node, 'the element to click is not rendered'); node.props.onClick({ preventDefault() {} }); await settle() }
const chips = (m) => parts(m.tree(), 'label-chip').map((c) => text(c.children[0]))

test('the limits are the issue route\'s: non-empty, at most 64 bytes, at most 20 labels', () => {
  assert.equal(labelProblem(''), 'A label cannot be empty.')
  assert.equal(labelProblem('   '), 'A label cannot be empty.')
  assert.equal(labelProblem('x'.repeat(64)), '')
  assert.equal(labelProblem('x'.repeat(65)), 'A label is at most 64 bytes. This one is 65 bytes.')
  // bytes, not characters: é is two bytes in UTF-8
  assert.equal(labelBytes('é'), 2)
  assert.equal(labelProblem('é'.repeat(32)), '')
  assert.match(labelProblem('é'.repeat(33)), /at most 64 bytes\. This one is 66 bytes/)
  assert.equal(labelProblem('bug', ['bug']), 'The pull request already has the label bug.')
  const twenty = Array.from({ length: 20 }, (_, i) => `l${i}`)
  assert.equal(labelProblem('one more', twenty), 'A pull request has at most 20 labels.')
  assert.equal(labelProblem('nineteen fit', twenty.slice(1)), '')
})

test('labels sort as the ship sorts cords, and one edit reports the events the ship reports, in name order', () => {
  assert.deepEqual(sortLabels(['wip', 'ci:fixtures', 'bug', 'Bug', 'bug']), ['Bug', 'bug', 'ci:fixtures', 'wip'])
  // lib/ci-forge pull-updates-of, and ci-forge-vector's case: add ci:fixtures
  // and docs, remove wip
  const events = labelEvents(['bug', 'wip'], ['bug', 'ci:fixtures', 'docs'])
  assert.deepEqual(events, [
    { action: 'labeled', label: 'ci:fixtures', labels: ['bug', 'ci:fixtures', 'wip'] },
    { action: 'labeled', label: 'docs', labels: ['bug', 'ci:fixtures', 'docs', 'wip'] },
    { action: 'unlabeled', label: 'wip', labels: ['bug', 'ci:fixtures', 'docs'] },
  ])
  assert.deepEqual(labelEvents(['bug'], ['bug']), [], 'no change is no event')
  assert.equal(changeSummary(events), 'Saving adds ci:fixtures and docs and removes wip.')
  assert.equal(changeSummary(labelEvents([], ['a', 'b', 'c'])), 'Saving adds a, b and c.')
  assert.equal(changeSummary(labelEvents(['a'], [])), 'Saving removes a.')
})

test('a writer edits the labels: adds and removes as free text, sees what saving does, and saves one edit', async () => {
  const saves = []
  const saved = []
  const m = mountLabels({
    labels: ['wip', 'bug'], editable: true,
    onSave: async (labels) => { saves.push(labels); return { ok: true, labels } },
    onSaved: (labels) => saved.push(labels),
  })
  await settle()
  assert.deepEqual(chips(m), ['bug', 'wip'], 'the labels in the ship\'s order')
  assert.ok(part(m.tree(), 'label-editor'))
  assert.equal(part(m.tree(), 'label-pending'), null, 'nothing pending before an edit')
  await type(m, '  ci:fixtures  ')
  await click(parts(m.tree(), 'label-remove').find((b) => b.props['aria-label'] === 'Remove label wip'))
  assert.deepEqual(chips(m), ['bug', 'ci:fixtures'])
  assert.equal(text(part(m.tree(), 'label-summary')), 'Saving adds ci:fixtures and removes wip.')
  assert.match(text(part(m.tree(), 'label-pending')), /one labeled or unlabeled event, which can start CI/)
  await click(part(m.tree(), 'label-save'))
  assert.deepEqual(saves, [['bug', 'ci:fixtures']], 'one save of the whole set')
  assert.deepEqual(saved, [['bug', 'ci:fixtures']])
  assert.equal(part(m.tree(), 'label-pending'), null, 'saved: nothing pending')
  assert.deepEqual(chips(m), ['bug', 'ci:fixtures'])
  m.rt.unmount()
})

test('a reader, or anyone the ship does not let change labels, sees them read-only with no control', async () => {
  const m = mountLabels({ labels: ['ci:fixtures', 'bug'], editable: false, onSave: () => assert.fail('a reader saved') })
  await settle()
  assert.deepEqual(chips(m), ['bug', 'ci:fixtures'])
  for (const control of ['label-editor', 'label-input', 'label-add', 'label-remove', 'label-save', 'label-pending']) {
    assert.equal(part(m.tree(), control), null, `a reader has no ${control}`)
  }
  m.rt.unmount()
  const none = mountLabels({ labels: [], editable: false })
  await settle()
  assert.equal(text(part(none.tree(), 'labels-none')), 'None')
  none.rt.unmount()
})

test('the ship\'s refusal is shown in its own words, and the draft is kept to retry', async () => {
  for (const refusal of [OWNER_REFUSAL, LIMIT_REFUSAL, 'pull request not found']) {
    let calls = 0
    const m = mountLabels({ labels: [], editable: true, onSave: async () => { calls += 1; throw new Error(refusal) } })
    await settle()
    await type(m, 'ci:fixtures')
    await click(part(m.tree(), 'label-save'))
    assert.equal(calls, 1)
    assert.equal(text(part(m.tree(), 'label-refusal')), refusal)
    assert.deepEqual(chips(m), ['ci:fixtures'], 'the draft stays')
    assert.equal(part(m.tree(), 'label-save').props.disabled, false, 'Save is offered again')
    await click(part(m.tree(), 'label-reset'))
    assert.deepEqual(chips(m), [])
    assert.equal(part(m.tree(), 'label-refusal'), null, 'Cancel clears the refusal')
    m.rt.unmount()
  }
})

test('a label past the limits is refused before any request', async () => {
  const m = mountLabels({ labels: Array.from({ length: 20 }, (_, i) => `l${String(i).padStart(2, '0')}`), editable: true, onSave: () => assert.fail('saved past the limits') })
  await settle()
  await type(m, 'one more')
  assert.equal(text(part(m.tree(), 'label-problem')), 'A pull request has at most 20 labels.')
  assert.equal(part(m.tree(), 'label-pending'), null)
  await click(part(m.tree(), 'label-remove'))
  await type(m, 'x'.repeat(65))
  assert.equal(text(part(m.tree(), 'label-problem')), 'A label is at most 64 bytes. This one is 65 bytes.')
  await type(m, 'x'.repeat(64))
  assert.equal(part(m.tree(), 'label-problem'), null)
  assert.equal(chips(m).length, 20)
  m.rt.unmount()
})

test('labels the ship changed elsewhere replace an untouched view, never a pending edit', async () => {
  const rt = hooksRuntime()
  const PullLabels = makePullLabels(rt.React)
  rt.mount(PullLabels, { labels: ['a'], editable: true, onSave: async (labels) => ({ labels }) })
  await settle()
  rt.mount(PullLabels, { labels: ['a', 'b'], editable: true, onSave: async (labels) => ({ labels }) })
  await settle()
  assert.deepEqual(parts(rt.tree(), 'label-chip').map((c) => text(c.children[0])), ['a', 'b'])
  rt.unmount()
})

// the CI run page and the event log say which label changed and who changed it
const labelEvent = (action, label, labels, actor = '~zod') => ({
  id: '0v1.run', status: 'pending', mode: 'event', trust: 'trusted',
  event: {
    name: 'pull_request', kind: 'pull-request', actor, route: 'pull request labels', ref: 'refs/heads/main',
    source: 'd1'.repeat(20), eventId: '0v1.ev', trigger: `pull_request #7 ${action} head ${'d1'.repeat(20)} base ${'b1'.repeat(20)} event 0v1.ev`,
    pull: { number: 7, title: 'Add x', action, head: 'd1'.repeat(20), headRef: 'refs/heads/feature', baseRef: 'refs/heads/main', base: 'b1'.repeat(20), merged: false, sourceShip: '~nec', sourceRepository: 'demo', labels, label },
    payload: '{}', payloadSha256: 'e'.repeat(64), inputs: [],
  },
})

test('the run page of a label event says which label was added or removed, and by whom', () => {
  const added = eventRows(labelEvent('labeled', 'ci:fixtures', ['ci:fixtures', 'docs']))
  assert.deepEqual(added.labelChange, { label: 'ci:fixtures', verb: 'added', by: '~zod', text: 'ci:fixtures added by ~zod' })
  assert.equal(added.activity, 'labeled ci:fixtures')
  assert.deepEqual(added.labels, ['ci:fixtures', 'docs'])
  const removed = eventRows(labelEvent('unlabeled', 'wip', [], '~bus'))
  assert.equal(removed.labelChange.text, 'wip removed by ~bus')
  // a pull request activity that is no label change names none
  const opened = eventRows(labelEvent('opened', null, []))
  assert.equal(opened.labelChange, null)
  assert.equal(opened.activity, 'opened')
  // the recorded event log names the label in the activity
  const rows = forgeEventRows({ events: [{ id: '0v1.ev', kind: 'pull-request', ref: 'refs/heads/main', actor: '~zod', route: 'pull request labels', outcome: 'recorded: a label change on a closed pull request runs no workflow', pull: labelEvent('unlabeled', 'wip', []).event.pull, runs: [] }] })
  assert.equal(rows[0].kindText, 'PR #7 unlabeled wip')
  assert.equal(rows[0].pull.label.text, 'wip removed by ~zod')
  assert.equal(rows[0].tone, 'quiet', 'a recorded change that ran nothing is no refusal')
})

test('the real components render: the run page names the label change, the editor shows only for a writer', async () => {
  const cacheDir = mkdtempSync(join(tmpdir(), 'urgit-labels-ui-'))
  const server = await createServer({ root: fileURLToPath(new URL('../', import.meta.url)), configLoader: 'native', cacheDir,
    server: { middlewareMode: true, ws: false, hmr: false, watch: null }, appType: 'custom' })
  try {
    const { EventFacts } = await server.ssrLoadModule('/src/components/CiTab.jsx')
    const facts = renderToStaticMarkup(React.createElement(EventFacts, { candidate: labelEvent('labeled', 'ci:fixtures', ['ci:fixtures']), repo: { name: 'demo' } }))
    assert.match(facts, /<dt>Label<\/dt><dd data-part="event-label"><strong>ci:fixtures<\/strong> added by ~zod<\/dd>/)
    assert.match(facts, /<dt>Labels<\/dt><dd data-part="event-labels">ci:fixtures <small class="quiet">after this event<\/small><\/dd>/)
    assert.match(facts, /labeled ci:fixtures/)
    const removed = renderToStaticMarkup(React.createElement(EventFacts, { candidate: labelEvent('unlabeled', 'wip', [], '~bus'), repo: { name: 'demo' } }))
    assert.match(removed, /<strong>wip<\/strong> removed by ~bus/)
    assert.doesNotMatch(removed, /<dt>Labels<\/dt>/, 'no label left is no list')
    const { default: PullLabels } = await server.ssrLoadModule('/src/components/PullLabels.jsx')
    const writer = renderToStaticMarkup(React.createElement(PullLabels, { labels: ['wip', 'bug'], editable: true, onSave: async () => ({}) }))
    assert.match(writer, /<li class="label-chip" data-part="label-chip"><span>bug<\/span><button type="button" class="label-remove" data-part="label-remove" aria-label="Remove label bug">×<\/button><\/li>/)
    assert.match(writer, /<input data-part="label-input" aria-label="New label" placeholder="Add a label"/)
    const reader = renderToStaticMarkup(React.createElement(PullLabels, { labels: ['wip', 'bug'], editable: false }))
    assert.match(reader, /<li class="label-chip" data-part="label-chip"><span>bug<\/span><\/li><li class="label-chip" data-part="label-chip"><span>wip<\/span><\/li>/)
    assert.doesNotMatch(reader, /<input|<button|label-editor/)
  } finally {
    await server.close()
    rmSync(cacheDir, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 })
  }
})

test('the pull request pages use the component: editable only when the ship says so, saved through the ship', () => {
  const local = readFileSync(new URL('./components/RepositoryView.jsx', import.meta.url), 'utf8')
  assert.match(local, /<PullLabels labels=\{diff\?\.labels \|\| selected\.labels \|\| \[\]\} editable=\{Boolean\(diff\?\.labelsEditable\)\} onSave=\{\(labels\) => api\.setPullLabels\(repo\.name, selected\.number, labels\)\}/)
  assert.match(local, /\{\(pull\.labels \|\| \[\]\)\.length > 0 && <div className="issue-labels inline" aria-label="Labels">/)
  const remote = readFileSync(new URL('./components/RemoteRepositoryView.jsx', import.meta.url), 'utf8')
  assert.match(remote, /labelsEditable: kind === 'pull' && found\.result\.labelsEditable === true/)
  assert.match(remote, /api\.peerPullLabels\(ship, repository, selected\.item\.number, labels\)/)
  assert.match(remote, /if \(!found\.ok\) throw new Error\(found\.message \|\| 'The repository owner refused the labels'\)/)
  assert.match(remote, /\{kind === 'pull' && <PullLabels labels=\{detail\?\.labels \|\| fallback\.labels \|\| \[\]\} editable=\{Boolean\(detail\?\.labelsEditable\)\} onSave=\{onSaveLabels\} \/>\}/)
  const api = readFileSync(new URL('./api.js', import.meta.url), 'utf8')
  assert.match(api, /request\(`\/repository\/\$\{encodeURIComponent\(name\)\}\/pulls\/\$\{number\}\/labels`, \{\n {6}method: 'POST', body: JSON\.stringify\(\{ labels \}\),/)
  assert.match(api, /request\('\/peer\/labels', \{\n {4}method: 'POST', body: JSON\.stringify\(\{ ship, repository, number, labels \}\),/)
})
