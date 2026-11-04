::  The owner's release of a legacy retention from the Runners panel
::  (legacy-recovery UI ruling 01; QUESTIONS-SOURCE-01 §11;
::  runner/launcher/INTEGRATION.md §11.12; contract §8b): the message the
::  CI key signs for a recovery command, the parsing of a daemon's
::  retention report, and a command's lifecycle.  Nothing here scries or
::  signs; every input is a value the agent already holds.
::
::    the daemon decides: it checks the command and everything a release
::    stands on again when it runs, and answers.  the ship binds, records,
::    hands over and shows.
::
/-  ci
|%
::  the message version.  a verifier of another fails closed.
::
++  recovery-version  1
::
::  the operations a recovery command names: the release of a legacy
::  retention, and (legacy-replay-upgrade ruling 01; QUESTIONS-SOURCE-01
::  §15; INTEGRATION.md §11.15) the transition of a runner whose execution
::  history is incomplete to an authorization epoch
::
++  release-legacy  'release-legacy'
++  confirm-history  'confirm-history'
::
::  the signed noun: [%recovery 1 recipient command operation expiry nonce
::  selection revision evidence].  its leading tag keeps it apart from an
::  assignment's [2 ...]: no signature over one verifies as the other.
::  runner/internal/sig/recovery.go rebuilds the same noun.
::
++  message-noun
  |=  $:  recipient=@uv  command=@uv  operation=@t  expiry=@ud  nonce=@uv
          selection=@t  revision=@ud  evidence=@t
      ==
  ^-  *
  [%recovery recovery-version recipient command operation expiry nonce selection revision evidence]
::
++  message-bytes
  |=  $:  recipient=@uv  command=@uv  operation=@t  expiry=@ud  nonce=@uv
          selection=@t  revision=@ud  evidence=@t
      ==
  ^-  @
  (jam (message-noun recipient command operation expiry nonce selection revision evidence))
::
::  a report's entries: each of its retentions with its selection and
::  revision, or ~ when any entry is malformed — a report is taken whole
::  or not at all
::
++  report-entries
  |=  jon=json
  ^-  (unit (list recovery-entry:ci))
  ?.  ?=([%o *] jon)  ~
  =/  items=(unit json)  (~(get by p.jon) 'retentions')
  ?~  items  ~
  ?.  ?=([%a *] u.items)  ~
  =/  parsed=(list (unit recovery-entry:ci))  (turn p.u.items entry-of)
  ?:  (lien parsed |=(e=(unit recovery-entry:ci) ?=(~ e)))  ~
  `(murn parsed |=(e=(unit recovery-entry:ci) e))
::
++  entry-of
  |=  item=json
  ^-  (unit recovery-entry:ci)
  =/  selection=(unit @t)  (text-at 'selection' item)
  =/  revision=(unit @ud)  (count-at 'revision' item)
  ?~  selection  ~
  ?~  revision  ~
  :-  ~
  :*  u.selection
      u.revision
      (fall (text-at 'attempt' item) '')
      (fall (text-at 'label' item) '')
      (fall (text-at 'kind' item) '')
      (flag-at 'eligible' item)
      (fall (text-at 'evidence' item) '')
  ==
::
++  text-at
  |=  [key=@t jon=json]
  ^-  (unit @t)
  ?.  ?=([%o *] jon)  ~
  =/  value=(unit json)  (~(get by p.jon) key)
  ?~  value  ~
  ?.  ?=([%s *] u.value)  ~
  `p.u.value
::
::  a JSON number has no thousands dots: dim, not dem
::
++  count-at
  |=  [key=@t jon=json]
  ^-  (unit @ud)
  ?.  ?=([%o *] jon)  ~
  =/  value=(unit json)  (~(get by p.jon) key)
  ?~  value  ~
  ?.  ?=([%n *] u.value)  ~
  (rush p.u.value dim:ag)
::
::  absent or not a boolean is %.n: nothing is releasable by default
::
++  flag-at
  |=  [key=@t jon=json]
  ^-  ?
  ?.  ?=([%o *] jon)  %.n
  =/  value=(unit json)  (~(get by p.jon) key)
  ?~  value  %.n
  ?.  ?=([%b *] u.value)  %.n
  p.u.value
::
::  a command still waiting for its final answer: nothing more may be
::  requested of its entry meanwhile
::
++  open-command
  |=  c=recovery-command:ci
  ^-  ?
  ?=(?(%queued %delivered %uncertain) status.c)
::
::  a queued command past its expiry was never handed over: it expires,
::  and nothing was done
::
++  expire-command
  |=  [c=recovery-command:ci now=@da]
  ^-  recovery-command:ci
  ?.  ?&(=(%queued status.c) (gte now expires.c))  c
  c(status %expired, finished `now, detail 'not fetched by the runner within fifteen minutes; nothing was done')
::
::  the command a poll of .daemon hands over: the oldest queued one inside
::  its time, else the oldest handed over at least .again ago with no
::  final answer — its answer may have been lost; the daemon answers a
::  command it carried out from its own record, and refuses one expired
::
++  deliverable
  |=  [commands=(list recovery-command:ci) daemon=@uv now=@da again=@dr]
  ^-  (unit recovery-command:ci)
  =/  mine=(list recovery-command:ci)
    %+  sort
      %+  skim  commands
      |=  c=recovery-command:ci
      ?.  =(daemon daemon.c)  %.n
      ?:  =(%queued status.c)  (lth now expires.c)
      ?.  ?=(?(%delivered %uncertain) status.c)  %.n
      ?~  delivered.c  %.y
      (gte now (add u.delivered.c again))
    |=([a=recovery-command:ci b=recovery-command:ci] (lth requested.a requested.b))
  ?~(mine ~ `i.mine)
::
::  a daemon's answer applied to its command: %completed — the runner's
::  durable release — stands against any earlier answer and is never
::  changed; a refusal or a doubt changes only a command still open
::
++  answer-command
  |=  [c=recovery-command:ci status=?(%completed %refused %uncertain) detail=@t now=@da]
  ^-  recovery-command:ci
  ?:  =(%completed status.c)  c
  ?:  ?&(!(open-command c) !=(%completed status))  c
  %=  c
    status  status
    detail  detail
    finished  ?:(=(%uncertain status) finished.c `now)
  ==
::
::  a daemon's execution history as its report shows it (§11.15): its
::  selection and revision, whether it waits for its transition (as
::  .eligible) and the digest of its evidence, kind 'history'; ~ when the
::  report shows none, or a malformed one
::
++  history-entry
  |=  jon=json
  ^-  (unit recovery-entry:ci)
  ?.  ?=([%o *] jon)  ~
  =/  item=(unit json)  (~(get by p.jon) 'history')
  ?~  item  ~
  =/  selection=(unit @t)  (text-at 'selection' u.item)
  =/  revision=(unit @ud)  (count-at 'revision' u.item)
  =/  evidence=(unit @t)  (text-at 'evidence' u.item)
  ?~  selection  ~
  ?~  revision  ~
  ?~  evidence  ~
  `[u.selection u.revision '' 'execution history' 'history' (flag-at 'paused' u.item) u.evidence]
::
::  a daemon's authorization epoch at .at: how many transitions of its
::  history the owner had confirmed by then — every confirm-history
::  command of it, whatever became of it, so that the epoch only grows.
::  recovery commands are never pruned
::
++  epoch-at
  |=  [commands=(list recovery-command:ci) daemon=@uv at=@da]
  ^-  @ud
  %-  lent
  %+  skim  commands
  |=  c=recovery-command:ci
  ?&  =(daemon daemon.c)
      =(confirm-history operation.c)
      (lte requested.c at)
  ==
::
::  the nonce an assignment of epoch .epoch is signed with: the epoch
::  above bit 128, the fresh sixteen bytes below it.  every nonce the ship
::  signed before any transition is below 2^128 (fresh-nonce is sixteen
::  bytes), so a runner at epoch E refuses them all by comparing one
::  signed number with E·2^128
::
++  epoch-nonce
  |=  [epoch=@ud nonce=@uv]
  ^-  @uv
  (add (lsh [0 128] epoch) (end [0 128] nonce))
::
::  what a transition command binds (§11.15): the epoch it takes the
::  runner to, and the history evidence its report showed
::
++  transition-evidence
  |=  [epoch=@ud evidence=@t]
  ^-  @t
  (rap 3 ~['epoch ' (crip (a-co:co epoch)) ' history ' evidence])
--
