import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { forgeEventRows, lateText, pullHref, runEventSummary, scheduleModel, selectionModel } from './ciEvents.js'
import { blockedRequired, eventsAnswer, mergedPull, newBranchRun, oid, pullRun, pushRun, scheduleRun, schedulesAnswer, schedulesNeedRefresh, unevaluatedRequired } from './ciEventsFixtures.js'

// Delivery 1C's operator models, over the JSON %urgit-ci serves (the
// fixtures MODEL it from the agent's source; the parent's live recipe reads
// the real one): what an automatic run was for, what its event selected and
// why, the source events recorded, and the schedules with their next,
// last and missed occurrences — every value from the server.

test('an automatic run says what it was for: a push, a pull request activity, a scheduled occurrence', () => {
  assert.deepEqual(runEventSummary(pushRun.event), { kind: 'push', label: 'Push', short: 'push' })
  assert.deepEqual(runEventSummary(newBranchRun.event), { kind: 'push', label: 'Push', short: 'push (new branch)' })
  assert.deepEqual(runEventSummary(pullRun.event), { kind: 'pull-request', label: 'Pull request', short: 'PR #7 opened' })
  assert.equal(runEventSummary({ ...pullRun.event, pull: mergedPull }).short, 'PR #7 closed (merged)')
  assert.deepEqual(runEventSummary(scheduleRun.event), { kind: 'schedule', label: 'Schedule', short: 'scheduled: nightly.yml #0' })
  // a staged push and a manual run are not automatic events
  assert.equal(runEventSummary(blockedRequired.event), null)
  assert.equal(runEventSummary({ name: 'workflow_dispatch', workflow: 'manual.yml' }), null)
  assert.equal(runEventSummary(null), null)
})

test('a selection lists every workflow with its verdict and the reason, selected apart from filtered out and from a trigger error', () => {
  const m = selectionModel(pushRun)
  assert.equal(m.basis, pushRun.selection.basis)
  assert.deepEqual(m.rows.map((r) => [r.workflow, r.verdictText, r.tone]), [['a-branches.yml', 'selected', 'good'], ['docs.yml', 'filtered out', 'quiet'], ['broken.yml', 'trigger error', 'bad']])
  assert.deepEqual(m.counts, { selected: 1, excluded: 1, error: 1 })
  assert.match(m.rows[1].reason, /no changed path passes paths \[docs\/\*\*\]/)
  assert.equal(m.required, null, 'an event run carries no required evidence')
  assert.equal(selectionModel({ ...pushRun, selection: null }), null)
})

test('a required run with an excluded workflow is blocked: its evidence is absent, never a pass, and only an override lands it', () => {
  const m = selectionModel(blockedRequired)
  assert.equal(m.required.complete, false)
  assert.deepEqual(m.required.missing.map((o) => o.workflow), ['docs.yml'])
  assert.match(m.required.text, /^Required evidence absent: docs\.yml was not selected/)
  assert.match(m.required.text, /stays blocked/)
  assert.equal(m.required.tone, 'bad')
  // filters not evaluated (a lock resolved before triggers): every push
  // workflow runs as before, and the page says the filters were not read
  const u = selectionModel(unevaluatedRequired)
  assert.equal(u.required.evaluated, false)
  assert.match(u.required.text, /^Filters not evaluated/)
  assert.match(u.note, /resolved before trigger definitions were read/)
})

test('recorded source events: what moved, how it arrived, what the selection decided and the runs it made', () => {
  const rows = forgeEventRows(eventsAnswer)
  assert.deepEqual(rows.map((r) => r.kindText), ['push', 'new branch', 'tag deletion', 'PR #7 opened', 'PR #7 closed (merged)', 'default branch'])
  assert.deepEqual(rows.map((r) => r.tone), ['good', 'quiet', 'quiet', 'good', 'bad', 'quiet'])
  const [push, created] = rows
  assert.equal(push.branch, 'main')
  assert.equal(push.move, `${oid('b').slice(0, 8)} → ${oid('c').slice(0, 8)}`)
  assert.equal(created.move, `new at ${oid('c').slice(0, 8)}`)
  assert.equal(rows[2].move, `deleted (was ${oid('b').slice(0, 8)})`)
  assert.equal(push.actor, '~zod')
  assert.equal(push.route, 'smart-http push (write token)')
  assert.deepEqual(push.runs, ['0v1.push'])
  assert.deepEqual(push.counts, { selected: 1, excluded: 1, error: 1 })
  assert.equal(rows[2].selection, null)
  assert.equal(rows[3].pull.number, 7)
  assert.equal(rows[3].pull.title, 'Add <b>x</b>', 'a title is text, never markup')
  assert.equal(rows[5].branch, 'trunk')
  assert.equal(forgeEventRows(null).length, 0)
  assert.equal(forgeEventRows({ events: 'nope' }).length, 0)
})

test('schedules by title with the source cron, the zone, the next and last occurrences, lateness, missed intervals and provenance, all as the ship computed them', () => {
  const m = scheduleModel(schedulesAnswer)
  assert.equal(m.asOf, '2026-10-16T10:13:20Z')
  assert.equal(m.defaultBranch, 'main')
  assert.equal(m.refresh, '')
  const [nightly, refused, retired] = m.rows
  assert.equal(nightly.title, 'Nightly')
  assert.equal(nightly.entry, 'nightly.yml #0')
  assert.equal(nightly.cron, '30 5 * * 1-5')
  assert.equal(nightly.zone, 'America/New_York')
  assert.deepEqual([nightly.stateText, nightly.tone], ['active', 'good'])
  assert.deepEqual(nightly.next, { local: '2026-10-19 05:30 UTC-04:00', utc: '2026-10-19T09:30:00Z' })
  assert.deepEqual(nightly.lastDue, { local: '2026-10-16 05:30 UTC-04:00', utc: '2026-10-16T09:30:00Z' })
  assert.equal(nightly.lastAdmitted.run, '0v1.sched')
  assert.equal(nightly.lastAdmitted.lateText, 'late by 2m 5s')
  assert.equal(nightly.lastAdmitted.at.local, '2026-10-16 05:32 UTC-04:00')
  assert.deepEqual(nightly.missed.map((x) => x.text), ['2 occurrences missed, 2026-10-14 05:30 UTC-04:00 to 2026-10-15 05:30 UTC-04:00: not run'])
  assert.equal(nightly.staleWakes, 1)
  assert.match(nightly.provenance, /^promoted by ~zod/)
  assert.match(nightly.provenance, /baseline aaaaaaaa/)
  assert.match(nightly.provenance, /lock 11111111/)
  assert.equal(nightly.definitionRef, 'main')
  assert.deepEqual([refused.stateText, refused.tone, refused.zone], ['refused', 'bad', 'UTC (default)'])
  assert.match(refused.reason, /refused rather than clamped/)
  assert.equal(refused.next, null)
  assert.deepEqual([retired.stateText, retired.tone], ['retired', 'quiet'])
  assert.match(retired.reason, /no longer defined/)
  // a schedule that is not active shows no next occurrence, whatever else
  // the answer carries (a retired or refused entry is never upcoming)
  const stale = { ...schedulesAnswer.schedules[2], next: schedulesAnswer.schedules[0].next, lastDue: schedulesAnswer.schedules[0].lastDue }
  assert.equal(scheduleModel({ schedules: [stale] }).rows[0].next, null, 'A RETIRED SCHEDULE SHOWS A NEXT OCCURRENCE')
  assert.equal(scheduleModel({ schedules: [{ ...stale, state: 'refused' }] }).rows[0].next, null)
  const r = scheduleModel(schedulesNeedRefresh)
  assert.equal(r.rows.length, 0)
  assert.match(r.refresh, /resolved and promoted again/)
  assert.equal(scheduleModel(null).rows.length, 0)
})

test('lateness reads as a duration, on time within the minute', () => {
  assert.equal(lateText(false, 30), 'on time')
  assert.equal(lateText(true, 125), 'late by 2m 5s')
  assert.equal(lateText(true, 7260), 'late by 2h 1m')
  assert.equal(lateText(true, 61), 'late by 1m 1s')
})

test('a native pull request opens by its number in the repository\'s pull request tab', () => {
  assert.equal(pullHref('demo', 7), '#/demo?tab=pulls&pull=7')
  assert.equal(pullHref('my repo', 12), '#/my%20repo?tab=pulls&pull=12')
})

// STATIC, on the source: the scheduler is the ship. Nothing in these
// modules ticks, schedules a timer or reads the browser's clock to compute
// an occurrence; and nothing renders markup from the server's text
test('the event and schedule surfaces read the ship\'s values and never tick a client clock or render markup', () => {
  for (const file of ['./ciEvents.js', './ciEventsView.js', './ciEventsComponent.js']) {
    const source = readFileSync(new URL(file, import.meta.url), 'utf8')
    assert.ok(!/setInterval|setTimeout|Date\.now|new Date\(/.test(source), `${file} keeps a client clock`)
    assert.ok(!/dangerouslySetInnerHTML|innerHTML/.test(source), `${file} renders markup`)
  }
})
