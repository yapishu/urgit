::  ci-store-outage-vector: a store outage is unknown, never green
::  (R5.1-A).  %urgit-ci is built from app/urgit-ci and loaded with one
::  running job attempt whose daemon relayed a jobResult.  The daemon
::  then posts the result, with or without the log it stored.
::    - A success that names its log closes the attempt passed.
::    - A success that names no log closes it as an infrastructure
::      error, with the reason, so the run reads as unknown.
::    - A skip that names no log closes the same way.
::    - A failure that names no log stays failed.
::  Every case names the verdict it expects.  Prints `passed=N of=M` and
::  ends in a loobean.
::
/-  ci, git
/+  ci-cron, git-codec
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
=/  load
  |=  s=state-0:ci
  ^-  agent:gall
  +:(~(on-load ci-agent bowl) !>(s))
=/  with-result
  |=  r=result:ci
  ^-  agent:gall
  =/  a=attempt:ci  running(job-result `r, events 3)
  (load live-state(attempts (malt ~[[id.a a]]), assignments ~))
=/  sha=@t  'eed40d8e7be4151fb3bd0f1fcbf197399f70003e4157f480d081fae8d293203b'
=/  post
  |=  [a=agent:gall body=@t]
  ^-  (unit agent:gall)
  =/  request=inbound-request:eyre
    :*  %.n  %.n  [%ipv4 .127.0.0.1]
        %'POST'
        (rap 3 ~['/apps/urgit/api/ci/attempt/' (scot %uv 0v4.attmp) '/result'])
        ~[['x-ci-bearer' (scot %uv bearer)] ['content-type' 'application/json']]
        `(as-octs:mimes:html body)
    ==
  =/  r=(each (quip card:agent:gall agent:gall) tang)
    (mule |.((~(on-poke a bowl) %handle-http-request !>([%result-1 request]))))
  ?:  ?=(%| -.r)  ~
  `+.p.r
=/  attempt-of
  |=  a=(unit agent:gall)
  ^-  (unit attempt:ci)
  ?~  a  ~
  =/  got=(unit (unit cage))  (~(on-peek u.a bowl) /x/attempts)
  ?.  ?=([~ ~ *] got)  ~
  =/  all=(map attempt-id:ci attempt:ci)  !<((map attempt-id:ci attempt:ci) q.u.u.got)
  (~(get by all) 0v4.attmp)
=/  status-of
  |=  a=(unit agent:gall)
  ^-  @t
  =/  t=(unit attempt:ci)  (attempt-of a)
  ?~  t  'missing'
  status.u.t
=/  reason-of
  |=  a=(unit agent:gall)
  ^-  @t
  =/  t=(unit attempt:ci)  (attempt-of a)
  ?~  t  ''
  (fall reason.u.t '')
=/  logged=(unit agent:gall)
  %+  post  (with-result %success)
  (rap 3 ~['{"job-result":"success","log":{"size":5658,"sha256":"' sha '"}}'])
=/  unlogged=(unit agent:gall)  (post (with-result %success) '{"job-result":"success"}')
=/  skipped=(unit agent:gall)  (post (with-result %skipped) '{"job-result":"skipped"}')
=/  failure=(unit agent:gall)  (post (with-result %failure) '{"job-result":"failure"}')
=/  said-store
  |=  t=@t
  ?=(^ (find "object store" (trip t)))
=/  cases=(list [@t ? ?])
  :~  ['a success with its log closes passed' %.y =('passed' (status-of logged))]
      ['a success with its log names the log' %.y ?=([~ ~ *] (bind (attempt-of logged) |=(t=attempt:ci log.t)))]
      ['a success without a log closes as an infrastructure error' %.y =('infrastructure-error' (status-of unlogged))]
      ['a success without a log gives the store as the reason' %.y (said-store (reason-of unlogged))]
      ['a skip without a log closes as an infrastructure error' %.y =('infrastructure-error' (status-of skipped))]
      ['a failure without a log stays failed' %.y =('failed' (status-of failure))]
      ['intentionally false: a success without a log passes' %.n =('passed' (status-of unlogged))]
      ['intentionally false: a failure without a log is unknown' %.n =('infrastructure-error' (status-of failure))]
  ==
=/  failed=(list @t)
  %+  murn  cases
  |=  [name=@t expect=? got=?]
  ?:(=(expect got) ~ `name)
=/  passed=@ud  (sub (lent cases) (lent failed))
~&  [%failed failed]
~&  (crip "passed={<passed>} of={<(lent cases)>}")
?=(~ failed)
