import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { approveHint, attemptPips, attemptRows, attemptStatusLabel, candidateRow, candidateStatusLabel, ciActions, credentialFormError, duration, lineText, noRunnerMessage, parseEnvs, pinnedNote, pinnedRows, renderLog, stagedEditNote } from './ci.js'
import { capturedConsumer, capturedPlan, capturedProducer, capturedStoppedConsumer } from './ciJobsCaptured.js'

const jobA = { attempt: '0v1.a', kind: 'job', job: 'a', status: 'passed', started: 100, finished: 130, log: { key: 'k', size: 1, sha256: 'x' } }
const jobB = { attempt: '0v2.b', kind: 'job', job: 'b', status: 'running', started: 130, finished: null, log: null }
const plan = { attempt: '0v0.p', kind: 'plan', status: 'passed', started: 90, finished: 95, log: null }

test('a candidate row carries the ref, short head, actor, status, age and one pip per job attempt, oldest first', () => {
  const row = candidateRow({ id: '0vc', ref: 'refs/heads/master', head: '1e09de1959cf796d658f2cbda78b3e439d60815d', actor: '~dep', status: 'pending', trust: 'trusted', pull: 4, created: 1000, attempts: [jobB, jobA, plan] }, 1090)
  assert.equal(row.ref, 'master')
  assert.equal(row.head, '1e09de19')
  assert.equal(row.actor, '~dep')
  assert.equal(row.pull, 4)
  assert.equal(row.ageSeconds, 90)
  assert.deepEqual(row.pips.map((p) => p.status), ['passed', 'running'])
  assert.deepEqual(attemptPips([plan]), [])
})

test('attempt rows name the plan step, show the log link only when the ship recorded a log, compute durations, and carry runs-on from the plan', () => {
  const rows = attemptRows([jobB, jobA, plan], [{ id: 'a', workflow: 'w.yml', runsOn: ['self-hosted', 'big-mem'] }])
  assert.deepEqual(rows.map((r) => r.job), ['b', 'a', 'plan'])
  assert.deepEqual(rows.map((r) => r.hasLog), [false, true, false])
  assert.equal(rows[1].elapsed, '30s')
  assert.equal(rows[0].elapsed, '')
  assert.deepEqual(attemptRows([{ ...jobA, workflow: 'w.yml' }], [{ id: 'a', workflow: 'w.yml', runsOn: ['self-hosted', 'big-mem'] }])[0].runsOn, ['self-hosted', 'big-mem'])
  assert.deepEqual(rows[2].runsOn, [])
  assert.equal(duration(10, 3710), '1h 1m')
  assert.equal(duration(10, 5), '')
})

test('the first-run message shows only for a CI-required repository with no enrolled, unrevoked runner; the approve hint names the policy', () => {
  assert.equal(noRunnerMessage([], []), '')
  assert.match(noRunnerMessage(['refs/heads/master'], []), /No runner is enrolled/)
  assert.match(noRunnerMessage(['refs/heads/master'], [{ enrolled: 1, revoked: 5 }]), /No runner is enrolled/)
  assert.equal(noRunnerMessage(['refs/heads/master'], [{ enrolled: 1, revoked: null }]), '')
  assert.match(approveHint('restricted'), /^Policy: run restricted checks/)
  assert.match(approveHint('approval'), /^Policy: wait for approval/)
})

test('the log renders act jsonl as [job] step: msg lines grouped by group/endgroup, and keeps non-event lines as text', () => {
  const text = [
    '{"job":"w/a","jobID":"a","step":"Set up job","msg":"start","time":"t"}',
    '{"job":"w/a","jobID":"a","command":"group","arg":"Install deps","msg":"::group::Install deps","time":"t"}',
    '{"job":"w/a","jobID":"a","step":"deps","msg":"npm ci","time":"t"}',
    '{"job":"w/a","jobID":"a","command":"endgroup","msg":"::endgroup::","time":"t"}',
    'time="..." level=warning msg="not json"',
    '{"job":"w/a","jobID":"a","jobResult":"success","msg":"done","time":"t"}',
    '',
  ].join('\n')
  const groups = renderLog(text)
  assert.equal(groups.length, 3)
  assert.equal(groups[0].title, '')
  assert.equal(lineText(groups[0].lines[0]), '[a] Set up job: start')
  assert.equal(groups[1].title, 'Install deps')
  assert.equal(lineText(groups[1].lines[0]), '[a] deps: npm ci')
  assert.equal(groups[2].lines[0].msg, 'time="..." level=warning msg="not json"')
  assert.equal(groups[2].lines[1].result, 'success')
})

test('the log renderer coerces every field to text and survives hostile lines', () => {
  const groups = renderLog('{"job":1,"jobID":{"x":1},"msg":["a"],"step":null,"command":{"nope":1}}\n{"command":"group","arg":{"o":1}}\n[1,2]\n')
  assert.equal(typeof groups[0].lines[0].msg, 'string')
  assert.equal(groups[0].lines[0].step, '')
  assert.equal(groups[1].title, '[object Object]')
  assert.equal(groups[1].lines[0].msg, '[1,2]')
})

test('action bodies are the pokes as JSON', () => {
  assert.deepEqual(ciActions.approve('0v1'), { action: 'approve-candidate', id: '0v1' })
  assert.deepEqual(ciActions.setCiProtected('r', 'refs/heads/master', 1), { action: 'set-ci-protected', repo: 'r', ref: 'refs/heads/master', protected: true })
  assert.deepEqual(ciActions.setUntrustedPolicy('r', 'restricted'), { action: 'set-untrusted-policy', repo: 'r', policy: 'restricted' })
  assert.deepEqual(ciActions.setCredential('r', 'TOKEN', 'hunter2hunter2', 'env', ['staging']), { action: 'set-credential', repo: 'r', name: 'TOKEN', value: 'hunter2hunter2', scope: 'env', envs: ['staging'] })
  assert.deepEqual(ciActions.deleteCredential('r', 'TOKEN'), { action: 'delete-credential', repo: 'r', name: 'TOKEN' })
})

test('the credential form refuses a missing name, a bad name, a short value and an env scope without environments', () => {
  assert.match(credentialFormError({ name: '', value: 'hunter2hunter2', scope: 'job', envs: '' }), /name/)
  assert.match(credentialFormError({ name: 'my token', value: 'hunter2hunter2', scope: 'job', envs: '' }), /letters/)
  assert.match(credentialFormError({ name: 'TOKEN', value: 'short', scope: 'job', envs: '' }), /8 characters/)
  assert.equal(credentialFormError({ name: 'TOKEN', value: 'line one\nline two', scope: 'job', envs: '' }), '')
  assert.match(credentialFormError({ name: 'TOKEN', value: 'hunter2hunter2', scope: 'env', envs: ' ' }), /environment/)
  assert.equal(credentialFormError({ name: 'TOKEN', value: 'hunter2hunter2', scope: 'env', envs: 'staging, production' }), '')
  assert.deepEqual(parseEnvs('staging, production\nqa'), ['staging', 'production', 'qa'])
})

test('a staged web edit reads as staged, never as committed; an applied one has no note', () => {
  const staged = { ok: true, staged: true, candidate: '0v1.abcde', trust: 'trusted', actor: '~zod', head: 'eef8913900000000000000000000000000000000', base: '6216f30200000000000000000000000000000000' }
  const note = stagedEditNote(staged, 'refs/heads/main', 'This edit')
  assert.match(note, /^This edit was staged as CI candidate 0v1\.abcde, not committed: main is CI-protected/)
  assert.match(note, /until the candidate's checks pass and it lands/)
  assert.match(stagedEditNote(staged, '', 'This deletion'), /^This deletion was staged .* the branch is CI-protected/)
  assert.equal(stagedEditNote({ ok: true, commit: 'eef8913900000000000000000000000000000000' }, 'refs/heads/main', 'This edit'), '')
  assert.equal(stagedEditNote(null, 'refs/heads/main'), '')
})

test('a run row carries the addresses each granted name was pinned to, text only, and nothing for a run granted no name', () => {
  const pinned = [{ name: 'archive.ubuntu.com', addrs: ['91.189.91.82', '185.125.190.81'] }, { name: 'bootstrap.urbit.org', addrs: ['104.21.64.85'] }]
  const [row] = attemptRows([{ ...jobA, pinned }])
  assert.deepEqual(row.pinned, pinned)
  assert.deepEqual(attemptRows([jobA])[0].pinned, [])
  assert.deepEqual(attemptRows([{ ...jobA, pinned: [] }])[0].pinned, [])
  // anything that is not a list of {name, addrs} is dropped, never guessed
  assert.deepEqual(pinnedRows('91.189.91.82'), [])
  assert.deepEqual(pinnedRows([null, { name: 7, addrs: [] }, { name: 'a.example' }, { name: 'b.example', addrs: ['1.1.1.1', 9] }]), [{ name: 'b.example', addrs: ['1.1.1.1'] }])
  assert.match(pinnedNote, /shared CDN/)
})

// correction 01 (R3): `skipped` means two things. A candidate skipped is
// superseded; a job attempt skipped was not run because its condition was
// false or a need did not succeed. The parent's captured run (verbatim):
// the false-condition sibling's row must read skipped
test('a skipped job attempt reads as skipped, a skipped candidate as superseded', () => {
  const rows = attemptRows([capturedConsumer, capturedStoppedConsumer, capturedProducer], capturedPlan)
  assert.deepEqual(rows.map((r) => [r.job, r.statusText]), [['consumer', 'infra error'], ['stopped-consumer', 'skipped'], ['producer', 'passed']])
  assert.deepEqual(attemptPips([capturedStoppedConsumer]).map((p) => p.statusText), ['skipped'])
  const superseded = candidateRow({ id: '0v1', ref: 'refs/heads/master', head: 'a'.repeat(40), actor: '~nec', status: 'skipped', created: 1, attempts: [capturedStoppedConsumer] }, 2)
  assert.equal(superseded.statusText, 'superseded')
  assert.equal(superseded.pips[0].statusText, 'skipped')
  assert.equal(candidateStatusLabel.skipped, 'superseded')
  assert.equal(attemptStatusLabel.skipped, 'skipped')
  assert.equal(candidateRow({ id: '0v2', status: 'unknown', created: 1 }, 2).statusText, 'unknown')
  assert.equal(attemptRows([{ ...capturedProducer, status: 'reoffered' }], capturedPlan)[0].statusText, 're-offered')
})

// STATIC, on the source: the tab shows each status at its own scope. Rows
// and pips show the statusText their model gave them (an attempt's by its
// attempt label, the list's by its candidate label); only the candidate
// page's own status is looked up, by the candidate label
test('the CI tab labels attempt statuses and candidate statuses apart', () => {
  const tab = readFileSync(new URL('./components/CiTab.jsx', import.meta.url), 'utf8')
  assert.match(tab, /title=\{`\$\{pip\.job\}: \$\{pip\.statusText\}`\}/)
  assert.equal((tab.match(/\{row\.statusText\}/g) || []).length, 2)
  assert.ok(!/statusLabel\[/i.test(tab.replace('candidateStatusLabel[c.status]', '')), 'a status label map is indexed outside the candidate page header')
})

// Delivery 1C: an automatic run is listed with the event it was for and
// as advisory (it never lands); a required run whose required evidence is
// absent is listed blocked, never as a pass
test('a candidate row names an automatic run\'s event and an absent required evidence', async () => {
  const { blockedRequired, pullRun, pushRun, scheduleRun } = await import('./ciEventsFixtures.js')
  const push = candidateRow(pushRun, pushRun.created + 5)
  assert.equal(push.event, 'push')
  assert.equal(push.advisory, true)
  assert.equal(push.manual, false)
  assert.equal(candidateRow(pullRun, 0).event, 'PR #7 opened')
  assert.equal(candidateRow(scheduleRun, 0).event, 'scheduled: nightly.yml #0')
  const blocked = candidateRow(blockedRequired, 0)
  assert.equal(blocked.event, '')
  assert.equal(blocked.advisory, false)
  assert.equal(blocked.evidenceAbsent, true)
  assert.equal(candidateRow({ ...blockedRequired, requiredEvidence: { complete: true, evaluated: true, missing: [] } }, 0).evidenceAbsent, false)
  assert.equal(candidateRow({ id: '0v1', status: 'passed', created: 1 }, 2).evidenceAbsent, false)
})
