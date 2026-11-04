::  ci-recovery-pause-vector: CI-RECOVERY-1 (R5.2-A), %urgit-ci itself.
::  The agent is built from app/urgit-ci and loaded with a populated
::  state-0, once paused and once not.  The checks are these.
::    - Paused, it reads as paused, and the landing predicates %urgit
::      consumes name no authority, though one run is landable.  Not
::      paused, the same run is eligible.
::    - Paused, a runner's poll hands out no assignment, though one waits
::      for it.  Not paused, the same poll hands it out.
::    - Paused, a staging, a manual run, an operator assign, an override,
::      a rerun and a resolve are each refused with the pause reason.
::    - Paused, a schedule wake admits no run, and records that CI was
::      paused.
::    - Not paused, an import and an apply are refused.
::    - Resume clears the pause, sends no card and creates no run.  An
::      apply sends no card and creates no run.
::    - Checkpoint now writes through %urgit with a %write-recovery-commit
::      poke, never into %urgit's state.  Its acknowledgement records the
::      checkpoint as written, a refusal as not written, and a failed push
::      as a failed backup, never confirmed.
::  Checkpoint now reads %urgit through the ship's scry.  A generator
::  often cannot read %urgit that way, even when %urgit runs.  The vector
::  makes the same read first.  If %urgit is readable, it expects one
::  write and a pending record.  If %urgit is not readable, it expects no
::  write and a failed record with the reason.  The live recovery drill
::  shows the readable path on a running ship.  Every case names the
::  verdict it expects.  Prints `passed=N of=M` and ends in a loobean.
::
::    NOT RUN in the source stage that wrote it: it needs a ship.
::
/-  ci, git
/+  ci-checkpoint, ci-cron, git-codec
/=  ci-agent  /app/urgit-ci
:-  %say
|=  [[now=@da eny=@uvJ bec=beak] *]
:-  %noun
=/  ship=@p  p.bec
=/  blank-bowl=bowl:gall  *bowl:gall
=/  bowl=bowl:gall  blank-bowl(our ship, src ship, now now, eny 0v1.entro)
::  the fixture.  a pending run has a running attempt and an assignment
::  that waits for its runner.  another run is landable.  a promoted
::  baseline has its lock, and a schedule is armed for a minute ago
::
=/  revision=@ux  0xaaaa.bbbb.cccc.dddd.eeee.ffff.0000.1111.2222.3333
=/  head=@ux  0x1234.5678.9abc.def0.1234.5678.9abc.def0.1234.5678
=/  object=@ux  0x5678.1234.9abc.def0.1234.5678.9abc.def0.1234.5678
=/  digest=@ux  (shax 'the lock')
=/  lock=lock:ci  [digest 'demo' revision ~ ~2026.10.2 0v1.daemn 1 ~ `~ ~]
=/  base=baseline:ci  [revision ~['.github/'] `digest ~2026.10.4 ship 'promotion' 3 ~]
=/  bearer=@uv  0v7.beare.rtoke
=/  daemon=daemon:ci
  :*  0v1.daemn  0x1  `(shas %ci-bearer bearer)  ~2026.10.1  `~2026.10.1  `now
      1  'microvm'  (silt ~[0v4.attmp])  ~  ~  ~  ~  ~  %.n
  ==
=/  job=job:ci  ['build' 'ci.yml' 'build' 0 ~ ~ ~ ~ ~ `~]
=/  blank-candidate=candidate:ci  *candidate:ci
=/  pending=candidate:ci
  %=  blank-candidate
    id  0v3.cand1
    repo  'demo'
    ref  'refs/heads/main'
    head  head
    base  revision
    candidate  `object
    status  %pending
    attempts  ~[0v4.attmp]
    plan  `~[job]
    trust  %trusted
    mode  %required
    generation  3
    baseline  `revision
    lock  `digest
    incarnation  0v9.incar
    created  ~2026.10.21
    updated  ~2026.10.21
    concurrency  [%exempt 'a test run']
  ==
=/  landable=candidate:ci  pending(id 0v5.landa, status %passed, attempts ~)
=/  blank-attempt=attempt:ci  *attempt:ci
=/  running=attempt:ci
  %=  blank-attempt
    id  0v4.attmp
    candidate  0v3.cand1
    assignment  0v6.assig
    daemon  0v1.daemn
    trust  %trusted
    kind  %job
    workflow  `'ci.yml'
    job  `'build'
    status  %running
    started  now
    generation  3
    mode  %required
  ==
=/  waiting=assignment:ci
  [0v6.assig 0v3.cand1 0v1.daemn 0v4.attmp %trusted %job `'ci.yml' `'build' ~h1 now ~]
=/  every-minute=cron-spec:ci
  [(gulf 0 59) (gulf 0 23) (gulf 1 31) (gulf 1 12) (gulf 0 6) %.y %.y]
=/  definition=@uv  0v8.defin
=/  due=@da  ~2026.10.21..11.59.00
=/  entry=schedule-entry:ci
  :*  'CI'  ['* * * * *' ~ ~ `every-minute]  ~  definition  'refs/heads/main'
      revision  digest  0v9.incar  ship  ~2026.10.4  ~2026.10.4  %active  ~
      `due  ~  ~  ~  ~  0
  ==
=/  blank=state-0:ci  *state-0:ci
=/  live-state=state-0:ci
  %=  blank
    candidates  (malt ~[[id.pending pending] [id.landable landable]])
    daemons  (malt ~[[id.daemon daemon]])
    assignments  (malt ~[[id.waiting waiting]])
    attempts  (malt ~[[id.running running]])
    ci-protected  (silt ~[['demo' 'refs/heads/main']])
    signing  `[0x7777 0x1111 0x0 ~2026.10.1]
    incarnations  (malt ~[['demo' 0v9.incar]])
    generations  (malt ~[['demo' 3]])
    baselines  (malt ~[[['demo' 'refs/heads/main'] base]])
    locks  (malt ~[[digest lock]])
    schedules  (malt ~[[['demo' 'ci.yml' 0] entry]])
  ==
=/  paused-state=state-0:ci  live-state(paused.recovery `[now ship 'drill'])
::  the agent, loaded with a state, and its reads
::
=/  load
  |=  s=state-0:ci
  ^-  agent:gall
  +:(~(on-load ci-agent bowl) !>(s))
=/  paused-agent=agent:gall  (load paused-state)
=/  live-agent=agent:gall  (load live-state)
=/  peek
  |=  [a=agent:gall =path]
  ^-  (unit (unit cage))
  (~(on-peek a bowl) path)
=/  read-paused
  |=  a=agent:gall
  ^-  ?
  =/  got=(unit (unit cage))  (peek a /x/recovery-paused)
  ?.  ?=([~ ~ *] got)  %.n
  !<(? q.u.u.got)
=/  land-path=path
  :~  %x  %landing-for  (scot %t 'demo')  (scot %t 'refs/heads/main')
      (scot %t (oid-text:git-codec object))  (scot %t (oid-text:git-codec revision))
  ==
=/  lands
  |=  a=agent:gall
  ^-  ?
  =/  got=(unit (unit cage))  (peek a land-path)
  ?.  ?=([~ ~ *] got)  %.n
  =/  answer=(unit [candidate-id:ci (unit @ud)])
    !<((unit [candidate-id:ci (unit @ud)]) q.u.u.got)
  ?=(^ answer)
=/  eligible-path=path
  :~  %x  %eligible  (scot %t 'demo')  (scot %t 'refs/heads/main')
      (scot %t (oid-text:git-codec object))
  ==
=/  eligible
  |=  a=agent:gall
  ^-  ?
  =/  got=(unit (unit cage))  (peek a eligible-path)
  ?.  ?=([~ ~ *] got)  %.n
  !<(? q.u.u.got)
=/  delivered
  |=  a=agent:gall
  ^-  ?
  =/  got=(unit (unit cage))  (peek a /x/assignments)
  ?.  ?=([~ ~ *] got)  %.n
  =/  all=(map assignment-id:ci assignment:ci)
    !<((map assignment-id:ci assignment:ci) q.u.u.got)
  =/  one=(unit assignment:ci)  (~(get by all) 0v6.assig)
  ?~  one  %.n
  ?=(^ delivered.u.one)
=/  count-candidates
  |=  a=agent:gall
  ^-  @ud
  =/  got=(unit (unit cage))  (peek a /x/candidates)
  ?.  ?=([~ ~ *] got)  0
  =/  all=(map candidate-id:ci candidate:ci)
    !<((map candidate-id:ci candidate:ci) q.u.u.got)
  ~(wyt by all)
=/  audit-kinds
  |=  a=agent:gall
  ^-  (list @t)
  =/  got=(unit (unit cage))  (peek a /x/audit)
  ?.  ?=([~ ~ *] got)  ~
  =/  all=(list audit-entry:ci)  !<((list audit-entry:ci) q.u.u.got)
  (turn all |=(e=audit-entry:ci kind.e))
=/  first-kind
  |=  a=agent:gall
  ^-  (unit @t)
  =/  kinds=(list @t)  (audit-kinds a)
  ?~(kinds ~ `i.kinds)
=/  recovery-of
  |=  a=agent:gall
  ^-  recovery-state:ci
  =/  got=(unit (unit cage))  (peek a /x/recovery)
  ?.  ?=([~ ~ *] got)  *recovery-state:ci
  !<(recovery-state:ci q.u.u.got)
::  whether a refusal's trace says .words
::
=/  said
  |=  [=tang words=@t]
  ^-  ?
  %+  lien  tang
  |=  =tank
  =/  lines=wall  (wash [0 400] tank)
  %+  lien  lines
  |=  line=tape
  =/  at=(unit @ud)  (find (trip words) line)
  ?=(^ at)
=/  poke
  |=  [a=agent:gall act=action:ci]
  ^-  (each (quip card:agent:gall agent:gall) tang)
  (mule |.((~(on-poke a bowl) %ci-action !>(act))))
=/  refused-with
  |=  [a=agent:gall act=action:ci words=@t]
  ^-  ?
  =/  r=(each (quip card:agent:gall agent:gall) tang)  (poke a act)
  ?:  ?=(%& -.r)  %.n
  (said p.r words)
::  a runner's long-poll for its assignment
::
=/  request=inbound-request:eyre
  :*  %.n  %.n  [%ipv4 .127.0.0.1]
      %'GET'
      (rap 3 ~['/apps/urgit/api/ci/daemon/' (scot %uv 0v1.daemn) '/assignment'])
      ~[['x-ci-bearer' (scot %uv bearer)] ['x-ci-capacity' '1']]
      ~
  ==
=/  poll
  |=  a=agent:gall
  ^-  (unit agent:gall)
  =/  r=(each (quip card:agent:gall agent:gall) tang)
    (mule |.((~(on-poke a bowl) %handle-http-request !>([%poll-1 request]))))
  ?:  ?=(%| -.r)  ~
  `+.p.r
=/  paused-polled=(unit agent:gall)  (poll paused-agent)
=/  live-polled=(unit agent:gall)  (poll live-agent)
::  a schedule's wake for its armed occurrence
::
=/  wake-wire=wire
  :~  %schedule  (scot %t 'demo')  (scot %t 'ci.yml')  (scot %ud 0)
      (scot %ud (unix:ci-cron due))  (scot %uv definition)
  ==
=/  woken=(each (quip card:agent:gall agent:gall) tang)
  (mule |.((~(on-arvo paused-agent bowl) wake-wire [%behn %wake ~])))
::  resume, and an apply of a staged checkpoint on a quiet paused agent
::
=/  resumed=(each (quip card:agent:gall agent:gall) tang)
  (poke paused-agent [%resume-ci ship])
=/  quiet-state=state-0:ci
  paused-state(attempts ~, assignments ~, candidates (malt ~[[id.landable landable]]))
=/  made=written-files:ci-checkpoint
  %:  export:ci-checkpoint
    (project:ci-checkpoint quiet-state ship now)
    'cp-quiet'  ship  'urgit'  1  now  'test'
  ==
=/  by-name=(map @t octs)
  %-  malt
  %+  murn  files.made
  |=  [=path data=octs]
  ^-  (unit [@t octs])
  ?.  ?=([%checkpoint @ @ ~] path)  ~
  `[(rap 3 ~[i.t.path '.' i.t.t.path]) data]
=/  read=(each [manifest=checkpoint-manifest:ci content=checkpoint-content:ci] @t)
  (import:ci-checkpoint by-name)
=/  staged-state=state-0:ci
  ?.  ?=(%& -.read)  quiet-state
  quiet-state(staged.recovery `[0x1 now ship manifest.p.read content.p.read])
=/  applied=(each (quip card:agent:gall agent:gall) tang)
  (poke (load staged-state) [%apply-checkpoint 'cp-quiet' ship])
::  Checkpoint now on an unpaused agent with no run, then %urgit's
::  answers to its write and to its push
::
=/  calm-agent=agent:gall
  (load live-state(attempts ~, assignments ~, candidates ~))
=/  saved=(each (quip card:agent:gall agent:gall) tang)  (poke calm-agent [%checkpoint-now ship])
=/  write-pokes=(list action:git)
  ?:  ?=(%| -.saved)  ~
  %+  murn  -.p.saved
  |=  c=card:agent:gall
  ^-  (unit action:git)
  ?.  ?=([%pass * %agent [* %urgit] %poke %git-action *] c)  ~
  =/  act=(each action:git tang)  (mule |.(!<(action:git q.cage.task.q.c)))
  ?.  ?=(%& -.act)  ~
  ?.  ?=(%write-recovery-commit -.p.act)  ~
  `p.act
=/  id=@t  (checkpoint-id:ci-checkpoint now 1 ship)
::  whether this generator can read %urgit as the agent does
::
=/  urgit-readable=?
  =/  prefix=path  /(scot %p ship)/urgit/(scot %da now)
  =/  live=(each ? tang)  (mule |.(.^(? %gu (weld prefix /$))))
  ?.  ?&(?=(%& -.live) p.live)  %.n
  =/  raw=(each * tang)
    (mule |.(.^(* %gx (weld prefix /ci-recovery-repo/(scot %t 'ci-checkpoints')/noun))))
  ?=(%& -.raw)
~&  [%urgit-readable-from-this-generator urgit-readable]
=/  after-save=agent:gall  ?:(?=(%| -.saved) calm-agent +.p.saved)
=/  acked=agent:gall
  +:(~(on-agent after-save bowl) /urgit/checkpoint/(scot %t id) [%poke-ack ~])
=/  nacked=agent:gall
  +:(~(on-agent after-save bowl) /urgit/checkpoint/(scot %t id) [%poke-ack `~[leaf+"'the checkpoint branch moved'"]])
=/  record-of
  |=  a=agent:gall
  ^-  (unit checkpoint:ci)
  =/  r=recovery-state:ci  (recovery-of a)
  =/  hits=(list checkpoint:ci)  (skim checkpoints.r |=(c=checkpoint:ci =(id id.c)))
  ?~(hits ~ `i.hits)
=/  replica-state
  |=  a=agent:gall
  ^-  @t
  =/  c=(unit checkpoint:ci)  (record-of a)
  ?~  c  'missing'
  -.replica.u.c
=/  written-state
  |=  a=agent:gall
  ^-  @t
  =/  c=(unit checkpoint:ci)  (record-of a)
  ?~  c  'missing'
  -.written.u.c
=/  written-reason
  |=  a=agent:gall
  ^-  (unit @t)
  =/  c=(unit checkpoint:ci)  (record-of a)
  ?~  c  ~
  ?.  ?=(%failed -.written.u.c)  ~
  `reason.written.u.c
::  a push that %urgit started and that failed.  the record carries the
::  push's ticket once its route is a usable one.  the vector answers that
::  ticket as failed.  with no usable route, the record is not
::  pushing, and the failed answer changes nothing
::
=/  ticket=(unit @uv)
  =/  c=(unit checkpoint:ci)  (record-of acked)
  ?~  c  ~
  =/  r=checkpoint-replica:ci  replica.u.c
  ?.  ?=(%pushing -.r)  ~
  `ticket.r
=/  failed-push=agent:gall
  ?~  ticket  acked
  =/  r=(each (quip card:agent:gall agent:gall) tang)
    (poke acked [%replica-result u.ticket %.n 'GitHub rejected the branch update'])
  ?:(?=(%| -.r) acked +.p.r)
=/  cases=(list [name=@t expect=? got=?])
  :~  ['a paused agent reads as paused' %.y (read-paused paused-agent)]
      ['an unpaused agent reads as paused' %.n (read-paused live-agent)]
      ['unpaused, the landable run is named by the landing predicate' %.y (lands live-agent)]
      ['paused, the landing predicate names any run' %.n (lands paused-agent)]
      ['unpaused, the landable run is eligible' %.y (eligible live-agent)]
      ['paused, the landable run is eligible' %.n (eligible paused-agent)]
      ['the paused poll was answered' %.y ?=(^ paused-polled)]
      ['paused, the waiting assignment is handed out' %.n ?&(?=(^ paused-polled) (delivered u.paused-polled))]
      ['unpaused, the waiting assignment is handed out' %.y ?&(?=(^ live-polled) (delivered u.live-polled))]
      ['paused, a staging is refused for the pause' %.y (refused-with paused-agent [%stage-candidate 'demo' 'refs/heads/main' head revision ship %session ~] 'CI is paused')]
      ['paused, a manual run is refused for the pause' %.y (refused-with paused-agent [%dispatch-workflow 'demo' 'refs/heads/main' 'ci.yml' ~ head 3 'req-1' ship] 'CI is paused')]
      ['paused, an operator assign is refused for the pause' %.y (refused-with paused-agent [%assign 0v3.cand1 0v1.daemn %job `'ci.yml' `'build' ~] 'CI is paused')]
      ['paused, an override is refused for the pause' %.y (refused-with paused-agent [%record-override 'demo' 'refs/heads/main' 0v5.landa object revision 'hotfix' ship] 'CI is paused')]
      ['paused, a rerun is refused for the pause' %.y (refused-with paused-agent [%rerun-candidate 0v5.landa] 'CI is paused')]
      ['paused, a resolve is refused for the pause' %.y (refused-with paused-agent [%resolve-dependencies 'demo' revision ship ~] 'CI is paused')]
      ['paused, a schedule wake is handled' %.y ?=(%& -.woken)]
      ['paused, a schedule wake admits a run' %.n ?&(?=(%& -.woken) !=(2 (count-candidates +.p.woken)))]
      ['paused, the wake records that CI was paused' %.y ?&(?=(%& -.woken) =(`'schedule-paused' (first-kind +.p.woken)))]
      ['unpaused, an import is refused' %.y (refused-with live-agent [%import-checkpoint ~ ship] 'pause CI before importing')]
      ['unpaused, an apply is refused' %.y (refused-with live-agent [%apply-checkpoint 'cp-quiet' ship] 'pause CI before applying')]
      ['resume succeeds' %.y ?=(%& -.resumed)]
      ['resume sends a card' %.n ?&(?=(%& -.resumed) !=(~ -.p.resumed))]
      ['after resume the agent reads as paused' %.n ?&(?=(%& -.resumed) (read-paused +.p.resumed))]
      ['resume creates no run' %.y ?&(?=(%& -.resumed) =(2 (count-candidates +.p.resumed)))]
      ['the staged checkpoint was built' %.y ?=(%& -.read)]
      ['an apply succeeds' %.y ?=(%& -.applied)]
      ['an apply sends a card' %.n ?&(?=(%& -.applied) !=(~ -.p.applied))]
      ['an apply creates a run' %.n ?&(?=(%& -.applied) !=(1 (count-candidates +.p.applied)))]
      ['an apply leaves CI paused' %.y ?&(?=(%& -.applied) (read-paused +.p.applied))]
      ['checkpoint now succeeds' %.y ?=(%& -.saved)]
      ['checkpoint now writes through %urgit once when %urgit is readable, and never when it is not' %.y =(?:(urgit-readable 1 0) (lent write-pokes))]
      ['the write names the private checkpoint repository' %.y (levy write-pokes |=(w=action:git ?&(?=(%write-recovery-commit -.w) =('ci-checkpoints' repository.w))))]
      ['the checkpoint is pending until %urgit answers, or failed when %urgit cannot be read' %.y =(?:(urgit-readable %pending %failed) (written-state after-save))]
      ['an unreadable %urgit gives the reason, not a silent failure' %.y ?|(urgit-readable =(`'%urgit cannot be read, so the checkpoint repository cannot be checked' (written-reason after-save)))]
      ['an acknowledged write is written' %.y =(%written (written-state acked))]
      ['a refused write is not written' %.y =(%failed (written-state nacked))]
      ['a refused write has nothing to push' %.y =(%skipped (replica-state nacked))]
      ['a written checkpoint is confirmed before any push answers' %.n =(%confirmed (replica-state acked))]
      ['a failed push is confirmed' %.n =(%confirmed (replica-state failed-push))]
  ==
=/  failed=(list @t)
  %+  murn  cases
  |=  [name=@t expect=? got=?]
  ?:(=(expect got) ~ `name)
=/  passed=@ud  (sub (lent cases) (lent failed))
~&  [%false-assertions-refused (lent (skim cases |=([* expect=? got=?] &(!expect !got)))) %of (lent (skim cases |=([* expect=? *] !expect)))]
~&  [%failed failed]
~&  (crip "passed={<passed>} of={<(lent cases)>}")
?=(~ failed)
