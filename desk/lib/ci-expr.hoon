::  Job expressions on the ship (CI-EXPR-2; R2.1-A/R2.2-A): the compiled
::  tree a plan carries, checked node by node, and its evaluation.
::
::    the pinned compiler (runner/internal/plan expr.go) parses a job's
::    `if` and its declared `outputs`; the ship never parses expression
::    text.  it re-checks what the compiler sent — the version, every node,
::    the bounds, and the contexts and functions the field may use, with
::    the compiler's own words — and evaluates the tree with GitHub's
::    documented semantics: loose equality, coercion to number and to
::    text, case-insensitive strings, short-circuit && and ||, the object
::    filter, and the functions a job-level field may call.  evaluation is
::    bounded in steps and in the size of every value; an error is a
::    reason, never false.
::
::    text without case (correction-02): GitHub documents that it ignores
::    case, not how it cases non-ASCII letters, and the engines that run
::    workflows case them differently.  so the ship decides a comparison,
::    contains, startsWith, endsWith, array membership or property name
::    without case wherever ASCII-only folding and every simple Unicode
::    case mapping agree, and where they could differ — two texts that
::    differ only where a non-ASCII letter could match without case — the
::    operation is an error naming both texts (+case-tag).  a text no case
::    operation reads passes through untouched
::
/-  ci
|%
::  the bounds the compiler enforces too
::
++  max-text  4.096
++  max-nodes  256
++  max-depth  32
++  max-outputs  64
++  max-fuel  10.000
++  max-value  1.048.576
::
::  a value
::
+$  val
  $~  [%null ~]
  $%  [%null ~]
      [%bool p=?]
      [%num p=@rd]
      [%str p=@t]
      [%arr p=(list val)]
      [%obj p=(map @t val)]
  ==
::
::  the field an expression is written in: a job-level `if`, a workflow's
::  concurrency group or cancel-in-progress (CI-CONCURRENCY-1: github,
::  inputs and vars alone), or a job's declared output
::
+$  field  ?(%if %concurrency %output)
::
::  what an evaluation reads: the contexts, and the answers of the status
::  functions for the job being decided
::
+$  scope
  $:  github=val
      needs=val
      vars=val
      inputs=val
      steps=val
      success=?
      failure=?
      cancelled=?
  ==
::
++  empty-scope
  ^-  scope
  [[%obj ~] [%obj ~] [%obj ~] [%obj ~] [%obj ~] %.y %.n %.n]
::
::  one step of a context access: a property name (or a string index),
::  a dynamic index (~), or the * filter
::
+$  accessor  [name=(unit @t) star=?]
::
++  github-keys
  ^-  (set @t)
  %-  silt
  :~  'event_name'  'event'  'ref'  'ref_name'  'ref_type'  'sha'
      'actor'  'triggering_actor'  'workflow'  'job'  'base_ref'  'head_ref'
  ==
::
++  known-contexts
  ^-  (set @t)
  %-  silt
  :~  'github'  'env'  'vars'  'job'  'jobs'  'steps'  'runner'
      'secrets'  'strategy'  'matrix'  'needs'  'inputs'
  ==
::
::  the functions, by the lower-case name the tree carries, with the name
::  a message shows
::
++  functions
  ^-  (map @t @t)
  %-  malt
  ^-  (list [@t @t])
  :~  ['contains' 'contains']  ['startswith' 'startsWith']  ['endswith' 'endsWith']
      ['format' 'format']  ['join' 'join']  ['tojson' 'toJSON']  ['fromjson' 'fromJSON']
      ['hashfiles' 'hashFiles']  ['case' 'case']  ['success' 'success']
      ['failure' 'failure']  ['always' 'always']  ['cancelled' 'cancelled']
  ==
::
++  status-function
  |=  fn=@t
  ^-  ?
  ?=(?(%success %failure %always %cancelled) fn)
::
::  --  the wire
::
++  text-field
  |=  [f=(map @t json) key=@t]
  ^-  (unit @t)
  =/  v=(unit json)  (~(get by f) key)
  ?~  v  ~
  ?.  ?=([%s *] u.v)  ~
  `p.u.v
::
++  count-field
  |=  [f=(map @t json) key=@t]
  ^-  (unit @ud)
  =/  v=(unit json)  (~(get by f) key)
  ?~  v  ~
  ?.  ?=([%n *] u.v)  ~
  (rush p.u.v dim:ag)
::
::  a text shown in a reason: at most 200 bytes
::
++  shown
  |=  text=@t
  ^-  @t
  ?:  (lte (met 3 text) 200)  text
  (cat 3 (end [3 200] text) '…')
::
::  a compiled job-level `if`: {v:2, text, line, col, expr} or, refused by
::  the compiler, {v:2, text, line, col, refusal}.  either refusal is the
::  reason the plan is refused with
::
++  parse-condition
  |=  jon=json
  ^-  (each condition:ci @t)
  ?.  ?=([%o *] jon)  |+'the condition is not an object'
  =/  f=(map @t json)  p.jon
  ?.  =(`2 (count-field f 'v'))  |+'the condition is not version 2'
  =/  text=(unit @t)  (text-field f 'text')
  =/  line=(unit @ud)  (count-field f 'line')
  =/  col=(unit @ud)  (count-field f 'col')
  ?.  ?&(?=(^ text) ?=(^ line) ?=(^ col))
    |+'the condition has no text, line or col'
  ?:  (gth (met 3 u.text) max-text)  |+'the condition text exceeds 4096 bytes'
  =/  refusal=(unit @t)  (text-field f 'refusal')
  ?^  refusal  |+u.refusal
  =/  tree=(unit json)  (~(get by f) 'expr')
  ?~  tree  |+'the condition has neither a tree nor a refusal'
  =/  built=(each expr:ci @t)  (parse-tree u.tree %if)
  ?:  ?=(%| -.built)  built
  &+[%if u.text u.line u.col p.built]
::
::  a compiled declared output: {name, v:2, text, line, col, parts} or
::  {name, ..., refusal}; the node bound counts every part
::
++  parse-output
  |=  jon=json
  ^-  (each declared-output:ci @t)
  ?.  ?=([%o *] jon)  |+'an output is not an object'
  =/  f=(map @t json)  p.jon
  =/  name=@t  (fall (text-field f 'name') '')
  ?.  =(`2 (count-field f 'v'))  |+'the output is not version 2'
  =/  text=(unit @t)  (text-field f 'text')
  =/  line=(unit @ud)  (count-field f 'line')
  =/  col=(unit @ud)  (count-field f 'col')
  ?.  ?&(?=(^ text) ?=(^ line) ?=(^ col))
    |+'the output has no text, line or col'
  =/  refusal=(unit @t)  (text-field f 'refusal')
  ?^  refusal  |+u.refusal
  ?.  (output-name-valid name)
    |+(rap 3 ~['output name ' name ' starts with a letter or _ and holds only letters, digits, - and _'])
  ?:  (gth (met 3 u.text) max-text)  |+'the output text exceeds 4096 bytes'
  =/  raw=(unit json)  (~(get by f) 'parts')
  ?.  ?=([~ %a *] raw)  |+'the output has no parts'
  =/  items=(list json)  p.u.raw
  =|  out=(list part:ci)
  =|  nodes=@ud
  |-
  ?~  items  &+[name [u.text u.line u.col (flop out)]]
  ?.  ?=([%o *] i.items)  |+'an output part is not an object'
  =/  lit=(unit @t)  (text-field p.i.items 'lit')
  ?^  lit  $(items t.items, out [[%lit u.lit] out])
  =/  tree=(unit json)  (~(get by p.i.items) 'expr')
  ?~  tree  |+'an output part is neither text nor an expression'
  =/  built=(each [e=expr:ci n=@ud] @t)  (build u.tree 1 nodes)
  ?:  ?=(%| -.built)  built
  =/  problem=(unit @t)  (check e.p.built %output)
  ?^  problem  |+u.problem
  $(items t.items, nodes n.p.built, out [[%expr e.p.built] out])
::
::  a compiled template of a field (CI-CONCURRENCY-1: a workflow's
::  concurrency group): {text, line, col, parts}, every part checked for
::  the field and the node bound counted over every part, as a declared
::  output's are
::
++  parse-template
  |=  [jon=json =field]
  ^-  (each template:ci @t)
  ?.  ?=([%o *] jon)  |+'a template is not an object'
  =/  f=(map @t json)  p.jon
  =/  text=(unit @t)  (text-field f 'text')
  =/  line=(unit @ud)  (count-field f 'line')
  =/  col=(unit @ud)  (count-field f 'col')
  ?.  ?&(?=(^ text) ?=(^ line) ?=(^ col))
    |+'the template has no text, line or col'
  ?:  (gth (met 3 u.text) max-text)  |+'the template text exceeds 4096 bytes'
  =/  raw=(unit json)  (~(get by f) 'parts')
  ?.  ?=([~ %a *] raw)  |+'the template has no parts'
  =/  items=(list json)  p.u.raw
  =|  out=(list part:ci)
  =|  nodes=@ud
  |-
  ?~  items  &+[u.text u.line u.col (flop out)]
  ?.  ?=([%o *] i.items)  |+'a template part is not an object'
  =/  lit=(unit @t)  (text-field p.i.items 'lit')
  ?^  lit  $(items t.items, out [[%lit u.lit] out])
  =/  tree=(unit json)  (~(get by p.i.items) 'expr')
  ?~  tree  |+'a template part is neither text nor an expression'
  =/  built=(each [e=expr:ci n=@ud] @t)  (build u.tree 1 nodes)
  ?:  ?=(%| -.built)  built
  =/  problem=(unit @t)  (check e.p.built field)
  ?^  problem  |+u.problem
  $(items t.items, nodes n.p.built, out [[%expr e.p.built] out])
::
::  a compiled cancel-in-progress (CI-CONCURRENCY-1): {value: true|false}
::  for a fixed one, else {text, line, col, expr} for the expression the
::  ship evaluates when a run joins
::
++  parse-cancel
  |=  jon=json
  ^-  (each cancel-flag:ci @t)
  ?.  ?=([%o *] jon)  |+'cancel-in-progress is not an object'
  =/  f=(map @t json)  p.jon
  =/  value=(unit json)  (~(get by f) 'value')
  =/  tree=(unit json)  (~(get by f) 'expr')
  ?:  ?&(?=(^ value) ?=(^ tree))  |+'cancel-in-progress is both a value and an expression'
  ?:  ?=([~ %b *] value)  &+[%fixed p.u.value]
  ?^  value  |+'cancel-in-progress value is not true or false'
  ?~  tree  |+'cancel-in-progress is neither a value nor an expression'
  =/  text=(unit @t)  (text-field f 'text')
  =/  line=(unit @ud)  (count-field f 'line')
  =/  col=(unit @ud)  (count-field f 'col')
  ?.  ?&(?=(^ text) ?=(^ line) ?=(^ col))
    |+'cancel-in-progress has no text, line or col'
  ?:  (gth (met 3 u.text) max-text)  |+'the cancel-in-progress text exceeds 4096 bytes'
  =/  built=(each expr:ci @t)  (parse-tree u.tree %concurrency)
  ?:  ?=(%| -.built)  built
  &+[%expr u.text u.line u.col p.built]
::
++  output-name-valid
  |=  name=@t
  ^-  ?
  ?:  (gth (met 3 name) 100)  %.n
  ?=(^ (rush name ;~(plug ;~(pose alf cab) (star ;~(pose aln cab hep)))))
::
::  a tree from the wire, bounded and checked for its field
::
++  parse-tree
  |=  [jon=json =field]
  ^-  (each expr:ci @t)
  =/  built=(each [e=expr:ci n=@ud] @t)  (build jon 1 0)
  ?:  ?=(%| -.built)  built
  =/  problem=(unit @t)  (check e.p.built field)
  ?^  problem  |+u.problem
  &+e.p.built
::
::  one node and its children: the depth it sits at and the nodes counted
::  before it; refused past either bound
::
++  build
  |=  [jon=json depth=@ud count=@ud]
  ^-  (each [e=expr:ci n=@ud] @t)
  ?:  (gth depth max-depth)
    |+(rap 3 ~['the expression nests deeper than ' (crip (a-co:co max-depth))])
  =.  count  +(count)
  ?:  (gth count max-nodes)
    |+(rap 3 ~['the expression has more than ' (crip (a-co:co max-nodes)) ' nodes'])
  ?.  ?=([%o *] jon)  |+'an expression node is not an object'
  =/  f=(map @t json)  p.jon
  =/  kind=(unit @t)  (text-field f 'k')
  ?~  kind  |+'an expression node has no kind'
  =/  child
    |=  key=@t
    ^-  (each [e=expr:ci n=@ud] @t)
    =/  v=(unit json)  (~(get by f) key)
    ?~  v  |+(rap 3 ~['a ' u.kind ' node has no ' key])
    (build u.v +(depth) count)
  =/  name
    |=  key=@t
    ^-  (each @t @t)
    =/  v=(unit @t)  (text-field f key)
    ?~  v  |+(rap 3 ~['a ' u.kind ' node has no ' key])
    ?:  (gth (met 3 u.v) max-text)  |+'an expression text exceeds 4096 bytes'
    &+u.v
  ?+  u.kind  |+(rap 3 ~['unknown expression node ' u.kind])
    %null  &+[[%null ~] count]
  ::
      %bool
    =/  v=(unit json)  (~(get by f) 'b')
    ?.  ?=([~ %b *] v)  |+'a bool node has no b'
    &+[[%bool p.u.v] count]
  ::
      %num
    =/  v=(unit json)  (~(get by f) 'n')
    ?.  ?=([~ %n *] v)  |+'a num node has no n'
    =/  n=@rd  (to-number (crip (trip p.u.v)))
    ?:  (nan n)  |+'a num node is not a number'
    &+[[%num n] count]
  ::
      %str
    =/  s=(each @t @t)  (name 's')
    ?:  ?=(%| -.s)  s
    &+[[%str p.s] count]
  ::
      %ctx
    =/  s=(each @t @t)  (name 'name')
    ?:  ?=(%| -.s)  s
    ?.  =(p.s (crip (cass (trip p.s))))  |+'a context name is not lower case'
    &+[[%ctx p.s] count]
  ::
      %prop
    =/  s=(each @t @t)  (name 'name')
    ?:  ?=(%| -.s)  s
    =/  of  (child 'of')
    ?:  ?=(%| -.of)  of
    &+[[%prop e.p.of p.s] n.p.of]
  ::
      %index
    =/  of  (child 'of')
    ?:  ?=(%| -.of)  of
    =/  at  (build (~(gut by f) 'at' ~) +(depth) n.p.of)
    ?:  ?=(%| -.at)  at
    &+[[%index e.p.of e.p.at] n.p.at]
  ::
      %star
    =/  of  (child 'of')
    ?:  ?=(%| -.of)  of
    &+[[%star e.p.of] n.p.of]
  ::
      %not
    =/  a  (child 'a')
    ?:  ?=(%| -.a)  a
    &+[[%not e.p.a] n.p.a]
  ::
      %cmp
    =/  op=(unit @t)  (text-field f 'op')
    ?.  ?=([~ ?(%eq %ne %lt %le %gt %ge)] op)  |+'a cmp node has no known op'
    =/  l  (child 'l')
    ?:  ?=(%| -.l)  l
    =/  r  (build (~(gut by f) 'r' ~) +(depth) n.p.l)
    ?:  ?=(%| -.r)  r
    &+[[%cmp u.op e.p.l e.p.r] n.p.r]
  ::
      ?(%and %or)
    =/  l  (child 'l')
    ?:  ?=(%| -.l)  l
    =/  r  (build (~(gut by f) 'r' ~) +(depth) n.p.l)
    ?:  ?=(%| -.r)  r
    ?:  =(%and u.kind)  &+[[%and e.p.l e.p.r] n.p.r]
    &+[[%or e.p.l e.p.r] n.p.r]
  ::
      %call
    =/  fn=(each @t @t)  (name 'fn')
    ?:  ?=(%| -.fn)  fn
    =/  raw=(unit json)  (~(get by f) 'args')
    ?.  ?=([~ %a *] raw)  |+'a call node has no args'
    =/  items=(list json)  p.u.raw
    =|  args=(list expr:ci)
    =/  n=@ud  count
    |-
    ?~  items  &+[[%call p.fn (flop args)] n]
    =/  arg  (build i.items +(depth) n)
    ?:  ?=(%| -.arg)  arg
    $(items t.items, n n.p.arg, args [e.p.arg args])
  ==
::
::  the first construct the field may not use, in source order, in the
::  compiler's words (runner/internal/plan expr.go check)
::
++  check
  |=  [e=expr:ci =field]
  ^-  (unit @t)
  ?+  -.e  (check-children e field)
    %ctx  (check-context p.e ~ field)
  ::
      ?(%prop %index %star)
    =/  chain  (access-chain e)
    =/  problem=(unit @t)
      ?.  ?=(%ctx -.root.chain)  (check root.chain field)
      (check-context p.root.chain accessors.chain field)
    ?^  problem  problem
    (check-indexes e field)
  ::
      %call
    =/  problem=(unit @t)  (check-call e field)
    ?^  problem  problem
    (check-children e field)
  ==
::
++  check-children
  |=  [e=expr:ci =field]
  ^-  (unit @t)
  =/  kids=(list expr:ci)
    ?+  -.e  ~
      %not  ~[p.e]
      %cmp  ~[l.e r.e]
      ?(%and %or)  ~[l.e r.e]
      %call  args.e
    ==
  |-
  ?~  kids  ~
  =/  problem=(unit @t)  (check i.kids field)
  ?^  problem  problem
  $(kids t.kids)
::
::  the dynamic indexes of an access chain are expressions of their own
::
++  check-indexes
  |=  [e=expr:ci =field]
  ^-  (unit @t)
  ?+  -.e  ~
    %prop  $(e of.e)
    %star  $(e of.e)
      %index
    ?:  ?=(%str -.at.e)  $(e of.e)
    =/  problem=(unit @t)  (check at.e field)
    ?^  problem  problem
    $(e of.e)
  ==
::
++  access-chain
  |=  e=expr:ci
  ^-  [root=expr:ci accessors=(list accessor)]
  =|  acc=(list accessor)
  |-
  ?+  -.e  [e acc]
    %prop  $(e of.e, acc [[`name.e %.n] acc])
    %star  $(e of.e, acc [[~ %.y] acc])
      %index
    ?:  ?=(%str -.at.e)  $(e of.e, acc [[`p.at.e %.n] acc])
    $(e of.e, acc [[~ %.n] acc])
  ==
::
++  check-context
  |=  [name=@t chain=(list accessor) =field]
  ^-  (unit @t)
  =/  allowed=(set @t)
    %-  silt
    ?-  field
      %if  ~['github' 'needs' 'vars' 'inputs']
      %concurrency  ~['github' 'vars' 'inputs']
      %output  ~['github' 'needs' 'vars' 'inputs' 'steps']
    ==
  ?.  (~(has in allowed) name)
    ?.  (~(has in known-contexts) name)  `(rap 3 ~['unknown context ' name])
    ?:  ?=(%if field)
      `(rap 3 ~['context ' name ' is not available in a job-level if (github, needs, vars and inputs are)'])
    ?:  ?=(%concurrency field)
      `(rap 3 ~['context ' name ' is not available to a workflow\'s concurrency (github, inputs and vars are)'])
    `(rap 3 ~['context ' name ' is not available to a job output on the ship in this release (github, needs, vars, inputs and steps.<id>.outputs are)'])
  ?+  name  ~
      %github
    ?~  chain  `'the whole github context is not available on the ship; name one of its properties'
    ?~  name.i.chain  `'github is read by property name only on the ship'
    =/  key=@t  (crip (cass (trip u.name.i.chain)))
    ?.  (~(has in github-keys) key)
      `(rap 3 ~['github.' key ' is not available on the ship in this release'])
    ?:  ?&(?=(%concurrency field) =('job' key))
      `'github.job is not defined for a workflow\'s concurrency: it is set only inside a job'
    ~
  ::
      %steps
    ?.  ?&(?=([* * *] chain) ?=(^ name.i.chain) ?=(^ name.i.t.chain))
      ?.  ?&(?=([* * ~] chain) ?=(^ name.i.chain) ?=(^ name.i.t.chain))
        `'steps is read as steps.<id>.outputs on the ship'
      (steps-property u.name.i.chain u.name.i.t.chain)
    (steps-property u.name.i.chain u.name.i.t.chain)
  ==
::
++  steps-property
  |=  [id=@t property=@t]
  ^-  (unit @t)
  =/  lower=@t  (crip (cass (trip property)))
  ?:  =('outputs' lower)  ~
  `(rap 3 ~['steps.' id '.' lower ' is not available on the ship; only steps.<id>.outputs'])
::
++  check-call
  |=  [e=expr:ci =field]
  ^-  (unit @t)
  ?>  ?=(%call -.e)
  =/  display=(unit @t)  (~(get by functions) fn.e)
  ?~  display  `(rap 3 ~['unknown function ' fn.e])
  ?:  ?&((status-function fn.e) !?=(%if field))
    `(rap 3 ~['function ' u.display ' is only valid in an if'])
  ?:  =('hashfiles' fn.e)
    ?:  ?=(%if field)  `'function hashFiles is not available in a job-level if'
    ?:  ?=(%concurrency field)  `'function hashFiles is not available to a workflow\'s concurrency'
    `'function hashFiles is not available to a job output on the ship'
  =/  got=@ud  (lent args.e)
  =/  shown-got=@t  (crip (a-co:co got))
  ?+  fn.e  ~
      ?(%contains %startswith %endswith)
    ?:  =(2 got)  ~
    `(rap 3 ~[u.display ' takes 2 arguments, not ' shown-got])
  ::
      ?(%tojson %fromjson)
    ?:  =(1 got)  ~
    `(rap 3 ~[u.display ' takes 1 argument, not ' shown-got])
  ::
      ?(%success %failure %always %cancelled)
    ?:  =(0 got)  ~
    `(rap 3 ~[u.display ' takes 0 arguments, not ' shown-got])
  ::
      %format
    ?:  (gte got 1)  ~
    `'format takes at least 1 argument, not 0'
  ::
      %join
    ?:  &((gte got 1) (lte got 2))  ~
    `(rap 3 ~['join takes 1 or 2 arguments, not ' shown-got])
  ::
      %case
    ?:  &((gte got 3) =(1 (mod got 2)))  ~
    `(rap 3 ~['case takes an odd number of arguments, at least 3, not ' shown-got])
  ==
::
::  whether a tree calls a status function anywhere: without one, a
::  job-level if is read as success() && (if)
::
++  has-status
  |=  e=expr:ci
  ^-  ?
  ?-  -.e
    ?(%null %bool %num %str %ctx)  %.n
    %prop  $(e of.e)
    %star  $(e of.e)
    %index  |($(e of.e) $(e at.e))
    %not  $(e p.e)
    %cmp  |($(e l.e) $(e r.e))
    ?(%and %or)  |($(e l.e) $(e r.e))
    %call  |((status-function fn.e) (lien args.e has-status))
  ==
::
::  what callers outside this library read of a condition and of declared
::  outputs, as values of no recursive type: the compiler loops fusing a
::  pattern over the recursive tree in another library's subject, so every
::  traversal of a tree stays here
::
+$  summary
  $%  [%if text=@t line=@ud col=@ud status=?]
      [%output-eq job=@t output=@t literal=@t]
      [%refused text=@t reason=@t]
  ==
::
++  summarize
  |=  c=condition:ci
  ^-  summary
  ?-  -.c
    %if  [%if text.c line.c col.c (has-status expr.c)]
    %output-eq  [%output-eq job.c output.c literal.c]
    %refused  [%refused text.c reason.c]
  ==
::
::  a condition's value: the %if tree's, else an error
::
++  eval-condition
  |=  [c=condition:ci s=scope]
  ^-  (each val @t)
  ?.  ?=(%if -.c)  |+'the condition is not an expression'
  (eval expr.c s)
::
::  each declared output's name, text and place
::
++  output-places
  |=  outputs=(list declared-output:ci)
  ^-  (list [name=@t text=@t line=@ud col=@ud])
  =|  out=(list [name=@t text=@t line=@ud col=@ud])
  |-
  ?~  outputs  (flop out)
  =/  t=template:ci  template.i.outputs
  $(outputs t.outputs, out [[name.i.outputs text.t line.t col.t] out])
::
::  each declared output's value in a scope, or why it has none
::
++  resolve
  |=  [outputs=(list declared-output:ci) s=scope]
  ^-  (list [name=@t value=(each @t @t)])
  =|  out=(list [name=@t value=(each @t @t)])
  |-
  ?~  outputs  (flop out)
  =/  value=(each @t @t)  (interpolate parts.template.i.outputs s)
  $(outputs t.outputs, out [[name.i.outputs value] out])
::
::  the job ids a condition and declared outputs name literally as
::  needs.<id>, with where: 'if' or 'output <name>'
::
++  named-needs
  |=  [cond=(unit condition:ci) outputs=(list declared-output:ci)]
  ^-  (list [where=@t id=@t])
  =/  from-if=(list [where=@t id=@t])
    ?~  cond  ~
    ?.  ?=(%if -.u.cond)  ~
    (turn (needs-named expr.u.cond) |=(id=@t ['if' id]))
  =|  out=(list [where=@t id=@t])
  |-
  ?~  outputs  (weld from-if (flop out))
  =/  where=@t  (cat 3 'output ' name.i.outputs)
  =/  parts=(list part:ci)  parts.template.i.outputs
  =|  found=(list [where=@t id=@t])
  |-
  ?~  parts  ^$(outputs t.outputs, out (weld (flop found) out))
  ?:  ?=(%lit -.i.parts)  $(parts t.parts)
  =/  ids=(list @t)  (needs-named p.i.parts)
  $(parts t.parts, found (weld (flop (turn ids |=(id=@t [where id]))) found))
::
::  the job ids a tree names literally as needs.<id> or needs['<id>']
::
++  needs-named
  |=  e=expr:ci
  ^-  (list @t)
  ?-  -.e
    ?(%null %bool %num %str %ctx)  ~
      ?(%prop %index %star)
    =/  chain  (access-chain e)
    =/  here=(list @t)
      ?.  ?=(%ctx -.root.chain)  ~
      ?.  =('needs' p.root.chain)  ~
      ?~  accessors.chain  ~
      ?~  name.i.accessors.chain  ~
      ~[u.name.i.accessors.chain]
    =/  rest=(list @t)  ?:(?=(%ctx -.root.chain) ~ (needs-named root.chain))
    (weld here (weld rest (index-needs e)))
  ::
    %not  (needs-named p.e)
    %cmp  (weld (needs-named l.e) (needs-named r.e))
    ?(%and %or)  (weld (needs-named l.e) (needs-named r.e))
    %call  (zing (turn args.e needs-named))
  ==
::
++  index-needs
  |=  e=expr:ci
  ^-  (list @t)
  ?+  -.e  ~
    %prop  $(e of.e)
    %star  $(e of.e)
    %index  (weld (needs-named at.e) $(e of.e))
  ==
::
::  --  numbers.  a number is a double; NaN and the infinities are values
::  a comparison or a coercion can produce
::
++  nan-rd  `@rd`0x7ff8.0000.0000.0000
++  inf-rd  `@rd`0x7ff0.0000.0000.0000
++  neg-inf-rd  `@rd`0xfff0.0000.0000.0000
::
++  nan
  |=  n=@rd
  ^-  ?
  (gth (dis n 0x7fff.ffff.ffff.ffff) 0x7ff0.0000.0000.0000)
::
++  zero
  |=  n=@rd
  ^-  ?
  =(0 (dis n 0x7fff.ffff.ffff.ffff))
::
++  negative
  |=  n=@rd
  ^-  ?
  =(1 (rsh [0 63] n))
::
::  GitHub's number from text: trimmed; empty is 0; a decimal with an
::  optional sign, fraction and exponent; 0x hex and 0o octal integers;
::  Infinity and -Infinity; anything else NaN
::
++  to-number
  |=  text=@t
  ^-  @rd
  =/  chars=tape  (trim-tape (trip text))
  ?~  chars  .~0
  ?:  =("Infinity" chars)  inf-rd
  ?:  =("-Infinity" chars)  neg-inf-rd
  ?:  ?&(?=([%'0' %x * *] chars) (levy `tape`t.t.chars hex-digit))
    (sun:rd (scan t.t.chars hex-number))
  ?:  ?&(?=([%'0' %o * *] chars) (levy `tape`t.t.chars |=(c=@tD &((gte c '0') (lte c '7')))))
    (sun:rd (scan t.t.chars oct-number))
  =/  parsed=(unit [s=? e=@s a=@u])  (decimal chars)
  ?~  parsed  nan-rd
  (grd:rd [%d u.parsed])
::
++  hex-digit
  |=  c=@tD
  ^-  ?
  ?|(&((gte c '0') (lte c '9')) &((gte c 'a') (lte c 'f')) &((gte c 'A') (lte c 'F')))
::
++  hex-number
  %+  cook  |=(digits=tape (digits-value digits 16))
  (plus ;~(pose (shim '0' '9') (shim 'a' 'f') (shim 'A' 'F')))
::
++  oct-number
  %+  cook  |=(digits=tape (digits-value digits 8))
  (plus (shim '0' '7'))
::
::  the value of digits in a base: 0-9, then a-f or A-F
::
++  digits-value
  |=  [digits=tape base=@ud]
  ^-  @
  =/  acc=@  0
  |-
  ?~  digits  acc
  =/  c=@tD  i.digits
  =/  d=@
    ?:  &((gte c '0') (lte c '9'))  (sub c '0')
    ?:  &((gte c 'a') (lte c 'f'))  (add 10 (sub c 'a'))
    (add 10 (sub c 'A'))
  $(digits t.digits, acc (add (mul base acc) d))
::
++  trim-tape
  |=  t=tape
  ^-  tape
  =/  space  |=(c=@tD |(=(' ' c) =('\09' c) =('\0a' c) =('\0d' c)))
  =/  front=tape  |-(?~(t ~ ?:((space i.t) $(t t.t) t)))
  =/  back=tape  (flop front)
  =.  back  |-(?~(back ~ ?:((space i.back) $(back t.back) back)))
  (flop back)
::
::  [sign exponent mantissa] of a decimal: [+-]digits[.digits][(e|E)[+-]digits]
::  or [+-].digits[...]; ~ when the text is not one
::
++  decimal
  |=  chars=tape
  ^-  (unit [s=? e=@s a=@u])
  =/  positive=?  %.y
  =?  positive  ?=([%'-' *] chars)  %.n
  =?  chars  ?=([?(%'-' %'+') *] chars)  t.chars
  =|  whole=tape
  |-  ^-  (unit [s=? e=@s a=@u])
      ?:  ?=([@ *] chars)
        ?:  &((gte i.chars '0') (lte i.chars '9'))
          $(chars t.chars, whole [i.chars whole])
        (decimal-rest positive (flop whole) chars)
      (decimal-rest positive (flop whole) chars)
::
++  decimal-rest
  |=  [positive=? whole=tape chars=tape]
  ^-  (unit [s=? e=@s a=@u])
  ::  the fraction's digits and what follows them, from one trap
  ::
  =/  split=[fraction=tape rest=tape]
    ?.  ?=([%'.' *] chars)  [~ chars]
    =/  rest=tape  t.chars
    =|  digits=tape
    |-
    ?:  ?&(?=([@ *] rest) (gte i.rest '0') (lte i.rest '9'))
      $(rest t.rest, digits [i.rest digits])
    [(flop digits) rest]
  =/  fraction=tape  fraction.split
  =.  chars  rest.split
  ?:  ?&(?=(~ whole) ?=(~ fraction))  ~
  =/  exponent=(unit @s)
    ?~  chars  `--0
    ?.  ?=(?(%e %'E') i.chars)  ~
    =/  rest=tape  t.chars
    =/  up=?  ?=([%'-' *] rest)
    =?  rest  ?=([?(%'-' %'+') *] rest)  t.rest
    ?~  rest  ~
    ?.  (levy `tape`rest |=(c=@tD &((gte c '0') (lte c '9'))))  ~
    =/  n=@ud  (scan rest dem:ag-plain)
    `(new:si !up n)
  ?~  exponent  ~
  =/  digits=tape  (weld whole fraction)
  =/  mantissa=@u  ?~(digits 0 (scan digits dem:ag-plain))
  `[positive (dif:si u.exponent (sun:si (lent fraction))) mantissa]
::
::  plain decimal digits, leading zeros allowed (dem:ag wants none past
::  the first and a thousands dot)
::
++  ag-plain
  |%
  ++  dem
    %+  cook  |=(digits=tape (digits-value digits 10))
    (plus (shim '0' '9'))
  --
::
::  a number as GitHub writes it (G15, as act's %.15G does): at most 15
::  significant digits, plainly when its leading digit's exponent is from
::  -4 to 14, else with an exponent like 1.5E+20 or 1E-05; 0 for either
::  zero; NaN, Infinity, -Infinity
::
++  number-text
  |=  n=@rd
  ^-  @t
  ?:  (nan n)  'NaN'
  ?:  =(inf-rd n)  'Infinity'
  ?:  =(neg-inf-rd n)  '-Infinity'
  ?:  (zero n)  '0'
  =/  sign=tape  ?:((negative n) "-" "")
  =/  d=dn  (drg:rd (dis n 0x7fff.ffff.ffff.ffff))
  ?.  ?=(%d -.d)  'NaN'
  =/  rounded=[digits=tape exp=@s]  (significant a.d e.d)
  =/  digits=tape  digits.rounded
  ?~  digits  '0'
  =/  count=@ud  (lent digits)
  ::  the exponent of the leading digit
  =/  lead=@s  (sum:si exp.rounded (sun:si (dec count)))
  =/  [up=? mag=@ud]  (old:si lead)
  ?:  ?|(&(up (gte mag 15)) &(!up (gte mag 5)))
    =/  body=tape  ?~(t.digits digits [i.digits '.' t.digits])
    =/  power=tape  (a-co:co mag)
    =?  power  =(1 (lent power))  ['0' power]
    (crip :(weld sign body "E" ?:(up "+" "-") power))
  =/  [eup=? emag=@ud]  (old:si exp.rounded)
  ?:  eup  (crip :(weld sign `tape`digits (reap emag '0')))
  ?:  up
    =/  point=@ud  +(mag)
    (crip :(weld sign (scag point `tape`digits) "." (slag point `tape`digits)))
  (crip :(weld sign "0." (reap (dec mag) '0') `tape`digits))
::
::  a decimal mantissa and exponent rounded to 15 significant digits,
::  half up, with no trailing zeros: the digits and the last one's
::  exponent
::
++  significant
  |=  [a=@u e=@s]
  ^-  [tape @s]
  =/  count=@ud  (lent (a-co:co a))
  =/  drop=@ud  ?:((gth count 15) (sub count 15) 0)
  =/  kept=@u  (div a (pow 10 drop))
  =/  next=@ud  ?:(=(0 drop) 0 (mod (div a (pow 10 (dec drop))) 10))
  =?  kept  (gte next 5)  +(kept)
  =/  carry=?  =(kept (pow 10 15))
  =?  kept  carry  (pow 10 14)
  =/  shift=@ud  ?:(carry +(drop) drop)
  =/  zeros=@ud  0
  |-
  ?:  &((gth kept 0) =(0 (mod kept 10)))
    $(kept (div kept 10), zeros +(zeros))
  [(a-co:co kept) (sum:si e (sun:si (add shift zeros)))]
::
::  --  coercion
::
++  truthy
  |=  v=val
  ^-  ?
  ?-  -.v
    %null  %.n
    %bool  p.v
    %num  !|((nan p.v) (zero p.v))
    %str  !=('' p.v)
    ?(%arr %obj)  %.y
  ==
::
++  to-num
  |=  v=val
  ^-  @rd
  ?-  -.v
    %null  .~0
    %bool  ?:(p.v .~1 .~0)
    %num  p.v
    %str  (to-number p.v)
    ?(%arr %obj)  nan-rd
  ==
::
++  to-text
  |=  v=val
  ^-  @t
  ?-  -.v
    %null  ''
    %bool  ?:(p.v 'true' 'false')
    %num  (number-text p.v)
    %str  p.v
    %arr  'Array'
    %obj  'Object'
  ==
::
++  lower
  |=  t=@t
  ^-  tape
  (cass (trip t))
::
::  a text with its ASCII letters in upper case, as .NET's ordinal
::  ignore-case orders them (+text-order)
::
++  upper
  |=  t=@t
  ^-  tape
  (cuss (trip t))
::
::  byte order of two texts: %lt, %eq or %gt
::
++  order
  |=  [a=tape b=tape]
  ^-  ?(%lt %eq %gt)
  |-
  ?~  a  ?~(b %eq %lt)
  ?~  b  %gt
  ?:  (lth i.a i.b)  %lt
  ?:  (gth i.a i.b)  %gt
  $(a t.a, b t.b)
::
::  GitHub's loose comparison: values of different types are compared as
::  numbers; texts without case; NaN is unordered and unequal; an array
::  or object equals nothing the ship can tell is the same instance.  a
::  comparison of texts whose answer depends on how a non-ASCII letter is
::  cased is an error (+text-same, +text-order)
::
++  compare
  |=  [op=?(%eq %ne %lt %le %gt %ge) l=val r=val]
  ^-  (each ? @t)
  ?:  ?&(?=(%str -.l) ?=(%str -.r))
    ?:  ?=(?(%eq %ne) op)
      =/  same=(each ? @t)  (text-same p.l p.r)
      ?:  ?=(%| -.same)  |+p.same
      &+?:(?=(%eq op) p.same !p.same)
    =/  o=(each ?(%lt %eq %gt) @t)  (text-order p.l p.r)
    ?:  ?=(%| -.o)  |+p.o
    :-  %&
    ?-  op
      %lt  =(%lt p.o)
      %le  !=(%gt p.o)
      %gt  =(%gt p.o)
      %ge  !=(%lt p.o)
    ==
  ?:  ?|(?=(?(%arr %obj) -.l) ?=(?(%arr %obj) -.r))
    ?:  ?&(=(-.l -.r) ?=(%ne op))  &+%.y
    ?:  =(-.l -.r)  &+%.n
    &+(compare-numbers op (to-num l) (to-num r))
  &+(compare-numbers op (to-num l) (to-num r))
::
::  --  text without case (correction-02)
::
::  a letter of a text: its code point and what case can do to it.  an
::  ASCII letter is folded as +cass folds it; a %caseless code point
::  matches only itself; a %cased one may match another non-ASCII letter
::  without case; a %related one may also match an ASCII letter (ſ and s,
::  K and k, ı, İ and i, ß and the ﬀ–ﬆ ligatures), and so may every
::  unassigned code point
::
+$  kind  ?(%ascii %caseless %cased %related)
+$  letter  [c=@ k=kind]
::
::  how two aligned letters compare without case under every simple
::  (one-to-one) Unicode case mapping: %same in all, %differ in all, or
::  %unsure
::
++  pair-of
  |=  [x=letter y=letter]
  ^-  ?(%same %differ %unsure)
  ?:  =(c.x c.y)  %same
  ?:  ?&(?=(%ascii k.x) ?=(%ascii k.y))
    ?:(=((fold c.x) (fold c.y)) %same %differ)
  ?:  ?=(%ascii k.x)  ?:(?=(%related k.y) %unsure %differ)
  ?:  ?=(%ascii k.y)  ?:(?=(%related k.x) %unsure %differ)
  ?:  ?|(?=(%caseless k.x) ?=(%caseless k.y))  %differ
  %unsure
::
++  fold
  |=  c=@
  ^-  @
  ?:(&((gte c 'A') (lte c 'Z')) (add c 32) c)
::
::  an ASCII letter in upper case, for order (+text-order); equality and
::  matching fold either way
::
++  fold-up
  |=  c=@
  ^-  @
  ?:(&((gte c 'a') (lte c 'z')) (sub c 32) c)
::
::  whether every byte of a text is ASCII
::
++  ascii-text
  |=  t=@t
  ^-  ?
  (levy (rip 3 t) |=(b=@ (lth b 0x80)))
::
::  a text's letters: its code points (well-formed UTF-8; a byte that is
::  not stands for itself above the code space, caseless) with their kind
::
++  letters
  |=  t=@t
  ^-  (list letter)
  =/  n=@ud  (met 3 t)
  =/  i=@ud  0
  =|  out=(list letter)
  |-
  ?:  (gte i n)  (flop out)
  =/  one=[c=@ len=@ud]  (utf8-at t i n)
  =/  k=kind
    ?:  (lth c.one 0x80)  %ascii
    =/  tag=(unit ?)  (case-tag c.one)
    ?~  tag  %caseless
    ?:(u.tag %related %cased)
  $(i (add i len.one), out [[c.one k] out])
::
::  the code point at byte .i of a text of .n bytes and its length; a
::  byte that begins no well-formed sequence is one byte, 0x110000 above
::  its value
::
++  utf8-at
  |=  [t=@t i=@ud n=@ud]
  ^-  [c=@ len=@ud]
  =/  b=@  (cut 3 [i 1] t)
  =/  bad=[c=@ len=@ud]  [(add 0x11.0000 b) 1]
  ?:  (lth b 0x80)  [b 1]
  =/  shape=[len=@ud init=@ least=@]
    ?:  =(0xc0 (dis b 0xe0))  [2 (dis b 0x1f) 0x80]
    ?:  =(0xe0 (dis b 0xf0))  [3 (dis b 0xf) 0x800]
    ?:  =(0xf0 (dis b 0xf8))  [4 (dis b 0x7) 0x1.0000]
    [0 0 0]
  ?:  ?|(=(0 len.shape) (gth (add i len.shape) n))  bad
  =/  k=@ud  1
  =/  cp=@  init.shape
  |-
  ?:  =(k len.shape)
    ?:  ?|((lth cp least.shape) (gth cp 0x10.ffff) &((gte cp 0xd800) (lte cp 0xdfff)))  bad
    [cp len.shape]
  =/  next=@  (cut 3 [(add i k) 1] t)
  ?.  =(0x80 (dis next 0xc0))  bad
  $(k +(k), cp (add (mul cp 64) (dis next 0x3f)))
::
::  a non-ASCII code point's case: ~ when it is caseless, else whether it
::  may match an ASCII letter without case.  the records of +case-table:
::  six hex digits of a range's first code point, six of its last, then 1
::  when its code points may match an ASCII letter, 0 when they are cased
::  only.  Unicode 16.0, derived by .scratch/workflow/out/correction-02/
::  derive-case-table.py: every code point whose upper, lower, title or
::  case-folded form (full mappings, a superset of the simple ones) is not
::  itself, or which is another's single-letter mapping, and every
::  unassigned one (a later version may case a letter there)
::
++  case-tag
  |=  c=@
  ^-  (unit ?)
  =/  table=@t  case-table
  =/  lo=@ud  0
  =/  hi=@ud  (div (met 3 table) 13)
  |-
  ?:  (gte lo hi)  ~
  =/  mid=@ud  (div (add lo hi) 2)
  =/  rec=@  (cut 3 [(mul 13 mid) 13] table)
  ?:  (lth c (hex-at rec 0))  $(hi mid)
  ?:  (gth c (hex-at rec 6))  $(lo +(mid))
  `=('1' (cut 3 [12 1] rec))
::
::  six lower-case hex digits at byte .at of a record
::
++  hex-at
  |=  [rec=@ at=@ud]
  ^-  @
  =/  i=@ud  0
  =/  acc=@  0
  |-
  ?:  =(6 i)  acc
  =/  d=@  (cut 3 [(add at i) 1] rec)
  $(i +(i), acc (add (mul 16 acc) ?:((lte d '9') (sub d '0') (sub d 87))))
::
::  whether two texts are equal without case: identical up to ASCII case,
::  or (simple mappings keep lengths) told apart by a letter no mapping
::  can make equal; else an error
::
++  text-same
  |=  [a=@t b=@t]
  ^-  (each ? @t)
  ?:  =(a b)  &+%.y
  ?:  =((lower a) (lower b))  &+%.y
  ?:  ?&((ascii-text a) (ascii-text b))  &+%.n
  =/  xs=(list letter)  (letters a)
  =/  ys=(list letter)  (letters b)
  ?.  =((lent xs) (lent ys))  &+%.n
  =/  unsure=?  %.n
  |-
  ?~  xs  ?:(unsure |+(case-refusal a b) &+%.y)
  ?~  ys  &+%.n
  =/  p=?(%same %differ %unsure)  (pair-of i.xs i.ys)
  ?:  ?=(%differ p)  &+%.n
  $(xs t.xs, ys t.ys, unsure |(unsure ?=(%unsure p)))
::
::  two texts' order without case, as GitHub's runner orders them
::  (String.Compare with OrdinalIgnoreCase; correction-03): an ASCII
::  letter is folded to upper case, so the marks between the two cases
::  ([ \ ] ^ _ `) sort after every letter (a < _), after a matching
::  non-ASCII prefix as well.  at the first letters that differ, an ASCII
::  letter is before any non-ASCII one no mapping can make ASCII; else
::  (two differing non-ASCII letters, or a pair that may be equal) an error
::
++  text-order
  |=  [a=@t b=@t]
  ^-  (each ?(%lt %eq %gt) @t)
  ?:  ?&((ascii-text a) (ascii-text b))  &+(order (upper a) (upper b))
  =/  xs=(list letter)  (letters a)
  =/  ys=(list letter)  (letters b)
  |-
  ?~  xs  &+?~(ys %eq %lt)
  ?~  ys  &+%gt
  =/  p=?(%same %differ %unsure)  (pair-of i.xs i.ys)
  ?:  ?=(%same p)  $(xs t.xs, ys t.ys)
  ?:  ?=(%unsure p)  |+(order-refusal a b)
  ?:  ?&(?=(%ascii k.i.xs) ?=(%ascii k.i.ys))
    &+?:((lth (fold-up c.i.xs) (fold-up c.i.ys)) %lt %gt)
  ?:  ?=(%ascii k.i.xs)  &+%lt
  ?:  ?=(%ascii k.i.ys)  &+%gt
  |+(order-refusal a b)
::
::  how a part matches a text at its first letter: %yes, %no, or %maybe
::  (only without case of a non-ASCII letter)
::
++  match-at
  |=  [hs=(list letter) ns=(list letter)]
  ^-  ?(%yes %no %maybe)
  =/  unsure=?  %.n
  |-
  ?~  ns  ?:(unsure %maybe %yes)
  ?~  hs  %no
  =/  p=?(%same %differ %unsure)  (pair-of i.hs i.ns)
  ?:  ?=(%differ p)  %no
  $(hs t.hs, ns t.ns, unsure |(unsure ?=(%unsure p)))
::
++  text-starts
  |=  [whole=@t part=@t]
  ^-  (each ? @t)
  ?:  ?&((ascii-text whole) (ascii-text part))
    =/  w=tape  (lower whole)
    =/  p=tape  (lower part)
    &+=(p (scag (lent p) w))
  =/  hs=(list letter)  (letters whole)
  =/  ns=(list letter)  (letters part)
  ?:  (gth (lent ns) (lent hs))  &+%.n
  =/  m=?(%yes %no %maybe)  (match-at hs ns)
  ?-  m
    %yes  &+%.y
    %no  &+%.n
    %maybe  |+(match-refusal 'startsWith' whole part)
  ==
::
++  text-ends
  |=  [whole=@t part=@t]
  ^-  (each ? @t)
  ?:  ?&((ascii-text whole) (ascii-text part))
    =/  w=tape  (lower whole)
    =/  p=tape  (lower part)
    &+?&((lte (lent p) (lent w)) =(p (slag (sub (lent w) (lent p)) w)))
  =/  hs=(list letter)  (letters whole)
  =/  ns=(list letter)  (letters part)
  ?:  (gth (lent ns) (lent hs))  &+%.n
  =/  m=?(%yes %no %maybe)  (match-at (slag (sub (lent hs) (lent ns)) hs) ns)
  ?-  m
    %yes  &+%.y
    %no  &+%.n
    %maybe  |+(match-refusal 'endsWith' whole part)
  ==
::
::  whether a text contains a part without case, as GitHub's runner finds
::  it (IndexOf with OrdinalIgnoreCase): an empty part is in every text,
::  the empty one too (correction-03; +find never finds an empty list).
::  an ASCII part in a text no letter of which may match an ASCII letter
::  is found exactly as in an ASCII text; otherwise every alignment is
::  tried, and only an alignment that may match (and none that does) is
::  an error
::
++  text-contains
  |=  [whole=@t part=@t]
  ^-  (each ? @t)
  ?:  =('' part)  &+%.y
  ?:  ?&((ascii-text whole) (ascii-text part))
    &+?=(^ (find (lower part) (lower whole)))
  =/  hs=(list letter)  (letters whole)
  ?:  ?&((ascii-text part) !(lien hs |=(x=letter ?=(%related k.x))))
    &+?=(^ (find (lower part) (lower whole)))
  =/  ns=(list letter)  (letters part)
  ?~  ns  &+%.y
  =/  need=@ud  (lent ns)
  =/  left=@ud  (lent hs)
  =/  maybe=?  %.n
  |-
  ?:  (lth left need)
    ?:(maybe |+(match-refusal 'contains' whole part) &+%.n)
  ?~  hs  &+%.n
  =/  m=?(%yes %no %maybe)  (match-at hs ns)
  ?:  ?=(%yes m)  &+%.y
  $(hs t.hs, left (dec left), maybe |(maybe ?=(%maybe m)))
::
::  array membership: an element equal to the item (loose equality).  an
::  element whose equality cannot be decided is an error only when none
::  is equal
::
++  member
  |=  [items=(list val) item=val]
  ^-  (each val @t)
  =|  unsure=(unit @t)
  |-
  ?~  items  ?~(unsure &+[%bool %.n] |+u.unsure)
  =/  c=(each ? @t)  (compare %eq i.items item)
  ?:  ?=(%| -.c)  $(items t.items, unsure ?~(unsure `p.c unsure))
  ?:  p.c  &+[%bool %.y]
  $(items t.items)
::
::  the errors: what was compared, and the limit
::
++  case-limit
  ' (the ship decides case for ASCII letters only; GitHub does not document how it cases non-ASCII letters)'
::
++  case-refusal
  |=  [a=@t b=@t]
  ^-  @t
  %+  rap  3
  :~  'comparing text without case is not supported for non-ASCII letters: '
      (quote (shown a))  ' and '  (quote (shown b))
      ' differ only where a non-ASCII letter may match without case'  case-limit
  ==
::
++  order-refusal
  |=  [a=@t b=@t]
  ^-  @t
  %+  rap  3
  :~  'ordering text without case is not supported for non-ASCII letters: '
      (quote (shown a))  ' and '  (quote (shown b))
      ' first differ at a non-ASCII letter'  case-limit
  ==
::
++  match-refusal
  |=  [fn=@t whole=@t part=@t]
  ^-  @t
  %+  rap  3
  :~  fn  ' without case is not supported for non-ASCII letters: whether '
      (quote (shown part))  ' is in '  (quote (shown whole))
      ' depends on how a non-ASCII letter is cased'  case-limit
  ==
::
++  lookup-refusal
  |=  [name=@t key=@t]
  ^-  @t
  %+  rap  3
  :~  'a property name without case is not supported for non-ASCII letters: '
      (quote (shown name))  ' may or may not name the property '  (quote (shown key))
      case-limit
  ==
::
::  the case table (+case-tag): 871 records, 11.323 bytes, sha-256
::  5f239f18a070b10749424adb5d33625fc71076813de95b4b6ded2ca03545f446 of
::  the text, folded into one constant when the library is built
::
++  case-table
  ^-  @t
  ^~
  %+  rap  3
  :~  '0000b50000b500000c00000d600000d80000de00000df0000df10000e00000f600000f800012f0000130000131100013200013700001390001480000149000149100014a00017e000017f00017f100018000018c000018e0001a900001ac0001b900001bc0001bd00001bf0001bf00001c40001ef00001f0'
      '0001f010001f10002200000222000233000023a00025400002560002570000259000259000025b00025c00002600002610000263000266000026800026c000026f00026f00002710002720000275000275000027d00027d00002800002800000282000283000028700028c0000292000292000029d00029e'
      '0000345000345000037000037300003760003770000378000379100037b00037d000037f00037f00003800003831000386000386000038800038a000038b00038b100038c00038c000038d00038d100038e0003a100003a20003a210003a30003d100003d50003f500003f70003fb00003fd000481000048'
      'a00052f0000530000530100053100055600005570005581000561000587000058b00058c100059000059010005c80005cf10005eb0005ee10005f50005ff100070e00070e100074b00074c10007b20007bf10007fb0007fc100082e00082f100083f00083f100085c00085d100085f00085f100086b00086'
      'f100088f00088f10008920008961000984000984100098d00098e100099100099210009a90009a910009b10009b110009b30009b510009ba0009bb10009c50009c610009c90009ca10009cf0009d610009d80009db10009de0009de10009e40009e510009ff000a001000a04000a041000a0b000a0e1000a'
      '11000a121000a29000a291000a31000a311000a34000a341000a37000a371000a3a000a3b1000a3d000a3d1000a43000a461000a49000a4a1000a4e000a501000a52000a581000a5d000a5d1000a5f000a651000a77000a801000a84000a841000a8e000a8e1000a92000a921000aa9000aa91000ab1000a'
      'b11000ab4000ab41000aba000abb1000ac6000ac61000aca000aca1000ace000acf1000ad1000adf1000ae4000ae51000af2000af81000b00000b001000b04000b041000b0d000b0e1000b11000b121000b29000b291000b31000b311000b34000b341000b3a000b3b1000b45000b461000b49000b4a1000'
      'b4e000b541000b58000b5b1000b5e000b5e1000b64000b651000b78000b811000b84000b841000b8b000b8d1000b91000b911000b96000b981000b9b000b9b1000b9d000b9d1000ba0000ba21000ba5000ba71000bab000bad1000bba000bbd1000bc3000bc51000bc9000bc91000bce000bcf1000bd1000'
      'bd61000bd8000be51000bfb000bff1000c0d000c0d1000c11000c111000c29000c291000c3a000c3b1000c45000c451000c49000c491000c4e000c541000c57000c571000c5b000c5c1000c5e000c5f1000c64000c651000c70000c761000c8d000c8d1000c91000c911000ca9000ca91000cb4000cb4100'
      '0cba000cbb1000cc5000cc51000cc9000cc91000cce000cd41000cd7000cdc1000cdf000cdf1000ce4000ce51000cf0000cf01000cf4000cff1000d0d000d0d1000d11000d111000d45000d451000d49000d491000d50000d531000d64000d651000d80000d801000d84000d841000d97000d991000db200'
      '0db21000dbc000dbc1000dbe000dbf1000dc7000dc91000dcb000dce1000dd5000dd51000dd7000dd71000de0000de51000df0000df11000df5000e001000e3b000e3e1000e5c000e801000e83000e831000e85000e851000e8b000e8b1000ea4000ea41000ea6000ea61000ebe000ebf1000ec5000ec510'
      '00ec7000ec71000ecf000ecf1000eda000edb1000ee0000eff1000f48000f481000f6d000f701000f98000f981000fbd000fbd1000fcd000fcd1000fdb000fff10010a00010c500010c60010c610010c70010c700010c80010cc10010cd0010cd00010ce0010cf10010d00010fa00010fd0010ff00012490'
      '01249100124e00124f10012570012571001259001259100125e00125f1001289001289100128e00128f10012b10012b110012b60012b710012bf0012bf10012c10012c110012c60012c710012d70012d710013110013111001316001317100135b00135c100137d00137f100139a00139f10013a00013f50'
      '0013f60013f710013f80013fd00013fe0013ff100169d00169f10016f90016ff100171600171e100173700173f100175400175f100176d00176d1001771001771100177400177f10017de0017df10017ea0017ef10017fa0017ff100181a00181f100187900187f10018ab0018af10018f60018ff100191f'
      '00191f100192c00192f100193c00193f1001941001943100196e00196f100197500197f10019ac0019af10019ca0019cf10019db0019dd1001a1c001a1d1001a5f001a5f1001a7d001a7e1001a8a001a8f1001a9a001a9f1001aae001aaf1001acf001aff1001b4d001b4d1001bf4001bfb1001c38001c3a'
      '1001c4a001c4c1001c80001c8a0001c8b001c8f1001c90001cba0001cbb001cbc1001cbd001cbf0001cc8001ccf1001cfb001cff1001d79001d790001d7d001d7d0001d8e001d8e0001e00001e950001e96001e9a1001e9b001e9b0001e9e001e9e1001ea0001f150001f16001f171001f18001f1d0001f1'
      'e001f1f1001f20001f450001f46001f471001f48001f4d0001f4e001f4f1001f50001f570001f58001f581001f59001f590001f5a001f5a1001f5b001f5b0001f5c001f5c1001f5d001f5d0001f5e001f5e1001f5f001f7d0001f7e001f7f1001f80001fb40001fb5001fb51001fb6001fbc0001fbe001fb'
      'e0001fc2001fc40001fc5001fc51001fc6001fcc0001fd0001fd30001fd4001fd51001fd6001fdb0001fdc001fdc1001fe0001fec0001ff0001ff11001ff2001ff40001ff5001ff51001ff6001ffc0001fff001fff10020650020651002072002073100208f00208f100209d00209f10020c10020cf10020'
      'f10020ff1002126002126000212a00212a100212b00212b0002132002132000214e00214e000216000217f0002183002184000218c00218f100242a00243f100244b00245f10024b60024e90002b74002b751002b96002b961002c00002c700002c72002c730002c75002c760002c7e002ce30002ceb002c'
      'ee0002cf2002cf30002cf4002cf81002d00002d250002d26002d261002d27002d270002d28002d2c1002d2d002d2d0002d2e002d2f1002d68002d6e1002d71002d7e1002d97002d9f1002da7002da71002daf002daf1002db7002db71002dbf002dbf1002dc7002dc71002dcf002dcf1002dd7002dd71002'
      'ddf002ddf1002e5e002e7f1002e9a002e9a1002ef4002eff1002fd6002fef1003040003040100309700309810031000031041003130003130100318f00318f10031e60031ee100321f00321f100a48d00a48f100a4c700a4cf100a62c00a63f100a64000a66d000a68000a69b000a6f800a6ff100a72200a'
      '72f000a73200a76f000a77900a787000a78b00a78d000a79000a794000a79600a7ae000a7b000a7cd000a7ce00a7cf100a7d000a7d1000a7d200a7d2100a7d400a7d4100a7d600a7dc000a7dd00a7f1100a7f500a7f6000a82d00a82f100a83a00a83f100a87800a87f100a8c600a8cd100a8da00a8df100'
      'a95400a95e100a97d00a97f100a9ce00a9ce100a9da00a9dd100a9ff00a9ff100aa3700aa3f100aa4e00aa4f100aa5a00aa5b100aac300aada100aaf700ab00100ab0700ab08100ab0f00ab10100ab1700ab1f100ab2700ab27100ab2f00ab2f100ab5300ab53000ab6c00ab6f100ab7000abbf000abee00'
      'abef100abfa00abff100d7a400d7af100d7c700d7ca100d7fc00d7ff100fa6e00fa6f100fada00fb12100fb1300fb17000fb1800fb1c100fb3700fb37100fb3d00fb3d100fb3f00fb3f100fb4200fb42100fb4500fb45100fbc300fbd2100fd9000fd91100fdc800fdce100fdd000fdef100fe1a00fe1f10'
      '0fe5300fe53100fe6700fe67100fe6c00fe6f100fe7500fe75100fefd00fefe100ff0000ff00100ff2100ff3a000ff4100ff5a000ffbf00ffc1100ffc800ffc9100ffd000ffd1100ffd800ffd9100ffdd00ffdf100ffe700ffe7100ffef00fff8100fffe00ffff101000c01000c1010027010027101003b0'
      '1003b101003e01003e101004e01004f101005e01007f10100fb0100ff10101030101061010134010136101018f01018f101019d01019f10101a10101cf10101fe01027f101029d01029f10102d10102df10102fc0102ff101032401032c101034b01034f101037b01037f101039e01039e10103c40103c71'
      '0103d60103ff101040001044f001049e01049f10104aa0104af10104b00104d300104d40104d710104d80104fb00104fc0104ff101052801052f101056401056e101057001057a001057b01057b101057c01058a001058b01058b101058c0105920010593010593101059401059500105960105961010597'
      '0105a100105a20105a210105a30105b100105b20105b210105b30105b900105ba0105ba10105bb0105bc00105bd0105bf10105f40105ff101073701073f101075601075f101076801077f101078601078610107b10107b110107bb0107ff101080601080710108090108091010836010836101083901083b'
      '101083d01083e1010856010856101089f0108a610108b00108df10108f30108f310108f60108fa101091c01091e101093a01093e101094001097f10109b80109bb10109d00109d11010a04010a041010a07010a0b1010a14010a141010a18010a181010a36010a371010a3b010a3e1010a49010a4f1010a5'
      '9010a5f1010aa0010abf1010ae7010aea1010af7010aff1010b36010b381010b56010b571010b73010b771010b92010b981010b9d010ba81010bb0010bff1010c49010c7f1010c80010cb20010cb3010cbf1010cc0010cf20010cf3010cf91010d28010d2f1010d3a010d3f1010d50010d650010d66010d6'
      '81010d70010d850010d86010d8d1010d90010e5f1010e7f010e7f1010eaa010eaa1010eae010eaf1010eb2010ec11010ec5010efb1010f28010f2f1010f5a010f6f1010f8a010faf1010fcc010fdf1010ff7010fff101104e011051101107601107e10110c30110cc10110ce0110cf10110e90110ef10110'
      'fa0110ff1011135011135101114801114f101117701117f10111e00111e010111f50111ff1011212011212101124201127f10112870112871011289011289101128e01128e101129e01129e10112aa0112af10112eb0112ef10112fa0112ff1011304011304101130d01130e101131101131210113290113'
      '2910113310113311011334011334101133a01133a1011345011346101134901134a101134e01134f1011351011356101135801135c1011364011365101136d01136f101137501137f101138a01138a101138c01138d101138f01138f10113b60113b610113c10113c110113c30113c410113c60113c61011'
      '3cb0113cb10113d60113d610113d90113e010113e30113ff101145c01145c101146201147f10114c80114cf10114da01157f10115b60115b710115de0115ff101164501164f101165a01165f101166d01167f10116ba0116bf10116ca0116cf10116e40116ff101171b01171c101172c01172f1011747011'
      '7ff101183c01189f10118a00118df00118f30118fe1011907011908101190a01190b101191401191410119170119171011936011936101193901193a101194701194f101195a01199f10119a80119a910119d80119d910119e50119ff1011a48011a4f1011aa3011aaf1011af9011aff1011b0a011bbf101'
      '1be2011bef1011bfa011bff1011c09011c091011c37011c371011c46011c4f1011c6d011c6f1011c90011c911011ca8011ca81011cb7011cff1011d07011d071011d0a011d0a1011d37011d391011d3b011d3b1011d3e011d3e1011d48011d4f1011d5a011d5f1011d66011d661011d69011d691011d8f01'
      '1d8f1011d92011d921011d99011d9f1011daa011edf1011ef9011eff1011f11011f111011f3b011f3d1011f5b011faf1011fb1011fbf1011ff2011ffe101239a0123ff101246f01246f101247501247f1012544012f8f1012ff3012fff101345601345f10143fb0143ff10146470160ff101613a0167ff10'
      '16a39016a3f1016a5f016a5f1016a6a016a6d1016abf016abf1016aca016acf1016aee016aef1016af6016aff1016b46016b4f1016b5a016b5a1016b62016b621016b78016b7c1016b90016d3f1016d7a016e3f1016e40016e7f0016e9b016eff1016f4b016f4e1016f88016f8e1016fa0016fdf1016fe50'
      '16fef1016ff2016fff10187f80187ff1018cd6018cfe1018d0901afef101aff401aff4101affc01affc101afff01afff101b12301b131101b13301b14f101b15301b154101b15601b163101b16801b16f101b2fc01bbff101bc6b01bc6f101bc7d01bc7f101bc8901bc8f101bc9a01bc9b101bca401cbff1'
      '01ccfa01ccff101ceb401ceff101cf2e01cf2f101cf4701cf4f101cfc401cfff101d0f601d0ff101d12701d128101d1eb01d1ff101d24601d2bf101d2d401d2df101d2f401d2ff101d35701d35f101d37901d3ff101d45501d455101d49d01d49d101d4a001d4a1101d4a301d4a4101d4a701d4a8101d4ad'
      '01d4ad101d4ba01d4ba101d4bc01d4bc101d4c401d4c4101d50601d506101d50b01d50c101d51501d515101d51d01d51d101d53a01d53a101d53f01d53f101d54501d545101d54701d549101d55101d551101d6a601d6a7101d7cc01d7cd101da8c01da9a101daa001daa0101dab001deff101df1f01df24'
      '101df2b01dfff101e00701e007101e01901e01a101e02201e022101e02501e025101e02b01e02f101e06e01e08e101e09001e0ff101e12d01e12f101e13e01e13f101e14a01e14d101e15001e28f101e2af01e2bf101e2fa01e2fe101e30001e4cf101e4fa01e5cf101e5fb01e5fe101e60001e7df101e7e'
      '701e7e7101e7ec01e7ec101e7ef01e7ef101e7ff01e7ff101e8c501e8c6101e8d701e8ff101e90001e943001e94c01e94f101e95a01e95d101e96001ec70101ecb501ed00101ed3e01edff101ee0401ee04101ee2001ee20101ee2301ee23101ee2501ee26101ee2801ee28101ee3301ee33101ee3801ee3'
      '8101ee3a01ee3a101ee3c01ee41101ee4301ee46101ee4801ee48101ee4a01ee4a101ee4c01ee4c101ee5001ee50101ee5301ee53101ee5501ee56101ee5801ee58101ee5a01ee5a101ee5c01ee5c101ee5e01ee5e101ee6001ee60101ee6301ee63101ee6501ee66101ee6b01ee6b101ee7301ee73101ee'
      '7801ee78101ee7d01ee7d101ee7f01ee7f101ee8a01ee8a101ee9c01eea0101eea401eea4101eeaa01eeaa101eebc01eeef101eef201efff101f02c01f02f101f09401f09f101f0af01f0b0101f0c001f0c0101f0d001f0d0101f0f601f0ff101f1ae01f1e5101f20301f20f101f23c01f23f101f24901f2'
      '4f101f25201f25f101f26601f2ff101f6d801f6db101f6ed01f6ef101f6fd01f6ff101f77701f77a101f7da01f7df101f7ec01f7ef101f7f101f7ff101f80c01f80f101f84801f84f101f85a01f85f101f88801f88f101f8ae01f8af101f8bc01f8bf101f8c201f8ff101fa5401fa5f101fa6e01fa6f101f'
      'a7d01fa7f101fa8a01fa8e101fac701facd101fadd01fade101faea01faef101faf901faff101fb9301fb93101fbfa01ffff102a6e002a6ff102b73a02b73f102b81e02b81f102cea202ceaf102ebe102ebef102ee5e02f7ff102fa1e02ffff103134b03134f10323b00e000010e00020e001f10e00800e0'
      '0ff10e01f00effff10ffffe0fffff110fffe10ffff1'
  ==
::
++  compare-numbers
  |=  [op=?(%eq %ne %lt %le %gt %ge) a=@rd b=@rd]
  ^-  ?
  ?:  |((nan a) (nan b))  ?=(%ne op)
  =/  same=?  |(&((zero a) (zero b)) =(a b))
  ?-  op
    %eq  same
    %ne  !same
    %lt  &(!same (lth:rd a b))
    %le  |(same (lth:rd a b))
    %gt  &(!same (gth:rd a b))
    %ge  |(same (gth:rd a b))
  ==
::
::  --  JSON
::
++  from-json
  |=  j=json
  ^-  val
  ?~  j  [%null ~]
  ?-  -.j
    %b  [%bool p.j]
    %n  [%num (to-number (crip (trip p.j)))]
    %s  [%str p.j]
    %a  [%arr (turn p.j from-json)]
    %o  [%obj (~(run by p.j) from-json)]
  ==
::
::  toJSON: two-space indentation, object keys in byte order
::
++  to-json
  |=  v=val
  ^-  @t
  (crip (json-tape v ""))
::
++  json-tape
  |=  [v=val indent=tape]
  ^-  tape
  ?-  -.v
    %null  "null"
    %bool  ?:(p.v "true" "false")
    %num  (trip (number-text p.v))
    %str  (quoted p.v)
      %arr
    ?~  p.v  "[]"
    =/  inner=tape  (weld indent "  ")
    =/  items=(list tape)  (turn p.v |=(x=val (weld inner (json-tape x inner))))
    :(weld "[\0a" (join-tapes items ",\0a") "\0a" indent "]")
  ::
      %obj
    ?:  =(~ p.v)  "\{}"
    =/  inner=tape  (weld indent "  ")
    =/  keys=(list @t)
      %+  sort
        ~(tap in ~(key by p.v))
      |=([a=@t b=@t] =(%lt (order (trip a) (trip b))))
    =/  items=(list tape)
      %+  turn  keys
      |=  k=@t
      :(weld inner (quoted k) ": " (json-tape (~(got by p.v) k) inner))
    :(weld "\{\0a" (join-tapes items ",\0a") "\0a" indent "}")
  ==
::
++  join-tapes
  |=  [items=(list tape) sep=tape]
  ^-  tape
  ?~  items  ~
  =/  out=tape  i.items
  |-
  ?~  t.items  out
  $(items t.items, out :(weld out sep i.t.items))
::
++  quoted
  |=  t=@t
  ^-  tape
  =/  out=tape
    %-  zing
    %+  turn  (trip t)
    |=  c=@tD
    ^-  tape
    ?:  =('"' c)  "\\\""
    ?:  =('\\' c)  "\\\\"
    ?:  =('\0a' c)  "\\n"
    ?:  =('\0d' c)  "\\r"
    ?:  =('\09' c)  "\\t"
    ?:  =('\08' c)  "\\b"
    ?:  =('\0c' c)  "\\f"
    ?:  (lth c 32)
      =/  hex=tape  ((x-co:co 4) c)
      (weld "\\u" hex)
    ~[c]
  :(weld "\"" out "\"")
::
::  --  evaluation
::
::  an expression's value, or why it has none: evaluation is bounded at
::  max-fuel steps and every text at max-value bytes
::
++  eval
  |=  [e=expr:ci s=scope]
  ^-  (each val @t)
  =/  r  (run e s max-fuel)
  ?:  ?=(%| -.r)  r
  &+v.p.r
::
+$  ran  (each [v=val filtered=? fuel=@ud] @t)
::
++  run
  |=  [e=expr:ci s=scope fuel=@ud]
  ^-  ran
  ?:  =(0 fuel)
    |+(rap 3 ~['the evaluation exceeds its bound of ' (crip (a-co:co max-fuel)) ' steps'])
  =.  fuel  (dec fuel)
  ?-  -.e
    %null  &+[[%null ~] %.n fuel]
    %bool  &+[[%bool p.e] %.n fuel]
    %num  &+[[%num p.e] %.n fuel]
    %str  &+[[%str p.e] %.n fuel]
    %ctx  &+[(context-of p.e s) %.n fuel]
  ::
      %prop
    =/  r=ran  $(e of.e)
    ?:  ?=(%| -.r)  r
    =/  x=(each val @t)  (property v.p.r filtered.p.r name.e)
    ?:  ?=(%| -.x)  |+p.x
    &+[p.x filtered.p.r fuel.p.r]
  ::
      %index
    =/  r=ran  $(e of.e)
    ?:  ?=(%| -.r)  r
    =/  i=ran  $(e at.e, fuel fuel.p.r)
    ?:  ?=(%| -.i)  i
    =/  x=(each val @t)  (element v.p.r filtered.p.r v.p.i)
    ?:  ?=(%| -.x)  |+p.x
    &+[p.x filtered.p.r fuel.p.i]
  ::
      %star
    =/  r=ran  $(e of.e)
    ?:  ?=(%| -.r)  r
    &+[(filter v.p.r filtered.p.r) %.y fuel.p.r]
  ::
      %not
    =/  r=ran  $(e p.e)
    ?:  ?=(%| -.r)  r
    &+[[%bool !(truthy v.p.r)] %.n fuel.p.r]
  ::
      %cmp
    =/  l=ran  $(e l.e)
    ?:  ?=(%| -.l)  l
    =/  r=ran  $(e r.e, fuel fuel.p.l)
    ?:  ?=(%| -.r)  r
    =/  c=(each ? @t)  (compare op.e v.p.l v.p.r)
    ?:  ?=(%| -.c)  |+p.c
    &+[[%bool p.c] %.n fuel.p.r]
  ::
      %and
    =/  l=ran  $(e l.e)
    ?:  ?=(%| -.l)  l
    ?.  (truthy v.p.l)  &+[v.p.l %.n fuel.p.l]
    =/  r=ran  $(e r.e, fuel fuel.p.l)
    ?:  ?=(%| -.r)  r
    &+[v.p.r %.n fuel.p.r]
  ::
      %or
    =/  l=ran  $(e l.e)
    ?:  ?=(%| -.l)  l
    ?:  (truthy v.p.l)  &+[v.p.l %.n fuel.p.l]
    =/  r=ran  $(e r.e, fuel fuel.p.l)
    ?:  ?=(%| -.r)  r
    &+[v.p.r %.n fuel.p.r]
  ::
      %call
    ?:  =('case' fn.e)  (run-case args.e s fuel)
    ?:  =('always' fn.e)  &+[[%bool %.y] %.n fuel]
    ?:  =('success' fn.e)  &+[[%bool success.s] %.n fuel]
    ?:  =('failure' fn.e)  &+[[%bool failure.s] %.n fuel]
    ?:  =('cancelled' fn.e)  &+[[%bool cancelled.s] %.n fuel]
    =/  args=(list expr:ci)  args.e
    =|  vals=(list val)
    |-  ^-  ran
        ?^  args
          =/  a=ran  ^$(e i.args)
          ?:  ?=(%| -.a)  a
          $(args t.args, vals [v.p.a vals], fuel fuel.p.a)
        =/  out=(each val @t)  (apply fn.e (flop vals))
        ?:  ?=(%| -.out)  out
        ?:  ?&(?=(%str -.p.out) (gth (met 3 p.p.out) max-value))
          |+'a value exceeds 1 MiB'
        &+[p.out %.n fuel]
  ==
::
::  case(pred, value, ..., default): the value of the first true
::  predicate; only that value is evaluated
::
++  run-case
  |=  [args=(list expr:ci) s=scope fuel=@ud]
  ^-  ran
  ?~  args  &+[[%null ~] %.n fuel]
  ?~  t.args  (run i.args s fuel)
  =/  p=ran  (run i.args s fuel)
  ?:  ?=(%| -.p)  p
  ?:  (truthy v.p.p)  (run i.t.args s fuel.p.p)
  $(args t.t.args, fuel fuel.p.p)
::
++  context-of
  |=  [name=@t s=scope]
  ^-  val
  ?+  name  [%null ~]
    %github  github.s
    %needs  needs.s
    %vars  vars.s
    %inputs  inputs.s
    %steps  steps.s
  ==
::
::  a property, read without case; over a filter's result, of each item.
::  a name that may or may not match a key only without case of a
::  non-ASCII letter is an error (+lookup)
::
++  property
  |=  [v=val filtered=? name=@t]
  ^-  (each val @t)
  ?:  ?&(filtered ?=(%arr -.v))
    =/  items=(list val)  p.v
    =|  out=(list val)
    |-
    ?~  items  &+[%arr (flop out)]
    =/  x=(each val @t)  (property i.items %.n name)
    ?:  ?=(%| -.x)  x
    $(items t.items, out [p.x out])
  ?.  ?=(%obj -.v)  &+[%null ~]
  (lookup p.v name)
::
::  a key by name: the key itself, else the first key equal without case
::  (+text-same); none equal and one undecided is an error
::
++  lookup
  |=  [m=(map @t val) name=@t]
  ^-  (each val @t)
  =/  hit=(unit val)  (~(get by m) name)
  ?^  hit  &+u.hit
  =/  pairs=(list [k=@t v=val])  ~(tap by m)
  =|  unsure=(unit @t)
  |-
  ?~  pairs  ?~(unsure &+[%null ~] |+u.unsure)
  =/  same=(each ? @t)  (text-same k.i.pairs name)
  ?:  ?=(%| -.same)
    $(pairs t.pairs, unsure ?~(unsure `(lookup-refusal name k.i.pairs) unsure))
  ?:  p.same  &+v.i.pairs
  $(pairs t.pairs)
::
::  an index: an array's integral element, an object's property, each
::  item's over a filter's result
::
++  element
  |=  [v=val filtered=? at=val]
  ^-  (each val @t)
  ?:  ?&(filtered ?=(%arr -.v))
    =/  items=(list val)  p.v
    =|  out=(list val)
    |-
    ?~  items  &+[%arr (flop out)]
    =/  x=(each val @t)  (element i.items %.n at)
    ?:  ?=(%| -.x)  x
    $(items t.items, out [p.x out])
  ?:  ?=(%obj -.v)
    ?.  ?=(%str -.at)  &+[%null ~]
    (lookup p.v p.at)
  ?.  ?=(%arr -.v)  &+[%null ~]
  ?.  ?=(%num -.at)  &+[%null ~]
  ?:  (zero p.at)  &+(fall (head-of p.v) [%null ~])
  ?:  |((nan p.at) (negative p.at))  &+[%null ~]
  =/  d=dn  (drg:rd p.at)
  ?.  ?=(%d -.d)  &+[%null ~]
  =/  [up=? mag=@ud]  (old:si e.d)
  ?.  up  &+[%null ~]
  =/  index=@ud  (mul a.d (pow 10 mag))
  ?:  (gte index (lent p.v))  &+[%null ~]
  &+(snag index p.v)
::
++  head-of
  |=  items=(list val)
  ^-  (unit val)
  ?~(items ~ `i.items)
::
::  the object filter: an array's items, an object's values in key order;
::  over a filter's result, each item filtered
::
++  filter
  |=  [v=val filtered=?]
  ^-  val
  ?:  ?&(filtered ?=(%arr -.v))
    [%arr (zing (turn p.v |=(x=val =/(f (filter x %.n) ?:(?=(%arr -.f) p.f ~)))))]
  ?+  -.v  [%arr ~]
    %arr  v
      %obj
    =/  keys=(list @t)
      %+  sort
        ~(tap in ~(key by p.v))
      |=([a=@t b=@t] =(%lt (order (trip a) (trip b))))
    [%arr (turn keys |=(k=@t (~(got by p.v) k)))]
  ==
::
::  a function of its evaluated arguments
::
++  apply
  |=  [fn=@t args=(list val)]
  ^-  (each val @t)
  =/  a=val  ?~(args [%null ~] i.args)
  =/  b=val  ?~(args [%null ~] ?~(t.args [%null ~] i.t.args))
  ?+  fn  |+(rap 3 ~['unknown function ' fn])
      %contains
    ?:  ?=(%arr -.a)  (member p.a b)
    ?:  ?=(%obj -.a)  &+[%bool %.n]
    ?:  ?=(?(%arr %obj) -.b)  &+[%bool %.n]
    =/  r=(each ? @t)  (text-contains (to-text a) (to-text b))
    ?:  ?=(%| -.r)  |+p.r
    &+[%bool p.r]
  ::
      %startswith
    ?:  ?|(?=(?(%arr %obj) -.a) ?=(?(%arr %obj) -.b))  &+[%bool %.n]
    =/  r=(each ? @t)  (text-starts (to-text a) (to-text b))
    ?:  ?=(%| -.r)  |+p.r
    &+[%bool p.r]
  ::
      %endswith
    ?:  ?|(?=(?(%arr %obj) -.a) ?=(?(%arr %obj) -.b))  &+[%bool %.n]
    =/  r=(each ? @t)  (text-ends (to-text a) (to-text b))
    ?:  ?=(%| -.r)  |+p.r
    &+[%bool p.r]
  ::
      %format
    =/  out=(each @t @t)  (format-text (to-text a) ?~(args ~ t.args))
    ?:  ?=(%| -.out)  out
    &+[%str p.out]
  ::
      %join
    =/  sep=@t  ?:((gte (lent args) 2) (to-text b) ',')
    ?.  ?=(%arr -.a)  &+[%str (to-text a)]
    &+[%str (rap 3 (join-texts (turn p.a to-text) sep))]
::
    %tojson  &+[%str (to-json a)]
  ::
      %fromjson
    ?.  ?=(%str -.a)  |+'fromJSON takes text'
    =/  parsed=(unit json)  (de:json:html p.a)
    ?~  parsed  |+(rap 3 ~['fromJSON: ' (shown (quote p.a)) ' is not JSON'])
    &+(from-json u.parsed)
  ==
::
++  join-texts
  |=  [items=(list @t) sep=@t]
  ^-  (list @t)
  ?~  items  ~
  [i.items (zing (turn t.items |=(t=@t ~[sep t])))]
::
++  quote
  |=  t=@t
  ^-  @t
  (rap 3 ~['\'' t '\''])
::
::  format('…{0}…', …): {N} is the Nth value as text, {{ and }} are
::  braces; a placeholder past the values, or an unclosed one, is an
::  error
::
++  format-text
  |=  [pattern=@t values=(list val)]
  ^-  (each @t @t)
  =/  chars=tape  (trip pattern)
  =|  out=tape
  |-
  ?~  chars  &+(crip (flop out))
  ?:  ?&(=('{' i.chars) ?=([%'{' *] t.chars))  $(chars t.t.chars, out ['{' out])
  ?:  ?&(=('}' i.chars) ?=([%'}' *] t.chars))  $(chars t.t.chars, out ['}' out])
  ?:  =('}' i.chars)
    |+(rap 3 ~['format: a } without its { in ' (quote (shown pattern))])
  ?.  =('{' i.chars)  $(chars t.chars, out [i.chars out])
  =/  close=(unit @ud)  (find "}" t.chars)
  ?~  close  |+(rap 3 ~['format: an unclosed { in ' (quote (shown pattern))])
  =/  digits=tape  (scag u.close t.chars)
  ?.  ?&(?=(^ digits) (levy `tape`digits |=(c=@tD &((gte c '0') (lte c '9')))))
    |+(rap 3 ~['format: {' (crip digits) '} is not a placeholder'])
  =/  index=@ud  (scan digits dem:ag-plain)
  ?:  (gte index (lent values))
    |+(rap 3 ~['format: {' (crip digits) '} has no value'])
  %=  $
    chars  (slag +(u.close) t.chars)
    out  (weld (flop (trip (to-text (snag index values)))) out)
  ==
::
::  a template's text: each expression's value as text
::
++  interpolate
  |=  [parts=(list part:ci) s=scope]
  ^-  (each @t @t)
  =|  out=(list @t)
  |-
  ?~  parts
    =/  text=@t  (rap 3 (flop out))
    ?:  (gth (met 3 text) max-value)  |+'the value exceeds 1 MiB'
    &+text
  ?:  ?=(%lit -.i.parts)  $(parts t.parts, out [p.i.parts out])
  =/  v=(each val @t)  (eval p.i.parts s)
  ?:  ?=(%| -.v)  v
  $(parts t.parts, out [(to-text p.v) out])
::
::  a value as a reason shows it
::
++  render
  |=  v=val
  ^-  @t
  ?-  -.v
    %null  'null'
    %bool  ?:(p.v 'true' 'false')
    %num  (number-text p.v)
    %str  ?:(=('' p.v) 'an empty string' (quote (shown p.v)))
    %arr  'an array'
    %obj  'an object'
  ==
::
::  --  the contexts a run's jobs read
::
::  github, as the ship holds a run: the event and its payload, the ref,
::  the source, the actor, the workflow's name and the job
::
++  github-of
  |=  [event=@t payload=@t ref=@t sha=@t actor=@t workflow=@t job=@t]
  ^-  val
  =/  parsed=(unit json)  ?:(=('' payload) ~ (de:json:html payload))
  =/  branch=?  =("refs/heads/" (scag 11 (trip ref)))
  =/  tag=?  =("refs/tags/" (scag 10 (trip ref)))
  :-  %obj
  %-  malt
  ^-  (list [@t val])
  :~  ['event_name' [%str event]]
      ['event' ?~(parsed [%obj ~] (from-json u.parsed))]
      ['ref' [%str ref]]
      ['ref_name' [%str ?:(branch (crip (slag 11 (trip ref))) ?:(tag (crip (slag 10 (trip ref))) ref))]]
      ['ref_type' [%str ?:(branch 'branch' ?:(tag 'tag' ''))]]
      ['sha' [%str sha]]
      ['actor' [%str actor]]
      ['triggering_actor' [%str actor]]
      ['workflow' [%str workflow]]
      ['job' [%str job]]
      ['base_ref' [%str '']]
      ['head_ref' [%str '']]
  ==
::
::  inputs: a manual run's admitted values, typed; an input without a
::  value is false when it is a boolean and empty text otherwise, as act
::  reads it.  a push has none
::
++  inputs-of
  |=  inputs=(list admitted-input:ci)
  ^-  val
  :-  %obj
  %-  malt
  %+  turn  inputs
  |=  i=admitted-input:ci
  ^-  [@t val]
  :-  id.i
  ?~  value.i
    ?:(?=(%boolean kind.i) [%bool %.n] [%str ''])
  ?-  -.u.value.i
    %boolean  [%bool p.u.value.i]
    %number  [%num (to-number p.u.value.i)]
    %string  [%str p.u.value.i]
  ==
::
::  needs: each need's result and its resolved declared outputs
::
++  needs-of
  |=  entries=(list need-entry:ci)
  ^-  val
  :-  %obj
  %-  malt
  %+  turn  entries
  |=  n=need-entry:ci
  ^-  [@t val]
  :-  id.n
  :-  %obj
  %-  malt
  ^-  (list [@t val])
  :~  ['result' [%str result.n]]
      ['outputs' [%obj (malt (turn outputs.n |=([k=@t v=@t] [k [%str v]])))]]
  ==
::
::  the needs context act reads (the projection's carrier) and the signed
::  manifest binds: {"<id>": {"outputs": {...}, "result": "..."}}
::
++  needs-text
  |=  entries=(list need-entry:ci)
  ^-  @t
  %-  en:json:html
  %-  pairs:enjs:format
  %+  turn  entries
  |=  n=need-entry:ci
  :-  id.n
  %-  pairs:enjs:format
  :~  ['outputs' (pairs:enjs:format (turn outputs.n |=([k=@t v=@t] [k s+v])))]
      ['result' s+result.n]
  ==
::
::  steps: each step of the job (one-element step ids) and its outputs;
::  a later value of the same step and name replaces an earlier one, as
::  act records it.  a composite action's own steps are not the job's
::
++  steps-of
  |=  outputs=(list step-output:ci)
  ^-  val
  =|  acc=(map @t (map @t val))
  =.  acc
    %+  roll  outputs
    |=  [o=step-output:ci m=_acc]
    ?.  ?=([@ ~] step.o)  m
    =/  step=(map @t val)  (~(gut by m) i.step.o ~)
    (~(put by m) i.step.o (~(put by step) name.o [%str value.o]))
  :-  %obj
  %-  ~(run by acc)
  |=  outs=(map @t val)
  [%obj (malt ~[['outputs' [%obj outs]]])]
--
