::  ci-concurrency-vector: workflow concurrency groups on the ship
::  (CI-CONCURRENCY-1).  The two wires embedded below are the real
::  producers' bytes, captured by runner/internal/daemon
::  concurrency_capture_test.go from the fake ship's handler — the
::  resolver's trigger catalog (ERPit's suite.yml and fixtures.yml, cut
::  before env:, with lane.yml, plain.yml and refused.yml) and the
::  planner's jobs of lane.yml — and pinned there byte for byte; plan
::  vector_embed_test.go checks this file embeds exactly them.  Checked
::  here, through the production arms of lib/ci-concurrency, lib/ci-plan
::  and lib/ci-trigger:
::    - the wire: every captured workflow's concurrency parses (none, a
::      group, a refusal) and ERPit's group and cancel-in-progress keep
::      their parts; a catalog without the key is unknown, never "no
::      group"; a malformed one refuses the catalog; a job-level
::      concurrency refuses the plan with the reason;
::    - ERPit's own expressions: on refs/heads/master two pushes land in
::      groups of their own (the sha is in the group) and both run to the
::      end; on a feature branch the newer push cancels the older; a pull
::      request reads refs/pull/<n>/merge as act gives its jobs;
::    - GitHub's rules: the newcomer's cancel-in-progress decides; true
::      cancels the run in progress and the waiting one; false waits; a
::      group keeps one waiting run, a newer arrival cancelling the older
::      whatever the flags; groups ignore case; a waiting run starts when
::      the run in progress finishes;
::    - cancellation: one workflow's run is cancelled inside its
::      candidate and no other workflow's job is touched; a running job is
::      stopped unless its if holds when cancelled() does (always()); a
::      run cancelled while it waited runs no job; a privileged attempt
::      closes unknown, needing review; a cancelled run's result is
::      cancelled, never passed, and a required one never lands;
::    - what takes part: trial twins and resolver records never;
::    - pull request labels: adding ci:fixtures while a synchronize run is
::      in flight cancels it in ERPit's group refs/pull/<n>/merge, and
::      ERPit's label expression, pinned from the compiler, is true on the
::      label run's real payload and false without the label;
::    - the gate, evaluation errors refusing a workflow's run, an unknown
::      catalog, and every bunt.
::  The helpers and scenarios are arms of one core, so the subject stays
::  shallow for the pinned analyzer.  Every case names the verdict it
::  expects; prints `passed=N of=M` and ends in a loobean.  NOT RUN in the
::  source stage that wrote it: it needs a ship.
::
/-  ci, git
/+  ci-concurrency, ci-expr, ci-plan, ci-provenance, ci-trigger, git-codec
:-  %say
|=  *
:-  %noun
=/  capture-catalog-1=@t
  %+  rap  3
  :~  '{"version":1,"workflows":[{"workflow":"fixtures.yml","name":"fixtures","'
      'events":[{"event":"push","refusal":"","branches":{"ignore":false,"patter'
      'ns":[{"text":"master","negated":false,"tokens":[{"t":"lit","c":"master"}'
      ']}]},"tags":null,"paths":null,"types":null,"typesDeclared":false,"schedu'
      'les":null,"line":50,"col":3},{"event":"pull_request","refusal":"","branc'
      'hes":null,"tags":null,"paths":null,"types":["opened","synchronize","reop'
      'ened","labeled"],"typesDeclared":true,"schedules":null,"line":53,"col":3'
      '},{"event":"workflow_dispatch","refusal":"","branches":null,"tags":null,'
      '"paths":null,"types":null,"typesDeclared":false,"schedules":null,"line":'
      '57,"col":3}],"refusal":"","concurrency":{"v":2,"kind":"group","group":{"'
      'text":"${{ github.workflow }}-${{ github.ref }}-${{ github.ref == \'refs/'
      'heads/master\' \\u0026\\u0026 github.sha || \'head\' }}","line":91,"col":10,"'
      'parts":[{"expr":{"k":"prop","of":{"k":"ctx","name":"github"},"name":"wor'
      'kflow"}},{"lit":"-"},{"expr":{"k":"prop","of":{"k":"ctx","name":"github"'
      '},"name":"ref"}},{"lit":"-"},{"expr":{"k":"or","l":{"k":"and","l":{"k":"'
      'cmp","op":"eq","l":{"k":"prop","of":{"k":"ctx","name":"github"},"name":"'
      'ref"},"r":{"k":"str","s":"refs/heads/master"}},"r":{"k":"prop","of":{"k"'
      ':"ctx","name":"github"},"name":"sha"}},"r":{"k":"str","s":"head"}}}]},"c'
      'ancel":{"text":"${{ github.ref != \'refs/heads/master\' }}","line":92,"col'
      '":23,"expr":{"k":"cmp","op":"ne","l":{"k":"prop","of":{"k":"ctx","name":'
      '"github"},"name":"ref"},"r":{"k":"str","s":"refs/heads/master"}}}}},{"wo'
      'rkflow":"lane.yml","name":"Lane","events":[{"event":"push","refusal":"",'
      '"branches":null,"tags":null,"paths":null,"types":null,"typesDeclared":fa'
      'lse,"schedules":null,"line":2,"col":6},{"event":"workflow_dispatch","ref'
      'usal":"","branches":null,"tags":null,"paths":null,"types":null,"typesDec'
      'lared":false,"schedules":null,"line":2,"col":12}],"refusal":"","concurre'
      'ncy":{"v":2,"kind":"group","group":{"text":"lane-${{ github.ref_name }}"'
      ',"line":3,"col":14,"parts":[{"lit":"lane-"},{"expr":{"k":"prop","of":{"k'
      '":"ctx","name":"github"},"name":"ref_name"}}]},"cancel":{"text":"","line'
      '":0,"col":0,"value":false}}},{"workflow":"plain.yml","name":"Plain","eve'
      'nts":[{"event":"push","refusal":"","branches":null,"tags":null,"paths":n'
      'ull,"types":null,"typesDeclared":false,"schedules":null,"line":2,"col":5'
      '}],"refusal":"","concurrency":{"v":2,"kind":"none"}},{"workflow":"refuse'
      'd.yml","name":"Refused group","events":[{"event":"push","refusal":"","br'
      'anches":null,"tags":null,"paths":null,"types":null,"typesDeclared":false'
      ',"schedules":null,"line":2,"col":5}],"refusal":"","concurrency":{"v":2,"'
      'kind":"refused","text":"yes","line":5,"col":23,"refusal":"cancel-in-prog'
      'ress is true, false or one ${{ }} expression, not \\"yes\\""}},{"workflow"'
      ':"suite.yml","name":"suite","events":[{"event":"pull_request","refusal":'
      '"","branches":null,"tags":null,"paths":null,"types":["opened","synchroni'
      'ze","reopened"],"typesDeclared":false,"schedules":null,"line":25,"col":3'
      '},{"event":"push","refusal":"","branches":{"ignore":false,"patterns":[{"'
      'text":"master","negated":false,"tokens":[{"t":"lit","c":"master"}]}]},"t'
      'ags":null,"paths":null,"types":null,"typesDeclared":false,"schedules":nu'
      'll,"line":26,"col":3},{"event":"workflow_dispatch","refusal":"","branche'
      's":null,"tags":null,"paths":null,"types":null,"typesDeclared":false,"sch'
      'edules":null,"line":29,"col":3}],"refusal":"","concurrency":{"v":2,"kind'
      '":"group","group":{"text":"${{ github.workflow }}-${{ github.ref }}-${{ '
  ==
=/  capture-catalog-2=@t
  %+  rap  3
  :~  'github.ref == \'refs/heads/master\' \\u0026\\u0026 github.sha || \'head\' }}",'
      '"line":47,"col":10,"parts":[{"expr":{"k":"prop","of":{"k":"ctx","name":"'
      'github"},"name":"workflow"}},{"lit":"-"},{"expr":{"k":"prop","of":{"k":"'
      'ctx","name":"github"},"name":"ref"}},{"lit":"-"},{"expr":{"k":"or","l":{'
      '"k":"and","l":{"k":"cmp","op":"eq","l":{"k":"prop","of":{"k":"ctx","name'
      '":"github"},"name":"ref"},"r":{"k":"str","s":"refs/heads/master"}},"r":{'
      '"k":"prop","of":{"k":"ctx","name":"github"},"name":"sha"}},"r":{"k":"str'
      '","s":"head"}}}]},"cancel":{"text":"${{ github.ref != \'refs/heads/master'
      '\' }}","line":48,"col":23,"expr":{"k":"cmp","op":"ne","l":{"k":"prop","of'
      '":{"k":"ctx","name":"github"},"name":"ref"},"r":{"k":"str","s":"refs/hea'
      'ds/master"}}}}}],"zones":{}}'
  ==
=/  capture-catalog=@t
  %+  rap  3
  :~  capture-catalog-1
      capture-catalog-2
  ==
=/  capture-plan-jobs-1=@t
  %+  rap  3
  :~  '[{"id":"build","workflow":"lane.yml","name":"Lane","stage":0,"needs":[],'
      '"cond":null,"outputs":[],"matrix":false,"events":["push","workflow_dispa'
      'tch"],"runs-on":["ubuntu-latest"],"concurrency":false},{"id":"deploy","w'
      'orkflow":"lane.yml","name":"Lane","stage":1,"needs":["build"],"cond":nul'
      'l,"outputs":[],"matrix":false,"events":["push","workflow_dispatch"],"run'
      's-on":["ubuntu-latest"],"concurrency":true}]'
  ==
=/  capture-plan-jobs=@t
  %+  rap  3
  :~  capture-plan-jobs-1
  ==
::  ERPit's label expression from fixtures.yml, as the pinned compiler
::  compiles it: runner/internal/plan labels_pin_test.go reads it from the
::  real workflow and pins testdata/labels/erpit-labeled.json
::
=/  erpit-labeled-1=@t
  %+  rap  3
  :~  '{"v":2,"text":"${{ contains(github.event.pull_request.labels.*.name, \'ci'
      ':fixtures\') }}","line":172,"col":20,"expr":{"k":"call","fn":"contains","'
      'args":[{"k":"prop","of":{"k":"star","of":{"k":"prop","of":{"k":"prop","o'
      'f":{"k":"prop","of":{"k":"ctx","name":"github"},"name":"event"},"name":"'
      'pull_request"},"name":"labels"}},"name":"name"},{"k":"str","s":"ci:fixtu'
      'res"}]}}'
  ==
=/  erpit-labeled=@t
  erpit-labeled-1
=>
|%
+$  case  [name=@t expect=? got=?]
+$  defs  (list [workflow=@t name=@t def=(unit concurrency-def:ci)])
++  has-text
  |=  [text=@t part=@t]
  ^-  ?
  ?=(^ (find (trip part) (trip text)))
++  now  ^-  @da  ~2026.10.19..12.00.00
++  later
  |=  n=@ud
  ^-  @da
  (add now (mul n ~s10))
::
::  ---- the captured catalog, parsed by the ship's own parser ----
::
++  parsed
  ^-  (each (unit trigger-catalog:ci) @t)
  (parse-catalog:ci-trigger (de:json:html capture-catalog))
++  cat
  ^-  trigger-catalog:ci
  =/  r=(each (unit trigger-catalog:ci) @t)  parsed
  ?:  ?=(%| -.r)  [~ ~]
  (fall p.r [~ ~])
++  workflow-of
  |=  file=@t
  ^-  (unit trigger-workflow:ci)
  =/  ws=(list trigger-workflow:ci)  workflows:cat
  |-
  ?~  ws  ~
  ?:  =(file workflow.i.ws)  `i.ws
  $(ws t.ws)
++  def-of
  |=  file=@t
  ^-  (unit concurrency-def:ci)
  =/  w=(unit trigger-workflow:ci)  (workflow-of file)
  ?~  w  ~
  concurrency.u.w
++  suite-def  ^-  (unit concurrency-def:ci)  (def-of 'suite.yml')
++  fixtures-def  ^-  (unit concurrency-def:ci)  (def-of 'fixtures.yml')
++  erpit-group
  ^-  @t
  '${{ github.workflow }}-${{ github.ref }}-${{ github.ref == \'refs/heads/master\' && github.sha || \'head\' }}'
++  erpit-cancel  ^-  @t  '${{ github.ref != \'refs/heads/master\' }}'
::
::  ---- records ----
::
++  head-1  ^-  oid:git  0xa1a1.a1a1.a1a1.a1a1.a1a1.a1a1.a1a1.a1a1.a1a1.a1a1
++  head-2  ^-  oid:git  0xb2b2.b2b2.b2b2.b2b2.b2b2.b2b2.b2b2.b2b2.b2b2.b2b2
++  head-3  ^-  oid:git  0xc3c3.c3c3.c3c3.c3c3.c3c3.c3c3.c3c3.c3c3.c3c3.c3c3
++  head-4  ^-  oid:git  0xd4d4.d4d4.d4d4.d4d4.d4d4.d4d4.d4d4.d4d4.d4d4.d4d4
++  merge-5  ^-  oid:git  0xe5e5.e5e5.e5e5.e5e5.e5e5.e5e5.e5e5.e5e5.e5e5.e5e5
::  an event run of a push to a ref, selecting suite.yml
::
++  push-run
  |=  [id=candidate-id:ci ref=@t head=oid:git at=@da]
  ^-  candidate:ci
  =/  blank=candidate:ci  *candidate:ci
  %=  blank
    id  id
    repo  'erpit'
    ref  ref
    head  head
    base  head
    candidate  `head
    status  %pending
    mode  %event
    trust  %trusted
    created  at
    updated  at
    lock  `0x99
    trigger  [%event [id %push ref ~ `head ~ ~ ~zod 'smart-http push' at '{}']]
    selected  `['basis' ~[['suite.yml' 'suite' %selected 'selected']] ~]
    concurrency  [%pending ~]
  ==
++  seed  ^-  state-0:ci  *state-0:ci
++  with
  |=  [s=state-0:ci cs=(list candidate:ci)]
  ^-  state-0:ci
  s(candidates (~(gas by candidates.s) (turn cs |=(c=candidate:ci [id.c c]))))
++  got
  |=  [s=state-0:ci id=candidate-id:ci]
  ^-  candidate:ci
  (~(got by candidates.s) id)
++  restatus
  |=  [s=state-0:ci id=candidate-id:ci status=candidate-status:ci]
  ^-  state-0:ci
  =/  c=candidate:ci  (got s id)
  s(candidates (~(put by candidates.s) id c(status status)))
++  group
  |=  [s=state-0:ci id=candidate-id:ci wf=@t]
  ^-  (unit workflow-group:ci)
  (group-of:ci-concurrency (got s id) wf)
++  place
  |=  [s=state-0:ci id=candidate-id:ci wf=@t]
  ^-  (unit group-place:ci)
  =/  g=(unit workflow-group:ci)  (group s id wf)
  ?~  g  ~
  ?.  ?=(%member -.u.g)  ~
  `place.u.g
++  stop
  |=  [s=state-0:ci id=candidate-id:ci wf=@t]
  ^-  (unit cancellation:ci)
  (~(get by cancelled:(got s id)) wf)
::  the waiting members of a group of the repository, by key
::
++  waiting-in
  |=  [s=state-0:ci key=@t]
  ^-  @ud
  %-  lent
  %+  skim  (members:ci-concurrency s 'erpit' key)
  |=(o=occupant:ci-concurrency =(%waiting place.o))
++  suite-defs  ^-  defs  ~[['suite.yml' 'suite' suite-def]]
::  a literal group, as the compiler compiles `concurrency: <name>` with a
::  fixed cancel-in-progress
::
++  lane
  |=  [name=@t cancel=?]
  ^-  defs
  ~[['lane.yml' 'Lane' `[%group [name 1 1 ~[[%lit name]]] [%fixed cancel]]]]
::  jobs and attempts
::
++  wjob
  |=  [wf=@t id=@t needs=(list @t) cond=(unit condition:ci)]
  ^-  job:ci
  [id wf 'W' 0 needs cond ~ ~ ~ `~]
++  always-if  ^-  (unit condition:ci)  `[%if 'always()' 1 1 [%call 'always' ~]]
++  success-if  ^-  (unit condition:ci)  `[%if 'success()' 1 1 [%call 'success' ~]]
++  gate-if
  ^-  (unit condition:ci)
  :-  ~
  :*  %if  'needs.plan.outputs.suite == \'true\''  1  1
      [%cmp %eq [%prop [%prop [%prop [%ctx 'needs'] 'plan'] 'outputs'] 'suite'] [%str 'true']]
  ==
++  attempt
  |=  $:  id=attempt-id:ci
          cand=candidate-id:ci
          wf=@t
          job=@t
          status=attempt-status:ci
          approval=(unit @uv)
      ==
  ^-  attempt:ci
  =/  blank=attempt:ci  *attempt:ci
  %=  blank
    id  id
    candidate  cand
    kind  %job
    workflow  `wf
    job  `job
    status  status
    started  now
    approval  approval
    outcome  %known
  ==
::  a candidate's plan and attempts put in a state (attempts newest first)
::
++  planned
  |=  [s=state-0:ci id=candidate-id:ci plan=(list job:ci) as=(list attempt:ci)]
  ^-  state-0:ci
  =/  c=candidate:ci  (got s id)
  =.  attempts.s  (~(gas by attempts.s) (turn as |=(a=attempt:ci [id.a a])))
  =/  ids=(list attempt-id:ci)  (turn (flop as) |=(a=attempt:ci id.a))
  s(candidates (~(put by candidates.s) id c(plan `plan, attempts ids)))
++  standing-of
  |=  [s=state-0:ci id=candidate-id:ci wf=@t job=@t]
  ^-  standing:ci-plan
  (~(gut by standings:(standings:ci-concurrency s (got s id))) [wf job] %pending)
++  decision-of
  |=  [s=state-0:ci id=candidate-id:ci j=job:ci]
  ^-  decision:ci-plan
  =/  c=candidate:ci  (got s id)
  =/  known  (standings:ci-concurrency s c)
  =/  entries=(map key:ci-plan need-entry:ci)
    (need-entries:ci-concurrency c newest.known standings.known)
  %:  decide-with:ci-concurrency
    s
    c
    j
    (fall plan.c ~)
    standings.known
    entries
    (run-context:ci-concurrency c)
  ==
++  status-of
  |=  [s=state-0:ci aid=attempt-id:ci]
  ^-  attempt-status:ci
  status:(~(got by attempts.s) aid)
++  verdict-of
  |=  [s=state-0:ci id=candidate-id:ci cancelled=(set @t)]
  ^-  candidate-status:ci
  =/  c=candidate:ci  (got s id)
  -:(verdict-in:ci-plan (fall plan.c ~) standings:(standings:ci-concurrency s c) cancelled)
::
::  ---- ERPit on a feature branch: the newer push cancels the older ----
::
++  b1  ^-  candidate:ci  (push-run 0v1 'refs/heads/feature' head-1 now)
++  b2  ^-  candidate:ci  (push-run 0v2 'refs/heads/feature' head-2 (later 1))
::  b1's suite.yml: plan passed, suite running (a gate with no status
::  function), notify (always()) and report (no if) not started
++  b-plan
  ^-  (list job:ci)
  :~  (wjob 'suite.yml' 'plan' ~ ~)
      (wjob 'suite.yml' 'suite' ~['plan'] gate-if)
      (wjob 'suite.yml' 'notify' ~['suite'] always-if)
      (wjob 'suite.yml' 'report' ~['plan'] ~)
  ==
++  sb0
  ^-  state-0:ci
  %:  planned
    (with seed ~[b1 b2])
    id:b1
    b-plan
    :~  (attempt 0v101 id:b1 'suite.yml' 'plan' %passed ~)
        (attempt 0v102 id:b1 'suite.yml' 'suite' %running ~)
    ==
  ==
++  sb1  ^-  state-0:ci  (join:ci-concurrency sb0 id:b1 suite-defs now)
++  sb2  ^-  state-0:ci  (join:ci-concurrency sb1 id:b2 suite-defs (later 1))
++  feature-group  ^-  @t  'suite-refs/heads/feature-head'
++  sb-before  ^-  state-0:ci  (release:ci-concurrency sb2 (later 2))
::  notify ran and passed, report is recorded cancelled: the run in
::  progress finished, and the group starts b2
++  sb3
  ^-  state-0:ci
  %:  planned
    sb2
    id:b1
    b-plan
    :~  (attempt 0v101 id:b1 'suite.yml' 'plan' %passed ~)
        (~(got by attempts:sb2) 0v102)
        (attempt 0v103 id:b1 'suite.yml' 'notify' %passed ~)
        (attempt 0v104 id:b1 'suite.yml' 'report' %cancelled ~)
    ==
  ==
++  sb4  ^-  state-0:ci  (release:ci-concurrency sb3 (later 2))
::
::  ---- ERPit on master: one group per commit, both run to the end ----
::
++  m1  ^-  candidate:ci  (push-run 0v3 'refs/heads/master' head-3 now)
++  m2  ^-  candidate:ci  (push-run 0v4 'refs/heads/master' head-4 (later 1))
++  sm1  ^-  state-0:ci  (join:ci-concurrency (with seed ~[m1 m2]) id:m1 suite-defs now)
++  sm  ^-  state-0:ci  (join:ci-concurrency sm1 id:m2 suite-defs (later 1))
::  a required run's github.sha is its integration object, as its jobs see
++  r5
  ^-  candidate:ci
  =/  run=candidate:ci  (push-run 0v5 'refs/heads/master' head-4 now)
  run(candidate `merge-5, mode %required, trigger [%push ~], selected ~)
++  sr  ^-  state-0:ci  (join:ci-concurrency (with seed ~[r5]) id:r5 suite-defs now)
::  a pull request reads refs/pull/<n>/merge, as act gives its jobs
++  facts
  ^-  pull-facts:ci
  [7 'a change' 'synchronize' head-2 'refs/heads/feature' 'refs/heads/master' head-1 %.n ~nec 'erpit' ~ ~]
++  pr
  ^-  candidate:ci
  =/  run=candidate:ci  (push-run 0v6 'refs/heads/master' head-2 now)
  %=  run
    pull  `7
    trigger  [%event [0v6 %pull-request 'refs/heads/master' ~ `head-2 `facts ~ ~nec 'peer' now '{}']]
  ==
++  spr  ^-  state-0:ci  (join:ci-concurrency (with seed ~[pr]) id:pr suite-defs now)
++  pr-github  ^-  val:ci-expr  (github-for:ci-concurrency pr 'suite')
++  github-prop
  |=  [v=val:ci-expr key=@t]
  ^-  (unit val:ci-expr)
  ?.  ?=(%obj -.v)  ~
  (~(get by p.v) key)
::
::  ---- one waiting run; the newcomer's flag decides; case ----
::
++  d1  ^-  candidate:ci  (push-run 0v7 'refs/heads/main' head-1 now)
++  d2  ^-  candidate:ci  (push-run 0v8 'refs/heads/main' head-2 (later 1))
++  d3  ^-  candidate:ci  (push-run 0v9 'refs/heads/main' head-3 (later 2))
++  d4  ^-  candidate:ci  (push-run 0va 'refs/heads/main' head-4 (later 3))
++  sl1  ^-  state-0:ci  (join:ci-concurrency (with seed ~[d1 d2 d3 d4]) id:d1 (lane 'lane' %.n) now)
++  sl2  ^-  state-0:ci  (join:ci-concurrency sl1 id:d2 (lane 'lane' %.n) (later 1))
::  d3 arrives with cancel-in-progress false and still displaces the
::  waiting d2: the one-waiting rule ignores the flags
++  sl3  ^-  state-0:ci  (join:ci-concurrency sl2 id:d3 (lane 'lane' %.n) (later 2))
++  sl4  ^-  state-0:ci  (join:ci-concurrency sl3 id:d4 (lane 'LANE' %.y) (later 3))
++  lane-job  ^-  job:ci  (wjob 'lane.yml' 'build' ~ ~)
++  d3-stop  ^-  (unit cancellation:ci)  (stop sl4 id:d3 'lane.yml')
++  d3-gate
  ^-  (unit decision:ci-plan)
  (gate:ci-concurrency sl4 (got sl4 id:d3) (wjob 'lane.yml' 'tidy' ~ always-if))
::  e1 holds with cancel-in-progress true; e2 arrives with false: e2's own
::  flag decides, so it waits and e1 runs on
++  e1  ^-  candidate:ci  (push-run 0vb 'refs/heads/main' head-1 now)
++  e2  ^-  candidate:ci  (push-run 0vc 'refs/heads/main' head-2 (later 1))
++  se1  ^-  state-0:ci  (join:ci-concurrency (with seed ~[e1 e2]) id:e1 (lane 'other' %.y) now)
++  se  ^-  state-0:ci  (join:ci-concurrency se1 id:e2 (lane 'other' %.n) (later 1))
::  d1 closed (it passed): the group starts its waiting run, d4
++  sl5  ^-  state-0:ci  (release:ci-concurrency (restatus sl4 id:d1 %passed) (later 4))
::
::  ---- cross-workflow isolation and the operator's cancel ----
::
++  x  ^-  candidate:ci  (push-run 0vd 'refs/heads/main' head-1 now)
++  x-plan  ^-  (list job:ci)  ~[(wjob 'a.yml' 'a1' ~ ~) (wjob 'b.yml' 'b1' ~ ~)]
++  sx0
  ^-  state-0:ci
  %:  planned
    (with seed ~[x])
    id:x
    x-plan
    :~  (attempt 0v201 id:x 'a.yml' 'a1' %running ~)
        (attempt 0v202 id:x 'b.yml' 'b1' %running ~)
    ==
  ==
++  x-defs
  ^-  defs
  :~  ['a.yml' 'A' `[%group ['ga' 1 1 ~[[%lit 'ga']]] [%fixed %.n]]]
      ['b.yml' 'B' `[%none ~]]
  ==
++  sx1  ^-  state-0:ci  (join:ci-concurrency sx0 id:x x-defs now)
++  sx2
  ^-  state-0:ci
  %:  cancel-workflows:ci-concurrency
    sx1  id:x  ~['a.yml']  [%operator ~zod]  'cancelled by ~zod: stop a'  (later 1)
  ==
::  a newcomer with cancel-in-progress in group ga stops x's a.yml alone
++  y  ^-  candidate:ci  (push-run 0ve 'refs/heads/main' head-2 (later 1))
++  y-defs  ^-  defs  ~[['a.yml' 'A' `[%group ['GA' 1 1 ~[[%lit 'GA']]] [%fixed %.y]]]]
++  sy  ^-  state-0:ci  (join:ci-concurrency (with sx1 ~[y]) id:y y-defs (later 1))
::
::  ---- always(), success(), a privileged attempt, the verdicts ----
::
++  p  ^-  candidate:ci  (push-run 0vf 'refs/heads/main' head-1 now)
++  p-plan
  ^-  (list job:ci)
  :~  (wjob 'd.yml' 'deploy' ~ ~)
      (wjob 'd.yml' 'tidy' ~['deploy'] always-if)
      (wjob 'd.yml' 'check' ~['deploy'] success-if)
  ==
++  sp0
  ^-  state-0:ci
  (planned (with seed ~[p]) id:p p-plan ~[(attempt 0v301 id:p 'd.yml' 'deploy' %running `0v1)])
++  sp1  ^-  state-0:ci  (join:ci-concurrency sp0 id:p ~[['d.yml' 'D' `[%none ~]]] now)
++  sp2
  ^-  state-0:ci
  %:  cancel-workflows:ci-concurrency
    sp1  id:p  ~['d.yml']  [%operator ~zod]  'cancelled by ~zod: stop'  (later 1)
  ==
++  closed-deploy  ^-  attempt:ci  (~(got by attempts:sp2) 0v301)
::  tidy (always()) ran and passed; check (success()) is recorded cancelled
++  sp3
  ^-  state-0:ci
  %:  planned
    sp2
    id:p
    p-plan
    :~  closed-deploy
        (attempt 0v302 id:p 'd.yml' 'tidy' %passed ~)
        (attempt 0v303 id:p 'd.yml' 'check' %cancelled ~)
    ==
  ==
::  a required run: passed it lands; with its workflow cancelled it is
::  cancelled and lands nothing
++  rev  ^-  oid:git  head-3
++  req
  ^-  candidate:ci
  =/  run=candidate:ci  (push-run 0vg 'refs/heads/main' head-1 now)
  run(mode %required, trigger [%push ~], baseline `rev, selected ~)
++  sq
  ^-  state-0:ci
  =/  s=state-0:ci  (with seed ~[req])
  s(baselines (~(put by baselines.s) ['erpit' 'refs/heads/main'] [rev ~ `0x99 now ~zod 'why' 0 ~]))
++  q-plan  ^-  (list job:ci)  ~[(wjob 'ci.yml' 'build' ~ ~) (wjob 'ci.yml' 'test' ~ ~)]
++  sq1
  ^-  state-0:ci
  %:  planned
    sq
    id:req
    q-plan
    :~  (attempt 0v401 id:req 'ci.yml' 'build' %passed ~)
        (attempt 0v402 id:req 'ci.yml' 'test' %running ~)
    ==
  ==
++  sq2
  ^-  state-0:ci
  %:  cancel-workflows:ci-concurrency
    sq1  id:req  ~['ci.yml']  [%operator ~zod]  'cancelled by ~zod: no'  (later 1)
  ==
++  q-status  ^-  candidate-status:ci  (verdict-of sq2 id:req (silt ~['ci.yml']))
++  q-cancelled  ^-  candidate:ci  (got (restatus sq2 id:req q-status) id:req)
++  q-passed  ^-  candidate:ci  (got (restatus sq1 id:req %passed) id:req)
::  a run no longer pending is finished: nothing of it is cancelled
++  sq-done  ^-  state-0:ci  (restatus sq2 id:req %cancelled)
++  sq-again
  ^-  state-0:ci
  %:  cancel-workflows:ci-concurrency
    sq-done  id:req  ~['other.yml']  [%operator ~zod]  'again'  (later 2)
  ==
::
::  ---- what takes part ----
::
++  trial
  ^-  candidate:ci
  =/  run=candidate:ci  (push-run 0vh 'refs/heads/main' head-1 now)
  run(mode %trial)
++  resolver
  ^-  candidate:ci
  =/  run=candidate:ci  (push-run 0vi 'refs/ci/resolve' head-1 now)
  run(mode %shadow)
::
::  ---- evaluation and the catalog ----
::
++  push-github  ^-  val:ci-expr  (github-for:ci-concurrency b1 'suite')
++  group-def
  |=  [parts=(list part:ci) cancel=cancel-flag:ci]
  ^-  concurrency-def:ci
  [%group ['t' 1 1 parts] cancel]
++  bad-json
  ^-  (each [text=@t cancel=?] @t)
  %^  evaluate:ci-concurrency
      (group-def ~[[%expr [%call 'fromjson' ~[[%str 'not json']]]]] [%fixed %.n])
    push-github
  [%obj ~]
++  base-ref
  ^-  (each [text=@t cancel=?] @t)
  %^  evaluate:ci-concurrency
      (group-def ~[[%expr [%prop [%ctx 'github'] 'base_ref']]] [%fixed %.n])
    push-github
  [%obj ~]
++  whole-event
  ^-  (each [text=@t cancel=?] @t)
  %^  evaluate:ci-concurrency
      (group-def ~[[%expr [%prop [%ctx 'github'] 'event']]] [%fixed %.n])
    push-github
  [%obj ~]
++  text-cancel
  ^-  (each [text=@t cancel=?] @t)
  %^  evaluate:ci-concurrency
      (group-def ~[[%lit 'g']] [%expr 'yes' 1 1 [%str 'yes']])
    push-github
  [%obj ~]
++  sk
  ^-  state-0:ci
  =/  s=state-0:ci  (with seed ~[b1])
  %=  s
    locks
      %-  my
      :~  [0x99 [0x99 'erpit' head-1 ~ now 0v1 0 ~ ~ `cat]]
          [0x98 [0x98 'erpit' head-1 ~ now 0v1 0 ~ ~ ~]]
      ==
  ==
++  old-lock
  ^-  candidate:ci
  =/  run=candidate:ci  b1
  run(lock `0x98)
++  refused-defs  ^-  defs  ~[['refused.yml' 'Refused group' (def-of 'refused.yml')]]
++  srf  ^-  state-0:ci  (join:ci-concurrency (with seed ~[b1]) id:b1 refused-defs now)
++  refused-group  ^-  (unit workflow-group:ci)  (group srf id:b1 'refused.yml')
++  refused-gate
  ^-  (unit decision:ci-plan)
  (gate:ci-concurrency srf (got srf id:b1) (wjob 'refused.yml' 'never' ~ ~))
::
::  ---- the plan wire: a job-level concurrency refuses the plan ----
::
++  lane-oid  ^-  @t  (oid-text:git-codec head-1)
++  plan-body
  ^-  @t
  %+  rap  3
  :~  '{"oid":"'  lane-oid  '","workflows-oid":"'  lane-oid
      '","workflows":["lane.yml"],"jobs":'  capture-plan-jobs  '}'
  ==
++  plan-wire
  ^-  (each wire-plan:ci-plan @t)
  (parse:ci-plan (need (de:json:html plan-body)))
++  plan-checked
  ^-  (each (list job:ci) @t)
  =/  w=(each wire-plan:ci-plan @t)  plan-wire
  ?:  ?=(%| -.w)  [%| p.w]
  (validate:ci-plan lane-oid ~['lane.yml'] p.w)
++  catalog-of-text
  |=  text=@t
  ^-  (each (unit trigger-catalog:ci) @t)
  (parse-catalog:ci-trigger (de:json:html text))
++  no-key
  ^-  (each (unit trigger-catalog:ci) @t)
  %-  catalog-of-text
  %+  rap  3
  :~  '{"version":1,"workflows":[{"workflow":"old.yml","name":"Old","events":[{"event":"push",'
      '"refusal":"","branches":null,"tags":null,"paths":null,"types":null,"typesDeclared":false,'
      '"schedules":null,"line":1,"col":5}],"refusal":""}],"zones":{}}'
  ==
++  no-key-workflows
  ^-  (list trigger-workflow:ci)
  =/  r=(each (unit trigger-catalog:ci) @t)  no-key
  ?.  ?=([%& ~ *] r)  ~
  workflows.u.p.r
++  bad-version
  ^-  (each (unit trigger-catalog:ci) @t)
  %-  catalog-of-text
  %+  rap  3
  :~  '{"version":1,"workflows":[{"workflow":"old.yml","name":"Old","events":[],"refusal":"no on:",'
      '"concurrency":{"v":3,"kind":"none"}}],"zones":{}}'
  ==
++  bad-context
  ^-  (each (unit trigger-catalog:ci) @t)
  %-  catalog-of-text
  %+  rap  3
  :~  '{"version":1,"workflows":[{"workflow":"old.yml","name":"Old","events":[],"refusal":"no on:",'
      '"concurrency":{"v":2,"kind":"group","group":{"text":"g","line":1,"col":1,"parts":[{"expr":'
      '{"k":"prop","of":{"k":"ctx","name":"needs"},"name":"a"}}]},"cancel":{"text":"","line":0,'
      '"col":0,"value":false}}}],"zones":{}}'
  ==
++  bad-kind
  ^-  (each (unit trigger-catalog:ci) @t)
  %-  catalog-of-text
  %+  rap  3
  :~  '{"version":1,"workflows":[{"workflow":"old.yml","name":"Old","events":[],"refusal":"no on:",'
      '"concurrency":{"v":2,"kind":"later"}}],"zones":{}}'
  ==
::
::  ---- the cases ----
::
++  wire-cases
  ^-  (list case)
  :~  ['the captured catalog parses' %.y =/(r parsed ?=(%& -.r))]
      ['every captured workflow carries its concurrency' %.y (levy workflows:cat |=(w=trigger-workflow:ci ?=(^ concurrency.w)))]
      ['plain.yml declares none' %.y =(`[%none ~] (def-of 'plain.yml'))]
      :-  'refused.yml is refused with the compiler\'s reason and place'
      :-  %.y
      =(`[%refused 'yes' 5 23 'cancel-in-progress is true, false or one ${{ }} expression, not "yes"'] (def-of 'refused.yml'))
      :-  'lane.yml\'s string form is a group, cancel-in-progress false'
      :-  %.y
      =(`[%group ['lane-${{ github.ref_name }}' 3 14 ~[[%lit 'lane-'] [%expr [%prop [%ctx 'github'] 'ref_name']]]] [%fixed %.n]] (def-of 'lane.yml'))
      :-  'suite.yml keeps ERPit\'s group text and its five parts'
      :-  %.y
      =/  d=(unit concurrency-def:ci)  suite-def
      ?.  ?=([~ %group *] d)  %.n
      ?&(=(erpit-group text.group.u.d) =(5 (lent parts.group.u.d)))
      :-  'suite.yml keeps ERPit\'s cancel-in-progress expression'
      :-  %.y
      =/  d=(unit concurrency-def:ci)  suite-def
      ?.  ?=([~ %group *] d)  %.n
      ?.  ?=(%expr -.cancel.u.d)  %.n
      ?&  =(erpit-cancel text.cancel.u.d)
          =([%cmp %ne [%prop [%ctx 'github'] 'ref'] [%str 'refs/heads/master']] expr.cancel.u.d)
      ==
      :-  'fixtures.yml and suite.yml compile the same group at their own lines'
      :-  %.y
      =/  a=(unit concurrency-def:ci)  suite-def
      =/  b=(unit concurrency-def:ci)  fixtures-def
      ?.  ?&(?=([~ %group *] a) ?=([~ %group *] b))  %.n
      ?.  ?&(?=(%expr -.cancel.u.a) ?=(%expr -.cancel.u.b))  %.n
      ?&  =(parts.group.u.a parts.group.u.b)
          =(expr.cancel.u.a expr.cancel.u.b)
          =(47 line.group.u.a)
          =(91 line.group.u.b)
      ==
      ['a catalog without the key parses' %.y =/(r no-key ?=([%& ~ *] r))]
      ['a catalog without the key is unknown' %.y =/(ws no-key-workflows ?=([[* * * * ~] ~] ws))]
      ['a catalog without the key reads "no group"' %.n =/(ws no-key-workflows ?=([[* * * * [~ %none ~]] ~] ws))]
      ['a concurrency of another version refuses the catalog' %.y =/(r bad-version ?&(?=(%| -.r) (has-text p.r 'not version 2')))]
      ['a context concurrency cannot read refuses the catalog' %.y =/(r bad-context ?&(?=(%| -.r) (has-text p.r 'context needs is not available to a workflow\'s concurrency')))]
      ['an unknown kind refuses the catalog' %.y =/(r bad-kind ?&(?=(%| -.r) (has-text p.r 'unknown kind')))]
      ['the captured plan wire parses' %.y =/(w plan-wire ?=(%& -.w))]
      :-  'the planner refuses a job-level concurrency with the reason'
      :-  %.y
      =([%| 'job-level concurrency is refused in this release (job deploy in lane.yml): only a workflow\'s concurrency group is supported'] plan-checked)
      ['the planner ignores a job-level concurrency' %.n =/(c plan-checked ?=(%& -.c))]
  ==
++  erpit-cases
  ^-  (list case)
  :~  ['a feature push joins its group in progress' %.y =(`[%member feature-group feature-group %.y %holding ~ now] (group sb1 id:b1 'suite.yml'))]
      :-  'the newer feature push cancels the older, with cancel-in-progress'
      :-  %.y
      =/  why=@t
        (rap 3 ~['cancelled: the newer run (push of b2b2b2b2 to feature) joined group ' feature-group ' with cancel-in-progress'])
      =(`[(later 1) %.y [%superseded id:b2 feature-group] why] (stop sb2 id:b1 'suite.yml'))
      ['the newer push waits while the cancelled run finishes' %.y =(`[%member feature-group feature-group %.y %waiting `id:b1 (later 1)] (group sb2 id:b2 'suite.yml'))]
      ['the running job without a status function is stopped' %.y =(%cancelled (status-of sb2 0v102))]
      ['its stopped attempt is the job\'s end, cancelled' %.y =(%cancelled (standing-of sb2 id:b1 'suite.yml' 'suite'))]
      ['the passed job keeps its result' %.y =(%passed (status-of sb2 0v101))]
      ['always() runs after the cancellation' %.y =(%run -:(decision-of sb2 id:b1 (wjob 'suite.yml' 'notify' ~['suite'] always-if)))]
      ['a job with no if is cancelled, not skipped' %.y =(%cancel -:(decision-of sb2 id:b1 (wjob 'suite.yml' 'report' ~['plan'] ~)))]
      ['the group does not start the newer run while always() runs' %.y =(`%waiting (place sb-before id:b2 'suite.yml'))]
      ['the waiting run starts when the run in progress finishes' %.y =(`%holding (place sb4 id:b2 'suite.yml'))]
      ['the finished run leaves its group' %.y =(`%released (place sb4 id:b1 'suite.yml'))]
      ['the cancelled run\'s result is cancelled' %.y =(%cancelled (verdict-of sb4 id:b1 (silt ~['suite.yml'])))]
      :-  'a master push groups by its own sha, with cancel-in-progress false'
      :-  %.y
      =/  t=@t  (rap 3 ~['suite-refs/heads/master-' (oid-text:git-codec head-3)])
      =(`[%member t t %.n %holding ~ now] (group sm id:m1 'suite.yml'))
      ['a second master push holds a group of its own' %.y =(`%holding (place sm id:m2 'suite.yml'))]
      ['neither master push is cancelled' %.y &(=(~ cancelled:(got sm id:m1)) =(~ cancelled:(got sm id:m2)))]
      :-  'a required run groups by its integration object, the sha its jobs see'
      :-  %.y
      =/  t=@t  (rap 3 ~['suite-refs/heads/master-' (oid-text:git-codec merge-5)])
      =(`[%member t t %.n %holding ~ now] (group sr id:r5 'suite.yml'))
      ['a pull request reads refs/pull/<n>/merge' %.y =(`[%str 'refs/pull/7/merge'] (github-prop pr-github 'ref'))]
      ['a pull request reads its ref name, head and base' %.y &(=(`[%str '7/merge'] (github-prop pr-github 'ref_name')) =(`[%str 'feature'] (github-prop pr-github 'head_ref')) =(`[%str 'master'] (github-prop pr-github 'base_ref')))]
      ['a pull request groups as on GitHub, with cancel-in-progress' %.y =(`[%member 'suite-refs/pull/7/merge-head' 'suite-refs/pull/7/merge-head' %.y %holding ~ now] (group spr id:pr 'suite.yml'))]
  ==
++  rule-cases
  ^-  (list case)
  :~  ['the first run holds its group' %.y =(`%holding (place sl1 id:d1 'lane.yml'))]
      ['cancel-in-progress false waits behind the run in progress' %.y =(`[%member 'lane' 'lane' %.n %waiting `id:d1 (later 1)] (group sl2 id:d2 'lane.yml'))]
      ['a waiting newcomer cancels nothing' %.y =(~ cancelled:(got sl2 id:d1))]
      :-  'a newer arrival cancels the older waiting run whatever the flags'
      :-  %.y
      =(`[(later 2) %.n [%displaced id:d3 'lane'] 'cancelled: a newer run (push of c3c3c3c3 to main) is waiting in group lane'] (stop sl3 id:d2 'lane.yml'))
      ['the displaced run leaves the group never having started' %.y =(`%released (place sl3 id:d2 'lane.yml'))]
      ['the newer arrival waits in its place' %.y =(`%waiting (place sl3 id:d3 'lane.yml'))]
      ['a group keeps one waiting run' %.y &(=(1 (waiting-in sl2 'lane')) =(1 (waiting-in sl3 'lane')) =(1 (waiting-in sl4 'lane')))]
      ['the run in progress survives a waiting arrival' %.y =(~ cancelled:(got sl3 id:d1))]
      ['groups ignore case: LANE is lane' %.y =(`[%member 'LANE' 'lane' %.y %waiting `id:d1 (later 3)] (group sl4 id:d4 'lane.yml'))]
      :-  'cancel-in-progress true cancels the run in progress'
      :-  %.y
      =(`[(later 3) %.y [%superseded id:d4 'LANE'] 'cancelled: the newer run (push of d4d4d4d4 to main) joined group LANE with cancel-in-progress'] (stop sl4 id:d1 'lane.yml'))
      :-  'cancel-in-progress true cancels the waiting run too'
      :-  %.y
      =/  c=(unit cancellation:ci)  d3-stop
      ?~  c  %.n
      ?&(!started.u.c ?=(%superseded -.cause.u.c) =(`%released (place sl4 id:d3 'lane.yml')))
      ['a run cancelled while it waited runs no job, not even always()' %.y =/(g d3-gate ?=([~ %cancel *] g))]
      ['a waiting job waits for the run in progress, by name' %.y =(`[%wait 'waiting for run push of a1a1a1a1 to main in group lane'] (gate:ci-concurrency sl3 (got sl3 id:d3) lane-job))]
      ['the newcomer\'s own flag decides: false waits' %.y =(`%waiting (place se id:e2 'lane.yml'))]
      ['an older cancel-in-progress does not cancel a newer run' %.y &(=(~ cancelled:(got se id:e1)) =(`%holding (place se id:e1 'lane.yml')))]
      ['when the run in progress closes, the waiting run starts' %.y =(`%holding (place sl5 id:d4 'lane.yml'))]
      ['a closed run holds nothing' %.y =(`%released (place sl5 id:d1 'lane.yml'))]
  ==
++  cancel-cases
  ^-  (list case)
  :~  ['a workflow in no group is free' %.y =(`[%free ~] (group sx1 id:x 'b.yml'))]
      ['the operator cancels one workflow\'s run' %.y =(`[(later 1) %.y [%operator ~zod] 'cancelled by ~zod: stop a'] (stop sx2 id:x 'a.yml'))]
      ['its running job is stopped' %.y =(%cancelled (status-of sx2 0v201))]
      ['another workflow\'s job in the same run keeps running' %.y =(%running (status-of sx2 0v202))]
      ['another workflow is not cancelled' %.y =(~ (stop sx2 id:x 'b.yml'))]
      ['a group newcomer stops only that workflow of the run' %.y &(=(%cancelled (status-of sy 0v201)) =(%running (status-of sy 0v202)) =(~ (stop sy id:x 'b.yml')))]
      ['a privileged attempt closes unknown, needing review' %.y &(=(%infrastructure-error status:closed-deploy) =(%unknown outcome:closed-deploy) (has-text (fall reason:closed-deploy '') 'needs review'))]
      ['a privileged attempt closes as an ordinary cancel' %.n =(%cancelled status:closed-deploy)]
      ['a privileged run needs review: its verdict is unknown' %.y =(%unknown (verdict-of sp3 id:p (silt ~['d.yml'])))]
      ['success() is false in a cancelled run' %.y =(%cancel -:(decision-of sp2 id:p (wjob 'd.yml' 'check' ~ success-if)))]
      ['always() runs in a cancelled run' %.y =(%run -:(decision-of sp2 id:p (wjob 'd.yml' 'tidy' ~ always-if)))]
      ['a cancelled required run is cancelled' %.y =(%cancelled q-status)]
      ['a cancelled required run never passes' %.n =(%passed q-status)]
      ['a passed required run lands' %.y (landable:ci-concurrency sq1 q-passed)]
      ['a cancelled required run never lands' %.n (landable:ci-concurrency sq2 q-cancelled)]
      ['a finished run is not cancelled' %.y =(sq-done sq-again)]
  ==
++  rest-cases
  ^-  (list case)
  :~  ['a trial twin takes part in no group' %.y &(!=(~ (exempt:ci-concurrency trial)) =(%exempt -:(initial:ci-concurrency trial)))]
      ['a resolver record takes part in no group' %.y &(!=(~ (exempt:ci-concurrency resolver)) =(%exempt -:(initial:ci-concurrency resolver)))]
      ['a push, pull request, schedule or manual run joins' %.y =([%pending ~] (initial:ci-concurrency b1))]
      ['a run not joined yet waits to join' %.y =(`[%wait 'waiting to join its concurrency groups'] (gate:ci-concurrency seed b1 lane-job))]
      ['an expression that errs refuses the workflow\'s run' %.y =/(r bad-json ?&(?=(%| -.r) (has-text p.r 'is not JSON')))]
      ['an empty group refuses, never "no group"' %.y =/(r base-ref ?&(?=(%| -.r) (has-text p.r 'empty text')))]
      ['an object is no group name' %.y =/(r whole-event ?&(?=(%| -.r) (has-text p.r 'not text')))]
      ['cancel-in-progress that is not true or false refuses' %.y =/(r text-cancel ?&(?=(%| -.r) (has-text p.r 'not true or false')))]
      ['a refused definition refuses its workflow\'s run with the reason' %.y =/(g refused-group ?=([~ %refused *] g))]
      ['a refused workflow\'s job is refused' %.y =/(g refused-gate ?=([~ %error *] g))]
      ['a lock that read no catalog is unknown, with the reason' %.y =([%| unread:ci-concurrency] (definitions:ci-concurrency sk old-lock ~['suite.yml']))]
      ['a workflow the catalog does not list is unknown' %.y =([%& ~[['missing.yml' 'missing.yml' ~]]] (definitions:ci-concurrency sk b1 ~['missing.yml']))]
      ['an unknown definition joins as unknown, never free' %.y =([%unknown unread:ci-concurrency] (group-for:ci-concurrency b1 'x' ~ now))]
      ['the catalog\'s definition is read for a run' %.y =([%& ~[['suite.yml' 'suite' suite-def]]] (definitions:ci-concurrency sk b1 ~['suite.yml']))]
      ['the candidate status bunts to unknown' %.y =(%unknown *candidate-status:ci)]
      ['a run\'s concurrency bunts to unknown' %.y =([%unknown 'no concurrency was recorded for this run'] *run-concurrency:ci)]
      ['a workflow\'s group bunts to unknown' %.y =([%unknown 'no concurrency was recorded for this workflow'] *workflow-group:ci)]
      ['a group place bunts to released' %.y =(%released *group-place:ci)]
      ['a decision bunts to a refusal' %.y =(%error verdict:*decision:ci)]
      ['a job standing bunts to pending' %.y =(%pending *standing:ci-plan)]
  ==
::
::  ---- pull request labels ----
::
::  a pull request run of #7 onto master, its payload the ship's own
::  (lib/ci-trigger pull-event-payload) for its facts and labels
::
++  pull-run
  |=  [id=candidate-id:ci action=@t labels=(list @t) label=(unit @t) at=@da]
  ^-  candidate:ci
  ::  facts is an arm: bind its value before changing fields of it
  =/  plain=pull-facts:ci  facts
  =/  f=pull-facts:ci  plain(action action, labels labels, label label)
  =/  payload=@t  (pull-event-payload:ci-trigger 'erpit' f ~nec `'refs/heads/master')
  =/  run=candidate:ci  (push-run id 'refs/heads/master' head-2 at)
  %=  run
    pull  `7
    trigger  [%event [id %pull-request 'refs/heads/master' ~ `head-2 `f ~ ~nec 'pull request labels' at payload]]
  ==
::  a synchronize run of #7 in flight; then an owner adds ci:fixtures.
::  ERPit's fixtures.yml groups both runs by refs/pull/7/merge with
::  cancel-in-progress true off master, so the label run cancels it, as
::  on GitHub
::
++  sync-run  ^-  candidate:ci  (pull-run 0vg 'synchronize' ~ ~ now)
++  label-run
  ^-  candidate:ci
  (pull-run 0vh 'labeled' ~['ci:fixtures'] `'ci:fixtures' (later 1))
++  other-label-run
  ^-  candidate:ci
  (pull-run 0vi 'labeled' ~['docs'] `'docs' (later 1))
++  carried-run
  ^-  candidate:ci
  (pull-run 0vj 'synchronize' ~['ci:fixtures'] ~ (later 2))
++  fixtures-defs  ^-  defs  ~[['fixtures.yml' 'fixtures' fixtures-def]]
++  fixtures-group  ^-  @t  'fixtures-refs/pull/7/merge-head'
++  sf1
  ^-  state-0:ci
  (join:ci-concurrency (with seed ~[sync-run label-run]) id:sync-run fixtures-defs now)
++  sf2  ^-  state-0:ci  (join:ci-concurrency sf1 id:label-run fixtures-defs (later 1))
::  ERPit's expression, parsed by the ship's parser and evaluated by its
::  evaluator against a run's github context, whose event is the payload
::
++  erpit-labeled-cond
  ^-  (each condition:ci @t)
  =/  j=(unit json)  (de:json:html erpit-labeled)
  ?~  j  |+'the pinned expression is not JSON'
  (parse-condition:ci-expr u.j)
++  erpit-labeled-on
  |=  c=candidate:ci
  ^-  (each val:ci-expr @t)
  =/  cond=(each condition:ci @t)  erpit-labeled-cond
  ?:  ?=(%| -.cond)  |+p.cond
  =/  =scope:ci-expr
    [(github-for:ci-concurrency c 'fixtures') [%obj ~] [%obj ~] [%obj ~] [%obj ~] %.n %.n %.n]
  (eval-condition:ci-expr p.cond scope)
++  label-cases
  ^-  (list case)
  :~  :+  'the synchronize run holds ERPit\'s group, with cancel-in-progress'  %.y
      =(`[%member fixtures-group fixtures-group %.y %holding ~ now] (group sf1 id:sync-run 'fixtures.yml'))
      :+  'adding ci:fixtures cancels the in-flight synchronize run of its group'  %.y
      =/  c=(unit cancellation:ci)  (stop sf2 id:sync-run 'fixtures.yml')
      ?~  c  %.n
      ?&  ?=(%superseded -.cause.u.c)
          =(id:label-run by.cause.u.c)
          =(fixtures-group group.cause.u.c)
          =((later 1) at.u.c)
          .=  reason.u.c
          %+  rap  3
          :~  'cancelled: the newer run (pull request #7 at b2b2b2b2 into master) joined group '
              fixtures-group
              ' with cancel-in-progress'
          ==
      ==
      :+  'the label run waits in its place until the cancelled run finishes'  %.y
      =(`[%member fixtures-group fixtures-group %.y %waiting `id:sync-run (later 1)] (group sf2 id:label-run 'fixtures.yml'))
      :+  'a label run reads refs/pull/7/merge, as act gives its jobs'  %.y
      =(`[%str 'refs/pull/7/merge'] (github-prop (github-for:ci-concurrency label-run 'fixtures') 'ref'))
      ['ERPit\'s label expression parses as the pinned compiler compiled it' %.y =/(c=(each condition:ci @t) erpit-labeled-cond ?=(%& -.c))]
      :+  'it is true on the labeled run\'s real payload, which lists ci:fixtures'  %.y
      =(&+[%bool %.y] (erpit-labeled-on label-run))
      :+  'it is false on the synchronize run\'s real payload, which lists no label'  %.y
      =(&+[%bool %.n] (erpit-labeled-on sync-run))
      :+  'it is false when another label was added'  %.y
      =(&+[%bool %.n] (erpit-labeled-on other-label-run))
      :+  'it is true on a synchronize run of a pull request that carries the label'  %.y
      =(&+[%bool %.y] (erpit-labeled-on carried-run))
  ==
--
=/  cases=(list case)
  :(weld wire-cases erpit-cases rule-cases cancel-cases rest-cases label-cases)
=/  failed=(list @t)
  %+  murn  cases
  |=  [name=@t expect=? got=?]
  ?:(=(expect got) ~ `name)
=/  passed=@ud  (sub (lent cases) (lent failed))
~&  [%ci-concurrency-vector passed=passed of=(lent cases)]
~&  [%ci-concurrency-vector-failures failed]
?=(~ failed)
