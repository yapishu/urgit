import test from 'node:test'
import assert from 'node:assert/strict'
import { makeRunWorkflow } from './runWorkflowComponent.js'
import { hooksRuntime, part, parts, settle, text } from './runnerRecoveryFixtures.js'
import { TIP, inventory, modelShip, repo } from './runWorkflowFixtures.js'

// the Run workflow component itself (Delivery 1A): its hooks run in the
// small runtime and it renders the element tree. Its ci API is the MODEL of
// the ship's dispatch contract (runWorkflowFixtures.js), labelled as such:
// the controller's own enforcement is exercised on the fake ship.

async function mount(ship = modelShip(), { onCreated } = {}) {
  const rt = hooksRuntime()
  let request = 0
  const created = []
  const RunWorkflow = makeRunWorkflow(rt.React, { ci: ship, newRequest: () => `run-test-${++request}` })
  rt.mount(RunWorkflow, { repo: repo(), onClose() {}, onCreated: (id, run) => { created.push({ id, run }); onCreated?.(id, run) } })
  await settle()
  return { ship, rt, created, tree: () => rt.tree() }
}

const control = (tree, id) => parts(tree, 'control').find((n) => n.props['data-id'] === id) || null
const fieldError = (tree, id) => parts(tree, 'field-error').find((n) => n.props['data-id'] === id) || null
const emptyToggle = (tree, id) => parts(tree, 'empty').find((n) => n.props['data-id'] === id) || null
const hint = (tree, id) => parts(tree, 'hint').find((n) => n.props['data-id'] === id) || null
const change = async (node, value) => { assert.ok(node, 'the control is not rendered'); node.props.onChange({ target: { value, checked: value } }); await settle() }
const click = async (node) => { assert.ok(node, 'the element to click is not rendered'); node.props.onClick(); await settle() }

test('it loads the ship\'s inventory and renders each declared input with its typed control, the workflow and branch chosen by name', async () => {
  const m = await mount()
  assert.equal(m.ship.reads, 1)
  const workflow = part(m.tree(), 'workflow')
  assert.equal(workflow.props.value, 'manual.yml')
  assert.deepEqual(workflow.children.map((o) => [o.props.value, text(o), Boolean(o.props.disabled)]), [['manual.yml', 'Manual release (manual.yml)', false], ['matrix.yml', 'Matrix (matrix.yml) — cannot run manually: job a: a matrix strategy is not supported in this release', true], ['release.yml', 'Release (release.yml)', false]])
  const ref = part(m.tree(), 'ref')
  assert.equal(ref.props.value, 'refs/heads/main')
  assert.deepEqual(ref.children.filter((o) => o.props.disabled).map((o) => o.props.value), ['refs/heads/feature', 'refs/heads/old'])
  assert.equal(control(m.tree(), 'dry_run').props.type, 'checkbox')
  assert.equal(control(m.tree(), 'count').props.inputMode, 'decimal')
  assert.equal(control(m.tree(), 'level').type, 'select')
  assert.equal(control(m.tree(), 'note').props.placeholder, 'default: hello')
  assert.deepEqual(control(m.tree(), 'target').children.map((o) => o.props.value), ['', 'production', 'staging'])
  m.rt.unmount()
})

test('it sends the intended typed values — a false toggle and a zero, the choice and the string left to their defaults — and opens the run the ship returned', async () => {
  const m = await mount()
  await change(control(m.tree(), 'count'), '0')
  await click(part(m.tree(), 'submit'))
  assert.deepEqual(m.ship.posts, [{ ref: 'refs/heads/main', workflow: 'manual.yml', tip: TIP, generation: 7, request: 'run-test-1', inputs: { dry_run: false, count: 0 } }])
  assert.equal(m.created.length, 1, 'THE RETURNED RUN WAS NOT OPENED')
  assert.equal(m.created[0].id, '0v1.run')
  assert.equal(m.created[0].run.event.name, 'workflow_dispatch')
  m.rt.unmount()
})

test('missing, the default\'s own text and an explicit empty text are three requests, each chosen with a control, never typed as JSON', async () => {
  // left alone: not supplied, so the ship applies the default hello
  const left = await mount()
  await click(part(left.tree(), 'submit'))
  assert.equal('note' in left.ship.posts[0].inputs, false)
  left.rt.unmount()
  // the default's text, typed: supplied
  const typed = await mount()
  await change(control(typed.tree(), 'note'), 'hello')
  await click(part(typed.tree(), 'submit'))
  assert.equal(typed.ship.posts[0].inputs.note, 'hello')
  typed.rt.unmount()
  // empty text, asked for with its own control: the field empties and
  // locks, the hint says the default does not apply, and "" is sent
  const blank = await mount()
  const toggle = emptyToggle(blank.tree(), 'note')
  assert.ok(toggle, 'NO CONTROL OFFERS EMPTY TEXT FOR AN INPUT WITH A DEFAULT')
  assert.equal(toggle.props.type, 'checkbox')
  for (const id of ['dry_run', 'count', 'level', 'target']) assert.equal(emptyToggle(blank.tree(), id), null, `${id} offers empty text`)
  await change(control(blank.tree(), 'note'), 'typed first')
  await change(emptyToggle(blank.tree(), 'note'), true)
  assert.equal(control(blank.tree(), 'note').props.value, '')
  assert.equal(control(blank.tree(), 'note').props.disabled, true)
  assert.equal(text(hint(blank.tree(), 'note')), 'Sends empty text: the default hello does not apply.')
  await click(part(blank.tree(), 'submit'))
  assert.deepEqual(blank.ship.posts[0].inputs, { dry_run: false, note: '' })
  blank.rt.unmount()
  // a required input with no default offers none: empty there is a refusal
  const release = await mount()
  await change(part(release.tree(), 'workflow'), 'release.yml')
  assert.equal(emptyToggle(release.tree(), 'version'), null)
  release.rt.unmount()
})

test('a number field says the number it sends, not text', async () => {
  const m = await mount()
  await change(control(m.tree(), 'count'), '0')
  assert.equal(text(hint(m.tree(), 'count')), 'Sent as the number 0.')
  await change(control(m.tree(), 'count'), '12.50')
  assert.equal(text(hint(m.tree(), 'count')), 'Sent as the number 12.5.')
  await click(part(m.tree(), 'submit'))
  assert.equal(m.ship.posts[0].inputs.count, 12.5)
  m.rt.unmount()
})

test('a field the ship would refuse is shown before submission, and nothing is posted', async () => {
  const m = await mount()
  await change(control(m.tree(), 'count'), '1e3')
  assert.equal(text(fieldError(m.tree(), 'count')), 'must be a plain decimal number, like 12 or -0.5')
  await click(part(m.tree(), 'submit'))
  assert.equal(m.ship.posts.length, 0, 'AN INVALID FORM WAS POSTED')
  await change(part(m.tree(), 'workflow'), 'release.yml')
  assert.equal(control(m.tree(), 'version').props.required, true)
  await click(part(m.tree(), 'submit'))
  assert.equal(text(fieldError(m.tree(), 'version')), 'is required')
  assert.equal(m.ship.posts.length, 0)
  m.rt.unmount()
})

test('when client validation is bypassed the ship\'s refusal is shown in its words, field by field, and no run is opened', async () => {
  const ship = modelShip()
  ship.refuseNext = Object.assign(new Error('1 input refused: note contains the value of a stored credential; a credential reaches a job only as a grant'), { status: 422, fields: { note: 'contains the value of a stored credential; a credential reaches a job only as a grant' } })
  const m = await mount(ship)
  await change(control(m.tree(), 'note'), 'x npm-fixture-value-1234 y')
  await click(part(m.tree(), 'submit'))
  assert.match(text(part(m.tree(), 'submit-error')), /1 input refused: note contains the value of a stored credential/)
  assert.equal(text(fieldError(m.tree(), 'note')), 'contains the value of a stored credential; a credential reaches a job only as a grant')
  assert.equal(m.created.length, 0)
  m.rt.unmount()
})

test('a stale form is refused with the reason and reloads; an unavailable branch states why', async () => {
  const ship = modelShip()
  const m = await mount(ship)
  ship.inv.generation = 8
  await click(part(m.tree(), 'submit'))
  assert.match(text(part(m.tree(), 'submit-error')), /changed since the form was loaded \(generation 7, now 8\)/)
  await click(part(m.tree(), 'reload'))
  assert.equal(ship.reads, 2)
  assert.equal(part(m.tree(), 'submit-error'), null)
  await change(part(m.tree(), 'ref'), 'refs/heads/old')
  assert.match(text(part(m.tree(), 'ref-reason')), /resolve and promote its revision again/)
  assert.equal(part(m.tree(), 'submit').props.disabled, true)
  m.rt.unmount()
})

test('a double click posts once; a lost answer is retried with the same request, so the ship answers the same run', async () => {
  const ship = modelShip()
  ship.loseNext = true
  const m = await mount(ship)
  await change(control(m.tree(), 'count'), '2')
  const submit = part(m.tree(), 'submit')
  submit.props.onClick()
  submit.props.onClick()
  await settle()
  assert.equal(ship.posts.length, 1, 'A DOUBLE CLICK POSTED TWICE')
  assert.match(text(part(m.tree(), 'submit-error')), /answer never arrived/)
  await click(part(m.tree(), 'retry'))
  assert.equal(ship.posts.length, 2)
  assert.equal(ship.posts[1].request, ship.posts[0].request, 'THE RETRY WAS NOT THE SAME REQUEST')
  assert.equal(m.created.length, 1)
  assert.equal(ship.runs.size, 1)
  m.rt.unmount()
})

test('without the ci-policy role the form says so and posts nothing; a failed read offers a retry', async () => {
  const m = await mount(modelShip(inventory({ authorized: false, authority: "only the repository's owner, or a ship holding its ci-policy role, runs a workflow manually" })))
  assert.match(text(part(m.tree(), 'unauthorized')), /ci-policy role/)
  assert.equal(part(m.tree(), 'submit').props.disabled, true)
  m.rt.unmount()
  const failing = modelShip()
  failing.failRead = true
  const f = await mount(failing)
  assert.match(text(part(f.tree(), 'load-error')), /Failed to fetch/)
  failing.failRead = false
  await click(part(f.tree(), 'retry-load'))
  assert.equal(part(f.tree(), 'workflow').props.value, 'manual.yml')
  f.rt.unmount()
})

test('a repository with no manual workflow says why for each branch', async () => {
  const m = await mount(modelShip(inventory({ refs: [] })))
  assert.match(text(part(m.tree(), 'no-workflows')), /No workflow of demo declares workflow_dispatch at a promoted baseline/)
  assert.equal(part(m.tree(), 'submit'), null)
  m.rt.unmount()
})
