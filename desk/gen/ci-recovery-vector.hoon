::  ci-recovery-vector: the cross-language recovery command vector
::  (legacy-recovery UI ruling 01; contract §8b).  The reference command
::  below is the one runner/internal/sig/recovery_test.go signs with the
::  same fixed seed; both sides must produce the same jam bytes, and every
::  single-field mutation must fail to verify against the reference
::  signature.  An assignment's message over the same fields is another
::  noun, and refuses too.  The generator prints the jam hex, the
::  signature hex and the counts, and ends in a loobean: %.y only when the
::  jam and the signature match the Go side's pinned bytes, the reference
::  verifies, and EVERY mutation refuses.
::
::    NOT RUN in the source stage that wrote it: it needs a ship.
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
=/  recipient=@uv  (parse-uv '0v1.daemon')
=/  command=@uv  (parse-uv '0v2.command')
=/  nonce=@uv  (parse-uv '0v3.nonce')
=/  expiry=@ud  1.900.000.000
=/  selection=@t  'ci-0v4.att/microvm///0/0//1726000000/1'
=/  revision=@ud  1
=/  evidence=@t  'abababababababababababababababababababababababababababababababab'
=/  message=@
  %:  message-bytes:ci-recovery
    recipient  command  'release-legacy'  expiry  nonce  selection  revision  evidence
  ==
=/  jam-hex=@t  (hex-bytes:ci-provenance message (met 3 message))
::  what the Go side printed for the same message (recovery_test.go)
::
=/  expected-jam=@t
  %+  rap  3
  :~  '017eb9b2b137bb32b97c1cf02fb64eb501967695b59819c057ae8cad2c6caeac85adec2c6c2c1ff001667fe201d7b18bef01d0652cad05c68ec6258c8eeea52d6d4ceecdaeede5e505e605e6e525e646c6060606060606e6258e01f81f26162616261626162616261626162616261626162616261626162616261626162616261626162616261626162616261626162616261626162616261626162606'
  ==
=/  sig=@ux  (sign-raw:ed:crypto message pub.pair sek.pair)
=/  sig-hex=@t  (hex-bytes:ci-provenance sig 64)
::  the Go side's signature over the same bytes with the same seed
::
=/  expected-sig=@t
  '887ccc2dbb85ef586307e68b640587b4677e7aadda26d9e34c5f3910bbd977cc15956132cf7a9ee7fc8b212781890337d64f87c9ac5f5625d4301928c8cc5c03'
=/  sig-matches=?  =(sig-hex expected-sig)
=/  verifies=?  (veri:ed:crypto sig message pub.pair)
::  every single-field mutation of the message must refuse the signature
::
=/  mutations=(list [name=@t message=@])
  :~  ['recipient' (message-bytes:ci-recovery (parse-uv '0v9') command 'release-legacy' expiry nonce selection revision evidence)]
      ['command' (message-bytes:ci-recovery recipient (parse-uv '0v9') 'release-legacy' expiry nonce selection revision evidence)]
      ['operation' (message-bytes:ci-recovery recipient command 'release' expiry nonce selection revision evidence)]
      ['expiry' (message-bytes:ci-recovery recipient command 'release-legacy' +(expiry) nonce selection revision evidence)]
      ['nonce' (message-bytes:ci-recovery recipient command 'release-legacy' expiry (parse-uv '0v9') selection revision evidence)]
      ['selection' (message-bytes:ci-recovery recipient command 'release-legacy' expiry nonce 'ci-0v4.att/microvm///0/0//1726000000/2' revision evidence)]
      ['revision' (message-bytes:ci-recovery recipient command 'release-legacy' expiry nonce selection 2 evidence)]
      ['evidence' (message-bytes:ci-recovery recipient command 'release-legacy' expiry nonce selection revision 'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd')]
  ==
=/  refused=(list @t)
  %+  murn  mutations
  |=  [name=@t m=@]
  ?:((veri:ed:crypto sig m pub.pair) ~ `name)
=/  accepted=(list @t)
  %+  murn  mutations
  |=  [name=@t m=@]
  ?:((veri:ed:crypto sig m pub.pair) `name ~)
::  an assignment's message over the same fields is another noun
::
=/  assign=@  (jam [2 recipient command 'release-legacy' expiry nonce selection revision evidence])
=/  assign-refused=?  !(veri:ed:crypto sig assign pub.pair)
=/  jam-matches=?  =(jam-hex expected-jam)
=/  passed=@ud
  ;:  add
      ?:(jam-matches 1 0)
      ?:(sig-matches 1 0)
      ?:(verifies 1 0)
      ?:(assign-refused 1 0)
      (lent refused)
  ==
=/  total=@ud  (add 4 (lent mutations))
~&  [%jam-hex jam-hex]
~&  [%jam-matches-go jam-matches]
~&  [%sig-hex sig-hex]
~&  [%sig-matches-go sig-matches]
~&  [%reference-verifies verifies]
~&  [%assign-refused assign-refused]
~&  [%mutations-refused (lent refused) %of (lent mutations)]
~&  [%mutations-accepted accepted]
~&  (crip "passed={<passed>} of={<total>}")
?&  jam-matches
    sig-matches
    verifies
    assign-refused
    =((lent refused) (lent mutations))
    ?=(~ accepted)
==
