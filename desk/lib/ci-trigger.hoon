::  Automatic events (Delivery 1C): the trigger catalog a resolver's
::  pinned compiler posts beside the lock (runner/internal/plan
::  TriggersOf), checked here structure by structure; the matcher its
::  compiled filter patterns run on; the selection of a push or a pull
::  request activity against a promoted baseline's catalog, with the
::  reason for every workflow; and the payloads act reads for the runs.
::  Nothing here parses YAML, glob or cron text, and nothing scries.
::
::    a malformed catalog is the resolver's error and refuses the whole
::    lock, as a malformed manual inventory does; a refused event or
::    schedule the compiler reports is kept, with its reason, and never
::    selects.  missing change evidence never reads as no match: a path
::    filter it would decide selects its workflow, labelled.
::
/-  ci, git
/+  ci-cron, ci-expr, git-codec
|%
++  catalog-version  1
++  max-workflows  256
++  max-events  64
++  max-patterns  100
++  max-pattern-bytes  256
++  max-tokens  256
++  max-schedules  32
++  max-types  32
++  max-zones  32
++  max-transitions  512
::
::  the pull_request activity types of the captured reference, and the
::  six this forge's native pull requests go through: opened, closed
::  (merged or not), reopened, synchronize when the head moves (a local
::  pull request's source branch moved, or the peer that opened one sent a
::  new head), and labeled and unlabeled, one for each label an owner or
::  writer adds or removes.  GitHub's defaults stay the three below: a
::  workflow runs on a label change only when its types name it
::
++  pull-request-types
  ^-  (set @t)
  %-  silt
  :~  'assigned'  'unassigned'  'labeled'  'unlabeled'  'opened'  'edited'
      'closed'  'reopened'  'synchronize'  'converted_to_draft'  'locked'
      'unlocked'  'enqueued'  'dequeued'  'milestoned'  'demilestoned'
      'ready_for_review'  'review_requested'  'review_request_removed'
      'auto_merge_enabled'  'auto_merge_disabled'
  ==
++  native-pull-types
  `(set @t)`(silt ~['opened' 'reopened' 'closed' 'synchronize' 'labeled' 'unlabeled'])
++  default-pull-types  `(list @t)`~['opened' 'synchronize' 'reopened']
::
::  ---- the catalog ----
::
::  the resolver's catalog (the lock body's `triggers`): ~ when it sent
::  none — a resolver that predates triggers — which is unknown, never an
::  empty catalog
::
++  parse-catalog
  |=  jon=(unit json)
  ^-  (each (unit trigger-catalog:ci) @t)
  ?~  jon  [%& ~]
  ?.  ?=([%o *] u.jon)  [%| 'triggers must be an object']
  =/  f=(map @t json)  p.u.jon
  =/  version=(unit @ud)  (ud-at f 'version')
  ?.  =(`catalog-version version)
    [%| 'trigger catalog version is not 1: this ship reads catalog version 1']
  =/  zones=(each (map @t zone:ci) @t)  (parse-zones (~(get by f) 'zones'))
  ?:  ?=(%| -.zones)  [%| p.zones]
  =/  raw=(unit json)  (~(get by f) 'workflows')
  ?.  ?=([~ %a *] raw)  [%| 'trigger catalog workflows must be a list']
  =/  items=(list json)  p.u.raw
  ?:  (gth (lent items) max-workflows)
    [%| (rap 3 ~['trigger catalog lists ' (crip (a-co:co (lent items))) ' workflows; the bound is 256'])]
  =|  seen=(set @t)
  =|  out=(list trigger-workflow:ci)
  |-
  ?~  items
    =/  workflows=(list trigger-workflow:ci)  (flop out)
    =/  missing=(unit @t)  (unzoned workflows p.zones)
    ?^  missing
      [%| (rap 3 ~['a schedule names timezone ' u.missing ' and the catalog has no table for it'])]
    [%& `[workflows p.zones]]
  =/  one=(each trigger-workflow:ci @t)  (parse-workflow i.items)
  ?:  ?=(%| -.one)  [%| p.one]
  ?:  (~(has in seen) workflow.p.one)
    [%| (rap 3 ~['trigger catalog lists ' workflow.p.one ' twice'])]
  $(items t.items, seen (~(put in seen) workflow.p.one), out [p.one out])
::
::  the first timezone an accepted schedule names that the catalog has no
::  table for
::
++  unzoned
  |=  [workflows=(list trigger-workflow:ci) zones=(map @t zone:ci)]
  ^-  (unit @t)
  =/  names=(list @t)
    %-  zing
    %+  turn  workflows
    |=  w=trigger-workflow:ci
    ^-  (list @t)
    %-  zing
    %+  turn  events.w
    |=  e=trigger-event:ci
    ^-  (list @t)
    %+  murn  schedules.e
    |=  s=schedule-def:ci
    ^-  (unit @t)
    ?:  ?|(?=(^ refusal.s) ?=(~ timezone.s))  ~
    timezone.s
  |-
  ?~  names  ~
  ?.  (~(has by zones) i.names)  `i.names
  $(names t.names)
::
++  parse-workflow
  |=  jon=json
  ^-  (each trigger-workflow:ci @t)
  ?.  ?=([%o *] jon)  [%| 'a catalog workflow is not an object']
  =/  f=(map @t json)  p.jon
  =/  file=(unit @t)  (text-at f 'workflow')
  ?~  file  [%| 'a catalog workflow names no workflow file']
  ?.  (workflow-file-valid u.file)
    [%| (rap 3 ~['catalog workflow ' u.file ' is not a file name under .github/workflows'])]
  =/  where=@t  (rap 3 ~['catalog workflow ' u.file ': '])
  =/  name=@t  (fall (text-at f 'name') u.file)
  =?  name  =('' name)  u.file
  =/  refusal=(unit @t)  (refusal-at f)
  ::  CI-CONCURRENCY-1: its compiled concurrency; absent is unknown
  =/  concurrency=(each (unit concurrency-def:ci) @t)
    (parse-concurrency (~(get by f) 'concurrency'))
  ?:  ?=(%| -.concurrency)  [%| (rap 3 ~[where 'concurrency ' p.concurrency])]
  =/  raw=(unit json)  (~(get by f) 'events')
  ?.  ?=([~ %a *] raw)  [%| (rap 3 ~[where 'events must be a list'])]
  =/  items=(list json)  p.u.raw
  ?:  (gth (lent items) max-events)  [%| (rap 3 ~[where 'more than 64 events'])]
  ?:  ?&(?=(^ refusal) ?=(^ items))  [%| (rap 3 ~[where 'a refused workflow lists no event'])]
  =|  seen=(set @t)
  =|  out=(list trigger-event:ci)
  |-
  ?~  items  [%& u.file name (flop out) refusal p.concurrency]
  =/  one=(each trigger-event:ci @t)  (parse-event i.items)
  ?:  ?=(%| -.one)  [%| (rap 3 ~[where p.one])]
  ?:  (~(has in seen) event.p.one)  [%| (rap 3 ~[where 'event ' event.p.one ' twice'])]
  $(items t.items, seen (~(put in seen) event.p.one), out [p.one out])
::
::  a workflow's compiled concurrency (CI-CONCURRENCY-1): absent is ~,
::  unknown — a catalog an older compiler read, never "no group"; else
::  version 2 and one of none, a group (its template and cancel-in-
::  progress checked by lib/ci-expr for the concurrency field) or a
::  refusal with its reason.  anything else refuses the catalog
::
++  parse-concurrency
  |=  jon=(unit json)
  ^-  (each (unit concurrency-def:ci) @t)
  ?~  jon  [%& ~]
  ?.  ?=([%o *] u.jon)  [%| 'is not an object']
  =/  f=(map @t json)  p.u.jon
  ?.  =(`2 (ud-at f 'v'))  [%| 'is not version 2']
  ?+  (text-at f 'kind')  [%| 'is of an unknown kind']
      [~ %none]  [%& `[%none ~]]
  ::
      [~ %refused]
    =/  reason=(unit @t)  (refusal-at f)
    ?~  reason  [%| 'is refused with no reason']
    :+  %&  ~
    :*  %refused
        (fall (text-at f 'text') '')
        (fall (ud-at f 'line') 0)
        (fall (ud-at f 'col') 0)
        u.reason
    ==
  ::
      [~ %group]
    =/  group=(unit json)  (~(get by f) 'group')
    =/  cancel=(unit json)  (~(get by f) 'cancel')
    ?~  group  [%| 'names no group']
    ?~  cancel  [%| 'names no cancel-in-progress']
    =/  g=(each template:ci @t)  (parse-template:ci-expr u.group %concurrency)
    ?:  ?=(%| -.g)  [%| (rap 3 ~['group ' p.g])]
    =/  c=(each cancel-flag:ci @t)  (parse-cancel:ci-expr u.cancel)
    ?:  ?=(%| -.c)  [%| p.c]
    [%& `[%group p.g p.c]]
  ==
::
::  one event.  a refused one keeps only its name, reason and place
::
++  parse-event
  |=  jon=json
  ^-  (each trigger-event:ci @t)
  ?.  ?=([%o *] jon)  [%| 'an event is not an object']
  =/  f=(map @t json)  p.jon
  =/  event=(unit @t)  (text-at f 'event')
  ?~  event  [%| 'an event has no name']
  ?:  =('' u.event)  [%| 'an event has no name']
  =/  line=@ud  (fall (ud-at f 'line') 0)
  =/  col=@ud  (fall (ud-at f 'col') 0)
  =/  refusal=(unit @t)  (refusal-at f)
  ?^  refusal  [%& u.event refusal ~ ~ ~ ~ %.n ~ line col]
  =/  where=@t  (rap 3 ~['event ' u.event ': '])
  =/  branches=(each (unit filter:ci) @t)  (parse-filter (~(get by f) 'branches'))
  ?:  ?=(%| -.branches)  [%| (rap 3 ~[where 'branches ' p.branches])]
  =/  tags=(each (unit filter:ci) @t)  (parse-filter (~(get by f) 'tags'))
  ?:  ?=(%| -.tags)  [%| (rap 3 ~[where 'tags ' p.tags])]
  =/  paths=(each (unit filter:ci) @t)  (parse-filter (~(get by f) 'paths'))
  ?:  ?=(%| -.paths)  [%| (rap 3 ~[where 'paths ' p.paths])]
  =/  types=(unit (list @t))  (texts-at f 'types')
  ?~  types  [%| (rap 3 ~[where 'types must be a list of activity types'])]
  ?:  (gth (lent u.types) max-types)  [%| (rap 3 ~[where 'more than 32 activity types'])]
  =/  unknown=(unit @t)
    =/  ts=(list @t)  u.types
    |-
    ?~  ts  ~
    ?.  (~(has in pull-request-types) i.ts)  `i.ts
    $(ts t.ts)
  ?^  unknown  [%| (rap 3 ~[where u.unknown ' is not a pull_request activity type'])]
  =/  declared=?  (fall (bool-at f 'typesDeclared') %.n)
  =/  scheds=(each (list schedule-def:ci) @t)  (parse-schedules (~(get by f) 'schedules'))
  ?:  ?=(%| -.scheds)  [%| (rap 3 ~[where p.scheds])]
  ::  a filter belongs to the events the reference defines it for; types
  ::  to a pull request, schedules to a schedule
  ?:  ?&(!=('push' u.event) ?=(^ p.tags))  [%| (rap 3 ~[where 'only a push filters tags'])]
  ?:  ?&(!?=(?(%push %'pull_request') u.event) |(?=(^ p.branches) ?=(^ p.paths)))
    [%| (rap 3 ~[where 'only a push or a pull_request filters branches and paths'])]
  ?:  ?&(!=('pull_request' u.event) ?=(^ u.types))
    [%| (rap 3 ~[where 'only a pull_request has activity types'])]
  ?:  ?&(=('pull_request' u.event) ?=(~ u.types))
    [%| (rap 3 ~[where 'a pull_request lists its activity types'])]
  ?:  ?&(!=('schedule' u.event) ?=(^ p.scheds))
    [%| (rap 3 ~[where 'only a schedule has cron entries'])]
  ?:  ?&(=('schedule' u.event) ?=(~ p.scheds))
    [%| (rap 3 ~[where 'a schedule lists its cron entries'])]
  [%& u.event ~ p.branches p.tags p.paths u.types declared p.scheds line col]
::
::  a filter list: null (none), or {ignore, patterns} with 1 to 100
::  patterns; an -ignore list holds no ! pattern, an include list at
::  least one positive one (the compiler's own rules, checked again)
::
++  parse-filter
  |=  jon=(unit json)
  ^-  (each (unit filter:ci) @t)
  ?~  jon  [%& ~]
  ?~  u.jon  [%& ~]
  ?.  ?=([%o *] u.jon)  [%| 'is not a filter object']
  =/  f=(map @t json)  p.u.jon
  =/  ignore=(unit ?)  (bool-at f 'ignore')
  ?~  ignore  [%| 'names no ignore flag']
  =/  raw=(unit json)  (~(get by f) 'patterns')
  ?.  ?=([~ %a *] raw)  [%| 'patterns must be a list']
  =/  items=(list json)  p.u.raw
  ?:  =(~ items)  [%| 'lists no pattern']
  ?:  (gth (lent items) max-patterns)  [%| 'lists more than 100 patterns']
  =|  out=(list pattern:ci)
  |-
  ?~  items
    =/  ps=(list pattern:ci)  (flop out)
    ?:  ?&(u.ignore (lien ps |=(p=pattern:ci negated.p)))
      [%| 'is an -ignore list holding a ! pattern']
    ?:  ?&(!u.ignore (levy ps |=(p=pattern:ci negated.p)))
      [%| 'holds only ! patterns']
    [%& `[u.ignore ps]]
  =/  one=(each pattern:ci @t)  (parse-pattern i.items)
  ?:  ?=(%| -.one)  [%| p.one]
  $(items t.items, out [p.one out])
::
++  parse-pattern
  |=  jon=json
  ^-  (each pattern:ci @t)
  ?.  ?=([%o *] jon)  [%| 'pattern is not an object']
  =/  f=(map @t json)  p.jon
  =/  text=(unit @t)  (text-at f 'text')
  =/  negated=(unit ?)  (bool-at f 'negated')
  ?~  text  [%| 'pattern has no text']
  ?~  negated  [%| 'pattern has no negated flag']
  ?:  (gth (met 3 u.text) max-pattern-bytes)  [%| 'pattern exceeds 256 bytes']
  ?.  =(u.negated =('!' (end 3 u.text)))
    [%| (rap 3 ~['pattern ' u.text ' is negated exactly when it starts with !'])]
  =/  raw=(unit json)  (~(get by f) 'tokens')
  ?.  ?=([~ %a *] raw)  [%| 'pattern tokens must be a list']
  =/  items=(list json)  p.u.raw
  ?:  =(~ items)  [%| (rap 3 ~['pattern ' u.text ' has no tokens'])]
  ?:  (gth (lent items) max-tokens)  [%| 'pattern has more than 256 tokens']
  =|  out=(list glob-token:ci)
  |-
  ?~  items  [%& u.text u.negated (flop out)]
  =/  one=(each glob-token:ci @t)  (parse-token i.items)
  ?:  ?=(%| -.one)  [%| (rap 3 ~['pattern ' u.text ': ' p.one])]
  $(items t.items, out [p.one out])
::
++  parse-token
  |=  jon=json
  ^-  (each glob-token:ci @t)
  ?.  ?=([%o *] jon)  [%| 'a token is not an object']
  =/  f=(map @t json)  p.jon
  =/  kind=(unit @t)  (text-at f 't')
  ?+  kind  [%| 'a token of an unknown kind']
    [~ %star]  [%& %star ~]
    [~ %globstar]  [%& %globstar ~]
    [~ %dirs]  [%& %dirs ~]
  ::
      [~ %lit]
    =/  c=(unit @t)  (text-at f 'c')
    ?.  ?&(?=(^ c) !=('' u.c))  [%| 'a literal token has no bytes']
    [%& %lit u.c]
  ::
      [~ %class]
    =/  set=(unit @t)  (text-at f 'set')
    ?.  ?&(?=(^ set) (class-valid u.set))  [%| 'a class token is not a set of letters and digits']
    [%& %class u.set]
  ::
      [~ ?(%opt %many)]
    =/  of=(unit json)  (~(get by f) 'of')
    ?~  of  [%| 'a quantifier token quantifies nothing']
    =/  atom=(each glob-atom:ci @t)  (parse-atom u.of)
    ?:  ?=(%| -.atom)  [%| p.atom]
    ?:  =(`'opt' kind)  [%& %opt p.atom]
    [%& %many p.atom]
  ==
::
::  what a quantifier quantifies: one ASCII byte, or a class
::
++  parse-atom
  |=  jon=json
  ^-  (each glob-atom:ci @t)
  ?.  ?=([%o *] jon)  [%| 'a quantified token is not an object']
  =/  f=(map @t json)  p.jon
  ?+  (text-at f 't')  [%| 'a quantifier quantifies a byte or a class']
      [~ %lit]
    =/  c=(unit @t)  (text-at f 'c')
    ?.  ?&(?=(^ c) =(1 (met 3 u.c)) (lth u.c 128))
      [%| 'a quantifier quantifies one ASCII byte']
    [%& %lit u.c]
  ::
      [~ %class]
    =/  set=(unit @t)  (text-at f 'set')
    ?.  ?&(?=(^ set) (class-valid u.set))  [%| 'a class token is not a set of letters and digits']
    [%& %class u.set]
  ==
::
++  class-valid
  |=  set=@t
  ^-  ?
  ?:  =('' set)  %.n
  %+  levy  (rip 3 set)
  |=  b=@
  ?|  &((gte b 'a') (lte b 'z'))
      &((gte b 'A') (lte b 'Z'))
      &((gte b '0') (lte b '9'))
  ==
::
::  the schedule entries of one schedule event: a refused one keeps its
::  text and reason; an accepted one its fields, checked again by the
::  ship's own rules (lib/ci-cron spec-problem), which refuse the entry —
::  not the catalog — when they disagree with the compiler
::
++  parse-schedules
  |=  jon=(unit json)
  ^-  (each (list schedule-def:ci) @t)
  ?~  jon  [%& ~]
  ?~  u.jon  [%& ~]
  ?.  ?=([%a *] u.jon)  [%| 'schedules must be a list']
  =/  items=(list json)  p.u.jon
  ?:  (gth (lent items) max-schedules)  [%| 'more than 32 schedule entries']
  =|  out=(list schedule-def:ci)
  |-
  ?~  items  [%& (flop out)]
  =/  one=(each schedule-def:ci @t)  (parse-schedule i.items)
  ?:  ?=(%| -.one)  [%| p.one]
  $(items t.items, out [p.one out])
::
++  parse-schedule
  |=  jon=json
  ^-  (each schedule-def:ci @t)
  ?.  ?=([%o *] jon)  [%| 'a schedule entry is not an object']
  =/  f=(map @t json)  p.jon
  =/  cron=@t  (fall (text-at f 'cron') '')
  =/  tz=(unit @t)
    =/  t=(unit @t)  (text-at f 'timezone')
    ?~  t  ~
    ?:  =('' u.t)  ~
    t
  =/  refusal=(unit @t)  (refusal-at f)
  ?^  refusal  [%& cron tz refusal ~]
  =/  minutes=(unit (list @ud))  (uds-at f 'minutes')
  =/  hours=(unit (list @ud))  (uds-at f 'hours')
  =/  days=(unit (list @ud))  (uds-at f 'days')
  =/  months=(unit (list @ud))  (uds-at f 'months')
  =/  weekdays=(unit (list @ud))  (uds-at f 'weekdays')
  =/  day-star=(unit ?)  (bool-at f 'dayStar')
  =/  weekday-star=(unit ?)  (bool-at f 'weekdayStar')
  ?.  ?&  ?=(^ minutes)  ?=(^ hours)  ?=(^ days)  ?=(^ months)  ?=(^ weekdays)
          ?=(^ day-star)  ?=(^ weekday-star)
      ==
    [%| (rap 3 ~['schedule ' cron ' has malformed fields'])]
  =/  spec=cron-spec:ci
    [u.minutes u.hours u.days u.months u.weekdays u.day-star u.weekday-star]
  =/  problem=(unit @t)  (spec-problem:ci-cron spec)
  ?^  problem  [%& cron tz `(rap 3 ~['the ship refuses it: ' u.problem]) ~]
  [%& cron tz ~ `spec]
::
::  the zone tables: {name: {start, end, offset, transitions}}, unix
::  seconds and signed offsets in seconds east of UTC (at most 18 hours),
::  each transition strictly inside the horizon and after the one before
::
++  parse-zones
  |=  jon=(unit json)
  ^-  (each (map @t zone:ci) @t)
  ?~  jon  [%& ~]
  ?~  u.jon  [%& ~]
  ?.  ?=([%o *] u.jon)  [%| 'zones must be an object']
  =/  entries=(list [@t json])  ~(tap by p.u.jon)
  ?:  (gth (lent entries) max-zones)  [%| 'more than 32 zone tables']
  =|  out=(map @t zone:ci)
  |-
  ?~  entries  [%& out]
  =/  one=(each zone:ci @t)  (parse-zone +.i.entries)
  ?:  ?=(%| -.one)  [%| (rap 3 ~['zone ' -.i.entries ': ' p.one])]
  $(entries t.entries, out (~(put by out) -.i.entries p.one))
::
++  parse-zone
  |=  jon=json
  ^-  (each zone:ci @t)
  ?.  ?=([%o *] jon)  [%| 'is not an object']
  =/  f=(map @t json)  p.jon
  =/  start=(unit @ud)  (ud-at f 'start')
  =/  end=(unit @ud)  (ud-at f 'end')
  =/  offset=(unit @sd)  (sd-at f 'offset')
  ?.  ?&(?=(^ start) ?=(^ end) ?=(^ offset) (lth u.start u.end))  [%| 'has a malformed horizon']
  ?.  (offset-valid u.offset)  [%| 'has an offset beyond 18 hours']
  =/  raw=(unit json)  (~(get by f) 'transitions')
  ?.  ?=([~ %a *] raw)  [%| 'transitions must be a list']
  =/  items=(list json)  p.u.raw
  ?:  (gth (lent items) max-transitions)  [%| 'more than 512 transitions']
  =/  prev=@ud  u.start
  =|  out=(list [at=@da offset=@sd])
  |-
  ?~  items  [%& (unix-to-da u.start) (unix-to-da u.end) u.offset (flop out)]
  ?.  ?=([%a [%n *] [%n *] ~] i.items)  [%| 'a transition is not [instant, offset]']
  =/  at=(unit @ud)  (rush p.i.p.i.items dim:ag)
  =/  off=(unit @sd)  (parse-sd p.i.t.p.i.items)
  ?.  ?&(?=(^ at) ?=(^ off) (gth u.at prev) (lth u.at u.end) (offset-valid u.off))
    [%| 'has a transition out of order, outside the horizon or beyond 18 hours']
  $(items t.items, prev u.at, out [[(unix-to-da u.at) u.off] out])
::
++  offset-valid
  |=  off=@sd
  ^-  ?
  (lte (abs:si off) 64.800)
::
++  unix-to-da
  |=  secs=@ud
  ^-  @da
  (add ~1970.1.1 (mul secs ~s1))
::
::  ---- the matcher ----
::
::  one state of the byte-level NFA a pattern's tokens compile to, as
::  runner/internal/plan glob.go builds it: a literal run is one state per
::  byte; `**/` is an entry state, which may be skipped, and an inside
::  state, which leaves only after a /
::
+$  nfa-state
  $%  [%byte p=@]
      [%class p=@t]
      [%star ~]
      [%globstar ~]
      [%entry ~]
      [%inside ~]
      [%opt p=glob-atom:ci]
      [%many p=glob-atom:ci]
  ==
::
++  program
  |=  tokens=(list glob-token:ci)
  ^-  (list nfa-state)
  %-  zing
  %+  turn  tokens
  |=  t=glob-token:ci
  ^-  (list nfa-state)
  ?-  -.t
    %lit  (turn (rip 3 p.t) |=(b=@ `nfa-state`[%byte b]))
    %class  ~[[%class p.t]]
    %star  ~[[%star ~]]
    %globstar  ~[[%globstar ~]]
    %dirs  ~[[%entry ~] [%inside ~]]
    %opt  ~[[%opt p.t]]
    %many  ~[[%many p.t]]
  ==
::
++  atom-takes
  |=  [a=glob-atom:ci c=@]
  ^-  ?
  ?-  -.a
    %lit  =(c p.a)
    %class  (lien (rip 3 p.a) |=(b=@ =(b c)))
  ==
::
::  the states reachable without reading a byte: forward edges only, so
::  one pass in order is the whole closure
::
++  closure
  |=  [prog=(list nfa-state) states=@]
  ^-  @
  =/  k=@ud  0
  |-
  ?~  prog  states
  ?.  =(1 (cut 0 [k 1] states))  $(prog t.prog, k +(k))
  =?  states  ?=(?(%star %globstar %opt %many) -.i.prog)  (con states (bex +(k)))
  =?  states  ?=(%entry -.i.prog)  (con states (bex (add k 2)))
  $(prog t.prog, k +(k))
::
++  step
  |=  [prog=(list nfa-state) states=@ c=@]
  ^-  @
  =/  k=@ud  0
  =|  next=@
  |-
  ?~  prog  next
  ?.  =(1 (cut 0 [k 1] states))  $(prog t.prog, k +(k))
  =/  here=@  (bex k)
  =/  on=@  (bex +(k))
  =.  next
    ?-  -.i.prog
      %byte  ?:(=(c p.i.prog) (con next on) next)
      %class  ?:((lien (rip 3 p.i.prog) |=(b=@ =(b c))) (con next on) next)
      %star  ?:(=(c '/') next (con next here))
      %globstar  (con next here)
      %entry  ?:(=(c '/') (con (con next on) (bex (add k 2))) (con next on))
      %inside  ?:(=(c '/') (con (con next here) on) (con next here))
      %opt  ?:((atom-takes p.i.prog c) (con next on) next)
      %many  ?:((atom-takes p.i.prog c) (con next here) next)
    ==
  $(prog t.prog, k +(k))
::
::  whether a pattern's tokens match the whole name, byte by byte
::
++  glob-match
  |=  [tokens=(list glob-token:ci) name=@t]
  ^-  ?
  =/  prog=(list nfa-state)  (program tokens)
  =/  accept=@ud  (lent prog)
  =/  len=@ud  (met 3 name)
  =/  states=@  (closure prog 1)
  =/  i=@ud  0
  |-
  ?:  =(i len)  =(1 (cut 0 [accept 1] states))
  =/  next=@  (step prog states (cut 3 [i 1] name))
  ?:  =(0 next)  %.n
  $(i +(i), states (closure prog next))
::
::  ---- filters ----
::
::  whether a name passes a filter list: an ordered include list starts
::  excluded and each matching pattern includes the name, or excludes it
::  again when negated; an -ignore list excludes it when any pattern
::  matches
::
++  included
  |=  [f=filter:ci name=@t]
  ^-  ?
  ?:  ignore.f
    !(lien patterns.f |=(p=pattern:ci (glob-match tokens.p name)))
  ::  explicitly %.n: a fold over a bare ? would start at its bunt, %.y
  =/  ps=(list pattern:ci)  patterns.f
  =/  in=?  %.n
  |-
  ?~  ps  in
  ?.  (glob-match tokens.i.ps name)  $(ps t.ps)
  $(ps t.ps, in !negated.i.ps)
::
++  filter-text
  |=  [key=@t f=filter:ci]
  ^-  @t
  =/  texts=(list @t)  (turn patterns.f |=(p=pattern:ci text.p))
  (rap 3 ~[key ?:(ignore.f '-ignore' '') ' [' (join texts ', ') ']'])
::
::  the ref condition of a push (the captured reference): a branch is
::  tested against branches/branches-ignore, a tag against tags/tags-
::  ignore; filtering only one kind runs nothing for the other; filtering
::  neither runs both; any other ref selects nothing.  a tag that passes
::  says so when the event also filters paths, which a tag push never
::  reads
::
++  push-ref-selects
  |=  [e=trigger-event:ci ref=@t]
  ^-  [ok=? why=@t]
  =/  branch=(unit @t)  (strip 'refs/heads/' ref)
  =/  tag=(unit @t)  (strip 'refs/tags/' ref)
  ?:  ?&(?=(~ branch) ?=(~ tag))
    [%.n (rap 3 ~[ref ' is neither a branch nor a tag'])]
  ?^  branch
    ?:  ?&(?=(~ branches.e) ?=(^ tags.e))
      [%.n (rap 3 ~['only tags are filtered (' (filter-text 'tags' u.tags.e) '), so a push to branch ' u.branch ' does not run it'])]
    ?~  branches.e  [%.y (rap 3 ~['push to branch ' u.branch ', no branch filter'])]
    ?:  (included u.branches.e u.branch)
      [%.y (rap 3 ~['branch ' u.branch ' passes ' (filter-text 'branches' u.branches.e)])]
    [%.n (rap 3 ~['branch ' u.branch ' does not pass ' (filter-text 'branches' u.branches.e)])]
  ?>  ?=(^ tag)
  ?:  ?&(?=(~ tags.e) ?=(^ branches.e))
    [%.n (rap 3 ~['only branches are filtered (' (filter-text 'branches' u.branches.e) '), so a push of tag ' u.tag ' does not run it'])]
  =/  unread=@t  ?~(paths.e '' '; paths are not evaluated for a tag push')
  ?~  tags.e  [%.y (rap 3 ~['push of tag ' u.tag ', no tag filter' unread])]
  ?:  (included u.tags.e u.tag)
    [%.y (rap 3 ~['tag ' u.tag ' passes ' (filter-text 'tags' u.tags.e) unread])]
  [%.n (rap 3 ~['tag ' u.tag ' does not pass ' (filter-text 'tags' u.tags.e)])]
::
::  the path condition, over the complete set of changed paths: an
::  include list runs when any changed path ends included; an -ignore list
::  when any changed path matches no pattern; no changed path runs nothing
::
++  paths-select
  |=  [f=filter:ci paths=(list @t)]
  ^-  [ok=? why=@t]
  =/  shown=@t  (filter-text 'paths' f)
  =/  count=@t  (crip (a-co:co (lent paths)))
  ?~  paths  [%.n (rap 3 ~['no file changed, so ' shown ' does not run it'])]
  =/  hit=(unit @t)
    =/  ps=(list @t)  paths
    |-
    ?~  ps  ~
    ?:  (included f i.ps)  `i.ps
    $(ps t.ps)
  ?^  hit
    ?:  ignore.f  [%.y (rap 3 ~[u.hit ' is not ignored by ' shown])]
    [%.y (rap 3 ~[u.hit ' passes ' shown])]
  ?:  ignore.f  [%.n (rap 3 ~[shown ' matches every changed path (' count ')'])]
  [%.n (rap 3 ~['no changed path passes ' shown ' (' count ' changed)'])]
::
::  ---- selection ----
::
::  the change evidence a path filter reads: the complete set of changed
::  paths, or why it could not be had (bounded work, a missing object)
::
+$  evidence  (each (list @t) @t)
::
::  what one workflow's declaration of an event selects.  a path filter
::  with no evidence given (~) is not evaluated, exactly as when the
::  evidence could not be had: the workflow runs, labelled
::
++  decide
  |=  $:  w=trigger-workflow:ci
          e=trigger-event:ci
          gate=[ok=? why=@t]
          paths=(unit filter:ci)
          changes=(unit evidence)
      ==
  ^-  workflow-selection:ci
  ?^  refusal.e
    [workflow.w name.w %error (rap 3 ~['the ' event.e ' trigger is refused: ' u.refusal.e])]
  ?.  ok.gate  [workflow.w name.w %excluded why.gate]
  ?~  paths  [workflow.w name.w %selected why.gate]
  =/  have=evidence  (fall changes [%| 'no change evidence was computed'])
  ?:  ?=(%| -.have)
    :^  workflow.w  name.w  %selected
    (rap 3 ~[why.gate '; the path filter is not evaluated (' p.have '), so the workflow runs'])
  =/  by-path=[ok=? why=@t]  (paths-select u.paths p.have)
  ?.  ok.by-path  [workflow.w name.w %excluded (rap 3 ~[why.gate '; but ' why.by-path])]
  [workflow.w name.w %selected (rap 3 ~[why.gate '; ' why.by-path])]
::
::  the declared event of one name, if the workflow declares it
::
++  event-of
  |=  [w=trigger-workflow:ci name=@t]
  ^-  (unit trigger-event:ci)
  =/  es=(list trigger-event:ci)  events.w
  |-
  ?~  es  ~
  ?:  =(name event.i.es)  `i.es
  $(es t.es)
::
::  whether any workflow would read change evidence for this push: the
::  caller computes the (bounded) diff only then
::
++  push-needs-paths
  |=  [cat=trigger-catalog:ci ref=@t]
  ^-  ?
  ?~  (strip 'refs/heads/' ref)  %.n
  %+  lien  workflows.cat
  |=  w=trigger-workflow:ci
  =/  e=(unit trigger-event:ci)  (event-of w 'push')
  ?&(?=(^ e) ?=(~ refusal.u.e) ?=(^ paths.u.e) ok:(push-ref-selects u.e ref))
::
::  a push against a catalog: every workflow that declares push, or whose
::  on: is refused, with its verdict; a workflow that declares no push is
::  not listed (it is not triggered).  .changes is the evidence for a
::  branch; a tag's path filters are never read, whatever is given
::
++  select-push
  |=  [cat=trigger-catalog:ci ref=@t changes=(unit evidence)]
  ^-  (list workflow-selection:ci)
  %+  murn  workflows.cat
  |=  w=trigger-workflow:ci
  ^-  (unit workflow-selection:ci)
  ?^  refusal.w
    `[workflow.w name.w %error (rap 3 ~['the workflow\'s on: is refused: ' u.refusal.w])]
  =/  e=(unit trigger-event:ci)  (event-of w 'push')
  ?~  e  ~
  =/  tag=?  ?=(^ (strip 'refs/tags/' ref))
  `(decide w u.e (push-ref-selects u.e ref) ?:(tag ~ paths.u.e) ?:(tag ~ changes))
::
::  whether any workflow would read change evidence for this activity
::
++  pull-needs-paths
  |=  [cat=trigger-catalog:ci action=@t base-ref=@t]
  ^-  ?
  %+  lien  workflows.cat
  |=  w=trigger-workflow:ci
  =/  e=(unit trigger-event:ci)  (event-of w 'pull_request')
  ?&  ?=(^ e)  ?=(~ refusal.u.e)  ?=(^ paths.u.e)
      ok:(pull-gate u.e action base-ref)
  ==
::
::  the activity and branch condition of a pull request: its activity is
::  one of the declared types (the reference's defaults when undeclared),
::  and its base — the target branch — passes branches/branches-ignore
::
++  pull-gate
  |=  [e=trigger-event:ci action=@t base-ref=@t]
  ^-  [ok=? why=@t]
  =/  types=(list @t)  ?:(types-declared.e types.e default-pull-types)
  =/  shown=@t  (rap 3 ~['types [' (join types ', ') ']'])
  ?~  (find ~[action] types)
    [%.n (rap 3 ~['activity ' action ' is not in ' shown])]
  =/  base=@t  (fall (strip 'refs/heads/' base-ref) base-ref)
  ?~  branches.e  [%.y (rap 3 ~['activity ' action ' is in ' shown ', no branch filter'])]
  ?:  (included u.branches.e base)
    [%.y (rap 3 ~['activity ' action ' is in ' shown '; target ' base ' passes ' (filter-text 'branches' u.branches.e)])]
  [%.n (rap 3 ~['target ' base ' does not pass ' (filter-text 'branches' u.branches.e)])]
::
++  select-pull
  |=  [cat=trigger-catalog:ci action=@t base-ref=@t changes=(unit evidence)]
  ^-  (list workflow-selection:ci)
  %+  murn  workflows.cat
  |=  w=trigger-workflow:ci
  ^-  (unit workflow-selection:ci)
  ?^  refusal.w
    `[workflow.w name.w %error (rap 3 ~['the workflow\'s on: is refused: ' u.refusal.w])]
  =/  e=(unit trigger-event:ci)  (event-of w 'pull_request')
  ?~  e  ~
  `(decide w u.e (pull-gate u.e action base-ref) paths.u.e changes)
::
::  a label change on a pull request that is not open runs nothing: the
::  words its record keeps, or ~ when it is selected as any activity is
::
++  label-outcome
  |=  p=pull-update:ci
  ^-  (unit @t)
  ?~  label.p  ~
  ?:  =(%open state.p)  ~
  `(rap 3 ~['recorded: a label change on a ' state.p ' pull request runs no workflow'])
::
::  the workflows a selection runs
::
++  selected-workflows
  |=  outcomes=(list workflow-selection:ci)
  ^-  (list @t)
  (murn outcomes |=(o=workflow-selection:ci ?.(?=(%selected verdict.o) ~ `workflow.o)))
::
::  the workflows a selection leaves without evidence: excluded or in
::  error.  for a required run, each is required evidence that is absent
::
++  unselected
  |=  outcomes=(list workflow-selection:ci)
  ^-  (list workflow-selection:ci)
  (skip outcomes |=(o=workflow-selection:ci ?=(%selected verdict.o)))
::
::  ---- payloads (what act reads with -e) ----
::
++  zeros  '0000000000000000000000000000000000000000'
::
++  login
  |=  who=@p
  ^-  json
  (pairs:enjs:format ~[['login' s+(scot %p who)]])
::
++  repository-json
  |=  [repo=@t default=(unit @t)]
  ^-  json
  %-  pairs:enjs:format
  :~  ['name' s+repo]
      ['default_branch' ?~(default ~ s+(fall (strip 'refs/heads/' u.default) u.default))]
  ==
::
::  a push event's payload: GitHub's push keys, the ref's before (forty
::  zeros for a new ref) and after, created, never deleted (a deletion runs
::  nothing), the pusher and the sender
::
++  push-event-payload
  |=  [repo=@t ref=@t old=(unit oid:git) new=oid:git actor=@p default=(unit @t)]
  ^-  @t
  %-  en:json:html
  %-  pairs:enjs:format
  :~  ['ref' s+ref]
      ['before' s+?~(old zeros (oid-text:git-codec u.old))]
      ['after' s+(oid-text:git-codec new)]
      ['created' b+?=(~ old)]
      ['deleted' b+%.n]
      ['pusher' (pairs:enjs:format ~[['name' s+(scot %p actor)]])]
      ['sender' (login actor)]
      ['repository' (repository-json repo default)]
  ==
::
::  a pull request activity's payload: GitHub's pull_request keys — the
::  action, the number, the pull request's state, merged flag, title, head
::  (its ref and sha) and base (the target branch and the tip the run
::  integrates onto), its author, its labels after the activity as
::  [{name}] — and the sender.  a labeled or unlabeled activity also
::  names the label added or removed, as {name}, under label
::
++  pull-event-payload
  |=  [repo=@t facts=pull-facts:ci actor=@p default=(unit @t)]
  ^-  @t
  =/  side
    |=  [ref=@t sha=oid:git]
    ^-  json
    %-  pairs:enjs:format
    :~  ['ref' s+(fall (strip 'refs/heads/' ref) ref)]
        ['sha' s+(oid-text:git-codec sha)]
        ['repo' (pairs:enjs:format ~[['name' s+repo]])]
    ==
  =/  named
    |=  name=@t
    ^-  json
    (pairs:enjs:format ~[['name' s+name]])
  =/  labels=json  [%a (turn labels.facts named)]
  =/  label=(list [@t json])
    ?~  label.facts  ~
    ~[['label' (named u.label.facts)]]
  =/  keys=(list [@t json])
    :~  ['action' s+action.facts]
        ['number' (numb:enjs:format number.facts)]
        :-  'pull_request'
        %-  pairs:enjs:format
        :~  ['number' (numb:enjs:format number.facts)]
            ['state' s+?:(=('closed' action.facts) 'closed' 'open')]
            ['merged' b+merged.facts]
            ['title' s+title.facts]
            ['head' (side head-ref.facts head.facts)]
            ['base' (side base-ref.facts base.facts)]
            ['user' (login source-ship.facts)]
            ['labels' labels]
        ==
        ['repository' (repository-json repo default)]
        ['sender' (login actor)]
    ==
  (en:json:html (pairs:enjs:format (weld keys label)))
::
::  a due occurrence's payload: the cron text it fired for (GitHub's
::  github.event.schedule), the repository and its default branch, and the
::  promoter whose promotion authorized it as the sender (act needs one;
::  nobody clicked)
::
++  schedule-event-payload
  |=  [repo=@t default=@t cron=@t promoter=@p]
  ^-  @t
  %-  en:json:html
  %-  pairs:enjs:format
  :~  ['schedule' s+cron]
      ['repository' (repository-json repo `default)]
      ['sender' (login promoter)]
  ==
::
::  ---- the signed trigger (manifest version 5) ----
::
::  the canonical text of the event a run was admitted for, beginning with
::  the event's name: what the runner checks the run's event against
::
++  trigger-text
  |=  c=candidate:ci
  ^-  @t
  ?-  -.trigger.c
      %push
    %+  rap  3
    :~  'push '  ref.c  ' '  (oid-text:git-codec base.c)  '..'
        ?~(candidate.c '' (oid-text:git-codec u.candidate.c))
    ==
  ::
      %dispatch
    (rap 3 ~['workflow_dispatch ' workflow.trigger.c ' request ' request.trigger.c])
  ::
      %event
    =/  e=run-event:ci  run-event.trigger.c
    ?-  kind.e
        %push
      %+  rap  3
      :~  'push '  ref.e  ' '  ?~(before.e zeros (oid-text:git-codec u.before.e))
          '..'  ?~(after.e zeros (oid-text:git-codec u.after.e))
          ' event '  (scot %uv id.e)
      ==
    ::
        %pull-request
      ?~  pull.e  (rap 3 ~['pull_request event ' (scot %uv id.e)])
      %+  rap  3
      :~  'pull_request #'  (crip (a-co:co number.u.pull.e))  ' '  action.u.pull.e
          ' head '  (oid-text:git-codec head.u.pull.e)
          ' base '  (oid-text:git-codec base.u.pull.e)
          ' event '  (scot %uv id.e)
      ==
    ::
        %schedule
      ?~  occurrence.e  (rap 3 ~['schedule occurrence ' (scot %uv id.e)])
      %+  rap  3
      :~  'schedule '  workflow.u.occurrence.e  '#'  (crip (a-co:co index.u.occurrence.e))
          ' due '  (iso-utc:ci-cron due.u.occurrence.e)
          ' occurrence '  (scot %uv id.e)
      ==
    ==
  ==
::
::  the name act runs a candidate's jobs under (`act <event>`)
::
++  event-name
  |=  =trigger:ci
  ^-  @t
  ?-  -.trigger
    %push  'push'
    %dispatch  'workflow_dispatch'
      %event
    ?-  kind.run-event.trigger
      %push  'push'
      %pull-request  'pull_request'
      %schedule  'schedule'
    ==
  ==
::
::  ---- helpers ----
::
++  strip
  |=  [prefix=@t text=@t]
  ^-  (unit @t)
  =/  width=@ud  (met 3 prefix)
  ?.  =(prefix (end [3 width] text))  ~
  =/  rest=@t  (rsh [3 width] text)
  ?:  =('' rest)  ~
  `rest
::
++  join
  |=  [items=(list @t) separator=@t]
  ^-  @t
  ?~  items  ''
  %+  roll  t.items
  |=  [item=@t acc=_i.items]
  (rap 3 ~[acc separator item])
::
++  workflow-file-valid
  |=  file=@t
  ^-  ?
  =/  chars=tape  (trip file)
  ?:  (gth (lent chars) 255)  %.n
  ?:  ?=(^ (find "/" chars))  %.n
  ?:  ?=(^ (find "\\" chars))  %.n
  ?|  &((gth (lent chars) 4) =(".yml" (slag (sub (lent chars) 4) chars)))
      &((gth (lent chars) 5) =(".yaml" (slag (sub (lent chars) 5) chars)))
  ==
::
++  text-at
  |=  [f=(map @t json) key=@t]
  ^-  (unit @t)
  =/  v=(unit json)  (~(get by f) key)
  ?.  ?=([~ %s *] v)  ~
  `p.u.v
::
::  a refusal: null or '' is none
::
++  refusal-at
  |=  f=(map @t json)
  ^-  (unit @t)
  =/  t=(unit @t)  (text-at f 'refusal')
  ?~  t  ~
  ?:  =('' u.t)  ~
  t
::
++  bool-at
  |=  [f=(map @t json) key=@t]
  ^-  (unit ?)
  =/  v=(unit json)  (~(get by f) key)
  ?.  ?=([~ %b *] v)  ~
  `p.u.v
::
++  ud-at
  |=  [f=(map @t json) key=@t]
  ^-  (unit @ud)
  =/  v=(unit json)  (~(get by f) key)
  ?.  ?=([~ %n *] v)  ~
  (rush p.u.v dim:ag)
::
++  parse-sd
  |=  text=@t
  ^-  (unit @sd)
  ?:  =('-' (end 3 text))
    =/  n=(unit @ud)  (rush (rsh 3 text) dim:ag)
    ?~(n ~ `(new:si %.n u.n))
  =/  n=(unit @ud)  (rush text dim:ag)
  ?~(n ~ `(new:si %.y u.n))
::
++  sd-at
  |=  [f=(map @t json) key=@t]
  ^-  (unit @sd)
  =/  v=(unit json)  (~(get by f) key)
  ?.  ?=([~ %n *] v)  ~
  (parse-sd p.u.v)
::
::  a list of text: null is the empty list; anything but text refuses
::
++  texts-at
  |=  [f=(map @t json) key=@t]
  ^-  (unit (list @t))
  =/  v=(unit json)  (~(get by f) key)
  ?~  v  `~
  ?~  u.v  `~
  ?.  ?=([%a *] u.v)  ~
  =/  out=(list @t)  (murn p.u.v |=(j=json ?.(?=([%s *] j) ~ `p.j)))
  ?.  =((lent out) (lent p.u.v))  ~
  `out
::
++  uds-at
  |=  [f=(map @t json) key=@t]
  ^-  (unit (list @ud))
  =/  v=(unit json)  (~(get by f) key)
  ?.  ?=([~ %a *] v)  ~
  =/  out=(list @ud)
    %+  murn  p.u.v
    |=  j=json
    ?.  ?=([%n *] j)  ~
    (rush p.j dim:ag)
  ?.  =((lent out) (lent p.u.v))  ~
  `out
--
