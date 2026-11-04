::  git-http: HTTP request parsing, authentication, and response cards
::
/-  git
/+  server, git-codec, git-gzip, git-protocol, *git-format
|%
++  query-value
  |=  [key=@t args=(list [key=@t value=@t])]
  ^-  (unit @t)
  ?~  args  ~
  ?:  =(key key.i.args)  `value.i.args
  $(args t.args)
::
++  repository-name
  |=  segment=@t
  ^-  @t
  =/  chars=tape  (trip segment)
  ?.  (gte (lent chars) 4)  segment
  ?.  =(".git" (slag (sub (lent chars) 4) chars))  segment
  (crip (scag (sub (lent chars) 4) chars))
::
++  json-at
  |=  [key=@t jon=json]
  ^-  (unit json)
  ?.  ?=([%o *] jon)  ~
  (~(get by p.jon) key)
::
++  string-at
  |=  [key=@t jon=json]
  ^-  (unit @t)
  =/  value=(unit json)  (json-at key jon)
  ?~  value  ~
  ?.  ?=([%s *] u.value)  ~
  `p.u.value
::
++  parse-decimal
  |=  text=@t
  ^-  (unit @ud)
  =/  chars=tape  (trip text)
  ?~  chars  ~
  =/  parse
    |=  [remaining=tape value=@ud]
    ^-  (unit @ud)
    ?~  remaining  `value
    ?.  &((gte i.remaining '0') (lte i.remaining '9'))  ~
    $(remaining t.remaining, value (add (mul value 10) (sub i.remaining '0')))
  (parse chars 0)
::
++  nat-at
  |=  [key=@t jon=json]
  ^-  (unit @ud)
  =/  value=(unit json)  (json-at key jon)
  ?~  value  ~
  ?.  ?=([%n *] u.value)  ~
  (parse-decimal p.u.value)
::
++  bool-at
  |=  [key=@t jon=json]
  ^-  (unit ?)
  =/  value=(unit json)  (json-at key jon)
  ?~  value  ~
  ?.  ?=([%b *] u.value)  ~
  `p.u.value
::
++  string-list-at
  |=  [key=@t jon=json]
  ^-  (unit (list @t))
  =/  value=(unit json)  (json-at key jon)
  ?~  value  ~
  ?.  ?=([%a *] u.value)  ~
  =/  items=(list json)  p.u.value
  =/  out=(list @t)  ~
  |-
  ?~  items  `(flop out)
  ?.  ?=([%s *] i.items)  ~
  $(items t.items, out [p.i.items out])
::
++  webhook-events-at
  |=  [key=@t jon=json]
  ^-  (unit (set webhook-event:git))
  =/  values=(unit (list @t))  (string-list-at key jon)
  ?~  values  ~
  =/  remaining=(list @t)  u.values
  =/  events=(set webhook-event:git)  ~
  |-
  ?~  remaining  `events
  =/  event=(unit webhook-event:git)
    ?:  =('push' i.remaining)  `%push
    ?:  =('tag' i.remaining)  `%tag
    ?:  =('pull-request' i.remaining)  `%pull-request
    ?:  =('issue' i.remaining)  `%issue
    ?:  =('release' i.remaining)  `%release
    ?:  =('clay-sync' i.remaining)  `%clay-sync
    ~
  ?~  event  ~
  $(remaining t.remaining, events (~(put in events) u.event))
::
++  notification-events-at
  |=  [key=@t jon=json]
  ^-  (unit (set notification-event:git))
  =/  values=(unit (list @t))  (string-list-at key jon)
  ?~  values  ~
  =/  remaining=(list @t)  u.values
  =/  events=(set notification-event:git)  ~
  |-
  ?~  remaining  `events
  =/  event=(unit notification-event:git)
    ?:  =('issue' i.remaining)  `%issue
    ?:  =('issue-comment' i.remaining)  `%issue-comment
    ?:  =('pull-request' i.remaining)  `%pull-request
    ?:  =('pull-comment' i.remaining)  `%pull-comment
    ~
  ?~  event  ~
  $(remaining t.remaining, events (~(put in events) u.event))
::
++  ship-list-at
  |=  [key=@t jon=json]
  ^-  (unit (list @p))
  =/  texts=(unit (list @t))  (string-list-at key jon)
  ?~  texts  ~
  =/  remaining=(list @t)  u.texts
  =/  out=(list @p)  ~
  |-
  ?~  remaining  `(flop out)
  =/  parsed=(unit @p)  (slaw %p i.remaining)
  ?~  parsed  ~
  $(remaining t.remaining, out [u.parsed out])
::
++  api-json-payload
  |=  [status=@ud jon=json]
  ^-  simple-payload:http
  :_  `(json-to-octs:server jon)
  :-  status
  :~  ['content-type' 'application/json; charset=utf-8']
      ['cache-control' 'no-store']
  ==
::
++  api-error
  |=  [eyre-id=@ta status=@ud message=@t]
  ^-  (list card:agent:gall)
  %+  give-simple-payload:app:server  eyre-id
  (api-json-payload status (pairs:enjs:format ~[['error' s+message]]))
::
++  api-ok
  |=  [eyre-id=@ta status=@ud]
  ^-  (list card:agent:gall)
  %+  give-simple-payload:app:server  eyre-id
  (api-json-payload status (pairs:enjs:format ~[['ok' b+%.y]]))
::
++  api-json
  |=  [eyre-id=@ta status=@ud jon=json]
  ^-  (list card:agent:gall)
  (give-simple-payload:app:server eyre-id (api-json-payload status jon))
::
++  api-archive
  |=  [eyre-id=@ta name=@t data=octs]
  ^-  (list card:agent:gall)
  %+  give-simple-payload:app:server  eyre-id
  :_  `data
  :-  200
  :~  ['content-type' 'application/x-tar']
      ['content-disposition' (rap 3 ~['attachment; filename="' name '.tar"'])]
      ['cache-control' 'no-store']
  ==
::
++  api-body
  |=  req=inbound-request:eyre
  ^-  (unit json)
  ?~  body.request.req  ~
  (de:json:html q.u.body.request.req)
::
++  parse-capability
  |=  text=@t
  ^-  (unit capability:git)
  ?+  text  ~
    %none  `%none
    %read  `%read
    %write  `%write
  ==
::
::  the policy object the settings panel posts:
::  {"host": "~sampel", "group": "crew", "base": "none", "roles": {"verified": "write"}},
::  "host" defaulting to this ship; anything else is a 422 message.  the
::  group must be one this ship is seated in right now, hosted here or
::  joined, read the same way every later access check reads it
::
++  valid-repository-name
  |=  name=@t
  ^-  ?
  =/  chars=tape  (trip name)
  ?.  &((gth (lent chars) 0) (lte (lent chars) 100))  %.n
  %+  levy  chars
  |=  char=@tD
  ?|  &((gte char 'a') (lte char 'z'))
      &((gte char 'A') (lte char 'Z'))
      &((gte char '0') (lte char '9'))
      =('-' char)
      =('_' char)
      =('.' char)
  ==
::
++  api-terminal-name
  |=  [segment=@t extension=(unit @ta)]
  ^-  @t
  ?~  extension  segment
  (rap 3 ~[segment '.' `@t`u.extension])
::
++  api-file-path
  |=  [segments=(list @t) extension=(unit @ta)]
  ^-  (unit path)
  ?~  segments  ~
  =/  segments=(list @t)
    ?~  extension  segments
    =/  reversed=(list @t)  (flop segments)
    ?~  reversed  segments
    =/  leaf=@t  (rap 3 ~[i.reversed '.' `@t`u.extension])
    (flop [leaf t.reversed])
  =/  parse
    |=  [remaining=(list @t) out=path]
    ^-  (unit path)
    ?~  remaining  `(flop out)
    =/  chars=tape  (trip i.remaining)
    ?.  ?&  !=('' i.remaining)
            !=('.' i.remaining)
            !=('..' i.remaining)
            (lte (lent chars) 255)
            %+  levy  chars
            |=(char=@tD &(!=(char 0) !=(char '/')))
        ==
      ~
    $(remaining t.remaining, out [`knot`i.remaining out])
  (parse segments ~)
::
++  write-authorized
  |=  [repo=repository:git req=inbound-request:eyre]
  ^-  ?
  ?:  authenticated.req  %.y
  ?~  write-token-hash.repo  %.n
  =/  token=(unit @t)  (basic-password req)
  ?~  token  %.n
  =(u.write-token-hash.repo (shas %git-write-token u.token))
::
::  the password of a Basic authorization header, if any
::
++  basic-password
  |=  req=inbound-request:eyre
  ^-  (unit @t)
  =/  header=(unit @t)  (get-header:http 'authorization' header-list.request.req)
  ?~  header  ~
  ?.  (starts-with 'Basic ' u.header)  ~
  =/  decoded=(unit octs)
    (de:base64:mimes:html (crip (slag 6 (trip u.header))))
  ?~  decoded  ~
  =/  credentials=tape  (trip q.u.decoded)
  =/  colon=(unit @ud)  (find ":" credentials)
  ?~  colon  ~
  `(crip (slag +(u.colon) credentials))
::
++  receive-payload
  |=  [unpack=@t results=(list [ok=? ref=@t message=@t])]
  ^-  simple-payload:http
  :_  `(receive-status:git-protocol unpack results)
  :-  200
  :~  ['content-type' 'application/x-git-receive-pack-result']
      ['cache-control' 'no-store']
  ==
::
::  The bytes of a Git request body, with Content-Encoding applied.
::
::  git compresses a request body once it grows past 1,024 bytes, so a
::  clone of a repository with enough refs arrives gzipped.  Everything
::  that reads the body -- the protocol v2 command dispatch as much as
::  the request parsers -- has to see the same decompressed bytes, so the
::  decoding happens once, here, ahead of every reader.
::
::  +gunzip is total, but it is called under +mule anyway: a body that
::  claims gzip and is not gzip must answer 400, never take the agent
::  down with it.
::
++  decoded-body
  |=  req=inbound-request:eyre
  ^-  (each octs [status=@ud message=@t])
  =/  raw=octs  ?~(body.request.req [0 0] u.body.request.req)
  =/  encoding=(unit @t)
    (get-header:http 'content-encoding' header-list.request.req)
  ?~  encoding  [%& raw]
  ?:  |(=('' u.encoding) =('identity' u.encoding))  [%& raw]
  ?.  |(=('gzip' u.encoding) =('x-gzip' u.encoding))
    [%| 415 'unsupported content-encoding\0a']
  =/  attempt  (mule |.((gunzip:git-gzip raw)))
  ?:  ?=(%| -.attempt)  [%| 400 'invalid gzip request body\0a']
  ?~  p.attempt  [%| 400 'invalid gzip request body\0a']
  [%& u.p.attempt]
::
++  public-base
  |=  req=inbound-request:eyre
  ^-  @t
  =/  host=@t  (fall (get-header:http 'host' header-list.request.req) 'localhost')
  =/  forwarded=(unit @t)  (get-header:http 'x-forwarded-proto' header-list.request.req)
  =/  scheme=@t
    ?^  forwarded  u.forwarded
    ?:(|((starts-with 'localhost' host) (starts-with '127.0.0.1' host)) 'http' 'https')
  (rap 3 ~[scheme '://' host])
::
::  the largest body piece one response fact carries.  The runtime
::  stops the ship when an effect holds an atom of 2^32 bits (512 MiB)
::  or more, so a larger body, such as the pack of a full clone, is
::  given as several pieces of at most 64 MiB each.
::
++  body-piece  67.108.864
::
++  body-pieces
  |=  [body=octs size=@ud]
  ^-  (list octs)
  ?>  (gth size 0)
  =/  offset=@ud  0
  =|  out=(list octs)
  |-
  ?:  (gte offset p.body)  (flop out)
  =/  width=@ud  (min size (sub p.body offset))
  %=  $
    offset  (add offset width)
    out  [[width (cut 3 [offset width] q.body)] out]
  ==
::
++  give-http
  |=  [eyre-id=@ta status=@ud headers=(list [@t @t]) body=(unit octs)]
  ^-  (list card:agent:gall)
  ?:  |(?=(~ body) (lte p.u.body body-piece))
    %+  give-simple-payload:app:server  eyre-id
    [[status headers] body]
  =/  =path  /http-response/[eyre-id]
  =/  header=response-header:http  [status headers]
  =/  start=card:agent:gall
    [%give %fact ~[path] [%http-response-header !>(header)]]
  =/  pieces=(list card:agent:gall)
    %+  turn  (body-pieces u.body body-piece)
    |=  piece=octs
    ^-  card:agent:gall
    =/  data=(unit octs)  `piece
    [%give %fact ~[path] [%http-response-data !>(data)]]
  =/  done=card:agent:gall  [%give %kick ~[path] ~]
  [start (snoc pieces done)]
::
++  give-text
  |=  [eyre-id=@ta status=@ud message=@t]
  ^-  (list card:agent:gall)
  (give-http eyre-id status ~[['content-type' 'text/plain']] `(text:git-codec message))
--
