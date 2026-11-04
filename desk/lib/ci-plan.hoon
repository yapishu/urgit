::  Plan validation and job-level evaluation: the pure rules %urgit-ci
::  applies to the plan a daemon posts and to the attempts recorded
::  against it.  nothing here scries or parses expression syntax: the
::  daemon compiles every job-level `if` and declared output to a
::  versioned structure (CI-EXPR-2) and the ship checks that structure
::  (lib/ci-expr) and evaluates it.
::
::    every refusal is a reason cord, never a crash and never `false`: a
::    plan the ship cannot validate fails the candidate with the reason
::    (R1-A); a condition that cannot be evaluated refuses its job, which
::    is recorded failed with the reason and never runs (R2.2-A).
::
/-  ci
/+  ci-expr
|%
::  jobs are keyed by [workflow id]: `needs` never crosses a workflow
::  file, and ERPit has a `plan` job in both of its workflows
::
+$  key  [workflow=@t id=@t]
::
::  one job's standing, read off the newest attempt recorded for its key;
::  a job with no attempt is pending.  $? bunts to its last entry, so a
::  defaulted standing is pending: never passed, never skipped.
::  %cancelled (CI-CONCURRENCY-1) is a job of a cancelled workflow run
::  that was stopped or never ran: terminal, and never a pass
::
+$  standing  ?(%passed %failed %skipped %cancelled %unknown %running %pending)
::
::  the wire plan as the daemon posts it, decoded but not yet validated
::
+$  wire-job
  $:  id=@t
      workflow=@t
      name=@t
      stage=@ud
      needs=(list @t)
      cond=(unit condition:ci)
      outputs=(list declared-output:ci)
      matrix=?
      ::  CI-CONCURRENCY-1: the job declares a job-level concurrency
      concurrency=?
      events=(list @t)
      environment=(unit @t)
      runs-on=(set @t)
      timeout=(unit @ud)
  ==
::  P4: .workflows-oid is the revision the daemon read the workflow files
::  at (the baseline under a required run, the candidate under a trial);
::  the ship checks it against the mode.  a plan without it read the
::  candidate's own files (a pre-P4 daemon) and says so.
::
+$  wire-plan  [oid=@t workflows-oid=@t workflows=(list @t) jobs=(list wire-job)]
::
++  quote
  |=  text=@t
  ^-  @t
  (rap 3 ~['"' text '"'])
::
++  job-name
  |=  [id=@t workflow=@t]
  ^-  @t
  (rap 3 ~['job ' id ' in ' workflow])
::
++  join
  |=  [items=(list @t) separator=@t]
  ^-  @t
  ?~  items  ''
  =/  acc=@t  i.items
  =/  rest=(list @t)  t.items
  |-
  ?~  rest  acc
  $(rest t.rest, acc (rap 3 ~[acc separator i.rest]))
::
++  sort-texts
  |=  items=(list @t)
  ^-  (list @t)
  (sort items |=([a=@t b=@t] (aor a b)))
::
::  the plan body.  `error` is the daemon reporting that it could not
::  produce a plan at all (act refused a workflow, the clone failed); its
::  text is the reason.  otherwise oid, workflows and jobs are required.
::
++  parse
  |=  jon=json
  ^-  (each wire-plan @t)
  ?.  ?=([%o *] jon)  [%| 'plan body is not a JSON object']
  =/  fields=(map @t json)  p.jon
  =/  error=(unit @t)  (string-field fields 'error')
  ?^  error  [%| u.error]
  =/  oid=(unit @t)  (string-field fields 'oid')
  ?~  oid  [%| 'plan is missing oid']
  =/  workflows-oid=@t  (fall (string-field fields 'workflows-oid') u.oid)
  =/  workflows=(unit (list @t))  (string-list-field fields 'workflows')
  ?~  workflows  [%| 'plan is missing workflows']
  =/  raw-jobs=(unit json)  (~(get by fields) 'jobs')
  ?~  raw-jobs  [%| 'plan is missing jobs']
  ?.  ?=([%a *] u.raw-jobs)  [%| 'plan jobs is not a list']
  =/  jobs=(each (list wire-job) @t)
    =/  remaining=(list json)  p.u.raw-jobs
    =|  out=(list wire-job)
    |-
    ?~  remaining  [%& (flop out)]
    =/  parsed=(each wire-job @t)  (parse-job i.remaining)
    ?:  ?=(%| -.parsed)  parsed
    $(remaining t.remaining, out [p.parsed out])
  ?:  ?=(%| -.jobs)  jobs
  [%& u.oid workflows-oid u.workflows p.jobs]
::
++  parse-job
  |=  jon=json
  ^-  (each wire-job @t)
  ?.  ?=([%o *] jon)  [%| 'plan job is not a JSON object']
  =/  fields=(map @t json)  p.jon
  =/  id=(unit @t)  (string-field fields 'id')
  =/  workflow=(unit @t)  (string-field fields 'workflow')
  ?~  id  [%| 'plan job is missing id']
  ?~  workflow  [%| (rap 3 ~['job ' u.id ' is missing workflow'])]
  =/  name=@t  (job-name u.id u.workflow)
  =/  stage=(unit @ud)
    =/  value=(unit json)  (~(get by fields) 'stage')
    ?~  value  ~
    ?.  ?=([%n *] u.value)  ~
    (slaw %ud p.u.value)
  ?~  stage
    =/  shown=@t
      =/  value=(unit json)  (~(get by fields) 'stage')
      ?~  value  'missing'
      ?.  ?=([%n *] u.value)  'not a number'
      p.u.value
    [%| (rap 3 ~[name ': stage ' shown ' is not a natural number'])]
  =/  needs=(unit (list @t))  (string-list-field fields 'needs')
  ?~  needs  [%| (rap 3 ~[name ': needs is not a list of job ids'])]
  =/  matrix=?
    =/  value=(unit json)  (~(get by fields) 'matrix')
    ?~  value  %.n
    ?.  ?=([%b *] u.value)  %.n
    p.u.value
  ::  a job-level concurrency (CI-CONCURRENCY-1), which the runner's
  ::  compiler always sends; read as matrix is, absent being undeclared
  ::  (a runner older than this release cannot say)
  ::
  =/  concurrency=?
    =/  value=(unit json)  (~(get by fields) 'concurrency')
    ?~  value  %.n
    ?.  ?=([%b *] u.value)  %.n
    p.u.value
  =/  events=(unit (list @t))  (string-list-field fields 'events')
  ?~  events  [%| (rap 3 ~[name ': events is not a list'])]
  =/  cond=(each (unit condition:ci) @t)  (parse-cond fields name)
  ?:  ?=(%| -.cond)  cond
  =/  outputs=(each (list declared-output:ci) @t)  (parse-outputs fields name)
  ?:  ?=(%| -.outputs)  outputs
  =/  workflow-name=@t  (fall (string-field fields 'name') '')
  ::  the job's `environment:` name, for %env-scoped credentials (D4);
  ::  absent or empty means the job names none
  ::
  =/  environment=(unit @t)
    =/  value=(unit @t)  (string-field fields 'environment')
    ?~  value  ~
    ?:  =('' u.value)  ~
    value
  ::  the job's `runs-on` as a set (CI-P3-SCHED-A): a string is a
  ::  one-element set, a list its elements; absent is the empty set, which
  ::  every daemon covers
  ::
  =/  runs-on=(set @t)
    =/  value=(unit json)  (~(get by fields) 'runs-on')
    ?~  value  ~
    ?:  ?=([%s *] u.value)  ?:(=('' p.u.value) ~ (silt ~[p.u.value]))
    ?.  ?=([%a *] u.value)  ~
    %-  silt
    %+  murn  p.u.value
    |=  item=json
    ?.  ?=([%s *] item)  ~
    ?:(=('' p.item) ~ `p.item)
  ::  the job's `timeout-minutes` (CI-DELIVERY-1.1 c): a natural number
  ::  of minutes when declared; anything else is no timeout
  ::
  =/  timeout=(unit @ud)
    =/  value=(unit json)  (~(get by fields) 'timeout-minutes')
    ?~  value  ~
    ?.  ?=([%n *] u.value)  ~
    =/  parsed=(unit @ud)  (rush p.u.value dim:ag)
    ?~  parsed  ~
    ?:(=(0 u.parsed) ~ parsed)
  :*  %&  u.id  u.workflow  workflow-name  u.stage  u.needs  p.cond  p.outputs
      matrix  concurrency  u.events  environment  runs-on  timeout
  ==
::
::  the compiled condition (CI-EXPR-2): absent or null means none;
::  otherwise version 2, its tree checked node by node (lib/ci-expr), or
::  the compiler's own refusal.  either refusal refuses the plan with the
::  job, the text and where the workflow wrote it: a condition the ship
::  cannot evaluate is never read as false
::
++  parse-cond
  |=  [fields=(map @t json) name=@t]
  ^-  (each (unit condition:ci) @t)
  =/  value=(unit json)  (~(get by fields) 'cond')
  ?~  value  [%& ~]
  ?:  ?=(~ u.value)  [%& ~]
  =/  parsed=(each condition:ci @t)  (parse-condition:ci-expr u.value)
  ?:  ?=(%| -.parsed)
    [%| (rap 3 ~[name ': if ' (written u.value) 'is refused: ' p.parsed])]
  [%& `p.parsed]
::
::  where a compiled field was written, for a refusal: its text (at most
::  200 bytes) and line and column, when the wire names them
::
++  written
  |=  jon=json
  ^-  @t
  ?.  ?=([%o *] jon)  ''
  =/  text=(unit @t)  (string-field p.jon 'text')
  =/  line=(unit json)  (~(get by p.jon) 'line')
  =/  col=(unit json)  (~(get by p.jon) 'col')
  ?~  text  ''
  =/  place=@t
    ?.  ?&(?=([~ %n *] line) ?=([~ %n *] col))  ''
    (rap 3 ~['(line ' p.u.line ', column ' p.u.col ') '])
  (rap 3 ~[(quote (shown:ci-expr u.text)) ' ' place])
::
::  the declared outputs (CI-EXPR-2): a list the compiler always sends,
::  empty for a job that declares none; at most 64, each name once, each
::  checked; a refused one refuses the plan
::
++  parse-outputs
  |=  [fields=(map @t json) name=@t]
  ^-  (each (list declared-output:ci) @t)
  =/  value=(unit json)  (~(get by fields) 'outputs')
  ?.  ?=([~ %a *] value)
    [%| (rap 3 ~[name ': the plan carries no outputs list; the runner\'s compiler predates declared outputs'])]
  =/  items=(list json)  p.u.value
  =/  count=@ud  (lent items)
  ?:  (gth count max-outputs:ci-expr)
    [%| (rap 3 ~[name ' declares ' (crip (a-co:co count)) ' outputs; the bound is 64'])]
  =|  out=(list declared-output:ci)
  =|  names=(set @t)
  |-
  ?~  items  [%& (flop out)]
  =/  label=@t
    ?.  ?=([%o *] i.items)  ''
    (fall (string-field p.i.items 'name') '')
  =/  one=(each declared-output:ci @t)  (parse-output:ci-expr i.items)
  ?:  ?=(%| -.one)
    [%| (rap 3 ~[name ': output ' label ' ' (written i.items) 'is refused: ' p.one])]
  ?:  (~(has in names) name.p.one)
    [%| (rap 3 ~[name ': output ' name.p.one ' is declared twice'])]
  $(items t.items, out [p.one out], names (~(put in names) name.p.one))
::
++  string-field
  |=  [fields=(map @t json) name=@t]
  ^-  (unit @t)
  =/  value=(unit json)  (~(get by fields) name)
  ?~  value  ~
  ?.  ?=([%s *] u.value)  ~
  `p.u.value
::
++  string-list-field
  |=  [fields=(map @t json) name=@t]
  ^-  (unit (list @t))
  =/  value=(unit json)  (~(get by fields) name)
  ?~  value  `~
  ?.  ?=([%a *] u.value)  ~
  =/  remaining=(list json)  p.u.value
  =|  out=(list @t)
  |-
  ?~  remaining  `(flop out)
  ?.  ?=([%s *] i.remaining)  ~
  $(remaining t.remaining, out [p.i.remaining out])
::
::  validation against the candidate: the plan was read at the candidate
::  oid; the workflow files it names are exactly the ones under
::  .github/workflows in the candidate's tree; every job id is unique per
::  workflow and every stage a natural number (parse); `needs` names jobs
::  of the same workflow; every condition is one the ship evaluates; no
::  job carries a matrix.  jobs whose workflow does not trigger on push
::  are not planned: a push is what staged the candidate.
::
++  validate
  |=  [candidate=@t tree=(list @t) plan=wire-plan]
  ^-  (each (list job:ci) @t)
  =/  common=(unit @t)  (plan-problem candidate tree plan)
  ?^  common  [%| u.common]
  =/  problem=(unit @t)  (job-problem workflows.plan jobs.plan)
  ?^  problem  [%| u.problem]
  =/  planned=(list job:ci)
    %+  murn  jobs.plan
    |=  =wire-job
    ^-  (unit job:ci)
    ?.  (lien events.wire-job |=(event=@t =('push' event)))  ~
    `(to-job wire-job)
  ?~  planned
    [%| 'no push-triggered jobs under .github/workflows']
  [%& planned]
::
::  validation for the event a candidate runs for (Delivery 1A).  a push
::  is +validate.  a manual run plans exactly the jobs of the one
::  workflow it dispatches, which must trigger on workflow_dispatch, and
::  the job checks apply to those jobs: a construct this release refuses
::  in an unrelated workflow does not refuse the run
::
++  validate-for
  |=  [candidate=@t tree=(list @t) plan=wire-plan =trigger:ci]
  ^-  (each (list job:ci) @t)
  ?:  ?=(%push -.trigger)  (validate candidate tree plan)
  ::  an event run plans what its event selected (+validate-selected)
  ?:  ?=(%event -.trigger)
    [%| 'an event run plans the workflows its event selected, never every one']
  =/  common=(unit @t)  (plan-problem candidate tree plan)
  ?^  common  [%| u.common]
  =/  file=@t  workflow.trigger
  ?.  (lien workflows.plan |=(name=@t =(name file)))
    [%| (rap 3 ~['workflow ' file ' is not a workflow file of this revision'])]
  =/  selected=(list wire-job)
    %+  skim  jobs.plan
    |=  =wire-job
    ?&  =(file workflow.wire-job)
        (lien events.wire-job |=(event=@t =('workflow_dispatch' event)))
    ==
  ?~  selected
    [%| (rap 3 ~['workflow ' file ' does not trigger on workflow_dispatch at this revision'])]
  =/  problem=(unit @t)  (job-problem workflows.plan selected)
  ?^  problem  [%| u.problem]
  [%& (turn selected to-job)]
::
::  validation for a run whose workflows an event selected (Delivery 1C):
::  the jobs of exactly the selected workflows that trigger on the event,
::  every selected workflow with at least one (else the plan and the
::  catalog disagree, and the plan is refused), the job checks over those
::  jobs.  no selected workflow plans no job: a required push whose every
::  push workflow was excluded keeps its exclusions as its record
::
++  validate-selected
  |=  [candidate=@t tree=(list @t) plan=wire-plan event=@t workflows=(list @t)]
  ^-  (each (list job:ci) @t)
  =/  common=(unit @t)  (plan-problem candidate tree plan)
  ?^  common  [%| u.common]
  =/  chosen=(set @t)  (silt workflows)
  =/  selected=(list wire-job)
    %+  skim  jobs.plan
    |=  =wire-job
    ?&  (~(has in chosen) workflow.wire-job)
        (lien events.wire-job |=(e=@t =(event e)))
    ==
  =/  bare=(unit @t)
    %+  find-first  workflows
    |=(w=@t !(lien selected |=(j=wire-job =(w workflow.j))))
  ?^  bare
    :-  %|
    %+  rap  3
    :~  'the plan and the trigger catalog disagree: the catalog selects '
        u.bare  ' for '  event  ', and act lists no job of it that triggers on '  event
    ==
  =/  problem=(unit @t)  (job-problem workflows.plan selected)
  ?^  problem  [%| u.problem]
  [%& (turn selected to-job)]
::
::  the plan's own identity: read at the candidate, naming exactly the
::  workflow files of the tree
::
++  plan-problem
  |=  [candidate=@t tree=(list @t) plan=wire-plan]
  ^-  (unit @t)
  ?.  =(candidate oid.plan)
    `(rap 3 ~['plan oid ' oid.plan ' is not the candidate oid ' candidate])
  =/  in-tree=(list @t)
    %-  sort-texts
    %+  skim  tree
    |=  name=@t
    =/  width=@ud  (met 3 name)
    ?|  &((gth width 4) =('.yml' (rsh [3 (sub width 4)] name)))
        &((gth width 5) =('.yaml' (rsh [3 (sub width 5)] name)))
    ==
  =/  named=(list @t)  (sort-texts workflows.plan)
  ?:  =(in-tree named)  ~
  :-  ~
  %-  rap
  :-  3
  :~  'workflow files under .github/workflows differ from the plan: tree has '
      (join in-tree ', ')  '; plan has '  (join named ', ')
  ==
::
::  the checks every planned job must pass; each walks the jobs once and
::  stops at the first refusal
::
++  job-problem
  |=  [workflows=(list @t) jobs=(list wire-job)]
  ^-  (unit @t)
  =/  ids=(set key)
    %-  silt
    %+  turn  jobs
    |=(=wire-job [workflow.wire-job id.wire-job])
  =/  remaining=(list wire-job)  jobs
  =|  seen=(set key)
  |-
  ?~  remaining  ~
  =/  =wire-job  i.remaining
  =/  name=@t  (job-name id.wire-job workflow.wire-job)
  =/  k=key  [workflow.wire-job id.wire-job]
  ?:  (~(has in seen) k)
    `(rap 3 ~['duplicate job id ' id.wire-job ' in ' workflow.wire-job])
  ?.  (lien workflows |=(name=@t =(name workflow.wire-job)))
    `(rap 3 ~[name ': workflow ' workflow.wire-job ' is not in the plan'])
  ?:  matrix.wire-job
    `(rap 3 ~['matrix unsupported in P1 (' name ')'])
  ::  a job-level concurrency is refused with the reason, never ignored
  ::  (CI-CONCURRENCY-1): only a workflow's concurrency group is evaluated
  ::
  ?:  concurrency.wire-job
    `(rap 3 ~['job-level concurrency is refused in this release (' name '): only a workflow\'s concurrency group is supported'])
  ::  runs-on is matched as literal labels (CI-P3-SCHED-A, rider 2): an
  ::  expression there could never match a daemon and is refused now,
  ::  never left pending
  ::
  ?:  (lien ~(tap in runs-on.wire-job) has-expression)
    `(rap 3 ~['runs-on expression unsupported in P3 (' name ')'])
  =/  missing=(unit @t)
    %+  find-first  needs.wire-job
    |=(need=@t !(~(has in ids) [workflow.wire-job need]))
  ?^  missing
    `(rap 3 ~[name ' needs ' u.missing ', which is not a job in ' workflow.wire-job])
  ::  a condition or an output reads needs.<id> of a job it does not
  ::  need: GitHub's linter refuses it, and the ship would read null
  ::
  =/  named=(list [where=@t id=@t])
    (named-needs:ci-expr cond.wire-job outputs.wire-job)
  =/  stray=(unit [where=@t id=@t])
    =/  items  named
    |-
    ?~  items  ~
    ?.  (lien needs.wire-job |=(need=@t =((cass (trip need)) (cass (trip id.i.items)))))
      `i.items
    $(items t.items)
  ?^  stray
    `(rap 3 ~[name ': ' where.u.stray ' references needs.' id.u.stray ', which is not in needs'])
  $(remaining t.remaining, seen (~(put in seen) k))
::
++  to-job
  |=  =wire-job
  ^-  job:ci
  :*  id.wire-job  workflow.wire-job  name.wire-job  stage.wire-job
      needs.wire-job  cond.wire-job  environment.wire-job
      runs-on.wire-job  timeout.wire-job  `outputs.wire-job
  ==
::
::  whether a label carries a `${{` expression opener
::
++  has-expression
  |=  label=@t
  ^-  ?
  =/  chars=tape  (trip label)
  |-
  ?~  chars  %.n
  ?:  =("$\{\{" (scag 3 `tape`chars))  %.y
  $(chars t.chars)
::
++  find-first
  |=  [items=(list @t) test=$-(@t ?)]
  ^-  (unit @t)
  ?~  items  ~
  ?:  (test i.items)  `i.items
  $(items t.items)
::
::  what to do with a job whose own attempt has not been recorded: wait
::  while any job it needs is open, then decide (CI-EXPR-2):
::    - no condition is GitHub's implicit success(): it runs when every
::      ancestor (its needs, and theirs) succeeded, else it is skipped
::      naming the first that did not;
::    - a condition with a status function (success, failure, always,
::      cancelled) is evaluated as written, whatever the needs did, so a
::      failed or skipped need never suppresses it;
::    - a condition without one is success() && (condition), short-
::      circuited: the condition is not read once success() is false;
::    - a value that cannot be computed refuses the job with the reason
::      (%error), never false.
::  a need's result is success, failure or skipped as GitHub names them;
::  an infrastructure error is never success: it reads as failure.  a
::  state-3 plan's %output-eq keeps the meaning it was admitted under.
::
::  in a cancelled workflow run (CI-CONCURRENCY-1) cancelled() is true and
::  success() false, as GitHub reads them: a job whose if holds runs
::  (always()), and one that does not run is %cancel, never a skip
::
+$  decision
  $%  [%run reason=@t value=(unit @t)]
      [%skip reason=@t value=(unit @t)]
      [%cancel reason=@t value=(unit @t)]
      [%error reason=@t]
      [%wait reason=@t]
  ==
::
::  the run a decision reads: its event and payload, ref, source and
::  actor (the github context), its typed inputs, and whether it was
::  cancelled
::
+$  run-context
  $:  event=@t
      payload=@t
      ref=@t
      sha=@t
      actor=@t
      inputs=val:ci-expr
      cancelled=?
  ==
::
++  result-word
  |=  =standing
  ^-  @t
  ?+  standing  'failure'
    %passed  'success'
    %skipped  'skipped'
    %cancelled  'cancelled'
  ==
::
++  standing-text
  |=  =standing
  ^-  @t
  ?-  standing
    %passed  'succeeded'
    %failed  'failed'
    %skipped  'was skipped'
    %cancelled  'was cancelled'
    %unknown  'had an infrastructure error'
    %running  'is running'
    %pending  'is pending'
  ==
::
::  a job's ancestors in its workflow: its needs first, then theirs
::
++  ancestors
  |=  [=job:ci plan=(list job:ci)]
  ^-  (list @t)
  =/  by-id=(map @t job:ci)
    %-  malt
    %+  turn  (skim plan |=(j=job:ci =(workflow.j workflow.job)))
    |=(j=job:ci [id.j j])
  =|  seen=(set @t)
  =|  order=(list @t)
  =/  todo=(list @t)  needs.job
  |-
  ?~  todo  (flop order)
  ?:  (~(has in seen) i.todo)  $(todo t.todo)
  =/  found=(unit job:ci)  (~(get by by-id) i.todo)
  %=  $
    todo  (weld t.todo ?~(found ~ needs.u.found))
    seen  (~(put in seen) i.todo)
    order  [i.todo order]
  ==
::
::  the entries of a job's direct needs, in its needs order
::
++  direct-entries
  |=  [=job:ci entries=(map key need-entry:ci)]
  ^-  (list need-entry:ci)
  (murn needs.job |=(need=@t (~(get by entries) [workflow.job need])))
::
::  the scope a job's condition reads
::
++  job-scope
  |=  [=job:ci entries=(map key need-entry:ci) =run-context status=[success=? failure=?]]
  ^-  scope:ci-expr
  :*  %:  github-of:ci-expr
        event.run-context  payload.run-context  ref.run-context
        sha.run-context  actor.run-context  name.job  id.job
      ==
      (needs-of:ci-expr (direct-entries job entries))
      [%obj ~]
      inputs.run-context
      [%obj ~]
      success.status
      failure.status
      cancelled.run-context
  ==
::
++  decide
  |=  $:  =job:ci
          plan=(list job:ci)
          standings=(map key standing)
          entries=(map key need-entry:ci)
          =run-context
      ==
  ^-  decision
  =/  open=(unit @t)
    %+  find-first  needs.job
    |=  need=@t
    ?=(?(%pending %running) (~(gut by standings) [workflow.job need] %pending))
  ?^  open  [%wait (rap 3 ~['waiting for ' u.open])]
  =/  family=(list @t)  (ancestors job plan)
  =/  word
    |=  id=@t
    ^-  @t
    (result-word (~(gut by standings) [workflow.job id] %pending))
  ::  success() is false in a cancelled run (CI-CONCURRENCY-1)
  =/  cancelled=?  cancelled.run-context
  =/  succeeded=?  ?&(!cancelled (levy family |=(id=@t =('success' (word id)))))
  =/  failed=?  (lien family |=(id=@t =('failure' (word id))))
  =/  blocker=@t
    =/  first=(unit @t)  (find-first family |=(id=@t !=('success' (word id))))
    ?~  first  ''
    (rap 3 ~[u.first ' ' (standing-text (~(gut by standings) [workflow.job u.first] %pending))])
  =/  stopped=@t  'not run: the workflow run was cancelled'
  ?~  cond.job
    ?:  succeeded
      [%run ?~(needs.job 'no prerequisites' 'every prerequisite succeeded') ~]
    ?:  cancelled
      [%cancel (rap 3 ~[stopped '; the job has no if, so success() applies, and it is false']) ~]
    [%skip (rap 3 ~['skipped: ' blocker]) ~]
  =/  cond=summary:ci-expr  (summarize:ci-expr u.cond.job)
  ?-  -.cond
      %refused
    [%error (rap 3 ~['if ' (quote (shown:ci-expr text.cond)) ' is refused: ' reason.cond])]
::
      %output-eq
    ::  a state-3 gate reads success() first, which a cancelled run fails
    ?:  cancelled  [%cancel stopped ~]
    (legacy job cond standings entries)
  ::
      %if
    =/  shown=@t  (quote (shown:ci-expr text.cond))
    ?:  ?&(!status.cond !succeeded)
      ?:  cancelled
        :+  %cancel
          (rap 3 ~[stopped '; the if ' shown ' has no status function, so success() applies first, and it is false'])
        ~
      [%skip (rap 3 ~['skipped: ' blocker '; the if has no status function, so success() applies first']) ~]
    =/  value=(each val:ci-expr @t)
      (eval-condition:ci-expr u.cond.job (job-scope job entries run-context [succeeded failed]))
    ?:  ?=(%| -.value)
      [%error (rap 3 ~['if ' shown ' could not be evaluated: ' p.value])]
    =/  seen=@t  (render:ci-expr p.value)
    ?:  (truthy:ci-expr p.value)  [%run (rap 3 ~['if ' shown ' is ' seen]) `seen]
    ?:  cancelled  [%cancel (rap 3 ~[stopped '; if ' shown ' is ' seen]) `seen]
    [%skip (rap 3 ~['if ' shown ' is ' seen]) `seen]
  ==
::
::  a state-3 plan's gate, as it was admitted (CI-EXPR-1): every need
::  passed, then the named output the need recorded equals the literal
::  exactly; an output never set is a skip with the reason
::
++  legacy
  |=  [=job:ci cond=summary:ci-expr standings=(map key standing) entries=(map key need-entry:ci)]
  ^-  decision
  ?>  ?=(%output-eq -.cond)
  =/  needs=(list @t)  needs.job
  |-
  ?^  needs
    =/  standing=standing  (~(gut by standings) [workflow.job i.needs] %pending)
    ?+  standing  [%wait (rap 3 ~['waiting for ' i.needs])]
      %failed  [%skip (rap 3 ~['needs ' i.needs ' failed']) ~]
      %unknown  [%skip (rap 3 ~['needs ' i.needs ' did not complete']) ~]
      %skipped  [%skip (rap 3 ~['needs ' i.needs ' was skipped']) ~]
      %passed  $(needs t.needs)
    ==
  =/  reference=@t  (rap 3 ~['needs.' job.cond '.outputs.' output.cond])
  =/  entry=(unit need-entry:ci)  (~(get by entries) [workflow.job job.cond])
  =/  value=(unit @t)
    ?~  entry  ~
    =/  hits  (skim outputs.u.entry |=([k=@t v=@t] =(k output.cond)))
    ?~(hits ~ `+.i.hits)
  ?~  value  [%skip (rap 3 ~['output not set: ' reference]) ~]
  ?:  =(u.value literal.cond)
    [%run (rap 3 ~[reference ' is ' (quote u.value)]) `(quote u.value)]
  :+  %skip
    (rap 3 ~['if false: ' reference ' is ' (quote u.value) ', not ' (quote literal.cond)])
  `(quote u.value)
::
::  keep the candidate pending while any job is open, so the scheduler
::  can finish independent jobs after a failure.  pending never permits
::  landing.  once all jobs are terminal, failure takes precedence over
::  infrastructure error.  otherwise every job passed or skipped.  an `if`
::  that is false is GitHub's skip, and ERPit's plan gates depend on it.
::
++  verdict
  |=  [plan=(list job:ci) standings=(map key standing)]
  ^-  [status=candidate-status:ci reason=(unit @t)]
  (verdict-in plan standings ~)
::
::  the verdict of a run some of whose workflow runs were cancelled
::  (CI-CONCURRENCY-1): a cancelled workflow's conclusion is cancelled, as
::  on GitHub — a job of it that failed (an always() job) does not make
::  the run failed — yet an infrastructure error anywhere still needs
::  review.  failure of another workflow first, then unknown, then
::  cancelled, then passed; open jobs keep it pending
::
++  verdict-in
  |=  [plan=(list job:ci) standings=(map key standing) cancelled=(set @t)]
  ^-  [status=candidate-status:ci reason=(unit @t)]
  =/  open=?
    %+  lien  plan
    |=  =job:ci
    =/  standing=standing  (~(gut by standings) [workflow.job id.job] %pending)
    ?=(?(%pending %running) standing)
  ?:  open  [%pending ~]
  =/  live=(list job:ci)
    (skip plan |=(=job:ci (~(has in cancelled) workflow.job)))
  =/  gone=(list job:ci)
    (skim plan |=(=job:ci (~(has in cancelled) workflow.job)))
  =/  failed=(unit job:ci)
    (find-job live standings %failed)
  ?^  failed
    [%failed `(rap 3 ~[(job-name id.u.failed workflow.u.failed) ' failed'])]
  =/  unknown=(unit job:ci)
    (find-job plan standings %unknown)
  ?^  unknown
    [%unknown `(rap 3 ~[(job-name id.u.unknown workflow.u.unknown) ' had an infrastructure error'])]
  ?^  gone
    [%cancelled `(rap 3 ~['the run of ' workflow.i.gone ' was cancelled'])]
  =/  stopped=(unit job:ci)
    (find-job plan standings %cancelled)
  ?^  stopped
    [%cancelled `(rap 3 ~[(job-name id.u.stopped workflow.u.stopped) ' was cancelled'])]
  [%passed ~]
::
++  find-job
  |=  [plan=(list job:ci) standings=(map key standing) want=standing]
  ^-  (unit job:ci)
  ?~  plan  ~
  ?:  =(want (~(gut by standings) [workflow.i.plan id.i.plan] %pending))
    `i.plan
  $(plan t.plan)
--
