import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { api } from './api.js'
import { describeGroup, describeHost, describeRole, filterGroups, findGroup, groupMatches, groupNeedle, normalizeGroups, policyFlag, roleOptions } from './groupPolicy.js'
import { actionArm, arm, deskText, gaps, importClosure, routeArm } from './hoonSource.js'

const repositoryView = readFileSync(
  new URL('./components/RepositoryView.jsx', import.meta.url),
  'utf8',
)
const backend = readFileSync(
  new URL('../../desk/app/urgit.hoon', import.meta.url),
  'utf8',
)
const access = readFileSync(
  new URL('../../desk/lib/git-access.hoon', import.meta.url),
  'utf8',
)
const readme = readFileSync(new URL('../../README.md', import.meta.url), 'utf8')
const settings = repositoryView.slice(
  repositoryView.indexOf('function Settings'),
  repositoryView.indexOf('export default function RepositoryView'),
)
const groupAccess = settings.slice(
  settings.indexOf('<h3>Group access</h3>'),
  // the section ends where the Runners section begins (the branch policy
  // lists that follow are their own component, with a filter <input>)
  settings.indexOf('<RunnersSection />'),
)
assert.ok(settings.indexOf('<RunnersSection />') > settings.indexOf('<h3>Group access</h3>'), 'Group access precedes Runners')
// the %groups readers live in the helper core the agent door is composed with
// (=>, ahead of the door) since P2's ci-can-write peek (fence touch 5); the
// one-line wrappers on-poke's core keeps for its callers are not the bodies
const groupPeek = arm(backend, 'group-peek')
const groupSeat = arm(backend, 'group-seat')
const groupMembers = arm(backend, 'on-poke/group-members')
// the repository JSON is lib/git-json's, which the agent imports
const repositoryJson = arm(deskText('lib/git-json.hoon'), 'repository-json-up-to')
const publicJson = arm(deskText('lib/git-json.hoon'), 'public-repository-json-up-to')
const setGroupPolicy = actionArm(backend, 'set-group-policy')
const parseGroupPolicy = arm(backend, 'on-poke/parse-group-policy')
const endpoint = routeArm(backend, 'repository-settings-api', 'post-repository-group-policy', 'POST', '[%apps %urgit %api %repository @ %group-policy ~]')
// the agent and every library it imports (skeleton is base-dev's, staged at
// install): what "the agent reads %groups only here" and "nothing caches a
// seat" range over
const allSource = [backend, ...importClosure('app/urgit.hoon', ['lib/skeleton.hoon']).map(([, text]) => text)].join('\n')

async function capture(call, answer = { ok: true, status: 200, text: async () => '{}' }) {
  const originalFetch = globalThis.fetch
  let request
  globalThis.fetch = async (url, options) => {
    request = { url, options }
    if (answer instanceof Error) throw answer
    return answer
  }
  let outcome
  try {
    outcome = await call().then((result) => ({ result }), (error) => ({ error }))
  } finally {
    globalThis.fetch = originalFetch
  }
  return { ...request, ...outcome }
}

// the Groups light scry as ~syt answers it, keys flagged with the host, roles under `cabals`
const lightScry = {
  '~syt/v188gelp': { meta: { title: 'Test' }, cabals: { legendary: { meta: { title: 'Legendary' } }, plebe: { meta: { title: 'Plebe' } }, admin: { meta: { title: 'Admin' } } }, fleet: {} },
  '~syt/vgrp': { meta: { title: 'Verify' }, cabals: { rwrite: { meta: { title: 'W' } }, rread: { meta: { title: 'R' } }, admin: { meta: { title: 'Admin' } }, rnone: { meta: { title: 'N' } } }, fleet: {} },
  '~dur/elsewhere': { meta: { title: 'Elsewhere' }, cabals: { admin: { meta: { title: 'Admin' } } }, fleet: {} },
}

test('setGroupPolicy posts the policy to the encoded repository route', async () => {
  const policy = { group: 'crew', base: 'none', roles: { verified: 'write', legacy: 'read' } }
  const request = await capture(() => api.setGroupPolicy('private repo', policy))
  assert.equal(request.url, '/apps/urgit/api/repository/private%20repo/group-policy')
  assert.equal(request.options.method, 'POST')
  assert.deepEqual(JSON.parse(request.options.body), { policy })
})

test('setGroupPolicy clears the policy with an explicit null', async () => {
  const request = await capture(() => api.setGroupPolicy('private repo', null))
  assert.equal(request.url, '/apps/urgit/api/repository/private%20repo/group-policy')
  assert.deepEqual(JSON.parse(request.options.body), { policy: null })
})

test('listGroups reads the Groups light scry with the session cookie and lists joined groups too', async () => {
  const call = await capture(() => api.listGroups('~syt'), { ok: true, status: 200, text: async () => JSON.stringify(lightScry) })
  assert.equal(call.url, '/~/scry/groups/groups/light.json')
  assert.equal(call.options.credentials, 'same-origin')
  assert.equal(call.error, undefined)
  assert.deepEqual(call.result.map((group) => [group.flag, group.hostedHere]), [['~dur/elsewhere', false], ['~syt/v188gelp', true], ['~syt/vgrp', true]])
})

test('listGroups fails loudly instead of answering an empty list', async () => {
  const http = await capture(() => api.listGroups('~syt'), { ok: false, status: 500, text: async () => 'oops' })
  assert.match(http.error?.message, /^Groups unavailable/)
  const network = await capture(() => api.listGroups('~syt'), new Error('Failed to fetch'))
  assert.match(network.error?.message, /^Groups unavailable/)
  const garbage = await capture(() => api.listGroups('~syt'), { ok: true, status: 200, text: async () => '<html>' })
  assert.match(garbage.error?.message, /^Groups unavailable/)
})

test('normalizeGroups reads titles, slugs, and roles from either `cabals` or `roles`', () => {
  const groups = normalizeGroups(lightScry)
  assert.deepEqual(groups.map((group) => [group.flag, group.host, group.slug, group.title]), [
    ['~dur/elsewhere', '~dur', 'elsewhere', 'Elsewhere'],
    ['~syt/v188gelp', '~syt', 'v188gelp', 'Test'],
    ['~syt/vgrp', '~syt', 'vgrp', 'Verify'],
  ])
  assert.deepEqual(findGroup(groups, '~syt/vgrp').roles, [
    { id: 'admin', title: 'Admin' },
    { id: 'rnone', title: 'N' },
    { id: 'rread', title: 'R' },
    { id: 'rwrite', title: 'W' },
  ])
  const newer = normalizeGroups({ '~syt/vgrp': { meta: { title: 'Verify' }, roles: { rread: { meta: { title: 'R' } }, bare: {} } } })
  assert.deepEqual(newer[0].roles, [{ id: 'bare', title: 'bare' }, { id: 'rread', title: 'R' }])
  // a group with no title still shows its slug, and junk keys are dropped
  assert.deepEqual(normalizeGroups({ '~syt/untitled': {}, '~syt': {}, '': null }).map((group) => group.title), ['untitled'])
  assert.deepEqual(normalizeGroups(null), [])
})

test('normalizeGroups keeps every group and marks the ones hosted by this ship', () => {
  assert.deepEqual(normalizeGroups(lightScry, '~syt').map((group) => [group.slug, describeHost(group)]), [['elsewhere', 'hosted by ~dur'], ['v188gelp', 'hosted here'], ['vgrp', 'hosted here']])
  assert.deepEqual(normalizeGroups(lightScry, '~dur').map((group) => [group.slug, describeHost(group)]), [['elsewhere', 'hosted here'], ['v188gelp', 'hosted by ~syt'], ['vgrp', 'hosted by ~syt']])
  assert.deepEqual(normalizeGroups(lightScry, '~zod').map((group) => group.hostedHere), [false, false, false])
  // two hosts may use one slug, so groups are told apart by flag
  const twins = normalizeGroups({ '~syt/verify': { meta: { title: 'Verify' } }, '~dur/verify': { meta: { title: 'Verify' } } }, '~syt')
  assert.deepEqual(twins.map((group) => group.flag), ['~dur/verify', '~syt/verify'])
  assert.equal(findGroup(twins, '~dur/verify').hostedHere, false)
  assert.equal(findGroup(twins, '~syt/verify').hostedHere, true)
  assert.equal(findGroup(twins, 'verify'), undefined)
})

test('the Groups filter matches title or host, ignores case and surrounding space, and never widens the list', () => {
  const groups = normalizeGroups(lightScry, '~syt')
  const flags = (list) => list.map((group) => group.flag)
  // by title
  assert.deepEqual(flags(filterGroups(groups, 'veri')), ['~syt/vgrp'])
  assert.deepEqual(flags(filterGroups(groups, 'Test')), ['~syt/v188gelp'])
  // by host, with or without the sig; the host of a group hosted here is this ship's own name
  assert.deepEqual(flags(filterGroups(groups, '~dur')), ['~dur/elsewhere'])
  assert.deepEqual(flags(filterGroups(groups, 'dur')), ['~dur/elsewhere'])
  assert.deepEqual(flags(filterGroups(groups, '~syt')), ['~syt/v188gelp', '~syt/vgrp'])
  assert.deepEqual(flags(filterGroups(groups, 'syt')), ['~syt/v188gelp', '~syt/vgrp'])
  // the description is not what is matched: 'hosted here' finds nothing by itself
  assert.deepEqual(flags(filterGroups(groups, 'hosted here')), [])
  assert.deepEqual(flags(filterGroups(groups, 'hosted')), [])
  // case-insensitive both ways
  assert.deepEqual(flags(filterGroups(groups, 'ELSEWHERE')), ['~dur/elsewhere'])
  assert.deepEqual(flags(filterGroups(groups, '~DUR')), ['~dur/elsewhere'])
  assert.deepEqual(flags(filterGroups(normalizeGroups({ '~syt/loud': { meta: { title: 'LOUD Title' } } }), 'loud t')), ['~syt/loud'])
  // surrounding whitespace is trimmed; inner whitespace is part of the query
  assert.deepEqual(flags(filterGroups(groups, '  verify  ')), ['~syt/vgrp'])
  assert.deepEqual(flags(filterGroups(groups, '\t~dur\n')), ['~dur/elsewhere'])
  assert.deepEqual(flags(filterGroups(groups, 'veri fy')), [])
  // an empty or blank query is the whole list, the very same array
  assert.equal(filterGroups(groups, ''), groups)
  assert.equal(filterGroups(groups, '   '), groups)
  assert.equal(filterGroups(groups, undefined), groups)
  assert.equal(filterGroups(groups, null), groups)
  // no match is an empty list, never a fallback to everything
  assert.deepEqual(filterGroups(groups, 'nothing-like-this'), [])
  assert.deepEqual(filterGroups(groups, '~zod'), [])
  // a list that has not arrived filters to nothing without throwing
  assert.deepEqual(filterGroups(null, 'x'), [])
  assert.deepEqual(filterGroups(undefined, ''), [])
  // the slug is not matched: two hosts' twin groups are told apart by host, not by slug text
  const twins = normalizeGroups({ '~syt/verify': { meta: { title: 'Alpha' } }, '~dur/verify': { meta: { title: 'Beta' } } }, '~syt')
  assert.deepEqual(flags(filterGroups(twins, 'verify')), [])
  assert.deepEqual(flags(filterGroups(twins, 'dur')), ['~dur/verify'])
  // the pieces the sidebar composes
  assert.equal(groupNeedle('  MiXed '), 'mixed')
  assert.equal(groupNeedle(''), '')
  assert.equal(groupNeedle(null), '')
  assert.equal(groupMatches(findGroup(groups, '~dur/elsewhere'), 'dur'), true)
  assert.equal(groupMatches(findGroup(groups, '~dur/elsewhere'), 'syt'), false)
  assert.equal(groupMatches(findGroup(groups, '~dur/elsewhere'), ''), true)
})

test('roleOptions offers each role once, keeping a row\'s own choice', () => {
  const group = findGroup(normalizeGroups(lightScry, '~syt'), '~syt/vgrp')
  const rows = [{ role: 'rwrite', capability: 'write' }, { role: 'rread', capability: 'read' }]
  assert.deepEqual(roleOptions(group, rows).map((role) => role.id), ['admin', 'rnone'])
  assert.deepEqual(roleOptions(group, rows, 'rread').map((role) => role.id), ['admin', 'rnone', 'rread'])
  assert.deepEqual(roleOptions(group, [{ role: 'admin' }, { role: 'rnone' }, { role: 'rread' }, { role: 'rwrite' }]), [])
  assert.deepEqual(roleOptions(undefined, rows), [])
})

test('saved policies name titles and hosts, and flag groups or roles Groups no longer has', () => {
  const groups = normalizeGroups(lightScry, '~syt')
  const policy = { host: '~syt', group: 'v188gelp', base: 'none', roles: { legendary: 'write', gone: 'read' } }
  assert.equal(policyFlag(policy), '~syt/v188gelp')
  assert.equal(policyFlag(null), '')
  assert.equal(describeGroup(groups, policy), 'Test (~syt/v188gelp, hosted here)')
  assert.equal(describeGroup(groups, { ...policy, host: '~dur', group: 'elsewhere' }), 'Elsewhere (~dur/elsewhere, hosted by ~dur)')
  assert.equal(describeGroup(groups, { ...policy, group: 'deleted' }), 'missing group `~syt/deleted`')
  // a joined group that has since gone from the mirror is missing too, host and all
  assert.equal(describeGroup(groups, { ...policy, host: '~dur', group: 'v188gelp' }), 'missing group `~dur/v188gelp`')
  // before the scry answers (or when it failed) nothing can be called missing
  assert.equal(describeGroup(null, policy), '~syt/v188gelp')
  assert.equal(describeGroup(groups, null), '')
  const group = findGroup(groups, '~syt/v188gelp')
  assert.equal(describeRole(group, 'legendary'), 'Legendary (legendary)')
  assert.equal(describeRole(group, 'gone'), 'missing role `gone`')
  assert.equal(describeRole(undefined, 'gone'), 'gone')
})

test('settings pick the group, hosted here or joined, and its roles from dropdowns', () => {
  assert.ok(groupAccess.length > 0)
  // nothing about a group is typed: host, slug and role ids all come from Groups
  assert.doesNotMatch(groupAccess, /<input/)
  assert.doesNotMatch(groupAccess, /setGroupHost|groupHost/)
  assert.match(settings, /api\.listGroups\(repo\.owner\)/)
  assert.match(groupAccess, /<select value=\{groupFlag\} disabled=\{!groupsReady\} onChange=\{\(e\) => chooseGroup\(e\.target\.value\)\}/)
  assert.match(groupAccess, /<option key=\{group\.flag\} value=\{group\.flag\}>\{group\.title\} \(\{group\.flag\}, \{describeHost\(group\)\}\)<\/option>/)
  assert.match(groupAccess, /Choose a group this ship is in/)
  assert.match(groupAccess, /This ship is in no groups/)
  assert.match(groupAccess, /<select value=\{groupBase\}/)
  assert.match(groupAccess, /<select value=\{row\.role\} disabled=\{!groupsReady\}/)
  assert.match(groupAccess, /<option key=\{role\.id\} value=\{role\.id\}>\{role\.title\} \(\{role\.id\}\)<\/option>/)
  assert.match(groupAccess, /roleOptions\(selectedGroup, groupRoles, row\.role\)/)
  assert.match(groupAccess, /updateGroupRole\(index, \{ capability: e\.target\.value \}\)/)
  assert.match(groupAccess, /\{ role: nextRole\.id, capability: 'read' \}/)
  assert.match(groupAccess, /rows\.filter\(\(_, at\) => at !== index\)/)
  // saved policy and stale entries are described by title, flagged when missing
  assert.match(groupAccess, /describeGroup\(groups, repo\.groupPolicy\)/)
  assert.match(groupAccess, /describeRole\(savedGroup, row\.role\)/)
  assert.match(groupAccess, /describeRole\(selectedGroup, row\.role\)/)
  assert.match(groupAccess, /missing group \\`\$\{groupFlag\}\\`/)
  // a failed scry says so and disables the pickers rather than offering an empty list
  assert.match(groupAccess, /Groups unavailable/)
  assert.match(settings, /const groupsReady = Boolean\(groups\) && !groupsError/)
  assert.match(groupAccess, /api\.setGroupPolicy\(repo\.name, null\)/)
  assert.match(settings, /api\.setGroupPolicy\(repo\.name, \{ host: selectedGroup\.host, group: selectedGroup\.slug, base: groupBase, roles \}\)/)
  assert.match(groupAccess, /disabled=\{busy \|\| !canSaveGroupPolicy\}/)
  assert.match(repositoryView, /const groupCapabilities = \['none', 'read', 'write'\]/)
})

test('the agent reads the seat from %groups per event, fails closed, and never caches it', () => {
  // every %groups read goes through one guarded arm
  assert.match(groupPeek, /\.\^\(\? %gu \(weld prefix \/\$\)\)/)
  assert.match(groupPeek, /\.\^\(\? %gu \(weld prefix flag\)\)/)
  assert.match(groupPeek, /\.\^\(\* %gx \(weld prefix \(weld under \(weld flag rest\)\)\)\)/)
  assert.match(groupPeek, /\?\.  \?=\(%& -\.raw\)  ~/)
  assert.equal(allSource.match(/\/groups\/\(scot %da now\.bowl\)/g).length, 1)
  assert.equal(allSource.match(/\/groups\/\(scot/g).length, groupPeek.match(/\/groups\/\(scot/g).length)
  // the seat route stays the one unversioned route, soft-cast under mule
  assert.match(groupSeat, /\(group-peek group \/ \/seats\/\(scot %p who\)\/noun\)/)
  assert.match(groupSeat, /;;\(\(unit group-seat:git\) u\.raw\)/)
  // a joined group is the host's mirror: believed only while initialised and this ship is seated
  assert.match(groupSeat, /=\/  net=\?\(%pub %sub\)  \?:\(=\(our\.bowl host\.group\) %pub %sub\)/)
  assert.match(groupSeat, /\(group-peek group \/v2\/ui \/noun\)/)
  assert.match(groupSeat, /;;\(\[\* init=\? member-count=@ud\] u\.raw\)/)
  assert.match(groupSeat, /\?\.  \?=\(%& -\.ui\)  %\.n/)
  // |( is ?|'s irregular form: the same rune the wide ?|( wrote
  assert.match(groupSeat, /=\/  seated=\?  \|\(\?=\(%pub net\) !=\(~ \(seat-of our\.bowl\)\)\)/)
  assert.match(groupSeat, /\?\.  \(mirror-trusted:git-access net init seated\)  ~/)
  assert.doesNotMatch(groupSeat, /host\.group\)  ~/)
  assert.doesNotMatch(allSource, /group-seat-cache|seat-cache/)
  // no age limit, no timestamp comparison: the initialised bit is the whole liveness test
  assert.doesNotMatch(groupSeat + groupPeek + groupMembers, /max-age|mirror-age|joined\.|\(sub now|\(lth now|\(gth now/)
  // the member list for discovery is believed on the same terms, and read by
  // the mark %groups serves /seats/ships as: %ships, never %noun
  assert.match(groupMembers, /\?~  \(group-seat `\[group %none ~\] our\.bowl\)  ~/)
  assert.match(groupMembers, /\(group-peek group \/ \/seats\/ships\/ships\)/)
  assert.doesNotMatch(allSource, /\/seats\/ships\/noun/)
  assert.match(groupMembers, /;;\(\(set ship\) u\.raw\)/)
  assert.match(backend, /\(repository-writable u\.found src\.bowl\)/)
  assert.match(backend, /\(repository-writable repo src\.bowl\)/)
})

test('group policy is owner-administered, membership-checked at save, and hidden from public and peer JSON', () => {
  assert.match(setGroupPolicy, /!=\(~ \(group-seat policy\.act our\.bowl\)\)/)
  assert.doesNotMatch(setGroupPolicy, /=\(our\.bowl host\.group\.u\.policy\.act\)/)
  assert.match(parseGroupPolicy, /\[%\| 'host must be a valid ship name'\]/)
  assert.match(gaps(parseGroupPolicy), /\?~  \(group-seat `\[\[u\.host u\.group\] %none ~\] our\.bowl\)  \[%\| 'this ship is not a member of that group'\]/)
  assert.doesNotMatch(parseGroupPolicy, /group host must be this ship/)
  assert.match(endpoint, /'policy is required; null clears it'/)
  assert.match(endpoint, /\[%set-group-policy name ~\]/)
  assert.match(endpoint, /\[%set-group-policy name `p\.parsed\]/)
  assert.match(repositoryJson, /\['groupPolicy' \(group-policy-json group-policy\.repo\)\]/)
  assert.match(publicJson, /\(~\(del by fields\) 'groupPolicy'\)/)
})

test('access library stays pure and lets write imply read', () => {
  assert.doesNotMatch(access, /\.\^/)
  assert.match(access, /\+\+  group-capability/)
  assert.match(access, /\+\+  mirror-trusted\n  \|=  \[net=\?\(%pub %sub\) init=\? seated=\?\]/)
  assert.match(access, /\?:  \?=\(%pub net\)  %\.y\n  &\(init seated\)/)
  assert.match(access, /\+\+  can-write/)
  assert.match(access, /!=\(%none group\)/)
  assert.match(access, /=\(%write group\)/)
})

test('readme explains group access in the access model', () => {
  assert.match(readme, /Group member/)
  assert.match(readme, /roles?/)
  assert.match(readme, /hosted by the ship itself or by another ship/)
  assert.match(readme, /reports that copy initialised and this ship still holds a seat/)
})
