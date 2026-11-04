::  One relayed `act --json` line: parsed, bounded, never trusted.
::
::    a line over 64 KiB is refused before it is parsed; a message is cut
::    to 4 KiB; unknown keys are ignored; a missing job, jobID or time is
::    a refusal.  parsing is total: every refusal is an HTTP status and a
::    message, never a crash, so a hostile line cannot take the agent down.
::
/-  ci
|%
++  max-line  65.536
++  max-msg  4.096
++  max-events  50.000
::  an attempt's step outputs: entries, and bytes of values
++  max-step-outputs  256
++  max-output-bytes  1.048.576
::
+$  refusal  [status=@ud message=@t]
::
++  parse
  |=  line=octs
  ^-  (each event:ci refusal)
  ?:  (gth p.line max-line)
    [%| 413 'event line exceeds 64 KiB']
  =/  jon=(unit json)  (de:json:html q.line)
  ?~  jon
    [%| 400 'event line is not valid JSON']
  ?.  ?=([%o *] u.jon)
    [%| 400 'event line is not a JSON object']
  =/  fields=(map @t json)  p.u.jon
  =/  job=(unit @t)  (string-field fields 'job')
  =/  job-id=(unit @t)  (string-field fields 'jobID')
  =/  time=(unit @t)  (string-field fields 'time')
  ?~  job  [%| 400 'event is missing job']
  ?~  job-id  [%| 400 'event is missing jobID']
  ?~  time  [%| 400 'event is missing time']
  =/  at=(unit @da)  (parse-time u.time)
  ?~  at  [%| 400 'event time is not an RFC 3339 timestamp']
  =/  step-result=(each (unit result:ci) refusal)
    (parse-result (string-field fields 'stepResult') 'stepResult')
  ?:  ?=(%| -.step-result)  [%| p.step-result]
  =/  job-result=(each (unit result:ci) refusal)
    (parse-result (string-field fields 'jobResult') 'jobResult')
  ?:  ?=(%| -.job-result)  [%| p.job-result]
  =/  command=(each (unit command:ci) refusal)  (parse-command fields)
  ?:  ?=(%| -.command)  [%| p.command]
  =/  raw=?
    =/  value=(unit json)  (~(get by fields) 'raw_output')
    ?~  value  %.n
    ?.  ?=([%b *] u.value)  %.n
    p.u.value
  =/  msg=@t  (end [3 max-msg] (fall (string-field fields 'msg') ''))
  =/  step-id=(list @t)
    =/  value=(unit json)  (~(get by fields) 'stepID')
    =?  value  ?=(~ value)  (~(get by fields) 'stepid')
    ?~  value  ~
    ?.  ?=([%a *] u.value)  ~
    %+  murn  p.u.value
    |=  item=json
    ^-  (unit @t)
    ?.  ?=([%s *] item)  ~
    `p.item
  :-  %&
  :*  u.job
      u.job-id
      (string-field fields 'stage')
      (string-field fields 'step')
      step-id
      p.step-result
      p.job-result
      p.command
      raw
      msg
      u.at
  ==
::
++  string-field
  |=  [fields=(map @t json) key=@t]
  ^-  (unit @t)
  =/  value=(unit json)  (~(get by fields) key)
  ?~  value  ~
  ?.  ?=([%s *] u.value)  ~
  `p.u.value
::
::  an unknown result word is a refusal, never a default: act's result
::  vocabulary is pinned with the act release, and a word outside it means
::  the relay and the ship disagree about what ran.
::
++  parse-result
  |=  [value=(unit @t) key=@t]
  ^-  (each (unit result:ci) refusal)
  ?~  value  [%& ~]
  =/  known=(unit result:ci)
    ?+  u.value  ~
      %success  `%success
      %failure  `%failure
      %skipped  `%skipped
      %cancelled  `%cancelled
    ==
  ?~  known
    [%| 400 (rap 3 ~[key ' is not a known result'])]
  [%& known]
::
::  act names a set-output twice: `name` at the top level when the value
::  came from $GITHUB_OUTPUT (measured on 0.2.89), and `kvPairs.name` when
::  it came from a ::set-output:: workflow command.  both are accepted.
::  seen live on act 0.2.89: a $GITHUB_OUTPUT file command emits top-level `name` (no kvPairs), the legacy stdout ::set-output:: emits `kvPairs.name`; the parser accepts both.
::
++  parse-command
  |=  fields=(map @t json)
  ^-  (each (unit command:ci) refusal)
  =/  name=(unit @t)  (string-field fields 'command')
  ?~  name  [%& ~]
  =/  arg=@t  (fall (string-field fields 'arg') '')
  ?+  u.name
    =/  other=(unit command:ci)  `[%other u.name]
    [%& other]
  ::
      %set-output
    =/  output=(unit @t)
      =/  top=(unit @t)  (string-field fields 'name')
      ?^  top  top
      =/  pairs=(unit json)  (~(get by fields) 'kvPairs')
      ?~  pairs  ~
      ?.  ?=([%o *] u.pairs)  ~
      (string-field p.u.pairs 'name')
    ?~  output
      [%| 400 'set-output without a name']
    =/  set=(unit command:ci)  `[%set-output u.output arg]
    [%& set]
  ::
      %summary
    =/  summary=(unit command:ci)  `[%summary (fall (string-field fields 'content') '')]
    [%& summary]
  ::
      %group
    =/  group=(unit command:ci)  `[%group arg]
    [%& group]
  ::
      %endgroup
    =/  endgroup=(unit command:ci)  `[%endgroup ~]
    [%& endgroup]
  ==
::
::  a credential value never enters state or a reply (D4): every text the
::  ship keeps from an event (a set-output value, a summary, the message)
::  is scrubbed of every released value first.  act masks its own output
::  and the daemon scrubs the relay; this is the ship's own fence, so a
::  value that slipped both is still not recorded.
::
++  mask  '***'
::
++  replace-all
  |=  [text=@t needle=@t]
  ^-  @t
  ?:  =('' needle)  text
  =/  hay=tape  (trip text)
  =/  pin=tape  (trip needle)
  =/  width=@ud  (lent pin)
  =/  out=tape  ~
  |-
  ?~  hay  (crip (flop out))
  ::  the wet gates see the list's full type, not the refined cell
  ?:  =(pin (scag width `tape`hay))
    $(hay (slag width `tape`hay), out (weld (flop (trip mask)) out))
  $(hay t.hay, out [i.hay out])
::
++  scrub-text
  |=  [text=@t values=(list @t)]
  ^-  @t
  ?~  values  text
  $(text (replace-all text i.values), values t.values)
::
::  the forms a released value is scrubbed in (P3 D9): the whole value,
::  then each of its lines that is at least eight characters — a PEM key
::  or a JSON credential prints line by line, and act masks none of it
::  (measured on 0.2.89).  a line shorter than that is not a secret on
::  its own and would eat ordinary text.
::
++  min-scrub  8
++  scrub-forms
  |=  value=@t
  ^-  (list @t)
  =/  lines=(list @t)  (split-lines value)
  =/  long=(list @t)
    %+  skim  lines
    |=(line=@t (gte (met 3 line) min-scrub))
  ?:  ?=([* ~] lines)  ~[value]
  [value long]
::
++  split-lines
  |=  text=@t
  ^-  (list @t)
  =/  chars=tape  (trip text)
  =|  out=(list @t)
  =|  cur=tape
  |-
  ?~  chars  (flop [(crip (flop cur)) out])
  ?:  ?|(=('\0a' i.chars) =('\0d' i.chars))
    $(chars t.chars, cur ~, out [(crip (flop cur)) out])
  $(chars t.chars, cur [i.chars cur])
::
++  scrub
  |=  [=event:ci values=(list @t)]
  ^-  event:ci
  ?~  values  event
  =.  msg.event  (scrub-text msg.event values)
  =?  command.event  ?=([~ %set-output *] command.event)
    command.event(value.u (scrub-text value.u.command.event values))
  =?  command.event  ?=([~ %summary *] command.event)
    command.event(body.u (scrub-text body.u.command.event values))
  event
::
::  the one per-event effect that persists: a set-output lands in the
::  attempt's step outputs under the step act names it by (its stepID:
::  [id] for a job's step, [id sub] for a composite action's own step).
::  a later value of the same step and name replaces the earlier, as act
::  records it; another step's output of the same name is an entry of its
::  own, never overwritten.  .redacted says the ship's credential fence
::  changed the value.  ~ past the bounds: the output is not recorded.
::  everything else of an event is relayed and forgotten.
::
++  record-output
  |=  [outputs=(list step-output:ci) =event:ci redacted=?]
  ^-  (unit (list step-output:ci))
  ?~  command.event  `outputs
  ?.  ?=(%set-output -.u.command.event)  `outputs
  =/  name=@t  name.u.command.event
  =/  kept=(list step-output:ci)
    (skip outputs |=(o=step-output:ci &(=(step.o step-id.event) =(name.o name))))
  =/  next=(list step-output:ci)
    (snoc kept [step-id.event name value.u.command.event redacted])
  ?:  (gth (lent next) max-step-outputs)  ~
  =/  bytes=@ud
    =/  items=(list step-output:ci)  next
    =|  sum=@ud
    |-
    ?~  items  sum
    $(items t.items, sum (add sum (met 3 value.i.items)))
  ?:  (gth bytes max-output-bytes)  ~
  `next
::
::  RFC 3339: YYYY-MM-DDTHH:MM:SS[.fraction](Z|+HH:MM|-HH:MM), as act
::  emits it.  the result is the UTC instant.
::
++  parse-time
  |=  text=@t
  ^-  (unit @da)
  =/  digits
    |=  [count=@ud remaining=tape]
    ^-  (unit [value=@ud rest=tape])
    =/  value=@ud  0
    |-
    ?:  =(count 0)  `[value remaining]
    ?~  remaining  ~
    ?.  &((gte i.remaining '0') (lte i.remaining '9'))  ~
    %=  $
      count  (dec count)
      remaining  t.remaining
      value  (add (mul value 10) (sub i.remaining '0'))
    ==
  =/  expect
    |=  [char=@tD remaining=tape]
    ^-  (unit tape)
    ?~  remaining  ~
    ?.  =(char i.remaining)  ~
    `t.remaining
  =/  chars=tape  (trip text)
  =/  year-part=(unit [value=@ud rest=tape])  (digits 4 chars)
  ?~  year-part  ~
  =/  after-year=(unit tape)  (expect '-' rest.u.year-part)
  ?~  after-year  ~
  =/  month-part=(unit [value=@ud rest=tape])  (digits 2 u.after-year)
  ?~  month-part  ~
  =/  after-month=(unit tape)  (expect '-' rest.u.month-part)
  ?~  after-month  ~
  =/  day-part=(unit [value=@ud rest=tape])  (digits 2 u.after-month)
  ?~  day-part  ~
  =/  after-day=(unit tape)  (expect 'T' rest.u.day-part)
  ?~  after-day  ~
  =/  hour-part=(unit [value=@ud rest=tape])  (digits 2 u.after-day)
  ?~  hour-part  ~
  =/  after-hour=(unit tape)  (expect ':' rest.u.hour-part)
  ?~  after-hour  ~
  =/  minute-part=(unit [value=@ud rest=tape])  (digits 2 u.after-hour)
  ?~  minute-part  ~
  =/  after-minute=(unit tape)  (expect ':' rest.u.minute-part)
  ?~  after-minute  ~
  =/  second-part=(unit [value=@ud rest=tape])  (digits 2 u.after-minute)
  ?~  second-part  ~
  =/  skip-fraction
    |=  rest=tape
    ^-  tape
    ?~  rest  rest
    ?.  =('.' i.rest)  rest
    =/  fraction=tape  t.rest
    |-
    ?~  fraction  fraction
    ?.  &((gte i.fraction '0') (lte i.fraction '9'))  fraction
    $(fraction t.fraction)
  =/  remaining=tape  (skip-fraction rest.u.second-part)
  ?.  ?&  (gte value.u.month-part 1)  (lte value.u.month-part 12)
          (gte value.u.day-part 1)  (lte value.u.day-part 31)
          (lth value.u.hour-part 24)
          (lth value.u.minute-part 60)
          (lth value.u.second-part 60)
      ==
    ~
  =/  local=@da
    %-  year
    :*  [%.y value.u.year-part]
        value.u.month-part
        value.u.day-part
        value.u.hour-part
        value.u.minute-part
        value.u.second-part
        ~
    ==
  ?~  remaining  ~
  ?:  =('Z' i.remaining)
    ?^  t.remaining  ~
    `local
  ?.  ?|(=('+' i.remaining) =('-' i.remaining))  ~
  =/  east=?  =('+' i.remaining)
  =/  offset-hours=(unit [value=@ud rest=tape])  (digits 2 t.remaining)
  ?~  offset-hours  ~
  =/  after-offset-hours=(unit tape)  (expect ':' rest.u.offset-hours)
  ?~  after-offset-hours  ~
  =/  offset-minutes=(unit [value=@ud rest=tape])  (digits 2 u.after-offset-hours)
  ?~  offset-minutes  ~
  ?^  rest.u.offset-minutes  ~
  ?.  ?&((lth value.u.offset-hours 24) (lth value.u.offset-minutes 60))  ~
  =/  offset=@dr
    %+  add
      (mul value.u.offset-hours ~h1)
    (mul value.u.offset-minutes ~m1)
  ::  a local time east of UTC is ahead of it, so UTC is earlier
  ?:  east
    ?:  (lth local offset)  ~
    `(sub local offset)
  `(add local offset)
--
