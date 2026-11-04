::  ci-dispatch-vector: manual-run admission (Delivery 1A).  The inputs
::  of runner/internal/plan/testdata/manual.yml as the pinned compiler
::  reads them, admitted against typed values: a boolean false and a
::  number zero are supplied values, never missing ones; a choice and a
::  string take their defaults; an optional environment with no default
::  stays absent.  The event payloads act reads — a manual run's, its
::  number a JSON number and its boolean text, and a push's — and their
::  digest.  Every case names the verdict it expects.  Prints
::  `passed=N of=M` and ends in a loobean.
::
/-  ci
/+  ci-dispatch, ci-provenance
:-  %say
|=  *
:-  %noun
=/  manual=(list dispatch-input:ci)
  :~  ['dry_run' %boolean 'Rehearse without publishing' %.n `'false' ~]
      ['count' %number 'How many artifacts to build' %.y `'0' ~]
      ['level' %choice 'Log level' %.n `'warning' ~['info' 'warning' 'debug']]
      ['note' %string 'A note for the run record' %.n `'hello' ~]
      ['target' %environment 'Where to publish' %.n ~ ~]
  ==
=/  envs=(set @t)  (silt ~['production' 'staging'])
=/  admitted
  %:  admit:ci-dispatch
    manual
    ~[['dry_run' [%boolean %.n]] ['count' [%number '0']]]
    envs
    ~
  ==
=/  want=(list admitted-input:ci)
  :~  ['dry_run' %boolean %supplied `[%boolean %.n]]
      ['count' %number %supplied `[%number '0']]
      ['level' %choice %default `[%string 'warning']]
      ['note' %string %default `[%string 'hello']]
      ['target' %environment %absent ~]
  ==
=/  inputs=(list admitted-input:ci)  ?:(?=(%& -.admitted) p.admitted ~)
=/  text=@t  (payload:ci-dispatch 'refs/heads/main' 'manual.yml' ~zod inputs)
=/  parsed=(unit json)  (de:json:html text)
=/  field
  |=  key=@t
  ^-  (unit json)
  ?~  parsed  ~
  ?.  ?=([%o *] u.parsed)  ~
  (~(get by p.u.parsed) key)
=/  want-inputs=json
  %-  pairs:enjs:format
  :~  ['dry_run' s+'false']
      ['count' [%n ~.0]]
      ['level' s+'warning']
      ['note' s+'hello']
  ==
::  a push run's payload, as an attempt's manifest binds it
::
=/  push-parsed=(unit json)
  %-  de:json:html
  %:  push-payload:ci-dispatch
    'refs/heads/master'
    '00000000000000000000000000000000000000b0'
    '0000000000000000000000000000000000000001'
    ~zod
  ==
=/  push-field
  |=  key=@t
  ^-  (unit json)
  ?~  push-parsed  ~
  ?.  ?=([%o *] u.push-parsed)  ~
  (~(get by p.u.push-parsed) key)
=/  push-keys=(list @t)
  ?~  push-parsed  ~
  ?.  ?=([%o *] u.push-parsed)  ~
  (sort ~(tap in ~(key by p.u.push-parsed)) aor)
=/  value-text
  |=  v=input-value:ci
  ^-  @t
  (en:json:html (payload-value:ci-dispatch v))
::  one refusal: the field errors admission answers for these values
::
=/  refused
  |=  [defs=(list dispatch-input:ci) given=(list [@t input-value:ci])]
  ^-  (list [@t @t])
  =/  got  (admit:ci-dispatch defs given envs ~['npm-fixture-value-1234'])
  ?:(?=(%& -.got) ~ p.got)
=/  required-version=(list dispatch-input:ci)
  (snoc manual ['version' %string 'The version to publish' %.y ~ ~])
=/  supplied-empty
  (admit:ci-dispatch manual ~[['note' [%string '']]] envs ~)
=/  want-empty=(list admitted-input:ci)
  :~  ['dry_run' %boolean %default `[%boolean %.n]]
      ['count' %number %default `[%number '0']]
      ['level' %choice %default `[%string 'warning']]
      ['note' %string %supplied `[%string '']]
      ['target' %environment %absent ~]
  ==
=/  big=@t  (crip (reap 70.000 'x'))
::  the resolver's inventory as it posts it beside the lock
::
=/  inventory
  |=  text=@t
  (parse-inventory:ci-dispatch (de:json:html text))
=/  one-input
  |=  input=@t
  ^-  @t
  (rap 3 ~['[{"workflow":"m.yml","name":"M","inputs":[' input ']}]'])
=/  refusal-in
  |=  text=@t
  ^-  (unit @t)
  =/  got  (inventory text)
  ?.  ?=([%& ~ [* ~]] got)  `'NOT ONE LISTED WORKFLOW'
  ?.  =(~ inputs.i.u.p.got)  `'INPUTS KEPT'
  refusal.i.u.p.got
=/  refusal-of
  |=  input=@t
  ^-  (unit @t)
  (refusal-in (one-input input))
=/  wire-of
  |=  text=@t
  ^-  @t
  =/  got  (inventory text)
  ?:(?=(%| -.got) p.got 'ACCEPTED')
=/  many=@t
  %+  rap  3
  :~  '[{"workflow":"m.yml","name":"M","inputs":['
      %+  join:ci-dispatch
        %+  turn
          (gulf 1 26)
        |=(n=@ud (rap 3 ~['{"id":"i' (crip (a-co:co n)) '","type":"string","description":"","required":false,"default":null,"options":[]}']))
      ','
      ']}]'
  ==
=/  good=@t
  %+  rap  3
  :~  '[{"workflow":"manual.yml","name":"Manual release","inputs":['
      '{"id":"dry_run","type":"boolean","description":"Rehearse","required":false,"default":"false","options":[]},'
      '{"id":"target","type":"environment","description":"","required":false,"default":null,"options":[]}]}]'
  ==
=/  want-good=(list dispatch-workflow:ci)
  :~  :*  'manual.yml'  'Manual release'
          :~  ['dry_run' %boolean 'Rehearse' %.n `'false' ~]
              ['target' %environment '' %.n ~ ~]
          ==
          ~
      ==  ==
=/  cases=(list [name=@t want=? got=?])
  :~  ['a boolean false and a number zero are supplied; defaults fill the rest; no default stays absent' %.y =([%& want] admitted)]
      ['an empty string is a supplied value, not a missing one' %.y =([%& want-empty] supplied-empty)]
      ['a boolean given as text is refused' %.y =(~[['dry_run' 'must be true or false']] (refused manual ~[['dry_run' [%string 'yes']]]))]
      ['a number given as text is refused' %.y =(~[['count' 'must be a number']] (refused manual ~[['count' [%string '5']]]))]
      ['a number in exponent form is refused' %.y =(~[['count' 'must be a plain decimal number, like 12 or -0.5']] (refused manual ~[['count' [%number '1e3']]]))]
      ['a number with a leading zero is refused' %.y =(~[['count' 'must be a plain decimal number, like 12 or -0.5']] (refused manual ~[['count' [%number '05']]]))]
      ['a negative decimal is a number' %.y =(~ (refused manual ~[['count' [%number '-0.5']]]))]
      ['a choice outside its options is refused' %.y =(~[['level' 'must be one of info, warning, debug']] (refused manual ~[['level' [%string 'verbose']]]))]
      ['an environment the repository does not define is refused' %.y =(~[['target' 'must be an environment of this repository: production, staging']] (refused manual ~[['target' [%string 'nowhere']]]))]
      ['an environment the repository defines is admitted' %.y =(~ (refused manual ~[['target' [%string 'production']]]))]
      ['a missing required input with no default is refused' %.y =(~[['version' 'is required']] (refused required-version ~))]
      ['an input the workflow does not declare is refused' %.y =(~[['extra' 'is not an input of this workflow']] (refused manual ~[['extra' [%string 'x']]]))]
      ['an input supplied twice is refused' %.y =(~[['count' 'is supplied twice']] (refused manual ~[['count' [%number '1']] ['count' [%number '2']]]))]
      ['a value holding a stored credential is refused' %.y =(~[['note' 'contains the value of a stored credential; a credential reaches a job only as a grant']] (refused manual ~[['note' [%string 'x npm-fixture-value-1234 y']]]))]
      ['every refusal is reported: the unknown first, then in declaration order' %.y =(~[['extra' 'is not an input of this workflow'] ['dry_run' 'must be true or false'] ['level' 'must be one of info, warning, debug']] (refused manual ~[['level' [%string 'x']] ['extra' [%string 'x']] ['dry_run' [%number '1']]]))]
      ['inputs over 65,535 characters are refused' %.y =(~[['' 'the inputs exceed 65,535 characters']] (refused manual ~[['note' [%string big]]]))]
      ::  the inventory: absent (an older resolver) is not empty
      ['no inventory from the resolver is not an empty one' %.y =([%& ~] (parse-inventory:ci-dispatch ~))]
      ['an empty inventory lists no workflow' %.y =([%& `~] (inventory '[]'))]
      ['a well-formed workflow is listed with its inputs' %.y =([%& `want-good] (inventory good))]
      ['the compiler\'s refusal is kept' %.y =(`'job a: a matrix strategy is not supported in this release' (refusal-in '[{"workflow":"m.yml","name":"M","inputs":[],"refusal":"job a: a matrix strategy is not supported in this release"}]'))]
      ::  definitions the ship refuses: the workflow is listed, refused
      ['an input id outside the grammar is refused' %.y =(`'input 1x: an input id starts with a letter or _ and holds only letters, digits, - and _' (refusal-of '{"id":"1x","type":"string","description":"","required":false,"default":null,"options":[]}'))]
      ['an unknown type is refused' %.y =(`'input x: type colour is not boolean, choice, number, environment or string' (refusal-of '{"id":"x","type":"colour","description":"","required":false,"default":null,"options":[]}'))]
      ['a choice with no options is refused' %.y =(`'input x: a choice lists at least one option' (refusal-of '{"id":"x","type":"choice","description":"","required":false,"default":null,"options":[]}'))]
      ['a choice listing an option twice is refused' %.y =(`'input x: option a is listed twice' (refusal-of '{"id":"x","type":"choice","description":"","required":false,"default":null,"options":["a","b","a"]}'))]
      ['a choice default outside its options is refused' %.y =(`'input x: the default c is not one of its options' (refusal-of '{"id":"x","type":"choice","description":"","required":false,"default":"c","options":["a","b"]}'))]
      ['a boolean default that is not true or false is refused' %.y =(`'input x: a boolean default is true or false, not yes' (refusal-of '{"id":"x","type":"boolean","description":"","required":false,"default":"yes","options":[]}'))]
      ['a number default in exponent form is refused' %.y =(`'input x: the default 1e3 is not a plain decimal number' (refusal-of '{"id":"x","type":"number","description":"","required":false,"default":"1e3","options":[]}'))]
      ['an input declared twice is refused' %.y =(`'input x is declared twice' (refusal-of '{"id":"x","type":"string","description":"","required":false,"default":null,"options":[]},{"id":"x","type":"string","description":"","required":false,"default":null,"options":[]}'))]
      ['more than 25 inputs are refused' %.y =(`'the workflow declares 26 inputs; at most 25' (refusal-in many))]
      ::  a malformed wire is the resolver's error: the lock is refused
      ['an inventory that is not a list is refused' %.y =('dispatch must be a list of workflows' (wire-of '{}'))]
      ['a workflow outside .github/workflows is refused' %.y =('dispatch workflow ../x.yml is not a file name under .github/workflows' (wire-of '[{"workflow":"../x.yml","name":"X","inputs":[]}]'))]
      ['a workflow listed twice is refused' %.y =('dispatch lists m.yml twice' (wire-of '[{"workflow":"m.yml","name":"M","inputs":[]},{"workflow":"m.yml","name":"M","inputs":[]}]'))]
      ['an input with no id is refused' %.y =('dispatch workflow m.yml: an input has no id' (wire-of (one-input '{"type":"string"}')))]
      ['an input whose required is not a boolean is refused' %.y =('dispatch workflow m.yml: input x has malformed fields' (wire-of (one-input '{"id":"x","type":"string","description":"","required":"no","default":null,"options":[]}')))]
      ::  a lock's identity covers the inventory its resolver read
      ['the same nodes and inventory digest the same' %.y =((lock-digest-with:ci-provenance 'erpit' 0xb1 ~ `want-good) (lock-digest-with:ci-provenance 'erpit' 0xb1 ~ `want-good))]
      ['the same nodes read with another inventory are another lock' %.n =((lock-digest-with:ci-provenance 'erpit' 0xb1 ~ `want-good) (lock-digest-with:ci-provenance 'erpit' 0xb1 ~ `~))]
      ['no inventory is another lock than an empty one' %.n =((lock-digest-with:ci-provenance 'erpit' 0xb1 ~ ~) (lock-digest-with:ci-provenance 'erpit' 0xb1 ~ `~))]
      ::  the operator's idempotency key
      ['a request key of letters, digits, dots, dashes and underscores is valid' %.y (request-valid:ci-dispatch 'run-2026.10.15_01')]
      ['an empty request key is refused' %.n (request-valid:ci-dispatch '')]
      ['a request key with a space or slash is refused' %.n |((request-valid:ci-dispatch 'a b') (request-valid:ci-dispatch 'a/b'))]
      ['a request key over 64 characters is refused' %.n (request-valid:ci-dispatch (crip (reap 65 'a')))]
      ['the payload is a JSON object' %.y ?=([~ %o *] parsed)]
      ['the payload carries every supplied and defaulted input, typed, and no absent one' %.y =(`want-inputs (field 'inputs'))]
      ['the payload names the ref' %.y =(`s+'refs/heads/main' (field 'ref'))]
      ['the payload names the workflow file by its path' %.y =(`s+'.github/workflows/manual.yml' (field 'workflow'))]
      ['the payload names the sender' %.y =(`(pairs:enjs:format ~[['login' s+'~zod']]) (field 'sender'))]
      ['the context digest is the sha-256 of the payload bytes' %.y =('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad' (context-digest:ci-dispatch 'abc'))]
      ::  act types inputs.<id> from the payload's own value: a number
      ::  input's zero is the JSON number 0, never the text "0"; a boolean
      ::  is its text, which act reads as true exactly when it is "true"
      ['a number zero is the JSON number 0 in the payload' %.y =('0' (value-text [%number '0']))]
      ['a negative decimal is a JSON number in the payload' %.y =('-0.5' (value-text [%number '-0.5']))]
      ['a string zero stays the text "0"' %.y =('"0"' (value-text [%string '0']))]
      ['a boolean false is the text "false"' %.y =('"false"' (value-text [%boolean %.n]))]
      ['a boolean true is the text "true"' %.y =('"true"' (value-text [%boolean %.y]))]
      ['an empty string stays the text ""' %.y =('""' (value-text [%string '']))]
      ::  a push run's payload: the candidate's ref, base and source and
      ::  its actor, nothing else
      ['a push payload is a JSON object' %.y ?=([~ %o *] push-parsed)]
      ['a push payload names the ref' %.y =(`s+'refs/heads/master' (push-field 'ref'))]
      ['a push payload names the base as before' %.y =(`s+'00000000000000000000000000000000000000b0' (push-field 'before'))]
      ['a push payload names the source as after' %.y =(`s+'0000000000000000000000000000000000000001' (push-field 'after'))]
      ['a push payload is never a deletion' %.y =(`b+%.n (push-field 'deleted'))]
      ['a push payload names the actor as pusher' %.y =(`(pairs:enjs:format ~[['name' s+'~zod']]) (push-field 'pusher'))]
      ['a push payload names the actor as sender' %.y =(`(pairs:enjs:format ~[['login' s+'~zod']]) (push-field 'sender'))]
      ['a push payload carries nothing else' %.y =(~['after' 'before' 'deleted' 'pusher' 'ref' 'sender'] push-keys)]
  ==
=/  failed=(list @t)
  %+  murn  cases
  |=  [name=@t want=? got=?]
  ?:(=(want got) ~ `name)
=/  passed=@ud  (sub (lent cases) (lent failed))
~&  [%payload text]
~&  [%failed failed]
~&  (crip "passed={<passed>} of={<(lent cases)>}")
?=(~ failed)
