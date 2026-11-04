::  ci-checkpoint-vector: CI-RECOVERY-1 (R5.2-A), lib/ci-checkpoint on a
::  populated state that holds real secrets.  The checks are these.
::    1. The export holds no credential value, whole or by any line of a
::       multi-line one.  It holds no CI or ship private key, no bearer or
::       token hash, no read capability and no approval in force.  Its
::       bytes are searched for each one.  It writes exactly its ten files, and the
::       commit built from them holds only their blobs, so no repository
::       object.  Positive controls show the search finds what is there.
::    2. The manifest lists each file's length, sha-256 and count, and
::       the files read back whole and equal.  Each of these is refused
::       whole, with the reason: a flipped byte, a truncated file, a
::       missing file and a wrong count.  So are a malformed record, an
::       unsupported version, another format and a lock that is not the one
::       listed.
::    3. A failed replica push is a failed backup, never confirmed.  So
::       is a push with no answer.  No push path leaves the checkpoint
::       written with its replica not confirmed.
::    4. Import and apply are refused unless CI is paused.  Apply is also
::       refused for another id than the staged one and while an attempt
::       runs.
::    5. After an apply on a fresh ship, credentials need re-entry, and
::       approvals and leases are inert.  Runners must re-enroll and the
::       signing key is the new ship's.  No run, attempt or schedule exists,
::       and run summaries are history.  An apply in place cancels
::       open runs, invalidates unused approvals and keeps every current
::       credential value.
::  Every case names the verdict it expects.  The intentionally FALSE
::  cases are the absences.  Prints `passed=N of=M` and ends in a loobean.
::
::    NOT RUN in the source stage that wrote it: it needs a ship.
::
/-  ci, git
/+  ci-checkpoint, ci-provenance, git-clay, git-codec
:-  %say
|=  *
:-  %noun
=/  now=@da  ~2026.10.21..12.00.00
=/  ship=@p  ~zod
::  the secrets
::
=/  secret-a=@t  'sk-live-0123456789abcdef-DEPLOY'
=/  secret-github=@t  'ghp_A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8'
=/  pem-line=@t  'MIIEvQIBADANBgkqhkiG9w0BAQEFAASC'
=/  secret-pem=@t
  (rap 3 ~['-----BEGIN PRIVATE KEY-----\0a' pem-line '\0a-----END PRIVATE KEY-----'])
=/  ci-sek=@ux  0x1111.2222.3333.4444.5555.6666.7777.8888.9999.aaaa.bbbb.cccc.dddd.eeee.ffff.1234
=/  ship-sek=@ux  0x4321.ffff.eeee.dddd.cccc.bbbb.aaaa.9999.8888.7777.6666.5555.4444.3333.2222.1111
=/  token-hash=@  0xabcd.ef01.2345.6789.abcd.ef01.2345.6789.abcd.ef01.2345.6789.abcd.ef01.2345.6789
=/  bearer-hash=@  0x9876.5432.10fe.dcba.9876.5432.10fe.dcba.9876.5432.10fe.dcba.9876.5432.10fe.dcba
=/  read-hash=@  0x5555.aaaa.5555.aaaa.5555.aaaa.5555.aaaa.5555.aaaa.5555.aaaa.5555.aaaa.5555.aaaa
::  the records
::
=/  revision=@ux  0xaaaa.bbbb.cccc.dddd.eeee.ffff.0000.1111.2222.3333
=/  head=@ux  0x1234.5678.9abc.def0.1234.5678.9abc.def0.1234.5678
=/  lock-digest=@ux  (shax 'the lock of demo')
=/  auto-digest=@ux  (shax 'the automatic lock of tools')
=/  lock=lock:ci
  [lock-digest 'demo' revision ~ ~2026.10.2 0v1.daemn 120 ~['MIT'] `~ ~]
=/  auto-lock=lock:ci
  [auto-digest 'tools' revision ~ ~2026.10.3 0v1.daemn 64 ~ ~ ~]
=/  base=baseline:ci
  [revision ~['.github/'] `lock-digest ~2026.10.4 ship 'first promotion' 3 ~]
=/  tools-base=baseline:ci
  [revision ~['.github/'] `auto-digest ~2026.10.4 ship 'tools promotion' 1 ~]
=/  prod=environment:ci
  ['prod' 'production deploys' %manual (silt ~['DEPLOY_KEY']) ~2026.10.5 ship]
=/  approver=binding:ci  [%environment-approver `'prod' (silt ~[~nec ~bud])]
=/  overrider=binding:ci  [%override `'refs/heads/main' (silt ~[~nec])]
=/  net=network-policy:ci
  ['ci.yml' 'deploy' 'egress' ~['tcp:api.example.com:443'] `'prod' ship ~2026.10.6]
=/  spent=approval:ci
  :*  0v2.spent  'demo'  0v9.incar  0v3.cand1  head  'ci.yml'  'deploy'  'prod'
      (silt ~['DEPLOY_KEY'])  revision  `lock-digest  3  ~nec  ~2026.10.10
      ~2026.10.10..00.15.00  `0v4.attmp  ~
  ==
=/  live=approval:ci
  :*  0v5.alive  'demo'  0v9.incar  0v3.cand1  head  'ci.yml'  'deploy'  'prod'
      (silt ~['DEPLOY_KEY'])  revision  `lock-digest  3  ~nec  ~2026.10.21..11.55.00
      ~2026.10.21..12.10.00  ~  ~
  ==
=/  over=override:ci
  :*  0v6.overr  'demo'  'refs/heads/main'  0v9.incar  0v3.cand1  head  revision
      ~nec  'hotfix during an outage'  'status failed'  3  ~2026.10.11
      ~2026.10.11..00.15.00  `~2026.10.11..00.05.00  ~
  ==
=/  daemon=daemon:ci
  :*  0v1.daemn  token-hash  `bearer-hash  ~2026.10.1  `~2026.10.1  `~2026.10.21
      2  'microvm'  ~  ~  ~  (silt ~['linux' 'big-mem'])  `(silt ~['demo'])  ~  %.n
  ==
=/  blank-candidate=candidate:ci  *candidate:ci
=/  run=candidate:ci
  %=  blank-candidate
    id  0v3.cand1
    repo  'demo'
    ref  'refs/heads/main'
    head  head
    base  revision
    status  %failed
    attempts  ~[0v4.attmp]
    verdict-reason  `(rap 3 ~['failed: the log printed ' secret-a])
    actor  ship
    created  ~2026.10.10
    updated  ~2026.10.10..00.20.00
    mode  %required
  ==
=/  blank-attempt=attempt:ci  *attempt:ci
=/  att=attempt:ci
  %=  blank-attempt
    id  0v4.attmp
    candidate  0v3.cand1
    daemon  0v1.daemn
    kind  %job
    workflow  `'ci.yml'
    job  `'deploy'
    status  %failed
    log  `['ci/demo/0v3.cand1/0v4.attmp/log' 2.048 'f00d']
    started  ~2026.10.10
    finished  `~2026.10.10..00.20.00
  ==
=/  audit=(list audit-entry:ci)
  :~  [~2026.10.11 ~nec 'record-override' 'demo' 'refs/heads/main: hotfix']
      [~2026.10.10 ~nec 'approve-environment' 'demo' (rap 3 ~['deploy with ' secret-github])]
      [~2026.10.9 ship 'promote-baseline' 'demo' 'first promotion']
      [~2026.10.8 ship 'set-credential' 'demo' 'no audit kind a checkpoint keeps']
  ==
=/  signing=signing:ci  [0x7777 ci-sek 0x8888 ~2026.10.1]
=/  keys=ship-keys:ci  [3 0x9999 ship-sek]
=/  cap=read-capability:ci  [0v4.attmp (silt ~['demo']) ~2026.10.10..01.00.00]
=/  creds=(map [repo=@t name=@t] credential:ci)
  %-  malt
  ^-  (list [[repo=@t name=@t] credential:ci])
  :~  [['demo' 'DEPLOY_KEY'] [secret-a %env (silt ~['prod']) ~2026.10.5]]
      [['demo' 'GITHUB_TOKEN'] [secret-github %job ~ ~2026.10.5]]
      [['demo' 'PEM'] [secret-pem %job ~ ~2026.10.5]]
  ==
=/  blank-state=state-0:ci  *state-0:ci
=/  s=state-0:ci
  %=  blank-state
    candidates  (malt ~[[id.run run]])
    daemons  (malt ~[[id.daemon daemon]])
    attempts  (malt ~[[id.att att]])
    ci-protected  (silt ~[['demo' 'refs/heads/main'] ['demo' 'refs/heads/release']])
    policies  (malt ~[['demo' %restricted]])
    credentials  creds
    signing  `signing
    ship-keys  `keys
    incarnations  (malt ~[['demo' 0v9.incar]])
    generations  (malt ~[['demo' 3]])
    baselines  (malt ~[[['demo' 'refs/heads/main'] base] [['tools' 'refs/heads/main'] tools-base]])
    locks  (malt ~[[lock-digest lock] [auto-digest auto-lock]])
    roles  (malt ~[['demo' ~[approver overrider]]])
    environments  (malt ~[[['demo' 'prod'] prod]])
    approvals  (malt ~[[id.spent spent] [id.live live]])
    overrides  (malt ~[[id.over over]])
    network-policies  (malt ~[['demo' ~[net]]])
    read-capabilities  (malt ~[[read-hash cap]])
    audit  audit
    sandbox-requirements  (malt ~[['demo' %container]])
    mirror-tokens  (malt ~[[0v4.attmp (silt ~['ci-mirror-actions-cache'])]])
    harness-paths  (malt ~[['demo' ~['.github/' 'ci/']]])
    automatic-inputs  (malt ~[['tools' ~['https://inputs.example/tool']]])
    input-evidence  (malt ~[[auto-digest 'evidence-of-tools']])
  ==
::  the export
::
=/  id=@t  (checkpoint-id:ci-checkpoint now 1 ship)
=/  content=checkpoint-content:ci  (project:ci-checkpoint s ship now)
=/  made=written-files:ci-checkpoint
  %:  export:ci-checkpoint
    content  id  ship  'urgit'  42  now  'policy change: set-environment (demo)'
  ==
=/  files=(list [=path data=octs])  files.made
=/  everything=@  (can 3 (turn files |=([* data=octs] [p.data q.data])))
::  whether .needle's bytes occur in .hay's
::
=/  has-bytes
  |=  [hay=@ needle=@]
  ^-  ?
  =/  h=(list @)  (rip 3 hay)
  =/  n=(list @)  (rip 3 needle)
  ?~  n  %.n
  =/  width=@ud  (lent n)
  |-  ^-  ?
  ?~  h  %.n
  ?:  =(n (scag width `(list @)`h))  %.y
  $(h t.h)
=/  forms=(list [name=@t needle=@])
  :~  ['a credential value' secret-a]
      ['the GitHub token, stored as a credential' secret-github]
      ['a multi-line credential, whole' secret-pem]
      ['a line of a multi-line credential' pem-line]
      ['the CI private key as hex' (hex-bytes:ci-provenance ci-sek 32)]
      ['the CI private key as @ux' (scot %ux ci-sek)]
      ['the CI private key as bytes' ci-sek]
      ['the ship private key as hex' (hex-bytes:ci-provenance ship-sek 32)]
      ['the ship private key as @ux' (scot %ux ship-sek)]
      ['a token hash as @uv' (scot %uv token-hash)]
      ['a token hash as hex' (hex-bytes:ci-provenance token-hash 32)]
      ['a bearer hash as @uv' (scot %uv bearer-hash)]
      ['a bearer hash as hex' (hex-bytes:ci-provenance bearer-hash 32)]
      ['a read capability as @uv' (scot %uv read-hash)]
      ['a read capability as hex' (hex-bytes:ci-provenance read-hash 32)]
      ['an approval in force' (scot %uv id.live)]
  ==
=/  absent=(list [name=@t expect=? got=?])
  %+  turn  forms
  |=  [name=@t needle=@]
  [(rap 3 ~['the export holds ' name]) %.n (has-bytes everything needle)]
=/  present=(list [name=@t expect=? got=?])
  :~  ['the export holds the credential names' %.y &((has-bytes everything 'DEPLOY_KEY') (has-bytes everything 'GITHUB_TOKEN'))]
      ['the export holds the CI public key' %.y (has-bytes everything (hex-bytes:ci-provenance 0x7777 32))]
      ['the export holds the runner id' %.y (has-bytes everything (scot %uv 0v1.daemn))]
      ['the export holds the spent approval as a record' %.y (has-bytes everything (scot %uv id.spent))]
      ['the export holds the scrub mask where the secret was' %.y (has-bytes everything 'the log printed ***')]
  ==
::  the files and the commit
::
=/  want=(list path)
  :~  /readme/md
      /checkpoint/manifest/json
      /checkpoint/policy/json
      /checkpoint/locks/json
      /checkpoint/access/json
      /checkpoint/runners/json
      /checkpoint/credentials/json
      /checkpoint/signing/json
      /checkpoint/runs/json
      /checkpoint/audit/json
  ==
=/  snapped=(unit [commit=oid:git objects=(map oid:git object:git)])
  (snapshot:git-clay (malt files) ~ ~ ship now 'checkpoint')
=/  blobs=(list octs)
  ?~  snapped  ~
  %+  murn  ~(val by objects.u.snapped)
  |=(o=object:git ?.(=(%blob kind.o) ~ `data.o))
=/  written=(set octs)  (silt (turn files |=([* data=octs] data)))
=/  layout=(list [name=@t expect=? got=?])
  :~  ['the export writes exactly its ten files' %.y =(want (turn files |=([=path *] path)))]
      ['the commit builds' %.y ?=(^ snapped)]
      ['the commit holds ten blobs, two trees and itself' %.y ?&(?=(^ snapped) =(13 ~(wyt by objects.u.snapped)))]
      ['every blob of the commit is one of the files' %.y ?&(=(10 (lent blobs)) (levy blobs |=(b=octs (~(has in written) b))))]
  ==
::  the files read back, by name
::
=/  by-name=(map @t octs)
  %-  malt
  %+  murn  files
  |=  [=path data=octs]
  ^-  (unit [@t octs])
  ?.  ?=([%checkpoint @ @ ~] path)  ~
  `[(rap 3 ~[i.t.path '.' i.t.t.path]) data]
=/  read=(each [manifest=checkpoint-manifest:ci content=checkpoint-content:ci] @t)
  (import:ci-checkpoint by-name)
=/  refused
  |=  [m=(map @t octs) words=@t]
  ^-  ?
  =/  r=(each [manifest=checkpoint-manifest:ci content=checkpoint-content:ci] @t)
    (import:ci-checkpoint m)
  ?.  ?=(%| -.r)  %.n
  (has-bytes p.r words)
=/  flip
  |=  [m=(map @t octs) file=@t]
  ^-  (map @t octs)
  =/  d=octs  (~(got by m) file)
  (~(put by m) file [p.d (mix q.d 1)])
=/  truncate
  |=  [m=(map @t octs) file=@t]
  ^-  (map @t octs)
  =/  d=octs  (~(got by m) file)
  (~(put by m) file [(dec p.d) (end [3 (dec p.d)] q.d)])
=/  manifest-jon=json  (need (de:json:html q:(~(got by by-name) 'manifest.json')))
=/  bumped=json
  ?>  ?=([%o *] manifest-jon)
  [%o (~(put by p.manifest-jon) 'version' [%n ~.2])]
=/  foreign=json
  ?>  ?=([%o *] manifest-jon)
  [%o (~(put by p.manifest-jon) 'format' [%s 'some-other-backup'])]
=/  miscounted=checkpoint-manifest:ci
  %=  manifest.made
    sections
      %+  turn  sections.manifest.made
      |=(r=checkpoint-section:ci ?.(=('runners' name.r) r r(count +(count.r))))
  ==
::  a policy file with a malformed repository, listed with its own
::  length, digest and count, so only its record is wrong
::
=/  bad-policy=octs  (as-octs:mimes:html '{"repositories":[{"repo":"demo"}]}')
=/  bad-policy-manifest=checkpoint-manifest:ci
  %=  manifest.made
    sections
      %+  turn  sections.manifest.made
      |=  r=checkpoint-section:ci
      ?.  =('policy' name.r)  r
      r(count 1, sha256 (digest-of:ci-checkpoint bad-policy), bytes p.bad-policy)
  ==
::  a locks file whose lock is not the one its digest names
::
=/  wrong-lock-body=json
  %-  locks-json:ci-checkpoint
  ~[[lock(digest (shax 'another digest')) ~]]
=/  wrong-lock-jon=json
  ?>  ?=([%o *] wrong-lock-body)
  =/  items=(list json)
    =/  v=(unit json)  (~(get by p.wrong-lock-body) 'locks')
    ?>  ?=([~ %a *] v)
    p.u.v
  ?>  ?=([[%o *] ~] items)
  =/  item=(map @t json)  (~(put by p.i.items) 'digest' [%s (hex-bytes:ci-provenance lock-digest 32)])
  [%o (~(put by p.wrong-lock-body) 'locks' [%a ~[[%o item]]])]
=/  wrong-lock=octs  (octs-of:ci-checkpoint wrong-lock-jon)
=/  wrong-lock-manifest=checkpoint-manifest:ci
  %=  manifest.made
    sections
      %+  turn  sections.manifest.made
      |=  r=checkpoint-section:ci
      ?.  =('locks' name.r)  r
      r(count 1, sha256 (digest-of:ci-checkpoint wrong-lock), bytes p.wrong-lock)
  ==
=/  with-manifest
  |=  [m=(map @t octs) mf=checkpoint-manifest:ci]
  ^-  (map @t octs)
  (~(put by m) 'manifest.json' (octs-of:ci-checkpoint (manifest-json:ci-checkpoint mf)))
=/  import-cases=(list [name=@t expect=? got=?])
  :~  ['the export reads back whole' %.y ?=(%& -.read)]
      ['what reads back is exactly what was written' %.y ?&(?=(%& -.read) =(content content.p.read))]
      ['the manifest reads back' %.y ?&(?=(%& -.read) =(manifest.made manifest.p.read))]
      ['the manifest lists the eight sections in order' %.y =(~['policy' 'locks' 'access' 'runners' 'credentials' 'signing' 'runs' 'audit'] (turn sections.manifest.made |=(r=checkpoint-section:ci name.r)))]
      ['the manifest counts three credential references' %.y (lien sections.manifest.made |=(r=checkpoint-section:ci &(=('credentials' name.r) =(3 count.r))))]
      ['the manifest\'s digest is the sha-256 of its bytes' %.y =(digest.made (digest-of:ci-checkpoint (~(got by by-name) 'manifest.json')))]
      ['a flipped byte is refused whole' %.y (refused (flip by-name 'policy.json') 'corrupt checkpoint: the sha-256 of policy.json')]
      ['a truncated file is refused whole' %.y (refused (truncate by-name 'runs.json') 'truncated or altered')]
      ['a missing file is refused whole' %.y (refused (~(del by by-name) 'credentials.json') 'incomplete checkpoint: credentials.json is missing')]
      ['a missing manifest is refused whole' %.y (refused (~(del by by-name) 'manifest.json') 'manifest.json is missing')]
      ['a wrong count is refused whole' %.y (refused (with-manifest by-name miscounted) 'incomplete checkpoint: runners.json holds')]
      ['a malformed record is refused whole' %.y (refused (with-manifest (~(put by by-name) 'policy.json' bad-policy) bad-policy-manifest) 'policy.json has a malformed repository')]
      ['an unsupported version is refused whole' %.y (refused (~(put by by-name) 'manifest.json' (octs-of:ci-checkpoint bumped)) 'unsupported checkpoint: format version 2')]
      ['another format is refused whole' %.y (refused (~(put by by-name) 'manifest.json' (octs-of:ci-checkpoint foreign)) 'not an urgit-ci checkpoint')]
      ['a manifest that is not JSON is refused whole' %.y (refused (~(put by by-name) 'manifest.json' (as-octs:mimes:html 'not json')) 'manifest.json is not JSON')]
      ['a lock that is not the one listed is refused whole' %.y (refused (with-manifest (~(put by by-name) 'locks.json' wrong-lock) wrong-lock-manifest) 'locks.json has a malformed lock')]
      ['a corrupt checkpoint reads back' %.n =(%& -:(import:ci-checkpoint (flip by-name 'audit.json')))]
  ==
::  the replica records
::
=/  record=checkpoint:ci
  :*  'cp-1'  now  'policy change'  ship  'ci-checkpoints'  'refs/heads/main'
      ~  0x1  'digest'  ~  [%pending ~]  [%waiting ~]
  ==
=/  r1=(list checkpoint:ci)  (add-record:ci-checkpoint ~ record)
=/  r2=(list checkpoint:ci)  (written:ci-checkpoint r1 'cp-1' now)
=/  r3=(list checkpoint:ci)  (push-started:ci-checkpoint r2 0v7 'GitHub owner/backup' now)
=/  r4=(list checkpoint:ci)
  (push-answered:ci-checkpoint r3 0v7 %.n 'GitHub rejected the branch update' now)
=/  r5=(list checkpoint:ci)  (push-answered:ci-checkpoint r3 0v7 %.y 'GitHub branch synchronized' now)
=/  r6=(list checkpoint:ci)  (push-answered:ci-checkpoint r3 0v8 %.y 'another push' now)
=/  r7=(list checkpoint:ci)
  (push-answered:ci-checkpoint r3 0v7 %.n push-silence:ci-checkpoint now)
=/  r8=(list checkpoint:ci)  (push-unconfigured:ci-checkpoint r2 'no replica is configured')
=/  r9=(list checkpoint:ci)
  (not-written:ci-checkpoint r1 'cp-1' now 'the checkpoint branch moved')
=/  second=checkpoint:ci  record(id 'cp-2', parent `0x1, commit 0x2)
=/  q1=(list checkpoint:ci)  (written:ci-checkpoint (add-record:ci-checkpoint r3 second) 'cp-2' now)
=/  q2=(list checkpoint:ci)
  (push-answered:ci-checkpoint q1 0v7 %.y 'GitHub branch synchronized' now)
=/  replica-of
  |=  [records=(list checkpoint:ci) id=@t]
  ^-  checkpoint-replica:ci
  =/  hits=(list checkpoint:ci)  (skim records |=(c=checkpoint:ci =(id id.c)))
  ?~  hits  [%skipped 'missing']
  replica.i.hits
=/  written-of
  |=  [records=(list checkpoint:ci) id=@t]
  ^-  checkpoint-write:ci
  =/  hits=(list checkpoint:ci)  (skim records |=(c=checkpoint:ci =(id id.c)))
  ?~  hits  [%pending ~]
  written.i.hits
=/  many=(list checkpoint:ci)
  %+  roll  (gulf 1 25)
  |=  [n=@ud acc=(list checkpoint:ci)]
  (add-record:ci-checkpoint acc record(id (crip (a-co:co n))))
=/  replicas=(list [name=@t expect=? got=?])
  :~  ['a checkpoint whose write is pending is not pushed' %.y =(~ (next-push:ci-checkpoint r1))]
      ['a written checkpoint waits for its push' %.y =(%waiting -:(replica-of r2 'cp-1'))]
      ['a written checkpoint is pushed next' %.y =(`'cp-1' (bind (next-push:ci-checkpoint r2) |=(c=checkpoint:ci id.c)))]
      ['a failed push is a failed backup' %.y =(%failed -:(replica-of r4 'cp-1'))]
      ['a failed push is recorded as confirmed' %.n =(%confirmed -:(replica-of r4 'cp-1'))]
      ['a failed push leaves the checkpoint written' %.y =(%written -:(written-of r4 'cp-1'))]
      ['a failed push keeps the replica\'s own words' %.y =([%failed now 'GitHub owner/backup' 'GitHub rejected the branch update'] (replica-of r4 'cp-1'))]
      ['an accepted push is confirmed' %.y =(%confirmed -:(replica-of r5 'cp-1'))]
      ['an answer for another ticket changes nothing' %.y =(%pushing -:(replica-of r6 'cp-1'))]
      ['a push with no answer is a failed backup' %.y =(%failed -:(replica-of r7 'cp-1'))]
      ['no push path leaves the replica not confirmed' %.y =(%unconfigured -:(replica-of r8 'cp-1'))]
      ['no push path is recorded as confirmed' %.n =(%confirmed -:(replica-of r8 'cp-1'))]
      ['a write the forge refused is not written' %.y =(%failed -:(written-of r9 'cp-1'))]
      ['a write the forge refused has nothing to push' %.y =(%skipped -:(replica-of r9 'cp-1'))]
      ['a checkpoint written during a push waits' %.y =(%waiting -:(replica-of q1 'cp-2'))]
      ['no second push starts while one is in flight' %.y =(~ (next-push:ci-checkpoint q1))]
      ['the next push starts once the first is answered' %.y =(`'cp-2' (bind (next-push:ci-checkpoint q2) |=(c=checkpoint:ci id.c)))]
      ['records are newest first and bounded' %.y &(=(20 (lent many)) =('25' id:(snag 0 many)))]
  ==
::  pause, import and apply: the refusals
::
=/  paused-s=state-0:ci  s(paused.recovery `[now ship 'drill'])
=/  staged=staged-checkpoint:ci
  ?>  ?=(%& -.read)
  [0xc0ff.ee00 now ship manifest.p.read content.p.read]
=/  staged-unpaused=state-0:ci  s(staged.recovery `staged)
=/  staged-paused=state-0:ci  paused-s(staged.recovery `staged)
=/  busy=state-0:ci
  staged-paused(attempts (~(put by attempts.staged-paused) id.att att(status %running)))
=/  refusals=(list [name=@t expect=? got=?])
  :~  ['an import into an unpaused CI is refused' %.y ?=(^ (import-refusal:ci-checkpoint s))]
      ['an import into a paused CI is allowed' %.y ?=(~ (import-refusal:ci-checkpoint paused-s))]
      ['an apply to an unpaused CI is refused' %.y ?=(^ (apply-refusal:ci-checkpoint staged-unpaused id))]
      ['an apply with nothing staged is refused' %.y ?=(^ (apply-refusal:ci-checkpoint paused-s id))]
      ['an apply of another id than the staged one is refused' %.y ?=(^ (apply-refusal:ci-checkpoint staged-paused 'another'))]
      ['an apply while an attempt runs is refused' %.y ?=(^ (apply-refusal:ci-checkpoint busy id))]
      ['an apply when paused, staged and idle is allowed' %.y ?=(~ (apply-refusal:ci-checkpoint staged-paused id))]
      ['a pause when paused is refused' %.y ?=(^ (pause-refusal:ci-checkpoint paused-s))]
      ['a resume when not paused is refused' %.y ?=(^ (resume-refusal:ci-checkpoint s))]
      ['a paused CI reads as paused' %.y (paused:ci-checkpoint paused-s)]
      ['an unpaused CI reads as paused' %.n (paused:ci-checkpoint s)]
  ==
::  an apply on a fresh ship: its own new signing key, no runs, paused
::
=/  fresh-signing=signing:ci  [0x4242 0x4343 0x4444 now]
=/  fresh=state-0:ci
  =/  b=state-0:ci  *state-0:ci
  b(signing `fresh-signing, paused.recovery `[now ~zod 'drill'], staged.recovery `staged)
=/  here=presence:ci-checkpoint
  [(silt ~[['demo' 'refs/heads/main']]) (silt ~[['demo' revision]])]
=/  done=[s=state-0:ci =restore:ci]  (apply:ci-checkpoint fresh here ship now 0v0)
=/  after=state-0:ci  s.done
=/  changes=(list change:ci-checkpoint)  (diff:ci-checkpoint fresh content)
=/  applies=(list [name=@t expect=? got=?])
  :~  ['credentials come back with no value: none is stored' %.y =(~ credentials.after)]
      ['every credential reference needs re-entry' %.y =(3 (lent credentials.history.recovery.after))]
      ['no approval comes back live' %.y =(~ approvals.after)]
      ['no override comes back live' %.y =(~ overrides.after)]
      ['the spent approval and the override come back as history' %.y =(2 (lent authorizations.history.recovery.after))]
      ['the approval in force was never exported' %.n (lien authorizations.history.recovery.after |=(a=authorization:ci =(id.live (auth-id:ci-checkpoint a))))]
      ['no lease comes back: no assignment, read capability or mirror token' %.y &(=(~ assignments.after) =(~ read-capabilities.after) =(~ mirror-tokens.after))]
      ['no runner comes back enrolled: no daemon record' %.y =(~ daemons.after)]
      ['every runner must re-enroll' %.y =(~[0v1.daemn] (turn runners.history.recovery.after |=(r=runner-record:ci id.r)))]
      ['the ship keeps its own signing key' %.y =(`fresh-signing signing.after)]
      ['the old public key is history only' %.y =(~[0x7777] (turn keys.history.recovery.after |=(k=key-record:ci pub.k)))]
      ['no run, attempt or schedule is created' %.y &(=(~ candidates.after) =(~ attempts.after) =(~ schedules.after))]
      ['run summaries come back as history' %.y =(~[0v3.cand1] (turn runs.history.recovery.after |=(r=run-summary:ci id.r)))]
      ['a CI-protected ref with a tip here comes back' %.y (~(has in ci-protected.after) ['demo' 'refs/heads/main'])]
      ['a CI-protected ref with no tip here comes back' %.n (~(has in ci-protected.after) ['demo' 'refs/heads/release'])]
      ['the skipped ref is said' %.y (lien skipped.restore.done |=(w=@t (has-bytes w 'refs/heads/release')))]
      ['the baseline whose revision is here comes back' %.y =(`base(reason 'first promotion') (~(get by baselines.after) ['demo' 'refs/heads/main']))]
      ['the baseline whose revision is not here comes back' %.n (~(has by baselines.after) ['tools' 'refs/heads/main'])]
      ['the locks come back' %.y &((~(has by locks.after) lock-digest) =(`'evidence-of-tools' (~(get by input-evidence.after) auto-digest)))]
      ['the environments and role bindings come back' %.y &(=(`prod (~(get by environments.after) ['demo' 'prod'])) =(`~[approver overrider] (~(get by roles.after) 'demo')))]
      ['the policy fields come back' %.y &(=(`%restricted (~(get by policies.after) 'demo')) =(`%container (~(get by sandbox-requirements.after) 'demo')) =(`~[net] (~(get by network-policies.after) 'demo')))]
      ['the generation moves' %.y =(1 (~(gut by generations.after) 'demo' 0))]
      ['the staged checkpoint is cleared and the restore recorded' %.y &(=(~ staged.recovery.after) =(~[restore.done] restores.recovery.after))]
      ['an apply never resumes CI' %.y ?=(^ paused.recovery.after)]
      ['the diff names each grant' %.y (lien changes |=(c=change:ci-checkpoint &(=('access' section.c) =(%add kind.c) (has-bytes text.c '~bud'))))]
      ['the diff says credentials need re-entry' %.y (lien changes |=(c=change:ci-checkpoint &(=('credentials' section.c) (has-bytes text.c 're-entry'))))]
      ['the diff says the old key becomes history' %.y (lien changes |=(c=change:ci-checkpoint &(=('signing' section.c) (has-bytes text.c 'becomes history'))))]
  ==
::  an apply in place: an open run of the restored repository and an
::  unused approval of this ship, every credential value stored here
::
=/  open-run=candidate:ci  run(id 0v8.openr, status %pending, attempts ~)
=/  in-place-s=state-0:ci
  staged-paused(candidates (~(put by candidates.staged-paused) id.open-run open-run))
=/  in-place=[s=state-0:ci =restore:ci]  (apply:ci-checkpoint in-place-s here ship now 0v0)
=/  kept=state-0:ci  s.in-place
=/  in-place-cases=(list [name=@t expect=? got=?])
  :~  ['an open run of a restored repository is cancelled' %.y =(%cancelled status:(~(got by candidates.kept) 0v8.openr))]
      ['the cancellation is said' %.y =(~[0v8.openr] cancelled.restore.in-place)]
      ['a closed run keeps its status' %.y =(%failed status:(~(got by candidates.kept) 0v3.cand1))]
      ['an unused approval of this ship is invalidated' %.y !=(~ invalidated:(~(got by approvals.kept) id.live))]
      ['every credential value stored here is kept' %.y =(credentials.s credentials.kept)]
      ['no reference needs re-entry when its value is stored here' %.y =(~ credentials.history.recovery.kept)]
      ['this ship\'s own key stays' %.y =(signing.s signing.kept)]
      ['its own key becomes history' %.n (lien keys.history.recovery.kept |=(k=key-record:ci =(pub.k 0x7777)))]
  ==
=/  cases=(list [name=@t expect=? got=?])
  :(weld absent present layout import-cases replicas refusals applies in-place-cases)
=/  failed=(list @t)
  %+  murn  cases
  |=  [name=@t expect=? got=?]
  ?:(=(expect got) ~ `name)
=/  passed=@ud  (sub (lent cases) (lent failed))
~&  [%false-assertions-refused (lent (skim cases |=([* expect=? got=?] &(!expect !got)))) %of (lent (skim cases |=([* expect=? *] !expect)))]
~&  [%failed failed]
~&  (crip "passed={<passed>} of={<(lent cases)>}")
?=(~ failed)
