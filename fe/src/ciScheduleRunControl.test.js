import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { scheduleModel } from './ciEvents.js'
import { makeSchedules } from './ciEventsComponent.js'
import { renderSchedules } from './ciEventsView.js'
import { all, h, hooksRuntime, part, parts, settle, text } from './runnerRecoveryFixtures.js'

// The Schedules tab's open run (correction 05). In the parent's browser, at a
// 1360px viewport, a retired schedule's open run lay wholly outside its
// parent small.quiet.ci-job-meta: the button at x 1111 to 1158.375, the
// parent's right edge at 1106.84375, overflow-x hidden and nowrap,
// scrollWidth 441 against clientWidth 389 (UI-SCHEDULE-LINK-GEOMETRY.json).
// None of this is a browser. The row is the view's own render (React's server
// render must give the same markup); the styles are this stylesheet's own
// rules put through a small model of selector matching and the cascade; the
// widths come from a box model of the page, calibrated against the captured
// numbers. Only a browser certifies the layout: the parent rechecks it.

let deps = null
try {
  const [react, server] = await Promise.all([import('react'), import('react-dom/server')])
  deps = { React: react.default ?? react, renderToStaticMarkup: server.renderToStaticMarkup }
} catch {
  deps = null
}
const skip = deps ? false : 'fe/node_modules is not installed (react, react-dom): the React render is NOT RUN here'

// ---- the captured row: the browser's text of it (UI-SCHEDULE.json, where
// RETIRED is the status badge's uppercase of `retired`) and its geometry

const CAPTURED_TEXT = [
  'Schedule reload acceptance · schedule.yml #0',
  '*/5 * * * * · UTC (default)',
  'RETIRED',
  'baseline of refs/heads/master revoked: no promoted baseline governs refs/heads/master: nothing runs (promote one in Settings → CI policy)',
  'no next occurrence',
  'last due 2026-10-16 20:55 UTC · admitted 2026-10-16 20:55 UTC (on time) open run',
  'promoted by ~nec · baseline f3570bc7 · lock 8f07807a · from master',
  '1 stale wake ignored',
].join('\n')
const CAPTURED = { viewport: 1360, parentLeft: 717.703125, parentRight: 1106.84375, parentWidth: 389.140625, buttonLeft: 1111, buttonRight: 1158.375, scrollWidth: 441, clientWidth: 389 }
const BUTTON = CAPTURED.buttonRight - CAPTURED.buttonLeft
const TEXT_BEFORE = CAPTURED.buttonLeft - CAPTURED.parentLeft

// the ship's schedules answer that renders that row: every shown value is the
// captured text, and the run is the one the parent's report names for the
// 20:55 due; what the row does not show (definition, promoted, registered,
// the admission's seconds) is a placeholder
const RUN = '0v7.8301k.3pp43.tvvm4.5lnr2.79r13'
const instant = (at, utc, local) => ({ at, utc, local })
const DUE = instant(1792198500, '2026-10-16T20:55:00Z', '2026-10-16 20:55 UTC')
const retired = {
  workflow: 'schedule.yml', index: 0, name: 'Schedule reload acceptance', cron: '*/5 * * * *', timezone: null, timezoneLabel: 'UTC (default)',
  state: 'retired', reason: 'baseline of refs/heads/master revoked: no promoted baseline governs refs/heads/master: nothing runs (promote one in Settings → CI policy)', refusal: null,
  ref: 'refs/heads/master', baseline: 'f3570bc7cb9b2a74341c97b6e616b1f225665747', lock: '8f07807a61ce4832cc8edc84cf87a897a560b77dcc44f1f5e37ad84a5b383388',
  promoter: '~nec', promoted: 1792197000, registered: 1792197000, definition: '0v1.unshown',
  next: null, lastDue: DUE, lastAdmitted: { due: DUE, at: DUE, run: RUN, late: false, lateSeconds: 0 }, missed: [], staleWakes: 1,
}
const answer = (...schedules) => ({
  repo: 'wf1c-schedule-reload', now: 1792198664, nowUtc: '2026-10-16T20:57:44Z', defaultBranch: 'refs/heads/master',
  refresh: 'no promoted baseline governs refs/heads/master: nothing runs (promote one in Settings → CI policy)', schedules,
})

// long values in every column: a long title and file, a list cron, a long
// zone name, a long refusal, an admission late by hours in a zone with an
// offset, missed occurrences and stale wakes
const ZONE = 'America/Argentina/ComodRivadavia'
const LONG_DUE = instant(1792155600, '2026-10-16T09:00:00Z', '2026-10-16 06:00 UTC-03:00')
const longActive = {
  ...retired,
  workflow: 'nightly-integration-and-release-candidate-verification.yml', index: 12,
  name: 'Nightly integration and release-candidate verification across every supported platform and toolchain',
  cron: '0,5,10,15,20,25,30,35,40,45,50,55 0-23/2 1-31 1-12 MON-FRI', timezone: ZONE, timezoneLabel: ZONE,
  state: 'active', reason: '',
  next: instant(1792242000, '2026-10-17T09:00:00Z', '2026-10-17 06:00 UTC-03:00'),
  lastDue: LONG_DUE,
  lastAdmitted: { due: LONG_DUE, at: instant(1792205100, '2026-10-16T22:45:00Z', '2026-10-16 19:45 UTC-03:00'), run: '0v2.ab12c.de34f.gh56i.jk78l.mn90p', late: true, lateSeconds: 49500 },
  missed: [{ first: instant(1791032400, '2026-10-03T09:00:00Z', '2026-10-03 06:00 UTC-03:00'), last: instant(1792069200, '2026-10-15T09:00:00Z', '2026-10-15 06:00 UTC-03:00'), count: 14 }],
  staleWakes: 3,
}
const REFUSAL = 'the schedule runs 4 minute(s) apart; GitHub Actions runs scheduled workflows at most once every five minutes, and this one is refused rather than clamped; its earlier definition admitted the run below'
const longRefused = {
  ...longActive, index: 13, state: 'refused', reason: REFUSAL, refusal: REFUSAL, next: null,
  lastAdmitted: { ...longActive.lastAdmitted, run: '0v2.qr12s.tu34v.ab56c.de78f.gh90i' },
}

const noop = () => {}
function rendered(...schedules) {
  const opened = []
  const model = scheduleModel(answer(...schedules))
  const tree = renderSchedules(h, { phase: 'ready', error: '', model }, { refresh: noop, retry: noop, openRun: (id) => opened.push(id) })
  return { tree, opened, panel: onPage(tree) }
}

// ---- this stylesheet as rules: each rule's selectors (with specificity),
// declarations, source order and the @media/@container conditions around it

function splitTop(source, separator) {
  const out = []
  let depth = 0
  let quote = ''
  let start = 0
  for (let i = 0; i < source.length; i++) {
    const c = source[i]
    if (quote) {
      if (c === quote) quote = ''
    } else if (c === '"' || c === "'") quote = c
    else if (c === '(' || c === '[') depth++
    else if (c === ')' || c === ']') depth--
    else if (depth === 0 && (separator === ' ' ? /\s/.test(c) : c === separator)) {
      out.push(source.slice(start, i))
      start = i + 1
    }
  }
  out.push(source.slice(start))
  return out.map((x) => x.trim()).filter(Boolean)
}

function parseCss(source) {
  const s = source.replace(/\/\*[\s\S]*?\*\//g, '')
  const rules = []
  let i = 0
  const upTo = (stops) => {
    const start = i
    let quote = ''
    let depth = 0
    for (; i < s.length; i++) {
      const c = s[i]
      if (quote) {
        if (c === quote) quote = ''
      } else if (c === '"' || c === "'") quote = c
      else if (c === '(') depth++
      else if (c === ')') depth--
      else if (depth === 0 && stops.includes(c)) break
    }
    return s.slice(start, i).trim()
  }
  const skipBlock = () => {
    for (let depth = 1; depth > 0 && i < s.length; i++) depth += s[i] === '{' ? 1 : s[i] === '}' ? -1 : 0
  }
  const block = (conditions) => {
    while (i < s.length) {
      const prelude = upTo('{};')
      const c = s[i++]
      if (c === '}' || c === undefined) return
      if (c === ';') continue
      if (/^@(media|container)\b/.test(prelude)) block([...conditions, prelude])
      else if (prelude.startsWith('@')) skipBlock()
      else {
        const body = upTo('}')
        i++
        rules.push({ order: rules.length, conditions, selectors: splitTop(prelude, ',').map(parseSelector), declarations: splitTop(body, ';').map(parseDeclaration).filter(Boolean) })
      }
    }
  }
  block([])
  return rules
}

function parseDeclaration(source) {
  const colon = source.indexOf(':')
  if (colon < 0) return null
  const raw = source.slice(colon + 1).trim()
  return { property: source.slice(0, colon).trim().toLowerCase(), value: raw.replace(/\s*!\s*important$/i, ''), important: /!\s*important$/i.test(raw) }
}

// a selector as compounds, left to right, each with the combinator that joins
// it to the one before; pseudo-classes keep their argument (:not's parsed)
function parseSelector(source) {
  const sel = source.trim()
  const parts = []
  let compound = []
  let combinator = null
  let i = 0
  const name = () => {
    const m = /^-?[_a-zA-Z][-_a-zA-Z0-9]*/.exec(sel.slice(i))
    if (!m) throw new Error(`selector "${sel}": no name at ${i}`)
    i += m[0].length
    return m[0]
  }
  const argument = () => {
    const start = i + 1
    for (let depth = 0; i < sel.length; i++) {
      if (sel[i] === '(') depth++
      else if (sel[i] === ')' && --depth === 0) return sel.slice(start, i++)
    }
    throw new Error(`selector "${sel}": unbalanced (`)
  }
  while (i < sel.length) {
    const c = sel[i]
    if (/[\s>+~]/.test(c)) {
      let joint = ' '
      for (; i < sel.length && /[\s>+~]/.test(sel[i]); i++) if (!/\s/.test(sel[i])) joint = sel[i]
      parts.push({ compound, combinator })
      compound = []
      combinator = joint
    } else if (c === '*') {
      i++
      compound.push({ kind: 'any' })
    } else if (c === '#') {
      i++
      compound.push({ kind: 'id', name: name() })
    } else if (c === '.') {
      i++
      compound.push({ kind: 'class', name: name() })
    } else if (c === '[') {
      const end = sel.indexOf(']', i) + 1
      const m = /^\[\s*([-\w]+)\s*(?:(=)\s*(?:"([^"]*)"|'([^']*)'|([^\s\]]+))\s*)?\]$/.exec(sel.slice(i, end))
      if (!m) throw new Error(`selector "${sel}": attribute ${sel.slice(i, end)} is not modelled`)
      compound.push({ kind: 'attribute', name: m[1], value: m[2] ? (m[3] ?? m[4] ?? m[5]) : null })
      i = end
    } else if (c === ':' && sel[i + 1] === ':') {
      i += 2
      compound.push({ kind: 'element', name: name() })
    } else if (c === ':') {
      i++
      const pseudo = name().toLowerCase()
      const arg = sel[i] === '(' ? argument() : null
      compound.push({ kind: 'pseudo', name: pseudo, argument: arg, inner: pseudo === 'not' ? parseSelector(arg) : null })
    } else compound.push({ kind: 'tag', name: name().toLowerCase() })
  }
  parts.push({ compound, combinator })
  return { source: sel, parts, specificity: specificity(parts) }
}

function specificity(parts) {
  const total = [0, 0, 0]
  const count = (simple) => {
    if (simple.kind === 'id') total[0]++
    else if (simple.kind === 'class' || simple.kind === 'attribute') total[1]++
    else if (simple.kind === 'pseudo' && simple.inner) simple.inner.parts.forEach((p) => p.compound.forEach(count))
    else if (simple.kind === 'pseudo') total[1]++
    else if (simple.kind === 'tag' || simple.kind === 'element') total[2]++
  }
  parts.forEach((p) => p.compound.forEach(count))
  return total
}

const RULES = parseCss(readFileSync(new URL('./style.css', import.meta.url), 'utf8'))

// ---- the rendered panel on the page: the CI tab's real ancestors
// (App.jsx's .app-shell and .workspace, RepositoryView.jsx's main.content and
// section.repo-body, CiTab.jsx's section.panel.ci-tab) above the view's tree.
// Inside the panel every element's siblings are known; above it they are not

const PAGE = [['html', {}], ['body', {}], ['div', { id: 'root' }], ['div', { className: 'app-shell' }], ['div', { className: 'workspace' }], ['main', { className: 'content' }], ['section', { className: 'repo-body' }], ['section', { className: 'panel ci-tab' }]]

function adopt(node, parent, index, count, known) {
  const el = { tag: String(node.type).toLowerCase(), props: node.props || {}, node, parent, index, count, known, children: [] }
  const kids = (node.children || []).filter((c) => c && typeof c === 'object')
  el.children = kids.map((c, k) => adopt(c, el, k, kids.length, true))
  return el
}

function onPage(tree) {
  let parent = null
  for (const [tag, props] of PAGE) {
    const el = { tag, props, node: null, parent, index: 0, count: 1, known: false, children: [] }
    if (parent) parent.children = [el]
    parent = el
  }
  const panel = adopt(tree, parent, 0, 1, false)
  parent.children = [panel]
  return panel
}

const below = (el, wanted) => (wanted(el) ? [el] : []).concat(...el.children.map((c) => below(c, wanted)))
const classesOf = (el) => String(el.props.className || '').split(/\s+/).filter(Boolean)
const label = (el) => `${el.tag}${classesOf(el).map((c) => `.${c}`).join('')}${el.props['data-part'] ? `[data-part=${el.props['data-part']}]` : ''}`

function attributeOf(el, name) {
  const v = el.props[name === 'class' ? 'className' : name]
  if (v === undefined || v === null || v === false || typeof v === 'function') return undefined
  return v === true ? '' : String(v)
}

// ---- selector matching in a state: `dynamic` turns :hover, :focus and
// :active on, `unknown` answers the sibling facts the model does not know
// (above the panel), `scheme` is the colour scheme a media query asks for

const DYNAMIC = new Set(['hover', 'focus', 'focus-visible', 'focus-within', 'active'])

function nth(argument, position) {
  const t = argument.replace(/\s+/g, '')
  if (t === 'even') return position % 2 === 0
  if (t === 'odd') return position % 2 === 1
  const m = /^([+-]?\d*)n([+-]\d+)?$/.exec(t)
  if (!m) return position === Number(t)
  const a = m[1] === '' || m[1] === '+' ? 1 : m[1] === '-' ? -1 : Number(m[1])
  const b = Number(m[2] || 0)
  return a === 0 ? position === b : Number.isInteger((position - b) / a) && (position - b) / a >= 0
}

const STRUCTURAL = {
  'first-child': (el) => el.index === 0,
  'last-child': (el) => el.index === el.count - 1,
  'nth-child': (el, arg) => nth(arg, el.index + 1),
  'nth-last-child': (el, arg) => nth(arg, el.count - el.index),
}

function simpleMatches(el, simple, state) {
  switch (simple.kind) {
    case 'any': return true
    case 'tag': return el.tag === simple.name
    case 'id': return el.props.id === simple.name
    case 'class': return classesOf(el).includes(simple.name)
    case 'attribute': {
      const v = attributeOf(el, simple.name)
      return v !== undefined && (simple.value === null || v === simple.value)
    }
    case 'pseudo':
      if (DYNAMIC.has(simple.name)) return state.dynamic
      if (simple.name === 'root') return el.tag === 'html'
      if (simple.name === 'not') return !simple.inner.parts[0].compound.every((s) => simpleMatches(el, s, state))
      if (simple.name === 'disabled') return el.props.disabled === true
      if (STRUCTURAL[simple.name]) return el.known ? STRUCTURAL[simple.name](el, simple.argument) : state.unknown
      throw new Error(`:${simple.name} is not modelled`)
    default:
      return false
  }
}

function matches(el, selector, state) {
  const { parts } = selector
  if (parts[parts.length - 1].compound.some((s) => s.kind === 'element')) return false
  const from = (node, j) => {
    if (!parts[j].compound.every((s) => simpleMatches(node, s, state))) return false
    if (j === 0) return true
    const joint = parts[j].combinator
    if (joint === '>') return Boolean(node.parent) && from(node.parent, j - 1)
    if (joint === ' ') {
      for (let p = node.parent; p; p = p.parent) if (from(p, j - 1)) return true
      return false
    }
    if (!node.known) return state.unknown
    const before = node.parent.children.slice(0, node.index)
    return joint === '+' ? before.length > 0 && from(before[before.length - 1], j - 1) : before.some((b) => from(b, j - 1))
  }
  return from(el, parts.length - 1)
}

// ---- the cascade: of the rules whose selectors match and whose conditions
// hold, the declaration with the highest importance, specificity and source
// order wins each longhand; inherited properties fall back to the parent

const REM = 16
function length(value) {
  const m = /^(-?\d*\.?\d+)(px|rem)?$/.exec(String(value).trim())
  if (!m || (!m[2] && Number(m[1]) !== 0)) throw new Error(`length "${value}" is not modelled`)
  return Number(m[1]) * (m[2] === 'rem' ? REM : 1)
}

function feature(source, width, state) {
  const m = /^\(\s*([-a-z]+)\s*:\s*([^)]+?)\s*\)$/.exec(source.trim())
  if (!m) throw new Error(`feature ${source} is not modelled`)
  if (m[1] === 'prefers-color-scheme') return m[2] === state.scheme
  if (m[1] === 'max-width') return width <= length(m[2])
  if (m[1] === 'min-width') return width >= length(m[2])
  throw new Error(`feature ${source} is not modelled`)
}

function containerOf(el, name, ctx) {
  for (let p = el.parent; p; p = p.parent) {
    const type = computed(p, 'container-type', ctx)
    if ((type === 'inline-size' || type === 'size') && (!name || computed(p, 'container-name', ctx).split(/\s+/).includes(name))) {
      if (!ctx.widths.has(p)) throw new Error(`${label(p)} is a container the box model does not size`)
      return p
    }
  }
  return null
}

function holds(condition, el, ctx) {
  const media = /^@media\s+([\s\S]+)$/.exec(condition)
  if (media) return splitTop(media[1], ',').some((query) => query.split(/\s+and\s+/).every((f) => feature(f, ctx.viewport, ctx.state)))
  const query = /^@container\s+(?:([-\w]+)\s+)?(\([\s\S]+\))$/.exec(condition)
  if (query) {
    const box = containerOf(el, query[1] || null, ctx)
    return Boolean(box) && query[2].split(/\s+and\s+/).every((f) => feature(f, ctx.widths.get(box), ctx.state))
  }
  throw new Error(`${condition} is not modelled`)
}

function longhands(property, value) {
  const v = splitTop(value, ' ')
  switch (property) {
    case 'overflow': return [['overflow-x', v[0]], ['overflow-y', v[1] ?? v[0]]]
    case 'gap': return [['row-gap', v[0]], ['column-gap', v[1] ?? v[0]]]
    case 'padding':
    case 'margin': return [[`${property}-right`, v[1] ?? v[0]], [`${property}-left`, v[3] ?? v[1] ?? v[0]]]
    case 'border':
    case 'border-left':
    case 'border-right': {
      const width = v.find((x) => /^-?\d*\.?\d+(px|rem)?$/.test(x)) ?? (v.includes('none') ? '0' : 'medium')
      return property === 'border' ? [['border-left-width', width], ['border-right-width', width]] : [[`${property}-width`, width]]
    }
    case 'border-width': return [['border-right-width', v[1] ?? v[0]], ['border-left-width', v[3] ?? v[1] ?? v[0]]]
    case 'container': {
      const [name, type] = value.split('/').map((x) => x.trim())
      return [['container-name', name], ['container-type', type ?? 'normal']]
    }
    default: return [[property, value]]
  }
}

const compare = (a, b) => {
  for (let k = 0; k < a.length; k++) if (a[k] !== b[k]) return a[k] - b[k]
  return 0
}

function cascade(el, ctx) {
  if (ctx.memo.has(el)) return ctx.memo.get(el)
  const won = new Map()
  for (const rule of RULES) {
    let best = null
    for (const selector of rule.selectors) if ((!best || compare(selector.specificity, best) > 0) && matches(el, selector, ctx.state)) best = selector.specificity
    if (!best || !rule.conditions.every((c) => holds(c, el, ctx))) continue
    rule.declarations.forEach((d, k) => {
      for (const [property, value] of longhands(d.property, d.value)) {
        const rank = [d.important ? 1 : 0, ...best, rule.order, k]
        if (!won.has(property) || compare(rank, won.get(property).rank) >= 0) won.set(property, { value, rank, rule })
      }
    })
  }
  ctx.memo.set(el, won)
  return won
}

const INHERITED = new Set(['white-space', 'overflow-wrap', 'visibility'])
const INITIAL = {
  'overflow-x': 'visible', 'white-space': 'normal', 'text-overflow': 'clip', 'overflow-wrap': 'normal', visibility: 'visible', display: 'inline',
  'container-type': 'normal', 'container-name': 'none', 'grid-template-columns': 'none', 'column-gap': 'normal', width: 'auto', 'max-width': 'none',
  'padding-left': '0', 'padding-right': '0', 'margin-left': '0', 'margin-right': '0', 'border-left-width': '0', 'border-right-width': '0',
}

function computed(el, property, ctx) {
  const value = cascade(el, ctx).get(property)?.value
  if (value === 'inherit' || ((value === undefined || value === 'unset') && INHERITED.has(property))) return el.parent ? computed(el.parent, property, ctx) : INITIAL[property]
  return value === undefined || value === 'initial' || value === 'unset' ? INITIAL[property] : value
}

// the rule a computed value came from, for a failure's message
function origin(el, property, ctx) {
  for (let p = el; p; p = INHERITED.has(property) ? p.parent : null) {
    const d = cascade(p, ctx).get(property)
    if (d) return `${d.rule.selectors.map((s) => s.source).join(', ')}${d.rule.conditions.length ? ` in ${d.rule.conditions.join(' ')}` : ''}${p === el ? '' : ` on ${label(p)}`}`
  }
  return 'the initial value'
}

// ---- the boxes at a viewport width, from this stylesheet: .app-shell's
// sidebar track, then down to the schedules list each box's max-width (an
// auto-margined one is centred), border and padding; the list's width is its
// container size. A schedule row's grid follows CSS Grid's sizing of an fr
// (a flexible track whose share would fall below its minimum keeps its
// minimum), each track floored to the browser's 1/64px layout unit, which is
// what the captured geometry shows. A track whose minimum is the content's
// (auto, min-content) is not modelled and fails loudly.

const unit = (x) => Math.floor(x * 64) / 64

function frame(list, viewport, state) {
  const ctx = { viewport, state, widths: new Map(), memo: new Map() }
  const boxes = []
  for (let el = list; el; el = el.parent) boxes.unshift(el)
  const shell = boxes.find((el) => classesOf(el).includes('app-shell'))
  const columns = splitTop(computed(shell, 'grid-template-columns', ctx), ' ')
  const sidebar = columns.length === 2 && columns[1] === 'minmax(0, 1fr)' ? length(columns[0]) : columns.join(' ') === '1fr' ? 0 : NaN
  if (Number.isNaN(sidebar)) throw new Error(`.app-shell columns "${columns.join(' ')}" are not modelled`)
  let left = sidebar
  let width = viewport - sidebar
  for (const el of boxes.slice(boxes.indexOf(shell) + 1)) {
    const value = (property) => computed(el, property, ctx)
    if (value('width') !== 'auto') throw new Error(`${label(el)}: width ${value('width')} is not modelled`)
    const max = value('max-width')
    const used = max === 'none' ? width : Math.min(width, length(max))
    const margins = [value('margin-left'), value('margin-right')]
    if (margins.every((m) => m === 'auto')) left += (width - used) / 2
    else if (!margins.every((m) => length(m) === 0)) throw new Error(`${label(el)}: margins ${margins.join(' ')} are not modelled`)
    const inset = (side) => length(value(`border-${side}-width`)) + length(value(`padding-${side}`))
    left += inset('left')
    width = used - inset('left') - inset('right')
  }
  ctx.widths.set(list, width)
  return { ctx, left, width }
}

function track(token) {
  const m = /^minmax\((.+),\s*(\d*\.?\d+)fr\)$/.exec(token)
  if (m) return { min: length(m[1].trim()), flex: Number(m[2]) }
  if (/fr$|auto|content/.test(token)) throw new Error(`grid track ${token}: a content-sized minimum is not modelled`)
  return { min: length(token), flex: 0 }
}

function trackSizes(tracks, free) {
  const flexible = tracks.map((t) => t.flex > 0)
  for (;;) {
    const fixed = tracks.reduce((s, t, k) => s + (flexible[k] ? 0 : t.min), 0)
    const factors = Math.max(1, tracks.reduce((s, t, k) => s + (flexible[k] ? t.flex : 0), 0))
    const fr = Math.max(0, free - fixed) / factors
    const under = tracks.findIndex((t, k) => flexible[k] && t.flex * fr < t.min)
    if (under < 0) return tracks.map((t, k) => (flexible[k] ? t.flex * fr : t.min))
    flexible[under] = false
  }
}

function grid(row, box, ctx) {
  const tracks = splitTop(computed(row, 'grid-template-columns', ctx), ' ').map(track)
  const gapValue = computed(row, 'column-gap', ctx)
  const gap = gapValue === 'normal' ? 0 : length(gapValue)
  const pad = { left: length(computed(row, 'padding-left', ctx)), right: length(computed(row, 'padding-right', ctx)) }
  const gaps = gap * (tracks.length - 1)
  const needs = tracks.reduce((s, t) => s + t.min, 0) + gaps + pad.left + pad.right
  const sizes = trackSizes(tracks, box.width - pad.left - pad.right - gaps).map(unit)
  const lefts = []
  let x = box.left + pad.left
  for (const size of sizes) {
    lefts.push(x)
    x += size + gap
  }
  return { tracks, needs, sizes, lefts }
}

const WRAPS = new Set(['normal', 'pre-wrap', 'pre-line', 'break-spaces'])

// a schedule row's open run at a viewport width in a state: its line (the
// button's parent), the cell holding it, the panel's frame and the row's grid
function inspect(panel, index, viewport, state) {
  const [list] = below(panel, (el) => classesOf(el).includes('ci-list'))
  const box = frame(list, viewport, state)
  const row = below(panel, (el) => el.props['data-part'] === 'schedule-row')[index]
  const [button] = below(row, (el) => el.props['data-part'] === 'open-run')
  const cell = row.children.find((c) => below(c, (el) => el === button).length > 0)
  const g = grid(row, box, box.ctx)
  const column = row.children.indexOf(cell) % g.sizes.length
  const line = button.parent
  let clips = false
  for (let el = line; el !== row.parent; el = el.parent) if (computed(el, 'overflow-x', box.ctx) !== 'visible') clips = true
  return {
    ctx: box.ctx, box, row, line, button, grid: g, clips,
    cell: { left: g.lefts[column], width: g.sizes[column], right: g.lefts[column] + g.sizes[column] },
    wraps: WRAPS.has(computed(line, 'white-space', box.ctx)),
  }
}

// where the open run lands in its line, by CSS inline layout: a line that may
// wrap puts the button (an atomic inline narrower than the line, after a
// space) on a new line when the text before it leaves no room, so all of it
// lies in the box; a line that may not puts it after all the text before it
// (393.296875px of it in the capture), and a clipping or scrolling box shows
// only what lies inside its edge
function placement(wraps, clips, width) {
  if (wraps) return BUTTON <= width ? { visible: BUTTON, inside: true, at: 'its own place on a wrapped line' } : { visible: clips ? width : BUTTON, inside: false, at: `a line ${width}px wide` }
  const right = TEXT_BEFORE + BUTTON
  return { visible: clips ? Math.max(0, Math.min(right, width) - TEXT_BEFORE) : BUTTON, inside: right <= width, at: `x ${TEXT_BEFORE} to ${right} of a ${width}px box` }
}

// why a row's open run could be out of sight or out of the keyboard's reach:
// a box around it that clips, scrolls or is not displayed; a line that cannot
// wrap or truncates; a button the keyboard skips
function obstacles(panel, index, viewport, state) {
  const s = inspect(panel, index, viewport, state)
  const found = []
  for (let el = s.line; el; el = el.parent) {
    const overflow = computed(el, 'overflow-x', s.ctx)
    if (overflow !== 'visible') found.push(`${label(el)} has overflow-x ${overflow} (${origin(el, 'overflow-x', s.ctx)})`)
    if (computed(el, 'display', s.ctx) === 'none') found.push(`${label(el)} is not displayed (${origin(el, 'display', s.ctx)})`)
    for (const attr of ['hidden', 'inert', 'aria-hidden']) if (el.props[attr]) found.push(`${label(el)} is ${attr}`)
  }
  if (computed(s.button, 'visibility', s.ctx) === 'hidden') found.push(`the open run is visibility hidden (${origin(s.button, 'visibility', s.ctx)})`)
  const whiteSpace = computed(s.line, 'white-space', s.ctx)
  if (!WRAPS.has(whiteSpace)) found.push(`the last-occurrence line has white-space ${whiteSpace} (${origin(s.line, 'white-space', s.ctx)}): the open run cannot start a new line`)
  if (computed(s.line, 'text-overflow', s.ctx) === 'ellipsis') found.push(`the last-occurrence line truncates with an ellipsis (${origin(s.line, 'text-overflow', s.ctx)})`)
  const { props } = s.button
  if (props.disabled || Number(props.tabIndex) < 0 || props['aria-hidden']) found.push('the keyboard skips the open run')
  const kids = s.line.node.children
  const before = kids.slice(0, kids.indexOf(s.button.node))
  if (before.length && !/\s$/.test(typeof before[before.length - 1] === 'string' ? before[before.length - 1] : '')) found.push('no space before the open run lets it start a new line')
  return found
}

const STATES = [
  { name: 'ordinary', dynamic: false, unknown: false, scheme: 'light' },
  { name: 'hovered, focused, dark, unknown sibling facts true', dynamic: true, unknown: true, scheme: 'dark' },
]
const WIDTHS = [320, 360, 390, 414, 600, 720, 760, 761, 800, 900, 1024, 1123, 1124, 1280, 1360, 1440, 1600, 1920, 2560]

// every distinct finding, with how many of the width × state cases show it
function survey(cases, look) {
  const seen = new Map()
  for (const c of cases) for (const finding of look(c)) seen.set(finding, [...(seen.get(finding) || []), c.where])
  return [...seen].map(([finding, where]) => `${finding} (at ${where.length} of ${cases.length}: ${where.slice(0, 4).join('; ')}${where.length > 4 ? '; …' : ''})`)
}
const everyCase = WIDTHS.flatMap((viewport) => STATES.map((state) => ({ viewport, state, where: `${viewport}px ${state.name === 'ordinary' ? 'ordinary' : 'extreme'}` })))

test('the captured retired schedule renders exactly the text the browser read, with one open run for its retained run', () => {
  const { tree, opened } = rendered(retired)
  const rows = parts(tree, 'schedule-row')
  assert.equal(rows.length, 1)
  assert.equal(text(rows[0]), CAPTURED_TEXT.split('\n').map((line) => (line === 'RETIRED' ? 'retired' : line)).join(''))
  const status = all(rows[0], (n) => /\bstatus\b/.test(n.props?.className || ''))
  assert.deepEqual(status.map(text), ['retired'], 'the status badge holds the state alone')
  const buttons = parts(rows[0], 'open-run')
  assert.equal(buttons.length, 1)
  const [button] = buttons
  assert.equal(button.type, 'button')
  assert.equal(button.props.type, 'button')
  assert.equal(text(button), 'open run')
  assert.equal(button.props.href, undefined, 'the open run is the existing button, not a manufactured route')
  button.props.onClick()
  assert.deepEqual(opened, [RUN])
})

test('no box around the captured open run clips, scrolls or hides it, and its line wraps instead of truncating, at every modelled width and state', () => {
  const { panel } = rendered(retired)
  assert.deepEqual(survey(everyCase, (c) => obstacles(panel, 0, c.viewport, c.state)), [])
})

test('the box model puts the captured cell where the browser did; with this stylesheet the open run lies wholly inside that line', (t) => {
  // the capture itself: the button began past its parent's visible right edge
  assert.ok(CAPTURED.buttonLeft > CAPTURED.parentRight)
  assert.equal(Math.ceil(TEXT_BEFORE + BUTTON), CAPTURED.scrollWidth)
  assert.equal(Math.floor(CAPTURED.parentWidth), CAPTURED.clientWidth)
  const { panel } = rendered(retired)
  const s = inspect(panel, 0, CAPTURED.viewport, STATES[0])
  t.diagnostic(`modelled at ${CAPTURED.viewport}px: cell x ${s.cell.left}..${s.cell.right} (width ${s.cell.width}); line wraps: ${s.wraps}; a box clips: ${s.clips}`)
  assert.equal(s.cell.left, CAPTURED.parentLeft)
  assert.equal(s.cell.width, CAPTURED.parentWidth)
  assert.equal(s.cell.right, CAPTURED.parentRight)
  const p = placement(s.wraps, s.clips, s.cell.width)
  assert.equal(p.visible, BUTTON, `${p.visible}px of the ${BUTTON}px open run is visible: it lands at ${p.at}${s.clips ? ' in a box that clips' : ''}`)
  assert.equal(p.inside, true, `the open run lands outside its line: ${p.at}`)
})

test('at every modelled width, from a 320px phone to 2560px, the schedule row fits its panel and the open run\'s cell lies inside the panel and the viewport', (t) => {
  const { panel } = rendered(retired)
  // the modelled boxes, for the record (a model, not a measurement)
  for (const viewport of WIDTHS) {
    const s = inspect(panel, 0, viewport, STATES[0])
    t.diagnostic(`${viewport}px: panel x ${s.box.left}..${s.box.left + s.box.width}; row needs ${s.grid.needs}px in ${s.grid.tracks.length} track(s); open run's cell x ${s.cell.left}..${s.cell.right}`)
  }
  assert.deepEqual(survey(everyCase, ({ viewport, state }) => {
    const s = inspect(panel, 0, viewport, state)
    const found = []
    if (s.grid.needs > s.box.width + 1e-9) found.push(`the schedule row needs ${s.grid.needs}px in ${s.grid.tracks.length} track(s), more than its panel`)
    if (s.cell.left < s.box.left - 1e-9 || s.cell.right > s.box.left + s.box.width + 1e-9) found.push('the open run\'s cell leaves the panel')
    if (s.cell.right > viewport + 1e-9) found.push('the open run\'s cell ends past the viewport')
    if (s.cell.width < BUTTON) found.push(`the open run's cell is narrower than the ${BUTTON}px button`)
    return found
  }), [])
})

test('long titles, crons, zones, reasons and late admissions keep every word in its case; each open run stays the one unclipped control of its row, and other metadata keeps its truncation', () => {
  const { tree, opened, panel } = rendered(longActive, longRefused)
  const rows = parts(tree, 'schedule-row')
  for (const [k, schedule] of [longActive, longRefused].entries()) {
    const shown = text(rows[k])
    const words = [schedule.name, `${schedule.workflow} #${schedule.index}`, schedule.cron, ZONE, schedule.reason, `last due ${LONG_DUE.local}`, `admitted ${schedule.lastAdmitted.at.local} (late by 13h 45m)`,
      '14 occurrences missed, 2026-10-03 06:00 UTC-03:00 to 2026-10-15 06:00 UTC-03:00: not run', '3 stale wakes ignored', 'promoted by ~nec · baseline f3570bc7 · lock 8f07807a · from master'].filter(Boolean)
    for (const word of words) assert.ok(shown.includes(word), `row ${k} shows "${word}" as written`)
    if (schedule.next) assert.equal(text(part(rows[k], 'schedule-next')), `next ${schedule.next.local} · ${schedule.next.utc}`)
    const buttons = parts(rows[k], 'open-run')
    assert.equal(buttons.length, 1, `row ${k} has one open run`)
    buttons[0].props.onClick()
    assert.equal(opened[k], schedule.lastAdmitted.run)
    const cases = [320, 390, 800, 1360, 1920].flatMap((viewport) => STATES.map((state) => ({ viewport, state, where: `${viewport}px ${state.name === 'ordinary' ? 'ordinary' : 'extreme'}` })))
    assert.deepEqual(survey(cases, (c) => obstacles(panel, k, c.viewport, c.state)), [], `row ${k}`)
    // the row's grid has no content-sized track, so no long value moves the cell
    for (const viewport of [390, 1360]) assert.ok(inspect(panel, k, viewport, STATES[0]).grid.tracks.every((t) => Number.isFinite(t.min)))
  }
  // the cron and zone, reasons, missed and stale-wake lines are still ci-job-meta, truncating
  const { ctx } = frame(below(panel, (el) => classesOf(el).includes('ci-list'))[0], 1360, STATES[0])
  const meta = below(panel, (el) => classesOf(el).includes('ci-job-meta'))
  assert.equal(meta.length, 7)
  for (const el of meta) assert.deepEqual(['white-space', 'overflow-x', 'text-overflow'].map((p) => computed(el, p, ctx)), ['nowrap', 'hidden', 'ellipsis'], label(el))
  assert.equal(below(panel, (el) => el.props['data-part'] === 'schedule-last').every((el) => !classesOf(el).includes('ci-job-meta')), true)
})

test('a schedule with no last admission, or one without a run, shows its last due and admission but no open run, and invents no target', () => {
  const admitted = 'last due 2026-10-16 20:55 UTC · admitted 2026-10-16 20:55 UTC (on time) '
  const cases = [
    ['due, never admitted', { ...retired, lastAdmitted: null }, 'last due 2026-10-16 20:55 UTC'],
    ['admitted with an empty run', { ...retired, lastAdmitted: { ...retired.lastAdmitted, run: '' } }, admitted],
    ['admitted with a null run', { ...retired, lastAdmitted: { ...retired.lastAdmitted, run: null } }, admitted],
    ['admitted with no run field', { ...retired, lastAdmitted: { due: DUE, at: DUE, late: false, lateSeconds: 0 } }, admitted],
  ]
  for (const [name, schedule, last] of cases) {
    const { tree, opened } = rendered(schedule)
    assert.equal(text(part(tree, 'schedule-last')), last, name)
    assert.equal(parts(tree, 'open-run').length, 0, `${name}: an open run with no run to open`)
    assert.deepEqual(all(tree, (n) => n.type === 'button').map((b) => b.props['data-part']), ['schedules-refresh-button'], `${name}: the panel's one control is Refresh`)
    assert.equal(all(tree, (n) => n.type === 'a').length, 0, `${name}: no link`)
    assert.deepEqual(opened, [])
  }
  const { tree } = rendered({ ...retired, lastDue: null, lastAdmitted: null })
  assert.equal(part(tree, 'schedule-last'), null, 'neither due nor admitted: no last line')
  assert.equal(parts(tree, 'open-run').length, 0)
})

test('the Schedules panel hands the retained run id to the CI tab\'s own opener, which opens that candidate', async () => {
  const rt = hooksRuntime()
  const names = []
  const ship = { schedules: async (name) => { names.push(name); return answer(retired) } }
  const opened = []
  rt.mount(makeSchedules(rt.React, { ci: ship }), { repo: { name: 'wf1c-schedule-reload' }, onOpenRun: (id) => opened.push(id) })
  await settle()
  part(rt.tree(), 'open-run').props.onClick()
  await settle()
  assert.deepEqual(opened, [RUN])
  assert.deepEqual(names, ['wf1c-schedule-reload'], 'opening the run read nothing more from the ship')
  rt.unmount()
  // STATIC: the opener is the CI tab's own candidate state, as before
  const tab = readFileSync(new URL('./components/CiTab.jsx', import.meta.url), 'utf8')
  assert.equal(tab.split('<Schedules repo={repo} onOpenRun={setOpen} />').length - 1, 1)
  assert.match(tab, /const \[open, setOpen\] = useState\(''\)/)
  assert.match(tab, /\? <CandidatePage id=\{open\} /)
})

// what React escapes in text and attributes
const escape = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#x27;')
function markup(node) {
  if (typeof node === 'string' || typeof node === 'number') return escape(node)
  const attributes = Object.entries(node.props)
    .filter(([k, v]) => k !== 'key' && typeof v !== 'function' && v !== false && v !== null && v !== undefined)
    .map(([k, v]) => ` ${k === 'className' ? 'class' : k}="${v === true ? '' : escape(v)}"`).join('')
  return `<${node.type}${attributes}>${node.children.map(markup).join('')}</${node.type}>`
}

test('React\'s server render of the schedules panel is the markup these checks read', { skip }, () => {
  const { React, renderToStaticMarkup } = deps
  const model = scheduleModel(answer(retired, longActive, longRefused, { ...retired, index: 1, lastAdmitted: null }))
  const actions = { refresh: noop, retry: noop, openRun: noop }
  const html = renderToStaticMarkup(renderSchedules(React.createElement, { phase: 'ready', error: '', model }, actions))
  assert.equal(html, markup(renderSchedules(h, { phase: 'ready', error: '', model }, actions)))
  assert.ok(html.includes('<div class="ci-list ci-schedule-list">'))
  assert.ok(html.includes('<small class="quiet ci-schedule-last" data-part="schedule-last">last due 2026-10-16 20:55 UTC · admitted 2026-10-16 20:55 UTC (on time) <button type="button" class="text-button" data-part="open-run">open run</button></small>'))
})
