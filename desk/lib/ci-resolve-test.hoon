::  Executable vectors over the same transitions/guards the controller uses.
::  Fixture creation supplies records, never a second implementation of policy.
/-  ci, git
/+  ci-input, ci-provenance, ci-resolve, ci-tag, ci-trigger
|%
++  fixture
  ^-  [s=state-0:ci c=candidate:ci r=candidate:ci a=attempt:ci b=daemon:ci]
  =/  c=candidate:ci  *candidate:ci
  =.  c
    %=  c
      id  (sham [%ci-event-run 0v10])
      repo  'demo'
      ref  'refs/tags/v1'
      head  0x123
      base  0x123
      candidate  `0x123
      baseline  `0x123
      status  %pending
      trust  %untrusted
      mode  %event
      incarnation  0v7
      generation  1
      actor  ~zod
      trigger  [%event [0v10 %push 'refs/tags/v1' ~ `0x456 ~ ~ ~zod 'tag API' ~2026.10.17 '{}']]
    ==
  =/  r=candidate:ci
    %=  c
      id  (sham [%ci-tag-resolve id.c])
      ref  'refs/ci/resolve'
      baseline  ~
      mode  %shadow
      attempts  ~[0v1]
    ==
  =/  a=attempt:ci  *attempt:ci
  =.  a
    %=  a
      id  0v1
      candidate  id.r
      assignment  0v11
      daemon  0v2
      kind  %resolve
      status  %running
      started  ~2026.10.17
      generation  1
    ==
  =/  d=daemon:ci  *daemon:ci
  =.  d
    %=  d
      id  0v2
      enrolled  `~2026.10.17
      bearer-hash  `0xbeef
      last-seen  `~2026.10.17
      capacity  1
      resolver  %.y
      running  (silt ~[id.a])
    ==
  =/  b=daemon:ci  d(id 0v3, running ~)
  =/  asg=assignment:ci  *assignment:ci
  =.  asg  asg(id 0v11, candidate id.r, daemon id.d, attempt id.a, kind %resolve)
  =/  s=state-0:ci  *state-0:ci
  =.  s
    %=  s
      candidates  (my ~[[id.c c] [id.r r]])
      attempts  (my ~[[id.a a]])
      assignments  (my ~[[id.asg asg]])
      daemons  (my ~[[id.d d] [id.b b]])
      tag-runs  (my ~[[id.c `id.a]])
      input-snapshots  %-  my
                       ~[[id.c ~['https://inputs.example/tool']] [id.r ~['https://inputs.example/tool']]]
      read-capabilities  (my ~[[0x11 [id.a (silt ~['demo']) ~2026.10.18]]])
      mirror-tokens  (my ~[[id.a (silt ~['ci-mirror-fixture'])]])
      generations  (my ~[['demo' 1]])
      incarnations  (my ~[['demo' 0v7]])
    ==
  [s c r a b]
::
++  vectors
  ^-  (list [name=@t ok=?])
  =+  fixture
  =/  now=@da  ~2026.10.17..00.01.00
  ::  Revoke/unfetched uses this exact reoffer transition, not a state model.
  =/  given=state-0:ci  (reoffer:ci-resolve s a 'daemon revoked; re-offered' now)
  =/  next  (next:ci-resolve given c)
  ?>  ?=(%offer -.next)
  =/  absent=(map daemon-id:ci daemon:ci)
    (~(del by daemons.given) id.b)
  =/  chosen=(unit daemon-id:ci)
    (choose:ci-resolve daemons.given now ~m5 repo.c exclude.next)
  ::  Generic create-attempt supplies the replacement. bind-attempt is the
  ::  actual controller transition that updates every live dependent run.
  =/  replacement=attempt:ci  a(id 0v4, daemon id.b, assignment 0v12, started now)
  =/  replaced=state-0:ci
    %=  given
      attempts  (~(put by attempts.given) id.replacement replacement)
      candidates  (~(put by candidates.given) id.r r(attempts [id.replacement attempts.r]))
    ==
  =.  replaced  (bind-attempt:ci-resolve replaced c id.replacement)
  =/  c2=candidate:ci  (~(got by candidates.replaced) id.c)
  =/  clean  (sweep:ci-resolve replaced now)
  =/  finished=attempt:ci  a(status %passed, finished `now)
  =/  failed=attempt:ci  a(status %failed, reason `'bad catalog', finished `now)
  =/  unknown=attempt:ci  a(status %infrastructure-error, finished `now)
  ::  Cancellation after policy generation changes, before delivery.
  =/  cancelled=state-0:ci
    (cancel:ci-resolve s c 'cancelled: policy generation 2' now)
  =.  generations.cancelled  (~(put by generations.cancelled) repo.c 2)
  =/  retired  (sweep:ci-resolve cancelled now)
  =/  dead=attempt:ci  (~(got by attempts.state.retired) id.a)
  =/  rr=candidate:ci  (~(got by candidates.state.retired) id.r)
  ::  Approval produces a trusted twin with the same captured binding.
  =/  fresh=candidate:ci
    c(id (sham [%ci-event-approved id.c]), trust %trusted, attempts ~)
  =/  twin=candidate:ci  (twin:ci-resolve c fresh)
  =/  approved=state-0:ci  (approve:ci-resolve s c twin now)
  =/  held  (sweep:ci-resolve approved now)
  =/  reoffered-twin=state-0:ci  (reoffer:ci-resolve approved a 'unfetched; re-offered' now)
  =.  attempts.reoffered-twin
    (~(put by attempts.reoffered-twin) id.replacement replacement)
  =.  candidates.reoffered-twin
    (~(put by candidates.reoffered-twin) id.r r(attempts [id.replacement attempts.r]))
  =/  rebound-twin=state-0:ci  (bind-attempt:ci-resolve reoffered-twin twin id.replacement)
  =/  cancelled-twin=state-0:ci  (cancel:ci-resolve approved twin 'policy generation 2' now)
  =/  retired-twin  (sweep:ci-resolve cancelled-twin now)
  ::  A successful captured lock selects once; no ref lookup is performed.
  =/  catalog=trigger-catalog:ci
    [~[['release.yml' 'Release' ~[['push' ~ ~ ~ ~ ~ %.n ~ 1 1]] ~ ~]] ~]
  =/  lock=lock:ci  [0x99 repo.c head.c ~ now id.b 0 ~ ~ `catalog]
  =/  bound  (bind-lock:ci-tag c2 lock)
  ?>  ?=(%& -.bound)
  =/  selected=candidate:ci  p.bound
  ?>  ?=(^ selected.selected)
  =/  selected-state=state-0:ci
    replaced(candidates (~(put by candidates.replaced) id.c selected))
  ::  Supported state5 explicit records retain their established purpose.
  =/  explicit=candidate:ci  r(id (sham [%ci-resolve repo.r head.r]), trigger [%push ~])
  =/  import=attempt:ci  a(candidate id.explicit)
  =/  explicit-state=state-0:ci
    s(candidates (my ~[[id.explicit explicit]]), attempts (my ~[[id.a import]]), tag-runs ~)
  ::  Cancellation of a stale owner must not cancel its approved twin's
  ::  shared resolver even when the owner's history lists that attempt.
  =/  shared-cancel=state-0:ci
    (cancel:ci-resolve approved c(attempts ~[id.a]) 'superseded owner cancelled' now)
  =/  shared-sweep  (sweep:ci-resolve shared-cancel now)
  =/  changed=state-0:ci
    approved(generations (~(put by generations.approved) repo.c 2))
  =/  cancelled-import=state-0:ci
    (cancel:ci-resolve explicit-state explicit 'explicit obligation cancelled' now)
  =/  manifest=manifest:ci-provenance  *manifest:ci-provenance
  :~  ['automatic signed domain rejects older runners' =(6 (manifest-version-for:ci-provenance manifest(mode 'resolve-tag')))]
      ['explicit signed domain stays compatible' =(5 (manifest-version-for:ci-provenance manifest(mode 'resolve')))]
      ['ordinary jobs keep their signed domain' =(5 (manifest-version-for:ci-provenance manifest(mode 'event')))]
      ['automatic purpose is source-bound' =(%tag (purpose:ci-resolve r))]
      ['missing automatic provenance cannot elevate to import' =(%invalid (purpose:ci-resolve r(trigger [%push ~])))]
      ['unknown synthetic identity refuses' =(%invalid (purpose:ci-resolve r(id 0v99)))]
      ['legacy explicit purpose preserved' =(%import (purpose:ci-resolve explicit))]
      ['legacy explicit obligation needs no tag consumer' (active:ci-resolve explicit-state import)]
      ['explicit cancellation does not gain shared automatic immunity' =(%cancelled status:(~(got by attempts.cancelled-import) id.a))]
      ['live automatic delivery/inventory/lock allowed' (active:ci-resolve s a)]
      ['captured lock consumer allowed' (accepts:ci-resolve s id.c id.a)]
      ['initial absent resolver is an offer' ?=([%offer *] (next:ci-resolve s(tag-runs (my ~[[id.c ~]])) c))]
      ['reoffer is not terminal failure' =(`id.r record.next)]
      ['old daemon excluded' (~(has in exclude.next) daemon.a)]
      ['second resolver chosen' =(`id.b chosen)]
      ['missing replacement stays pending' =(~ (choose:ci-resolve absent now ~m5 repo.c exclude.next))]
      ['nonresolver cannot take replacement' =(~ (choose:ci-resolve (my ~[[id.b b(resolver %.n)]]) now ~m5 repo.c exclude.next))]
      ['later eligible resolver resumes same record' =(`id.b (choose:ci-resolve daemons.given now ~m5 repo.c exclude.next))]
      ['replacement captures same source event actor and policy' =([head candidate baseline trigger actor generation incarnation]:c [head candidate baseline trigger actor generation incarnation]:c2)]
      ['replacement binding stored' =(`id.replacement (~(got by tag-runs.replaced) id.c))]
      ['replacement lock accepted' (accepts:ci-resolve replaced id.c id.replacement)]
      ['old completion refused' !(accepts:ci-resolve replaced id.c id.a)]
      ['old delivery refused' !(active:ci-resolve replaced (~(got by attempts.replaced) id.a))]
      ['even running stale binding refuses' !(active:ci-resolve replaced a)]
      ['old attempt history retained' =(%reoffered status:(~(got by attempts.replaced) id.a))]
      ['reoffer retains resolver source' =(~ release.clean)]
      ['closed reoffer read authority removed' =(~ read-capabilities.state.clean)]
      ['closed reoffer mirror authority removed' =(~ mirror-tokens.state.clean)]
      ['closed reoffer mirror clear emitted' =((silt ~['ci-mirror-fixture']) mirrors.clean)]
      ['true failure terminal' ?=([%failed *] (next:ci-resolve s(attempts (my ~[[id.a failed]])) c))]
      ['catalog-less completion terminal' ?=([%failed *] (next:ci-resolve s(attempts (my ~[[id.a finished]])) c))]
      ['uncertain effects are terminal' ?=([%failed *] (next:ci-resolve s(attempts (my ~[[id.a unknown]])) c))]
      ['completed attempt cannot be reoffered' =(s (reoffer:ci-resolve s finished 'retry' now))]
      ['one selected workflow' =(~['release.yml'] (selected-workflows:ci-trigger outcomes.u.selected.selected))]
      ['selected input never rebound' =([%& selected] (bind-lock:ci-tag selected lock))]
      ['completion replay has no live consumer' !(accepts:ci-resolve selected-state id.c id.replacement)]
      ['cancelled parent refuses before sweep' !(active:ci-resolve cancelled a)]
      ['cancelled resolver attempt retired' =(%cancelled status.dead)]
      ['synthetic candidate retired' =(%skipped status.rr)]
      ['resolver retention released exactly once' =(~[id.r] release.retired)]
      ['deadline retirement emitted' =(~[id.a] stop.retired)]
      ['retired read capabilities gone' =(~ read-capabilities.state.retired)]
      ['retired mirror tokens gone' =(~ mirror-tokens.state.retired)]
      ['retired runner slot removed' =(~ running:(~(got by daemons.state.retired) daemon.a))]
      ['undelivered assignment retained as history' =(assignments.s assignments.state.retired)]
      ['orphan late inventory and lock refuse' !(active:ci-resolve state.retired dead)]
      ['orphan late completion refuses' !(accepts:ci-resolve state.retired id.c id.a)]
      ['event tombstone retained' =(tag-runs.s tag-runs.state.retired)]
      ['retirement idempotent' =([state.retired ~ ~ ~] (sweep:ci-resolve state.retired now))]
      ['approval preserves captured inputs' =([candidate baseline lock trigger generation incarnation]:c [candidate baseline lock trigger generation incarnation]:twin)]
      ['superseded original keeps tombstone' =(`id.a (~(got by tag-runs.approved) id.c))]
      ['approved twin shares live resolver' =(`id.a (~(got by tag-runs.approved) id.twin))]
      ['approval copies immutable input policy' =((captured:ci-input s id.c) (captured:ci-input approved id.twin))]
      ['cancelling one owner preserves live twin resolver' (active:ci-resolve shared-cancel a)]
      ['cancelling one owner preserves runner slot' (~(has in running:(~(got by daemons.shared-cancel) daemon.a)) id.a)]
      ['cancelling one owner preserves source retention' =(~ release.shared-sweep)]
      ['policy generation change immediately refuses obsolete completion' !(accepts:ci-resolve changed id.twin id.a)]
      ['approved twin permits delivery and inventory' (active:ci-resolve state.held a)]
      ['approved twin prevents source/capability retirement' =([~ ~ ~] [release mirrors stop]:held)]
      ['approved twin binds replacement' =(`id.replacement (~(got by tag-runs.rebound-twin) id.twin))]
      ['superseded history not rewritten by reoffer' =(`id.a (~(got by tag-runs.rebound-twin) id.c))]
      ['last twin cancellation retires resolver' =(~[id.r] release.retired-twin)]
      ['completed/explicit obligations not reset by sweep' =(explicit-state state:(sweep:ci-resolve explicit-state now))]
  ==
::
++  test-resolver-lifecycle
  ^-  ?
  (levy vectors |=([name=@t ok=?] ok))
--
