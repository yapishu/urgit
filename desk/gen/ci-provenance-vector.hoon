::  ci-provenance-vector: the cross-language manifest vector (P10; contract
::  §5; version 3 binds the run's event, Delivery 1A; version 4 a job's
::  needs context and the attempts it came from, Delivery 1B; version 5
::  the identity of the event the run was admitted for, Delivery 1C).  The reference
::  manifest below is the one runner/internal/sig/
::  manifest_test.go signs with the same fixed seed; both sides must
::  produce the same jam bytes, and every single-field mutation must fail
::  to verify against the reference signature.  The generator prints the
::  jam hex, the signature hex, the count, and ends in a loobean: %.y only
::  when the jam matches the Go side's pinned bytes, the reference
::  verifies, and EVERY mutation refuses.  Correction 01 adds the wire:
::  the manifest object the controller emits (manifest-json) carries every
::  signed field and decodes back to the signed noun.  The lock digest and
::  the policy predicates have their own vector (ci-policy-vector).
::
/-  ci
/+  ci-provenance, ci-recovery
:-  %say
|=  *
:-  %noun
=/  parse-uv
  |=  text=@t
  ^-  @uv
  =/  digits=tape  (skip (trip text) |=(c=@tD =('.' c)))
  =/  body=tape  ?:(=("0v" (scag 2 digits)) (slag 2 digits) digits)
  (rash (crip body) (bass 32 (plus siv:ab)))
::  the fixed seed: bytes 0x01..0x20, byte i the atom's i-th byte
::
=/  seed=@
  =/  i=@ud  0
  =/  acc=@  0
  |-
  ?:  =(i 32)  acc
  $(i +(i), acc (add acc (lsh [3 i] +(i))))
=/  pair  (luck:ed:crypto seed)
=/  =manifest:ci-provenance
  :*  (parse-uv '0v4.incar')
      'erpit'
      'refs/heads/master'
      (parse-uv '0v5.cand')
      'a6d15eddefa898250bf5f656441a55a80273f751'
      '0000000000000000000000000000000000000abc'
      '1111111111111111111111111111111111111111111111111111111111111111'
      7
      'suite.yml'
      'suite'
      'trusted'
      'vm'
      'required'
      'locked'
      ''
      'workflow_dispatch'
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
      'd3c9ae8d4bf4c5ef60aa2d3e6e9d8a4c5b3f0e1d2c3b4a5968778695a4b3c2d1'
      'build=0v6.prod,lint=0v7.lint'
      'workflow_dispatch suite.yml request run-1'
  ==
=/  recipient=@uv  (parse-uv '0v1.daemon')
=/  attempt=@uv  (parse-uv '0v2.attempt')
=/  nonce=@uv  (parse-uv '0v3.nonce')
=/  expiry=@ud  1.900.000.000
=/  message=@  (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce manifest)
=/  jam-hex=@t  (hex-bytes:ci-provenance message (met 3 message))
::  what the Go side printed for the same message (manifest_test.go)
::
=/  expected-jam=@t
  %+  rap  3
  :~  'e106fc8bad536d80a567eb7a5706f8c2e6e6d2cedc011f60f6271e701dbbf81e90b7625732c05326'
      '0797460fc0835c99d9dc0b5a5918d9dc4b5bd81c5d993ce0b5ab5803a04f980d594c4d1919599959'
      '184e0e8e4c0d8c98598d994d8d0d0d4d4c584d4d180e8ccccd8cd94d4d1c007f6060606060606060'
      '6060606060606060606060606060606060606060606060606060606060c2c4c601d03f2626262626'
      '26262626262626262626262626262626262626262626262626262626262626262626262626262626'
      '2626262626262626262626262626262626260e3f80c75c5d1a5d994b5e1b3bc033579746570ef0d2'
      'c9d5cdd19591036fd70ef0cb95c5d5a5c99591037c6c6f636b65e40cc0c3dd9bdc9a19dbdbdd1759'
      'da1c5c18dd183a00fe8b85dde0c4d88899e198c1c48c999585d1c4d0c4d0c09095d5908595c9c8c8'
      'cc88c1c0ccd8c484cde4d8c4dcdc84e58c89d1c4c09899d9c498c9c0c0c4d4849103a03fd9cc584e'
      '58190e198d9819cd584d99990d4c58980cd94c994d590e194e18cd588dd88c194c590c99ccd88c18'
      '4d584d8e0dcecd0d8e4d4e4d188dd8cc980c591c805fb1ba3436b21e183b1b1738b9373216b63437'
      'ba1e18bb1b17b634373a008deedee4d6ccd8deeebec8d2e6e0c2e8c6d040e6ead2e8ca5cf2dad840'
      'e4cae2eacae6e840e4eadc5a62'
  ==
=/  sig=@ux  (sign-raw:ed:crypto message pub.pair sek.pair)
=/  sig-hex=@t  (hex-bytes:ci-provenance sig 64)
::  the Go side's signature over the same bytes with the same seed
::
=/  expected-sig=@t
  'f6ba9c2b29b8cbfd7b7aced72187cfd201c2e6ece86d0a0dd345ec989d45fb21f5b0c64fbeb67aac611bc6e687ed580a73b4b891dd9433c878826f8262605e0a'
=/  sig-matches=?  =(sig-hex expected-sig)
=/  verifies=?  (veri:ed:crypto sig message pub.pair)
::  every single-field mutation of the message must refuse the signature
::
=/  mutations=(list [name=@t message=@])
  =/  mm  manifest
  :~  ['recipient' (message-bytes:ci-provenance (parse-uv '0v9') attempt 'assign' expiry nonce mm)]
      ['attempt' (message-bytes:ci-provenance recipient (parse-uv '0v9') 'assign' expiry nonce mm)]
      ['operation' (message-bytes:ci-provenance recipient attempt 'grant:X' expiry nonce mm)]
      ['expiry' (message-bytes:ci-provenance recipient attempt 'assign' +(expiry) nonce mm)]
      ['nonce' (message-bytes:ci-provenance recipient attempt 'assign' expiry (parse-uv '0v9') mm)]
      ['incarnation' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(incarnation (parse-uv '0v9')))]
      ['repo' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(repo 'other'))]
      ['ref' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(ref 'refs/heads/dev'))]
      ['candidate' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(candidate (parse-uv '0v9')))]
      ['oid' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(oid 'a6d15eddefa898250bf5f656441a55a80273f752'))]
      ['baseline' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(baseline ''))]
      ['lock' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(lock '2222222222222222222222222222222222222222222222222222222222222222'))]
      ['generation' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(generation 8))]
      ['workflow' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(workflow 'fixtures.yml'))]
      ['job' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(job 'plan'))]
      ['trust' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(trust 'untrusted'))]
      ['sandbox' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(sandbox 'container'))]
      ['mode' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(mode 'trial'))]
      ['network' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(network 'integration'))]
      ['network-scope' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(scope 'tcp:198.51.100.20:8472'))]
      ['event' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(event 'push'))]
      ['context' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(context 'ca7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'))]
      ['needs' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(needs 'e3c9ae8d4bf4c5ef60aa2d3e6e9d8a4c5b3f0e1d2c3b4a5968778695a4b3c2d1'))]
      ['needs-dropped' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(needs ''))]
      ['prerequisites' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(prerequisites 'build=0v8.stale,lint=0v7.lint'))]
      ['prerequisites-dropped' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(prerequisites ''))]
      ['trigger' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(trigger 'workflow_dispatch suite.yml request run-2'))]
      ['trigger-dropped' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(trigger ''))]
      ['trigger-event' (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce mm(trigger 'schedule suite.yml#0 due 2026-10-16T05:30:00Z occurrence 0v1'))]
  ==
=/  refused=(list @t)
  %+  murn  mutations
  |=  [name=@t m=@]
  ?:((veri:ed:crypto sig m pub.pair) ~ `name)
=/  accepted=(list @t)
  %+  murn  mutations
  |=  [name=@t m=@]
  ?:((veri:ed:crypto sig m pub.pair) `name ~)
::  a v1-shaped message over the same fields is a different noun
::
=/  v1=@  (jam [recipient attempt 'assign' expiry nonce])
=/  v1-refused=?  !(veri:ed:crypto sig v1 pub.pair)
=/  jam-matches=?  =(jam-hex expected-jam)
::  the same assignment of authorization epoch 1 (legacy-replay-upgrade
::  ruling 01; INTEGRATION.md §11.15): its nonce under the epoch
::  (epoch-nonce), whose bytes the Go side pins (epoch_test.go); a
::  signature over it does not verify for the nonce's low bits alone
::
=/  epoch-message=@
  %:  message-bytes:ci-provenance
    recipient
    attempt
    'assign'
    expiry
    (epoch-nonce:ci-recovery 1 nonce)
    manifest
  ==
=/  epoch-jam-hex=@t  (hex-bytes:ci-provenance epoch-message (met 3 epoch-message))
=/  expected-epoch-jam=@t
  %+  rap  3
  :~  'e106fc8bad536d80a567eb7a5706f8c2e6e6d2cedc011f60f6271e8001c72ebe0300000000000000'
      '000000008001792b7625033c65727069f4003cc89599cdbda0958591cdbdb485cdd195c9035ebb8a'
      '3500fa84d990c5d4949191959985e1e4e0c8d4c08899d598d9d4d8d0d0c484d5d484e1c0c8dccc98'
      'ddd4c401f00706060606060606060606060606060606060606060606060606060606060606060606'
      '0606264c6c1c00fd6362626262626262626262626262626262626262626262626262626262626262'
      '62626262626262626262626262626262626262626262626262626262626262e2f00378ccd5a5d195'
      'b9e4b5b1033c73756974e5002f9d5cdd1c5d1939f076ed00bf5c595c5d9a5c1939c0c7f636b65646'
      'ce003cdcbdc9ad99b1bddd7d91a5cdc185d18da103e0bf58d80d4e8c8d98198e194ccc985959184d'
      '0c4d0c0d0c59590d5958998c8ccc8c180ccc8c4d4cd84c8e4dcccd4d58ce98184d0c8c99994d8c99'
      '0c0c4c4c4d183900fa93cd8ce58495e190d18899d18cd59499d9c08485c990cd94d994e590e184d1'
      '8cd588cd98c194c590c98ccd88d184d5e4d8e0dcdce0d8e4d484d188cd8cc990c501f815ab4b6323'
      'eb81b1b37181937b2363614b73a3eb81b1bb71614b73a303d0e8ee4d6ecd8cededee8b2c6d0e2e8c'
      '6e0c0d64ae2e8daecc25af8d0d44ae2caeae6c8e0e44aecead2506'
  ==
=/  epoch-jam-matches=?  =(epoch-jam-hex expected-epoch-jam)
=/  epoch-sig=@ux  (sign-raw:ed:crypto epoch-message pub.pair sek.pair)
=/  epoch-low-refused=?  !(veri:ed:crypto epoch-sig message pub.pair)
::  the manifest as an assignment carries it (Delivery 1B correction
::  01): the controller's one serializer, manifest-json, emits every signed
::  field; its object equals the pinned emission the runner's Go test
::  decodes (runner/internal/sig/testdata/reference-manifest-v5.json);
::  decoded here as the runner decodes it, it is the signed manifest and
::  the reference signature verifies.  the 1B emission, without needs and
::  prerequisites, decodes those as empty and the signature refuses it
::
=/  signed-fields=(list @t)
  :~  'incarnation'  'repo'  'ref'  'candidate'  'oid'  'baseline'  'lock'
      'generation'  'workflow'  'job'  'trust'  'sandbox'  'mode'  'network'
      'network-scope'  'event'  'context'  'needs'  'prerequisites'  'trigger'
  ==
=/  rendered=json  (manifest-json:ci-provenance manifest)
=/  pinned-text=@t
  %+  rap  3
  :~  '{"incarnation":"0v4.incar","repo":"erpit","ref":"refs/heads/master","candidate":'
      '"0v5cand","oid":"a6d15eddefa898250bf5f656441a55a80273f751","baseline":"000000000'
      '0000000000000000000000000000abc","lock":"111111111111111111111111111111111111111'
      '1111111111111111111111111","generation":7,"workflow":"suite.yml","job":"suite","'
      'trust":"trusted","sandbox":"vm","mode":"required","network":"locked","network-sc'
      'ope":"","event":"workflow_dispatch","context":"ba7816bf8f01cfea414140de5dae2223b'
      '00361a396177a9cb410ff61f20015ad","needs":"d3c9ae8d4bf4c5ef60aa2d3e6e9d8a4c5b3f0e'
      '1d2c3b4a5968778695a4b3c2d1","prerequisites":"build=0v6.prod,lint=0v7.lint","trig'
      'ger":"workflow_dispatch suite.yml request run-1"}'
  ==
=/  pinned=(unit json)  (de:json:html pinned-text)
=/  decode
  |=  jon=json
  ^-  (unit manifest:ci-provenance)
  ?.  ?=([%o *] jon)  ~
  =/  fields=(map @t json)  p.jon
  =/  text
    |=  key=@t
    ^-  @t
    =/  v=(unit json)  (~(get by fields) key)
    ?~  v  ''
    ?.  ?=([%s *] u.v)  ''
    p.u.v
  =/  gen=(unit json)  (~(get by fields) 'generation')
  =/  generation=@ud
    ?.  ?=([~ %n *] gen)  0
    (fall (rush p.u.gen dim:ag) 0)
  :-  ~
  :*  (parse-uv (text 'incarnation'))
      (text 'repo')
      (text 'ref')
      (parse-uv (text 'candidate'))
      (text 'oid')
      (text 'baseline')
      (text 'lock')
      generation
      (text 'workflow')
      (text 'job')
      (text 'trust')
      (text 'sandbox')
      (text 'mode')
      (text 'network')
      (text 'network-scope')
      (text 'event')
      (text 'context')
      (text 'needs')
      (text 'prerequisites')
      (text 'trigger')
  ==
=/  emitted-keys=(set @t)
  ?.  ?=([%o *] rendered)  ~
  ~(key by p.rendered)
=/  short=json
  ?.  ?=([%o *] rendered)  ~
  [%o (~(del by (~(del by p.rendered) 'needs')) 'prerequisites')]
=/  decoded=(unit manifest:ci-provenance)  (decode rendered)
=/  decoded-short=(unit manifest:ci-provenance)  (decode short)
=/  emits-every-field=?  =((silt signed-fields) emitted-keys)
=/  pinned-matches=?  =(pinned `rendered)
=/  decodes-to-signed=?  =(decoded `manifest)
=/  decoded-verifies=?
  ?~  decoded  %.n
  %^  veri:ed:crypto
    sig
    (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce u.decoded)
  pub.pair
=/  short-refused=?
  ?~  decoded-short  %.n
  ?&  =('' needs.u.decoded-short)
      =('' prerequisites.u.decoded-short)
      !(veri:ed:crypto sig (message-bytes:ci-provenance recipient attempt 'assign' expiry nonce u.decoded-short) pub.pair)
  ==
=/  passed=@ud
  ;:  add
      ?:(jam-matches 1 0)
      ?:(sig-matches 1 0)
      ?:(verifies 1 0)
      ?:(v1-refused 1 0)
      ?:(epoch-jam-matches 1 0)
      ?:(epoch-low-refused 1 0)
      ?:(emits-every-field 1 0)
      ?:(pinned-matches 1 0)
      ?:(decodes-to-signed 1 0)
      ?:(decoded-verifies 1 0)
      ?:(short-refused 1 0)
      (lent refused)
  ==
=/  total=@ud  (add 11 (lent mutations))
~&  [%manifest-id (manifest-id:ci-provenance manifest)]
~&  [%jam-hex jam-hex]
~&  [%jam-matches-go jam-matches]
~&  [%sig-hex sig-hex]
~&  [%sig-matches-go sig-matches]
~&  [%reference-verifies verifies]
~&  [%v1-refused v1-refused]
~&  [%epoch-jam-hex epoch-jam-hex]
~&  [%epoch-jam-matches-go epoch-jam-matches]
~&  [%epoch-low-refused epoch-low-refused]
~&  [%manifest-json-emits-every-field emits-every-field]
~&  [%manifest-json-matches-pinned pinned-matches]
~&  [%manifest-json-decodes-to-signed decodes-to-signed]
~&  [%manifest-json-decoded-verifies decoded-verifies]
~&  [%manifest-json-1b-shape-refused short-refused]
~&  [%mutations-refused (lent refused) %of (lent mutations)]
~&  [%mutations-accepted accepted]
~&  (crip "passed={<passed>} of={<total>}")
?&  jam-matches
    sig-matches
    verifies
    v1-refused
    epoch-jam-matches
    epoch-low-refused
    emits-every-field
    pinned-matches
    decodes-to-signed
    decoded-verifies
    short-refused
    =((lent refused) (lent mutations))
    ?=(~ accepted)
==
