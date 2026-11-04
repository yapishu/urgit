import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { inputEdit, inputProvenanceText, inputSupport, inputURLProblem } from './automaticInputs.js'
import { makeAutomaticInputs } from './automaticInputsComponent.js'
import { hooksRuntime, part, parts, settle, text } from './runnerRecoveryFixtures.js'
import { arm, deskText } from './hoonSource.js'

const url = 'https://inputs.example/tool.tar.gz'
const policy = (over = {}) => ({ generation: 4, canEditAutomaticInputs: true, automaticPolicyId: 'fixture-id', automaticInputs: { version: 1, sources: [] }, automaticResolvers: [], ...over })
const clone = (x) => JSON.parse(JSON.stringify(x))
async function mount(initial = policy(), options = {}) {
  let stored = clone(initial)
  const posts = []
  const api = {
    policy: async () => { if (options.readError) throw Error(options.readError); return clone(stored) },
    action: async (body) => {
      posts.push(clone(body))
      if (options.postError) throw Error(options.postError)
      assert.deepEqual(body, inputEdit('demo', stored, body.sources))
      stored = { ...stored, generation: stored.generation + 1, automaticInputs: { version: 1, sources: body.sources } }
    },
  }
  const rt = hooksRuntime()
  rt.React.useState = (initial) => rt.React.useReducer((state, next) => typeof next === 'function' ? next(state) : next, initial)
  rt.mount(makeAutomaticInputs(rt.React, api), { repo: 'demo', policy: initial })
  await settle()
  return { rt, posts, api, tree: () => rt.tree() }
}
const input = async (m, value) => { part(m.tree(), 'url').props.onChange({ target: { value } }); await settle() }
const click = async (m, name) => { const n = part(m.tree(), name); assert.ok(n); n.props.onClick(); await settle() }

test('URL grammar and exact policy body reject ambiguous and stale/unauthorized edits', () => {
  assert.equal(inputURLProblem(url), '')
  for (const bad of ['https://host/a', 'https://127.0.0.1/a', 'https://[::ffff:127.0.0.1]/a', 'https://user@inputs.example/a', 'https://inputs.example:443/a', 'https://inputs.example/a/../b', 'https://inputs.example/a%2fb', 'https://inputs.example/a?token=x', 'http://inputs.example/a', 'https://*.example/a']) assert.ok(inputURLProblem(bad), bad)
  assert.throws(() => inputEdit('demo', policy({ canEditAutomaticInputs: false }), [url]), /permission/)
  assert.throws(() => inputEdit('demo', policy({ generation: null }), [url]), /Reload/)
  assert.deepEqual(inputEdit('demo', policy(), [url]), { action: 'set-automatic-inputs', repo: 'demo', generation: 4, sources: [url] })
})

test('empty and permission-aware controls use actual mounted component', async () => {
  const readOnly = await mount(policy({ canEditAutomaticInputs: false }))
  assert.match(text(readOnly.tree()), /No sources allowed/)
  assert.ok(part(readOnly.tree(), 'read-only'))
  assert.equal(part(readOnly.tree(), 'add'), null)
  assert.equal(part(readOnly.tree(), 'url'), null)
  assert.equal(readOnly.posts.length, 0)
  const owner = await mount()
  assert.equal(part(owner.tree(), 'add').props.disabled, true)
  await input(owner, 'https://user@inputs.example/tool')
  assert.ok(part(owner.tree(), 'validation'))
  assert.equal(part(owner.tree(), 'add').props.disabled, true)
})

test('add/readback/remove roundtrip and double click use captured generation', async () => {
  const m = await mount()
  await input(m, url)
  const add = part(m.tree(), 'add')
  assert.equal(add.props.disabled, false)
  add.props.onClick(); add.props.onClick(); await settle()
  assert.equal(m.posts.length, 1)
  assert.deepEqual(m.posts[0], inputEdit('demo', policy(), [url]))
  assert.equal(parts(m.tree(), 'source').length, 1)
  assert.match(text(part(m.tree(), 'notice')), /saved and read back/)
  assert.match(text(part(m.tree(), 'effective')), /does not make it usable/)
  await click(m, 'remove')
  assert.equal(m.posts[1].generation, 5)
  assert.deepEqual(m.posts[1].sources, [])
  assert.ok(part(m.tree(), 'empty'))
})

test('refusal and lost readback never display success or broaden controls', async () => {
  for (const options of [{ postError: 'CI policy changed' }, { readError: 'Read unavailable' }]) {
    const m = await mount(policy(), options)
    await input(m, url); await click(m, 'add')
    assert.ok(part(m.tree(), 'error'))
    assert.equal(part(m.tree(), 'notice'), null)
    assert.equal(parts(m.tree(), 'source').length, 0)
    assert.match(text(part(m.tree(), 'error')), /Reload/)
  }
})

test('effective limits use runner titles and exact URL matches; stale reports are not usable', async () => {
  const p = policy({ automaticInputs: { version: 1, sources: [url] }, automaticResolvers: [{ id: 'opaque', name: 'microvm resolver · build', live: true, reported: true, sources: [url] }] })
  assert.match(inputSupport(p, url), /microvm resolver · build/)
  assert.match(inputSupport(p, `${url}/extra`), /No live resolver/)
  assert.match(inputSupport({ ...p, automaticResolvers: [{ ...p.automaticResolvers[0], live: false }] }, url), /No live resolver/)
  const m = await mount(p)
  assert.match(text(part(m.tree(), 'runner')), /microvm resolver · build/)
  assert.doesNotMatch(text(m.tree()), /opaque/)
})

test('provenance distinguishes cached imports and immutable automatic identities', () => {
  const cached = inputProvenanceText({ acquisition: 'cached prior resolution; no new external fetch authorized', inputPolicyId: 'now' })
  assert.match(cached, /cached prior resolution/)
  assert.match(cached, /Prior import or resolution/)
  const automatic = inputProvenanceText({ inputPolicyId: 'admitted', inputEvidence: { policyId: 'resolved', ceilingId: 'owner' } })
  assert.match(automatic, /Admitted policy admitted/)
  assert.match(automatic, /Resolution policy resolved; runner ceiling owner/)
})

test('real controller edit, capture, serializer and acceptance remain on the production path', () => {
  const c = deskText('app/urgit-ci.hoon')
  assert.match(arm(c, 'handle-action'), /edit:ci-input\s+state\s+repo\.act\s+sources\.act\s+expected\.act\s+\(authorized repo\.act %ci-policy ~ actor\.act\)/)
  assert.match(arm(c, 'admit-tag'), /put by input-snapshots/)
  assert.match(arm(c, 'manifest-of'), /scope:ci-input \(captured:ci-input state id\.c\)/)
  assert.match(arm(c, 'assignment-json'), /'automatic-inputs'.*envelope:ci-input/)
  assert.match(arm(c, 'handle-lock'), /evidence-valid:ci-input/)
  assert.match(arm(c, 'handle-lock'), /shax \(jam \[%automatic-input-v1 digest/)
  assert.match(arm(c, 'policy-json'), /canEditAutomaticInputs.*authorized/)
  assert.match(arm(c, 'workflow-provenance-json'), /cached prior resolution; no new external fetch authorized/)
})

test('narrow panels wrap URLs, identities and controls without fixed widths', () => {
  const css = readFileSync(new URL('./style.css', import.meta.url), 'utf8')
  assert.match(css, /\.ci-automatic-inputs, \.ci-input-provenance \{ min-width: 0; overflow-wrap: anywhere;/)
  assert.match(css, /\.ci-input-add input \{ width: 100%; min-width: 0; box-sizing: border-box;/)
})
