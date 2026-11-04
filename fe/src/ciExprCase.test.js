// correction-02: text without case. The ship decides a case-insensitive
// operation only where ASCII-only folding and every simple Unicode case
// mapping agree; elsewhere it is an error naming the texts and the limit.
// desk/gen/ci-expr-case-vector checks the evaluator, +decide:ci-plan and
// +resolve:ci-expr natively; this pins in the source what a generator
// cannot reach: %urgit-ci keeps that error typed (an `if` that cannot be
// evaluated fails its job and is never run or skipped; an output that
// cannot be resolved keeps its reason and is never published), and no
// case-insensitive operation of the evaluator lowers a text that may hold
// a non-ASCII letter before deciding it.
import test from 'node:test'
import assert from 'node:assert/strict'
import { armsNamed, deskText, enclosingArms } from './hoonSource.js'

const expr = deskText('lib/ci-expr.hoon')
const plan = deskText('lib/ci-plan.hoon')
const agent = deskText('app/urgit-ci.hoon')
const concurrency = deskText('lib/ci-concurrency.hoon')

const one = (text, name) => {
  const found = armsNamed(text, name)
  assert.equal(found.length, 1, `exactly one arm ${name}`)
  return found[0]
}

// the arms whose code (not comments) holds `needle`
const armsWith = (text, needle) => {
  const out = new Set()
  text.split('\n').forEach((line, i) => {
    if (!line.trim().startsWith('::') && line.includes(needle)) out.add(enclosingArms(text, i).join('/'))
  })
  return [...out].sort()
}

test('a comparison, a property, an index, membership and a function answer an error, not a value', () => {
  assert.match(one(expr, 'compare'), /\^- {2}\(each \? @t\)/)
  for (const name of ['property', 'lookup', 'element', 'member', 'apply']) {
    assert.match(one(expr, name), /\^- {2}\(each val @t\)/, name)
  }
  const run = one(expr, 'run')
  assert.ok(run.includes('=/  c=(each ? @t)  (compare op.e v.p.l v.p.r)\n    ?:  ?=(%| -.c)  |+p.c'))
  assert.ok(run.includes('=/  x=(each val @t)  (property v.p.r filtered.p.r name.e)\n    ?:  ?=(%| -.x)  |+p.x'))
  assert.ok(run.includes('=/  x=(each val @t)  (element v.p.r filtered.p.r v.p.i)\n    ?:  ?=(%| -.x)  |+p.x'))
})

// correction 03: order upper-cases ASCII letters as GitHub's runner does
// (OrdinalIgnoreCase), so +text-order folds with +upper, not +lower; the
// guard is the same
test('text is folded only behind an ASCII guard, or to answer equal', () => {
  assert.deepEqual(armsWith(expr, '(lower '), ['text-contains', 'text-ends', 'text-same', 'text-starts'])
  assert.deepEqual(armsWith(expr, '(upper '), ['text-order'])
  assert.deepEqual(armsWith(expr, '(cuss '), ['upper'])
  assert.ok(one(expr, 'text-same').includes('?:  =((lower a) (lower b))  &+%.y\n  ?:  ?&((ascii-text a) (ascii-text b))  &+%.n'))
  for (const [name, fold] of [['text-order', '(upper '], ['text-starts', '(lower '], ['text-ends', '(lower '], ['text-contains', '(lower ']]) {
    const text = one(expr, name)
    const guard = text.indexOf('(ascii-text ')
    assert.ok(guard > 0 && guard < text.indexOf(fold), `${name}: an ASCII guard before the first fold`)
  }
  // plan-time names are lowered and then matched exactly against ASCII sets
  assert.deepEqual(armsWith(expr, '(cass '), ['build', 'check-context', 'lower', 'steps-property'])
})

test('an if that cannot be evaluated is an error decision: the job fails, it is never run or skipped', () => {
  const decide = one(plan, 'decide')
  assert.ok(decide.includes("?:  ?=(%| -.value)\n      [%error (rap 3 ~['if ' shown ' could not be evaluated: ' p.value])]"))
  assert.ok(one(agent, 'decide-pass').includes('%error  (record-decision id job [%error reason.decision ~] needs)'))
  assert.ok(one(agent, 'record-decision').includes('?:(?=(%error verdict.decision) %failed %skipped)'))
  // the concurrency gate decides first (CI-CONCURRENCY-1), then the same
  // +decide:ci-plan with cancelled() read for the job's own workflow run
  assert.ok(one(agent, 'runnable-jobs').includes('=(%run -:(decide-with:ci-concurrency state candidate job u.plan.candidate standings.known entries context))'))
  const gated = one(concurrency, 'decide-with')
  assert.ok(gated.includes('=/  gated=(unit decision:ci-plan)  (gate s c job)\n  ?^  gated  u.gated\n  %:  decide:ci-plan'))
})

test('an output that cannot be resolved keeps its reason and is never published', () => {
  const resolve = one(agent, 'resolve-outputs')
  assert.ok(resolve.includes('%+  turn  (resolve:ci-expr u.outputs.u.planned scope)'))
  assert.ok(resolve.includes('?:  ?=(%| -.r)  [name [%| p.r] %.n]'))
  // the agent publishes through lib/ci-concurrency, which its vector reads
  // too (CI-CONCURRENCY-1): the guard is held there
  assert.ok(one(agent, 'published-outputs').includes('(published-outputs:ci-concurrency planned a)'))
  assert.ok(one(concurrency, 'published-outputs').includes('?.  ?=(%& -.value.o)  ~'))
})

test('the vectors run the public evaluator, the decision and the resolution', () => {
  const cases = deskText('gen/ci-expr-case-vector.hoon')
  for (const call of ['/+  ci-expr, ci-plan', '(eval:ci-expr e sc)', '(decide:ci-plan j ~[j] ~ ~ ctx)', '(resolve:ci-expr outputs sc)']) {
    assert.ok(cases.includes(call), call)
  }
  const regressions = deskText('gen/ci-expr-regressions-vector.hoon')
  assert.ok(regressions.includes('(eval:ci-expr e empty-scope:ci-expr)'))
  assert.ok(!regressions.includes('(compare:ci-expr '), 'the regressions vector no longer reads the boolean helper')
})
