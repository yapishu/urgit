::  Resolver authority and lifecycle. These pure transitions are called by
::  the controller, and by ci-resolve-vector. No policy is inferred from YAML.
/-  ci, git
/+  ci-input
|%
++  purpose
  |=  c=candidate:ci
  ^-  ?(%tag %import %invalid)
  ?.  =('refs/ci/resolve' ref.c)  %invalid
  ?.  =(`head.c candidate.c)  %invalid
  ::  Supported explicit imports (including state5 obligations) have this
  ::  identity, minted only after the ci-policy check. An arbitrary shadow
  ::  candidate or a missing automatic marker never acquires import authority.
  ?:  =(id.c (sham [%ci-resolve repo.c head.c]))  %import
  ?.  ?=(%event -.trigger.c)  %invalid
  ?.  ?&  =(%push kind.run-event.trigger.c)
          =('refs/tags/' (end [3 10] ref.run-event.trigger.c))
      ==  %invalid
  =/  original=@uv  (sham [%ci-event-run id.run-event.trigger.c])
  =/  twin=@uv  (sham [%ci-event-approved original])
  ?.  ?|  =(id.c (sham [%ci-tag-resolve original]))
          =(id.c (sham [%ci-tag-resolve twin]))
      ==  %invalid
  %tag
::
++  waiting
  |=  c=candidate:ci
  ^-  ?
  ?&  =(%pending status.c)  ?=(~ selected.c)
      =(%event mode.c)  ?=(%event -.trigger.c)
      =(`head.c candidate.c)  =(`head.c baseline.c)
  ==
::
++  same-source
  |=  [c=candidate:ci r=candidate:ci]
  ^-  ?
  ?&  =(repo.c repo.r)  =(head.c head.r)  =(trigger.c trigger.r)
      =(actor.c actor.r)  =(generation.c generation.r)
      =(incarnation.c incarnation.r)
  ==
::
++  consumers
  |=  [s=state-0:ci rid=candidate-id:ci]
  ^-  (list candidate-id:ci)
  =/  record=(unit candidate:ci)  (~(get by candidates.s) rid)
  ?~  record  ~
  %+  murn  ~(tap by tag-runs.s)
  |=  [id=candidate-id:ci resolver=(unit attempt-id:ci)]
  ^-  (unit candidate-id:ci)
  ?~  resolver  ~
  =/  c=(unit candidate:ci)  (~(get by candidates.s) id)
  =/  a=(unit attempt:ci)  (~(get by attempts.s) u.resolver)
  ?~  c  ~
  ?~  a  ~
  ?.  ?&  (waiting u.c)  (same-source u.c u.record)
          =(%resolve kind.u.a)  =(rid candidate.u.a)
          =(generation.u.c (~(gut by generations.s) repo.u.c 0))
          =(incarnation.u.c (~(gut by incarnations.s) repo.u.c 0v0))
          =((captured:ci-input s id.u.c) (captured:ci-input s rid))
      ==  ~
  `id
::
::  Shared by delivery, inventory/lock receipt and read-capability use.
++  active
  |=  [s=state-0:ci a=attempt:ci]
  ^-  ?
  ?.  =(%running status.a)  %.n
  ?.  =(%resolve kind.a)  %.y
  =/  c=(unit candidate:ci)  (~(get by candidates.s) candidate.a)
  ?~  c  %.n
  ?-  (purpose u.c)
    %import  %.y
    %invalid  %.n
      %tag
    %+  lien  (consumers s id.u.c)
    |=(id=candidate-id:ci =(`id.a (~(got by tag-runs.s) id)))
  ==
::
++  accepts
  |=  [s=state-0:ci id=candidate-id:ci aid=attempt-id:ci]
  ^-  ?
  ?.  =(`aid (~(gut by tag-runs.s) id ~))  %.n
  =/  a=(unit attempt:ci)  (~(get by attempts.s) aid)
  ?~  a  %.n
  ?.  (active s u.a)  %.n
  ?=(^ (find ~[id] (consumers s candidate.u.a)))
::
::  A reoffer is still an obligation. Its record and exclusions survive;
::  all other closed/missing/catalog-less outcomes remain terminal.
++  next
  |=  [s=state-0:ci c=candidate:ci]
  ^-  $%  [%running ~]
          [%offer record=(unit candidate-id:ci) exclude=(set daemon-id:ci)]
          [%failed why=@t]
      ==
  ?.  =(generation.c (~(gut by generations.s) repo.c 0))
    [%failed 'the captured automatic input policy is obsolete']
  =/  resolver=(unit attempt-id:ci)  (~(gut by tag-runs.s) id.c ~)
  ?~  resolver  [%offer ~ ~]
  =/  a=(unit attempt:ci)  (~(get by attempts.s) u.resolver)
  ?~  a  [%failed 'the captured resolver attempt is missing']
  =/  r=(unit candidate:ci)  (~(get by candidates.s) candidate.u.a)
  ?~  r  [%failed 'the captured resolver record is missing']
  ?.  &((same-source c u.r) =(%tag (purpose u.r)) =(%resolve kind.u.a))
    [%failed 'the captured resolver does not bind this tagged source']
  ?:  =(%running status.u.a)  [%running ~]
  ?.  =(%reoffered status.u.a)
    [%failed (fall reason.u.a 'the resolver closed without a usable trigger catalog')]
  =/  exclude=(set daemon-id:ci)
    %-  silt
    %+  murn  attempts.u.r
    |=  id=attempt-id:ci
    ^-  (unit daemon-id:ci)
    =/  old=(unit attempt:ci)  (~(get by attempts.s) id)
    ?~  old  ~
    ?.  &(=(%resolve kind.u.old) =(%reoffered status.u.old))
      ~
    `daemon.u.old
  [%offer `id.u.r exclude]
::
++  choose
  |=  [daemons=(map daemon-id:ci daemon:ci) now=@da stale=@dr repo=@t exclude=(set daemon-id:ci)]
  ^-  (unit daemon-id:ci)
  =/  able=(list daemon:ci)
    %+  skim  ~(val by daemons)
    |=  d=daemon:ci
    ?&  ?=(^ enrolled.d)  ?=(^ bearer-hash.d)
        ?=(~ revoked.d)  ?=(~ refused.d)  ?=(^ last-seen.d)
        (lte (sub now (min now u.last-seen.d)) stale)
        resolver.d  (gth capacity.d 0)  !(~(has in exclude) id.d)
        ?~(repos.d %.y (~(has in u.repos.d) repo))
    ==
  ?~  able  ~
  =/  free=(list daemon:ci)
    (skim `(list daemon:ci)`able |=(d=daemon:ci (lth ~(wyt in running.d) capacity.d)))
  ?^  free  `id.i.free
  `id.i.able
::
::  Rebind every still-waiting consumer, including an approved twin, to
::  one replacement. Completed/superseded history keeps its original attempt.
++  bind-attempt
  |=  [s=state-0:ci c=candidate:ci aid=attempt-id:ci]
  ^-  state-0:ci
  =/  a=attempt:ci  (~(got by attempts.s) aid)
  =/  ids=(list candidate-id:ci)  (consumers s candidate.a)
  =.  ids  (snoc ids id.c)
  =/  bindings=(map candidate-id:ci (unit attempt-id:ci))
    %+  roll  ids
    |=  [id=candidate-id:ci acc=_tag-runs.s]
    (~(put by acc) id `aid)
  s(tag-runs bindings)
::
++  reoffer
  |=  [s=state-0:ci a=attempt:ci why=@t now=@da]
  ^-  state-0:ci
  ?.  =(%running status.a)  s
  =.  attempts.s
    (~(put by attempts.s) id.a a(status %reoffered, reason `why, finished `now))
  =/  runner=(unit daemon:ci)  (~(get by daemons.s) daemon.a)
  ?~  runner  s
  =.  daemons.s
    (~(put by daemons.s) daemon.a u.runner(running (~(del in running.u.runner) id.a)))
  s
::
++  cancel
  |=  [s=state-0:ci c=candidate:ci why=@t now=@da]
  ^-  state-0:ci
  ::  Remove this owner first. A shared resolver is closed only after its
  ::  final live owner disappears; history may list it on both candidates.
  =.  candidates.s
    (~(put by candidates.s) id.c c(status %skipped, verdict-reason `why, updated now))
  =.  attempts.s
    %+  roll  attempts.c
    |=  [id=attempt-id:ci acc=_attempts.s]
    =/  a=(unit attempt:ci)  (~(get by acc) id)
    ?~  a  acc
    ?.  =(%running status.u.a)  acc
    =/  owner=(unit candidate:ci)  (~(get by candidates.s) candidate.u.a)
    ?:  ?&  ?=(%resolve kind.u.a)  ?=(^ owner)
            =(%tag (purpose u.owner))  (active s u.a)
        ==  acc
    (~(put by acc) id u.a(status %cancelled, reason `why, finished `now))
  =/  ended=(set attempt-id:ci)
    %-  silt
    %+  skim  attempts.c
    |=  id=attempt-id:ci
    =/  a=(unit attempt:ci)  (~(get by attempts.s) id)
    ?~(a %.y !=(%running status.u.a))
  =.  daemons.s
    (~(run by daemons.s) |=(d=daemon:ci d(running (~(dif in running.d) ended))))
  s
::
::  Approval preserves the exact inputs and shares an unresolved obligation.
::  Its original marker remains a duplicate-event tombstone.
++  twin
  |=  [old=candidate:ci fresh=candidate:ci]
  ^-  candidate:ci
  %=  fresh
    candidate  candidate.old
    trigger  trigger.old
    selected  selected.old
    baseline  baseline.old
    lock  lock.old
    generation  generation.old
    incarnation  incarnation.old
    verdict-reason  verdict-reason.old
  ==
::
++  approve
  |=  [s=state-0:ci old=candidate:ci approved=candidate:ci now=@da]
  ^-  state-0:ci
  =.  candidates.s
    %+  ~(put by candidates.s)
      id.old
    old(status %skipped, verdict-reason `'superseded by approval', updated now)
  =.  candidates.s  (~(put by candidates.s) id.approved approved)
  =.  input-snapshots.s
    (~(put by input-snapshots.s) id.approved (captured:ci-input s id.old))
  s(tag-runs (~(put by tag-runs.s) id.approved (~(got by tag-runs.s) id.old)))
::
::  Retire orphaned automatic records and clean authority of closed
::  automatic attempts. Assignment/attempt/event history remains immutable.
::  Effects are returned to the controller, which emits them in the same event.
++  sweep
  |=  [s=state-0:ci now=@da]
  ^-  [state=state-0:ci release=(list candidate-id:ci) mirrors=(set @t) stop=(list attempt-id:ci)]
  =|  release=(list candidate-id:ci)
  =|  stop=(list attempt-id:ci)
  =/  records=(list candidate:ci)  ~(val by candidates.s)
  =/  retired=[state=state-0:ci release=(list candidate-id:ci) stop=(list attempt-id:ci)]
    |-  ^-  [state=state-0:ci release=(list candidate-id:ci) stop=(list attempt-id:ci)]
        ?~  records  [s release stop]
        =/  c=candidate:ci  i.records
        ?.  &(=(%tag (purpose c)) =(%pending status.c))
          $(records t.records)
        ?^  (consumers s id.c)  $(records t.records)
        =/  why=@t  'cancelled: no live tag run needs this resolver'
        =.  candidates.s
          (~(put by candidates.s) id.c c(status %skipped, verdict-reason `why, updated now))
        =/  closed=[attempts=_attempts.s stop=(list attempt-id:ci)]
          %+  roll  attempts.c
          |=  [aid=attempt-id:ci acc=[attempts=_attempts.s stop=(list attempt-id:ci)]]
          =/  a=(unit attempt:ci)  (~(get by attempts.acc) aid)
          ?~  a  acc
          ?.  =(%running status.u.a)  acc
          [(~(put by attempts.acc) aid u.a(status %cancelled, reason `why, finished `now)) [aid stop.acc]]
        =.  attempts.s  attempts.closed
        $(records t.records, release [id.c release], stop (weld stop stop.closed))
  =.  s  state.retired
  =/  ended=(set attempt-id:ci)
    %-  silt
    %+  murn  ~(val by attempts.s)
    |=  a=attempt:ci
    ^-  (unit attempt-id:ci)
    ?:  =(%running status.a)  ~
    ?.  =(%resolve kind.a)  ~
    =/  c=(unit candidate:ci)  (~(get by candidates.s) candidate.a)
    ?~  c  ~
    ?:(=(%tag (purpose u.c)) `id.a ~)
  =/  mirrors=(set @t)
    %+  roll  ~(tap in ended)
    |=  [aid=attempt-id:ci acc=(set @t)]
    (~(uni in acc) (~(gut by mirror-tokens.s) aid ~))
  =.  mirror-tokens.s
    (malt (skip ~(tap by mirror-tokens.s) |=([aid=attempt-id:ci *] (~(has in ended) aid))))
  =.  read-capabilities.s
    %-  malt
    %+  skip  ~(tap by read-capabilities.s)
    |=([* cap=read-capability:ci] (~(has in ended) attempt.cap))
  =.  daemons.s
    (~(run by daemons.s) |=(d=daemon:ci d(running (~(dif in running.d) ended))))
  ::  Do not clear a mirror token currently held by another import.
  =/  still-held=(set @t)
    (roll ~(val by mirror-tokens.s) |=([r=(set @t) acc=(set @t)] (~(uni in acc) r)))
  [s release.retired (~(dif in mirrors) still-held) stop.retired]
--
