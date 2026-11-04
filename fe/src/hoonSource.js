// Structural, fail-closed readers of the desk's Hoon for the source-pattern
// tests. Every decision reads code only: one lexer sets comments, cords and
// tapes apart, so their text is never a header, a core's end, a dispatch case
// or a guard. A test names an arm by its enclosing arm chain, a type by its
// name and a library by its import, and every reader throws when that arm,
// type or import is missing, ambiguous or written in a form it does not read.
// A binding is read from the switch a |^ core actually runs, case by case in
// order, never from a matching line anywhere in the owner's nested code; a
// route is followed hop by hop from handle-api; a guard counts only as the
// first thing its arm asserts. gaps() is the layout-free view for the patterns
// that span lines: Hoon reads every gap alike, so indentation, gap width and
// comment lines are not part of a pattern there, while aces, cords and tapes
// are kept byte for byte.
import { existsSync, readFileSync } from 'node:fs'

const DESK = new URL('../../desk/', import.meta.url)
const CODE = 0
const COMMENT = 1
const LITERAL = 2

export const deskText = (rel, root = DESK) => readFileSync(new URL(rel, root), 'utf8')

// where the cord or tape opened at i ends (the index after its closing
// quote); a one-line literal may not run past its line, and a ''' or """
// block opens only at the end of a line
function literalEnd(text, i) {
  const quote = text[i]
  const what = quote === "'" ? 'cord' : 'tape'
  if (text.startsWith(`${quote.repeat(3)}\n`, i)) {
    const end = text.indexOf(quote.repeat(3), i + 4)
    if (end < 0) throw new Error(`unterminated ${what} block at ${i}`)
    return end + 3
  }
  for (let j = i + 1; j < text.length;) {
    const c = text[j]
    if (c === '\n') break
    if (c === '\\') {
      j += 2
    } else if (c === quote) {
      return j + 1
    } else if (quote === '"' && c === '{') {
      j = interpolationEnd(text, j)
    } else {
      j += 1
    }
  }
  throw new Error(`unterminated ${what} at ${i}`)
}

// the index after the } that closes a tape's interpolation opened at i
function interpolationEnd(text, i) {
  let depth = 0
  for (let j = i; j < text.length;) {
    const c = text[j]
    if (c === '\n') break
    if (c === "'" || c === '"') {
      j = literalEnd(text, j)
      continue
    }
    if (c === '{') depth += 1
    if (c === '}') {
      depth -= 1
      if (depth === 0) return j + 1
    }
    j += 1
  }
  throw new Error(`unterminated tape interpolation at ${i}`)
}

const lexed = new Map()

// each character's class (code, a comment from :: to its line's end, or a
// literal: a cord or tape with its quotes, escapes and interpolations), and
// where each literal starts
function lex(text) {
  if (lexed.has(text)) return lexed.get(text)
  const kinds = new Uint8Array(text.length)
  const starts = new Set()
  for (let i = 0; i < text.length;) {
    const c = text[i]
    if (c === "'" || c === '"') {
      const end = literalEnd(text, i)
      kinds.fill(LITERAL, i, end)
      starts.add(i)
      i = end
    } else if (c === ':' && text[i + 1] === ':') {
      const eol = text.indexOf('\n', i)
      const end = eol < 0 ? text.length : eol
      kinds.fill(COMMENT, i, end)
      i = end
    } else {
      i += 1
    }
  }
  if (lexed.size > 64) lexed.clear()
  lexed.set(text, { kinds, starts })
  return lexed.get(text)
}

const lined = new Map()

// the text's lines: each one's start, indentation, and whether it is code,
// i.e. its first visible character is neither in a comment nor inside a
// literal that began on an earlier line
function linesOf(text) {
  if (lined.has(text)) return lined.get(text)
  const { kinds, starts } = lex(text)
  const lines = []
  let start = 0
  for (const line of text.split('\n')) {
    const indent = line.length - line.trimStart().length
    const at = start + indent
    const code = indent < line.length && (kinds[at] === CODE || (kinds[at] === LITERAL && starts.has(at)))
    lines.push({ text: line, start, indent, code })
    start += line.length + 1
  }
  if (lined.size > 64) lined.clear()
  lined.set(text, lines)
  return lines
}

// what a code line opens with: a core member (++ arm, +$ type, +* alias,
// +| chapter) or -- (a core's end); any other two-character + rune there is
// refused
function memberOf(line) {
  if (!line.code) return null
  const t = line.text.slice(line.indent)
  if (/^--(\s|$)/.test(t)) return { kind: 'end' }
  const m = /^\+([+$*|]) {2}(\S+)/.exec(t)
  if (m) return { kind: { '+': 'arm', $: 'type', '*': 'alias', '|': 'chapter' }[m[1]], name: m[2] }
  if (/^\+[^\w\s([]\s/.test(t)) throw new Error(`a core member this reader does not read: ${t.slice(0, 24)}`)
  return null
}

// the ++ arms enclosing line i (0-based), outermost first: walking up, each
// arm shallower than the last one found encloses it, and a core's end
// shallower than that ends the walk
function chainAt(lines, i) {
  const out = []
  let indent = Infinity
  for (let k = i; k >= 0; k -= 1) {
    const line = lines[k]
    if (!line.code || line.indent >= indent) continue
    const member = memberOf(line)
    if (member?.kind === 'end') break
    if (member?.kind === 'arm') {
      out.unshift(member.name)
      indent = line.indent
      if (indent === 0) break
    }
  }
  return out
}

export const enclosingArms = (text, i) => chainAt(linesOf(text), i)

// the line after the member at line i: the next member or core end at the
// same or a shallower indentation; code shallower than the member before
// either is refused
function spanEnd(lines, i) {
  const indent = lines[i].indent
  for (let j = i + 1; j < lines.length; j += 1) {
    const line = lines[j]
    if (!line.code || line.indent > indent) continue
    if (memberOf(line)) return j
    if (line.indent < indent) throw new Error(`the member at line ${i + 1} runs into code at line ${j + 1} before its core ends`)
  }
  return lines.length
}

const spanText = (lines, i) => lines.slice(i, spanEnd(lines, i)).map((line) => line.text).join('\n')

function armLine(lines, chain) {
  const name = chain.split('/').at(-1)
  const found = []
  lines.forEach((line, i) => {
    const member = memberOf(line)
    if (member?.kind === 'arm' && member.name === name && chainAt(lines, i).join('/') === chain) found.push(i)
  })
  if (found.length !== 1) throw new Error(`${found.length ? 'ambiguous' : 'missing'} arm ${chain}`)
  return found[0]
}

// the ++ arm whose enclosing chain is exactly `chain`, e.g.
// 'on-poke/handle-action/set-ref': its header to its span's end
export function arm(text, chain) {
  const lines = linesOf(text)
  return spanText(lines, armLine(lines, chain))
}

// every ++ arm named `name`, at any depth: what an absence check reads
export function armsNamed(text, name) {
  const lines = linesOf(text)
  return lines.flatMap((line, i) => {
    const member = memberOf(line)
    return member?.kind === 'arm' && member.name === name ? [spanText(lines, i)] : []
  })
}

// the column-0 +$ type `name`
export function type(text, name) {
  const lines = linesOf(text)
  const found = lines.flatMap((line, i) => {
    const member = memberOf(line)
    return member?.kind === 'type' && member.name === name && line.indent === 0 ? [i] : []
  })
  if (found.length !== 1) throw new Error(`${found.length ? 'ambiguous' : 'missing'} type ${name}`)
  return spanText(lines, found[0])
}

// the words of text[from, to): a gap is any run of whitespace and comments
// other than one space, and a word keeps its aces, cords and tapes
function wordsIn(text, from, to) {
  const { kinds } = lex(text)
  const blank = (k) => kinds[k] === COMMENT || (kinds[k] === CODE && /\s/.test(text[k]))
  const words = []
  let word = ''
  for (let i = from; i < to;) {
    if (!blank(i)) {
      word += text[i]
      i += 1
      continue
    }
    let j = i
    let gap = false
    for (; j < to && blank(j); j += 1) if (kinds[j] === COMMENT || text[j] !== ' ') gap = true
    if (gap || j - i > 1) {
      if (word) words.push(word)
      word = ''
    } else if (word) {
      word += ' '
    }
    i = j
  }
  if (word) words.push(word)
  return words
}

// layout-free Hoon: outside cords and tapes, every run of whitespace and ::
// comments other than a single space becomes two spaces (a gap); a single
// space (an ace) stays one. Cords and tapes are copied unchanged
export function gaps(text) {
  return wordsIn(text, 0, text.length).join('  ')
}

const RUNE = /^[!-/:-@[-`{-~]{2}$/
// the tall runes a dispatching expression may be built from, by arity
const ARITY = { '?:': 3, '?.': 3, '?>': 2, '?<': 2 }

const wideAt = (words, i) => {
  const w = words[i]
  if (w === undefined || (RUNE.test(w) && w !== '!!' && !/^['"]/.test(w))) {
    throw new Error(`${w ?? 'nothing'} where a wide expression belongs: a form this reader does not read`)
  }
  return w
}

// one expression from the words at i: a switch (?- or ?+), one of the tall
// runes above, or a wide expression; any other rune is refused
function expressionAt(words, i) {
  const w = words[i]
  if (w === '?-' || w === '?+') {
    const subject = wideAt(words, i + 1)
    let j = i + 2
    let fallback = null
    if (w === '?+') [fallback, j] = expressionAt(words, j)
    const cases = []
    while (words[j] !== '==') {
      if (words[j] === undefined) throw new Error(`a ${w} without its ==`)
      const pattern = wideAt(words, j)
      const [value, next] = expressionAt(words, j + 1)
      cases.push({ pattern, value })
      j = next
    }
    return [{ rune: w, subject, fallback, cases }, j + 1]
  }
  if (ARITY[w]) {
    const kids = []
    let j = i + 1
    for (let k = 0; k < ARITY[w]; k += 1) {
      const [kid, next] = expressionAt(words, j)
      kids.push(kid)
      j = next
    }
    return [{ rune: w, kids }, j]
  }
  return [{ wide: wideAt(words, i) }, i + 1]
}

// the words must be exactly one ?- or ?+ switch
function switchIn(words) {
  const [node, next] = expressionAt(words, 0)
  if (next !== words.length) throw new Error('more than one expression where one switch belongs')
  if (!node.cases) throw new Error('the dispatching expression is not a ?- or ?+ switch')
  return node
}

// a case's pattern as a mold over nouns: * any noun, @ any atom, ^ any cell,
// ~ or %term or %'cord' one atom, [a b ...] a cell; nothing else is read
function moldOf(text) {
  let i = 0
  const refuse = () => new Error(`a pattern this reader does not read: ${text}`)
  const item = () => {
    if (text[i] === '[') {
      i += 1
      const items = [item()]
      while (text[i] === ' ') {
        i += 1
        items.push(item())
      }
      if (text[i] !== ']') throw refuse()
      i += 1
      return items.reduceRight((tail, head) => (tail ? { cell: [head, tail] } : head), null)
    }
    if (text.startsWith("%'", i)) {
      const end = text.indexOf("'", i + 2)
      if (end < 0 || text.slice(i + 2, end).includes('\\')) throw refuse()
      const atom = text.slice(i + 2, end)
      i = end + 1
      return { atom }
    }
    const m = /^(?:%[a-z][a-z0-9-]*|\*|@|\^|~)/.exec(text.slice(i))
    if (!m) throw refuse()
    i += m[0].length
    if (m[0] === '*') return { any: true }
    if (m[0] === '@') return { atom: null }
    if (m[0] === '^') return { cell: null }
    return { atom: m[0] === '~' ? '' : m[0].slice(1) }
  }
  const mold = item()
  if (i !== text.length) throw refuse()
  return mold
}

const isAtom = (m) => 'atom' in m
const isCell = (m) => 'cell' in m

// some noun fits both molds
function overlaps(a, b) {
  if (a.any || b.any) return true
  if (isAtom(a) && isAtom(b)) return a.atom === null || b.atom === null || a.atom === b.atom
  if (isCell(a) && isCell(b)) return !a.cell || !b.cell || (overlaps(a.cell[0], b.cell[0]) && overlaps(a.cell[1], b.cell[1]))
  return false
}

// every noun that fits b fits a
function covers(a, b) {
  if (a.any) return true
  if (b.any) return false
  if (isAtom(a)) return isAtom(b) && (a.atom === null || a.atom === b.atom)
  return isCell(b) && (!a.cell || (!!b.cell && covers(a.cell[0], b.cell[0]) && covers(a.cell[1], b.cell[1])))
}

function slag(mold, n, text) {
  let rest = mold
  for (let k = 0; k < n; k += 1) {
    if (!isCell(rest) || !rest.cell) throw new Error(`${text} runs past the end of the request's path`)
    rest = rest.cell[1]
  }
  return rest
}

// what a switch is given for a request, by the subject it switches on
function given(subject, request) {
  if ((subject === '-.act' || subject === 'tag.act') && request.tag !== undefined) return { atom: request.tag }
  if (subject === 'wire' && request.wire) return request.wire
  let m = /^\(slag (\d+) site\)$/.exec(subject)
  if (m && request.site) return slag(request.site, Number(m[1]), subject)
  m = /^\[method \(slag (\d+) site\)\]$/.exec(subject)
  if (m && request.site) return { cell: [{ atom: request.method }, slag(request.site, Number(m[1]), subject)] }
  throw new Error(`a switch on ${subject}, which this reader does not read for this request`)
}

// the branch a switch takes for every noun it can be given: the first case
// that fits any of them must take them all, and a ?+ falls back when none fits
function branchFor(sw, input) {
  for (const { pattern, value } of sw.cases) {
    const mold = moldOf(pattern)
    if (!overlaps(mold, input)) continue
    if (!covers(mold, input)) throw new Error(`case ${pattern} takes only part of what the switch is given`)
    return value
  }
  if (sw.rune === '?+') return sw.fallback
  throw new Error('no case of the ?- takes what it is given')
}

// the arm a branch names: a bare name, or a choice between two on the
// request's method; null when the branch is not an arm
function armNamed(value, request) {
  if (value.wide && /^[a-z][a-z0-9-]*$/.test(value.wide)) return value.wide
  if (value.rune === '?:' && request.method !== undefined) {
    const test = /^=\((?:method %'([A-Z]+)'|%'([A-Z]+)' method)\)$/.exec(value.kids[0].wide ?? '')
    if (test) return armNamed(value.kids[(test[1] ?? test[2]) === request.method ? 1 : 2], request)
  }
  return null
}

// the |^ core whose arms include the arm at line `at`: the line of its |^,
// its first arm, its arms' names and its end; refused when the arm is in any
// other kind of core or the core's shape is not this
function barketOf(lines, at) {
  const indent = lines[at].indent
  const who = memberOf(lines[at]).name
  let first = at
  let opener = -1
  for (let j = at - 1; j >= 0; j -= 1) {
    const line = lines[j]
    if (!line.code || line.indent > indent) continue
    if (line.indent < indent) break
    const member = memberOf(line)
    if (member?.kind === 'arm') {
      first = j
      continue
    }
    if (member) throw new Error(`++${who} is not in a |^ core: a ${member.kind} stands at its column`)
    const t = line.text.slice(line.indent)
    if (/^\|\^(\s|$)/.test(t)) {
      opener = j
      break
    }
    if (/^\|[%_@](\s|$)/.test(t)) throw new Error(`++${who} is in a ${t.slice(0, 2)} core, not a |^ core`)
  }
  if (opener < 0) throw new Error(`no |^ core holds ++${who}`)
  const arms = []
  for (let j = first; j < lines.length; j += 1) {
    const line = lines[j]
    if (!line.code || line.indent > indent) continue
    if (line.indent < indent) break
    const member = memberOf(line)
    if (member?.kind === 'end') return { opener, first, arms }
    if (member?.kind !== 'arm') throw new Error(`the |^ core holding ++${who} has ${member ? `a ${member.kind}` : 'code'} among its arms`)
    arms.push(member.name)
  }
  throw new Error(`the |^ core holding ++${who} has no --`)
}

// the switch a |^ core runs: its body, from after the |^ to its first arm
function coreSwitch(text, lines, core) {
  const open = lines[core.opener]
  return switchIn(wordsIn(text, open.start + open.indent + 2, lines[core.first].start))
}

// the |^ core an arm holds, found through its arms; null when it holds none,
// refused when its arms are in more than one core
function heldCore(lines, at, chain) {
  const end = spanEnd(lines, at)
  let core = null
  for (let i = at + 1; i < end; i += 1) {
    const member = memberOf(lines[i])
    if (member?.kind !== 'arm' || chainAt(lines, i).join('/') !== `${chain}/${member.name}`) continue
    const found = barketOf(lines, i)
    if (core && found.opener !== core.opener) throw new Error(`++${chain.split('/').at(-1)} holds more than one core`)
    core = found
  }
  if (core && chainAt(lines, core.opener).join('/') !== chain) throw new Error(`the |^ core in ++${chain} is not its own`)
  return core
}

// a request followed from the arm `chain` hop by hop: each hop's switch is
// the body of the |^ core the arm holds (its names are that core's arms), or
// else the arm's own body (its names are the arm's siblings); returns the line
// of the arm `goal`, or throws
function follow(text, lines, chain, request, goal) {
  let path = chain.split('/')
  for (let hop = 0; hop < 8; hop += 1) {
    const at = armLine(lines, path.join('/'))
    const core = heldCore(lines, at, path.join('/'))
    let sw
    let scope
    let base
    try {
      if (core) {
        sw = coreSwitch(text, lines, core)
        scope = core.arms
        base = path
      } else {
        const line = lines[at]
        const end = spanEnd(lines, at)
        sw = switchIn(wordsIn(text, line.start + line.indent + 4 + memberOf(line).name.length, end < lines.length ? lines[end].start : text.length))
        scope = barketOf(lines, at).arms
        base = path.slice(0, -1)
      }
    } catch (e) {
      throw new Error(`the request reaches ++${path.at(-1)}, which dispatches no further (${e.message})`)
    }
    const name = armNamed(branchFor(sw, given(sw.subject, request)), request)
    if (!name || !scope.includes(name)) throw new Error(`++${path.at(-1)} does not dispatch the request to an arm of its core`)
    path = [...base, name]
    if (path.join('/') === goal) return armLine(lines, goal)
  }
  throw new Error(`no route to ${goal} within eight hops`)
}

// the guard an arm asserts first, after its result cast: a tag
// (?=(%tag -.act)), a wire (?=([...] wire)) or a route
// (?&  =(%'METHOD' method)  ?=([%apps ...] site)  ==); null when its first
// expression is anything else
export function entryGuard(armText) {
  const words = wordsIn(armText, 0, armText.length)
  if (words[0] !== '++') throw new Error('entryGuard reads an arm')
  let i = 2
  if (words[i] === '^-') i += 2
  if (words[i] !== '?>') return null
  const first = words[i + 1] ?? ''
  let m = /^\?=\(%([a-z][a-z0-9-]*) (?:-|tag)\.act\)$/.exec(first)
  if (m) return { tag: m[1] }
  m = /^\?=\((\[[^'"]*\]) wire\)$/.exec(first)
  if (m) return { wire: m[1] }
  if (first === '?&' && words[i + 4] === '==') {
    const method = /^=\(%'([A-Z]+)' method\)$/.exec(words[i + 2] ?? '')
    const site = /^\?=\((\[%apps [^'"]*\]) site\)$/.exec(words[i + 3] ?? '')
    if (method && site) return { method: method[1], path: site[1] }
  }
  return null
}

// a binding check's failure, said as the binding it refuses, with its reason
function refused(what, fn) {
  try {
    return fn()
  } catch (e) {
    throw new Error(`${what}: ${e.message}`)
  }
}

// %urgit's three dispatch shapes, each read from the switch that runs. An
// action is an arm of handle-action's |^ core that the core's switch sends
// the tag to
export function actionArm(agent, tag) {
  return refused(`handle-action does not dispatch %${tag} to ++${tag}`, () => {
    const lines = linesOf(agent)
    const at = armLine(lines, `on-poke/handle-action/${tag}`)
    const core = barketOf(lines, at)
    if (chainAt(lines, core.opener).join('/') !== 'on-poke/handle-action') throw new Error('not an arm of its |^ core')
    const sw = coreSwitch(agent, lines, core)
    const name = armNamed(branchFor(sw, given(sw.subject, { tag })), {})
    if (name !== tag) throw new Error(`its switch sends %${tag} to ${name ? `++${name}` : 'no arm'}`)
    return spanText(lines, at)
  })
}

// a route is an arm of a handle-api core whose first assertion is its
// method and route, and that handle-api's switches send that request to, hop
// by hop
export function routeArm(agent, core, name, method, path) {
  return refused(`handle-api does not route ${method} ${path} to ++${name}`, () => {
    const lines = linesOf(agent)
    const goal = `on-poke/handle-api/${core}/${name}`
    const at = armLine(lines, goal)
    const guard = entryGuard(spanText(lines, at))
    if (guard?.method !== method || guard.path !== path) throw new Error('its first assertion is not that route')
    if (follow(agent, lines, 'on-poke/handle-api', { method, site: moldOf(path) }, goal) !== at) throw new Error('the hops end elsewhere')
    return spanText(lines, at)
  })
}

// an arvo wire's handler is the arm on-arvo's |^ core's switch sends the
// wire to
export function wireArm(agent, wire, name) {
  return refused(`on-arvo does not dispatch ${wire} to ++${name}`, () => {
    const lines = linesOf(agent)
    const at = armLine(lines, `on-arvo/${name}`)
    const core = barketOf(lines, at)
    if (chainAt(lines, core.opener).join('/') !== 'on-arvo') throw new Error('not an arm of its |^ core')
    const sw = coreSwitch(agent, lines, core)
    const target = armNamed(branchFor(sw, given(sw.subject, { wire: moldOf(wire) })), {})
    if (target !== name) throw new Error(`its switch sends it to ${target ? `++${target}` : 'no arm'}`)
    return spanText(lines, at)
  })
}

// the Ford imports of a desk file, in order, as desk paths: each /- entry a
// sur file and each /+ entry a lib file (named, *wildcard or face=name). The
// imports end at the first line of code; any other Ford rune, or an entry in
// another form, throws
export function imports(rel, root = DESK) {
  const text = deskText(rel, root)
  const { kinds } = lex(text)
  const out = []
  for (const line of linesOf(text)) {
    if (!line.code) continue
    if (line.indent !== 0 || !line.text.startsWith('/')) break
    const code = line.text.split('').filter((_, k) => kinds[line.start + k] === CODE).join('').trimEnd()
    const rune = code.slice(0, 2)
    if ((rune !== '/-' && rune !== '/+') || !code.startsWith('  ', 2)) {
      throw new Error(`${rel}: a Ford import this reader does not read: ${code.slice(0, 24)}`)
    }
    for (const raw of code.slice(4).split(',')) {
      const m = /^(?:\*|[a-z][a-z0-9-]*=)?([a-z][a-z0-9-]*)$/.exec(raw.trim())
      if (!m) throw new Error(`${rel}: an import entry this reader does not read: '${raw.trim()}'`)
      out.push(`${rune === '/-' ? 'sur' : 'lib'}/${m[1]}.hoon`)
    }
  }
  return out
}

// every sur and lib file `rel` imports, transitively, as [path, text] pairs.
// A file the desk lacks throws, unless it is named in `external` (a base-dev
// library staged at install, which holds no %urgit code); a name that the
// desk could also read as a hyphen-split path is ambiguous and throws; an
// external the desk carries, or that nothing imports, throws
export function importClosure(rel, external = [], root = DESK) {
  const seen = new Map()
  const used = new Set()
  const has = (path) => existsSync(new URL(path, root))
  const visit = (from) => {
    for (const dep of imports(from, root)) {
      if (seen.has(dep) || used.has(dep)) continue
      if (external.includes(dep)) {
        if (has(dep)) throw new Error(`${dep} is named external, but the desk carries it`)
        used.add(dep)
        continue
      }
      const [dir, file] = dep.split('/')
      const split = `${dir}/${file.replace(/\.hoon$/, '').replaceAll('-', '/')}.hoon`
      if (split !== dep && has(split)) throw new Error(`${dep} is ambiguous: the desk also has ${split}`)
      if (!has(dep)) throw new Error(`missing import ${dep} (from ${from})`)
      seen.set(dep, deskText(dep, root))
      visit(dep)
    }
  }
  visit(rel)
  for (const dep of external) if (!used.has(dep)) throw new Error(`${dep} is named external, but nothing imports it`)
  return [...seen]
}
