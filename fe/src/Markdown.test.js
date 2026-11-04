import test from 'node:test'
import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import assert from 'node:assert/strict'
import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { createServer } from 'vite'

test('renders a gbrain-style GFM table with inline code and column alignment', async () => {
  const cacheDir = mkdtempSync(join(tmpdir(), 'urgit-ssr-'))
  const server = await createServer({ configLoader: 'native', cacheDir, server: { middlewareMode: true, ws: false, hmr: false, watch: null }, appType: 'custom' })
  try {
    const { default: Markdown } = await server.ssrLoadModule('/src/components/Markdown.jsx')
    const source = `| Concept | Status | Score |
| :--- | :---: | ---: |
| \`noun\` | active | 42 |`
    const html = renderToStaticMarkup(React.createElement(Markdown, null, source))

    assert.match(html, /<table>/)
    assert.match(html, /<code>noun<\/code>/)
    assert.match(html, /<th style="text-align:left">Concept<\/th>/)
    assert.match(html, /<th style="text-align:center">Status<\/th>/)
    assert.match(html, /<th style="text-align:right">Score<\/th>/)
  } finally {
    await server.close()
    rmSync(cacheDir, { recursive: true, force: true })
  }
})
