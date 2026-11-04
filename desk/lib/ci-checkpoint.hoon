::  CI-RECOVERY-1 (R5.2-A, ratified 2026-09-09): the checkpoint of
::  %urgit-ci's CI configuration, and its paused restore.
::
::    a checkpoint is the CI-configuration projection only.  it holds the
::    policy of each repository, the promoted baselines and the locks they
::    name.  it holds environment rules and role bindings, runner public
::    records and credential references.  it holds the CI public key and
::    its certificate, bounded run summaries with their log handles, and
::    the approval and override audit.  a manifest lists them all.
::
::    it never holds a repository object, a store byte or a credential
::    value.  it never holds a private key, a bearer or token hash, a live
::    lease or an approval in force.  it never holds a mirror token, a read
::    capability or the GitHub token.
::
::    everything here is pure.  %urgit-ci reads the ship, sends the cards
::    and calls these arms.  desk/gen/ci-checkpoint-vector calls the same
::    arms on a populated state.
::
/-  ci, git
/+  ci-event, ci-provenance, git-codec, git-protocol
|%
::  ---- the format ----
::
++  format-name  'urgit-ci-checkpoint'
++  format-version  1
::  the private repository checkpoints are written to, and the directory
::  of its tree that holds the newest one
::
++  repository  'ci-checkpoints'
++  directory  'checkpoint'
++  manifest-file  'manifest.json'
::  the bounds: checkpoint records kept on the ship, runs and attempts per
::  run in a checkpoint, audit records, and each history list
::
++  max-records  20
++  max-runs  100
++  max-attempts  64
++  max-audit  500
++  max-history  500
::  a replica push with no answer by then is a failed backup
::
++  replica-wait  ~m15
::
::  the sections of version 1, in manifest order, with their files and
::  their paths in the tree
::
++  sections
  ^-  (list [name=@t file=@t =path])
  :~  ['policy' 'policy.json' /checkpoint/policy/json]
      ['locks' 'locks.json' /checkpoint/locks/json]
      ['access' 'access.json' /checkpoint/access/json]
      ['runners' 'runners.json' /checkpoint/runners/json]
      ['credentials' 'credentials.json' /checkpoint/credentials/json]
      ['signing' 'signing.json' /checkpoint/signing/json]
      ['runs' 'runs.json' /checkpoint/runs/json]
      ['audit' 'audit.json' /checkpoint/audit/json]
  ==
::
::  what a checkpoint never holds, as its manifest lists it
::
++  excluded
  ^-  (list @t)
  :~  'repository objects'
      'LFS payloads'
      'store bytes'
      'credential values'
      'private keys'
      'bearer and token hashes'
      'live leases'
      'approvals in force'
      'mirror tokens'
      'read capabilities'
      'the GitHub token'
  ==
::
::  the audit kinds the audit section keeps: approvals, overrides,
::  promotions, role grants and restores
::
++  audit-kinds
  ^-  (set @t)
  %-  silt
  ^-  (list @t)
  :~  'approve-environment'
      'record-override'
      'approve-candidate'
      'promote-baseline'
      'revoke-baseline'
      'set-role'
      'clear-role'
      'checkpoint-applied'
  ==
::
::  the repository's readme: what the repository is, and where the drill
::  is written down
::
++  readme
  ^-  @t
  %+  rap  3
  :~  '# ci-checkpoints\0a\0a'
      'This private repository holds checkpoints of the CI configuration '
      'of an urgit ship.\0a'
      'The ship writes them. Do not edit them by hand.\0a\0a'
      'Each commit holds one checkpoint under `checkpoint/`. '
      '`checkpoint/manifest.json` lists each file with its sha-256.\0a'
      'A checkpoint holds no credential value, private key, token or '
      'repository object.\0a\0a'
      'To restore, follow "Backup and restore" in the urgit '
      '`docs/ci-setup-guide.md`.\0a'
  ==
::
::  ---- a checkpoint's id ----
::
::  <yyyymmdd>t<hhmmss>z-<sequence>-<ship>: sorts by time, and stays
::  unique when a restored ship writes into the same repository
::
++  checkpoint-id
  |=  [at=@da sequence=@ud ship=@p]
  ^-  @t
  =/  d  (yore at)
  =/  name=tape  (slag 1 (scow %p ship))
  %-  crip
  ;:  weld
    (pad 4 y.d)  (pad 2 m.d)  (pad 2 d.t.d)  "t"
    (pad 2 h.t.d)  (pad 2 m.t.d)  (pad 2 s.t.d)  "z-"
    (pad 4 sequence)  "-"  name
  ==
::
::  a number in decimal, zero-padded to .width digits
::
++  pad
  |=  [width=@ud n=@ud]
  ^-  tape
  =/  digits=tape  (a-co:co n)
  ?:  (gte (lent digits) width)  digits
  (weld (reap (sub width (lent digits)) '0') digits)
::
::  ---- the secrets a checkpoint must not hold ----
::
::  every form a stored credential value is scrubbed in (lib/ci-event).
::  the export reads the values here and nowhere else: free text that
::  reached the ship from outside is scrubbed of them before it is written
::
++  secret-forms
  |=  s=state-0:ci
  ^-  (list @t)
  =/  values=(list @t)
    (turn ~(val by credentials.s) |=(c=credential:ci value.c))
  =/  forms=(list (list @t))  (turn values scrub-forms:ci-event)
  (zing forms)
::
++  clean
  |=  [text=@t secrets=(list @t)]
  ^-  @t
  (scrub-text:ci-event text secrets)
::
::  ---- the projection ----
::
::  the checkpoint content of a state at .now: the CI-configuration
::  projection only, every free text scrubbed
::
++  project
  |=  [s=state-0:ci ship=@p now=@da]
  ^-  checkpoint-content:ci
  =/  secrets=(list @t)  (secret-forms s)
  :*  (policy-of s secrets)
      (locks-of s)
      (environments-of s secrets)
      (bindings-of s)
      (runners-of s)
      (credentials-of s)
      (key-of s ship)
      (runs-of s secrets)
      (authorizations-of s secrets now)
      (audit-of s secrets)
  ==
::
::  every repository with any CI policy
::
++  policy-repos
  |=  s=state-0:ci
  ^-  (list @t)
  =/  protected=(list @t)
    (turn ~(tap in ci-protected.s) |=([r=@t *] r))
  =/  based=(list @t)
    (turn ~(tap by baselines.s) |=([[r=@t *] *] r))
  =/  envs=(list @t)
    (turn ~(tap by environments.s) |=([[r=@t *] *] r))
  =/  keyed=(list @t)
    ;:  weld
      ~(tap in ~(key by policies.s))
      ~(tap in ~(key by sandbox-requirements.s))
      ~(tap in ~(key by harness-paths.s))
      ~(tap in ~(key by network-policies.s))
      ~(tap in ~(key by automatic-inputs.s))
      ~(tap in ~(key by roles.s))
    ==
  =/  all=(list @t)  :(weld protected based envs keyed)
  (sort ~(tap in (silt all)) aor)
::
++  policy-of
  |=  [s=state-0:ci secrets=(list @t)]
  ^-  (list repo-policy:ci)
  =/  names=(list @t)  (policy-repos s)
  %+  turn  names
  |=  repo=@t
  ^-  repo-policy:ci
  =/  refs=(list @t)
    %+  murn  ~(tap in ci-protected.s)
    |=([r=@t ref=@t] ?.(=(r repo) ~ `ref))
  =/  found=(list [ref=@t =baseline:ci])
    %+  murn  ~(tap by baselines.s)
    |=  [[r=@t ref=@t] b=baseline:ci]
    ^-  (unit [ref=@t =baseline:ci])
    ?.  =(r repo)  ~
    `[ref b(reason (clean reason.b secrets))]
  =/  bases=(list [ref=@t =baseline:ci])
    (sort found |=([a=[ref=@t *] b=[ref=@t *]] (aor ref.a ref.b)))
  =/  inputs=(list @t)  (~(gut by automatic-inputs.s) repo ~)
  =/  networks=(list network-policy:ci)  (~(gut by network-policies.s) repo ~)
  :*  repo
      (sort refs aor)
      (~(gut by policies.s) repo %approval)
      (~(get by sandbox-requirements.s) repo)
      (~(get by harness-paths.s) repo)
      inputs
      networks
      bases
  ==
::
::  the locks the promoted baselines name, with any automatic-input
::  evidence their digest binds
::
++  locks-of
  |=  s=state-0:ci
  ^-  (list [=lock:ci evidence=(unit @t)])
  =/  named=(list @ux)
    %+  murn  ~(val by baselines.s)
    |=(b=baseline:ci lock.b)
  =/  digests=(list @ux)  (sort ~(tap in (silt named)) lth)
  %+  murn  digests
  |=  d=@ux
  ^-  (unit [=lock:ci evidence=(unit @t)])
  =/  found=(unit lock:ci)  (~(get by locks.s) d)
  ?~  found  ~
  `[u.found (~(get by input-evidence.s) d)]
::
++  environments-of
  |=  [s=state-0:ci secrets=(list @t)]
  ^-  (list [repo=@t =environment:ci])
  =/  all=(list [repo=@t =environment:ci])
    %+  turn  ~(tap by environments.s)
    |=  [[repo=@t name=@t] e=environment:ci]
    ^-  [repo=@t =environment:ci]
    [repo e(description (clean description.e secrets))]
  %+  sort  all
  |=  [a=[repo=@t =environment:ci] b=[repo=@t =environment:ci]]
  ?.  =(repo.a repo.b)  (aor repo.a repo.b)
  (aor name.environment.a name.environment.b)
::
++  bindings-of
  |=  s=state-0:ci
  ^-  (list [repo=@t =binding:ci])
  =/  repos=(list @t)  (sort ~(tap in ~(key by roles.s)) aor)
  =/  nested=(list (list [repo=@t =binding:ci]))
    %+  turn  repos
    |=  repo=@t
    ^-  (list [repo=@t =binding:ci])
    =/  mine=(list binding:ci)  (~(gut by roles.s) repo ~)
    (turn mine |=(b=binding:ci [repo b]))
  (zing nested)
::
::  every runner's public record: id, labels, binding, enrolled and
::  revoked.  the token hash and the bearer hash are never read
::
++  runners-of
  |=  s=state-0:ci
  ^-  (list runner-record:ci)
  =/  all=(list daemon:ci)
    (sort ~(val by daemons.s) |=([a=daemon:ci b=daemon:ci] (lth id.a id.b)))
  %+  turn  all
  |=  d=daemon:ci
  ^-  runner-record:ci
  =/  labels=(list @t)  (sort ~(tap in labels.d) aor)
  =/  repos=(unit (list @t))
    ?~  repos.d  ~
    `(sort ~(tap in u.repos.d) aor)
  [id.d labels repos enrolled.d revoked.d]
::
::  every credential reference, and every one an earlier restore brought
::  back that still needs re-entry.  the value is never read
::
++  credentials-of
  |=  s=state-0:ci
  ^-  (list credential-ref:ci)
  =/  live=(list credential-ref:ci)
    %+  turn  ~(tap by credentials.s)
    |=  [[repo=@t name=@t] c=credential:ci]
    ^-  credential-ref:ci
    [repo name scope.c (sort ~(tap in envs.c) aor) created.c]
  =/  waiting=(list credential-ref:ci)
    %+  skip  credentials.history.recovery.s
    |=(r=credential-ref:ci (~(has by credentials.s) [repo.r name.r]))
  =/  all=(list credential-ref:ci)  (weld live waiting)
  %+  sort  all
  |=  [a=credential-ref:ci b=credential-ref:ci]
  ?.  =(repo.a repo.b)  (aor repo.a repo.b)
  (aor name.a name.b)
::
::  the CI signing key's public half and certificate, and the ship's own
::  public signing key: neither private key is read
::
++  key-of
  |=  [s=state-0:ci ship=@p]
  ^-  (unit key-record:ci)
  ?~  signing.s  ~
  =/  life=(unit @ud)  ?~(ship-keys.s ~ `life.u.ship-keys.s)
  =/  ship-key=(unit @ux)  ?~(ship-keys.s ~ `pub.u.ship-keys.s)
  `[pub.u.signing.s cert.u.signing.s created.u.signing.s ship life ship-key]
::
::  the newest runs as history: this ship's and those an earlier restore
::  brought back, one record per run, newest first
::
++  runs-of
  |=  [s=state-0:ci secrets=(list @t)]
  ^-  (list run-summary:ci)
  =/  live=(list run-summary:ci)
    %+  turn  ~(val by candidates.s)
    |=  c=candidate:ci
    ^-  run-summary:ci
    =/  ids=(list attempt-id:ci)  (scag max-attempts attempts.c)
    =/  handles=(list attempt-handle:ci)
      %+  murn  ids
      |=  id=attempt-id:ci
      ^-  (unit attempt-handle:ci)
      =/  a=(unit attempt:ci)  (~(get by attempts.s) id)
      ?~  a  ~
      `[id workflow.u.a job.u.a status.u.a log.u.a]
    =/  verdict=(unit @t)
      ?~  verdict-reason.c  ~
      `(clean u.verdict-reason.c secrets)
    [id.c repo.c ref.c head.c status.c verdict mode.c created.c updated.c handles]
  =/  older=(map candidate-id:ci run-summary:ci)
    %-  malt
    %+  turn  runs.history.recovery.s
    |=(r=run-summary:ci [id.r r])
  =/  merged=(map candidate-id:ci run-summary:ci)
    %+  roll  live
    |=  [r=run-summary:ci acc=_older]
    (~(put by acc) id.r r)
  =/  sorted=(list run-summary:ci)
    %+  sort  ~(val by merged)
    |=([a=run-summary:ci b=run-summary:ci] (gth updated.a updated.b))
  (scag max-runs sorted)
::
::  an authorization record's time and id
::
++  auth-at
  |=  a=authorization:ci
  ^-  @da
  ?-  -.a
    %approval  at.approval.a
    %override  at.override.a
  ==
::
++  auth-id
  |=  a=authorization:ci
  ^-  @uv
  ?-  -.a
    %approval  id.approval.a
    %override  id.override.a
  ==
::
::  whether an approval or override is in force at .now: unused, valid and
::  unexpired.  one in force is never exported, as its audit entry is
::
++  approval-in-force
  |=  [a=approval:ci now=@da]
  ^-  ?
  ?&(?=(~ consumed.a) ?=(~ invalidated.a) (lth now expires.a))
::
++  override-in-force
  |=  [o=override:ci now=@da]
  ^-  ?
  ?&(?=(~ consumed.o) ?=(~ invalidated.o) (lth now expires.o))
::
::  every approval and override no longer in force, as inert records,
::  with those an earlier restore brought back, newest first
::
++  authorizations-of
  |=  [s=state-0:ci secrets=(list @t) now=@da]
  ^-  (list authorization:ci)
  =/  spent-approvals=(list approval:ci)
    (skip ~(val by approvals.s) |=(a=approval:ci (approval-in-force a now)))
  =/  spent-overrides=(list override:ci)
    (skip ~(val by overrides.s) |=(o=override:ci (override-in-force o now)))
  =/  approvals=(list authorization:ci)
    %+  turn  spent-approvals
    |=  a=approval:ci
    ^-  authorization:ci
    =/  why=(unit @t)  ?~(invalidated.a ~ `(clean u.invalidated.a secrets))
    [%approval a(invalidated why)]
  =/  overrides=(list authorization:ci)
    %+  turn  spent-overrides
    |=  o=override:ci
    ^-  authorization:ci
    =/  why=(unit @t)  ?~(invalidated.o ~ `(clean u.invalidated.o secrets))
    [%override o(reason (clean reason.o secrets), missing (clean missing.o secrets), invalidated why)]
  =/  older=(map @uv authorization:ci)
    %-  malt
    %+  turn  authorizations.history.recovery.s
    |=(a=authorization:ci [(auth-id a) a])
  =/  live=(list authorization:ci)  (weld approvals overrides)
  =/  merged=(map @uv authorization:ci)
    %+  roll  live
    |=  [a=authorization:ci acc=_older]
    (~(put by acc) (auth-id a) a)
  =/  sorted=(list authorization:ci)
    %+  sort  ~(val by merged)
    |=([a=authorization:ci b=authorization:ci] (gth (auth-at a) (auth-at b)))
  (scag max-audit sorted)
::
::  the audit entries of approvals, overrides, promotions, role grants and
::  restores, with those an earlier restore brought back, newest first
::
++  audit-of
  |=  [s=state-0:ci secrets=(list @t)]
  ^-  (list audit-entry:ci)
  =/  kept=(list audit-entry:ci)
    %+  skim  audit.s
    |=(e=audit-entry:ci (~(has in audit-kinds) kind.e))
  =/  all=(list audit-entry:ci)
    ~(tap in (silt (weld kept audit.history.recovery.s)))
  =/  sorted=(list audit-entry:ci)
    (sort all |=([a=audit-entry:ci b=audit-entry:ci] (gth at.a at.b)))
  %+  turn  (scag max-audit sorted)
  |=(e=audit-entry:ci e(detail (clean detail.e secrets)))
::
::  ---- writing JSON ----
::
++  time-json
  |=  at=@da
  ^-  json
  [%s (scot %da at)]
::
++  ship-json
  |=  who=@p
  ^-  json
  [%s (scot %p who)]
::
++  uv-json
  |=  id=@uv
  ^-  json
  [%s (scot %uv id)]
::
++  oid-json
  |=  o=oid:git
  ^-  json
  [%s (oid-text:git-codec o)]
::
++  texts-json
  |=  items=(list @t)
  ^-  json
  [%a (turn items |=(t=@t `json`[%s t]))]
::
++  maybe-text-json
  |=  t=(unit @t)
  ^-  json
  ?~  t  ~
  [%s u.t]
::
++  maybe-time-json
  |=  t=(unit @da)
  ^-  json
  ?~  t  ~
  (time-json u.t)
::
++  network-policy-json
  |=  n=network-policy:ci
  ^-  json
  %-  pairs:enjs:format
  :~  ['workflow' s+workflow.n]
      ['job' s+job.n]
      ['profile' s+profile.n]
      ['destinations' (texts-json destinations.n)]
      ['environment' (maybe-text-json environment.n)]
      ['actor' (ship-json actor.n)]
      ['at' (time-json at.n)]
  ==
::
++  baseline-json
  |=  [ref=@t b=baseline:ci]
  ^-  json
  %-  pairs:enjs:format
  :~  ['ref' s+ref]
      ['revision' (oid-json revision.b)]
      ['harnessPaths' (texts-json harness-paths.b)]
      ['lock' ?~(lock.b ~ s+(hex-bytes:ci-provenance u.lock.b 32))]
      ['promoted' (time-json promoted.b)]
      ['actor' (ship-json actor.b)]
      ['reason' s+reason.b]
      ['generation' (numb:enjs:format generation.b)]
      ['policyRepo' (maybe-text-json policy-repo.b)]
  ==
::
++  policy-json
  |=  items=(list repo-policy:ci)
  ^-  json
  %-  pairs:enjs:format
  :~  :-  'repositories'
      :-  %a
      %+  turn  items
      |=  p=repo-policy:ci
      ^-  json
      %-  pairs:enjs:format
      :~  ['repo' s+repo.p]
          ['ciProtected' (texts-json protected.p)]
          ['untrusted' s+untrusted.p]
          ['sandbox' ?~(sandbox.p ~ s+u.sandbox.p)]
          ['harnessPaths' ?~(harness-paths.p ~ (texts-json u.harness-paths.p))]
          ['automaticInputs' (texts-json automatic-inputs.p)]
          ['networkPolicies' [%a (turn network-policies.p network-policy-json)]]
          ['baselines' [%a (turn baselines.p baseline-json)]]
      ==
  ==
::
::  a lock is an opaque restore unit: its jam in base64, beside the facts
::  an operator reads, which the import checks against it
::
++  locks-json
  |=  items=(list [=lock:ci evidence=(unit @t)])
  ^-  json
  %-  pairs:enjs:format
  :~  :-  'locks'
      :-  %a
      %+  turn  items
      |=  [l=lock:ci evidence=(unit @t)]
      ^-  json
      =/  noun=@  (jam l)
      %-  pairs:enjs:format
      :~  ['digest' s+(hex-bytes:ci-provenance digest.l 32)]
          ['repo' s+repo.l]
          ['revision' (oid-json revision.l)]
          ['nodes' (numb:enjs:format (lent nodes.l))]
          ['resolved' (time-json resolved.l)]
          ['evidence' (maybe-text-json evidence)]
          ['noun' s+(en:base64:mimes:html [(met 3 noun) noun])]
      ==
  ==
::
++  access-json
  |=  [envs=(list [repo=@t =environment:ci]) bindings=(list [repo=@t =binding:ci])]
  ^-  json
  %-  pairs:enjs:format
  :~  :-  'environments'
      :-  %a
      %+  turn  envs
      |=  [repo=@t e=environment:ci]
      ^-  json
      %-  pairs:enjs:format
      :~  ['repo' s+repo]
          ['name' s+name.e]
          ['description' s+description.e]
          ['automation' s+automation.e]
          ['credentials' (texts-json (sort ~(tap in credentials.e) aor))]
          ['created' (time-json created.e)]
          ['actor' (ship-json actor.e)]
      ==
      :-  'bindings'
      :-  %a
      %+  turn  bindings
      |=  [repo=@t b=binding:ci]
      ^-  json
      %-  pairs:enjs:format
      :~  ['repo' s+repo]
          ['role' s+role.b]
          ['scope' (maybe-text-json scope.b)]
          ['ships' [%a (turn (sort ~(tap in ships.b) lth) ship-json)]]
      ==
  ==
::
++  runners-json
  |=  items=(list runner-record:ci)
  ^-  json
  %-  pairs:enjs:format
  :~  :-  'runners'
      :-  %a
      %+  turn  items
      |=  r=runner-record:ci
      ^-  json
      %-  pairs:enjs:format
      :~  ['id' (uv-json id.r)]
          ['labels' (texts-json labels.r)]
          ['repos' ?~(repos.r ~ (texts-json u.repos.r))]
          ['enrolled' (maybe-time-json enrolled.r)]
          ['revoked' (maybe-time-json revoked.r)]
      ==
  ==
::
++  credentials-json
  |=  items=(list credential-ref:ci)
  ^-  json
  %-  pairs:enjs:format
  :~  :-  'credentials'
      :-  %a
      %+  turn  items
      |=  r=credential-ref:ci
      ^-  json
      %-  pairs:enjs:format
      :~  ['repo' s+repo.r]
          ['name' s+name.r]
          ['scope' s+scope.r]
          ['environments' (texts-json envs.r)]
          ['created' (time-json created.r)]
      ==
  ==
::
++  key-json
  |=  k=key-record:ci
  ^-  json
  %-  pairs:enjs:format
  :~  ['pub' s+(hex-bytes:ci-provenance pub.k 32)]
      ['cert' s+(hex-bytes:ci-provenance cert.k 64)]
      ['certified' b+!=(0x0 cert.k)]
      ['created' (time-json created.k)]
      ['ship' (ship-json ship.k)]
      ['life' ?~(life.k ~ (numb:enjs:format u.life.k))]
      ['shipKey' ?~(ship-key.k ~ s+(hex-bytes:ci-provenance u.ship-key.k 32))]
  ==
::
++  signing-json
  |=  key=(unit key-record:ci)
  ^-  json
  (pairs:enjs:format ~[['key' ?~(key ~ (key-json u.key))]])
::
++  handle-json
  |=  h=attempt-handle:ci
  ^-  json
  %-  pairs:enjs:format
  :~  ['id' (uv-json id.h)]
      ['workflow' (maybe-text-json workflow.h)]
      ['job' (maybe-text-json job.h)]
      ['status' s+status.h]
      :-  'log'
      ?~  log.h  ~
      %-  pairs:enjs:format
      :~  ['key' s+key.u.log.h]
          ['size' (numb:enjs:format size.u.log.h)]
          ['sha256' s+sha256.u.log.h]
      ==
  ==
::
++  runs-json
  |=  items=(list run-summary:ci)
  ^-  json
  %-  pairs:enjs:format
  :~  :-  'runs'
      :-  %a
      %+  turn  items
      |=  r=run-summary:ci
      ^-  json
      %-  pairs:enjs:format
      :~  ['id' (uv-json id.r)]
          ['repo' s+repo.r]
          ['ref' s+ref.r]
          ['head' (oid-json head.r)]
          ['status' s+status.r]
          ['verdict' (maybe-text-json verdict.r)]
          ['mode' s+mode.r]
          ['created' (time-json created.r)]
          ['updated' (time-json updated.r)]
          ['attempts' [%a (turn attempts.r handle-json)]]
      ==
  ==
::
++  approval-json
  |=  a=approval:ci
  ^-  json
  %-  pairs:enjs:format
  :~  ['kind' s+'approval']
      ['id' (uv-json id.a)]
      ['repo' s+repo.a]
      ['incarnation' (uv-json incarnation.a)]
      ['candidate' (uv-json candidate.a)]
      ['oid' (oid-json oid.a)]
      ['workflow' s+workflow.a]
      ['job' s+job.a]
      ['environment' s+environment.a]
      ['credentials' (texts-json (sort ~(tap in credentials.a) aor))]
      ['baseline' (oid-json baseline.a)]
      ['lock' ?~(lock.a ~ s+(hex-bytes:ci-provenance u.lock.a 32))]
      ['generation' (numb:enjs:format generation.a)]
      ['approver' (ship-json approver.a)]
      ['at' (time-json at.a)]
      ['expires' (time-json expires.a)]
      ['consumed' ?~(consumed.a ~ (uv-json u.consumed.a))]
      ['invalidated' (maybe-text-json invalidated.a)]
  ==
::
++  override-json
  |=  o=override:ci
  ^-  json
  %-  pairs:enjs:format
  :~  ['kind' s+'override']
      ['id' (uv-json id.o)]
      ['repo' s+repo.o]
      ['ref' s+ref.o]
      ['incarnation' (uv-json incarnation.o)]
      ['candidate' (uv-json candidate.o)]
      ['oid' (oid-json oid.o)]
      ['expected' (oid-json expected.o)]
      ['actor' (ship-json actor.o)]
      ['reason' s+reason.o]
      ['missing' s+missing.o]
      ['generation' (numb:enjs:format generation.o)]
      ['at' (time-json at.o)]
      ['expires' (time-json expires.o)]
      ['consumed' (maybe-time-json consumed.o)]
      ['invalidated' (maybe-text-json invalidated.o)]
  ==
::
++  audit-json
  |=  [auths=(list authorization:ci) entries=(list audit-entry:ci)]
  ^-  json
  %-  pairs:enjs:format
  :~  :-  'authorizations'
      :-  %a
      %+  turn  auths
      |=  a=authorization:ci
      ^-  json
      ?-  -.a
        %approval  (approval-json approval.a)
        %override  (override-json override.a)
      ==
      :-  'audit'
      :-  %a
      %+  turn  entries
      |=  e=audit-entry:ci
      ^-  json
      %-  pairs:enjs:format
      :~  ['at' (time-json at.e)]
          ['actor' (ship-json actor.e)]
          ['kind' s+kind.e]
          ['repo' s+repo.e]
          ['detail' s+detail.e]
      ==
  ==
::
++  section-json
  |=  r=checkpoint-section:ci
  ^-  json
  %-  pairs:enjs:format
  :~  ['name' s+name.r]
      ['file' s+file.r]
      ['count' (numb:enjs:format count.r)]
      ['sha256' s+sha256.r]
      ['bytes' (numb:enjs:format bytes.r)]
  ==
::
++  manifest-json
  |=  m=checkpoint-manifest:ci
  ^-  json
  %-  pairs:enjs:format
  :~  ['format' s+format-name]
      ['version' (numb:enjs:format format-version)]
      ['id' s+id.m]
      ['ship' (ship-json ship.m)]
      ['desk' s+desk.m]
      ['revision' (numb:enjs:format revision.m)]
      ['created' (time-json at.m)]
      ['cause' s+cause.m]
      ['sections' [%a (turn sections.m section-json)]]
      ['excluded' (texts-json excluded)]
  ==
::
::  the sha-256 of a file's bytes, as hex
::
++  digest-of
  |=  data=octs
  ^-  @t
  (hex-bytes:ci-provenance (shay p.data q.data) 32)
::
++  octs-of
  |=  jon=json
  ^-  octs
  (as-octs:mimes:html (en:json:html jon))
::
::  ---- the export ----
::
::  one checkpoint's files: each section's JSON in manifest order, then
::  the manifest over their lengths and digests.  the manifest's own
::  digest comes back for the record
::
+$  written-files
  $:  files=(list [=path data=octs])
      manifest=checkpoint-manifest:ci
      digest=@t
  ==
::
++  export
  |=  $:  content=checkpoint-content:ci
          id=@t
          ship=@p
          desk=@t
          revision=@ud
          at=@da
          cause=@t
      ==
  ^-  written-files
  =/  bodies=(list [count=@ud body=json])
    :~  [(lent policy.content) (policy-json policy.content)]
        [(lent locks.content) (locks-json locks.content)]
        :-  (add (lent environments.content) (lent bindings.content))
        (access-json environments.content bindings.content)
        [(lent runners.content) (runners-json runners.content)]
        [(lent credentials.content) (credentials-json credentials.content)]
        [?~(key.content 0 1) (signing-json key.content)]
        [(lent runs.content) (runs-json runs.content)]
        :-  (add (lent authorizations.content) (lent audit.content))
        (audit-json authorizations.content audit.content)
    ==
  =/  encoded=(list [count=@ud data=octs])
    (turn bodies |=([count=@ud body=json] [count (octs-of body)]))
  =/  zipped=(list [name=@t file=@t =path count=@ud data=octs])
    =/  names=(list [name=@t file=@t =path])  sections
    =/  items=(list [count=@ud data=octs])  encoded
    =|  out=(list [name=@t file=@t =path count=@ud data=octs])
    |-  ^-  (list [name=@t file=@t =path count=@ud data=octs])
    ?~  names  (flop out)
    ?~  items  (flop out)
    $(names t.names, items t.items, out [[name.i.names file.i.names path.i.names count.i.items data.i.items] out])
  =/  records=(list checkpoint-section:ci)
    %+  turn  zipped
    |=  [name=@t file=@t =path count=@ud data=octs]
    ^-  checkpoint-section:ci
    [name file count (digest-of data) p.data]
  =/  manifest=checkpoint-manifest:ci  [id ship desk revision at cause records]
  =/  manifest-data=octs  (octs-of (manifest-json manifest))
  =/  files=(list [=path data=octs])
    %+  weld
      ^-  (list [=path data=octs])
      :~  [/readme/md (as-octs:mimes:html readme)]
          [/checkpoint/manifest/json manifest-data]
      ==
    (turn zipped |=([* * =path * data=octs] [path data]))
  [files manifest (digest-of manifest-data)]
::
::  ---- reading JSON back ----
::
++  field
  |=  [key=@t jon=json]
  ^-  (unit json)
  ?.  ?=([%o *] jon)  ~
  (~(get by p.jon) key)
::
++  text-at
  |=  [key=@t jon=json]
  ^-  (unit @t)
  =/  v=(unit json)  (field key jon)
  ?~  v  ~
  ?.  ?=([%s *] u.v)  ~
  `p.u.v
::
::  a field that is text or null: ~ when it is missing or another kind
::
++  maybe-text-at
  |=  [key=@t jon=json]
  ^-  (unit (unit @t))
  =/  v=(unit json)  (field key jon)
  ?~  v  ~
  ?~  u.v  [~ ~]
  ?.  ?=([%s *] u.v)  ~
  [~ ~ p.u.v]
::
++  number-at
  |=  [key=@t jon=json]
  ^-  (unit @ud)
  =/  v=(unit json)  (field key jon)
  ?~  v  ~
  ?.  ?=([%n *] u.v)  ~
  (rush p.u.v dim:ag)
::
++  maybe-number-at
  |=  [key=@t jon=json]
  ^-  (unit (unit @ud))
  =/  v=(unit json)  (field key jon)
  ?~  v  ~
  ?~  u.v  [~ ~]
  ?.  ?=([%n *] u.v)  ~
  =/  n=(unit @ud)  (rush p.u.v dim:ag)
  ?~  n  ~
  [~ n]
::
++  array-at
  |=  [key=@t jon=json]
  ^-  (unit (list json))
  =/  v=(unit json)  (field key jon)
  ?~  v  ~
  ?.  ?=([%a *] u.v)  ~
  `p.u.v
::
++  texts-of
  |=  jon=json
  ^-  (unit (list @t))
  ?.  ?=([%a *] jon)  ~
  =/  items=(list @t)
    %+  murn  p.jon
    |=(j=json ?.(?=([%s *] j) ~ `p.j))
  ?.  =((lent items) (lent p.jon))  ~
  `items
::
++  texts-at
  |=  [key=@t jon=json]
  ^-  (unit (list @t))
  =/  v=(unit json)  (field key jon)
  ?~  v  ~
  (texts-of u.v)
::
::  a list of texts or null
::
++  maybe-texts-at
  |=  [key=@t jon=json]
  ^-  (unit (unit (list @t)))
  =/  v=(unit json)  (field key jon)
  ?~  v  ~
  ?~  u.v  [~ ~]
  =/  items=(unit (list @t))  (texts-of u.v)
  ?~  items  ~
  [~ items]
::
++  date-at
  |=  [key=@t jon=json]
  ^-  (unit @da)
  =/  t=(unit @t)  (text-at key jon)
  ?~  t  ~
  (slaw %da u.t)
::
++  maybe-date-at
  |=  [key=@t jon=json]
  ^-  (unit (unit @da))
  =/  t=(unit (unit @t))  (maybe-text-at key jon)
  ?~  t  ~
  ?~  u.t  [~ ~]
  =/  d=(unit @da)  (slaw %da u.u.t)
  ?~  d  ~
  [~ d]
::
++  ship-at
  |=  [key=@t jon=json]
  ^-  (unit @p)
  =/  t=(unit @t)  (text-at key jon)
  ?~  t  ~
  (slaw %p u.t)
::
++  uv-at
  |=  [key=@t jon=json]
  ^-  (unit @uv)
  =/  t=(unit @t)  (text-at key jon)
  ?~  t  ~
  (slaw %uv u.t)
::
++  oid-field
  |=  [key=@t jon=json]
  ^-  (unit oid:git)
  =/  t=(unit @t)  (text-at key jon)
  ?~  t  ~
  ?.  =(40 (met 3 u.t))  ~
  (oid-at:git-protocol [40 u.t] 0)
::
::  one lowercase hex digit's value
::
++  nibble
  |=  c=@
  ^-  (unit @ud)
  ?:  &((gte c '0') (lte c '9'))  `(sub c '0')
  ?:  &((gte c 'a') (lte c 'f'))  `(add 10 (sub c 'a'))
  ~
::
::  .count bytes from the hex the CI tab shows, least significant byte
::  first, as hex-bytes:ci-provenance writes it: exactly that form, or ~
::
++  bytes-of
  |=  [text=@t count=@ud]
  ^-  (unit @)
  ?.  =((mul 2 count) (met 3 text))  ~
  =/  index=@ud  0
  =/  out=@  0
  |-  ^-  (unit @)
  ?:  =(index count)  `out
  =/  high=(unit @ud)  (nibble (cut 3 [(mul 2 index) 1] text))
  =/  low=(unit @ud)  (nibble (cut 3 [+((mul 2 index)) 1] text))
  ?~  high  ~
  ?~  low  ~
  =/  byte=@  (add (mul 16 u.high) u.low)
  $(index +(index), out (add out (lsh [3 index] byte)))
::
++  bytes-at
  |=  [key=@t jon=json count=@ud]
  ^-  (unit @)
  =/  t=(unit @t)  (text-at key jon)
  ?~  t  ~
  (bytes-of u.t count)
::
++  maybe-bytes-at
  |=  [key=@t jon=json count=@ud]
  ^-  (unit (unit @))
  =/  t=(unit (unit @t))  (maybe-text-at key jon)
  ?~  t  ~
  ?~  u.t  [~ ~]
  =/  b=(unit @)  (bytes-of u.u.t count)
  ?~  b  ~
  [~ b]
::
++  candidate-status-of
  |=  t=(unit @t)
  ^-  (unit candidate-status:ci)
  ?+  t  ~
    [~ %passed]  `%passed
    [~ %failed]  `%failed
    [~ %pending]  `%pending
    [~ %skipped]  `%skipped
    [~ %cancelled]  `%cancelled
    [~ %unknown]  `%unknown
  ==
::
++  attempt-status-of
  |=  t=(unit @t)
  ^-  (unit attempt-status:ci)
  ?+  t  ~
    [~ %passed]  `%passed
    [~ %failed]  `%failed
    [~ %skipped]  `%skipped
    [~ %running]  `%running
    [~ %reoffered]  `%reoffered
    [~ %cancelled]  `%cancelled
    [~ %infrastructure-error]  `%infrastructure-error
  ==
::
++  mode-of
  |=  t=(unit @t)
  ^-  (unit mode:ci)
  ?+  t  ~
    [~ %required]  `%required
    [~ %trial]  `%trial
    [~ %manual]  `%manual
    [~ %event]  `%event
    [~ %shadow]  `%shadow
  ==
::
++  network-policy-of
  |=  jon=json
  ^-  (unit network-policy:ci)
  =/  workflow=(unit @t)  (text-at 'workflow' jon)
  =/  job=(unit @t)  (text-at 'job' jon)
  =/  profile=(unit @t)  (text-at 'profile' jon)
  =/  destinations=(unit (list @t))  (texts-at 'destinations' jon)
  =/  environment=(unit (unit @t))  (maybe-text-at 'environment' jon)
  =/  actor=(unit @p)  (ship-at 'actor' jon)
  =/  at=(unit @da)  (date-at 'at' jon)
  ?:  ?|  ?=(~ workflow)  ?=(~ job)  ?=(~ profile)  ?=(~ destinations)
          ?=(~ environment)  ?=(~ actor)  ?=(~ at)
      ==
    ~
  `[u.workflow u.job u.profile u.destinations u.environment u.actor u.at]
::
++  baseline-of
  |=  jon=json
  ^-  (unit [ref=@t =baseline:ci])
  =/  ref=(unit @t)  (text-at 'ref' jon)
  =/  revision=(unit oid:git)  (oid-field 'revision' jon)
  =/  paths=(unit (list @t))  (texts-at 'harnessPaths' jon)
  =/  lock=(unit (unit @))  (maybe-bytes-at 'lock' jon 32)
  =/  promoted=(unit @da)  (date-at 'promoted' jon)
  =/  actor=(unit @p)  (ship-at 'actor' jon)
  =/  reason=(unit @t)  (text-at 'reason' jon)
  =/  generation=(unit @ud)  (number-at 'generation' jon)
  =/  policy-repo=(unit (unit @t))  (maybe-text-at 'policyRepo' jon)
  ?:  ?|  ?=(~ ref)  ?=(~ revision)  ?=(~ paths)  ?=(~ lock)  ?=(~ promoted)
          ?=(~ actor)  ?=(~ reason)  ?=(~ generation)  ?=(~ policy-repo)
      ==
    ~
  =/  b=baseline:ci
    [u.revision u.paths u.lock u.promoted u.actor u.reason u.generation u.policy-repo]
  `[u.ref b]
::
++  repo-policy-of
  |=  jon=json
  ^-  (unit repo-policy:ci)
  =/  repo=(unit @t)  (text-at 'repo' jon)
  =/  protected=(unit (list @t))  (texts-at 'ciProtected' jon)
  =/  untrusted=(unit untrusted-policy:ci)
    =/  t=(unit @t)  (text-at 'untrusted' jon)
    ?+  t  ~
      [~ %approval]  `%approval
      [~ %restricted]  `%restricted
    ==
  =/  sandbox=(unit (unit sandbox-need:ci))
    =/  t=(unit (unit @t))  (maybe-text-at 'sandbox' jon)
    ?+  t  ~
      [~ ~]  [~ ~]
      [~ ~ %vm]  [~ ~ %vm]
      [~ ~ %container]  [~ ~ %container]
    ==
  =/  harness=(unit (unit (list @t)))  (maybe-texts-at 'harnessPaths' jon)
  =/  inputs=(unit (list @t))  (texts-at 'automaticInputs' jon)
  =/  networks=(unit (list network-policy:ci))
    =/  items=(unit (list json))  (array-at 'networkPolicies' jon)
    ?~  items  ~
    =/  parsed=(list (unit network-policy:ci))  (turn u.items network-policy-of)
    ?:  (lien parsed |=(u=(unit network-policy:ci) ?=(~ u)))  ~
    `(murn parsed |=(u=(unit network-policy:ci) u))
  =/  bases=(unit (list [ref=@t =baseline:ci]))
    =/  items=(unit (list json))  (array-at 'baselines' jon)
    ?~  items  ~
    =/  parsed=(list (unit [ref=@t =baseline:ci]))  (turn u.items baseline-of)
    ?:  (lien parsed |=(u=(unit [ref=@t =baseline:ci]) ?=(~ u)))  ~
    `(murn parsed |=(u=(unit [ref=@t =baseline:ci]) u))
  ?:  ?|  ?=(~ repo)  ?=(~ protected)  ?=(~ untrusted)  ?=(~ sandbox)
          ?=(~ harness)  ?=(~ inputs)  ?=(~ networks)  ?=(~ bases)
      ==
    ~
  `[u.repo u.protected u.untrusted u.sandbox u.harness u.inputs u.networks u.bases]
::
::  a lock read back from its restore unit.  the jam decodes and the noun
::  is a lock.  its digest, repository and revision are the ones listed
::  beside it.  a lock keeps the digest it was stored under, so its
::  integrity is the section's sha-256
::
++  lock-of
  |=  jon=json
  ^-  (unit [=lock:ci evidence=(unit @t)])
  =/  digest=(unit @)  (bytes-at 'digest' jon 32)
  =/  repo=(unit @t)  (text-at 'repo' jon)
  =/  revision=(unit oid:git)  (oid-field 'revision' jon)
  =/  evidence=(unit (unit @t))  (maybe-text-at 'evidence' jon)
  =/  noun=(unit @t)  (text-at 'noun' jon)
  ?:  ?|(?=(~ digest) ?=(~ repo) ?=(~ revision) ?=(~ evidence) ?=(~ noun))  ~
  =/  bytes=(unit octs)  (de:base64:mimes:html u.noun)
  ?~  bytes  ~
  =/  cued=(each lock:ci tang)
    %-  mule
    |.
    ;;(lock:ci (cue q.u.bytes))
  ?.  ?=(%& -.cued)  ~
  =/  l=lock:ci  p.cued
  ?.  ?&(=(digest.l u.digest) =(repo.l u.repo) =(revision.l u.revision))  ~
  `[l u.evidence]
::
++  environment-of
  |=  jon=json
  ^-  (unit [repo=@t =environment:ci])
  =/  repo=(unit @t)  (text-at 'repo' jon)
  =/  name=(unit @t)  (text-at 'name' jon)
  =/  description=(unit @t)  (text-at 'description' jon)
  =/  automation=(unit automation:ci)
    =/  t=(unit @t)  (text-at 'automation' jon)
    ?+  t  ~
      [~ %manual]  `%manual
      [~ %automatic]  `%automatic
    ==
  =/  credentials=(unit (list @t))  (texts-at 'credentials' jon)
  =/  created=(unit @da)  (date-at 'created' jon)
  =/  actor=(unit @p)  (ship-at 'actor' jon)
  ?:  ?|  ?=(~ repo)  ?=(~ name)  ?=(~ description)  ?=(~ automation)
          ?=(~ credentials)  ?=(~ created)  ?=(~ actor)
      ==
    ~
  =/  e=environment:ci
    [u.name u.description u.automation (silt u.credentials) u.created u.actor]
  `[u.repo e]
::
++  binding-of
  |=  jon=json
  ^-  (unit [repo=@t =binding:ci])
  =/  repo=(unit @t)  (text-at 'repo' jon)
  =/  role=(unit role:ci)
    =/  t=(unit @t)  (text-at 'role' jon)
    ?+  t  ~
      [~ %ci-policy]  `%ci-policy
      [~ %environment-approver]  `%environment-approver
      [~ %override]  `%override
    ==
  =/  scope=(unit (unit @t))  (maybe-text-at 'scope' jon)
  =/  names=(unit (list @t))  (texts-at 'ships' jon)
  ?:  ?|(?=(~ repo) ?=(~ role) ?=(~ scope) ?=(~ names))  ~
  =/  ships=(list @p)  (murn u.names |=(n=@t (slaw %p n)))
  ?.  =((lent ships) (lent u.names))  ~
  `[u.repo [u.role u.scope (silt ships)]]
::
++  runner-of
  |=  jon=json
  ^-  (unit runner-record:ci)
  =/  id=(unit @uv)  (uv-at 'id' jon)
  =/  labels=(unit (list @t))  (texts-at 'labels' jon)
  =/  repos=(unit (unit (list @t)))  (maybe-texts-at 'repos' jon)
  =/  enrolled=(unit (unit @da))  (maybe-date-at 'enrolled' jon)
  =/  revoked=(unit (unit @da))  (maybe-date-at 'revoked' jon)
  ?:  ?|(?=(~ id) ?=(~ labels) ?=(~ repos) ?=(~ enrolled) ?=(~ revoked))  ~
  `[u.id u.labels u.repos u.enrolled u.revoked]
::
++  credential-of
  |=  jon=json
  ^-  (unit credential-ref:ci)
  =/  repo=(unit @t)  (text-at 'repo' jon)
  =/  name=(unit @t)  (text-at 'name' jon)
  =/  scope=(unit ?(%job %env))
    =/  t=(unit @t)  (text-at 'scope' jon)
    ?+  t  ~
      [~ %job]  `%job
      [~ %env]  `%env
    ==
  =/  envs=(unit (list @t))  (texts-at 'environments' jon)
  =/  created=(unit @da)  (date-at 'created' jon)
  ?:  ?|(?=(~ repo) ?=(~ name) ?=(~ scope) ?=(~ envs) ?=(~ created))  ~
  `[u.repo u.name u.scope u.envs u.created]
::
::  the signing section: a key record, or null when the ship had none
::
++  signing-of
  |=  jon=json
  ^-  (unit (unit key-record:ci))
  =/  v=(unit json)  (field 'key' jon)
  ?~  v  ~
  ?~  u.v  [~ ~]
  =/  k=json  u.v
  =/  pub=(unit @)  (bytes-at 'pub' k 32)
  =/  cert=(unit @)  (bytes-at 'cert' k 64)
  =/  created=(unit @da)  (date-at 'created' k)
  =/  ship=(unit @p)  (ship-at 'ship' k)
  =/  life=(unit (unit @ud))  (maybe-number-at 'life' k)
  =/  ship-key=(unit (unit @))  (maybe-bytes-at 'shipKey' k 32)
  ?:  ?|  ?=(~ pub)  ?=(~ cert)  ?=(~ created)  ?=(~ ship)  ?=(~ life)
          ?=(~ ship-key)
      ==
    ~
  [~ ~ [u.pub u.cert u.created u.ship u.life u.ship-key]]
::
++  handle-of
  |=  jon=json
  ^-  (unit attempt-handle:ci)
  =/  id=(unit @uv)  (uv-at 'id' jon)
  =/  workflow=(unit (unit @t))  (maybe-text-at 'workflow' jon)
  =/  job=(unit (unit @t))  (maybe-text-at 'job' jon)
  =/  status=(unit attempt-status:ci)  (attempt-status-of (text-at 'status' jon))
  =/  log=(unit (unit object-ref:ci))
    =/  v=(unit json)  (field 'log' jon)
    ?~  v  ~
    ?~  u.v  [~ ~]
    =/  key=(unit @t)  (text-at 'key' u.v)
    =/  size=(unit @ud)  (number-at 'size' u.v)
    =/  sha=(unit @t)  (text-at 'sha256' u.v)
    ?:  ?|(?=(~ key) ?=(~ size) ?=(~ sha))  ~
    [~ ~ [u.key u.size u.sha]]
  ?:  ?|(?=(~ id) ?=(~ workflow) ?=(~ job) ?=(~ status) ?=(~ log))  ~
  `[u.id u.workflow u.job u.status u.log]
::
++  run-of
  |=  jon=json
  ^-  (unit run-summary:ci)
  =/  id=(unit @uv)  (uv-at 'id' jon)
  =/  repo=(unit @t)  (text-at 'repo' jon)
  =/  ref=(unit @t)  (text-at 'ref' jon)
  =/  head=(unit oid:git)  (oid-field 'head' jon)
  =/  status=(unit candidate-status:ci)  (candidate-status-of (text-at 'status' jon))
  =/  verdict=(unit (unit @t))  (maybe-text-at 'verdict' jon)
  =/  mode=(unit mode:ci)  (mode-of (text-at 'mode' jon))
  =/  created=(unit @da)  (date-at 'created' jon)
  =/  updated=(unit @da)  (date-at 'updated' jon)
  =/  handles=(unit (list attempt-handle:ci))
    =/  items=(unit (list json))  (array-at 'attempts' jon)
    ?~  items  ~
    =/  parsed=(list (unit attempt-handle:ci))  (turn u.items handle-of)
    ?:  (lien parsed |=(u=(unit attempt-handle:ci) ?=(~ u)))  ~
    `(murn parsed |=(u=(unit attempt-handle:ci) u))
  ?:  ?|  ?=(~ id)  ?=(~ repo)  ?=(~ ref)  ?=(~ head)  ?=(~ status)
          ?=(~ verdict)  ?=(~ mode)  ?=(~ created)  ?=(~ updated)  ?=(~ handles)
      ==
    ~
  `[u.id u.repo u.ref u.head u.status u.verdict u.mode u.created u.updated u.handles]
::
++  approval-of
  |=  jon=json
  ^-  (unit approval:ci)
  =/  id=(unit @uv)  (uv-at 'id' jon)
  =/  repo=(unit @t)  (text-at 'repo' jon)
  =/  incarnation=(unit @uv)  (uv-at 'incarnation' jon)
  =/  candidate=(unit @uv)  (uv-at 'candidate' jon)
  =/  oid=(unit oid:git)  (oid-field 'oid' jon)
  =/  workflow=(unit @t)  (text-at 'workflow' jon)
  =/  job=(unit @t)  (text-at 'job' jon)
  =/  environment=(unit @t)  (text-at 'environment' jon)
  =/  credentials=(unit (list @t))  (texts-at 'credentials' jon)
  =/  baseline=(unit oid:git)  (oid-field 'baseline' jon)
  =/  lock=(unit (unit @))  (maybe-bytes-at 'lock' jon 32)
  =/  generation=(unit @ud)  (number-at 'generation' jon)
  =/  approver=(unit @p)  (ship-at 'approver' jon)
  =/  at=(unit @da)  (date-at 'at' jon)
  =/  expires=(unit @da)  (date-at 'expires' jon)
  =/  consumed=(unit (unit @uv))
    =/  t=(unit (unit @t))  (maybe-text-at 'consumed' jon)
    ?~  t  ~
    ?~  u.t  [~ ~]
    =/  v=(unit @uv)  (slaw %uv u.u.t)
    ?~  v  ~
    [~ v]
  =/  invalidated=(unit (unit @t))  (maybe-text-at 'invalidated' jon)
  ?:  ?|  ?=(~ id)  ?=(~ repo)  ?=(~ incarnation)  ?=(~ candidate)  ?=(~ oid)
          ?=(~ workflow)  ?=(~ job)  ?=(~ environment)  ?=(~ credentials)
          ?=(~ baseline)  ?=(~ lock)  ?=(~ generation)  ?=(~ approver)  ?=(~ at)
          ?=(~ expires)  ?=(~ consumed)  ?=(~ invalidated)
      ==
    ~
  :-  ~
  :*  u.id  u.repo  u.incarnation  u.candidate  u.oid  u.workflow  u.job
      u.environment  (silt u.credentials)  u.baseline  u.lock  u.generation
      u.approver  u.at  u.expires  u.consumed  u.invalidated
  ==
::
++  override-of
  |=  jon=json
  ^-  (unit override:ci)
  =/  id=(unit @uv)  (uv-at 'id' jon)
  =/  repo=(unit @t)  (text-at 'repo' jon)
  =/  ref=(unit @t)  (text-at 'ref' jon)
  =/  incarnation=(unit @uv)  (uv-at 'incarnation' jon)
  =/  candidate=(unit @uv)  (uv-at 'candidate' jon)
  =/  oid=(unit oid:git)  (oid-field 'oid' jon)
  =/  expected=(unit oid:git)  (oid-field 'expected' jon)
  =/  actor=(unit @p)  (ship-at 'actor' jon)
  =/  reason=(unit @t)  (text-at 'reason' jon)
  =/  missing=(unit @t)  (text-at 'missing' jon)
  =/  generation=(unit @ud)  (number-at 'generation' jon)
  =/  at=(unit @da)  (date-at 'at' jon)
  =/  expires=(unit @da)  (date-at 'expires' jon)
  =/  consumed=(unit (unit @da))  (maybe-date-at 'consumed' jon)
  =/  invalidated=(unit (unit @t))  (maybe-text-at 'invalidated' jon)
  ?:  ?|  ?=(~ id)  ?=(~ repo)  ?=(~ ref)  ?=(~ incarnation)  ?=(~ candidate)
          ?=(~ oid)  ?=(~ expected)  ?=(~ actor)  ?=(~ reason)  ?=(~ missing)
          ?=(~ generation)  ?=(~ at)  ?=(~ expires)  ?=(~ consumed)
          ?=(~ invalidated)
      ==
    ~
  :-  ~
  :*  u.id  u.repo  u.ref  u.incarnation  u.candidate  u.oid  u.expected
      u.actor  u.reason  u.missing  u.generation  u.at  u.expires  u.consumed
      u.invalidated
  ==
::
++  authorization-of
  |=  jon=json
  ^-  (unit authorization:ci)
  =/  kind=(unit @t)  (text-at 'kind' jon)
  ?:  =(`'approval' kind)
    =/  a=(unit approval:ci)  (approval-of jon)
    ?~  a  ~
    `[%approval u.a]
  ?:  =(`'override' kind)
    =/  o=(unit override:ci)  (override-of jon)
    ?~  o  ~
    `[%override u.o]
  ~
::
++  audit-entry-of
  |=  jon=json
  ^-  (unit audit-entry:ci)
  =/  at=(unit @da)  (date-at 'at' jon)
  =/  actor=(unit @p)  (ship-at 'actor' jon)
  =/  kind=(unit @t)  (text-at 'kind' jon)
  =/  repo=(unit @t)  (text-at 'repo' jon)
  =/  detail=(unit @t)  (text-at 'detail' jon)
  ?:  ?|(?=(~ at) ?=(~ actor) ?=(~ kind) ?=(~ repo) ?=(~ detail))  ~
  `[u.at u.actor u.kind u.repo u.detail]
::
::  ---- the import ----
::
::  a refusal's words: the file and what is wrong with it
::
++  malformed
  |=  [file=@t what=@t index=@ud]
  ^-  @t
  (rap 3 ~['malformed checkpoint: ' file ' has a malformed ' what ' (number ' (crip (a-co:co +(index))) ')'])
::
::  the index of the first ~ in a list of units, or ~ when there is none
::
++  first-gap
  |=  units=(list (unit *))
  ^-  (unit @ud)
  =/  index=@ud  0
  |-  ^-  (unit @ud)
  ?~  units  ~
  ?~  i.units  `index
  $(units t.units, index +(index))
::
++  manifest-of
  |=  jon=json
  ^-  (each checkpoint-manifest:ci @t)
  =/  format=(unit @t)  (text-at 'format' jon)
  ?.  =(`format-name format)
    [%| 'not an urgit-ci checkpoint: manifest.json names no urgit-ci checkpoint format']
  =/  version=(unit @ud)  (number-at 'version' jon)
  ?~  version  [%| 'malformed checkpoint: manifest.json has no format version']
  ?.  =(format-version u.version)
    :-  %|
    %+  rap  3
    :~  'unsupported checkpoint: format version '  (crip (a-co:co u.version))
        ', and this ship reads version '  (crip (a-co:co format-version))
    ==
  =/  id=(unit @t)  (text-at 'id' jon)
  =/  ship=(unit @p)  (ship-at 'ship' jon)
  =/  desk=(unit @t)  (text-at 'desk' jon)
  =/  revision=(unit @ud)  (number-at 'revision' jon)
  =/  at=(unit @da)  (date-at 'created' jon)
  =/  cause=(unit @t)  (text-at 'cause' jon)
  =/  listed=(unit (list json))  (array-at 'sections' jon)
  ?:  ?|  ?=(~ id)  ?=(~ ship)  ?=(~ desk)  ?=(~ revision)  ?=(~ at)
          ?=(~ cause)  ?=(~ listed)
      ==
    [%| 'malformed checkpoint: manifest.json lacks its id, ship, desk, revision, time, cause or sections']
  =/  parsed=(list (unit checkpoint-section:ci))  (turn u.listed section-of)
  =/  gap=(unit @ud)  (first-gap parsed)
  ?^  gap  [%| (malformed manifest-file 'section' u.gap)]
  =/  records=(list checkpoint-section:ci)
    (murn parsed |=(u=(unit checkpoint-section:ci) u))
  =/  have=(list [@t @t])  (turn records |=(r=checkpoint-section:ci [name.r file.r]))
  =/  want=(list [@t @t])  (turn sections |=([name=@t file=@t *] [name file]))
  ?.  =(have want)
    [%| 'malformed checkpoint: manifest.json does not list the eight sections of version 1 in order']
  [%& [u.id u.ship u.desk u.revision u.at u.cause records]]
::
++  section-of
  |=  jon=json
  ^-  (unit checkpoint-section:ci)
  =/  name=(unit @t)  (text-at 'name' jon)
  =/  file=(unit @t)  (text-at 'file' jon)
  =/  count=(unit @ud)  (number-at 'count' jon)
  =/  sha=(unit @t)  (text-at 'sha256' jon)
  =/  bytes=(unit @ud)  (number-at 'bytes' jon)
  ?:  ?|(?=(~ name) ?=(~ file) ?=(~ count) ?=(~ sha) ?=(~ bytes))  ~
  `[u.name u.file u.count u.sha u.bytes]
::
::  one section's bytes as its manifest lists them, parsed: the length,
::  then the sha-256, then the JSON
::
++  section-body
  |=  [files=(map @t octs) r=checkpoint-section:ci]
  ^-  (each json @t)
  =/  data=(unit octs)  (~(get by files) file.r)
  ?~  data  [%| (rap 3 ~['incomplete checkpoint: ' file.r ' is missing'])]
  ?.  =(bytes.r p.u.data)
    :-  %|
    %+  rap  3
    :~  'corrupt checkpoint: '  file.r  ' is '  (crip (a-co:co p.u.data))
        ' bytes, and the manifest lists '  (crip (a-co:co bytes.r))
        ': it is truncated or altered'
    ==
  ?.  =(sha256.r (digest-of u.data))
    [%| (rap 3 ~['corrupt checkpoint: the sha-256 of ' file.r ' is not the one its manifest lists'])]
  =/  jon=(unit json)  (de:json:html q.u.data)
  ?~  jon  [%| (rap 3 ~['malformed checkpoint: ' file.r ' is not JSON'])]
  [%& u.jon]
::
::  a section's count against its manifest
::
++  count-problem
  |=  [r=checkpoint-section:ci found=@ud]
  ^-  (unit @t)
  ?:  =(count.r found)  ~
  :-  ~
  %+  rap  3
  :~  'incomplete checkpoint: '  file.r  ' holds '  (crip (a-co:co found))
      ' records, and the manifest lists '  (crip (a-co:co count.r))
  ==
::
::  a checkpoint read back from its files, by file name, checked whole:
::  the manifest, then every section's length, digest, JSON, records and
::  count.  any failure refuses the whole checkpoint with the reason
::
++  import
  |=  files=(map @t octs)
  ^-  (each [manifest=checkpoint-manifest:ci content=checkpoint-content:ci] @t)
  =/  raw=(unit octs)  (~(get by files) manifest-file)
  ?~  raw  [%| 'incomplete checkpoint: manifest.json is missing']
  =/  top=(unit json)  (de:json:html q.u.raw)
  ?~  top  [%| 'malformed checkpoint: manifest.json is not JSON']
  =/  manifest=(each checkpoint-manifest:ci @t)  (manifest-of u.top)
  ?:  ?=(%| -.manifest)  [%| p.manifest]
  =/  m=checkpoint-manifest:ci  p.manifest
  =/  bodies=(list (each json @t))
    (turn sections.m |=(r=checkpoint-section:ci (section-body files r)))
  =/  bad=(list @t)
    (murn bodies |=(b=(each json @t) ?:(?=(%| -.b) `p.b ~)))
  ?^  bad  [%| i.bad]
  =/  jons=(list json)
    (murn bodies |=(b=(each json @t) ?:(?=(%& -.b) `p.b ~)))
  =/  content=(each checkpoint-content:ci @t)  (content-of sections.m jons)
  ?:  ?=(%| -.content)  [%| p.content]
  [%& m p.content]
::
::  the eight sections, decoded and counted
::
++  content-of
  |=  [listed=(list checkpoint-section:ci) jons=(list json)]
  ^-  (each checkpoint-content:ci @t)
  ?.  ?&(=(8 (lent listed)) =(8 (lent jons)))
    [%| 'malformed checkpoint: the sections are not the eight of version 1']
  =/  at
    |=  i=@ud
    ^-  [r=checkpoint-section:ci jon=json]
    [(snag i listed) (snag i jons)]
  ::  policy
  =/  p  (at 0)
  =/  policy-items=(unit (list json))  (array-at 'repositories' jon.p)
  ?~  policy-items  [%| (malformed file.r.p 'body' 0)]
  =/  policy-parsed=(list (unit repo-policy:ci))  (turn u.policy-items repo-policy-of)
  =/  policy-gap=(unit @ud)  (first-gap policy-parsed)
  ?^  policy-gap  [%| (malformed file.r.p 'repository' u.policy-gap)]
  =/  policy=(list repo-policy:ci)
    (murn policy-parsed |=(u=(unit repo-policy:ci) u))
  =/  policy-count=(unit @t)  (count-problem r.p (lent policy))
  ?^  policy-count  [%| u.policy-count]
  ::  locks
  =/  l  (at 1)
  =/  lock-items=(unit (list json))  (array-at 'locks' jon.l)
  ?~  lock-items  [%| (malformed file.r.l 'body' 0)]
  =/  lock-parsed=(list (unit [=lock:ci evidence=(unit @t)]))  (turn u.lock-items lock-of)
  =/  lock-gap=(unit @ud)  (first-gap lock-parsed)
  ?^  lock-gap  [%| (malformed file.r.l 'lock' u.lock-gap)]
  =/  locks=(list [=lock:ci evidence=(unit @t)])
    (murn lock-parsed |=(u=(unit [=lock:ci evidence=(unit @t)]) u))
  =/  lock-count=(unit @t)  (count-problem r.l (lent locks))
  ?^  lock-count  [%| u.lock-count]
  ::  access
  =/  a  (at 2)
  =/  env-items=(unit (list json))  (array-at 'environments' jon.a)
  =/  binding-items=(unit (list json))  (array-at 'bindings' jon.a)
  ?~  env-items  [%| (malformed file.r.a 'body' 0)]
  ?~  binding-items  [%| (malformed file.r.a 'body' 0)]
  =/  env-parsed=(list (unit [repo=@t =environment:ci]))  (turn u.env-items environment-of)
  =/  env-gap=(unit @ud)  (first-gap env-parsed)
  ?^  env-gap  [%| (malformed file.r.a 'environment' u.env-gap)]
  =/  binding-parsed=(list (unit [repo=@t =binding:ci]))  (turn u.binding-items binding-of)
  =/  binding-gap=(unit @ud)  (first-gap binding-parsed)
  ?^  binding-gap  [%| (malformed file.r.a 'role binding' u.binding-gap)]
  =/  envs=(list [repo=@t =environment:ci])
    (murn env-parsed |=(u=(unit [repo=@t =environment:ci]) u))
  =/  bindings=(list [repo=@t =binding:ci])
    (murn binding-parsed |=(u=(unit [repo=@t =binding:ci]) u))
  =/  access-count=(unit @t)  (count-problem r.a (add (lent envs) (lent bindings)))
  ?^  access-count  [%| u.access-count]
  ::  runners
  =/  n  (at 3)
  =/  runner-items=(unit (list json))  (array-at 'runners' jon.n)
  ?~  runner-items  [%| (malformed file.r.n 'body' 0)]
  =/  runner-parsed=(list (unit runner-record:ci))  (turn u.runner-items runner-of)
  =/  runner-gap=(unit @ud)  (first-gap runner-parsed)
  ?^  runner-gap  [%| (malformed file.r.n 'runner' u.runner-gap)]
  =/  runners=(list runner-record:ci)
    (murn runner-parsed |=(u=(unit runner-record:ci) u))
  =/  runner-count=(unit @t)  (count-problem r.n (lent runners))
  ?^  runner-count  [%| u.runner-count]
  ::  credentials
  =/  c  (at 4)
  =/  cred-items=(unit (list json))  (array-at 'credentials' jon.c)
  ?~  cred-items  [%| (malformed file.r.c 'body' 0)]
  =/  cred-parsed=(list (unit credential-ref:ci))  (turn u.cred-items credential-of)
  =/  cred-gap=(unit @ud)  (first-gap cred-parsed)
  ?^  cred-gap  [%| (malformed file.r.c 'credential reference' u.cred-gap)]
  =/  creds=(list credential-ref:ci)
    (murn cred-parsed |=(u=(unit credential-ref:ci) u))
  =/  cred-count=(unit @t)  (count-problem r.c (lent creds))
  ?^  cred-count  [%| u.cred-count]
  ::  signing
  =/  g  (at 5)
  =/  key=(unit (unit key-record:ci))  (signing-of jon.g)
  ?~  key  [%| (malformed file.r.g 'key' 0)]
  =/  key-count=(unit @t)  (count-problem r.g ?~(u.key 0 1))
  ?^  key-count  [%| u.key-count]
  ::  runs
  =/  u  (at 6)
  =/  run-items=(unit (list json))  (array-at 'runs' jon.u)
  ?~  run-items  [%| (malformed file.r.u 'body' 0)]
  =/  run-parsed=(list (unit run-summary:ci))  (turn u.run-items run-of)
  =/  run-gap=(unit @ud)  (first-gap run-parsed)
  ?^  run-gap  [%| (malformed file.r.u 'run' u.run-gap)]
  =/  runs=(list run-summary:ci)
    (murn run-parsed |=(u=(unit run-summary:ci) u))
  =/  run-count=(unit @t)  (count-problem r.u (lent runs))
  ?^  run-count  [%| u.run-count]
  ::  audit
  =/  t  (at 7)
  =/  auth-items=(unit (list json))  (array-at 'authorizations' jon.t)
  =/  entry-items=(unit (list json))  (array-at 'audit' jon.t)
  ?~  auth-items  [%| (malformed file.r.t 'body' 0)]
  ?~  entry-items  [%| (malformed file.r.t 'body' 0)]
  =/  auth-parsed=(list (unit authorization:ci))  (turn u.auth-items authorization-of)
  =/  auth-gap=(unit @ud)  (first-gap auth-parsed)
  ?^  auth-gap  [%| (malformed file.r.t 'approval or override' u.auth-gap)]
  =/  entry-parsed=(list (unit audit-entry:ci))  (turn u.entry-items audit-entry-of)
  =/  entry-gap=(unit @ud)  (first-gap entry-parsed)
  ?^  entry-gap  [%| (malformed file.r.t 'audit entry' u.entry-gap)]
  =/  auths=(list authorization:ci)
    (murn auth-parsed |=(u=(unit authorization:ci) u))
  =/  entries=(list audit-entry:ci)
    (murn entry-parsed |=(u=(unit audit-entry:ci) u))
  =/  audit-count=(unit @t)  (count-problem r.t (add (lent auths) (lent entries)))
  ?^  audit-count  [%| u.audit-count]
  [%& policy locks envs bindings runners creds u.key runs auths entries]
::
::  ---- the diff ----
::
::  one line of what an apply would change against the ship's current
::  configuration.  it names its section and its repository, '' for the
::  whole ship.  its kind says whether it adds, removes or changes
::  configuration, or brings back inert history
::
+$  change  [section=@t repo=@t kind=?(%add %remove %change %history) text=@t]
::
++  join-texts
  |=  [items=(list @t) sep=@t]
  ^-  @t
  ?~  items  ''
  =/  out=@t  i.items
  =/  rest=(list @t)  t.items
  |-  ^-  @t
  ?~  rest  out
  $(rest t.rest, out (rap 3 ~[out sep i.rest]))
::
++  shown
  |=  items=(list @t)
  ^-  @t
  ?~  items  'none'
  (join-texts items ', ')
::
::  the texts of .new that .old lacks
::
++  missing-from
  |=  [old=(list @t) new=(list @t)]
  ^-  (list @t)
  =/  had=(set @t)  (silt old)
  (skip new |=(t=@t (~(has in had) t)))
::
++  short-oid
  |=  o=oid:git
  ^-  @t
  (end [3 12] (oid-text:git-codec o))
::
++  policy-changes
  |=  [old=(unit repo-policy:ci) new=repo-policy:ci]
  ^-  (list change)
  =/  was=repo-policy:ci  (fall old [repo.new ~ %approval ~ ~ ~ ~ ~])
  =/  repo=@t  repo.new
  =/  added=(list @t)  (missing-from protected.was protected.new)
  =/  dropped=(list @t)  (missing-from protected.new protected.was)
  =/  protect-lines=(list change)
    %+  weld
      (turn added |=(r=@t `change`['policy' repo %add (rap 3 ~['CI required on ' r])]))
    (turn dropped |=(r=@t `change`['policy' repo %remove (rap 3 ~['CI no longer required on ' r])]))
  =/  untrusted-lines=(list change)
    ?:  =(untrusted.was untrusted.new)  ~
    ~[['policy' repo %change (rap 3 ~['untrusted revisions: ' untrusted.was ' becomes ' untrusted.new])]]
  =/  sandbox-text
    |=  s=(unit sandbox-need:ci)
    ^-  @t
    ?~(s 'the default' u.s)
  =/  sandbox-lines=(list change)
    ?:  =(sandbox.was sandbox.new)  ~
    ~[['policy' repo %change (rap 3 ~['sandbox requirement: ' (sandbox-text sandbox.was) ' becomes ' (sandbox-text sandbox.new)])]]
  =/  harness-text
    |=  h=(unit (list @t))
    ^-  @t
    ?~(h 'the default' (shown u.h))
  =/  harness-lines=(list change)
    ?:  =(harness-paths.was harness-paths.new)  ~
    ~[['policy' repo %change (rap 3 ~['harness paths: ' (harness-text harness-paths.was) ' becomes ' (harness-text harness-paths.new)])]]
  =/  input-lines=(list change)
    ?:  =(automatic-inputs.was automatic-inputs.new)  ~
    ~[['policy' repo %change (rap 3 ~['automatic inputs: ' (shown automatic-inputs.was) ' becomes ' (shown automatic-inputs.new)])]]
  =/  net-key
    |=  n=network-policy:ci
    ^-  @t
    (rap 3 ~[workflow.n '/' job.n])
  =/  old-nets=(map @t network-policy:ci)
    (malt (turn network-policies.was |=(n=network-policy:ci [(net-key n) n])))
  =/  new-nets=(map @t network-policy:ci)
    (malt (turn network-policies.new |=(n=network-policy:ci [(net-key n) n])))
  =/  net-lines=(list change)
    %+  weld
      %+  murn  ~(tap by new-nets)
      |=  [k=@t n=network-policy:ci]
      ^-  (unit change)
      =/  o=(unit network-policy:ci)  (~(get by old-nets) k)
      =/  text=@t  (rap 3 ~['network policy ' k ': ' profile.n ' to ' (shown destinations.n)])
      ?~  o  `['policy' repo %add text]
      ?:  ?&(=(profile.u.o profile.n) =(destinations.u.o destinations.n) =(environment.u.o environment.n))  ~
      `['policy' repo %change text]
    %+  murn  ~(tap by old-nets)
    |=  [k=@t n=network-policy:ci]
    ^-  (unit change)
    ?:  (~(has by new-nets) k)  ~
    `['policy' repo %remove (rap 3 ~['network policy ' k ' cleared'])]
  =/  old-bases=(map @t baseline:ci)  (malt baselines.was)
  =/  new-bases=(map @t baseline:ci)  (malt baselines.new)
  =/  base-lines=(list change)
    %+  weld
      %+  murn  ~(tap by new-bases)
      |=  [ref=@t b=baseline:ci]
      ^-  (unit change)
      =/  o=(unit baseline:ci)  (~(get by old-bases) ref)
      =/  text=@t  (rap 3 ~['baseline of ' ref ': revision ' (short-oid revision.b)])
      ?~  o  `['policy' repo %add text]
      ?:  ?&(=(revision.u.o revision.b) =(lock.u.o lock.b) =(harness-paths.u.o harness-paths.b))  ~
      `['policy' repo %change text]
    %+  murn  ~(tap by old-bases)
    |=  [ref=@t b=baseline:ci]
    ^-  (unit change)
    ?:  (~(has by new-bases) ref)  ~
    `['policy' repo %remove (rap 3 ~['baseline of ' ref ' revoked'])]
  ;:  weld
    protect-lines
    untrusted-lines
    sandbox-lines
    harness-lines
    input-lines
    net-lines
    base-lines
  ==
::
::  the role grants an apply adds and removes, ship by ship: a grant is
::  authority, so each one is its own line
::
++  grant-text
  |=  [=role:ci scope=(unit @t) who=@p]
  ^-  @t
  =/  where=@t  ?~(scope '' (rap 3 ~[' (' u.scope ')']))
  (rap 3 ~[role where ' for ' (scot %p who)])
::
++  grants-of
  |=  bindings=(list binding:ci)
  ^-  (set [=role:ci scope=(unit @t) who=@p])
  =/  nested=(list (list [=role:ci scope=(unit @t) who=@p]))
    %+  turn  bindings
    |=  b=binding:ci
    ^-  (list [=role:ci scope=(unit @t) who=@p])
    (turn ~(tap in ships.b) |=(who=@p [role.b scope.b who]))
  =/  flat=(list [=role:ci scope=(unit @t) who=@p])  (zing nested)
  (silt flat)
::
++  access-changes
  |=  [s=state-0:ci content=checkpoint-content:ci repos=(list @t)]
  ^-  (list change)
  =/  nested=(list (list change))
    %+  turn  repos
    |=  repo=@t
    ^-  (list change)
    =/  old-grants  (grants-of (~(gut by roles.s) repo ~))
    =/  mine=(list binding:ci)
      (murn bindings.content |=([r=@t b=binding:ci] ?.(=(r repo) ~ `b)))
    =/  new-grants  (grants-of mine)
    =/  granted=(list change)
      %+  murn  ~(tap in new-grants)
      |=  g=[=role:ci scope=(unit @t) who=@p]
      ^-  (unit change)
      ?:  (~(has in old-grants) g)  ~
      `['access' repo %add (rap 3 ~['grants ' (grant-text g)])]
    =/  revoked=(list change)
      %+  murn  ~(tap in old-grants)
      |=  g=[=role:ci scope=(unit @t) who=@p]
      ^-  (unit change)
      ?:  (~(has in new-grants) g)  ~
      `['access' repo %remove (rap 3 ~['removes ' (grant-text g)])]
    =/  old-envs=(map @t environment:ci)
      %-  malt
      %+  murn  ~(tap by environments.s)
      |=([[r=@t name=@t] e=environment:ci] ?.(=(r repo) ~ `[name e]))
    =/  new-envs=(map @t environment:ci)
      %-  malt
      %+  murn  environments.content
      |=([r=@t e=environment:ci] ?.(=(r repo) ~ `[name.e e]))
    =/  env-text
      |=  e=environment:ci
      ^-  @t
      (rap 3 ~['environment ' name.e ' (' automation.e '): ' (shown (sort ~(tap in credentials.e) aor))])
    =/  env-added=(list change)
      %+  murn  ~(tap by new-envs)
      |=  [name=@t e=environment:ci]
      ^-  (unit change)
      =/  o=(unit environment:ci)  (~(get by old-envs) name)
      ?~  o  `['access' repo %add (env-text e)]
      ?:  ?&(=(automation.u.o automation.e) =(credentials.u.o credentials.e))  ~
      `['access' repo %change (env-text e)]
    =/  env-dropped=(list change)
      %+  murn  ~(tap by old-envs)
      |=  [name=@t e=environment:ci]
      ^-  (unit change)
      ?:  (~(has by new-envs) name)  ~
      `['access' repo %remove (rap 3 ~['environment ' name ' deleted'])]
    :(weld granted revoked env-added env-dropped)
  (zing nested)
::
::  what comes back as history, never as authority
::
++  history-changes
  |=  [s=state-0:ci content=checkpoint-content:ci]
  ^-  (list change)
  =/  creds=(list change)
    %+  turn  credentials.content
    |=  r=credential-ref:ci
    ^-  change
    ?:  (~(has by credentials.s) [repo.r name.r])
      ['credentials' repo.r %history (rap 3 ~[name.r ': a value is stored on this ship and is kept'])]
    ['credentials' repo.r %history (rap 3 ~[name.r ': comes back with no value and needs re-entry'])]
  =/  runners=(list change)
    %+  turn  runners.content
    |=  r=runner-record:ci
    ^-  change
    ['runners' '' %history (rap 3 ~['runner ' (scot %uv id.r) ' comes back as a record: it must re-enroll'])]
  =/  key=(list change)
    ?~  key.content  ~
    =/  mine=@t  ?~(signing.s 'none' (hex-bytes:ci-provenance pub.u.signing.s 32))
    :~  :*  'signing'  ''  %history
            %+  rap  3
            :~  'the checkpoint key '  (hex-bytes:ci-provenance pub.u.key.content 32)
                ' becomes history: this ship keeps its own key '  mine
            ==
        ==
    ==
  =/  counts=(list change)
    :~  :*  'runs'  ''  %history
            (rap 3 ~[(crip (a-co:co (lent runs.content))) ' run summaries come back as history: none can land anything'])
        ==
        :*  'audit'  ''  %history
            %+  rap  3
            :~  (crip (a-co:co (lent authorizations.content)))
                ' approval and override records come back inert, and '
                (crip (a-co:co (lent audit.content)))
                ' audit entries as history'
            ==
        ==
    ==
  :(weld creds runners key counts)
::
::  the repositories an apply touches
::
++  content-repos
  |=  content=checkpoint-content:ci
  ^-  (list @t)
  =/  named=(list @t)
    ;:  weld
      (turn policy.content |=(p=repo-policy:ci repo.p))
      (turn environments.content |=([r=@t *] r))
      (turn bindings.content |=([r=@t *] r))
    ==
  (sort ~(tap in (silt named)) aor)
::
++  diff
  |=  [s=state-0:ci content=checkpoint-content:ci]
  ^-  (list change)
  =/  current=(map @t repo-policy:ci)
    (malt (turn (policy-of s ~) |=(p=repo-policy:ci [repo.p p])))
  =/  policy-lines=(list change)
    %-  zing
    ^-  (list (list change))
    %+  turn  policy.content
    |=  p=repo-policy:ci
    (policy-changes (~(get by current) repo.p) p)
  =/  repos=(list @t)  (content-repos content)
  :(weld policy-lines (access-changes s content repos) (history-changes s content))
::
::  ---- pause, import and apply: the refusals ----
::
++  paused
  |=  s=state-0:ci
  ^-  ?
  ?=(^ paused.recovery.s)
::
::  why a new run, assignment, schedule admission or landing is refused
::
++  paused-refusal
  ^-  @t
  'CI is paused for a restore: no run is admitted, offered or landed until it resumes'
::
++  pause-refusal
  |=  s=state-0:ci
  ^-  (unit @t)
  ?^  paused.recovery.s  `'CI is already paused'
  ~
::
++  resume-refusal
  |=  s=state-0:ci
  ^-  (unit @t)
  ?~  paused.recovery.s  `'CI is not paused'
  ~
::
++  import-refusal
  |=  s=state-0:ci
  ^-  (unit @t)
  ?~  paused.recovery.s
    `'pause CI before importing a checkpoint: an import into a running CI is refused'
  ~
::
::  the attempts still running: an apply waits for none
::
++  running-attempts
  |=  s=state-0:ci
  ^-  @ud
  (lent (skim ~(val by attempts.s) |=(a=attempt:ci =(%running status.a))))
::
++  apply-refusal
  |=  [s=state-0:ci id=@t]
  ^-  (unit @t)
  ?~  paused.recovery.s
    `'pause CI before applying a checkpoint: an apply to a running CI is refused'
  ?~  staged.recovery.s  `'no checkpoint is staged: import one first'
  =/  staged-id=@t  id.manifest.u.staged.recovery.s
  ?.  =(id staged-id)
    `(rap 3 ~['the staged checkpoint is ' staged-id ', not ' id ': review the staged one, then apply it'])
  =/  running=@ud  (running-attempts s)
  ?.  =(0 running)
    :-  ~
    %+  rap  3
    :~  (crip (a-co:co running))
        ' attempts are still running: wait for them to finish or cancel them, then apply'
    ==
  ~
::
::  ---- the apply ----
::
::  what an apply reads from the ship first.  it is each CI-protected ref
::  of the checkpoint that has a tip here.  it is each baseline revision
::  readable in its repository here
::
+$  presence
  $:  tips=(set [repo=@t ref=@t])
      revisions=(set [repo=@t revision=oid:git])
  ==
::
::  the CI-protected refs and baseline revisions an apply asks about
::
++  wanted-tips
  |=  content=checkpoint-content:ci
  ^-  (list [repo=@t ref=@t])
  =/  nested=(list (list [repo=@t ref=@t]))
    %+  turn  policy.content
    |=  p=repo-policy:ci
    (turn protected.p |=(ref=@t [repo.p ref]))
  (zing nested)
::
++  wanted-revisions
  |=  content=checkpoint-content:ci
  ^-  (list [repo=@t revision=oid:git])
  =/  nested=(list (list [repo=@t revision=oid:git]))
    %+  turn  policy.content
    |=  p=repo-policy:ci
    %+  turn  baselines.p
    |=([ref=@t b=baseline:ci] [(fall policy-repo.b repo.p) revision.b])
  (zing nested)
::
::  bounded history, newest first, one entry per key
::
++  merge-runners
  |=  [old=(list runner-record:ci) new=(list runner-record:ci)]
  ^-  (list runner-record:ci)
  =/  seen=(set @uv)  (silt (turn new |=(r=runner-record:ci id.r)))
  =/  kept=(list runner-record:ci)  (skip old |=(r=runner-record:ci (~(has in seen) id.r)))
  (scag max-history (weld new kept))
::
++  merge-runs
  |=  [old=(list run-summary:ci) new=(list run-summary:ci)]
  ^-  (list run-summary:ci)
  =/  seen=(set @uv)  (silt (turn new |=(r=run-summary:ci id.r)))
  =/  kept=(list run-summary:ci)  (skip old |=(r=run-summary:ci (~(has in seen) id.r)))
  (scag max-history (weld new kept))
::
++  merge-authorizations
  |=  [old=(list authorization:ci) new=(list authorization:ci)]
  ^-  (list authorization:ci)
  =/  seen=(set @uv)  (silt (turn new auth-id))
  =/  kept=(list authorization:ci)  (skip old |=(a=authorization:ci (~(has in seen) (auth-id a))))
  (scag max-history (weld new kept))
::
++  merge-audit
  |=  [old=(list audit-entry:ci) new=(list audit-entry:ci)]
  ^-  (list audit-entry:ci)
  =/  seen=(set audit-entry:ci)  (silt new)
  =/  kept=(list audit-entry:ci)  (skip old |=(e=audit-entry:ci (~(has in seen) e)))
  (scag max-history (weld new kept))
::
::  credential references that need re-entry: those the checkpoint names
::  that hold no value on this ship, one per repository and name
::
++  merge-credentials
  |=  [s=state-0:ci new=(list credential-ref:ci)]
  ^-  (list credential-ref:ci)
  =/  wanted=(list credential-ref:ci)
    (skip new |=(r=credential-ref:ci (~(has by credentials.s) [repo.r name.r])))
  =/  seen=(set [@t @t])  (silt (turn wanted |=(r=credential-ref:ci [repo.r name.r])))
  =/  kept=(list credential-ref:ci)
    %+  skip  credentials.history.recovery.s
    |=(r=credential-ref:ci (~(has in seen) [repo.r name.r]))
  (weld wanted kept)
::
::  an open run of a repository the apply restores: cancelled with the
::  reason, its whole run's cancellation recorded as the operator's.  no
::  attempt is running when an apply runs
::
++  cancel-open
  |=  [c=candidate:ci why=@t actor=@p now=@da]
  ^-  candidate:ci
  =/  started=?  ?=(^ attempts.c)
  %=  c
    status  %cancelled
    verdict-reason  `why
    updated  now
    cancelled  (~(put by cancelled.c) '' [now started [%operator actor] why])
  ==
::
::  one repository's configuration replaced by the checkpoint's: policy,
::  baselines, environments and role bindings.  its generation moves, its
::  unused approvals and overrides are invalidated, and its open runs are
::  cancelled.  a CI-protected ref with no tip here and a baseline whose
::  revision or lock is missing here are skipped, with why
::
+$  applied  [s=state-0:ci skipped=(list @t) cancelled=(list candidate-id:ci)]
::
++  apply-repo
  |=  $:  acc=applied
          repo=@t
          content=checkpoint-content:ci
          =presence
          id=@t
          actor=@p
          now=@da
          eny=@uvJ
      ==
  ^-  applied
  =/  s=state-0:ci  s.acc
  =/  p=repo-policy:ci
    =/  hits=(list repo-policy:ci)  (skim policy.content |=(q=repo-policy:ci =(repo repo.q)))
    ?^  hits  i.hits
    [repo ~ %approval ~ ~ ~ ~ ~]
  =/  why=@t  (rap 3 ~['the CI configuration was restored from checkpoint ' id])
  ::  the incarnation, minted the way %urgit-ci mints it, and the generation
  =?  incarnations.s  !(~(has by incarnations.s) repo)
    (~(put by incarnations.s) repo (sham [%ci-incarnation repo now eny]))
  =/  next=@ud  +((~(gut by generations.s) repo 0))
  =.  generations.s  (~(put by generations.s) repo next)
  =/  reason=@t  (rap 3 ~['policy generation ' (crip (a-co:co next)) ': ' why])
  =.  approvals.s
    %-  ~(run by approvals.s)
    |=  a=approval:ci
    ?.  &(=(repo repo.a) ?=(~ consumed.a) ?=(~ invalidated.a))  a
    a(invalidated `reason)
  =.  overrides.s
    %-  ~(run by overrides.s)
    |=  o=override:ci
    ?.  &(=(repo repo.o) ?=(~ consumed.o) ?=(~ invalidated.o))  o
    o(invalidated `reason)
  ::  open runs of the repository
  =/  open=(list candidate:ci)
    %+  skim  ~(val by candidates.s)
    |=  c=candidate:ci
    ?&  =(repo repo.c)
        =(%pending status.c)
        !=('refs/ci/resolve' ref.c)
    ==
  =/  stop=@t  (rap 3 ~['cancelled: ' why '. Push or dispatch again to run under it'])
  =.  candidates.s
    %+  roll  open
    |=  [c=candidate:ci m=_candidates.s]
    (~(put by m) id.c (cancel-open c stop actor now))
  ::  CI-protected refs: those with a tip here
  =/  kept-refs=(list @t)
    (skim protected.p |=(ref=@t (~(has in tips.presence) [repo ref])))
  =/  lost-refs=(list @t)
    (skip protected.p |=(ref=@t (~(has in tips.presence) [repo ref])))
  =.  ci-protected.s
    =/  others=(list [repo=@t ref=@t])
      (skip ~(tap in ci-protected.s) |=([r=@t *] =(r repo)))
    (silt (weld others (turn kept-refs |=(ref=@t [repo ref]))))
  =/  ref-skips=(list @t)
    %+  turn  lost-refs
    |=  ref=@t
    (rap 3 ~[repo ': CI was not required on ' ref ': it has no tip on this ship, so push the repository first, then require CI'])
  ::  the plain policy fields
  =.  policies.s  (~(put by policies.s) repo untrusted.p)
  =.  sandbox-requirements.s
    ?~  sandbox.p  (~(del by sandbox-requirements.s) repo)
    (~(put by sandbox-requirements.s) repo u.sandbox.p)
  =.  harness-paths.s
    ?~  harness-paths.p  (~(del by harness-paths.s) repo)
    (~(put by harness-paths.s) repo u.harness-paths.p)
  =.  automatic-inputs.s
    ?~  automatic-inputs.p  (~(del by automatic-inputs.s) repo)
    (~(put by automatic-inputs.s) repo automatic-inputs.p)
  =.  network-policies.s
    ?~  network-policies.p  (~(del by network-policies.s) repo)
    (~(put by network-policies.s) repo network-policies.p)
  ::  baselines: those whose revision is readable and whose lock is here
  =/  usable
    |=  [ref=@t b=baseline:ci]
    ^-  (unit @t)
    =/  home=@t  (fall policy-repo.b repo)
    ?.  (~(has in revisions.presence) [home revision.b])
      `(rap 3 ~[repo ': the baseline of ' ref ' was not restored: revision ' (oid-text:git-codec revision.b) ' is not readable in ' home ' here, so push it first'])
    ?~  lock.b  ~
    ?:  (~(has by locks.s) u.lock.b)  ~
    `(rap 3 ~[repo ': the baseline of ' ref ' was not restored: its lock is not in the checkpoint'])
  =/  base-skips=(list @t)
    (murn baselines.p |=([ref=@t b=baseline:ci] (usable ref b)))
  =/  restored=(list [ref=@t =baseline:ci])
    (skim baselines.p |=([ref=@t b=baseline:ci] ?=(~ (usable ref b))))
  =.  baselines.s
    =/  others=(list [[repo=@t ref=@t] baseline:ci])
      (skip ~(tap by baselines.s) |=([[r=@t *] *] =(r repo)))
    =/  mine=(list [[repo=@t ref=@t] baseline:ci])
      (turn restored |=([ref=@t b=baseline:ci] [[repo ref] b]))
    (malt (weld others mine))
  ::  environments and role bindings
  =.  environments.s
    =/  others=(list [[repo=@t name=@t] environment:ci])
      (skip ~(tap by environments.s) |=([[r=@t *] *] =(r repo)))
    =/  mine=(list [[repo=@t name=@t] environment:ci])
      %+  murn  environments.content
      |=  [r=@t e=environment:ci]
      ^-  (unit [[repo=@t name=@t] environment:ci])
      ?.  =(r repo)  ~
      `[[repo name.e] e]
    (malt (weld others mine))
  =/  bound=(list binding:ci)
    (murn bindings.content |=([r=@t b=binding:ci] ?.(=(r repo) ~ `b)))
  =.  roles.s
    ?~  bound  (~(del by roles.s) repo)
    (~(put by roles.s) repo bound)
  :+  s
    :(weld skipped.acc ref-skips base-skips)
  (weld cancelled.acc (turn open |=(c=candidate:ci id.c)))
::
::  the staged checkpoint applied, once apply-refusal said yes.  every
::  repository it names is replaced and its locks are added.  everything
::  that would be authority comes back as inert history.  the staged area is
::  cleared and the restore recorded.  nothing here creates a run, an
::  attempt, an approval in force, a daemon or a credential value
::
++  apply
  |=  $:  s=state-0:ci
          =presence
          actor=@p
          now=@da
          eny=@uvJ
      ==
  ^-  [s=state-0:ci =restore:ci]
  ::  bound first: a refinement of .s itself would fix its type
  =/  waiting=(unit staged-checkpoint:ci)  staged.recovery.s
  ?>  ?=(^ waiting)
  =/  staged=staged-checkpoint:ci  u.waiting
  =/  content=checkpoint-content:ci  content.staged
  =/  id=@t  id.manifest.staged
  ::  the locks first: a baseline's lock must be here
  =.  locks.s
    %+  roll  locks.content
    |=  [[l=lock:ci *] m=_locks.s]
    (~(put by m) digest.l l)
  =.  input-evidence.s
    %+  roll  locks.content
    |=  [[l=lock:ci evidence=(unit @t)] m=_input-evidence.s]
    ?~  evidence  m
    (~(put by m) digest.l u.evidence)
  =/  repos=(list @t)  (content-repos content)
  =/  done=applied
    =/  todo=(list @t)  repos
    =/  acc=applied  [s ~ ~]
    |-  ^-  applied
    ?~  todo  acc
    $(todo t.todo, acc (apply-repo acc i.todo content presence id actor now eny))
  =.  s  s.done
  ::  history only
  =/  key=(list key-record:ci)
    ?~  key.content  ~
    ?:  ?&(?=(^ signing.s) =(pub.u.signing.s pub.u.key.content))  ~
    ~[u.key.content]
  =.  history.recovery.s
    :*  (scag max-history (weld key keys.history.recovery.s))
        (merge-runners runners.history.recovery.s runners.content)
        (merge-credentials s credentials.content)
        (merge-runs runs.history.recovery.s runs.content)
        (merge-authorizations authorizations.history.recovery.s authorizations.content)
        (merge-audit audit.history.recovery.s audit.content)
    ==
  =/  =restore:ci
    [id commit.staged now actor repos skipped.done cancelled.done]
  =.  staged.recovery.s  ~
  =.  restores.recovery.s  (scag max-records `(list restore:ci)`[restore restores.recovery.s])
  [s restore]
::
::  setting or deleting a credential settles its re-entry mark
::
++  reentered
  |=  [s=state-0:ci repo=@t name=@t]
  ^-  state-0:ci
  =.  credentials.history.recovery.s
    %+  skip  credentials.history.recovery.s
    |=(r=credential-ref:ci &(=(repo repo.r) =(name name.r)))
  s
::
::  ---- the checkpoint records ----
::
::  a new record, newest first, the list bounded
::
++  add-record
  |=  [records=(list checkpoint:ci) c=checkpoint:ci]
  ^-  (list checkpoint:ci)
  (scag max-records `(list checkpoint:ci)`[c records])
::
::  the write's answer.  written means queued for its replica.  not
::  written carries the reason, and then there is nothing to push
::
++  written
  |=  [records=(list checkpoint:ci) id=@t now=@da]
  ^-  (list checkpoint:ci)
  %+  turn  records
  |=  c=checkpoint:ci
  ?.  =(id id.c)  c
  c(written [%written now], replica [%waiting ~])
::
++  not-written
  |=  [records=(list checkpoint:ci) id=@t now=@da reason=@t]
  ^-  (list checkpoint:ci)
  %+  turn  records
  |=  c=checkpoint:ci
  ?.  =(id id.c)  c
  c(written [%failed now reason], replica [%skipped 'the checkpoint was not written, so there is nothing to push'])
::
::  whether a push is in flight
::
++  pushing
  |=  records=(list checkpoint:ci)
  ^-  ?
  (lien records |=(c=checkpoint:ci ?=(%pushing -.replica.c)))
::
::  whether a record is written and waits for its push
::
++  ready
  |=  c=checkpoint:ci
  ^-  ?
  ?&(?=(%written -.written.c) ?=(%waiting -.replica.c))
::
::  the record whose push starts now: the newest written one that waits,
::  when no push is in flight.  every waiting record rides that push,
::  since each written commit is an ancestor of the newest
::
++  next-push
  |=  records=(list checkpoint:ci)
  ^-  (unit checkpoint:ci)
  ?:  (pushing records)  ~
  =/  waiting=(list checkpoint:ci)  (skim records ready)
  ?~  waiting  ~
  `i.waiting
::
++  push-started
  |=  [records=(list checkpoint:ci) ticket=@uv route=@t now=@da]
  ^-  (list checkpoint:ci)
  %+  turn  records
  |=  c=checkpoint:ci
  ?.  (ready c)  c
  c(replica [%pushing now route ticket])
::
::  no push path: every waiting written record stays written and its
::  replica is not confirmed, with the reason
::
++  push-unconfigured
  |=  [records=(list checkpoint:ci) reason=@t]
  ^-  (list checkpoint:ci)
  %+  turn  records
  |=  c=checkpoint:ci
  ?.  (ready c)  c
  c(replica [%unconfigured reason])
::
::  a push's answer: each record it carried is confirmed only on the
::  replica's own acceptance, and is a failed backup otherwise
::
++  push-answered
  |=  [records=(list checkpoint:ci) ticket=@uv ok=? message=@t now=@da]
  ^-  (list checkpoint:ci)
  %+  turn  records
  |=  c=checkpoint:ci
  =/  r=checkpoint-replica:ci  replica.c
  ?.  ?=(%pushing -.r)  c
  ?.  =(ticket ticket.r)  c
  ?:  ok  c(replica [%confirmed now route.r])
  c(replica [%failed now route.r message])
::
::  the answer that never came
::
++  push-silence
  ^-  @t
  'no answer from the push path within fifteen minutes: the replica is not confirmed'
--
