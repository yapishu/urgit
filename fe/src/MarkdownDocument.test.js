import test from 'node:test'
import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { createServer } from 'vite'

async function renderMarkdownDocument(source, props = {}) {
  const cacheDir = mkdtempSync(join(tmpdir(), 'urgit-ssr-'))
  const server = await createServer({ configLoader: 'native', cacheDir, server: { middlewareMode: true, ws: false, hmr: false, watch: null }, appType: 'custom' })
  try {
    const { default: MarkdownDocument } = await server.ssrLoadModule('/src/components/MarkdownDocument.jsx')
    return renderToStaticMarkup(React.createElement(MarkdownDocument, props, source))
  } finally {
    await server.close()
    rmSync(cacheDir, { recursive: true, force: true })
  }
}

test('renders leading YAML frontmatter as ordered metadata above the Markdown body', async () => {
  const source = `---
type: concept
title: Visible frontmatter
timestamp: 2026-08-19T12:34:56Z
tags:
  - urbit
  - markdown

10: ten
2: two
status: draft
---
# Actual heading`
  const html = await renderMarkdownDocument(source)

  assert.match(html, /<table class="markdown-frontmatter">/)
  assert.match(html, /<th scope="row">type<\/th><td>concept<\/td>/)
  assert.match(html, /<th scope="row">title<\/th><td>Visible frontmatter<\/td>/)
  assert.match(html, /<th scope="row">timestamp<\/th><td>2026-08-19T12:34:56Z<\/td>/)
  assert.match(html, /<th scope="row">tags<\/th><td><code class="markdown-frontmatter-complex">- urbit\n- markdown<\/code><\/td>/)
  assert.match(html, /<th scope="row">10<\/th><td>ten<\/td>/)
  assert.match(html, /<th scope="row">2<\/th><td>two<\/td>/)
  assert.match(html, /<th scope="row">status<\/th><td>draft<\/td>/)
  assert.ok(html.indexOf('>type</th>') < html.indexOf('>title</th>'))
  assert.ok(html.indexOf('>title</th>') < html.indexOf('>timestamp</th>'))
  assert.ok(html.indexOf('>timestamp</th>') < html.indexOf('>tags</th>'))
  assert.ok(html.indexOf('>tags</th>') < html.indexOf('>10</th>'))
  assert.ok(html.indexOf('>10</th>') < html.indexOf('>2</th>'))
  assert.ok(html.indexOf('>2</th>') < html.indexOf('>status</th>'))
  assert.match(html, /<h1>Actual heading<\/h1>/)
})

test('recognizes only leading frontmatter with BOM and CRLF and keeps complex values legible', async () => {
  const leading = '\uFEFF---\r\ntype: concept\r\nsettings:\r\n  owner: ~zod\r\n  flags:\r\n    - visible\r\n---\r\n# BOM heading\r\n\r\n---\r\n\r\nAfter break'
  const laterBreak = '# Plain heading\n\n---\n\ntype: ordinary body text'

  const leadingHtml = await renderMarkdownDocument(leading)
  const laterBreakHtml = await renderMarkdownDocument(laterBreak)

  assert.equal((leadingHtml.match(/<table class="markdown-frontmatter">/g) || []).length, 1)
  assert.match(leadingHtml, /<h1>BOM heading<\/h1>/)
  assert.match(leadingHtml, /owner:/)
  assert.match(leadingHtml, /flags:/)
  assert.match(leadingHtml, /visible/)
  assert.doesNotMatch(leadingHtml, /\[object Object\]/)
  assert.equal((leadingHtml.match(/<hr\s*\/>/g) || []).length, 1)
  assert.doesNotMatch(laterBreakHtml, /markdown-frontmatter/)
  assert.match(laterBreakHtml, /<hr\s*\/>/)
  assert.match(laterBreakHtml, /type: ordinary body text/)
})

test('keeps malformed, unclosed, and non-map frontmatter visibly present', async () => {
  const malformed = `---
title: [unfinished
---
# Malformed body`
  const unclosed = `---
title: Never closed
# Unclosed body`
  const nonMap = `---
- concept
- urbit
---
# Non-map body`

  const malformedHtml = await renderMarkdownDocument(malformed)
  const unclosedHtml = await renderMarkdownDocument(unclosed)
  const nonMapHtml = await renderMarkdownDocument(nonMap)

  assert.doesNotMatch(malformedHtml, /markdown-frontmatter/)
  assert.match(malformedHtml, /title: \[unfinished/)
  assert.match(malformedHtml, /Malformed body/)
  assert.doesNotMatch(unclosedHtml, /markdown-frontmatter/)
  assert.match(unclosedHtml, /title: Never closed/)
  assert.match(unclosedHtml, /Unclosed body/)
  assert.doesNotMatch(nonMapHtml, /markdown-frontmatter/)
  assert.match(nonMapHtml, /concept/)
  assert.match(nonMapHtml, /urbit/)
  assert.match(nonMapHtml, /Non-map body/)
})

test('frontmatter is display-only while Markdown props still control rendering', async () => {
  const source = `---
className: metadata-class
onOpenPath: metadata-handler
---
[Repository file](docs/file.md)`
  const html = await renderMarkdownDocument(source, { className: 'actual-class', onOpenPath: () => {} })

  assert.match(html, /class="markdown-body actual-class"/)
  assert.doesNotMatch(html, /class="metadata-class"/)
  assert.match(html, /<a href="docs\/file\.md">Repository file<\/a>/)
})

test('renders GitHub user-attachment HTML image tags inline', async () => {
  const source = 'Before <img width="947" height="585" alt="image" src="https://github.com/user-attachments/assets/b13cdad5-ab95-4e9a-95af-e3fc81fbdd18" /> after'
  const html = await renderMarkdownDocument(source)

  assert.match(html, /<p>Before <img /)
  assert.match(html, /src="https:\/\/github\.com\/user-attachments\/assets\/b13cdad5-ab95-4e9a-95af-e3fc81fbdd18"/)
  assert.match(html, /alt="image"/)
  assert.match(html, /width="947"/)
  assert.match(html, /height="585"/)
  assert.match(html, /\/> after<\/p>/)
})

test('does not enable arbitrary raw HTML images', async () => {
  const source = '<img alt="tracking" src="https://example.com/tracker.png" />'
  const html = await renderMarkdownDocument(source)

  assert.doesNotMatch(html, /<img/)
  assert.match(html, /&lt;img alt=&quot;tracking&quot;/)
})

test('keeps frontmatter metadata compact and usable in narrow Markdown panels', async () => {
  const css = await readFile(new URL('./frontmatter.css', import.meta.url), 'utf8')
  const tableRule = css.match(/\.markdown-frontmatter\s*\{([^}]*)\}/)?.[1] || ''
  const complexRule = css.match(/\.markdown-frontmatter-complex\s*\{([^}]*)\}/)?.[1] || ''

  assert.match(tableRule, /max-width:\s*100%/)
  assert.match(tableRule, /overflow-x:\s*auto/)
  assert.match(tableRule, /font-size:\s*12px/)
  assert.match(complexRule, /white-space:\s*pre-wrap/)
  assert.match(complexRule, /overflow-wrap:\s*anywhere/)
})
