::  Automatic dependency policy. Exact URLs, no authority from repository YAML.
/-  ci
/+  ci-provenance, ci-plan, ci-dispatch
|%
++  url-valid
  |=  url=@t
  ^-  ?
  ?.  &((lte (met 3 url) 512) =('https://' (end [3 8] url)))  %.n
  =/  rest=tape  (trip (rsh [3 8] url))
  =/  slash=(unit @ud)  (find "/" rest)
  ?~  slash  %.n
  ?.  (dns-name-valid:ci-provenance (crip (scag u.slash rest)))  %.n
  =/  path=tape  (slag u.slash rest)
  ?.  %+  levy
        path
      |=(c=@tD ?=(^ (find ~[c] "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/-._~")))
    %.n
  =/  tail=tape  (snoc path '/')
  ?&  ?=(~ (find "//" path))
      ?=(~ (find "/./" tail))
      ?=(~ (find "/../" tail))
  ==
::
++  valid
  |=  sources=(list @t)
  ^-  ?
  ?&  (lte (lent sources) 16)
      =((lent sources) ~(wyt in (silt sources)))
      (levy sources url-valid)
  ==
::
++  scope
  |=  sources=(list @t)
  ^-  @t
  (rap 3 ~['automatic-input-v1\0a' (join:ci-plan (sort sources aor) '\0a')])
::
++  envelope
  |=  sources=(list @t)
  ^-  json
  (pairs:enjs:format ~[['version' n+'1'] ['sources' [%a (turn sources |=(s=@t s+s))]]])
::
++  captured
  |=  [s=state-0:ci id=candidate-id:ci]
  ^-  (list @t)
  (~(gut by input-snapshots.s) id ~)
::
::  Shared by the actual action and native semantic vectors. Check authority
::  and the observed generation before changing even an empty list.
++  edit
  |=  [s=state-0:ci repo=@t sources=(list @t) expected=@ud allowed=?]
  ^-  (each state-0:ci @t)
  ?.  allowed  [%| 'ci-policy authority is required to edit automatic inputs']
  ?.  =(expected (~(gut by generations.s) repo 0))
    [%| 'CI policy changed; reload before editing automatic inputs']
  ?.  (valid sources)
    [%| 'automatic inputs require at most 16 distinct canonical https://DNS-host/path URLs; no credentials, ports, queries, fragments, escapes or dot segments']
  [%& s(automatic-inputs (~(put by automatic-inputs.s) repo (sort sources aor)))]
::
++  string-at
  |=  [key=@t jon=json]
  ^-  (unit @t)
  ?.  ?=([%o *] jon)  ~
  =/  v=(unit json)  (~(get by p.jon) key)
  ?~  v  ~
  ?.(?=([%s *] u.v) ~ `p.u.v)
::
++  scope-sources
  |=  text=@t
  ^-  (unit (list @t))
  =/  prefix=@t  'automatic-input-v1\0a'
  ?.  =(prefix (end [3 (met 3 prefix)] text))  ~
  =/  rest=@t  (rsh [3 (met 3 prefix)] text)
  =/  urls=(list @t)
    ?:  =('' rest)  ~
    (turn (split-on:ci-provenance (trip rest) '\0a') crip)
  ?.  &((valid urls) =(text (scope urls)))  ~
  `urls
::
::  The daemon is an authenticated producer. Bind its reported owner ceiling
::  and measurements to this captured policy, then bind the full text into the
::  automatic lock digest. Neither response JSON nor notices can widen policy.
++  evidence-valid
  |=  [text=@t sources=(list @t) nodes=(list dep-node:ci)]
  ^-  ?
  ?:  (gth (met 3 text) 65.536)  %.n
  =/  parsed=(unit json)  (de:json:html text)
  ?~  parsed  %.n
  =/  jon=json  u.parsed
  ?.  ?=([%o *] jon)  %.n
  ?.  =(`(scope sources) (string-at 'policy' jon))  %.n
  ?.  =(`(context-digest:ci-dispatch (scope sources)) (string-at 'policyId' jon))  %.n
  =/  ceiling=(unit @t)  (string-at 'ceiling' jon)
  ?~  ceiling  %.n
  =/  permitted=(unit (list @t))  (scope-sources u.ceiling)
  ?~  permitted  %.n
  ?.  =(`(context-digest:ci-dispatch u.ceiling) (string-at 'ceilingId' jon))  %.n
  =/  receipts=(unit json)  (~(get by p.jon) 'acquisitions')
  ?~  receipts  %.n
  ?.  ?=([%a *] u.receipts)  %.n
  ?:  (gth (lent p.u.receipts) 256)  %.n
  ?.  (levy p.u.receipts |=(r=json (receipt-valid r sources u.permitted nodes)))  %.n
  %+  levy  nodes
  |=  n=dep-node:ci
  ?^  refusal.n  %.y
  ?.  =(%download kind.n)  ?=(?(%local %reusable) kind.n)
  (lien p.u.receipts |=(r=json (receipt-matches r n)))
::
++  receipt-matches
  |=  [r=json n=dep-node:ci]
  ^-  ?
  ?.  ?=([%o *] r)  %.n
  ?&  =(`origin.n (string-at 'url' r))
      =(`sha256.n (string-at 'sha256' r))
      =(`(numb:enjs:format size.n) (~(get by p.r) 'size'))
  ==
::
++  receipt-valid
  |=  [r=json sources=(list @t) ceiling=(list @t) nodes=(list dep-node:ci)]
  ^-  ?
  =/  url=(unit @t)  (string-at 'url' r)
  =/  target=(unit @t)  (string-at 'resolvedUrl' r)
  ?~  url  %.n
  ?~  target  %.n
  ?&  (lien sources |=(s=@t =(s u.url)))
      (lien sources |=(s=@t =(s u.target)))
      (lien ceiling |=(s=@t =(s u.url)))
      (lien ceiling |=(s=@t =(s u.target)))
      (lien nodes |=(n=dep-node:ci &(?=(%download kind.n) (receipt-matches r n))))
  ==
--
