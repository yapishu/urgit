::  Persisted repository %1 to %2, %3 to %4 and %4 to %5 migration vectors,
::  and every stored state from %0 through %4 loaded as state-5.
::
/-  git
/+  git-migrate
:-  %say
|=  *
:-  %noun
=/  =oid:git  0x1234
=/  when=@da  ~2026.8.19
=/  refs=(map @t oid:git)
  (my ~[['refs/heads/main' oid]])
=/  protected-refs=(set @t)
  (silt ~['refs/heads/main'])
=/  objects=(map oid:git object:git)
  (my ~[[oid [%blob [4 0x7473.6574]]]])
=/  writers=(set @p)
  (silt ~[~zod ~nec])
=/  lfs-objects=(map @t lfs-object:git)
  (my ~[['sha256:fixture' [4 'objects/fixture']]])
=/  lfs-uploads=(map @t lfs-upload:git)
  (my ~[['sha256:upload' [8 'uploads/fixture' when]]])
=/  lfs-locks=(map @ud lfs-lock:git)
  (my ~[[7 [7 'src/main.hoon' '~zod' when]]])
=/  binding=(unit desk-binding:git)
  `[%urgit 'refs/heads/main' `12 `oid ~[[12 oid %git-to-clay when]]]
=/  peer-origin=(unit peer-origin:git)
  `[~nec 'upstream']
=/  github-origin=(unit github-origin:git)
  `['nousresearch' 'urgit']
=/  github-issues=(list forge-item:git)
  ~[[1 'Migration issue' 'open' 'https://example.test/issues/1' 'zod' %.n]]
=/  github-pulls=(list forge-item:git)
  ~[[2 'Migration pull' 'open' 'https://example.test/pulls/2' 'nec' %.y]]
=/  native-pulls=(list native-pull-1:git)
  :~  :-  3
      :*  ~nec
          'fork'
          'Native pull'
          %open
          oid
          oid
          ~[[1 ~zod 'review' when `'src/main.hoon' `7 `%head %.n]]
      ==
  ==
=/  native-issues=(list native-issue:git)
  :~  :-  4
      :*  ~nec
          'Native issue'
          'body'
          %open
          (silt ~['migration'])
          (silt ~[~zod])
          when
          when
          ~[[1 ~zod 'issue reply' when]]
      ==
  ==
=/  releases=(map @t release:git)
  (my ~[['v2' ['v2' 'Migration release' 'notes' ~zod when]]])
=/  webhooks=(map @ud webhook:git)
  %-  my
  :~  :*  1
          :*  1
              'https://example.test/hook'
              'secret'
              (silt ~[`webhook-event:git`%push `webhook-event:git`%issue])
              %.y
          ==
      ==
  ==
=/  incoming-hook=(unit incoming-hook:git)
  `['incoming-secret' %.y]
=/  webhook-deliveries=(list webhook-delivery:git)
  ~[[`@uv`10 1 %push %success 204 'delivered' when]]
=/  upstream-updates=(list upstream-update:git)
  ~[[`@uv`11 'github' 'refs/heads/main' 'before' 'after' when]]
=/  notification-events=(set notification-event:git)
  (silt ~[`notification-event:git`%issue `notification-event:git`%pull-request])
=/  old=repository-1:git
  :*  ~zod
      %.n
      'migration fixture'
      'refs/heads/main'
      refs
      protected-refs
      objects
      writers
      `0xdead.beef
      lfs-objects
      lfs-uploads
      lfs-locks
      binding
      peer-origin
      github-origin
      github-issues
      github-pulls
      native-pulls
      native-issues
      releases
      webhooks
      incoming-hook
      webhook-deliveries
      upstream-updates
      notification-events
  ==
=/  migrated=repository-3:git
  (repository-1-to-2:git-migrate old)
=/  old-pull=native-pull-1:git  (snag 0 native-pulls.old)
=/  migrated-pull=native-pull-4:git  (snag 0 native-pulls.migrated)
=/  expected=repository-3:git
  :*  owner.old
      public-read.old
      description.old
      head.old
      refs.old
      protected-refs.old
      objects.old
      writers.old
      ~
      write-token-hash.old
      lfs-objects.old
      lfs-uploads.old
      lfs-locks.old
      binding.old
      peer-origin.old
      github-origin.old
      github-issues.old
      github-pulls.old
      :~  :*  number.old-pull
              source-ship.old-pull
              source-repository.old-pull
              ''
              head.old
              title.old-pull
              state.old-pull
              head.old-pull
              base.old-pull
              comments.old-pull
          ==
      ==
      native-issues.old
      releases.old
      webhooks.old
      incoming-hook.old
      webhook-deliveries.old
      upstream-updates.old
      notification-events.old
  ==
?>  =(expected migrated)
?>  =(~ readers.migrated)
?>  =('' source-ref.migrated-pull)
?>  =(head.old target-ref.migrated-pull)
?>  =(number.old-pull number.migrated-pull)
?>  =(source-ship.old-pull source-ship.migrated-pull)
?>  =(source-repository.old-pull source-repository.migrated-pull)
?>  =(title.old-pull title.migrated-pull)
?>  =(state.old-pull state.migrated-pull)
?>  =(head.old-pull head.migrated-pull)
?>  =(base.old-pull base.migrated-pull)
?>  =(comments.old-pull comments.migrated-pull)
::  a stored %3 repository comes forward field for field with no group policy
::
=/  current=repository-4:git  (repository-3-to-4:git-migrate migrated)
?>  =(~ group-policy.current)
=/  expected-current=repository-4:git
  :*  owner.migrated
      public-read.migrated
      description.migrated
      head.migrated
      refs.migrated
      protected-refs.migrated
      objects.migrated
      writers.migrated
      readers.migrated
      write-token-hash.migrated
      lfs-objects.migrated
      lfs-uploads.migrated
      lfs-locks.migrated
      binding.migrated
      peer-origin.migrated
      github-origin.migrated
      github-issues.migrated
      github-pulls.migrated
      native-pulls.migrated
      native-issues.migrated
      releases.migrated
      webhooks.migrated
      incoming-hook.migrated
      webhook-deliveries.migrated
      upstream-updates.migrated
      notification-events.migrated
      ~
  ==
?>  =(expected-current current)
?>  =(readers.migrated readers.current)
?>  =(writers.migrated writers.current)
::  a stored %4 repository comes forward field for field, and each pull
::  request starts with no labels
::
=/  fifth=repository:git  (repository-4-to-5:git-migrate current)
=/  current-pull=native-pull-4:git  (snag 0 native-pulls.current)
=/  fifth-pull=native-pull:git  (snag 0 native-pulls.fifth)
?>  =(~ labels.fifth-pull)
?>  =((lent native-pulls.current) (lent native-pulls.fifth))
?>  .=  current-pull
    :*  number.fifth-pull
        source-ship.fifth-pull
        source-repository.fifth-pull
        source-ref.fifth-pull
        target-ref.fifth-pull
        title.fifth-pull
        state.fifth-pull
        head.fifth-pull
        base.fifth-pull
        comments.fifth-pull
    ==
=/  expected-fifth=repository:git
  :*  owner.current
      public-read.current
      description.current
      head.current
      refs.current
      protected-refs.current
      objects.current
      writers.current
      readers.current
      write-token-hash.current
      lfs-objects.current
      lfs-uploads.current
      lfs-locks.current
      binding.current
      peer-origin.current
      github-origin.current
      github-issues.current
      github-pulls.current
      ~[(pull-4-to-5:git-migrate current-pull)]
      native-issues.current
      releases.current
      webhooks.current
      incoming-hook.current
      webhook-deliveries.current
      upstream-updates.current
      notification-events.current
      group-policy.current
  ==
?>  =(expected-fifth fifth)
::  every stored state loads as state-5 through each later conversion, as
::  on-load chains them: %0 and %1 hold the repository-1 fixture (as the
::  repository-0 it extends, for %0), %4 the converted repository-4 with a
::  queued fork, which is kept
::
=/  old-0=repository-0:git
  :*  owner.old
      public-read.old
      description.old
      head.old
      refs.old
      protected-refs.old
      objects.old
      writers.old
      write-token-hash.old
      lfs-objects.old
      lfs-uploads.old
      lfs-locks.old
      binding.old
      peer-origin.old
      github-origin.old
      github-issues.old
      github-pulls.old
      native-pulls.old
      native-issues.old
      releases.old
      webhooks.old
      incoming-hook.old
      webhook-deliveries.old
      upstream-updates.old
  ==
=/  queue=(map @uv peer-prepare-entry:git)
  (my ~[[`@uv`12 [~nec [`@uv`12 'demo' ~]]]])
=/  stored-0=state-0:git  [%0 (my ~[['demo' old-0]]) (silt ~[~nec]) `'token']
=/  stored-1=state-1:git  [%1 (my ~[['demo' old]]) (silt ~[~nec]) `'token']
=/  stored-4=state-4:git  [%4 (my ~[['demo' current]]) (silt ~[~nec]) `'token' queue]
=/  from-0=state-5:git
  %-  migrate-state-4:git-migrate
  %-  migrate-state-3:git-migrate
  %-  migrate-state-2:git-migrate
  %-  migrate-state-1:git-migrate
  (migrate-state-0:git-migrate stored-0)
=/  from-1=state-5:git
  %-  migrate-state-4:git-migrate
  %-  migrate-state-3:git-migrate
  (migrate-state-2:git-migrate (migrate-state-1:git-migrate stored-1))
=/  from-4=state-5:git  (migrate-state-4:git-migrate stored-4)
?>  =(%5 -.from-0)
?>  =(%5 -.from-1)
?>  =(%5 -.from-4)
?>  =((my ~[['demo' fifth]]) repositories.from-1)
?>  =((my ~[['demo' fifth]]) repositories.from-4)
?>  =(queue peer-prepare-queue.from-4)
?>  =([(silt ~[~nec]) `'token'] [peers github-token]:from-4)
::  %0 predates notification events: its repository gains the default
::  events, and is otherwise the %1 one
=/  zero=repository:git  (~(got by repositories.from-0) 'demo')
?>  =(fifth zero(notification-events notification-events.fifth))
?>  (levy native-pulls.zero |=(p=native-pull:git =(~ labels.p)))
::  on-load settles webhook deliveries on the loaded state-5
?>  =(%5 -:(settle-webhook-state:git-migrate from-4))
%.y
