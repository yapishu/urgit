import test from 'node:test'
import assert from 'node:assert/strict'
import { commandState } from './runnerRecovery.js'
import { NOW, command } from './runnerRecoveryFixtures.js'

// Independent review 07, R7-1 (runner/launcher/INTEGRATION.md §11.12, "Every
// final answer is recorded first"): the runner answers uncertain for every
// outcome it has not recorded yet — a release whose save was uncertain, a
// refusal not recorded yet, a message it cannot authenticate. The panel
// says no final answer is recorded, with the runner's own reason, keeps the
// command open, and never calls it a release's save alone.

test('an uncertain answer says no final answer is recorded yet, whatever the runner could not settle', () => {
  for (const detail of [
    "its release may or may not be recorded (state file: sync-dir failed)",
    'refused (its release is not proven now), but the refusal is not recorded durably yet (state file: create failed)',
    'not carried out, and nothing decided: this runner cannot authenticate it (signature does not verify)',
  ]) {
    const s = commandState(command('uncertain', { detail }), NOW)
    assert.equal(s.state, 'uncertain')
    assert.equal(s.open, true, 'AN UNCERTAIN ANSWER WAS TAKEN FOR A FINAL ONE')
    assert.match(s.detail, /no final answer/i, 'AN UNCERTAIN ANSWER DOES NOT SAY NO FINAL ANSWER IS RECORDED')
    assert.match(s.detail, /slot stays withheld/)
    assert.ok(s.detail.includes(detail), "THE RUNNER'S OWN REASON IS NOT SHOWN")
    assert.doesNotMatch(s.detail, /could not confirm that its release was saved/, "AN UNCERTAIN ANSWER WAS CALLED A RELEASE'S SAVE")
  }
})
