import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { api } from './api.js'
import { countParts, describeCounts, describeGrant, describeHold, describeReach, describeVia, discoveryStatus, groupOptionLabel, mergeDiscoveries } from './groupDiscovery.js'
import { describeHost, normalizeGroups } from './groupPolicy.js'
import { arm, gaps, importClosure, routeArm, wireArm } from './hoonSource.js'

const sidebar = readFileSync(new URL('./components/Sidebar.jsx', import.meta.url), 'utf8')
const app = readFileSync(new URL('./App.jsx', import.meta.url), 'utf8')
const css = readFileSync(new URL('./style.css', import.meta.url), 'utf8')
const backend = readFileSync(new URL('../../desk/app/urgit.hoon', import.meta.url), 'utf8')
const wire = readFileSync(new URL('../../desk/sur/git-peer.hoon', import.meta.url), 'utf8')
const catalogLib = readFileSync(new URL('../../desk/lib/git-catalog.hoon', import.meta.url), 'utf8')
const stateSur = readFileSync(new URL('../../desk/sur/git.hoon', import.meta.url), 'utf8')
const catalogVector = readFileSync(new URL('../../desk/gen/git-catalog-vector.hoon', import.meta.url), 'utf8')
const mark = readFileSync(new URL('../../desk/mar/git-peer.hoon', import.meta.url), 'utf8')
const catalogRequest = arm(backend, 'on-poke/peer-catalog-request')
const discoverGroup = routeArm(backend, 'peer-api', 'post-peer-discover-group', 'POST', '[%apps %urgit %api %peer %discover-group ~]')
const discoverOne = routeArm(backend, 'peer-api', 'post-peer-discover', 'POST', '[%apps %urgit %api %peer %discover ~]')
const onAgent = arm(backend, 'on-agent')
const discoveryTimeout = wireArm(backend, '[%peer %discovery-timeout @ ~]', 'peer-discovery-timeout')
const discoveriesJson = arm(backend, 'on-poke/peer-discoveries-json')
// the agent and every library it imports (skeleton is base-dev's, staged at install)
const allSource = [backend, ...importClosure('app/urgit.hoon', ['lib/skeleton.hoon']).map(([, text]) => text)].join('\n')
// %urgit's own state and the files it versions: every file of its closure
// but sur/ci.hoon, which is %urgit-ci's state (versioned on its own under
// CI-STATE-MIGRATION-1, state-5 since Delivery 1C) and is imported here
// only for the CI action and candidate types
const gitStateSource = [backend, ...importClosure('app/urgit.hoon', ['lib/skeleton.hoon']).filter(([rel]) => rel !== 'sur/ci.hoon').map(([, text]) => text)].join('\n')
const ciStateSur = readFileSync(new URL('../../desk/sur/ci.hoon', import.meta.url), 'utf8')
// the three sections of the sidebar, in the order they render
const sections = ['repositories', 'peers', 'groups'].map((name) => sidebar.indexOf(`toggleSection('${name}')`))
const peersSection = sidebar.slice(sections[1], sections[2])
const groupsSection = sidebar.slice(sections[2], sidebar.indexOf('</aside>'))

const groups = normalizeGroups({
  '~sun/verify': { meta: { title: 'Verify' }, cabals: { rread: { meta: { title: 'Read' } } } },
  '~wyl/team': { meta: { title: 'Team' }, roles: { admin: { meta: { title: 'Admin' } } } },
}, '~rys')

test('the sidebar is three sibling sections, and Peers is back to a chevron, a label, and an add button', () => {
  assert.ok(sections[0] > 0 && sections[0] < sections[1] && sections[1] < sections[2])
  assert.deepEqual([...sidebar.matchAll(/<span className="sidebar-section-chevron">[^<]*<\/span><span>(\w+)<\/span>/g)].map((found) => found[1]), ['Repositories', 'Peers', 'Groups'])
  assert.match(sidebar, /useState\(\{ repositories: true, peers: true, groups: true \}\)/)
  assert.match(sidebar, /<div className="sidebar-heading peer-heading"><button className="sidebar-section-toggle" onClick=\{\(\) => toggleSection\('peers'\)\} aria-expanded=\{sectionsOpen\.peers\}><span className="sidebar-section-chevron">[^<]*<\/span><span>Peers<\/span><\/button><button className="icon-button" onClick=\{[^\n]*\} title="Add peer"><PlusIcon \/><\/button><\/div>/)
  // no control wedged onto the Peers heading and nothing about groups in its body
  assert.doesNotMatch(sidebar, /<select|peer-groups|group-catalog|groupOptionLabel|findGroup/)
  assert.doesNotMatch(peersSection, /group|Group|via-badge|describeGrant/)
  assert.doesNotMatch(css, /peer-groups|group-catalog/)
  // Groups has the same chrome and no add button: membership is managed in Tlon
  assert.match(sidebar, /<div className="sidebar-heading peer-heading"><button className="sidebar-section-toggle" onClick=\{\(\) => toggleSection\('groups'\)\} aria-expanded=\{sectionsOpen\.groups\}><span className="sidebar-section-chevron">[^<]*<\/span><span>Groups<\/span><\/button><\/div>/)
  assert.match(groupsSection, /\{sectionsOpen\.groups && <><input className="repo-search group-filter"[^\n]*\/>\n\s*<nav className="peer-tree">/)
  assert.doesNotMatch(groupsSection, /icon-button|PlusIcon/)
  // the ship comes from the agent, not from a docket global the app is not served with
  assert.match(sidebar, /api\.listGroups\(ourShip\)/)
  assert.match(backend, /\['ship' s\+\(scot %p our\.bowl\)\] \['peers' \[%a entries\]\]/)
  assert.match(app, /setOurShip\(data\.ship \|\| ''\)/)
  assert.match(app, /<Sidebar repositories=\{repositories\} peers=\{peers\} ourShip=\{ourShip\}/)
})

test('the Groups body lists one row per membership, title over host on two lines, and says so when there are none', () => {
  assert.match(groupsSection, /visibleGroups\.map\(\(group\) => <div className="peer-node" key=\{group\.flag\}>/)
  assert.doesNotMatch(groupsSection, /\(groups \|\| \[\]\)\.map/)
  // the chevron, then one label column holding the title line and the host line, each truncating on its own
  assert.match(groupsSection, /<div className="peer-link-row"><button className="repo-link peer-link group-link" onClick=\{\(\) => toggleGroup\(group\.flag\)\} title=\{group\.flag\}><span className="peer-chevron">\{groupsOpen\[group\.flag\] \? '⌄' : '›'\}<\/span><span className="group-label"><span className="group-title truncate">\{group\.title\}<\/span><span className="host-tag truncate">\{describeHost\(group\)\}<\/span><\/span><\/button>/)
  // peer rows keep their one-line shape
  assert.match(peersSection, /<button className="repo-link peer-link" onClick=\{\(\) => togglePeer\(ship\)\}><span className="peer-chevron">\{expanded\[ship\] \? '⌄' : '›'\}<\/span><code>\{ship\}<\/code><\/button>/)
  assert.doesNotMatch(peersSection, /group-label|group-link|group-title/)
  assert.deepEqual(groups.map((group) => [group.title, group.flag, describeHost(group)]), [['Team', '~wyl/team', 'hosted by ~wyl'], ['Verify', '~sun/verify', 'hosted by ~sun']])
  assert.deepEqual(normalizeGroups({ '~sun/verify': { meta: { title: 'Verify' }, cabals: {} } }, '~sun').map(describeHost), ['hosted here'])
  assert.deepEqual(groups.map(groupOptionLabel), ['Team (~wyl/team)', 'Verify (~sun/verify)'])
  // the three states of the section itself
  assert.match(groupsSection, /\{groups === null && !groupsError && <small className="quiet peer-empty">Loading groups…<\/small>\}/)
  assert.match(groupsSection, /\{groupsError && <small className="field-error sidebar-peer-error">\{groupsError\}<\/small>\}/)
  assert.match(groupsSection, /\{groups && !groups\.length && !groupsError && <small className="quiet peer-empty">Join a group in Tlon to see repositories shared with it\.<\/small>\}/)
  assert.match(sidebar, /\.catch\(\(cause\) => \{ if \(!stale\) \{ setGroups\(\[\]\); setGroupsError\(cause\.message\) \} \}\)/)
})

test('the Groups filter sits under the heading, outside the scrolling list, and narrows the rows by title or host', () => {
  // its own state, its own memo, and the shared helper; the repository search keeps its own query
  assert.match(sidebar, /const \[groupQuery, setGroupQuery\] = useState\(''\)/)
  assert.match(sidebar, /const visibleGroups = useMemo\(\(\) => filterGroups\(groups, groupQuery\), \[groups, groupQuery\]\)/)
  assert.match(sidebar, /import \{ describeHost, filterGroups \} from '\.\.\/groupPolicy'/)
  assert.match(sidebar, /repositories\.filter\(\(repo\) => repo\.name\.toLowerCase\(\)\.includes\(needle\)\)/)
  assert.doesNotMatch(sidebar, /filterGroups\(groups, query\)|repositories\.filter\([^\n]*groupQuery/)
  // always there while the section is open, whatever Groups answered, and before the <nav> that scrolls
  assert.match(groupsSection, /<input className="repo-search group-filter" value=\{groupQuery\} onChange=\{\(event\) => setGroupQuery\(event\.target\.value\)\} placeholder="Filter by group or host…" aria-label="Filter groups by group or host" \/>/)
  assert.ok(groupsSection.indexOf('group-filter') < groupsSection.indexOf('<nav className="peer-tree">'))
  assert.doesNotMatch(groupsSection, /groups\.length > \d+ && <input/)
  // typing never asks the group again and never touches what is open or cached
  assert.doesNotMatch(sidebar, /groupQuery[^\n]*discoverGroup|discoverGroup[^\n]*groupQuery/)
  assert.doesNotMatch(sidebar, /setGroupQuery[^\n]*setGroupsOpen|setGroupQuery[^\n]*setGroupCatalogs/)
  assert.doesNotMatch(sidebar, /useEffect\([^\n]*groupQuery/)
  // an unmatched query says so, and only when a loaded list had groups to hide; the other three states stand as they are
  assert.match(groupsSection, /\{groups && groups\.length > 0 && !visibleGroups\.length && <small className="quiet peer-empty">No matching groups\.<\/small>\}/)
  assert.match(groupsSection, /\{groups === null && !groupsError && <small className="quiet peer-empty">Loading groups…<\/small>\}/)
  assert.match(groupsSection, /\{groupsError && <small className="field-error sidebar-peer-error">\{groupsError\}<\/small>\}/)
  assert.match(groupsSection, /\{groups && !groups\.length && !groupsError && <small className="quiet peer-empty">Join a group in Tlon to see repositories shared with it\.<\/small>\}/)
  assert.equal(groupsSection.match(/No matching groups/g).length, 1)
  assert.equal(sidebar.match(/No matching repositories/g).length, 1)
})

test('opening a group fans one catalog request out per member, keyed by flag so several groups can be open at once', () => {
  assert.match(sidebar, /function toggleGroup\(flag\) \{\n    if \(groupsOpen\[flag\]\) \{ setGroupsOpen\(\(value\) => \(\{ \.\.\.value, \[flag\]: false \}\)\); return \}\n    setGroupsOpen\(\(value\) => \(\{ \.\.\.value, \[flag\]: true \}\)\)\n    discoverGroup\(flag\)\n  \}/)
  assert.match(sidebar, /const started = await api\.peerDiscoverGroup\(flag\)/)
  assert.match(sidebar, /const status = await api\.peerDiscoveries\(\)/)
  assert.match(sidebar, /merged = mergeDiscoveries\(status\.discoveries, requests\)/)
  assert.match(sidebar, /requests\.map\(\(request\) => api\.peerDeleteDiscovery\(request\)/)
  // one catalog and one generation per flag, like catalogs per peer
  assert.match(sidebar, /const generation = \(generations\.current\[flag\] \|\| 0\) \+ 1\n    generations\.current\[flag\] = generation\n    const current = \(\) => generations\.current\[flag\] === generation/)
  assert.match(sidebar, /const show = \(catalog\) => setGroupCatalogs\(\(value\) => \(\{ \.\.\.value, \[flag\]: catalog \}\)\)/)
  assert.doesNotMatch(sidebar, /setDiscovery|discoveryRef|idleDiscovery/)
  // the refresh on the row asks the same group again, and opens it if it was closed
  assert.match(groupsSection, /<button className="peer-remove group-refresh" onClick=\{\(event\) => refreshGroup\(group\.flag, event\)\} disabled=\{groupCatalogs\[group\.flag\]\?\.loading\} title="Ask the group again">↻<\/button>/)
  assert.match(sidebar, /function refreshGroup\(flag, event\) \{\n    event\.stopPropagation\(\)\n    setGroupsOpen\(\(value\) => \(\{ \.\.\.value, \[flag\]: true \}\)\)\n    discoverGroup\(flag\)\n  \}/)
  assert.equal(typeof api.peerDiscoverGroup, 'function')
  assert.match(readFileSync(new URL('./api.js', import.meta.url), 'utf8'), /peerDiscoverGroup: \(group\) => request\('\/peer\/discover-group', \{ method: 'POST', body: JSON\.stringify\(\{ group \}\) \}\)/)
  const discoveries = [
    { request: '0v1', ship: '~wyl', active: false, ok: true, message: 'complete', status: 'answered', group: '~sun/verify', repositories: [
      { name: 'secret', writable: false, via: '~sun/verify' },
      { name: 'tools', writable: true, via: null },
    ] },
    { request: '0v2', ship: '~bud', active: true, ok: false, message: 'contacting peer', status: 'waiting', group: '~sun/verify', repositories: [] },
    { request: '0v3', ship: '~dur', active: false, ok: false, message: 'peer discovery timed out', status: 'unreachable', group: '~sun/verify', repositories: [] },
    { request: '0v9', ship: '~wyl', active: false, ok: true, message: 'complete', status: 'answered', group: null, repositories: [{ name: 'other', writable: false, via: null }] },
  ]
  const merged = mergeDiscoveries(discoveries, ['0v1', '0v2', '0v3'])
  assert.deepEqual(merged.entries, [
    { key: '~wyl/secret', ship: '~wyl', name: 'secret', writable: false, via: '~sun/verify' },
    { key: '~wyl/tools', ship: '~wyl', name: 'tools', writable: true, via: null },
  ])
  assert.equal(merged.pending, 1)
  assert.equal(merged.settled, 2)
  assert.deepEqual(merged.counts, { answered: 1, noUrgit: 0, unreachable: 1, pending: 0, waiting: 1 })
  // the same repository answered twice under one fan-out stays one entry
  const twice = mergeDiscoveries([discoveries[0], { ...discoveries[0], request: '0v4' }], ['0v1', '0v4'])
  assert.equal(twice.entries.length, 2)
  assert.deepEqual(mergeDiscoveries([], ['0v1']), { entries: [], counts: { answered: 0, noUrgit: 0, unreachable: 0, pending: 0, waiting: 0 }, heldSince: null, pending: 0, settled: 0 })
})

test('the footer under an open group counts every member by how it stands and drops the zeros', () => {
  const mixed = [
    { request: '0v1', ship: '~wyl', active: false, ok: true, status: 'answered', repositories: [{ name: 'tools', writable: false, via: null }] },
    { request: '0v2', ship: '~bud', active: false, ok: true, status: 'answered', repositories: [] },
    { request: '0v3', ship: '~dur', active: false, ok: false, status: 'no-urgit', message: 'peer does not run urgit', repositories: [] },
    { request: '0v4', ship: '~mex', active: false, ok: false, status: 'unreachable', message: 'peer discovery timed out', repositories: [] },
    { request: '0v5', ship: '~lun', active: false, ok: false, status: 'pending', message: 'an earlier request to this ship is still in flight', heldSince: '2026-09-02T19:04:30Z', repositories: [] },
    { request: '0v6', ship: '~nus', active: true, ok: false, status: 'waiting', message: 'contacting peer', repositories: [] },
    { request: '0v7', ship: '~sen', active: false, ok: false, status: 'answered', message: 'no such repository', repositories: [] },
  ]
  const merged = mergeDiscoveries(mixed, mixed.map((item) => item.request))
  assert.deepEqual(merged.counts, { answered: 3, noUrgit: 1, unreachable: 1, pending: 1, waiting: 1 })
  assert.equal(merged.pending, 1)
  assert.equal(merged.settled, 6)
  // only an answered member contributes repositories; a pending one is settled at once and is not an error
  assert.deepEqual(merged.entries.map((entry) => entry.key), ['~wyl/tools'])
  assert.equal(describeCounts(merged.counts), '3 answered · 1 without urgit · 1 unreachable · 1 pending')
  assert.equal(describeCounts({ answered: 2, noUrgit: 0, unreachable: 0, pending: 0, waiting: 0 }), '2 answered')
  assert.equal(describeCounts({ answered: 0, noUrgit: 0, unreachable: 0, pending: 1, waiting: 0 }), '1 pending')
  assert.equal(describeCounts({ answered: 0, noUrgit: 0, unreachable: 0, pending: 0, waiting: 3 }), '')
  assert.equal(describeCounts(null), '')
  assert.deepEqual(countParts(merged.counts).map((part) => part.key), ['answered', 'noUrgit', 'unreachable', 'pending'])
  assert.deepEqual(countParts(null), [])
  // the pending count says how long the oldest hold has stood, from the time the agent reports
  assert.equal(merged.heldSince, Date.parse('2026-09-02T19:04:30Z'))
  const older = mergeDiscoveries([
    ...mixed,
    { request: '0v8', ship: '~ryx', active: false, ok: false, status: 'pending', message: 'an earlier request to this ship is still in flight', heldSince: '2026-09-02T18:30:00Z', repositories: [] },
    { request: '0v9', ship: '~tel', active: false, ok: false, status: 'pending', message: 'an earlier request to this ship is still in flight', repositories: [] },
  ], ['0v1', '0v2', '0v3', '0v4', '0v5', '0v6', '0v7', '0v8', '0v9'])
  assert.equal(older.heldSince, Date.parse('2026-09-02T18:30:00Z'))
  assert.equal(older.counts.pending, 3)
  assert.equal(describeHold(Date.parse('2026-09-02T19:04:30Z'), Date.parse('2026-09-02T19:16:45Z')), 'held 12 min')
  assert.equal(describeHold(Date.parse('2026-09-02T19:04:30Z'), Date.parse('2026-09-02T19:04:59Z')), 'held less than a minute')
  assert.equal(describeHold(Date.parse('2026-09-02T19:04:30Z'), Date.parse('2026-09-02T20:04:30Z')), 'held 1 h')
  assert.equal(describeHold(Date.parse('2026-09-02T19:04:30Z'), Date.parse('2026-09-02T20:09:30Z')), 'held 1 h 5 min')
  assert.equal(describeHold(Date.parse('2026-09-02T19:04:30Z'), Date.parse('2026-09-02T19:00:00Z')), 'held less than a minute')
  assert.equal(describeHold(null), '')
  assert.equal(describeHold(undefined), '')
  // an agent that predates the word is read from the flags it sends
  assert.equal(discoveryStatus({ active: true, ok: false }), 'waiting')
  assert.equal(discoveryStatus({ active: false, ok: true }), 'answered')
  assert.equal(discoveryStatus({ active: false, ok: false }), 'unreachable')
  assert.equal(discoveryStatus({ active: false, ok: false, status: 'pending' }), 'pending')
  assert.match(groupsSection, /\{groupCatalogs\[group\.flag\] && !groupCatalogs\[group\.flag\]\.loading && !groupCatalogs\[group\.flag\]\.error && countParts\(groupCatalogs\[group\.flag\]\.counts\)\.length > 0 && <small className="group-footer">\{countParts\(groupCatalogs\[group\.flag\]\.counts\)\.map\(\(part, index\) => <Fragment key=\{part\.key\}>\{index > 0 && ' · '\}\{part\.key === 'pending' \? <span title=\{describeHold\(groupCatalogs\[group\.flag\]\.heldSince\)\}>\{part\.text\}<\/span> : part\.text\}<\/Fragment>\)\}/)
  assert.match(sidebar, /^const idleCatalog = \{ loading: false, entries: \[\], counts: null, heldSince: null, /m)
  assert.match(groupsSection, /\{groupCatalogs\[group\.flag\]\?\.loading && <small>Asking… \{groupCatalogs\[group\.flag\]\.settled\} of \{groupCatalogs\[group\.flag\]\.settled \+ groupCatalogs\[group\.flag\]\.pending\}<\/small>\}/)
  assert.doesNotMatch(groupsSection, /did not answer|failures/)
})

test('one catalog request rides to a ship at a time: a ship still unacked is recorded as pending, not asked again', () => {
  // the ledger is transient, beside the discoveries, and no state version carries it
  assert.match(backend, /^=\/  peer-inflight  \*ledger:git-catalog$/m)
  assert.match(gaps(backend), /(?:^|  )peer-discoveries  ~  peer-inflight  ~  peer-browses  ~(?=  |$)/)
  assert.match(catalogLib, /\+\$  ledger  \(map ship \[request=@uv sent=@da\]\)/)
  // state-5 (pull request labels) is the four fields of state-4 with
  // labelled pull requests: no state version carries the ledger, and no
  // later version exists to carry it
  assert.doesNotMatch(stateSur, /inflight|ledger/)
  assert.match(stateSur, /\+\$  state-5\n  \$:  %5\n      repositories=\(map @t repository\)\n      peers=\(set @p\)\n      github-token=\(unit @t\)\n      peer-prepare-queue=\(map @uv peer-prepare-entry\)\n  ==\n/)
  assert.doesNotMatch(gitStateSource, /state-6/)
  assert.doesNotMatch(ciStateSur, /inflight|ledger|discover/, "%urgit-ci's state carries no catalog ledger")
  // both senders decide through the same gate before a poke goes out
  assert.match(discoverGroup, /=\/  decision  \(plan:git-catalog peer-inflight active-for i\.targets now\.bowl\)/)
  assert.match(gaps(discoverGroup), /\?:  \?=\(%hold -\.decision\)  =\.  peer-discoveries  %\+  ~\(put by peer-discoveries\)  request  \(held:git-catalog i\.targets group since\.decision\)  \$\(targets t\.targets, requests \[request requests\]\)/)
  assert.match(discoverGroup, /\(waiting:git-catalog i\.targets group\)/)
  assert.match(discoverGroup, /=\.  peer-inflight  \(sent:git-catalog peer-inflight i\.targets request now\.bowl\)/)
  assert.match(discoverOne, /=\/  decision  \(plan:git-catalog peer-inflight ~ u\.source now\.bowl\)/)
  assert.match(discoverOne, /\(held:git-catalog u\.source ~ since\.decision\)/)
  assert.match(discoverOne, /=\.  peer-inflight  \(sent:git-catalog peer-inflight u\.source request now\.bowl\)/)
  assert.match(catalogLib, /\?~  riding  \[%ask ~\]\n  \?:  \(lapsed sent\.u\.riding now\)  \[%ask ~\]\n  \[%hold sent\.u\.riding\]/)
  assert.match(catalogLib, /'an earlier request to this ship is still in flight' ~ group %pending `since\]/)
  // the hold lapses after an hour, so a kernel that never acks is not waited on forever;
  // the fresh request overwrites the ledger entry, and nothing persisted changes
  assert.match(catalogLib, /^\+\+  hold-expiry  ~h1$/m)
  assert.match(catalogLib, /\+\+  lapsed\n  \|=  \[sent=@da now=@da\]\n  \^-  \?\n  \?:  \(lth now sent\)  %\.n\n  \(gte \(sub now sent\) hold-expiry\)/)
  assert.match(catalogLib, /\+\+  sent\n  \|=  \[=ledger peer=ship request=@uv now=@da\]\n  \^-  \^ledger\n  \(~\(put by ledger\) peer \[request now\]\)/)
  assert.match(catalogVector, /\[%hold sent-at\] \(plan:git-catalog riding ~ member \(add sent-at ~m59\)\)/)
  assert.match(catalogVector, /\[%ask ~\] \(plan:git-catalog riding ~ member \(add sent-at ~m61\)\)/)
  // a pending entry says when the request it waits behind went out
  assert.match(catalogLib, /held-since=\(unit @da\)/)
  assert.match(discoveriesJson, /\['heldSince' \?~\(held-since\.discovery ~ s\+\(iso:git-catalog u\.held-since\.discovery\)\)\]/)
  assert.match(catalogVector, /\('2026-09-03T00:04:30Z' \(iso:git-catalog ~2026\.9\.3\.\.0\.4\.30\)\)/)
  // the ack on the request's own wire settles the ledger; a nack settles the discovery too
  assert.match(gaps(onAgent), /\?:  \?=\(\[%peer %catalog-request @ ~\] wire\)  \?\.  \?=\(%poke-ack -\.sign\)  `this/)
  assert.match(gaps(onAgent), /=\.  peer-inflight  \(settled:git-catalog peer-inflight u\.request\)  \?~  p\.sign  `this/)
  assert.match(onAgent, /\(~\(put by peer-discoveries\) u\.request \(nacked:git-catalog u\.found\)\)/)
  assert.match(catalogLib, /'peer does not run urgit', status %no-urgit\)/)
  // the timer still settles the silent and the unreachable, and leaves the ledger alone
  assert.match(discoveryTimeout, /\(~\(put by peer-discoveries\) u\.request \(timed-out:git-catalog u\.found\)\)/)
  assert.doesNotMatch(discoveryTimeout, /peer-inflight/)
  assert.match(catalogLib, /'peer discovery timed out', status %unreachable\)/)
  assert.doesNotMatch(allSource, /%cork/)
  // the word reaches the UI beside the flags it already sent
  assert.match(discoveriesJson, /\['status' s\+\(status-text:git-catalog status\.discovery\)\]/)
  assert.match(catalogLib, /\+\$  status  \?\(%answered %no-urgit %unreachable %pending %waiting\)/)
  assert.match(catalogVector, /\(plan:git-catalog riding ~ member \(add sent-at ~m5\)\)/)
})

test('an entry under a group is badged only when that group is not what let this ship see it', () => {
  assert.equal(describeGrant('~sun/verify', '~sun/verify', groups), '')
  assert.equal(describeGrant('~wyl/team', '~sun/verify', groups), 'shared with Team')
  assert.equal(describeGrant('~zod/unknown', '~sun/verify', groups), 'shared with ~zod/unknown')
  assert.equal(describeGrant(null, '~sun/verify', groups), 'public or direct')
  assert.equal(describeGrant(null, null, groups), 'public or direct')
  assert.equal(describeVia('~sun/verify', groups), 'shared with Verify')
  assert.equal(describeVia('~zod/unknown', groups), 'shared with ~zod/unknown')
  assert.equal(describeVia(null, groups), '')
  assert.equal(describeVia('~sun/verify', null), 'shared with ~sun/verify')
  assert.match(groupsSection, /<span className="truncate"><code>\{entry\.ship\}<\/code> \/ \{entry\.name\}<\/span>\{describeGrant\(entry\.via, group\.flag, groups\) && <span className="via-badge" title=\{entry\.via \|\| 'readable without this group'\}>\{describeGrant\(entry\.via, group\.flag, groups\)\}<\/span>\}\{entry\.writable && <span className="write-badge">write<\/span>\}<\/button>/)
  assert.match(groupsSection, /className=\{remoteSelected\?\.ship === entry\.ship && remoteSelected\?\.name === entry\.name \? 'repo-link remote-repo-link active' : 'repo-link remote-repo-link'\} onClick=\{\(\) => onSelectRemote\(entry\.ship, entry\.name\)\}/)
  // what an open group says while asking, when nobody shares anything, and when the fan-out fails
  assert.match(groupsSection, /\{groupCatalogs\[group\.flag\]\?\.error && <small className="field-error">\{groupCatalogs\[group\.flag\]\.error\}<\/small>\}/)
  assert.match(groupsSection, /!groupCatalogs\[group\.flag\]\.entries\.length && <small>No repositories shared with this group\.<\/small>\}/)
  assert.match(sidebar, /\[flag\]: \{ \.\.\.idleCatalog, \.\.\.value\[flag\], loading: false, error: cause\.message \}/)
  assert.equal(describeReach(0, false), 'no other members')
  assert.equal(describeReach(1, false), 'asked 1 member')
  assert.equal(describeReach(3, false), 'asked 3 members')
  assert.equal(describeReach(340, true), 'asked 200 of 340 members')
})

test('the agent tags a catalog entry only when the group policy alone granted the read', () => {
  assert.match(catalogRequest, /\?\.  \(repository-readable repo src\.bowl\)  ~/)
  assert.match(catalogRequest, /\(can-read:git-access public-read\.repo owner\.repo readers\.repo writers\.repo %none src\.bowl\)/)
  assert.match(gaps(catalogRequest), /\?:  explicit  ~  \?~  group-policy\.repo  ~  `group\.u\.group-policy\.repo/)
  assert.match(gaps(catalogRequest), /\(repository-writable repo src\.bowl\)  via  ==/)
  assert.match(catalogRequest, /\(pack:git-catalog request\.msg answer\)/)
  assert.doesNotMatch(catalogRequest, /group-seat|\.\^/)
})

test('the fan-out reads seats from this ship\'s Groups, skips this ship, stops at 200, and says so', () => {
  assert.match(discoverGroup, /\(parse-group-flag u\.group-text\)/)
  assert.match(discoverGroup, /'group must be a Groups flag, ~host\/name'/)
  assert.match(discoverGroup, /=\/  members=\(unit \(set ship\)\)  \(group-members u\.group\)/)
  assert.match(discoverGroup, /'this ship is not a member of that group'/)
  assert.match(discoverGroup, /\(~\(del in u\.members\) our\.bowl\)/)
  assert.match(discoverGroup, /=\/  capped=\?  \(gth \(lent others\) 200\)/)
  assert.match(discoverGroup, /=\/  targets=\(list ship\)  \(scag 200 others\)/)
  assert.match(discoverGroup, /\[%catalog-request request\]/)
  assert.match(discoverGroup, /\(waiting:git-catalog i\.targets group\)/)
  assert.match(discoverGroup, /%wait \(add now\.bowl ~s30\)/)
  assert.match(discoverGroup, /\['capped' b\+capped\]/)
  assert.match(discoverGroup, /\['members' n\+\(decimal \(lent others\)\)\]/)
  // the group is read on exactly the terms access reads it
  assert.match(gaps(arm(backend, 'on-poke/group-members')), /\+\+  group-members  \|=  group=\[host=@p name=@tas\]  \^-  \(unit \(set ship\)\)  \?~  \(group-seat `\[group %none ~\] our\.bowl\)  ~/)
  // discoveries stay transient
  assert.match(backend, /^=\/  peer-discoveries  \*\(map @uv peer-discovery\)$/m)
  assert.match(gaps(backend), /(?:^|  )peer-discoveries  ~  peer-inflight  ~  peer-browses  ~(?=  |$)/)
  assert.doesNotMatch(gitStateSource, /state-6/)
  assert.doesNotMatch(ciStateSur, /inflight|ledger|discover/, "%urgit-ci's state carries no discovery")
  assert.doesNotMatch(readFileSync(new URL('../../desk/sur/git.hoon', import.meta.url), 'utf8'), /state-6|discover/)
  assert.match(discoveriesJson, /\['via' \(group-flag-json via\.repo\)\]/)
  assert.match(discoveriesJson, /\['group' \(group-flag-json group\.discovery\)\]/)
})

test('catalog entries carry via on the wire under a new tag while the old tag keeps its shape', () => {
  assert.match(wire, /\+\$  catalog-repository-legacy\n  \$:  name=@t\n      head=@t\n      refs=@ud\n      objects=@ud\n      writable=\?\n  ==/)
  assert.match(wire, /\+\$  catalog-repository\n  \$:  name=@t\n      head=@t\n      refs=@ud\n      objects=@ud\n      writable=\?\n      via=\(unit \[host=@p name=@tas\]\)\n  ==/)
  assert.match(wire, /\[%catalog catalog=catalog-legacy\]\n      \[%catalog-via catalog=catalog\]/)
  assert.match(mark, /noun/)
  assert.match(catalogLib, /\+\+  pack\n  \|=  \[request=@uv answer=\(list catalog-repository:git-peer\)\]/)
  assert.match(catalogLib, /\?\.  \(levy answer \|=\(repo=catalog-repository:git-peer \?=\(~ via\.repo\)\)\)\n    \[%catalog-via request answer\]\n  \[%catalog request \(turn answer legacy\)\]/)
  assert.match(gaps(catalogLib), /%catalog  `\[request\.catalog\.packet \(turn repositories\.catalog\.packet from-legacy\)\]/)
  assert.match(gaps(arm(backend, 'on-poke/handle-peer')), /%catalog  \(peer-catalog-legacy catalog\.packet\)  %catalog-via  \(peer-catalog catalog\.packet\)/)
  // the vector round-trips both shapes through the mark the peers exchange
  assert.match(catalogVector, /\(noun:grab:git-peer-mark \(cue \(jam packet\)\)\)/)
  assert.match(catalogVector, /\?>  \?=\(%catalog -\.old\)/)
  assert.match(catalogVector, /\?>  \?=\(%catalog-via -\.new\)/)
  assert.match(catalogVector, /\?>  =\(\[~ request ~\[plain\]\] \(unpack:git-catalog \(receive from-old\)\)\)/)
})
