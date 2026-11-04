::  Pure persisted-repository migrations.
::
/-  git
/+  *git-format
|%
++  repository-1-to-2
  |=  repo=repository-1:git
  ^-  repository-3:git
  =/  native-pulls=(list native-pull-4:git)
    %+  turn  native-pulls.repo
    |=  pull=native-pull-1:git
    =/  source-ref=@t  ''
    =/  target-ref=@t  head.repo
    :*  number.pull
        source-ship.pull
        source-repository.pull
        source-ref
        target-ref
        title.pull
        state.pull
        head.pull
        base.pull
        comments.pull
    ==
  :*  owner.repo
      public-read.repo
      description.repo
      head.repo
      refs.repo
      protected-refs.repo
      objects.repo
      writers.repo
      ~
      write-token-hash.repo
      lfs-objects.repo
      lfs-uploads.repo
      lfs-locks.repo
      binding.repo
      peer-origin.repo
      github-origin.repo
      github-issues.repo
      github-pulls.repo
      native-pulls
      native-issues.repo
      releases.repo
      webhooks.repo
      incoming-hook.repo
      webhook-deliveries.repo
      upstream-updates.repo
      notification-events.repo
  ==
::
::  a stored repository predates group policies; it starts without one
::
++  repository-3-to-4
  |=  repo=repository-3:git
  ^-  repository-4:git
  :*  owner.repo
      public-read.repo
      description.repo
      head.repo
      refs.repo
      protected-refs.repo
      objects.repo
      writers.repo
      readers.repo
      write-token-hash.repo
      lfs-objects.repo
      lfs-uploads.repo
      lfs-locks.repo
      binding.repo
      peer-origin.repo
      github-origin.repo
      github-issues.repo
      github-pulls.repo
      native-pulls.repo
      native-issues.repo
      releases.repo
      webhooks.repo
      incoming-hook.repo
      webhook-deliveries.repo
      upstream-updates.repo
      notification-events.repo
      ~
  ==
::
::  a stored pull request predates labels, so it starts with none
::
++  pull-4-to-5
  |=  pull=native-pull-4:git
  ^-  native-pull:git
  :*  number.pull
      source-ship.pull
      source-repository.pull
      source-ref.pull
      target-ref.pull
      title.pull
      state.pull
      head.pull
      base.pull
      comments.pull
      ~
  ==
::
::  a stored repository predates pull request labels: every field comes
::  across as it was, and each pull request starts with no labels
::
++  repository-4-to-5
  |=  repo=repository-4:git
  ^-  repository:git
  =/  native-pulls=(list native-pull:git)
    (turn native-pulls.repo pull-4-to-5)
  :*  owner.repo
      public-read.repo
      description.repo
      head.repo
      refs.repo
      protected-refs.repo
      objects.repo
      writers.repo
      readers.repo
      write-token-hash.repo
      lfs-objects.repo
      lfs-uploads.repo
      lfs-locks.repo
      binding.repo
      peer-origin.repo
      github-origin.repo
      github-issues.repo
      github-pulls.repo
      native-pulls
      native-issues.repo
      releases.repo
      webhooks.repo
      incoming-hook.repo
      webhook-deliveries.repo
      upstream-updates.repo
      notification-events.repo
      group-policy.repo
  ==
::
++  settle-webhook-repository
  |=  repo=repository:git
  ^-  repository:git
  =/  deliveries=(list webhook-delivery:git)
    %+  turn  webhook-deliveries.repo
    |=  delivery=webhook-delivery:git
    ?:  =(%pending status.delivery)
      delivery(status %failure, status-code 0, message 'delivery interrupted by agent restart')
    delivery
  %=  repo
    webhook-deliveries  deliveries
    upstream-updates  (dedupe-upstream-updates upstream-updates.repo)
  ==
::
++  migrate-repository-0
  |=  repo=repository-0:git
  ^-  repository-1:git
  :*  owner.repo
      public-read.repo
      description.repo
      head.repo
      refs.repo
      protected-refs.repo
      objects.repo
      writers.repo
      write-token-hash.repo
      lfs-objects.repo
      lfs-uploads.repo
      lfs-locks.repo
      binding.repo
      peer-origin.repo
      github-origin.repo
      github-issues.repo
      github-pulls.repo
      native-pulls.repo
      native-issues.repo
      releases.repo
      webhooks.repo
      incoming-hook.repo
      webhook-deliveries.repo
      upstream-updates.repo
      default-notification-events
  ==
::
++  migrate-state-0
  |=  stored=state-0:git
  ^-  state-1:git
  =/  remaining=(list [@t repository-0:git])  ~(tap by repositories.stored)
  =/  migrated=(map @t repository-1:git)  ~
  =.  migrated
    |-
    ?~  remaining  migrated
    =.  migrated
      (~(put by migrated) -.i.remaining (migrate-repository-0 +.i.remaining))
    $(remaining t.remaining)
  [%1 migrated peers.stored github-token.stored]
::
++  migrate-state-1
  |=  stored=state-1:git
  ^-  state-2:git
  =/  remaining=(list [@t repository-1:git])  ~(tap by repositories.stored)
  =/  migrated=(map @t repository-3:git)  ~
  =.  migrated
    |-
    ?~  remaining  migrated
    =.  migrated
      %+  ~(put by migrated)  -.i.remaining
      (repository-1-to-2 +.i.remaining)
    $(remaining t.remaining)
  [%2 migrated peers.stored github-token.stored]
::
::  a stored %2 predates the persistent fork queue; it starts empty
::
++  migrate-state-2
  |=  stored=state-2:git
  ^-  state-3:git
  [%3 repositories.stored peers.stored github-token.stored ~]
::
::  a stored %3 predates group policies; every repository starts without one
::
++  migrate-state-3
  |=  stored=state-3:git
  ^-  state-4:git
  =/  remaining=(list [@t repository-3:git])  ~(tap by repositories.stored)
  =/  migrated=(map @t repository-4:git)  ~
  =.  migrated
    |-
    ?~  remaining  migrated
    =.  migrated
      %+  ~(put by migrated)  -.i.remaining
      (repository-3-to-4 +.i.remaining)
    $(remaining t.remaining)
  [%4 migrated peers.stored github-token.stored peer-prepare-queue.stored]
::
::  a stored %4 predates pull request labels.  every repository comes
::  forward with no label on any pull request, and the queue is kept
::
++  migrate-state-4
  |=  stored=state-4:git
  ^-  state-5:git
  =/  remaining=(list [@t repository-4:git])  ~(tap by repositories.stored)
  =/  migrated=(map @t repository:git)  ~
  =.  migrated
    |-
    ^-  (map @t repository:git)
    ?~  remaining  migrated
    =.  migrated
      %+  ~(put by migrated)  -.i.remaining
      (repository-4-to-5 +.i.remaining)
    $(remaining t.remaining)
  [%5 migrated peers.stored github-token.stored peer-prepare-queue.stored]
::
++  settle-webhook-state
  |=  stored=state-5:git
  ^-  state-5:git
  =/  remaining=(list [@t repository:git])  ~(tap by repositories.stored)
  =/  settled=(map @t repository:git)  ~
  |-
  ?~  remaining  stored(repositories settled)
  %=  $
    remaining  t.remaining
    settled  (~(put by settled) -.i.remaining (settle-webhook-repository +.i.remaining))
  ==
::
--
