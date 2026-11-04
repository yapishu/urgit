::  CI object-store signing vectors: the key prefix, the trust-class
::  refusal at signing time, and the unconfigured-store refusal.
::
/-  ci
/+  ci-storage, git-storage
:-  %say
|=  *
:-  %noun
=/  configured=settings:ci-storage
  `[['https://objects.example' 'EXAMPLEKEY' 'example-secret'] ['git-data' 'local-1']]
=/  when=@da  ~2026.8.16..12.34.56
=/  payload=@t  'ae85361c4307a95c463c809a426a2bc2b69f7c8db52c5a4122cfb2d4b9d5f205'
::  every key sits under the CI prefix, namespaced by repository, run,
::  attempt and trust class; LFS keys live under git-lfs/ and never here
::
?>  =('ci/erpit/run1/att1/trusted/cache.tar' (object-key:ci-storage 'erpit' 'run1' 'att1' %trusted 'cache.tar'))
?>  =('ci/erpit/run1/att1/untrusted/cache.tar' (object-key:ci-storage 'erpit' 'run1' 'att1' %untrusted 'cache.tar'))
::  a read across trust classes is refused at signing time, both ways
::
?>  =(~ (sign-get:ci-storage configured %trusted 'erpit' 'run1' 'att1' %untrusted 'cache.tar' when))
?>  =(~ (sign-get:ci-storage configured %untrusted 'erpit' 'run1' 'att1' %trusted 'cache.tar' when))
::  a same-class read signs a URL whose path starts with the forced prefix
::
=/  same=(unit signed-request:git-storage)
  (sign-get:ci-storage configured %trusted 'erpit' 'run1' 'att1' %trusted 'cache.tar' when)
?>  ?=(^ same)
?>  =('https://objects.example/git-data/ci/erpit/run1/att1/trusted/cache.tar' url.u.same)
?>  ?=(^ (get-header:http 'authorization' headers.u.same))
?>  ?=(^ (get-header:http 'x-amz-date' headers.u.same))
?>  =(`empty-payload-hash:ci-storage (get-header:http 'x-amz-content-sha256' headers.u.same))
=/  untrusted-same=(unit signed-request:git-storage)
  (sign-get:ci-storage configured %untrusted 'erpit' 'run1' 'att1' %untrusted 'cache.tar' when)
?>  ?=(^ untrusted-same)
?>  =('https://objects.example/git-data/ci/erpit/run1/att1/untrusted/cache.tar' url.u.untrusted-same)
::  an upload signs into the attempt's own namespace
::
=/  put=(unit signed-request:git-storage)
  %:  sign-put:ci-storage
    configured
    'erpit'
    'run1'
    'att1'
    %untrusted
    'log.txt'
    'text/plain'
    payload
    when
  ==
?>  ?=(^ put)
?>  =('https://objects.example/git-data/ci/erpit/run1/att1/untrusted/log.txt' url.u.put)
?>  =(`payload (get-header:http 'x-amz-content-sha256' headers.u.put))
?>  ?=(^ (get-header:http 'authorization' headers.u.put))
::  the signature is the same signer LFS uses: same inputs, same request
::
=/  direct=signed-request:git-storage
  %:  sign-hash:git-storage
    'PUT'  'text/plain'  payload
    ['https://objects.example' 'EXAMPLEKEY' 'example-secret']
    ['git-data' 'local-1']
    'ci/erpit/run1/att1/untrusted/log.txt'
    when
  ==
?>  =(direct u.put)
::  with no store configured every arm returns ~
::
?>  =(~ (sign-get:ci-storage ~ %trusted 'erpit' 'run1' 'att1' %trusted 'cache.tar' when))
?>  =(~ (sign-get:ci-storage ~ %untrusted 'erpit' 'run1' 'att1' %untrusted 'cache.tar' when))
?>  =(~ (sign-put:ci-storage ~ 'erpit' 'run1' 'att1' %trusted 'log.txt' 'text/plain' payload when))
::  a presigned download URL (D2): the standard query form, in the
::  attempt's own trust class only, expiring within fifteen minutes; the
::  credential's scope is encoded with '/' reserved
::
=/  presigned=(unit @t)
  (presign-get:ci-storage configured %trusted 'erpit' 'run1' 'att1' %trusted 'log.jsonl' ~m5 when)
?>  ?=(^ presigned)
=/  link=tape  (trip u.presigned)
=/  starts
  |=  [prefix=tape text=tape]
  =(prefix (scag (lent prefix) text))
?>  %+  starts
      "https://objects.example/git-data/ci/erpit/run1/att1/trusted/log.jsonl?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=EXAMPLEKEY%2F20260816%2Flocal-1%2Fs3%2Faws4_request&X-Amz-Date=20260816T123456Z&X-Amz-Expires=300&X-Amz-SignedHeaders=host&X-Amz-Signature="
    link
?>  =(64 (lent (slag (need (find "Signature=" link)) (slag 10 link))))
?>  =(~ (find "authorization" link))
?>  =(~ (presign-get:ci-storage configured %untrusted 'erpit' 'run1' 'att1' %trusted 'log.jsonl' ~m5 when))
?>  =(~ (presign-get:ci-storage configured %trusted 'erpit' 'run1' 'att1' %untrusted 'log.jsonl' ~m5 when))
?>  =(~ (presign-get:ci-storage configured %trusted 'erpit' 'run1' 'att1' %trusted 'log.jsonl' ~m16 when))
?>  =(~ (presign-get:ci-storage configured %trusted 'erpit' 'run1' 'att1' %trusted 'log.jsonl' ~s0 when))
?>  =(~ (presign-get:ci-storage ~ %trusted 'erpit' 'run1' 'att1' %trusted 'log.jsonl' ~m5 when))
::  the same signing inputs sign the same URL; a different expiry signs a
::  different one
::
?>  =(presigned (presign-get:ci-storage configured %trusted 'erpit' 'run1' 'att1' %trusted 'log.jsonl' ~m5 when))
?>  !=(presigned (presign-get:ci-storage configured %trusted 'erpit' 'run1' 'att1' %trusted 'log.jsonl' ~m4 when))
::  the upload name fence (D2): the log, the summary, a plain artifact
::  name; nothing that traverses, hides or leaves the attempt's prefix
::
?>  (upload-name-allowed:ci-storage 'log.jsonl')
?>  (upload-name-allowed:ci-storage 'summary.md')
?>  (upload-name-allowed:ci-storage 'artifact/build.tar.gz')
?>  !(upload-name-allowed:ci-storage '../x')
?>  !(upload-name-allowed:ci-storage 'artifact/../x')
?>  !(upload-name-allowed:ci-storage 'artifact/a/b')
?>  !(upload-name-allowed:ci-storage 'artifact/.hidden')
?>  !(upload-name-allowed:ci-storage 'artifact/')
?>  !(upload-name-allowed:ci-storage 'log.jsonl.bak')
?>  !(upload-name-allowed:ci-storage '')
?>  (sha256-text-valid:ci-storage payload)
?>  !(sha256-text-valid:ci-storage 'abc')
?>  !(sha256-text-valid:ci-storage (crip (weld (scag 63 (trip payload)) "G")))
::  a defaulted trust class is untrusted
::
?>  =(%untrusted *trust:ci)
%.y
