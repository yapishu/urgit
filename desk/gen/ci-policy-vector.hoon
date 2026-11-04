::  ci-policy-vector: the pure policy predicates of lib/ci-provenance (P4
::  riders 02 and 03; rows P02, P09, P10, A01, A02, A04, A05, P03): role
::  authority, the fifteen-minute single-use approval and override rules
::  with every binding they carry, the network policy lookup, the
::  destination and harness-path syntax, and the lock rule (bounds,
::  refusals, mirrored downloads, digest stability).  Every case names
::  the verdict it expects; the intentionally FALSE cases are the ones
::  where the predicate must refuse, and the generator fails if any of
::  them is accepted.  Prints `passed=N of=M` and ends in a loobean.
::
/-  ci, git
/+  ci-provenance
:-  %say
|=  [[now=@da * *] * *]
:-  %noun
=/  owner=@p  ~tyv
=/  syd=@p  ~syd
=/  nec=@p  ~nec
=/  bindings=(list binding:ci)
  :~  [%ci-policy ~ (silt ~[syd])]
      [%environment-approver `'prod' (silt ~[nec])]
      [%override `'refs/heads/master' (silt ~[syd])]
  ==
=/  auth
  |=  [=role:ci scope=(unit @t) actor=@p]
  (authorized:ci-provenance `owner bindings role scope actor)
=/  inc=@uv  0v1.incar
=/  cand=@uv  0v2.cand0
=/  oid=@ux  0xa6d1.5edd.efa8.9825.0bf5.f656.441a.55a8.0273.f751
=/  base=@ux  0xbbbb.0000.0000.0000.0000.0000.0000.0000.0000.0001
=/  tip=@ux  0xcccc.0000.0000.0000.0000.0000.0000.0000.0000.0002
=/  lock=(unit @ux)  `0x1111
=/  =approval:ci
  :*  0v3.appr0  'erpit'  inc  cand  oid  'suite.yml'  'deploy'  'prod'
      (silt ~['DEPLOY_KEY'])  base  lock  7  nec  now
      (add now authorization-lifetime:ci-provenance)  ~  ~
  ==
=/  appr-ok
  |=  [a=approval:ci at=@da]
  (approval-valid:ci-provenance a at inc cand oid 'suite.yml' 'deploy' 'prod' base lock 7)
=/  =override:ci
  :*  0v4.over0  'erpit'  'refs/heads/master'  inc  cand  oid  tip  syd  'hotfix'
      'status failed'  7  now  (add now authorization-lifetime:ci-provenance)  ~  ~
  ==
=/  over-ok
  |=  [o=override:ci at=@da]
  (override-valid:ci-provenance o at inc 'erpit' 'refs/heads/master' oid tip 7)
=/  policies=(list network-policy:ci)
  :~  ['suite.yml' 'integration' 'egress' ~['tcp:140.82.112.3:443'] ~ owner now]
  ==
=/  node
  |=  [uses=@t kind=dep-kind:ci]
  ^-  dep-node:ci
  :*  uses  kind  'https://github.com/actions/checkout'  'v4'
      '11d5960a326750d5838078e36cf38b85af677262'  'f8a7b72dc00648d050099727d25ca92a43ad1162'  ''
      'ci-mirror-actions-checkout'  '7fcfc62a9d93ce747310f9535b43c86ca615250d'  ''  'MIT'
      'suite.yml'  'build'  0  ''  0  ''  ~
  ==
=/  js=dep-node:ci  (node 'actions/checkout@v4' %js)
=/  download=dep-node:ci
  =/  d=dep-node:ci  (node 'https://bootstrap.urbit.org/urbit-v4.6.pill' %download)
  %=  d
    commit  ''
    tree    ''
    mirror  'store'
    mirror-commit  ''
    sha256  'c0ffee0000000000000000000000000000000000000000000000000000000001'
    size    210.249.590
    path    'ci/downloads/c0ffee0000000000000000000000000000000000000000000000000000000001'
  ==
=/  image=dep-node:ci
  =/  d=dep-node:ci  (node 'container:node:20-bookworm' %container)
  %=  d
    commit  ''
    tree    'sha256:1212121212121212121212121212121212121212121212121212121212121212'
    mirror  'store'
    mirror-commit  ''
    digest  'sha256:abababababababababababababababababababababababababababababababab'
    sha256  'efefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefef'
    size    2.152.960
    path    'ci/downloads/efefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefef'
  ==
=/  valid
  |=  nodes=(list dep-node:ci)
  (validate-lock:ci-provenance nodes 5.000 1)
=/  many=(list dep-node:ci)
  =|  acc=(list dep-node:ci)
  =/  i=@ud  0
  |-
  ?:  =(i 257)  acc
  $(i +(i), acc [js(uses (rap 3 ~['n' (scot %ud i)])) acc])
::  each case: a name, the verdict expected, the verdict observed.  a
::  case expecting %.n is an intentionally false assertion: the
::  predicate must REFUSE it
::
::  the DNS name length bounds (CI-P4-NET-1, named destinations): a
::  63- and a 64-character label, a 253- and a 255-character name
=/  label-63=@t  (rap 3 ~['tcp:' (fil 3 63 'a') '.com:443'])
=/  label-64=@t  (rap 3 ~['tcp:' (fil 3 64 'a') '.com:443'])
=/  name-253=@t  (rap 3 (snoc (reap 125 'a.') 'com'))
=/  name-255=@t  (rap 3 (snoc (reap 126 'a.') 'com'))
::  destination syntax (rider 03; named destinations, CI-P4-NET-1)
=/  dest-ok  destination-valid:ci-provenance
=/  destination-cases=(list [name=@t expect=? got=?])
  :~  ['a tcp destination with an IPv4 literal' %.y (dest-ok 'tcp:140.82.112.3:443')]
      ['a udp destination' %.y (dest-ok 'udp:1.1.1.1:53')]
      ['a bracketed IPv6 literal' %.y (dest-ok 'tcp:[2606:50c0:8000::153]:443')]
      ::  named destinations (CI-P4-NET-1, 2026-10-08): the grammar
      ::  runner/internal/netname checks too
      ['a DNS name is a destination' %.y (dest-ok 'tcp:github.com:443')]
      ['a deeper DNS name' %.y (dest-ok 'tcp:raw.githubusercontent.com:443')]
      ['a name with digits and a hyphen' %.y (dest-ok 'udp:ns-1.x1.example:53')]
      ['a single label is not a name' %.n (dest-ok 'tcp:localhost:80')]
      ['upper case is not a name' %.n (dest-ok 'tcp:GitHub.com:443')]
      ['a wildcard is not a name' %.n (dest-ok 'tcp:*.github.com:443')]
      ['a trailing dot is not a name' %.n (dest-ok 'tcp:github.com.:443')]
      ['an empty label is not a name' %.n (dest-ok 'tcp:git..hub.com:443')]
      ['a label starting with a hyphen is not a name' %.n (dest-ok 'tcp:-git.com:443')]
      ['a label ending with a hyphen is not a name' %.n (dest-ok 'tcp:git-.com:443')]
      ['an underscore is not a name' %.n (dest-ok 'tcp:git_hub.com:443')]
      ['a numeric last label is not a name' %.n (dest-ok 'tcp:host.123:443')]
      ['a 64-character label is not a name' %.n (dest-ok label-64)]
      ['a 63-character label is a name' %.y (dest-ok label-63)]
      ['a name of 255 characters is not a name' %.n (dns-name-valid:ci-provenance name-255)]
      ['a name of 253 characters is a name' %.y (dns-name-valid:ci-provenance name-253)]
      ['a port of zero' %.n (dest-ok 'tcp:140.82.112.3:0')]
      ['a port past 65535' %.n (dest-ok 'tcp:140.82.112.3:65536')]
      ::  a port is plain decimal: no thousands dot, no padding
      ['a four-digit port' %.y (dest-ok 'tcp:198.51.100.20:8472')]
      ['the highest port' %.y (dest-ok 'tcp:140.82.112.3:65535')]
      ['a named destination on a four-digit port' %.y (dest-ok 'tcp:archive.ubuntu.com:8080')]
      ['a padded port' %.n (dest-ok 'tcp:140.82.112.3:0443')]
      ['a port with a thousands dot' %.n (dest-ok 'tcp:198.51.100.20:8.472')]
      ['an octet past 255' %.n (dest-ok 'tcp:300.82.112.3:443')]
      ['a bare address' %.n (dest-ok '140.82.112.3:443')]
  ==
::  a daemon's report of what the launcher pinned (CI-P4-NET-1, pinned
::  addresses shown per run): exactly the granted names, IPv4 only
=/  scope=@t  'tcp:198.51.100.20:8472,tcp:archive.ubuntu.com:80,tcp:bootstrap.urbit.org:443'
=/  granted=(list @t)  (granted-names:ci-provenance scope)
=/  pin-json
  |=  [name=@t addrs=(list @t)]
  ^-  json
  (pairs:enjs:format ~[['name' s+name] ['addrs' a+(turn addrs |=(a=@t s+a))]])
=/  report
  |=  items=(list json)
  ^-  json
  (pairs:enjs:format ~[['pinned' a+items]])
=/  ubuntu  (pin-json 'archive.ubuntu.com' ~['91.189.91.82' '185.125.190.81'])
=/  urbit  (pin-json 'bootstrap.urbit.org' ~['104.21.64.85'])
=/  parse  |=(jon=json (parse-pinned:ci-provenance jon granted))
=/  parses  |=(jon=json =/(r (parse jon) ?=(%& -.r)))
=/  pin-ok  |=(items=(list json) (parses (report items)))
::  archive.ubuntu.com with these addresses, beside the urbit entry
=/  ubuntu-as  |=(addrs=(list @t) (pin-ok ~[(pin-json 'archive.ubuntu.com' addrs) urbit]))
=/  names  granted-names:ci-provenance
=/  sixty-five=(list @t)
  (turn (gulf 1 65) |=(i=@ud (rap 3 ~['91.189.91.' (scot %ud i)])))
=/  in-order=(list pin:ci)
  :~  ['archive.ubuntu.com' ~['91.189.91.82' '185.125.190.81']]
      ['bootstrap.urbit.org' ~['104.21.64.85']]
  ==
=/  evil  (pin-json 'evil.example' ~['203.0.113.9'])
=/  pin-cases=(list [name=@t expect=? got=?])
  :~  ['a scope grants its names in order' %.y =(granted (turn in-order head))]
      ['a literals-only scope grants no name' %.y =(~ (names 'tcp:198.51.100.20:8472'))]
      ['a name on two ports is granted once' %.y =(1 (lent (names 'tcp:a.ex:443,tcp:a.ex:80')))]
      ['every granted name, each with addresses' %.y (pin-ok ~[urbit ubuntu])]
      ['the report is kept in name order' %.y =([%& in-order] (parse (report ~[urbit ubuntu])))]
      ['a granted name missing' %.n (pin-ok ~[ubuntu])]
      ['a name not granted' %.n (pin-ok ~[ubuntu urbit evil])]
      ['a granted name swapped for another' %.n (pin-ok ~[ubuntu evil])]
      ['a name twice' %.n (pin-ok ~[ubuntu urbit ubuntu])]
      ['a name with no address' %.n (ubuntu-as ~)]
      ['a name with 65 addresses' %.n (ubuntu-as sixty-five)]
      ['an IPv6 address' %.n (ubuntu-as ~['2620:2d:4000:1::16'])]
      ['a padded octet' %.n (ubuntu-as ~['091.189.91.82'])]
      ['an octet past 255' %.n (ubuntu-as ~['291.189.91.82'])]
      ['one address twice' %.n (ubuntu-as ~['91.189.91.82' '91.189.91.82'])]
      ['a name for an address' %.n (ubuntu-as ~['archive.ubuntu.com'])]
      ['a body that is no object' %.n (parses a+~)]
      ['a body with no pinned list' %.n (parses (pairs:enjs:format ~))]
  ==
=/  other-cases=(list [name=@t expect=? got=?])
  :~  ::  authority (rider 02)
      ['owner holds every role implicitly' %.y (auth %ci-policy ~ owner)]
      ['owner holds a scoped role too' %.y (auth %override `'refs/heads/master' owner)]
      ['bound ship holds ci-policy' %.y (auth %ci-policy ~ syd)]
      ['unbound ship does not hold ci-policy' %.n (auth %ci-policy ~ nec)]
      ['approver bound for prod approves prod' %.y (auth %environment-approver `'prod' nec)]
      ['approver bound for prod does not approve staging' %.n (auth %environment-approver `'staging' nec)]
      ['override bound for master' %.y (auth %override `'refs/heads/master' syd)]
      ['override bound for master is not override for dev' %.n (auth %override `'refs/heads/dev' syd)]
      ['ci-policy does not imply override' %.n (auth %override `'refs/heads/master' nec)]
      ['no owner known: nobody holds anything unbound' %.n (authorized:ci-provenance ~ ~ %ci-policy ~ owner)]
      ::  approvals (rider 02): fifteen minutes, single use, exact bindings
      ['a fresh approval holds' %.y ?=(~ (appr-ok approval now))]
      ['an approval holds at fourteen minutes' %.y ?=(~ (appr-ok approval (add now ~m14)))]
      ['an approval is dead at sixteen minutes' %.n ?=(~ (appr-ok approval (add now ~m16)))]
      ['an approval is dead at exactly fifteen minutes' %.n ?=(~ (appr-ok approval (add now ~m15)))]
      ['a consumed approval is dead' %.n ?=(~ (appr-ok approval(consumed `0v9.att00) now))]
      ['an invalidated approval is dead' %.n ?=(~ (appr-ok approval(invalidated `'generation 8') now))]
      ['another candidate refuses' %.n ?=(~ (approval-valid:ci-provenance approval now inc 0v9 oid 'suite.yml' 'deploy' 'prod' base lock 7))]
      ['another object refuses' %.n ?=(~ (approval-valid:ci-provenance approval now inc cand tip 'suite.yml' 'deploy' 'prod' base lock 7))]
      ['another job refuses' %.n ?=(~ (approval-valid:ci-provenance approval now inc cand oid 'suite.yml' 'deploy2' 'prod' base lock 7))]
      ['another workflow refuses' %.n ?=(~ (approval-valid:ci-provenance approval now inc cand oid 'fixtures.yml' 'deploy' 'prod' base lock 7))]
      ['another environment refuses' %.n ?=(~ (approval-valid:ci-provenance approval now inc cand oid 'suite.yml' 'deploy' 'staging' base lock 7))]
      ['another baseline refuses' %.n ?=(~ (approval-valid:ci-provenance approval now inc cand oid 'suite.yml' 'deploy' 'prod' tip lock 7))]
      ['another lock refuses' %.n ?=(~ (approval-valid:ci-provenance approval now inc cand oid 'suite.yml' 'deploy' 'prod' base `0x2222 7))]
      ['another generation refuses' %.n ?=(~ (approval-valid:ci-provenance approval now inc cand oid 'suite.yml' 'deploy' 'prod' base lock 8))]
      ['another incarnation refuses' %.n ?=(~ (approval-valid:ci-provenance approval now 0v9.inc00 cand oid 'suite.yml' 'deploy' 'prod' base lock 7))]
      ::  overrides (rider 02): exact object and tip, single use
      ['a fresh override holds' %.y ?=(~ (over-ok override now))]
      ['an override is dead at sixteen minutes' %.n ?=(~ (over-ok override (add now ~m16)))]
      ['a used override is dead (replay)' %.n ?=(~ (over-ok override(consumed `now) now))]
      ['an invalidated override is dead' %.n ?=(~ (over-ok override(invalidated `'generation 8') now))]
      ['another object refuses' %.n ?=(~ (override-valid:ci-provenance override now inc 'erpit' 'refs/heads/master' base tip 7))]
      ['a moved tip refuses' %.n ?=(~ (override-valid:ci-provenance override now inc 'erpit' 'refs/heads/master' oid base 7))]
      ['another ref refuses' %.n ?=(~ (override-valid:ci-provenance override now inc 'erpit' 'refs/heads/dev' oid tip 7))]
      ['another generation refuses' %.n ?=(~ (override-valid:ci-provenance override now inc 'erpit' 'refs/heads/master' oid tip 8))]
      ['another incarnation (a re-created repository) refuses' %.n ?=(~ (override-valid:ci-provenance override now 0v9.inc00 'erpit' 'refs/heads/master' oid tip 7))]
      ::  network policy (rider 03): locked unless a policy names the job
      ['a job without a policy is locked' %.y =('locked' profile:(network-for:ci-provenance policies 'suite.yml' 'build'))]
      ['the named job gets its profile' %.y =('egress' profile:(network-for:ci-provenance policies 'suite.yml' 'integration'))]
      ['the same job of another workflow is locked' %.y =('locked' profile:(network-for:ci-provenance policies 'fixtures.yml' 'integration'))]
      ['no policies: locked' %.y =('locked' profile:(network-for:ci-provenance ~ 'suite.yml' 'integration'))]
      ::  harness paths (D5)
      ['.github/ is a harness path' %.y (harness-path-valid:ci-provenance '.github/')]
      ['bin/ is a harness path' %.y (harness-path-valid:ci-provenance 'bin/')]
      ['an absolute path is not' %.n (harness-path-valid:ci-provenance '/etc/')]
      ['a traversal is not' %.n (harness-path-valid:ci-provenance '.github/../secrets')]
      ['an empty path is not' %.n (harness-path-valid:ci-provenance '')]
      ::  locks (D4): well-formed, mirrored, bounded; the digest follows the bytes
      ['a js node with a mirror and a download in the store validate' %.y ?=(~ (valid ~[js download image]))]
      ['a refusal never validates' %.n ?=(~ (valid ~[js(refusal `'could not resolve')]))]
      ['an unknown kind never validates' %.n ?=(~ (valid ~[js(kind %unknown)]))]
      ['a reusable workflow never validates' %.n ?=(~ (valid ~[js(kind %reusable)]))]
      ['an action without a mirror commit never validates' %.n ?=(~ (valid ~[js(mirror-commit '')]))]
      ['an action without a commit never validates' %.n ?=(~ (valid ~[js(commit '')]))]
      ['a download outside the store never validates' %.n ?=(~ (valid ~[download(mirror 'ci-downloads-x')]))]
      ['a download at the wrong key never validates' %.n ?=(~ (valid ~[download(path 'ci/downloads/other')]))]
      ['a download without a sha256 never validates' %.n ?=(~ (valid ~[download(sha256 '')]))]
      ['an image without a digest never validates' %.n ?=(~ (valid ~[image(digest 'latest')]))]
      ['an image without its archive in the store never validates' %.n ?=(~ (valid ~[image(sha256 '', size 0)]))]
      ['an image whose archive is not in the store never validates' %.n ?=(~ (valid ~[image(mirror '', path '')]))]
      ['an image without the id it loads as never validates' %.n ?=(~ (valid ~[image(tree '')]))]
      ['257 nodes exceed the bound' %.n ?=(~ (valid many))]
      ['metadata past 1 MiB exceeds the bound' %.n ?=(~ (validate-lock:ci-provenance ~[js] 2.000.000 1))]
      ['depth 17 exceeds the bound' %.n ?=(~ (validate-lock:ci-provenance ~[js] 100 17))]
      ['the same nodes digest the same' %.y =((lock-digest:ci-provenance 'erpit' oid ~[js download]) (lock-digest:ci-provenance 'erpit' oid ~[js download]))]
      ['one changed commit changes the digest' %.n =((lock-digest:ci-provenance 'erpit' oid ~[js]) (lock-digest:ci-provenance 'erpit' oid ~[js(commit '11d5960a326750d5838078e36cf38b85af677263')]))]
      ['node order is part of the identity' %.n =((lock-digest:ci-provenance 'erpit' oid ~[js download]) (lock-digest:ci-provenance 'erpit' oid ~[download js]))]
      ['the same nodes in another repository are another lock' %.n =((lock-digest:ci-provenance 'erpit' oid ~[js]) (lock-digest:ci-provenance 'urgit' oid ~[js]))]
      ['the same nodes at another revision are another lock' %.n =((lock-digest:ci-provenance 'erpit' oid ~[js]) (lock-digest:ci-provenance 'erpit' tip ~[js]))]
  ==
=/  cases=(list [name=@t expect=? got=?])  :(weld other-cases destination-cases pin-cases)
=/  failed=(list @t)
  %+  murn  cases
  |=  [name=@t expect=? got=?]
  ?:(=(expect got) ~ `name)
=/  passed=@ud  (sub (lent cases) (lent failed))
~&  [%false-assertions-refused (lent (skim cases |=([* expect=? got=?] &(!expect !got)))) %of (lent (skim cases |=([* expect=? *] !expect)))]
~&  [%failed failed]
~&  (crip "passed={<passed>} of={<(lent cases)>}")
?=(~ failed)
