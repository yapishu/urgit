import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The control that chooses a runner's repositories (hands-on review,
// 2026-10-19: "That edit button is VERY NOT OBVIOUS"). It was a lowercase
// text link reading "edit" at the end of the Repositories cell. It is now a
// bordered button that names what it changes. These tests read the
// component's source and the stylesheet; they are NOT a browser render
// (the Runners panel loads its rows from the ship), so the parent rechecks
// the row in Chromium.

const source = readFileSync(new URL('./components/Runners.jsx', import.meta.url), 'utf8')
const css = readFileSync(new URL('./style.css', import.meta.url), 'utf8')

// the JSX element whose onClick opens the repository binding
function bindingControl() {
  const at = source.indexOf('onClick={() => setBinding(row)}')
  assert.ok(at > 0, 'the row has a control that opens the repository binding')
  const open = source.lastIndexOf('<button', at)
  const close = source.indexOf('</button>', at)
  return source.slice(open, close + '</button>'.length)
}

test('the repository binding is a labelled button, not a text link', () => {
  const control = bindingControl()
  assert.match(control, /className="button small"/)
  assert.doesNotMatch(control, /text-button/)
  assert.match(control, />Repositories…<\/button>$/)
  assert.doesNotMatch(control, />edit</i)
})

test('the button says which runner it changes to assistive technology', () => {
  assert.match(bindingControl(), /aria-label=\{`Choose the repositories runner \$\{row\.shortId\} may take`\}/)
})

test('the small button and the repositories cell have their own rules', () => {
  assert.match(css, /\.button\.small \{[^}]*min-height: 28px/)
  assert.match(css, /\.ci-runner-repos \{[^}]*display: flex[^}]*flex-wrap: wrap/)
  assert.match(source, /<span data-label="Repositories" className="ci-runner-repos">/)
})

test('a revoked runner offers no binding', () => {
  const at = source.indexOf('onClick={() => setBinding(row)}')
  const guard = source.slice(source.lastIndexOf('{', source.lastIndexOf('<button', at)), at)
  assert.match(guard, /row\.state !== 'revoked' &&/)
})
