::  ci-trigger-vector: automatic-event selection on the ship (Delivery
::  1C).  The catalog and the glob table embedded below are the pinned
::  compiler's own output, which runner/internal/plan vector_pin_test.go
::  pins byte for byte: testdata/selection/*.yml compiled by CatalogOf,
::  and the captured reference's filter-pattern cheat sheet with each
::  pattern's compiled tokens.  Checked here:
::    - the wire: the pinned catalog parses with its refused workflow and
::      refused event kept; a malformed catalog refuses whole (version, a
::      duplicate or misnamed workflow, a filter on the wrong event, an
::      -ignore list holding a ! pattern, a negation flag that disagrees
::      with its text, a pull request without types or with an unknown
::      one, a zone a schedule names with no table, a bad zone table); a
::      schedule the ship's own rules refuse is refused alone; no catalog
::      is unknown, never empty;
::    - the matcher: every cheat-sheet row, matched and not;
::    - selection, every expectation by hand from the reference's rules:
::      ordered negation and re-inclusion, -ignore lists, branch and path
::      filters as a conjunction, a tags-only filter skipping branches and
::      a branches-only one skipping tags, paths never read for a tag, no
::      changed path running nothing, unavailable evidence selecting with
::      its label, activity types and their defaults, a pull request's
::      target branch, refused triggers in error, undeclared events not
::      listed; and whether the diff is needed at all;
::    - the payloads act reads, and the signed trigger text of every run
::      kind, which begins with the event act runs.
::    - pull request labels: labeled and unlabeled are native activities,
::      selected only by a workflow whose types name them, with branch and
::      path filters applied.  the ship's labeled and unlabeled payloads
::      are the JSON pinned in runner/internal/daemon/testdata/labels,
::      which the runner's eventOf accepts.  a label change on a closed or
::      merged pull request runs nothing.
::  Every case names the verdict it expects; prints `passed=N of=M` and
::  ends in a loobean.
::
/-  ci, git
/+  ci-trigger, git-codec
:-  %say
|=  *
:-  %noun
=/  catalog-1=@t
  %+  rap  3
  :~  '{"version":1,"workflows":[{"workflow":"a-branches.yml","name":"Branches '
      'and paths","events":[{"event":"push","refusal":"","branches":{"ignore":f'
      'alse,"patterns":[{"text":"main","negated":false,"tokens":[{"t":"lit","c"'
      ':"main"}]},{"text":"releases/**","negated":false,"tokens":[{"t":"lit","c'
      '":"releases/"},{"t":"globstar"}]},{"text":"!releases/**-alpha","negated"'
      ':true,"tokens":[{"t":"lit","c":"releases/"},{"t":"globstar"},{"t":"lit",'
      '"c":"-alpha"}]},{"text":"releases/keep-alpha","negated":false,"tokens":['
      '{"t":"lit","c":"releases/keep-alpha"}]}]},"tags":null,"paths":{"ignore":'
      'false,"patterns":[{"text":"src/**","negated":false,"tokens":[{"t":"lit",'
      '"c":"src/"},{"t":"globstar"}]},{"text":"!src/docs/**","negated":true,"to'
      'kens":[{"t":"lit","c":"src/docs/"},{"t":"globstar"}]},{"text":"src/docs/'
      'keep/**","negated":false,"tokens":[{"t":"lit","c":"src/docs/keep/"},{"t"'
      ':"globstar"}]}]},"types":null,"typesDeclared":false,"schedules":null,"li'
      'ne":5,"col":3},{"event":"pull_request","refusal":"","branches":{"ignore"'
      ':false,"patterns":[{"text":"main","negated":false,"tokens":[{"t":"lit","'
      'c":"main"}]}]},"tags":null,"paths":{"ignore":true,"patterns":[{"text":"d'
      'ocs/**","negated":false,"tokens":[{"t":"lit","c":"docs/"},{"t":"globstar'
      '"}]},{"text":"**/*.md","negated":false,"tokens":[{"t":"dirs"},{"t":"star'
      '"},{"t":"lit","c":".md"}]}]},"types":["opened","synchronize","reopened"]'
      ',"typesDeclared":false,"schedules":null,"line":8,"col":3}],"refusal":"",'
      '"concurrency":{"v":2,"kind":"none"}},{"workflow":"b-ignore.yml","name":"'
      'Ignore lists","events":[{"event":"push","refusal":"","branches":{"ignore'
      '":true,"patterns":[{"text":"feature/**","negated":false,"tokens":[{"t":"'
      'lit","c":"feature/"},{"t":"globstar"}]}]},"tags":null,"paths":{"ignore":'
      'true,"patterns":[{"text":"docs/**","negated":false,"tokens":[{"t":"lit",'
      '"c":"docs/"},{"t":"globstar"}]}]},"types":null,"typesDeclared":false,"sc'
      'hedules":null,"line":4,"col":3},{"event":"pull_request","refusal":"","br'
      'anches":{"ignore":true,"patterns":[{"text":"wip","negated":false,"tokens'
      '":[{"t":"lit","c":"wip"}]}]},"tags":null,"paths":null,"types":["opened",'
      '"closed"],"typesDeclared":true,"schedules":null,"line":7,"col":3}],"refu'
      'sal":"","concurrency":{"v":2,"kind":"none"}},{"workflow":"c-tags.yml","n'
      'ame":"Tags only","events":[{"event":"push","refusal":"","branches":null,'
      '"tags":{"ignore":false,"patterns":[{"text":"v[0-9]+.[0-9]+.[0-9]+","nega'
      'ted":false,"tokens":[{"t":"lit","c":"v"},{"t":"class","set":"0123456789"'
      '},{"t":"many","of":{"t":"class","set":"0123456789"}},{"t":"lit","c":"."}'
      ',{"t":"class","set":"0123456789"},{"t":"many","of":{"t":"class","set":"0'
      '123456789"}},{"t":"lit","c":"."},{"t":"class","set":"0123456789"},{"t":"'
      'many","of":{"t":"class","set":"0123456789"}}]},{"text":"!v0.*","negated"'
      ':true,"tokens":[{"t":"lit","c":"v0."},{"t":"star"}]}]},"paths":{"ignore"'
      ':false,"patterns":[{"text":"never/**","negated":false,"tokens":[{"t":"li'
      't","c":"never/"},{"t":"globstar"}]}]},"types":null,"typesDeclared":false'
      ',"schedules":null,"line":4,"col":3}],"refusal":"","concurrency":{"v":2,"'
      'kind":"none"}},{"workflow":"d-plain.yml","name":"Unfiltered","events":[{'
      '"event":"push","refusal":"","branches":null,"tags":null,"paths":null,"ty'
      'pes":null,"typesDeclared":false,"schedules":null,"line":3,"col":6},{"eve'
      'nt":"pull_request","refusal":"","branches":null,"tags":null,"paths":null'
      ',"types":["opened","synchronize","reopened"],"typesDeclared":false,"sche'
      'dules":null,"line":3,"col":12}],"refusal":"","concurrency":{"v":2,"kind"'
  ==
=/  catalog-2=@t
  %+  rap  3
  :~  ':"none"}},{"workflow":"e-refused.yml","name":"Refused push","events":[{"'
      'event":"push","refusal":"push: branches and branches-ignore cannot both '
      'filter one event","branches":null,"tags":null,"paths":null,"types":null,'
      '"typesDeclared":false,"schedules":null,"line":4,"col":3},{"event":"workf'
      'low_dispatch","refusal":"","branches":null,"tags":null,"paths":null,"typ'
      'es":null,"typesDeclared":false,"schedules":null,"line":7,"col":3}],"refu'
      'sal":"","concurrency":{"v":2,"kind":"none"}},{"workflow":"f-manual.yml",'
      '"name":"Manual only","events":[{"event":"workflow_dispatch","refusal":""'
      ',"branches":null,"tags":null,"paths":null,"types":null,"typesDeclared":f'
      'alse,"schedules":null,"line":4,"col":3},{"event":"schedule","refusal":""'
      ',"branches":null,"tags":null,"paths":null,"types":null,"typesDeclared":f'
      'alse,"schedules":[{"cron":"0 0 29 2 *","timezone":"","refusal":"","minut'
      'es":[0],"hours":[0],"days":[29],"months":[2],"weekdays":[0,1,2,3,4,5,6],'
      '"dayStar":false,"weekdayStar":true}],"line":5,"col":3}],"refusal":"","co'
      'ncurrency":{"v":2,"kind":"none"}},{"workflow":"g-broken.yml","name":"Bro'
      'ken on","events":[],"refusal":"on: lists push twice","concurrency":{"v":'
      '2,"kind":"none"}}],"zones":{}}'
  ==
=/  catalog=@t
  %+  rap  3
  :~  catalog-1
      catalog-2
  ==
=/  globs-1=@t
  %+  rap  3
  :~  '[{"text":"feature/*","negated":false,"tokens":[{"t":"lit","c":"feature/"'
      '},{"t":"star"}],"match":["feature/my-branch","feature/your-branch"],"mis'
      's":["feature/beta-a/my-branch","feature","main"]},{"text":"feature/**","'
      'negated":false,"tokens":[{"t":"lit","c":"feature/"},{"t":"globstar"}],"m'
      'atch":["feature/beta-a/my-branch","feature/your-branch","feature/mona/th'
      'e/octocat"],"miss":["features/x","main"]},{"text":"main","negated":false'
      ',"tokens":[{"t":"lit","c":"main"}],"match":["main"],"miss":["mainline","'
      'a/main","Main"]},{"text":"releases/mona-the-octocat","negated":false,"to'
      'kens":[{"t":"lit","c":"releases/mona-the-octocat"}],"match":["releases/m'
      'ona-the-octocat"],"miss":["releases/mona"]},{"text":"*","negated":false,'
      '"tokens":[{"t":"star"}],"match":["main","releases"],"miss":["releases/10'
      '","feature/x"]},{"text":"**","negated":false,"tokens":[{"t":"globstar"}]'
      ',"match":["all/the/branches","every/tag","main"],"miss":[]},{"text":"*fe'
      'ature","negated":false,"tokens":[{"t":"star"},{"t":"lit","c":"feature"}]'
      ',"match":["mona-feature","feature","ver-10-feature"],"miss":["feature-x"'
      ',"a/feature"]},{"text":"v2*","negated":false,"tokens":[{"t":"lit","c":"v'
      '2"},{"t":"star"}],"match":["v2","v2.0","v2.9"],"miss":["v1","v3.0","rele'
      'ase/v2"]},{"text":"v[12].[0-9]+.[0-9]+","negated":false,"tokens":[{"t":"'
      'lit","c":"v"},{"t":"class","set":"12"},{"t":"lit","c":"."},{"t":"class",'
      '"set":"0123456789"},{"t":"many","of":{"t":"class","set":"0123456789"}},{'
      '"t":"lit","c":"."},{"t":"class","set":"0123456789"},{"t":"many","of":{"t'
      '":"class","set":"0123456789"}}],"match":["v1.10.1","v2.0.0"],"miss":["v3'
      '.0.0","v1.x.1","v1..1","v1.0."]},{"text":"releases/**-alpha","negated":f'
      'alse,"tokens":[{"t":"lit","c":"releases/"},{"t":"globstar"},{"t":"lit","'
      'c":"-alpha"}],"match":["releases/10-alpha","releases/beta/3-alpha"],"mis'
      's":["releases/10","releases/beta/mona"]},{"text":"*","negated":false,"to'
      'kens":[{"t":"star"}],"match":["README.md","server.rb"],"miss":["docs/REA'
      'DME.md"]},{"text":"*.jsx?","negated":false,"tokens":[{"t":"star"},{"t":"'
      'lit","c":".js"},{"t":"opt","of":{"t":"lit","c":"x"}}],"match":["page.js"'
      ',"page.jsx"],"miss":["page.jsxx","src/page.js"]},{"text":"**","negated":'
      'false,"tokens":[{"t":"globstar"}],"match":["all/the/files.md","x"],"miss'
      '":[]},{"text":"*.js","negated":false,"tokens":[{"t":"star"},{"t":"lit","'
      'c":".js"}],"match":["app.js","index.js"],"miss":["js/index.js","app.jsx"'
      ']},{"text":"**.js","negated":false,"tokens":[{"t":"globstar"},{"t":"lit"'
      ',"c":".js"}],"match":["index.js","js/index.js","src/js/app.js"],"miss":['
      '"index.jsx"]},{"text":"docs/*","negated":false,"tokens":[{"t":"lit","c":'
      '"docs/"},{"t":"star"}],"match":["docs/README.md","docs/file.txt"],"miss"'
      ':["docs/mona/octocat.txt","README.md"]},{"text":"docs/**","negated":fals'
      'e,"tokens":[{"t":"lit","c":"docs/"},{"t":"globstar"}],"match":["docs/REA'
      'DME.md","docs/mona/octocat.txt"],"miss":["doc/x","x/docs/y"]},{"text":"d'
      'ocs/**/*.md","negated":false,"tokens":[{"t":"lit","c":"docs/"},{"t":"dir'
      's"},{"t":"star"},{"t":"lit","c":".md"}],"match":["docs/README.md","docs/'
      'mona/hello-world.md","docs/a/markdown/file.md"],"miss":["docs/a.txt","x/'
      'docs/a.md"]},{"text":"**/docs/**","negated":false,"tokens":[{"t":"dirs"}'
      ',{"t":"lit","c":"docs/"},{"t":"globstar"}],"match":["docs/hello.md","dir'
      '/docs/my-file.txt","space/docs/plan/space.doc"],"miss":["docsx/a","dir/m'
      'ydocs/a"]},{"text":"**/README.md","negated":false,"tokens":[{"t":"dirs"}'
      ',{"t":"lit","c":"README.md"}],"match":["README.md","js/README.md"],"miss'
  ==
=/  globs-2=@t
  %+  rap  3
  :~  '":["README.mdx","xREADME.md"]},{"text":"**/*src/**","negated":false,"tok'
      'ens":[{"t":"dirs"},{"t":"star"},{"t":"lit","c":"src/"},{"t":"globstar"}]'
      ',"match":["a/src/app.js","my-src/code/js/app.js"],"miss":["src","a/sourc'
      'e/x"]},{"text":"**/*-post.md","negated":false,"tokens":[{"t":"dirs"},{"t'
      '":"star"},{"t":"lit","c":"-post.md"}],"match":["my-post.md","path/their-'
      'post.md"],"miss":["post.md","path/post.md"]},{"text":"**/migrate-*.sql",'
      '"negated":false,"tokens":[{"t":"dirs"},{"t":"lit","c":"migrate-"},{"t":"'
      'star"},{"t":"lit","c":".sql"}],"match":["migrate-10909.sql","db/migrate-'
      'v1.0.sql","db/sept/migrate-v1.sql"],"miss":["migrate.sql","db/migrate-v1'
      '/x.sql"]},{"text":"sub-project/**","negated":false,"tokens":[{"t":"lit",'
      '"c":"sub-project/"},{"t":"globstar"}],"match":["sub-project/index.js","s'
      'ub-project/src/index.js","sub-project/docs/readme.md"],"miss":["sub-proj'
      'ect2/x"]},{"text":"release\\\\*","negated":false,"tokens":[{"t":"lit","c":'
      '"release*"}],"match":["release*"],"miss":["release","release-1"]},{"text'
      '":"[CB]at","negated":false,"tokens":[{"t":"class","set":"BC"},{"t":"lit"'
      ',"c":"at"}],"match":["Cat","Bat"],"miss":["cat","Hat","CBat"]},{"text":"'
      '[1-2]00","negated":false,"tokens":[{"t":"class","set":"12"},{"t":"lit","'
      'c":"00"}],"match":["100","200"],"miss":["300","1200"]},{"text":"[0-9a-z]'
      'x","negated":false,"tokens":[{"t":"class","set":"0123456789abcdefghijklm'
      'nopqrstuvwxyz"},{"t":"lit","c":"x"}],"match":["5x","qx"],"miss":["Qx","-'
      'x"]},{"text":"a\\\\?b","negated":false,"tokens":[{"t":"lit","c":"a?b"}],"m'
      'atch":["a?b"],"miss":["ab","b"]}]'
  ==
=/  globs=@t
  %+  rap  3
  :~  globs-1
      globs-2
  ==
::  the ship's labeled and unlabeled payloads for the label facts below,
::  pinned in runner/internal/daemon/testdata/labels, where eventOf
::  accepts them
::
=/  labeled-payload-1=@t
  %+  rap  3
  :~  '{"action":"labeled","number":7,"pull_request":{"number":7,"state":"open"'
      ',"merged":false,"title":"Add x","head":{"ref":"feature","sha":"000000000'
      '00000000000000000000000000000d1","repo":{"name":"demo"}},"base":{"ref":"'
      'main","sha":"00000000000000000000000000000000000000b1","repo":{"name":"d'
      'emo"}},"user":{"login":"~nec"},"labels":[{"name":"ci:fixtures"},{"name":'
      '"needs review"}]},"repository":{"name":"demo","default_branch":"main"},"'
      'sender":{"login":"~zod"},"label":{"name":"ci:fixtures"}}'
  ==
=/  labeled-payload=@t
  labeled-payload-1
=/  unlabeled-payload-1=@t
  %+  rap  3
  :~  '{"action":"unlabeled","number":7,"pull_request":{"number":7,"state":"ope'
      'n","merged":false,"title":"Add x","head":{"ref":"feature","sha":"0000000'
      '0000000000000000000000000000000d1","repo":{"name":"demo"}},"base":{"ref"'
      ':"main","sha":"00000000000000000000000000000000000000b1","repo":{"name":'
      '"demo"}},"user":{"login":"~nec"},"labels":[{"name":"needs review"}]},"re'
      'pository":{"name":"demo","default_branch":"main"},"sender":{"login":"~zo'
      'd"},"label":{"name":"ci:fixtures"}}'
  ==
=/  unlabeled-payload=@t
  unlabeled-payload-1
=/  has-text
  |=  [text=@t part=@t]
  ^-  ?
  ?=(^ (find (trip part) (trip text)))
=/  parsed=(each (unit trigger-catalog:ci) @t)
  (parse-catalog:ci-trigger (de:json:html catalog))
=/  cat=trigger-catalog:ci
  ?:  ?=(%| -.parsed)  [~ ~]
  (fall p.parsed [~ ~])
=/  workflow-of
  |=  file=@t
  ^-  (unit trigger-workflow:ci)
  =/  ws=(list trigger-workflow:ci)  workflows.cat
  |-
  ?~  ws  ~
  ?:  =(file workflow.i.ws)  `i.ws
  $(ws t.ws)
=/  event-in
  |=  [file=@t name=@t]
  ^-  (unit trigger-event:ci)
  =/  w=(unit trigger-workflow:ci)  (workflow-of file)
  ?~  w  ~
  (event-of:ci-trigger u.w name)
=/  texts
  |=  f=(unit filter:ci)
  ^-  (list @t)
  ?~  f  ~
  (turn patterns.u.f |=(p=pattern:ci text.p))
::  a catalog text's verdict
::
=/  refused
  |=  [text=@t part=@t]
  ^-  ?
  =/  r=(each (unit trigger-catalog:ci) @t)  (parse-catalog:ci-trigger (de:json:html text))
  ?.  ?=(%| -.r)  %.n
  (has-text p.r part)
=/  accepted
  |=  text=@t
  ^-  (unit trigger-catalog:ci)
  =/  r=(each (unit trigger-catalog:ci) @t)  (parse-catalog:ci-trigger (de:json:html text))
  ?.  ?=(%& -.r)  ~
  p.r
::  one workflow of one event, and a catalog of it
::
=/  one
  |=  event=@t
  ^-  @t
  %+  rap  3
  :~  '{"version":1,"zones":{},"workflows":[{"workflow":"w.yml","name":"W",'
      '"refusal":"","events":['  event  ']}]}'
  ==
=/  plain
  |=  [event=@t rest=@t]
  ^-  @t
  %+  rap  3
  :~  '{"event":"'  event  '","refusal":"","branches":null,"tags":null,'
      '"paths":null,"typesDeclared":false,"line":1,"col":1'  rest  '}'
  ==
=/  lit-main  '{"text":"main","negated":false,"tokens":[{"t":"lit","c":"main"}]}'
::  ---- selection ----
::
=/  verdicts
  |=  outcomes=(list workflow-selection:ci)
  ^-  (list [@t selection-verdict:ci])
  (turn outcomes |=(o=workflow-selection:ci [workflow.o verdict.o]))
=/  verdict-of
  |=  [outcomes=(list workflow-selection:ci) file=@t]
  ^-  (unit selection-verdict:ci)
  =/  hit=(list workflow-selection:ci)
    (skim outcomes |=(o=workflow-selection:ci =(file workflow.o)))
  ?~  hit  ~
  `verdict.i.hit
=/  reason-of
  |=  [outcomes=(list workflow-selection:ci) file=@t]
  ^-  @t
  =/  hit=(list workflow-selection:ci)
    (skim outcomes |=(o=workflow-selection:ci =(file workflow.o)))
  ?~  hit  ''
  reason.i.hit
=/  diff
  |=  paths=(list @t)
  ^-  (unit evidence:ci-trigger)
  `[%& paths]
=/  unknown=(unit evidence:ci-trigger)  `[%| 'more than 10000 paths changed']
=/  push
  |=  [ref=@t changes=(unit evidence:ci-trigger)]
  ^-  (list workflow-selection:ci)
  (select-push:ci-trigger cat ref changes)
=/  pull
  |=  [action=@t base=@t changes=(unit evidence:ci-trigger)]
  ^-  (list workflow-selection:ci)
  (select-pull:ci-trigger cat action base changes)
=/  main  'refs/heads/main'
=/  main-src=(list workflow-selection:ci)  (push main (diff ~['src/app.js']))
=/  main-readme=(list workflow-selection:ci)  (push main (diff ~['README.md']))
=/  main-docs=(list workflow-selection:ci)  (push main (diff ~['docs/a.md']))
=/  main-none=(list workflow-selection:ci)  (push main (diff ~))
=/  main-unknown=(list workflow-selection:ci)  (push main unknown)
=/  tag-v1=(list workflow-selection:ci)  (push 'refs/tags/v1.2.3' ~)
=/  feature=(list workflow-selection:ci)  (push 'refs/heads/feature/x' (diff ~['src/app.js']))
=/  pr-src=(list workflow-selection:ci)  (pull 'opened' main (diff ~['src/app.js']))
=/  pr-docs=(list workflow-selection:ci)  (pull 'opened' main (diff ~['docs/x.md' 'README.md']))
=/  pr-closed=(list workflow-selection:ci)  (pull 'closed' main (diff ~['src/app.js']))
=/  pr-unknown=(list workflow-selection:ci)  (pull 'opened' main unknown)
::  ---- payloads and trigger text ----
::
=/  field
  |=  [text=@t path=(list @t)]
  ^-  (unit json)
  =/  j=(unit json)  (de:json:html text)
  |-
  ?~  j  ~
  ?~  path  j
  ?.  ?=([%o *] u.j)  ~
  $(j (~(get by p.u.j) i.path), path t.path)
=/  zeros  zeros:ci-trigger
=/  hx  oid-text:git-codec
=/  push-new=@t
  (push-event-payload:ci-trigger 'demo' main ~ 0xc1 ~zod `main)
=/  push-moved=@t
  (push-event-payload:ci-trigger 'demo' main `0xb1 0xc1 ~zod `main)
=/  facts=pull-facts:ci
  :*  7  'Add x'  'closed'  0xd1  'refs/heads/feature'  main  0xb1  %.y
      ~nec  'demo'  ~  ~
  ==
=/  pull-text=@t  (pull-event-payload:ci-trigger 'demo' facts ~zod `main)
=/  opened-text=@t
  (pull-event-payload:ci-trigger 'demo' facts(action 'opened', merged %.n) ~nec `main)
=/  sched-text=@t
  (schedule-event-payload:ci-trigger 'demo' main '30 5 * * 1-5' ~zod)
=/  push-cand=candidate:ci
  :*  0v3.ccccc  'demo'  main  0xa1  0xb1  `0xc1  %.n
      %pending  ~  ~  ~  ~  ~zod  %session  %trusted  ~
      ~2026.10.16  ~2026.10.16
      %required  4  `0xb1  `0x1111  0v9.eeeee  %vm  ~  %.n
      [%push ~]
      ~
      *run-concurrency:ci
      ~
  ==
=/  ev-push=run-event:ci
  :*  0v5.eeeee  %push  main  ~  `0xc1  ~  ~  ~zod
      'smart-http push (write token)'  ~2026.10.16  push-new
  ==
=/  ev-pull=run-event:ci
  :*  0v6.fffff  %pull-request  main  ~  `0xd1  `facts  ~  ~nec
      'pull request merge'  ~2026.10.16  pull-text
  ==
=/  occ=occurrence-facts:ci
  :*  'nightly.yml'  0  '30 5 * * 1-5'  `'America/New_York'
      ~2026.10.16..09.30.00  ~2026.10.16..09.30.05  0v7.ggggg  ~zod  ~2026.10.1
  ==
=/  ev-sched=run-event:ci
  :*  0v8.hhhhh  %schedule  main  ~  `0xc1  ~  `occ  ~zod
      'schedule'  ~2026.10.16..09.30.05  sched-text
  ==
=/  as-event
  |=  e=run-event:ci
  ^-  candidate:ci
  push-cand(mode %event, trigger [%event e])
=/  starts-with-event
  |=  c=candidate:ci
  ^-  ?
  =/  name=@t  (rap 3 ~[(event-name:ci-trigger trigger.c) ' '])
  =(name (end [3 (met 3 name)] (trigger-text:ci-trigger c)))
::  ---- glob table ----
::
=/  glob-rows=(list json)
  =/  j=(unit json)  (de:json:html globs)
  ?.  ?=([~ %a *] j)  ~
  p.u.j
=/  glob-cases=(list [name=@t expect=? got=?])
  %+  turn  glob-rows
  |=  row=json
  ^-  [name=@t expect=? got=?]
  ?.  ?=([%o *] row)  ['a glob row is an object' %.y %.n]
  =/  p=(each pattern:ci @t)  (parse-pattern:ci-trigger row)
  ?:  ?=(%| -.p)  [(rap 3 ~['a glob row parses: ' p.p]) %.y %.n]
  =/  names
    |=  key=@t
    ^-  (list @t)
    =/  v=(unit json)  (~(get by p.row) key)
    ?.  ?=([~ %a *] v)  ~
    (murn p.u.v |=(j=json ?.(?=([%s *] j) ~ `p.j)))
  =/  match=(list @t)  (names 'match')
  =/  miss=(list @t)  (names 'miss')
  :+  %+  rap
        3
      ~['glob ' text.p.p ' matches each of its ' (crip (a-co:co (lent match))) ' and none of its ' (crip (a-co:co (lent miss)))]
    %.y
  ::  the non-empty test comes last: narrowing .match first would hand
  ::  levy a cell for its list
  ?&  (levy match |=(n=@t (glob-match:ci-trigger tokens.p.p n)))
      !(lien miss |=(n=@t (glob-match:ci-trigger tokens.p.p n)))
      ?=(^ match)
  ==
::  ---- the cases ----
::
=/  wire=(list [name=@t expect=? got=?])
  :~  ['the pinned selection catalog parses' %.y ?=([%& ^] parsed)]
      :+  'its seven workflows, in name order'  %.y
      .=  (turn workflows.cat |=(w=trigger-workflow:ci workflow.w))
      :~  'a-branches.yml'  'b-ignore.yml'  'c-tags.yml'  'd-plain.yml'
          'e-refused.yml'  'f-manual.yml'  'g-broken.yml'
      ==
      :+  'an on: that cannot be read refuses its workflow, with the reason'  %.y
      =/  w=(unit trigger-workflow:ci)  (workflow-of 'g-broken.yml')
      ?&(?=(^ w) ?=(^ refusal.u.w) (has-text u.refusal.u.w 'push twice') ?=(~ events.u.w))
      :+  'a refused push trigger is kept, refused; its workflow is not'  %.y
      =/  w=(unit trigger-workflow:ci)  (workflow-of 'e-refused.yml')
      =/  e=(unit trigger-event:ci)  (event-in 'e-refused.yml' 'push')
      =/  d=(unit trigger-event:ci)  (event-in 'e-refused.yml' 'workflow_dispatch')
      ?&  ?=(^ w)  ?=(~ refusal.u.w)  ?=(^ e)  ?=(^ refusal.u.e)
          (has-text u.refusal.u.e 'branches and branches-ignore')
          ?=(^ d)  ?=(~ refusal.u.d)
      ==
      :+  'an ordered include list keeps its order and its negation'  %.y
      =/  e=(unit trigger-event:ci)  (event-in 'a-branches.yml' 'push')
      ?&  ?=(^ e)  ?=(^ branches.u.e)  !ignore.u.branches.u.e
          .=  (texts branches.u.e)
          ~['main' 'releases/**' '!releases/**-alpha' 'releases/keep-alpha']
          (levy patterns.u.branches.u.e |=(p=pattern:ci =(negated.p =('!' (end 3 text.p)))))
      ==
      :+  'an -ignore list is marked so'  %.y
      =/  e=(unit trigger-event:ci)  (event-in 'b-ignore.yml' 'push')
      ?&(?=(^ e) ?=(^ branches.u.e) ignore.u.branches.u.e ?=(^ paths.u.e) ignore.u.paths.u.e)
      :+  'declared activity types are kept as declared'  %.y
      =/  e=(unit trigger-event:ci)  (event-in 'b-ignore.yml' 'pull_request')
      ?&(?=(^ e) types-declared.u.e =(types.u.e ~['opened' 'closed']))
      :+  'undeclared activity types are the reference\'s defaults'  %.y
      =/  e=(unit trigger-event:ci)  (event-in 'd-plain.yml' 'pull_request')
      ?&(?=(^ e) !types-declared.u.e =(types.u.e ~['opened' 'synchronize' 'reopened']))
      :+  'a UTC schedule needs no zone table'  %.y
      =/  e=(unit trigger-event:ci)  (event-in 'f-manual.yml' 'schedule')
      ?&  ?=(^ e)  ?=([* ~] schedules.u.e)  ?=(~ timezone.i.schedules.u.e)
          ?=(^ spec.i.schedules.u.e)  =(~ zones.cat)
      ==
      ['no triggers key is unknown, never an empty catalog' %.y =([%& ~] (parse-catalog:ci-trigger ~))]
      :+  'an empty catalog is a catalog'  %.y
      =(`[~ ~] (accepted '{"version":1,"workflows":[],"zones":{}}'))
      ['a catalog of another version refuses' %.y (refused '{"version":2,"workflows":[],"zones":{}}' 'version is not 1')]
      ['a catalog whose workflows are not a list refuses' %.y (refused '{"version":1,"workflows":{},"zones":{}}' 'must be a list')]
      :+  'a workflow listed twice refuses the catalog'  %.y
      %+  refused
        '{"version":1,"zones":{},"workflows":[{"workflow":"w.yml","name":"W","refusal":"","events":[]},{"workflow":"w.yml","name":"V","refusal":"","events":[]}]}'
      'twice'
      :+  'a workflow outside .github/workflows refuses the catalog'  %.y
      %+  refused
        '{"version":1,"zones":{},"workflows":[{"workflow":"../w.yml","name":"W","refusal":"","events":[]}]}'
      'not a file name'
      :+  'a refused workflow lists no event'  %.y
      %+  refused
        %+  rap
          3
        ~['{"version":1,"zones":{},"workflows":[{"workflow":"w.yml","name":"W","refusal":"bad","events":[' (plain 'push' '') ']}]}']
      'lists no event'
  ==
=/  wire-2=(list [name=@t expect=? got=?])
  :~  :+  'tags belong to a push only'  %.y
      %+  refused
        %-  one
        %+  plain  'pull_request'
        (rap 3 ~[',"types":["opened"]' ',"tags":{"ignore":false,"patterns":[' lit-main ']}'])
      'only a push filters tags'
      :+  'branches and paths belong to a push or a pull request only'  %.y
      %+  refused
        %-  one
        (plain 'workflow_dispatch' (rap 3 ~[',"paths":{"ignore":false,"patterns":[' lit-main ']}']))
      'only a push or a pull_request filters branches and paths'
      :+  'an -ignore list holding a ! pattern refuses'  %.y
      %+  refused
        %-  one
        %+  plain
          'push'
        ',"branches":{"ignore":true,"patterns":[{"text":"!a","negated":true,"tokens":[{"t":"lit","c":"a"}]}]}'
      'holding a ! pattern'
      :+  'an include list of ! patterns only refuses'  %.y
      %+  refused
        %-  one
        %+  plain
          'push'
        ',"branches":{"ignore":false,"patterns":[{"text":"!a","negated":true,"tokens":[{"t":"lit","c":"a"}]}]}'
      'only ! patterns'
      :+  'a negation flag that disagrees with its text refuses'  %.y
      %+  refused
        %-  one
        %+  plain
          'push'
        ',"branches":{"ignore":false,"patterns":[{"text":"a","negated":true,"tokens":[{"t":"lit","c":"a"}]}]}'
      'negated exactly when'
      :+  'a token of an unknown kind refuses'  %.y
      %+  refused
        %-  one
        %+  plain
          'push'
        ',"branches":{"ignore":false,"patterns":[{"text":"a","negated":false,"tokens":[{"t":"regex","c":"a"}]}]}'
      'unknown kind'
      :+  'a quantifier of more than one byte refuses'  %.y
      %+  refused
        %-  one
        %+  plain
          'push'
        ',"branches":{"ignore":false,"patterns":[{"text":"ab?","negated":false,"tokens":[{"t":"opt","of":{"t":"lit","c":"ab"}}]}]}'
      'one ASCII byte'
      :+  'a pull request lists its activity types'  %.y
      (refused (one (plain 'pull_request' ',"types":null')) 'lists its activity types')
      :+  'an unknown activity type refuses'  %.y
      %+  refused
        (one (plain 'pull_request' ',"types":["opend"]'))
      'opend is not a pull_request activity type'
      :+  'only a pull request has activity types'  %.y
      (refused (one (plain 'push' ',"types":["opened"]')) 'only a pull_request has activity types')
      :+  'a schedule naming a zone the catalog has no table for refuses it'  %.y
      %+  refused
        %-  one
        %+  plain
          'schedule'
        ',"schedules":[{"cron":"0 3 1 1 0","timezone":"Europe/Paris","refusal":"","minutes":[0],"hours":[3],"days":[1],"months":[1],"weekdays":[0],"dayStar":false,"weekdayStar":false}]'
      'Europe/Paris'
      :+  'a schedule the ship\'s own rules refuse is refused alone'  %.y
      =/  c=(unit trigger-catalog:ci)
        %-  accepted
        %-  one
        %+  plain
          'schedule'
        ',"schedules":[{"cron":"0,3 3 * * *","timezone":"","refusal":"","minutes":[0,3],"hours":[3],"days":[1],"months":[1],"weekdays":[0],"dayStar":true,"weekdayStar":true}]'
      ?~  c  %.n
      ?.  ?=([* ~] workflows.u.c)  %.n
      ?.  ?=([* ~] events.i.workflows.u.c)  %.n
      =/  e=trigger-event:ci  i.events.i.workflows.u.c
      ?.  ?=([* ~] schedules.e)  %.n
      ?&  ?=(^ refusal.i.schedules.e)  ?=(~ spec.i.schedules.e)
          (has-text u.refusal.i.schedules.e 'the ship refuses it')
          (has-text u.refusal.i.schedules.e '3 minute(s) apart')
      ==
      :+  'a compiler-refused schedule keeps its text and reason'  %.y
      =/  c=(unit trigger-catalog:ci)
        %-  accepted
        %-  one
        %+  plain
          'schedule'
        ',"schedules":[{"cron":"@daily","timezone":"","refusal":"@daily is non-standard","minutes":null,"hours":null,"days":null,"months":null,"weekdays":null,"dayStar":false,"weekdayStar":false}]'
      ?~  c  %.n
      ?.  ?=([* ~] workflows.u.c)  %.n
      ?.  ?=([* ~] events.i.workflows.u.c)  %.n
      =/  e=trigger-event:ci  i.events.i.workflows.u.c
      ?.  ?=([* ~] schedules.e)  %.n
      ?&(=('@daily' cron.i.schedules.e) =(`'@daily is non-standard' refusal.i.schedules.e))
      :+  'a zone transition out of order refuses'  %.y
      %+  refused
        '{"version":1,"workflows":[],"zones":{"X/Y":{"start":1577836800,"end":2208988800,"offset":0,"transitions":[[1600000000,3600],[1590000000,0]]}}}'
      'out of order'
      :+  'a zone offset beyond 18 hours refuses'  %.y
      %+  refused
        '{"version":1,"workflows":[],"zones":{"X/Y":{"start":1577836800,"end":2208988800,"offset":70000,"transitions":[]}}}'
      'beyond 18 hours'
      :+  'a zone table reads negative offsets'  %.y
      =/  c=(unit trigger-catalog:ci)
        %-  accepted
        '{"version":1,"workflows":[],"zones":{"X/Y":{"start":1577836800,"end":2208988800,"offset":-18000,"transitions":[[1583650800,-14400]]}}}'
      ?~  c  %.n
      =/  z=(unit zone:ci)  (~(get by zones.u.c) 'X/Y')
      ?~  z  %.n
      ?&  =(offset.u.z -18.000)  =(start.u.z ~2020.1.1)
          =(transitions.u.z ~[[~2020.3.8..07.00.00 -14.400]])
      ==
  ==
=/  globs-counted=(list [name=@t expect=? got=?])
  :~  ['the glob table has all 29 cheat-sheet rows' %.y =(29 (lent glob-rows))]
  ==
=/  select=(list [name=@t expect=? got=?])
  :~  :+  'push main changing src/app.js: what each workflow decides'  %.y
      .=  (verdicts main-src)
      :~  ['a-branches.yml' %selected]  ['b-ignore.yml' %selected]
          ['c-tags.yml' %excluded]  ['d-plain.yml' %selected]
          ['e-refused.yml' %error]  ['g-broken.yml' %error]
      ==
      :+  'a workflow declaring no push is not listed'  %.y
      !(lien main-src |=(o=workflow-selection:ci =('f-manual.yml' workflow.o)))
      :+  'branch and path filters are a conjunction: a branch match is not enough'  %.y
      =(`%excluded (verdict-of main-readme 'a-branches.yml'))
      :+  'push main changing README.md'  %.y
      .=  (verdicts main-readme)
      :~  ['a-branches.yml' %excluded]  ['b-ignore.yml' %selected]
          ['c-tags.yml' %excluded]  ['d-plain.yml' %selected]
          ['e-refused.yml' %error]  ['g-broken.yml' %error]
      ==
      :+  'the excluded reason names the branch that passed and the paths that did not'  %.y
      =/  r=@t  (reason-of main-readme 'a-branches.yml')
      &((has-text r 'branch main passes') (has-text r 'no changed path passes paths'))
      :+  'a path the ordered list excludes again does not run it'  %.y
      =(`%excluded (verdict-of (push main (diff ~['src/docs/guide.md'])) 'a-branches.yml'))
      :+  'a path a later pattern includes again runs it'  %.y
      =(`%selected (verdict-of (push main (diff ~['src/docs/keep/note.md'])) 'a-branches.yml'))
      :+  'one included path among excluded ones runs it'  %.y
      =(`%selected (verdict-of (push main (diff ~['src/docs/guide.md' 'README.md' 'src/docs/keep/x.md'])) 'a-branches.yml'))
      :+  'paths-ignore matching every changed path does not run it'  %.y
      ?&  =(`%excluded (verdict-of main-docs 'b-ignore.yml'))
          (has-text (reason-of main-docs 'b-ignore.yml') 'matches every changed path')
      ==
      :+  'paths-ignore with one path it does not match runs it'  %.y
      =(`%selected (verdict-of (push main (diff ~['docs/a.md' 'lib/x.c'])) 'b-ignore.yml'))
      :+  'no changed path runs no path-filtered workflow, include or ignore'  %.y
      ?&  =(`%excluded (verdict-of main-none 'a-branches.yml'))
          =(`%excluded (verdict-of main-none 'b-ignore.yml'))
          =(`%selected (verdict-of main-none 'd-plain.yml'))
          (has-text (reason-of main-none 'a-branches.yml') 'no file changed')
      ==
      :+  'unavailable change evidence selects, labelled, never a silent no match'  %.y
      ?&  =(`%selected (verdict-of main-unknown 'a-branches.yml'))
          =(`%selected (verdict-of main-unknown 'b-ignore.yml'))
          (has-text (reason-of main-unknown 'a-branches.yml') 'the path filter is not evaluated')
          (has-text (reason-of main-unknown 'a-branches.yml') '(more than 10000 paths changed)')
          !(has-text (reason-of main-unknown 'd-plain.yml') 'not evaluated')
      ==
      :+  'a branch an -ignore list matches does not run it; an excluded branch reads no paths'  %.y
      .=  (verdicts feature)
      :~  ['a-branches.yml' %excluded]  ['b-ignore.yml' %excluded]
          ['c-tags.yml' %excluded]  ['d-plain.yml' %selected]
          ['e-refused.yml' %error]  ['g-broken.yml' %error]
      ==
      :+  'releases/** includes releases/10'  %.y
      =(`%selected (verdict-of (push 'refs/heads/releases/10' (diff ~['src/a.c'])) 'a-branches.yml'))
      :+  '!releases/**-alpha excludes releases/10-alpha again'  %.y
      =(`%excluded (verdict-of (push 'refs/heads/releases/10-alpha' (diff ~['src/a.c'])) 'a-branches.yml'))
      :+  'a later releases/keep-alpha includes it again'  %.y
      =(`%selected (verdict-of (push 'refs/heads/releases/keep-alpha' (diff ~['src/a.c'])) 'a-branches.yml'))
      :+  '** crosses directories: releases/beta/3-alpha is excluded again'  %.y
      =(`%excluded (verdict-of (push 'refs/heads/releases/beta/3-alpha' (diff ~['src/a.c'])) 'a-branches.yml'))
  ==
=/  select-2=(list [name=@t expect=? got=?])
  :~  :+  'a tag push: branch-only filters skip it, tags filter it, paths are not read'  %.y
      .=  (verdicts tag-v1)
      :~  ['a-branches.yml' %excluded]  ['b-ignore.yml' %excluded]
          ['c-tags.yml' %selected]  ['d-plain.yml' %selected]
          ['e-refused.yml' %error]  ['g-broken.yml' %error]
      ==
      :+  'the tag reasons say so'  %.y
      ?&  (has-text (reason-of tag-v1 'a-branches.yml') 'only branches are filtered')
          (has-text (reason-of tag-v1 'b-ignore.yml') 'only branches are filtered')
          (has-text (reason-of tag-v1 'c-tags.yml') 'paths are not evaluated for a tag push')
          (has-text (reason-of tag-v1 'd-plain.yml') 'no tag filter')
      ==
      :+  'a tag push never reads paths, even when evidence is offered'  %.y
      =(`%selected (verdict-of (push 'refs/tags/v1.2.3' (diff ~)) 'c-tags.yml'))
      :+  'a tag an ordered list excludes again does not run it'  %.y
      =(`%excluded (verdict-of (push 'refs/tags/v0.9.1' ~) 'c-tags.yml'))
      :+  'a tag no pattern matches does not run it'  %.y
      =(`%excluded (verdict-of (push 'refs/tags/v1.2' ~) 'c-tags.yml'))
      :+  'a tags-only filter skips a branch push'  %.y
      (has-text (reason-of main-src 'c-tags.yml') 'only tags are filtered')
      :+  'a ref that is neither a branch nor a tag runs nothing'  %.y
      =/  o=(list workflow-selection:ci)  (push 'refs/notes/commits' (diff ~['src/a.c']))
      ?&  =(`%excluded (verdict-of o 'd-plain.yml'))
          (has-text (reason-of o 'd-plain.yml') 'neither a branch nor a tag')
      ==
      :+  'refused triggers are in error with their reasons'  %.y
      ?&  (has-text (reason-of main-src 'e-refused.yml') 'the push trigger is refused')
          (has-text (reason-of main-src 'g-broken.yml') 'on: is refused')
      ==
      :+  'selected and unselected partition the outcomes'  %.y
      ?&  =((selected-workflows:ci-trigger main-src) ~['a-branches.yml' 'b-ignore.yml' 'd-plain.yml'])
          .=  (turn (unselected:ci-trigger main-src) |=(o=workflow-selection:ci workflow.o))
          ~['c-tags.yml' 'e-refused.yml' 'g-broken.yml']
      ==
      ['main needs the diff' %.y (push-needs-paths:ci-trigger cat main)]
      ['an excluded branch needs no diff' %.n (push-needs-paths:ci-trigger cat 'refs/heads/feature/x')]
      ['a tag never needs the diff' %.n (push-needs-paths:ci-trigger cat 'refs/tags/v1.2.3')]
      ['releases/10-alpha needs it (b-ignore reads paths)' %.y (push-needs-paths:ci-trigger cat 'refs/heads/releases/10-alpha')]
  ==
=/  select-3=(list [name=@t expect=? got=?])
  :~  :+  'a pull request opened onto main'  %.y
      .=  (verdicts pr-src)
      :~  ['a-branches.yml' %selected]  ['b-ignore.yml' %selected]
          ['d-plain.yml' %selected]  ['g-broken.yml' %error]
      ==
      :+  'a workflow declaring no pull_request is not listed, even with a refused push'  %.y
      =/  absent=(set @t)  (silt ~['c-tags.yml' 'e-refused.yml' 'f-manual.yml'])
      !(lien pr-src |=(o=workflow-selection:ci (~(has in absent) workflow.o)))
      :+  'paths-ignore over a pull request\'s changes: all ignored does not run it'  %.y
      =(`%excluded (verdict-of pr-docs 'a-branches.yml'))
      :+  '**/*.md ignores a nested markdown file'  %.y
      =(`%excluded (verdict-of (pull 'opened' main (diff ~['lib/README.md'])) 'a-branches.yml'))
      :+  'one path paths-ignore does not match runs it'  %.y
      =(`%selected (verdict-of (pull 'opened' main (diff ~['docs/x.md' 'src/app.js'])) 'a-branches.yml'))
      :+  'closed is not a default activity type; declared, it runs'  %.y
      .=  (verdicts pr-closed)
      :~  ['a-branches.yml' %excluded]  ['b-ignore.yml' %selected]
          ['d-plain.yml' %excluded]  ['g-broken.yml' %error]
      ==
      :+  'the excluded activity names the types it is not in'  %.y
      %+  has-text
        (reason-of pr-closed 'd-plain.yml')
      'activity closed is not in types [opened, synchronize, reopened]'
      :+  'reopened is a default type and not one b-ignore declares'  %.y
      .=  (verdicts (pull 'reopened' main (diff ~['src/app.js'])))
      :~  ['a-branches.yml' %selected]  ['b-ignore.yml' %excluded]
          ['d-plain.yml' %selected]  ['g-broken.yml' %error]
      ==
      :+  'a pull request\'s branch filter reads its target, not its head'  %.y
      =/  o=(list workflow-selection:ci)
        %^  pull
          'opened'
          'refs/heads/develop'
        (diff ~['src/app.js'])
      ?&  =(`%excluded (verdict-of o 'a-branches.yml'))
          =(`%selected (verdict-of o 'b-ignore.yml'))
          (has-text (reason-of o 'a-branches.yml') 'target develop does not pass')
      ==
      :+  'branches-ignore over the target'  %.y
      =(`%excluded (verdict-of (pull 'opened' 'refs/heads/wip' (diff ~['src/app.js'])) 'b-ignore.yml'))
      :+  'a pull request\'s unavailable evidence selects, labelled'  %.y
      ?&  =(`%selected (verdict-of pr-unknown 'a-branches.yml'))
          (has-text (reason-of pr-unknown 'a-branches.yml') 'not evaluated')
      ==
      ['opened onto main needs the diff' %.y (pull-needs-paths:ci-trigger cat 'opened' main)]
      ['closed needs none (no path-filtered workflow takes it)' %.n (pull-needs-paths:ci-trigger cat 'closed' main)]
      ['opened onto develop needs none' %.n (pull-needs-paths:ci-trigger cat 'opened' 'refs/heads/develop')]
  ==
=/  payloads=(list [name=@t expect=? got=?])
  :~  ['a new ref\'s push payload: before is forty zeros' %.y =(`[%s zeros] (field push-new ~['before']))]
      ['and created is true, deleted false' %.y &(=(`[%b %.y] (field push-new ~['created'])) =(`[%b %.n] (field push-new ~['deleted'])))]
      ['after is the new tip' %.y =(`[%s '00000000000000000000000000000000000000c1'] (field push-new ~['after']))]
      ['ref, sender and default branch' %.y &(=(`[%s main] (field push-new ~['ref'])) =(`[%s '~zod'] (field push-new ~['sender' 'login'])) =(`[%s 'main'] (field push-new ~['repository' 'default_branch'])))]
      ['a moved ref: before is the old tip, created false' %.y &(=(`[%s (hx 0xb1)] (field push-moved ~['before'])) =(`[%b %.n] (field push-moved ~['created'])))]
      ['a pull request payload: action and number' %.y &(=(`[%s 'closed'] (field pull-text ~['action'])) =(`[%n ~.7] (field pull-text ~['number'])))]
      ['a merged close is closed and merged' %.y &(=(`[%s 'closed'] (field pull-text ~['pull_request' 'state'])) =(`[%b %.y] (field pull-text ~['pull_request' 'merged'])))]
      ['head: its branch and sha' %.y &(=(`[%s 'feature'] (field pull-text ~['pull_request' 'head' 'ref'])) =(`[%s (hx 0xd1)] (field pull-text ~['pull_request' 'head' 'sha'])))]
      ['base: the target branch and the tip it integrates onto' %.y &(=(`[%s 'main'] (field pull-text ~['pull_request' 'base' 'ref'])) =(`[%s (hx 0xb1)] (field pull-text ~['pull_request' 'base' 'sha'])))]
      ['the author and the sender' %.y &(=(`[%s '~nec'] (field pull-text ~['pull_request' 'user' 'login'])) =(`[%s '~zod'] (field pull-text ~['sender' 'login'])))]
      ['an opened pull request is open and not merged' %.y &(=(`[%s 'open'] (field opened-text ~['pull_request' 'state'])) =(`[%b %.n] (field opened-text ~['pull_request' 'merged'])))]
      ['a schedule payload: the cron it fired for' %.y =(`[%s '30 5 * * 1-5'] (field sched-text ~['schedule']))]
      ['its default branch and its sender, the promoter' %.y &(=(`[%s 'main'] (field sched-text ~['repository' 'default_branch'])) =(`[%s '~zod'] (field sched-text ~['sender' 'login'])))]
  ==
=/  signed=(list [name=@t expect=? got=?])
  :~  :+  'a staged push\'s trigger: its ref, base and candidate'  %.y
      .=  (trigger-text:ci-trigger push-cand)
      (rap 3 ~['push refs/heads/main ' (hx 0xb1) '..' (hx 0xc1)])
      :+  'an automatic push\'s trigger names its tips and its event'  %.y
      .=  (trigger-text:ci-trigger (as-event ev-push))
      (rap 3 ~['push refs/heads/main ' zeros '..' (hx 0xc1) ' event ' (scot %uv 0v5.eeeee)])
      :+  'a pull request\'s trigger names its number, activity, head, base and event'  %.y
      .=  (trigger-text:ci-trigger (as-event ev-pull))
      %+  rap
        3
      ~['pull_request #7 closed head ' (hx 0xd1) ' base ' (hx 0xb1) ' event ' (scot %uv 0v6.fffff)]
      :+  'a schedule\'s trigger names the definition, the due instant and the occurrence'  %.y
      .=  (trigger-text:ci-trigger (as-event ev-sched))
      (rap 3 ~['schedule nightly.yml#0 due 2026-10-16T09:30:00Z occurrence ' (scot %uv 0v8.hhhhh)])
      :+  'every trigger begins with the event act runs'  %.y
      ?&  (starts-with-event push-cand)
          (starts-with-event (as-event ev-push))
          (starts-with-event (as-event ev-pull))
          (starts-with-event (as-event ev-sched))
      ==
      :+  'the events act runs'  %.y
      .=  :~  (event-name:ci-trigger trigger.push-cand)
              (event-name:ci-trigger [%event ev-push])
              (event-name:ci-trigger [%event ev-pull])
              (event-name:ci-trigger [%event ev-sched])
          ==
      ~['push' 'push' 'pull_request' 'schedule']
  ==
::  ---- pull request labels ----
::
::  four pull_request triggers as the compiler compiles them, written out
::  with the tokens it gives `main` and `src/**`: ERPit's declared types,
::  GitHub's defaults (undeclared), unlabeled on main, labeled with a path
::  filter
::
=/  pr-event
  |=  [types=(list @t) declared=? branches=(unit filter:ci) paths=(unit filter:ci)]
  ^-  trigger-event:ci
  ['pull_request' ~ branches ~ paths types declared ~ 1 1]
=/  label-wf
  |=  [file=@t e=trigger-event:ci]
  ^-  trigger-workflow:ci
  [file file ~[e] ~ ~]
=/  on-main=(unit filter:ci)  `[%.n ~[['main' %.n ~[[%lit 'main']]]]]
=/  src-only=(unit filter:ci)  `[%.n ~[['src/**' %.n ~[[%lit 'src/'] [%globstar ~]]]]]
=/  label-cat=trigger-catalog:ci
  :_  ~
  :~  (label-wf 'erpit.yml' (pr-event ~['opened' 'synchronize' 'reopened' 'labeled'] %.y ~ ~))
      (label-wf 'defaults.yml' (pr-event ~['opened' 'synchronize' 'reopened'] %.n ~ ~))
      (label-wf 'unlabeled.yml' (pr-event ~['unlabeled'] %.y on-main ~))
      (label-wf 'paths.yml' (pr-event ~['labeled'] %.y ~ src-only))
  ==
=/  lpull
  |=  [action=@t base=@t changes=(unit evidence:ci-trigger)]
  ^-  (list workflow-selection:ci)
  (select-pull:ci-trigger label-cat action base changes)
=/  labeled-src=(list workflow-selection:ci)  (lpull 'labeled' main (diff ~['src/app.js']))
=/  labeled-docs=(list workflow-selection:ci)  (lpull 'labeled' main (diff ~['docs/a.md']))
=/  unlabeled-main=(list workflow-selection:ci)  (lpull 'unlabeled' main (diff ~['src/app.js']))
=/  unlabeled-dev=(list workflow-selection:ci)
  (lpull 'unlabeled' 'refs/heads/dev' (diff ~['src/app.js']))
=/  sync-src=(list workflow-selection:ci)  (lpull 'synchronize' main (diff ~['src/app.js']))
::  the label facts the pinned payloads were rendered from
::
=/  labeled-facts=pull-facts:ci
  :*  7  'Add x'  'labeled'  0xd1  'refs/heads/feature'  main  0xb1  %.n
      ~nec  'demo'  ~['ci:fixtures' 'needs review']  `'ci:fixtures'
  ==
=/  labeled-text=@t  (pull-event-payload:ci-trigger 'demo' labeled-facts ~zod `main)
=/  unlabeled-text=@t
  %:  pull-event-payload:ci-trigger
    'demo'
    labeled-facts(action 'unlabeled', labels ~['needs review'])
    ~zod
    `main
  ==
=/  sync-text=@t
  %:  pull-event-payload:ci-trigger
    'demo'
    labeled-facts(action 'synchronize', labels ~['ci:fixtures'], label ~)
    ~nec
    `main
  ==
=/  bare-text=@t
  (pull-event-payload:ci-trigger 'demo' labeled-facts(action 'opened', labels ~, label ~) ~nec `main)
=/  named
  |=  name=@t
  ^-  json
  (pairs:enjs:format ~[['name' s+name]])
=/  label-update
  |=  [action=@t at=?(%open %merged %closed) labels=(list @t) label=(unit @t)]
  ^-  pull-update:ci
  :*  0v1.label  7  action  0xd1  0xb1  'refs/heads/feature'  main  ~nec  'demo'
      'Add x'  =(%merged at)  ~  at  labels  label
  ==
=/  label-cases=(list [name=@t expect=? got=?])
  :~  :+  'labeled and unlabeled are native activities now'  %.y
      ?&  (~(has in native-pull-types:ci-trigger) 'labeled')
          (~(has in native-pull-types:ci-trigger) 'unlabeled')
      ==
      :+  'GitHub\'s default types stay opened, synchronize and reopened'  %.y
      =(default-pull-types:ci-trigger ~['opened' 'synchronize' 'reopened'])
      :+  'labeled selects a workflow that declares it, and the default types do not'  %.y
      .=  (verdicts labeled-src)
      :~  ['erpit.yml' %selected]  ['defaults.yml' %excluded]
          ['unlabeled.yml' %excluded]  ['paths.yml' %selected]
      ==
      :+  'the default types\' refusal names them'  %.y
      %+  has-text
        (reason-of labeled-src 'defaults.yml')
      'activity labeled is not in types [opened, synchronize, reopened]'
      :+  'a path filter applies to a label change'  %.y
      ?&  =(`%excluded (verdict-of labeled-docs 'paths.yml'))
          =(`%selected (verdict-of labeled-docs 'erpit.yml'))
      ==
      :+  'unlabeled selects only a workflow that declares it, on its branch filter'  %.y
      .=  (verdicts unlabeled-main)
      :~  ['erpit.yml' %excluded]  ['defaults.yml' %excluded]
          ['unlabeled.yml' %selected]  ['paths.yml' %excluded]
      ==
      :+  'a branch filter applies to a label change'  %.y
      ?&  =(`%excluded (verdict-of unlabeled-dev 'unlabeled.yml'))
          (has-text (reason-of unlabeled-dev 'unlabeled.yml') 'target dev does not pass')
      ==
      :+  'synchronize still selects as before'  %.y
      .=  (verdicts sync-src)
      :~  ['erpit.yml' %selected]  ['defaults.yml' %selected]
          ['unlabeled.yml' %excluded]  ['paths.yml' %excluded]
      ==
      :+  'the ship\'s labeled payload is the pinned one the runner accepts'  %.y
      =((de:json:html labeled-text) (de:json:html labeled-payload))
      :+  'the ship\'s unlabeled payload is the pinned one the runner accepts'  %.y
      =((de:json:html unlabeled-text) (de:json:html unlabeled-payload))
      :+  'a labeled payload names the label and lists the labels after it, sorted'  %.y
      ?&  =(`(named 'ci:fixtures') (field labeled-text ~['label']))
          =(`[%a ~[(named 'ci:fixtures') (named 'needs review')]] (field labeled-text ~['pull_request' 'labels']))
          =(`[%s 'labeled'] (field labeled-text ~['action']))
          =(`[%s '~zod'] (field labeled-text ~['sender' 'login']))
          =(`[%s '~nec'] (field labeled-text ~['pull_request' 'user' 'login']))
      ==
      :+  'an unlabeled payload no longer lists the label it removed'  %.y
      ?&  =(`(named 'ci:fixtures') (field unlabeled-text ~['label']))
          =(`[%a ~[(named 'needs review')]] (field unlabeled-text ~['pull_request' 'labels']))
      ==
      :+  'every pull request payload lists its labels, and only a label change names one'  %.y
      ?&  =(`[%a ~[(named 'ci:fixtures')]] (field sync-text ~['pull_request' 'labels']))
          =(~ (field sync-text ~['label']))
          =(`[%a ~] (field bare-text ~['pull_request' 'labels']))
          =(~ (field bare-text ~['label']))
      ==
      :+  'a label change on an open pull request is selected as any activity is'  %.y
      =(~ (label-outcome:ci-trigger (label-update 'labeled' %open ~['ci:fixtures'] `'ci:fixtures')))
      :+  'a label change on a closed pull request is recorded and runs nothing'  %.y
      .=  `'recorded: a label change on a closed pull request runs no workflow'
      (label-outcome:ci-trigger (label-update 'labeled' %closed ~['ci:fixtures'] `'ci:fixtures'))
      :+  'a label change on a merged pull request is recorded and runs nothing'  %.y
      .=  `'recorded: a label change on a merged pull request runs no workflow'
      (label-outcome:ci-trigger (label-update 'unlabeled' %merged ~ `'ci:fixtures'))
      :+  'the rule is a label change\'s alone: a close is no label change'  %.y
      =(~ (label-outcome:ci-trigger (label-update 'closed' %closed ~ ~)))
  ==
=/  cases=(list [name=@t expect=? got=?])
  :(weld wire wire-2 globs-counted glob-cases select select-2 select-3 payloads signed label-cases)
=/  failed=(list @t)
  %+  murn  cases
  |=  [name=@t expect=? got=?]
  ?:(=(expect got) ~ `name)
=/  passed=@ud  (sub (lent cases) (lent failed))
~&  [%failed failed]
~&  (crip "passed={<passed>} of={<(lent cases)>}")
?=(~ failed)
