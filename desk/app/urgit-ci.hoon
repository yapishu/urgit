::  Native CI controller: candidates, daemons, assignments, attempts.
::
::    P0 holds the contracts: the landing-eligibility scry %urgit reads
::    before it advances a CI-protected ref, the candidate pokes exchanged
::    with %urgit, the daemon channel under /apps/urgit/api/ci, the relayed
::    act event envelope, and CI object-store signing.
::
::    P1 replaces the operator: a staged candidate is materialized at once;
::    a materialized candidate is planned by a daemon running `act -l` on
::    its checkout; the ship validates the plan, schedules each job on the
::    least-loaded daemon with capacity as its `needs` and `if` allow,
::    records the verdict, and asks %urgit to land a passed candidate.
::    the daemon never decides; the operator's %assign remains for re-runs.
::
::    P2 adds trust, storage and the web surface: a candidate's trust class
::    is decided at staging from its actor and an untrusted one waits for
::    approval or runs restricted; the daemon uploads each finished act
::    stream to the ship's object store under a ship-signed PUT and the
::    ship hands viewers a presigned GET; credentials are stored here and
::    released per attempt as signed grants; assignments are signed with a
::    ship-certified CI key; the session-authorized ci/* routes serve the
::    repository page's CI tab.
::
::    P3 gives the mechanisms an operator surface and closes one scheduler
::    hole: the enrollment token is minted by the session-authorized mint
::    route and answered once; minted tokens expire and enrolled daemons
::    are revoked from the Runners panel; daemons declare labels and the
::    operator binds a daemon to repositories, both read by the scheduler;
::    an abandoned, silent or revoked attempt is re-offered on another
::    daemon and a daemon that refuses over its pinned key is de-listed
::    until it re-enrolls (CI-DELIVERY-1.1); the CI tab subscribes to a
::    fact path per repository and the Runners panel to one for daemons.
::
::    P4 makes execution provenance the controller's business (D4-D7,
::    riders 02-04): every branch runs its required checks from a promoted
::    baseline (harness revision + dependency lock) under a policy
::    generation; a candidate that changes the harness gets an unprivileged
::    trial twin; every assignment carries a signed execution manifest
::    binding incarnation, object, baseline, lock, generation, job, trust,
::    sandbox requirement, mode and network profile; environment
::    credentials release only through a one-use fifteen-minute approval
::    or an explicit automation rule; an override is a recorded fifteen-
::    minute one-use action checked again at the ref advance; a policy
::    change invalidates unused authorizations and resets affected
::    evidence; a privileged attempt whose outcome is uncertain is marked
::    unknown and never retried; shadow candidates land nothing.
::
::    Delivery 1B adds job conditions and outputs across jobs: each job's
::    `if` and declared outputs arrive compiled (CI-EXPR-2) and are checked
::    and evaluated here with GitHub's status semantics — a job waits for
::    its needs, then runs, skips or is refused with the reason recorded —
::    and a job's declared outputs are resolved from its accepted attempt
::    when it closes; a dependent's needs context is that snapshot, bound
::    to its attempt by the signed manifest.
::
::    Delivery 1A adds manual runs: an operator dispatches one workflow
::    that declares workflow_dispatch at a ref's promoted baseline, with
::    typed inputs admitted against the declaration the resolver's pinned
::    compiler read (the lock's inventory); the run is a candidate of mode
::    %manual, never landable, whose trigger — the event, the admitted
::    inputs and the payload act reads — every attempt's signed manifest
::    binds.
::
::    Delivery 1C adds automatic events: %urgit reports every persisted
::    ref move and pull request transition (%forge-events), which is
::    verified against %urgit's own state, recorded, and selected against
::    the applicable trigger catalog (lib/ci-trigger),
::    with changed paths %urgit computes from its objects; a selected
::    event becomes a run of mode %event, never landable, with no
::    credentials.  a required push whose push workflow the filters
::    exclude has absent required evidence and stays blocked.  the default
::    branch baseline's schedules are armed as Behn timers (lib/ci-cron)
::    and each due occurrence is admitted once, revalidated.
::    Ordinary tags bind their own commit's YAML, resolving its catalog
::    automatically. Promoted branch, PR and schedule authority stays
::    unchanged. A tag run remains advisory and receives no credentials.
::
::    CI-CONCURRENCY-1 adds workflow concurrency groups as GitHub runs
::    them (lib/ci-concurrency): a run joins its workflows' groups once it
::    is materialized, in creation order; a newcomer's cancel-in-progress
::    cancels the group's runs, or it waits behind the run in progress,
::    and a group keeps one waiting run; a cancelled workflow's jobs stop,
::    its always() jobs still run, and the run's result is cancelled,
::    which never lands.  the CI tab's Cancel takes the same path.
::
::    Pull request labels add the labeled and unlabeled activities: each
::    label a write adds or removes is one event, its pull facts carrying
::    the labels after it and the label, and a label change on a closed
::    or merged pull request is recorded and runs nothing.
::
::    CI-RECOVERY-1 (R5.2-A) adds checkpoints and a paused restore
::    (lib/ci-checkpoint).  a checkpoint, the CI-configuration projection
::    only, is written as files to the private repository ci-checkpoints
::    through %urgit on every CI-policy change and on the owner's Checkpoint
::    now, then pushed to the repository's own origin as its replica.
::    "written" and "replica confirmed" are separate facts.  the owner
::    pauses CI, imports a checkpoint into the staged area, reviews its
::    manifest and diff, applies it and resumes, each as its own action.
::    while paused no run is admitted, no assignment offered, no schedule
::    admitted and nothing landed.  an apply never rewinds authority.
::
::    persisted state is state-0, with no conversion code: the agent was
::    never published before this release.  the open long-polls are
::    transient and dropped on every load.
::
/-  ci, git
/+  dbug, default-agent, server, ci-checkpoint, ci-input, ci-concurrency, ci-cron, ci-dispatch, ci-event, ci-expr, ci-forge, ci-plan, ci-provenance, ci-recovery, ci-resolve, ci-storage, ci-tag, ci-trigger, git-clay, git-codec, git-protocol, git-storage
|%
+$  card  card:agent:gall
+$  poll  [eyre-id=@ta at=@da]
++  poll-window  ~s25
++  redeliver-after  ~m2
++  default-deadline  ~h1
++  plan-deadline  ~m5
++  stale-after  ~m5
::  the Runners panel's pip (D3, rider 2) reads the scheduler's own
::  window: a daemon seen within stale-after is healthy, one not seen for
::  longer is stale — one number.  the daemon polls at capacity too (D6 f),
::  so last-seen is always liveness.
::
::  a job that declares timeout-minutes gets that plus this margin as its
::  deadline (CI-DELIVERY-1.1 c); a silent runner is re-offered at it
::
++  silent-margin  ~m2
::  every daemon stands for these labels whether it declares them or not
::  (CI-P3-SCHED-A): every workflow that runs today keeps running on a
::  daemon that declares nothing
::
++  implicit-labels
  ^-  (set @t)
  (silt ~['self-hosted' 'linux' 'ubuntu-latest' 'ubuntu-22.04' 'ubuntu-24.04' 'x64'])
::  the reason prefix a daemon abandons an assignment with when its pinned
::  CI key refuses it: such a daemon is de-listed until it re-enrolls
::
++  refusal-prefix  'assignment refused: '
++  revoked-refusal  'revoked by the ship'
++  storage-refusal  'ship object storage is not configured; CI cannot be enabled'
++  no-log-reason
  'the job log was not stored, so its result is unknown: check the object store, then run it again'
++  no-tip-refusal  'ref has no tip; push a commit before CI-protecting it'
++  linked-refusal  'CI protection is not available for desk-linked repositories in this release'
::  a viewer's download link lives five minutes (D2: at most fifteen)
++  log-link-expiry  ~m5
::  a credential value is scrubbed from every text the ship keeps, so a
::  value short enough to occur by accident is refused at storage
++  min-credential  8
::  the audit list is bounded (newest first)
++  max-audit  1.000
::  the sandbox a repository requires unless the operator lowered it to
::  the explicit container compatibility mode (rider 04)
++  default-sandbox  %vm
::  a resolve attempt's deadline
++  resolve-deadline  ~m30
::  the largest retention report a daemon may post (legacy-recovery UI
::  ruling 01): it lists at most 64 retentions and 16 released ones, each
::  text clipped to 512 bytes — well inside the lock's own bound
++  max-report-bytes  1.048.576
--
=|  state-0:ci
=*  state  -
=|  polls=(map daemon-id:ci poll)
::  the live feed's rate limit (D4): the last-seen each runner fact
::  carried, so a daemon's heartbeat and event touches produce a fact only
::  every announce-every, while any other change to the record is a fact
::  at once.  transient, like the polls.
::
=|  announced=(map daemon-id:ci @da)
%-  agent:dbug
=<
  |_  =bowl:gall
  +*  this  .
      def  ~(. (default-agent this %|) bowl)
      hc  ~(. +> bowl)
  ::
  ::  the CI signing key exists from the first event (D5): every assignment
  ::  is signed, so a daemon can refuse an unsigned one from its first
  ::  enrollment.  the ship's own signing pair arrives from Jael's
  ::  %private-keys and certifies it; a rotation re-certifies.
  ::
  ++  on-init
    ^-  (quip card _this)
    =.  signing  `fresh-signing-key:hc
    [~[connect-card:hc keys-card:hc] this]
  ::
  ++  on-save
    !>(state)
  ::
  ++  on-load
    |=  old=vase
    ^-  (quip card _this)
    ::  the saved state is state-0, the one shape.  every active
    ::  schedule's armed wake is set again (Delivery 1C): a timer that
    ::  survived is then set twice, and the armed-due and
    ::  admitted-occurrence checks make the second wake nothing.  a pier
    ::  restart calls no on-load; Behn keeps its timers across it.
    ::
    =.  state  !<(state-0:ci old)
    =?  signing  ?=(~ signing)  `fresh-signing-key:hc
    [(weld ~[connect-card:hc keys-card:hc] rearm-cards:hc) this(polls ~)]
  ::
  ++  on-poke
    |=  [=mark =vase]
    ^-  (quip card _this)
    =/  before=snapshot:hc  snap:hc
    ::  CI-RECOVERY-1: the CI policy as it stood, and the audit, so that a
    ::  change of policy writes a checkpoint, named by its audit entry
    ::
    =/  print=*  policy-print:hc
    =/  told=(list audit-entry:ci)  audit
    =/  =out:hc
      ?+  mark  ~|([%urgit-ci-bad-mark mark] !!)
          %ci-action
        ?>  =(src.bowl our.bowl)
        (handle-action:hc !<(action:ci vase))
      ::
          %handle-http-request
        =+  !<([eyre-id=@ta req=inbound-request:eyre] vase)
        (handle-http:hc eyre-id req)
      ==
    ::  the live feed (D4): after every event that may have changed a
    ::  candidate, an attempt or a daemon, the changed rows go out as facts
    ::  to whoever watches the repository or the runners.  the helper door
    ::  with the NEW state does the diff against the snapshot taken before.
    ::  the facts go FIRST: arvo runs each card to completion before the
    ::  next, so a poke to %urgit that answers with %landed inside this
    ::  event would otherwise have its fact numbered before this one's.
    ::  (inline, not an arm: the agent door has exactly its ten.)
    ::
    =/  next  this(state state.out, polls polls.out)
    =/  saved=out:hc  (auto-checkpoint:~(. +>.next bowl) print told)
    =.  next  next(state state.saved, polls polls.saved)
    =/  live  (live-facts:~(. +>.next bowl) before announced)
    [:(weld cards.live cards.out cards.saved) next(announced announced.live)]
  ::
  ::  the live feed's paths (D4): a repository's candidates, and the runner
  ::  records.  session-authorized: only this ship may watch.  the initial
  ::  fact is the same JSON the GET answers, so a page that subscribes never
  ::  waits for the next change to render.
  ::
  ++  on-watch
    |=  =path
    ^-  (quip card _this)
    ?:  ?=([%http-response @ ~] path)  `this
    ?>  =(our.bowl src.bowl)
    ?+  path  (on-watch:def path)
        [%ci %runners ~]
      :_  this
      ~[[%give %fact ~ %json !>(runners-fact:hc)]]
    ::
        [%ci %repository @ ~]
      =/  repo=@t  (decode-segment:hc i.t.t.path)
      :_  this
      ~[[%give %fact ~ %json !>((candidates-fact:hc repo))]]
    ==
  ::
  ::  eyre leaves /http-response/<id> when the client's connection closes:
  ::  a long-poll whose daemon went away is forgotten at once, so a later
  ::  assignment is not answered into a dead connection and lost until its
  ::  deadline (a daemon stopped and restarted within the poll window).
  ::
  ++  on-leave
    |=  =path
    ^-  (quip card _this)
    ?.  ?=([%http-response @ ~] path)  (on-leave:def path)
    =/  gone=@ta  i.t.path
    =.  polls
      %-  malt
      %+  skip  ~(tap by polls)
      |=([* p=poll] =(eyre-id.p gone))
    `this
  ::
  ::  every route %urgit reads answers a loobean; none ever answers [~ ~],
  ::  because an empty answer kills the reading event before any trap runs.
  ::
  ++  on-peek
    |=  =path
    ^-  (unit (unit cage))
    ?+  path  (on-peek:def path)
        [%x %state %version ~]
      ``noun+!>(-.state)
    ::
        ::  CI-RECOVERY-1: whether CI is paused for a restore.  %urgit's CI
        ::  gate reads it and refuses every write to a CI-protected ref
        ::  while it is.  the recovery record, for the dojo
        ::
        [%x %recovery-paused ~]
      ``noun+!>(`?`ci-paused:hc)
        [%x %recovery ~]
      ``noun+!>(recovery)
    ::
        [%x %eligible @ @ @ ~]
      ``noun+!>((eligible:hc i.t.t.path i.t.t.t.path i.t.t.t.t.path))
    ::
        ::  the one landing predicate every %urgit writer consumes (P4 D5,
        ::  rider 02): the exact object under the current bindings, or a
        ::  live override naming it and this tip
        ::
        [%x %eligible-at @ @ @ @ ~]
      ``noun+!>((eligible-at:hc i.t.t.path i.t.t.t.path i.t.t.t.t.path i.t.t.t.t.t.path))
    ::
        ::  the authority that predicate names (Q5): %urgit's push path
        ::  lands an eligible object through its landing path by this
        ::  candidate, so the landing is recorded
        ::
        [%x %landing-for @ @ @ @ ~]
      ``noun+!>((landing-for:hc i.t.t.path i.t.t.t.path i.t.t.t.t.path i.t.t.t.t.t.path))
    ::
        ::  whether a presented read capability (its hash) may clone a
        ::  repository now (A06): %urgit's /git read authorization asks
        ::
        [%x %ci-read @ @ ~]
      =/  repo=@t  (decode-segment:hc i.t.t.path)
      =/  hash=(unit @)  (slaw %uv i.t.t.t.path)
      ``noun+!>(?~(hash %.n (read-allowed:hc repo u.hash)))
    ::
        ::  the read token of an attempt, for the harness (A06): the dojo
        ::  reads anything; the token is what the daemon was handed
        ::
        [%x %read-token @ ~]
      =/  id=(unit @uv)  (slaw %uv i.t.t.path)
      ``noun+!>(?~(id 0v0 (read-token:hc u.id)))
    ::
        [%x %generation @ ~]
      ``noun+!>((~(gut by generations) (decode-segment:hc i.t.t.path) 0))
        [%x %incarnation @ ~]
      ``noun+!>((~(get by incarnations) (decode-segment:hc i.t.t.path)))
        [%x %baseline @ @ ~]
      ``noun+!>((~(get by baselines) [(decode-segment:hc i.t.t.path) (decode-segment:hc i.t.t.t.path)]))
        [%x %roles @ ~]
      ``noun+!>((~(gut by roles) (decode-segment:hc i.t.t.path) ~))
        [%x %environments @ ~]
      =/  repo=@t  (decode-segment:hc i.t.t.path)
      ``noun+!>((skim ~(val by environments) |=(e=environment:ci %.y)))
        [%x %sandbox-requirement @ ~]
      ``noun+!>(`sandbox-need:ci`(~(gut by sandbox-requirements) (decode-segment:hc i.t.t.path) default-sandbox))
        [%x %network-policies @ ~]
      ``noun+!>((~(gut by network-policies) (decode-segment:hc i.t.t.path) ~))
      [%x %audit ~]  ``noun+!>(audit)
      [%x %approvals ~]  ``noun+!>(approvals)
      [%x %overrides ~]  ``noun+!>(overrides)
      [%x %locks ~]  ``noun+!>(locks)
      [%x %shadows ~]  ``noun+!>(shadows)
      [%x %comparisons ~]  ``noun+!>(comparisons)
    ::
        [%x %approval @ ~]
      =/  id=(unit @uv)  (slaw %uv i.t.t.path)
      ``noun+!>(?~(id ~ (~(get by approvals) u.id)))
        [%x %override @ ~]
      =/  id=(unit @uv)  (slaw %uv i.t.t.path)
      ``noun+!>(?~(id ~ (~(get by overrides) u.id)))
        [%x %lock @ ~]
      =/  id=(unit @ux)  (slaw %ux i.t.t.path)
      ``noun+!>(?~(id ~ (~(get by locks) u.id)))
        [%x %shadow @ ~]
      =/  id=(unit @uv)  (slaw %uv i.t.t.path)
      ``noun+!>(?~(id ~ (~(get by shadows) u.id)))
    ::
        [%x %ci-protected @ @ ~]
      =/  repo=@t  (decode-segment:hc i.t.t.path)
      =/  ref=@t  (decode-segment:hc i.t.t.t.path)
      ``noun+!>((~(has in ci-protected) [repo ref]))
  ::
      [%x %polls ~]  ``noun+!>(polls)
      [%x %policies ~]  ``noun+!>(policies)
    ::
        ::  the credentials of a repository by name, scope, environments
        ::  and creation time: the value is never read out (D4)
        ::
        [%x %credential-names @ ~]
      =/  repo=@t  (decode-segment:hc i.t.t.path)
      ``noun+!>((credential-names:hc repo))
    ::
        [%x %policy @ ~]
      =/  repo=@t  (decode-segment:hc i.t.t.path)
      ``noun+!>(`untrusted-policy:ci`(~(gut by policies) repo %approval))
      [%x %candidates ~]  ``noun+!>(candidates)
      [%x %daemons ~]  ``noun+!>(daemons)
      [%x %assignments ~]  ``noun+!>(assignments)
      [%x %attempts ~]  ``noun+!>(attempts)
    ::
        [%x %candidate @ ~]
      =/  id=(unit @uv)  (slaw %uv i.t.t.path)
      ``noun+!>(?~(id ~ (~(get by candidates) u.id)))
    ::
        [%x %attempt @ ~]
      =/  id=(unit @uv)  (slaw %uv i.t.t.path)
      ``noun+!>(?~(id ~ (~(get by attempts) u.id)))
    ::
        [%x %daemon @ ~]
      =/  id=(unit @uv)  (slaw %uv i.t.t.path)
      ``noun+!>(?~(id ~ (~(get by daemons) u.id)))
    ::
        ::  a download request for an attempt: ~ when the store is not
        ::  configured, the attempt is unknown, or the key's trust class is
        ::  not the attempt's own
        ::
        [%x %sign-get @ @ @ ~]
      =/  id=(unit @uv)  (slaw %uv i.t.t.path)
      =/  =trust:ci
        ?:(=(%trusted i.t.t.t.path) %trusted %untrusted)
      =/  name=@t  (decode-segment:hc i.t.t.t.t.path)
      =/  found=(unit attempt:ci)  ?~(id ~ (~(get by attempts) u.id))
      ?~  found  ``noun+!>(`(unit @t)`~)
      =/  signed=(unit signed-request:git-storage)
        %:  sign-get:ci-storage
          (read-settings:ci-storage our.bowl now.bowl)
          trust.u.found
          (candidate-repo:hc candidate.u.found)
          (scot %uv candidate.u.found)
          (scot %uv id.u.found)
          trust
          name
          now.bowl
        ==
      ``noun+!>(`(unit @t)`?~(signed ~ `url.u.signed))
    ::
        ::  a presigned download URL for an attempt's object, expiring after
        ::  the given seconds (bounded to fifteen minutes): the same signer
        ::  the GET attempt/<id>/log route answers with, with the expiry
        ::  chosen so a row can watch a link expire
        ::
        [%x %presign-get @ @ @ @ ~]
      =/  id=(unit @uv)  (slaw %uv i.t.t.path)
      =/  =trust:ci
        ?:(=(%trusted i.t.t.t.path) %trusted %untrusted)
      =/  name=@t  (decode-segment:hc i.t.t.t.t.path)
      =/  seconds=(unit @ud)  (slaw %ud i.t.t.t.t.t.path)
      =/  found=(unit attempt:ci)  ?~(id ~ (~(get by attempts) u.id))
      ?~  found  ``noun+!>(`(unit @t)`~)
      ?~  seconds  ``noun+!>(`(unit @t)`~)
      ``noun+!>((presign-log:hc u.found trust name (mul u.seconds ~s1)))
    ==
  ::
  ++  on-agent
    |=  [=wire =sign:agent:gall]
    ^-  (quip card _this)
    ?.  ?=([%urgit *] wire)  (on-agent:def wire sign)
    ?.  ?=(%poke-ack -.sign)  (on-agent:def wire sign)
    ::  CI-RECOVERY-1: %urgit's answer to a checkpoint's write, and to the
    ::  start of a replica push
    ::
    ?:  ?=([%urgit %checkpoint @ ~] wire)
      =/  =out:hc  (checkpoint-acked:hc i.t.t.wire p.sign)
      [cards.out this(state state.out, polls polls.out)]
    ?:  ?=([%urgit %replica @ ~] wire)
      =/  =out:hc  (replica-acked:hc i.t.t.wire p.sign)
      [cards.out this(state state.out, polls polls.out)]
    ?~  p.sign  `this
    %-  (slog leaf+"urgit-ci: %urgit rejected {<wire>}" u.p.sign)
    `this
  ::
  ++  on-arvo
    |=  [=wire =sign-arvo]
    ^-  (quip card _this)
    ?+  wire  (on-arvo:def wire sign-arvo)
      [%eyre *]  `this
    ::
        ::  the ship's keys, once at subscription and again at every
        ::  rotation: the signing half of the current ring is derived the
        ::  way ames derives [sgn.pub sgn.sek] and the CI key is
        ::  (re)certified with it.  nothing of the ring is logged.
        ::
        [%jael %keys ~]
      ?.  ?=([%jael %private-keys *] sign-arvo)  (on-arvo:def wire sign-arvo)
      =/  ring=(unit @)  (~(get by vein.sign-arvo) life.sign-arvo)
      ?~  ring  `this
      =/  derived=(unit ship-keys:ci)  (ship-keys-from-ring:hc life.sign-arvo u.ring)
      ?~  derived
        %-  %+  slog
              leaf+"urgit-ci: the ship's ring is not a suite-b ring; the CI key is uncertified"
            ~
        `this
      =.  ship-keys  derived
      =.  signing  (certified:hc signing u.derived)
      `this
    ::
        ::  a long-poll that saw no assignment closes with 204
        ::
        [%poll @ @ ~]
      ?.  ?=([%behn %wake *] sign-arvo)  (on-arvo:def wire sign-arvo)
      ?^  error.sign-arvo  `this
      =/  daemon=(unit @uv)  (slaw %uv i.t.wire)
      ?~  daemon  `this
      =/  waiting=(unit poll)  (~(get by polls) u.daemon)
      ?~  waiting  `this
      ?.  =(eyre-id.u.waiting i.t.t.wire)  `this
      =.  polls  (~(del by polls) u.daemon)
      [(give-empty:hc eyre-id.u.waiting 204) this]
    ::
        ::  an attempt with no result by its deadline (CI-DELIVERY-1.1 c):
        ::  offered again once on another daemon when one exists, and the
        ::  second silence — or the first with no other daemon to take it —
        ::  is an infrastructure error; its candidate becomes unknown, never
        ::  passed
        ::
        [%deadline @ ~]
      ?.  ?=([%behn %wake *] sign-arvo)  (on-arvo:def wire sign-arvo)
      ?^  error.sign-arvo  `this
      =/  id=(unit @uv)  (slaw %uv i.t.wire)
      ?~  id  `this
      =/  found=(unit attempt:ci)  (~(get by attempts) u.id)
      ?~  found  `this
      ?.  =(%running status.u.found)  `this
      =/  before=snapshot:hc  snap:hc
      =/  =out:hc  (expire-attempt:hc u.found)
      =/  next  this(state state.out, polls polls.out)
      =/  live  (live-facts:~(. +>.next bowl) before announced)
      [(weld cards.live cards.out) next(announced announced.live)]
    ::
        ::  a schedule's armed wake (Delivery 1C): the occurrence it names
        ::  is admitted at most once, revalidated now (lib/ci-cron
        ::  on-wake); a wake for a replaced, revoked or already admitted
        ::  occurrence does nothing.  a timer error is the same wake late
        ::
        [%schedule @ @ @ @ @ ~]
      ?.  ?=([%behn %wake *] sign-arvo)  (on-arvo:def wire sign-arvo)
      =/  before=snapshot:hc  snap:hc
      =/  =out:hc  (schedule-wake:hc t.wire)
      =/  next  this(state state.out, polls polls.out)
      =/  live  (live-facts:~(. +>.next bowl) before announced)
      [(weld cards.live cards.out) next(announced announced.live)]
    ::
        ::  CI-RECOVERY-1: a replica push still unanswered fifteen minutes
        ::  after it started is a failed backup
        ::
        [%replica-timeout @ ~]
      ?.  ?=([%behn %wake *] sign-arvo)  (on-arvo:def wire sign-arvo)
      =/  =out:hc  (replica-silent:hc i.t.wire)
      [cards.out this(state state.out, polls polls.out)]
    ==
  ::
  ++  on-fail  on-fail:def
  --
::
::  the helper door: everything below reads and writes the same state the
::  agent holds and hands back the cards to emit with the new state.
::
|_  =bowl:gall
+$  out  [cards=(list card) state=_state polls=_polls]
::  what the live feed diffs against (D4): the three maps a fact can
::  come from, as they were before the event
::
+$  snapshot  [candidates=_candidates attempts=_attempts daemons=_daemons]
::
++  snap
  ^-  snapshot
  [candidates attempts daemons]
::
::  a daemon's heartbeat becomes a fact this often at most; any other
::  change to its record is a fact at once
::
++  announce-every  ~s20
::
++  emit
  |=  cards=(list card)
  ^-  out
  =/  retired  (sweep:ci-resolve state now.bowl)
  =.  state  state.retired
  =/  releases=(list card)
    %+  turn  release.retired
    |=  id=candidate-id:ci
    =/  c=candidate:ci  (~(got by candidates) id)
    (urgit-git-poke /release/(scot %uv id) [%delete-ref repo.c (scratch-ref c)])
  =/  clears=(list card)
    %+  turn  ~(tap in mirrors.retired)
    |=(repo=@t (urgit-git-poke /mirror-token/(scot %t repo) [%clear-write-token repo]))
  =/  stops=(list card)
    %+  turn  stop.retired
    |=  id=attempt-id:ci
    =/  a=attempt:ci  (~(got by attempts) id)
    [%pass /deadline/(scot %uv id) %arvo %b %rest (add started.a resolve-deadline)]
  [:(weld cards releases clears stops) state polls]
::
::  the live feed (D4).  for every watched repository: each candidate of
::  it whose record, or any of whose attempts, changed since the snapshot
::  (the relayed-event counter aside) goes out as its full row.  for the
::  runners path and every watched repository: each daemon record that
::  changed, its heartbeat rate-limited, and each record that is gone.
::
++  live-facts
  |=  [before=snapshot announced=(map daemon-id:ci @da)]
  ^-  [cards=(list card) announced=(map daemon-id:ci @da)]
  =/  paths=(set path)
    (silt (turn ~(val by sup.bowl) |=([* =path] path)))
  ::  each watched repository with its path as subscribed, so a fact goes
  ::  back on exactly the path the page named
  ::
  =/  repo-paths=(list [repo=@t =path])
    %+  murn  ~(tap in paths)
    |=  =path
    ^-  (unit [@t ^path])
    ?.  ?=([%ci %repository @ ~] path)  ~
    `[(decode-segment i.t.t.path) path]
  =/  runners-watched=?  (~(has in paths) /ci/runners)
  ?:  ?&(?=(~ repo-paths) !runners-watched)  [~ announced]
  ::  the candidates that changed, per watched repository
  ::
  =/  candidate-cards=(list card)
    %-  zing
    %+  turn  repo-paths
    |=  [repo=@t =path]
    ^-  (list card)
    %+  murn  ~(tap by candidates)
    |=  [id=candidate-id:ci c=candidate:ci]
    ^-  (unit card)
    ?.  =(repo repo.c)  ~
    ?.  (candidate-changed before id c)  ~
    :-  ~
    :*  %give  %fact  ~[path]  %json
        !>((row-fact 'candidate' (scot %uv id) (candidate-json c)))
    ==
  ::  the daemons that changed or went away, to the runners path and
  ::  every watched repository
  ::
  =/  runner-paths=(list path)
    %+  weld  ?:(runners-watched ~[/ci/runners] ~)
    (turn repo-paths |=([* =path] path))
  =/  gone=(list card)
    %+  murn  ~(tap by daemons.before)
    |=  [id=daemon-id:ci *]
    ^-  (unit card)
    ?:  (~(has by daemons) id)  ~
    :-  ~
    :*  %give  %fact  runner-paths  %json
        !>((pairs:enjs:format ~[['kind' s+'runner-gone'] ['id' s+(scot %uv id)]]))
    ==
  =/  changed=(list [id=daemon-id:ci =daemon:ci])
    %+  skim  ~(tap by daemons)
    |=  [id=daemon-id:ci d=daemon:ci]
    =/  old=(unit daemon:ci)  (~(get by daemons.before) id)
    ?~  old  %.y
    ?:  !=(u.old(last-seen ~) d(last-seen ~))  %.y
    ?:  =(last-seen.u.old last-seen.d)  %.n
    ::  only the heartbeat moved: a fact when the last one is old enough
    ::
    ?~  last-seen.d  %.n
    =/  last=(unit @da)  (~(get by announced) id)
    ?~  last  %.y
    (gte u.last-seen.d (add u.last announce-every))
  =/  announced-next=(map daemon-id:ci @da)
    %+  roll  changed
    |=  [[id=daemon-id:ci d=daemon:ci] acc=_announced]
    ?~  last-seen.d  acc
    (~(put by acc) id u.last-seen.d)
  =.  announced-next
    %+  roll  ~(tap by announced-next)
    |=  [[id=daemon-id:ci *] acc=_announced-next]
    ?:((~(has by daemons) id) acc (~(del by acc) id))
  =/  runner-cards=(list card)
    %+  turn  changed
    |=  [id=daemon-id:ci d=daemon:ci]
    ^-  card
    :*  %give  %fact  runner-paths  %json
        !>((row-fact 'runner' (scot %uv id) (runner-json d)))
    ==
  :_  announced-next
  :(weld candidate-cards gone runner-cards)
::
++  candidate-changed
  |=  [before=snapshot id=candidate-id:ci c=candidate:ci]
  ^-  ?
  =/  old=(unit candidate:ci)  (~(get by candidates.before) id)
  ?~  old  %.y
  ?:  !=(u.old c)  %.y
  %+  lien  attempts.c
  |=  aid=attempt-id:ci
  =/  new=(unit attempt:ci)  (~(get by attempts) aid)
  =/  was=(unit attempt:ci)  (~(get by attempts.before) aid)
  ?~  new  %.n
  ?~  was  %.y
  !=(u.was(events 0) u.new(events 0))
::
++  row-fact
  |=  [kind=@t id=@t patch=json]
  ^-  json
  (pairs:enjs:format ~[['kind' s+kind] ['id' s+id] ['patch' patch]])
::
::  the runners path's initial fact: the list, as GET ci/runners answers
::
++  runners-fact
  ^-  json
  =/  all=json  runners-json
  ?.  ?=([%o *] all)  all
  [%o (~(put by p.all) 'kind' s+'runners')]
::
::  a repository path's initial fact: the candidate list as GET
::  ci/repository/<name>/candidates answers it, with the runner list so
::  the tab can say when no runner is enrolled (D7)
::
++  candidates-fact
  |=  repo=@t
  ^-  json
  =/  page=json  (candidates-json repo ~)
  ?.  ?=([%o *] page)  page
  =/  runners=json
    =/  all=json  runners-json
    ?.  ?=([%o *] all)  ~
    (fall (~(get by p.all) 'runners') ~)
  :-  %o
  %-  ~(gas by p.page)
  :~  ['kind' s+'candidates']
      ['runners' runners]
      ['now' (numb:enjs:format (unix-seconds now.bowl))]
  ==
::
++  connect-card
  ^-  card
  [%pass /eyre/connect %arvo %e %connect [~ /apps/urgit/api/ci] %urgit-ci]
::
::  a trusted candidate's id is the one %urgit prints in the push answer
::  and names the scratch ref by; an untrusted twin of the same head and
::  base has its own id, so approval can re-stage the head as trusted
::  beside it (D3); a rerun is a fresh id for the same head and base
::
++  candidate-id
  |=  [repo=@t ref=@t head=oid:git base=oid:git =trust:ci]
  ^-  candidate-id:ci
  ?:  =(%trusted trust)  (sham [repo ref head base])
  (sham [repo ref head base %untrusted])
::
++  rerun-id
  |=  [repo=@t ref=@t head=oid:git base=oid:git]
  ^-  candidate-id:ci
  (sham [repo ref head base %rerun now.bowl])
::
++  candidate-repo
  |=  id=candidate-id:ci
  ^-  @t
  =/  found=(unit candidate:ci)  (~(get by candidates) id)
  ?~(found '' repo.u.found)
::
::  %urgit names the scratch ref by the head and base alone, so every
::  candidate of one head and base shares it: the twin's materialization
::  re-sets what the first one's close released.  a manual run keeps its
::  source under a scratch ref of its own (Delivery 1A): two runs of one
::  tip never release each other's objects
::
++  scratch-ref
  |=  =candidate:ci
  ^-  @t
  ?:  ?=(?(%dispatch %event) -.trigger.candidate)
    (rap 3 ~['refs/ci/run/' (scot %uv id.candidate)])
  (rap 3 ~['refs/ci/candidate/' (scot %uv (sham [repo ref head base]:candidate))])
::
::  every candidate staged for this head and base that %urgit has not
::  materialized yet: %candidate-ready and %candidate-conflict name the
::  head and base, not an id
::
++  staged-for
  |=  [repo=@t ref=@t head=oid:git base=oid:git]
  ^-  (list candidate:ci)
  %+  skim  ~(val by candidates)
  |=  c=candidate:ci
  ?&  =(repo repo.c)  =(ref ref.c)  =(head head.c)  =(base base.c)
      ?=(~ candidate.c)
      !?=(%event -.trigger.c)
  ==
::
::  the repository's policy for untrusted revisions: approval unless set
::
++  restricted
  |=  repo=@t
  ^-  ?
  =(%restricted (~(gut by policies) repo %approval))
::
::  what may land (D3; P4 D5): a passed, materialized, TRUSTED, REQUIRED
::  candidate whose bindings — incarnation, policy generation, baseline
::  and lock — are the repository's current ones.  the eligibility scries
::  and the settle's landing request all read this one arm, so a
::  restricted check, a trial, a shadow or stale evidence can never
::  advance a ref from any side.
::
::  (lib/ci-concurrency +landable, which its vector reads too: a
::  cancelled run is not passed and never lands)
::
++  landable
  |=  c=candidate:ci
  ^-  ?
  (landable:ci-concurrency state c)
::
::  the candidate's bindings against the repository's current policy
::
++  bindings-current
  |=  c=candidate:ci
  ^-  ?
  (bindings-current:ci-concurrency state c)
::
++  current-generation
  |=  repo=@t
  ^-  @ud
  (~(gut by generations) repo 0)
::
::  a repository's incarnation: minted at first sight, dropped with the
::  repository, so a re-created one binds nothing of the old
::
++  current-incarnation
  |=  repo=@t
  ^-  @uv
  (~(gut by incarnations) repo 0v0)
::
::  the synthetic record a resolve attempt binds to (resolve-dependencies:
::  refs/ci/resolve, never a branch or a tag): dependency maintenance, not
::  a run of the revision's workflows.  it is never planned, re-planned on
::  a policy change or re-run; its resolve attempt and the lock it posts
::  are its whole record.  its shadow mode is no proof of that: an
::  explicitly admitted shadow run plans as before
::
++  resolver-record
  |=  c=candidate:ci
  ^-  ?
  =('refs/ci/resolve' ref.c)
::
::  a mirror repository a resolve writes (a lock names it, or a resolve in
::  flight holds its write token): dependency maintenance, never a source
::  of workflow events
::
++  mirror-repository
  |=  repo=@t
  ^-  ?
  ?|  (lien ~(val by mirror-tokens) |=(r=(set @t) (~(has in r) repo)))
      %+  lien  ~(val by locks)
      |=(l=lock:ci (lien nodes.l |=(n=dep-node:ci =(repo mirror.n))))
  ==
::
++  ensure-incarnation
  |=  repo=@t
  ^-  _incarnations
  ?:  (~(has by incarnations) repo)  incarnations
  (~(put by incarnations) repo (sham [%ci-incarnation repo now.bowl eny.bowl]))
::
::  the sandbox a job of a repository needs (contract §1; rider 04): the
::  repository's requirement, and always the VM for an untrusted
::  candidate, a trial, a shadow, or a privileged (environment) job
::
++  sandbox-for
  |=  [=candidate:ci privileged=?]
  ^-  sandbox-need:ci
  ?:  ?|  =(%untrusted trust.candidate)
          !=(%required mode.candidate)
          privileged
      ==
    %vm
  (~(gut by sandbox-requirements) repo.candidate default-sandbox)
::
::  the network a job runs under (rider 03)
::
++  network-of
  |=  [repo=@t workflow=@t job=@t]
  ^-  [profile=@t destinations=(list @t)]
  (network-for:ci-provenance (~(gut by network-policies) repo ~) workflow job)
::
::  the repository's owner as %urgit knows it (rider 02: the forge's
::  identity, never JSON); ~ when %urgit cannot be read
::
++  repo-owner
  |=  repo=@t
  ^-  (unit @p)
  =/  raw=(unit *)  (urgit-peek /ci-owner/(scot %t repo))
  ?~  raw  ~
  =/  answer=(each (unit @p) tang)
    %-  mule
    |.
    ;;((unit @p) u.raw)
  ?.  ?=(%& -.answer)  ~
  p.answer
::
::  authority (rider 02): the owner implicitly, else a delegated binding
::
++  authorized
  |=  [repo=@t =role:ci scope=(unit @t) actor=@p]
  ^-  ?
  (authorized:ci-provenance (repo-owner repo) (~(gut by roles) repo ~) role scope actor)
::
++  require-authority
  |=  [repo=@t =role:ci scope=(unit @t) actor=@p]
  ^-  ~
  ?:  (authorized repo role scope actor)  ~
  ~|  `@t`(rap 3 ~[(scot %p actor) ' does not hold ' role ' for ' repo ?~(scope '' (rap 3 ~[' (' u.scope ')'])) '; the owner or a delegated binding is required'])
  !!
::
++  record-audit
  |=  [actor=@p kind=@t repo=@t detail=@t]
  ^-  _audit
  (scag max-audit `(list audit-entry:ci)`[[now.bowl actor kind repo detail] audit])
::
::  a policy generation change (rider 02): the counter moves, unused
::  approvals and overrides of the repository are invalidated, every
::  required candidate of it is reset in place (its plan dropped, its
::  running attempts cancelled with the daemon told at its next event),
::  and the scheduler re-plans them under the new bindings.  a passed
::  candidate that has not landed (its landing parked, or refused) is
::  reset too: its scratch ref, released at the verdict, is set once
::  more so the re-plan can read its objects (the cards returned)
::
++  bump-generation
  |=  [repo=@t reason=@t]
  ^-  [(list card) _state]
  =/  next=@ud  +((current-generation repo))
  =.  generations  (~(put by generations) repo next)
  =/  why=@t  (rap 3 ~['policy generation ' (scot %ud next) ': ' reason])
  =.  approvals
    %-  ~(run by approvals)
    |=  a=approval:ci
    ?.  &(=(repo repo.a) ?=(~ consumed.a) ?=(~ invalidated.a))  a
    a(invalidated `why)
  =.  overrides
    %-  ~(run by overrides)
    |=  o=override:ci
    ?.  &(=(repo repo.o) ?=(~ consumed.o) ?=(~ invalidated.o))  o
    o(invalidated `why)
  %+  roll  ~(tap by candidates)
  |=  [[id=candidate-id:ci c=candidate:ci] acc=[cards=(list card) =_state]]
  =.  state  state.acc
  ?.  =(repo repo.c)  [cards.acc state]
  ?.  ?=(?(%pending %running %passed) status.c)  [cards.acc state]
  ?:  =(%skipped status.c)  [cards.acc state]
  ::  a resolve's record is no run: a policy change resets nothing of it
  ::  (its lock is checked again when a revision is promoted)
  ?:  (resolver-record c)  [cards.acc state]
  ::  a manual run is bound to the generation it was dispatched under
  ::  (Delivery 1A): one still open is cancelled, never re-planned under
  ::  another baseline with inputs admitted against an earlier one; one
  ::  that passed keeps its verdict, which lands nothing
  ::
  ?:  ?=(?(%dispatch %event) -.trigger.c)
    ?:  =(%passed status.c)  [cards.acc state]
    =/  release=card
      (urgit-git-poke /release/(scot %uv id) [%delete-ref repo.c (scratch-ref c)])
    [(snoc cards.acc release) (cancel-run c why)]
  ::  a landed candidate keeps its record; one still open is reset
  ::
  ?:  ?&(?=(^ verdict-reason.c) =('landed' u.verdict-reason.c))  [cards.acc state]
  =/  restore=(list card)
    ?.  ?&(=(%passed status.c) ?=(^ candidate.c))  ~
    :_  ~
    %+  urgit-git-poke  /scratch/(scot %uv id)
    [%set-ref repo.c (scratch-ref c) u.candidate.c]
  [(weld cards.acc restore) (reset-candidate c why)]
::
::  the open required candidates that name the object a candidate just
::  landed on the same ref: skipped as superseded, their running attempts
::  cancelled (the daemon hears `attempt is closed`), never planned again
::
++  supersede-landed
  |=  landed=candidate:ci
  ^-  _state
  ?~  candidate.landed  state
  =/  object=oid:git  u.candidate.landed
  %+  roll  ~(tap by candidates)
  |=  [[id=candidate-id:ci c=candidate:ci] acc=_state]
  =.  state  acc
  ?.  ?&  !=(id id.landed)
          =(repo.c repo.landed)
          =(ref.c ref.landed)
          =(%required mode.c)
          ?=(?(%pending %running) status.c)
          =(`object candidate.c)
      ==
    state
  =/  why=@t  (rap 3 ~['superseded: the same object landed as candidate ' (scot %uv id.landed)])
  =.  attempts
    %+  roll  attempts.c
    |=  [aid=attempt-id:ci acc=_attempts]
    =/  found=(unit attempt:ci)  (~(get by acc) aid)
    ?~  found  acc
    ?.  =(%running status.u.found)  acc
    (~(put by acc) aid u.found(status %cancelled, reason `why, finished `now.bowl))
  =.  daemons
    %-  ~(run by daemons)
    |=  d=daemon:ci
    d(running (~(dif in running.d) (silt attempts.c)))
  =.  candidates
    (~(put by candidates) id c(status %skipped, verdict-reason `why, updated now.bowl))
  state
::
::  an open manual run whose policy changed (Delivery 1A): its running
::  attempts are cancelled (the daemon hears `attempt is closed`) and the
::  run closes superseded with the reason; it is dispatched again, never
::  re-bound
::
++  cancel-run
  |=  [c=candidate:ci why=@t]
  ^-  _state
  =/  reason=@t
    %+  rap  3
    :~  'cancelled: '  why
        ?:  ?=(%event -.trigger.c)
          '; an event run keeps the policy it was admitted under: the next event runs under the new one'
        '; a manual run keeps the policy it was dispatched under: dispatch it again'
    ==
  =.  state  (cancel:ci-resolve state c reason now.bowl)
  =?  forge-events  (tagged-run c)  (note-tag-event c reason)
  state
::
::  a candidate whose bindings changed under it: running attempts are
::  cancelled (the daemon hears `attempt is closed` and stops act), the
::  plan is dropped, and the record is re-bound to the current baseline
::
++  reset-candidate
  |=  [c=candidate:ci why=@t]
  ^-  _state
  =.  attempts
    %+  roll  attempts.c
    |=  [id=attempt-id:ci acc=_attempts]
    =/  found=(unit attempt:ci)  (~(get by acc) id)
    ?~  found  acc
    ?.  =(%running status.u.found)  acc
    (~(put by acc) id u.found(status %cancelled, reason `why, finished `now.bowl))
  =.  daemons
    %-  ~(run by daemons)
    |=  d=daemon:ci
    d(running (~(dif in running.d) (silt attempts.c)))
  =/  base=(unit baseline:ci)  (~(get by baselines) [repo.c ref.c])
  =.  candidates
    %+  ~(put by candidates)  id.c
    %=  c
      status  ?:(=(%skipped status.c) status.c %pending)
      plan  ~
      plan-oid  ~
      selected  ?:(=(%required mode.c) ~ selected.c)
      verdict-reason  `why
      generation  (current-generation repo.c)
      baseline  ?~(base ~ `revision.u.base)
      lock  ?~(base ~ lock.u.base)
      incarnation  (current-incarnation repo.c)
      updated  now.bowl
    ==
  state
::
::  scry segments carry repository names and refs as (scot %t ...) so a
::  ref with slashes fits one path segment; a raw segment is taken as-is
::
++  decode-segment
  |=  segment=@t
  ^-  @t
  (fall (slaw %t segment) segment)
::
++  parse-oid
  |=  text=@t
  ^-  (unit oid:git)
  ?.  =(40 (met 3 text))  ~
  (oid-at:git-protocol [40 text] 0)
::
::  the landing rule: an object is eligible only when it is the
::  materialized candidate of a passed candidate for exactly this
::  repository and ref.  everything else is no.
::
++  eligible
  |=  [repo-segment=@t ref-segment=@t oid-segment=@t]
  ^-  ?
  ::  CI-RECOVERY-1: nothing lands while CI is paused
  ?:  ci-paused  %.n
  =/  repo=@t  (decode-segment repo-segment)
  =/  ref=@t  (decode-segment ref-segment)
  =/  oid=(unit oid:git)  (parse-oid (decode-segment oid-segment))
  ?~  oid  %.n
  %+  lien  ~(tap by candidates)
  |=  [* c=candidate:ci]
  ?&  =(repo repo.c)
      =(ref ref.c)
      (landable c)
      ?=(^ candidate.c)
      =(u.oid u.candidate.c)
  ==
::
::  the P4 landing predicate (rider 02; Q5): some authority lands the
::  object over exactly this tip, the one landing-for names.  %landed is
::  the record of a landing; %urgit binds the tip itself in the event
::  that moves the ref, so this predicate is never the replay guard alone
::
++  eligible-at
  |=  [repo-segment=@t ref-segment=@t oid-segment=@t tip-segment=@t]
  ^-  ?
  ?=(^ (landing-for repo-segment ref-segment oid-segment tip-segment))
::
::  the exact authority that lands an object over a tip (Q5): a landable
::  candidate of this repository and ref whose object it is and whose base
::  is the tip (landable is passed, trusted, required and bound to the
::  current incarnation, generation, baseline and lock); else the
::  candidate of a live override naming the object and the tip, whose
::  actor still holds the branch's override role.  several landable
::  candidates can share the object and base (a rerun, an approval twin):
::  the same authority, and %landed then supersedes the open ones, so the
::  first in map order is named.  %urgit's push path lands through it
::
++  landing-for
  |=  [repo-segment=@t ref-segment=@t oid-segment=@t tip-segment=@t]
  ^-  (unit [id=candidate-id:ci pull=(unit @ud)])
  ::  CI-RECOVERY-1: no authority lands anything while CI is paused
  ?:  ci-paused  ~
  =/  repo=@t  (decode-segment repo-segment)
  =/  ref=@t  (decode-segment ref-segment)
  =/  oid=(unit oid:git)  (parse-oid (decode-segment oid-segment))
  =/  tip=(unit oid:git)  (parse-oid (decode-segment tip-segment))
  ?~  oid  ~
  ?~  tip  ~
  =/  passed=(list [id=candidate-id:ci pull=(unit @ud)])
    %+  murn  ~(tap by candidates)
    |=  [id=candidate-id:ci c=candidate:ci]
    ?.  ?&  =(repo repo.c)
            =(ref ref.c)
            =(u.tip base.c)
            (landable c)
            ?=(^ candidate.c)
            =(u.oid u.candidate.c)
        ==
      ~
    `[id pull.c]
  ?^  passed  `i.passed
  =/  over=(unit override:ci)  (live-override repo ref u.oid u.tip)
  ?~  over  ~
  =/  owner=(unit candidate:ci)  (~(get by candidates) candidate.u.over)
  ?~  owner  ~
  `[candidate.u.over pull.u.owner]
::
::  the override that holds now for this advance, if any: valid by the
::  pure rule, and its actor still holding the branch's override role
::
++  live-override
  |=  [repo=@t ref=@t oid=oid:git tip=oid:git]
  ^-  (unit override:ci)
  =/  found=(list override:ci)
    %+  skim  ~(val by overrides)
    |=  o=override:ci
    ?&  =(repo repo.o)  =(ref ref.o)  =(oid oid.o)
        ?=(~ (override-valid:ci-provenance o now.bowl (current-incarnation repo) repo ref oid tip (current-generation repo)))
        (authorized repo %override `ref actor.o)
    ==
  ?~  found  ~
  `i.found
::
::  a read capability presented to /git (A06): the hash of a live
::  capability naming the repository, for an attempt still running
::
++  read-allowed
  |=  [repo=@t hash=@]
  ^-  ?
  =/  cap=(unit read-capability:ci)  (~(get by read-capabilities) hash)
  ?~  cap  %.n
  ?.  (~(has in repos.u.cap) repo)  %.n
  ?:  (gte now.bowl expires.u.cap)  %.n
  =/  running=(unit attempt:ci)  (~(get by attempts) attempt.u.cap)
  ?&(?=(^ running) (active:ci-resolve state u.running))
::
++  urgit-poke
  |=  [=wire act=action:ci]
  ^-  card
  [%pass (weld /urgit wire) %agent [our.bowl %urgit] %poke %ci-action !>(act)]
::
++  urgit-git-poke
  |=  [=wire act=action:git]
  ^-  card
  [%pass (weld /urgit wire) %agent [our.bowl %urgit] %poke %git-action !>(act)]
::
::  the three reads of %urgit, each guarded the way %urgit guards its own
::  reads of %urgit-ci: gall's %gu liveness first, under mule, and the %gx
::  read only once it says yes, because a bare %gx answered [~ ~] kills
::  the event even under mule.  ~ means "could not read": every caller
::  refuses on it.
::
++  urgit-peek
  |=  rest=path
  ^-  (unit *)
  =/  prefix=path  /(scot %p our.bowl)/urgit/(scot %da now.bowl)
  =/  live=(each ? tang)
    %-  mule
    |.
    .^(? %gu (weld prefix /$))
  ?.  ?&(?=(%& -.live) p.live)  ~
  =/  raw=(each * tang)
    %-  mule
    |.
    .^(* %gx (weld prefix (snoc rest %noun)))
  ?.  ?=(%& -.raw)  ~
  `p.raw
::
++  ref-tip
  |=  [repo=@t ref=@t]
  ^-  (unit (unit [tip=oid:git linked=?]))
  =/  raw=(unit *)  (urgit-peek /ci-ref/(scot %t repo)/(scot %t ref))
  ?~  raw  ~
  `;;((unit [tip=oid:git linked=?]) u.raw)
::
::  whether an actor can write a repository, as %urgit answers it (D3):
::  ~ when %urgit cannot be read, and every caller refuses on ~ rather
::  than assuming a class
::
++  can-write
  |=  [repo=@t actor=@p]
  ^-  (unit ?)
  =/  raw=(unit *)  (urgit-peek /ci-can-write/(scot %t repo)/(scot %p actor))
  ?~  raw  ~
  =/  answer=(each ? tang)
    %-  mule
    |.
    ;;(? u.raw)
  ?.  ?=(%& -.answer)  ~
  `p.answer
::
++  tree-at
  |=  [repo=@t oid=oid:git under=@t]
  ^-  (unit (list path))
  =/  raw=(unit *)
    (urgit-peek /ci-tree/(scot %t repo)/(scot %t (oid-text:git-codec oid))/(scot %t under))
  ?~  raw  ~
  ;;((unit (list path)) u.raw)
::
++  file-at
  |=  [repo=@t oid=oid:git file=@t]
  ^-  (unit octs)
  =/  raw=(unit *)
    (urgit-peek /ci-file/(scot %t repo)/(scot %t (oid-text:git-codec oid))/(scot %t file))
  ?~  raw  ~
  ;;((unit octs) u.raw)
::
++  handle-action
  |=  act=action:ci
  ^-  out
  ?-  -.act
      ::  CI-EMPTY-REF-1-A: every CI-protected ref has a tip, so the gate's
      ::  "no tip to stage against" branch is unreachable.  a repository
      ::  bound to a Clay desk lands through the clay path since P3 D9
      ::  (CI-LINKED-DESK-P1-B alternative A).  un-protect never checks.
      ::
      %set-ci-protected
    ?.  protected.act
      =.  ci-protected  (~(del in ci-protected) [repo.act ref.act])
      (emit ~)
    ?~  (read-settings:ci-storage our.bowl now.bowl)
      ~|  storage-refusal
      !!
    ?:  =('refs/ci/' (end [3 8] ref.act))
      ~|  'refs/ci/* are scratch refs and cannot be CI-protected'
      !!
    =/  tip=(unit (unit [tip=oid:git linked=?]))  (ref-tip repo.act ref.act)
    ?~  tip
      ~|  'ci: %urgit is not running; the ref cannot be checked'
      !!
    ?~  u.tip
      ~|  no-tip-refusal
      !!
    ::  a desk-linked repository lands through the receive tail's clay
    ::  path since P3 D9; the ci-ref peek still says whether it is linked
    ::
    =.  ci-protected  (~(put in ci-protected) [repo.act ref.act])
    =.  incarnations  (ensure-incarnation repo.act)
    =^  restores  state  (bump-generation repo.act (rap 3 ~['CI required on ' ref.act]))
    =.  audit  (record-audit our.bowl 'set-ci-protected' repo.act ref.act)
    (emit restores)
  ::
      ::  a staged head is materialized at once (D5); a head staged again
      ::  against the same base is the same candidate and keeps its record
      ::
      %stage-candidate
    ::  CI-RECOVERY-1: no run is admitted while CI is paused
    ?:  ci-paused  ~|(paused-refusal:ci-checkpoint !!)
    ::  the trust class is the actor's standing with the repository as
    ::  %urgit answers it (D3): a writer's revision is trusted, anyone
    ::  else's is untrusted.  an unreadable answer refuses the staging
    ::  rather than assuming a class.
    ::
    =/  writable=(unit ?)  (can-write repo.act actor.act)
    ?~  writable
      ~|  'ci: %urgit cannot be read; the actor cannot be classified'
      !!
    =/  =trust:ci  ?:(u.writable %trusted %untrusted)
    =/  id=candidate-id:ci  (candidate-id repo.act ref.act head.act base.act trust)
    =/  existing=(unit candidate:ci)  (~(get by candidates) id)
    ?^  existing
      =.  candidates  (~(put by candidates) id u.existing(updated now.bowl))
      (emit ~)
    ::  an untrusted candidate is materialized like any other but is
    ::  planned only once its repository runs restricted checks or a
    ::  writer approves it
    ::
    =.  incarnations  (ensure-incarnation repo.act)
    =/  next=candidate:ci
      %:  fresh-candidate
        id
        repo.act
        ref.act
        head.act
        base.act
        actor.act
        via.act
        trust
        pull.act
        %required
        ~
      ==
    =.  candidates  (~(put by candidates) id next)
    %-  emit
    :_  ~
    %+  urgit-poke  /materialize/(scot %uv id)
    [%materialize-candidate repo.act ref.act head.act base.act]
  ::
      %materialize
    =/  found=(unit candidate:ci)  (~(get by candidates) candidate.act)
    ?~  found  ~|('no such candidate' !!)
    ?^  candidate.u.found  ~|('candidate is already materialized' !!)
    %-  emit
    :_  ~
    %+  urgit-poke  /materialize/(scot %uv candidate.act)
    [%materialize-candidate repo.u.found ref.u.found head.u.found base.u.found]
  ::
      ::  the repository's policy for untrusted revisions (D3): %approval
      ::  holds them until a writer approves; %restricted plans and runs
      ::  them at once with no credentials and no landing
      ::
      %set-untrusted-policy
    =.  policies  (~(put by policies) repo.act policy.act)
    ::  a repository opening restricted checks has untrusted candidates
    ::  waiting: they are schedulable now
    ::
    schedule
  ::
      ::  a writer approves an untrusted candidate (D3): the same head and
      ::  base are staged again as a trusted candidate with its own id,
      ::  and the untrusted one is superseded.  a writer is whoever
      ::  %urgit's ci-can-write admits for the repository; an unreadable
      ::  answer refuses.
      ::
      %approve-candidate
    ::  CI-RECOVERY-1: an approval twin is a new run: none while paused
    ?:  ci-paused  ~|(paused-refusal:ci-checkpoint !!)
    =/  found=(unit candidate:ci)  (~(get by candidates) id.act)
    ?~  found  ~|('no such candidate' !!)
    =/  writable=(unit ?)  (can-write repo.u.found actor.act)
    ?~  writable
      ~|  'ci: %urgit cannot be read; the actor cannot be checked'
      !!
    ?.  u.writable
      ~|  `@t`(rap 3 ~['actor cannot write ' repo.u.found])
      !!
    ?.  =(%untrusted trust.u.found)
      ~|  'candidate is already trusted'
      !!
    ?:  =(%skipped status.u.found)
      ~|  'candidate was already superseded'
      !!
    =/  old=candidate:ci  u.found
    ?:  ?&  (tagged-run old)
            ?|  !=(generation.old (current-generation repo.old))
                !=(incarnation.old (current-incarnation repo.old))
            ==
        ==
      ~|('the admitted tag policy changed; this run cannot be approved' !!)
    =.  candidates
      %+  ~(put by candidates)  id.old
      %=  old
        status  %skipped
        verdict-reason  `'superseded by approval'
        updated  now.bowl
      ==
    =/  release=card
      (urgit-git-poke /release/(scot %uv id.old) [%delete-ref repo.old (scratch-ref old)])
    ::  an untrusted event run (a pull request from a ship that cannot
    ::  write the repository, Delivery 1C) is approved into a trusted
    ::  twin of the same event, selection and object, under a scratch
    ::  ref of its own; still an event run, never landable
    ?:  ?=(%event -.trigger.old)
      =/  event-twin=candidate-id:ci  (sham [%ci-event-approved id.old])
      ?:  (~(has by candidates) event-twin)  (emit ~[release])
      =/  fresh=candidate:ci
        %:  fresh-candidate
          event-twin  repo.old  ref.old  head.old  base.old  actor.old
          via.old  %trusted  pull.old  %event  ~
        ==
      =/  approved=candidate:ci
        fresh(candidate candidate.old, trigger trigger.old, selected selected.old)
      =?  approved  (tagged-run old)  (twin:ci-resolve old fresh)
      =?  state  (tagged-run old)  (approve:ci-resolve state old approved now.bowl)
      =.  candidates  (~(put by candidates) event-twin approved)
      =?  forge-events  (tagged-run approved)
        %+  note-tag-event
          approved
        (fall verdict-reason.approved 'tagged revision workflows selected after test approval')
      =.  audit  (record-audit actor.act 'approve-candidate' repo.old (scot %uv id.old))
      =/  source=card
        ?~  candidate.old
          %+  urgit-poke  /materialize/(scot %uv event-twin)
          [%materialize-run event-twin repo.old ref.old head.old base.old]
        %+  urgit-git-poke  /scratch/(scot %uv event-twin)
        [%set-ref repo.old (scratch-ref approved) u.candidate.old]
      =/  scheduled=out  schedule
      [[release source cards.scheduled] state.scheduled polls.scheduled]
    =/  twin-id=candidate-id:ci  (candidate-id repo.old ref.old head.old base.old %trusted)
    =/  twin=(unit candidate:ci)  (~(get by candidates) twin-id)
    ?^  twin
      =.  candidates  (~(put by candidates) twin-id u.twin(updated now.bowl))
      (emit ~[release])
    =/  next=candidate:ci
      %:  fresh-candidate
        twin-id
        repo.old
        ref.old
        head.old
        base.old
        actor.act
        %session
        %trusted
        pull.old
        mode.old
        trial-of.old
      ==
    =.  candidates  (~(put by candidates) twin-id next)
    =.  audit  (record-audit actor.act 'approve-candidate' repo.old (scot %uv id.old))
    %-  emit
    :~  release
        %+  urgit-poke  /materialize/(scot %uv twin-id)
        [%materialize-candidate repo.old ref.old head.old base.old]
    ==
  ::
      ::  a rerun stages the same head and base as a new candidate of the
      ::  same trust class; every job runs again from a fresh plan
      ::
      %rerun-candidate
    ?:  ci-paused  ~|(paused-refusal:ci-checkpoint !!)
    =/  found=(unit candidate:ci)  (~(get by candidates) id.act)
    ?~  found  ~|('no such candidate' !!)
    =/  old=candidate:ci  u.found
    ::  a manual run's inputs were admitted under the policy then
    ::  (Delivery 1A): it is dispatched again, never re-run in place
    ?:  ?=(%dispatch -.trigger.old)
      ~|  'a manual run is not re-run in place: dispatch it again from Run workflow, which admits its inputs under the policy now'
      !!
    ::  a resolve's record is no run: resolve the revision again instead
    ?:  (resolver-record old)
      ~|  'a dependency resolution is not a run: resolve the revision again from Settings → CI policy'
      !!
    ::  an event run is the run of one admitted event (Delivery 1C)
    ?:  ?=(%event -.trigger.old)
      ~|  'an event run is not re-run in place: the next push, pull request activity or due schedule runs again under the policy then'
      !!
    =/  new-id=candidate-id:ci  (rerun-id repo.old ref.old head.old base.old)
    =/  next=candidate:ci
      %:  fresh-candidate
        new-id
        repo.old
        ref.old
        head.old
        base.old
        actor.old
        via.old
        trust.old
        pull.old
        mode.old
        trial-of.old
      ==
    =.  candidates  (~(put by candidates) new-id next)
    %-  emit
    :_  ~
    %+  urgit-poke  /materialize/(scot %uv new-id)
    [%materialize-candidate repo.old ref.old head.old base.old]
  ::
      ::  a stored credential (D4): the value sits in state and is released
      ::  only as a grant to a trusted attempt; it never leaves through a
      ::  scry, a reply, a log line or an event.  a short value would be
      ::  scrubbed out of ordinary text, so it is refused.
      ::
      %set-credential
    ?:  =('' name.act)  ~|('credential name is required' !!)
    ::  CI-RECOVERY-1: a value entered settles its re-entry mark
    =.  state  (reentered:ci-checkpoint state repo.act name.act)
    ?:  (gth (met 3 name.act) 64)  ~|('credential name is at most 64 characters' !!)
    ?:  (lth (met 3 value.act) min-credential)
      ~|  'credential values must be at least 8 characters'
      !!
    ::  act masks a secret only where the whole value appears on one
    ::  output line (measured on 0.2.89: a two-line secret printed line by
    ::  line is not masked), so every line of every released value is
    ::  scrubbed on both sides, daemon and ship; every line of at least
    ::  eight characters is in the scrub set
    ::
    =.  credentials
      (~(put by credentials) [repo.act name.act] [value.act scope.act envs.act now.bowl])
    (emit ~)
  ::
      %delete-credential
    =.  credentials  (~(del by credentials) [repo.act name.act])
    ::  CI-RECOVERY-1: a deleted credential needs no re-entry either
    =.  state  (reentered:ci-checkpoint state repo.act name.act)
    (emit ~)
  ::
      %rotate-ci-key
    =.  signing  `fresh-signing-key
    =?  signing  ?=(^ ship-keys)  (certified signing u.ship-keys)
    (emit ~)
  ::
      %materialize-candidate
    ~|  '%materialize-candidate is a poke on %urgit, not %urgit-ci'
    !!
  ::
      %land-candidate
    ~|  '%land-candidate is a poke on %urgit, not %urgit-ci'
    !!
  ::
      ::  the first materialization wins: a candidate is never regenerated
      ::  after it has been recorded, let alone after it has been tested.
      ::  a ready candidate is planned at once (D4).
      ::
      %candidate-ready
    =/  waiting=(list candidate:ci)  (staged-for repo.act ref.act head.act base.act)
    ?~  waiting  (emit ~)
    =.  candidates
      %+  roll  `(list candidate:ci)`waiting
      |=  [c=candidate:ci acc=_candidates]
      (~(put by acc) id.c c(candidate `candidate.act, conflict %.n, updated now.bowl))
    ::  a required candidate of a branch without a promoted baseline waits
    ::  with the reason (P4 D5: the candidate's own YAML is no evidence);
    ::  one whose harness paths differ from the baseline's gets a trial
    ::  twin — its own harness, unprivileged, never landable — beside the
    ::  required run that uses the baseline's bytes
    ::
    =.  state
      %+  roll  `(list candidate:ci)`waiting
      |=  [stale=candidate:ci acc=_state]
      =.  state  acc
      ::  the record as the first roll left it (materialized), not the
      ::  one `waiting` listed: a put of the stale row would unset it
      =/  c=candidate:ci  (~(got by candidates) id.stale)
      ?.  =(%required mode.c)  state
      =/  base=(unit baseline:ci)  (~(get by baselines) [repo.c ref.c])
      ?~  base
        =.  candidates
          %+  ~(put by candidates)  id.c
          %=  c
            verdict-reason  `(rap 3 ~['no promoted baseline for ' ref.c '; promote a harness revision (Settings → CI policy) to run required checks'])
            updated  now.bowl
          ==
        state
      =/  differs=?  (harness-differs repo.c candidate.act revision.u.base harness-paths.u.base)
      =.  candidates  (~(put by candidates) id.c c(harness-differs differs))
      ?.  differs  state
      =/  twin-id=candidate-id:ci  (sham [repo.c ref.c head.c base.c %trial])
      ?:  (~(has by candidates) twin-id)  state
      =/  twin=candidate:ci
        %:  fresh-candidate
          twin-id
          repo.c
          ref.c
          head.c
          base.c
          actor.c
          via.c
          trust.c
          pull.c
          %trial
          `id.c
        ==
      =.  candidates
        %+  ~(put by candidates)
          twin-id
        twin(candidate `candidate.act, baseline `candidate.act, lock ~)
      =.  audit
        %:  record-audit
          actor.c
          'trial-staged'
          repo.c
          %+  rap
            3
          ~[(scot %uv twin-id) ' beside ' (scot %uv id.c) ': harness paths differ from the baseline']
        ==
      state
    schedule
  ::
      ::  a head that cannot be merged onto its base cannot be tested: the
      ::  candidate fails with the reason rather than waiting forever
      ::
      %candidate-conflict
    =/  waiting=(list candidate:ci)  (staged-for repo.act ref.act head.act base.act)
    ?~  waiting  (emit ~)
    =.  candidates
      %+  roll  `(list candidate:ci)`waiting
      |=  [c=candidate:ci acc=_candidates]
      %+  ~(put by acc)  id.c
      %=  c
        conflict  %.y
        status  %failed
        verdict-reason  `'candidate could not be materialized: the source conflicts with the destination'
        updated  now.bowl
      ==
    (emit ~)
  ::
      ::  a minted, never enrolled token is deleted (D2); an enrolled
      ::  daemon is revoked instead, and a revoked record may be removed
      ::
      %expire-token
    =/  found=(unit daemon:ci)  (~(get by daemons) id.act)
    ?~  found  ~|('no such daemon' !!)
    ?:  ?&(?=(^ enrolled.u.found) ?=(~ revoked.u.found))
      ~|  'daemon is enrolled; revoke it instead'
      !!
    =.  daemons  (~(del by daemons) id.act)
    (emit ~)
  ::
      ::  an enrolled daemon is revoked (D2): its bearer is cleared, so its
      ::  next poll answers 401 and it exits; everything it was running is
      ::  offered again on another daemon (CI-DELIVERY-1.1 d)
      ::
      %revoke-daemon
    =/  found=(unit daemon:ci)  (~(get by daemons) id.act)
    ?~  found  ~|('no such daemon' !!)
    ?~  enrolled.u.found  ~|('daemon is not enrolled; expire its token instead' !!)
    ?^  revoked.u.found  ~|('daemon is already revoked' !!)
    =.  daemons
      (~(put by daemons) id.act u.found(bearer-hash ~, revoked `now.bowl))
    =/  released=(list attempt:ci)
      %+  murn  ~(tap in running.u.found)
      |=(id=attempt-id:ci (~(get by attempts) id))
    =.  state
      %+  roll  released
      |=  [=attempt:ci acc=_state]
      =.  state  acc
      ?.  =(%running status.attempt)  state
      ::  a privileged attempt is never re-offered (rider 02, A03): the
      ::  external side effect may have happened; it closes unknown
      ?:  ?=(^ approval.attempt)
        %+  close-unknown
          attempt
        'daemon revoked while a privileged job ran; the external side effect may have happened: needs review'
      (reoffer-attempt attempt 'daemon revoked; re-offered')
    =/  touched=(list candidate-id:ci)
      ~(tap in (silt (turn released |=(=attempt:ci candidate.attempt))))
    =|  cards=(list card)
    |-
    ?^  touched
      =/  settled=out  (settle i.touched)
      =.  state  state.settled
      $(touched t.touched, cards (weld cards cards.settled))
    =/  scheduled=out  schedule
    [(weld cards cards.scheduled) state.scheduled polls.scheduled]
  ::
      ::  the operator binds a daemon to named repositories (D2b): ~ is
      ::  the pool; the daemon never declares this itself
      ::
      %set-daemon-repos
    =/  found=(unit daemon:ci)  (~(get by daemons) id.act)
    ?~  found  ~|('no such daemon' !!)
    =.  daemons  (~(put by daemons) id.act u.found(repos repos.act))
    schedule
  ::
      ::  the operator's assignment: a plan, or one named job, on one
      ::  named daemon, capacity notwithstanding.  the harness drives this;
      ::  an operator re-runs a job with it.
      ::
      %assign
    ::  CI-RECOVERY-1: no assignment is offered while CI is paused
    ?:  ci-paused  ~|(paused-refusal:ci-checkpoint !!)
    =/  found=(unit candidate:ci)  (~(get by candidates) candidate.act)
    ?~  found  ~|('no such candidate' !!)
    ?:  (tagged-run u.found)
      ~|('tagged-revision runs use the scheduler and their admitted selection' !!)
    ?~  candidate.u.found  ~|('candidate is not materialized' !!)
    =/  runner=(unit daemon:ci)  (~(get by daemons) daemon.act)
    ?~  runner  ~|('no such daemon' !!)
    ?~  enrolled.u.runner  ~|('daemon is not enrolled' !!)
    ?:  ?&(?=(%plan kind.act) ?=(^ plan.u.found))
      ~|('candidate already has a plan' !!)
    ?:  ?&(?=(%job kind.act) |(?=(~ workflow.act) ?=(~ job.act)))
      ~|('a job assignment names a workflow file and a job id' !!)
    ?:  ?&(?=(%resolve kind.act) !resolver.u.runner)
      ~|('a resolve assignment needs a resolver-capable daemon' !!)
    =/  deadline=@dr
      %+  fall  deadline.act
      ?-  kind.act
        %plan  plan-deadline
        %resolve  resolve-deadline
        %job  default-deadline
      ==
    =^  made  state
      (create-attempt candidate.act daemon.act kind.act workflow.act job.act deadline ~)
    =/  delivered=out  (deliver daemon.act)
    =.  state  state.delivered
    =.  polls  polls.delivered
    ::  a re-run of a closed candidate needs its objects reachable again:
    ::  the scratch ref released at the terminal status is set once more
    ::  through the existing %set-ref path, before the assignment goes out
    ::
    =/  restore=card
      %+  urgit-git-poke  /scratch/(scot %uv candidate.act)
      [%set-ref repo.u.found (scratch-ref u.found) u.candidate.u.found]
    (emit [restore timer.made cards.delivered])
  ::
      %landed
    =/  found=(unit candidate:ci)  (~(get by candidates) candidate.act)
    ?~  found  (emit ~)
    =.  candidates
      (~(put by candidates) candidate.act u.found(verdict-reason `'landed', updated now.bowl))
    ::  the override that let this object advance (if one did) is used
    ::  now, in the same event the ref moved (rider 02): a replay finds
    ::  it consumed
    ::
    =.  overrides
      ?~  candidate.u.found  overrides
      %-  ~(run by overrides)
      |=  o=override:ci
      ?.  ?&  =(repo.o repo.u.found)  =(ref.o ref.u.found)  =(oid.o u.candidate.u.found)
              ?=(~ consumed.o)  ?=(~ invalidated.o)
          ==
        o
      o(consumed `now.bowl)
    =.  audit
      %:  record-audit
        our.bowl
        'landed'
        repo.u.found
        %+  rap
          3
        ~[ref.u.found ' ← ' (oid-text:git-codec (fall candidate.u.found head.u.found)) ' (candidate ' (scot %uv candidate.act) ')']
      ==
    ::  every other open REQUIRED candidate of the same object on the
    ::  same ref is superseded: what it was for has happened (a re-run
    ::  that landed leaves its original behind; a stale original would
    ::  otherwise be re-planned by every later policy change and take a
    ::  runner for nothing).  trials and shadows keep their own purpose.
    ::
    =.  state  (supersede-landed u.found)
    (emit ~)
  ::
      ::  a stale destination leaves the candidate passed and unlanded;
      ::  the pusher rebases and pushes again (P17)
      ::
      %land-refused
    =/  found=(unit candidate:ci)  (~(get by candidates) candidate.act)
    ?~  found  (emit ~)
    =.  candidates
      (~(put by candidates) candidate.act u.found(verdict-reason `reason.act, updated now.bowl))
    (emit ~)
  ::
      ::  %urgit deleted the repository: every record kept under the
      ::  name goes with it — its candidates, their attempts and
      ::  assignments, its CI protection, its policy, its credentials, and
      ::  the name in every daemon's binding — so a repository re-created
      ::  under the name has no CI history.  R18 found the gap: a passed
      ::  candidate of the deleted repository answered the eligibility
      ::  peek %.y and the same oid landed unstaged in the new one.  a
      ::  daemon bound only to the deleted repository is left bound to
      ::  nothing, not returned to the pool: the operator drew that fence
      ::  and widens it in the panel.
      ::
      %repository-deleted
    =/  gone=(set candidate-id:ci)  (repository-candidates repository.act)
    =/  gone-attempts=(set attempt-id:ci)
      %-  silt
      %+  murn  ~(tap by attempts)
      |=([id=attempt-id:ci a=attempt:ci] ?:((~(has in gone) candidate.a) `id ~))
    =.  candidates
      %-  malt
      %+  skip  ~(tap by candidates)
      |=([id=candidate-id:ci *] (~(has in gone) id))
    =.  attempts
      %-  malt
      %+  skip  ~(tap by attempts)
      |=([id=attempt-id:ci *] (~(has in gone-attempts) id))
    =.  assignments
      %-  malt
      %+  skip  ~(tap by assignments)
      |=([* a=assignment:ci] (~(has in gone) candidate.a))
    =.  ci-protected
      %-  silt
      %+  skip  ~(tap in ci-protected)
      |=([repo=@t ref=@t] =(repository.act repo))
    =.  policies  (~(del by policies) repository.act)
    =.  credentials
      %-  malt
      %+  skip  ~(tap by credentials)
      |=([[repo=@t name=@t] *] =(repository.act repo))
    =.  daemons
      %-  ~(run by daemons)
      |=  d=daemon:ci
      =.  running.d  (~(dif in running.d) gone-attempts)
      ?~  repos.d  d
      d(repos `(~(del in u.repos.d) repository.act))
    ::  P4 (P12): the incarnation, generation, baselines, locks, roles,
    ::  environments, approvals, overrides, network policies, read
    ::  capabilities, shadows, comparisons and sandbox requirement go too;
    ::  a re-created repository starts from nothing
    ::
    =.  incarnations  (~(del by incarnations) repository.act)
    =.  generations  (~(del by generations) repository.act)
    =.  automatic-inputs  (~(del by automatic-inputs) repository.act)
    =.  input-snapshots
      (malt (skip ~(tap by input-snapshots) |=([id=candidate-id:ci *] (~(has in gone) id))))
    =.  baselines
      %-  malt
      %+  skip  ~(tap by baselines)
      |=([[repo=@t ref=@t] *] =(repository.act repo))
    =.  locks
      %-  malt
      %+  skip  ~(tap by locks)
      |=([* l=lock:ci] =(repository.act repo.l))
    =.  input-evidence
      (malt (skim ~(tap by input-evidence) |=([id=@ux *] (~(has by locks) id))))
    =.  roles  (~(del by roles) repository.act)
    =.  environments
      %-  malt
      %+  skip  ~(tap by environments)
      |=([[repo=@t name=@t] *] =(repository.act repo))
    =.  approvals
      %-  malt
      %+  skip  ~(tap by approvals)
      |=([* a=approval:ci] =(repository.act repo.a))
    =.  overrides
      %-  malt
      %+  skip  ~(tap by overrides)
      |=([* o=override:ci] =(repository.act repo.o))
    =.  network-policies  (~(del by network-policies) repository.act)
    =.  read-capabilities
      %-  malt
      %+  skip  ~(tap by read-capabilities)
      |=([* c=read-capability:ci] (~(has in repos.c) repository.act))
    =.  shadows
      %-  malt
      %+  skip  ~(tap by shadows)
      |=([* sh=shadow:ci] =(repository.act repo.sh))
    =.  sandbox-requirements  (~(del by sandbox-requirements) repository.act)
    =.  tag-runs
      %-  malt
      %+  skip  ~(tap by tag-runs)
      |=([id=candidate-id:ci *] (~(has in gone) id))
    =.  resolve-mappings
      %-  malt
      %+  skip  ~(tap by resolve-mappings)
      |=([id=candidate-id:ci *] (~(has in gone) id))
    =.  harness-paths  (~(del by harness-paths) repository.act)
    ::  Delivery 1C: its recorded forge events and its schedules (a wake
    ::  still set finds no entry and does nothing)
    =.  forge-events
      %-  malt
      %+  skip  ~(tap by forge-events)
      |=([* e=forge-event:ci] =(repository.act repo.e))
    =.  schedules
      %-  malt
      %+  skip  ~(tap by schedules)
      |=([k=schedule-key:ci *] =(repository.act repo.k))
    =.  audit
      %:  record-audit
        our.bowl
        'repository-deleted'
        repository.act
        'every CI record under the name dropped'
      ==
    (emit ~)
  ::
      ::  ---- P4 actions (D4-D7; riders 02-04) ----
      ::
      ::  an explicit import (D4; rider 03): a resolve attempt on a
      ::  resolver-capable daemon, which walks the revision's workflows,
      ::  fetches every external input, mirrors Git sources into urgit
      ::  repositories this ship creates for it, and posts the lock
      ::
      %resolve-dependencies
    ::  CI-RECOVERY-1: a resolve is an assignment: none while paused
    ?:  ci-paused  ~|(paused-refusal:ci-checkpoint !!)
    =+  (require-authority repo.act %ci-policy ~ actor.act)
    =.  incarnations  (ensure-incarnation repo.act)
    =/  chosen=(unit daemon-id:ci)  (select-resolver repo.act)
    ?~  chosen
      ~|  'no live resolver-capable runner (resolver = true) is enrolled'
      !!
    ::  the resolve rides a synthetic candidate record for the revision so
    ::  the attempt has a candidate to bind to; it never lands (mode shadow)
    =/  id=candidate-id:ci  (sham [%ci-resolve repo.act revision.act])
    =/  existing=(unit candidate:ci)  (~(get by candidates) id)
    =/  c=candidate:ci
      ?^  existing  u.existing
      =/  fresh=candidate:ci
        %:  fresh-candidate
          id
          repo.act
          'refs/ci/resolve'
          revision.act
          revision.act
          actor.act
          %session
          %trusted
          ~
          %shadow
          ~
        ==
      fresh(candidate `revision.act, status %pending)
    =.  candidates  (~(put by candidates) id c(candidate `revision.act, updated now.bowl))
    ::  a mapping is a prefix of an origin or URL and where to read it
    ::  from; both must be non-empty and the target an http(s) URL
    ?.  %+  levy  mappings.act
        |=  [from=@t to=@t]
        ?&  !=('' from)
            ?|(=('http://' (end [3 7] to)) =('https://' (end [3 8] to)))
        ==
      ~|('a mapping is [from to] with a non-empty prefix and an http(s) target' !!)
    =.  resolve-mappings
      ?~  mappings.act  (~(del by resolve-mappings) id)
      (~(put by resolve-mappings) id mappings.act)
    =^  made  state
      (create-attempt id u.chosen %resolve ~ ~ resolve-deadline ~)
    =.  audit
      %:  record-audit  actor.act  'resolve-dependencies'  repo.act
        %+  rap  3
        :~  (oid-text:git-codec revision.act)  ' on daemon '  (scot %uv u.chosen)
            ?~  mappings.act  ''
            %+  rap
              3
            ~['; mappings: ' (join:ci-plan (turn mappings.act |=([from=@t to=@t] (rap 3 ~[from ' -> ' to]))) ', ')]
        ==
      ==
    =/  restore=card
      %+  urgit-git-poke  /scratch/(scot %uv id)
      [%set-ref repo.act (scratch-ref c) revision.act]
    =/  delivered=out  (deliver u.chosen)
    =.  state  state.delivered
    =.  polls  polls.delivered
    (emit [restore timer.made cards.delivered])
  ::
      ::  promotion (D5; rider 02): the branch's required checks come from
      ::  this revision's harness and its lock from now on; the generation
      ::  moves and affected evidence is reset
      ::
      %promote-baseline
    =+  (require-authority repo.act %ci-policy ~ actor.act)
    ?:  =('' reason.act)  ~|('a promotion names its reason' !!)
    =/  policy-repo=@t  (fall policy-repo.act repo.act)
    ::  the lock the baseline runs with: the one named, which must be a
    ::  lock of this revision, else the NEWEST lock resolved for it (an
    ::  explicit update is a later resolve; promotion is what adopts it)
    =/  resolved-for=(list lock:ci)
      %+  sort
        %+  skim  ~(val by locks)
        |=(l=lock:ci &(=(repo.l repo.act) =(revision.l revision.act)))
      |=([a=lock:ci b=lock:ci] (gth resolved.a resolved.b))
    =/  lock-of=(unit @ux)
      ?^  lock.act
        ?.  (lien resolved-for |=(l=lock:ci =(digest.l u.lock.act)))
          ~|('the named lock is not a lock of this revision' !!)
        lock.act
      ?~(resolved-for ~ `digest.i.resolved-for)
    ::  a revision whose dependency walk is not resolved cannot be the
    ::  baseline unless it has no workflows at all; the operator resolves
    ::  first (P02: a lock is promoted, never inferred)
    =/  wf-tree=(unit (list path))  (tree-at policy-repo revision.act '.github/workflows')
    ?~  wf-tree
      ~|  `@t`(rap 3 ~['revision ' (oid-text:git-codec revision.act) ' is not readable in ' policy-repo])
      !!
    ?:  ?&(?=(~ lock-of) ?=(^ u.wf-tree))
      ~|  'resolve the revision\'s dependencies before promoting it (no lock for it)'
      !!
    =/  before=(unit baseline:ci)  (~(get by baselines) [repo.act ref.act])
    =/  harness=(list @t)
      =/  set=(unit (list @t))  (~(get by harness-paths) repo.act)
      ?^  set  u.set
      ?^  before  harness-paths.u.before
      ~['.github/']
    =/  next-gen=@ud  +((current-generation repo.act))
    =.  baselines
      %+  ~(put by baselines)  [repo.act ref.act]
      [revision.act harness lock-of now.bowl actor.act reason.act next-gen policy-repo.act]
    =.  incarnations  (ensure-incarnation repo.act)
    =^  restores  state
      %+  bump-generation
        repo.act
      (rap 3 ~['baseline promoted to ' (oid-text:git-codec revision.act)])
    =.  audit
      %:  record-audit  actor.act  'promote-baseline'  repo.act
        %+  rap  3
        :~  ref.act
            ': '
            ?~(before 'none' (oid-text:git-codec revision.u.before))
            ' → '
            %-  oid-text:git-codec
            revision.act
            '; lock '  ?~(lock-of 'none' (hex-bytes:ci-provenance u.lock-of 32))  '; '  reason.act
        ==
      ==
    ::  the baseline's objects stay reachable for the runner under a
    ::  scratch ref of its own
    =/  keep=card
      %+  urgit-git-poke  /baseline/(scot %t repo.act)
      [%set-ref policy-repo (baseline-ref repo.act ref.act) revision.act]
    ::  the default branch's schedules (Delivery 1C) come from its promoted
    ::  catalog: a promotion registers them again, a new definition from
    ::  future time only
    =^  timers  state
      (register-schedules repo.act (rap 3 ~['baseline of ' ref.act ' promoted']))
    =/  scheduled=out  schedule
    =.  state  state.scheduled
    =.  polls  polls.scheduled
    (emit :(weld restores [keep cards.scheduled] timers))
  ::
      %revoke-baseline
    =+  (require-authority repo.act %ci-policy ~ actor.act)
    =/  before=(unit baseline:ci)  (~(get by baselines) [repo.act ref.act])
    ?~  before  ~|('no baseline is promoted for that ref' !!)
    =.  baselines  (~(del by baselines) [repo.act ref.act])
    =^  restores  state  (bump-generation repo.act 'baseline revoked')
    =.  audit
      %:  record-audit
        actor.act
        'revoke-baseline'
        repo.act
        (rap 3 ~[ref.act ': ' (oid-text:git-codec revision.u.before) '; ' reason.act])
      ==
    =/  release=card
      %+  urgit-git-poke  /baseline/(scot %t repo.act)
      [%delete-ref (fall policy-repo.u.before repo.act) (baseline-ref repo.act ref.act)]
    =^  timers  state
      (register-schedules repo.act (rap 3 ~['baseline of ' ref.act ' revoked']))
    (emit (weld (snoc restores release) timers))
  ::
      ::  which paths of the tree are the harness (D5): trusted
      ::  orchestration taken from the baseline in a required run.  every
      ::  branch's baseline of the repository is updated; the generation
      ::  moves.
      ::
      %set-harness-paths
    =+  (require-authority repo.act %ci-policy ~ actor.act)
    ?~  paths.act  ~|('at least one harness path is required' !!)
    ?.  (levy `(list @t)`paths.act harness-path-valid:ci-provenance)
      ~|('a harness path is repository-relative with no traversal' !!)
    =.  harness-paths  (~(put by harness-paths) repo.act paths.act)
    =.  baselines
      %-  ~(urn by baselines)
      |=  [[repo=@t ref=@t] b=baseline:ci]
      ?.(=(repo repo.act) b b(harness-paths paths.act))
    =^  restores  state  (bump-generation repo.act 'harness paths changed')
    =.  audit  (record-audit actor.act 'set-harness-paths' repo.act (join:ci-plan paths.act ', '))
    (emit restores)
  ::
      ::  the sandbox a repository's ordinary required jobs need (rider
      ::  04): the VM unless the operator opts the repository into the
      ::  container compatibility mode; untrusted, trial, shadow and
      ::  privileged work needs the VM regardless
      ::
      %set-sandbox-requirement
    =+  (require-authority repo.act %ci-policy ~ actor.act)
    =.  sandbox-requirements  (~(put by sandbox-requirements) repo.act need.act)
    =^  restores  state  (bump-generation repo.act (rap 3 ~['sandbox requirement ' need.act]))
    =.  audit  (record-audit actor.act 'set-sandbox-requirement' repo.act need.act)
    (emit restores)
  ::
      ::  delegated role bindings (rider 02): the owner grants subsets
      ::
      %set-role
    =+  (require-authority repo.act %ci-policy ~ actor.act)
    ?:  ?&(?=(%ci-policy role.act) !=(~ (repo-owner-or-fail repo.act actor.act)))
      ~|('only the owner delegates the ci-policy role' !!)
    ?:  ?&(!=(~ (repo-owner-or-fail repo.act actor.act)) (~(has in ships.act) actor.act))
      ~|('a delegate does not bind a role to itself' !!)
    =/  current=(list binding:ci)  (~(gut by roles) repo.act ~)
    =/  rest=(list binding:ci)
      (skip current |=(b=binding:ci &(=(role.b role.act) =(scope.b scope.act))))
    =.  roles  (~(put by roles) repo.act [[role.act scope.act ships.act] rest])
    =^  restores  state  (bump-generation repo.act (rap 3 ~['role ' role.act ' bound']))
    =.  audit
      %:  record-audit
        actor.act
        'set-role'
        repo.act
        %+  rap
          3
        ~[role.act ?~(scope.act '' (rap 3 ~[' (' u.scope.act ')'])) ': ' (join:ci-plan (turn ~(tap in ships.act) |=(p=@p (scot %p p))) ', ')]
      ==
    (emit restores)
  ::
      %clear-role
    =+  (require-authority repo.act %ci-policy ~ actor.act)
    =/  current=(list binding:ci)  (~(gut by roles) repo.act ~)
    =.  roles
      %+  ~(put by roles)  repo.act
      (skip current |=(b=binding:ci &(=(role.b role.act) =(scope.b scope.act))))
    =^  restores  state  (bump-generation repo.act (rap 3 ~['role ' role.act ' cleared']))
    =.  audit
      %:  record-audit
        actor.act
        'clear-role'
        repo.act
        (rap 3 ~[role.act ?~(scope.act '' (rap 3 ~[' (' u.scope.act ')']))])
      ==
    (emit restores)
  ::
      ::  environments (D6): records, never an enum; a job that names one
      ::  is privileged and releases only its credentials, only through an
      ::  approval or this explicit automation rule
      ::
      %set-environment
    =+  (require-authority repo.act %ci-policy ~ actor.act)
    ?:  =('' name.act)  ~|('an environment has a name' !!)
    =.  environments
      %+  ~(put by environments)
        [repo.act name.act]
      [name.act description.act automation.act credentials.act now.bowl actor.act]
    =^  restores  state  (bump-generation repo.act (rap 3 ~['environment ' name.act ' set']))
    =.  audit
      %:  record-audit
        actor.act
        'set-environment'
        repo.act
        %+  rap
          3
        ~[name.act ' (' automation.act '): ' (join:ci-plan ~(tap in credentials.act) ', ')]
      ==
    (emit restores)
  ::
      %delete-environment
    =+  (require-authority repo.act %ci-policy ~ actor.act)
    =.  environments  (~(del by environments) [repo.act name.act])
    =^  restores  state  (bump-generation repo.act (rap 3 ~['environment ' name.act ' deleted']))
    =.  audit  (record-audit actor.act 'delete-environment' repo.act name.act)
    (emit restores)
  ::
      ::  a one-use approval (rider 02): fifteen minutes, exactly one
      ::  attempt, bound to everything the job is now.  test approval is
      ::  not this: %approve-candidate releases nothing.
      ::
      %approve-environment
    ::  CI-RECOVERY-1: nothing runs while CI is paused, so nothing is
    ::  approved for a run then
    ?:  ci-paused  ~|(paused-refusal:ci-checkpoint !!)
    =/  found=(unit candidate:ci)  (~(get by candidates) candidate.act)
    ?~  found  ~|('no such candidate' !!)
    =/  c=candidate:ci  u.found
    =+  (require-authority repo.c %environment-approver `environment.act actor.act)
    =/  env=(unit environment:ci)  (~(get by environments) [repo.c environment.act])
    ?~  env  ~|(`@t`(rap 3 ~['unknown environment ' environment.act]) !!)
    ?~  candidate.c  ~|('candidate is not materialized' !!)
    ?.  =(%trusted trust.c)  ~|('an untrusted candidate cannot receive a deployment approval' !!)
    ?.  =(%required mode.c)
      ~|('only a required run can be approved for an environment; a trial or shadow releases nothing' !!)
    ?~  baseline.c  ~|('the candidate has no baseline' !!)
    =/  planned=(unit job:ci)  (planned-job c `workflow.act `job.act)
    ?~  planned  ~|('the candidate\'s plan has no such job' !!)
    ?.  =(environment.u.planned `environment.act)
      ~|(`@t`(rap 3 ~['job ' job.act ' does not name environment ' environment.act]) !!)
    ::  the released subset: what was asked, within what the environment
    ::  allows, within what the repository holds
    =/  allowed=(set @t)
      %-  ~(int in credentials.u.env)
      %-  ~(int in credentials.act)
      (silt (turn (credential-names repo.c) |=([name=@t *] name)))
    ?:  =(~ allowed)  ~|('none of the requested credentials is allowed for that environment' !!)
    =/  id=@uv
      %-  sham
      [%ci-approval candidate.act workflow.act job.act environment.act now.bowl eny.bowl]
    =/  =approval:ci
      :*  id
          repo.c
          incarnation.c
          candidate.act
          u.candidate.c
          workflow.act
          job.act
          environment.act
          allowed  u.baseline.c  lock.c  generation.c  actor.act  now.bowl
          (add now.bowl authorization-lifetime:ci-provenance)  ~  ~
      ==
    =.  approvals  (~(put by approvals) id approval)
    =.  audit
      %:  record-audit
        actor.act
        'approve-environment'
        repo.c
        %+  rap
          3
        ~[(scot %uv candidate.act) ' ' workflow.act '/' job.act ' → ' environment.act ' [' (join:ci-plan ~(tap in allowed) ', ') '] (' (scot %uv id) ')']
      ==
    schedule
  ::
      ::  an override (R4.3-A; rider 02): recorded with what was missing,
      ::  fifteen minutes to use, and the landing asked at once
      ::
      %record-override
    ::  CI-RECOVERY-1: an override lands at once: never while paused
    ?:  ci-paused  ~|(paused-refusal:ci-checkpoint !!)
    =+  (require-authority repo.act %override `ref.act actor.act)
    ?:  =('' reason.act)  ~|('an override names its reason' !!)
    =/  found=(unit candidate:ci)  (~(get by candidates) candidate.act)
    ?~  found  ~|('no such candidate' !!)
    =/  c=candidate:ci  u.found
    ?.  &(=(repo.c repo.act) =(ref.c ref.act))  ~|('candidate is for another ref' !!)
    ?~  candidate.c  ~|('candidate is not materialized' !!)
    ?.  =(u.candidate.c oid.act)  ~|('oid is not the candidate\'s exact object' !!)
    ?.  =(%required mode.c)  ~|('a trial or shadow candidate cannot be overridden onto the ref' !!)
    =/  tip=(unit (unit [tip=oid:git linked=?]))  (ref-tip repo.act ref.act)
    ?~  tip  ~|('ci: %urgit cannot be read' !!)
    ?~  u.tip  ~|('ref has no tip' !!)
    ?.  =(tip.u.u.tip expected.act)  ~|('expected tip is not the ref\'s current tip' !!)
    =/  missing=@t
      %+  rap  3
      :~  'status '  status.c
          ?~(verdict-reason.c '' (rap 3 ~[' (' u.verdict-reason.c ')']))
          ?:((bindings-current c) '' '; bindings not current')
      ==
    =/  id=@uv  (sham [%ci-override candidate.act oid.act expected.act now.bowl eny.bowl])
    =/  =override:ci
      :*  id
          repo.act
          ref.act
          incarnation.c
          candidate.act
          oid.act
          expected.act
          actor.act
          reason.act
          missing  (current-generation repo.act)  now.bowl
          %+  add
            now.bowl
          authorization-lifetime:ci-provenance
          ~
          ~
      ==
    =.  overrides  (~(put by overrides) id override)
    =.  audit
      %:  record-audit
        actor.act
        'record-override'
        repo.act
        %+  rap
          3
        ~[ref.act ' ← ' (oid-text:git-codec oid.act) ' over ' (oid-text:git-codec expected.act) '; missing: ' missing '; reason: ' reason.act ' (' (scot %uv id) ')']
      ==
    %-  emit
    :_  ~
    %+  urgit-poke  /land/(scot %uv candidate.act)
    [%land-candidate candidate.act repo.act ref.act oid.act expected.act pull.c]
  ::
      ::  a standing network policy (rider 03): this job of this workflow
      ::  may use a runner profile toward these destinations
      ::
      %set-automatic-inputs
    =/  changed=(each state-0:ci @t)
      %:  edit:ci-input  state  repo.act  sources.act  expected.act
        (authorized repo.act %ci-policy ~ actor.act)
      ==
    ?:  ?=(%| -.changed)  ~|(p.changed !!)
    =.  state  p.changed
    =^  restores  state
      %+  bump-generation
        repo.act
      'automatic input allowlist changed; in-flight effects may already have occurred'
    =.  audit
      (record-audit actor.act 'set-automatic-inputs' repo.act (scope:ci-input sources.act))
    (emit restores)
  ::
      %set-network-policy
    =+  (require-authority repo.act %ci-policy ~ actor.act)
    ?:  |(=('' workflow.act) =('' job.act) =('' profile.act))
      ~|('workflow, job and profile are required' !!)
    ?:  =('locked' profile.act)  ~|('locked is the default; clear the policy instead' !!)
    ?~  destinations.act  ~|('a network policy names at least one destination' !!)
    ?.  (levy `(list @t)`destinations.act destination-valid:ci-provenance)
      ~|('destinations are tcp|udp:<IP literal or DNS name>:<port>' !!)
    =/  current=(list network-policy:ci)  (~(gut by network-policies) repo.act ~)
    =/  rest=(list network-policy:ci)
      (skip current |=(n=network-policy:ci &(=(workflow.n workflow.act) =(job.n job.act))))
    =.  network-policies
      %+  ~(put by network-policies)
        repo.act
      [[workflow.act job.act profile.act destinations.act environment.act actor.act now.bowl] rest]
    =^  restores  state
      %+  bump-generation
        repo.act
      (rap 3 ~['network policy for ' workflow.act '/' job.act])
    =.  audit
      %:  record-audit
        actor.act
        'set-network-policy'
        repo.act
        %+  rap
          3
        ~[workflow.act '/' job.act ' → ' profile.act ' [' (join:ci-plan destinations.act ', ') ']']
      ==
    (emit restores)
  ::
      %clear-network-policy
    =+  (require-authority repo.act %ci-policy ~ actor.act)
    =/  current=(list network-policy:ci)  (~(gut by network-policies) repo.act ~)
    =.  network-policies
      %+  ~(put by network-policies)  repo.act
      (skip current |=(n=network-policy:ci &(=(workflow.n workflow.act) =(job.n job.act))))
    =^  restores  state
      %+  bump-generation
        repo.act
      (rap 3 ~['network policy cleared for ' workflow.act '/' job.act])
    =.  audit
      %:  record-audit
        actor.act
        'clear-network-policy'
        repo.act
        (rap 3 ~[workflow.act '/' job.act])
      ==
    (emit restores)
  ::
      ::  a shadow run (D7): a candidate that lands nothing, for one
      ::  external event, so the two systems can be compared on the same
      ::  source
      ::
      %stage-shadow
    ?:  ci-paused  ~|(paused-refusal:ci-checkpoint !!)
    =+  (require-authority repo.act %ci-policy ~ actor.act)
    =.  incarnations  (ensure-incarnation repo.act)
    =/  id=candidate-id:ci
      %-  sham
      [repo.act ref.act head.act base.act %shadow event.act external.act]
    ?:  (~(has by candidates) id)  ~|('that shadow is already staged' !!)
    =/  c=candidate:ci
      %:  fresh-candidate
        id
        repo.act
        ref.act
        head.act
        base.act
        actor.act
        %session
        %trusted
        ~
        %shadow
        ~
      ==
    =.  candidates  (~(put by candidates) id c)
    =/  sid=@uv  (sham [%ci-shadow id])
    =.  shadows  (~(put by shadows) sid [sid id repo.act ref.act event.act external.act now.bowl])
    =.  audit
      %:  record-audit
        actor.act
        'stage-shadow'
        repo.act
        (rap 3 ~[(scot %uv sid) ' ' event.act ' ' external.act])
      ==
    %-  emit
    :_  ~
    %+  urgit-poke  /materialize/(scot %uv id)
    [%materialize-candidate repo.act ref.act head.act base.act]
  ::
      ::  a comparison (D7): agreement only on the same object, the same
      ::  event, complete evidence and equal verdicts per job
      ::
      %compare-shadow
    =/  sh=(unit shadow:ci)  (~(get by shadows) shadow.act)
    ?~  sh  ~|('no such shadow' !!)
    =+  (require-authority repo.u.sh %ci-policy ~ actor.act)
    =/  c=(unit candidate:ci)  (~(get by candidates) candidate.u.sh)
    ?~  c  ~|('the shadow\'s candidate is gone' !!)
    =/  cid=@uv  (sham [%ci-comparison shadow.act now.bowl])
    =/  native=@t  status.u.c
    =/  verdict=[agreement=? reason=@t]
      ?~  candidate.u.c  [%.n 'shadow candidate was never materialized']
      ?.  =(u.candidate.u.c oid.act)
        [%.n (rap 3 ~['object differs: native ' (oid-text:git-codec u.candidate.u.c) ', external ' (oid-text:git-codec oid.act)])]
      ?.  =(event.u.sh event.act)
        [%.n (rap 3 ~['event differs: native ' event.u.sh ', external ' event.act])]
      ::  a cancelled run is a conclusion, as on GitHub (CI-CONCURRENCY-1)
      ?.  ?=(?(%passed %failed %cancelled) status.u.c)
        [%.n (rap 3 ~['native evidence incomplete: ' status.u.c])]
      ?~  plan.u.c  [%.n 'native run has no plan']
      ?.  =(native verdict.act)
        [%.n (rap 3 ~['verdicts differ: native ' native ', external ' verdict.act])]
      =/  known  (standings u.c)
      =/  mismatch=(unit @t)
        %+  find-first:ci-plan  (turn jobs.act |=([w=@t j=@t st=@t] (rap 3 ~[w '/' j '=' st])))
        |=  entry=@t
        =/  hit=(unit [workflow=@t job=@t status=@t])
          (find-job-entry jobs.act entry)
        ?~  hit  %.y
        =/  st=standing:ci-plan  (~(gut by standings.known) [workflow.u.hit job.u.hit] %pending)
        !=(`@t`st status.u.hit)
      ?^  mismatch  [%.n (rap 3 ~['job verdict differs or is missing natively: ' u.mismatch])]
      ?.  =((lent jobs.act) (lent u.plan.u.c))  [%.n 'job sets differ in size']
      [%.y 'same object, event, inputs and verdicts']
    =.  comparisons
      %+  ~(put by comparisons)
        cid
      [cid shadow.act now.bowl agreement.verdict reason.verdict verdict.act native]
    =.  audit
      %:  record-audit
        actor.act
        'compare-shadow'
        repo.u.sh
        %+  rap
          3
        ~[(scot %uv shadow.act) ': ' ?:(agreement.verdict 'agreement' 'mismatch') ' — ' reason.verdict]
      ==
    (emit ~)
  ::
      ::  the operator cancels a running attempt (rider 02): closed here,
      ::  the daemon told at its next event; a privileged one closes unknown
      ::
      %cancel-attempt
    =/  found=(unit attempt:ci)  (~(get by attempts) id.act)
    ?~  found  ~|('no such attempt' !!)
    =+  (require-authority (candidate-repo candidate.u.found) %ci-policy ~ actor.act)
    ?.  =(%running status.u.found)  ~|('attempt is not running' !!)
    =.  state
      ?:  ?=(^ approval.u.found)
        %+  close-unknown
          u.found
        %+  rap
          3
        ~['cancelled while a privileged job ran; the external side effect may have happened: needs review (' reason.act ')']
      (close-attempt u.found [%infrastructure-error (rap 3 ~['cancelled: ' reason.act])])
    =.  attempts
      =/  a=attempt:ci  (~(got by attempts) id.act)
      (~(put by attempts) id.act a(status ?:(?=(^ approval.a) status.a %cancelled)))
    =.  audit
      %:  record-audit
        actor.act
        'cancel-attempt'
        (candidate-repo candidate.u.found)
        (rap 3 ~[(scot %uv id.act) ': ' reason.act])
      ==
    (after-close candidate.u.found)
  ::
      ::  CI-CONCURRENCY-1: an operator cancels a run, or one workflow of
      ::  it, by the path a concurrency group cancels by: the cancellation
      ::  is recorded, every running attempt that does not keep running
      ::  under cancelled() closes (the daemon hears `attempt is closed`), a
      ::  privileged one closes unknown and needs review, and no other
      ::  workflow's job is touched.  the ci-policy role's, the owner's
      ::  implicitly; anyone else is refused
      ::
      %cancel-run
    =/  found=(unit candidate:ci)  (~(get by candidates) id.act)
    ?~  found  ~|('no such run' !!)
    =+  (require-authority repo.u.found %ci-policy ~ actor.act)
    ?:  (resolver-record u.found)
      ~|('a dependency resolution is not a run: there is nothing to cancel' !!)
    ?.  =(%pending status.u.found)
      ~|('the run has finished: nothing is left to cancel' !!)
    ?:  (~(has by cancelled.u.found) '')
      ~|('the run is cancelled already' !!)
    =/  why=@t  ?:(=('' reason.act) 'cancelled from the CI tab' reason.act)
    =/  reason=@t  (rap 3 ~['cancelled by ' (scot %p actor.act) ': ' why])
    =/  cause=cancel-cause:ci  [%operator actor.act]
    =/  known=(list @t)  (run-workflows:ci-concurrency u.found)
    =/  open=(list @t)
      %+  skip  known
      |=(w=@t (workflow-finished:ci-concurrency state u.found w))
    =.  state
      ?~  workflow.act
        ?:  ?&(?=(^ plan.u.found) ?=(~ open))
          ~|('every workflow of the run has finished: nothing is left to cancel' !!)
        (cancel-whole-run:ci-concurrency state id.act cause reason now.bowl)
      ?.  (lien known |=(w=@t =(w u.workflow.act)))
        ~|(`@t`(rap 3 ~['the run has no workflow ' u.workflow.act]) !!)
      ?:  (workflow-cancelled:ci-concurrency u.found u.workflow.act)
        ~|('that workflow\'s run is cancelled already' !!)
      ?.  (lien open |=(w=@t =(w u.workflow.act)))
        ~|('that workflow\'s run has finished: nothing is left to cancel' !!)
      (cancel-workflows:ci-concurrency state id.act ~[u.workflow.act] cause reason now.bowl)
    =.  audit
      %:  record-audit
        actor.act
        'cancel-run'
        repo.u.found
        %+  rap  3
        :~  (scot %uv id.act)
            ?~(workflow.act ' (the whole run)' (rap 3 ~[' ' u.workflow.act]))
            ': '
            why
        ==
      ==
    (after-close id.act)
  ::
      ::  a delegate's request from another ship (rider 02): the JSON is
      ::  the operator surface's, the actor is the requester, and only the
      ::  delegable actions pass — roles are bound by the owner's session,
      ::  candidates are approved through P3's own packet, and daemons,
      ::  credentials and keys are never delegated.  the body must name
      ::  the repository the request was addressed to.
      ::
      %delegated
    =/  jon=(unit json)  (de:json:html body.act)
    ?~  jon  ~|('the delegated request is not JSON' !!)
    ?.  =(`repo.act (string-at 'repo' u.jon))
      ~|('the delegated request names another repository than it was addressed to' !!)
    =/  parsed=(each action:ci @t)  (parse-web-action u.jon actor.act)
    ?:  ?=(%| -.parsed)  ~|(p.parsed !!)
    ?.  ?=  $?  %resolve-dependencies  %promote-baseline  %revoke-baseline
                %set-harness-paths  %set-sandbox-requirement
                %set-environment  %delete-environment  %approve-environment
                %record-override  %set-network-policy  %clear-network-policy
                %set-automatic-inputs
                %stage-shadow  %compare-shadow  %cancel-attempt  %cancel-run
            ==
        -.p.parsed
      ~|  `@t`(rap 3 ~[-.p.parsed ' is not a delegable action'])
      !!
    =.  audit
      %:  record-audit
        actor.act
        'delegated'
        repo.act
        (rap 3 ~[-.p.parsed ' requested from ' (scot %p actor.act)])
      ==
    (handle-action p.parsed)
  ::
      ::  the owner's release of a legacy retention (legacy-recovery UI
      ::  ruling 01; INTEGRATION.md §11.12): a command bound to exactly
      ::  the entry, revision and evidence digest the runner's latest
      ::  report shows as releasable, recorded, handed over on its poll,
      ::  checked again and carried out by the runner, which answers.  one
      ::  open command per entry: a repeated request while one is open is
      ::  that one.  never delegable.
      ::
      %request-legacy-release
    ?.  =(our.bowl actor.act)
      ~|('only the ship\'s owner releases a runner\'s retention' !!)
    =/  found=(unit daemon:ci)  (~(get by daemons) id.act)
    ?~  found  ~|('no such runner' !!)
    ?~  enrolled.u.found  ~|('the runner is not enrolled' !!)
    ?^  revoked.u.found  ~|('the runner is revoked' !!)
    =/  report=(unit recovery-report:ci)  (~(get by recovery-reports) id.act)
    ?~  report  ~|('the runner has not reported its retentions' !!)
    =/  hits=(list recovery-entry:ci)
      (skim entries.u.report |=(e=recovery-entry:ci =(selection.e selection.act)))
    ?~  hits
      ~|('the runner\'s latest report does not show this retention: inspect it again' !!)
    =/  entry=recovery-entry:ci  i.hits
    ?.  =(revision.entry revision.act)
      ~|('the retention changed since it was inspected: inspect it again' !!)
    ?.  =('legacy' kind.entry)
      ~|('the retention is not a legacy retention' !!)
    ?.  eligible.entry
      ~|('the runner\'s latest report does not show this retention as releasable' !!)
    ?.  =(evidence.entry evidence.act)
      ~|('the evidence changed since it was inspected: inspect it again' !!)
    =.  recovery-commands
      %-  ~(run by recovery-commands)
      |=(c=recovery-command:ci (expire-command:ci-recovery c now.bowl))
    =/  waiting=(list recovery-command:ci)
      %+  skim  ~(val by recovery-commands)
      |=  c=recovery-command:ci
      ?&  =(id.act daemon.c)
          =(selection.act selection.c)
          (open-command:ci-recovery c)
      ==
    ?^  waiting  (emit ~)
    =/  id=@uv  (sham [%ci-recovery id.act selection.act revision.act eny.bowl now.bowl])
    =/  command=recovery-command:ci
      :*  id  id.act  release-legacy:ci-recovery  selection.act  revision.act  evidence.act
          label.entry  actor.act  now.bowl  (add now.bowl authorization-lifetime:ci-provenance)
          (fresh-nonce [%recovery id])  ~  0  %queued  ''  ~
      ==
    =.  recovery-commands  (~(put by recovery-commands) id command)
    =.  audit
      %:  record-audit
        actor.act
        'legacy-release-requested'
        ''
        %+  rap
          3
        ~[(scot %uv id) ' on runner ' (scot %uv id.act) ': ' label.entry ' (' selection.act ')']
      ==
    (emit ~)
  ::
      ::  the owner's transition of a runner whose execution history is
      ::  incomplete (legacy-replay-upgrade ruling 01; INTEGRATION.md
      ::  §11.15): a command bound to exactly the history, revision and
      ::  evidence digest the runner's latest report shows waiting, naming
      ::  the next authorization epoch; recorded, handed over on its poll,
      ::  checked again and carried out by the runner, which answers.  from
      ::  this request on, every assignment the ship creates for the runner
      ::  is signed with that epoch (epoch-at, epoch-nonce).  one open
      ::  transition per runner.  never delegable.
      ::
      %request-history-transition
    ?.  =(our.bowl actor.act)
      ~|('only the ship\'s owner confirms a runner\'s history transition' !!)
    =/  found=(unit daemon:ci)  (~(get by daemons) id.act)
    ?~  found  ~|('no such runner' !!)
    ?~  enrolled.u.found  ~|('the runner is not enrolled' !!)
    ?^  revoked.u.found  ~|('the runner is revoked' !!)
    =/  report=(unit recovery-report:ci)  (~(get by recovery-reports) id.act)
    ?~  report  ~|('the runner has not reported its history' !!)
    =/  history=(unit recovery-entry:ci)
      =/  jon=(unit json)  (de:json:html body.u.report)
      ?~(jon ~ (history-entry:ci-recovery u.jon))
    ?~  history
      ~|('the runner\'s latest report shows no execution history' !!)
    ?.  =(revision.u.history revision.act)
      ~|('the runner\'s history changed since it was inspected: inspect it again' !!)
    ?.  eligible.u.history
      ~|('the runner\'s latest report does not show its history waiting for a transition' !!)
    ?.  =(evidence.u.history evidence.act)
      ~|('the history evidence changed since it was inspected: inspect it again' !!)
    =.  recovery-commands
      %-  ~(run by recovery-commands)
      |=(c=recovery-command:ci (expire-command:ci-recovery c now.bowl))
    =/  waiting=(list recovery-command:ci)
      %+  skim  ~(val by recovery-commands)
      |=  c=recovery-command:ci
      ?&  =(id.act daemon.c)
          =(confirm-history:ci-recovery operation.c)
          (open-command:ci-recovery c)
      ==
    ?^  waiting  (emit ~)
    =/  epoch=@ud  +((epoch-at:ci-recovery ~(val by recovery-commands) id.act now.bowl))
    =/  id=@uv  (sham [%ci-history id.act revision.act eny.bowl now.bowl])
    =/  command=recovery-command:ci
      :*  id  id.act  confirm-history:ci-recovery  selection.u.history  revision.act
          (transition-evidence:ci-recovery epoch evidence.act)
          'execution history transition'  actor.act  now.bowl
          %+  add
            now.bowl
          authorization-lifetime:ci-provenance
          (fresh-nonce [%recovery id])  ~  0  %queued  ''  ~
      ==
    =.  recovery-commands  (~(put by recovery-commands) id command)
    =.  audit
      %:  record-audit
        actor.act
        'history-transition-requested'
        ''
        %+  rap
          3
        ~[(scot %uv id) ' on runner ' (scot %uv id.act) ': epoch ' (crip (a-co:co epoch)) ' (' selection.u.history ')']
      ==
    (emit ~)
  ::
      ::  a manual run (Delivery 1A): one workflow that declares
      ::  workflow_dispatch at the ref's promoted baseline, run on the
      ::  ref's tip with its typed inputs admitted against the declaration
      ::  the baseline's lock lists.  the run is a candidate of mode
      ::  %manual — trusted, never landable, planned and scheduled like a
      ::  trial — whose trigger every attempt's signed manifest binds.  the
      ::  same request is the same run.  the authority is the ci-policy
      ::  role's, the actor the session's ship (or the dojo's), never JSON.
      ::
      %dispatch-workflow
    ::  CI-RECOVERY-1: no run is admitted while CI is paused
    ?:  ci-paused  ~|(paused-refusal:ci-checkpoint !!)
    =+  (require-authority repo.act %ci-policy ~ actor.act)
    =/  admitted  (admit-dispatch act)
    ?:  ?=(%| -.admitted)  ~|(reason.p.admitted !!)
    ?.  fresh.p.admitted  (emit ~)
    =/  run=candidate:ci  run.p.admitted
    =.  candidates  (~(put by candidates) id.run run)
    =.  audit
      %:  record-audit
        actor.act
        'dispatch-workflow'
        repo.act
        %+  rap  3
        :~  workflow.act  ' on '  ref.act  ' at '  (oid-text:git-codec tip.act)
            ' (run '  (scot %uv id.run)  ')'
        ==
      ==
    ::  the source stays reachable for the runner under the run's own
    ::  scratch ref, set before the plan attempt is handed out
    ::
    =/  keep=card
      %+  urgit-git-poke  /scratch/(scot %uv id.run)
      [%set-ref repo.act (scratch-ref run) tip.act]
    =/  scheduled=out  schedule
    [[keep cards.scheduled] state.scheduled polls.scheduled]
::
    ::  what one of %urgit's events persisted (Delivery 1C; lib/ci-forge):
    ::  each ref move and pull request transition is verified against
    ::  %urgit's state, recorded, and selected against the governing
    ::  catalog; a default-branch change registers the schedules again.
    ::  the poke is local (src=our) and never a web or delegated action
    ::
    %forge-events  (admit-forge-events act)
  ::
      %materialize-run
    ~|  '%materialize-run is a poke on %urgit, not %urgit-ci'
    !!
::
    %run-ready  (run-ready id.act candidate.act)
    %run-conflict  (run-conflict id.act reason.act)
  ::
      ::  CI-RECOVERY-1 (R5.2-A): the owner's recovery actions.  none is
      ::  delegable, and the actor is the session's ship.  only Checkpoint
      ::  now sends a card, the checkpoint's own write.  pause, resume,
      ::  import, discard and apply send none, so none of them can start a
      ::  run, a schedule wake or a webhook
      ::
      %checkpoint-now
    ?.  =(our.bowl actor.act)  ~|(owner-refusal !!)
    =.  audit  (record-audit actor.act 'checkpoint-requested' '' 'checkpoint now')
    (write-checkpoint 'operator: checkpoint now' actor.act)
  ::
      %pause-ci
    ?.  =(our.bowl actor.act)  ~|(owner-refusal !!)
    =/  problem=(unit @t)  (pause-refusal:ci-checkpoint state)
    ?^  problem  ~|(u.problem !!)
    =/  why=@t  ?:(=('' reason.act) 'paused for a restore' reason.act)
    =.  paused.recovery  `[now.bowl actor.act why]
    =.  audit  (record-audit actor.act 'ci-paused' '' why)
    [~ state polls]
  ::
      %resume-ci
    ?.  =(our.bowl actor.act)  ~|(owner-refusal !!)
    =/  problem=(unit @t)  (resume-refusal:ci-checkpoint state)
    ?^  problem  ~|(u.problem !!)
    =.  paused.recovery  ~
    =.  audit
      (record-audit actor.act 'ci-resumed' '' 'CI resumed: resuming ran nothing and landed nothing')
    [~ state polls]
  ::
      ::  a checkpoint read from the checkpoint repository, at its default
      ::  branch's tip or at the named commit, checked whole and staged.
      ::  a refusal changes nothing
      ::
      %import-checkpoint
    ?.  =(our.bowl actor.act)  ~|(owner-refusal !!)
    =/  problem=(unit @t)  (import-refusal:ci-checkpoint state)
    ?^  problem  ~|(u.problem !!)
    =/  repo=@t  repository:ci-checkpoint
    =/  info=(unit (unit recovery-repo:ci))  (checkpoint-repo-info repo)
    ?~  info
      ~|('%urgit cannot be read, so the checkpoint repository cannot be read' !!)
    ?~  u.info
      ~|('this ship has no repository ci-checkpoints: push the replica into it first' !!)
    =/  at=(unit oid:git)  ?^(commit.act commit.act tip.u.u.info)
    ?~  at
      ~|('the checkpoint repository has no commit on its default branch: push the replica into it first' !!)
    =/  names=(list @t)
      :-  manifest-file:ci-checkpoint
      (turn sections:ci-checkpoint |=([* file=@t *] file))
    =/  found=(list [@t octs])
      %+  murn  names
      |=  file=@t
      ^-  (unit [@t octs])
      =/  data=(unit octs)
        (file-at repo u.at (rap 3 ~[directory:ci-checkpoint '/' file]))
      ?~  data  ~
      `[file u.data]
    =/  read=(each [manifest=checkpoint-manifest:ci content=checkpoint-content:ci] @t)
      (import:ci-checkpoint (malt found))
    ?:  ?=(%| -.read)  ~|(p.read !!)
    =/  staged=staged-checkpoint:ci
      [u.at now.bowl actor.act manifest.p.read content.p.read]
    =.  staged.recovery  `staged
    =.  audit
      %:  record-audit  actor.act  'checkpoint-imported'  ''
        (rap 3 ~[id.manifest.p.read ' from commit ' (oid-text:git-codec u.at)])
      ==
    [~ state polls]
  ::
      %discard-checkpoint
    ?.  =(our.bowl actor.act)  ~|(owner-refusal !!)
    =/  waiting=(unit staged-checkpoint:ci)  staged.recovery
    ?~  waiting  ~|('no checkpoint is staged' !!)
    =.  staged.recovery  ~
    =.  audit
      (record-audit actor.act 'checkpoint-discarded' '' id.manifest.u.waiting)
    [~ state polls]
  ::
      ::  the staged checkpoint applied, named by the id the operator
      ::  reviewed, while CI is paused and no attempt runs.  the ship's
      ::  refs and revisions are read first, so a CI-protected ref with no
      ::  tip and a baseline whose revision is missing are skipped
      ::
      %apply-checkpoint
    ?.  =(our.bowl actor.act)  ~|(owner-refusal !!)
    =/  problem=(unit @t)  (apply-refusal:ci-checkpoint state id.act)
    ?^  problem  ~|(u.problem !!)
    =/  waiting=(unit staged-checkpoint:ci)  staged.recovery
    ?~  waiting  ~|('no checkpoint is staged' !!)
    =/  content=checkpoint-content:ci  content.u.waiting
    =/  tips=(list [repo=@t ref=@t])
      %+  skim  (wanted-tips:ci-checkpoint content)
      |=  [repo=@t ref=@t]
      =/  tip=(unit (unit [tip=oid:git linked=?]))  (ref-tip repo ref)
      ?&(?=(^ tip) ?=(^ u.tip))
    =/  revisions=(list [repo=@t revision=oid:git])
      %+  skim  (wanted-revisions:ci-checkpoint content)
      |=  [repo=@t revision=oid:git]
      =/  found=(each oid:git @t)  (tag-commit repo revision)
      ?=(%& -.found)
    =/  here=presence:ci-checkpoint  [(silt tips) (silt revisions)]
    =/  done=[s=state-0:ci =restore:ci]
      (apply:ci-checkpoint state here actor.act now.bowl eny.bowl)
    =.  state  s.done
    =.  audit
      %:  record-audit  actor.act  'checkpoint-applied'  ''
        %+  rap  3
        :~  id.restore.done  ': '
            (crip (a-co:co (lent repos.restore.done)))  ' repositories restored, '
            (crip (a-co:co (lent skipped.restore.done)))  ' items skipped, '
            (crip (a-co:co (lent cancelled.restore.done)))  ' open runs cancelled'
        ==
      ==
    [~ state polls]
  ::
      ::  %urgit's answer to a replica push (local only): each checkpoint
      ::  the push carried is confirmed only on the replica's acceptance
      ::
      %replica-result
    =.  checkpoints.recovery
      %:  push-answered:ci-checkpoint
        checkpoints.recovery  ticket.act  ok.act  message.act  now.bowl
      ==
    start-push
  ==
::
::  the manual-run inventory of one ref (Delivery 1A): the workflows that
::  declare workflow_dispatch at its promoted baseline, as the baseline's
::  lock lists them, or why the ref offers none.  the inventory is what
::  the resolver's pinned compiler read at the revision the CI-policy
::  authority promoted: never a second catalog, never the tip's own YAML
::
++  ref-inventory
  |=  [repo=@t ref=@t]
  ^-  (each [=baseline:ci workflows=(list dispatch-workflow:ci)] @t)
  =/  base=(unit baseline:ci)  (~(get by baselines) [repo ref])
  ?~  base
    :-  %|
    %+  rap  3
    :~  'no promoted baseline for '  ref
        ': promote a harness revision (Settings → CI policy) to run its workflows'
    ==
  ?~  lock.u.base
    [%| (rap 3 ~['the promoted baseline of ' ref ' has no workflows'])]
  =/  found=(unit lock:ci)  (~(get by locks) u.lock.u.base)
  ?~  found
    [%| 'the baseline\'s lock is not on this ship: resolve and promote the revision again']
  ?~  inventory.u.found
    :-  %|
    %+  rap  3
    :~  'the baseline\'s lock was resolved before manual runs were listed: '
        'resolve and promote its revision again to list its manual workflows'
    ==
  [%& u.base u.inventory.u.found]
::
::  the environments of a repository, by name: what an environment input
::  may name.  naming one releases none of its credentials
::
++  environment-names
  |=  repo=@t
  ^-  (set @t)
  %-  silt
  %+  murn  ~(tap by environments)
  |=([[r=@t name=@t] *] ?.(=(r repo) ~ `name))
::
::  a manual run's id: the repository, the actor and the operator's
::  request, so a repeated request is the same run
::
++  dispatch-id
  |=  [repo=@t actor=@p request=@t]
  ^-  candidate-id:ci
  (sham [%ci-dispatch repo actor request])
::
::  what a manual run's admission decides (Delivery 1A), as the route
::  answers it: the run to record (or the one this request recorded
::  before), else a status, the reason and any refused fields.  the
::  operator's view is bound: the tip and the policy generation the form
::  was loaded at must be the ref's and the repository's now.  every
::  input is admitted against the declaration the baseline's lock lists.
::
++  admit-dispatch
  |=  act=action:ci
  ^-  (each [run=candidate:ci fresh=?] [status=@ud reason=@t fields=(list [@t @t])])
  ?>  ?=(%dispatch-workflow -.act)
  =/  bad
    |=  reason=@t
    ^-  (each [run=candidate:ci fresh=?] [status=@ud reason=@t fields=(list [@t @t])])
    [%| 409 reason ~]
  ?.  (request-valid:ci-dispatch request.act)
    [%| 400 'request is 1 to 64 letters, digits, dots, dashes and underscores' ~]
  =/  id=candidate-id:ci  (dispatch-id repo.act actor.act request.act)
  =/  existing=(unit candidate:ci)  (~(get by candidates) id)
  ?^  existing
    ?:  (same-dispatch u.existing act)  [%& u.existing %.n]
    (bad (rap 3 ~['request ' request.act ' was already used for another dispatch']))
  =/  inventory=(each [=baseline:ci workflows=(list dispatch-workflow:ci)] @t)
    (ref-inventory repo.act ref.act)
  ?:  ?=(%| -.inventory)  (bad p.inventory)
  =/  tip=(unit (unit [tip=oid:git linked=?]))  (ref-tip repo.act ref.act)
  ?~  tip  (bad 'ci: %urgit cannot be read; the ref cannot be checked')
  ?~  u.tip  (bad (rap 3 ~[ref.act ' has no tip']))
  ?.  =(tip.u.u.tip tip.act)
    %-  bad
    %+  rap  3
    :~  ref.act  ' moved since the form was loaded: its tip is now '
        (oid-text:git-codec tip.u.u.tip)  '; reload and dispatch again'
    ==
  ?.  =(generation.act (current-generation repo.act))
    %-  bad
    %+  rap  3
    :~  'the CI policy of '  repo.act  ' changed since the form was loaded (generation '
        (crip (a-co:co generation.act))  ', now '  (crip (a-co:co (current-generation repo.act)))
        '): reload the workflow\'s inputs and dispatch again'
    ==
  =/  hits=(list dispatch-workflow:ci)
    (skim workflows.p.inventory |=(w=dispatch-workflow:ci =(workflow.w workflow.act)))
  ?~  hits
    %-  bad
    %+  rap  3
    :~  'workflow '
        workflow.act
        ' does not declare workflow_dispatch at the baseline revision of '
        ref.act
    ==
  ?^  refusal.i.hits
    (bad (rap 3 ~['workflow ' workflow.act ' cannot be run manually: ' u.refusal.i.hits]))
  =/  admitted
    %:  admit:ci-dispatch
      inputs.i.hits
      inputs.act
      (environment-names repo.act)
      (credential-values repo.act)
    ==
  ?:  ?=(%| -.admitted)
    [%| 422 (refused-inputs p.admitted) p.admitted]
  =/  payload=@t  (payload:ci-dispatch ref.act workflow.act actor.act p.admitted)
  =/  run=candidate:ci
    %:  fresh-candidate
      id  repo.act  ref.act  tip.act  tip.act  actor.act  %session  %trusted  ~  %manual  ~
    ==
  :+  %&
    %=  run
      candidate  `tip.act
      trigger  [%dispatch workflow.act name.i.hits p.admitted payload request.act]
    ==
  %.y
::
::  whether a recorded run is what this request asks again: the same ref,
::  source, workflow and supplied values
::
++  same-dispatch
  |=  [run=candidate:ci act=action:ci]
  ^-  ?
  ?>  ?=(%dispatch-workflow -.act)
  ?.  ?=(%dispatch -.trigger.run)  %.n
  =/  supplied=(map @t input-value:ci)
    %-  malt
    %+  murn  inputs.trigger.run
    |=  i=admitted-input:ci
    ^-  (unit [@t input-value:ci])
    ?.  ?=(%supplied source.i)  ~
    ?~  value.i  ~
    `[id.i u.value.i]
  ?&  =(ref.run ref.act)
      =(head.run tip.act)
      =(workflow.trigger.run workflow.act)
      =(supplied (malt inputs.act))
  ==
::
::  the 422's reason: every refused input, in the order admission found
::  them
::
++  refused-inputs
  |=  fields=(list [field=@t reason=@t])
  ^-  @t
  =/  texts=(list @t)
    %+  turn  fields
    |=([field=@t reason=@t] ?:(=('' field) reason (rap 3 ~[field ' ' reason])))
  =/  count=@ud  (lent fields)
  %+  rap  3
  :~  (crip (a-co:co count))
      ?:(=(1 count) ' input refused: ' ' inputs refused: ')
      (join:ci-plan texts '; ')
  ==
::
::  a fresh candidate record with its P4 bindings taken from the current
::  policy: the generation, the baseline and lock of its ref, the
::  incarnation; the sandbox is computed from what it is
::
++  fresh-candidate
  |=  $:  id=candidate-id:ci  repo=@t  ref=@t  head=oid:git  base=oid:git
          actor=@p  =via:ci  =trust:ci  pull=(unit @ud)  =mode:ci  trial-of=(unit candidate-id:ci)
      ==
  ^-  candidate:ci
  =/  promoted=(unit baseline:ci)  (~(get by baselines) [repo ref])
  =/  c=candidate:ci
    :*  id  repo  ref  head  base
        ~  %.n  %pending  ~  ~  ~  ~  actor  via  trust  pull
        now.bowl  now.bowl
        mode  (current-generation repo)
        ?~(promoted ~ `revision.u.promoted)
        ?~(promoted ~ lock.u.promoted)
        (current-incarnation repo)
        %vm  trial-of  %.n  [%push ~]  ~
        [%pending ~]  ~
    ==
  ::  CI-CONCURRENCY-1: a new run joins its groups once it is materialized,
  ::  unless by rule it takes part in none (a trial, a resolver record)
  c(sandbox (sandbox-for c %.n), concurrency (initial:ci-concurrency c))
::
::  the scratch ref a promoted baseline stays reachable under
::
++  baseline-ref
  |=  [repo=@t ref=@t]
  ^-  @t
  (rap 3 ~['refs/ci/baseline/' (scot %uv (sham [repo ref]))])
::
::  the owner check for delegating ci-policy: ~ when the actor is the
::  owner, else the reason
::
++  repo-owner-or-fail
  |=  [repo=@t actor=@p]
  ^-  (unit @t)
  =/  owner=(unit @p)  (repo-owner repo)
  ?:  ?&(?=(^ owner) =(u.owner actor))  ~
  `'not the owner'
::
++  find-job-entry
  |=  [jobs=(list [workflow=@t job=@t status=@t]) entry=@t]
  ^-  (unit [workflow=@t job=@t status=@t])
  |-
  ?~  jobs  ~
  ?:  =(entry (rap 3 ~[workflow.i.jobs '/' job.i.jobs '=' status.i.jobs]))  `i.jobs
  $(jobs t.jobs)
::
::  whether the candidate's harness paths differ from the baseline's:
::  every file under each path at both objects, byte for byte, through
::  %urgit's tree and file peeks (an unreadable side counts as different,
::  so a required run never silently assumes equality)
::
++  harness-differs
  |=  [repo=@t candidate=oid:git baseline=oid:git paths=(list @t)]
  ^-  ?
  ?:  =(candidate baseline)  %.n
  %+  lien  paths
  |=  p=@t
  =/  under=@t  (rap 3 ~[(strip-slash p)])
  =/  a=(unit (list path))  (tree-at repo candidate under)
  =/  b=(unit (list path))  (tree-at repo baseline under)
  ?~  a  %.y
  ?~  b  %.y
  ::  a file path (not a directory) lists as a single empty path at
  ::  either side when it exists as a file: tree-at lists entries UNDER
  ::  the prefix; compare the file bytes directly then
  =/  files-a=(set path)  (silt u.a)
  =/  files-b=(set path)  (silt u.b)
  ?.  =(files-a files-b)  %.y
  %+  lien  ~(tap in files-a)
  |=  sub=path
  =/  full=@t
    ?~  sub  under
    (rap 3 ~[under '/' (join:ci-plan (turn sub |=(s=@ta `@t`s)) '/')])
  =/  fa=(unit octs)  (file-at repo candidate full)
  =/  fb=(unit octs)  (file-at repo baseline full)
  ?~  fa  %.y
  ?~  fb  %.y
  !=(u.fa u.fb)
::
++  strip-slash
  |=  p=@t
  ^-  @t
  =/  chars=tape  (trip p)
  =.  chars  ?:(&(?=(^ chars) =('/' i.chars)) t.chars chars)
  =.  chars  (flop chars)
  =.  chars  ?:(&(?=(^ chars) =('/' i.chars)) t.chars chars)
  (crip (flop chars))
::
::  a resolver-capable live daemon (rider 03: imports may fetch): one
::  with a free slot first, else any — a busy resolver takes the resolve
::  at its next poll (its slots poll only when free), which beats
::  refusing an explicit import because the runner is momentarily full
::
++  select-resolver
  |=  repo=@t
  ^-  (unit daemon-id:ci)
  (select-resolver-excluding repo ~)
::
++  select-resolver-excluding
  |=  [repo=@t exclude=(set daemon-id:ci)]
  ^-  (unit daemon-id:ci)
  (choose:ci-resolve daemons now.bowl stale-after repo exclude)
::
::  a privileged attempt whose outcome cannot be known closes unknown
::  (rider 02): never re-offered, visible as needs-review
::
++  close-unknown
  |=  [=attempt:ci reason=@t]
  ^-  _state
  =.  state  (close-attempt attempt [%infrastructure-error reason])
  =/  closed=attempt:ci  (~(got by attempts) id.attempt)
  =.  attempts  (~(put by attempts) id.attempt closed(outcome %unknown))
  state
::
::  the candidates a repository has, by name (every status)
::
++  repository-candidates
  |=  repo=@t
  ^-  (set candidate-id:ci)
  %-  silt
  %+  murn  ~(tap by candidates)
  |=([id=candidate-id:ci c=candidate:ci] ?:(=(repo repo.c) `id ~))
::
::  a new attempt and its assignment, undelivered, and the deadline timer
::  the caller emits.  the daemon's running set grows here and shrinks in
::  +close-attempt.
::
++  create-attempt
  |=  $:  candidate=candidate-id:ci
          daemon=daemon-id:ci
          =kind:ci
          workflow=(unit @t)
          job=(unit @t)
          deadline=@dr
          approval=(unit @uv)
      ==
  ^-  [[attempt-id:ci timer=card] _state]
  =/  found=candidate:ci  (~(got by candidates) candidate)
  =/  attempt-id=attempt-id:ci
    (sham [%ci-attempt candidate daemon kind workflow job now.bowl (lent attempts.found)])
  =/  assignment-id=assignment-id:ci  (sham [%ci-assignment attempt-id])
  ::  an attempt carries its candidate's trust class (D3): every key it
  ::  writes and every grant it may receive follow from it; and its
  ::  bindings (P4 D5): the generation, mode, sandbox, network and the
  ::  manifest digest the signed assignment carries
  ::
  =/  privileged=?  ?=(^ approval)
  =/  net=[profile=@t destinations=(list @t)]
    ?~(workflow ['locked' ~] ?~(job ['locked' ~] (network-of repo.found u.workflow u.job)))
  ::  a resolve is host-side parsing on a resolver (D4): it needs no
  ::  sandbox, so it carries the container need (satisfied by any runner)
  =/  need=sandbox-need:ci  ?:(?=(%resolve kind) %container (sandbox-for found privileged))
  ::  a job runs on its decision (CI-EXPR-2): why it runs, and the needs
  ::  context it is given — each need's accepted attempt, result and
  ::  published outputs — fixed here and bound by its signed manifest; an
  ::  operator's %assign of a job its plan would not run says so
  ::
  =/  decided=[decision=(unit decision:ci) needs=(list need-entry:ci)]
    ?.  ?=(%job kind)  [~ ~]
    =/  planned=(unit job:ci)  (planned-job found workflow job)
    ?~  planned  [`[%run 'assigned by hand: the job is not in the plan' ~] ~]
    =/  now  (job-decision found u.planned)
    :_  needs.now
    ?:  ?=(%run -.decision.now)  `[%run reason.decision.now value.decision.now]
    `[%run 'assigned by hand' ~]
  =/  =attempt:ci
    :*  attempt-id  candidate  assignment-id  daemon
        trust.found  kind  workflow  job  %running  0  ~  ~  ~  ~  ~  ~  now.bowl  ~
        generation.found  mode.found  0v0  need  profile.net  approval  %known  ~
        decision.decided  needs.decided  ~
    ==
  =/  =attempt:ci  attempt(manifest (manifest-id:ci-provenance (manifest-of found attempt)))
  =/  =assignment:ci
    :*  assignment-id  candidate  daemon  attempt-id
        trust.found  kind  workflow  job  deadline  now.bowl  ~
    ==
  ::  the approval is consumed here, at admission, atomically with the
  ::  attempt's creation (rider 02): a rerun needs a new one
  =?  approvals  ?=(^ approval)
    =/  a=(unit approval:ci)  (~(get by approvals) u.approval)
    ?~  a  approvals
    (~(put by approvals) u.approval u.a(consumed `attempt-id))
  ::  the read capability the daemon clones with (A06): the candidate's
  ::  repository and every mirror its lock names, until the deadline
  =.  read-capabilities
    %+  ~(put by read-capabilities)  (shas %ci-read-hash (read-token attempt-id))
    [attempt-id (~(put in (lock-mirrors lock.found)) repo.found) (add now.bowl (add deadline ~m2))]
  =.  attempts  (~(put by attempts) attempt-id attempt)
  =.  assignments  (~(put by assignments) assignment-id assignment)
  =.  candidates
    %+  ~(put by candidates)  candidate
    found(status %pending, attempts [attempt-id attempts.found], updated now.bowl)
  =.  daemons
    =/  runner=(unit daemon:ci)  (~(get by daemons) daemon)
    ?~  runner  daemons
    (~(put by daemons) daemon u.runner(running (~(put in running.u.runner) attempt-id)))
  =/  timer=card
    [%pass /deadline/(scot %uv attempt-id) %arvo %b %wait (add now.bowl deadline)]
  [[attempt-id timer] state]
::
::  the attempt-bound read capability (A06): derived from the CI signing
::  secret so it is unforgeable and recoverable at delivery without being
::  stored raw; presented to /git as basic auth; its hash is what state
::  and %urgit's peek see
::
++  read-token
  |=  attempt=attempt-id:ci
  ^-  @uv
  ?~  signing  0v0
  (end [3 32] (shas %ci-read-token (jam [attempt sek.u.signing])))
::
::  the mirror repositories a lock names
::
++  lock-mirrors
  |=  lock=(unit @ux)
  ^-  (set @t)
  ?~  lock  ~
  =/  found=(unit lock:ci)  (~(get by locks) u.lock)
  ?~  found  ~
  %-  silt
  %+  murn  nodes.u.found
  |=(n=dep-node:ci ?:(=('' mirror.n) ~ `mirror.n))
::
::  the execution manifest of an attempt (contract §5): every binding the
::  daemon must act within, as the noun the CI key signs
::
++  manifest-of
  |=  [c=candidate:ci a=attempt:ci]
  ^-  manifest:ci-provenance
  =/  net=[profile=@t destinations=(list @t)]
    ?~(workflow.a ['locked' ~] ?~(job.a ['locked' ~] (network-of repo.c u.workflow.a u.job.a)))
  =/  event=[name=@t payload=@t]  (run-event c a)
  :*  incarnation.c
      repo.c
      ref.c
      candidate.a
      (oid-hex:ci-provenance candidate.c)
      ?:(=(%trial mode.c) '' (oid-hex:ci-provenance baseline.c))
      ?:(=(%trial mode.c) '' (lock-hex:ci-provenance lock.c))
      generation.c
      (fall workflow.a '')
      (fall job.a '')
      trust.a
      ?-(sandbox.a %vm 'vm', %container 'container')
      ?-  kind.a
        %plan  'plan'
          %resolve
        ?-  (purpose:ci-resolve c)
          %import  'resolve'
          %tag  'resolve-tag'
          %invalid  'resolve-invalid'
        ==
        %job  `@t`mode.c
      ==
      profile.net
      ?:  &(=(%resolve kind.a) =(%tag (purpose:ci-resolve c)))
        ?:((~(has by input-snapshots) id.c) (scope:ci-input (captured:ci-input state id.c)) '')
      (scope-text:ci-provenance destinations.net)
      ::  the event the run is for (Delivery 1A) and its payload's digest;
      ::  a resolve runs none
      name.event
      ?:(=('' payload.event) '' (context-digest:ci-dispatch payload.event))
      ::  a job's needs context (Delivery 1B): the digest of the text its
      ::  expressions read, and the attempt each need was accepted from
      ?~(needs.a '' (context-digest:ci-dispatch (needs-text:ci-expr needs.a)))
      (prerequisites-text needs.a)
      ::  the event the run was admitted for (manifest version 5,
      ::  Delivery 1C); a resolve runs none
      ?:(?=(%resolve kind.a) '' (trigger-text:ci-trigger c))
  ==
::
::  `<job>=<attempt>` for each need, by job id, comma-joined
::
++  prerequisites-text
  |=  needs=(list need-entry:ci)
  ^-  @t
  =/  sorted=(list need-entry:ci)
    %+  sort
      needs
    |=([x=need-entry:ci y=need-entry:ci] (aor id.x id.y))
  (join:ci-plan (turn sorted |=(n=need-entry:ci (rap 3 ~[id.n '=' (scot %uv attempt.n)]))) ',')
::
::  the event an attempt's job receives (Delivery 1A), as act is told it:
::  its name and the payload act reads with -e, both bound by the signed
::  manifest, whose context is the payload's digest.  a push renders its
::  payload from the candidate; a manual run carries the payload admitted
::  with it; a resolve runs no job and receives none
::
++  run-event
  |=  [c=candidate:ci a=attempt:ci]
  ^-  [name=@t payload=@t]
  ?:  ?=(%resolve kind.a)  ['' '']
  ?-  -.trigger.c
    %push  ['push' (push-payload-of c)]
    %dispatch  ['workflow_dispatch' payload.trigger.c]
    %event  [(event-name:ci-trigger trigger.c) payload.run-event.trigger.c]
  ==
::
::  a push candidate's event payload (push-payload): its ref, its base as
::  before, and as after the integration object the manifest signs as its
::  source ('' until %urgit has materialized it); its actor pushed
::
++  push-payload-of
  |=  c=candidate:ci
  ^-  @t
  (push-payload-of:ci-concurrency c)
::
::  a decided skip or refusal is recorded as an attempt no daemon ran: a
::  skip %skipped, a condition that could not be evaluated %failed (the
::  job did not run, and the run cannot pass), each with its decision,
::  the reason, and the needs context it was decided on
::
++  record-decision
  |=  [candidate=candidate-id:ci =job:ci =decision:ci needs=(list need-entry:ci)]
  ^-  _state
  =/  found=candidate:ci  (~(got by candidates) candidate)
  =/  attempt-id=attempt-id:ci
    (sham [%ci-skip candidate workflow.job id.job now.bowl (lent attempts.found)])
  =/  =attempt:ci
    :*  attempt-id  candidate  0v0  0v0
        trust.found
        %job
        `workflow.job
        `id.job
        ::  a job of a cancelled workflow run that did not run is cancelled
        ::  (CI-CONCURRENCY-1), never a skip
        ?:  ?=(%cancel verdict.decision)  %cancelled
        ?:(?=(%error verdict.decision) %failed %skipped)
        0
        ~
        ~
        ~
        `reason.decision
        ~
        ~
        now.bowl
        `now.bowl
        generation.found  mode.found  0v0  sandbox.found  'locked'  ~  %known  ~
        `decision  needs  ~
    ==
  =.  attempts  (~(put by attempts) attempt-id attempt)
  =.  candidates
    %+  ~(put by candidates)  candidate
    found(attempts [attempt-id attempts.found], updated now.bowl)
  state
::
::  a daemon holding the channel open receives its oldest undelivered
::  assignment now; the rest wait for its next poll, one per request
::
++  deliver
  |=  daemon=daemon-id:ci
  ^-  out
  ::  CI-RECOVERY-1: no assignment is handed out while CI is paused
  ?:  ci-paused  [~ state polls]
  =/  waiting=(unit poll)  (~(get by polls) daemon)
  ?~  waiting  (emit ~)
  =/  undelivered=(list assignment:ci)
    %+  sort
      %+  skim  ~(val by assignments)
      |=  =assignment:ci
      ?.  =(daemon.assignment daemon)  %.n
      ?^  delivered.assignment  %.n
      =/  running=(unit attempt:ci)  (~(get by attempts) attempt.assignment)
      ?&(?=(^ running) (active:ci-resolve state u.running))
    |=([a=assignment:ci b=assignment:ci] (lth assigned.a assigned.b))
  ?~  undelivered  (emit ~)
  =/  =assignment:ci  i.undelivered
  =/  =attempt:ci  (~(got by attempts) attempt.assignment)
  =/  =candidate:ci  (~(got by candidates) candidate.assignment)
  =.  assignment  assignment(delivered `now.bowl)
  =.  assignments  (~(put by assignments) id.assignment assignment)
  =.  polls  (~(del by polls) daemon)
  (emit (give-json eyre-id.u.waiting 200 (assignment-json assignment candidate attempt)))
::
::  a daemon the scheduler may hand work to at all (D6, CI-DELIVERY-1.1):
::  enrolled with a bearer, seen within five minutes, neither revoked nor
::  refused.  capacity, labels and the repository binding are the seam
::  below; this is the standing test alone.
::
++  live-daemon
  |=  =daemon:ci
  ^-  ?
  ?&  ?=(^ enrolled.daemon)
      ?=(^ bearer-hash.daemon)
      ?=(~ revoked.daemon)
      ?=(~ refused.daemon)
      ?=(^ last-seen.daemon)
      (lte (sub now.bowl (min now.bowl u.last-seen.daemon)) stale-after)
  ==
::
::  the labels a daemon stands for: what it declared plus the implicit set
::
++  daemon-labels
  |=  =daemon:ci
  ^-  (set @t)
  (~(uni in labels.daemon) implicit-labels)
::
::  whether a daemon may run a job of a repository (CI-P3-SCHED-A): every
::  label the job asks for is one it stands for, and its binding, when the
::  operator set one, names the repository
::
++  daemon-takes
  |=  [=daemon:ci repo=@t runs-on=(set @t)]
  ^-  ?
  ?&  =(~ (~(dif in runs-on) (daemon-labels daemon)))
      ?~(repos.daemon %.y (~(has in u.repos.daemon) repo))
  ==
::
::  the sandbox requirement in selection (P4 D5; rider 04): a VM-required
::  attempt goes only to a microvm daemon; a container daemon takes only
::  container-mode work.  the daemon's self-reported sandbox is trusted
::  as far as its enrollment is: no attestation is claimed.
::
++  daemon-satisfies
  |=  [=daemon:ci need=sandbox-need:ci]
  ^-  ?
  ?-  need
    %vm  =('microvm' sandbox.daemon)
    %container  %.y
  ==
::
::  the network profile in selection (rider 03): a job authorized for a
::  profile needs a daemon that declared it; locked needs nothing
::
++  daemon-offers
  |=  [=daemon:ci profile=@t]
  ^-  ?
  ?:(=('locked' profile) %.y (~(has in profiles.daemon) profile))
::
::  daemon selection (D6, D2b; P4): a live daemon that takes the job,
::  satisfies its sandbox need and network profile, below its capacity,
::  not among the excluded (the daemons that already gave this job up);
::  fewest running first, then the oldest enrollment
::
++  select-daemon
  |=  [repo=@t runs-on=(set @t) exclude=(set daemon-id:ci) need=sandbox-need:ci profile=@t]
  ^-  (unit daemon-id:ci)
  =/  able=(list daemon:ci)
    %+  skim  ~(val by daemons)
    |=  =daemon:ci
    ?&  (live-daemon daemon)
        !(~(has in exclude) id.daemon)
        (daemon-takes daemon repo runs-on)
        (daemon-satisfies daemon need)
        (daemon-offers daemon profile)
        (lth ~(wyt in running.daemon) capacity.daemon)
    ==
  ?~  able  ~
  =/  sorted=(list daemon:ci)
    %+  sort  able
    |=  [a=daemon:ci b=daemon:ci]
    =/  ra=@ud  ~(wyt in running.a)
    =/  rb=@ud  ~(wyt in running.b)
    ?:  !=(ra rb)  (lth ra rb)
    (lth (fall enrolled.a now.bowl) (fall enrolled.b now.bowl))
  ?~  sorted  ~
  `id.i.sorted
::
::  whether any live daemon but the excluded could take the job, capacity
::  aside: a re-offer waits for such a daemon's capacity rather than
::  failing, and fails only when none exists (CI-DELIVERY-1.1 a)
::
++  other-daemon-exists
  |=  [repo=@t runs-on=(set @t) exclude=(set daemon-id:ci) need=sandbox-need:ci profile=@t]
  ^-  ?
  %+  lien  ~(val by daemons)
  |=  =daemon:ci
  ?&  (live-daemon daemon)
      !(~(has in exclude) id.daemon)
      (daemon-takes daemon repo runs-on)
      (daemon-satisfies daemon need)
      (daemon-offers daemon profile)
  ==
::
::  the labels of a job that no enrolled, unrevoked daemon stands for:
::  the candidate's reason while it waits (D2b), empty once one enrolls
::
++  missing-labels
  |=  runs-on=(set @t)
  ^-  (list @t)
  =/  offered=(set @t)
    %+  roll  ~(val by daemons)
    |=  [=daemon:ci acc=(set @t)]
    ?.  ?&(?=(^ enrolled.daemon) ?=(~ revoked.daemon))  acc
    (~(uni in acc) (daemon-labels daemon))
  (sort ~(tap in (~(dif in runs-on) offered)) aor)
::
::  the daemons that gave a job of a candidate up (their attempts stand
::  %reoffered): never offered that job again (CI-DELIVERY-1.1 a).  a plan
::  is keyed by its kind alone.
::
++  excluded-daemons
  |=  [=candidate:ci =kind:ci workflow=(unit @t) job=(unit @t)]
  ^-  (set daemon-id:ci)
  %-  silt
  %+  murn  attempts.candidate
  |=  id=attempt-id:ci
  ^-  (unit daemon-id:ci)
  =/  found=(unit attempt:ci)  (~(get by attempts) id)
  ?~  found  ~
  ?.  =(%reoffered status.u.found)  ~
  ?.  =(kind kind.u.found)  ~
  ?.  ?&(=(workflow workflow.u.found) =(job job.u.found))  ~
  `daemon.u.found
::
::  the job's deadline: its own timeout-minutes plus the silent margin
::  when it declares one (CI-DELIVERY-1.1 c), else the default hour
::
++  job-deadline
  |=  =job:ci
  ^-  @dr
  ?~  timeout.job  default-deadline
  (add (mul u.timeout.job ~m1) silent-margin)
::
::  the scheduler (D4).  every pending, materialized candidate is
::  settled first: skips its plan decides are recorded and its verdict
::  recomputed.  then every runnable unit of work is assigned: a plan
::  for a candidate without one and without a plan attempt in flight;
::  each job the plan makes runnable that has no attempt yet.  work
::  waits when no daemon can take it and is offered again at the next
::  poll, enrollment, ready candidate or closed attempt.  a job whose
::  labels no daemon stands for waits with the reason on the candidate
::  (D2b), never silently.
::
++  schedule
  ^-  out
  ::  CI-RECOVERY-1: while CI is paused nothing is planned, assigned,
  ::  re-offered, resolved or joined, and no card goes out
  ?:  ci-paused  [~ state polls]
  =.  state  reoffer-unfetched
  =/  tags=out  advance-tags
  =.  state  state.tags
  =.  polls  polls.tags
  ::  CI-CONCURRENCY-1: runs that finished leave their groups, new runs
  ::  join theirs oldest first, and a group with no run in progress starts
  ::  its waiting run, before anything is planned or assigned
  ::
  =^  grouped  state  concurrency-pass
  =.  cards.tags  (weld cards.tags grouped)
  ::  an untrusted candidate is planned only where the repository runs
  ::  restricted checks (D3); under the approval policy it waits
  ::
  =/  pending=(list candidate:ci)
    %+  skim  ~(val by candidates)
    |=  =candidate:ci
    ?&  =(%pending status.candidate)
        ?=(^ candidate.candidate)
        !conflict.candidate
        ::  a resolve's record is no run (+resolver-record)
        !(resolver-record candidate)
        ?|(!(tagged-run candidate) (ready:ci-tag candidate))
        ?|(=(%trusted trust.candidate) (restricted repo.candidate))
        ::  a required candidate runs only under a promoted baseline (P4
        ::  D5); a trial runs its own harness; a shadow like a trial
        ?|(!=(%required mode.candidate) ?=(^ baseline.candidate))
    ==
  =/  cards=(list card)  cards.tags
  =|  touched=(set daemon-id:ci)
  |-
  ?~  pending
    =/  daemons-to-answer=(list daemon-id:ci)  ~(tap in touched)
    |-
    ?~  daemons-to-answer  (emit cards)
    =/  delivered=out  (deliver i.daemons-to-answer)
    =.  state  state.delivered
    =.  polls  polls.delivered
    $(daemons-to-answer t.daemons-to-answer, cards (weld cards cards.delivered))
  =/  settled=out  (settle id.i.pending)
  =.  state  state.settled
  =.  cards  (weld cards cards.settled)
  =/  =candidate:ci  (~(got by candidates) id.i.pending)
  ?.  =(%pending status.candidate)  $(pending t.pending)
  ?~  plan.candidate
    ?:  (plan-in-flight candidate)  $(pending t.pending)
    =/  chosen=(unit daemon-id:ci)
      %:  select-daemon
        repo.candidate
        ~
        (excluded-daemons candidate %plan ~ ~)
        (sandbox-for candidate %.n)
        'locked'
      ==
    ?~  chosen
      =.  candidates
        %+  note-wait
          candidate
        %+  rap
          3
        ~['no runner satisfies sandbox requirement ' (sandbox-for candidate %.n)]
      $(pending t.pending)
    =^  made  state
      (create-attempt id.candidate u.chosen %plan ~ ~ plan-deadline ~)
    %=  $
      pending  t.pending
      cards  (snoc cards timer.made)
      touched  (~(put in touched) u.chosen)
    ==
  =/  runnable=(list job:ci)  (runnable-jobs candidate)
  =|  blocked=(unit @t)
  |-
  ?~  runnable
    ::  the labels reason stands while a runnable job has no daemon that
    ::  could take it, and clears when every runnable job found one
    ::
    =/  current=candidate:ci  (~(got by candidates) id.candidate)
    =/  reason=(unit @t)
      ?^  blocked  blocked
      ?:  ?&  ?=(^ verdict-reason.current)
              ?|  =('no runner ' (end [3 10] u.verdict-reason.current))
                  =('environment ' (end [3 12] u.verdict-reason.current))
              ==
          ==
        ~
      verdict-reason.current
    =?  candidates  !=(reason verdict-reason.current)
      (~(put by candidates) id.candidate current(verdict-reason reason, updated now.bowl))
    ^$(pending t.pending)
  =/  =job:ci  i.runnable
  ::  a privileged job (one naming an environment) is admitted only with
  ::  a valid one-use approval or an explicit automation rule (rider 02);
  ::  otherwise it waits with the reason
  =/  admission=(each (unit @uv) @t)  (admit-privileged candidate job)
  ?:  ?=(%| -.admission)
    =?  blocked  ?=(~ blocked)  `p.admission
    $(runnable t.runnable)
  =/  privileged=?  ?=(^ environment.job)
  =/  need=sandbox-need:ci  (sandbox-for candidate privileged)
  =/  net=[profile=@t destinations=(list @t)]  (network-of repo.candidate workflow.job id.job)
  =/  chosen=(unit daemon-id:ci)
    %:  select-daemon  repo.candidate  runs-on.job
      (excluded-daemons candidate %job `workflow.job `id.job)
      need  profile.net
    ==
  ?~  chosen
    =?  blocked  ?=(~ blocked)  `(no-daemon-reason runs-on.job profile.net need)
    $(runnable t.runnable)
  =^  made  state
    %:  create-attempt
      id.candidate  u.chosen  %job
      `workflow.job  `id.job  (job-deadline job)  p.admission
    ==
  %=  $
    runnable  t.runnable
    cards  (snoc cards timer.made)
    touched  (~(put in touched) u.chosen)
  ==
::
::  CI-CONCURRENCY-1: the scheduler's pass over the groups (lib/ci-
::  concurrency).  every run holding or waiting in a group is settled
::  first — its verdict says whether it finished — and released; then the
::  new runs join against the groups as they stand; then the runs a join
::  cancelled are settled and released in turn, so a waiting run starts in
::  the same pass its group frees
::
++  concurrency-pass
  ^-  [(list card) _state]
  =^  settled-before  state  settle-members
  =.  state  (release:ci-concurrency state now.bowl)
  =.  state  join-arrivals
  =^  settled-after  state  settle-members
  =.  state  (release:ci-concurrency state now.bowl)
  [(weld settled-before settled-after) state]
::
::  every run in progress that holds or waits in a group, settled
::
++  settle-members
  ^-  [(list card) _state]
  =/  ids=(list candidate-id:ci)
    %+  murn  ~(val by candidates)
    |=  c=candidate:ci
    ^-  (unit candidate-id:ci)
    ?.  =(%pending status.c)  ~
    ?.  ?=(%joined -.concurrency.c)  ~
    =/  open=?
      %+  lien  runs.concurrency.c
      |=  r=workflow-run:ci
      ?&(?=(%member -.group.r) !=(%released place.group.r))
    ?.  open  ~
    `id.c
  =|  cards=(list card)
  |-
  ?~  ids  [cards state]
  =/  settled=out  (settle i.ids)
  =.  state  state.settled
  $(ids t.ids, cards (weld cards cards.settled))
::
::  the runs ready to join their groups, oldest first: pending and
::  materialized (the jobs' github.sha is the integration object), not
::  conflicted, runnable now (trusted, or untrusted where the repository
::  runs restricted checks), a required run under a promoted baseline, an
::  event run with its selection made.  each joins with its workflows'
::  definitions from its own lock; a run whose workflows or catalog cannot
::  be read takes part in no group, unknown, with the reason
::
++  join-arrivals
  ^-  _state
  =/  ready=(list candidate:ci)
    %+  sort
      %+  skim  ~(val by candidates)
      |=  c=candidate:ci
      ?&  =(%pending status.c)
          ?=(%pending -.concurrency.c)
          ?=(^ candidate.c)
          !conflict.c
          ?|(=(%trusted trust.c) (restricted repo.c))
          ?|(!=(%required mode.c) ?=(^ baseline.c))
          ?|(!?=(%event -.trigger.c) ?=(^ selected.c))
      ==
    |=  [a=candidate:ci b=candidate:ci]
    ?.  =(created.a created.b)  (lth created.a created.b)
    (lth id.a id.b)
  %+  roll  ready
  |=  [c=candidate:ci acc=_state]
  =.  state  acc
  =/  current=candidate:ci  (~(got by candidates) id.c)
  =/  workflows=(each (list @t) @t)  (join-workflows current)
  ?:  ?=(%| -.workflows)
    =.  candidates  (~(put by candidates) id.c current(concurrency [%unknown p.workflows]))
    state
  =/  defs=(each (list [workflow=@t name=@t def=(unit concurrency-def:ci)]) @t)
    (definitions:ci-concurrency state current p.workflows)
  ?:  ?=(%| -.defs)
    =.  candidates  (~(put by candidates) id.c current(concurrency [%unknown p.defs]))
    state
  (join:ci-concurrency state id.c p.defs now.bowl)
::
::  the workflows a run joins with: an event run's selected ones, a
::  manual run's one, a required push's selection from its baseline's
::  catalog (the arm its plan reads), a shadow's push workflows
::
++  join-workflows
  |=  c=candidate:ci
  ^-  (each (list @t) @t)
  ?-  -.trigger.c
    %dispatch  [%& ~[workflow.trigger.c]]
  ::
      %event
    ?~  selected.c  [%| 'the run\'s workflows are not selected yet']
    [%& (selected-workflows:ci-trigger outcomes.u.selected.c)]
  ::
      %push
    ?~  candidate.c  [%| 'the run is not materialized yet']
    ?.  =(%required mode.c)  (push-workflows:ci-concurrency state c)
    =/  sel=event-selection:ci  (required-push-selection c u.candidate.c)
    ?^  note.sel  [%| (rap 3 ~[unread:ci-concurrency ' (' u.note.sel ')'])]
    [%& (selected-workflows:ci-trigger outcomes.sel)]
  ==
::
::  an assignment its daemon never fetched (undelivered) while that
::  daemon's record went stale, refused or revoked is offered again on
::  another daemon when one exists (CI-DELIVERY-1.1): the P1 ghost.  a
::  delivered one is CI-DELIVERY-1's, offered again to its own daemon.
::
::  a scheduling wait written on the candidate row (D2b; rider 03: a
::  missing runner is visible, never a silent widening)
::
::  why no daemon takes a job: its labels, then its network profile,
::  then its sandbox need (the scheduler's order)
::
++  no-daemon-reason
  |=  [runs-on=(set @t) profile=@t need=sandbox-need:ci]
  ^-  @t
  =/  missing=(list @t)  (missing-labels runs-on)
  ?^  missing  (rap 3 ~['no runner has labels [' (join:ci-plan missing ', ') ']'])
  ?.  =('locked' profile)  (rap 3 ~['no runner supports network profile ' profile])
  (rap 3 ~['no runner satisfies sandbox requirement ' need])
::
::  why each runnable job of a pending candidate waits right now, for
::  the candidate view (an operator sees every job's reason, not only
::  the one the candidate's verdict reason carries): admission first,
::  then the daemon that would take it
::
++  job-waits
  |=  =candidate:ci
  ^-  (list [workflow=@t job=@t reason=@t])
  ?.  =(%pending status.candidate)  ~
  ?~  plan.candidate  ~
  %+  murn  (runnable-jobs candidate)
  |=  =job:ci
  ^-  (unit [@t @t @t])
  =/  admission=(each (unit @uv) @t)  (admit-privileged candidate job)
  ?:  ?=(%| -.admission)  `[workflow.job id.job p.admission]
  =/  need=sandbox-need:ci  (sandbox-for candidate ?=(^ environment.job))
  =/  net=[profile=@t destinations=(list @t)]  (network-of repo.candidate workflow.job id.job)
  =/  chosen=(unit daemon-id:ci)
    %:  select-daemon  repo.candidate  runs-on.job
      (excluded-daemons candidate %job `workflow.job `id.job)
      need  profile.net
    ==
  ?^  chosen  ~
  `[workflow.job id.job (no-daemon-reason runs-on.job profile.net need)]
::
++  note-wait
  |=  [=candidate:ci reason=@t]
  ^-  _candidates
  ?:  =(`reason verdict-reason.candidate)  candidates
  (~(put by candidates) id.candidate candidate(verdict-reason `reason, updated now.bowl))
::
::  admission of a privileged job (rider 02): an environment the
::  repository defines, and either an automation rule or a valid one-use
::  approval for exactly this candidate, object, job and environment
::  under the current baseline, lock and generation.  the approval id
::  comes back to be consumed at attempt creation.
::
++  admit-privileged
  |=  [c=candidate:ci =job:ci]
  ^-  (each (unit @uv) @t)
  ?~  environment.job  [%& ~]
  =/  env=(unit environment:ci)  (~(get by environments) [repo.c u.environment.job])
  ?~  env
    [%| (rap 3 ~['environment ' u.environment.job ' is not defined for ' repo.c '; the job waits'])]
  ?.  =(%trusted trust.c)
    [%| (rap 3 ~['environment ' u.environment.job ': an untrusted candidate receives no deployment credentials'])]
  ?.  =(%required mode.c)
    [%| (rap 3 ~['environment ' u.environment.job ': ' ?:(=(%event mode.c) 'an' 'a') ' ' mode.c ' run receives no deployment credentials'])]
  ?~  candidate.c  [%| 'candidate is not materialized']
  ?~  baseline.c  [%| 'no baseline']
  ?:  =(%automatic automation.u.env)  [%& ~]
  =/  valid=(list approval:ci)
    %+  skim  ~(val by approvals)
    |=  a=approval:ci
    ?&  =(repo.a repo.c)  =(candidate.a id.c)
        ?=(~ (approval-valid:ci-provenance a now.bowl incarnation.c id.c u.candidate.c workflow.job id.job u.environment.job u.baseline.c lock.c generation.c))
        (authorized repo.c %environment-approver `u.environment.job approver.a)
    ==
  ?~  valid  [%| (rap 3 ~['environment ' u.environment.job ' needs an approval for job ' id.job])]
  [%& `id.i.valid]
::
++  reoffer-unfetched
  ^-  _state
  %+  roll  ~(val by assignments)
  |=  [=assignment:ci acc=_state]
  =.  state  acc
  ?^  delivered.assignment  state
  =/  running=(unit attempt:ci)  (~(get by attempts) attempt.assignment)
  ?~  running  state
  ?.  =(%running status.u.running)  state
  =/  runner=(unit daemon:ci)  (~(get by daemons) daemon.assignment)
  ?:  ?&(?=(^ runner) (live-daemon u.runner))  state
  =/  found=(unit candidate:ci)  (~(get by candidates) candidate.assignment)
  ?~  found  state
  =/  exclude=(set daemon-id:ci)
    %-  ~(put in (excluded-daemons u.found kind.assignment workflow.assignment job.assignment))
    daemon.assignment
  ?:  ?=(^ approval.u.running)
    %+  close-unknown
      u.running
    'daemon stopped polling before it fetched a privileged assignment; the approval is spent: needs review'
  ::  An undelivered automatic resolve has no uncertain execution to
  ::  replay. Reoffer even without a replacement now; next preserves it.
  ?:  &(?=(%resolve kind.u.running) =(%tag (purpose:ci-resolve u.found)))
    %+  reoffer-attempt
      u.running
    'daemon stopped polling before it fetched the resolver assignment; re-offered'
  ?.  %:  other-daemon-exists
        repo.u.found
        (attempt-runs-on u.found u.running)
        exclude
        sandbox.u.running
        network.u.running
      ==  state
  (reoffer-attempt u.running 'daemon stopped polling before it fetched the assignment; re-offered')
::
::  the runs-on set of an attempt's job, from the candidate's plan; a plan
::  attempt asks for nothing
::
++  attempt-runs-on
  |=  [=candidate:ci =attempt:ci]
  ^-  (set @t)
  ?.  ?=(%job kind.attempt)  ~
  ?~  plan.candidate  ~
  =/  planned=(unit job:ci)  (planned-job candidate workflow.attempt job.attempt)
  ?~(planned ~ runs-on.u.planned)
::
++  planned-job
  |=  [=candidate:ci workflow=(unit @t) job=(unit @t)]
  ^-  (unit job:ci)
  (planned-job:ci-concurrency candidate workflow job)
::
::  an attempt is given up without a verdict and its job offered again
::  (CI-DELIVERY-1.1): closed %reoffered with the reason, let go by its
::  daemon, and standing for nothing, so the scheduler assigns the job
::  afresh — to a daemon that never gave it up — at the next opportunity.
::  the caller settles and schedules.
::
++  reoffer-attempt
  |=  [=attempt:ci reason=@t]
  ^-  _state
  (reoffer:ci-resolve state attempt reason now.bowl)
::
::  a running attempt at its deadline (CI-DELIVERY-1.1 c): offered again
::  once on another daemon when one exists; else — or after that one
::  re-offer — an infrastructure error.  the reason says which silence
::  it was: a runner that started and went quiet, or one that never
::  reported at all.
::
++  expire-attempt
  |=  =attempt:ci
  ^-  out
  =/  found=(unit candidate:ci)  (~(get by candidates) candidate.attempt)
  =/  silent-before=?
    ?~  found  %.y
    %+  lien  attempts.u.found
    |=  id=attempt-id:ci
    =/  earlier=(unit attempt:ci)  (~(get by attempts) id)
    ?~  earlier  %.n
    ?&  =(%reoffered status.u.earlier)
        =(kind.attempt kind.u.earlier)
        =(workflow.attempt workflow.u.earlier)
        =(job.attempt job.u.earlier)
        ?=(^ reason.u.earlier)
        =('runner went silent' (end [3 18] u.reason.u.earlier))
    ==
  =/  again=?
    ?~  found  %.n
    ?:  silent-before  %.n
    ?:  ?=(^ approval.attempt)  %.n
    =/  exclude=(set daemon-id:ci)
      %-  ~(put in (excluded-daemons u.found kind.attempt workflow.attempt job.attempt))
      daemon.attempt
    ?:  &(?=(%resolve kind.attempt) =(%tag (purpose:ci-resolve u.found)))
      ?=(^ (select-resolver-excluding repo.u.found exclude))
    %:  other-daemon-exists
      repo.u.found
      (attempt-runs-on u.found attempt)
      exclude
      sandbox.attempt
      network.attempt
    ==
  =.  state
    ?:  again
      (reoffer-attempt attempt 'runner went silent; re-offered')
    ::  a privileged attempt that timed out is unknown, never retried
    ::  (rider 02, A03)
    ?:  ?=(^ approval.attempt)
      %+  close-unknown
        attempt
      'no result before the deadline of a privileged job; the external side effect may have happened: needs review'
    %+  close-attempt  attempt
    :-  %infrastructure-error
    ?:(silent-before 'runner went silent' 'no result arrived before the deadline')
  (after-close candidate.attempt)
::
++  plan-in-flight
  |=  =candidate:ci
  ^-  ?
  %+  lien  attempts.candidate
  |=  id=attempt-id:ci
  =/  found=(unit attempt:ci)  (~(get by attempts) id)
  ?&(?=(^ found) ?=(%plan kind.u.found) =(%running status.u.found))
::
::  the newest job attempt per [workflow id] is that job's standing, and
::  the accepted attempt a dependent's decision and needs context read.  a
::  re-offered or cancelled attempt stands for nothing — the job is owed a
::  fresh one — unless its workflow's run was cancelled: then it is the
::  job's end (lib/ci-concurrency, CI-CONCURRENCY-1)
::
++  standings
  |=  =candidate:ci
  ^-  [standings=(map key:ci-plan standing:ci-plan) newest=(map key:ci-plan attempt:ci)]
  (standings:ci-concurrency state candidate)
::
::  the run a candidate's decisions read (CI-EXPR-2): its event, the
::  payload act reads, ref, source and actor, and its typed inputs.
::  cancelled() is read per job, for the job's own workflow's run
::  (lib/ci-concurrency +decide-with)
::
++  run-context
  |=  c=candidate:ci
  ^-  run-context:ci-plan
  (run-context:ci-concurrency c)
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
  (need-entries:ci-concurrency c newest standings)
::
::  what an attempt published to its dependents (lib/ci-concurrency)
::
++  published-outputs
  |=  [planned=(unit job:ci) a=attempt:ci]
  ^-  (list [name=@t value=@t])
  (published-outputs:ci-concurrency planned a)
::
++  legacy-outputs
  |=  outputs=(list step-output:ci)
  ^-  (list [name=@t value=@t])
  (legacy-outputs:ci-concurrency outputs)
::
::  a job's decision now, and the needs context it would be given: its
::  concurrency gate first (CI-CONCURRENCY-1), then its condition
::
++  job-decision
  |=  [c=candidate:ci =job:ci]
  ^-  [=decision:ci-plan needs=(list need-entry:ci)]
  ?~  plan.c  [[%wait 'the run has no plan yet'] ~]
  =/  known  (standings c)
  =/  entries=(map key:ci-plan need-entry:ci)  (need-entries c newest.known standings.known)
  :-  (decide-with:ci-concurrency state c job u.plan.c standings.known entries (run-context c))
  (direct-entries:ci-plan job entries)
::
++  runnable-jobs
  |=  =candidate:ci
  ^-  (list job:ci)
  ?~  plan.candidate  ~
  =/  known  (standings candidate)
  =/  entries=(map key:ci-plan need-entry:ci)  (need-entries candidate newest.known standings.known)
  =/  context=run-context:ci-plan  (run-context candidate)
  %+  skim  u.plan.candidate
  |=  =job:ci
  ?:  (~(has by standings.known) [workflow.job id.job])  %.n
  =(%run -:(decide-with:ci-concurrency state candidate job u.plan.candidate standings.known entries context))
::
::  one pass of a candidate's undecided jobs: a skip, a cancel or a
::  refusal its plan decides is recorded with the reason and the needs
::  context
::
++  decide-pass
  |=  id=candidate-id:ci
  ^-  _state
  =/  found=candidate:ci  (~(got by candidates) id)
  ?~  plan.found  state
  =/  known  (standings found)
  =/  entries=(map key:ci-plan need-entry:ci)  (need-entries found newest.known standings.known)
  =/  context=run-context:ci-plan  (run-context found)
  %+  roll  u.plan.found
  |=  [=job:ci acc=_state]
  =.  state  acc
  ?:  (~(has by standings.known) [workflow.job id.job])  state
  =/  =decision:ci-plan
    (decide-with:ci-concurrency state found job u.plan.found standings.known entries context)
  =/  needs=(list need-entry:ci)  (direct-entries:ci-plan job entries)
  ?+  -.decision  state
    %skip  (record-decision id job [%skip reason.decision value.decision] needs)
    %cancel  (record-decision id job [%cancel reason.decision value.decision] needs)
    %error  (record-decision id job [%error reason.decision ~] needs)
  ==
::
::  one candidate's verdict from its record: over the plan when it has
::  one (skips decided now are recorded first), else from its newest
::  attempt, the P0 rule the harness drives by hand.  a verdict that
::  becomes terminal releases the scratch ref; a passed one asks %urgit
::  to land the candidate at once (D14).
::
++  settle
  |=  id=candidate-id:ci
  ^-  out
  =/  found=(unit candidate:ci)  (~(get by candidates) id)
  ?~  found  (emit ~)
  ::  a superseded candidate keeps its verdict whatever its attempts do
  ::
  ?:  =(%skipped status.u.found)  (emit ~)
  =/  before=candidate-status:ci  status.u.found
  ::  skips and refusals the plan decides now, until none is left: a skip
  ::  decides its dependents' skips in the same event (at most one round
  ::  per job)
  ::
  =.  state
    ?~  plan.u.found  state
    =/  rounds=@ud  (lent u.plan.u.found)
    |-
    ?:  =(0 rounds)  state
    =/  count=@ud  (lent attempts:(~(got by candidates) id))
    =.  state  (decide-pass id)
    ?:  =(count (lent attempts:(~(got by candidates) id)))  state
    $(rounds (dec rounds))
  ::  a run cancelled before it was planned — whole, or every workflow it
  ::  joined while it waited (CI-CONCURRENCY-1) — is cancelled with no
  ::  job: its plan attempt is closed, as nothing is left to plan
  ::
  =/  unplanned=?  (unplanned-cancelled (~(got by candidates) id))
  =?  state  unplanned  (close-plan-attempts (~(got by candidates) id))
  =/  =candidate:ci  (~(got by candidates) id)
  =/  verdict=[status=candidate-status:ci reason=(unit @t)]
    ?^  plan.candidate
      %^  verdict-in:ci-plan
          u.plan.candidate
        standings:(standings candidate)
      (cancelled-workflows candidate)
    ?:  unplanned  [%cancelled ~]
    ::  the newest attempt OF THIS GENERATION: a candidate reset by a
    ::  policy change keeps its history, but evidence from another
    ::  generation stands for nothing (P09/P11 — the cold run found the
    ::  old passed attempt re-settling a reset candidate as passed)
    =/  newest=(unit attempt:ci)
      =/  ids=(list attempt-id:ci)  attempts.candidate
      |-
      ?~  ids  ~
      =/  a=(unit attempt:ci)  (~(get by attempts) i.ids)
      ?~  a  $(ids t.ids)
      ?.  =(generation.u.a generation.candidate)  $(ids t.ids)
      a
    ?~  newest  [%pending ~]
    ?-  status.u.newest
      %passed  [%passed ~]
      %failed  [%failed reason.u.newest]
      %skipped  [%pending ~]
      %running  [%pending ~]
      %reoffered  [%pending ~]
      %cancelled  [%pending ~]
      %infrastructure-error  [%unknown reason.u.newest]
    ==
  ::  a required run whose push workflow the filters excluded, or whose
  ::  trigger is refused (Delivery 1C), has absent required evidence: it
  ::  never passes, keeps its ref blocked with the reason, and no attempt
  ::  stands in for the workflow; an override is the way past it
  ::
  =/  missing=(list workflow-selection:ci)
    ?.  =(%required mode.candidate)  ~
    ?~  selected.candidate  ~
    (unselected:ci-trigger outcomes.u.selected.candidate)
  =/  blocked=(unit @t)
    ?.  ?&(?=(^ missing) =(%passed status.verdict))  ~
    `(absent-evidence missing)
  =?  verdict  ?=(^ blocked)  [%pending blocked]
  ::  a cancelled run says who or what cancelled it, in plain words
  =?  verdict  ?=(%cancelled status.verdict)  [%cancelled `(cancel-reason candidate)]
  ::  a restricted check that passes is a verdict, never a landing: the
  ::  reason says so, and only approval runs the head as trusted (D3)
  ::
  =/  reason=(unit @t)
    ?:  ?&(=(%passed status.verdict) =(%untrusted trust.candidate))
      `'passed as a restricted check: an untrusted candidate cannot land; approve it to run trusted'
    ?:  ?&(=(%passed status.verdict) =(%trial mode.candidate))
      `'passed as a trial of the candidate\'s own harness: trial evidence never satisfies the required checks; promote the revision to make it the baseline'
    ?:  ?&(=(%passed status.verdict) =(%shadow mode.candidate))
      `'passed as a shadow run: nothing lands'
    ?:  ?&(=(%passed status.verdict) =(%manual mode.candidate))
      `'passed as a manual run: nothing lands'
    ?:  ?&(=(%passed status.verdict) =(%event mode.candidate))
      `'passed as an event run: nothing lands, and no required check is satisfied by it'
    reason.verdict
  =/  next=candidate:ci
    %=  candidate
      status  status.verdict
      verdict-reason
        ?^  blocked  blocked
        ?:(=(before status.verdict) verdict-reason.candidate reason)
      updated  now.bowl
    ==
  =.  candidates  (~(put by candidates) id next)
  ?:  =(before status.verdict)  (emit ~)
  ?:  =(%pending status.verdict)  (emit ~)
  =/  release=card
    (urgit-git-poke /release/(scot %uv id) [%delete-ref repo.next (scratch-ref next)])
  ?.  (landable next)  (emit ~[release])
  ::  CI-RECOVERY-1: nothing lands while CI is paused, and resuming lands
  ::  nothing either: the reason says what to do
  ?:  ci-paused
    =/  why=@t
      'passed while CI was paused for a restore: nothing was landed. Push the same commit again after CI resumes to land it'
    =.  candidates  (~(put by candidates) id next(verdict-reason `why))
    (emit ~[release])
  (emit (snoc (land-cards next) release))
::
::  CI-CONCURRENCY-1: the workflows of a run whose runs were cancelled;
::  the whole run's cancellation ('') covers every workflow of its plan
::
++  cancelled-workflows
  |=  c=candidate:ci
  ^-  (set @t)
  =/  own=(set @t)  (~(del in ~(key by cancelled.c)) '')
  ?.  (~(has by cancelled.c) '')  own
  ?~  plan.c  own
  (~(gas in own) (turn u.plan.c |=(j=job:ci workflow.j)))
::
::  whether a run with no plan is cancelled: whole, or every workflow it
::  joined, each before it started
::
++  unplanned-cancelled
  |=  c=candidate:ci
  ^-  ?
  ?^  plan.c  %.n
  ?:  (~(has by cancelled.c) '')  %.y
  ?.  ?=(%joined -.concurrency.c)  %.n
  =/  runs=(list workflow-run:ci)  runs.concurrency.c
  ?:  =(~ runs)  %.n
  %+  levy  runs
  |=  r=workflow-run:ci
  =/  stop=(unit cancellation:ci)  (~(get by cancelled.c) workflow.r)
  ?&(?=(^ stop) !started.u.stop)
::
::  a cancelled run's running plan attempts, closed (the daemon hears
::  `attempt is closed`)
::
++  close-plan-attempts
  |=  c=candidate:ci
  ^-  _state
  %+  roll  attempts.c
  |=  [aid=attempt-id:ci acc=_state]
  =.  state  acc
  =/  a=(unit attempt:ci)  (~(get by attempts) aid)
  ?~  a  state
  ?.  ?&(=(%running status.u.a) ?=(%plan kind.u.a))  state
  (close-cancelled:ci-concurrency state u.a (cancel-reason c) now.bowl)
::
::  the reason a cancelled run shows: the whole run's cancellation, else
::  each cancelled workflow's, by workflow file
::
++  cancel-reason
  |=  c=candidate:ci
  ^-  @t
  =/  whole=(unit cancellation:ci)  (~(get by cancelled.c) '')
  ?^  whole  reason.u.whole
  =/  items=(list [workflow=@t =cancellation:ci])
    %+  sort  ~(tap by cancelled.c)
    |=([a=[workflow=@t cancellation:ci] b=[workflow=@t cancellation:ci]] (aor workflow.a workflow.b))
  ?~  items  'the run was cancelled'
  %+  join:ci-plan
    (turn items |=([workflow=@t =cancellation:ci] (rap 3 ~[workflow ': ' reason.cancellation])))
  '; '
::
++  land-cards
  |=  =candidate:ci
  ^-  (list card)
  ?~  candidate.candidate  ~
  :_  ~
  %+  urgit-poke  /land/(scot %uv id.candidate)
  [%land-candidate id.candidate repo.candidate ref.candidate u.candidate.candidate base.candidate pull.candidate]
::
::  after an attempt closes: its candidate is settled whatever its status
::  (a re-run changes a verdict), then the scheduler runs for everything
::
++  after-close
  |=  id=candidate-id:ci
  ^-  out
  =/  settled=out  (settle id)
  =.  state  state.settled
  =/  scheduled=out  schedule
  [(weld cards.settled cards.scheduled) state.scheduled polls.scheduled]
::
::  an attempt closes once.  a job result closes it passed or failed; an
::  invalid plan closes it failed with the reason; an infrastructure error
::  closes it unknown for the candidate.  the daemon's running set lets
::  the attempt go.  the candidate's verdict is +settle's, after this.
::
::  (lib/ci-concurrency +close, which a cancellation closes through too):
::  a resolve's mirror write tokens end with it (the cards are emitted by
::  the caller through mirror-token-cards), and the read capability of a
::  closed attempt is gone (A06)
::
++  close-attempt
  |=  [=attempt:ci =attempt-result:ci]
  ^-  _state
  (close:ci-concurrency state attempt attempt-result now.bowl)
::
::  the %clear-write-token cards for a resolve attempt's mirrors: read
::  BEFORE close-attempt drops the record
::
++  mirror-token-cards
  |=  =attempt:ci
  ^-  (list card)
  =/  repos=(unit (set @t))  (~(get by mirror-tokens) id.attempt)
  ?~  repos  ~
  %+  turn  ~(tap in u.repos)
  |=  repo=@t
  (urgit-git-poke /mirror-token/(scot %t repo) [%clear-write-token repo])
::
::  a mirror repository's name for an origin such as
::  https://github.com/actions/cache: ci-mirror-actions-cache
::
++  mirror-name
  |=  origin=@t
  ^-  @t
  =/  chars=tape  (trip origin)
  =.  chars
    ?:  =("https://github.com/" (scag 19 chars))  (slag 19 chars)
    ?:  =("https://" (scag 8 chars))  (slag 8 chars)
    chars
  =/  safe=tape
    %+  turn  chars
    |=  c=@tD
    ?:  ?|  &((gte c 'a') (lte c 'z'))
            &((gte c '0') (lte c '9'))
            =('-' c)  =('.' c)  =('_' c)
        ==
      c
    ?:  &((gte c 'A') (lte c 'Z'))  (add c 32)
    '-'
  (crip (weld "ci-mirror-" (scag 80 safe)))
::
::  http
::
++  give-json
  |=  [eyre-id=@ta status=@ud jon=json]
  ^-  (list card)
  %+  give-simple-payload:app:server  eyre-id
  :_  `(json-to-octs:server jon)
  :-  status
  :~  ['content-type' 'application/json; charset=utf-8']
      ['cache-control' 'no-store']
  ==
::
++  give-error
  |=  [eyre-id=@ta status=@ud message=@t]
  ^-  (list card)
  (give-json eyre-id status (pairs:enjs:format ~[['error' s+message]]))
::
++  give-empty
  |=  [eyre-id=@ta status=@ud]
  ^-  (list card)
  %+  give-simple-payload:app:server  eyre-id
  [[status ~[['cache-control' 'no-store']]] ~]
::
++  body-json
  |=  req=inbound-request:eyre
  ^-  (unit json)
  ?~  body.request.req  ~
  (de:json:html q.u.body.request.req)
::
++  string-at
  |=  [key=@t jon=json]
  ^-  (unit @t)
  ?.  ?=([%o *] jon)  ~
  =/  value=(unit json)  (~(get by p.jon) key)
  ?~  value  ~
  ?.  ?=([%s *] u.value)  ~
  `p.u.value
::
++  number-at
  |=  [key=@t jon=json]
  ^-  (unit (unit @ud))
  ?.  ?=([%o *] jon)  `~
  =/  value=(unit json)  (~(get by p.jon) key)
  ?~  value  `~
  ?.  ?=([%n *] u.value)  ~
  ::  a JSON number has no thousands dots: dim, not %ud (dem:ag wants them)
  ::
  =/  parsed=(unit @ud)  (rush p.u.value dim:ag)
  ?~  parsed  ~
  `parsed
::
::  a daemon presents its bearer as `x-ci-bearer: <@uv>`.  it cannot use
::  `Authorization: Bearer`: eyre reads that header itself as a session
::  token and answers 401 before the request reaches any agent.  only
::  hashes are compared, and only against the daemon the route names.  a
::  logged-in ship session is always accepted.
::
++  presented-bearer-hash
  |=  req=inbound-request:eyre
  ^-  (unit @)
  =/  header=(unit @t)
    (get-header:http 'x-ci-bearer' header-list.request.req)
  ?~  header  ~
  =/  bearer=(unit @uv)  (slaw %uv u.header)
  ?~  bearer  ~
  `(shas %ci-bearer u.bearer)
::
::  a viewer of the web surface (D6) is the ship's own session; every
::  ci/* read and the action route ask this one arm, so the fence is one
::  line.  a daemon bearer is not a viewer.
::
++  viewer
  |=  req=inbound-request:eyre
  ^-  ?
  authenticated.req
::
++  daemon-authorized
  |=  [req=inbound-request:eyre =daemon:ci]
  ^-  ?
  ?:  authenticated.req  %.y
  ?~  bearer-hash.daemon  %.n
  =/  presented=(unit @)  (presented-bearer-hash req)
  ?~  presented  %.n
  =(u.bearer-hash.daemon u.presented)
::
++  attempt-authorized
  |=  [req=inbound-request:eyre =attempt:ci]
  ^-  ?
  =/  found=(unit daemon:ci)  (~(get by daemons) daemon.attempt)
  ?~  found  authenticated.req
  (daemon-authorized req u.found)
::
++  touch-daemon
  |=  id=daemon-id:ci
  ^-  _daemons
  =/  found=(unit daemon:ci)  (~(get by daemons) id)
  ?~  found  daemons
  (~(put by daemons) id u.found(last-seen `now.bowl))
::
::  the assignment as the daemon reads it.  a job assignment carries its
::  needs context (Delivery 1B): the text its expressions read, rendered
::  from the needs snapshot fixed when the attempt was created — each
::  need's accepted attempt, result and published outputs — and bound by
::  the signed manifest's needs digest and prerequisites; '' for a job
::  that needs none.  the daemon runs act on a single-job projection that
::  reads every needs root from it (runner/internal/plan ProjectJob).
::
++  assignment-json
  |=  [=assignment:ci =candidate:ci =attempt:ci]
  ^-  json
  =/  oid=@t
    ?~  candidate.candidate  ''
    (oid-text:git-codec u.candidate.candidate)
  =/  needs-context=@t
    ?~  needs.attempt  ''
    (needs-text:ci-expr needs.attempt)
  ::  the credentials released to this attempt (D4; P4 D6, rider 02): a
  ::  trusted REQUIRED job gets every %job-scoped credential of its
  ::  repository; a privileged job (one naming an environment) gets only
  ::  the subset its consumed approval or automation rule allows, out of
  ::  the environment's own set; an untrusted attempt, a trial, a shadow
  ::  and a plan get none
  ::
  =/  environment=(unit @t)
    ?~  workflow.assignment  ~
    ?~  job.assignment  ~
    =/  planned=(unit job:ci)  (planned-job candidate workflow.assignment job.assignment)
    ?~(planned ~ environment.u.planned)
  =/  released=(set @t)
    ?~  environment  ~
    ?^  approval.attempt
      =/  a=(unit approval:ci)  (~(get by approvals) u.approval.attempt)
      ?~(a ~ credentials.u.a)
    =/  env=(unit environment:ci)  (~(get by environments) [repo.candidate u.environment])
    ?~  env  ~
    ?:(=(%automatic automation.u.env) credentials.u.env ~)
  =/  grants=(list [name=@t value=@t])
    ?.  ?&(?=(%job kind.assignment) =(%trusted trust.assignment) =(%required mode.candidate))  ~
    %+  murn  ~(tap by credentials)
    |=  [[repo=@t name=@t] =credential:ci]
    ^-  (unit [@t @t])
    ?.  =(repo repo.candidate)  ~
    ?-  scope.credential
        %job
      ?^(environment ?:((~(has in released) name) `[name value.credential] ~) `[name value.credential])
        %env
      ?~(environment ~ ?:(&((~(has in envs.credential) u.environment) (~(has in released) name)) `[name value.credential] ~))
    ==
  =/  expiry=@da  (add assigned.assignment deadline.assignment)
  =/  =manifest:ci-provenance  (manifest-of candidate attempt)
  ::  the assignment's own signature (D5; P4 contract §5): version 2 over
  ::  the recipient, the attempt, the operation 'assign', an expiry a
  ::  minute past the attempt's deadline (delivery is not instant), a
  ::  nonce and the whole execution manifest
  ::
  =/  sig-json=json
    ::  the nonce carries the runner's authorization epoch at the
    ::  assignment's creation (legacy-replay-upgrade ruling 01;
    ::  INTEGRATION.md §11.15): a runner past a transition refuses every
    ::  assignment of an earlier epoch, however often it is signed again
    ::
    =/  epoch=@ud
      %^  epoch-at:ci-recovery
        ~(val by recovery-commands)
        daemon.assignment
      assigned.assignment
    =/  nonce=@uv  (epoch-nonce:ci-recovery epoch (fresh-nonce [%assign id.assignment]))
    =/  sig-expiry=@da  (add expiry ~m1)
    %-  pairs:enjs:format
    :~  ['version' (numb:enjs:format (manifest-version-for:ci-provenance manifest))]
        ['recipient' s+(scot %uv daemon.assignment)]
        ['attempt' s+(scot %uv attempt.assignment)]
        ['operation' s+'assign']
        ['expiry' (numb:enjs:format (unix-seconds sig-expiry))]
        ['nonce' s+(scot %uv nonce)]
        ['sig' s+(hex-bytes (sign-authorization daemon.assignment attempt.assignment 'assign' sig-expiry nonce manifest) 64)]
    ==
  =/  grants-json=json
    :-  %a
    %+  turn  grants
    |=  [name=@t value=@t]
    =/  =grant:ci  (sign-grant daemon.assignment attempt.assignment name expiry manifest)
    %-  pairs:enjs:format
    :~  ['name' s+name]
        ['value' s+value]
        ['expiry' (numb:enjs:format (unix-seconds expiry))]
        ['nonce' s+(scot %uv nonce.grant)]
        ['sig' s+(hex-bytes sig.grant 64)]
    ==
  =/  base=(unit baseline:ci)
    ?:  (tagged-run candidate)  ~
    (~(get by baselines) [repo.candidate ref.candidate])
  =/  lock-json=json
    ?~  lock.candidate  ~
    =/  found=(unit lock:ci)  (~(get by locks) u.lock.candidate)
    ?~  found  ~
    (lock-json u.found)
  =/  downloads-json=json
    ?~  lock.candidate  [%a ~]
    =/  found=(unit lock:ci)  (~(get by locks) u.lock.candidate)
    ?~  found  [%a ~]
    =/  store-settings  (read-settings:ci-storage our.bowl now.bowl)
    :-  %a
    %+  murn  nodes.u.found
    |=  n=dep-node:ci
    ^-  (unit json)
    ::  a download, or a container image's archive (P03): both are
    ::  content-addressed objects the daemon stages before the job
    ?.  ?=(?(%download %container) kind.n)  ~
    ::  the bytes: a presigned GET of the content-addressed object, for
    ::  the store's window (the daemon fetches at bundle time, at once)
    =/  store-url=(unit @t)
      (presign-key:ci-storage store-settings path.n max-presign:ci-storage now.bowl)
    :-  ~
    %-  pairs:enjs:format
    :~  ['url' s+origin.n]
        ['uses' s+uses.n]
        ['kind' s+kind.n]
        ['subpath' s+subpath.n]
        ['sha256' s+sha256.n]
        ['size' (numb:enjs:format size.n)]
        ['mirror' s+mirror.n]
        ['commit' s+mirror-commit.n]
        ['path' s+path.n]
        ['store' ?~(store-url ~ s+u.store-url)]
        ['digest' s+digest.n]
        ['id' s+tree.n]
    ==
  %-  pairs:enjs:format
  :_  ~
  :-  'assignment'
  %-  pairs:enjs:format
  :~  ['id' s+(scot %uv id.assignment)]
      ['attempt' s+(scot %uv attempt.assignment)]
      ['candidate' s+(scot %uv candidate.assignment)]
      ['repo' s+repo.candidate]
      ['ref' s+ref.candidate]
      ['oid' s+oid]
      ['head' s+(oid-text:git-codec head.candidate)]
      ['base' s+(oid-text:git-codec base.candidate)]
      ['trust' s+trust.assignment]
      ['scratch-ref' s+(scratch-ref candidate)]
      ['kind' s+kind.assignment]
      ['workflow' ?~(workflow.assignment ~ s+u.workflow.assignment)]
      ['job' ?~(job.assignment ~ s+u.job.assignment)]
      ['needs-context' s+needs-context]
      ['deadline-seconds' (numb:enjs:format (div deadline.assignment ~s1))]
      ['assigned' s+(scot %da assigned.assignment)]
      ['grants' grants-json]
      ['sig' sig-json]
      ::  every signed field (Delivery 1B correction 01): the shared
      ::  serializer, so the object always carries what the signature binds
      ['manifest' (manifest-json:ci-provenance manifest)]
      ['automatic-inputs' ?:(&(=('resolve-tag' mode.manifest) (~(has by input-snapshots) id.candidate)) (envelope:ci-input (captured:ci-input state id.candidate)) ~)]
      ['harness-paths' [%a ?~(base ~ (turn harness-paths.u.base |=(p=@t s+p)))]]
      ::  An automatic resolver has a captured source, not a promoted baseline.
      :-  'workflows-oid'
      :-  %s
      ?:  |(=(%trial mode.candidate) =('resolve-tag' mode.manifest))
        oid
      (oid-hex:ci-provenance baseline.candidate)
      ['baseline-ref' ?~(base ~ s+(baseline-ref repo.candidate ref.candidate))]
      ['lock' lock-json]
      ['downloads' downloads-json]
      ['read-token' s+(scot %uv (read-token attempt.assignment))]
      ::  the event payload act reads (Delivery 1A), a push's or a manual
      ::  run's, whose sha-256 the manifest's context binds; '' for a
      ::  resolve
      ['event-payload' s+payload:(run-event candidate attempt)]
      :-  'mappings'
      :-  %a
      %+  turn  (~(gut by resolve-mappings) candidate.assignment ~)
      |=  [from=@t to=@t]
      (pairs:enjs:format ~[['from' s+from] ['to' s+to]])
  ==
::
::  a lock as the daemon and the UI read it
::
++  lock-json
  |=  l=lock:ci
  ^-  json
  %-  pairs:enjs:format
  :~  ['digest' s+(hex-bytes:ci-provenance digest.l 32)]
      ['repo' s+repo.l]
      ['revision' s+(oid-text:git-codec revision.l)]
      ['resolved' (numb:enjs:format (unix-seconds resolved.l))]
      ['resolver' s+(scot %uv resolver.l)]
      ['bytes' (numb:enjs:format bytes.l)]
      ['notices' [%a (turn notices.l |=(n=@t s+n))]]
      ['automaticInputEvidence' ?~(e=(~(get by input-evidence) digest.l) ~ (fall (de:json:html u.e) ~))]
      :-  'nodes'
      :-  %a
      %+  turn  nodes.l
      |=  n=dep-node:ci
      %-  pairs:enjs:format
      :~  ['uses' s+uses.n]
          ['kind' s+kind.n]
          ['origin' s+origin.n]
          ['ref' s+ref.n]
          ['commit' s+commit.n]
          ['tree' s+tree.n]
          ['subpath' s+subpath.n]
          ['mirror' s+mirror.n]
          ['mirror-commit' s+mirror-commit.n]
          ['digest' s+digest.n]
          ['license' s+license.n]
          ['workflow' s+workflow.n]
          ['job' s+job.n]
          ['step' (numb:enjs:format step.n)]
          ['sha256' s+sha256.n]
          ['size' (numb:enjs:format size.n)]
          ['path' s+path.n]
          ['refusal' ?~(refusal.n ~ s+u.refusal.n)]
      ==
      ::  the manual workflows the resolver listed (Delivery 1A): null
      ::  when the lock predates them, which is not an empty list
      :-  'inventory'
      ?~  inventory.l  ~
      [%a (turn u.inventory.l dispatch-workflow-json)]
      ::  the events each workflow declares (Delivery 1C), in brief: null
      ::  when the lock predates trigger definitions, which is unknown
      :-  'triggers'
      ?~  triggers.l  ~
      %-  pairs:enjs:format
      :~  ['zones' [%a (turn (sort ~(tap in ~(key by zones.u.triggers.l)) aor) |=(n=@t s+n))]]
          :-  'workflows'
          :-  %a
          %+  turn  workflows.u.triggers.l
          |=  w=trigger-workflow:ci
          %-  pairs:enjs:format
          :~  ['workflow' s+workflow.w]
              ['name' s+name.w]
              ['refusal' ?~(refusal.w ~ s+u.refusal.w)]
              ['concurrency' (concurrency-def-json concurrency.w)]
              :-  'events'
              :-  %a
              %+  turn  events.w
              |=  e=trigger-event:ci
              (pairs:enjs:format ~[['event' s+event.e] ['refusal' ?~(refusal.e ~ s+u.refusal.e)]])
          ==
      ==
  ==
::
::  one workflow of a lock's manual-run inventory, as the run form and the
::  lock view read it
::
++  dispatch-workflow-json
  |=  w=dispatch-workflow:ci
  ^-  json
  %-  pairs:enjs:format
  :~  ['workflow' s+workflow.w]
      ['name' s+name.w]
      ['refusal' ?~(refusal.w ~ s+u.refusal.w)]
      :-  'inputs'
      :-  %a
      %+  turn  inputs.w
      |=  i=dispatch-input:ci
      %-  pairs:enjs:format
      :~  ['id' s+id.i]
          ['type' s+kind.i]
          ['description' s+description.i]
          ['required' b+required.i]
          ['default' ?~(default.i ~ s+u.default.i)]
          ['options' [%a (turn options.i |=(o=@t s+o))]]
      ==
  ==
::
::  the Jael subscription that hands over the ship's keys
::
++  keys-card
  ^-  card
  [%pass /jael/keys %arvo %j %private-keys ~]
::
::  a fresh CI keypair from entropy: luck:ed:crypto takes a 32-byte seed
::  and answers [pub sek]; the certificate is 0 until the ship's keys
::  arrive
::
++  fresh-signing-key
  ^-  signing:ci
  =/  pair  (luck:ed:crypto (end [3 32] eny.bowl))
  [pub.pair sek.pair 0x0 now.bowl]
::
::  the ship's signing pair from a suite-b ring ('B' then 64 bytes: the
::  encryption seed above the signing seed, as nol:nu:crub reads it);
::  the pair is (luck:ed seed), which is what ames signs with
::
++  ship-keys-from-ring
  |=  [=life ring=@]
  ^-  (unit ship-keys:ci)
  ?.  =('B' (end 3 ring))  ~
  =/  body=@  (rsh 3 ring)
  =/  seed=@  (end 8 body)
  =/  pair  (luck:ed:crypto seed)
  `[life pub.pair sek.pair]
::
::  the certificate: the ship's signature over the CI public key (D5)
::
++  certified
  |=  [key=(unit signing:ci) keys=ship-keys:ci]
  ^-  (unit signing:ci)
  ?~  key  ~
  `u.key(cert (sign-raw:ed:crypto pub.u.key pub.keys sek.keys))
::
::  what the ship signs for one authorization (D5): the jam of the
::  recipient daemon, the attempt, the operation, the expiry in unix
::  seconds and a nonce.  the daemon rebuilds the same noun from the
::  fields it received and verifies with the pinned public key.
::
++  sign-authorization
  |=  [recipient=daemon-id:ci attempt=attempt-id:ci operation=@t expiry=@da nonce=@uv =manifest:ci-provenance]
  ^-  @ux
  ?~  signing  0x0
  =/  message=@
    %:  message-bytes:ci-provenance
      recipient
      attempt
      operation
      (unix-seconds expiry)
      nonce
      manifest
    ==
  (sign-raw:ed:crypto message pub.u.signing sek.u.signing)
::
++  fresh-nonce
  |=  salt=*
  ^-  @uv
  (end [3 16] (shas %ci-nonce (jam [salt eny.bowl now.bowl])))
::
::  unix seconds of a time, for the wire (a @da is not a JSON number)
::
++  unix-seconds
  |=  at=@da
  ^-  @ud
  ?:  (lth at ~1970.1.1)  0
  (div (sub at ~1970.1.1) ~s1)
::
::  an atom's low .count bytes as lowercase hex, least significant byte
::  first: the standard wire encoding of an ed25519 key or signature
::
++  hex-bytes
  |=  [value=@ count=@ud]
  ^-  @t
  =/  alphabet=@t  '0123456789abcdef'
  =/  index=@ud  0
  =/  out=tape  ~
  |-
  ?:  =(index count)  (crip (flop out))
  =/  byte=@ud  (cut 3 [index 1] value)
  =/  high=@tD  (cut 3 [(div byte 16) 1] alphabet)
  =/  low=@tD  (cut 3 [(mod byte 16) 1] alphabet)
  $(index +(index), out [low high out])
::
::  a grant's signature (D5): over the jam of the recipient, the attempt,
::  the operation 'grant:<name>', the expiry in unix seconds and a
::  nonce.  until the signing key exists (the signing stage) the
::  signature is 0; the daemon starts verifying when the key does.
::
++  sign-grant
  |=  [recipient=daemon-id:ci attempt=attempt-id:ci name=@t expiry=@da =manifest:ci-provenance]
  ^-  grant:ci
  =/  nonce=@uv  (fresh-nonce [%grant recipient attempt name])
  [name expiry nonce (sign-authorization recipient attempt (cat 3 'grant:' name) expiry nonce manifest)]
::
++  credential-names
  |=  repo=@t
  ^-  (list [name=@t scope=?(%job %env) envs=(set @t) created=@da])
  %+  murn  ~(tap by credentials)
  |=  [[r=@t name=@t] c=credential:ci]
  ?.  =(r repo)  ~
  `[name scope.c envs.c created.c]
::
::  the values released for a repository: what the ship scrubs from
::  every event text it keeps
::
++  credential-values
  |=  repo=@t
  ^-  (list @t)
  %-  zing
  %+  murn  ~(tap by credentials)
  |=  [[r=@t name=@t] c=credential:ci]
  ^-  (unit (list @t))
  ?.  =(r repo)  ~
  `(scrub-forms:ci-event value.c)
::
++  attempt-json
  |=  =attempt:ci
  ^-  json
  =/  candidate-status=@t
    =/  found=(unit candidate:ci)  (~(get by candidates) candidate.attempt)
    ?~(found 'unknown' status.u.found)
  %-  pairs:enjs:format
  :~  ['attempt' s+(scot %uv id.attempt)]
      ['status' s+status.attempt]
      ['kind' s+kind.attempt]
      ['workflow' ?~(workflow.attempt ~ s+u.workflow.attempt)]
      ['job' ?~(job.attempt ~ s+u.job.attempt)]
      ['events' (numb:enjs:format events.attempt)]
      ['job-result' ?~(job-result.attempt ~ s+u.job-result.attempt)]
      ['reason' ?~(reason.attempt ~ s+u.reason.attempt)]
      ['projection-name' ?~(projection-name.attempt ~ s+u.projection-name.attempt)]
      ['trust' s+trust.attempt]
      ['log' (object-ref-json log.attempt)]
      ['candidate' s+(scot %uv candidate.attempt)]
      ['candidate-status' s+candidate-status]
      ['generation' (numb:enjs:format generation.attempt)]
      ['mode' s+mode.attempt]
      ['manifest' s+(scot %uv manifest.attempt)]
      ['sandbox' s+sandbox.attempt]
      ['network' s+network.attempt]
      ['approval' ?~(approval.attempt ~ s+(scot %uv u.approval.attempt))]
      ['outcome' s+outcome.attempt]
      ['pinned' (pinned-json pinned.attempt)]
  ==
::
++  object-ref-json
  |=  ref=(unit object-ref:ci)
  ^-  json
  ?~  ref  ~
  %-  pairs:enjs:format
  :~  ['key' s+key.u.ref]
      ['size' (numb:enjs:format size.u.ref)]
      ['sha256' s+sha256.u.ref]
  ==
::
::  the object key an attempt's upload lands under: the attempt's own
::  trust class, never the daemon's choice (D2)
::
++  attempt-object-key
  |=  [=attempt:ci name=@t]
  ^-  @t
  %:  object-key:ci-storage
    (candidate-repo candidate.attempt)
    (scot %uv candidate.attempt)
    (scot %uv id.attempt)
    trust.attempt
    name
  ==
::
::  a presigned download link for one of an attempt's objects, in the
::  attempt's own trust class only (D2)
::
++  presign-log
  |=  [=attempt:ci =trust:ci name=@t expires=@dr]
  ^-  (unit @t)
  %:  presign-get:ci-storage
    (read-settings:ci-storage our.bowl now.bowl)
    trust.attempt
    (candidate-repo candidate.attempt)
    (scot %uv candidate.attempt)
    (scot %uv id.attempt)
    trust
    name
    expires
    now.bowl
  ==
::
::
::  ---- automatic events and schedules (Delivery 1C) ----
::
::  the forge events kept per repository, newest first, and the event ids
::  kept as the replay guard (the oldest thousand go past the bound)
::
++  max-forge-events  200
++  max-event-ids  10.000
::
::  %urgit's reads for events: the default branch, the changed paths of a
::  push and of a pull request (lib/ci-changes over %urgit's own objects),
::  and a native pull request's record.  ~ means %urgit could not be read
::
++  default-ref
  |=  repo=@t
  ^-  (unit (unit @t))
  =/  raw=(unit *)  (urgit-peek /ci-head/(scot %t repo))
  ?~  raw  ~
  =/  got=(each (unit @t) tang)  (mule |.(;;((unit @t) u.raw)))
  ?.(?=(%& -.got) ~ `p.got)
::
++  push-evidence
  |=  [repo=@t ref=@t old=(unit oid:git) new=oid:git]
  ^-  evidence:ci-trigger
  =/  from=@t  ?~(old '' (oid-text:git-codec u.old))
  %-  evidence-of
  %-  urgit-peek
  /ci-push-changes/(scot %t repo)/(scot %t ref)/(scot %t from)/(scot %t (oid-text:git-codec new))
::
++  pull-evidence
  |=  [repo=@t head=oid:git target=oid:git]
  ^-  evidence:ci-trigger
  %-  evidence-of
  %-  urgit-peek
  /ci-pull-changes/(scot %t repo)/(scot %t (oid-text:git-codec head))/(scot %t (oid-text:git-codec target))
::
++  evidence-of
  |=  raw=(unit *)
  ^-  evidence:ci-trigger
  ?~  raw  [%| '%urgit cannot be read for the changed paths']
  =/  got=(each (unit (each (list @t) @t)) tang)
    (mule |.(;;((unit (each (list @t) @t)) u.raw)))
  ?.  ?=(%& -.got)  [%| '%urgit answered the changed paths in a shape this agent does not read']
  ?~  p.got  [%| 'the repository is not in %urgit']
  u.p.got
::
++  pull-record
  |=  [repo=@t number=@ud]
  ^-  (unit (unit native-pull:git))
  =/  raw=(unit *)  (urgit-peek /ci-pull/(scot %t repo)/(scot %ud number))
  ?~  raw  ~
  =/  got=(each (unit native-pull:git) tang)  (mule |.(;;((unit native-pull:git) u.raw)))
  ?.(?=(%& -.got) ~ `p.got)
::
::  the promoted baseline that governs a ref's events and its lock's
::  catalog, or why there is none: no baseline, no workflows, a lock not
::  on this ship, or a lock resolved before triggers (unknown: nothing runs
::  automatically, never an empty catalog)
::
++  governing
  |=  [repo=@t ref=@t]
  ^-  (each [=baseline:ci =lock:ci catalog=trigger-catalog:ci] @t)
  =/  base=(unit baseline:ci)  (~(get by baselines) [repo ref])
  ?~  base
    [%| (rap 3 ~['no promoted baseline governs ' ref ': nothing runs (promote one in Settings → CI policy)'])]
  ?~  lock.u.base  [%| (rap 3 ~['the promoted baseline of ' ref ' has no workflows'])]
  =/  found=(unit lock:ci)  (~(get by locks) u.lock.u.base)
  ?~  found
    [%| 'the baseline\'s lock is not on this ship: resolve and promote the revision again']
  ?~  triggers.u.found
    :-  %|
    %+  rap  3
    :~  'the baseline of '  ref
        ' was resolved before trigger definitions were read: its events are unknown, '
        'and nothing runs automatically until its revision is resolved and promoted again'
    ==
  [%& u.base u.found u.triggers.u.found]
::
::  a forge event recorded: at most max-forge-events per repository kept
::
++  record-forge-event
  |=  e=forge-event:ci
  ^-  _forge-events
  =.  forge-events  (~(put by forge-events) id.e e)
  =/  mine=(list forge-event:ci)
    %+  sort
      (skim ~(val by forge-events) |=(f=forge-event:ci =(repo.f repo.e)))
    |=([a=forge-event:ci b=forge-event:ci] (gth received.a received.b))
  ?:  (lte (lent mine) max-forge-events)  forge-events
  %+  roll  (slag max-forge-events mine)
  |=  [f=forge-event:ci acc=_forge-events]
  (~(del by acc) id.f)
::
++  remember-id
  |=  id=@uv
  ^-  _event-ids
  =.  event-ids  (~(put by event-ids) id now.bowl)
  ?:  (lte ~(wyt by event-ids) max-event-ids)  event-ids
  =/  newest=(list [@uv @da])
    (sort ~(tap by event-ids) |=([a=[@uv @da] b=[@uv @da]] (gth +.a +.b)))
  (malt (scag (sub max-event-ids 1.000) newest))
::
::  an event run's record: a fresh candidate of mode %event bound to the
::  current policy of its ref, its object (the pushed tip, a merge's
::  result, a schedule's tip; ~ while a pull request's integration object
::  is built), its trigger and selection
::
++  event-candidate
  |=  $:  id=candidate-id:ci  repo=@t  ref=@t  head=oid:git  base=oid:git
          actor=@p  route=@t  =trust:ci  pull=(unit @ud)  e=run-event:ci
          sel=event-selection:ci  object=(unit oid:git)
      ==
  ^-  candidate:ci
  =/  =via:ci  ?:(=('smart-http push (write token)' route) %token %session)
  =/  c=candidate:ci
    (fresh-candidate id repo ref head base actor via trust pull %event ~)
  c(candidate object, trigger [%event e], selected `sel)
::
::  the candidate that landed an object on a protected ref, if any
::
++  landed-by
  |=  [repo=@t ref=@t object=oid:git]
  ^-  (unit candidate-id:ci)
  =/  hits=(list candidate:ci)
    %+  skim  ~(val by candidates)
    |=  c=candidate:ci
    ?&  =(repo repo.c)  =(ref ref.c)  =(`object candidate.c)
        =(`'landed' verdict-reason.c)
    ==
  ?~(hits ~ `id.i.hits)
::
::  what a selection that ran nothing says
::
++  no-run-outcome
  |=  [event=@t outcomes=(list workflow-selection:ci)]
  ^-  @t
  ?~  outcomes
    (rap 3 ~['no workflow of the governing baseline triggers on ' event])
  %+  rap
    3
  ~['no workflow selected (' (crip (a-co:co (lent outcomes))) ' declare ' event '; see each reason)']
::
::  what a push's selection compared
::
++  push-basis
  |=  [ref=@t old=(unit oid:git) new=oid:git changes=(unit evidence:ci-trigger)]
  ^-  @t
  %+  rap  3
  :~  'push to '  ref  ': '
      ?~  old
        %+  rap
          3
        ~['a new ref at ' (oid-text:git-codec new) ', against the commits it brought']
      (rap 3 ~[(oid-text:git-codec u.old) '..' (oid-text:git-codec new) ' (two-dot)'])
      (evidence-text changes)
  ==
::
::  a pull request activity as the records name it: a label change names
::  its label
::
++  pull-activity
  |=  p=pull-update:ci
  ^-  @t
  ?~  label.p  action.p
  (rap 3 ~[action.p ' ' u.label.p])
::
++  pull-basis
  |=  [p=pull-update:ci target=oid:git changes=(unit evidence:ci-trigger)]
  ^-  @t
  %+  rap  3
  :~  'pull request #'  (crip (a-co:co number.p))  ' '  (pull-activity p)  ': head '
      (oid-text:git-codec head.p)  ' into '  target-ref.p  ' at '
      (oid-text:git-codec target)  ' (three-dot, from the merge base)'
      (evidence-text changes)
  ==
::
++  evidence-text
  |=  changes=(unit evidence:ci-trigger)
  ^-  @t
  ?~  changes  ''
  ?:  ?=(%| -.u.changes)  (rap 3 ~['; changed paths unavailable: ' p.u.changes])
  (rap 3 ~['; ' (crip (a-co:co (lent p.u.changes))) ' changed path(s)'])
::
::  the reason a blocked required run stays blocked
::
++  absent-evidence
  |=  missing=(list workflow-selection:ci)
  ^-  @t
  %+  rap  3
  :~  'required evidence absent: '
      %+  join:ci-plan
        %+  turn  missing
        |=  o=workflow-selection:ci
        (rap 3 ~[workflow.o ' was not selected (' reason.o ')'])
      '; '
      '; no attempt stands for it, the ref stays blocked, and only a recorded override lands it'
  ==
::
::  a required push's selection at its plan: the baseline's catalog and the
::  push's own changed paths, its base to the object it would land.  with
::  no catalog (a lock resolved before triggers) every push workflow plans
::  as before and the selection says the filters were not evaluated
::
++  required-push-selection
  |=  [c=candidate:ci object=oid:git]
  ^-  event-selection:ci
  =/  gov  (governing repo.c ref.c)
  ?:  ?=(%| -.gov)
    :+  (push-basis ref.c `base.c object ~)
      ~
    `(rap 3 ~['filters not evaluated, every push workflow runs as before: ' p.gov])
  =/  cat=trigger-catalog:ci  catalog.p.gov
  =/  changes=(unit evidence:ci-trigger)
    ?.  (push-needs-paths:ci-trigger cat ref.c)  ~
    `(push-evidence repo.c ref.c `base.c object)
  [(push-basis ref.c `base.c object changes) (select-push:ci-trigger cat ref.c changes) ~]
::
::  every report of one %urgit event
::
++  admit-forge-events
  |=  act=action:ci
  ^-  out
  ?>  ?=(%forge-events -.act)
  ::  a repository CI was never configured for records nothing, and a
  ::  resolver's mirror repository is dependency maintenance, never a
  ::  source of workflow events
  ?.  (~(has by incarnations) repo.act)  (emit ~)
  ?:  (mirror-repository repo.act)  (emit ~)
  ::  CI-RECOVERY-1: the checkpoint repository is recovery storage, never
  ::  a source of workflow events.  while CI is paused an event is
  ::  recorded and remembered, and runs nothing, now or later
  ?:  =(repository:ci-checkpoint repo.act)  (emit ~)
  ?:  ci-paused  (paused-events act)
  ::  each fold's product is cast to [(list card) _state]: its accumulator
  ::  names its head (cards=), and a list that keeps that face cannot be
  ::  welded (weld's homo reads i.b through the formal (list) faces only)
  =^  ref-cards  state
    ^-  [(list card) _state]
    %+  roll  refs.act
    |=  [u=ref-update:ci acc=[cards=(list card) =_state]]
    =.  state  state.acc
    =^  more  state  (admit-push repo.act u actor.act route.act at.act)
    [(weld cards.acc more) state]
  =^  pull-cards  state
    ^-  [(list card) _state]
    %+  roll  pulls.act
    |=  [p=pull-update:ci acc=[cards=(list card) =_state]]
    =.  state  state.acc
    =^  more  state  (admit-pull repo.act p actor.act route.act at.act)
    [(weld cards.acc more) state]
  ::  a default-branch move registers the schedules again from the new
  ::  branch's baseline, and is recorded (its id is the move's facts and
  ::  instant, so a redelivery records it once)
  =^  timers  state
    ?~  head.act  [~ state]
    =/  moved=@t  (rap 3 ~['the default branch moved from ' old.u.head.act ' to ' new.u.head.act])
    =^  cards  state  (register-schedules repo.act moved)
    =.  forge-events
      %-  record-forge-event
      :*  (sham [%ci-default-branch-event repo.act old.u.head.act new.u.head.act at.act])
          repo.act  %default-branch  new.u.head.act  ~  ~  ~  actor.act  route.act
          at.act  now.bowl  (rap 3 ~['recorded: ' moved '; its schedules were registered again'])
          ~  ~
      ==
    [cards state]
  =/  scheduled=out  schedule
  [:(weld ref-cards pull-cards timers cards.scheduled) state.scheduled polls.scheduled]
::
::  a ref move %urgit reported, checked against the ref now: still at the
::  reported tip (or gone, for a deletion)
::
++  verify-push
  |=  [repo=@t u=ref-update:ci]
  ^-  (each ~ @t)
  =/  tip=(unit (unit [tip=oid:git linked=?]))  (ref-tip repo ref.u)
  ?~  tip  [%| '%urgit cannot be read, so the ref cannot be checked']
  ?~  new.u
    ?~  u.tip  [%& ~]
    [%| (rap 3 ~['the event deletes ' ref.u ', which is at ' (oid-text:git-codec tip.u.u.tip) ' now: stale'])]
  ?~  u.tip  [%| (rap 3 ~[ref.u ' has no tip now: the event is stale'])]
  ?:  =(u.new.u tip.u.u.tip)  [%& ~]
  :-  %|
  %+  rap  3
  :~  ref.u  ' is at '  (oid-text:git-codec tip.u.u.tip)  ', not the event\'s '
      (oid-text:git-codec u.new.u)  ': stale, or not what the forge persisted'
  ==
::
::  one push: recorded with its outcome, and run when the governing
::  catalog selects a workflow for it
::
::  Tagged-revision authority is explicit. Historical promoted tag runs
::  do not acquire it on upgrade.
++  tagged-run
  |=  c=candidate:ci
  ^-  ?
  (~(has by tag-runs) id.c)
::
++  tag-commit
  |=  [repo=@t object=oid:git]
  ^-  (each oid:git @t)
  =/  raw=(unit *)
    (urgit-peek /ci-tag-commit/(scot %t repo)/(scot %t (oid-text:git-codec object)))
  ?~  raw  [%| '%urgit cannot be read for the tag target']
  =/  got=(each (unit (each oid:git @t)) tang)
    (mule |.(;;((unit (each oid:git @t)) u.raw)))
  ?.  ?=(%& -.got)  [%| '%urgit returned an unreadable tag target']
  ?~  p.got  [%| 'the tag repository is unavailable']
  u.p.got
::
::  Verify the ref before this arm. From admission onward, use only the
::  captured commit, actor, event payload and exact resolver attempt.
++  admit-tag
  |=  [e=forge-event:ci object=oid:git]
  ^-  [(list card) _state]
  =/  id=candidate-id:ci  (sham [%ci-event-run id.e])
  ?:  (~(has by candidates) id)  [~ state]
  =/  peeled=(each oid:git @t)  (tag-commit repo.e object)
  ?:  ?=(%| -.peeled)
    [~ state(forge-events (record-forge-event e(outcome (rap 3 ~['refused: ' p.peeled]))))]
  =/  writable=(unit ?)  (can-write repo.e actor.e)
  ?~  writable
    [~ state(forge-events (record-forge-event e(outcome 'refused: the tag actor cannot be classified')))]
  =/  waiting=@ud
    %-  lent
    %+  skim  ~(val by candidates)
    |=  c=candidate:ci
    ?&((tagged-run c) =(repo.e repo.c) =(%pending status.c) ?=(~ selected.c))
  ?:  (gte waiting max-forge-events)
    [~ state(forge-events (record-forge-event e(outcome 'refused: too many tag resolutions are pending')))]
  =/  payload=@t
    %:  push-event-payload:ci-trigger
      repo.e  ref.e  before.e  p.peeled  actor.e  (fall (default-ref repo.e) ~)
    ==
  =/  event=run-event:ci
    [id.e %push ref.e before.e after.e ~ ~ actor.e route.e at.e payload]
  =/  run=candidate:ci
    %:  event-candidate
      id  repo.e  ref.e  p.peeled  p.peeled  actor.e  route.e
      ?:(u.writable %trusted %untrusted)  ~  event  *event-selection:ci  `p.peeled
    ==
  =.  run
    run(baseline `p.peeled, lock ~, selected ~, verdict-reason `'pending: resolving tagged revision workflows')
  =.  candidates  (~(put by candidates) id run)
  =.  tag-runs  (~(put by tag-runs) id ~)
  =.  input-snapshots
    (~(put by input-snapshots) id (~(gut by automatic-inputs) repo.e ~))
  =.  forge-events
    (record-forge-event e(outcome 'pending: resolving tagged revision workflows', runs ~[id]))
  =/  cached=(unit lock:ci)  (cached-lock:ci-tag locks repo.e p.peeled)
  =?  state  ?=(^ cached)  (bind-tag-lock id u.cached)
  =.  audit
    %:  record-audit
      actor.e
      'tag-event-admitted'
      repo.e
      (rap 3 ~[ref.e ' at ' (oid-text:git-codec p.peeled)])
    ==
  ::  Keep the source reachable during resolution, including ref deletion.
  ?.  =(%pending status:(~(got by candidates) id))  [~ state]
  :_  state
  ~[(urgit-git-poke /scratch/(scot %uv id) [%set-ref repo.e (scratch-ref run) p.peeled])]
::
++  note-tag-event
  |=  [c=candidate:ci why=@t]
  ^-  _forge-events
  ?.  ?=(%event -.trigger.c)  forge-events
  =/  found=(unit forge-event:ci)  (~(get by forge-events) id.run-event.trigger.c)
  ?~  found  forge-events
  %-  record-forge-event
  %=  u.found
    outcome  why
    selected  selected.c
    runs  ?:(?=(^ (find ~[id.c] runs.u.found)) runs.u.found (snoc runs.u.found id.c))
  ==
::
++  fail-tag
  |=  [c=candidate:ci why=@t]
  ^-  _state
  =/  reason=@t  (rap 3 ~['refused: tagged revision resolution: ' why])
  =.  candidates
    (~(put by candidates) id.c c(status %failed, verdict-reason `reason, updated now.bowl))
  =.  forge-events  (note-tag-event c reason)
  state
::
++  bind-tag-lock
  |=  [id=candidate-id:ci l=lock:ci]
  ^-  _state
  =/  c=candidate:ci  (~(got by candidates) id)
  ?.  ?&((tagged-run c) =(%pending status.c) ?=(~ selected.c))  state
  =/  bound=(each candidate:ci @t)  (bind-lock:ci-tag c l)
  ?:  ?=(%| -.bound)  (fail-tag c p.bound)
  =/  next=candidate:ci  p.bound(updated now.bowl)
  =.  candidates  (~(put by candidates) id next)
  =/  why=@t
    ?^  verdict-reason.next  u.verdict-reason.next
    (rap 3 ~['tagged revision workflows selected: run ' (scot %uv id)])
  =.  forge-events  (note-tag-event next why)
  state
::
::  Only the lock returned by the captured attempt can complete admission.
::  A resolved but excluded/refused tag has no job to release its source.
++  tag-resolve-releases
  |=  attempt=attempt-id:ci
  ^-  (list card)
  %+  murn  ~(tap by tag-runs)
  |=  [id=candidate-id:ci resolver=(unit attempt-id:ci)]
  ^-  (unit card)
  ?.  =(`attempt resolver)  ~
  =/  c=(unit candidate:ci)  (~(get by candidates) id)
  ?~  c  ~
  ?:  =(%pending status.u.c)  ~
  `(urgit-git-poke /release/(scot %uv id) [%delete-ref repo.u.c (scratch-ref u.c)])
::
++  complete-tag-resolve
  |=  [attempt=attempt-id:ci l=lock:ci]
  ^-  _state
  %+  roll  ~(tap by tag-runs)
  |=  [[id=candidate-id:ci resolver=(unit attempt-id:ci)] acc=_state]
  =.  state  acc
  ?.  (accepts:ci-resolve state id attempt)  state
  (bind-tag-lock id l)
::
::  A missing resolver waits durably. Its next poll/enrollment resumes the
::  same revision. Failure closes the run explicitly, without a new input.
++  advance-tags
  ^-  out
  =/  pending=(list candidate-id:ci)
    %+  murn  ~(val by candidates)
    |=  c=candidate:ci
    ?:(?&((tagged-run c) (waiting:ci-resolve c)) `id.c ~)
  =|  cards=(list card)
  |-
  ?~  pending  (emit cards)
  ::  Read current bindings: a preceding twin may have rebound this run.
  =/  c=candidate:ci  (~(got by candidates) i.pending)
  =/  decision  (next:ci-resolve state c)
  ?:  ?=(%running -.decision)  $(pending t.pending)
  ?:  ?=(%failed -.decision)
    =.  state  (fail-tag c why.decision)
    %=  $
      pending  t.pending
      cards  %+  snoc
               cards
             (urgit-git-poke /release/(scot %uv id.c) [%delete-ref repo.c (scratch-ref c)])
    ==
  =/  chosen=(unit daemon-id:ci)
    (select-resolver-excluding repo.c exclude.decision)
  ?~  chosen
    =/  why=@t
      ?~  record.decision
        'pending: tagged revision waits for a live resolver-capable runner'
      'pending: tagged revision resolver was re-offered; waiting for another eligible runner'
    =.  candidates  (note-wait c why)
    =.  forge-events  (note-tag-event c why)
    $(pending t.pending)
  ::  Reuse the synthetic record on reoffer. Its history/exclusions and
  ::  source retention stay intact. The event marker authenticates purpose.
  =/  rid=candidate-id:ci
    (fall record.decision (sham [%ci-tag-resolve id.c]))
  =/  record=candidate:ci
    ?^  record.decision  (~(got by candidates) rid)
    =/  fresh=candidate:ci
      %:  fresh-candidate
        rid  repo.c  'refs/ci/resolve'  head.c  head.c
        actor.c  via.c  trust.c  ~  %shadow  ~
      ==
    %=  fresh
      candidate  `head.c
      baseline  ~
      lock  ~
      trigger  trigger.c
      generation  generation.c
      incarnation  incarnation.c
    ==
  =.  candidates  (~(put by candidates) rid record)
  =.  input-snapshots
    (~(put by input-snapshots) rid (captured:ci-input state id.c))
  =^  made  state  (create-attempt rid u.chosen %resolve ~ ~ resolve-deadline ~)
  =.  state  (bind-attempt:ci-resolve state c -.made)
  =/  restores=(list card)
    ?^  record.decision  ~
    ~[(urgit-git-poke /scratch/(scot %uv rid) [%set-ref repo.c (scratch-ref record) head.c])]
  =/  delivered=out  (deliver u.chosen)
  =.  state  state.delivered
  =.  polls  polls.delivered
  $(pending t.pending, cards :(weld cards restores ~[timer.made] cards.delivered))
::
++  admit-push
  |=  [repo=@t u=ref-update:ci actor=@p route=@t at=@da]
  ^-  [(list card) _state]
  ?:  (~(has by event-ids) id.u)  [~ state]
  ?:  (~(has by tag-runs) (sham [%ci-event-run id.u]))  [~ state]
  =.  event-ids  (remember-id id.u)
  =/  base=forge-event:ci
    [id.u repo %push ref.u old.u new.u ~ actor route at now.bowl '' ~ ~]
  =/  checked=(each ~ @t)  (verify-push repo u)
  ?:  ?=(%| -.checked)
    [~ state(forge-events (record-forge-event base(outcome (rap 3 ~['refused: ' p.checked]))))]
  ?~  new.u
    =/  why=@t  'recorded: a deletion runs no workflow (the delete event is not implemented)'
    [~ state(forge-events (record-forge-event base(outcome why)))]
  ?:  (~(has in ci-protected) [repo ref.u])
    =/  landed=(unit candidate-id:ci)  (landed-by repo ref.u u.new.u)
    =/  why=@t
      %+  rap  3
      :~  'recorded: a CI-protected ref moves only by landing, so its push ran as '
          'the required candidate before it moved; nothing runs again'
      ==
    [~ state(forge-events (record-forge-event base(outcome why, runs ?~(landed ~ ~[u.landed]))))]
  ?:  (tag-ref:ci-tag ref.u)  (admit-tag base u.new.u)
  =/  gov  (governing repo ref.u)
  ?:  ?=(%| -.gov)  [~ state(forge-events (record-forge-event base(outcome p.gov)))]
  =/  cat=trigger-catalog:ci  catalog.p.gov
  =/  changes=(unit evidence:ci-trigger)
    ?.  (push-needs-paths:ci-trigger cat ref.u)  ~
    `(push-evidence repo ref.u old.u u.new.u)
  =/  outcomes=(list workflow-selection:ci)  (select-push:ci-trigger cat ref.u changes)
  =/  sel=event-selection:ci  [(push-basis ref.u old.u u.new.u changes) outcomes ~]
  =/  chosen=(list @t)  (selected-workflows:ci-trigger outcomes)
  ?~  chosen
    [~ state(forge-events (record-forge-event base(outcome (no-run-outcome 'push' outcomes), selected `sel)))]
  =/  writable=(unit ?)  (can-write repo actor)
  ?~  writable
    =/  why=@t  'refused: %urgit cannot be read, so the actor cannot be classified'
    [~ state(forge-events (record-forge-event base(outcome why, selected `sel)))]
  =/  id=candidate-id:ci  (sham [%ci-event-run id.u])
  =/  default=(unit @t)  (fall (default-ref repo) ~)
  =/  payload=@t  (push-event-payload:ci-trigger repo ref.u old.u u.new.u actor default)
  =/  e=run-event:ci  [id.u %push ref.u old.u new.u ~ ~ actor route at payload]
  =/  =trust:ci  ?:(u.writable %trusted %untrusted)
  =/  run=candidate:ci
    (event-candidate id repo ref.u u.new.u (fall old.u u.new.u) actor route trust ~ e sel new.u)
  =.  candidates  (~(put by candidates) id run)
  =/  why=@t
    (rap 3 ~[(crip (a-co:co (lent chosen))) ' workflow(s) selected: run ' (scot %uv id)])
  =.  forge-events  (record-forge-event base(outcome why, selected `sel, runs ~[id]))
  =.  audit
    %:  record-audit
      actor
      'event-run'
      repo
      (rap 3 ~['push to ' ref.u ' → run ' (scot %uv id)])
    ==
  :_  state
  ~[(urgit-git-poke /scratch/(scot %uv id) [%set-ref repo (scratch-ref run) u.new.u])]
::
::  a pull request transition %urgit reported, checked against the
::  record now: present, in the state the activity leaves it in, at the
::  reported head.  a label change leaves the state it reports, and its
::  label is on the record now (labeled) or off it (unlabeled): a later
::  edit that undid it makes this one stale
::
++  verify-pull
  |=  [repo=@t p=pull-update:ci]
  ^-  (each ~ @t)
  =/  found=(unit (unit native-pull:git))  (pull-record repo number.p)
  ?~  found  [%| '%urgit cannot be read, so the pull request cannot be checked']
  ?~  u.found
    [%| (rap 3 ~['pull request #' (crip (a-co:co number.p)) ' is not in the repository'])]
  =/  stale=(unit @t)  (pull-stale:ci-forge p u.u.found)
  ?^  stale  [%| u.stale]
  [%& ~]
::
::  one pull request activity: recorded with its outcome, and run when
::  the target branch's catalog selects a workflow for it.  the run tests
::  the head merged onto the target's tip (%urgit builds it under the
::  run's own scratch ref), or for a merged close the target's tip after
::  the merge; its paths are three-dot from the merge base
::
++  admit-pull
  |=  [repo=@t p=pull-update:ci actor=@p route=@t at=@da]
  ^-  [(list card) _state]
  ?:  (~(has by event-ids) id.p)  [~ state]
  =.  event-ids  (remember-id id.p)
  =/  now-tip=(unit oid:git)
    =/  tip=(unit (unit [tip=oid:git linked=?]))  (ref-tip repo target-ref.p)
    ?~  tip  ~
    ?~  u.tip  ~
    `tip.u.u.tip
  ::  the tip the run integrates onto, and the target side of its diff
  =/  onto=(unit oid:git)  ?:(merged.p target-before.p now-tip)
  =/  facts=pull-facts:ci
    :*  number.p  title.p  action.p  head.p  source-ref.p  target-ref.p
        (fall onto base.p)  merged.p  source-ship.p  source-repository.p
        labels.p  label.p
    ==
  =/  base=forge-event:ci
    [id.p repo %pull-request target-ref.p ~ `head.p `facts actor route at now.bowl '' ~ ~]
  ::  a malformed update is refused with the reason, never read another
  ::  way: a missing label is not "no labels"
  =/  malformed=(unit @t)  (pull-update-error:ci-forge p)
  ?^  malformed
    =/  why=@t  (rap 3 ~['refused: a malformed pull request update: ' u.malformed])
    [~ state(forge-events (record-forge-event base(outcome why)))]
  =/  checked=(each ~ @t)  (verify-pull repo p)
  ?:  ?=(%| -.checked)
    [~ state(forge-events (record-forge-event base(outcome (rap 3 ~['refused: ' p.checked]))))]
  ::  a label change on a closed or merged pull request is recorded and
  ::  runs nothing
  =/  inert=(unit @t)  (label-outcome:ci-trigger p)
  ?^  inert
    [~ state(forge-events (record-forge-event base(outcome u.inert)))]
  ?~  onto
    =/  why=@t  (rap 3 ~['refused: the target branch ' target-ref.p ' has no tip to test against'])
    [~ state(forge-events (record-forge-event base(outcome why)))]
  ?:  ?&(merged.p ?=(~ now-tip))
    =/  why=@t  (rap 3 ~['refused: the target branch ' target-ref.p ' has no tip after the merge'])
    [~ state(forge-events (record-forge-event base(outcome why)))]
  =/  gov  (governing repo target-ref.p)
  ?:  ?=(%| -.gov)  [~ state(forge-events (record-forge-event base(outcome p.gov)))]
  =/  cat=trigger-catalog:ci  catalog.p.gov
  =/  changes=(unit evidence:ci-trigger)
    ?.  (pull-needs-paths:ci-trigger cat action.p target-ref.p)  ~
    `(pull-evidence repo head.p u.onto)
  =/  outcomes=(list workflow-selection:ci)
    (select-pull:ci-trigger cat action.p target-ref.p changes)
  =/  note=(unit @t)
    ?:  (~(has in native-pull-types:ci-trigger) action.p)  ~
    `(rap 3 ~['activity ' action.p ' has no native source in this forge'])
  =/  sel=event-selection:ci  [(pull-basis p u.onto changes) outcomes note]
  =/  chosen=(list @t)  (selected-workflows:ci-trigger outcomes)
  ?~  chosen
    =/  why=@t  (no-run-outcome 'pull_request' outcomes)
    [~ state(forge-events (record-forge-event base(outcome why, selected `sel)))]
  ::  the pull request's author decides the trust class (D3): a ship that
  ::  cannot write the repository runs untrusted, and waits for a writer's
  ::  approval unless the repository runs restricted checks
  =/  writable=(unit ?)  (can-write repo source-ship.p)
  ?~  writable
    =/  why=@t  'refused: %urgit cannot be read, so the author cannot be classified'
    [~ state(forge-events (record-forge-event base(outcome why, selected `sel)))]
  =/  id=candidate-id:ci  (sham [%ci-event-run id.p])
  =/  default=(unit @t)  (fall (default-ref repo) ~)
  =/  payload=@t  (pull-event-payload:ci-trigger repo facts actor default)
  =/  e=run-event:ci  [id.p %pull-request target-ref.p ~ `head.p `facts ~ actor route at payload]
  =/  =trust:ci  ?:(u.writable %trusted %untrusted)
  =/  object=(unit oid:git)  ?:(merged.p now-tip ~)
  =/  run=candidate:ci
    %:  event-candidate
      id  repo  target-ref.p  head.p  ?:(merged.p (need now-tip) u.onto)  actor  route
      trust  `number.p  e  sel  object
    ==
  =.  candidates  (~(put by candidates) id run)
  =/  why=@t
    (rap 3 ~[(crip (a-co:co (lent chosen))) ' workflow(s) selected: run ' (scot %uv id)])
  =.  forge-events  (record-forge-event base(outcome why, selected `sel, runs ~[id]))
  =.  audit
    %:  record-audit  actor  'event-run'  repo
      (rap 3 ~['pull request #' (crip (a-co:co number.p)) ' ' (pull-activity p) ' → run ' (scot %uv id)])
    ==
  :_  state
  :_  ~
  ?^  object
    (urgit-git-poke /scratch/(scot %uv id) [%set-ref repo (scratch-ref run) u.object])
  (urgit-poke /materialize/(scot %uv id) [%materialize-run id repo target-ref.p head.p u.onto])
::
::  a pull request run's integration object, built by %urgit under the
::  run's own scratch ref
::
++  run-ready
  |=  [id=candidate-id:ci object=oid:git]
  ^-  out
  =/  found=(unit candidate:ci)  (~(get by candidates) id)
  ?~  found  (emit ~)
  ?.  ?=(%event -.trigger.u.found)  (emit ~)
  ?^  candidate.u.found  (emit ~)
  =.  candidates  (~(put by candidates) id u.found(candidate `object, updated now.bowl))
  schedule
::
::  a head that cannot be merged onto its target runs nothing (GitHub
::  runs no pull_request workflow on a conflicted pull request either)
::
++  run-conflict
  |=  [id=candidate-id:ci reason=@t]
  ^-  out
  =/  found=(unit candidate:ci)  (~(get by candidates) id)
  ?~  found  (emit ~)
  ?.  ?=(%event -.trigger.u.found)  (emit ~)
  =/  why=@t
    (rap 3 ~['not run: the pull request cannot be merged onto its target (' reason ')'])
  =.  candidates
    %+  ~(put by candidates)  id
    u.found(conflict %.y, status %failed, verdict-reason `why, updated now.bowl)
  (emit ~)
::
::  ---- schedules ----
::
++  timer-wire
  |=  [k=schedule-key:ci due=@da definition=@uv]
  ^-  wire
  :~  %schedule  (scot %t repo.k)  (scot %t workflow.k)  (scot %ud index.k)
      (scot %ud (unix:ci-cron due))  (scot %uv definition)
  ==
::
++  timer-card
  |=  [k=schedule-key:ci due=@da definition=@uv]
  ^-  card
  [%pass (timer-wire k due definition) %arvo %b %wait due]
::
::  the wake of every active schedule, set again (on-load)
::
++  rearm-cards
  ^-  (list card)
  %+  murn  ~(tap by schedules)
  |=  [k=schedule-key:ci e=schedule-entry:ci]
  ^-  (unit card)
  ?.  ?&(=(%active state.e) ?=(^ armed.e))  ~
  `(timer-card k u.armed.e definition.e)
::
::  the schedules a default branch's catalog defines now, each a new entry
::  armed at its first occurrence after now (never earlier: no catch-up);
::  a refused entry, or a refused schedule event, is listed refused
::
++  catalog-schedules
  |=  [repo=@t ref=@t gov=[=baseline:ci =lock:ci catalog=trigger-catalog:ci]]
  ^-  (list [k=schedule-key:ci e=schedule-entry:ci])
  %-  zing
  %+  turn  workflows.catalog.gov
  |=  w=trigger-workflow:ci
  ^-  (list [k=schedule-key:ci e=schedule-entry:ci])
  ?^  refusal.w  ~
  =/  ev=(unit trigger-event:ci)  (event-of:ci-trigger w 'schedule')
  ?~  ev  ~
  =/  defs=(list schedule-def:ci)
    ?~  refusal.u.ev  schedules.u.ev
    ~[['' ~ refusal.u.ev ~]]
  =/  i=@ud  0
  =|  out=(list [k=schedule-key:ci e=schedule-entry:ci])
  |-
  ?~  defs  (flop out)
  =/  zone=(unit zone:ci)
    ?~  timezone.i.defs  ~
    (~(get by zones.catalog.gov) u.timezone.i.defs)
  =/  definition=@uv
    %-  sham
    :*  repo  workflow.w  i  i.defs  zone  revision.baseline.gov
        digest.lock.gov  (current-incarnation repo)
    ==
  =/  next=(each @da @t)
    ?~  spec.i.defs  [%| (fall refusal.i.defs 'the schedule is refused')]
    (next-after:ci-cron u.spec.i.defs zone now.bowl)
  =/  entry=schedule-entry:ci
    :*  name.w  i.defs  zone  definition  ref  revision.baseline.gov
        digest.lock.gov  (current-incarnation repo)  actor.baseline.gov
        promoted.baseline.gov  now.bowl
        ?:(?=(%& -.next) %active %refused)
        ?:(?=(%& -.next) ~ `p.next)
        ?:(?=(%& -.next) `p.next ~)
        ~  ~  ~  ~  0
    ==
  $(defs t.defs, i +(i), out [[[repo workflow.w i] entry] out])
::
::  a repository's schedules registered again from its default branch's
::  promoted catalog: an equal definition keeps its entry and wake; a new
::  one replaces the entry and arms from now; one no longer defined — every
::  one, when the default branch has no baseline or an unknown catalog — is
::  retired with the reason (its wake, still set, does nothing).  the cards
::  are the new wakes
::
++  register-schedules
  |=  [repo=@t why=@t]
  ^-  [(list card) _state]
  =/  mine=(list [k=schedule-key:ci e=schedule-entry:ci])
    (skim ~(tap by schedules) |=([k=schedule-key:ci *] =(repo repo.k)))
  =/  default=(unit (unit @t))  (default-ref repo)
  =/  found=(each [ref=@t gov=[=baseline:ci =lock:ci catalog=trigger-catalog:ci]] @t)
    ?~  default  [%| '%urgit cannot be read for the default branch']
    ?~  u.default  [%| 'the repository has no default branch']
    =/  gov  (governing repo u.u.default)
    ?:  ?=(%| -.gov)  [%| p.gov]
    [%& u.u.default p.gov]
  =/  wanted=(list [k=schedule-key:ci e=schedule-entry:ci])
    ?:(?=(%| -.found) ~ (catalog-schedules repo ref.p.found gov.p.found))
  =/  retire=@t  ?:(?=(%| -.found) (rap 3 ~[why ': ' p.found]) (rap 3 ~[why ': no longer defined']))
  =/  keys=(set schedule-key:ci)  (silt (turn wanted |=([k=schedule-key:ci *] k)))
  =.  schedules
    %+  roll  mine
    |=  [[k=schedule-key:ci e=schedule-entry:ci] acc=_schedules]
    ?:  (~(has in keys) k)  acc
    ?:  =(%retired state.e)  acc
    (~(put by acc) k e(state %retired, armed ~, reason `retire))
  =|  cards=(list card)
  |-
  ?~  wanted  [(flop cards) state]
  =/  old=(unit schedule-entry:ci)  (~(get by schedules) k.i.wanted)
  ?:  ?&(?=(^ old) =(definition.u.old definition.e.i.wanted) !=(%retired state.u.old))
    $(wanted t.wanted)
  =.  schedules  (~(put by schedules) k.i.wanted e.i.wanted)
  =?  audit  =(%active state.e.i.wanted)
    %:  record-audit  our.bowl  'schedule-armed'  repo
      %+  rap  3
      :~  workflow.k.i.wanted  '#'  (crip (a-co:co index.k.i.wanted))  ' '
          cron.def.e.i.wanted  ' first due '
          ?~(armed.e.i.wanted '' (iso-utc:ci-cron u.armed.e.i.wanted))
      ==
    ==
  =?  cards  ?=(^ armed.e.i.wanted)
    [(timer-card k.i.wanted u.armed.e.i.wanted definition.e.i.wanted) cards]
  $(wanted t.wanted)
::
::  what a due occurrence needs at admission, revalidated now: the
::  repository's incarnation, its default branch, that branch's baseline
::  revision and lock, and a tip to run
::
++  due-problem
  |=  [k=schedule-key:ci e=schedule-entry:ci]
  ^-  (each oid:git @t)
  =/  repo=@t  repo.k
  ?.  =(incarnation.e (current-incarnation repo))
    [%| 'the repository is another incarnation than the one the schedule was armed for']
  =/  default=(unit (unit @t))  (default-ref repo)
  ?~  default  [%| '%urgit cannot be read for the default branch']
  ?.  =(`ref.e u.default)  [%| 'the default branch is no longer the one the schedule was armed for']
  =/  base=(unit baseline:ci)  (~(get by baselines) [repo ref.e])
  ?~  base  [%| (rap 3 ~['no promoted baseline governs ' ref.e ' now'])]
  ?.  ?&(=(revision.u.base baseline.e) =(lock.u.base `lock.e))
    [%| 'the default branch\'s baseline was replaced since the schedule was armed']
  =/  tip=(unit (unit [tip=oid:git linked=?]))  (ref-tip repo ref.e)
  ?~  tip  [%| '%urgit cannot be read for the default branch\'s tip']
  ?~  u.tip  [%| (rap 3 ~[ref.e ' has no tip'])]
  [%& tip.u.u.tip]
::
::  a schedule's wake: /schedule/<repo>/<workflow>/<index>/<due>/<definition>.
::  the occurrence is admitted at most once (lib/ci-cron on-wake),
::  revalidated (due-problem), and run as an event run of the default
::  branch's tip with its due instant and admission time; the next is armed
::  after now, and the occurrences between are recorded missed
::
++  schedule-wake
  |=  rest=wire
  ^-  out
  ?.  ?=([@ @ @ @ @ ~] rest)  (emit ~)
  =/  repo=@t  (decode-segment i.rest)
  =/  workflow=@t  (decode-segment i.t.rest)
  =/  index=(unit @ud)  (slaw %ud i.t.t.rest)
  =/  due-secs=(unit @ud)  (slaw %ud i.t.t.t.rest)
  =/  definition=(unit @uv)  (slaw %uv i.t.t.t.t.rest)
  ?:  |(?=(~ index) ?=(~ due-secs) ?=(~ definition))  (emit ~)
  =/  k=schedule-key:ci  [repo workflow u.index]
  =/  found=(unit schedule-entry:ci)  (~(get by schedules) k)
  ::  a reinstalled agent or a removed repository: nothing is armed
  ?~  found  (emit ~)
  =/  e=schedule-entry:ci  u.found
  =/  due=@da  (from-unix:ci-cron u.due-secs)
  =/  occurrence=@uv  (sham [%ci-occurrence repo workflow u.index u.definition due])
  =/  verdict=wake:ci-cron  (on-wake:ci-cron e due u.definition occurrence now.bowl)
  ?:  ?=(%ignore -.verdict)
    =.  schedules  (~(put by schedules) k e(stale-wakes +(stale-wakes.e)))
    (emit ~)
  =/  next-due=(unit @da)  ?:(?=(%& -.next.verdict) `p.next.verdict ~)
  =/  advanced=schedule-entry:ci
    %=  e
      armed  next-due
      state  ?~(next-due %refused state.e)
      reason  ?:(?=(%| -.next.verdict) `p.next.verdict ~)
      last-due  `due
      admitted  (scag 64 `(list @uv)`[occurrence admitted.e])
      missed
        ?~  missed.verdict  missed.e
        (scag 16 `(list missed-interval:ci)`[u.missed.verdict missed.e])
    ==
  =/  timers=(list card)  ?~(next-due ~ ~[(timer-card k u.next-due definition.e)])
  ::  CI-RECOVERY-1: a wake while CI is paused admits nothing.  its
  ::  occurrence is recorded as not admitted and the next one is armed.
  ::  there is no catch-up when CI resumes
  ?:  ci-paused
    =/  why=@t  (rap 3 ~['not admitted at ' (iso-utc:ci-cron due) ': CI was paused for a restore'])
    =.  schedules  (~(put by schedules) k advanced(reason `why))
    =.  audit  (record-audit our.bowl 'schedule-paused' repo why)
    [timers state polls]
  =/  ready=(each oid:git @t)  (due-problem k e)
  ?:  ?=(%| -.ready)
    =/  why=@t  (rap 3 ~['not admitted at ' (iso-utc:ci-cron due) ': ' p.ready])
    =.  schedules  (~(put by schedules) k advanced(reason `why))
    =.  audit  (record-audit our.bowl 'schedule-refused' repo why)
    ::  a changed default branch or baseline registers the schedules again
    =^  again  state  (register-schedules repo 'revalidated at due admission')
    (emit (weld timers again))
  =/  tip=oid:git  p.ready
  =/  facts=occurrence-facts:ci
    :*  workflow  u.index  cron.def.e  timezone.def.e  due  now.bowl
        definition.e  promoter.e  promoted.e
    ==
  =/  payload=@t  (schedule-event-payload:ci-trigger repo ref.e cron.def.e promoter.e)
  =/  ev=run-event:ci
    [occurrence %schedule ref.e ~ `tip ~ `facts promoter.e 'schedule (system timer)' due payload]
  =/  zone-text=@t  (fall timezone.def.e 'UTC')
  =/  late-text=@t
    ?.  late.verdict  ''
    (rap 3 ~['; admitted late at ' (iso-utc:ci-cron now.bowl)])
  =/  sel=event-selection:ci
    :+  (rap 3 ~['schedule ' cron.def.e ' (' zone-text ') due ' (iso-utc:ci-cron due)])
      :~  :*  workflow  name.e  %selected
              %+  rap
                3
              ~['due ' (iso-utc:ci-cron due) ' (' (local-text:ci-cron zone.e due) ')' late-text]
          ==  ==
    ~
  =/  id=candidate-id:ci  (sham [%ci-occurrence-run occurrence])
  =/  run=candidate:ci
    %:  event-candidate
      id  repo  ref.e  tip  tip  promoter.e  'schedule (system timer)'
      %trusted  ~  ev  sel  `tip
    ==
  =.  candidates  (~(put by candidates) id run)
  =.  schedules
    %+  ~(put by schedules)  k
    advanced(last-admitted `[due now.bowl id late.verdict])
  =.  audit
    %:  record-audit  our.bowl  'schedule-run'  repo
      %+  rap  3
      :~  workflow  '#'  (crip (a-co:co u.index))  ' due '  (iso-utc:ci-cron due)
          ' → run '  (scot %uv id)  late-text
      ==
    ==
  =/  keep=card
    (urgit-git-poke /scratch/(scot %uv id) [%set-ref repo (scratch-ref run) tip])
  =/  scheduled=out  schedule
  [:(weld ~[keep] timers cards.scheduled) state.scheduled polls.scheduled]
::
::
::  ---- CI-RECOVERY-1 (R5.2-A): checkpoints and the paused restore ----
::
++  owner-refusal
  ^-  @t
  'only the ship\'s owner checkpoints, pauses, resumes, imports or applies: recovery is never delegated'
::
++  ci-paused
  ^-  ?
  ?=(^ paused.recovery)
::
::  what a checkpoint is written on a change of: two equal prints are the
::  same CI policy.  runner heartbeats and labels, runs, locks and the
::  audit are not in it, and no credential value is
::
++  policy-print
  ^-  *
  =/  creds  (~(run by credentials) |=(c=credential:ci [scope.c envs.c created.c]))
  =/  runners=(list [daemon-id:ci (unit (set @t)) (unit @da)])
    %+  murn  ~(tap by daemons)
    |=  [id=daemon-id:ci d=daemon:ci]
    ^-  (unit [daemon-id:ci (unit (set @t)) (unit @da)])
    ?~  enrolled.d  ~
    `[id repos.d revoked.d]
  :*  ci-protected
      policies
      sandbox-requirements
      harness-paths
      network-policies
      automatic-inputs
      baselines
      roles
      environments
      creds
      ?~(signing ~ `[pub.u.signing cert.u.signing])
      (silt runners)
  ==
::
::  after every poke: a changed CI policy writes a checkpoint, named by
::  the audit entry the change wrote.  none is written while CI is paused
::
++  auto-checkpoint
  |=  [print=* told=(list audit-entry:ci)]
  ^-  out
  ?:  =(print policy-print)  [~ state polls]
  ?:  ci-paused  [~ state polls]
  =/  cause=@t
    ?:  =(told audit)  'policy change'
    ?~  audit  'policy change'
    =/  where=@t  ?:(=('' repo.i.audit) '' (rap 3 ~[' (' repo.i.audit ')']))
    (rap 3 ~['policy change: ' kind.i.audit where])
  (write-checkpoint cause our.bowl)
::
::  the checkpoint repository as %urgit answers it: ~ when %urgit cannot
::  be read, [~ ~] when the repository does not exist
::
++  checkpoint-repo-info
  |=  repo=@t
  ^-  (unit (unit recovery-repo:ci))
  =/  raw=(unit *)  (urgit-peek /ci-recovery-repo/(scot %t repo))
  ?~  raw  ~
  =/  got=(each (unit recovery-repo:ci) tang)
    (mule |.(;;((unit recovery-repo:ci) u.raw)))
  ?.  ?=(%& -.got)  ~
  `p.got
::
::  the desk this agent runs from, and its Clay revision
::
++  desk-revision
  ^-  [desk=@t revision=@ud]
  =/  got=(each @ud tang)
    %-  mule
    |.
    ud:.^(cass:clay %cw /(scot %p our.bowl)/[q.byk.bowl]/(scot %da now.bowl))
  [q.byk.bowl ?:(?=(%& -.got) p.got 0)]
::
::  a checkpoint that could not be written: recorded, with the reason
::
++  record-unwritten
  |=  [id=@t cause=@t actor=@p reason=@t]
  ^-  out
  =/  record=checkpoint:ci
    :*  id  now.bowl  cause  actor  repository:ci-checkpoint  ''  ~  0x0  ''  ~
        [%failed now.bowl reason]
        [%skipped 'the checkpoint was not written, so there is nothing to push']
    ==
  =.  checkpoints.recovery  (add-record:ci-checkpoint checkpoints.recovery record)
  [~ state polls]
::
::  one checkpoint: its files and its commit are built here, so the record
::  knows its commit before %urgit writes it.  the repository is created
::  private when it does not exist.  a repository that is public or bound
::  to a desk is never written to
::
++  write-checkpoint
  |=  [cause=@t actor=@p]
  ^-  out
  =/  seq=@ud  +(sequence.recovery)
  =.  sequence.recovery  seq
  =/  id=@t  (checkpoint-id:ci-checkpoint now.bowl seq our.bowl)
  =/  repo=@t  repository:ci-checkpoint
  =/  info=(unit (unit recovery-repo:ci))  (checkpoint-repo-info repo)
  ?~  info
    (record-unwritten id cause actor '%urgit cannot be read, so the checkpoint repository cannot be checked')
  =/  existing=(unit recovery-repo:ci)  u.info
  ?:  ?&(?=(^ existing) public.u.existing)
    (record-unwritten id cause actor 'the repository ci-checkpoints is public: a checkpoint is written only to a private repository')
  ?:  ?&(?=(^ existing) linked.u.existing)
    (record-unwritten id cause actor 'the repository ci-checkpoints is bound to a Clay desk: a checkpoint is not written there')
  =/  ref=@t  ?~(existing 'refs/heads/main' head.u.existing)
  =/  parent=(unit oid:git)  ?~(existing ~ tip.u.existing)
  =/  where=[desk=@t revision=@ud]  desk-revision
  =/  content=checkpoint-content:ci  (project:ci-checkpoint state our.bowl now.bowl)
  =/  made=written-files:ci-checkpoint
    %:  export:ci-checkpoint
      content  id  our.bowl  desk.where  revision.where  now.bowl  cause
    ==
  =/  tree=(map path octs)  (malt files.made)
  =/  message=@t  (rap 3 ~['checkpoint ' id ': ' cause])
  =/  snapped=(unit [commit=oid:git objects=(map oid:git object:git)])
    (snapshot:git-clay tree ~ parent our.bowl now.bowl message)
  ?~  snapped
    (record-unwritten id cause actor 'the checkpoint tree could not be built')
  =/  record=checkpoint:ci
    :*  id  now.bowl  cause  actor  repo  ref  parent  commit.u.snapped
        digest.made  sections.manifest.made  [%pending ~]  [%waiting ~]
    ==
  =.  checkpoints.recovery  (add-record:ci-checkpoint checkpoints.recovery record)
  =/  objects=(list object:git)  ~(val by objects.u.snapped)
  =/  write=card
    %+  urgit-git-poke  /checkpoint/(scot %t id)
    [%write-recovery-commit repo ref parent commit.u.snapped objects]
  ?^  existing  [~[write] state polls]
  :_  [state polls]
  :~  (urgit-git-poke /checkpoint-repo [%create repo %.n])
      write
  ==
::
::  %urgit's answer to a checkpoint's write.  written means its replica
::  push is queued.  not written carries %urgit's reason
::
++  checkpoint-acked
  |=  [segment=@ta error=(unit tang)]
  ^-  out
  =/  id=@t  (fall (slaw %t segment) segment)
  ?^  error
    =.  checkpoints.recovery
      (not-written:ci-checkpoint checkpoints.recovery id now.bowl (trace-reason u.error))
    [~ state polls]
  =.  checkpoints.recovery  (written:ci-checkpoint checkpoints.recovery id now.bowl)
  start-push
::
::  the replica path of the checkpoint repository: a GitHub origin with
::  a stored token, or the ship it was forked from.  else %| with whether
::  no path is configured (%.y) or the path cannot be used (%.n)
::
++  replica-route
  |=  [info=(unit (unit recovery-repo:ci)) ref=@t]
  ^-  (each @t [unconfigured=? reason=@t])
  ?~  info  [%| %.n '%urgit cannot be read, so the replica path cannot be checked']
  ?~  u.info  [%| %.n 'the repository ci-checkpoints is gone']
  =/  r=recovery-repo:ci  u.u.info
  ?^  github.r
    ?.  token.r
      [%| %.n 'the repository has a GitHub origin, but no GitHub token is connected']
    [%& (rap 3 ~['GitHub ' owner.u.github.r '/' repository.u.github.r])]
  ?^  peer.r
    ?.  =(ref head.r)
      [%| %.n 'a peer replica receives only the default branch, and the checkpoint branch is another']
    [%& (rap 3 ~['ship ' (scot %p ship.u.peer.r) ', repository ' repository.u.peer.r])]
  :+  %|  %.y
  %+  rap  3
  :~  'no replica is configured: ci-checkpoints has no GitHub origin and is no fork of '
      'another ship\'s repository. Clone it over Smart HTTP to hold a copy'
  ==
::
::  the next replica push, when none is in flight: the newest written
::  checkpoint carries every waiting one, its commit being their
::  descendant.  a push that cannot start is a failed backup.  no path at
::  all leaves each one written with its replica not confirmed
::
++  start-push
  ^-  out
  =/  next=(unit checkpoint:ci)  (next-push:ci-checkpoint checkpoints.recovery)
  ?~  next  [~ state polls]
  =/  route=(each @t [unconfigured=? reason=@t])
    (replica-route (checkpoint-repo-info repository.u.next) ref.u.next)
  ?:  ?=(%| -.route)
    =.  checkpoints.recovery
      ?:  unconfigured.p.route
        (push-unconfigured:ci-checkpoint checkpoints.recovery reason.p.route)
      =/  ticket=@uv  (fresh-nonce [%replica id.u.next])
      =/  started  (push-started:ci-checkpoint checkpoints.recovery ticket '' now.bowl)
      (push-answered:ci-checkpoint started ticket %.n reason.p.route now.bowl)
    [~ state polls]
  =/  ticket=@uv  (fresh-nonce [%replica id.u.next])
  =.  checkpoints.recovery
    (push-started:ci-checkpoint checkpoints.recovery ticket p.route now.bowl)
  :_  [state polls]
  :~  %+  urgit-git-poke  /replica/(scot %uv ticket)
      [%push-recovery-replica repository.u.next ref.u.next ticket]
      [%pass /replica-timeout/(scot %uv ticket) %arvo %b %wait (add now.bowl replica-wait:ci-checkpoint)]
  ==
::
::  %urgit refused to start a push: a failed backup, with its reason
::
++  replica-acked
  |=  [segment=@ta error=(unit tang)]
  ^-  out
  ?~  error  [~ state polls]
  =/  ticket=(unit @uv)  (slaw %uv segment)
  ?~  ticket  [~ state polls]
  =.  checkpoints.recovery
    %:  push-answered:ci-checkpoint
      checkpoints.recovery  u.ticket  %.n  (trace-reason u.error)  now.bowl
    ==
  start-push
::
::  a push with no answer in its time: a failed backup
::
++  replica-silent
  |=  segment=@ta
  ^-  out
  =/  ticket=(unit @uv)  (slaw %uv segment)
  ?~  ticket  [~ state polls]
  =.  checkpoints.recovery
    %:  push-answered:ci-checkpoint
      checkpoints.recovery  u.ticket  %.n  push-silence:ci-checkpoint  now.bowl
    ==
  start-push
::
::  the forge events of one %urgit event while CI is paused: each one is
::  recorded and remembered, and admits nothing, now or later
::
++  paused-events
  |=  act=action:ci
  ^-  out
  ?>  ?=(%forge-events -.act)
  =/  why=@t  'not admitted: CI was paused for a restore, so this event runs nothing'
  =.  state
    %+  roll  refs.act
    |=  [u=ref-update:ci acc=_state]
    =.  state  acc
    ?:  (~(has by event-ids) id.u)  state
    =.  event-ids  (remember-id id.u)
    =/  e=forge-event:ci
      :*  id.u  repo.act  %push  ref.u  old.u  new.u  ~  actor.act  route.act
          at.act  now.bowl  why  ~  ~
      ==
    =.  forge-events  (record-forge-event e)
    state
  =.  state
    %+  roll  pulls.act
    |=  [p=pull-update:ci acc=_state]
    =.  state  acc
    ?:  (~(has by event-ids) id.p)  state
    =.  event-ids  (remember-id id.p)
    =/  facts=pull-facts:ci
      :*  number.p  title.p  action.p  head.p  source-ref.p  target-ref.p
          base.p  merged.p  source-ship.p  source-repository.p  labels.p  label.p
      ==
    =/  e=forge-event:ci
      :*  id.p  repo.act  %pull-request  target-ref.p  ~  `head.p  `facts
          actor.act  route.act  at.act  now.bowl  why  ~  ~
      ==
    =.  forge-events  (record-forge-event e)
    state
  [~ state polls]
::
::  the Recovery section's data (GET ci/recovery): the ship's session only
::
++  handle-recovery
  |=  [eyre-id=@ta req=inbound-request:eyre]
  ^-  out
  ?.  (viewer req)
    (emit (give-error eyre-id 401 'session required'))
  (emit (give-json eyre-id 200 recovery-section-json))
::
++  seconds-json
  |=  at=@da
  ^-  json
  (numb:enjs:format (unix-seconds at))
::
++  write-json
  |=  w=checkpoint-write:ci
  ^-  json
  =/  fields=(list [@t json])
    ?-  -.w
      %pending  ~[['state' s+'pending']]
      %written  ~[['state' s+'written'] ['at' (seconds-json at.w)]]
      %failed  ~[['state' s+'failed'] ['at' (seconds-json at.w)] ['reason' s+reason.w]]
    ==
  (pairs:enjs:format fields)
::
++  replica-json
  |=  r=checkpoint-replica:ci
  ^-  json
  =/  fields=(list [@t json])
    ?-  -.r
      %waiting  ~[['state' s+'waiting']]
      %pushing  ~[['state' s+'pushing'] ['at' (seconds-json at.r)] ['route' s+route.r]]
      %confirmed  ~[['state' s+'confirmed'] ['at' (seconds-json at.r)] ['route' s+route.r]]
        %failed
      :~  ['state' s+'failed']  ['at' (seconds-json at.r)]
          ['route' s+route.r]  ['reason' s+reason.r]
      ==
      %unconfigured  ~[['state' s+'unconfigured'] ['reason' s+reason.r]]
      %skipped  ~[['state' s+'skipped'] ['reason' s+reason.r]]
    ==
  (pairs:enjs:format fields)
::
++  checkpoint-json
  |=  c=checkpoint:ci
  ^-  json
  %-  pairs:enjs:format
  :~  ['id' s+id.c]
      ['at' (seconds-json at.c)]
      ['cause' s+cause.c]
      ['actor' s+(scot %p actor.c)]
      ['repository' s+repository.c]
      ['ref' s+ref.c]
      ['commit' ?:(=(0x0 commit.c) ~ s+(oid-text:git-codec commit.c))]
      ['parent' ?~(parent.c ~ s+(oid-text:git-codec u.parent.c))]
      ['manifest' s+manifest.c]
      ['sections' [%a (turn sections.c section-json:ci-checkpoint)]]
      ['written' (write-json written.c)]
      ['replica' (replica-json replica.c)]
  ==
::
++  staged-json
  |=  st=staged-checkpoint:ci
  ^-  json
  =/  m=checkpoint-manifest:ci  manifest.st
  =/  changes=(list change:ci-checkpoint)  (diff:ci-checkpoint state content.st)
  %-  pairs:enjs:format
  :~  ['id' s+id.m]
      ['commit' s+(oid-text:git-codec commit.st)]
      ['imported' (seconds-json imported.st)]
      ['actor' s+(scot %p actor.st)]
      :-  'manifest'
      %-  pairs:enjs:format
      :~  ['id' s+id.m]
          ['ship' s+(scot %p ship.m)]
          ['desk' s+desk.m]
          ['revision' (numb:enjs:format revision.m)]
          ['created' (seconds-json at.m)]
          ['cause' s+cause.m]
          ['sections' [%a (turn sections.m section-json:ci-checkpoint)]]
          ['excluded' [%a (turn excluded:ci-checkpoint |=(t=@t s+t))]]
      ==
      :-  'diff'
      :-  %a
      %+  turn  changes
      |=  c=change:ci-checkpoint
      %-  pairs:enjs:format
      :~  ['section' s+section.c]
          ['repo' s+repo.c]
          ['kind' s+kind.c]
          ['text' s+text.c]
      ==
  ==
::
++  restore-json
  |=  r=restore:ci
  ^-  json
  %-  pairs:enjs:format
  :~  ['id' s+id.r]
      ['commit' s+(oid-text:git-codec commit.r)]
      ['at' (seconds-json at.r)]
      ['actor' s+(scot %p actor.r)]
      ['repos' [%a (turn repos.r |=(t=@t s+t))]]
      ['skipped' [%a (turn skipped.r |=(t=@t s+t))]]
      ['cancelled' (numb:enjs:format (lent cancelled.r))]
  ==
::
++  history-json
  |=  h=restored-history:ci
  ^-  json
  %-  pairs:enjs:format
  :~  :-  'keys'
      :-  %a
      %+  turn  keys.h
      |=  k=key-record:ci
      %-  pairs:enjs:format
      :~  ['pub' s+(hex-bytes pub.k 32)]
          ['ship' s+(scot %p ship.k)]
          ['created' (seconds-json created.k)]
      ==
      :-  'runners'
      :-  %a
      %+  turn  runners.h
      |=  r=runner-record:ci
      %-  pairs:enjs:format
      :~  ['id' s+(scot %uv id.r)]
          ['labels' [%a (turn labels.r |=(t=@t s+t))]]
          ['repos' ?~(repos.r ~ [%a (turn u.repos.r |=(t=@t s+t))])]
      ==
      :-  'credentials'
      :-  %a
      %+  turn  credentials.h
      |=  r=credential-ref:ci
      %-  pairs:enjs:format
      :~  ['repo' s+repo.r]
          ['name' s+name.r]
          ['scope' s+scope.r]
      ==
      ['runs' (numb:enjs:format (lent runs.h))]
      ['authorizations' (numb:enjs:format (lent authorizations.h))]
      ['audit' (numb:enjs:format (lent audit.h))]
  ==
::
++  recovery-repo-json
  |=  info=(unit (unit recovery-repo:ci))
  ^-  json
  =/  name=json  s+repository:ci-checkpoint
  ?~  info
    (pairs:enjs:format ~[['name' name] ['readable' b+%.n] ['exists' b+%.n]])
  ?~  u.info
    (pairs:enjs:format ~[['name' name] ['readable' b+%.y] ['exists' b+%.n]])
  =/  r=recovery-repo:ci  u.u.info
  =/  route=(each @t [unconfigured=? reason=@t])  (replica-route info head.r)
  %-  pairs:enjs:format
  :~  ['name' name]
      ['readable' b+%.y]
      ['exists' b+%.y]
      ['private' b+!public.r]
      ['linked' b+linked.r]
      ['branch' s+head.r]
      ['tip' ?~(tip.r ~ s+(oid-text:git-codec u.tip.r))]
      ['replica' ?:(?=(%& -.route) s+p.route ~)]
      ['replicaProblem' ?:(?=(%& -.route) ~ s+reason.p.route)]
  ==
::
::  the whole Recovery section.  the session is the ship's owner, who
::  holds every role, so it may manage recovery
::
++  recovery-section-json
  ^-  json
  =/  info=(unit (unit recovery-repo:ci))  (checkpoint-repo-info repository:ci-checkpoint)
  %-  pairs:enjs:format
  :~  ['authority' (pairs:enjs:format ~[['manage' b+%.y] ['ship' s+(scot %p our.bowl)]])]
      :-  'paused'
      ?~  paused.recovery  ~
      %-  pairs:enjs:format
      :~  ['at' (seconds-json at.u.paused.recovery)]
          ['actor' s+(scot %p actor.u.paused.recovery)]
          ['reason' s+reason.u.paused.recovery]
      ==
      ['repository' (recovery-repo-json info)]
      ['checkpoints' [%a (turn checkpoints.recovery checkpoint-json)]]
      ['staged' ?~(staged.recovery ~ (staged-json u.staged.recovery))]
      ['restores' [%a (turn restores.recovery restore-json)]]
      ['history' (history-json history.recovery)]
      ['running' (numb:enjs:format (running-attempts:ci-checkpoint state))]
      ['now' (numb:enjs:format (unix-seconds now.bowl))]
  ==
::
++  handle-http
  |=  [eyre-id=@ta req=inbound-request:eyre]
  ^-  out
  =/  line=request-line:server  (parse-request-line:server url.request.req)
  =/  site=(list @t)  site.line
  =/  method=@tas  method.request.req
  ?:  ?=([%apps %urgit %api %ci %daemon %enroll ~] site)
    ?.  =(%'POST' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-enroll eyre-id req)
  ?:  ?=([%apps %urgit %api %ci %daemon @ %assignment ~] site)
    ?.  =(%'GET' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-assignment-poll eyre-id req i.t.t.t.t.t.site)
  ?:  ?=([%apps %urgit %api %ci %attempt @ ~] site)
    ?.  =(%'GET' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    ::  the id is the last segment here, so the request-line parser has
    ::  split its last dotted group off as an extension: rejoin it
    ::
    =/  segment=@t
      ?~  ext.line  i.t.t.t.t.t.site
      (rap 3 ~[i.t.t.t.t.t.site '.' u.ext.line])
    (handle-attempt-read eyre-id req segment)
  ?:  ?=([%apps %urgit %api %ci %attempt @ %event ~] site)
    ?.  =(%'POST' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-event eyre-id req i.t.t.t.t.t.site)
  ?:  ?=([%apps %urgit %api %ci %attempt @ %result ~] site)
    ?.  =(%'POST' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-result eyre-id req i.t.t.t.t.t.site)
  ?:  ?=([%apps %urgit %api %ci %attempt @ %plan ~] site)
    ?.  =(%'POST' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-plan eyre-id req i.t.t.t.t.t.site)
  ?:  ?=([%apps %urgit %api %ci %attempt @ %abandon ~] site)
    ?.  =(%'POST' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-abandon eyre-id req i.t.t.t.t.t.site)
  ::  the addresses the launcher pinned each granted DNS name to, once,
  ::  when the VM starts (CI-P4-NET-1, pinned addresses shown per run)
  ?:  ?=([%apps %urgit %api %ci %attempt @ %pinned ~] site)
    ?.  =(%'POST' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-pinned eyre-id req i.t.t.t.t.t.site)
  ?:  ?=([%apps %urgit %api %ci %attempt @ %upload ~] site)
    ?.  =(%'POST' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-upload eyre-id req i.t.t.t.t.t.site)
  ?:  ?=([%apps %urgit %api %ci %attempt @ %log ~] site)
    ?.  =(%'GET' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-log-read eyre-id req i.t.t.t.t.t.site)
  ::  the resolver posts its lock (D4)
  ?:  ?=([%apps %urgit %api %ci %attempt @ %lock ~] site)
    ?.  =(%'POST' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-lock eyre-id req i.t.t.t.t.t.site)
  ::  the provenance surface (D7): a lock by digest, the audit, a shadow
  ?:  ?=([%apps %urgit %api %ci %repository @ %lock @ ~] site)
    ?.  =(%'GET' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-lock-read eyre-id req i.t.t.t.t.t.site i.t.t.t.t.t.t.t.site)
  ?:  ?=([%apps %urgit %api %ci %repository @ %audit ~] site)
    ?.  =(%'GET' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-audit eyre-id req i.t.t.t.t.t.site)
  ?:  ?=([%apps %urgit %api %ci %shadow @ ~] site)
    ?.  =(%'GET' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    =/  segment=@t
      ?~  ext.line  i.t.t.t.t.t.site
      (rap 3 ~[i.t.t.t.t.t.site '.' u.ext.line])
    (handle-shadow-read eyre-id req segment)
  ?:  ?=([%apps %urgit %api %ci %key ~] site)
    ?.  =(%'GET' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-key eyre-id req)
  ::  the legacy recovery (legacy-recovery UI ruling 01): a daemon's
  ::  retention report and its answer to a recovery command, each with the
  ::  daemon's own bearer, never the ship's session
  ::
  ?:  ?=([%apps %urgit %api %ci %daemon @ %retentions ~] site)
    ?.  =(%'POST' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-retention-report eyre-id req i.t.t.t.t.t.site)
  ?:  ?=([%apps %urgit %api %ci %daemon @ %recovery ~] site)
    ?.  =(%'POST' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-recovery-answer eyre-id req i.t.t.t.t.t.site)
  ::  the web surface (D6): every read and the action route need the
  ::  ship session; a daemon bearer is not a viewer
  ::
  ?:  ?=([%apps %urgit %api %ci %action ~] site)
    ?.  =(%'POST' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-web-action eyre-id req)
  ::  the Runners panel (D1/D3): the daemon records, and the mint that
  ::  answers a fresh enrollment token exactly once
  ::
  ?:  ?=([%apps %urgit %api %ci %runners ~] site)
    ?.  =(%'GET' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-runners eyre-id req)
  ?:  ?=([%apps %urgit %api %ci %runners %mint ~] site)
    ?.  =(%'POST' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-mint eyre-id req)
  ::  a runner's retentions, its report and its recovery commands, for the
  ::  Runners panel (legacy-recovery UI ruling 01)
  ::
  ?:  ?=([%apps %urgit %api %ci %runners @ %recovery ~] site)
    ?.  =(%'GET' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-runner-recovery eyre-id req i.t.t.t.t.t.site)
  ?:  ?=([%apps %urgit %api %ci %storage %probe ~] site)
    ?.  =(%'GET' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-storage-probe eyre-id req)
  ::  CI-RECOVERY-1: the Recovery section's data, the ship's session only
  ?:  ?=([%apps %urgit %api %ci %recovery ~] site)
    ?.  =(%'GET' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-recovery eyre-id req)
  ::  the recorded forge events and the schedules of a repository
  ::  (Delivery 1C), for the CI tab; the ship's session
  ?:  ?=([%apps %urgit %api %ci %repository @ %events ~] site)
    ?.  =(%'GET' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-events eyre-id req i.t.t.t.t.t.site)
  ?:  ?=([%apps %urgit %api %ci %repository @ %schedules ~] site)
    ?.  =(%'GET' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-schedules eyre-id req i.t.t.t.t.t.site)
  ?:  ?=([%apps %urgit %api %ci %repository @ %candidates ~] site)
    ?.  =(%'GET' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-candidates eyre-id req i.t.t.t.t.t.site args.line)
  ?:  ?=([%apps %urgit %api %ci %repository @ %policy ~] site)
    ?.  =(%'GET' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-policy eyre-id req i.t.t.t.t.t.site)
  ::  the resolve of one revision (P4 D4): the synthetic candidate the
  ::  import rides, by repository and revision, as the candidate view
  ?:  ?=([%apps %urgit %api %ci %repository @ %resolve @ ~] site)
    ?.  =(%'GET' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    =/  repo=@t  (decode-segment i.t.t.t.t.t.site)
    =/  oid=(unit oid:git)  (parse-oid i.t.t.t.t.t.t.t.site)
    ?~  oid  (emit (give-error eyre-id 400 'revision must be 40 hex'))
    (handle-candidate-read eyre-id req (scot %uv (sham [%ci-resolve repo u.oid])))
  ?:  ?=([%apps %urgit %api %ci %repository @ %credentials ~] site)
    ?.  =(%'GET' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    (handle-credentials eyre-id req i.t.t.t.t.t.site)
  ?:  ?=([%apps %urgit %api %ci %candidate @ ~] site)
    ?.  =(%'GET' method)
      (emit (give-error eyre-id 405 'method not allowed'))
    =/  segment=@t
      ?~  ext.line  i.t.t.t.t.t.site
      (rap 3 ~[i.t.t.t.t.t.site '.' u.ext.line])
    (handle-candidate-read eyre-id req segment)
  ::  manual runs (Delivery 1A): the Run workflow form's data, and the
  ::  dispatch itself; both the ship's session
  ::
  ?:  ?=([%apps %urgit %api %ci %repository @ %dispatch ~] site)
    ?:  =(%'GET' method)  (handle-dispatch-inventory eyre-id req i.t.t.t.t.t.site)
    ?:  =(%'POST' method)  (handle-dispatch eyre-id req i.t.t.t.t.t.site)
    (emit (give-error eyre-id 405 'method not allowed'))
  (emit (give-error eyre-id 404 'ci route not found'))
::
::  enrollment: the token is the credential.  its hash must match a
::  minted, not yet enrolled daemon record.  the bearer is derived from
::  the daemon id and the token, returned once, and stored only hashed.
::  the daemon reports its capacity (default 1) and its sandbox (D6); a
::  newly enrolled daemon may take work at once.
::
++  handle-enroll
  |=  [eyre-id=@ta req=inbound-request:eyre]
  ^-  out
  =/  jon=(unit json)  (body-json req)
  ?~  jon
    (emit (give-error eyre-id 400 'valid JSON body required'))
  =/  token-text=(unit @t)  (string-at 'token' u.jon)
  ?~  token-text
    (emit (give-error eyre-id 422 'token is required'))
  =/  token=(unit @uv)  (slaw %uv u.token-text)
  ?~  token
    (emit (give-error eyre-id 422 'token must be a @uv'))
  =/  capacity=(unit (unit @ud))  (number-at 'capacity' u.jon)
  ?~  capacity
    (emit (give-error eyre-id 422 'capacity must be a natural number'))
  ?:  ?&(?=(^ u.capacity) =(0 u.u.capacity))
    (emit (give-error eyre-id 422 'capacity must be at least 1'))
  =/  sandbox=@t  (fall (string-at 'sandbox' u.jon) '')
  ::  the labels the daemon declares (D2b): a list of strings, sent again
  ::  on every poll; the implicit set is the ship's, never the daemon's
  ::
  =/  labels=(set @t)  (labels-at 'labels' u.jon)
  ::  the network profiles the daemon supports (rider 03) and whether it
  ::  may run imports (resolver = true in its config)
  =/  profiles=(set @t)  (labels-at 'profiles' u.jon)
  =/  resolver=?
    ?.  ?=([%o *] u.jon)  %.n
    =/  v=(unit json)  (~(get by p.u.jon) 'resolver')
    ?~  v  %.n
    ?.(?=([%b *] u.v) %.n p.u.v)
  =/  token-hash=@  (shas %ci-enroll u.token)
  =/  matches=(list daemon:ci)
    %+  skim  ~(val by daemons)
    |=  =daemon:ci
    ?&(=(token-hash token-hash.daemon) ?=(~ enrolled.daemon))
  ?~  matches
    (emit (give-error eyre-id 401 'enroll token is not recognized'))
  =/  =daemon:ci  i.matches
  =/  bearer=@uv  (shas %ci-daemon (jam [id.daemon u.token]))
  =/  bearer-hash=@  (shas %ci-bearer bearer)
  =/  next=daemon:ci
    %=  daemon
      bearer-hash  `bearer-hash
      enrolled  `now.bowl
      last-seen  `now.bowl
      capacity  (fall u.capacity 1)
      sandbox  sandbox
      running  ~
      labels  labels
      refused  ~
      profiles  profiles
      resolver  resolver
    ==
  =.  daemons  (~(put by daemons) id.daemon next)
  =/  scheduled=out  schedule
  =.  state  state.scheduled
  =.  polls  polls.scheduled
  %-  emit
  %+  weld  cards.scheduled
  %^  give-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['daemon-id' s+(scot %uv id.daemon)]
      ['bearer' s+(scot %uv bearer)]
      ['capacity' (numb:enjs:format (fall u.capacity 1))]
      ['sandbox' s+sandbox]
      ['ci-public-key' ?~(signing ~ s+(hex-bytes pub.u.signing 32))]
  ==
::
::  the assignment channel.  a polling daemon has capacity to offer, so
::  the scheduler runs first; then an undelivered assignment for a
::  running attempt answers at once, else the request is held for the
::  poll window and closes 204, unless an assignment arrives first.
::
::  an assignment answered into a poll whose daemon had already gone
::  (eyre reports a closed connection seconds later) would otherwise wait
::  out its whole deadline: a delivered assignment whose attempt shows no
::  activity two minutes on is offered again to its daemon's next poll.
::  the daemon ignores an attempt it is already running.
::
++  stale-delivery
  |=  =assignment:ci
  ^-  ?
  ?~  delivered.assignment  %.n
  ?.  (gte now.bowl (add u.delivered.assignment redeliver-after))  %.n
  =/  running=(unit attempt:ci)  (~(get by attempts) attempt.assignment)
  ?~  running  %.n
  ?&  =(%running status.u.running)
      =(0 events.u.running)
      ?~  found=(~(get by candidates) candidate.assignment)  %.n
      ?:(?=(%plan kind.assignment) ?=(~ plan.u.found) %.y)
  ==
::
++  handle-assignment-poll
  |=  [eyre-id=@ta req=inbound-request:eyre segment=@t]
  ^-  out
  =/  daemon-id=(unit @uv)  (slaw %uv segment)
  =/  found=(unit daemon:ci)  ?~(daemon-id ~ (~(get by daemons) u.daemon-id))
  ::  a bearer for a daemon the ship does not know (no record of it here:
  ::  never enrolled, or the agent's state was wiped) is a credential that
  ::  authenticates nothing: 401
  ::
  ?~  found
    ?^  (presented-bearer-hash req)
      (emit (give-error eyre-id 401 'daemon authentication required'))
    (emit (give-error eyre-id 404 'no such daemon'))
  ::  a revoked daemon's bearer authenticates nothing (D2): its next poll
  ::  is answered 401 with the reason, and the daemon exits on it
  ::
  ?:  ?&(?=(^ revoked.u.found) ?=(^ (presented-bearer-hash req)))
    (emit (give-error eyre-id 401 revoked-refusal))
  ?.  (daemon-authorized req u.found)
    (emit (give-error eyre-id 401 'daemon authentication required'))
  =.  daemons  (touch-daemon id.u.found)
  ::  the capacity a daemon reports as it waits (spec: "reports capacity,
  ::  and waits"): a restart with a new config takes effect at its next
  ::  poll, without a second enrollment.  its labels ride the same way
  ::  (D2b): `x-ci-labels`, comma-separated.  a runner waiting for its
  ::  history transition reports 0, explicitly (legacy-replay-upgrade
  ::  ruling 01; INTEGRATION.md §11.15): it is offered no work until it
  ::  reports its capacity again.  no runner before it sends 0.
  ::
  =.  daemons
    =/  header=(unit @t)  (get-header:http 'x-ci-capacity' header-list.request.req)
    =/  reported=(unit @ud)  ?~(header ~ (slaw %ud u.header))
    ?~  reported  daemons
    =/  runner=daemon:ci  (~(got by daemons) id.u.found)
    ?:  =(capacity.runner u.reported)  daemons
    (~(put by daemons) id.u.found runner(capacity u.reported))
  =.  daemons
    =/  header=(unit @t)  (get-header:http 'x-ci-labels' header-list.request.req)
    ?~  header  daemons
    =/  reported=(set @t)  (parse-labels u.header)
    =/  runner=daemon:ci  (~(got by daemons) id.u.found)
    ?:  =(labels.runner reported)  daemons
    (~(put by daemons) id.u.found runner(labels reported))
  =.  daemons
    =/  header=(unit @t)  (get-header:http 'x-ci-profiles' header-list.request.req)
    ?~  header  daemons
    =/  reported=(set @t)  (parse-labels u.header)
    =/  runner=daemon:ci  (~(got by daemons) id.u.found)
    ?:  =(profiles.runner reported)  daemons
    (~(put by daemons) id.u.found runner(profiles reported))
  =.  resolver-inputs
    =/  header=(unit @t)  (get-header:http 'x-ci-automatic-inputs' header-list.request.req)
    =/  reported=(list @t)  ?~(header ~ (sort ~(tap in (parse-labels u.header)) aor))
    (~(put by resolver-inputs) id.u.found ?:((valid:ci-input reported) reported ~))
  =/  scheduled=out  schedule
  =.  state  state.scheduled
  =.  polls  polls.scheduled
  ::  CI-RECOVERY-1: while CI is paused no assignment is handed out, not
  ::  even one created before the pause: the poll waits
  =/  pending=(list assignment:ci)
    ?:  ci-paused  ~
    %+  skim  ~(val by assignments)
    |=  =assignment:ci
    ?.  =(daemon.assignment id.u.found)  %.n
    ?^  delivered.assignment  (stale-delivery assignment)
    =/  running=(unit attempt:ci)  (~(get by attempts) attempt.assignment)
    ?&(?=(^ running) =(%running status.u.running))
  ?^  pending
    =/  =assignment:ci  i.pending
    =/  =attempt:ci  (~(got by attempts) attempt.assignment)
    =/  =candidate:ci  (~(got by candidates) candidate.assignment)
    =.  assignment  assignment(delivered `now.bowl)
    =.  assignments  (~(put by assignments) id.assignment assignment)
    %-  emit
    %+  weld  cards.scheduled
    (give-json eyre-id 200 (assignment-json assignment candidate attempt))
  ::  the owner's recovery command (legacy-recovery UI ruling 01): handed
  ::  over only to a daemon whose poll says it carries them out, when no
  ::  assignment waits; the daemon checks it and answers on its own route.
  ::  a queued command past its time expires here, never handed over.
  ::
  =.  recovery-commands
    %-  ~(run by recovery-commands)
    |=(c=recovery-command:ci (expire-command:ci-recovery c now.bowl))
  =/  command=(unit recovery-command:ci)
    ?~  (get-header:http 'x-ci-recovery' header-list.request.req)  ~
    (deliverable:ci-recovery ~(val by recovery-commands) id.u.found now.bowl redeliver-after)
  ?^  command
    =/  sent=recovery-command:ci
      %=  u.command
        delivered  `now.bowl
        deliveries  +(deliveries.u.command)
        status  ?:(=(%queued status.u.command) %delivered status.u.command)
      ==
    =.  recovery-commands  (~(put by recovery-commands) id.sent sent)
    %-  emit
    %+  weld  cards.scheduled
    (give-json eyre-id 200 (recovery-json sent))
  =/  previous=(unit poll)  (~(get by polls) id.u.found)
  =.  polls  (~(put by polls) id.u.found [eyre-id now.bowl])
  =/  closed=(list card)
    ?~(previous ~ (give-empty eyre-id.u.previous 204))
  =/  timer=card
    :*  %pass  /poll/(scot %uv id.u.found)/[eyre-id]
        %arvo  %b  %wait  (add now.bowl poll-window)
    ==
  (emit :(weld cards.scheduled closed ~[timer]))
::
::  a daemon reconciling its orphans after a restart asks what became of
::  an attempt (D7); the answer is the attempt's status, nothing more
::
++  handle-attempt-read
  |=  [eyre-id=@ta req=inbound-request:eyre segment=@t]
  ^-  out
  =/  attempt-id=(unit @uv)  (slaw %uv segment)
  =/  found=(unit attempt:ci)  ?~(attempt-id ~ (~(get by attempts) u.attempt-id))
  ?~  found
    (emit (give-error eyre-id 404 'no such attempt'))
  ?.  (attempt-authorized req u.found)
    (emit (give-error eyre-id 401 'attempt authentication required'))
  =.  daemons  (touch-daemon daemon.u.found)
  (emit (give-json eyre-id 200 (attempt-json u.found)))
::
::  one relayed act line.  validated and bounded by ci-event; a set-output
::  lands in the attempt's outputs and a jobResult is remembered so the
::  daemon cannot later claim a result it never relayed.  nothing else
::  about the event is kept.
::
++  handle-event
  |=  [eyre-id=@ta req=inbound-request:eyre segment=@t]
  ^-  out
  =/  attempt-id=(unit @uv)  (slaw %uv segment)
  =/  found=(unit attempt:ci)  ?~(attempt-id ~ (~(get by attempts) u.attempt-id))
  ?~  found
    (emit (give-error eyre-id 404 'no such attempt'))
  ?.  (attempt-authorized req u.found)
    (emit (give-error eyre-id 401 'attempt authentication required'))
  ?.  =(%running status.u.found)
    (emit (give-error eyre-id 409 'attempt is closed'))
  ?:  (gte events.u.found max-events:ci-event)
    (emit (give-error eyre-id 429 'attempt event limit reached'))
  =/  body=octs  ?~(body.request.req [0 0] u.body.request.req)
  =/  parsed=(each event:ci refusal:ci-event)  (parse:ci-event body)
  ?:  ?=(%| -.parsed)
    (emit (give-error eyre-id status.p.parsed message.p.parsed))
  ::  the ship's own credential fence (D4): the message, a set-output value
  ::  and a summary body are scrubbed of every released value before
  ::  anything of the event is kept
  ::
  =/  =event:ci  (scrub:ci-event p.parsed (credential-values (candidate-repo candidate.u.found)))
  =/  redacted=?
    ?.  ?&(?=([~ %set-output *] command.p.parsed) ?=([~ %set-output *] command.event))  %.n
    !=(value.u.command.p.parsed value.u.command.event)
  ::  the tripwire for the daemon's single-job projection (CI-PROJECT-1):
  ::  a line from any job but the assigned one means act ran more than
  ::  the ship admitted
  ::
  ?:  ?&(?=(%job kind.u.found) ?=(^ job.u.found) !=(u.job.u.found job-id.event))
    (emit (give-error eyre-id 409 'event job does not match the assignment'))
  ::  the name act ran the job under, as act's own line says it: `job` is
  ::  `<workflow name>/<run name>`, and the projection names the run
  ::  `<attempt>/<the job's name or id>` (CI-PROJECT-1.1)
  ::
  =/  seen-under=(unit @t)
    ?^  projection-name.u.found  projection-name.u.found
    `job.event
  ::  a step output lands under the step act names it by (Delivery 1B);
  ::  past the attempt's bound it is refused, never silently dropped
  ::
  =/  recorded=(unit (list step-output:ci))
    (record-output:ci-event step-outputs.u.found event redacted)
  ?~  recorded
    %-  emit
    (give-error eyre-id 413 'the attempt\'s step outputs exceed their bound (256 outputs, 1 MiB)')
  =/  next=attempt:ci
    %=  u.found
      events  +(events.u.found)
      step-outputs  u.recorded
      job-result  ?^(job-result.event job-result.event job-result.u.found)
      projection-name  seen-under
    ==
  =.  attempts  (~(put by attempts) id.next next)
  =.  daemons  (touch-daemon daemon.next)
  (emit (give-json eyre-id 202 (attempt-json next)))
::
::  what the launcher pinned each granted DNS name to for this run
::  (CI-P4-NET-1, pinned addresses shown per run): `{"pinned": [{"name",
::  "addrs"}]}`, posted once by the attempt's daemon when its VM starts.
::  the names must be exactly the DNS names among the destinations the
::  attempt's manifest grants — the current policy's, since a policy
::  change cancels every running attempt (bump-generation) — each with 1
::  to 64 distinct IPv4 addresses in their plain form.  kept in the ship's
::  name order; a second report is refused, never merged
::
++  handle-pinned
  |=  [eyre-id=@ta req=inbound-request:eyre segment=@t]
  ^-  out
  =/  attempt-id=(unit @uv)  (slaw %uv segment)
  =/  found=(unit attempt:ci)  ?~(attempt-id ~ (~(get by attempts) u.attempt-id))
  ?~  found
    (emit (give-error eyre-id 404 'no such attempt'))
  ?.  (attempt-authorized req u.found)
    (emit (give-error eyre-id 401 'attempt authentication required'))
  ?.  =(%running status.u.found)
    (emit (give-error eyre-id 409 'attempt is closed'))
  ?^  pinned.u.found
    (emit (give-error eyre-id 409 'the pinned addresses are recorded already'))
  =/  cand=(unit candidate:ci)  (~(get by candidates) candidate.u.found)
  ?~  cand
    (emit (give-error eyre-id 409 'the attempt names no candidate'))
  =/  =manifest:ci-provenance  (manifest-of u.cand u.found)
  =/  granted=(list @t)  (granted-names:ci-provenance scope.manifest)
  ?~  granted
    (emit (give-error eyre-id 409 'this attempt was granted no DNS name'))
  =/  jon=(unit json)  (body-json req)
  ?~  jon
    (emit (give-error eyre-id 400 'valid JSON body required'))
  =/  parsed=(each (list pin:ci) @t)  (parse-pinned:ci-provenance u.jon granted)
  ?:  ?=(%| -.parsed)
    (emit (give-error eyre-id 422 p.parsed))
  =/  next=attempt:ci  u.found(pinned p.parsed)
  =.  attempts  (~(put by attempts) id.next next)
  =.  daemons  (touch-daemon daemon.next)
  (emit (give-json eyre-id 200 (attempt-json next)))
::
++  pinned-json
  |=  pins=(list pin:ci)
  ^-  json
  :-  %a
  %+  turn  pins
  |=  =pin:ci
  %-  pairs:enjs:format
  :~  ['name' s+name.pin]
      ['addrs' a+(turn addrs.pin |=(a=@t s+a))]
  ==
::
::  the claimed result.  a job result is accepted only after the daemon
::  relayed a matching jobResult event; an infrastructure error is always
::  accepted and never reads as success.
::
++  handle-result
  |=  [eyre-id=@ta req=inbound-request:eyre segment=@t]
  ^-  out
  =/  attempt-id=(unit @uv)  (slaw %uv segment)
  =/  found=(unit attempt:ci)  ?~(attempt-id ~ (~(get by attempts) u.attempt-id))
  ?~  found
    (emit (give-error eyre-id 404 'no such attempt'))
  ?.  (attempt-authorized req u.found)
    (emit (give-error eyre-id 401 'attempt authentication required'))
  ?.  =(%running status.u.found)
    (emit (give-error eyre-id 409 'attempt is closed'))
  =/  jon=(unit json)  (body-json req)
  ?~  jon
    (emit (give-error eyre-id 400 'valid JSON body required'))
  =/  claimed=(unit @t)  (string-at 'job-result' u.jon)
  =/  infrastructure=(unit @t)  (string-at 'infrastructure-error' u.jon)
  ?^  claimed
    =/  result=(unit result:ci)
      ?+  u.claimed  ~
        %success  `%success
        %failure  `%failure
        %skipped  `%skipped
        %cancelled  `%cancelled
      ==
    ?~  result
      (emit (give-error eyre-id 422 'job-result must be success, failure, skipped or cancelled'))
    ?~  job-result.u.found
      (emit (give-error eyre-id 409 'no jobResult event was relayed for this attempt'))
    ?.  =(u.job-result.u.found u.result)
      (emit (give-error eyre-id 409 'job-result does not match the relayed jobResult event'))
    =/  named=(each (unit object-ref:ci) @t)  (result-log u.found u.jon)
    ?:  ?=(%| -.named)
      (emit (give-error eyre-id 422 p.named))
    ::  a store outage is unknown, never green (R5.1-A).  a job that
    ::  claims success or a skip must name the log it stored.  without
    ::  that log the attempt closes as an infrastructure error, and the
    ::  candidate reads as unknown.  a failure stands without a log,
    ::  because it is never green
    ::
    ?:  ?&  ?=(%job kind.u.found)
            ?=(~ p.named)
            ?=(?(%success %skipped) u.result)
        ==
      =.  state  (close-attempt u.found [%infrastructure-error no-log-reason])
      =/  closed=out  (after-close candidate.u.found)
      =.  state  state.closed
      =.  polls  polls.closed
      %-  emit
      (weld cards.closed (give-json eyre-id 200 (attempt-json (~(got by attempts) id.u.found))))
    =/  with-log=attempt:ci  u.found(log p.named)
    =.  attempts  (~(put by attempts) id.with-log with-log)
    =.  state  (close-attempt with-log [%job-result u.result])
    ::  its declared outputs, resolved at the end of the job from what it
    ::  recorded (Delivery 1B): what its dependents' needs contexts read
    ::
    =.  attempts
      =/  closed=attempt:ci  (~(got by attempts) id.u.found)
      (~(put by attempts) id.closed closed(job-outputs (resolve-outputs closed)))
    =/  closed=out  (after-close candidate.u.found)
    =.  state  state.closed
    =.  polls  polls.closed
    %-  emit
    (weld cards.closed (give-json eyre-id 200 (attempt-json (~(got by attempts) id.u.found))))
  ?^  infrastructure
    =.  state  (close-attempt u.found [%infrastructure-error u.infrastructure])
    =/  closed=out  (after-close candidate.u.found)
    =.  state  state.closed
    =.  polls  polls.closed
    %-  emit
    (weld cards.closed (give-json eyre-id 200 (attempt-json (~(got by attempts) id.u.found))))
  (emit (give-error eyre-id 422 'job-result or infrastructure-error is required'))
::
::  a closed job attempt's declared outputs (Delivery 1B), resolved as
::  GitHub does at the end of the job: each template evaluated over the
::  steps' outputs the attempt recorded, its own needs context, the run's
::  github and inputs.  a value that cannot be resolved keeps its reason;
::  every value is scrubbed of the repository's credentials (D4).  a plan
::  saved before state-4 declared nothing the ship read: ~
::
++  resolve-outputs
  |=  a=attempt:ci
  ^-  (unit (list job-output:ci))
  ?.  ?=(%job kind.a)  ~
  =/  c=(unit candidate:ci)  (~(get by candidates) candidate.a)
  ?~  c  ~
  =/  planned=(unit job:ci)  (planned-job u.c workflow.a job.a)
  ?~  planned  ~
  ?~  outputs.u.planned  ~
  =/  context=run-context:ci-plan  (run-context u.c)
  =/  =scope:ci-expr
    :*  %:  github-of:ci-expr
          event.context  payload.context  ref.context  sha.context
          actor.context  name.u.planned  id.u.planned
        ==
        (needs-of:ci-expr needs.a)
        [%obj ~]
        inputs.context
        (steps-of:ci-expr step-outputs.a)
        %.y
        %.n
        %.n
    ==
  =/  values=(list @t)  (credential-values repo.u.c)
  =/  fenced=?  (lien step-outputs.a |=(o=step-output:ci redacted.o))
  :-  ~
  %+  turn  (resolve:ci-expr u.outputs.u.planned scope)
  |=  [name=@t r=(each @t @t)]
  ^-  job-output:ci
  ?:  ?=(%| -.r)  [name [%| p.r] %.n]
  =/  clean=@t  (scrub-text:ci-event p.r values)
  :+  name  [%& clean]
  ?|(!=(clean p.r) &(fenced ?=(^ (find "***" (trip clean)))))
::
::  the log a result names (D1): `log: {size, sha256}` records the handle
::  of the finished act stream the daemon uploaded under log.jsonl before
::  it posted the result.  the key is the attempt's own, never the body's;
::  a result that names no log leaves the attempt without one, and the
::  verdict stands either way.
::
++  result-log
  |=  [=attempt:ci jon=json]
  ^-  (each (unit object-ref:ci) @t)
  ?.  ?=([%o *] jon)  [%& ~]
  =/  log=(unit json)  (~(get by p.jon) 'log')
  ?~  log  [%& ~]
  ?~  u.log  [%& ~]
  ?.  ?=([%o *] u.log)  [%| 'log must be an object with size and sha256']
  =/  size=(unit (unit @ud))  (number-at 'size' u.log)
  =/  sha=(unit @t)  (string-at 'sha256' u.log)
  ?.  ?&(?=(^ size) ?=(^ u.size))  [%| 'log.size must be a natural number']
  ?~  sha  [%| 'log.sha256 is required']
  ?.  (sha256-text-valid:ci-storage u.sha)  [%| 'log.sha256 must be 64 hex digits']
  [%& `[(attempt-object-key attempt 'log.jsonl') u.u.size u.sha]]
::
::  the daemon asks for an upload (D2): a header-authorized SigV4 PUT into
::  the attempt's own trust namespace, for one of the names the fence
::  allows, with the payload hash the daemon computed.  the ship never
::  sees the bytes.  an attempt that is no longer running has nothing to
::  upload; a store that is not configured cannot be uploaded to.
::
++  handle-upload
  |=  [eyre-id=@ta req=inbound-request:eyre segment=@t]
  ^-  out
  =/  attempt-id=(unit @uv)  (slaw %uv segment)
  =/  found=(unit attempt:ci)  ?~(attempt-id ~ (~(get by attempts) u.attempt-id))
  ?~  found
    (emit (give-error eyre-id 404 'no such attempt'))
  ?.  (attempt-authorized req u.found)
    (emit (give-error eyre-id 401 'attempt authentication required'))
  =/  jon=(unit json)  (body-json req)
  ?~  jon
    (emit (give-error eyre-id 400 'valid JSON body required'))
  =/  name=(unit @t)  (string-at 'name' u.jon)
  ?~  name
    (emit (give-error eyre-id 400 'name is required'))
  ?.  (upload-name-allowed:ci-storage u.name)
    (emit (give-error eyre-id 400 'name must be log.jsonl, summary.md or artifact/<file>'))
  =/  content-type=@t  (fall (string-at 'contentType' u.jon) 'application/octet-stream')
  =/  sha=(unit @t)  (string-at 'sha256' u.jon)
  ?~  sha
    (emit (give-error eyre-id 400 'sha256 is required'))
  ?.  (sha256-text-valid:ci-storage u.sha)
    (emit (give-error eyre-id 400 'sha256 must be 64 hex digits'))
  =/  size=(unit (unit @ud))  (number-at 'size' u.jon)
  ?.  ?&(?=(^ size) ?=(^ u.size))
    (emit (give-error eyre-id 400 'size must be a natural number'))
  ?.  (active:ci-resolve state u.found)
    (emit (give-error eyre-id 409 'attempt is closed'))
  =/  signed=(unit signed-request:git-storage)
    %:  sign-put:ci-storage
      (read-settings:ci-storage our.bowl now.bowl)
      (candidate-repo candidate.u.found)
      (scot %uv candidate.u.found)
      (scot %uv id.u.found)
      trust.u.found
      u.name
      content-type
      u.sha
      now.bowl
    ==
  ?~  signed
    (emit (give-error eyre-id 503 storage-refusal))
  =.  daemons  (touch-daemon daemon.u.found)
  %-  emit
  %^  give-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['url' s+url.u.signed]
      ['method' s+'PUT']
      ['key' s+(attempt-object-key u.found u.name)]
      ['trust' s+trust.u.found]
      :-  'headers'
      %-  pairs:enjs:format
      (turn headers.u.signed |=([k=@t v=@t] [k s+v]))
  ==
::
::  a viewer reads an attempt's log (D2): a 302 to a presigned GET the
::  browser follows with no headers of its own, in the attempt's own
::  trust class; 404 while no result has named a log.  the ship session
::  is the authorization; a daemon bearer is not a viewer.
::
++  handle-log-read
  |=  [eyre-id=@ta req=inbound-request:eyre segment=@t]
  ^-  out
  ?.  (viewer req)
    (emit (give-error eyre-id 401 'session required'))
  =/  attempt-id=(unit @uv)  (slaw %uv segment)
  =/  found=(unit attempt:ci)  ?~(attempt-id ~ (~(get by attempts) u.attempt-id))
  ?~  found
    (emit (give-error eyre-id 404 'no such attempt'))
  ?~  log.u.found
    (emit (give-error eyre-id 404 'attempt has no log'))
  =/  url=(unit @t)  (presign-log u.found trust.u.found 'log.jsonl' log-link-expiry)
  ?~  url
    (emit (give-error eyre-id 503 storage-refusal))
  %-  emit
  %+  give-simple-payload:app:server  eyre-id
  [[302 ~[['location' u.url] ['cache-control' 'no-store']]] ~]
::
::  the candidate as the CI tab reads it (D6): the record, with times as
::  unix seconds, and each attempt's status, timing and whether a log
::  was recorded.  no credential value can be here: none is on either.
::
++  attempt-summary-json
  |=  =attempt:ci
  ^-  json
  %-  pairs:enjs:format
  :~  ['attempt' s+(scot %uv id.attempt)]
      ['kind' s+kind.attempt]
      ['workflow' ?~(workflow.attempt ~ s+u.workflow.attempt)]
      ['job' ?~(job.attempt ~ s+u.job.attempt)]
      ['status' s+status.attempt]
      ['trust' s+trust.attempt]
      ['daemon' ?:(=(0v0 daemon.attempt) ~ s+(scot %uv daemon.attempt))]
      ['events' (numb:enjs:format events.attempt)]
      ['reason' ?~(reason.attempt ~ s+u.reason.attempt)]
      ['started' (numb:enjs:format (unix-seconds started.attempt))]
      ['finished' ?~(finished.attempt ~ (numb:enjs:format (unix-seconds u.finished.attempt)))]
      ['log' (object-ref-json log.attempt)]
      ['generation' (numb:enjs:format generation.attempt)]
      ['mode' s+mode.attempt]
      ['manifest' s+(scot %uv manifest.attempt)]
      ['sandbox' s+sandbox.attempt]
      ['network' s+network.attempt]
      ['approval' ?~(approval.attempt ~ s+(scot %uv u.approval.attempt))]
      ['outcome' s+outcome.attempt]
      ['pinned' (pinned-json pinned.attempt)]
      ::  Delivery 1B: why the job ran or did not, the needs context it
      ::  was given, what its steps recorded and what it published
      ['decision' (decision-json decision.attempt)]
      ['needs' (needs-json needs.attempt)]
      ['stepOutputs' (step-outputs-json step-outputs.attempt)]
      ['stepOutputCount' (numb:enjs:format (lent step-outputs.attempt))]
      ['jobOutputs' (job-outputs-json job-outputs.attempt)]
  ==
::
::  a decision, a needs context and outputs as the CI tab reads them
::  (Delivery 1B): text only.  the values are what the ship recorded,
::  scrubbed of the repository's credentials when they were recorded; a
::  value is shown up to 1 KiB and says when it was cut, and at most 64
::  step outputs are listed (stepOutputCount counts them all)
::
++  decision-json
  |=  d=(unit decision:ci)
  ^-  json
  ?~  d  ~
  %-  pairs:enjs:format
  :~  ['verdict' s+verdict.u.d]
      ['reason' s+reason.u.d]
      ['value' ?~(value.u.d ~ s+u.value.u.d)]
  ==
::
++  shown-value
  |=  value=@t
  ^-  [text=@t cut=?]
  ?:  (lte (met 3 value) 1.024)  [value %.n]
  [(end [3 1.024] value) %.y]
::
++  needs-json
  |=  needs=(list need-entry:ci)
  ^-  json
  :-  %a
  %+  turn  needs
  |=  n=need-entry:ci
  %-  pairs:enjs:format
  :~  ['job' s+id.n]
      ['attempt' s+(scot %uv attempt.n)]
      ['status' s+status.n]
      ['result' s+result.n]
      :-  'outputs'
      :-  %a
      %+  turn  outputs.n
      |=  [name=@t value=@t]
      =/  v  (shown-value value)
      (pairs:enjs:format ~[['name' s+name] ['value' s+text.v] ['cut' b+cut.v]])
  ==
::
++  step-outputs-json
  |=  outputs=(list step-output:ci)
  ^-  json
  :-  %a
  %+  turn  (scag 64 outputs)
  |=  o=step-output:ci
  =/  v  (shown-value value.o)
  %-  pairs:enjs:format
  :~  ['step' [%a (turn step.o |=(id=@t s+id))]]
      ['name' s+name.o]
      ['value' s+text.v]
      ['cut' b+cut.v]
      ['redacted' b+redacted.o]
  ==
::
++  job-outputs-json
  |=  outputs=(unit (list job-output:ci))
  ^-  json
  ?~  outputs  ~
  :-  %a
  %+  turn  u.outputs
  |=  o=job-output:ci
  %-  pairs:enjs:format
  ?:  ?=(%| -.value.o)
    :~  ['name' s+name.o]  ['value' ~]  ['error' s+p.value.o]
        ['cut' b+%.n]  ['redacted' b+redacted.o]
    ==
  =/  v  (shown-value p.value.o)
  :~  ['name' s+name.o]  ['value' s+text.v]  ['error' ~]
      ['cut' b+cut.v]  ['redacted' b+redacted.o]
  ==
::
::  a job's condition as written, where, and whether it is a plan's from
::  before state-4
::
++  condition-json
  |=  cond=(unit condition:ci)
  ^-  json
  ?~  cond  ~
  =/  c=(unit summary:ci-expr)  `(summarize:ci-expr u.cond)
  ?>  ?=(^ c)
  ?-  -.u.c
      %if
    %-  pairs:enjs:format
    :~  ['text' s+text.u.c]  ['line' (numb:enjs:format line.u.c)]
        ['col' (numb:enjs:format col.u.c)]  ['legacy' b+%.n]  ['refusal' ~]
    ==
  ::
      %output-eq
    %-  pairs:enjs:format
    :~  ['text' s+(rap 3 ~['needs.' job.u.c '.outputs.' output.u.c ' == \'' literal.u.c '\''])]
        ['line' ~]  ['col' ~]  ['legacy' b+%.y]  ['refusal' ~]
    ==
  ::
      %refused
    %-  pairs:enjs:format
    :~  ['text' s+text.u.c]  ['line' ~]  ['col' ~]  ['legacy' b+%.y]
        ['refusal' s+reason.u.c]
    ==
  ==
::
++  decision-reason
  |=  d=decision:ci-plan
  ^-  @t
  ?-  -.d
    %run  reason.d
    %skip  reason.d
    %cancel  reason.d
    %error  reason.d
    %wait  reason.d
  ==
::
::  CI-CONCURRENCY-1: a run's concurrency as the CI tab reads it: its
::  state, why it takes part in no group, and each workflow's group, its
::  place, the run it waits behind, its cancellation and whether its run
::  finished.  a run in no group lists the workflows it knows with no
::  group, so one of them can still be cancelled.  runs are named by
::  their label, their ids beside them for the fine print
::
++  concurrency-json
  |=  c=candidate:ci
  ^-  json
  =/  rc=run-concurrency:ci  concurrency.c
  %-  pairs:enjs:format
  :~  ['state' s+-.rc]
      :-  'reason'
      ?+  -.rc  ~
        %exempt  s+reason.rc
        %unknown  s+reason.rc
      ==
      ['joined' ?.(?=(%joined -.rc) ~ (numb:enjs:format (unix-seconds at.rc)))]
      :-  'workflows'
      :-  %a
      ?.  ?=(%joined -.rc)
        %+  turn  (run-workflows:ci-concurrency c)
        |=  workflow=@t
        %-  pairs:enjs:format
        :~  ['workflow' s+workflow]
            ['name' s+workflow]
            ['group' ~]
            ['cancelled' (cancellation-json (cancellation-of:ci-concurrency c workflow))]
            ['finished' b+(workflow-finished:ci-concurrency state c workflow)]
        ==
      %+  turn  runs.rc
      |=  r=workflow-run:ci
      %-  pairs:enjs:format
      :~  ['workflow' s+workflow.r]
          ['name' s+name.r]
          ['group' (group-json group.r)]
          ['cancelled' (cancellation-json (cancellation-of:ci-concurrency c workflow.r))]
          ['finished' b+(workflow-finished:ci-concurrency state c workflow.r)]
      ==
  ==
::
++  group-json
  |=  g=workflow-group:ci
  ^-  json
  ?-  -.g
    %free  (pairs:enjs:format ~[['kind' s+'free']])
    %unknown  (pairs:enjs:format ~[['kind' s+'unknown'] ['reason' s+reason.g]])
    %refused  (pairs:enjs:format ~[['kind' s+'refused'] ['reason' s+reason.g]])
  ::
      %member
    %-  pairs:enjs:format
    :~  ['kind' s+'member']
        ['text' s+text.g]
        ['cancelInProgress' b+cancel.g]
        ['place' s+place.g]
        ['behind' ?~(behind.g ~ (run-ref-json u.behind.g))]
        ['since' (numb:enjs:format (unix-seconds since.g))]
    ==
  ==
::
::  another run, by its label and, for the fine print, its id
::
++  run-ref-json
  |=  id=candidate-id:ci
  ^-  json
  %-  pairs:enjs:format
  :~  ['id' s+(scot %uv id)]
      ['label' s+(label-of:ci-concurrency state id)]
  ==
::
++  cancellation-json
  |=  c=(unit cancellation:ci)
  ^-  json
  ?~  c  ~
  =/  =cancel-cause:ci  cause.u.c
  %-  pairs:enjs:format
  :~  ['at' (numb:enjs:format (unix-seconds at.u.c))]
      ['started' b+started.u.c]
      ['cause' s+-.cancel-cause]
      ['reason' s+reason.u.c]
      ['actor' ?.(?=(%operator -.cancel-cause) ~ s+(scot %p actor.cancel-cause))]
      ['by' ?:(?=(%operator -.cancel-cause) ~ (run-ref-json by.cancel-cause))]
      ['group' ?:(?=(%operator -.cancel-cause) ~ s+group.cancel-cause)]
  ==
::
::  whether this session's ship may cancel a run: the ci-policy role (the
::  owner's implicitly), on a run still in progress and not cancelled whole
::
++  may-cancel
  |=  c=candidate:ci
  ^-  ?
  ?&  (authorized repo.c %ci-policy ~ our.bowl)
      =(%pending status.c)
      !(resolver-record c)
      !(~(has by cancelled.c) '')
  ==
::
++  no-cancel-authority
  ^-  @t
  'only the repository\'s owner, or a ship holding its ci-policy role, cancels a run'
::
::  a lock catalog workflow's compiled concurrency, in brief: null when the
::  lock's compiler did not read it, which is unknown
::
++  concurrency-def-json
  |=  d=(unit concurrency-def:ci)
  ^-  json
  ?~  d  ~
  ?-  -.u.d
    %none  (pairs:enjs:format ~[['kind' s+'none']])
    %refused  (pairs:enjs:format ~[['kind' s+'refused'] ['reason' s+reason.u.d]])
  ::
      %group
    %-  pairs:enjs:format
    :~  ['kind' s+'group']
        ['group' s+text.group.u.d]
        :-  'cancelInProgress'
        ?-  -.cancel.u.d
          %fixed  b+p.cancel.u.d
          %expr  s+text.cancel.u.d
        ==
    ==
  ==
::
++  workflow-provenance-json
  |=  c=candidate:ci
  ^-  json
  ?.  (tagged-run c)  ~
  =/  resolution=@t
    ?^  selected.c  'resolved'
    ?:  =(%pending status.c)  'pending'
    ?:  =(%skipped status.c)
      ?:  =(`'superseded by approval' verdict-reason.c)  'superseded'
      'cancelled'
    'refused'
  =/  resolver=(unit attempt-id:ci)  (~(got by tag-runs) id.c)
  %-  pairs:enjs:format
  :~  ['authority' s+'tagged-revision']
      ['source' s+(oid-text:git-codec head.c)]
      ['revision' ?~(baseline.c ~ s+(oid-text:git-codec u.baseline.c))]
      ['lock' ?~(lock.c ~ s+(hex-bytes:ci-provenance u.lock.c 32))]
      ['resolution' s+resolution]
      ['resolverAttempt' ?~(resolver ~ s+(scot %uv u.resolver))]
      ['inputPolicyId' s+(context-digest:ci-dispatch (scope:ci-input (captured:ci-input state id.c)))]
      ['inputPolicy' (envelope:ci-input (captured:ci-input state id.c))]
      ['inputPolicyRecorded' b+(~(has by input-snapshots) id.c)]
      :-  'acquisition'
      :-  %s
      ?~  resolver
        ?^  lock.c  'cached prior resolution; no new external fetch authorized'
        'awaiting resolution; no external acquisition recorded'
      'captured automatic resolver'
      :-  'inputEvidence'
      ?~  lock.c  ~
      =/  e=(unit @t)  (~(get by input-evidence) u.lock.c)
      ?~(e ~ (fall (de:json:html u.e) ~))
  ==
::
++  candidate-json
  |=  =candidate:ci
  ^-  json
  %-  pairs:enjs:format
  :~  ['id' s+(scot %uv id.candidate)]
      ['repo' s+repo.candidate]
      ['ref' s+ref.candidate]
      ['head' s+(oid-text:git-codec head.candidate)]
      ['base' s+(oid-text:git-codec base.candidate)]
      ['candidate' ?~(candidate.candidate ~ s+(oid-text:git-codec u.candidate.candidate))]
      ['conflict' b+conflict.candidate]
      ['status' s+status.candidate]
      ['trust' s+trust.candidate]
      ['actor' s+(scot %p actor.candidate)]
      ['via' s+via.candidate]
      ['pull' ?~(pull.candidate ~ (numb:enjs:format u.pull.candidate))]
      ['verdictReason' ?~(verdict-reason.candidate ~ s+u.verdict-reason.candidate)]
      :-  'waits'
      :-  %a
      %+  turn  (job-waits candidate)
      |=  [workflow=@t job=@t reason=@t]
      (pairs:enjs:format ~[['workflow' s+workflow] ['job' s+job] ['reason' s+reason]])
      ['planned' b+?=(^ plan.candidate)]
      :-  'plan'
      ?~  plan.candidate  ~
      ::  each job's condition and declared outputs (Delivery 1B), and for
      ::  a job of a pending run with no attempt yet, its decision now:
      ::  waiting for a need, about to run, or a skip or refusal the next
      ::  settle records
      ::
      =/  known  (standings candidate)
      =/  entries=(map key:ci-plan need-entry:ci)
        %^  need-entries
          candidate
          newest.known
        standings.known
      =/  context=run-context:ci-plan  (run-context candidate)
      :-  %a
      %+  turn  u.plan.candidate
      |=  =job:ci
      =/  live=json
        ?:  (~(has by standings.known) [workflow.job id.job])  ~
        ?.  =(%pending status.candidate)  ~
        =/  d=decision:ci-plan
          %:  decide-with:ci-concurrency
            state
            candidate
            job
            u.plan.candidate
            standings.known
            entries
            context
          ==
        (pairs:enjs:format ~[['verdict' s+-.d] ['reason' s+(decision-reason d)]])
      %-  pairs:enjs:format
      :~  ['id' s+id.job]
          ['workflow' s+workflow.job]
          ['name' s+name.job]
          ['stage' (numb:enjs:format stage.job)]
          ['needs' [%a (turn needs.job |=(need=@t s+need))]]
          ['runsOn' [%a (turn (sort ~(tap in runs-on.job) aor) |=(l=@t s+l))]]
          ['timeoutMinutes' ?~(timeout.job ~ (numb:enjs:format u.timeout.job))]
          ['if' (condition-json cond.job)]
          :-  'outputs'
          ?~  outputs.job  ~
          :-  %a
          %+  turn  (output-places:ci-expr u.outputs.job)
          |=  [name=@t text=@t line=@ud col=@ud]
          %-  pairs:enjs:format
          :~  ['name' s+name]  ['text' s+text]
              ['line' (numb:enjs:format line)]  ['col' (numb:enjs:format col)]
          ==
          ['decision' live]
      ==
      ['created' (numb:enjs:format (unix-seconds created.candidate))]
      ['updated' (numb:enjs:format (unix-seconds updated.candidate))]
      ['workflowAuthority' s+?:((tagged-run candidate) 'tagged-revision' 'promoted-baseline')]
      ['workflowProvenance' (workflow-provenance-json candidate)]
      ['mode' s+mode.candidate]
      ['generation' (numb:enjs:format generation.candidate)]
      ['currentGeneration' (numb:enjs:format (current-generation repo.candidate))]
      ['baseline' ?~(baseline.candidate ~ s+(oid-text:git-codec u.baseline.candidate))]
      ['lock' ?~(lock.candidate ~ s+(hex-bytes:ci-provenance u.lock.candidate 32))]
      ['incarnation' s+(scot %uv incarnation.candidate)]
      ['sandbox' s+sandbox.candidate]
      ['trialOf' ?~(trial-of.candidate ~ s+(scot %uv u.trial-of.candidate))]
      ['harnessDiffers' b+harness-differs.candidate]
      ['bindingsCurrent' b+(bindings-current candidate)]
      ['landable' b+(landable candidate)]
      ::  CI-CONCURRENCY-1: each workflow's group and place, every
      ::  cancellation, and whether this session's ship may cancel
      ['concurrency' (concurrency-json candidate)]
      :-  'cancellations'
      :-  %a
      %+  turn
        (sort ~(tap by cancelled.candidate) |=([a=[@t *] b=[@t *]] (aor -.a -.b)))
      |=  [workflow=@t =cancellation:ci]
      =/  base=json  (cancellation-json `cancellation)
      ?.  ?=([%o *] base)  base
      [%o (~(put by p.base) 'workflow' s+workflow)]
      ['canCancel' b+(may-cancel candidate)]
      :-  'cancelAuthority'
      ?:  (authorized repo.candidate %ci-policy ~ our.bowl)  ~
      s+no-cancel-authority
      ['event' (event-json candidate)]
      ::  which workflows the event selected and why (Delivery 1C), and for
      ::  a required run whether its required evidence is complete: an
      ::  excluded or refused push workflow is evidence absent, never a pass
      ['selection' (selection-json selected.candidate)]
      :-  'requiredEvidence'
      ?.  =(%required mode.candidate)  ~
      =/  missing=(list workflow-selection:ci)
        ?~  selected.candidate  ~
        (unselected:ci-trigger outcomes.u.selected.candidate)
      %-  pairs:enjs:format
      :~  ['complete' b+=(~ missing)]
          ['evaluated' b+?&(?=(^ selected.candidate) ?=(~ note.u.selected.candidate))]
          ['missing' [%a (turn missing outcome-json)]]
      ==
      :-  'approvals'
      :-  %a
      %+  turn
        %+  skim  ~(val by approvals)
        |=(a=approval:ci =(candidate.a id.candidate))
      approval-json
      :-  'overrides'
      :-  %a
      %+  turn
        %+  skim  ~(val by overrides)
        |=(o=override:ci =(candidate.o id.candidate))
      override-json
      :-  'attempts'
      :-  %a
      %+  murn  attempts.candidate
      |=  id=attempt-id:ci
      ^-  (unit json)
      =/  found=(unit attempt:ci)  (~(get by attempts) id)
      ?~  found  ~
      `(attempt-summary-json u.found)
  ==
::
::  the event a run is for, as its record holds it (Delivery 1A): the
::  event act gives its jobs, who triggered it, the ref and the exact
::  source, the workflow revision its jobs run from, the payload act
::  reads with its digest (a push's once its integration object exists),
::  and for a manual run the workflow and the typed inputs as admitted
::  with how each was decided.  nothing here is secret: admission refused
::  any input holding a stored credential's value
::
++  event-json
  |=  c=candidate:ci
  ^-  json
  =/  common=(list [@t json])
    :~  ['workflowAuthority' s+?:((tagged-run c) 'tagged-revision' 'promoted-baseline')]
        ['actor' s+(scot %p actor.c)]
        ['ref' s+ref.c]
        ['source' s+(oid-text:git-codec head.c)]
        ['revision' ?~(baseline.c ~ s+(oid-text:git-codec u.baseline.c))]
        ::  the event the run was admitted for, as its manifest signs it
        ['trigger' s+(trigger-text:ci-trigger c)]
    ==
  ?-  -.trigger.c
      ::  an automatic event's run (Delivery 1C): the event, how it
      ::  arrived, its tips, the pull request or the occurrence, and the
      ::  payload act reads
      ::
      %event
    =/  e=run-event:ci  run-event.trigger.c
    %-  pairs:enjs:format
    :*  ['name' s+(event-name:ci-trigger trigger.c)]
        ['kind' s+kind.e]
        ['workflow' ~]
        ['inputs' [%a ~]]
        ['eventId' s+(scot %uv id.e)]
        ['route' s+route.e]
        ['at' (numb:enjs:format (unix-seconds at.e))]
        ['before' ?~(before.e ~ s+(oid-text:git-codec u.before.e))]
        ['after' ?~(after.e ~ s+(oid-text:git-codec u.after.e))]
        ['pull' (pull-facts-json pull.e)]
        ['occurrence' (occurrence-json occurrence.e)]
        ['payload' s+payload.e]
        ['payloadSha256' s+(context-digest:ci-dispatch payload.e)]
        common
    ==
  ::
      %push
    =/  payload=@t  (push-payload-of c)
    %-  pairs:enjs:format
    :*  ['name' s+'push']
        ['workflow' ~]
        ['inputs' [%a ~]]
        ['payload' ?~(candidate.c ~ s+payload)]
        ['payloadSha256' ?~(candidate.c ~ s+(context-digest:ci-dispatch payload))]
        common
    ==
  ::
      %dispatch
    %-  pairs:enjs:format
    :*  ['name' s+'workflow_dispatch']
        ['workflow' s+workflow.trigger.c]
        ['workflowName' s+name.trigger.c]
        ['request' s+request.trigger.c]
        ['payload' s+payload.trigger.c]
        ['payloadSha256' s+(context-digest:ci-dispatch payload.trigger.c)]
        :-  'inputs'
        :-  %a
        %+  turn  inputs.trigger.c
        |=  i=admitted-input:ci
        %-  pairs:enjs:format
        :~  ['id' s+id.i]
            ['type' s+kind.i]
            ['source' s+source.i]
            ['value' ?~(value.i ~ (input-value-json u.value.i))]
        ==
        common
    ==
  ==
::
::  an admitted value as JSON of its type: a boolean, a number (its plain
::  decimal text), or text
::
++  input-value-json
  |=  v=input-value:ci
  ^-  json
  ?-  -.v
    %boolean  b+p.v
    %number  [%n p.v]
    %string  s+p.v
  ==
::
++  approval-json
  |=  a=approval:ci
  ^-  json
  %-  pairs:enjs:format
  :~  ['id' s+(scot %uv id.a)]
      ['candidate' s+(scot %uv candidate.a)]
      ['oid' s+(oid-text:git-codec oid.a)]
      ['workflow' s+workflow.a]
      ['job' s+job.a]
      ['environment' s+environment.a]
      ['credentials' [%a (turn (sort ~(tap in credentials.a) aor) |=(c=@t s+c))]]
      ['baseline' s+(oid-text:git-codec baseline.a)]
      ['generation' (numb:enjs:format generation.a)]
      ['approver' s+(scot %p approver.a)]
      ['at' (numb:enjs:format (unix-seconds at.a))]
      ['expires' (numb:enjs:format (unix-seconds expires.a))]
      ['consumed' ?~(consumed.a ~ s+(scot %uv u.consumed.a))]
      ['invalidated' ?~(invalidated.a ~ s+u.invalidated.a)]
      :-  'state'
      :-  %s
      ?^  consumed.a  'consumed'
      ?^  invalidated.a  'invalidated'
      ?:((gte now.bowl expires.a) 'expired' 'valid')
  ==
::
++  override-json
  |=  o=override:ci
  ^-  json
  %-  pairs:enjs:format
  :~  ['id' s+(scot %uv id.o)]
      ['repo' s+repo.o]
      ['ref' s+ref.o]
      ['candidate' s+(scot %uv candidate.o)]
      ['oid' s+(oid-text:git-codec oid.o)]
      ['expected' s+(oid-text:git-codec expected.o)]
      ['actor' s+(scot %p actor.o)]
      ['reason' s+reason.o]
      ['missing' s+missing.o]
      ['generation' (numb:enjs:format generation.o)]
      ['at' (numb:enjs:format (unix-seconds at.o))]
      ['expires' (numb:enjs:format (unix-seconds expires.o))]
      ['consumed' ?~(consumed.o ~ (numb:enjs:format (unix-seconds u.consumed.o)))]
      ['invalidated' ?~(invalidated.o ~ s+u.invalidated.o)]
      :-  'state'
      :-  %s
      ?^  consumed.o  'used'
      ?^  invalidated.o  'invalidated'
      ?:((gte now.bowl expires.o) 'expired' 'valid')
  ==
::
::  ---- the views of events and schedules (Delivery 1C) ----
::
++  outcome-json
  |=  o=workflow-selection:ci
  ^-  json
  %-  pairs:enjs:format
  :~  ['workflow' s+workflow.o]  ['name' s+name.o]
      ['verdict' s+verdict.o]  ['reason' s+reason.o]
  ==
::
++  selection-json
  |=  s=(unit event-selection:ci)
  ^-  json
  ?~  s  ~
  %-  pairs:enjs:format
  :~  ['basis' s+basis.u.s]
      ['note' ?~(note.u.s ~ s+u.note.u.s)]
      ['outcomes' [%a (turn outcomes.u.s outcome-json)]]
  ==
::
++  pull-facts-json
  |=  p=(unit pull-facts:ci)
  ^-  json
  ?~  p  ~
  %-  pairs:enjs:format
  :~  ['number' (numb:enjs:format number.u.p)]
      ['title' s+title.u.p]
      ['action' s+action.u.p]
      ['head' s+(oid-text:git-codec head.u.p)]
      ['headRef' s+head-ref.u.p]
      ['baseRef' s+base-ref.u.p]
      ['base' s+(oid-text:git-codec base.u.p)]
      ['merged' b+merged.u.p]
      ['sourceShip' s+(scot %p source-ship.u.p)]
      ['sourceRepository' s+source-repository.u.p]
      ['labels' [%a (turn labels.u.p |=(name=@t s+name))]]
      ['label' ?~(label.u.p ~ s+u.label.u.p)]
  ==
::
::  an instant as the views show it: unix seconds, UTC, and the wall clock
::  of the schedule's zone from its pinned table
::
++  instant-json
  |=  [zone=(unit zone:ci) at=(unit @da)]
  ^-  json
  ?~  at  ~
  %-  pairs:enjs:format
  :~  ['at' (numb:enjs:format (unix-seconds u.at))]
      ['utc' s+(iso-utc:ci-cron u.at)]
      ['local' s+(local-text:ci-cron zone u.at)]
  ==
::
++  seconds-between
  |=  [a=@da b=@da]
  ^-  @ud
  ?:  (lte b a)  0
  (div (sub b a) ~s1)
::
++  occurrence-json
  |=  o=(unit occurrence-facts:ci)
  ^-  json
  ?~  o  ~
  =/  zone=(unit zone:ci)
    =/  hits=(list schedule-entry:ci)
      (skim ~(val by schedules) |=(e=schedule-entry:ci =(definition.e definition.u.o)))
    ?~(hits ~ zone.i.hits)
  %-  pairs:enjs:format
  :~  ['workflow' s+workflow.u.o]
      ['index' (numb:enjs:format index.u.o)]
      ['cron' s+cron.u.o]
      ['timezone' ?~(timezone.u.o ~ s+u.timezone.u.o)]
      ['due' (instant-json zone `due.u.o)]
      ['admitted' (instant-json zone `admitted.u.o)]
      ['lateSeconds' (numb:enjs:format (seconds-between due.u.o admitted.u.o))]
      ['late' b+(gth admitted.u.o (add due.u.o late-after:ci-cron))]
      ['definition' s+(scot %uv definition.u.o)]
      ['promoter' s+(scot %p promoter.u.o)]
      ['promoted' (numb:enjs:format (unix-seconds promoted.u.o))]
  ==
::
++  forge-event-json
  |=  e=forge-event:ci
  ^-  json
  %-  pairs:enjs:format
  :~  ['id' s+(scot %uv id.e)]
      ['kind' s+kind.e]
      ['ref' s+ref.e]
      ['before' ?~(before.e ~ s+(oid-text:git-codec u.before.e))]
      ['after' ?~(after.e ~ s+(oid-text:git-codec u.after.e))]
      ['pull' (pull-facts-json pull.e)]
      ['actor' s+(scot %p actor.e)]
      ['route' s+route.e]
      ['at' (numb:enjs:format (unix-seconds at.e))]
      ['received' (numb:enjs:format (unix-seconds received.e))]
      ['outcome' s+outcome.e]
      :-  'workflowProvenance'
      ?~  runs.e  ~
      =/  run=(unit candidate:ci)  (~(get by candidates) (rear runs.e))
      ?~(run ~ (workflow-provenance-json u.run))
      ['selection' (selection-json selected.e)]
      ['runs' [%a (turn runs.e |=(id=candidate-id:ci s+(scot %uv id)))]]
  ==
::
::  a repository's recorded forge events, newest first, at most fifty
::
++  events-json
  |=  repo=@t
  ^-  json
  =/  mine=(list forge-event:ci)
    %+  sort
      (skim ~(val by forge-events) |=(e=forge-event:ci =(repo repo.e)))
    |=([a=forge-event:ci b=forge-event:ci] (gth received.a received.b))
  %-  pairs:enjs:format
  :~  ['repo' s+repo]
      ['now' (numb:enjs:format (unix-seconds now.bowl))]
      ['events' [%a (turn (scag 50 mine) forge-event-json)]]
  ==
::
++  schedule-entry-json
  |=  [k=schedule-key:ci e=schedule-entry:ci]
  ^-  json
  %-  pairs:enjs:format
  :~  ['workflow' s+workflow.k]
      ['index' (numb:enjs:format index.k)]
      ['name' s+name.e]
      ['cron' s+cron.def.e]
      ['timezone' ?~(timezone.def.e ~ s+u.timezone.def.e)]
      ['timezoneLabel' s+?~(timezone.def.e 'UTC (default)' u.timezone.def.e)]
      ['state' s+state.e]
      ['reason' ?~(reason.e ~ s+u.reason.e)]
      ['refusal' ?~(refusal.def.e ~ s+u.refusal.def.e)]
      ['ref' s+ref.e]
      ['baseline' s+(oid-text:git-codec baseline.e)]
      ['lock' s+(hex-bytes:ci-provenance lock.e 32)]
      ['promoter' s+(scot %p promoter.e)]
      ['promoted' (numb:enjs:format (unix-seconds promoted.e))]
      ['registered' (numb:enjs:format (unix-seconds registered.e))]
      ['definition' s+(scot %uv definition.e)]
      ['next' (instant-json zone.e armed.e)]
      ['lastDue' (instant-json zone.e last-due.e)]
      :-  'lastAdmitted'
      ?~  last-admitted.e  ~
      =/  a  u.last-admitted.e
      %-  pairs:enjs:format
      :~  ['due' (instant-json zone.e `due.a)]
          ['at' (instant-json zone.e `at.a)]
          ['run' s+(scot %uv run.a)]
          ['late' b+late.a]
          ['lateSeconds' (numb:enjs:format (seconds-between due.a at.a))]
      ==
      :-  'missed'
      :-  %a
      %+  turn  missed.e
      |=  m=missed-interval:ci
      %-  pairs:enjs:format
      :~  ['first' (instant-json zone.e `first.m)]
          ['last' (instant-json zone.e `last.m)]
          ['count' (numb:enjs:format count.m)]
      ==
      ['staleWakes' (numb:enjs:format stale-wakes.e)]
  ==
::
::  a repository's schedules by workflow and entry, with the default
::  branch they come from and what the default branch's catalog needs
::  (refresh: a baseline to promote, or a lock to resolve again)
::
++  schedules-json
  |=  repo=@t
  ^-  json
  =/  default=(unit (unit @t))  (default-ref repo)
  =/  mine=(list [k=schedule-key:ci e=schedule-entry:ci])
    %+  sort
      (skim ~(tap by schedules) |=([k=schedule-key:ci *] =(repo repo.k)))
    |=  [a=[k=schedule-key:ci *] b=[k=schedule-key:ci *]]
    ?:  =(workflow.k.a workflow.k.b)  (lth index.k.a index.k.b)
    (aor workflow.k.a workflow.k.b)
  =/  refresh=(unit @t)
    ?~  default  `'%urgit cannot be read for the default branch'
    ?~  u.default  `'the repository has no default branch'
    =/  gov  (governing repo u.u.default)
    ?:(?=(%| -.gov) `p.gov ~)
  %-  pairs:enjs:format
  :~  ['repo' s+repo]
      ['now' (numb:enjs:format (unix-seconds now.bowl))]
      ['nowUtc' s+(iso-utc:ci-cron now.bowl)]
      ['defaultBranch' ?~(default ~ ?~(u.default ~ s+u.u.default))]
      ['refresh' ?~(refresh ~ s+u.refresh)]
      ['schedules' [%a (turn mine schedule-entry-json)]]
  ==
::
++  handle-events
  |=  [eyre-id=@ta req=inbound-request:eyre repo=@t]
  ^-  out
  ?.  (viewer req)
    (emit (give-error eyre-id 401 'session required'))
  (emit (give-json eyre-id 200 (events-json repo)))
::
++  handle-schedules
  |=  [eyre-id=@ta req=inbound-request:eyre repo=@t]
  ^-  out
  ?.  (viewer req)
    (emit (give-error eyre-id 401 'session required'))
  (emit (give-json eyre-id 200 (schedules-json repo)))
::
::  a repository's candidates newest first, at most fifty, from before
::  the candidate `before` names when the query carries one
::
++  handle-candidates
  |=  [eyre-id=@ta req=inbound-request:eyre repo=@t args=(list [@t @t])]
  ^-  out
  ?.  (viewer req)
    (emit (give-error eyre-id 401 'session required'))
  =/  before=(unit candidate:ci)
    =/  named=(unit @t)  (get-header:http 'before' args)
    ?~  named  ~
    =/  id=(unit @uv)  (slaw %uv u.named)
    ?~  id  ~
    (~(get by candidates) u.id)
  (emit (give-json eyre-id 200 (candidates-json repo before)))
::
::  a repository's candidates newest first, at most fifty, from before
::  the candidate `before` names when the caller gives one; the GET's
::  page and the live feed's initial fact are this one JSON
::
++  candidates-json
  |=  [repo=@t before=(unit candidate:ci)]
  ^-  json
  =/  mine=(list candidate:ci)
    %+  sort
      %+  skim  ~(val by candidates)
      |=  c=candidate:ci
      ?&  =(repo repo.c)
          ?~  before  %.y
          (lth created.c created.u.before)
      ==
    |=([a=candidate:ci b=candidate:ci] (gth created.a created.b))
  =/  page=(list candidate:ci)  (scag 50 mine)
  %-  pairs:enjs:format
  :~  ['repo' s+repo]
      ['candidates' [%a (turn page candidate-json)]]
      ['more' b+(gth (lent mine) 50)]
  ==
::
++  handle-candidate-read
  |=  [eyre-id=@ta req=inbound-request:eyre segment=@t]
  ^-  out
  ?.  (viewer req)
    (emit (give-error eyre-id 401 'session required'))
  =/  id=(unit @uv)  (slaw %uv segment)
  =/  found=(unit candidate:ci)  ?~(id ~ (~(get by candidates) u.id))
  ?~  found
    (emit (give-error eyre-id 404 'no such candidate'))
  %-  emit
  %^  give-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['candidate' (candidate-json u.found)]
      :-  'attempts'
      :-  %a
      %+  murn  attempts.u.found
      |=  id=attempt-id:ci
      ^-  (unit json)
      =/  att=(unit attempt:ci)  (~(get by attempts) id)
      ?~  att  ~
      `(attempt-summary-json u.att)
  ==
::
::  the repository's CI policy for the settings page: which refs require
::  CI and what an untrusted revision gets
::
++  handle-policy
  |=  [eyre-id=@ta req=inbound-request:eyre repo=@t]
  ^-  out
  ?.  (viewer req)
    (emit (give-error eyre-id 401 'session required'))
  (emit (give-json eyre-id 200 (policy-json repo)))
::
::  the repository's whole CI policy as the settings page and the
::  provenance panel read it (D7): protection, baselines, roles (the
::  owner implicit), environments, network policies, the sandbox
::  requirement, the generation, and every lock the baselines name
::
++  policy-json
  |=  repo=@t
  ^-  json
  =/  owner=(unit @p)  (repo-owner repo)
  %-  pairs:enjs:format
  :~  ['repo' s+repo]
      ['untrusted' s+(~(gut by policies) repo %approval)]
      ['canEditAutomaticInputs' b+(authorized repo %ci-policy ~ our.bowl)]
      ['automaticInputs' (envelope:ci-input (~(gut by automatic-inputs) repo ~))]
      ['automaticPolicyId' s+(context-digest:ci-dispatch (scope:ci-input (~(gut by automatic-inputs) repo ~)))]
      :-  'automaticResolvers'
      :-  %a
      %+  murn  ~(val by daemons)
      |=  d=daemon:ci
      ^-  (unit json)
      ?.  resolver.d  ~
      ?.  ?~(repos.d %.y (~(has in u.repos.d) repo))  ~
      :-  ~
      %-  pairs:enjs:format
      :~  ['id' s+(scot %uv id.d)]
          ['name' s+(rap 3 ~[sandbox.d ' resolver ' (join:ci-plan (sort ~(tap in labels.d) aor) ', ')])]
          ['live' b+(live-daemon d)]
          ['reported' b+(~(has by resolver-inputs) id.d)]
          ['sources' [%a (turn (~(gut by resolver-inputs) id.d ~) |=(v=@t s+v))]]
      ==
      :-  'ciProtected'
      :-  %a
      %+  murn  ~(tap in ci-protected)
      |=  [r=@t ref=@t]
      ?.(=(r repo) ~ `s+ref)
      ['generation' (numb:enjs:format (current-generation repo))]
      ['incarnation' s+(scot %uv (current-incarnation repo))]
      ['owner' ?~(owner ~ s+(scot %p u.owner))]
      ['sandboxRequirement' s+`@t`(~(gut by sandbox-requirements) repo default-sandbox)]
      ['harnessPaths' [%a (turn (~(gut by harness-paths) repo ~['.github/']) |=(p=@t s+p))]]
      :-  'baselines'
      :-  %a
      %+  murn  ~(tap by baselines)
      |=  [[r=@t ref=@t] b=baseline:ci]
      ^-  (unit json)
      ?.  =(r repo)  ~
      :-  ~
      %-  pairs:enjs:format
      :~  ['ref' s+ref]
          ['revision' s+(oid-text:git-codec revision.b)]
          ['harnessPaths' [%a (turn harness-paths.b |=(p=@t s+p))]]
          ['lock' ?~(lock.b ~ s+(hex-bytes:ci-provenance u.lock.b 32))]
          ['promoted' (numb:enjs:format (unix-seconds promoted.b))]
          ['actor' s+(scot %p actor.b)]
          ['reason' s+reason.b]
          ['generation' (numb:enjs:format generation.b)]
          ['policyRepo' ?~(policy-repo.b ~ s+u.policy-repo.b)]
      ==
      :-  'roles'
      :-  %a
      %+  turn  (~(gut by roles) repo ~)
      |=  b=binding:ci
      %-  pairs:enjs:format
      :~  ['role' s+role.b]
          ['scope' ?~(scope.b ~ s+u.scope.b)]
          ['ships' [%a (turn (sort ~(tap in ships.b) lth) |=(p=@p s+(scot %p p)))]]
      ==
      :-  'environments'
      :-  %a
      %+  murn  ~(tap by environments)
      |=  [[r=@t name=@t] e=environment:ci]
      ^-  (unit json)
      ?.  =(r repo)  ~
      :-  ~
      %-  pairs:enjs:format
      :~  ['name' s+name.e]
          ['description' s+description.e]
          ['automation' s+automation.e]
          ['credentials' [%a (turn (sort ~(tap in credentials.e) aor) |=(c=@t s+c))]]
          ['created' (numb:enjs:format (unix-seconds created.e))]
          ['actor' s+(scot %p actor.e)]
      ==
      :-  'networkPolicies'
      :-  %a
      %+  turn  (~(gut by network-policies) repo ~)
      |=  n=network-policy:ci
      %-  pairs:enjs:format
      :~  ['workflow' s+workflow.n]
          ['job' s+job.n]
          ['profile' s+profile.n]
          ['destinations' [%a (turn destinations.n |=(d=@t s+d))]]
          ['environment' ?~(environment.n ~ s+u.environment.n)]
          ['actor' s+(scot %p actor.n)]
          ['at' (numb:enjs:format (unix-seconds at.n))]
      ==
      :-  'locks'
      :-  %a
      %+  murn  ~(tap by locks)
      |=  [* l=lock:ci]
      ?.(=(repo repo.l) ~ `(lock-json l))
  ==
::
++  handle-lock-read
  |=  [eyre-id=@ta req=inbound-request:eyre repo=@t segment=@t]
  ^-  out
  ?.  (viewer req)
    (emit (give-error eyre-id 401 'session required'))
  =/  found=(unit lock:ci)
    =/  hits=(list lock:ci)
      %+  skim  ~(val by locks)
      |=(l=lock:ci &(=(repo repo.l) =(segment (hex-bytes:ci-provenance digest.l 32))))
    ?~(hits ~ `i.hits)
  ?~  found
    (emit (give-error eyre-id 404 'no such lock'))
  (emit (give-json eyre-id 200 (lock-json u.found)))
::
++  handle-audit
  |=  [eyre-id=@ta req=inbound-request:eyre repo=@t]
  ^-  out
  ?.  (viewer req)
    (emit (give-error eyre-id 401 'session required'))
  %-  emit
  %^  give-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['repo' s+repo]
      :-  'audit'
      :-  %a
      %+  murn  audit
      |=  e=audit-entry:ci
      ^-  (unit json)
      ?.  =(repo repo.e)  ~
      :-  ~
      %-  pairs:enjs:format
      :~  ['at' (numb:enjs:format (unix-seconds at.e))]
          ['actor' s+(scot %p actor.e)]
          ['kind' s+kind.e]
          ['detail' s+detail.e]
      ==
  ==
::
::  the exportable comparison record (D7, U03)
::
++  handle-shadow-read
  |=  [eyre-id=@ta req=inbound-request:eyre segment=@t]
  ^-  out
  ?.  (viewer req)
    (emit (give-error eyre-id 401 'session required'))
  =/  id=(unit @uv)  (slaw %uv segment)
  =/  found=(unit shadow:ci)  ?~(id ~ (~(get by shadows) u.id))
  ?~  found
    (emit (give-error eyre-id 404 'no such shadow'))
  =/  c=(unit candidate:ci)  (~(get by candidates) candidate.u.found)
  %-  emit
  %^  give-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['id' s+(scot %uv id.u.found)]
      ['candidate' s+(scot %uv candidate.u.found)]
      ['repo' s+repo.u.found]
      ['ref' s+ref.u.found]
      ['event' s+event.u.found]
      ['external' s+external.u.found]
      ['oid' ?~(c ~ ?~(candidate.u.c ~ s+(oid-text:git-codec u.candidate.u.c)))]
      ['baseline' ?~(c ~ ?~(baseline.u.c ~ s+(oid-text:git-codec u.baseline.u.c)))]
      ['lock' ?~(c ~ ?~(lock.u.c ~ s+(hex-bytes:ci-provenance u.lock.u.c 32)))]
      ['generation' ?~(c ~ (numb:enjs:format generation.u.c))]
      ['verdict' ?~(c ~ s+status.u.c)]
      ['complete' b+?&(?=(^ c) ?=(?(%passed %failed) status.u.c))]
      :-  'jobs'
      :-  %a
      ?~  c  ~
      ?~  plan.u.c  ~
      =/  known  (standings u.c)
      %+  turn  u.plan.u.c
      |=  =job:ci
      %-  pairs:enjs:format
      :~  ['workflow' s+workflow.job]
          ['job' s+id.job]
          ['status' s+`@t`(~(gut by standings.known) [workflow.job id.job] %pending)]
      ==
      :-  'comparisons'
      :-  %a
      %+  murn  ~(tap by comparisons)
      |=  [* cmp=comparison:ci]
      ^-  (unit json)
      ?.  =(shadow.cmp id.u.found)  ~
      :-  ~
      %-  pairs:enjs:format
      :~  ['id' s+(scot %uv id.cmp)]
          ['at' (numb:enjs:format (unix-seconds at.cmp))]
          ['agreement' b+agreement.cmp]
          ['reason' s+reason.cmp]
          ['externalVerdict' s+external-verdict.cmp]
          ['nativeVerdict' s+native-verdict.cmp]
      ==
  ==
::
::  the resolver's lock (D4): validated by the pure rule, digested, stored
::  by digest for its repository and revision; the resolve attempt closes
::  with the verdict.  a lock the ship refuses closes the attempt failed
::  with the reason and stores nothing.
::
++  handle-lock
  |=  [eyre-id=@ta req=inbound-request:eyre segment=@t]
  ^-  out
  =/  attempt-id=(unit @uv)  (slaw %uv segment)
  =/  found=(unit attempt:ci)  ?~(attempt-id ~ (~(get by attempts) u.attempt-id))
  ?~  found
    (emit (give-error eyre-id 404 'no such attempt'))
  ?.  (attempt-authorized req u.found)
    (emit (give-error eyre-id 401 'attempt authentication required'))
  ?.  (active:ci-resolve state u.found)
    (emit (give-error eyre-id 409 'attempt is closed or has no live tag consumer'))
  ?.  ?=(%resolve kind.u.found)
    (emit (give-error eyre-id 409 'attempt is not a resolve attempt'))
  =/  jon=(unit json)  (body-json req)
  ?~  jon
    (emit (give-error eyre-id 400 'valid JSON body required'))
  =/  =candidate:ci  (~(got by candidates) candidate.u.found)
  =/  refused=(unit @t)  (string-at 'error' u.jon)
  =/  automatic=?  =(%tag (purpose:ci-resolve candidate))
  =/  legacy=?  &(automatic !(~(has by input-snapshots) id.candidate))
  =/  evidence=(unit @t)  (string-at 'input-evidence' u.jon)
  =/  evidence-ok=?
    ?.  automatic  %.y
    =/  parsed  (parse-lock u.jon)
    ?:  ?=(%| -.parsed)  %.n
    ?~  evidence
      ?.  legacy  %.n
      ::  Persisted state6 obligations can finish their already-supported
      ::  dependency-free/local walk, with no invented acquisition evidence.
      (levy nodes.p.parsed |=(n=dep-node:ci ?=(?(%local %reusable) kind.n)))
    (evidence-valid:ci-input u.evidence (captured:ci-input state id.candidate) nodes.p.parsed)
  ?:  &(automatic !evidence-ok ?=(~ refused))
    %-  emit
    %^  give-error
      eyre-id
      422
    'automatic input evidence is missing or does not bind the captured policy and measured inputs'
  ::  phase 1 (inventory): the resolver names what it found; the ship
  ::  creates the private mirror repositories the lock will point at and
  ::  hands back a write token per repository, valid for this resolve
  ::  only (cleared when the attempt closes).  nothing is stored yet.
  ::
  ?:  ?&(?=(~ refused) =(`'inventory' (string-at 'phase' u.jon)))
    =/  parsed=(each [nodes=(list dep-node:ci) bytes=@ud depth=@ud notices=(list @t)] @t)
      %-  parse-lock
      u.jon
    ?:  ?=(%| -.parsed)
      (emit (give-error eyre-id 422 p.parsed))
    =/  origins=(list @t)
      =|  acc=(list @t)
      =/  nodes=(list dep-node:ci)  nodes.p.parsed
      |-
      ?~  nodes  (flop acc)
      ?.  ?&(?=(?(%js %composite) kind.i.nodes) ?=(~ refusal.i.nodes) !=('' origin.i.nodes))
        $(nodes t.nodes)
      ?:  (lien acc |=(o=@t =(o origin.i.nodes)))  $(nodes t.nodes)
      $(nodes t.nodes, acc [origin.i.nodes acc])
    ::  the downloads and the container image archives go to the ship's
    ::  object store, content-addressed: one header-signed PUT per sha256
    ::  whose payload hash IS the sha256
    =/  download-shas=(list @t)
      =|  acc=(list @t)
      =/  nodes=(list dep-node:ci)  nodes.p.parsed
      |-
      ?~  nodes  (flop acc)
      ?.  ?&(?=(?(%download %container) kind.i.nodes) ?=(~ refusal.i.nodes) =(64 (met 3 sha256.i.nodes)))
        $(nodes t.nodes)
      ?:  (lien acc |=(o=@t =(o sha256.i.nodes)))  $(nodes t.nodes)
      $(nodes t.nodes, acc [sha256.i.nodes acc])
    =/  store-settings  (read-settings:ci-storage our.bowl now.bowl)
    ?:  &(?=(^ download-shas) ?=(~ store-settings))
      (emit (give-error eyre-id 503 storage-refusal))
    =/  uploads=(list [sha=@t signed=signed-request:git-storage])
      %+  murn  download-shas
      |=  sha=@t
      =/  signed=(unit signed-request:git-storage)
        %^  sign-put-download:ci-storage
          store-settings
          sha
        now.bowl
      ?~(signed ~ `[sha u.signed])
    =/  grants=(list [origin=@t repo=@t token=@uv])
      %+  turn  origins
      |=  origin=@t
      [origin (mirror-name origin) (fresh-nonce [%mirror-token origin id.u.found])]
    =/  repos=(list [repo=@t token=@uv])
      (turn grants |=([* repo=@t token=@uv] [repo token]))
    =/  cards=(list card)
      %-  zing
      %+  turn  repos
      |=  [repo=@t token=@uv]
      ^-  (list card)
      =/  exists=?
        =/  raw=(unit *)  (urgit-peek /ci-exists/(scot %t repo))
        ?~(raw %.n ;;(? u.raw))
      %+  weld
        ?:(exists ~ ~[(urgit-git-poke /mirror/(scot %t repo) [%create repo %.n])])
      ~[(urgit-git-poke /mirror-token/(scot %t repo) [%set-write-token repo (scot %uv token)])]
    =.  mirror-tokens  (~(put by mirror-tokens) id.u.found (silt (turn repos |=([repo=@t *] repo))))
    =.  daemons  (touch-daemon daemon.u.found)
    =.  audit
      %:  record-audit
        our.bowl
        'inventory'
        repo.candidate
        %+  rap
          3
        ~[(scot %ud (lent nodes.p.parsed)) ' node(s); mirrors: ' (join:ci-plan (turn repos |=([repo=@t *] repo)) ', ') '; downloads to the store: ' (scot %ud (lent uploads))]
      ==
    %-  emit
    %+  weld  cards
    %^  give-json  eyre-id  200
    %-  pairs:enjs:format
    :~  :-  'mirrors'
        %-  pairs:enjs:format
        %+  turn  grants
        |=  [origin=@t repo=@t token=@uv]
        [origin (pairs:enjs:format ~[['repo' s+repo] ['token' s+(scot %uv token)]])]
        :-  'downloads'
        %-  pairs:enjs:format
        %+  turn  uploads
        |=  [sha=@t signed=signed-request:git-storage]
        :-  sha
        %-  pairs:enjs:format
        :~  ['url' s+url.signed]
            ['method' s+'PUT']
            ['key' s+(download-key:ci-storage sha)]
            ['headers' (pairs:enjs:format (turn headers.signed |=([k=@t v=@t] [k s+v])))]
        ==
    ==
  =/  parsed=(each [nodes=(list dep-node:ci) bytes=@ud depth=@ud notices=(list @t)] @t)
    ?^  refused  [%| u.refused]
    (parse-lock u.jon)
  =/  verdict=(each lock:ci @t)
    ?:  ?=(%| -.parsed)  parsed
    =/  problem=(unit @t)
      %^  validate-lock:ci-provenance
        nodes.p.parsed
        bytes.p.parsed
      depth.p.parsed
    ?^  problem  [%| u.problem]
    ::  the manual-run inventory the resolver's compiler read (Delivery
    ::  1A): none from a resolver that sends none, never an empty one; a
    ::  malformed one refuses the lock
    ::
    =/  inventory=(each (unit (list dispatch-workflow:ci)) @t)
      ?.  ?=([%o *] u.jon)  [%& ~]
      (parse-inventory:ci-dispatch (~(get by p.u.jon) 'dispatch'))
    ?:  ?=(%| -.inventory)  [%| (rap 3 ~['dispatch inventory: ' p.inventory])]
    ::  the trigger catalog the resolver's compiler read (Delivery 1C):
    ::  none from a resolver that sends none — unknown, never empty — and a
    ::  malformed one refuses the lock
    ::
    =/  triggers=(each (unit trigger-catalog:ci) @t)
      ?.  ?=([%o *] u.jon)  [%& ~]
      (parse-catalog:ci-trigger (~(get by p.u.jon) 'triggers'))
    ?:  ?=(%| -.triggers)  [%| (rap 3 ~['trigger catalog: ' p.triggers])]
    =/  revision=oid:git  (fall candidate.candidate head.candidate)
    =/  digest=@ux
      %:  lock-digest-full:ci-provenance
        repo.candidate  revision  nodes.p.parsed  p.inventory  p.triggers
      ==
    =?  digest  &(automatic ?=(^ evidence))
      (shax (jam [%automatic-input-v1 digest (fall evidence '')]))
    :*  %&  digest  repo.candidate  revision  nodes.p.parsed  now.bowl  daemon.u.found
        bytes.p.parsed  notices.p.parsed  p.inventory  p.triggers
    ==
  =.  daemons  (touch-daemon daemon.u.found)
  =/  clear=(list card)  (mirror-token-cards u.found)
  ?:  ?=(%| -.verdict)
    =.  state  (close-attempt u.found [%plan-invalid (rap 3 ~['lock refused: ' p.verdict])])
    =.  audit  (record-audit our.bowl 'lock-refused' repo.candidate p.verdict)
    =/  closed=out  (after-close candidate.u.found)
    =.  state  state.closed
    =.  polls  polls.closed
    %-  emit
    %+  weld  (weld clear cards.closed)
    %^  give-json
      eyre-id
      422
    %-  pairs:enjs:format
    ~[['error' s+p.verdict] ['attempt' (attempt-json (~(got by attempts) id.u.found))]]
  =?  input-evidence  &(automatic ?=(^ evidence))
    (~(put by input-evidence) digest.p.verdict (fall evidence ''))
  =.  locks  (~(put by locks) digest.p.verdict p.verdict)
  =.  state  (complete-tag-resolve id.u.found p.verdict)
  =.  clear  (weld clear (tag-resolve-releases id.u.found))
  =.  audit
    %:  record-audit
      our.bowl
      'lock-resolved'
      repo.candidate
      %+  rap
        3
      ~[(oid-text:git-codec revision.p.verdict) ' → ' (hex-bytes:ci-provenance digest.p.verdict 32) ' (' (scot %ud (lent nodes.p.verdict)) ' nodes)']
    ==
  =.  state  (close-attempt u.found [%job-result %success])
  =/  closed=out  (after-close candidate.u.found)
  =.  state  state.closed
  =.  polls  polls.closed
  %-  emit
  %+  weld  (weld clear cards.closed)
  %^  give-json
    eyre-id
    200
  %-  pairs:enjs:format
  ~[['lock' (lock-json p.verdict)] ['attempt' (attempt-json (~(got by attempts) id.u.found))]]
::
::  the lock body: `{nodes: [...], bytes, depth, notices}`; every node's
::  fields are strings but step/size; a missing field is empty
::
++  parse-lock
  |=  jon=json
  ^-  (each [nodes=(list dep-node:ci) bytes=@ud depth=@ud notices=(list @t)] @t)
  ?.  ?=([%o *] jon)  [%| 'lock body is not a JSON object']
  =/  raw=(unit json)  (~(get by p.jon) 'nodes')
  ?~  raw  [%| 'lock is missing nodes']
  ?.  ?=([%a *] u.raw)  [%| 'lock nodes is not a list']
  =/  bytes=@ud  (fall (fall (number-at 'bytes' jon) ~) 0)
  =/  depth=@ud  (fall (fall (number-at 'depth' jon) ~) 0)
  =/  notices=(list @t)
    =/  v=(unit json)  (~(get by p.jon) 'notices')
    ?~  v  ~
    ?.  ?=([%a *] u.v)  ~
    (murn p.u.v |=(j=json ?.(?=([%s *] j) ~ `p.j)))
  =/  nodes=(each (list dep-node:ci) @t)
    =/  remaining=(list json)  p.u.raw
    =|  out=(list dep-node:ci)
    |-
    ?~  remaining  [%& (flop out)]
    ?.  ?=([%o *] i.remaining)  [%| 'lock node is not an object']
    =/  f=(map @t json)  p.i.remaining
    =/  str  |=(k=@t (fall (string-at k i.remaining) ''))
    =/  kind=dep-kind:ci
      ?+  (str 'kind')  %unknown
        %js  %js
        %composite  %composite
        %container  %container
        %local  %local
        %download  %download
        %reusable  %reusable
      ==
    =/  step=@ud  (fall (fall (number-at 'step' i.remaining) ~) 0)
    =/  size=@ud  (fall (fall (number-at 'size' i.remaining) ~) 0)
    =/  refusal=(unit @t)  (string-at 'refusal' i.remaining)
    =/  node=dep-node:ci
      :*  (str 'uses')  kind  (str 'origin')  (str 'ref')  (str 'commit')  (str 'tree')
          %-  str
          'subpath'
          (str 'mirror')  (str 'mirror-commit')  (str 'digest')  (str 'license')
          (str 'workflow')  (str 'job')  step  (str 'sha256')  size  (str 'path')  refusal
      ==
    $(remaining t.remaining, out [node out])
  ?:  ?=(%| -.nodes)  nodes
  [%& p.nodes bytes depth notices]
::
::  the repository's credentials by name, scope and environments: the
::  value is never in a reply (D4)
::
++  handle-credentials
  |=  [eyre-id=@ta req=inbound-request:eyre repo=@t]
  ^-  out
  ?.  (viewer req)
    (emit (give-error eyre-id 401 'session required'))
  %-  emit
  %^  give-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['repo' s+repo]
      :-  'credentials'
      :-  %a
      %+  turn  (credential-names repo)
      |=  [name=@t scope=?(%job %env) envs=(set @t) created=@da]
      %-  pairs:enjs:format
      :~  ['name' s+name]
          ['scope' s+scope]
          ['envs' [%a (turn ~(tap in envs) |=(e=@t s+e))]]
          ['created' (numb:enjs:format (unix-seconds created))]
      ==
      ::  CI-RECOVERY-1: the references a restore brought back with no
      ::  value, which need re-entry
      :-  'needsReentry'
      :-  %a
      %+  murn  credentials.history.recovery
      |=  r=credential-ref:ci
      ^-  (unit json)
      ?.  =(repo repo.r)  ~
      :-  ~
      %-  pairs:enjs:format
      :~  ['name' s+name.r]
          ['scope' s+scope.r]
          ['envs' [%a (turn envs.r |=(e=@t s+e))]]
          ['created' (numb:enjs:format (unix-seconds created.r))]
      ==
  ==
::
::  the operator actions as JSON (D6): the poke, with the acting ship
::  always this ship's owner (the session), applied under mule so a
::  refusal answers 409 with its reason instead of dropping the request
::
++  handle-web-action
  |=  [eyre-id=@ta req=inbound-request:eyre]
  ^-  out
  ?.  (viewer req)
    (emit (give-error eyre-id 401 'session required'))
  =/  jon=(unit json)  (body-json req)
  ?~  jon
    (emit (give-error eyre-id 400 'valid JSON body required'))
  =/  parsed=(each action:ci @t)  (parse-web-action u.jon our.bowl)
  ?:  ?=(%| -.parsed)
    (emit (give-error eyre-id 400 p.parsed))
  =/  applied=(each out tang)  (mule |.((handle-action p.parsed)))
  ?:  ?=(%| -.applied)
    (emit (give-error eyre-id 409 (trace-reason p.applied)))
  =.  state  state.p.applied
  =.  polls  polls.p.applied
  %-  emit
  %+  weld
    cards.p.applied
  (give-json eyre-id 200 (pairs:enjs:format ~[['ok' b+%.y] ['action' s+-.p.parsed]]))
::
::  a refusal's own words: the first quoted cord in the trace (a ~|
::  message renders as 'text'), else the trace's first line
::
++  trace-reason
  |=  =tang
  ^-  @t
  =/  lines=(list @t)
    %+  turn  tang
    |=  =tank
    (crip (of-wall:format (wash [0 200] tank)))
  =/  quoted=(list @t)
    (skim lines |=(line=@t ?&(!=('' line) =('\'' (end [3 1] line)))))
  =/  reason=@t
    ?^  quoted  i.quoted
    ?^  lines  i.lines
    'action refused'
  (strip-quotes reason)
::
::  the Run workflow form's data (Delivery 1A): for every ref of the
::  repository with a promoted baseline, its tip, whether it offers manual
::  runs (else why not) and the manual workflows its baseline's lock
::  lists, each with its declared inputs or the reason it cannot run; the
::  repository's environments by name, for an environment input; the
::  policy generation a dispatch binds; and whether this session's ship
::  may dispatch at all.  a ref with no baseline is not listed
::
++  handle-dispatch-inventory
  |=  [eyre-id=@ta req=inbound-request:eyre repo=@t]
  ^-  out
  ?.  (viewer req)
    (emit (give-error eyre-id 401 'session required'))
  (emit (give-json eyre-id 200 (dispatch-inventory-json repo)))
::
++  no-dispatch-authority
  ^-  @t
  'only the repository\'s owner, or a ship holding its ci-policy role, runs a workflow manually'
::
++  dispatch-inventory-json
  |=  repo=@t
  ^-  json
  =/  allowed=?  (authorized repo %ci-policy ~ our.bowl)
  =/  refs=(list @t)
    %+  sort
      %+  murn  ~(tap by baselines)
      |=([[r=@t ref=@t] *] ?.(=(r repo) ~ `ref))
    aor
  %-  pairs:enjs:format
  :~  ['repo' s+repo]
      ['generation' (numb:enjs:format (current-generation repo))]
      ['authorized' b+allowed]
      ['authority' ?:(allowed ~ s+no-dispatch-authority)]
      ['environments' [%a (turn (sort ~(tap in (environment-names repo)) aor) |=(n=@t s+n))]]
      :-  'refs'
      :-  %a
      %+  turn  refs
      |=  ref=@t
      ^-  json
      =/  tip=(unit (unit [tip=oid:git linked=?]))  (ref-tip repo ref)
      =/  inventory  (ref-inventory repo ref)
      =/  base=(unit baseline:ci)  (~(get by baselines) [repo ref])
      =/  reason=(unit @t)
        ?:  ?=(%| -.inventory)  `p.inventory
        ?~  tip  `'ci: %urgit cannot be read; the ref cannot be checked'
        ?~  u.tip  `(rap 3 ~[ref ' has no tip'])
        ~
      %-  pairs:enjs:format
      :~  ['ref' s+ref]
          ['tip' ?~(tip ~ ?~(u.tip ~ s+(oid-text:git-codec tip.u.u.tip)))]
          ['baseline' ?~(base ~ s+(oid-text:git-codec revision.u.base))]
          ['lock' ?~(base ~ ?~(lock.u.base ~ s+(hex-bytes:ci-provenance u.lock.u.base 32)))]
          ['available' b+?=(~ reason)]
          ['reason' ?~(reason ~ s+u.reason)]
          :-  'workflows'
          :-  %a
          ?:  ?=(%| -.inventory)  ~
          (turn workflows.p.inventory dispatch-workflow-json)
      ==
  ==
::
::  a manual run (Delivery 1A): the session's ship dispatches one
::  workflow on one ref with typed inputs.  the body is {ref, workflow,
::  tip, generation, request, inputs: {<id>: value}}; an actor, event or
::  repository in it is never read.  the answer is the run as the ship
::  recorded it ({run, fresh}: fresh is false for a request it recorded
::  before), or the refusal {error, fields}: 400 a malformed body, 401 no
::  session, 403 no ci-policy authority, 409 a refusal and its reason,
::  422 refused inputs with each field's reason
::
++  handle-dispatch
  |=  [eyre-id=@ta req=inbound-request:eyre repo=@t]
  ^-  out
  ?.  (viewer req)
    (emit (give-error eyre-id 401 'session required'))
  =/  jon=(unit json)  (body-json req)
  ?~  jon
    (emit (give-error eyre-id 400 'valid JSON body required'))
  =/  parsed=(each action:ci [status=@ud reason=@t fields=(list [@t @t])])
    (parse-dispatch repo u.jon our.bowl)
  ?:  ?=(%| -.parsed)
    (emit (give-refusal eyre-id p.parsed))
  ?.  (authorized repo %ci-policy ~ our.bowl)
    (emit (give-error eyre-id 403 no-dispatch-authority))
  ::  CI-RECOVERY-1: no run is admitted while CI is paused
  ?:  ci-paused
    (emit (give-error eyre-id 409 paused-refusal:ci-checkpoint))
  =/  checked  (admit-dispatch p.parsed)
  ?:  ?=(%| -.checked)
    (emit (give-refusal eyre-id p.checked))
  =/  applied=(each out tang)  (mule |.((handle-action p.parsed)))
  ?:  ?=(%| -.applied)
    (emit (give-error eyre-id 409 (trace-reason p.applied)))
  =.  state  state.p.applied
  =.  polls  polls.p.applied
  =/  run=(unit candidate:ci)  (~(get by candidates) id.run.p.checked)
  ?~  run
    (emit (give-error eyre-id 500 'the run was not recorded'))
  %-  emit
  %+  weld  cards.p.applied
  %^  give-json  eyre-id  200
  (pairs:enjs:format ~[['run' (candidate-json u.run)] ['fresh' b+fresh.p.checked]])
::
::  the dispatch body as the action, every input a typed value: a JSON
::  boolean, number or text.  a value of another JSON type is a refused
::  field; a missing required field is a malformed body
::
++  parse-dispatch
  |=  [repo=@t jon=json actor=@p]
  ^-  (each action:ci [status=@ud reason=@t fields=(list [@t @t])])
  =/  required  'ref, workflow, tip (40 hex), generation and request are required'
  ?.  ?=([%o *] jon)  [%| 400 'the body is not a JSON object' ~]
  =/  ref=(unit @t)  (string-at 'ref' jon)
  =/  workflow=(unit @t)  (string-at 'workflow' jon)
  =/  tip=(unit oid:git)  (oid-field 'tip' jon)
  =/  generation=(unit (unit @ud))  (number-at 'generation' jon)
  =/  request=(unit @t)  (string-at 'request' jon)
  ?:  |(?=(~ ref) ?=(~ workflow) ?=(~ tip) ?=(~ request))  [%| 400 required ~]
  ?.  ?&(?=(^ generation) ?=(^ u.generation))  [%| 400 required ~]
  =/  raw=(unit json)  (~(get by p.jon) 'inputs')
  =/  given=(each (list [@t json]) ~)
    ?~  raw  [%& ~]
    ?~  u.raw  [%& ~]
    ?.  ?=([%o *] u.raw)  [%| ~]
    [%& ~(tap by p.u.raw)]
  ?:  ?=(%| -.given)  [%| 400 'inputs must be an object of input values' ~]
  =/  typed=(list (each [@t input-value:ci] [@t @t]))
    %+  turn  p.given
    |=  [name=@t value=json]
    ^-  (each [@t input-value:ci] [@t @t])
    ?+  value  [%| name 'must be true or false, a number or text']
      [%b *]  [%& name [%boolean p.value]]
      [%n *]  [%& name [%number p.value]]
      [%s *]  [%& name [%string p.value]]
    ==
  =/  errors=(list [@t @t])
    (murn typed |=(t=(each [@t input-value:ci] [@t @t]) ?:(?=(%| -.t) `p.t ~)))
  ?^  errors  [%| 422 (refused-inputs errors) errors]
  =/  inputs=(list [name=@t value=input-value:ci])
    (murn typed |=(t=(each [@t input-value:ci] [@t @t]) ?:(?=(%& -.t) `p.t ~)))
  [%& [%dispatch-workflow repo u.ref u.workflow inputs u.tip u.u.generation u.request actor]]
::
::  a refusal with the reason and every refused field by name
::
++  give-refusal
  |=  [eyre-id=@ta status=@ud reason=@t fields=(list [@t @t])]
  ^-  (list card)
  %^  give-json  eyre-id  status
  %-  pairs:enjs:format
  :~  ['error' s+reason]
      ['fields' (pairs:enjs:format (turn fields |=([field=@t why=@t] [field s+why])))]
  ==
::
++  strip-quotes
  |=  text=@t
  ^-  @t
  =/  chars=tape  (trip text)
  =.  chars  ?:(&(?=(^ chars) =('\'' i.chars)) t.chars chars)
  =.  chars  (flop chars)
  =.  chars  ?:(&(?=(^ chars) =('\0a' i.chars)) t.chars chars)
  =.  chars  ?:(&(?=(^ chars) =('\'' i.chars)) t.chars chars)
  (crip (flop chars))
::
++  parse-web-action
  |=  [jon=json actor=@p]
  ^-  (each action:ci @t)
  =/  kind=(unit @t)  (string-at 'action' jon)
  ?~  kind  [%| 'action is required']
  =/  id=(unit @uv)
    =/  text=(unit @t)  (string-at 'id' jon)
    ?~(text ~ (slaw %uv u.text))
  =/  repo=(unit @t)  (string-at 'repo' jon)
  =/  name=(unit @t)  (string-at 'name' jon)
  ?+  u.kind  [%| 'unknown action']
      %approve-candidate
    ?~  id  [%| 'id must be a candidate id']
    [%& [%approve-candidate u.id actor]]
  ::
      %rerun-candidate
    ?~  id  [%| 'id must be a candidate id']
    [%& [%rerun-candidate u.id]]
  ::
      %set-ci-protected
    =/  ref=(unit @t)  (string-at 'ref' jon)
    =/  protected=(unit ?)
      ?.  ?=([%o *] jon)  ~
      =/  value=(unit json)  (~(get by p.jon) 'protected')
      ?~  value  ~
      ?.  ?=([%b *] u.value)  ~
      `p.u.value
    ?:  |(?=(~ repo) ?=(~ ref) ?=(~ protected))  [%| 'repo, ref and protected are required']
    [%& [%set-ci-protected u.repo u.ref u.protected]]
  ::
      %set-untrusted-policy
    =/  policy=(unit @t)  (string-at 'policy' jon)
    ?~  repo  [%| 'repo is required']
    ?+  policy  [%| 'policy must be approval or restricted']
      [~ %approval]  [%& [%set-untrusted-policy u.repo %approval]]
      [~ %restricted]  [%& [%set-untrusted-policy u.repo %restricted]]
    ==
  ::
      %set-credential
    =/  value=(unit @t)  (string-at 'value' jon)
    =/  scope=(unit @t)  (string-at 'scope' jon)
    =/  envs=(set @t)
      ?.  ?=([%o *] jon)  ~
      =/  list=(unit json)  (~(get by p.jon) 'envs')
      ?~  list  ~
      ?.  ?=([%a *] u.list)  ~
      %-  silt
      %+  murn  p.u.list
      |=  item=json
      ?.(?=([%s *] item) ~ `p.item)
    ?:  |(?=(~ repo) ?=(~ name) ?=(~ value))  [%| 'repo, name and value are required']
    ?+  scope  [%| 'scope must be job or env']
      [~ %job]  [%& [%set-credential u.repo u.name u.value %job envs]]
      [~ %env]  [%& [%set-credential u.repo u.name u.value %env envs]]
    ==
  ::
      %delete-credential
    ?:  |(?=(~ repo) ?=(~ name))  [%| 'repo and name are required']
    [%& [%delete-credential u.repo u.name]]
  ::
      ::  the Runners panel's actions (D2/D2b/D3): expire, revoke, bind,
      ::  rotate — every one on the allow-list, none dojo-only
      ::
      %expire-token
    ?~  id  [%| 'id must be a daemon id']
    [%& [%expire-token u.id]]
  ::
      %revoke-daemon
    ?~  id  [%| 'id must be a daemon id']
    [%& [%revoke-daemon u.id]]
  ::
      %set-daemon-repos
    ?~  id  [%| 'id must be a daemon id']
    ?.  ?=([%o *] jon)  [%| 'repos must be null or a list of repository names']
    =/  value=(unit json)  (~(get by p.jon) 'repos')
    ?~  value  [%| 'repos must be null or a list of repository names']
    ?~  u.value  [%& [%set-daemon-repos u.id ~]]
    ?.  ?=([%a *] u.value)  [%| 'repos must be null or a list of repository names']
    =/  names=(list @t)
      (murn p.u.value |=(item=json ?.(?=([%s *] item) ~ `p.item)))
    ?.  =((lent names) (lent p.u.value))  [%| 'repos must be null or a list of repository names']
    [%& [%set-daemon-repos u.id `(silt names)]]
  ::
      %rotate-ci-key
    [%& [%rotate-ci-key ~]]
  ::
      ::  P4 (D4-D7): the provenance and policy actions.  the actor is the
      ::  session's ship (our), never a field of the body.
      ::
      %resolve-dependencies
    =/  revision=(unit oid:git)  (oid-field 'revision' jon)
    ?:  |(?=(~ repo) ?=(~ revision))  [%| 'repo and revision (40 hex) are required']
    =/  mappings=(unit (list [from=@t to=@t]))
      ?.  ?=([%o *] jon)  `~
      =/  raw=(unit json)  (~(get by p.jon) 'mappings')
      ?~  raw  `~
      ?.  ?=([%a *] u.raw)  ~
      =/  parsed=(list (unit [from=@t to=@t]))
        %+  turn  p.u.raw
        |=  j=json
        ^-  (unit [from=@t to=@t])
        =/  from=(unit @t)  (string-at 'from' j)
        =/  to=(unit @t)  (string-at 'to' j)
        ?:  |(?=(~ from) ?=(~ to))  ~
        `[u.from u.to]
      ?:  (lien parsed |=(m=(unit [from=@t to=@t]) ?=(~ m)))  ~
      `(murn parsed |=(m=(unit [from=@t to=@t]) m))
    ?~  mappings  [%| 'mappings must be a list of {from, to} strings']
    [%& [%resolve-dependencies u.repo u.revision actor u.mappings]]
  ::
      %promote-baseline
    =/  ref=(unit @t)  (string-at 'ref' jon)
    =/  revision=(unit oid:git)  (oid-field 'revision' jon)
    =/  reason=(unit @t)  (string-at 'reason' jon)
    =/  policy-repo=(unit @t)  (string-at 'policyRepo' jon)
    =/  lock-text=(unit @t)  (string-at 'lock' jon)
    =/  lock=(unit @ux)
      ?~  lock-text  ~
      ?.  =(64 (met 3 u.lock-text))  ~
      =/  parsed=(unit @ux)  (rush u.lock-text hex)
      ?~  parsed  ~
      ::  the digest as the locks are keyed: compared by its 64-hex text
      =/  hit=(list lock:ci)
        %+  skim
          ~(val by locks)
        |=(l=lock:ci =(u.lock-text (hex-bytes:ci-provenance digest.l 32)))
      ?~(hit `u.parsed `digest.i.hit)
    ?:  |(?=(~ repo) ?=(~ ref) ?=(~ revision) ?=(~ reason))
      [%| 'repo, ref, revision (40 hex) and reason are required']
    ?:  &(?=(^ lock-text) ?=(~ lock))  [%| 'lock must be a 64-hex digest']
    [%& [%promote-baseline u.repo u.ref u.revision u.reason actor policy-repo lock]]
  ::
      %revoke-baseline
    =/  ref=(unit @t)  (string-at 'ref' jon)
    =/  reason=(unit @t)  (string-at 'reason' jon)
    ?:  |(?=(~ repo) ?=(~ ref) ?=(~ reason))  [%| 'repo, ref and reason are required']
    [%& [%revoke-baseline u.repo u.ref u.reason actor]]
  ::
      %set-harness-paths
    =/  paths=(unit (list @t))  (string-list-at 'paths' jon)
    ?:  |(?=(~ repo) ?=(~ paths))  [%| 'repo and paths (a list) are required']
    [%& [%set-harness-paths u.repo u.paths actor]]
  ::
      %set-sandbox-requirement
    =/  need=(unit @t)  (string-at 'need' jon)
    ?~  repo  [%| 'repo is required']
    ?+  need  [%| 'need must be vm or container']
      [~ %vm]  [%& [%set-sandbox-requirement u.repo %vm actor]]
      [~ %container]  [%& [%set-sandbox-requirement u.repo %container actor]]
    ==
  ::
      ?(%set-role %clear-role)
    =/  role=(unit role:ci)
      ?+  (string-at 'role' jon)  ~
        [~ %ci-policy]  `%ci-policy
        [~ %environment-approver]  `%environment-approver
        [~ %override]  `%override
      ==
    =/  scope=(unit @t)  (string-at 'scope' jon)
    ?:  |(?=(~ repo) ?=(~ role))
      [%| 'repo and role (ci-policy, environment-approver, override) are required']
    ?:  =(%clear-role u.kind)  [%& [%clear-role u.repo u.role scope actor]]
    =/  names=(unit (list @t))  (string-list-at 'ships' jon)
    ?~  names  [%| 'ships (a list of @p) is required']
    =/  ships=(list @p)  (murn u.names |=(n=@t (slaw %p n)))
    ?.  =((lent ships) (lent u.names))  [%| 'every ship must be a valid @p']
    [%& [%set-role u.repo u.role scope (silt ships) actor]]
  ::
      %set-environment
    =/  description=@t  (fall (string-at 'description' jon) '')
    =/  automation=(unit automation:ci)
      ?+  (string-at 'automation' jon)  ~
        ~  `%manual
        [~ %manual]  `%manual
        [~ %automatic]  `%automatic
      ==
    =/  creds=(unit (list @t))  (string-list-at 'credentials' jon)
    ?:  |(?=(~ repo) ?=(~ name) ?=(~ automation))
      [%| 'repo, name and automation (manual or automatic) are required']
    [%& [%set-environment u.repo u.name description u.automation (silt (fall creds ~)) actor]]
  ::
      %delete-environment
    ?:  |(?=(~ repo) ?=(~ name))  [%| 'repo and name are required']
    [%& [%delete-environment u.repo u.name actor]]
  ::
      %approve-environment
    =/  workflow=(unit @t)  (string-at 'workflow' jon)
    =/  job=(unit @t)  (string-at 'job' jon)
    =/  environment=(unit @t)  (string-at 'environment' jon)
    =/  creds=(unit (list @t))  (string-list-at 'credentials' jon)
    ?:  |(?=(~ id) ?=(~ workflow) ?=(~ job) ?=(~ environment) ?=(~ creds))
      [%| 'id (candidate), workflow, job, environment and credentials (a list) are required']
    [%& [%approve-environment u.id u.workflow u.job u.environment (silt u.creds) actor]]
  ::
      %record-override
    =/  ref=(unit @t)  (string-at 'ref' jon)
    =/  oid=(unit oid:git)  (oid-field 'oid' jon)
    =/  expected=(unit oid:git)  (oid-field 'expected' jon)
    =/  reason=(unit @t)  (string-at 'reason' jon)
    ?:  |(?=(~ repo) ?=(~ ref) ?=(~ id) ?=(~ oid) ?=(~ expected) ?=(~ reason))
      [%| 'repo, ref, id (candidate), oid, expected (40 hex each) and reason are required']
    [%& [%record-override u.repo u.ref u.id u.oid u.expected u.reason actor]]
  ::
      %set-automatic-inputs
    =/  sources=(unit (list @t))  (string-list-at 'sources' jon)
    =/  expected=(unit (unit @ud))  (number-at 'generation' jon)
    ?:  |(?=(~ repo) ?=(~ sources) ?=(~ expected))
      [%| 'repo, sources (a list) and generation are required']
    ?~  u.expected  [%| 'generation is required']
    [%& [%set-automatic-inputs u.repo u.sources u.u.expected actor]]
  ::
      %set-network-policy
    =/  workflow=(unit @t)  (string-at 'workflow' jon)
    =/  job=(unit @t)  (string-at 'job' jon)
    =/  profile=(unit @t)  (string-at 'profile' jon)
    =/  dests=(unit (list @t))  (string-list-at 'destinations' jon)
    =/  environment=(unit @t)  (string-at 'environment' jon)
    ?:  |(?=(~ repo) ?=(~ workflow) ?=(~ job) ?=(~ profile) ?=(~ dests))
      [%| 'repo, workflow, job, profile and destinations (a list) are required']
    [%& [%set-network-policy u.repo u.workflow u.job u.profile u.dests environment actor]]
  ::
      %clear-network-policy
    =/  workflow=(unit @t)  (string-at 'workflow' jon)
    =/  job=(unit @t)  (string-at 'job' jon)
    ?:  |(?=(~ repo) ?=(~ workflow) ?=(~ job))  [%| 'repo, workflow and job are required']
    [%& [%clear-network-policy u.repo u.workflow u.job actor]]
  ::
      %stage-shadow
    =/  ref=(unit @t)  (string-at 'ref' jon)
    =/  head=(unit oid:git)  (oid-field 'head' jon)
    =/  base=(unit oid:git)  (oid-field 'base' jon)
    =/  event=(unit @t)  (string-at 'event' jon)
    =/  external=@t  (fall (string-at 'external' jon) '')
    ?:  |(?=(~ repo) ?=(~ ref) ?=(~ head) ?=(~ base) ?=(~ event))
      [%| 'repo, ref, head, base (40 hex each) and event are required']
    [%& [%stage-shadow u.repo u.ref u.head u.base u.event external actor]]
  ::
      %compare-shadow
    =/  shadow=(unit @uv)
      =/  t=(unit @t)  (string-at 'shadow' jon)
      ?~(t ~ (slaw %uv u.t))
    =/  oid=(unit oid:git)  (oid-field 'oid' jon)
    =/  event=(unit @t)  (string-at 'event' jon)
    =/  verdict=(unit @t)  (string-at 'verdict' jon)
    =/  jobs=(list [workflow=@t job=@t status=@t])
      ?.  ?=([%o *] jon)  ~
      =/  v=(unit json)  (~(get by p.jon) 'jobs')
      ?~  v  ~
      ?.  ?=([%a *] u.v)  ~
      %+  murn  p.u.v
      |=  j=json
      =/  w=(unit @t)  (string-at 'workflow' j)
      =/  jb=(unit @t)  (string-at 'job' j)
      =/  st=(unit @t)  (string-at 'status' j)
      ?:  |(?=(~ w) ?=(~ jb) ?=(~ st))  ~
      `[u.w u.jb u.st]
    ?:  |(?=(~ shadow) ?=(~ oid) ?=(~ event) ?=(~ verdict))
      [%| 'shadow, oid, event, verdict and jobs are required']
    [%& [%compare-shadow u.shadow u.oid u.event u.verdict jobs actor]]
  ::
      %cancel-attempt
    =/  reason=@t  (fall (string-at 'reason' jon) 'cancelled by the operator')
    ?~  id  [%| 'id must be an attempt id']
    [%& [%cancel-attempt u.id reason actor]]
  ::
      ::  CI-CONCURRENCY-1: the run page's Cancel, for the whole run or one
      ::  workflow of it (`workflow`); the actor is the session's ship
      ::
      %cancel-run
    =/  reason=@t  (fall (string-at 'reason' jon) 'cancelled from the CI tab')
    ?~  id  [%| 'id must be a run id']
    =/  workflow=(unit @t)  (string-at 'workflow' jon)
    ?:  ?&(?=(^ workflow) =('' u.workflow))  [%| 'workflow names a workflow file']
    [%& [%cancel-run u.id workflow reason actor]]
  ::
      ::  the Runners panel's release of a legacy retention (legacy-recovery
      ::  UI ruling 01): the runner, and the entry, revision and evidence
      ::  digest the panel showed from the runner's report — never typed
      ::
      %request-legacy-release
    =/  selection=(unit @t)  (string-at 'selection' jon)
    =/  evidence=(unit @t)  (string-at 'evidence' jon)
    =/  revision=(unit (unit @ud))  (number-at 'revision' jon)
    ?~  id  [%| 'id must be a runner id']
    ?:  |(?=(~ selection) ?=(~ evidence) ?=(~ revision))
      [%| 'selection, revision and evidence are required']
    ?~  u.revision  [%| 'selection, revision and evidence are required']
    [%& [%request-legacy-release u.id u.selection u.u.revision u.evidence actor]]
  ::
      ::  the Runners panel's transition of a runner whose execution history
      ::  is incomplete (legacy-replay-upgrade ruling 01): the runner, and
      ::  the history's revision and evidence digest the panel showed from
      ::  the runner's report — never typed
      ::
      %request-history-transition
    =/  evidence=(unit @t)  (string-at 'evidence' jon)
    =/  revision=(unit (unit @ud))  (number-at 'revision' jon)
    ?~  id  [%| 'id must be a runner id']
    ?:  |(?=(~ evidence) ?=(~ revision))
      [%| 'revision and evidence are required']
    ?~  u.revision  [%| 'revision and evidence are required']
    [%& [%request-history-transition u.id u.u.revision u.evidence actor]]
  ::
      ::  CI-RECOVERY-1: the Recovery section's actions.  the actor is
      ::  the session's ship.  an import names a commit (40 hex) or none,
      ::  for the tip.  an apply names the staged checkpoint it reviewed
      ::
      %checkpoint-now  [%& [%checkpoint-now actor]]
      %pause-ci  [%& [%pause-ci (fall (string-at 'reason' jon) '') actor]]
      %resume-ci  [%& [%resume-ci actor]]
      %discard-checkpoint  [%& [%discard-checkpoint actor]]
  ::
      %import-checkpoint
    =/  text=(unit @t)  (string-at 'commit' jon)
    ?~  text  [%& [%import-checkpoint ~ actor]]
    ?:  =('' u.text)  [%& [%import-checkpoint ~ actor]]
    =/  commit=(unit oid:git)  (parse-oid u.text)
    ?~  commit  [%| 'commit must be 40 hex']
    [%& [%import-checkpoint commit actor]]
  ::
      %apply-checkpoint
    =/  checkpoint=(unit @t)  (string-at 'checkpoint' jon)
    ?~  checkpoint  [%| 'checkpoint (the staged checkpoint\'s id) is required']
    [%& [%apply-checkpoint u.checkpoint actor]]
  ==
::
++  oid-field
  |=  [key=@t jon=json]
  ^-  (unit oid:git)
  =/  t=(unit @t)  (string-at key jon)
  ?~  t  ~
  (parse-oid u.t)
::
++  string-list-at
  |=  [key=@t jon=json]
  ^-  (unit (list @t))
  ?.  ?=([%o *] jon)  ~
  =/  v=(unit json)  (~(get by p.jon) key)
  ?~  v  ~
  ?.  ?=([%a *] u.v)  ~
  =/  items=(list @t)  (murn p.u.v |=(j=json ?.(?=([%s *] j) ~ `p.j)))
  ?.  =((lent items) (lent p.u.v))  ~
  `items
::
::  the CI key's public half and the ship's certificate over it (D5):
::  what a verifier holds.  neither private key, nor the ring, is ever
::  answered by any route or scry.
::
++  handle-key
  |=  [eyre-id=@ta req=inbound-request:eyre]
  ^-  out
  ?.  (viewer req)
    (emit (give-error eyre-id 401 'session required'))
  ?~  signing
    (emit (give-error eyre-id 503 'the CI signing key is not generated'))
  %-  emit
  %^  give-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['pub' s+(hex-bytes pub.u.signing 32)]
      ['cert' s+(hex-bytes cert.u.signing 64)]
      ['certified' b+!=(0x0 cert.u.signing)]
      ['ship' s+(scot %p our.bowl)]
      ['life' ?~(ship-keys ~ (numb:enjs:format life.u.ship-keys))]
      ['shipSigningKey' ?~(ship-keys ~ s+(hex-bytes pub.u.ship-keys 32))]
      ['created' (numb:enjs:format (unix-seconds created.u.signing))]
  ==
::
::  a JSON list of strings as a set, for the daemon's labels (D2b); a
::  missing or malformed field is the empty set
::
++  labels-at
  |=  [key=@t jon=json]
  ^-  (set @t)
  ?.  ?=([%o *] jon)  ~
  =/  value=(unit json)  (~(get by p.jon) key)
  ?~  value  ~
  ?.  ?=([%a *] u.value)  ~
  %-  silt
  %+  murn  p.u.value
  |=  item=json
  ?.  ?=([%s *] item)  ~
  ?:  =('' p.item)  ~
  `p.item
::
::  `x-ci-labels: linux,x64, big-mem` as a set: split on commas, trimmed
::
++  parse-labels
  |=  header=@t
  ^-  (set @t)
  =/  chars=tape  (trip header)
  =|  acc=(set @t)
  =|  cur=tape
  |-
  ?~  chars
    =/  word=@t  (crip (trim-spaces cur))
    ?:(=('' word) acc (~(put in acc) word))
  ?:  =(',' i.chars)
    =/  word=@t  (crip (trim-spaces cur))
    $(chars t.chars, cur ~, acc ?:(=('' word) acc (~(put in acc) word)))
  $(chars t.chars, cur (snoc cur i.chars))
::
++  trim-spaces
  |=  text=tape
  ^-  tape
  =/  blank  |=(c=@tD |(=(' ' c) =('\09' c)))
  =.  text  (flop (skip-while (flop text) blank))
  (skip-while text blank)
::
++  skip-while
  |=  [text=tape test=$-(@tD ?)]
  ^-  tape
  ?~  text  ~
  ?:  (test i.text)  $(text t.text)
  text
::
::  the Runners panel's pip (D3): revoked, refused, minted (never
::  enrolled), healthy (seen within stale-after, the scheduler's window),
::  else stale.  a full daemon keeps polling (D6 f), so a dead daemon with
::  a full slot set reads stale like any other.
::
++  runner-state
  |=  =daemon:ci
  ^-  @t
  ?^  revoked.daemon  'revoked'
  ?^  refused.daemon  'refused'
  ?~  enrolled.daemon  'minted'
  ?~  last-seen.daemon  'stale'
  ?:  (lth (sub now.bowl (min now.bowl u.last-seen.daemon)) stale-after)  'healthy'
  'stale'
::
++  runner-json
  |=  =daemon:ci
  ^-  json
  %-  pairs:enjs:format
  :~  ['id' s+(scot %uv id.daemon)]
      ['capacity' (numb:enjs:format capacity.daemon)]
      ['sandbox' s+sandbox.daemon]
      ['labels' [%a (turn (sort ~(tap in labels.daemon) aor) |=(l=@t s+l))]]
      ['profiles' [%a (turn (sort ~(tap in profiles.daemon) aor) |=(l=@t s+l))]]
      ['resolver' b+resolver.daemon]
      ['repos' ?~(repos.daemon ~ [%a (turn (sort ~(tap in u.repos.daemon) aor) |=(r=@t s+r))])]
      ['minted' (numb:enjs:format (unix-seconds minted.daemon))]
      ['enrolled' ?~(enrolled.daemon ~ (numb:enjs:format (unix-seconds u.enrolled.daemon)))]
      ['lastSeen' ?~(last-seen.daemon ~ (numb:enjs:format (unix-seconds u.last-seen.daemon)))]
      ['running' (numb:enjs:format ~(wyt in running.daemon))]
      ['revoked' ?~(revoked.daemon ~ (numb:enjs:format (unix-seconds u.revoked.daemon)))]
      ['refused' ?~(refused.daemon ~ s+u.refused.daemon)]
      ['state' s+(runner-state daemon)]
      ::  what its latest retention report says it withholds (legacy-
      ::  recovery UI ruling 01): null when it has reported none
      ::
      :-  'retentions'
      =/  report=(unit recovery-report:ci)  (~(get by recovery-reports) id.daemon)
      ?~  report  ~
      %-  pairs:enjs:format
      :~  ['reported' (numb:enjs:format (unix-seconds at.u.report))]
          ['total' (numb:enjs:format (lent entries.u.report))]
          ['legacy' (numb:enjs:format (lent (skim entries.u.report |=(e=recovery-entry:ci =('legacy' kind.e)))))]
          ['eligible' (numb:enjs:format (lent (skim entries.u.report |=(e=recovery-entry:ci eligible.e))))]
      ==
      ::  whether its latest report shows it waiting for its history
      ::  transition (legacy-replay-upgrade ruling 01): null when it has
      ::  reported no history
      ::
      :-  'history'
      =/  report=(unit recovery-report:ci)  (~(get by recovery-reports) id.daemon)
      =/  entry=(unit recovery-entry:ci)
        ?~  report  ~
        =/  jon=(unit json)  (de:json:html body.u.report)
        ?~(jon ~ (history-entry:ci-recovery u.jon))
      ?~  entry  ~
      %-  pairs:enjs:format
      ~[['paused' b+eligible.u.entry] ['revision' (numb:enjs:format revision.u.entry)]]
  ==
::
::  every daemon record, newest minted first, with the ship's clock so a
::  panel can age the stamps against its own
::
++  runners-json
  ^-  json
  =/  sorted=(list daemon:ci)
    (sort ~(val by daemons) |=([a=daemon:ci b=daemon:ci] (gth minted.a minted.b)))
  %-  pairs:enjs:format
  :~  ['runners' [%a (turn sorted runner-json)]]
      ['now' (numb:enjs:format (unix-seconds now.bowl))]
      ['staleAfter' (numb:enjs:format (div stale-after ~s1))]
      ['implicitLabels' [%a (turn (sort ~(tap in implicit-labels) aor) |=(l=@t s+l))]]
  ==
::
++  handle-runners
  |=  [eyre-id=@ta req=inbound-request:eyre]
  ^-  out
  ?.  (viewer req)
    (emit (give-error eyre-id 401 'session required'))
  (emit (give-json eyre-id 200 runners-json))
::
::  the storage reachability probe (D5): the store's endpoint as the ship
::  knows it and one URL under the CI prefix for the viewer's browser to
::  fetch.  the URL is unsigned on purpose: an unsigned read draws the
::  store's 403, and any HTTP answer proves the endpoint reachable from
::  the browser (and CORS-readable), where a link to 127.0.0.1 or a
::  LAN-only host draws a NetworkError.  the ship, which has no outbound
::  HTTP, cannot make this check itself.
::
++  handle-storage-probe
  |=  [eyre-id=@ta req=inbound-request:eyre]
  ^-  out
  ?.  (viewer req)
    (emit (give-error eyre-id 401 'session required'))
  =/  settings=settings:ci-storage  (read-settings:ci-storage our.bowl now.bowl)
  ?~  settings
    (emit (give-json eyre-id 200 (pairs:enjs:format ~[['configured' b+%.n]])))
  =/  endpoint=@t  endpoint.credentials.u.settings
  =/  host=@t  (endpoint-host:git-storage endpoint)
  =/  bucket=@t  current-bucket.configuration.u.settings
  %-  emit
  %^  give-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['configured' b+%.y]
      ['endpoint' s+endpoint]
      ['host' s+host]
      ['bucket' s+bucket]
      ['url' s+(rap 3 ~[(endpoint-scheme:git-storage endpoint) host '/' bucket '/ci/_probe'])]
  ==
::
::  the mint (D1): the ship draws 256 bits of entropy as the token,
::  stores its hash on a fresh daemon record, and answers the raw token
::  in this one response — the only time it exists outside the operator's
::  clipboard — beside the config lines the daemon needs.  the poke union
::  has no mint action: nothing but this session-authorized route mints.
::
++  handle-mint
  |=  [eyre-id=@ta req=inbound-request:eyre]
  ^-  out
  ?.  (viewer req)
    (emit (give-error eyre-id 401 'session required'))
  =/  token=@uv  (end [3 32] eny.bowl)
  =/  token-hash=@  (shas %ci-enroll token)
  =/  id=daemon-id:ci  (sham [%ci-daemon token-hash])
  ?:  (~(has by daemons) id)
    (emit (give-error eyre-id 409 'enroll token already minted; try again'))
  =.  daemons
    (~(put by daemons) id [id token-hash ~ now.bowl ~ ~ 1 '' ~ ~ ~ ~ ~ ~ %.n])
  =/  host=@t
    (fall (get-header:http 'host' header-list.request.req) 'ship.example')
  =/  ship-url=@t
    (rap 3 ~[?:(secure.req 'https://' 'http://') host])
  =/  snippet=@t
    %+  rap  3
    :~  'ship_url = "'  ship-url  '"\0a'
        'enroll_token = "'  (scot %uv token)  '"\0a'
        'sandbox = "microvm"\0a'
    ==
  %-  emit
  %^  give-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['id' s+(scot %uv id)]
      ['token' s+(scot %uv token)]
      ['shipUrl' s+ship-url]
      ['configSnippet' s+snippet]
      ['runner' (runner-json (~(got by daemons) id))]
  ==
::
::  the legacy recovery's routes (legacy-recovery UI ruling 01;
::  runner/launcher/INTEGRATION.md §11.12; contract §8b).  a daemon's
::  report and its answers are its own: they need its bearer, and the
::  ship's session is refused — a request received in a browser is never a
::  runner's result.
::
++  daemon-bearer
  |=  [req=inbound-request:eyre =daemon:ci]
  ^-  ?
  ?~  bearer-hash.daemon  %.n
  =/  presented=(unit @)  (presented-bearer-hash req)
  ?~  presented  %.n
  =(u.bearer-hash.daemon u.presented)
::
::  a daemon's retention report: every retention it withholds, how its
::  slot returns, and a legacy retention's evidence.  kept whole as the
::  panel's source, with the entries a command is bound to; a report with
::  any malformed entry is refused whole.
::
++  handle-retention-report
  |=  [eyre-id=@ta req=inbound-request:eyre segment=@t]
  ^-  out
  =/  daemon-id=(unit @uv)  (slaw %uv segment)
  =/  found=(unit daemon:ci)  ?~(daemon-id ~ (~(get by daemons) u.daemon-id))
  ?~  found
    (emit (give-error eyre-id 404 'no such daemon'))
  ?.  (daemon-bearer req u.found)
    (emit (give-error eyre-id 401 'daemon authentication required'))
  ?~  body.request.req
    (emit (give-error eyre-id 400 'valid JSON body required'))
  ?:  (gth p.u.body.request.req max-report-bytes)
    (emit (give-error eyre-id 413 'the retention report is too large'))
  =/  jon=(unit json)  (de:json:html q.u.body.request.req)
  ?~  jon
    (emit (give-error eyre-id 400 'valid JSON body required'))
  =/  entries=(unit (list recovery-entry:ci))  (report-entries:ci-recovery u.jon)
  ?~  entries
    %-  emit
    %^  give-error
      eyre-id
      422
    'retentions must be a list of entries, each with its selection and revision'
  =.  recovery-reports
    (~(put by recovery-reports) id.u.found [now.bowl `@t`q.u.body.request.req u.entries])
  =.  daemons  (touch-daemon id.u.found)
  (emit (give-empty eyre-id 204))
::
::  a daemon's answer to one of its recovery commands: completed is the
::  runner's durable release and stands against any earlier answer; a
::  refusal or a doubt changes only a command still open (answer-command)
::
++  handle-recovery-answer
  |=  [eyre-id=@ta req=inbound-request:eyre segment=@t]
  ^-  out
  =/  daemon-id=(unit @uv)  (slaw %uv segment)
  =/  found=(unit daemon:ci)  ?~(daemon-id ~ (~(get by daemons) u.daemon-id))
  ?~  found
    (emit (give-error eyre-id 404 'no such daemon'))
  ?.  (daemon-bearer req u.found)
    (emit (give-error eyre-id 401 'daemon authentication required'))
  =/  jon=(unit json)  (body-json req)
  ?~  jon
    (emit (give-error eyre-id 400 'valid JSON body required'))
  =/  command-id=(unit @uv)
    =/  text=(unit @t)  (string-at 'command' u.jon)
    ?~(text ~ (slaw %uv u.text))
  =/  command=(unit recovery-command:ci)
    ?~(command-id ~ (~(get by recovery-commands) u.command-id))
  ?~  command
    (emit (give-error eyre-id 404 'no such recovery command'))
  ?.  =(daemon.u.command id.u.found)
    (emit (give-error eyre-id 404 'no such recovery command'))
  =/  status=(unit ?(%completed %refused %uncertain))
    ?+  (string-at 'status' u.jon)  ~
      [~ %completed]  `%completed
      [~ %refused]  `%refused
      [~ %uncertain]  `%uncertain
    ==
  ?~  status
    (emit (give-error eyre-id 422 'status must be completed, refused or uncertain'))
  =/  detail=@t  (fall (string-at 'detail' u.jon) '')
  =/  next=recovery-command:ci  (answer-command:ci-recovery u.command u.status detail now.bowl)
  =.  daemons  (touch-daemon id.u.found)
  ?:  =(next u.command)
    (emit (give-json eyre-id 200 (recovery-command-json next)))
  =.  recovery-commands  (~(put by recovery-commands) id.next next)
  =/  kind=@t
    ?:(=(confirm-history:ci-recovery operation.next) 'history-transition-' 'legacy-release-')
  =.  audit
    %:  record-audit
      our.bowl
      (cat 3 kind status.next)
      ''
      (rap 3 ~[(scot %uv id.next) ' on runner ' (scot %uv id.u.found) ': ' detail])
    ==
  (emit (give-json eyre-id 200 (recovery-command-json next)))
::
::  the Runners panel's view of one runner's retentions: its record, its
::  latest report as it came, its recovery commands newest first, and what
::  the ship knows of each retention's attempt.  nothing here changes.
::
++  handle-runner-recovery
  |=  [eyre-id=@ta req=inbound-request:eyre segment=@t]
  ^-  out
  ?.  (viewer req)
    (emit (give-error eyre-id 401 'session required'))
  =/  daemon-id=(unit @uv)  (slaw %uv segment)
  =/  found=(unit daemon:ci)  ?~(daemon-id ~ (~(get by daemons) u.daemon-id))
  ?~  found
    (emit (give-error eyre-id 404 'no such runner'))
  =/  report=(unit recovery-report:ci)  (~(get by recovery-reports) id.u.found)
  =/  mine=(list recovery-command:ci)
    %+  sort
      (skim ~(val by recovery-commands) |=(c=recovery-command:ci =(id.u.found daemon.c)))
    |=([a=recovery-command:ci b=recovery-command:ci] (gth requested.a requested.b))
  %-  emit
  %^  give-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['runner' (runner-json u.found)]
      ['now' (numb:enjs:format (unix-seconds now.bowl))]
      ['reported' ?~(report ~ (numb:enjs:format (unix-seconds at.u.report)))]
      ['report' ?~(report ~ (fall (de:json:html body.u.report) ~))]
      ['commands' [%a (turn mine recovery-command-json)]]
      ::  what the ship holds of the runner's authorizations, for its
      ::  history transition (legacy-replay-upgrade ruling 01): its epoch
      ::  now, the next, the assignments it holds for it, and the attempts
      ::  still running on it — a transition gives those back
      ::
      :-  'history'
      =/  epoch=@ud  (epoch-at:ci-recovery ~(val by recovery-commands) id.u.found now.bowl)
      %-  pairs:enjs:format
      :~  ['epoch' (numb:enjs:format epoch)]
          ['next' (numb:enjs:format +(epoch))]
          ['assignments' (numb:enjs:format (lent (skim ~(val by assignments) |=(a=assignment:ci =(id.u.found daemon.a)))))]
          ['running' [%a (turn ~(tap in running.u.found) |=(a=attempt-id:ci s+(scot %uv a)))]]
      ==
      :-  'attempts'
      ?~  report  ~
      %-  pairs:enjs:format
      %+  murn  entries.u.report
      |=  e=recovery-entry:ci
      ^-  (unit [@t json])
      =/  aid=(unit @uv)  (slaw %uv attempt.e)
      ?~  aid  ~
      =/  a=(unit attempt:ci)  (~(get by attempts) u.aid)
      ?~  a  ~
      =/  c=(unit candidate:ci)  (~(get by candidates) candidate.u.a)
      :-  ~
      :-  attempt.e
      %-  pairs:enjs:format
      :~  ['repo' s+?~(c '' repo.u.c)]
          ['ref' s+?~(c '' ref.u.c)]
          ['workflow' ?~(workflow.u.a ~ s+u.workflow.u.a)]
          ['job' ?~(job.u.a ~ s+u.job.u.a)]
          ['kind' s+kind.u.a]
          ['status' s+status.u.a]
      ==
  ==
::
::  a recovery command as the panel reads it: a queued one past its time
::  reads expired before a poll records it so
::
++  recovery-command-json
  |=  c=recovery-command:ci
  ^-  json
  =/  status=@t
    ?:  ?&(=(%queued status.c) (gte now.bowl expires.c))  'expired'
    status.c
  %-  pairs:enjs:format
  :~  ['id' s+(scot %uv id.c)]
      ['runner' s+(scot %uv daemon.c)]
      ['operation' s+operation.c]
      ['selection' s+selection.c]
      ['revision' (numb:enjs:format revision.c)]
      ['evidence' s+evidence.c]
      ['label' s+label.c]
      ['actor' s+(scot %p actor.c)]
      ['requested' (numb:enjs:format (unix-seconds requested.c))]
      ['expires' (numb:enjs:format (unix-seconds expires.c))]
      ['delivered' ?~(delivered.c ~ (numb:enjs:format (unix-seconds u.delivered.c)))]
      ['deliveries' (numb:enjs:format deliveries.c)]
      ['status' s+status]
      ['detail' s+detail.c]
      ['finished' ?~(finished.c ~ (numb:enjs:format (unix-seconds u.finished.c)))]
  ==
::
::  a recovery command as its daemon receives it (contract §8b): every
::  field the CI key signed, and the signature (message-bytes:ci-recovery)
::
++  recovery-json
  |=  c=recovery-command:ci
  ^-  json
  =/  expiry=@ud  (unix-seconds expires.c)
  =/  message=@
    %:  message-bytes:ci-recovery
      daemon.c
      id.c
      operation.c
      expiry
      nonce.c
      selection.c
      revision.c
      evidence.c
    ==
  =/  signature=@ux
    ?~  signing  0x0
    (sign-raw:ed:crypto message pub.u.signing sek.u.signing)
  %-  pairs:enjs:format
  :_  ~
  :-  'recovery'
  %-  pairs:enjs:format
  :~  ['version' (numb:enjs:format recovery-version:ci-recovery)]
      ['id' s+(scot %uv id.c)]
      ['recipient' s+(scot %uv daemon.c)]
      ['operation' s+operation.c]
      ['selection' s+selection.c]
      ['revision' (numb:enjs:format revision.c)]
      ['evidence' s+evidence.c]
      ['label' s+label.c]
      ['expiry' (numb:enjs:format expiry)]
      ['nonce' s+(scot %uv nonce.c)]
      ['sig' s+(hex-bytes signature 64)]
  ==
::
::  the daemon could not finish: act exited without a jobResult, the
::  sandbox failed, teardown failed, or the assignment did not verify
::  against its pinned key (D8; CI-DELIVERY-1.1 a/b).  the attempt is
::  released at once instead of at its deadline: offered again on another
::  daemon when one exists, else closed as an infrastructure error with
::  the daemon's reason.  a daemon abandoning over its key is marked
::  refused and offered no work until it re-enrolls.  a second abandon of
::  a re-offered attempt is idempotent; a result already recorded is never
::  overwritten.
::
++  handle-abandon
  |=  [eyre-id=@ta req=inbound-request:eyre segment=@t]
  ^-  out
  =/  attempt-id=(unit @uv)  (slaw %uv segment)
  =/  found=(unit attempt:ci)  ?~(attempt-id ~ (~(get by attempts) u.attempt-id))
  ?~  found
    (emit (give-error eyre-id 404 'no such attempt'))
  ?.  (attempt-authorized req u.found)
    (emit (give-error eyre-id 401 'attempt authentication required'))
  ?:  =(%reoffered status.u.found)
    (emit (give-json eyre-id 200 (attempt-json u.found)))
  ?.  =(%running status.u.found)
    (emit (give-error eyre-id 409 'attempt is closed'))
  =/  jon=(unit json)  (body-json req)
  ?~  jon
    (emit (give-error eyre-id 400 'valid JSON body required'))
  =/  reason=(unit @t)  (string-at 'reason' u.jon)
  ?~  reason
    (emit (give-error eyre-id 422 'reason is required'))
  =/  given=out  (give-up u.found u.reason)
  =.  state  state.given
  =.  polls  polls.given
  (emit (weld cards.given (give-json eyre-id 200 (attempt-json (~(got by attempts) id.u.found)))))
::
::  a daemon gives an attempt up with a reason (CI-DELIVERY-1.1 a/b): the
::  one path behind the abandon route and a plan posted as a refusal.  a
::  reason with the refusal prefix marks the daemon refused first; then
::  the attempt is offered again on another daemon when one exists, else
::  closed as an infrastructure error with the reason; then the candidate
::  is settled and the scheduler runs.
::
++  refusal-reason
  |=  reason=@t
  ^-  ?
  =/  width=@ud  (met 3 refusal-prefix)
  ?&  (gte (met 3 reason) width)
      =(refusal-prefix (end [3 width] reason))
  ==
::
++  give-up
  |=  [=attempt:ci reason=@t]
  ^-  out
  =?  daemons  (refusal-reason reason)
    =/  runner=(unit daemon:ci)  (~(get by daemons) daemon.attempt)
    ?~  runner  daemons
    (~(put by daemons) daemon.attempt u.runner(refused `reason))
  =/  candidate=(unit candidate:ci)  (~(get by candidates) candidate.attempt)
  =/  again=?
    ?~  candidate  %.n
    ?:  ?=(^ approval.attempt)  %.n
    =/  exclude=(set daemon-id:ci)
      %-  ~(put in (excluded-daemons u.candidate kind.attempt workflow.attempt job.attempt))
      daemon.attempt
    %:  other-daemon-exists
      repo.u.candidate
      (attempt-runs-on u.candidate attempt)
      exclude
      sandbox.attempt
      network.attempt
    ==
  =.  state
    ?:  again
      (reoffer-attempt attempt (rap 3 ~['abandoned: ' reason '; re-offered']))
    ::  a privileged attempt its daemon gave up is unknown, never retried
    ::  (rider 02, A03): the daemon may have run part of the deployment
    ?:  ?=(^ approval.attempt)
      %+  close-unknown
        attempt
      %+  rap
        3
      ~['abandoned by the daemon during a privileged job: ' reason '; the external side effect may have happened: needs review']
    (close-attempt attempt [%infrastructure-error (rap 3 ~['abandoned: ' reason])])
  (after-close candidate.attempt)
::
::  the plan (D1): what `act -l` listed on the candidate checkout, with
::  the daemon's compiled `needs` and `if` per job.  the ship reads the
::  candidate's own tree to check it (D2), stores it with the oid it was
::  read from (CI-BASELINE-P1), closes the plan attempt, and schedules.
::  a plan the ship cannot validate fails the attempt and the candidate
::  with the reason.
::
++  handle-plan
  |=  [eyre-id=@ta req=inbound-request:eyre segment=@t]
  ^-  out
  =/  attempt-id=(unit @uv)  (slaw %uv segment)
  =/  found=(unit attempt:ci)  ?~(attempt-id ~ (~(get by attempts) u.attempt-id))
  ?~  found
    (emit (give-error eyre-id 404 'no such attempt'))
  ?.  (attempt-authorized req u.found)
    (emit (give-error eyre-id 401 'attempt authentication required'))
  ?.  =(%running status.u.found)
    (emit (give-error eyre-id 409 'attempt is closed'))
  ?.  ?=(%plan kind.u.found)
    (emit (give-error eyre-id 409 'attempt is not a plan attempt'))
  =/  jon=(unit json)  (body-json req)
  ?~  jon
    (emit (give-error eyre-id 400 'valid JSON body required'))
  ::  a plan the daemon refused over its pinned key is not a plan error
  ::  (CI-DELIVERY-1.1 b): the daemon gave the attempt up, and the
  ::  candidate keeps waiting for a plan from a daemon that can verify
  ::
  =/  refused=(unit @t)  (string-at 'error' u.jon)
  ?:  ?&(?=(^ refused) (refusal-reason u.refused))
    =/  given=out  (give-up u.found u.refused)
    =.  state  state.given
    =.  polls  polls.given
    (emit (weld cards.given (give-json eyre-id 200 (attempt-json (~(got by attempts) id.u.found)))))
  =/  =candidate:ci  (~(got by candidates) candidate.u.found)
  ?~  candidate.candidate
    (emit (give-error eyre-id 409 'candidate is not materialized'))
  =/  oid=oid:git  u.candidate.candidate
  ::  the workflow files a required (or shadow) run plans from are the
  ::  baseline's (P4 D5); a trial's are the candidate's own.  the plan
  ::  says which revision it read them from and the ship checks it.
  ::
  =/  wf-oid=oid:git
    ?:  =(%trial mode.candidate)  oid
    (fall baseline.candidate oid)
  =/  wf-repo=@t
    ?:  (tagged-run candidate)  repo.candidate
    =/  base=(unit baseline:ci)  (~(get by baselines) [repo.candidate ref.candidate])
    ?~  base  repo.candidate
    ?:(=(%trial mode.candidate) repo.candidate (fall policy-repo.u.base repo.candidate))
  ::  a required push's selection (Delivery 1C), from the baseline's
  ::  catalog and the push's own changed paths (two-dot, its base to the
  ::  object it would land); ~ for any other run
  =/  required-selection=(unit event-selection:ci)
    ?.  ?&(?=(%push -.trigger.candidate) =(%required mode.candidate))  ~
    `(required-push-selection candidate oid)
  =/  validated=(each (list job:ci) @t)
    =/  parsed=(each wire-plan:ci-plan @t)  (parse:ci-plan u.jon)
    ?:  ?=(%| -.parsed)  parsed
    ?.  =((oid-text:git-codec wf-oid) workflows-oid.p.parsed)
      [%| (rap 3 ~['plan read its workflows at ' workflows-oid.p.parsed ', not the ' ?:(=(%trial mode.candidate) 'candidate' 'baseline') ' ' (oid-text:git-codec wf-oid)])]
    =/  tree=(unit (list path))
      (tree-at wf-repo wf-oid '.github/workflows')
    ?~  tree
      [%| 'workflow tree could not be read from %urgit']
    =/  names=(list @t)
      %+  murn  u.tree
      |=  =path
      ^-  (unit @t)
      ?.  ?=([@ ~] path)  ~
      `i.path
    ::  a push plans every push-triggered job; a manual run the one
    ::  workflow it dispatched (Delivery 1A); an event run the workflows
    ::  its event selected (Delivery 1C); a required push the push
    ::  workflows the baseline's filters select for it, which are
    ::  selected now, the rest recorded as absent evidence
    =/  checked=(each (list job:ci) @t)
      ?:  ?=(%event -.trigger.candidate)
        %:  validate-selected:ci-plan
          (oid-text:git-codec oid)  names  p.parsed
          (event-name:ci-trigger trigger.candidate)
          ?~(selected.candidate ~ (selected-workflows:ci-trigger outcomes.u.selected.candidate))
        ==
      ?.  ?&(?=(%push -.trigger.candidate) =(%required mode.candidate) ?=(^ required-selection))
        (validate-for:ci-plan (oid-text:git-codec oid) names p.parsed trigger.candidate)
      =/  outcomes=(list workflow-selection:ci)  outcomes.u.required-selection
      ?~  outcomes
        (validate-for:ci-plan (oid-text:git-codec oid) names p.parsed trigger.candidate)
      %:  validate-selected:ci-plan
        (oid-text:git-codec oid)  names  p.parsed  'push'
        (selected-workflows:ci-trigger outcomes)
      ==
    ?:  ?=(%| -.checked)  checked
    =/  unreadable=(unit @t)
      %+  find-first:ci-plan  workflows.p.parsed
      |=  name=@t
      =(~ (file-at wf-repo wf-oid (rap 3 ~['.github/workflows/' name])))
    ?^  unreadable
      [%| (rap 3 ~['workflow file ' u.unreadable ' could not be read at ' (oid-text:git-codec wf-oid)])]
    checked
  =.  daemons  (touch-daemon daemon.u.found)
  ?:  ?=(%| -.validated)
    =.  state  (close-attempt u.found [%plan-invalid p.validated])
    =/  closed=out  (after-close candidate.u.found)
    =.  state  state.closed
    =.  polls  polls.closed
    %-  emit
    %+  weld  cards.closed
    %^  give-json
      eyre-id
      422
    %-  pairs:enjs:format
    ~[['error' s+p.validated] ['attempt' (attempt-json (~(got by attempts) id.u.found))]]
  =.  candidates
    %+  ~(put by candidates)  id.candidate
    %=  candidate
      plan  `p.validated
      plan-oid  `wf-oid
      updated  now.bowl
      selected  ?^(required-selection required-selection selected.candidate)
    ==
  =.  state  (close-attempt u.found [%job-result %success])
  =/  closed=out  (after-close candidate.u.found)
  =.  state  state.closed
  =.  polls  polls.closed
  %-  emit
  %+  weld  cards.closed
  %^  give-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['attempt' (attempt-json (~(got by attempts) id.u.found))]
      :-  'plan'
      :-  %a
      %+  turn  p.validated
      |=  =job:ci
      %-  pairs:enjs:format
      :~  ['id' s+id.job]
          ['workflow' s+workflow.job]
          ['name' s+name.job]
          ['stage' (numb:enjs:format stage.job)]
          ['needs' [%a (turn needs.job |=(need=@t s+need))]]
          ['runs-on' [%a (turn (sort ~(tap in runs-on.job) aor) |=(l=@t s+l))]]
          ['timeout-minutes' ?~(timeout.job ~ (numb:enjs:format u.timeout.job))]
      ==
  ==
--
