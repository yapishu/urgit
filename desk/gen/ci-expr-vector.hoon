::  ci-expr-vector: job expressions on the ship (CI-EXPR-2, Delivery 1B).
::  The compiled wires embedded below are the pinned compiler's own
::  output for runner/internal/plan/testdata/d1b/*.yml (wire_pin_test.go
::  pins the same bytes on the Go side).  Checked here:
::    - the wire: refusals carried, malformed trees refused node by node,
::      the depth and node bounds, contexts and functions per field;
::    - semantics: loose equality and coercion, text without case, NaN,
::      G15 numbers, toJSON/fromJSON, format, join, contains, case, the
::      object filter, short-circuit && and ||;
::    - decisions on the fixtures: waiting for needs, implicit success()
::      over ancestors, always() and failure() after a failure, a skipped
::      intermediary, an infrastructure error read as failure, typed
::      manual inputs (false and zero), an evaluation error refusing its
::      job, a state-3 %output-eq kept at its meaning;
::    - outputs: two steps emitting the same name kept apart, a composite
::      action's own step not read as the job's, declared outputs resolved
::      by step, the needs context text and its digest, the value bound.
::  Every case names the verdict it expects; prints `passed=N of=M` and
::  ends in a loobean.
::
/-  ci
/+  ci-expr, ci-plan, ci-event, ci-dispatch
:-  %say
|=  *
:-  %noun
=/  wire-outputs=@t
  %+  rap  3
  :~  '[{"id":"producer","needs":[],"cond":null,"outputs":[{"name":"verdict","v'
      '":2,"text":"${{ steps.emit.outputs.raw }}","line":11,"col":16,"parts":[{'
      '"expr":{"k":"prop","of":{"k":"prop","of":{"k":"prop","of":{"k":"ctx","na'
      'me":"steps"},"name":"emit"},"name":"outputs"},"name":"raw"}}]},{"name":"'
      'first","v":2,"text":"${{ steps.one.outputs.same }}","line":13,"col":14,"'
      'parts":[{"expr":{"k":"prop","of":{"k":"prop","of":{"k":"prop","of":{"k":'
      '"ctx","name":"steps"},"name":"one"},"name":"outputs"},"name":"same"}}]},'
      '{"name":"second","v":2,"text":"${{ steps.two.outputs.same }}","line":14,'
      '"col":15,"parts":[{"expr":{"k":"prop","of":{"k":"prop","of":{"k":"prop",'
      '"of":{"k":"ctx","name":"steps"},"name":"two"},"name":"outputs"},"name":"'
      'same"}}]},{"name":"empty","v":2,"text":"${{ steps.emit.outputs.blank }}"'
      ',"line":15,"col":14,"parts":[{"expr":{"k":"prop","of":{"k":"prop","of":{'
      '"k":"prop","of":{"k":"ctx","name":"steps"},"name":"emit"},"name":"output'
      's"},"name":"blank"}}]},{"name":"quoted","v":2,"text":"${{ steps.emit.out'
      'puts.quoted }}","line":16,"col":15,"parts":[{"expr":{"k":"prop","of":{"k'
      '":"prop","of":{"k":"prop","of":{"k":"ctx","name":"steps"},"name":"emit"}'
      ',"name":"outputs"},"name":"quoted"}}]},{"name":"json","v":2,"text":"${{ '
      'steps.emit.outputs.json }}","line":17,"col":13,"parts":[{"expr":{"k":"pr'
      'op","of":{"k":"prop","of":{"k":"prop","of":{"k":"ctx","name":"steps"},"n'
      'ame":"emit"},"name":"outputs"},"name":"json"}}]},{"name":"composed","v":'
      '2,"text":"release-${{ steps.one.outputs.same }}","line":18,"col":17,"par'
      'ts":[{"lit":"release-"},{"expr":{"k":"prop","of":{"k":"prop","of":{"k":"'
      'prop","of":{"k":"ctx","name":"steps"},"name":"one"},"name":"outputs"},"n'
      'ame":"same"}}]}]},{"id":"consumer","needs":["producer"],"cond":{"v":2,"t'
      'ext":"needs.producer.outputs.verdict == \'go\' \\u0026\\u0026 needs.producer'
      '.result == \'success\'","line":38,"col":9,"expr":{"k":"and","l":{"k":"cmp"'
      ',"op":"eq","l":{"k":"prop","of":{"k":"prop","of":{"k":"prop","of":{"k":"'
      'ctx","name":"needs"},"name":"producer"},"name":"outputs"},"name":"verdic'
      't"},"r":{"k":"str","s":"go"}},"r":{"k":"cmp","op":"eq","l":{"k":"prop","'
      'of":{"k":"prop","of":{"k":"ctx","name":"needs"},"name":"producer"},"name'
      '":"result"},"r":{"k":"str","s":"success"}}}},"outputs":[]},{"id":"stoppe'
      'd-consumer","needs":["producer"],"cond":{"v":2,"text":"needs.producer.ou'
      'tputs.verdict == \'stop\'","line":61,"col":9,"expr":{"k":"cmp","op":"eq","'
      'l":{"k":"prop","of":{"k":"prop","of":{"k":"prop","of":{"k":"ctx","name":'
      '"needs"},"name":"producer"},"name":"outputs"},"name":"verdict"},"r":{"k"'
      ':"str","s":"stop"}}},"outputs":[]}]'
  ==
=/  wire-status=@t
  %+  rap  3
  :~  '[{"id":"build","needs":[],"cond":null,"outputs":[]},{"id":"test","needs"'
      ':["build"],"cond":null,"outputs":[]},{"id":"deploy","needs":["test"],"co'
      'nd":null,"outputs":[]},{"id":"report","needs":["build","test"],"cond":{"'
      'v":2,"text":"always()","line":35,"col":9,"expr":{"k":"call","fn":"always'
      '","args":[]}},"outputs":[]},{"id":"notify","needs":["deploy"],"cond":{"v'
      '":2,"text":"failure()","line":45,"col":9,"expr":{"k":"call","fn":"failur'
      'e","args":[]}},"outputs":[]}]'
  ==
=/  wire-typed=@t
  %+  rap  3
  :~  '[{"id":"typed","needs":[],"cond":{"v":2,"text":"inputs.dry_run == false '
      '\\u0026\\u0026 toJSON(inputs.dry_run) == \'false\' \\u0026\\u0026 inputs.count'
      ' == 0 \\u0026\\u0026 toJSON(inputs.count) == \'0\'","line":20,"col":9,"expr"'
      ':{"k":"and","l":{"k":"and","l":{"k":"and","l":{"k":"cmp","op":"eq","l":{'
      '"k":"prop","of":{"k":"ctx","name":"inputs"},"name":"dry_run"},"r":{"k":"'
      'bool","b":false}},"r":{"k":"cmp","op":"eq","l":{"k":"call","fn":"tojson"'
      ',"args":[{"k":"prop","of":{"k":"ctx","name":"inputs"},"name":"dry_run"}]'
      '},"r":{"k":"str","s":"false"}}},"r":{"k":"cmp","op":"eq","l":{"k":"prop"'
      ',"of":{"k":"ctx","name":"inputs"},"name":"count"},"r":{"k":"num","n":0}}'
      '},"r":{"k":"cmp","op":"eq","l":{"k":"call","fn":"tojson","args":[{"k":"p'
      'rop","of":{"k":"ctx","name":"inputs"},"name":"count"}]},"r":{"k":"str","'
      's":"0"}}}},"outputs":[]},{"id":"coercion","needs":[],"cond":{"v":2,"text'
      '":"inputs.count == \'\' \\u0026\\u0026 inputs.count == \'0\' \\u0026\\u0026 \'ABC'
      '\' == \'abc\' \\u0026\\u0026 !(inputs.count == \'zero\')","line":26,"col":9,"ex'
      'pr":{"k":"and","l":{"k":"and","l":{"k":"and","l":{"k":"cmp","op":"eq","l'
      '":{"k":"prop","of":{"k":"ctx","name":"inputs"},"name":"count"},"r":{"k":'
      '"str","s":""}},"r":{"k":"cmp","op":"eq","l":{"k":"prop","of":{"k":"ctx",'
      '"name":"inputs"},"name":"count"},"r":{"k":"str","s":"0"}}},"r":{"k":"cmp'
      '","op":"eq","l":{"k":"str","s":"ABC"},"r":{"k":"str","s":"abc"}}},"r":{"'
      'k":"not","a":{"k":"cmp","op":"eq","l":{"k":"prop","of":{"k":"ctx","name"'
      ':"inputs"},"name":"count"},"r":{"k":"str","s":"zero"}}}}},"outputs":[]},'
      '{"id":"short-circuit","needs":[],"cond":{"v":2,"text":"inputs.dry_run \\u'
      '0026\\u0026 fromJSON(\'not json\')","line":32,"col":9,"expr":{"k":"and","l"'
      ':{"k":"prop","of":{"k":"ctx","name":"inputs"},"name":"dry_run"},"r":{"k"'
      ':"call","fn":"fromjson","args":[{"k":"str","s":"not json"}]}}},"outputs"'
      ':[]},{"id":"json","needs":[],"cond":{"v":2,"text":"fromJSON(inputs.paylo'
      'ad).level == inputs.count \\u0026\\u0026 contains(fromJSON(inputs.payload)'
      '.tags, \'A\')","line":37,"col":9,"expr":{"k":"and","l":{"k":"cmp","op":"eq'
      '","l":{"k":"prop","of":{"k":"call","fn":"fromjson","args":[{"k":"prop","'
      'of":{"k":"ctx","name":"inputs"},"name":"payload"}]},"name":"level"},"r":'
      '{"k":"prop","of":{"k":"ctx","name":"inputs"},"name":"count"}},"r":{"k":"'
      'call","fn":"contains","args":[{"k":"prop","of":{"k":"call","fn":"fromjso'
      'n","args":[{"k":"prop","of":{"k":"ctx","name":"inputs"},"name":"payload"'
      '}]},"name":"tags"},{"k":"str","s":"A"}]}}},"outputs":[]},{"id":"event-te'
      'xt","needs":[],"cond":{"v":2,"text":"github.event.inputs.dry_run == \'fal'
      'se\' \\u0026\\u0026 github.event.inputs.dry_run","line":43,"col":9,"expr":{'
      '"k":"and","l":{"k":"cmp","op":"eq","l":{"k":"prop","of":{"k":"prop","of"'
      ':{"k":"prop","of":{"k":"ctx","name":"github"},"name":"event"},"name":"in'
      'puts"},"name":"dry_run"},"r":{"k":"str","s":"false"}},"r":{"k":"prop","o'
      'f":{"k":"prop","of":{"k":"prop","of":{"k":"ctx","name":"github"},"name":'
      '"event"},"name":"inputs"},"name":"dry_run"}}},"outputs":[]},{"id":"zero-'
      'is-false","needs":[],"cond":{"v":2,"text":"inputs.count","line":48,"col"'
      ':9,"expr":{"k":"prop","of":{"k":"ctx","name":"inputs"},"name":"count"}},'
      '"outputs":[]}]'
  ==
=/  wire-eval-error=@t
  %+  rap  3
  :~  '[{"id":"broken","needs":[],"cond":{"v":2,"text":"fromJSON(\'not json\').re'
      'ady","line":6,"col":9,"expr":{"k":"prop","of":{"k":"call","fn":"fromjson'
      '","args":[{"k":"str","s":"not json"}]},"name":"ready"}},"outputs":[]},{"'
      'id":"independent","needs":[],"cond":null,"outputs":[]}]'
  ==
=/  wire-refused-context=@t
  %+  rap  3
  :~  '[{"id":"deploy","needs":[],"cond":{"v":2,"text":"env.DEPLOY == \'true\'","'
      'line":6,"col":9,"refusal":"context env is not available in a job-level i'
      'f (github, needs, vars and inputs are)"},"outputs":[]}]'
  ==
=/  wire-malformed=@t
  %+  rap  3
  :~  '[{"id":"deploy","needs":[],"cond":{"v":2,"text":"github.ref == \\"refs/he'
      'ads/master\\"","line":6,"col":9,"refusal":"syntax error at column 15: dou'
      'ble quotes are not string delimiters; use single quotes"},"outputs":[]}]'
  ==
=/  wire-oversized=@t
  %+  rap  3
  :~  '[{"id":"deploy","needs":[],"cond":{"v":2,"text":"github.ref == \'refs/hea'
      'ds/branch-0000\' || github.ref == \'refs/heads/branch-0001\' || github.ref '
      '== \'refs/heads/branch-0002\' || github.ref == \'refs/heads/branch-0003\' ||'
      ' github.ref == \'refs/heads/branch-0004\' || github.ref == \'refs/heads/bra'
      'nch-0005\' || github.ref == \'refs/heads/branch-0006\' || github.ref == \'re'
      'fs/heads/branch-0007\' || github.ref == \'refs/heads/branch-0008\' || githu'
      'b.ref == \'refs/heads/branch-0009\' || github.ref == \'refs/heads/branch-00'
      '10\' || github.ref == \'refs/heads/branch-0011\' || github.r","line":6,"col'
      '":9,"refusal":"the expression is 5036 bytes; the bound is 4096"},"output'
      's":[]}]'
  ==
::  a pinned wire as the plan's jobs: each condition and output parsed
::  by the ship's own checks
::
=/  wire-jobs
  |=  [workflow=@t text=@t]
  ^-  (list [job=(unit job:ci) refusal=(unit @t)])
  =/  parsed=(unit json)  (de:json:html text)
  ?>  ?=([~ %a *] parsed)
  %+  turn  p.u.parsed
  |=  j=json
  ^-  [(unit job:ci) (unit @t)]
  ?>  ?=([%o *] j)
  =/  id=@t  (need (text-field:ci-expr p.j 'id'))
  =/  needs-json=json  (~(got by p.j) 'needs')
  ?>  ?=([%a *] needs-json)
  =/  needs=(list @t)  (turn p.needs-json |=(n=json ?>(?=([%s *] n) p.n)))
  =/  raw-cond=(unit json)  (~(get by p.j) 'cond')
  =/  cond=(each (unit condition:ci) @t)
    ?~  raw-cond  &+~
    ?~  u.raw-cond  &+~
    =/  c=(each condition:ci @t)  (parse-condition:ci-expr u.raw-cond)
    ?:  ?=(%| -.c)  |+p.c
    &+`p.c
  ?:  ?=(%| -.cond)  [~ `p.cond]
  =/  outs-json=json  (~(got by p.j) 'outputs')
  ?>  ?=([%a *] outs-json)
  =/  outputs=(list declared-output:ci)
    %+  turn  p.outs-json
    |=  o=json
    =/  r=(each declared-output:ci @t)  (parse-output:ci-expr o)
    ?>  ?=(%& -.r)
    p.r
  [`[id workflow workflow 0 needs p.cond ~ ~ ~ `outputs] ~]
=/  plan-of
  |=  [workflow=@t text=@t]
  ^-  (list job:ci)
  (murn (wire-jobs workflow text) |=([j=(unit job:ci) *] j))
=/  job-of
  |=  [plan=(list job:ci) id=@t]
  ^-  job:ci
  =/  hits  (skim plan |=(j=job:ci =(id id.j)))
  ?>  ?=(^ hits)
  i.hits
::  standings and need entries from literal lists
::
=/  st
  |=  [workflow=@t items=(list [@t standing:ci-plan])]
  ^-  (map key:ci-plan standing:ci-plan)
  (malt (turn items |=([id=@t s=standing:ci-plan] [[workflow id] s])))
=/  status-of
  |=  s=standing:ci-plan
  ^-  attempt-status:ci
  ?+  s  %running
    %passed  %passed
    %failed  %failed
    %skipped  %skipped
    %unknown  %infrastructure-error
  ==
=/  ent
  |=  [workflow=@t items=(list [id=@t s=standing:ci-plan outs=(list [@t @t])])]
  ^-  (map key:ci-plan need-entry:ci)
  %-  malt
  %+  turn  items
  |=  [id=@t s=standing:ci-plan outs=(list [@t @t])]
  [[workflow id] [id 0v1 (status-of s) (result-word:ci-plan s) outs]]
::  the run contexts: a push, and a manual run of typed.yml with its
::  declared defaults admitted (false, 0 and the JSON text)
::
=/  push-ctx=run-context:ci-plan
  :*  'push'
      (push-payload:ci-dispatch 'refs/heads/master' (fil 3 40 '0') (fil 3 40 'a') ~zod)
      'refs/heads/master'  (fil 3 40 'a')  '~zod'  [%obj ~]  %.n
  ==
=/  typed-inputs=(list admitted-input:ci)
  :~  ['dry_run' %boolean %default `[%boolean %.n]]
      ['count' %number %default `[%number '0']]
      ['payload' %string %default `[%string '{"level":0,"tags":["a"]}']]
  ==
=/  typed-ctx
  |=  inputs=(list admitted-input:ci)
  ^-  run-context:ci-plan
  :*  'workflow_dispatch'
      (payload:ci-dispatch 'refs/heads/master' 'typed.yml' ~zod inputs)
      'refs/heads/master'  (fil 3 40 'a')  '~zod'  (inputs-of:ci-expr inputs)  %.n
  ==
=/  status-plan=(list job:ci)  (plan-of 'status.yml' wire-status)
=/  typed-plan=(list job:ci)  (plan-of 'typed.yml' wire-typed)
=/  error-plan=(list job:ci)  (plan-of 'eval-error.yml' wire-eval-error)
=/  outputs-plan=(list job:ci)  (plan-of 'outputs.yml' wire-outputs)
=/  status
  |=  [id=@t items=(list [@t standing:ci-plan])]
  ^-  decision:ci-plan
  =/  standings  (st 'status.yml' items)
  =/  entries  (ent 'status.yml' (turn items |=([i=@t s=standing:ci-plan] [i s ~])))
  (decide:ci-plan (job-of status-plan id) status-plan standings entries push-ctx)
=/  typed
  |=  [id=@t inputs=(list admitted-input:ci)]
  ^-  decision:ci-plan
  (decide:ci-plan (job-of typed-plan id) typed-plan ~ ~ (typed-ctx inputs))
::  one expression of the if field, compiled by hand as the compiler
::  would, evaluated in a scope
::
=/  num  |=(t=@t `expr:ci`[%num (to-number:ci-expr t)])
=/  str  |=(t=@t `expr:ci`[%str t])
=/  call  |=([fn=@t args=(list expr:ci)] `expr:ci`[%call fn args])
=/  cmp  |=([op=?(%eq %ne %lt %le %gt %ge) l=expr:ci r=expr:ci] `expr:ci`[%cmp op l r])
=/  ev
  |=  e=expr:ci
  ^-  (each val:ci-expr @t)
  (eval:ci-expr e empty-scope:ci-expr)
=/  is
  |=  [e=expr:ci want=val:ci-expr]
  ^-  ?
  =((ev e) &+want)
::  the producer's step outputs as act relays them: two steps emit
::  `same`, a composite action's own step emits `raw` under emit
::
=/  set-output
  |=  [step=(list @t) name=@t value=@t]
  ^-  event:ci
  :*  'outputs/producer'  'producer'  `'Main'  `'step'  step  ~  ~
      `[%set-output name value]  %.n  ''  ~2026.10.15
  ==
=/  recorded=(list step-output:ci)
  =/  events=(list event:ci)
    :~  (set-output ~['emit'] 'raw' 'stale')
        (set-output ~['emit'] 'raw' 'go')
        (set-output ~['emit'] 'blank' '')
        (set-output ~['emit'] 'undeclared' 'never published')
        (set-output ~['emit'] 'quoted' 'it\'s "quoted"\0asecond line')
        (set-output ~['emit'] 'json' '{"n":0,"ok":false,"list":["a","b"]}')
        (set-output ~['one'] 'same' 'from-one')
        (set-output ~['two'] 'same' 'from-two')
        (set-output ~['emit' 'inner'] 'raw' 'composite-substep')
    ==
  %+  roll  events
  |=  [e=event:ci acc=(list step-output:ci)]
  (need (record-output:ci-event acc e %.n))
=/  producer=job:ci  (job-of outputs-plan 'producer')
=/  producer-scope=scope:ci-expr
  :*  %:  github-of:ci-expr
        'push'
        ''
        'refs/heads/master'
        (fil 3 40 'a')
        '~zod'
        'outputs.yml'
        'producer'
      ==
      [%obj ~]  [%obj ~]  [%obj ~]  (steps-of:ci-expr recorded)  %.y  %.n  %.n
  ==
=/  resolved=(list [@t (each @t @t)])
  ?>  ?=(^ outputs.producer)
  %+  turn  u.outputs.producer
  |=  o=declared-output:ci
  [name.o (interpolate:ci-expr parts.template.o producer-scope)]
=/  published=(list [@t @t])
  (murn resolved |=([n=@t r=(each @t @t)] ?:(?=(%& -.r) `[n p.r] ~)))
=/  outputs-entries=(map key:ci-plan need-entry:ci)
  (ent 'outputs.yml' ~[['producer' %passed published]])
=/  consumer=(each condition:ci @t)
  =/  c  cond:(job-of outputs-plan 'consumer')
  ?~(c |+'none' &+u.c)
=/  results=(list [name=@t ok=?])
  :~  ::  --  the wire
    :-  'wire: every condition of the outputs, status, typed and eval-error fixtures is accepted'
    %+  levy
      %-  zing
      :~  (wire-jobs 'outputs.yml' wire-outputs)
          (wire-jobs 'status.yml' wire-status)
          (wire-jobs 'typed.yml' wire-typed)
          (wire-jobs 'eval-error.yml' wire-eval-error)
      ==
    |=([j=(unit job:ci) r=(unit @t)] &(?=(^ j) ?=(~ r)))
  ::
    :-  'wire: the compiler\'s refusal of a context is carried, by name'
    .=  ~[[~ `'context env is not available in a job-level if (github, needs, vars and inputs are)']]
    (wire-jobs 'refused-context.yml' wire-refused-context)
  ::
    :-  'wire: a malformed if is carried as the compiler\'s syntax error'
    .=  ~[[~ `'syntax error at column 15: double quotes are not string delimiters; use single quotes']]
    (wire-jobs 'malformed.yml' wire-malformed)
  ::
    :-  'wire: an oversized if is refused with its size'
    .=  ~[[~ `'the expression is 5036 bytes; the bound is 4096']]
    (wire-jobs 'oversized.yml' wire-oversized)
  ::
    :-  'wire: an unknown node kind is refused, never read as false'
    .=  |+'unknown expression node lambda'
    (parse-tree:ci-expr (need (de:json:html '{"k":"lambda"}')) %if)
  ::
    :-  'wire: a tree past the depth bound is refused'
    .=  |+'the expression nests deeper than 32'
    =/  fixed=@t  (rap 3 :(weld (reap 33 '{"k":"not","a":') ~['{"k":"null"}'] (reap 33 '}')))
    (parse-tree:ci-expr (need (de:json:html fixed)) %if)
  ::
    :-  'wire: a tree past the node bound is refused'
    .=  |+'the expression has more than 256 nodes'
    =/  args=@t  (rap 3 (join-texts:ci-expr (reap 300 '{"k":"null"}') ','))
    %+  parse-tree:ci-expr
      (need (de:json:html (rap 3 ~['{"k":"call","fn":"format","args":[' args ']}'])))
    %if
  ::
    :-  'wire: the ship checks contexts itself: steps in a job-level if is refused'
    .=  |+'context steps is not available in a job-level if (github, needs, vars and inputs are)'
    %+  parse-tree:ci-expr
      (need (de:json:html '{"k":"prop","of":{"k":"ctx","name":"steps"},"name":"a"}'))
    %if
  ::
    :-  'wire: and a github property it does not hold'
    .=  |+'github.repository is not available on the ship in this release'
    %+  parse-tree:ci-expr
      (need (de:json:html '{"k":"prop","of":{"k":"ctx","name":"github"},"name":"repository"}'))
    %if
  ::
    :-  'wire: a status function outside an if is refused'
    .=  |+'function success is only valid in an if'
    (parse-tree:ci-expr (need (de:json:html '{"k":"call","fn":"success","args":[]}')) %output)
  ::
    :-  'wire: an arity the function does not take is refused'
    .=  |+'contains takes 2 arguments, not 1'
    %+  parse-tree:ci-expr
      (need (de:json:html '{"k":"call","fn":"contains","args":[{"k":"null"}]}'))
    %if
  ::
    :-  'wire: needs.<id> named literally are found'
    .=  ~['producer' 'b']
    %-  needs-named:ci-expr
    [%and [%prop [%prop [%ctx 'needs'] 'producer'] 'result'] [%index [%ctx 'needs'] [%str 'b']]]
  ::
    ::  --  semantics
    :-  'eq: text compares without case'
    (is (cmp %eq (str 'ABC') (str 'abc')) [%bool %.y])
  ::
    :-  'eq: an empty text is the number 0, as is null'
    ?&  (is (cmp %eq (str '') (num '0')) [%bool %.y])
        (is (cmp %eq [%null ~] (num '0')) [%bool %.y])
    ==
  ::
    :-  'eq: the text true is not the boolean true (NaN against 1)'
    (is (cmp %eq (str 'true') [%bool %.y]) [%bool %.n])
  ::
    :-  'eq: NaN equals nothing and differs from everything'
    ?&  (is (cmp %eq (str 'x') (str 'x')) [%bool %.y])
        (is (cmp %eq (str 'x') (num '0')) [%bool %.n])
        (is (cmp %ne (str 'x') (num '0')) [%bool %.y])
        (is (cmp %lt (str 'x') (num '0')) [%bool %.n])
        (is (cmp %ge (str 'x') (num '0')) [%bool %.n])
    ==
  ::
    :-  'relational: numbers, and texts by byte order without case'
    ?&  (is (cmp %lt (num '-1.5') (num '2')) [%bool %.y])
        (is (cmp %gt (str 'b') (str 'A')) [%bool %.y])
        (is (cmp %le (str '10') (num '9')) [%bool %.n])
    ==
  ::
    :-  'numbers from text: trimmed, hex, octal, exponent; anything else NaN'
    ?&  =((to-number:ci-expr ' 12 ') (to-number:ci-expr '12'))
        =((to-number:ci-expr '0x1F') (sun:rd 31))
        =((to-number:ci-expr '0o17') (sun:rd 15))
        =((to-number:ci-expr '1e3') (sun:rd 1.000))
        (nan:ci-expr (to-number:ci-expr 'abc'))
        =((to-number:ci-expr '') .~0)
    ==
  ::
    :-  'numbers as text: G15'
    .=  ~['0' '1.5' '-0.25' '1E+21' '1.23456789012346E+17' '0.0001' '1E-05' '0.3' '100' 'NaN']
    %+  turn
      ~['0' '1.5' '-0.25' '1e21' '123456789012345678' '0.0001' '0.00001' '0.30000000000000004' '1e2' 'x']
    |=(t=@t (number-text:ci-expr (to-number:ci-expr t)))
  ::
    :-  'truthiness: false, 0, NaN, empty text and null are false'
    ?&  !(truthy:ci-expr [%bool %.n])
        !(truthy:ci-expr [%num .~0])
        !(truthy:ci-expr [%num nan-rd:ci-expr])
        !(truthy:ci-expr [%str ''])
        !(truthy:ci-expr [%null ~])
        (truthy:ci-expr [%str 'false'])
        (truthy:ci-expr [%arr ~])
    ==
  ::
    :-  '&& and || return an operand, and stop once decided'
    ?&  (is [%and [%num .~0] (call 'fromjson' ~[(str 'not json')])] [%num .~0])
        (is [%or (str 'x') (call 'fromjson' ~[(str 'not json')])] [%str 'x'])
        (is [%or [%null ~] (str 'y')] [%str 'y'])
        =(%| -:(ev [%or [%null ~] (call 'fromjson' ~[(str 'not json')])]))
    ==
  ::
    :-  'fromJSON then toJSON: two-space indentation, keys in order'
    .=  &+[%str '{\0a  "a": [\0a    1,\0a    "x"\0a  ],\0a  "b": null\0a}']
    (ev (call 'tojson' ~[(call 'fromjson' ~[(str '{"b":null,"a":[1,"x"]}')])]))
  ::
    :-  'toJSON of a scalar: false, 0, null and text'
    ?&  (is (call 'tojson' ~[[%bool %.n]]) [%str 'false'])
        (is (call 'tojson' ~[(num '0')]) [%str '0'])
        (is (call 'tojson' ~[[%null ~]]) [%str 'null'])
        (is (call 'tojson' ~[(str 'a"b\0a')]) [%str '"a\\"b\\n"'])
    ==
  ::
    :-  'fromJSON of text that is not JSON is an error, never null'
    .=  |+'fromJSON: \'not json\' is not JSON'
    (ev (call 'fromjson' ~[(str 'not json')]))
  ::
    :-  'index and property: integral array index, property without case'
    ?&  (is [%index (call 'fromjson' ~[(str '[10,20]')]) (num '1')] [%num (sun:rd 20)])
        (is [%index (call 'fromjson' ~[(str '[10,20]')]) (num '1.5')] [%null ~])
        (is [%prop (call 'fromjson' ~[(str '{"Key":1}')]) 'kEY'] [%num .~1])
    ==
  ::
    :-  'the object filter: an object\'s values, then each one\'s property'
    .=  &+[%arr ~[[%str 'failure'] [%str 'success']]]
    %-  ev
    [%prop [%star (call 'fromjson' ~[(str '{"b":{"result":"success"},"a":{"result":"failure"}}')])] 'result']
  ::
    :-  'contains: a substring without case, an array element by loose equality'
    ?&  (is (call 'contains' ~[(str 'Hello world') (str 'LLO')]) [%bool %.y])
        (is (call 'contains' ~[(call 'fromjson' ~[(str '["a","B"]')]) (str 'b')]) [%bool %.y])
        (is (call 'contains' ~[(call 'fromjson' ~[(str '[0]')]) (str '')]) [%bool %.y])
    ==
  ::
    :-  'startsWith and endsWith without case'
    ?&  (is (call 'startswith' ~[(str 'refs/heads/main') (str 'REFS/')]) [%bool %.y])
        (is (call 'endswith' ~[(str 'a.yml') (str '.YML')]) [%bool %.y])
        (is (call 'endswith' ~[(str 'a') (str 'longer')]) [%bool %.n])
    ==
  ::
    :-  'format: placeholders, escaped braces, a missing value is an error'
    ?&  (is (call 'format' ~[(str '{0}-{1}') (str 'a') (num '1')]) [%str 'a-1'])
        (is (call 'format' ~[(str '{{x}}')]) [%str '{x}'])
        =(%| -:(ev (call 'format' ~[(str '{2}') (str 'a')])))
    ==
  ::
    :-  'join: an array with a separator, a comma by default'
    ?&  %+  is
          (call 'join' ~[(call 'fromjson' ~[(str '["a",1,true]')]) (str '+')])
        [%str 'a+1+true']
        (is (call 'join' ~[(call 'fromjson' ~[(str '["a","b"]')])]) [%str 'a,b'])
    ==
  ::
    :-  'case: the first true predicate\'s value, only it evaluated'
    ?&  (is (call 'case' ~[[%bool %.n] (str 'a') [%bool %.y] (str 'b') (str 'c')]) [%str 'b'])
        (is (call 'case' ~[[%bool %.n] (call 'fromjson' ~[(str 'x')]) (str 'd')]) [%str 'd'])
    ==
  ::
    :-  'the evaluation is bounded in steps'
    =(%| -:(run:ci-expr [%not [%not [%not [%null ~]]]] empty-scope:ci-expr 2))
  ::
    :-  'a value past 1 MiB is an error'
    =/  big=@t  (fil 3 700.000 'x')
    =/  sc=scope:ci-expr  empty-scope:ci-expr
    =.  steps.sc  (steps-of:ci-expr ~[[~['a'] 'big' big %.n]])
    =/  part=part:ci  [%expr [%prop [%prop [%prop [%ctx 'steps'] 'a'] 'outputs'] 'big']]
    =(|+'the value exceeds 1 MiB' (interpolate:ci-expr ~[part part] sc))
  ::
    ::  --  decisions: status functions (status.yml)
    :-  'status: an ordinary dependent waits, then is skipped naming the failure'
    ?&  =([%wait 'waiting for build'] (status 'test' ~[['build' %running]]))
        =([%skip 'skipped: build failed' ~] (status 'test' ~[['build' %failed]]))
    ==
  ::
    :-  'status: a skipped intermediary skips its dependent too'
    .=  [%skip 'skipped: test was skipped' ~]
    (status 'deploy' ~[['build' %failed] ['test' %skipped]])
  ::
    :-  'status: always() runs whatever its needs did, once they are terminal'
    ?&  =([%wait 'waiting for test'] (status 'report' ~[['build' %failed]]))
        .=  [%run 'if "always()" is true' `'true']
        (status 'report' ~[['build' %failed] ['test' %skipped]])
    ==
  ::
    :-  'status: failure() runs through a skipped chain for an ancestor\'s failure'
    .=  [%run 'if "failure()" is true' `'true']
    (status 'notify' ~[['build' %failed] ['test' %skipped] ['deploy' %skipped]])
  ::
    :-  'status: on success the ordinary jobs run and failure() skips'
    ?&  =([%run 'every prerequisite succeeded' ~] (status 'test' ~[['build' %passed]]))
        .=  [%skip 'if "failure()" is false' `'false']
        (status 'notify' ~[['build' %passed] ['test' %passed] ['deploy' %passed]])
    ==
  ::
    :-  'status: an infrastructure error is never success: it reads as failure'
    ?&  .=  [%skip 'skipped: build had an infrastructure error' ~]
        (status 'test' ~[['build' %unknown]])
        .=  [%run 'if "failure()" is true' `'true']
        (status 'notify' ~[['build' %unknown] ['test' %skipped] ['deploy' %skipped]])
    ==
  ::
    :-  'status: an unrelated job\'s failure does not suppress a ready job'
    =([%run 'no prerequisites' ~] (status 'build' ~[['report' %failed]]))
  ::
    :-  'status: cancelled() reads the run, always() runs, success() does not'
    =/  job=job:ci  (job-of status-plan 'report')
    =/  ctx=run-context:ci-plan  push-ctx(cancelled %.y)
    =/  standings  (st 'status.yml' ~[['build' %passed] ['test' %passed]])
    =/  entries  (ent 'status.yml' ~[['build' %passed ~] ['test' %passed ~]])
    ?&  .=  [%run 'if "cancelled()" is true' `'true']
        %:  decide:ci-plan
          job(cond `[%if 'cancelled()' 1 1 [%call 'cancelled' ~]])
          status-plan
          standings
          entries
          ctx
        ==
        .=  [%skip 'if "cancelled()" is false' `'false']
        %:  decide:ci-plan
          job(cond `[%if 'cancelled()' 1 1 [%call 'cancelled' ~]])
          status-plan
          standings
          entries
          push-ctx
        ==
    ==
  ::
    ::  --  decisions: typed manual inputs (typed.yml)
    :-  'typed: false and zero arrive as a boolean and a number'
    =(%run -:(typed 'typed' typed-inputs))
  ::
    :-  'typed: the same zero sent as text is not the number'
    =/  as-text=(list admitted-input:ci)
      :~  ['dry_run' %boolean %default `[%boolean %.n]]
          ['count' %number %supplied `[%string '0']]
          ['payload' %string %default `[%string '{"level":0,"tags":["a"]}']]
      ==
    =(%skip -:(typed 'typed' as-text))
  ::
    :-  'typed: loose equality and coercion'
    =(%run -:(typed 'coercion' typed-inputs))
  ::
    :-  'typed: && stops at false before invalid JSON'
    .=  [%skip 'if "inputs.dry_run && fromJSON(\'not json\')" is false' `'false']
    (typed 'short-circuit' typed-inputs)
  ::
    :-  'typed: fromJSON of an input, contains without case'
    =(%run -:(typed 'json' typed-inputs))
  ::
    :-  'typed: github.event.inputs carries the boolean as truthy text'
    .=  [%run 'if "github.event.inputs.dry_run == \'false\' && github.event.inputs.dry_run" is \'false\'' `'\'false\'']
    (typed 'event-text' typed-inputs)
  ::
    :-  'typed: zero is false'
    =([%skip 'if "inputs.count" is 0' `'0'] (typed 'zero-is-false' typed-inputs))
  ::
    ::  --  decisions: an evaluation error refuses its job
    :-  'error: a value that cannot be computed refuses the job with the reason'
    .=  [%error 'if "fromJSON(\'not json\').ready" could not be evaluated: fromJSON: \'not json\' is not JSON']
    (decide:ci-plan (job-of error-plan 'broken') error-plan ~ ~ push-ctx)
  ::
    :-  'error: an independent job of the same run still runs'
    =([%run 'no prerequisites' ~] (decide:ci-plan (job-of error-plan 'independent') error-plan ~ ~ push-ctx))
  ::
    ::  --  outputs (outputs.yml)
    :-  'outputs: two steps\' outputs of one name are two entries; a step\'s later value replaces its own'
    ?&  =(8 (lent recorded))
        =(~['go'] (murn recorded |=(o=step-output:ci ?.(&(=(~['emit'] step.o) =('raw' name.o)) ~ `value.o))))
        =(2 (lent (skim recorded |=(o=step-output:ci =('same' name.o)))))
    ==
  ::
    :-  'outputs: a composite action\'s own step is not one of the job\'s steps'
    ::  correction-02: +property answers (each val @t); every read here
    ::  must succeed, and an error is a value that is not 'go'
    =/  read
      |=  [v=val:ci-expr name=@t]
      ^-  val:ci-expr
      =/  r=(each val:ci-expr @t)  (property:ci-expr v %.n name)
      ?:(?=(%| -.r) [%str (cat 3 'error: ' p.r)] p.r)
    =([%str 'go'] (read (read (read (steps-of:ci-expr recorded) 'emit') 'outputs') 'raw'))
  ::
    :-  'outputs: each declared output resolves from its own step'
    .=  :~  ['verdict' &+'go']
            ['first' &+'from-one']
            ['second' &+'from-two']
            ['empty' &+'']
            ['quoted' &+'it\'s "quoted"\0asecond line']
            ['json' &+'{"n":0,"ok":false,"list":["a","b"]}']
            ['composed' &+'release-from-one']
        ==
    resolved
  ::
    :-  'outputs: an undeclared output is never published'
    !(lien published |=([n=@t *] =('undeclared' n)))
  ::
    :-  'outputs: the consumer\'s condition reads the declared output and the result'
    ?.  ?=(%& -.consumer)  %.n
    =/  job=job:ci  (job-of outputs-plan 'consumer')
    =/  standings  (st 'outputs.yml' ~[['producer' %passed]])
    .=  [%run 'if "needs.producer.outputs.verdict == \'go\' && needs.producer.result == \'success\'" is true' `'true']
    (decide:ci-plan job outputs-plan standings outputs-entries push-ctx)
  ::
    :-  'outputs: a consumer whose condition is false is skipped with the value'
    =/  standings  (st 'outputs.yml' ~[['producer' %passed]])
    .=  [%skip 'if "needs.producer.outputs.verdict == \'stop\'" is false' `'false']
    %:  decide:ci-plan
      (job-of outputs-plan 'stopped-consumer')
      outputs-plan
      standings
      outputs-entries
      push-ctx
    ==
  ::
    :-  'outputs: the needs context text is GitHub\'s shape, with the values as data'
    =/  text=@t  (needs-text:ci-expr ~[['producer' 0v1 %passed 'success' published]])
    =/  back=(unit json)  (de:json:html text)
    ?&  ?=(^ back)
        .=  u.back
        %-  pairs:enjs:format
        :~  :-  'producer'
            %-  pairs:enjs:format
            :~  ['result' s+'success']
                ['outputs' (pairs:enjs:format (turn published |=([n=@t v=@t] [n s+v])))]
            ==
        ==
        =(64 (met 3 (context-digest:ci-dispatch text)))
    ==
  ::
    ::  --  a state-3 plan's gate keeps its admitted meaning
    :-  'legacy: an output-eq reads the recorded output exactly, after every need passed'
    =/  job=job:ci  (job-of status-plan 'test')
    =/  gated=job:ci  job(cond `[%output-eq 'build' 'go' 'true'])
    =/  standings  (st 'status.yml' ~[['build' %passed]])
    ?&  .=  [%run 'needs.build.outputs.go is "true"' `'"true"']
        %:  decide:ci-plan
          gated
          status-plan
          standings
          (ent 'status.yml' ~[['build' %passed ~[['go' 'true']]]])
          push-ctx
        ==
        .=  [%skip 'output not set: needs.build.outputs.go' ~]
        %:  decide:ci-plan
          gated
          status-plan
          standings
          (ent 'status.yml' ~[['build' %passed ~]])
          push-ctx
        ==
        .=  [%skip 'needs build failed' ~]
        (decide:ci-plan gated status-plan (st 'status.yml' ~[['build' %failed]]) ~ push-ctx)
    ==
  ==
=/  failures=(list @t)
  (murn results |=([name=@t ok=?] ?:(ok ~ `name)))
~&  [%ci-expr-vector passed=(sub (lent results) (lent failures)) of=(lent results)]
?~  failures  %.y
~&  [%ci-expr-vector-failures failures]
%.n
