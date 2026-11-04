// correction 04: a peer's write belongs to the peer. A receive this ship
// accepted from a peer's push or pull request completes either by the peer's
// own packet or by this ship's continuation of a Fine page it checked came
// from that peer; the receipt's actor must be the peer either way, never the
// host that delivered the continuation to itself. desk/gen/
// ci-peer-attribution-vector checks the decision (+receive-attribution) and
// the receipt (+forge-actions) natively; this pins in the source what a
// generator cannot reach: %urgit's on-poke reads that decision with the
// receives in flight as the event BEGAN (before +peer-finish removes the
// flight), only the two completing packets consult it, and the sibling
// actors (CI staging, the linked desk) already use the flight's source.
import test from 'node:test'
import assert from 'node:assert/strict'
import { armsNamed, deskText } from './hoonSource.js'

const agent = deskText('app/urgit.hoon')
const transfer = deskText('lib/git-peer-transfer.hoon')

const one = (text, name) => {
  const found = armsNamed(text, name)
  assert.equal(found.length, 1, `exactly one arm ${name}`)
  return found[0]
}

test('a %git-peer poke is attributed by the receive it completes, with the flights as the event began', () => {
  const poke = one(agent, 'poke-attribution')
  assert.match(poke, /\|=  \[=mark =vase repos=\(map @t repository:git\) flights=\(map @uv peer-receive\)\]/)
  assert.ok(poke.includes('[(receive-attribution p.got flights src.bowl our.bowl) \'peer\']'))
  assert.ok(!/%git-peer  \[src\.bowl 'peer'\]/.test(poke), 'the immediate-sender attribution is gone')
  // the wrapper passes the pre-event flights (before.receiving), not the state after peer-finish
  assert.ok(agent.includes('(poke-attribution:hc mark vase repos-before receiving.before)'))
  assert.ok(agent.includes('=/  before=peer-ui-state\n    [peer-activities notification-activities peer-results peer-receiving peer-outgoing]'))
})

test('only the two completing packets consult the flight, and they are the only callers of peer-finish', () => {
  const gate = one(transfer, 'receive-attribution')
  assert.ok(gate.includes('%snapshot  `transfer.packet'))
  assert.ok(gate.includes('%object-fragments  `transfer.packet'))
  assert.equal((gate.match(/`transfer\.packet/g) || []).length, 2, 'exactly two completing kinds')
  // a fork or its refresh is the requester's; an offer is its source's; a mismatch is its sender's
  assert.ok(gate.includes('?.  |(=(src our) =(src source.u.flight))  src'))
  assert.ok(gate.includes('?:  ?=(%fork purpose.u.flight)  our'))
  assert.match(gate, /\n  source\.u\.flight\s*$/)
  const finishers = agent.split('\n').filter((line) => line.includes('(peer-finish transfer)'))
  assert.equal(finishers.length, 2, 'peer-finish has exactly two callers')
  assert.ok(one(agent, 'peer-object-fragments').includes('(peer-finish transfer)'))
  assert.ok(one(agent, 'peer-snapshot').includes('(peer-finish transfer)'))
})

test('the sibling actors already use the flight\'s source, and a fork refresh stages as its requester', () => {
  const finish = one(agent, 'peer-finish')
  // an incoming push stages its CI candidates as the offering peer
  assert.ok(finish.includes('(ci-stages:hc local-repository.flight u.existing stages.gate source.flight %session)'))
  // a fork's install or refresh stages as this ship, the refresh's requester
  assert.ok(finish.includes('(ci-stages:hc local-repository.flight u.existing stages.gate our.bowl %session)'))
  // a linked-desk peer write parks its peer and is credited to it on completion
  assert.ok(finish.includes('`[[source.flight transfer]]'))
  const arvo = one(agent, 'arvo-attribution')
  assert.ok(arvo.includes("[ship.u.peer-response.u.parked 'peer push (linked desk)']"))
})

test('the Fine reply only checks its ship and continues locally; it persists no refs itself', () => {
  const fine = one(agent, 'peer-fine')
  assert.ok(fine.includes('?.  =(ship.p.sage source.u.found)'), 'a Fine page must come from the flight\'s source')
  assert.ok(fine.includes('(peer-card our.bowl /peer/snapshot/(scot %uv u.transfer) packet)'), 'and is continued by this ship')
  assert.ok(!fine.includes('(peer-finish'), 'the Fine reply itself finishes nothing')
})
