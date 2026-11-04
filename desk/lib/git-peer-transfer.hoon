::  git-peer-transfer: Peer transfer envelopes, limits, and activity views
::
/-  git, git-peer
/+  git-codec, git-catalog, *git-format
|%
+$  peer-transfer-mode  ?(%archive %pack %objects)
+$  peer-serve
  $:  target=ship
      transfer=@uv
      repository=@t
      mode=peer-transfer-mode
      pages=@ud
      bytes=@ud
      sent=?
      objects=(list [oid:git object:git])
  ==
+$  peer-object-assembly
  [kind=object-kind:git total=@ud next=@ud data=octs]
+$  peer-receive
  $:  purpose=?(%fork %push %pull)
      mode=peer-transfer-mode
      source=ship
      source-repository=@t
      local-repository=@t
      title=@t
      source-ref=@t
      target-ref=@t
      public-read=?
      accepted=?
      head=@t
      refs=(map @t oid:git)
      expected=@ud
      expected-bytes=@ud
      received=@ud
      pages=@ud
      completed=(set @ud)
      pending-pages=(map @ud (list object-fragment:git-peer))
      progress-at=@da
      fine-progress=(map @ud [fag=@ud tot=@ud])
      assemblies=(map oid:git peer-object-assembly)
      assembly-bytes=@ud
      assembly-count=@ud
      objects=(map oid:git object:git)
  ==
+$  peer-stream-job
  $:  target=ship
      transfer=@uv
      repository=@t
      head=@t
      refs=(map @t oid:git)
      expected=@ud
      pages=@ud
      revision=@ud
      remaining=(list [oid:git object:git])
      offset=@ud
      begun=?
  ==
+$  peer-transfer-debug
  $:  transfer=@uv
      purpose=?(%fork %push %pull)
      source=ship
      source-repository=@t
      local-repository=@t
      stage=?(%request %prepare %archive %fine)
      expected-objects=@ud
      expected-bytes=@ud
      received-objects=@ud
      pages=@ud
      completed-pages=(list @ud)
      fine-progress=(list [revision=@ud fag=@ud tot=@ud])
      progress-at=@da
  ==
+$  peer-serve-debug
  $:  transfer=@uv
      target=ship
      repository=@t
      mode=peer-transfer-mode
      pages=@ud
      bytes=@ud
      sent=?
      objects=@ud
  ==
+$  peer-result  [status=? message=@t repository=@t]
+$  peer-offer-flight
  $:  peer=ship
      repository=@t
      kind=?(%push %pull-request)
  ==
+$  peer-browse-serve  [target=ship pages=@ud]
+$  peer-browse-job
  $:  target=ship
      repository=@t
      view=browse-view:git-peer
      number=@ud
      file-path=path
  ==
::  group is set when the discovery was fanned out to a group's members
+$  peer-discovery  discovery:git-catalog
+$  peer-browse
  $:  peer=ship
      repository=@t
      view=browse-view:git-peer
      number=@ud
      file-path=path
      phase=?(%request %prepare %fine)
      active=?
      ok=?
      message=@t
      progress=(unit [boq=@ud fag=@ud tot=@ud])
      progress-at=@da
      expected=@ud
      received=@ud
      parts=(map @ud [length=@ud data=@])
      result=(unit json)
  ==
+$  peer-forge
  $:  peer=ship
      repository=@t
      kind=forge-kind:git-peer
      number=@ud
      active=?
      ok=?
      message=@t
      result=(unit json)
  ==
+$  peer-activity-kind  ?(%fork %serve %push %pull-request)
+$  peer-activity-status  ?(%active %success %failure)
+$  peer-activity
  $:  id=@uv
      kind=peer-activity-kind
      direction=?(%incoming %outgoing)
      peer=ship
      repository=@t
      status=peer-activity-status
      message=@t
      when=@da
  ==
+$  notification-activity
  $:  id=@uv
      event=notification-event:git
      repository=@t
      message=@t
      when=@da
  ==
++  peer-browse-join
  |=  [pages=(map @ud [length=@ud data=@]) expected=@ud]
  ^-  (unit @)
  =/  revision=@ud  1
  =/  offset=@ud  0
  =/  encoded=@  0
  |-
  ?:  (gth revision expected)  `encoded
  =/  page=(unit [length=@ud data=@])  (~(get by pages) revision)
  ?~  page  ~
  =/  page-length=@ud  -.u.page
  =/  page-data=@  +.u.page
  %=  $
    revision  +(revision)
    offset  (add offset page-length)
    encoded  (mix encoded (lsh [3 offset] page-data))
  ==
::
++  peer-browse-yawns
  |=  [request=@uv peer=ship pages=@ud]
  ^-  (list card:agent:gall)
  %+  turn  (gulf 1 pages)
  |=  revision=@ud
  =/  scry-path=path
    /g/x/(scot %ud revision)/urgit//1/browse/(scot %uv request)
  [%pass /peer/browse-cancel/(scot %uv request)/(scot %ud revision) %arvo %a %yawn [peer scry-path]]
::
++  peer-serve-lifetime
  |=  [mode=peer-transfer-mode pages=@ud]
  ^-  @dr
  ?:  =(%archive mode)  ~d1
  ?:  =(%objects mode)
    (min ~d1 (add ~m10 (mul pages ~m2)))
  ~m10
::
++  peer-object-capability  0x7572.6769.742d.6132
::
++  peer-stream-max-objects  25.000
++  peer-stream-max-pages  65.536
++  peer-stream-max-object-bytes  67.108.864
++  peer-stream-max-assembly-bytes  67.108.864
++  peer-archive-max-objects  250.000
++  peer-archive-max-bytes  1.073.741.824
++  peer-archive-max-object-bytes  536.870.912
++  peer-stream-window  8
++  peer-stream-page-max-fragments  512
++  peer-stream-page-max-bytes  1.048.576
::
::  the most stream pages one object can take: a fragment carries at
::  most 1.048.576 bytes and a page at least one fragment, so an object
::  of at most peer-stream-max-object-bytes takes at most this many
::
++  peer-stream-max-object-pages
  (div (add peer-stream-max-object-bytes (dec 1.048.576)) 1.048.576)
::
++  peer-object-capable
  |=  transfer=@uv
  ^-  ?
  =(peer-object-capability (cut 0 [128 64] transfer))
::
++  peer-object-transfer
  |=  transfer=@uv
  ^-  @uv
  `@uv`(mix (cut 0 [0 128] transfer) (lsh [0 128] peer-object-capability))
::
++  peer-object-bytes
  |=  objects=(list [oid:git object:git])
  ^-  @ud
  =/  remaining  objects
  =/  total=@ud  0
  |-
  ?~  remaining  total
  $(remaining t.remaining, total (add total p.data.+.i.remaining))
::
::  transfer visibility: one projection, three consumers
::
::    $peer-ui-state is everything /peer/activity and /peer/transfers read.
::    The two polling endpoints and the /peer/activity subscription all go
::    through +peer-ui-json, so a subscriber and a poller can never disagree
::    about shape.
::
+$  peer-ui-state
  $:  activities=(list peer-activity)
      notes=(list notification-activity)
      results=(map @uv peer-result)
      receiving=(map @uv peer-receive)
      outgoing=(map @uv peer-offer-flight)
  ==
::
++  peer-ui-path  `path`/peer/activity
::
++  peer-ui-activity-json
  |=  ui=peer-ui-state
  ^-  json
  =/  entries=(list json)
    %+  turn  activities.ui
    |=  event=peer-activity
    %-  pairs:enjs:format
    :~  ['id' s+(scot %uv id.event)]
        ['kind' s+kind.event]
        ['direction' s+direction.event]
        ['ship' s+(scot %p peer.event)]
        ['repository' s+repository.event]
        ['status' s+status.event]
        ['message' s+message.event]
        ['when' s+(scot %da when.event)]
    ==
  =/  notifications=(list json)
    %+  turn  notes.ui
    |=  event=notification-activity
    %-  pairs:enjs:format
    :~  ['id' s+(scot %uv id.event)]
        ['event' s+event.event]
        ['repository' s+repository.event]
        ['message' s+message.event]
        ['when' s+(scot %da when.event)]
    ==
  (pairs:enjs:format ~[['activity' [%a entries]] ['notifications' [%a notifications]]])
::
++  peer-ui-transfers-json
  |=  ui=peer-ui-state
  ^-  json
  =/  entries=(list json)
    %+  turn  ~(tap by results.ui)
    |=  entry=[@uv peer-result]
    =/  transfer=@uv  -.entry
    =/  result=peer-result  +.entry
    =/  flight=(unit peer-receive)  (~(get by receiving.ui) transfer)
    =/  offer=(unit peer-offer-flight)  (~(get by outgoing.ui) transfer)
    %-  pairs:enjs:format
    :~  ['transfer' s+(scot %uv transfer)]
        ['active' b+|(?=(^ flight) ?=(^ offer))]
        ['ok' b+status.result]
        ['message' s+message.result]
        ['repository' s+repository.result]
        :*  'stage'
            :-  %s
            ?~
              flight
              'complete'
            ?:
              =('' head.u.flight)
              ?:(accepted.u.flight 'prepare' 'request')
            ?:(=(%archive mode.u.flight) 'archive' 'fine')
        ==
        ['received' n+(decimal ?~(flight 0 received.u.flight))]
        ['expected' n+(decimal ?~(flight 0 expected.u.flight))]
        ['expectedBytes' n+(decimal ?~(flight 0 expected-bytes.u.flight))]
        ['pages' n+(decimal ?~(flight 0 pages.u.flight))]
        ['completedPages' n+(decimal ?~(flight 0 ~(wyt in completed.u.flight)))]
        :*  'fineFragmentsReceived'
            :-  %n
            %:  decimal
              ?~
                flight
                0
              %:  roll
                ~(val by fine-progress.u.flight)
                |=([[fag=@ud tot=@ud] sum=@ud] (add fag sum))
              ==
            ==
        ==
        :*  'fineFragmentsTotal'
            :-  %n
            %:  decimal
              ?~
                flight
                0
              %:  roll
                ~(val by fine-progress.u.flight)
                |=([[fag=@ud tot=@ud] sum=@ud] (add tot sum))
              ==
            ==
        ==
    ==
  (pairs:enjs:format ~[['transfers' [%a entries]]])
::
::  +peer-ui-json: what both polling endpoints return, in one object.  No
::  third shape is invented; the keys are the ones already served.
::
++  peer-ui-json
  |=  ui=peer-ui-state
  ^-  json
  =/  activity=json  (peer-ui-activity-json ui)
  =/  transfers=json  (peer-ui-transfers-json ui)
  ?.  ?=([%o *] activity)  activity
  ?.  ?=([%o *] transfers)  activity
  [%o (~(uni by p.activity) p.transfers)]
::
::  +peer-ui-digest: a cheap fingerprint of everything +peer-ui-json shows.
::  Reads only scalars out of .receiving, never its object maps, so testing
::  it on every event costs nothing that scales with repository size.
::
++  peer-ui-digest
  |=  ui=peer-ui-state
  ^-  *
  :^  activities.ui
    notes.ui
    [~(tap by results.ui) ~(tap by outgoing.ui)]
  %+  turn  ~(tap by receiving.ui)
  |=  entry=[@uv peer-receive]
  =/  flight=peer-receive  +.entry
  :*  -.entry
      received.flight
      expected.flight
      expected-bytes.flight
      pages.flight
      ~(wyt in completed.flight)
      %+  roll  ~(val by fine-progress.flight)
      |=([[fag=@ud tot=@ud] sum=@ud] (add fag sum))
      %+  roll  ~(val by fine-progress.flight)
      |=([[fag=@ud tot=@ud] sum=@ud] (add tot sum))
  ==
::
::  +peer-ui-notify: append a fact when an event moved anything the transfer
::  UI shows.  Gall discards facts for subscribers that have gone away, so
::  this cannot crash the agent on a closed browser.
::
++  peer-ui-notify
  |=  [before=peer-ui-state after=peer-ui-state cards=(list card:agent:gall)]
  ^-  (list card:agent:gall)
  ?:  =((peer-ui-digest before) (peer-ui-digest after))  cards
  %+  snoc  cards
  [%give %fact ~[peer-ui-path] %json !>((peer-ui-json after))]
::
++  peer-fine-name
  |=  transfer=@uv
  ^-  @ta
  (scot %uv (cut 0 [0 64] transfer))
::
++  peer-serve-activity-id
  |=  transfer=@uv
  ^-  @uv
  `@uv`(shas %git-peer-serve-activity transfer)
++  assemble-peer-fragments
  |=  [flight=peer-receive fragments=(list object-fragment:git-peer)]
  ^-  (unit peer-receive)
  =/  remaining  fragments
  =/  next=peer-receive  flight
  =/  seen=(set [oid:git @ud])  ~
  |-
  ?~  remaining  `next
  =/  fragment=object-fragment:git-peer  i.remaining
  ?.  ?|  ?&  =(total.fragment 0)
              =(offset.fragment 0)
              =(p.data.fragment 0)
              =(q.data.fragment 0)
          ==
          ?&  (gth total.fragment 0)
              (lte total.fragment peer-stream-max-object-bytes)
              (lth offset.fragment total.fragment)
              (gth p.data.fragment 0)
              (lte p.data.fragment 1.048.576)
              (lte (met 3 q.data.fragment) p.data.fragment)
              (lte (add offset.fragment p.data.fragment) total.fragment)
          ==
      ==
    ~
  ?:  (~(has in seen) [oid.fragment offset.fragment])  ~
  ?:  (~(has by objects.next) oid.fragment)  ~
  ?.  (lth received.next expected.next)  ~
  =/  prior=(unit peer-object-assembly)
    (~(get by assemblies.next) oid.fragment)
  =/  current=peer-object-assembly
    ?~(prior [kind.fragment total.fragment 0 [0 0]] u.prior)
  ?.  ?&  =(kind.fragment kind.current)
          =(total.fragment total.current)
          =(offset.fragment next.current)
      ==
    ~
  =/  full-data=octs
    (join:git-codec data.current data.fragment)
  =/  next-offset=@ud
    (add offset.fragment p.data.fragment)
  ?:  ?&  (lth next-offset total.fragment)
          !=(p.data.fragment 1.048.576)
      ==
    ~
  =/  next-assembly-bytes=@ud
    (add assembly-bytes.next p.data.fragment)
  ?:  (gth next-assembly-bytes peer-stream-max-assembly-bytes)  ~
  =/  next-seen=(set [oid:git @ud])
    (~(put in seen) [oid.fragment offset.fragment])
  ?:  =(next-offset total.fragment)
    ?.  =(oid.fragment (object-oid:git-codec kind.fragment full-data))  ~
    =/  completed=peer-receive
      %=  next
        assemblies  (~(del by assemblies.next) oid.fragment)
        assembly-bytes  (sub next-assembly-bytes total.fragment)
        assembly-count  ?~(prior assembly-count.next (sub assembly-count.next 1))
        objects  (~(put by objects.next) oid.fragment [kind.fragment full-data])
        received  +(received.next)
      ==
    $(remaining t.remaining, next completed, seen next-seen)
  =/  partial=peer-object-assembly
    [kind.fragment total.fragment next-offset full-data]
  ?:  ?&  ?=(~ prior)
          (gte (add received.next assembly-count.next) expected.next)
      ==
    ~
  =/  continued=peer-receive
    %=  next
      assemblies  (~(put by assemblies.next) oid.fragment partial)
      assembly-bytes  next-assembly-bytes
      assembly-count  ?~(prior +(assembly-count.next) assembly-count.next)
    ==
  $(remaining t.remaining, next continued, seen next-seen)
::
++  peer-card
  |=  [target=ship wire=wire packet=packet:git-peer]
  ^-  card:agent:gall
  [%pass wire %agent [target %urgit] %poke %git-peer !>(packet)]
::
::  whose write a peer packet persisted (Delivery 1C correction-04), from
::  the receives in flight when its event began.  a receive completes only
::  by %snapshot or %object-fragments (+peer-finish's two callers): sent
::  by the flight's own source, or delivered by this ship to itself, which
::  continues a Fine page it checked came from that source.  either way
::  the write is the receive this ship accepted: an incoming push or pull
::  request is the offering peer's (its source, Ames-authenticated when
::  the offer was accepted), and a fork or its refresh is this ship's,
::  which requested it, never the peer that served the data.  any other
::  packet, one naming no receive in flight, or one sent by a ship that
::  is neither this one nor the flight's source, is its immediate sender's:
::  no recorded state lends another ship's authority to it
::
++  receive-attribution
  |=  [=packet:git-peer flights=(map @uv peer-receive) src=ship our=ship]
  ^-  ship
  =/  transfer=(unit @uv)
    ?+  -.packet  ~
      %snapshot  `transfer.packet
      %object-fragments  `transfer.packet
    ==
  ?~  transfer  src
  =/  flight=(unit peer-receive)  (~(get by flights) u.transfer)
  ?~  flight  src
  ?.  |(=(src our) =(src source.u.flight))  src
  ?:  ?=(%fork purpose.u.flight)  our
  source.u.flight
--
