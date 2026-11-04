::  Workflow concurrency groups (CI-CONCURRENCY-1): the pure transitions
::  %urgit-ci applies when a run joins its workflows' groups, when a run in
::  progress finishes and its group's waiting run starts, and when a
::  workflow's run is cancelled — by a newer run of its group or by an
::  operator's Cancel, one path for both — and the gate every job's
::  decision passes first.  the controller calls these arms with its
::  state, and desk/gen/ci-concurrency-vector calls the same arms.  the run
::  records a decision reads (standings, the needs context, the run
::  context) live here too, so both read one definition.  nothing here
::  scries.
::
::    GitHub's rules, as ratified: a workflow-level group is evaluated
::    from the github, inputs and vars contexts the run's jobs see; groups
::    are the repository's, across its workflows, and compared without
::    case.  a newcomer's own cancel-in-progress decides: true cancels
::    every running and waiting run of its group; false waits behind the
::    run in progress, and a group keeps one waiting run — a newer arrival
::    cancels the older waiting run, whatever the flags say.  when the run
::    in progress finishes, the waiting run starts.  cancelling evaluates
::    each running job's if again with cancelled() true: a job whose if
::    holds (always()) keeps running, the rest are stopped; a run
::    cancelled while it waited never started and runs no job at all.
::
/-  ci, git
/+  ci-cron, ci-dispatch, ci-expr, ci-plan, ci-provenance, ci-trigger, git-codec
|%
::  a run's workflow that holds or waits in a group, and one that waits
::
+$  occupant  [id=candidate-id:ci workflow=@t place=group-place:ci since=@da]
+$  waiter  [id=candidate-id:ci repo=@t workflow=@t key=@t since=@da]
::
::  ---- what takes part ----
::
::  why a run takes part in no group by rule, or ~ when it takes part:
::  required, event (push, pull request, schedule, tag), manual and shadow
::  runs — the runs with a GitHub counterpart — do.  a trial twin does not
::  (it evaluates its required twin's group and would cancel it), nor does
::  a resolver record (dependency maintenance, no run of the workflows)
::
++  exempt
  |=  c=candidate:ci
  ^-  (unit @t)
  ?:  =('refs/ci/resolve' ref.c)
    `'a dependency resolution is not a run of the workflows: it takes part in no concurrency group'
  ?:  =(%trial mode.c)
    `'a trial twin takes part in no concurrency group: it would evaluate its required twin\'s group and cancel it'
  ~
::
::  a new run's concurrency: it joins once its workflows and its context
::  are known, unless by rule it takes part in none
::
++  initial
  |=  c=candidate:ci
  ^-  run-concurrency:ci
  =/  why=(unit @t)  (exempt c)
  ?~  why  [%pending ~]
  [%exempt u.why]
::
::  the reason a workflow's concurrency is unknown: its lock read none
::
++  unread
  ^-  @t
  'concurrency not read for this lock: resolve or promote again to apply it'
::
::  ---- the run records a decision reads ----
::
::  a job of a run's plan, by workflow and id
::
++  planned-job
  |=  [c=candidate:ci workflow=(unit @t) job=(unit @t)]
  ^-  (unit job:ci)
  ?~  plan.c  ~
  ?~  workflow  ~
  ?~  job  ~
  =/  jobs=(list job:ci)  u.plan.c
  |-
  ?~  jobs  ~
  ?:  &(=(u.workflow workflow.i.jobs) =(u.job id.i.jobs))  `i.jobs
  $(jobs t.jobs)
::
::  whether a workflow's run of a candidate is cancelled, or the whole run
::
++  workflow-cancelled
  |=  [c=candidate:ci workflow=@t]
  ^-  ?
  |((~(has by cancelled.c) workflow) (~(has by cancelled.c) ''))
::
::  the cancellation of a workflow's run: its own, else the whole run's
::
++  cancellation-of
  |=  [c=candidate:ci workflow=@t]
  ^-  (unit cancellation:ci)
  =/  own=(unit cancellation:ci)  (~(get by cancelled.c) workflow)
  ?^  own  own
  (~(get by cancelled.c) '')
::
::  the newest job attempt per [workflow id] is that job's standing, and
::  the accepted attempt a dependent's decision and needs context read.  a
::  re-offered attempt stands for nothing, and so does a cancelled one —
::  the job is owed a fresh attempt — unless its workflow's run was
::  cancelled (CI-CONCURRENCY-1): then it is the job's end, %cancelled.
::  evidence from another generation stands for nothing (P11)
::
++  standings
  |=  [s=state-0:ci c=candidate:ci]
  ^-  [standings=(map key:ci-plan standing:ci-plan) newest=(map key:ci-plan attempt:ci)]
  =/  newest=(map key:ci-plan attempt:ci)
    %+  roll  (flop attempts.c)
    |=  [id=attempt-id:ci acc=(map key:ci-plan attempt:ci)]
    =/  found=(unit attempt:ci)  (~(get by attempts.s) id)
    ?~  found  acc
    ?.  ?=(%job kind.u.found)  acc
    ?~  workflow.u.found  acc
    ?~  job.u.found  acc
    ?:  =(%reoffered status.u.found)  acc
    ?:  ?&  =(%cancelled status.u.found)
            !(workflow-cancelled c u.workflow.u.found)
        ==
      acc
    ?.  =(generation.u.found generation.c)  acc
    (~(put by acc) [u.workflow.u.found u.job.u.found] u.found)
  :_  newest
  %-  ~(run by newest)
  |=  =attempt:ci
  ^-  standing:ci-plan
  ?-  status.attempt
    %passed  %passed
    %failed  %failed
    %skipped  %skipped
    %running  %running
    %reoffered  %pending
    %cancelled  %cancelled
    %infrastructure-error  %unknown
  ==
::
::  a push candidate's event payload: its ref, its base as before, and as
::  after the integration object the manifest signs as its source (''
::  until %urgit has materialized it); its actor pushed
::
++  push-payload-of
  |=  c=candidate:ci
  ^-  @t
  %:  push-payload:ci-dispatch
    ref.c
    (oid-text:git-codec base.c)
    (oid-hex:ci-provenance candidate.c)
    actor.c
  ==
::
::  the run a candidate's decisions read (CI-EXPR-2): its event, the
::  payload act reads, ref, source and actor, and its typed inputs.
::  cancelled() is read per job, for the job's own workflow (+job-context)
::
++  run-context
  |=  c=candidate:ci
  ^-  run-context:ci-plan
  :*  (event-name:ci-trigger trigger.c)
      ?-  -.trigger.c
        %push  (push-payload-of c)
        %dispatch  payload.trigger.c
        %event  payload.run-event.trigger.c
      ==
      ref.c
      (oid-hex:ci-provenance candidate.c)
      (scot %p actor.c)
      ?-(-.trigger.c %push [%obj ~], %event [%obj ~], %dispatch (inputs-of:ci-expr inputs.trigger.c))
      %.n
  ==
::
::  the run context of one workflow's job: cancelled() is whether that
::  workflow's run was cancelled
::
++  job-context
  |=  [c=candidate:ci workflow=@t]
  ^-  run-context:ci-plan
  =/  context=run-context:ci-plan  (run-context c)
  context(cancelled (workflow-cancelled c workflow))
::
::  every terminal job's entry as its dependents' decisions and needs
::  contexts read it: the accepted attempt, its status and result, and the
::  outputs it published
::
++  need-entries
  |=  $:  c=candidate:ci
          newest=(map key:ci-plan attempt:ci)
          standings=(map key:ci-plan standing:ci-plan)
      ==
  ^-  (map key:ci-plan need-entry:ci)
  %-  malt
  %+  turn  ~(tap by newest)
  |=  [k=key:ci-plan att=attempt:ci]
  ^-  [key:ci-plan need-entry:ci]
  :-  k
  :*  id.k
      id.att
      status.att
      (result-word:ci-plan (~(gut by standings) k %pending))
      (published-outputs (planned-job c `workflow.k `id.k) att)
  ==
::
::  what an attempt published to its dependents: its declared outputs as
::  resolved when it closed; for a job of a plan saved before state-4,
::  every output it recorded, by name, the meaning that plan was admitted
::  under (its declarations were never read)
::
++  published-outputs
  |=  [planned=(unit job:ci) a=attempt:ci]
  ^-  (list [name=@t value=@t])
  ?:  ?&(?=(^ planned) ?=(~ outputs.u.planned))
    (legacy-outputs step-outputs.a)
  ?~  job-outputs.a  ~
  %+  murn  u.job-outputs.a
  |=  o=job-output:ci
  ?.  ?=(%& -.value.o)  ~
  `[name.o p.value.o]
::
++  legacy-outputs
  |=  outputs=(list step-output:ci)
  ^-  (list [name=@t value=@t])
  ~(tap by (malt (turn outputs |=(o=step-output:ci [name.o value.o]))))
::
::  ---- landing ----
::
::  what may land (D3; P4 D5): a passed, materialized, trusted, required
::  candidate whose bindings — incarnation, policy generation, baseline
::  and lock — are the repository's current ones.  a cancelled run is not
::  passed and never lands (CI-CONCURRENCY-1); the controller's
::  eligibility scries and its settle read this one arm
::
++  landable
  |=  [s=state-0:ci c=candidate:ci]
  ^-  ?
  ?&  =(%passed status.c)
      =(%trusted trust.c)
      ?=(^ candidate.c)
      =(%required mode.c)
      (bindings-current s c)
  ==
::
::  the candidate's bindings against the repository's current policy
::
++  bindings-current
  |=  [s=state-0:ci c=candidate:ci]
  ^-  ?
  =/  base=(unit baseline:ci)  (~(get by baselines.s) [repo.c ref.c])
  ?&  =(generation.c (~(gut by generations.s) repo.c 0))
      =(incarnation.c (~(gut by incarnations.s) repo.c 0v0))
      ?=(^ base)
      =(baseline.c `revision.u.base)
      =(lock.c lock.u.base)
  ==
::
::  ---- the gate ----
::
::  what a job's concurrency decides before its own condition is read, or
::  ~ when it decides nothing: a run that has not joined its groups waits;
::  a workflow cancelled before its run started runs no job at all, not
::  even an always() one; a workflow whose concurrency is refused is
::  refused with the reason; a workflow waiting in its group waits for the
::  run in progress
::
++  gate
  |=  [s=state-0:ci c=candidate:ci =job:ci]
  ^-  (unit decision:ci-plan)
  ?:  ?=(%pending -.concurrency.c)
    `[%wait 'waiting to join its concurrency groups']
  =/  stop=(unit cancellation:ci)  (cancellation-of c workflow.job)
  ?:  ?&(?=(^ stop) !started.u.stop)
    `[%cancel (rap 3 ~['not run: ' reason.u.stop]) ~]
  =/  group=(unit workflow-group:ci)  (group-of c workflow.job)
  ?~  group  ~
  ?:  ?=(%refused -.u.group)
    `[%error (rap 3 ~['the workflow\'s concurrency is refused: ' reason.u.group])]
  ?.  ?=(%member -.u.group)  ~
  ?.  =(%waiting place.u.group)  ~
  `[%wait (waiting-text s u.group)]
::
::  a job's decision: its concurrency gate, else its condition with
::  cancelled() read for its own workflow's run
::
++  decide-with
  |=  $:  s=state-0:ci
          c=candidate:ci
          =job:ci
          plan=(list job:ci)
          standings=(map key:ci-plan standing:ci-plan)
          entries=(map key:ci-plan need-entry:ci)
          context=run-context:ci-plan
      ==
  ^-  decision:ci-plan
  =/  gated=(unit decision:ci-plan)  (gate s c job)
  ?^  gated  u.gated
  %:  decide:ci-plan
    job
    plan
    standings
    entries
    context(cancelled (workflow-cancelled c workflow.job))
  ==
::
::  a workflow's group in a run, when it joined one
::
++  group-of
  |=  [c=candidate:ci workflow=@t]
  ^-  (unit workflow-group:ci)
  ?.  ?=(%joined -.concurrency.c)  ~
  =/  runs=(list workflow-run:ci)  runs.concurrency.c
  |-
  ?~  runs  ~
  ?:  =(workflow workflow.i.runs)  `group.i.runs
  $(runs t.runs)
::
::  ---- names ----
::
::  a run as the CI tab names it: its event and its source, never its id
::
++  run-label
  |=  c=candidate:ci
  ^-  @t
  =/  short=@t  (end [3 8] (oid-text:git-codec head.c))
  =/  where=@t  (ref-label ref.c)
  ?-  -.trigger.c
      %dispatch
    (rap 3 ~['manual run of ' name.trigger.c ' on ' where ' at ' short])
  ::
      %push
    ?:  =(%shadow mode.c)  (rap 3 ~['shadow run of ' short ' on ' where])
    ?~  pull.c  (rap 3 ~[short ' on ' where])
    (rap 3 ~['pull request #' (crip (a-co:co u.pull.c)) ' at ' short ' into ' where])
  ::
      %event
    =/  e=run-event:ci  run-event.trigger.c
    ?-  kind.e
      %push  (rap 3 ~['push of ' short ' to ' where])
    ::
        %pull-request
      ?~  pull.e  (rap 3 ~['pull request at ' short ' into ' where])
      (rap 3 ~['pull request #' (crip (a-co:co number.u.pull.e)) ' at ' short ' into ' where])
    ::
        %schedule
      ?~  occurrence.e  (rap 3 ~['schedule on ' where])
      (rap 3 ~['schedule of ' workflow.u.occurrence.e ' due ' (iso-utc:ci-cron due.u.occurrence.e)])
    ==
  ==
::
++  ref-label
  |=  ref=@t
  ^-  @t
  =/  branch=(unit @t)  (strip:ci-trigger 'refs/heads/' ref)
  ?^  branch  u.branch
  =/  tag=(unit @t)  (strip:ci-trigger 'refs/tags/' ref)
  ?^  tag  (rap 3 ~['tag ' u.tag])
  ref
::
::  a recorded run's name, or that it is no longer recorded
::
++  label-of
  |=  [s=state-0:ci id=candidate-id:ci]
  ^-  @t
  =/  c=(unit candidate:ci)  (~(get by candidates.s) id)
  ?~  c  'a run no longer recorded'
  (run-label u.c)
::
::  why a waiting workflow's run waits, in plain words
::
++  waiting-text
  |=  [s=state-0:ci g=workflow-group:ci]
  ^-  @t
  ?.  ?=(%member -.g)  'waiting for its concurrency group'
  ?~  behind.g  (rap 3 ~['waiting in group ' text.g])
  (rap 3 ~['waiting for run ' (label-of s u.behind.g) ' in group ' text.g])
::
::  ---- evaluation ----
::
::  the github context a workflow's run reads its concurrency with: the
::  one act gives the run's jobs — the event and its payload, the ref, the
::  source the jobs check out, the actor, the workflow's name.  for a pull
::  request github.ref is refs/pull/<n>/merge, ref_name <n>/merge, and
::  head_ref and base_ref the branches, as act derives them from the
::  payload.  github.job is undefined at the workflow level (the compiler
::  refuses it)
::
++  github-for
  |=  [c=candidate:ci name=@t]
  ^-  val:ci-expr
  =/  context=run-context:ci-plan  (run-context c)
  =/  pull=(unit pull-facts:ci)
    ?.  ?=(%event -.trigger.c)  ~
    ?.  ?=(%pull-request kind.run-event.trigger.c)  ~
    pull.run-event.trigger.c
  =/  number=@t  ?~(pull '' (crip (a-co:co number.u.pull)))
  =/  ref=@t  ?~(pull ref.context (rap 3 ~['refs/pull/' number '/merge']))
  =/  base=val:ci-expr
    %:  github-of:ci-expr
      event.context
      payload.context
      ref
      sha.context
      actor.context
      name
      ''
    ==
  ?~  pull  base
  ?.  ?=(%obj -.base)  base
  :-  %obj
  %-  ~(gas by p.base)
  ^-  (list [@t val:ci-expr])
  :~  ['ref_name' [%str (rap 3 ~[number '/merge'])]]
      ['head_ref' [%str (fall (strip:ci-trigger 'refs/heads/' head-ref.u.pull) head-ref.u.pull)]]
      ['base_ref' [%str (fall (strip:ci-trigger 'refs/heads/' base-ref.u.pull) base-ref.u.pull)]]
  ==
::
::  a workflow's group and cancel-in-progress for a run, or why they
::  cannot be evaluated: an expression that errs, an array or object in the
::  group, an empty group, a group past 4096 bytes, or a cancel-in-progress
::  that is not true or false.  never "no group"
::
++  evaluate
  |=  [def=concurrency-def:ci github=val:ci-expr inputs=val:ci-expr]
  ^-  (each [text=@t cancel=?] @t)
  ?.  ?=(%group -.def)  |+'the workflow declares no concurrency group'
  =/  =scope:ci-expr  [github [%obj ~] [%obj ~] inputs [%obj ~] %.n %.n %.n]
  =/  shown=@t  (quote:ci-plan (shown:ci-expr text.group.def))
  =/  text=(each @t @t)  (group-text parts.group.def scope)
  ?:  ?=(%| -.text)
    |+(rap 3 ~['the concurrency group ' shown ' could not be evaluated: ' p.text])
  ?:  =('' p.text)
    |+(rap 3 ~['the concurrency group ' shown ' evaluated to the empty text'])
  ?:  (gth (met 3 p.text) max-text:ci-expr)
    |+(rap 3 ~['the concurrency group ' shown ' evaluated to more than 4096 bytes'])
  ?-  -.cancel.def
    %fixed  &+[p.text p.cancel.def]
  ::
      %expr
    =/  said=@t  (quote:ci-plan (shown:ci-expr text.cancel.def))
    =/  v=(each val:ci-expr @t)  (eval:ci-expr expr.cancel.def scope)
    ?:  ?=(%| -.v)
      |+(rap 3 ~['cancel-in-progress ' said ' could not be evaluated: ' p.v])
    ?.  ?=(%bool -.p.v)
      |+(rap 3 ~['cancel-in-progress ' said ' is ' (render:ci-expr p.v) ', not true or false'])
    &+[p.text p.p.v]
  ==
::
::  a group template's text: each expression's value as text; an array or
::  object is no group name
::
++  group-text
  |=  [parts=(list part:ci) =scope:ci-expr]
  ^-  (each @t @t)
  =|  out=(list @t)
  |-
  ?~  parts  &+(rap 3 (flop out))
  ?:  ?=(%lit -.i.parts)  $(parts t.parts, out [p.i.parts out])
  =/  v=(each val:ci-expr @t)  (eval:ci-expr p.i.parts scope)
  ?:  ?=(%| -.v)  |+p.v
  ?:  ?=(?(%arr %obj) -.p.v)
    |+(rap 3 ~['an expression in it is ' (render:ci-expr p.v) ', which is not text'])
  $(parts t.parts, out [(to-text:ci-expr p.v) out])
::
::  a group's key: its text without ASCII case (GitHub's groups ignore
::  case)
::
++  key-of
  |=  text=@t
  ^-  @t
  (crip (cass (trip text)))
::
::  one workflow's group for a run, its place not decided yet
::
++  group-for
  |=  [c=candidate:ci name=@t def=(unit concurrency-def:ci) now=@da]
  ^-  workflow-group:ci
  ?~  def  [%unknown unread]
  ?-  -.u.def
    %none  [%free ~]
  ::
      %refused
    =/  where=@t
      ?:  =(0 line.u.def)  ''
      (rap 3 ~[' (line ' (crip (a-co:co line.u.def)) ', column ' (crip (a-co:co col.u.def)) ')'])
    [%refused (rap 3 ~[reason.u.def where])]
  ::
      %group
    =/  context=run-context:ci-plan  (run-context c)
    =/  got=(each [text=@t cancel=?] @t)
      (evaluate u.def (github-for c name) inputs.context)
    ?:  ?=(%| -.got)  [%refused p.got]
    [%member text.p.got (key-of text.p.got) cancel.p.got %released ~ now]
  ==
::
::  ---- the catalog ----
::
::  the catalog of a run's lock, or why none can be read: no lock, a lock
::  not on this ship, a catalog never read (unknown)
::
++  catalog-of
  |=  [s=state-0:ci c=candidate:ci]
  ^-  (each trigger-catalog:ci @t)
  ?~  lock.c  |+'the run is bound to no lock: its workflow revision has no workflows'
  =/  l=(unit lock:ci)  (~(get by locks.s) u.lock.c)
  ?~  l  |+'the run\'s lock is not on this ship: resolve and promote the revision again'
  ?~  triggers.u.l  |+unread
  &+u.triggers.u.l
::
::  each workflow's definition in a run's catalog, or why the catalog
::  cannot be read; a workflow the catalog does not list is unknown
::
++  definitions
  |=  [s=state-0:ci c=candidate:ci workflows=(list @t)]
  ^-  (each (list [workflow=@t name=@t def=(unit concurrency-def:ci)]) @t)
  =/  cat=(each trigger-catalog:ci @t)  (catalog-of s c)
  ?:  ?=(%| -.cat)  [%| p.cat]
  :-  %&
  %+  turn  workflows
  |=  wf=@t
  ^-  [workflow=@t name=@t def=(unit concurrency-def:ci)]
  =/  ws=(list trigger-workflow:ci)  workflows.p.cat
  |-
  ?~  ws  [wf wf ~]
  ?:  =(wf workflow.i.ws)  [wf name.i.ws concurrency.i.ws]
  $(ws t.ws)
::
::  a shadow's workflows: every workflow of its catalog that declares push
::  and whose on: can be read (a shadow plans every push job)
::
++  push-workflows
  |=  [s=state-0:ci c=candidate:ci]
  ^-  (each (list @t) @t)
  =/  cat=(each trigger-catalog:ci @t)  (catalog-of s c)
  ?:  ?=(%| -.cat)  [%| p.cat]
  :-  %&
  %+  murn  workflows.p.cat
  |=  w=trigger-workflow:ci
  ^-  (unit @t)
  ?^  refusal.w  ~
  =/  push=(unit trigger-event:ci)  (event-of:ci-trigger w 'push')
  ?~  push  ~
  `workflow.w
::
::  ---- groups ----
::
::  the workflows' runs that hold or wait in a group of a repository: of
::  runs still in progress (a closed run holds nothing)
::
++  members
  |=  [s=state-0:ci repo=@t key=@t]
  ^-  (list occupant)
  %-  zing
  %+  turn  ~(val by candidates.s)
  |=  c=candidate:ci
  ^-  (list occupant)
  ?.  =(repo repo.c)  ~
  ?.  =(%pending status.c)  ~
  ?.  ?=(%joined -.concurrency.c)  ~
  %+  murn  runs.concurrency.c
  |=  r=workflow-run:ci
  ^-  (unit occupant)
  ?.  ?=(%member -.group.r)  ~
  ?.  =(key key.group.r)  ~
  ?:  =(%released place.group.r)  ~
  `[id.c workflow.r place.group.r since.group.r]
::
::  the run in progress in a group
::
++  holder-of
  |=  [s=state-0:ci repo=@t key=@t]
  ^-  (unit candidate-id:ci)
  =/  held=(list occupant)
    (skim (members s repo key) |=(o=occupant =(%holding place.o)))
  ?~  held  ~
  `id.i.held
::
::  a workflow's run added to its candidate's groups
::
++  add-run
  |=  [s=state-0:ci id=candidate-id:ci run=workflow-run:ci]
  ^-  state-0:ci
  =/  c=candidate:ci  (~(got by candidates.s) id)
  ?.  ?=(%joined -.concurrency.c)  s
  =/  next=candidate:ci
    c(concurrency [%joined at.concurrency.c (snoc runs.concurrency.c run)])
  s(candidates (~(put by candidates.s) id next))
::
::  a workflow's run moved to another place in its group
::
++  set-place
  |=  [c=candidate:ci workflow=@t place=group-place:ci now=@da]
  ^-  candidate:ci
  ?.  ?=(%joined -.concurrency.c)  c
  =/  runs=(list workflow-run:ci)
    %+  turn  runs.concurrency.c
    |=  r=workflow-run:ci
    ^-  workflow-run:ci
    ?.  =(workflow workflow.r)  r
    ?.  ?=(%member -.group.r)  r
    r(group [%member text.group.r key.group.r cancel.group.r place ~ now])
  c(concurrency [%joined at.concurrency.c runs])
::
::  ---- joining ----
::
::  a run joins its groups: each workflow in the order given, evaluated
::  for the run and set against every member of its group in the
::  repository — the same run's earlier workflows among them.  its own
::  cancel-in-progress decides: true cancels every member that holds or
::  waits, and the run waits while a cancelled member finishes (its
::  always() jobs), or holds at once; false waits behind the member in
::  progress, and the older waiting member is cancelled whatever its flag:
::  a group keeps one waiting run
::
++  join
  |=  $:  s=state-0:ci
          id=candidate-id:ci
          defs=(list [workflow=@t name=@t def=(unit concurrency-def:ci)])
          now=@da
      ==
  ^-  state-0:ci
  =/  first=candidate:ci  (~(got by candidates.s) id)
  =.  candidates.s
    (~(put by candidates.s) id first(concurrency [%joined now ~], updated now))
  |-
  ?~  defs  s
  =/  c=candidate:ci  (~(got by candidates.s) id)
  =/  g=workflow-group:ci  (group-for c name.i.defs def.i.defs now)
  ?.  ?=(%member -.g)
    $(defs t.defs, s (add-run s id [workflow.i.defs name.i.defs g]))
  =/  others=(list occupant)  (members s repo.c key.g)
  =/  holder=(unit candidate-id:ci)  (holder-of s repo.c key.g)
  =/  label=@t  (run-label c)
  =/  named=@t  text.g
  =.  s
    ?:  cancel.g
      =/  why=@t
        (rap 3 ~['cancelled: the newer run (' label ') joined group ' named ' with cancel-in-progress'])
      %+  roll  others
      |=  [o=occupant acc=_s]
      (cancel-workflows acc id.o ~[workflow.o] [%superseded id named] why now)
    =/  why=@t
      ?~  holder  (rap 3 ~['cancelled: a newer run (' label ') joined group ' named])
      (rap 3 ~['cancelled: a newer run (' label ') is waiting in group ' named])
    %+  roll  (skim others |=(o=occupant =(%waiting place.o)))
    |=  [o=occupant acc=_s]
    (cancel-workflows acc id.o ~[workflow.o] [%displaced id named] why now)
  =/  placed=workflow-group:ci
    [%member named key.g cancel.g ?~(holder %holding %waiting) holder now]
  $(defs t.defs, s (add-run s id [workflow.i.defs name.i.defs placed]))
::
::  ---- releasing ----
::
::  whether a workflow's run in progress finished: every job of it in the
::  plan decided and done, or its candidate closed; a waiting run whose
::  candidate closed leaves without starting
::
++  finished
  |=  $:  c=candidate:ci
          stand=(map key:ci-plan standing:ci-plan)
          workflow=@t
          place=group-place:ci
      ==
  ^-  ?
  ?.  =(%pending status.c)  %.y
  ?:  =(%waiting place)  %.n
  ?~  plan.c  %.n
  %+  levy  (skim u.plan.c |=(j=job:ci =(workflow workflow.j)))
  |=  j=job:ci
  !?=(?(%pending %running) (~(gut by stand) [workflow.j id.j] %pending))
::
::  runs that finished leave their groups; then a group with no run in
::  progress starts its waiting run (the newest, of which there is one)
::
++  release
  |=  [s=state-0:ci now=@da]
  ^-  state-0:ci
  =.  candidates.s
    %-  ~(run by candidates.s)
    |=  c=candidate:ci
    ^-  candidate:ci
    ?.  ?=(%joined -.concurrency.c)  c
    =/  open=?
      %+  lien  runs.concurrency.c
      |=  r=workflow-run:ci
      ?&(?=(%member -.group.r) !=(%released place.group.r))
    ?.  open  c
    =/  stand=(map key:ci-plan standing:ci-plan)
      ?~  plan.c  ~
      standings:(standings s c)
    =/  runs=(list workflow-run:ci)
      %+  turn  runs.concurrency.c
      |=  r=workflow-run:ci
      ^-  workflow-run:ci
      ?.  ?=(%member -.group.r)  r
      ?:  =(%released place.group.r)  r
      ?.  (finished c stand workflow.r place.group.r)  r
      r(group [%member text.group.r key.group.r cancel.group.r %released ~ now])
    c(concurrency [%joined at.concurrency.c runs])
  =/  found=(list (list waiter))
      %+  turn  ~(val by candidates.s)
      |=  c=candidate:ci
      ^-  (list waiter)
      ?.  =(%pending status.c)  ~
      ?.  ?=(%joined -.concurrency.c)  ~
      %+  murn  runs.concurrency.c
      |=  r=workflow-run:ci
      ^-  (unit waiter)
      ?.  ?=(%member -.group.r)  ~
      ?.  =(%waiting place.group.r)  ~
      `[id.c repo.c workflow.r key.group.r since.group.r]
  =/  flat=(list waiter)  (zing found)
  =/  waiting=(list waiter)
    (sort flat |=([a=waiter b=waiter] (gth since.a since.b)))
  |-  ^-  state-0:ci
  ?~  waiting  s
  =/  held=(unit candidate-id:ci)  (holder-of s repo.i.waiting key.i.waiting)
  ?^  held  $(waiting t.waiting)
  =/  c=candidate:ci  (~(got by candidates.s) id.i.waiting)
  =/  next=candidate:ci  (set-place c workflow.i.waiting %holding now)
  =.  candidates.s  (~(put by candidates.s) id.i.waiting next(updated now))
  $(waiting t.waiting)
::
::  ---- cancelling ----
::
::  workflows' runs of a candidate cancelled with a cause and its reason:
::  the one path a concurrency group and an operator's Cancel take.  the
::  first cancellation of a workflow stands; a waiting run leaves its
::  group never having started; each running attempt of the workflow's
::  jobs is decided again with cancelled() true, as GitHub evaluates
::  running jobs again: one whose if holds (always()) keeps running, the
::  rest close %cancelled — the daemon hears `attempt is closed` at its
::  next event and stops act — and a privileged one (an approval's) closes
::  unknown, needing review.  no other workflow's job of the candidate is
::  touched.  a run that is no longer pending finished: nothing of it is
::  cancelled
::
++  cancel-workflows
  |=  $:  s=state-0:ci
          id=candidate-id:ci
          workflows=(list @t)
          cause=cancel-cause:ci
          reason=@t
          now=@da
      ==
  ^-  state-0:ci
  =/  found=(unit candidate:ci)  (~(get by candidates.s) id)
  ?~  found  s
  ?.  =(%pending status.u.found)  s
  |-
  ?~  workflows  s
  =/  c=candidate:ci  (~(got by candidates.s) id)
  =/  wf=@t  i.workflows
  ?:  (~(has by cancelled.c) wf)  $(workflows t.workflows)
  =/  g=(unit workflow-group:ci)  (group-of c wf)
  =/  started=?
    ?~  g  %.y
    ?.  ?=(%member -.u.g)  %.y
    !=(%waiting place.u.g)
  =.  c  c(cancelled (~(put by cancelled.c) wf [now started cause reason]), updated now)
  =?  c  !started  (set-place c wf %released now)
  =.  candidates.s  (~(put by candidates.s) id c)
  $(workflows t.workflows, s (stop-attempts s id wf reason now))
::
::  whether a workflow's run of a candidate finished: what +finished says
::  of its place in its group (a workflow in no group is in progress)
::
++  workflow-finished
  |=  [s=state-0:ci c=candidate:ci workflow=@t]
  ^-  ?
  =/  g=(unit workflow-group:ci)  (group-of c workflow)
  =/  place=group-place:ci
    ?~  g  %holding
    ?.  ?=(%member -.u.g)  %holding
    place.u.g
  =/  stand=(map key:ci-plan standing:ci-plan)
    ?~  plan.c  ~
    standings:(standings s c)
  (finished c stand workflow place)
::
::  a whole run cancelled: every workflow of it not yet finished — a
::  finished workflow's run keeps its result, as on GitHub — and, while
::  it has no plan yet, the run itself (''), which covers a workflow
::  planned later, with its plan attempt closed: nothing is left to plan
::
++  cancel-whole-run
  |=  [s=state-0:ci id=candidate-id:ci cause=cancel-cause:ci reason=@t now=@da]
  ^-  state-0:ci
  =/  c=candidate:ci  (~(got by candidates.s) id)
  =/  open=(list @t)
    (skip (run-workflows c) |=(w=@t (workflow-finished s c w)))
  =.  s  (cancel-workflows s id open cause reason now)
  ?^  plan.c  s
  =.  s  (cancel-workflows s id ~[''] cause reason now)
  =/  after=candidate:ci  (~(got by candidates.s) id)
  %+  roll  attempts.after
  |=  [aid=attempt-id:ci acc=_s]
  =/  a=(unit attempt:ci)  (~(get by attempts.acc) aid)
  ?~  a  acc
  ?.  ?&(=(%running status.u.a) ?=(%plan kind.u.a))  acc
  (close-cancelled acc u.a reason now)
::
::  the workflows a run knows: its groups', its plan's, a manual run's
::
++  run-workflows
  |=  c=candidate:ci
  ^-  (list @t)
  =/  joined=(list @t)
    ?.  ?=(%joined -.concurrency.c)  ~
    (turn runs.concurrency.c |=(r=workflow-run:ci workflow.r))
  =/  planned=(list @t)
    ?~  plan.c  ~
    (turn u.plan.c |=(j=job:ci workflow.j))
  =/  dispatched=(list @t)
    ?.  ?=(%dispatch -.trigger.c)  ~
    ~[workflow.trigger.c]
  (sort ~(tap in (silt :(weld joined planned dispatched))) aor)
::
::  the running job attempts of one workflow ('' for every workflow) that
::  do not keep running under cancellation, closed
::
++  stop-attempts
  |=  [s=state-0:ci id=candidate-id:ci workflow=@t reason=@t now=@da]
  ^-  state-0:ci
  =/  c=candidate:ci  (~(got by candidates.s) id)
  =/  ids=(list attempt-id:ci)  attempts.c
  |-
  ?~  ids  s
  =/  a=(unit attempt:ci)  (~(get by attempts.s) i.ids)
  ?~  a  $(ids t.ids)
  ?.  ?&  =(%running status.u.a)
          ?=(%job kind.u.a)
          ?|(=('' workflow) =(`workflow workflow.u.a))
      ==
    $(ids t.ids)
  ?:  (keeps-running s c u.a)  $(ids t.ids)
  $(ids t.ids, s (close-cancelled s u.a reason now))
::
::  whether a running attempt's job keeps running in its cancelled run:
::  its decision again with cancelled() true runs it
::
++  keeps-running
  |=  [s=state-0:ci c=candidate:ci a=attempt:ci]
  ^-  ?
  ?~  plan.c  %.n
  =/  planned=(unit job:ci)  (planned-job c workflow.a job.a)
  ?~  planned  %.n
  =/  known  (standings s c)
  =/  entries=(map key:ci-plan need-entry:ci)
    (need-entries c newest.known standings.known)
  =/  context=run-context:ci-plan  (run-context c)
  =/  d=decision:ci-plan
    (decide:ci-plan u.planned u.plan.c standings.known entries context(cancelled %.y))
  ?=(%run -.d)
::
::  a running attempt stopped by a cancellation: %cancelled, as an
::  operator's cancel closes it; a privileged one (an approval's) closes
::  unknown, never as if nothing happened (rider 02)
::
++  close-cancelled
  |=  [s=state-0:ci a=attempt:ci reason=@t now=@da]
  ^-  state-0:ci
  ?^  approval.a
    =/  why=@t
      %+  rap  3
      :~  'cancelled while a privileged job ran; the external side effect may '
          'have happened: needs review ('  reason  ')'
      ==
    =.  s  (close s a [%infrastructure-error why] now)
    =/  closed=attempt:ci  (~(got by attempts.s) id.a)
    s(attempts (~(put by attempts.s) id.a closed(outcome %unknown)))
  =.  s  (close s a [%infrastructure-error (rap 3 ~['cancelled: ' reason])] now)
  =/  closed=attempt:ci  (~(got by attempts.s) id.a)
  s(attempts (~(put by attempts.s) id.a closed(status %cancelled)))
::
::  an attempt closes once.  a job result closes it passed or failed; an
::  invalid plan closes it failed with the reason; an infrastructure error
::  closes it unknown for the candidate.  the daemon's running set lets
::  the attempt go, a resolve's mirror write tokens and the attempt's read
::  capability end with it.  the candidate's verdict is the caller's
::
++  close
  |=  [s=state-0:ci =attempt:ci =attempt-result:ci now=@da]
  ^-  state-0:ci
  =/  status=attempt-status:ci
    ?-  -.attempt-result
      %job-result  ?:(=(%success result.attempt-result) %passed %failed)
      %plan-invalid  %failed
      %infrastructure-error  %infrastructure-error
    ==
  =/  reason=(unit @t)
    ?-  -.attempt-result
      %job-result  ~
      %plan-invalid  `(rap 3 ~['plan-invalid: ' message.attempt-result])
      %infrastructure-error  `message.attempt-result
    ==
  =/  closed=attempt:ci
    attempt(status status, result `attempt-result, reason reason, finished `now)
  =.  attempts.s  (~(put by attempts.s) id.attempt closed)
  =.  daemons.s
    =/  runner=(unit daemon:ci)  (~(get by daemons.s) daemon.attempt)
    ?~  runner  daemons.s
    (~(put by daemons.s) daemon.attempt u.runner(running (~(del in running.u.runner) id.attempt)))
  =.  mirror-tokens.s  (~(del by mirror-tokens.s) id.attempt)
  =.  read-capabilities.s
    %-  malt
    %+  skip  ~(tap by read-capabilities.s)
    |=([* cap=read-capability:ci] =(attempt.cap id.attempt))
  s
--
