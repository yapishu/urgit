::  ci-expr-case-vector: text without case on the ship (correction-02).
::  GitHub documents that it ignores case, not how it cases non-ASCII
::  letters, and the engines that run workflows case them differently
::  (act lowers each letter as Go does; GitHub's runner upper-cases it as
::  .NET does); so the ship decides a case-insensitive operation wherever
::  ASCII-only folding and every simple Unicode case mapping agree, and
::  where they could differ it is an error naming the texts and the limit.
::  Every expectation below is derived by hand from that rule.  Checked
::  through the public evaluator (+eval), the job decision
::  (+decide:ci-plan) and output resolution (+resolve, which %urgit-ci's
::  resolve-outputs reads):
::    - equality: accented, ligature, emoji and unassigned letters,
::      decided and refused;
::    - order: ASCII letters folded to upper case as GitHub's runner folds
::      them, ASCII against non-ASCII, refused pairs;
::    - contains, startsWith and endsWith on text, an empty part among
::      them; array membership;
::    - property names: non-ASCII keys of a payload and of a need's
::      outputs, exact, up to ASCII case, refused and missing; through a
::      filter; and a key known only at evaluation;
::    - short-circuit: an unvisited refused branch never fails the whole;
::    - Unicode data passes through untouched: toJSON, fromJSON, format,
::      join, truthiness, a decision's reason, an output's value;
::    - ASCII equality and matching as before;
::    - a refused condition is an error decision (never a skip or a run),
::      and a refused output has no value (never a fabricated one).
::  Byte escapes: \e2\84\aa is the Kelvin sign U+212A, \e1\ba\9e is
::  U+1E9E (capital sharp s), \cd\b8 is U+0378 (unassigned).
::
::    correction-03: two inherited answers now follow GitHub's runner
::    source (EvaluationResult: String.Compare with OrdinalIgnoreCase;
::    Contains: IndexOf with OrdinalIgnoreCase).  order folds ASCII
::    letters to upper case, so `a < _` is true: this vector said false,
::    "unchanged", until then.  and an empty part is in every text, so
::    contains(x, '') is true: this vector checked only that it was the
::    same everywhere (false).  both changes are named below, and
::    +ordinal and +empties hold their controls.  the parent's test-only
::    correction is kept: an optional name of '' asks for no text, and
::    the planner quotes an `if` in double quotes.
::  Prints `passed=N of=M` and ends in a loobean.
::
/-  ci
/+  ci-expr, ci-plan
:-  %say
|=  *
:-  %noun
=/  str  |=(t=@t `expr:ci`[%str t])
=/  cmp  |=([op=?(%eq %ne %lt %le %gt %ge) l=expr:ci r=expr:ci] `expr:ci`[%cmp op l r])
=/  call  |=([fn=@t args=(list expr:ci)] `expr:ci`[%call fn args])
=/  event  `expr:ci`[%prop [%ctx 'github'] 'event']
=/  key  |=(k=expr:ci `expr:ci`[%index event k])
=/  need-output
  |=(k=@t `expr:ci`[%index [%prop [%prop [%ctx 'needs'] 'build'] 'outputs'] [%str k]])
=/  json-list  |=(t=@t (call 'fromjson' ~[(str t)]))
=/  french  (cmp %eq (str 'École') (str 'éCOLE'))
=/  payload=@t
  '{"École":"v1","naïve":"v2","which":"école","list":["École","x"],"ſhip":"long","people":[{"ſhip":"a"},{"ship":"b"}]}'
=/  needs=val:ci-expr
  =/  outs=val:ci-expr  [%obj (malt `(list [@t val:ci-expr])`~[['Größe' [%str '3']]])]
  =/  build=val:ci-expr
    [%obj (malt `(list [@t val:ci-expr])`~[['outputs' outs] ['result' [%str 'success']]])]
  [%obj (malt `(list [@t val:ci-expr])`~[['build' build]])]
=/  sc=scope:ci-expr
  :*  (github-of:ci-expr 'push' payload 'refs/heads/main' (fil 3 40 'a') '~zod' 'w.yml' 'j')
      needs  [%obj ~]  [%obj ~]  [%obj ~]  %.y  %.n  %.n
  ==
=/  ev
  |=  e=expr:ci
  ^-  (each val:ci-expr @t)
  (eval:ci-expr e sc)
=/  has-text
  |=  [text=@t part=@t]
  ^-  ?
  ?:  =('' part)  %.y
  ?=(^ (find (trip part) (trip text)))
::  a value; or an error naming the limit and, when given, a text
::
=/  is
  |=  [e=expr:ci want=val:ci-expr]
  ^-  ?
  =((ev e) &+want)
=/  refused
  |=  [e=expr:ci named=@t]
  ^-  ?
  =/  r=(each val:ci-expr @t)  (ev e)
  ?&  ?=(%| -.r)
      (has-text p.r 'not supported for non-ASCII letters')
      (has-text p.r 'ASCII letters only')
      (has-text p.r named)
  ==
=/  yes=val:ci-expr  [%bool %.y]
=/  no=val:ci-expr  [%bool %.n]
::  the job decision of an `if`, and its verdict
::
=/  ctx=run-context:ci-plan  ['push' payload 'refs/heads/main' (fil 3 40 'a') '~zod' [%obj ~] %.n]
=/  decided
  |=  [text=@t e=expr:ci]
  ^-  decision:ci-plan
  =/  j=job:ci  ['j' 'w.yml' 'j' 0 ~ `[%if text 1 1 e] ~ ~ ~ ~]
  (decide:ci-plan j ~[j] ~ ~ ctx)
=/  verdict
  |=  [text=@t e=expr:ci]
  ^-  @tas
  -:(decided text e)
::  declared outputs, resolved as %urgit-ci's resolve-outputs resolves them
::
=/  outputs=(list declared-output:ci)
  :~  ['refusal' ['${{ \'École\' == \'éCOLE\' }}' 1 1 ~[[%expr french]]]]
      ['school' ['${{ github.event[\'École\'] }}' 2 1 ~[[%expr (key (str 'École'))]]]]
      ['mixed' ['pre-${{ github.event[\'ÉCOLE\'] }}' 3 1 ~[[%lit 'pre-'] [%expr (key (str 'ÉCOLE'))]]]]
      ['accent' ['${{ github.event.which }}!' 4 1 ~[[%expr [%prop event 'which']] [%lit '!']]]]
  ==
=/  resolved=(list [name=@t value=(each @t @t)])  (resolve:ci-expr outputs sc)
=/  refusal-out=[name=@t value=(each @t @t)]  (snag 0 resolved)
=/  refused-if=@t
  'if "École == éCOLE" could not be evaluated: comparing text without case is not supported for non-ASCII letters: \'École\' and \'éCOLE\' differ only where a non-ASCII letter may match without case (the ship decides case for ASCII letters only; GitHub does not document how it cases non-ASCII letters)'
::
=/  equality=(list [name=@t expect=? got=?])
  :~  ['École and éCOLE may be equal or not: an error naming both' %.y ?&((refused french '\'École\'') (refused french '\'éCOLE\''))]
      ['identical non-ASCII texts are equal' %.y (is (cmp %eq (str 'École') (str 'École')) yes)]
      ['non-ASCII texts equal up to ASCII case are equal' %.y (is (cmp %eq (str 'École') (str 'ÉCOLE')) yes)]
      ['café is not cafe: no mapping makes é an ASCII letter' %.y (is (cmp %eq (str 'café') (str 'cafe')) no)]
      ['café != CAFE is decided too' %.y (is (cmp %ne (str 'café') (str 'CAFE')) yes)]
      ['two different emoji are different' %.y (is (cmp %eq (str 'go 🚀') (str 'go 🎉')) no)]
      ['naïve and NAÏVE: an error' %.y (refused (cmp %eq (str 'naïve') (str 'NAÏVE')) '\'NAÏVE\'')]
      ['Straße and STRASSE differ in length under every simple mapping' %.y (is (cmp %eq (str 'Straße') (str 'STRASSE')) no)]
      ['long s may be s without case: an error' %.y (refused (cmp %eq (str 'ſ') (str 's')) '')]
      ['ß and capital sharp s: Go lowers one to the other, .NET upper-cases neither: an error' %.y (refused (cmp %eq (str 'ß') (str '\e1\ba\9e')) '')]
      ['an unassigned code point may be cased by a later Unicode: an error against a letter' %.y (refused (cmp %eq (str 'x\cd\b8') (str 'xa')) '')]
      ['an unassigned code point is still itself' %.y (is (cmp %eq (str 'x\cd\b8') (str 'X\cd\b8')) yes)]
      ['!= of an undecided pair is an error too' %.y (refused (cmp %ne (str 'École') (str 'éCOLE')) '')]
      ['ASCII: Main is MAIN' %.y (is (cmp %eq (str 'Main') (str 'MAIN')) yes)]
      ['ASCII: main is not mainline' %.y (is (cmp %eq (str 'main') (str 'mainline')) no)]
  ==
=/  order=(list [name=@t expect=? got=?])
  :~  ['ASCII: a < B' %.y (is (cmp %lt (str 'a') (str 'B')) yes)]
      ['ASCII: B < a is false' %.y (is (cmp %lt (str 'B') (str 'a')) no)]
      ['ASCII order folds letters to upper case, as GitHub\'s runner does: a < _ (correction-03; was false)' %.y (is (cmp %lt (str 'a') (str '_')) yes)]
      ['an ASCII letter orders before a non-ASCII one: é < z is false' %.y (is (cmp %lt (str 'é') (str 'z')) no)]
      ['and z < é' %.y (is (cmp %lt (str 'z') (str 'é')) yes)]
      ['a prefix orders first: ab < abé' %.y (is (cmp %lt (str 'ab') (str 'abé')) yes)]
      ['éa < Éb: an error naming both' %.y (refused (cmp %lt (str 'éa') (str 'Éb')) '\'Éb\'')]
      ['two differing non-ASCII letters are not ordered: an error' %.y (refused (cmp %gt (str '🚀') (str '🎉')) 'ordering')]
      ['equal up to ASCII case: École <= ÉCOLE' %.y (is (cmp %le (str 'École') (str 'ÉCOLE')) yes)]
  ==
=/  message  (str 'Fix für München 🚀')
=/  functions=(list [name=@t expect=? got=?])
  :~  ['an ASCII part in a text with emoji and accents is decided: no [skip ci]' %.y (is (call 'contains' ~[message (str '[skip ci]')]) no)]
      ['an ASCII part is found without case: FIX' %.y (is (call 'contains' ~[message (str 'FIX')]) yes)]
      ['MÜNCHEN may or may not be in it: an error naming it' %.y (refused (call 'contains' ~[message (str 'MÜNCHEN')]) '\'MÜNCHEN\'')]
      ['münchen is in it, its non-ASCII letter exactly' %.y (is (call 'contains' ~[message (str 'münchen')]) yes)]
      ['the emoji is in it' %.y (is (call 'contains' ~[message (str '🚀')]) yes)]
      ['FÜR may or may not be in it: an error' %.y (refused (call 'contains' ~[message (str 'FÜR')]) 'contains')]
      ['the Kelvin sign may be k without case (Go lowers it to k, .NET keeps it): an error' %.y (refused (call 'contains' ~[(str '273 \e2\84\aa') (str 'k')]) '\'k\'')]
      ['a ligature is one letter under every simple mapping: ﬁx it holds no fix' %.y (is (call 'contains' ~[(str 'ﬁx it') (str 'fix')]) no)]
      ['a letter only a full mapping relates to ASCII is an error too: ﬁ and f' %.y (refused (call 'contains' ~[(str 'ﬁ') (str 'f')]) '')]
      ['startsWith(École, éc): an error' %.y (refused (call 'startswith' ~[(str 'École') (str 'éc')]) 'startsWith')]
      ['startsWith(École, Éc)' %.y (is (call 'startswith' ~[(str 'École') (str 'Éc')]) yes)]
      ['startsWith(École, Ec) is false: É is no ASCII letter' %.y (is (call 'startswith' ~[(str 'École') (str 'Ec')]) no)]
      ['endsWith(café, É): an error' %.y (refused (call 'endswith' ~[(str 'café') (str 'É')]) 'endsWith')]
      ['endsWith(café, e) is false' %.y (is (call 'endswith' ~[(str 'café') (str 'e')]) no)]
      ['endsWith(École, COLE)' %.y (is (call 'endswith' ~[(str 'École') (str 'COLE')]) yes)]
      :+  'ASCII: contains, startsWith and endsWith as before'  %.y
      ?&  (is (call 'contains' ~[(str 'Hello World') (str 'WORLD')]) yes)
          (is (call 'contains' ~[(str 'Hello') (str 'xyz')]) no)
          (is (call 'startswith' ~[(str 'Hello') (str 'he')]) yes)
          (is (call 'endswith' ~[(str 'Hello') (str 'LO')]) yes)
      ==
      ['an empty part is in a text (correction-03; was false)' %.y (is (call 'contains' ~[(str 'abc') (str '')]) yes)]
  ==
=/  membership=(list [name=@t expect=? got=?])
  :~  ['an array holding École may or may not hold éCOLE: an error' %.y (refused (call 'contains' ~[(json-list '["École","x"]') (str 'éCOLE')]) '\'éCOLE\'')]
      ['an element equal to the item decides, whatever else is undecided' %.y (is (call 'contains' ~[(json-list '["École","éCOLE"]') (str 'éCOLE')]) yes)]
      ['no element can be equal: false' %.y (is (call 'contains' ~[(json-list '["x","y"]') (str 'éCOLE')]) no)]
      ['ASCII membership as before, loose' %.y (is (call 'contains' ~[(json-list '[1,"A"]') (str 'a')]) yes)]
  ==
=/  keys=(list [name=@t expect=? got=?])
  :~  ['a non-ASCII key read by itself' %.y (is (key (str 'École')) [%str 'v1'])]
      ['and up to ASCII case' %.y (is (key (str 'ÉCOLE')) [%str 'v1'])]
      ['école may or may not name École: an error naming both' %.y ?&((refused (key (str 'école')) '\'école\'') (refused (key (str 'école')) '\'École\''))]
      ['NAÏVE may or may not name naïve: an error' %.y (refused (key (str 'NAÏVE')) '\'naïve\'')]
      ['naïve by itself' %.y (is (key (str 'naïve')) [%str 'v2'])]
      ['a missing key is null' %.y (is (key (str 'missing')) [%null ~])]
      ['an ASCII name no non-ASCII key can match is null: ecole' %.y (is [%prop event 'ecole'] [%null ~])]
      ['an ASCII property a key may match only without case: an error' %.y (refused [%prop event 'ship'] '\'ſhip\'')]
      ['through a filter, a property is each item\'s: an error when one item\'s is' %.y (refused [%prop [%star (key (str 'people'))] 'ship'] '')]
      ['through a filter, an index too' %.y (refused [%index [%star (key (str 'people'))] (str 'ship')] '')]
      ['a key known only at evaluation is checked as well: an error' %.y (refused (key [%prop event 'which']) '\'école\'')]
      ['an ASCII key without case, as before' %.y (is (key (str 'WHICH')) [%str 'école'])]
      ['a need\'s non-ASCII output name by itself' %.y (is (need-output 'Größe') [%str '3'])]
      ['ß is one letter under every simple mapping: GRÖSSE names no output' %.y (is (need-output 'GRÖSSE') [%null ~])]
      ['GRÖßE may or may not name Größe: an error' %.y (refused (need-output 'GRÖßE') '\'Größe\'')]
  ==
=/  branches=(list [name=@t expect=? got=?])
  :~  ['true || (École == éCOLE): the refused side is never read' %.y (is [%or [%bool %.y] french] yes)]
      ['false && (École == éCOLE)' %.y (is [%and [%bool %.n] french] no)]
      ['(École == éCOLE) || true: read first, an error' %.y (refused [%or french [%bool %.y]] '')]
      ['true && (École == éCOLE): read, an error' %.y (refused [%and [%bool %.y] french] '')]
      ['case(true, a, École == éCOLE, b, c): the later predicate is never read' %.y (is (call 'case' ~[[%bool %.y] (str 'a') french (str 'b') (str 'c')]) [%str 'a'])]
      ['case(false, a, École == éCOLE, b, c): read, an error' %.y (refused (call 'case' ~[[%bool %.n] (str 'a') french (str 'b') (str 'c')]) '')]
      ['case(false, École == éCOLE, true, b, c): an unchosen value is never read' %.y (is (call 'case' ~[[%bool %.n] french [%bool %.y] (str 'b') (str 'c')]) [%str 'b'])]
  ==
=/  data=(list [name=@t expect=? got=?])
  :~  ['toJSON keeps non-ASCII text' %.y (is (call 'tojson' ~[(key (str 'list'))]) [%str '[\0a  "École",\0a  "x"\0a]'])]
      ['fromJSON and toJSON keep a non-ASCII key' %.y (is (call 'tojson' ~[(json-list '{"é":"x"}')]) [%str '{\0a  "é": "x"\0a}'])]
      ['format keeps non-ASCII text' %.y (is (call 'format' ~[(str '{0}-{1}') (str 'École') (str '🚀')]) [%str 'École-🚀'])]
      ['join keeps non-ASCII text' %.y (is (call 'join' ~[(json-list '["É","ü"]') (str '+')]) [%str 'É+ü'])]
      ['a non-ASCII text is truthy' %.y (is [%not (str 'École')] no)]
      ['a non-ASCII value read from the payload is itself' %.y (is [%prop event 'which'] [%str 'école'])]
  ==
=/  consumers=(list [name=@t expect=? got=?])
  :~  ['a refused if is an error decision with its exact reason, never a skip or a run' %.y =([%error refused-if] (decided 'École == éCOLE' french))]
      ['a decided true if runs' %.y =(%run (verdict 'École == École' (cmp %eq (str 'École') (str 'École'))))]
      ['a decided false if skips' %.y =(%skip (verdict 'café == cafe' (cmp %eq (str 'café') (str 'cafe'))))]
      ['an unvisited refused branch does not fail the if' %.y =(%run (verdict 'true || École == éCOLE' [%or [%bool %.y] french]))]
      :+  'a key known only at evaluation fails the if as an error naming it'  %.y
      =/  d=decision:ci-plan
        %+  decided
          'github.event[github.event.which] == \'v1\''
        (cmp %eq (key [%prop event 'which']) (str 'v1'))
      ?&(?=(%error -.d) (has-text reason.d '\'école\''))
      :+  'a non-ASCII value reaches the decision\'s reason and value untouched'  %.y
      =([%run 'if "github.event.which" is \'école\'' `'\'école\''] (decided 'github.event.which' [%prop event 'which']))
      :+  'a refused output has no value, never a fabricated one'  %.y
      ?&  =('refusal' name.refusal-out)
          ?=(%| -.value.refusal-out)
          (has-text p.value.refusal-out 'not supported for non-ASCII letters')
      ==
      ['a non-ASCII key resolves in an output' %.y =(['school' &+'v1'] (snag 1 resolved))]
      ['and up to ASCII case beside a literal' %.y =(['mixed' &+'pre-v1'] (snag 2 resolved))]
      ['a non-ASCII value is an output\'s value untouched' %.y =(['accent' &+'école!'] (snag 3 resolved))]
  ==
::  correction-03: order as String.Compare with OrdinalIgnoreCase orders,
::  on every operator, before and after a matching non-ASCII prefix
::
=/  ordinal=(list [name=@t expect=? got=?])
  :~  ['_ > a' %.y (is (cmp %gt (str '_') (str 'a')) yes)]
      ['a >= _ is false' %.y (is (cmp %ge (str 'a') (str '_')) no)]
      ['a <= _' %.y (is (cmp %le (str 'a') (str '_')) yes)]
      ['z < [: Z is before [' %.y (is (cmp %lt (str 'z') (str '[')) yes)]
      ['a < `' %.y (is (cmp %lt (str 'a') (str '`')) yes)]
      ['Z < ^' %.y (is (cmp %lt (str 'Z') (str '^')) yes)]
      ['the marks after both cases keep their place: { > z' %.y (is (cmp %gt (str '{') (str 'z')) yes)]
      ['digits before letters, as before: 1 < a' %.y (is (cmp %lt (str '1') (str 'a')) yes)]
      :+  'case alone does not order: ABC <= abc, abc >= ABC, abc < ABC is false'  %.y
      ?&  (is (cmp %le (str 'ABC') (str 'abc')) yes)
          (is (cmp %ge (str 'abc') (str 'ABC')) yes)
          (is (cmp %lt (str 'abc') (str 'ABC')) no)
      ==
      ['after a matching non-ASCII prefix: Éa < É_' %.y (is (cmp %lt (str 'Éa') (str 'É_')) yes)]
      ['and É_ > Éa' %.y (is (cmp %gt (str 'É_') (str 'Éa')) yes)]
      ['and Éz < É[' %.y (is (cmp %lt (str 'Éz') (str 'É[')) yes)]
      ['a prefix that may differ without case is still an error: éa < É_' %.y (refused (cmp %lt (str 'éa') (str 'É_')) '\'É_\'')]
      ['an ASCII letter still orders before a non-ASCII one after it: Éa < Éá' %.y (is (cmp %lt (str 'Éa') (str 'Éá')) yes)]
      ['a prefix orders first after a non-ASCII letter too: É < É_' %.y (is (cmp %lt (str 'É') (str 'É_')) yes)]
      ['equality is unchanged: a_ == A_' %.y (is (cmp %eq (str 'a_') (str 'A_')) yes)]
      :+  'texts compare as texts and numbers as numbers, as before: 10 < 9 as text only'  %.y
      ?&((is (cmp %lt (str '10') (str '9')) yes) (is (cmp %lt [%num .~10] (str '9')) no))
  ==
::  correction-03: an empty part is in every text, as IndexOf finds it; a
::  value read as text the same; arrays and objects keep their rules
::
=/  empties=(list [name=@t expect=? got=?])
  :~  ['the empty string is in the empty string' %.y (is (call 'contains' ~[(str '') (str '')]) yes)]
      ['empty text is in a non-ASCII text with no letter related to ASCII: é' %.y (is (call 'contains' ~[(str 'é') (str '')]) yes)]
      ['and in one with a related letter: ſ' %.y (is (call 'contains' ~[(str 'ſ') (str '')]) yes)]
      :+  'a value read as text holds it too: null, a number, a boolean'  %.y
      ?&  (is (call 'contains' ~[[%null ~] (str '')]) yes)
          (is (call 'contains' ~[[%num .~1] (str '')]) yes)
          (is (call 'contains' ~[[%bool %.y] (str '')]) yes)
      ==
      ['a null part reads as empty text: contains(abc, null)' %.y (is (call 'contains' ~[(str 'abc') [%null ~]]) yes)]
      ['a nonempty part is still looked for: the empty string holds no a' %.y (is (call 'contains' ~[(str '') (str 'a')]) no)]
      ['an array is searched for an element, not a substring: ["abc"] holds no empty string' %.y (is (call 'contains' ~[(json-list '["abc"]') (str '')]) no)]
      ['and [""] holds it' %.y (is (call 'contains' ~[(json-list '[""]') (str '')]) yes)]
      ['an object holds nothing, as before' %.y (is (call 'contains' ~[(json-list '{"a":""}') (str '')]) no)]
      :+  'startsWith and endsWith find an empty part, as before'  %.y
      ?&  (is (call 'startswith' ~[(str 'abc') (str '')]) yes)
          (is (call 'endswith' ~[(str '') (str '')]) yes)
          (is (call 'startswith' ~[(str 'ſ') (str '')]) yes)
          (is (call 'endswith' ~[(str 'é') (str '')]) yes)
      ==
      ['a part longer than the text does not start it' %.y (is (call 'startswith' ~[(str '') (str 'a')]) no)]
  ==
=/  cases=(list [name=@t expect=? got=?])
  :(weld equality order functions membership keys branches data consumers ordinal empties)
=/  failed=(list @t)
  %+  murn  cases
  |=  [name=@t expect=? got=?]
  ?:(=(expect got) ~ `name)
=/  passed=@ud  (sub (lent cases) (lent failed))
~&  [%failed failed]
~&  (crip "passed={<passed>} of={<(lent cases)>}")
?=(~ failed)
