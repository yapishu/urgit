::  CI object-store URL signing: the existing SigV4 signer under a CI key
::  prefix that LFS cleanup never scans, namespaced by repository, run,
::  attempt and trust class.  the trust class is enforced here, at signing
::  time, not by runner cooperation.
::
/-  ci
/+  git-storage
|%
+$  settings
  (unit [credentials=credentials:git-storage configuration=configuration:git-storage])
::
::  sha-256 of an empty body: a signed GET carries no payload
::
++  empty-payload-hash
  'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
::
++  object-key
  |=  [repo=@t run=@t attempt=@t =trust:ci name=@t]
  ^-  @t
  (rap 3 ~['ci/' repo '/' run '/' attempt '/' trust '/' name])
::
::  an upload request for an attempt into its own trust namespace: the
::  URL plus the headers that authorize it.  this is a header-authorized
::  SigV4 request, not a presigned URL, so its lifetime is the SigV4
::  request window: the store accepts it while x-amz-date is within
::  15 minutes of its own clock.  a standalone expiring URL is later work.
::
++  sign-put
  |=  $:  =settings
          repo=@t
          run=@t
          attempt=@t
          =trust:ci
          name=@t
          content-type=@t
          payload-hash=@t
          now=@da
      ==
  ^-  (unit signed-request:git-storage)
  ?~  settings  ~
  :-  ~
  %:  sign-hash:git-storage
    'PUT'
    content-type
    payload-hash
    credentials.u.settings
    configuration.u.settings
    (object-key repo run attempt trust name)
    now
  ==
::
::  a download request, URL plus authorizing headers, with the same SigV4
::  lifetime as sign-put (x-amz-date within 15 minutes of the store's
::  clock).  refused outright when the requesting attempt's trust class
::  differs from the key's: an untrusted run never reads a trusted cache
::  and a trusted run never reads an untrusted one.
::
++  sign-get
  |=  $:  =settings
          requester=trust:ci
          repo=@t
          run=@t
          attempt=@t
          =trust:ci
          name=@t
          now=@da
      ==
  ^-  (unit signed-request:git-storage)
  ?~  settings  ~
  ?.  =(requester trust)  ~
  :-  ~
  %:  sign-hash:git-storage
    'GET'
    ''
    empty-payload-hash
    credentials.u.settings
    configuration.u.settings
    (object-key repo run attempt trust name)
    now
  ==
::
::  a presigned download URL (D2, astra §2): the standard SigV4 query-string
::  form a browser can follow from a 302 with no headers of its own.  the
::  canonical request signs the host header alone with an UNSIGNED-PAYLOAD
::  hash; the store checks X-Amz-Date + X-Amz-Expires against its clock.
::  the expiry is bounded to fifteen minutes and the trust class is
::  checked exactly as sign-get checks it.  the existing sign-get and
::  sign-put arms are not touched; this is additive.
::
++  max-presign  ~m15
::
++  presign-get
  |=  $:  =settings
          requester=trust:ci
          repo=@t
          run=@t
          attempt=@t
          =trust:ci
          name=@t
          expires=@dr
          now=@da
      ==
  ^-  (unit @t)
  ?.  =(trust requester)  ~
  (presign-key settings (object-key repo run attempt trust name) expires now)
::
::  the content-addressed key of a mirrored download (P4 D4): the same
::  bytes are one object whoever resolved them
::
++  download-key
  |=  sha256=@t
  ^-  @t
  (rap 3 ~['ci/downloads/' sha256])
::
::  an upload of a mirrored download: header-authorized, the payload
::  hash being the object's own sha256, so the store refuses other bytes
::
++  sign-put-download
  |=  [=settings sha256=@t now=@da]
  ^-  (unit signed-request:git-storage)
  ?~  settings  ~
  :-  ~
  %:  sign-hash:git-storage
    'PUT'
    'application/octet-stream'
    sha256
    credentials.u.settings
    configuration.u.settings
    (download-key sha256)
    now
  ==
::
::  a presigned GET of any key, for at most max-presign
::
++  presign-key
  |=  [=settings key=@t expires=@dr now=@da]
  ^-  (unit @t)
  ?~  settings  ~
  ?:  |(=(0 expires) (gth expires max-presign))  ~
  =/  seconds=@ud  (div expires ~s1)
  =.  seconds  ?:(=(0 seconds) 1 seconds)
  =/  credentials  credentials.u.settings
  =/  configuration  configuration.u.settings
  =/  host=@t  (endpoint-host:git-storage endpoint.credentials)
  =/  path=@t
    (rap 3 ~['/' current-bucket.configuration '/' key])
  =/  canonical-uri=@t  (uri-encode:git-storage path)
  =/  timestamp=@t  (amz-date:git-storage now)
  =/  date=@t  (date-stamp:git-storage now)
  =/  scope=@t  (rap 3 ~[date '/' region.configuration '/s3/aws4_request'])
  =/  credential=@t  (rap 3 ~[access-key-id.credentials '/' scope])
  ::  the query in canonical order: parameter names sort this way, and
  ::  every value is encoded with '/' reserved (the credential's scope)
  ::
  =/  canonical-query=@t
    %+  rap  3
    :~  'X-Amz-Algorithm=AWS4-HMAC-SHA256'
        '&X-Amz-Credential='  (query-encode credential)
        '&X-Amz-Date='  timestamp
        '&X-Amz-Expires='  (crip (a-co:co seconds))
        '&X-Amz-SignedHeaders=host'
    ==
  =/  canonical-request=@t
    %+  rap  3
    :~  'GET\0a'  canonical-uri  '\0a'  canonical-query  '\0a'
        'host:'  host  '\0a\0a'
        'host\0a'
        'UNSIGNED-PAYLOAD'
    ==
  =/  string-to-sign=@t
    %+  rap  3
    :~  'AWS4-HMAC-SHA256\0a'  timestamp  '\0a'  scope  '\0a'
        (hex-32:git-storage (shay [(met 3 canonical-request) canonical-request]))
    ==
  =/  key=@  (signing-key:git-storage secret-access-key.credentials date region.configuration)
  =/  signature=@t  (hex-32:git-storage (hmac-text:git-storage [32 key] string-to-sign))
  :-  ~
  %+  rap  3
  :~  (endpoint-scheme:git-storage endpoint.credentials)  host  canonical-uri
      '?'  canonical-query  '&X-Amz-Signature='  signature
  ==
::
::  RFC 3986 encoding for a query value: only the unreserved characters
::  pass, so a '/' becomes %2F (uri-encode keeps '/' for object paths)
::
++  query-encode
  |=  text=@t
  ^-  @t
  =/  input=tape  (trip text)
  =/  output=tape  ~
  |-
  ?~  input  (crip output)
  =/  char=@tD  i.input
  =/  unreserved=?
    ?|  &((gte char 'A') (lte char 'Z'))
        &((gte char 'a') (lte char 'z'))
        &((gte char '0') (lte char '9'))
        =(char '-')  =(char '_')  =(char '.')  =(char '~')
    ==
  ?:  unreserved
    $(input t.input, output (snoc output char))
  =/  digit=$-(@ud @tD)
    |=  value=@ud
    ?:  (lth value 10)  (add '0' value)
    (add 'A' (sub value 10))
  $(input t.input, output (weld output ~['%' (digit (div char 16)) (digit (mod char 16))]))
::
::  the names an attempt may upload under (D2): the finished act stream,
::  the step summary, or an artifact with a plain file name.  anything
::  else is refused before signing.  a plain name is [A-Za-z0-9._-]+ with
::  no leading dot, so no traversal, no separator and no hidden file.
::
++  upload-name-allowed
  |=  name=@t
  ^-  ?
  ?:  =('log.jsonl' name)  %.y
  ?:  =('summary.md' name)  %.y
  =/  prefix=@t  'artifact/'
  ?.  =(prefix (end [3 (met 3 prefix)] name))  %.n
  =/  rest=tape  (slag (met 3 prefix) (trip name))
  ?~  rest  %.n
  ?:  =('.' i.rest)  %.n
  ?:  (gth (lent rest) 128)  %.n
  %+  levy  `tape`rest
  |=  char=@tD
  ?|  &((gte char 'A') (lte char 'Z'))
      &((gte char 'a') (lte char 'z'))
      &((gte char '0') (lte char '9'))
      =(char '-')  =(char '_')  =(char '.')
  ==
::
::  a sha-256 as the daemon reports it: 64 lowercase hex digits
::
++  sha256-text-valid
  |=  text=@t
  ^-  ?
  =/  chars=tape  (trip text)
  ?.  =(64 (lent chars))  %.n
  %+  levy  chars
  |=  char=@tD
  ?|  &((gte char '0') (lte char '9'))
      &((gte char 'a') (lte char 'f'))
  ==
::
::  the ship's %storage settings, read the way %urgit reads them for LFS:
::  ~ unless the agent is running and endpoint, both keys, bucket and
::  region are all set with the %credentials service.  the liveness read
::  comes first because an absent agent answers [~ ~], which no trap sees.
::
++  read-settings
  |=  [our=@p now=@da]
  ^-  settings
  =/  prefix=path  /(scot %p our)/storage/(scot %da now)
  =/  live=(unit ?)
    (mole |.(;;(? .^(* %gu (weld prefix /$)))))
  ?.  ?&(?=(^ live) u.live)  ~
  =/  found-credentials=(unit json)
    (mole |.(.^(json %gx (weld prefix /credentials/json))))
  ?~  found-credentials  ~
  =/  found-configuration=(unit json)
    (mole |.(.^(json %gx (weld prefix /configuration/json))))
  ?~  found-configuration  ~
  =/  get-string
    |=  [jon=json keys=(list @t)]
    ^-  @t
    ?~  keys  ?:(?=([%s *] jon) p.jon '')
    ?.  ?=([%o *] jon)  ''
    =/  value=(unit json)  (~(get by p.jon) i.keys)
    ?~  value  ''
    $(jon u.value, keys t.keys)
  =/  credentials=credentials:git-storage
    :*  (get-string u.found-credentials ~['storage-update' 'credentials' 'endpoint'])
        (get-string u.found-credentials ~['storage-update' 'credentials' 'accessKeyId'])
        (get-string u.found-credentials ~['storage-update' 'credentials' 'secretAccessKey'])
    ==
  =/  configuration=configuration:git-storage
    :*  (get-string u.found-configuration ~['storage-update' 'configuration' 'currentBucket'])
        (get-string u.found-configuration ~['storage-update' 'configuration' 'region'])
    ==
  =/  service=@t
    (get-string u.found-configuration ~['storage-update' 'configuration' 'service'])
  ?.  =('credentials' service)  ~
  ?.  ?&  !=('' endpoint.credentials)
          !=('' access-key-id.credentials)
          !=('' secret-access-key.credentials)
          !=('' current-bucket.configuration)
          !=('' region.configuration)
      ==
    ~
  `[credentials configuration]
--
