::  Manual runs (Delivery 1A): the ship's half of `workflow_dispatch`.
::  The pinned compiler (runner/internal/plan DispatchOf) reads a
::  revision's declared inputs at the explicit import; this library
::  admits a run's typed values against them and builds the event
::  payload act reads (`act workflow_dispatch -e`), and a push run's
::  (`act push -e`).  Nothing here parses YAML or evaluates an
::  expression.
::
/-  ci
/+  ci-provenance
|%
::  GitHub's documented bound on the inputs of one run
::
++  max-payload  65.535
::
::  and on the inputs one workflow declares
::
++  max-inputs  25
::
::  the operator's idempotency key for one dispatch: 1 to 64 letters,
::  digits, dots, dashes and underscores (the form draws a fresh one per
::  submission; a retry of the same submission sends it again)
::
++  request-valid
  |=  request=@t
  ^-  ?
  ?:  (gth (met 3 request) 64)  %.n
  ?=(^ (rush request (plus ;~(pose aln dot hep cab))))
::
::  the resolver's manual-run inventory, posted beside the lock (the
::  `dispatch` field): ~ when it sent none — a resolver that predates
::  manual runs — which is not an empty inventory.  a malformed wire is
::  the resolver's error and refuses the whole lock; a definition the
::  ship does not accept lists its workflow refused, with the reason and
::  no inputs, so the workflow is shown and cannot be run
::
++  parse-inventory
  |=  jon=(unit json)
  ^-  (each (unit (list dispatch-workflow:ci)) @t)
  ?~  jon  [%& ~]
  ?.  ?=([%a *] u.jon)  [%| 'dispatch must be a list of workflows']
  =/  items=(list json)  p.u.jon
  =|  seen=(set @t)
  =|  out=(list dispatch-workflow:ci)
  |-
  ?~  items  [%& `(flop out)]
  =/  one=(each dispatch-workflow:ci @t)  (parse-workflow i.items)
  ?:  ?=(%| -.one)  [%| p.one]
  ?:  (~(has in seen) workflow.p.one)
    [%| (rap 3 ~['dispatch lists ' workflow.p.one ' twice'])]
  $(items t.items, seen (~(put in seen) workflow.p.one), out [p.one out])
::
::  one input as the wire carries it, its type not yet checked
::
+$  raw-input
  $:  id=@t
      type=@t
      description=@t
      required=?
      default=(unit @t)
      options=(list @t)
  ==
::
++  parse-workflow
  |=  jon=json
  ^-  (each dispatch-workflow:ci @t)
  ?.  ?=([%o *] jon)  [%| 'a dispatch workflow is not an object']
  =/  fields=(map @t json)  p.jon
  =/  file=(unit @t)  (text-at fields 'workflow')
  ?~  file  [%| 'a dispatch workflow names no workflow file']
  ?.  (workflow-file-valid u.file)
    [%| (rap 3 ~['dispatch workflow ' u.file ' is not a file name under .github/workflows'])]
  =/  where=@t  (rap 3 ~['dispatch workflow ' u.file ': '])
  =/  name=@t  (fall (text-at fields 'name') '')
  =?  name  =('' name)  u.file
  =/  raw=(each (list raw-input) @t)
    =/  value=(unit json)  (~(get by fields) 'inputs')
    ?~  value  [%& ~]
    ?.  ?=([%a *] u.value)  [%| (rap 3 ~[where 'inputs must be a list'])]
    =/  items=(list json)  p.u.value
    =|  out=(list raw-input)
    |-
    ?~  items  [%& (flop out)]
    =/  one=(each raw-input @t)  (parse-input i.items)
    ?:  ?=(%| -.one)  [%| (rap 3 ~[where p.one])]
    $(items t.items, out [p.one out])
  ?:  ?=(%| -.raw)  [%| p.raw]
  =/  refusal=(unit @t)  (text-at fields 'refusal')
  ?:  ?&(?=(^ refusal) !=('' u.refusal))
    [%& u.file name ~ refusal]
  =/  checked=(each (list dispatch-input:ci) @t)  (definitions p.raw)
  ?:  ?=(%| -.checked)  [%& u.file name ~ `p.checked]
  [%& u.file name p.checked ~]
::
++  parse-input
  |=  jon=json
  ^-  (each raw-input @t)
  ?.  ?=([%o *] jon)  [%| 'an input is not an object']
  =/  fields=(map @t json)  p.jon
  =/  id=(unit @t)  (text-at fields 'id')
  ?~  id  [%| 'an input has no id']
  =/  malformed=@t  (rap 3 ~['input ' u.id ' has malformed fields'])
  =/  type=(unit @t)  (optional-text fields 'type' 'string')
  =/  description=(unit @t)  (optional-text fields 'description' '')
  =/  required=(unit ?)
    =/  v=(unit json)  (~(get by fields) 'required')
    ?~  v  `%.n
    ?.(?=([%b *] u.v) ~ `p.u.v)
  =/  default=(unit (unit @t))
    =/  v=(unit json)  (~(get by fields) 'default')
    ?~  v  `~
    ?~  u.v  `~
    ?.(?=([%s *] u.v) ~ ``p.u.v)
  =/  options=(unit (list @t))
    =/  v=(unit json)  (~(get by fields) 'options')
    ?~  v  `~
    ?~  u.v  `~
    ?.  ?=([%a *] u.v)  ~
    =/  texts=(list @t)  (murn p.u.v |=(j=json ?.(?=([%s *] j) ~ `p.j)))
    ?.(=((lent texts) (lent p.u.v)) ~ `texts)
  ?.  ?&(?=(^ type) ?=(^ description) ?=(^ required) ?=(^ default) ?=(^ options))
    [%| malformed]
  [%& u.id u.type u.description u.required u.default u.options]
::
::  the ship's own check of what the compiler carried: GitHub's input
::  grammar and bounds, a known type, a choice with distinct options that
::  hold its default, and a default its type can hold.  an environment
::  default is checked at admission, against the environments then
::
++  definitions
  |=  raw=(list raw-input)
  ^-  (each (list dispatch-input:ci) @t)
  ?:  (gth (lent raw) max-inputs)
    [%| (rap 3 ~['the workflow declares ' (crip (a-co:co (lent raw))) ' inputs; at most 25'])]
  =|  seen=(set @t)
  =|  out=(list dispatch-input:ci)
  |-
  ?~  raw  [%& (flop out)]
  ?:  (~(has in seen) id.i.raw)
    [%| (rap 3 ~['input ' id.i.raw ' is declared twice'])]
  =/  one=(each dispatch-input:ci @t)  (definition i.raw)
  ?:  ?=(%| -.one)  [%| p.one]
  $(raw t.raw, seen (~(put in seen) id.i.raw), out [p.one out])
::
++  definition
  |=  r=raw-input
  ^-  (each dispatch-input:ci @t)
  =/  at=@t  (rap 3 ~['input ' id.r ': '])
  ?.  (id-valid id.r)
    [%| (rap 3 ~[at 'an input id starts with a letter or _ and holds only letters, digits, - and _'])]
  =/  kind=(unit input-kind:ci)
    ?+  type.r  ~
      %boolean  `%boolean
      %choice  `%choice
      %number  `%number
      %environment  `%environment
      %string  `%string
    ==
  ?~  kind
    [%| (rap 3 ~[at 'type ' type.r ' is not boolean, choice, number, environment or string'])]
  ?:  ?=(%choice u.kind)
    ?~  options.r  [%| (rap 3 ~[at 'a choice lists at least one option'])]
    =/  twice=(unit @t)  (first-twice options.r)
    ?^  twice  [%| (rap 3 ~[at 'option ' u.twice ' is listed twice'])]
    ?:  ?&(?=(^ default.r) ?=(~ (find ~[u.default.r] options.r)))
      [%| (rap 3 ~[at 'the default ' u.default.r ' is not one of its options'])]
    [%& id.r u.kind description.r required.r default.r options.r]
  ?:  ?&  ?=(%boolean u.kind)
          ?=(^ default.r)
          !|(=('true' u.default.r) =('false' u.default.r))
      ==
    [%| (rap 3 ~[at 'a boolean default is true or false, not ' u.default.r])]
  ?:  ?&(?=(%number u.kind) ?=(^ default.r) !(number-valid u.default.r))
    [%| (rap 3 ~[at 'the default ' u.default.r ' is not a plain decimal number'])]
  [%& id.r u.kind description.r required.r default.r ~]
::
::  GitHub's grammar for an input id: a letter or _, then letters,
::  digits, - and _
::
++  id-valid
  |=  id=@t
  ^-  ?
  ?:  (gth (met 3 id) 100)  %.n
  ?=(^ (rush id ;~(plug ;~(pose alf cab) (star ;~(pose aln cab hep)))))
::
::  a workflow file's name as listed under .github/workflows
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
++  first-twice
  |=  items=(list @t)
  ^-  (unit @t)
  =|  seen=(set @t)
  |-
  ?~  items  ~
  ?:  (~(has in seen) i.items)  `i.items
  $(items t.items, seen (~(put in seen) i.items))
::
++  text-at
  |=  [fields=(map @t json) key=@t]
  ^-  (unit @t)
  =/  v=(unit json)  (~(get by fields) key)
  ?~  v  ~
  ?.(?=([%s *] u.v) ~ `p.u.v)
::
::  a text field that may be absent (its default) but not another type
::
++  optional-text
  |=  [fields=(map @t json) key=@t default=@t]
  ^-  (unit @t)
  =/  v=(unit json)  (~(get by fields) key)
  ?~  v  `default
  ?~  u.v  `default
  ?.(?=([%s *] u.v) ~ `p.u.v)
::
::  every declared input of a run, in declaration order: the supplied
::  value, else the workflow's default, else absent.  a supplied false,
::  zero or empty text is a value, never a missing one.  every refusal is
::  a field and its reason, all of them at once: a name the workflow does
::  not declare (or supplies twice) first, then each declared input in
::  order; a reason about the run as a whole has the field ''.
::  .secrets are the stored credentials' scrub forms: a value holding
::  one is refused, so a credential never enters a run's record
::
++  admit
  |=  $:  inputs=(list dispatch-input:ci)
          supplied=(list [name=@t value=input-value:ci])
          environments=(set @t)
          secrets=(list @t)
      ==
  ^-  (each (list admitted-input:ci) (list [field=@t reason=@t]))
  =/  declared=(set @t)  (silt (turn inputs |=(i=dispatch-input:ci id.i)))
  =/  names=(list @t)  (turn supplied |=([name=@t *] name))
  =/  stray=(list [@t @t])
    =|  seen=(set @t)
    =|  out=(list [@t @t])
    |-
    ?~  names  (flop out)
    ?.  (~(has in declared) i.names)
      $(names t.names, out [[i.names 'is not an input of this workflow'] out])
    ?:  (~(has in seen) i.names)
      $(names t.names, out [[i.names 'is supplied twice'] out])
    $(names t.names, seen (~(put in seen) i.names))
  =/  given=(map @t input-value:ci)  (malt supplied)
  =/  results=(list (each admitted-input:ci [@t @t]))
    %+  turn  inputs
    |=  i=dispatch-input:ci
    (admit-one i (~(get by given) id.i) environments secrets)
  =/  errors=(list [@t @t])
    %+  weld  stray
    %+  murn  results
    |=  r=(each admitted-input:ci [@t @t])
    ?:(?=(%| -.r) `p.r ~)
  ?^  errors  [%| errors]
  =/  admitted=(list admitted-input:ci)
    %+  murn  results
    |=  r=(each admitted-input:ci [@t @t])
    ?:(?=(%& -.r) `p.r ~)
  ?:  (gth (met 3 (en:json:html (inputs-json admitted))) max-payload)
    [%| ~[['' 'the inputs exceed 65,535 characters']]]
  [%& admitted]
::
++  admit-one
  |=  $:  i=dispatch-input:ci
          given=(unit input-value:ci)
          environments=(set @t)
          secrets=(list @t)
      ==
  ^-  (each admitted-input:ci [field=@t reason=@t])
  ?^  given
    =/  problem=(unit @t)  (value-problem i u.given environments secrets)
    ?^  problem  [%| id.i u.problem]
    [%& id.i kind.i %supplied given]
  ?~  default.i
    ?:  required.i  [%| id.i 'is required']
    [%& id.i kind.i %absent ~]
  =/  value=input-value:ci  (from-text kind.i u.default.i)
  =/  problem=(unit @t)  (value-problem i value environments ~)
  ?^  problem
    [%| id.i (rap 3 ~['its default ' u.default.i ' is refused: it ' u.problem])]
  [%& id.i kind.i %default `value]
::
::  why a value does not fit its input, or ~
::
++  value-problem
  |=  [i=dispatch-input:ci v=input-value:ci environments=(set @t) secrets=(list @t)]
  ^-  (unit @t)
  ?-  kind.i
      %boolean
    ?:(?=(%boolean -.v) ~ `'must be true or false')
  ::
      %number
    ?.  ?=(%number -.v)  `'must be a number'
    ?:((number-valid p.v) ~ `'must be a plain decimal number, like 12 or -0.5')
  ::
      %choice
    ?.  ?=(%string -.v)  `(one-of options.i)
    ?.  ?=(^ (find ~[p.v] options.i))  `(one-of options.i)
    ~
  ::
      %environment
    ?:  ?&(?=(%string -.v) (~(has in environments) p.v))  ~
    =/  names=(list @t)  (sort ~(tap in environments) aor)
    ?~  names  `'must name an environment, and this repository defines none'
    `(rap 3 ~['must be an environment of this repository: ' (join names ', ')])
  ::
      %string
    ?.  ?=(%string -.v)  `'must be text'
    ?.  (lien secrets |=(s=@t ?=(^ (find (trip s) (trip p.v)))))  ~
    `'contains the value of a stored credential; a credential reaches a job only as a grant'
  ==
::
++  one-of
  |=  options=(list @t)
  ^-  @t
  (rap 3 ~['must be one of ' (join options ', ')])
::
++  join
  |=  [items=(list @t) separator=@t]
  ^-  @t
  ?~  items  ''
  %+  roll  t.items
  |=  [item=@t acc=_i.items]
  (rap 3 ~[acc separator item])
::
::  a number as act and GitHub read it from a form: plain decimal text,
::  an optional sign, no leading zero, no exponent, at most 32 characters
::
++  number-valid
  |=  text=@t
  ^-  ?
  ?:  (gth (met 3 text) 32)  %.n
  =/  digits  (plus (shim '0' '9'))
  =/  whole
    ;~  pose
        (cold %zero (just '0'))
        (cold %whole ;~(plug (shim '1' '9') (star (shim '0' '9'))))
    ==
  ?=(^ (rush text ;~(plug (punt hep) whole (punt ;~(plug dot digits)))))
::
::  a default's text as the value its kind declares; a boolean default
::  that is not exactly true or false stays text, and is refused as one
::
++  from-text
  |=  [kind=input-kind:ci text=@t]
  ^-  input-value:ci
  ?+  kind  [%string text]
    %boolean  ?+(text [%string text] %true [%boolean %.y], %false [%boolean %.n])
    %number  [%number text]
  ==
::
::  the event payload act reads for a manual run: every supplied and
::  defaulted input (see payload-value), the ref, the workflow's path and
::  the sender
::
++  payload
  |=  [ref=@t workflow=@t actor=@p inputs=(list admitted-input:ci)]
  ^-  @t
  %-  en:json:html
  %-  pairs:enjs:format
  :~  ['inputs' (inputs-json inputs)]
      ['ref' s+ref]
      ['workflow' s+(rap 3 ~['.github/workflows/' workflow])]
      ['sender' (pairs:enjs:format ~[['login' s+(scot %p actor)]])]
  ==
::
++  inputs-json
  |=  inputs=(list admitted-input:ci)
  ^-  json
  %-  pairs:enjs:format
  %+  murn  inputs
  |=  i=admitted-input:ci
  ^-  (unit [@t json])
  ?~  value.i  ~
  `[id.i (payload-value u.value.i)]
::
::  an input's value as the payload carries it.  act 0.2.89 makes
::  `inputs.<id>` the payload's own value (pkg/runner/expression.go
::  getEvaluatorInputs), except that a boolean input is true exactly when
::  its value is the text "true".  so a boolean is that text, as GitHub's
::  `github.event.inputs` carries it, and a number is a JSON number, so
::  `inputs.<id>` is a number: toJSON gives 0, never "0".  a choice, an
::  environment and a string are text
::
++  payload-value
  |=  v=input-value:ci
  ^-  json
  ?-  -.v
    %boolean  ?:(p.v s+'true' s+'false')
    %number  [%n p.v]
    %string  s+p.v
  ==
::
::  the event payload act reads for a push run's attempt, rendered from
::  its candidate's own immutable fields: the ref, the base it was staged
::  on as before, the integration object its jobs run on as after (the
::  manifest's source), and the actor as pusher and sender.  a candidate
::  is never a deletion, and act takes github.sha from after only beside
::  deleted false
::
++  push-payload
  |=  [ref=@t before=@t after=@t actor=@p]
  ^-  @t
  %-  en:json:html
  %-  pairs:enjs:format
  :~  ['ref' s+ref]
      ['before' s+before]
      ['after' s+after]
      ['deleted' b+%.n]
      ['pusher' (pairs:enjs:format ~[['name' s+(scot %p actor)]])]
      ['sender' (pairs:enjs:format ~[['login' s+(scot %p actor)]])]
  ==
::
::  the context the execution manifest signs: the sha-256 of the payload
::  bytes as 64 hex, the way the runner hashes what it receives
::
++  context-digest
  |=  payload=@t
  ^-  @t
  (hex-bytes:ci-provenance (shax payload) 32)
--
