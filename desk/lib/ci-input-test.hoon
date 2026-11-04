/-  ci
/+  ci-input, ci-dispatch, ci-provenance, ci-resolve, ci-resolve-test
|%
++  vectors
  ^-  (list [name=@t ok=?])
  =/  url=@t  'https://inputs.example/tool'
  =/  desired=(list @t)  ~[url]
  =/  scope=@t  (scope:ci-input desired)
  =/  s=state-0:ci  *state-0:ci
  =/  denied  (edit:ci-input s 'demo' ~ 0 %.n)
  =/  stale  (edit:ci-input s 'demo' desired 1 %.y)
  =/  good  (edit:ci-input s 'demo' desired 0 %.y)
  ?>  ?=(%& -.good)
  =/  n=dep-node:ci  *dep-node:ci
  =.  n
    n(kind %download, uses url, origin url, sha256 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', size 5)
  =/  receipt=json
    %-  pairs:enjs:format
    :~  ['url' s+url]  ['resolvedUrl' s+url]
        ['sha256' s+sha256.n]  ['size' n+'5']
    ==
  =/  evidence=json
    %-  pairs:enjs:format
    :~  ['policy' s+scope]
        ['policyId' s+(context-digest:ci-dispatch scope)]
        ['ceiling' s+scope]
        ['ceilingId' s+(context-digest:ci-dispatch scope)]
        ['acquisitions' [%a ~[receipt]]]
    ==
  =/  text=@t  (en:json:html evidence)
  =/  empty=@t
    %-  en:json:html
    %-  pairs:enjs:format
    :~  ['policy' s+(scope:ci-input ~)]
        ['policyId' s+(context-digest:ci-dispatch (scope:ci-input ~))]
        ['ceiling' s+(scope:ci-input ~)]
        ['ceilingId' s+(context-digest:ci-dispatch (scope:ci-input ~))]
        ['acquisitions' [%a ~]]
    ==
  :~  ['absent policy is empty deny' =(~ (captured:ci-input s 0v1))]
      ['empty canonical scope is explicit' =('automatic-input-v1\0a' (scope:ci-input ~))]
      ['exact HTTPS source valid' (url-valid:ci-input url)]
      ['host suffix is a distinct input' !=(url 'https://inputs.example.evil/tool')]
      ['public DNS names with simple paths supported' (url-valid:ci-input 'https://repo.de/a-1_2.tgz')]
      ['local IP form refuses' !(url-valid:ci-input 'https://127.0.0.1/a')]
      ['mapped IPv6 form refuses' !(url-valid:ci-input 'https://[::ffff:127.0.0.1]/a')]
      ['userinfo refuses' !(url-valid:ci-input 'https://user@inputs.example/tool')]
      ['port refuses' !(url-valid:ci-input 'https://inputs.example:443/tool')]
      ['dot segments refuse' !(url-valid:ci-input 'https://inputs.example/a/../tool')]
      ['encoded path refuses' !(url-valid:ci-input 'https://inputs.example/%2ftool')]
      ['query refuses' !(url-valid:ci-input 'https://inputs.example/tool?x=1')]
      ['duplicate policies refuse' !(valid:ci-input ~[url url])]
      ['unauthorized edit refuses even empty removal' ?=(%| -.denied)]
      ['stale edit refuses' ?=(%| -.stale)]
      ['operator edit stores exact sources' =(`desired (~(get by automatic-inputs.p.good) 'demo'))]
      ['desired edit never invents admission snapshot' =(~ input-snapshots.p.good)]
      ['a fresh state has no automatic input authority' =([~ ~ ~ ~] [automatic-inputs input-snapshots input-evidence resolver-inputs]:*state-0:ci)]
      ['serializer emits version and sources' =((pairs:enjs:format ~[['version' n+'1'] ['sources' [%a ~[s+url]]]]) (envelope:ci-input desired))]
      ['scope canonical order' =('automatic-input-v1\0ahttps://a.example/x\0ahttps://z.example/y' (scope:ci-input ~['https://z.example/y' 'https://a.example/x']))]
      ['measured permitted download accepted' (evidence-valid:ci-input text desired ~[n])]
      ['missing evidence refuses' !(evidence-valid:ci-input '' desired ~[n])]
      ['wrong policy refuses' !(evidence-valid:ci-input text ~ ~[n])]
      ['wrong immutable bytes refuse' !(evidence-valid:ci-input text desired ~[n(size 6)])]
      ['dependency-free default deny accepted' (evidence-valid:ci-input empty ~ ~)]
      ['default deny cannot reuse cache as a fetch receipt' !(evidence-valid:ci-input empty ~ ~[n])]
      ['production resolver ownership transitions' test-resolver-lifecycle:ci-resolve-test]
  ==
::
++  test-automatic-input-policy
  ^-  ?
  (levy vectors |=([name=@t ok=?] ok))
--
