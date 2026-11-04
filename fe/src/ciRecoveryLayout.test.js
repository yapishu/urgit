import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { renderCiRecovery } from './ciRecoveryView.js'
import { initialRecoveryView, recoveryReducer } from './ciRecovery.js'
import { NOW, staged, viewOf } from './ciRecoveryFixtures.js'
import { all, h } from './runnerRecoveryFixtures.js'

// CI recovery at 320px (CI-RECOVERY-1). These tests read the stylesheet's
// own rules and the view's markup, as responsiveLayout.test.js does. They
// are NOT a browser: the parent checks the geometry in Chromium.

const css = readFileSync(new URL('./style.css', import.meta.url), 'utf8').replace(/\/\*[\s\S]*?\*\//g, '')

function blocks(source) {
  const out = []
  let depth = 0
  let start = 0
  const prelude = []
  for (let i = 0; i < source.length; i++) {
    const c = source[i]
    if (c === '{') { prelude.push(source.slice(start, i).trim()); depth++; start = i + 1 } else if (c === '}') {
      const sel = prelude.pop()
      if (!sel.startsWith('@')) out.push({ selector: sel, body: source.slice(start, i), within: prelude.filter((p) => p.startsWith('@')).at(-1) || null })
      depth--
      start = i + 1
    } else if (c === ';' && depth === 0) start = i + 1
  }
  return out
}
const rules = blocks(css)
function decls(selector, within = null) {
  const found = rules.filter((r) => r.within === within && r.selector.split(',').map((s) => s.trim()).includes(selector))
  const map = {}
  for (const r of found) {
    for (const d of r.body.split(';')) {
      const at = d.indexOf(':')
      if (at < 0) continue
      map[d.slice(0, at).trim()] = d.slice(at + 1).trim()
    }
  }
  return map
}
const narrow = '@media (max-width: 760px)'

// the width a panel's content has at 320px: the narrow content padding
// (.content) and the panel's own padding (.panel), each side
const contentPadding = Number(/^\d+px (\d+)px/.exec(decls('.content', narrow).padding)?.[1])
const panelPadding = Number(/^(\d+)px$/.exec(decls('.panel').padding)?.[1])
const inner = 320 - 2 * contentPadding - 2 * panelPadding

test('at 320px the section has room, and spans the settings grid', () => {
  assert.equal(contentPadding, 20)
  assert.equal(panelPadding, 22)
  assert.equal(inner, 236)
  assert.equal(decls('.settings-columns > .ci-backup')['grid-column'], '1 / -1')
  assert.equal(decls('.settings-columns', narrow)['grid-template-columns'], '1fr')
})

test('nothing in the section is wider than 236px: long ids and hashes wrap, rows wrap, the table scrolls inside its box', () => {
  assert.equal(decls('.ci-backup')['min-width'], '0')
  assert.equal(decls('.ci-backup')['overflow-wrap'], 'anywhere')
  assert.equal(decls('.ci-backup code')['word-break'], 'break-all')
  assert.equal(decls('.ci-backup-facts')['flex-wrap'], 'wrap')
  assert.equal(decls('.ci-backup-fact')['max-width'], '100%')
  assert.equal(decls('.ci-backup-controls')['flex-wrap'], 'wrap')
  assert.equal(decls('.ci-backup-table')['overflow-x'], 'auto')
  assert.equal(decls('.ci-backup-table')['max-width'], '100%')
  assert.equal(decls('.ci-backup-diff li')['overflow-wrap'], 'anywhere')
  // no fixed width of any section rule exceeds the room it has
  for (const r of rules.filter((x) => x.selector.includes('ci-backup'))) {
    for (const m of r.body.matchAll(/(?:^|;|\s)(?:width|min-width|flex-basis|flex)\s*:\s*([^;]+)/g)) {
      for (const n of m[1].matchAll(/([\d.]+)(px|rem)\b/g)) {
        const px = n[2] === 'rem' ? Number(n[1]) * 16 : Number(n[1])
        assert.ok(px <= inner, `${r.selector} asks for ${n[0]}, wider than ${inner}px`)
      }
    }
  }
})

test('narrow: the controls, the pause reason and the import field stack to the full width', () => {
  assert.equal(decls('.ci-backup-controls', narrow)['flex-direction'], 'column')
  assert.equal(decls('.ci-backup-pause', narrow)['flex-direction'], 'column')
  assert.equal(decls('.ci-backup-import', narrow)['flex-direction'], 'column')
  assert.equal(decls('.ci-backup-controls .button', narrow).width, '100%')
  assert.equal(decls('.ci-backup-pause input', narrow).width, '100%')
  assert.equal(decls('.ci-backup-import input', narrow).width, '100%')
  assert.equal(decls('.ci-backup-pause input')['min-width'], '0')
})

test('the markup uses those classes: every control sits in a wrapping row, every hash in a code element', () => {
  const state = recoveryReducer(initialRecoveryView(), { type: 'loaded', view: viewOf({ paused: { at: NOW, actor: '~zod', reason: 'drill' }, staged: staged() }) })
  const tree = renderCiRecovery(h, { state, now: NOW }, {})
  const buttons = all(tree, (n) => n.type === 'button')
  assert.ok(buttons.length >= 4)
  const rows = all(tree, (n) => /ci-backup-(controls|import|pause)/.test(n.props?.className || ''))
  for (const b of buttons) {
    assert.ok(rows.some((row) => all(row, (n) => n === b).length), `${b.props['data-part']} is outside a wrapping row`)
  }
  const codes = all(tree, (n) => n.type === 'code')
  assert.ok(codes.some((c) => (c.children || []).join('').length === 40), 'the staged commit is in a code element')
  assert.equal(tree.props.className, 'panel ci-backup')
  // a failed replica uses the error colour: status bad, never warn
  assert.ok(css.includes('.status.bad {'), 'the error status style exists')
})
