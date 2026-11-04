::  ci-peer-attribution-vector: who a peer write belongs to (Delivery 1C
::  correction-04), through production logic: +receive-attribution
::  (lib/git-peer-transfer), which %urgit's on-poke reads with the receives
::  in flight as the event began, and +forge-actions (lib/ci-forge), which
::  builds the receipt %urgit-ci admits from that actor.
::
::  The reproduced fault: a peer's push, pull request and synchronize were
::  each completed by this ship's own Fine continuation, so the receipt
::  named the host (~nec) instead of the Ames-authenticated sender (~bud).
::  Checked here:
::    - a direct remote packet from the flight's source;
::    - a local completion (%snapshot or %object-fragments delivered by
::      this ship to itself) with authenticated receive state: the
::      offering peer, for a push and for a pull request (opened, and
::      synchronized by a read-only peer, whose request-text claims of
::      another actor are ignored);
::    - an owner merge (control): the receipt is the merger's while the
::      pull request keeps its peer source;
::    - a local fork refresh: the requester, never the data server;
::    - stale, missing and mismatched completion state: the immediate
::      sender, never a recorded peer and never an assumed owner;
::    - packets that complete nothing keep their sender;
::    - an Arvo Fine page event persists no repository change: no receipt.
::  The linked-desk completion is attributed by %urgit's arvo-attribution
::  from the parked write's peer-response (the flight's source); that arm
::  is the agent's and is pinned by fe/src/ciPeerAttribution.test.js.
::  Prints `passed=N of=M` and ends in a loobean.
::
/-  ci, git, git-peer
/+  ci-forge, git-peer-transfer
:-  %say
|=  *
:-  %noun
=/  now  ~2026.10.16..14.00.00
=/  master  'refs/heads/master'
::  a receive in flight, as accept-offer (push, pull) or post-peer-fork
::  (fork) records it: the purpose and the authenticated source matter;
::  title and repository text are deliberately misleading
::
=/  flight
  |=  [purpose=?(%fork %push %pull) source=ship]
  ^-  peer-receive:git-peer-transfer
  =/  f=peer-receive:git-peer-transfer  *peer-receive:git-peer-transfer
  %=  f
    purpose  purpose
    source  source
    source-repository  'wf1c-peer-fork'
    local-repository  'wf1c-peer-host'
    title  'Peer provenance fixture (actor=~zod)'
  ==
=/  t-push=@uv  0vpush
=/  t-pull=@uv  0vpull
=/  t-fork=@uv  0vfork
=/  t-gone=@uv  0vgone
::  the host ~nec's receives: ~bud's push and ~bud's pull request
::
=/  host=(map @uv peer-receive:git-peer-transfer)
  (my ~[[t-push (flight %push ~bud)] [t-pull (flight %pull ~bud)]])
::  the peer ~bud's own fork refresh, served by ~nec
::
=/  fork=(map @uv peer-receive:git-peer-transfer)
  (my ~[[t-fork (flight %fork ~nec)]])
=/  attr
  |=  [=packet:git-peer flights=(map @uv peer-receive:git-peer-transfer) src=ship our=ship]
  ^-  ship
  (receive-attribution:git-peer-transfer packet flights src our)
=/  snap  |=(t=@uv `packet:git-peer`[%snapshot t ~])
=/  frag  |=(t=@uv `packet:git-peer`[%object-fragments t 1 ~])
::
=/  direct=(list [name=@t expect=? got=?])
  :~  ['a push completed by its peer\'s own packet is the peer\'s' %.y =(~bud (attr (snap t-push) host ~bud ~nec))]
      ['a pull request completed by its peer\'s own packet is the peer\'s' %.y =(~bud (attr (snap t-pull) host ~bud ~nec))]
  ==
::  the reproduced fault: this ship continues the page it fetched
::
=/  local=(list [name=@t expect=? got=?])
  :~  ['a push completed by this ship\'s own %snapshot is the offering peer\'s' %.y =(~bud (attr (snap t-push) host ~nec ~nec))]
      ['a push completed by this ship\'s own %object-fragments is the peer\'s' %.y =(~bud (attr (frag t-push) host ~nec ~nec))]
      ['a pull request opened through this ship\'s continuation is the peer\'s' %.y =(~bud (attr (frag t-pull) host ~nec ~nec))]
      :+  'a read-only peer\'s synchronize, through a continuation, is the peer\'s, not a claimed ~zod'
        %.y
      ?&  =(~bud (attr (snap t-pull) host ~nec ~nec))
          !=(~zod (attr (snap t-pull) host ~nec ~nec))
          !=(~nec (attr (snap t-pull) host ~nec ~nec))
      ==
  ==
::  the receipt %urgit-ci admits, built as %urgit builds it
::
=/  blank=repository:git  *repository:git
=/  pr=native-pull:git
  [1 ~bud 'wf1c-peer-fork' 'refs/heads/peer-feature' master 'Peer provenance fixture' %open 0x2edc 0x5126 ~ ~]
=/  at-5126=repository:git
  blank(owner ~nec, head master, refs (my ~[[master 0x5126]]))
=/  receipt
  |=  as=(list action:ci)
  ^-  (unit [actor=@p route=@t pulls=(list pull-update:ci) refs=(list ref-update:ci)])
  ?.  ?=([* ~] as)  ~
  =/  a=action:ci  i.as
  ?.  ?=(%forge-events -.a)  ~
  `[actor.a route.a pulls.a refs.a]
=/  forged
  |=  [was=repository:git is=repository:git actor=@p route=@t]
  %-  receipt
  %:  forge-actions:ci-forge
    (my ~[['wf1c-peer-host' was]])
    (my ~[['wf1c-peer-host' is]])
    actor
    route
    now
  ==
=/  receipts=(list [name=@t expect=? got=?])
  :~  :+  'the peer push\'s receipt names ~bud, completed by this ship\'s continuation'  %.y
      =/  was=repository:git  blank(owner ~nec, head master, refs (my ~[[master 0x685d]]))
      =/  r  (forged was at-5126 (attr (snap t-push) host ~nec ~nec) 'peer')
      ?&(?=(^ r) =(~bud actor.u.r) =('peer' route.u.r) ?=([* ~] refs.u.r))
      :+  'the peer pull request\'s opened receipt names ~bud and its sourceShip ~bud'  %.y
      =/  r
        %:  forged
          at-5126
          at-5126(native-pulls ~[pr(head 0x99ba)])
          (attr (frag t-pull) host ~nec ~nec)
          'peer'
        ==
      ?&  ?=(^ r)  =(~bud actor.u.r)  ?=([* ~] pulls.u.r)
          =('opened' action.i.pulls.u.r)  =(~bud source-ship.i.pulls.u.r)
      ==
      :+  'owner merge (control): the receipts are ~nec\'s, the pull request keeps sourceShip ~bud'
        %.y
      =/  is=repository:git
        at-5126(refs (my ~[[master 0x2edc]]), native-pulls ~[pr(state %merged)])
      =/  r  (forged at-5126(native-pulls ~[pr]) is ~nec 'pull request merge')
      ?&  ?=(^ r)  =(~nec actor.u.r)  =('pull request merge' route.u.r)
          ?=([* ~] pulls.u.r)  =('closed' action.i.pulls.u.r)  merged.i.pulls.u.r
          =(~bud source-ship.i.pulls.u.r)  =(`0x5126 target-before.i.pulls.u.r)
          ?=([* ~] refs.u.r)
      ==
      :+  'the owner\'s merge route is the authenticated web route'  %.y
      =('pull request merge' (http-route:ci-forge ~['apps' 'urgit' 'api' 'repository' 'wf1c-peer-host' 'pulls' '1' 'merge'] %.y))
  ==
::  on ~bud: its own fork refresh, whose objects ~nec served
::
=/  refresh=(list [name=@t expect=? got=?])
  :~  ['a fork refresh completed by the data server\'s packet is the requester\'s' %.y =(~bud (attr (snap t-fork) fork ~nec ~bud))]
      ['and not the data server\'s' %.y !=(~nec (attr (snap t-fork) fork ~nec ~bud))]
      ['a fork refresh completed by the requester\'s continuation is the requester\'s' %.y =(~bud (attr (frag t-fork) fork ~bud ~bud))]
  ==
=/  stale=(list [name=@t expect=? got=?])
  :~  ['a continuation naming no receive in flight is its immediate sender\'s' %.y =(~nec (attr (snap t-gone) host ~nec ~nec))]
      ['a remote packet naming no receive in flight is that sender\'s, not the owner\'s' %.y =(~wes (attr (snap t-gone) host ~wes ~nec))]
      :+  'a packet from a ship other than the flight\'s source is that ship\'s'  %.y
      ?&  =(~wes (attr (snap t-push) host ~wes ~nec))
          !=(~bud (attr (snap t-push) host ~wes ~nec))
          !=(~nec (attr (snap t-push) host ~wes ~nec))
      ==
      ['another transfer\'s flight lends nothing' %.y =(~nec (attr (snap t-gone) (my ~[[t-push (flight %push ~bud)]]) ~nec ~nec))]
      ['no flights at all: the immediate sender' %.y =(~nec (attr (frag t-push) ~ ~nec ~nec))]
  ==
::  packets that complete no receive keep their sender, as before
::
=/  others=(list [name=@t expect=? got=?])
  :~  ['a release keeps its sender' %.y =(~bud (attr [%release t-push] host ~bud ~nec))]
      ['a snapshot error keeps its sender' %.y =(~nec (attr [%snapshot-error t-push 'x'] host ~nec ~nec))]
      ['an error keeps its sender' %.y =(~bud (attr [%error t-push 'x'] host ~bud ~nec))]
  ==
::  an Arvo Fine page event moves no repository: no receipt to attribute
::
=/  arvo=(list [name=@t expect=? got=?])
  :~  ['a Fine page event persists no repository change and reports nothing' %.y =(~ (forge-actions:ci-forge (my ~[['wf1c-peer-host' at-5126]]) (my ~[['wf1c-peer-host' at-5126]]) ~nec 'arvo peer' now))]
  ==
=/  cases=(list [name=@t expect=? got=?])
  :(weld direct local receipts refresh stale others arvo)
=/  failed=(list @t)
  %+  murn  cases
  |=  [name=@t expect=? got=?]
  ?:(=(expect got) ~ `name)
=/  passed=@ud  (sub (lent cases) (lent failed))
~&  [%failed failed]
~&  (crip "passed={<passed>} of={<(lent cases)>}")
?=(~ failed)
