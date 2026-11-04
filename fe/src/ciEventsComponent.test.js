import test from 'node:test'
import assert from 'node:assert/strict'
import { makeEventLog, makeSchedules } from './ciEventsComponent.js'
import { renderSelection } from './ciEventsView.js'
import { selectionModel } from './ciEvents.js'
import { h, hooksRuntime, part, parts, settle, text } from './runnerRecoveryFixtures.js'
import { blockedRequired, modelCi, pushRun, schedulesNeedRefresh } from './ciEventsFixtures.js'

// the CI tab's Events and Schedules panels (Delivery 1C), mounted in the
// small hooks runtime. Their ci API is a MODEL of the ship's routes
// (ciEventsFixtures.js), labelled as such; the agent's own answers are the
// parent's live recipe.

async function mount(make, ship, props = {}) {
  const rt = hooksRuntime()
  const opened = { runs: [], pulls: [] }
  const Panel = make(rt.React, { ci: ship })
  rt.mount(Panel, { repo: { name: 'demo' }, onOpenRun: (id) => opened.runs.push(id), onOpenPull: (n) => opened.pulls.push(n), ...props })
  return { rt, ship, opened, tree: () => rt.tree() }
}

const click = async (node, event) => { assert.ok(node, 'the element to click is not rendered'); node.props.onClick(event || { preventDefault() {} }); await settle() }

test('the events panel says it is loading, then lists each recorded event with its outcome and the runs it made', async () => {
  const m = await mount(makeEventLog, modelCi())
  assert.match(text(part(m.tree(), 'events-loading')), /Loading recorded events/)
  await settle()
  assert.equal(m.ship.reads.events, 1)
  const rows = parts(m.tree(), 'event-row')
  assert.equal(rows.length, 6)
  assert.match(text(rows[0]), /push/)
  assert.match(text(rows[0]), /1 workflow\(s\) selected: run 0v1\.push/)
  assert.match(text(rows[0]), /smart-http push \(write token\)/)
  assert.match(text(rows[4]), /refused: pull request #7 is open now/)
  // the selection's reasons are in the row's details, text only
  assert.match(text(part(rows[0], 'event-selection')), /no changed path passes paths \[docs\/\*\*\]/)
  // a run opens on the candidate page; a native pull request in its tab
  await click(part(rows[0], 'open-run'))
  assert.deepEqual(m.opened.runs, ['0v1.push'])
  const pr = part(rows[3], 'open-pull')
  assert.equal(pr.props.href, '#/demo?tab=pulls&pull=7')
  let prevented = false
  await click(pr, { preventDefault() { prevented = true } })
  assert.deepEqual(m.opened.pulls, [7])
  assert.equal(prevented, true, 'the link navigated the page instead of the repository view')
  assert.equal(text(part(rows[3], 'pull-title')), 'Add <b>x</b>')
  m.rt.unmount()
})

test('a failed read says why and offers a retry; Refresh reads the ship again', async () => {
  const ship = modelCi()
  ship.failRead = true
  const m = await mount(makeEventLog, ship)
  await settle()
  assert.match(text(part(m.tree(), 'events-error')), /Failed to fetch/)
  assert.equal(parts(m.tree(), 'event-row').length, 0, 'AN ERROR WAS SHOWN AS AN EMPTY LIST')
  ship.failRead = false
  await click(part(m.tree(), 'events-retry'))
  assert.equal(parts(m.tree(), 'event-row').length, 6)
  await click(part(m.tree(), 'events-refresh'))
  assert.equal(ship.reads.events, 3)
  m.rt.unmount()
})

test('no recorded event is its own state, not a loading or an error', async () => {
  const m = await mount(makeEventLog, modelCi({ events: { repo: 'demo', now: 1, events: [] } }))
  await settle()
  assert.match(text(part(m.tree(), 'events-empty')), /No source event is recorded for this repository yet/)
  assert.equal(part(m.tree(), 'events-error'), null)
  m.rt.unmount()
})

test('the schedules panel lists each schedule by title with its cron, zone, next and last occurrence, lateness and provenance, as of the ship\'s clock', async () => {
  const m = await mount(makeSchedules, modelCi())
  assert.match(text(part(m.tree(), 'schedules-loading')), /Loading schedules/)
  await settle()
  assert.match(text(part(m.tree(), 'schedules-as-of')), /2026-10-16T10:13:20Z/)
  const rows = parts(m.tree(), 'schedule-row')
  assert.equal(rows.length, 3)
  const [nightly, refused, retired] = rows
  assert.match(text(part(nightly, 'schedule-title')), /^Nightly/)
  assert.equal(text(part(nightly, 'schedule-cron')), '30 5 * * 1-5')
  assert.equal(text(part(nightly, 'schedule-zone')), 'America/New_York')
  assert.match(text(part(nightly, 'schedule-next')), /2026-10-19 05:30 UTC-04:00/)
  assert.match(text(part(nightly, 'schedule-next')), /2026-10-19T09:30:00Z/)
  assert.match(text(part(nightly, 'schedule-last')), /late by 2m 5s/)
  assert.match(text(part(nightly, 'schedule-missed')), /2 occurrences missed/)
  assert.match(text(part(nightly, 'schedule-provenance')), /promoted by ~zod/)
  await click(part(nightly, 'open-run'))
  assert.deepEqual(m.opened.runs, ['0v1.sched'])
  assert.match(text(refused), /refused/)
  assert.match(text(refused), /refused rather than clamped/)
  assert.equal(part(refused, 'schedule-next'), null, 'A REFUSED SCHEDULE SHOWS A NEXT OCCURRENCE')
  assert.match(text(retired), /no longer defined/)
  m.rt.unmount()
})

test('a default branch whose catalog must be refreshed says so, and no schedule is not an error', async () => {
  const m = await mount(makeSchedules, modelCi({ schedules: schedulesNeedRefresh }))
  await settle()
  assert.match(text(part(m.tree(), 'schedules-refresh')), /resolved and promoted again/)
  assert.match(text(part(m.tree(), 'schedules-empty')), /No schedule is registered/)
  assert.equal(part(m.tree(), 'schedules-error'), null)
  m.rt.unmount()
})

test('the candidate page\'s selection panel lists every workflow\'s verdict, and a blocked required run says its evidence is absent', () => {
  const tree = renderSelection(h, selectionModel(blockedRequired))
  assert.match(text(part(tree, 'required-evidence')), /^Required evidence absent: docs\.yml was not selected/)
  assert.deepEqual(parts(tree, 'selection-row').map((r) => text(part(r, 'selection-verdict'))), ['selected', 'filtered out'])
  assert.match(text(part(tree, 'selection-basis')), /two-dot/)
  const event = renderSelection(h, selectionModel(pushRun))
  assert.equal(part(event, 'required-evidence'), null)
  assert.equal(parts(event, 'selection-row').length, 3)
  assert.equal(renderSelection(h, null), null)
})
