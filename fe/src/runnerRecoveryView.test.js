import test from 'node:test'
import assert from 'node:assert/strict'
import { initialRecoveryState, recoveryReducer } from './runnerRecovery.js'
import { renderRecovery } from './runnerRecoveryView.js'
import { NOW, RUNNER, command, h, legacyEntry, part, parts, text, unmetEntry, viewOf, vmEntry } from './runnerRecoveryFixtures.js'

// the legacy recovery panel as rendered (legacy-recovery UI ruling 01): the
// same renderRecovery the component calls, with a plain element factory —
// the inspection, the confirmation, and every command state, each told
// apart

const noop = { select() {}, openConfirm() {}, acknowledge() {}, cancel() {}, release() {}, refresh() {}, close() {} }
const render = (state) => renderRecovery(h, { runner: { id: RUNNER }, state, now: NOW }, noop)
const stateWith = (view, events = []) => events.reduce(recoveryReducer, recoveryReducer(initialRecoveryState(), { type: 'loaded', view }))

test('the list names each retention by its job, attempt and kind, and the inspection shows what it withholds, why, its provenance and every condition', () => {
  const view = viewOf([legacyEntry(), vmEntry()])
  const tree = render(stateWith(view, [{ type: 'select', selection: legacyEntry().selection }]))
  const rows = parts(tree, 'retention')
  assert.equal(rows.length, 2)
  assert.match(text(rows[0]), /owner\/repo · ci\.yml · build/)
  assert.match(text(rows[0]), /0v4\.att/)
  assert.equal(rows[0].props['data-kind'], 'legacy')
  assert.match(text(rows[1]), /no job label recorded/)
  const inspection = part(tree, 'inspection')
  assert.ok(inspection, 'THE SELECTED RETENTION WAS NOT INSPECTED')
  assert.match(text(inspection), /Withholds.*one slot of this runner/)
  assert.match(text(inspection), /reserve answer lost/)
  assert.match(text(inspection), /legacy: in a state file an earlier runner wrote last \(format 0\)/)
  assert.match(text(inspection), /owner\/repo refs\/heads\/master · ci\.yml · build — job failed/)
  const conditions = parts(tree, 'condition')
  assert.equal(conditions.length, 6, 'NOT EVERY CONDITION OF THE RELEASE WAS SHOWN')
  assert.ok(conditions.every((c) => c.props['data-met'] === 'yes'))
  assert.match(text(part(tree, 'facts')), /v1 at \/run\/l\.sock, protocol 4/)
  assert.match(text(part(tree, 'capacity')), /2 slots configured · 2 withheld/)
  assert.ok(part(tree, 'open-confirm'), 'A RELEASABLE LEGACY RETENTION WAS OFFERED NO RELEASE')
})

test('a retention without its proof, or of another kind, is offered no release, and says why', () => {
  const unmet = render(stateWith(viewOf([unmetEntry('attempt')]), [{ type: 'select', selection: legacyEntry().selection }]))
  assert.equal(part(unmet, 'open-confirm'), null, 'A LEGACY RETENTION WITHOUT ITS PROOF WAS OFFERED A RELEASE')
  assert.match(text(part(unmet, 'not-releasable')), /Not releasable now: The launcher holds nothing of its attempt\. The slot stays withheld/)
  assert.equal(parts(unmet, 'condition').filter((c) => c.props['data-met'] === 'no').length, 1)
  const vm = render(stateWith(viewOf([vmEntry()]), [{ type: 'select', selection: vmEntry().selection }]))
  assert.equal(part(vm, 'open-confirm'), null, 'A RETENTION OF ANOTHER KIND WAS OFFERED A RELEASE')
  assert.match(text(part(vm, 'not-releasable')), /urgit-runner -recover, the daemon stopped/)
  assert.equal(parts(vm, 'condition').length, 0)
})

test('the confirmation restates the exact entry, revision and evidence, and its release waits for the acknowledgment', () => {
  const events = [{ type: 'select', selection: legacyEntry().selection }, { type: 'confirm-open', now: NOW }]
  const tree = render(stateWith(viewOf([legacyEntry()]), events))
  const confirmation = part(tree, 'confirmation')
  assert.ok(confirmation, 'NO SEPARATE CONFIRMATION WAS SHOWN')
  assert.equal(confirmation.props.role, 'alertdialog')
  const restated = text(part(confirmation, 'restated'))
  assert.match(restated, /owner\/repo · ci\.yml · build/)
  assert.match(restated, /attempt 0v4\.att/)
  assert.match(restated, /revision 1/)
  assert.match(restated, /digest aaaaaaaaaaaa/)
  assert.equal(part(tree, 'release').props.disabled, true, 'A RELEASE COULD BE CONFIRMED WITHOUT ITS ACKNOWLEDGMENT')
  assert.equal(part(tree, 'open-confirm').props.disabled, true)
  const acknowledged = render(stateWith(viewOf([legacyEntry()]), [...events, { type: 'acknowledge', value: true }]))
  assert.equal(part(acknowledged, 'release').props.disabled, false)
  assert.equal(part(acknowledged, 'stale'), null)
})

test('a confirmation the runner\'s latest report no longer supports is stale: said, and its release disabled', () => {
  const events = [{ type: 'select', selection: legacyEntry().selection }, { type: 'confirm-open', now: NOW }, { type: 'acknowledge', value: true }, { type: 'loaded', view: viewOf([legacyEntry({ evidence: 'b'.repeat(64) })]) }]
  const tree = render(stateWith(viewOf([legacyEntry()]), events))
  assert.match(text(part(tree, 'stale')), /evidence changed since you inspected it/, 'A STALE CONFIRMATION WAS NOT SAID')
  assert.equal(part(tree, 'release').props.disabled, true, 'A STALE CONFIRMATION COULD BE RELEASED')
})

test('every command state is shown apart: queued, pending, uncertain, completed, refused and expired — completed only from the runner\'s answer', () => {
  const states = {
    queued: command('queued'),
    pending: command('delivered'),
    uncertain: command('uncertain', { detail: 'its release may or may not be recorded' }),
    completed: command('completed', { detail: 'released ci-0v4.att: its slot returns; advertised capacity now 2' }),
    refused: command('refused', { detail: 'its release is not proven now: attempt: the launcher holds t-4' }),
    expired: command('queued', { expires: NOW - 1 }),
  }
  const seen = new Set()
  for (const [want, c] of Object.entries(states)) {
    const tree = render(stateWith(viewOf([legacyEntry()], [c]), [{ type: 'select', selection: legacyEntry().selection }]))
    const line = part(part(tree, 'inspection'), 'command-state')
    assert.equal(line.props['data-state'], want, `THE ${want.toUpperCase()} STATE WAS NOT SHOWN AS ITSELF`)
    seen.add(text(line))
    if (want === 'completed') assert.match(text(line), /Released.*advertised capacity now 2/)
    if (want === 'refused') assert.match(text(line), /Refused.*The slot stays withheld/)
    if (want === 'uncertain') assert.match(text(line), /slot stays withheld/)
    if (want === 'queued') assert.doesNotMatch(text(line), /Released/, 'A QUEUED COMMAND WAS SHOWN RELEASED')
    // an open command blocks a second release
    assert.equal(Boolean(part(tree, 'open-confirm')), !['queued', 'pending', 'uncertain'].includes(want))
  }
  assert.equal(seen.size, 6)
})

test('a runner that has not reported, and one that withholds nothing, say so', () => {
  assert.match(text(render(stateWith({ ...viewOf([]), report: null }))), /has not reported its retentions/)
  assert.match(text(render(stateWith(viewOf([])))), /It withholds no slot/)
  assert.match(text(render(initialRecoveryState())), /Reading the runner’s retentions/)
})
