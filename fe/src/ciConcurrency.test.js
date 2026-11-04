import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { candidateRow, candidateStatusLabel, ciActions } from './ci.js'
import { cancelConfirmation, concurrencyModel, groupWaitTag, renderConcurrency } from './ciConcurrency.js'
import { makeRunConcurrency } from './ciConcurrencyComponent.js'
import { jobDetailsModel, waitingRows } from './ciJobs.js'
import { all, h, hooksRuntime, part, parts, settle, text } from './runnerRecoveryFixtures.js'
import {
  AUTHORITY, TRIAL, UNREAD, displacedRun, holdingRun, joiningRun, manualWaitingRun,
  member, noAuthorityRun, oldLockRun, operatorRun, refusedRun, stoppingRun, supersededRun, trialRun,
  unknownWorkflowRun, waitingRun,
} from './ciConcurrencyFixtures.js'

// The candidate page's concurrency panel and Cancel control
// (CI-CONCURRENCY-1): the model and view over runs shaped as the ship's
// candidate route answers (ciConcurrencyFixtures.js, a MODEL of the
// agent's answers), and the component mounted in the small hooks runtime
// with a modelled ci API. Not a browser: the parent rechecks the page live.

const rowsOf = (candidate) => concurrencyModel(candidate).rows

test('a waiting workflow run says which run it waits for and in which group, in plain words; ids are fine print', () => {
  const m = concurrencyModel(waitingRun)
  const [deploy, ci] = m.rows
  assert.equal(deploy.badge, 'waiting')
  assert.equal(deploy.tone, 'warn')
  assert.equal(deploy.text, 'waiting for run push of 1a2b3c4d to main in group deploy-main')
  assert.equal(deploy.group, 'deploy-main')
  assert.ok(!deploy.text.includes('0v1.older'), 'A RUN WAS NAMED BY ITS ID')
  assert.match(deploy.fine, /behind run 0v1\.older/)
  assert.match(deploy.fine, /cancel-in-progress: false/)
  assert.equal(ci.text, 'no concurrency group: the workflow declares none')
  assert.equal(ci.group, 'none')
  assert.equal(m.summary, '1 of 2 workflows in a concurrency group')
})

test('a run in progress in its group, and a workflow of it that finished and left its group', () => {
  const [deploy, lint] = rowsOf(holdingRun)
  assert.equal(deploy.badge, 'in progress')
  assert.equal(deploy.text, 'in progress in group deploy-main')
  assert.match(deploy.fine, /cancel-in-progress: true/)
  assert.equal(lint.badge, 'finished')
  assert.equal(lint.text, 'finished; it left group lint-main')
})

test('a run cancelled by a newcomer with cancel-in-progress says which run joined which group, and reads cancelled, not failed', () => {
  const [deploy] = rowsOf(supersededRun)
  assert.equal(deploy.badge, 'cancelled')
  assert.equal(deploy.tone, '', 'A CANCELLED RUN READS AS A FAILURE')
  assert.equal(deploy.text, 'cancelled: the newer run (push of 5e6f7a8b to main) joined group deploy-main with cancel-in-progress')
  assert.match(deploy.fine, /cancelled by run 0v1\.newer/)
  assert.equal(candidateStatusLabel.cancelled, 'cancelled')
  assert.notEqual(candidateStatusLabel.cancelled, candidateStatusLabel.failed)
  assert.equal(candidateRow(supersededRun, 0).statusText, 'cancelled')
})

test('a cancelled run still finishing says a job whose condition holds when cancelled, such as always(), still runs', () => {
  const [deploy] = rowsOf(stoppingRun)
  assert.equal(deploy.badge, 'cancelled')
  assert.match(deploy.text, /^cancelled: the newer run \(push of 5e6f7a8b to main\) joined group deploy-main with cancel-in-progress — stopping: /)
  assert.match(deploy.text, /always\(\), still runs/)
  assert.equal(deploy.open, false, 'a cancelled workflow is offered Cancel again')
})

test('an older waiting run displaced by a newer arrival says so and that it never started', () => {
  const [deploy] = rowsOf(displacedRun)
  assert.equal(deploy.badge, 'cancelled')
  assert.match(deploy.text, /^cancelled: a newer run \(push of 9c0d1e2f to main\) is waiting in group deploy-main/)
  assert.match(deploy.text, /it had not started, so none of its jobs runs/)
})

test('an operator\'s whole-run Cancel is shown once for the run, with who cancelled it', () => {
  const m = concurrencyModel(operatorRun)
  assert.equal(m.whole.reason, 'cancelled by ~zod: cancelled from the CI tab')
  assert.equal(m.rows[0].badge, 'cancelled')
  assert.equal(m.cancelRun, false)
  const tree = renderConcurrency(h, m)
  assert.equal(text(part(tree, 'run-cancelled')), 'The whole run: cancelled by ~zod: cancelled from the CI tab')
})

test('a group that cannot be evaluated refuses that workflow\'s run with the reason; the run\'s other workflow is untouched', () => {
  const [deploy, ci] = rowsOf(refusedRun)
  assert.equal(deploy.badge, 'refused')
  assert.equal(deploy.tone, 'bad')
  assert.equal(deploy.text, 'refused: its concurrency could not be evaluated: the concurrency group \'${{ inputs.group }}\' evaluated to the empty text')
  assert.equal(deploy.canCancel, false, 'a refused workflow run is offered Cancel')
  assert.equal(ci.canCancel, true)
})

test('unknown is not none: an old lock\'s run and an unlisted workflow say their concurrency was not read, and how to apply it', () => {
  const m = concurrencyModel(oldLockRun)
  assert.equal(m.summary, `Concurrency unknown: ${UNREAD}`)
  assert.equal(m.rows[0].group, '—')
  assert.ok(!/no concurrency group/.test(`${m.summary} ${m.rows[0].text}`), 'AN UNKNOWN GROUP READ AS NO GROUP')
  assert.equal(m.rows[0].canCancel, true, 'a run with unknown groups can still be cancelled')
  const [ci] = rowsOf(unknownWorkflowRun)
  assert.equal(ci.badge, 'unknown')
  assert.equal(ci.tone, 'warn')
  assert.equal(ci.text, `concurrency unknown: ${UNREAD}`)
})

test('a trial twin and a run not joined yet say why they are in no group', () => {
  assert.equal(concurrencyModel(trialRun).summary, `Takes part in no concurrency group: ${TRIAL}`)
  const joining = concurrencyModel(joiningRun)
  assert.match(joining.summary, /^Not joined yet: /)
  assert.equal(joining.cancelRun, true, 'a run with no workflow known yet can be cancelled whole')
  assert.equal(concurrencyModel({ id: 'x' }), null, 'a ship that sends no concurrency is shown nothing, not "no group"')
})

test('Cancel is offered only when the ship says this ship may cancel, and only for workflow runs still open', () => {
  const waiting = concurrencyModel(waitingRun)
  assert.equal(waiting.cancelRun, true)
  assert.deepEqual(waiting.rows.map((r) => r.canCancel), [true, true])
  assert.equal(waiting.authority, '')
  assert.deepEqual(rowsOf(holdingRun).map((r) => r.canCancel), [true, false], 'a finished workflow run is offered Cancel')
  const none = concurrencyModel(noAuthorityRun)
  assert.equal(none.cancelRun, false)
  assert.deepEqual(none.rows.map((r) => r.canCancel), [false, false])
  assert.equal(none.authority, AUTHORITY)
  const done = concurrencyModel(supersededRun)
  assert.equal(done.cancelRun, false)
  assert.equal(done.authority, '', 'a finished run explains a Cancel nobody could use')
  // every workflow finished or cancelled: nothing is left for the whole run's Cancel
  const closed = concurrencyModel({ ...holdingRun, concurrency: { ...holdingRun.concurrency, workflows: [holdingRun.concurrency.workflows[1]] } })
  assert.equal(closed.cancelRun, false)
})

test('the view hides every Cancel from a ship without the authority and says why; the badges hold their word alone', () => {
  const hidden = renderConcurrency(h, concurrencyModel(noAuthorityRun))
  assert.equal(part(hidden, 'cancel-run'), null)
  assert.equal(parts(hidden, 'cancel-workflow').length, 0)
  assert.equal(text(part(hidden, 'cancel-authority')), `No Cancel here: ${AUTHORITY}.`)
  const shown = renderConcurrency(h, concurrencyModel(waitingRun))
  assert.equal(text(part(shown, 'cancel-run')), 'Cancel run')
  assert.equal(parts(shown, 'cancel-workflow').length, 2)
  const rows = parts(shown, 'concurrency-row')
  assert.equal(text(part(rows[0], 'state-text')), 'waiting for run push of 1a2b3c4d to main in group deploy-main')
  assert.equal(text(part(rows[0], 'group-state')), 'waiting')
  assert.deepEqual(all(rows[0], (n) => n.props?.['data-label']).map((n) => n.props['data-label']), ['Group', 'State'])
  for (const badge of all(shown, (n) => /\bstatus\b/.test(n.props?.className || ''))) assert.equal(badge.props['data-label'], undefined, 'a badge names itself')
})

test('the confirmation says what stops, what still runs, the privileged case, and that a cancelled required run never lands', () => {
  const whole = cancelConfirmation(concurrencyModel(waitingRun))
  assert.equal(whole.title, 'Cancel this run?')
  assert.equal(whole.confirmLabel, 'Cancel run')
  assert.equal(whole.cancelLabel, 'Keep running', 'the dismiss button reads "Cancel" next to "Cancel run"')
  assert.match(whole.message, /a finished workflow keeps its result/)
  assert.match(whole.message, /such as always\(\)/)
  assert.match(whole.message, /privileged job closes as unknown and needs review/)
  assert.match(whole.message, /never lands and does not satisfy the branch's required checks/)
  const model = concurrencyModel(waitingRun)
  const one = cancelConfirmation(model, model.rows[0])
  assert.equal(one.title, 'Cancel Deploy?')
  assert.match(one.message, /Only its jobs stop; the run's other workflows keep running\./)
  assert.ok(!/never lands/.test(cancelConfirmation(concurrencyModel(manualWaitingRun)).message), 'an advisory run is told it would have landed')
})

test('the candidate list tags a run whose workflow waits in its group, naming the run it waits for in its title', () => {
  const row = candidateRow(waitingRun, 0)
  assert.deepEqual(row.groupWait, { text: 'waiting in group deploy-main', title: 'Deploy waits for run push of 1a2b3c4d to main in group deploy-main' })
  assert.equal(candidateRow(holdingRun, 0).groupWait, null)
  assert.equal(groupWaitTag({ concurrency: { workflows: [{ workflow: 'd.yml', group: member('waiting'), cancelled: { reason: 'x' } }] } }), null, 'a cancelled waiter is tagged waiting')
})

test('the cancel-run body names the run, and the workflow only when one is cancelled', () => {
  assert.deepEqual(ciActions.cancelRun('0v1.run'), { action: 'cancel-run', id: '0v1.run' })
  assert.deepEqual(ciActions.cancelRun('0v1.run', ''), { action: 'cancel-run', id: '0v1.run' })
  assert.deepEqual(ciActions.cancelRun('0v1.run', 'deploy.yml'), { action: 'cancel-run', id: '0v1.run', workflow: 'deploy.yml' })
})

test('a job its cancelled workflow run does not run reads as a cancel decision and was not run; one still to be recorded says so', () => {
  const attempt = { attempt: '0v1.a', kind: 'job', status: 'cancelled', events: 0, reason: 'not run: cancelled by ~zod: cancelled from the CI tab', decision: { verdict: 'cancel', reason: 'not run: cancelled by ~zod: cancelled from the CI tab', value: null }, needs: [] }
  const d = jobDetailsModel(attempt, null)
  assert.equal(d.decision.label, 'Cancel: its workflow\'s run was cancelled')
  assert.equal(d.outcome.label, 'Cancelled: not run')
  assert.equal(d.outcome.execution, 'not-run')
  const ran = jobDetailsModel({ ...attempt, events: 3, decision: { verdict: 'run', reason: 'no prerequisites', value: null } }, null)
  assert.equal(ran.outcome.label, 'Cancelled after it started')
  const rows = waitingRows({ status: 'pending', plan: [{ id: 'deploy', workflow: 'deploy.yml', decision: { verdict: 'cancel', reason: 'not run: cancelled: a newer run (x) is waiting in group g' } }] })
  assert.equal(rows[0].label, 'Cancel being recorded')
})

// the component in the hooks runtime, over a modelled ci API
function modelShip({ refuse = '', hold = false } = {}) {
  const ship = { actions: [], release: null }
  ship.action = (body) => {
    ship.actions.push(body)
    if (refuse) return Promise.reject(new Error(refuse))
    if (hold) return new Promise((resolve) => { ship.release = () => resolve({ ok: true }) })
    return Promise.resolve({ ok: true })
  }
  return ship
}

function mount(candidate, ship, answer = true) {
  const rt = hooksRuntime()
  const asked = []
  const changed = []
  const Panel = makeRunConcurrency(rt.React, { ci: ship })
  rt.mount(Panel, { candidate, confirm: async (options) => { asked.push(options); return answer }, onChanged: async () => { changed.push(1) } })
  return { rt, asked, changed, tree: () => rt.tree() }
}

const click = async (node) => { assert.ok(node, 'the control to click is not rendered'); node.props.onClick({ preventDefault() {} }); await settle() }

test('Cancel run asks first, then posts cancel-run for the whole run and reads the run again', async () => {
  const ship = modelShip()
  const m = mount(waitingRun, ship)
  await click(part(m.tree(), 'cancel-run'))
  assert.equal(m.asked.length, 1)
  assert.equal(m.asked[0].title, 'Cancel this run?')
  assert.deepEqual(ship.actions, [{ action: 'cancel-run', id: '0v1.run' }])
  assert.equal(m.changed.length, 1, 'the page did not read the run again')
  assert.match(text(part(m.tree(), 'cancel-done')), /^Cancel recorded/)
  m.rt.unmount()
})

test('a workflow\'s Cancel cancels that workflow alone', async () => {
  const ship = modelShip()
  const m = mount(waitingRun, ship)
  const [deploy] = parts(m.tree(), 'concurrency-row')
  await click(part(deploy, 'cancel-workflow'))
  assert.equal(m.asked[0].title, 'Cancel Deploy?')
  assert.deepEqual(ship.actions, [{ action: 'cancel-run', id: '0v1.run', workflow: 'deploy.yml' }])
  m.rt.unmount()
})

test('declining the confirmation posts nothing', async () => {
  const ship = modelShip()
  const m = mount(waitingRun, ship, false)
  await click(part(m.tree(), 'cancel-run'))
  assert.equal(m.asked.length, 1)
  assert.deepEqual(ship.actions, [])
  assert.equal(m.changed.length, 0)
  m.rt.unmount()
})

test('the ship\'s refusal is shown in its own words and nothing is claimed', async () => {
  const words = '~nec does not hold ci-policy for demo; the owner or a delegated binding is required'
  const ship = modelShip({ refuse: words })
  const m = mount(waitingRun, ship)
  await click(part(m.tree(), 'cancel-run'))
  assert.equal(text(part(m.tree(), 'cancel-refused')), `Not cancelled: ${words}`)
  assert.equal(part(m.tree(), 'cancel-done'), null, 'A REFUSED CANCEL WAS REPORTED AS RECORDED')
  assert.equal(m.changed.length, 0)
  m.rt.unmount()
})

test('while a Cancel is in flight every Cancel is disabled and the one pressed says so', async () => {
  const ship = modelShip({ hold: true })
  const m = mount(waitingRun, ship)
  const [deploy] = parts(m.tree(), 'concurrency-row')
  await click(part(deploy, 'cancel-workflow'))
  const tree = m.tree()
  assert.equal(part(tree, 'cancel-run').props.disabled, true)
  assert.deepEqual(parts(tree, 'cancel-workflow').map((b) => b.props.disabled), [true, true])
  assert.equal(text(part(parts(tree, 'concurrency-row')[0], 'cancel-workflow')), 'Cancelling…')
  ship.release()
  await settle()
  assert.equal(part(m.tree(), 'cancel-run').props.disabled, false)
  m.rt.unmount()
})

// the React component itself, server-rendered through Vite as the tab
// builds it (not a browser)
let deps = null
try {
  const [react, server, vite] = await Promise.all([import('react'), import('react-dom/server'), import('vite')])
  deps = { React: react.default ?? react, renderToStaticMarkup: server.renderToStaticMarkup, createServer: vite.createServer }
} catch {
  deps = null
}
const skip = deps ? false : 'fe/node_modules is not installed (react, react-dom, vite): the React render is NOT RUN here'

test('the React panel renders the group and state as text, labels its cells, and offers Cancel only with the authority', { skip }, async () => {
  const { React, renderToStaticMarkup, createServer } = deps
  const cacheDir = mkdtempSync(join(tmpdir(), 'urgit-ssr-'))
  const server = await createServer({ configLoader: 'native', cacheDir, server: { middlewareMode: true, ws: false, hmr: false, watch: null }, appType: 'custom' })
  try {
    const { RunConcurrency } = await server.ssrLoadModule('/src/components/CiConcurrency.jsx')
    const hostile = { ...waitingRun, concurrency: { ...waitingRun.concurrency, workflows: [{ ...waitingRun.concurrency.workflows[0], group: member('waiting', { text: '<img src=x onerror=alert(1)>', behind: { id: '0v1.o', label: '<b>older</b>' } }) }] } }
    const html = renderToStaticMarkup(React.createElement(RunConcurrency, { candidate: hostile, confirm: async () => false }))
    assert.ok(!html.includes('<img'), 'A GROUP NAME WAS RENDERED AS MARKUP')
    assert.ok(html.includes('waiting for run &lt;b&gt;older&lt;/b&gt; in group &lt;img src=x onerror=alert(1)&gt;'))
    for (const label of ['Group', 'State']) assert.ok(html.includes(`data-label="${label}"`), `labelled ${label}`)
    assert.ok(html.includes('data-part="cancel-run"'))
    const none = renderToStaticMarkup(React.createElement(RunConcurrency, { candidate: noAuthorityRun, confirm: async () => false }))
    assert.ok(!none.includes('data-part="cancel-run"') && !none.includes('data-part="cancel-workflow"'), 'A SHIP WITHOUT THE AUTHORITY WAS OFFERED CANCEL')
    assert.ok(none.includes('No Cancel here: only the repository&#x27;s owner, or a ship holding its ci-policy role, cancels a run.'))
  } finally {
    await server.close()
    // Vite may still be writing its dependency cache as it closes
    rmSync(cacheDir, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 })
  }
})
