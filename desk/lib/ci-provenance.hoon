::  Provenance and policy rules for %urgit-ci (BRIEF-CI-P4 D4-D6; riders
::  02-04): the execution manifest the CI key signs and the daemon
::  verifies, the lock's digest and bounds, and the predicates that say
::  whether an approval, an override or an actor's authority holds now.
::  Nothing here scries; every input is a value the agent already holds.
::
::    every refusal is a reason cord, never a crash: the agent answers it
::    to the route or records it on the candidate.
::
/-  ci, git
/+  git-codec
|%
::  the manifest message version (contract §5; 3 binds the run's event,
::  Delivery 1A; 4 binds a job's needs context and the attempts it came
::  from, Delivery 1B; 5 binds the identity of the event the run was
::  admitted for, Delivery 1C).  a verifier of another version fails
::  closed on both sides.
::
++  manifest-version  5
::
::  A new automatic resolver must not run on an old v5 importer, which
::  ignored purpose. Only this authority uses v6; supported outstanding
::  jobs and explicit imports retain the byte-identical v5 message shape.
++  manifest-version-for
  |=  m=manifest
  ^-  @ud
  ?:(=('resolve-tag' mode.m) 6 manifest-version)
::
::  bounds (D4; the brief's proposed S0 bounds, adopted)
::
++  max-lock-bytes  1.048.576
++  max-lock-nodes  256
++  max-lock-depth  16
::
::  rider 02's unused-authorization lifetime
::
++  authorization-lifetime  ~m15
::
::  the manifest (contract §5): everything the attempt may act on, as
::  the noun both sides jam.  cords for texts, @ud for the generation,
::  @uv for the ids; the oid, baseline and lock travel as hex TEXT so the
::  daemon rebuilds them without a Git codec.
::
+$  manifest
  $:  incarnation=@uv
      repo=@t
      ref=@t
      candidate=@uv
      oid=@t
      baseline=@t
      lock=@t
      generation=@ud
      workflow=@t
      job=@t
      trust=@t
      sandbox=@t
      mode=@t
      network=@t
      scope=@t
      ::  the event the run's jobs receive (Delivery 1A): 'push', or
      ::  'workflow_dispatch' for a manual run, '' for a resolve; and
      ::  the sha-256 of the event payload act reads, 64 hex, a push's
      ::  as a manual run's; '' for a resolve, which runs no job
      event=@t
      context=@t
      ::  a job's needs context (Delivery 1B): the sha-256, 64 hex, of the
      ::  text its expressions read (lib/ci-expr needs-text), '' for a job
      ::  with no needs and for a plan or a resolve; and the accepted
      ::  attempt of each need, `<job>=<attempt>` by job id, comma-joined
      needs=@t
      prerequisites=@t
      ::  the event the run was admitted for (Delivery 1C): canonical text
      ::  beginning with the event's name (lib/ci-trigger trigger-text); ''
      ::  for a resolve
      trigger=@t
  ==
::
::  the signed noun: [5 recipient attempt operation expiry nonce manifest]
::  — the manifest's cells continue the tuple, exactly as the daemon's
::  Tuple(…, manifest) nests them
::
++  message-noun
  |=  [recipient=@uv attempt=@uv operation=@t expiry=@ud nonce=@uv =manifest]
  ^-  *
  [(manifest-version-for manifest) recipient attempt operation expiry nonce manifest]
::
++  message-bytes
  |=  [recipient=@uv attempt=@uv operation=@t expiry=@ud nonce=@uv =manifest]
  ^-  @
  (jam (message-noun recipient attempt operation expiry nonce manifest))
::
::  the manifest as an assignment carries it, its `manifest` object
::  (contract §5): every field the signature binds, under the name the
::  runner decodes (runner/internal/sig Manifest).  the one serializer the
::  controller emits a manifest with: a field missing here decodes empty on
::  the runner, which refuses the assignment (Delivery 1B correction 01)
::
++  manifest-json
  |=  m=manifest
  ^-  json
  %-  pairs:enjs:format
  :~  ['incarnation' s+(scot %uv incarnation.m)]
      ['repo' s+repo.m]
      ['ref' s+ref.m]
      ['candidate' s+(scot %uv candidate.m)]
      ['oid' s+oid.m]
      ['baseline' s+baseline.m]
      ['lock' s+lock.m]
      ['generation' (numb:enjs:format generation.m)]
      ['workflow' s+workflow.m]
      ['job' s+job.m]
      ['trust' s+trust.m]
      ['sandbox' s+sandbox.m]
      ['mode' s+mode.m]
      ['network' s+network.m]
      ['network-scope' s+scope.m]
      ['event' s+event.m]
      ['context' s+context.m]
      ['needs' s+needs.m]
      ['prerequisites' s+prerequisites.m]
      ['trigger' s+trigger.m]
  ==
::
::  a candidate's manifest digest as the attempt records it: the sham of
::  the manifest noun (an identity for display and binding, not the
::  security: the signature covers the whole noun)
::
++  manifest-id
  |=  =manifest
  ^-  @uv
  (sham manifest)
::
::  canonical scope text (rider 03): sorted destinations joined by commas
::
++  scope-text
  |=  destinations=(list @t)
  ^-  @t
  =/  sorted=(list @t)  (sort destinations aor)
  ?~  sorted  ''
  =/  acc=@t  i.sorted
  =/  rest=(list @t)  t.sorted
  |-
  ?~  rest  acc
  $(rest t.rest, acc (rap 3 ~[acc ',' i.rest]))
::
::  an oid as the 40-hex text the manifest carries
::
++  oid-hex
  |=  oid=(unit oid:git)
  ^-  @t
  ?~(oid '' (oid-text:git-codec u.oid))
::
::  a lock digest as 64-hex text (little-endian bytes of the @ux, the way
::  every other hash crosses this wire)
::
++  lock-hex
  |=  lock=(unit @ux)
  ^-  @t
  ?~  lock  ''
  (hex-bytes u.lock 32)
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
::  the lock's digest: sha-256 over the jam of its canonical node list
::  (nodes in wire order, every field), so a changed byte in any node is
::  a different lock; the ship computes it once at import and the daemon
::  only ever carries it
::
::  the lock's identity: the repository, the revision and every node.
::  two repositories with byte-identical workflows resolve to identical
::  node lists; the digest keys the ship's lock table, so it names the
::  repository and revision as well (P09's cold run found the collision:
::  a second repository's resolve overwrote the first's lock)
++  lock-digest
  |=  [repo=@t revision=oid:git nodes=(list dep-node:ci)]
  ^-  @ux
  (shax (jam [repo revision nodes]))
::
::  a lock resolved since manual runs (Delivery 1A): its identity covers
::  the manual-run inventory its resolver read too, so the same nodes
::  read with other declarations are another lock, and a promoted
::  baseline's inventory changes only with a promotion; no inventory (~)
::  is another lock than an empty one
::
++  lock-digest-with
  |=  [repo=@t revision=oid:git nodes=(list dep-node:ci) inventory=(unit (list dispatch-workflow:ci))]
  ^-  @ux
  (shax (jam [repo revision nodes inventory]))
::
::  a lock resolved since triggers (Delivery 1C): its identity covers the
::  trigger catalog too, so the same nodes and inventory read with other
::  events, filters or schedules are another lock, and no catalog (~,
::  unknown) another than an empty one.  a lock resolved before keeps the
::  digest it was stored under
::
++  lock-digest-full
  |=  $:  repo=@t
          revision=oid:git
          nodes=(list dep-node:ci)
          inventory=(unit (list dispatch-workflow:ci))
          triggers=(unit trigger-catalog:ci)
      ==
  ^-  @ux
  ?~  triggers  (lock-digest-with repo revision nodes inventory)
  (shax (jam [repo revision nodes inventory triggers]))
::
::  lock validation (D4): bounds, well-formed identities, refusals
::
++  validate-lock
  |=  [nodes=(list dep-node:ci) bytes=@ud depth=@ud]
  ^-  (unit @t)
  ?:  (gth bytes max-lock-bytes)
    `(rap 3 ~['lock metadata is ' (scot %ud bytes) ' bytes; the bound is ' (scot %ud max-lock-bytes)])
  ?:  (gth (lent nodes) max-lock-nodes)
    `(rap 3 ~['lock has ' (scot %ud (lent nodes)) ' nodes; the bound is ' (scot %ud max-lock-nodes)])
  ?:  (gth depth max-lock-depth)
    `(rap 3 ~['dependency depth ' (scot %ud depth) ' exceeds the bound ' (scot %ud max-lock-depth)])
  |-
  ?~  nodes  ~
  =/  n=dep-node:ci  i.nodes
  =/  where=@t  (rap 3 ~[uses.n ' (' workflow.n ' ' job.n ' step ' (scot %ud step.n) ')'])
  ?^  refusal.n
    `(rap 3 ~['unresolved dependency ' where ': ' u.refusal.n])
  ?-  kind.n
    %unknown  `(rap 3 ~['unknown dependency kind for ' where])
    %reusable  `(rap 3 ~['reusable workflow ' where ' is not supported in this release'])
    %local  $(nodes t.nodes)
      %download
    ?.  &(=(64 (met 3 sha256.n)) (gth size.n 0))
      `(rap 3 ~['download ' where ' has no sha256/size'])
    ?.  &(=('store' mirror.n) =(path.n (rap 3 ~['ci/downloads/' sha256.n])))
      `(rap 3 ~['download ' where ' is not mirrored in the ship\'s store'])
    $(nodes t.nodes)
  ::
      %container
    ?.  =('sha256:' (end [3 7] digest.n))
      `(rap 3 ~['container image ' where ' is not pinned to a sha256 digest'])
    ::  the image's bytes (P03): the archive of the pinned manifest in
    ::  the ship's store, and the id it loads as (the node's tree)
    ?.  &(=(64 (met 3 sha256.n)) (gth size.n 0) =('sha256:' (end [3 7] tree.n)))
      `(rap 3 ~['container image ' where ' has no archive sha256/size and image id'])
    ?.  &(=('store' mirror.n) =(path.n (rap 3 ~['ci/downloads/' sha256.n])))
      `(rap 3 ~['container image ' where ' is not mirrored in the ship\'s store'])
    $(nodes t.nodes)
  ::
      ?(%js %composite)
    ?.  &(=(40 (met 3 commit.n)) =(40 (met 3 tree.n)))
      `(rap 3 ~['action ' where ' has no resolved commit and tree'])
    ?:  |(=('' mirror.n) !=(40 (met 3 mirror-commit.n)))
      `(rap 3 ~['action ' where ' is not mirrored'])
    $(nodes t.nodes)
  ==
::
::  authority (rider 02): the repository owner holds every role
::  implicitly; a delegated binding grants a role to listed ships, for
::  every scope when its scope is ~, else for exactly that scope
::
++  authorized
  |=  [owner=(unit @p) bindings=(list binding:ci) =role:ci scope=(unit @t) actor=@p]
  ^-  ?
  ?:  ?&(?=(^ owner) =(u.owner actor))  %.y
  %+  lien  bindings
  |=  b=binding:ci
  ?&  =(role role.b)
      ?|(?=(~ scope.b) =(scope.b scope))
      (~(has in ships.b) actor)
  ==
::
::  an approval holds now for one attempt of one job (rider 02): never
::  consumed, never invalidated, inside its fifteen minutes, and bound to
::  exactly the candidate, object, job, environment, baseline, lock and
::  generation it was given for
::
++  approval-valid
  |=  $:  a=approval:ci
          now=@da
          incarnation=@uv
          candidate=candidate-id:ci
          oid=oid:git
          workflow=@t
          job=@t
          environment=@t
          baseline=oid:git
          lock=(unit @ux)
          generation=@ud
      ==
  ^-  (unit @t)
  ?^  consumed.a  `'approval already consumed'
  ?^  invalidated.a  `(rap 3 ~['approval invalidated: ' u.invalidated.a])
  ?:  (gte now expires.a)  `'approval expired (15 minutes)'
  ?.  =(incarnation incarnation.a)  `'approval is for another incarnation of the repository'
  ?.  =(candidate candidate.a)  `'approval is for another candidate'
  ?.  =(oid oid.a)  `'approval is for another object'
  ?.  &(=(workflow workflow.a) =(job job.a))  `'approval is for another job'
  ?.  =(environment environment.a)  `'approval is for another environment'
  ?.  =(baseline baseline.a)  `'approval was given under another baseline'
  ?.  =(lock lock.a)  `'approval was given under another lock'
  ?.  =(generation generation.a)  `'approval was given under another policy generation'
  ~
::
::  an override holds now for one ref advance (rider 02): unused, not
::  invalidated, inside its fifteen minutes, naming exactly this object
::  and this expected tip under the current generation and incarnation
::
++  override-valid
  |=  $:  o=override:ci
          now=@da
          incarnation=@uv
          repo=@t
          ref=@t
          oid=oid:git
          tip=oid:git
          generation=@ud
      ==
  ^-  (unit @t)
  ?^  consumed.o  `'override already used'
  ?^  invalidated.o  `(rap 3 ~['override invalidated: ' u.invalidated.o])
  ?:  (gte now expires.o)  `'override expired (15 minutes)'
  ?.  &(=(repo repo.o) =(ref ref.o))  `'override is for another ref'
  ?.  =(incarnation incarnation.o)  `'override is for another incarnation of the repository'
  ?.  =(oid oid.o)  `'override names another object'
  ?.  =(tip expected.o)  `'destination tip is not the one the override expected'
  ?.  =(generation generation.o)  `'override was recorded under another policy generation'
  ~
::
::  the network a job runs under (rider 03): its standing policy when the
::  repository has one for exactly this workflow and job, else locked
::
++  network-for
  |=  [policies=(list network-policy:ci) workflow=@t job=@t]
  ^-  [profile=@t destinations=(list @t)]
  |-
  ?~  policies  ['locked' ~]
  ?:  &(=(workflow workflow.i.policies) =(job job.i.policies))
    [profile.i.policies destinations.i.policies]
  $(policies t.policies)
::
::  a destination is `tcp:<host>:<port>` or `udp:<host>:<port>`, where the
::  host is an IP literal or a DNS name (CI-P4-NET-1, named destinations,
::  2026-10-08).  The ship never resolves a name: the VM launcher resolves
::  and pins it on the host for one reservation (rider 03 enforcement
::  stays outside the guest)
::
++  destination-valid
  |=  d=@t
  ^-  ?
  =/  chars=tape  (trip d)
  ?.  ?|(=("tcp:" (scag 4 chars)) =("udp:" (scag 4 chars)))  %.n
  =/  rest=tape  (slag 4 chars)
  =/  colon=(unit @ud)  (find ":" (flop rest))
  ?~  colon  %.n
  =/  host=tape  (scag (sub (lent rest) +(u.colon)) rest)
  =/  port=tape  (slag (sub (lent rest) u.colon) rest)
  ?~  host  %.n
  ?~  port  %.n
  ?.  (levy `tape`port |=(c=@tD &((gte c '0') (lte c '9'))))  %.n
  ::  plain decimal with no padding (dim:ag): dem:ag wants a thousands
  ::  dot, so it refused every port of four or more digits
  =/  n=(unit @ud)  (rush (crip port) dim:ag)
  ?~  n  %.n
  ?.  &((gth u.n 0) (lte u.n 65.535))  %.n
  ::  an IPv6 literal in brackets is accepted as written; a DNS name in
  ::  the grammar below; otherwise an IPv4 literal of four dotted decimal
  ::  octets
  ?:  =("[" (scag 1 `tape`host))  %.y
  ?:  (dns-name-valid (crip host))  %.y
  =/  parts=(list tape)  (split-on `tape`host '.')
  ?.  =(4 (lent parts))  %.n
  %+  levy  parts
  |=  p=tape
  ?~  p  %.n
  =/  v=(unit @ud)  (rush (crip p) dem:ag)
  ?&(?=(^ v) (lte u.v 255))
::
::  a DNS name in a destination: the grammar runner/internal/netname
::  spells too, so the ship, the runner and the launcher agree on what
::  one entry names.  Lower case only (a policy is compared as text),
::  1-253 characters, two or more labels of 1-63 characters from a-z,
::  0-9 and -, no label starting or ending with -, no wildcard, no
::  trailing dot, and a last label that starts with a letter, so no IPv4
::  literal, valid or not, is ever read as a name
::
++  dns-name-valid
  |=  name=@t
  ^-  ?
  =/  chars=tape  (trip name)
  ?.  &((gte (lent chars) 1) (lte (lent chars) 253))  %.n
  =/  labels=(list tape)  (split-on chars '.')
  ?.  (gte (lent labels) 2)  %.n
  ?.  (levy labels dns-label-valid)  %.n
  =/  last=tape  (rear labels)
  ?~  last  %.n
  &((gte i.last 'a') (lte i.last 'z'))
::
++  dns-label-valid
  |=  label=tape
  ^-  ?
  ?~  label  %.n
  ?.  (lte (lent label) 63)  %.n
  ?:  |(=('-' i.label) =('-' (rear `tape`label)))  %.n
  %+  levy  `tape`label
  |=  c=@tD
  ?|  &((gte c 'a') (lte c 'z'))
      &((gte c '0') (lte c '9'))
      =('-' c)
  ==
::
++  split-on
  |=  [text=tape sep=@tD]
  ^-  (list tape)
  =|  acc=(list tape)
  =|  cur=tape
  |-
  ?~  text  (flop [(flop cur) acc])
  ?:  =(sep i.text)  $(text t.text, acc [(flop cur) acc], cur ~)
  $(text t.text, cur [i.text cur])
::
::  the DNS names a signed scope grants (scope-text's sorted, comma-
::  separated destinations), each once, in name order; IP literals grant
::  no name (CI-P4-NET-1, pinned addresses shown per run)
::
++  granted-names
  |=  scope=@t
  ^-  (list @t)
  =/  names=(list @t)
    %+  murn  (split-on (trip scope) ',')
    |=  d=tape
    ^-  (unit @t)
    ?.  (destination-valid (crip d))  ~
    =/  rest=tape  (slag 4 d)
    =/  colon=(unit @ud)  (find ":" (flop rest))
    ?~  colon  ~
    =/  host=@t  (crip (scag (sub (lent rest) +(u.colon)) rest))
    ?.  (dns-name-valid host)  ~
    `host
  (sort ~(tap in (silt names)) aor)
::
::  a daemon's report of what the launcher pinned for one run:
::  `{"pinned": [{"name": .., "addrs": [..]}]}`.  each granted name
::  exactly once and nothing else, each with 1 to 64 distinct IPv4
::  addresses in their plain form; answered in the order of .granted
::
++  parse-pinned
  |=  [jon=json granted=(list @t)]
  ^-  (each (list pin:ci) @t)
  ?.  ?=([%o *] jon)  |+'the body is not a JSON object'
  =/  field=(unit json)  (~(get by p.jon) 'pinned')
  ?.  &(?=(^ field) ?=([%a *] u.field))  |+'pinned must be a list'
  =/  items=(list json)  p.u.field
  =|  got=(map @t (list @t))
  |-  ^-  (each (list pin:ci) @t)
      ?~  items
        ?.  =(~(wyt by got) (lent granted))
          |+'pinned must name every DNS name the attempt was granted'
        &+(turn granted |=(n=@t `pin:ci`[n (~(got by got) n)]))
      =/  item=(each pin:ci @t)  (parse-pin i.items)
      ?:  ?=(%| -.item)  |+p.item
      ?:  =(~ (find ~[name.p.item] granted))
        |+(rap 3 ~['pinned names ' name.p.item ', which the attempt was not granted'])
      ?:  (~(has by got) name.p.item)
        |+(rap 3 ~['pinned names ' name.p.item ' twice'])
      $(items t.items, got (~(put by got) name.p.item addrs.p.item))
::
++  parse-pin
  |=  jon=json
  ^-  (each pin:ci @t)
  ?.  ?=([%o *] jon)  |+'a pinned entry is not a JSON object'
  =/  name=(unit json)  (~(get by p.jon) 'name')
  =/  addrs=(unit json)  (~(get by p.jon) 'addrs')
  ?.  &(?=(^ name) ?=([%s *] u.name))  |+'a pinned entry has no name'
  ?.  &(?=(^ addrs) ?=([%a *] u.addrs))  |+'a pinned entry has no address list'
  =/  texts=(list json)  p.u.addrs
  ?.  &((gte (lent texts) 1) (lte (lent texts) 64))
    |+(rap 3 ~['pinned names ' p.u.name ' with no address, or more than 64'])
  =|  out=(list @t)
  |-  ^-  (each pin:ci @t)
      ?~  texts  &+[p.u.name (flop out)]
      ?.  ?=([%s *] i.texts)  |+'a pinned address is not a string'
      ?.  (ipv4-plain-valid p.i.texts)
        =/  why=@t  ' with an address that is not one IPv4 address in its plain form'
        |+(rap 3 ~['pinned names ' p.u.name why])
      ?.  =(~ (find ~[p.i.texts] out))
        |+(rap 3 ~['pinned names ' p.u.name ' with one address twice'])
      $(texts t.texts, out [p.i.texts out])
::
::  an IPv4 address in its plain form: four dotted decimal octets, each
::  0-255, with no leading zero (dem:ag refuses one)
::
++  ipv4-plain-valid
  |=  a=@t
  ^-  ?
  =/  parts=(list tape)  (split-on (trip a) '.')
  ?.  =(4 (lent parts))  %.n
  %+  levy  parts
  |=  p=tape
  ?~  p  %.n
  ?.  (lte (lent p) 3)  %.n
  ?.  (levy `tape`p |=(c=@tD &((gte c '0') (lte c '9'))))  %.n
  =/  v=(unit @ud)  (rush (crip p) dem:ag)
  &(?=(^ v) (lte u.v 255))
::
::  a harness path is a repository-relative path with no traversal
::
++  harness-path-valid
  |=  p=@t
  ^-  ?
  =/  chars=tape  (trip p)
  ?~  chars  %.n
  ?:  =('/' i.chars)  %.n
  ?:  ?=(^ (find `tape`".." `tape`chars))  %.n
  %.y
--
