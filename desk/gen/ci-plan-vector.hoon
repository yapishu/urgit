::  ci-plan vectors: the plan parser and validator on the wire shape the
::  daemon posts (CI-EXPR-2: compiled conditions and declared outputs),
::  and the decision on the standings a candidate records.  every negative
::  asserts the exact reason text.  ci-expr-vector holds the expression
::  semantics and the Delivery 1B fixtures.
::
/-  ci
/+  ci-plan
:-  %say
|=  *
:-  %noun
=/  oid=@t  '587258b028c9bcc01e497386f0f85c48d0b82762'
=/  tree=(list @t)  ~['chain.yml' 'pass.yml' 'README.md']
::  the compiler's wire for `needs.a.outputs.go == 'true'` (fixture-chain)
::
=/  cond-eq=@t
  %+  rap  3
  :~  '{"v":2,"text":"needs.a.outputs.go == \'true\'","line":15,"col":9,"expr":{"k":"cmp","op":"eq",'
      '"l":{"k":"prop","of":{"k":"prop","of":{"k":"prop","of":{"k":"ctx","name":"needs"},"name":"a"},'
      '"name":"outputs"},"name":"go"},"r":{"k":"str","s":"true"}}}'
  ==
=/  plan-json
  |=  jobs=@t
  ^-  json
  %-  need
  %-  de:json:html
  %-  rap
  :-  3
  :~  '{"oid":"'  oid  '","workflows":["chain.yml","pass.yml"],"jobs":['  jobs  ']}'
  ==
=/  job-json
  |=  [id=@t workflow=@t stage=@t needs=@t cond=@t extra=@t]
  ^-  @t
  %-  rap
  :-  3
  :~  '{"id":"'  id  '","workflow":"'  workflow  '","name":"wf","stage":'  stage
      ',"needs":'  needs  ',"cond":'  cond  ',"outputs":[],"events":["push"]'  extra  '}'
  ==
::  parse then validate, giving the plan or the reason
::
=/  check
  |=  jon=json
  ^-  (each (list job:ci) @t)
  =/  parsed=(each wire-plan:ci-plan @t)  (parse:ci-plan jon)
  ?:  ?=(%| -.parsed)  parsed
  (validate:ci-plan oid tree p.parsed)
=/  reason
  |=  jon=json
  ^-  @t
  =/  checked=(each (list job:ci) @t)  (check jon)
  ?:(?=(%& -.checked) 'VALID' p.checked)
::  the chain the harness runs: a emits go, b needs a and reads it
::
=/  chain=json
  %-  plan-json
  %-  rap
  :-  3
  :~  (job-json 'a' 'chain.yml' '0' '[]' 'null' '')  ','
      (job-json 'b' 'chain.yml' '1' '["a"]' cond-eq '')  ','
      (job-json 'pass' 'pass.yml' '0' '[]' 'null' '')
  ==
=/  chain-plan=(list job:ci)
  =/  checked  (check chain)
  ?>  ?=(%& -.checked)
  p.checked
=/  key-a=key:ci-plan  ['chain.yml' 'a']
=/  key-b=key:ci-plan  ['chain.yml' 'b']
=/  key-pass=key:ci-plan  ['pass.yml' 'pass']
=/  job-b=job:ci  (snag 1 chain-plan)
=/  job-pass=job:ci  (snag 2 chain-plan)
=/  sibling-plan=(list job:ci)
  ~[(snag 0 chain-plan) job-b job-pass(workflow 'chain.yml')]
=/  key-sibling=key:ci-plan  ['chain.yml' 'pass']
::  a push run's context: the github context b's condition does not read
::
=/  push-ctx=run-context:ci-plan
  ['push' '' 'refs/heads/master' oid '~zod' [%obj ~] %.n]
=/  decide-b
  |=  [standings=(map key:ci-plan standing:ci-plan) outputs=(map key:ci-plan (map @t @t))]
  ^-  decision:ci-plan
  =/  entries=(map key:ci-plan need-entry:ci)
    %-  malt
    %+  turn  ~(tap by standings)
    |=  [k=key:ci-plan s=standing:ci-plan]
    :-  k
    :*  id.k  0v1
        ?+(s %running %passed %passed, %failed %failed, %skipped %skipped, %unknown %infrastructure-error)
        (result-word:ci-plan s)
        ~(tap by (~(gut by outputs) k ~))
    ==
  (decide:ci-plan job-b chain-plan standings entries push-ctx)
::  standings and outputs from literal lists, typed as the maps the
::  evaluator reads
::
=/  st
  |=  entries=(list [key:ci-plan standing:ci-plan])
  ^-  (map key:ci-plan standing:ci-plan)
  (malt entries)
=/  ou
  |=  entries=(list [key:ci-plan (map @t @t)])
  ^-  (map key:ci-plan (map @t @t))
  (malt entries)
::  a manual run's plan (Delivery 1A): the tree gains manual.yml, and a
::  job names the events act -l listed for its workflow
::
=/  tree-3=(list @t)  ~['chain.yml' 'pass.yml' 'manual.yml' 'README.md']
=/  ev-job
  |=  [id=@t workflow=@t needs=@t events=@t extra=@t]
  ^-  @t
  %-  rap
  :-  3
  :~  '{"id":"'  id  '","workflow":"'  workflow  '","name":"wf","stage":0'
      ',"needs":'  needs  ',"cond":null,"outputs":[],"events":'  events  extra  '}'
  ==
=/  plan-3
  |=  jobs=@t
  ^-  wire-plan:ci-plan
  =/  jon=json
    %-  need
    %-  de:json:html
    %-  rap
    :-  3
    :~  '{"oid":"'  oid  '","workflows":["chain.yml","pass.yml","manual.yml"],"jobs":['  jobs  ']}'
    ==
  =/  parsed=(each wire-plan:ci-plan @t)  (parse:ci-plan jon)
  ?>  ?=(%& -.parsed)
  p.parsed
=/  dispatch-of
  |=  [workflow=@t jobs=@t]
  ^-  (each (list job:ci) @t)
  %:  validate-for:ci-plan
    oid
    tree-3
    (plan-3 jobs)
    [%dispatch workflow 'Manual release' ~ '' 'request-1']
  ==
=/  manual-jobs=@t
  %-  rap
  :-  3
  :~  (ev-job 'a' 'chain.yml' '[]' '["push"]' '')  ','
      (ev-job 'report' 'manual.yml' '[]' '["push","workflow_dispatch"]' '')  ','
      (ev-job 'deploy' 'manual.yml' '["report"]' '["push","workflow_dispatch"]' '')
  ==
::
=/  results=(list [name=@t ok=?])
  :~  :-  'chain: three jobs planned, keyed by [workflow id]'
      =(3 (lent chain-plan))
    ::
      :-  'chain: b needs a, its compiled condition and place carried, real workflow name carried'
      ?&  =(~['a'] needs.job-b)
          ?=(^ cond.job-b)
          ?=(%if -.+.cond.job-b)
          .=  [%if 'needs.a.outputs.go == \'true\'' 15 9]
          [-.+.cond.job-b +<.+.cond.job-b +>-.+.cond.job-b +>+<.+.cond.job-b]
          =('wf' name.job-b)
          =(`~ outputs.job-b)
      ==
    ::
      :-  'duplicate job id'
      .=  'duplicate job id a in chain.yml'
      %-  reason
      %-  plan-json
      %+  rap
        3
      ~[(job-json 'a' 'chain.yml' '0' '[]' 'null' '') ',' (job-json 'a' 'chain.yml' '0' '[]' 'null' '')]
    ::
      :-  'needs on a missing job'
      .=  'job b in chain.yml needs zz, which is not a job in chain.yml'
      %-  reason
      %-  plan-json
      %+  rap
        3
      ~[(job-json 'a' 'chain.yml' '0' '[]' 'null' '') ',' (job-json 'b' 'chain.yml' '1' '["zz"]' 'null' '')]
    ::
      :-  'needs never crosses a workflow file'
      .=  'job b in chain.yml needs pass, which is not a job in chain.yml'
      %-  reason
      %-  plan-json
      %+  rap
        3
      ~[(job-json 'pass' 'pass.yml' '0' '[]' 'null' '') ',' (job-json 'b' 'chain.yml' '1' '["pass"]' 'null' '')]
    ::
      :-  'a condition the compiler refused refuses the plan, by name and place'
      .=  'job b in chain.yml: if "env.X == \'1\'" (line 7, column 9) is refused: context env is not available in a job-level if (github, needs, vars and inputs are)'
      %-  reason
      %-  plan-json
      %-  rap
      :-  3
      :~  (job-json 'a' 'chain.yml' '0' '[]' 'null' '')  ','
          %:  job-json
            'b'
            'chain.yml'
            '1'
            '["a"]'
            '{"v":2,"text":"env.X == \'1\'","line":7,"col":9,"refusal":"context env is not available in a job-level if (github, needs, vars and inputs are)"}'
            ''
          ==
      ==
    ::
      :-  'an output the compiler refused refuses the plan'
      .=  'job a in chain.yml: output url "${{ env.URL }}" (line 4, column 12) is refused: context env is not available to a job output on the ship in this release (github, needs, vars, inputs and steps.<id>.outputs are)'
      %-  reason
      %-  plan-json
      %^  job-json  'a'  'chain.yml'
      :^  '0'  '[]'  'null'
      ',"outputs":[{"name":"url","v":2,"text":"${{ env.URL }}","line":4,"col":12,"refusal":"context env is not available to a job output on the ship in this release (github, needs, vars, inputs and steps.<id>.outputs are)"}]'
    ::
      :-  'a plan without an outputs list predates declared outputs and is refused'
      .=  'job a in chain.yml: the plan carries no outputs list; the runner\'s compiler predates declared outputs'
      %-  reason
      %-  plan-json
      '{"id":"a","workflow":"chain.yml","name":"wf","stage":0,"needs":[],"cond":null,"events":["push"]}'
    ::
      :-  'an output declared twice is refused'
      .=  'job a in chain.yml: output x is declared twice'
      %-  reason
      %-  plan-json
      %^  job-json  'a'  'chain.yml'
      :^  '0'  '[]'  'null'
      ',"outputs":[{"name":"x","v":2,"text":"1","line":4,"col":10,"parts":[{"lit":"1"}]},{"name":"x","v":2,"text":"2","line":5,"col":10,"parts":[{"lit":"2"}]}]'
    ::
      :-  'an output reading needs of a job it does not need is refused'
      .=  'job a in chain.yml: output y references needs.b, which is not in needs'
      %-  reason
      %-  plan-json
      %^  job-json  'a'  'chain.yml'
      :^  '0'  '[]'  'null'
      ',"outputs":[{"name":"y","v":2,"text":"${{ needs.b.result }}","line":4,"col":10,"parts":[{"expr":{"k":"prop","of":{"k":"prop","of":{"k":"ctx","name":"needs"},"name":"b"},"name":"result"}}]}]'
    ::
      :-  'matrix unsupported in P1'
      .=  'matrix unsupported in P1 (job a in chain.yml)'
      %-  reason
      %-  plan-json
      (job-json 'a' 'chain.yml' '0' '[]' 'null' ',"matrix":true')
    ::
      ::  P3 (CI-P3-SCHED-A, rider 2): runs-on as a string or a list is
      ::  the job's label set, timeout-minutes its deadline bound; absent
      ::  is the empty set and no timeout; an expression is refused
      ::
      :-  'runs-on: a string is a one-element set, a list its elements, absent is empty'
      =/  planned=(each (list job:ci) @t)
        %-  check
        %-  plan-json
        %-  rap
        :-  3
        :~  (job-json 'a' 'chain.yml' '0' '[]' 'null' ',"runs-on":"ubuntu-latest"')  ','
            %:  job-json
              'b'
              'chain.yml'
              '1'
              '["a"]'
              cond-eq
              ',"runs-on":["self-hosted","big-mem","self-hosted"],"timeout-minutes":3'
            ==  ','
            (job-json 'pass' 'pass.yml' '0' '[]' 'null' '')
        ==
      ?.  ?=(%& -.planned)  %.n
      ?&  =((silt ~['ubuntu-latest']) runs-on:(snag 0 p.planned))
          =(~ timeout:(snag 0 p.planned))
          =((silt ~['self-hosted' 'big-mem']) runs-on:(snag 1 p.planned))
          =(`3 timeout:(snag 1 p.planned))
          =(~ runs-on:(snag 2 p.planned))
      ==
    ::
      :-  'runs-on expression refused at plan time'
      .=  'runs-on expression unsupported in P3 (job a in chain.yml)'
      %-  reason
      %-  plan-json
      (job-json 'a' 'chain.yml' '0' '[]' 'null' ',"runs-on":"${{ matrix.os }}"')
    ::
      :-  'runs-on expression inside a list refused too'
      .=  'runs-on expression unsupported in P3 (job a in chain.yml)'
      %-  reason
      %-  plan-json
      (job-json 'a' 'chain.yml' '0' '[]' 'null' ',"runs-on":["self-hosted","${{ inputs.label }}"]')
    ::
      :-  'timeout-minutes 0 or non-numeric is no timeout'
      =/  planned=(each (list job:ci) @t)
        %-  check
        %-  plan-json
        (job-json 'a' 'chain.yml' '0' '[]' 'null' ',"timeout-minutes":0')
      ?.  ?=(%& -.planned)  %.n
      =(~ timeout:(snag 0 p.planned))
    ::
      :-  'a condition of another version (the state-3 v1 wire) is refused'
      .=  'job b in chain.yml: if is refused: the condition is not version 2'
      %-  reason
      %-  plan-json
      %-  rap
      :-  3
      :~  (job-json 'a' 'chain.yml' '0' '[]' 'null' '')  ','
          %:  job-json
            'b'
            'chain.yml'
            '1'
            '["a"]'
            '{"v":1,"kind":"output-eq","job":"a","output":"go","literal":"true"}'
            ''
          ==
      ==
    ::
      :-  'a condition with a node the ship does not know is refused'
      .=  'job b in chain.yml: if "x" (line 1, column 1) is refused: unknown expression node always'
      %-  reason
      %-  plan-json
      %-  rap
      :-  3
      :~  (job-json 'a' 'chain.yml' '0' '[]' 'null' '')  ','
          %:  job-json
            'b'
            'chain.yml'
            '1'
            '["a"]'
            '{"v":2,"text":"x","line":1,"col":1,"expr":{"k":"always"}}'
            ''
          ==
      ==
    ::
      :-  'if references a job that is not in needs'
      .=  'job b in chain.yml: if references needs.a, which is not in needs'
      %-  reason
      %-  plan-json
      %+  rap
        3
      ~[(job-json 'a' 'chain.yml' '0' '[]' 'null' '') ',' (job-json 'b' 'chain.yml' '1' '[]' cond-eq '')]
    ::
      :-  'stage must be a natural number'
      .=  'job a in chain.yml: stage -1 is not a natural number'
      %-  reason
      %-  plan-json
      (job-json 'a' 'chain.yml' '-1' '[]' 'null' '')
    ::
      :-  'plan oid must be the candidate oid'
      .=  %+  rap
            3
          ~['plan oid 0000000000000000000000000000000000000000 is not the candidate oid ' oid]
      %-  reason
      %-  need
      %-  de:json:html
      '{"oid":"0000000000000000000000000000000000000000","workflows":["chain.yml","pass.yml"],"jobs":[]}'
    ::
      :-  'workflow files must match the candidate tree'
      .=  'workflow files under .github/workflows differ from the plan: tree has chain.yml, pass.yml; plan has chain.yml'
      %-  reason
      %-  need
      %-  de:json:html
      (rap 3 ~['{"oid":"' oid '","workflows":["chain.yml"],"jobs":[]}'])
    ::
      :-  'a workflow that does not trigger on push is not planned'
      .=  'no push-triggered jobs under .github/workflows'
      %-  reason
      %-  need
      %-  de:json:html
      %-  rap
      :-  3
      :~  '{"oid":"'  oid  '","workflows":["chain.yml","pass.yml"],"jobs":['
          '{"id":"a","workflow":"chain.yml","stage":0,"needs":[],"cond":null,"outputs":[],"events":["workflow_dispatch"]}]}'
      ==
    ::
      :-  'the daemon reporting an error is the reason'
      .=  'act -l: yaml: line 3: did not find expected key'
      %-  reason
      %-  need
      %-  de:json:html
      '{"error":"act -l: yaml: line 3: did not find expected key"}'
    ::
      :-  'evaluate: b waits while a runs'
      =(%wait -:(decide-b (st ~[[key-a %running]]) ~))
    ::
      :-  'evaluate: if true runs'
      =(%run -:(decide-b (st ~[[key-a %passed]]) (ou ~[[key-a (malt ~[['go' 'true']])]])))
    ::
      :-  'evaluate: if false skips with the reason and the value'
      .=  [%skip 'if "needs.a.outputs.go == \'true\'" is false' `'false']
      (decide-b (st ~[[key-a %passed]]) (ou ~[[key-a (malt ~[['go' 'false']])]]))
    ::
      :-  'evaluate: an output never published reads as null, which is not \'true\''
      .=  [%skip 'if "needs.a.outputs.go == \'true\'" is false' `'false']
      (decide-b (st ~[[key-a %passed]]) ~)
    ::
      :-  'evaluate: a failed need skips: the if has no status function, so success() applies'
      .=  [%skip 'skipped: a failed; the if has no status function, so success() applies first' ~]
      (decide-b (st ~[[key-a %failed]]) ~)
    ::
      :-  'evaluate: an infrastructure error is never success'
      .=  [%skip 'skipped: a had an infrastructure error; the if has no status function, so success() applies first' ~]
      (decide-b (st ~[[key-a %unknown]]) ~)
    ::
      :-  'evaluate: a refused condition refuses its job, never false'
      .=  [%error 'if "always()" is refused: unsupported']
      %:  decide:ci-plan
        job-b(cond `[%refused 'always()' 'unsupported'])
        chain-plan
        (st ~[[key-a %passed]])
        ~
        push-ctx
      ==
    ::
      :-  'verdict: fan-out pending while any job is open'
      =([%pending ~] (verdict:ci-plan chain-plan (st ~[[key-a %passed] [key-pass %running]])))
    ::
      :-  'verdict: passed when every job passed or skipped by if'
      =([%passed ~] (verdict:ci-plan chain-plan (st ~[[key-a %passed] [key-b %skipped] [key-pass %passed]])))
    ::
      :-  'verdict: failed sibling leaves running work pending'
      .=  [%pending ~]
      %+  verdict:ci-plan  chain-plan
      (st ~[[key-a %passed] [key-b %running] [key-pass %failed]])
    ::
      :-  'verdict: failed sibling leaves an unstarted job pending'
      .=  [%pending ~]
      (verdict:ci-plan sibling-plan (st ~[[key-a %passed] [key-sibling %failed]]))
    ::
      :-  'evaluate: an unrelated failure does not suppress a ready job'
      =/  ready=decision:ci-plan
        %+  decide-b
          (st ~[[key-a %passed] [key-sibling %failed]])
        (ou ~[[key-a (malt ~[['go' 'true']])]])
      ?=(%run -.ready)
    ::
      :-  'verdict: terminal failure remains failed after other jobs finish'
      .=  [%failed `'job pass in pass.yml failed']
      %+  verdict:ci-plan  chain-plan
      (st ~[[key-a %passed] [key-b %passed] [key-pass %failed]])
    ::
      :-  'verdict: failure and skipped dependent never pass'
      .=  [%failed `'job a in chain.yml failed']
      %+  verdict:ci-plan  chain-plan
      (st ~[[key-a %failed] [key-b %skipped] [key-pass %passed]])
    ::
      :-  'verdict: infrastructure error leaves running work pending'
      .=  [%pending ~]
      %+  verdict:ci-plan  chain-plan
      (st ~[[key-a %unknown] [key-b %skipped] [key-pass %running]])
    ::
      :-  'verdict: infrastructure error leaves an unstarted job pending'
      .=  [%pending ~]
      (verdict:ci-plan chain-plan (st ~[[key-a %unknown] [key-b %skipped]]))
    ::
      :-  'verdict: terminal failure takes precedence over infrastructure error'
      .=  [%failed `'job pass in pass.yml failed']
      %+  verdict:ci-plan  chain-plan
      (st ~[[key-a %unknown] [key-b %skipped] [key-pass %failed]])
    ::
      :-  'verdict: unknown on an infrastructure error with no failure'
      .=  [%unknown `'job a in chain.yml had an infrastructure error']
      (verdict:ci-plan chain-plan (st ~[[key-a %unknown] [key-b %skipped] [key-pass %passed]]))
    ::
      :-  'verdict: a linear chain with no attempts is pending'
      =([%pending ~] (verdict:ci-plan chain-plan ~))
    ::
      ::  a manual run plans the one workflow it dispatches (Delivery 1A)
      ::
      :-  'dispatch: only the selected workflow\'s jobs are planned, its needs kept'
      =/  planned  (dispatch-of 'manual.yml' manual-jobs)
      ?.  ?=(%& -.planned)  %.n
      ?&  =(~['report' 'deploy'] (turn p.planned |=(=job:ci id.job)))
          (levy p.planned |=(=job:ci =('manual.yml' workflow.job)))
          =(~['report'] needs:(snag 1 p.planned))
      ==
    ::
      :-  'dispatch: a workflow that does not trigger on workflow_dispatch is refused'
      .=  [%| 'workflow chain.yml does not trigger on workflow_dispatch at this revision']
      (dispatch-of 'chain.yml' manual-jobs)
    ::
      :-  'dispatch: a workflow the plan does not list is refused'
      .=  [%| 'workflow nope.yml is not a workflow file of this revision']
      (dispatch-of 'nope.yml' manual-jobs)
    ::
      :-  'dispatch: an unsupported construct in another workflow does not refuse it'
      =/  jobs=@t
        %-  rap
        :-  3
        :~  (ev-job 'a' 'chain.yml' '[]' '["push"]' ',"matrix":true')  ','
            (ev-job 'report' 'manual.yml' '[]' '["workflow_dispatch"]' '')
        ==
      =/  got=(each (list job:ci) @t)  (dispatch-of 'manual.yml' jobs)
      ?=(%& -.got)
    ::
      :-  'dispatch: an unsupported construct in the selected workflow refuses it'
      .=  [%| 'matrix unsupported in P1 (job report in manual.yml)']
      %+  dispatch-of
        'manual.yml'
      (ev-job 'report' 'manual.yml' '[]' '["workflow_dispatch"]' ',"matrix":true')
    ::
      :-  'dispatch: needs still never cross a workflow file'
      .=  [%| 'job deploy in manual.yml needs a, which is not a job in manual.yml']
      %+  dispatch-of  'manual.yml'
      %-  rap
      :-  3
      :~  (ev-job 'a' 'chain.yml' '[]' '["push"]' '')  ','
          (ev-job 'deploy' 'manual.yml' '["a"]' '["workflow_dispatch"]' '')
      ==
    ::
      :-  'push: a dispatch-only workflow is not planned for a push'
      =/  planned
        %:  validate:ci-plan  oid  tree-3
          %-  plan-3
          %-  rap
          :-  3
          :~  (ev-job 'a' 'chain.yml' '[]' '["push"]' '')  ','
              (ev-job 'report' 'manual.yml' '[]' '["workflow_dispatch"]' '')
          ==
        ==
      ?.  ?=(%& -.planned)  %.n
      =(~['a'] (turn p.planned |=(=job:ci id.job)))
  ==
::  an event run plans the workflows its event selected (Delivery 1C):
::  chain.yml runs on push and pull_request, pass.yml on push only,
::  manual.yml on workflow_dispatch and schedule
::
=/  event-plan=wire-plan:ci-plan
  %-  plan-3
  %-  rap
  :-  3
  :~  (ev-job 'a' 'chain.yml' '[]' '["push","pull_request"]' '')  ','
      (ev-job 'b' 'chain.yml' '["a"]' '["push","pull_request"]' '')  ','
      (ev-job 'pass' 'pass.yml' '[]' '["push"]' '')  ','
      (ev-job 'report' 'manual.yml' '[]' '["workflow_dispatch","schedule"]' '')
  ==
=/  selected-of
  |=  [event=@t workflows=(list @t)]
  ^-  (each (list job:ci) @t)
  (validate-selected:ci-plan oid tree-3 event-plan event workflows)
=/  ids
  |=  planned=(each (list job:ci) @t)
  ^-  (unit (list @t))
  ?.  ?=(%& -.planned)  ~
  `(turn p.planned |=(=job:ci id.job))
=/  selected-results=(list [name=@t ok=?])
  :~  :-  'selected: the selected workflow\'s jobs that trigger on the event, needs kept'
      =/  planned  (selected-of 'pull_request' ~['chain.yml'])
      ?.  ?=(%& -.planned)  %.n
      ?&(=(~['a' 'b'] (turn p.planned |=(=job:ci id.job))) =(~['a'] needs:(snag 1 p.planned)))
    ::
      :-  'selected: a selected workflow with no job on the event refuses, naming it'
      .=  :-  %|
          %+  rap  3
          :~  'the plan and the trigger catalog disagree: the catalog selects pass.yml for '
              'pull_request, and act lists no job of it that triggers on pull_request'
          ==
      (selected-of 'pull_request' ~['chain.yml' 'pass.yml'])
    ::
      :-  'selected: an excluded workflow is not planned'
      =(`~['pass'] (ids (selected-of 'push' ~['pass.yml'])))
    ::
      :-  'selected: every selected workflow of a required push'
      =(`~['a' 'b' 'pass'] (ids (selected-of 'push' ~['chain.yml' 'pass.yml'])))
    ::
      :-  'selected: a schedule plans its workflow\'s scheduled jobs'
      =(`~['report'] (ids (selected-of 'schedule' ~['manual.yml'])))
    ::
      :-  'selected: nothing selected plans nothing'
      =(`~ (ids (selected-of 'push' ~)))
    ::
      :-  'selected: the plan must still be the candidate\'s'
      .=  [%| (rap 3 ~['plan oid ' oid ' is not the candidate oid 0000000000000000000000000000000000000001'])]
      %:  validate-selected:ci-plan
        '0000000000000000000000000000000000000001'  tree-3  event-plan  'push'  ~['chain.yml']
      ==
    ::
      :-  'selected: validate-for never plans an event run'
      .=  [%| 'an event run plans the workflows its event selected, never every one']
      %:  validate-for:ci-plan  oid  tree-3  event-plan
        [%event [0v1 %push 'refs/heads/main' ~ `0xc1 ~ ~ ~zod 'web editor' ~2026.10.16 '{}']]
      ==
  ==
=.  results  (weld results selected-results)
=/  failures=(list @t)
  (murn results |=([name=@t ok=?] ?:(ok ~ `name)))
~&  [%ci-plan-vector passed=(sub (lent results) (lent failures)) of=(lent results)]
?~  failures  %.y
~&  [%ci-plan-vector-failures failures]
%.n
