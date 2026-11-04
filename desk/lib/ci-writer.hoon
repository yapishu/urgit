::  the CI gate's pure rules for every ref writer (Q5).  which refs a
::  write changes, what the gate makes of those changes given what
::  %urgit-ci answers about each ref, and whether an object contains a
::  tip.  %urgit reads %urgit-ci and calls these; ci-writer-vector feeds
::  them fixtures.  nothing here reads a ship or moves a ref.
::
/-  git
/+  ci-candidate
|%
::  what the CI gate makes of one write: it changes no CI-protected ref
::  (%open); it is refused whole, with the answer's status and words
::  (%refuse); or every CI-protected ref it would advance is to be staged
::  as a candidate against its tip while no ref of the write moves (%stage)
::
+$  ci-write
  $%  [%open ~]
      [%refuse status=@ud message=@t]
      [%stage stages=(list [ref=@t head=oid:git base=oid:git])]
  ==
::
::  the ref changes that replace one ref map with another: every ref
::  whose tip differs, as receive commands; a ref only in the old map is
::  a deletion, a ref only in the new map a creation
::
++  ref-changes
  |=  [old=(map @t oid:git) new=(map @t oid:git)]
  ^-  (list receive-command:git)
  %+  weld
    %+  murn  ~(tap by new)
    |=  [ref=@t tip=oid:git]
    ^-  (unit receive-command:git)
    =/  before=(unit oid:git)  (~(get by old) ref)
    ?:  =(before `tip)  ~
    `[before `tip ref]
  %+  murn  ~(tap by old)
  |=  [ref=@t tip=oid:git]
  ^-  (unit receive-command:git)
  ?:  (~(has by new) ref)  ~
  `[`tip ~ ref]
::
::  what the gate makes of a write's changes.  .protection answers, per
::  ref, whether it is CI-protected, or %| with why that cannot be read;
::  it is asked only about a change that moves something.  a
::  CI-protected ref is never deleted and never created by a writer (a
::  creation has no tip to stage a candidate against), and every
::  CI-protected ref the write would advance is returned to be staged;
::  then no ref of the write moves.  an unreadable answer refuses the
::  whole write, protected or not.  a writer never advances a
::  CI-protected ref itself, even to an object %urgit-ci would land: only
::  %urgit's landing path does, which binds the tip and records the
::  landing
::
++  classify
  |=  [changes=(list receive-command:git) protection=$-(@t (each ? @t))]
  ^-  ci-write
  =|  stages=(list [ref=@t head=oid:git base=oid:git])
  |-
  ?~  changes
    ?~  stages  [%open ~]
    [%stage (flop stages)]
  =/  change=receive-command:git  i.changes
  ?:  =(old.change new.change)
    $(changes t.changes)
  =/  protected=(each ? @t)  (protection ref.change)
  ?.  ?=(%& -.protected)
    [%refuse 503 p.protected]
  ?.  p.protected
    $(changes t.changes)
  ?~  new.change
    [%refuse 409 (rap 3 ~['ci-protected ref cannot be deleted: ' ref.change])]
  ?~  old.change
    [%refuse 409 (rap 3 ~['ci-protected ref has no tip to stage a candidate against: ' ref.change])]
  $(changes t.changes, stages [[ref.change u.new.change u.old.change] stages])
::
::  the refusal of a writer that cannot stage (an owner poke, a branch or
::  tag route): ~ lets the write through, since it changes no
::  CI-protected ref
::
++  refusal
  |=  gate=ci-write
  ^-  (unit [status=@ud message=@t])
  ?-  -.gate
    %open  ~
    %refuse  `[status.gate message.gate]
      %stage
    =/  ref=@t  ?~(stages.gate '' ref.i.stages.gate)
    `[409 (rap 3 ~['ci-protected ref advances only by landing a CI candidate or a recorded override: ' ref])]
  ==
::
::  whether .ancestor is .commit or one of its ancestors through commit
::  parent links, searched breadth-first and stopped as soon as it is
::  found; a missing or malformed commit on the way answers no
::
++  commit-contains
  |=  [objects=(map oid:git object:git) commit=oid:git ancestor=oid:git]
  ^-  ?
  =/  pending=(list oid:git)  ~[commit]
  =/  seen=(set oid:git)  ~
  |-
  ?~  pending  %.n
  ?:  =(ancestor i.pending)  %.y
  ?:  (~(has in seen) i.pending)
    $(pending t.pending)
  =/  parents=(unit (list oid:git))  (commit-parents:ci-candidate objects i.pending)
  ?~  parents  %.n
  %=  $
    pending  (weld t.pending u.parents)
    seen  (~(put in seen) i.pending)
  ==
--
