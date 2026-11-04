// The bindings and first assertions the adapted source-pattern tests rely on,
// read from the agent itself: each action, route and wire through the switch
// that runs, and each writer's guard as the first thing its arm asserts.
import test from 'node:test'
import assert from 'node:assert/strict'
import { actionArm, deskText, entryGuard, routeArm, wireArm } from './hoonSource.js'

const agent = deskText('app/urgit.hoon')

test('each action the tests read is its tag in handle-action and asserts that tag first', () => {
  for (const tag of ['set-ref', 'delete-ref', 'publish-desk', 'set-group-policy']) {
    const text = actionArm(agent, tag)
    assert.match(text, new RegExp(`^ {6}\\+\\+  ${tag}\\n`), tag)
    assert.deepEqual(entryGuard(text), { tag }, tag)
  }
})

test('each route the tests read is reached through every hop from handle-api and asserts its route first', () => {
  const repository = (rest) => `[%apps %urgit %api %repository @ ${rest}]`
  for (const [core, name, method, path] of [
    ['repository-settings-api', 'post-repository-branches', 'POST', repository('%branches ~')],
    ['repository-settings-api', 'delete-repository-branches', 'DELETE', repository('%branches ~')],
    ['repository-settings-api', 'post-repository-tags', 'POST', repository('%tags ~')],
    ['repository-settings-api', 'delete-repository-tags', 'DELETE', repository('%tags ~')],
    ['repository-settings-api', 'post-repository-publish', 'POST', repository('%publish ~')],
    ['repository-settings-api', 'post-repository-group-policy', 'POST', repository('%group-policy ~')],
    ['repository-file-api', 'post-repository-file', 'POST', repository('%file *')],
    ['repository-file-api', 'delete-repository-file', 'DELETE', repository('%file *')],
    ['repository-pulls-api', 'post-repository-pulls-merge', 'POST', repository('%pulls @ %merge ~')],
    ['peer-api', 'post-peer-discover', 'POST', '[%apps %urgit %api %peer %discover ~]'],
    ['peer-api', 'post-peer-discover-group', 'POST', '[%apps %urgit %api %peer %discover-group ~]'],
  ]) {
    const text = routeArm(agent, core, name, method, path)
    assert.match(text, new RegExp(`^ {8}\\+\\+  ${name}\\n`), name)
    assert.deepEqual(entryGuard(text), { method, path }, name)
  }
})

test('each wire the tests read is sent to its handler by on-arvo, which asserts that wire first', () => {
  for (const [wire, name] of [
    ['[%peer %fine @ @ ~]', 'peer-fine'], ['[%peer %rate @ @ ~]', 'peer-rate'],
    ['[%peer %prepare-timeout @ ~]', 'peer-prepare-timeout'], ['[%peer %archive-timeout @ ~]', 'peer-archive-timeout'],
    ['[%peer %serve-timeout @ ~]', 'peer-serve-timeout'], ['[%peer %discovery-timeout @ ~]', 'peer-discovery-timeout'],
    ['[%clay-publish ~]', 'clay-publish'], ['[%clay-report ~]', 'clay-report'], ['[%github @ ~]', 'github-response'],
  ]) {
    const text = wireArm(agent, wire, name)
    assert.match(text, new RegExp(`^ {4}\\+\\+  ${name}\\n`), name)
    assert.deepEqual(entryGuard(text), { wire }, name)
  }
})
