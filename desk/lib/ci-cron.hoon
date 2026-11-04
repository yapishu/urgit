::  Schedules (Delivery 1C): the calendar a compiled cron line runs on.
::  The pinned compiler (runner/internal/plan cron.go) reads the cron
::  text and the IANA zone; the ship checks the fields again here, finds
::  each next due instant in UTC or over the zone's pinned offset table,
::  and decides what a due wake admits.  Nothing here reads host time
::  zones, parses cron text or scries; every instant is given.
::
::    a local time skipped at spring-forward runs at the transition (the
::    first valid time, as the captured reference says: 2:30 → 3:00), and
::    several skipped times are that one instant; a local time repeated at
::    fall-back runs once, at its first instance (a native choice: the
::    reference documents none).  an instant outside the table's horizon
::    refuses, never falls back to UTC.
::
/-  ci
|%
++  min-gap  5
::  eight years and two days: a 29 February schedule finds its day across
::  a century's skipped leap year
++  max-search-days  2.930
++  late-after  ~s60
++  max-missed  10.000
::
::  ---- the ship's own checks of a compiled entry ----
::
::  ~ when the fields are sorted distinct values in their ranges, the
::  schedule is no more frequent than every five minutes, and it occurs
::
++  spec-problem
  |=  s=cron-spec:ci
  ^-  (unit @t)
  ?.  (field-ok minutes.s 0 59)  `'its minutes are not distinct ascending values 0-59'
  ?.  (field-ok hours.s 0 23)  `'its hours are not distinct ascending values 0-23'
  ?.  (field-ok days.s 1 31)  `'its days of the month are not distinct ascending values 1-31'
  ?.  (field-ok months.s 1 12)  `'its months are not distinct ascending values 1-12'
  ?.  (field-ok weekdays.s 0 6)  `'its days of the week are not distinct ascending values 0-6'
  =/  gap=@ud  (gap-of s)
  ?:  (lth gap min-gap)
    `(rap 3 ~['the schedule runs ' (crip (a-co:co gap)) ' minute(s) apart; scheduled workflows run at most once every five minutes'])
  ?.  (occurs s)  `'the schedule never occurs: none of its months has that day of the month'
  ~
::
++  field-ok
  |=  [vs=(list @ud) lo=@ud hi=@ud]
  ^-  ?
  ?:  =(~ vs)  %.n
  =/  prev=(unit @ud)  ~
  |-
  ?~  vs  %.y
  ?:  |((lth i.vs lo) (gth i.vs hi))  %.n
  ?:  &(?=(^ prev) (lte i.vs u.prev))  %.n
  $(vs t.vs, prev `i.vs)
::
::  the fewest minutes between two consecutive times of a day: within an
::  hour, and from an hour's last minute to the next selected hour's first
::  (23 to 0 counted whatever the days: the compiler's rule)
::
++  gap-of
  |=  s=cron-spec:ci
  ^-  @ud
  ?~  minutes.s  0
  =/  ms=(list @ud)  minutes.s
  =/  gap=@ud  60
  =.  gap
    |-
    ?~  ms  gap
    ?~  t.ms  gap
    $(ms t.ms, gap (min gap (sub i.t.ms i.ms)))
  =/  wraps=?
    %+  lien  hours.s
    |=  h=@ud
    ?=(^ (find ~[(mod +(h) 24)] hours.s))
  ?.  wraps  gap
  (min gap (sub (add 60 i.minutes.s) (rear minutes.s)))
::
::  whether any date satisfies the day fields (the compiler's rule)
::
++  occurs
  |=  s=cron-spec:ci
  ^-  ?
  ?:  |(day-star.s !weekday-star.s)  %.y
  %+  lien  months.s
  |=  m=@ud
  (lien days.s |=(d=@ud (lte d (max-day m))))
::
++  max-day
  |=  m=@ud
  ^-  @ud
  ?:  =(2 m)  29
  ?:  ?=(^ (find ~[m] `(list @ud)`~[4 6 9 11]))  30
  31
::
++  has
  |=  [vs=(list @ud) v=@ud]
  ^-  ?
  ?=(^ (find ~[v] vs))
::
::  the day rule for one date: both day fields when either begins with *,
::  else either (Vixie/cronie)
::
++  day-matches
  |=  [s=cron-spec:ci month=@ud mday=@ud wday=@ud]
  ^-  ?
  ?.  (has months.s month)  %.n
  =/  dom=?  (has days.s mday)
  =/  dow=?  (has weekdays.s wday)
  ?:  |(day-star.s weekday-star.s)  &(dom dow)
  |(dom dow)
::
::  ---- time ----
::
++  unix
  |=  at=@da
  ^-  @ud
  ?:  (lth at ~1970.1.1)  0
  (div (sub at ~1970.1.1) ~s1)
::
++  from-unix
  |=  secs=@ud
  ^-  @da
  (add ~1970.1.1 (mul secs ~s1))
::
::  an offset as a sign (east of UTC) and seconds
::
+$  offset  [east=? secs=@ud]
::
++  to-offset
  |=  off=@sd
  ^-  offset
  =/  o=[? @ud]  (old:si off)
  [-.o +.o]
::
::  one stretch of a zone's table, in unix seconds: from, to (exclusive)
::  and its offset
::
+$  period  [from=@ud to=@ud off=offset]
::
++  periods
  |=  z=zone:ci
  ^-  (list period)
  =/  from=@ud  (unix start.z)
  =/  off=offset  (to-offset offset.z)
  =/  ts=(list [at=@da offset=@sd])  transitions.z
  =|  out=(list period)
  |-
  ?~  ts  (flop [[from (unix end.z) off] out])
  =/  at=@ud  (unix at.i.ts)
  $(ts t.ts, from at, off (to-offset offset.i.ts), out [[from at off] out])
::
++  offset-at
  |=  [ps=(list period) at=@ud]
  ^-  offset
  =/  off=offset  ?~(ps [%.y 0] off.i.ps)
  |-
  ?~  ps  off
  ?.  (gte at from.i.ps)  off
  $(off off.i.ps, ps t.ps)
::
::  a UTC instant's wall clock, and a wall clock's UTC (wall times are
::  read as if they were UTC seconds)
::
++  to-wall
  |=  [at=@ud off=offset]
  ^-  @ud
  ?:(east.off (add at secs.off) (sub at secs.off))
::
++  from-wall
  |=  [wall=@ud off=offset]
  ^-  @ud
  ?:(east.off (sub wall secs.off) (add wall secs.off))
::
::  a wall-clock time's instant over the table: the earliest instant
::  showing it, or for a skipped time the transition after the gap; or
::  that it falls before the table's start, or beyond its end
::
++  local-to-utc
  |=  [ps=(list period) wall=@ud]
  ^-  $%([%at p=@ud] [%before ~] [%beyond ~])
  =/  shown=(list @ud)
    %+  murn  ps
    |=  p=period
    ^-  (unit @ud)
    ?:  &(!east.off.p (gth secs.off.p 0) (lth (add wall secs.off.p) from.p))  ~
    ?:  &(east.off.p (lth wall secs.off.p))  ~
    =/  u=@ud  (from-wall wall off.p)
    ?:  &((gte u from.p) (lth u to.p))  `u
    ~
  ?^  shown  [%at (roll t.shown |=([u=@ud acc=_i.shown] (min u acc)))]
  =/  gap=(unit @ud)
    =/  rest=(list period)  ps
    |-
    ?~  rest  ~
    ?~  t.rest  ~
    =/  b=@ud  to.i.rest
    ?:  ?&  (gte wall (to-wall b off.i.rest))
            (lth wall (to-wall b off.i.t.rest))
        ==
      `b
    $(rest t.rest)
  ?^  gap  [%at u.gap]
  ?~  ps  [%beyond ~]
  =/  last=period  (rear ps)
  ?:  (gte (from-wall wall off.last) to.last)  [%beyond ~]
  [%before ~]
::
::  ---- the next due instant ----
::
::  the first due instant strictly after .after: in UTC with no zone, else
::  over the zone's table (refusing an instant outside its horizon).  wall
::  times are searched in order, whose instants never decrease, so the
::  first after .after is the next
::
++  next-after
  |=  [s=cron-spec:ci zone=(unit zone:ci) after=@da]
  ^-  (each @da @t)
  =/  a=@ud  (unix after)
  =/  ps=(list period)  ?~(zone ~ (periods u.zone))
  ?:  ?&  ?=(^ zone)
          |((lth after start.u.zone) (gte after end.u.zone))
      ==
    :-  %|
    %+  rap  3
    :~  (iso-utc after)  ' is outside the timezone horizon '
        (iso-utc start.u.zone)  ' to '  (iso-utc end.u.zone)
        ' of the pinned table: resolve the workflow again with a newer compiler'
    ==
  =/  wall-after=@ud  ?~(zone a (to-wall a (offset-at ps a)))
  =/  first=@ud  (sub (div wall-after 86.400) ?:((gth wall-after 86.400) 1 0))
  =/  d=@ud  0
  |-
  ?:  (gth d max-search-days)
    [%| (rap 3 ~['the schedule has no occurrence within ' (crip (a-co:co max-search-days)) ' days'])]
  =/  day=@ud  (add first d)
  =/  date  (yore (from-unix (mul day 86.400)))
  ?.  (day-matches s m.date d.t.date (mod (add day 4) 7))  $(d +(d))
  =/  found=(unit (each @ud @t))  (in-day s ps ?=(^ zone) day a)
  ?~  found  $(d +(d))
  ?:  ?=(%| -.u.found)  [%| p.u.found]
  [%& (from-unix p.u.found)]
::
::  the first time of a matching day after .a, if any
::
++  in-day
  |=  [s=cron-spec:ci ps=(list period) zoned=? day=@ud a=@ud]
  ^-  (unit (each @ud @t))
  =/  hs=(list @ud)  hours.s
  |-
  ?~  hs  ~
  =/  ms=(list @ud)  minutes.s
  |-
  ?~  ms  ^$(hs t.hs)
  =/  wall=@ud  :(add (mul day 86.400) (mul i.hs 3.600) (mul i.ms 60))
  =/  at=$%([%at p=@ud] [%before ~] [%beyond ~])
    ?.(zoned [%at wall] (local-to-utc ps wall))
  ?:  ?=(%beyond -.at)
    `[%| 'the next occurrence is beyond the timezone horizon of the pinned table: resolve the workflow again with a newer compiler']
  ?:  ?=(%before -.at)  $(ms t.ms)
  ?:  (gth p.at a)  `[%& p.at]
  $(ms t.ms)
::
::  ---- display ----
::
++  pad
  |=  [n=@ud width=@ud]
  ^-  @t
  =/  digits=tape  (a-co:co n)
  =/  short=@ud  ?:((gte (lent digits) width) 0 (sub width (lent digits)))
  (crip (weld (reap short '0') digits))
::
::  an instant as ISO 8601 UTC, to the second
::
++  iso-utc
  |=  at=@da
  ^-  @t
  =/  d  (yore at)
  %+  rap  3
  :~  (pad y.d 4)  '-'  (pad m.d 2)  '-'  (pad d.t.d 2)  'T'
      (pad h.t.d 2)  ':'  (pad m.t.d 2)  ':'  (pad s.t.d 2)  'Z'
  ==
::
::  an instant on the wall clock of a schedule's zone, with the offset it
::  had: `2026-10-19 05:30 UTC-04:00`; `UTC` with no zone
::
++  local-text
  |=  [zone=(unit zone:ci) at=@da]
  ^-  @t
  =/  a=@ud  (unix at)
  =/  off=offset  ?~(zone [%.y 0] (offset-at (periods u.zone) a))
  =/  d  (yore (from-unix (to-wall a off)))
  =/  hours=@ud  (div secs.off 3.600)
  =/  mins=@ud  (div (mod secs.off 3.600) 60)
  %+  rap  3
  :~  (pad y.d 4)  '-'  (pad m.d 2)  '-'  (pad d.t.d 2)  ' '
      (pad h.t.d 2)  ':'  (pad m.t.d 2)  ' '
      ?~  zone  'UTC'
      (rap 3 ~['UTC' ?:(east.off '+' '-') (pad hours 2) ':' (pad mins 2)])
  ==
::
::  ---- a due wake ----
::
::  what a schedule's due wake decides, before its run is created: the
::  occurrence it is for is admitted once — on time, or late when it
::  arrives more than a minute after its due instant — the next is armed
::  strictly after now (or after the due instant when it came early), and
::  the occurrences between that never ran are one missed interval, never
::  runs.  a wake for another definition, another occurrence than the one
::  armed, an occurrence already admitted, or a schedule no longer active
::  is ignored with the reason
::
+$  wake
  $%  $:  %admit
          late=?
          next=(each @da @t)
          missed=(unit missed-interval:ci)
      ==
      [%ignore why=@t]
  ==
::
++  on-wake
  |=  [entry=schedule-entry:ci due=@da definition=@uv occurrence=@uv now=@da]
  ^-  wake
  ?.  =(%active state.entry)  [%ignore 'the schedule is not active']
  ?.  =(definition definition.entry)
    [%ignore 'the wake is for a definition that was replaced or revoked']
  ?.  =(`due armed.entry)  [%ignore 'the wake is not for the occurrence armed now']
  ?^  (find ~[occurrence] admitted.entry)  [%ignore 'the occurrence was admitted already']
  ?~  spec.def.entry  [%ignore 'the schedule is refused']
  =/  late=?  (gth now (add due late-after))
  =/  next=(each @da @t)  (next-after u.spec.def.entry zone.entry (max now due))
  [%admit late next (missed-between u.spec.def.entry zone.entry due now)]
::
::  the occurrences strictly after .from and at or before .to: the first,
::  the last and how many (at most max-missed are counted)
::
++  missed-between
  |=  [s=cron-spec:ci zone=(unit zone:ci) from=@da to=@da]
  ^-  (unit missed-interval:ci)
  =/  count=@ud  0
  =|  first=(unit @da)
  =/  last=@da  from
  =/  at=@da  from
  |-
  ?:  (gte count max-missed)
    ?~(first ~ `[u.first last count])
  =/  next=(each @da @t)  (next-after s zone at)
  ?:  ?|(?=(%| -.next) (gth p.next to))
    ?~(first ~ `[u.first last count])
  %=  $
    count  +(count)
    first  ?~(first `p.next first)
    last  p.next
    at  p.next
  ==
--
