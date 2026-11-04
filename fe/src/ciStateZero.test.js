import test from 'node:test'
import assert from 'node:assert/strict'
import { readdirSync } from 'node:fs'
import { arm, deskText, type } from './hoonSource.js'

// The controller's one persisted shape (CI-STATE-PUBLISH-COLLAPSE-1).
// %urgit-ci was never published before this release, so it ships state-0
// with no conversion code. Source reading, not a run: a fresh-ship install
// is the parent's.

const current = deskText('sur/ci.hoon')
const controller = deskText('app/urgit-ci.hoon')

// the faces of a $: type's fields, in order (as ciStateNine.test.js reads
// them): the first after `$:  `, then each line at its column; a field
// written `=via` has the face via; the version tag is no field
function fields(typeText) {
  const lines = typeText.split('\n')
  const at = lines.findIndex((l) => /^\s*\$:\s{2}/.test(l))
  assert.ok(at >= 0, 'a $: type')
  const col = lines[at].indexOf('$:') + 4
  const out = []
  const push = (token) => {
    if (token.startsWith('%')) return
    const name = token.startsWith('=') ? token.slice(1) : token.slice(0, token.indexOf('='))
    assert.match(name, /^[a-z][a-z0-9-]*$/, `a field face in ${token}`)
    out.push(name)
  }
  push(lines[at].slice(col).split(/\s/)[0])
  for (const l of lines.slice(at + 1)) {
    if (!l.trim() || /^\s*::/.test(l)) continue
    const indent = l.length - l.trimStart().length
    if (indent < col) break
    if (indent === col) push(l.trim().split(/\s/)[0])
  }
  return out
}

test('sur/ci.hoon holds one state, state-0, tagged %0, with the recovery record last', () => {
  assert.match(current, /\+\$ {2}state-0\n {2}\$: {2}%0\n/)
  assert.doesNotMatch(current, /\+\$ {2}state-[1-9]/, 'no other state shape')
  const all = fields(type(current, 'state-0'))
  assert.equal(all.at(-1), 'recovery')
  assert.match(type(current, 'state-0'), /\n {6}recovery=recovery-state\n {2}==/)
  assert.equal(new Set(all).size, all.length, 'no field twice')
})

test('no frozen state, conversion library or migration vector is left', () => {
  const sur = readdirSync(new URL('../../desk/sur/', import.meta.url))
  assert.deepEqual(sur.filter((f) => f.startsWith('ci-state-')), [])
  const lib = readdirSync(new URL('../../desk/lib/', import.meta.url))
  assert.ok(!lib.includes('ci-migrate.hoon'))
  const gen = readdirSync(new URL('../../desk/gen/', import.meta.url))
  assert.ok(!gen.includes('ci-migration-vector.hoon'))
})

test('the controller saves and loads state-0 as it is', () => {
  assert.match(controller, /^=\| {2}state-0:ci$/m)
  assert.match(arm(controller, 'on-save'), /!>\(state\)/)
  assert.match(arm(controller, 'on-load'), /=\. {2}state {2}!<\(state-0:ci old\)/)
  assert.doesNotMatch(controller, /ci-migrate|state-migration/)
})

test('a fresh ship starts unpaused, with no checkpoint, no staged import and no history: the record\'s bunt is that', () => {
  const record = type(current, 'recovery-state')
  assert.deepEqual(fields(record), ['paused', 'checkpoints', 'staged', 'restores', 'history', 'sequence'])
  assert.match(record, /paused=\(unit \[at=@da actor=@p reason=@t\]\)/, 'a unit: its bunt is unpaused')
  assert.match(record, /checkpoints=\(list checkpoint\)/)
  assert.match(record, /staged=\(unit staged-checkpoint\)/)
  assert.match(record, /restores=\(list restore\)/)
  assert.match(record, /sequence=@ud/)
  for (const list of fields(type(current, 'restored-history'))) {
    assert.match(type(current, 'restored-history'), new RegExp(`${list}=\\(list `), `${list} is a list: its bunt is empty`)
  }
})

test('pull facts carry the labels, and the label of a labeled or unlabeled activity, last', () => {
  assert.match(type(current, 'pull-facts'), /labels=\(list @t\)\n {6}label=\(unit @t\)\n/)
  const update = fields(type(current, 'pull-update'))
  assert.deepEqual(update.slice(-3), ['state', 'labels', 'label'])
})

test('the controller refuses a malformed pull request update before reading it', () => {
  const admit = arm(controller, 'admit-pull')
  const order = ['(pull-update-error:ci-forge p)', '(verify-pull repo p)', '(label-outcome:ci-trigger p)', '(governing repo target-ref.p)'].map((s) => admit.indexOf(s))
  assert.ok(order.every((at) => at >= 0), `admit-pull reads ${order}`)
  assert.deepEqual([...order].sort((a, b) => a - b), order, 'malformed, then stale, then a closed or merged label change, then selection')
  assert.match(arm(controller, 'verify-pull'), /\(pull-stale:ci-forge p u\.u\.found\)/)
})
