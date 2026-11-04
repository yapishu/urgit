::  act --json envelope vectors: the 68 lines of the 001a spike log
::  (suite/structural, act 0.2.89) as literal cords, plus the set-output
::  line act emits for a $GITHUB_OUTPUT write, plus the refusals.
::  The checkout line's host path is replaced by /work/erpit.
::
/-  ci
/+  ci-event
:-  %say
|=  *
:-  %noun
=/  spike=(list @t)
  :~  '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"⭐ Run Set up job","step":"Set up job","stepid":["--setup-job"],"time":"2026-09-11T19:33:20-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"🚀  Start image=catthehacker/ubuntu:act-latest","step":"Set up job","stepid":["--setup-job"],"time":"2026-09-11T19:33:20-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"  🐳  docker pull image=catthehacker/ubuntu:act-latest platform= username= forcePull=true","step":"Set up job","stepid":["--setup-job"],"time":"2026-09-11T19:33:20-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"  🐳  docker create image=catthehacker/ubuntu:act-latest platform= entrypoint=[\\"tail\\" \\"-f\\" \\"/dev/null\\"] cmd=[] network=\\"bridge\\"","step":"Set up job","stepid":["--setup-job"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"  🐳  docker run image=catthehacker/ubuntu:act-latest platform= entrypoint=[\\"tail\\" \\"-f\\" \\"/dev/null\\"] cmd=[] network=\\"bridge\\"","step":"Set up job","stepid":["--setup-job"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"  🐳  docker exec cmd=[node --no-warnings -e console.log(process.execPath)] user= workdir=","step":"Set up job","stepid":["--setup-job"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"  ✅  Success - Set up job","step":"Set up job","stepResult":"success","stepid":["--setup-job"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"⭐ Run Main actions/checkout@v4","stage":"Main","step":"actions/checkout@v4","stepID":["0"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"  🐳  docker cp src=/work/erpit/. dst=/work/erpit","stage":"Main","step":"actions/checkout@v4","stepID":["0"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"executionTime":187301412,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"  ✅  Success - Main actions/checkout@v4 [187.301412ms]","stage":"Main","step":"actions/checkout@v4","stepID":["0"],"stepResult":"success","time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"⭐ Run Main run the structural pins","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"  🐳  docker exec cmd=[bash -e /var/run/act/workflow/1] user= workdir=","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"wired into bin/test.sh: 12\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"arg":"reports-queue-structural-test.sh ","command":"group","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::group::reports-queue-structural-test.sh \\n","raw":"::group::reports-queue-structural-test.sh \\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"reports-queue structural test: PASS\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"PASS reports-queue-structural-test.sh\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"arg":"","command":"endgroup","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::endgroup::\\n","raw":"::endgroup::\\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"arg":"role-catalog-structural-test.sh ","command":"group","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::group::role-catalog-structural-test.sh \\n","raw":"::group::role-catalog-structural-test.sh \\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"role-catalog structural test: PASS\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"PASS role-catalog-structural-test.sh\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"arg":"","command":"endgroup","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::endgroup::\\n","raw":"::endgroup::\\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"arg":"odoo-map-structural-test.sh ","command":"group","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::group::odoo-map-structural-test.sh \\n","raw":"::group::odoo-map-structural-test.sh \\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"odoo-map structural test: PASS\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"PASS odoo-map-structural-test.sh\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"arg":"","command":"endgroup","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::endgroup::\\n","raw":"::endgroup::\\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"arg":"decode-refusal-structural-test.sh ","command":"group","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::group::decode-refusal-structural-test.sh \\n","raw":"::group::decode-refusal-structural-test.sh \\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"decode-refusal structural test: PASS\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"PASS decode-refusal-structural-test.sh\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"arg":"","command":"endgroup","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::endgroup::\\n","raw":"::endgroup::\\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"arg":"human-units-structural-test.sh ","command":"group","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::group::human-units-structural-test.sh \\n","raw":"::group::human-units-structural-test.sh \\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"human-units structural test: PASS\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"PASS human-units-structural-test.sh\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"arg":"","command":"endgroup","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::endgroup::\\n","raw":"::endgroup::\\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"arg":"derive-structural-test.sh ","command":"group","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::group::derive-structural-test.sh \\n","raw":"::group::derive-structural-test.sh \\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"derive structural test: PASS\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"PASS derive-structural-test.sh\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"arg":"","command":"endgroup","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::endgroup::\\n","raw":"::endgroup::\\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"arg":"story-structural-test.sh ","command":"group","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::group::story-structural-test.sh \\n","raw":"::group::story-structural-test.sh \\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"story structural test: PASS\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"PASS story-structural-test.sh\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"arg":"","command":"endgroup","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::endgroup::\\n","raw":"::endgroup::\\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"arg":"skill-examples-structural-test.sh ","command":"group","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::group::skill-examples-structural-test.sh \\n","raw":"::group::skill-examples-structural-test.sh \\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:21-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"skill-examples structural test: PASS\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"PASS skill-examples-structural-test.sh\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"arg":"","command":"endgroup","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::endgroup::\\n","raw":"::endgroup::\\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"arg":"scry-care-structural-test.sh ","command":"group","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::group::scry-care-structural-test.sh \\n","raw":"::group::scry-care-structural-test.sh \\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"scry-care structural test: PASS\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"PASS scry-care-structural-test.sh\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"arg":"","command":"endgroup","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::endgroup::\\n","raw":"::endgroup::\\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"arg":"desk-sync-structural-test.sh ","command":"group","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::group::desk-sync-structural-test.sh \\n","raw":"::group::desk-sync-structural-test.sh \\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"desk-sync structural test: PASS\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"PASS desk-sync-structural-test.sh\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"arg":"","command":"endgroup","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::endgroup::\\n","raw":"::endgroup::\\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"arg":"verdict-roster-structural-test.sh ","command":"group","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::group::verdict-roster-structural-test.sh \\n","raw":"::group::verdict-roster-structural-test.sh \\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"verdict-roster structural test: PASS (366 refusals, both directions)\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"PASS verdict-roster-structural-test.sh\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"arg":"","command":"endgroup","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::endgroup::\\n","raw":"::endgroup::\\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"arg":"oneshot-fence-structural-test.sh ","command":"group","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::group::oneshot-fence-structural-test.sh \\n","raw":"::group::oneshot-fence-structural-test.sh \\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"oneshot-fence structural test: PASS\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"PASS oneshot-fence-structural-test.sh\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"arg":"","command":"endgroup","dryrun":false,"job":"suite/structural","jobID":"structural","kvPairs":{},"level":"info","matrix":{},"msg":"  ❓  ::endgroup::\\n","raw":"::endgroup::\\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"structural: PASS (12 wired scripts)\\n","raw_output":true,"stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"dryrun":false,"executionTime":359372775,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"  ✅  Success - Main run the structural pins [359.372775ms]","stage":"Main","step":"run the structural pins","stepID":["1"],"stepResult":"success","time":"2026-09-11T19:33:22-05:00"}'
      '{"command":"summary","content":"### structural pins\\n\\n| script | result | note |\\n| --- | --- | --- |\\n| `reports-queue-structural-test.sh` | PASS |  |\\n| `role-catalog-structural-test.sh` | PASS |  |\\n| `odoo-map-structural-test.sh` | PASS |  |\\n| `decode-refusal-structural-test.sh` | PASS |  |\\n| `human-units-structural-test.sh` | PASS |  |\\n| `derive-structural-test.sh` | PASS |  |\\n| `story-structural-test.sh` | PASS |  |\\n| `skill-examples-structural-test.sh` | PASS |  |\\n| `scry-care-structural-test.sh` | PASS |  |\\n| `desk-sync-structural-test.sh` | PASS |  |\\n| `verdict-roster-structural-test.sh` | PASS |  |\\n| `oneshot-fence-structural-test.sh` | PASS |  |\\n\\n12 wired into `bin/test.sh`, 0 present but unwired.\\n","dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"  ⚙  Summary - ### structural pins\\n\\n| script | result | note |\\n| --- | --- | --- |\\n| `reports-queue-structural-test.sh` | PASS |  |\\n| `role-catalog-structural-test.sh` | PASS |  |\\n| `odoo-map-structural-test.sh` | PASS |  |\\n| `decode-refusal-structural-test.sh` | PASS |  |\\n| `human-units-structural-test.sh` | PASS |  |\\n| `derive-structural-test.sh` | PASS |  |\\n| `story-structural-test.sh` | PASS |  |\\n| `skill-examples-structural-test.sh` | PASS |  |\\n| `scry-care-structural-test.sh` | PASS |  |\\n| `desk-sync-structural-test.sh` | PASS |  |\\n| `verdict-roster-structural-test.sh` | PASS |  |\\n| `oneshot-fence-structural-test.sh` | PASS |  |\\n\\n12 wired into `bin/test.sh`, 0 present but unwired.\\n","stage":"Main","step":"run the structural pins","stepID":["1"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"⭐ Run Complete job","step":"Complete job","stepid":["--complete-job"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"Cleaning up container for job structural","step":"Complete job","stepid":["--complete-job"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","level":"info","matrix":{},"msg":"  ✅  Success - Complete job","step":"Complete job","stepResult":"success","stepid":["--complete-job"],"time":"2026-09-11T19:33:22-05:00"}'
      '{"dryrun":false,"job":"suite/structural","jobID":"structural","jobResult":"success","level":"info","matrix":{},"msg":"🏁  Job succeeded","time":"2026-09-11T19:33:22-05:00"}'
  ==
=/  parse
  |=  line=@t
  ^-  (each event:ci refusal:ci-event)
  (parse:ci-event [(met 3 line) line])
=/  parsed=(list event:ci)
  %+  turn  spike
  |=  line=@t
  =/  result=(each event:ci refusal:ci-event)  (parse line)
  ?>  ?=(%& -.result)
  p.result
?>  =(68 (lent parsed))
::  every line names the job; the last carries the job result
::
?>  (levy parsed |=(=event:ci &(=('suite/structural' job.event) =('structural' job-id.event))))
=/  last=event:ci  (rear parsed)
?>  =(`%success job-result.last)
?>  =(~ step-result.last)
?>  =(~ command.last)
?>  =(~ stage.last)
?>  !raw.last
::  no other line carries a job result; a result is never inferred
::
?>  =(1 (lent (skim parsed |=(=event:ci ?=(^ job-result.event)))))
::  step results: three setup/checkout/run successes and the complete-job
::
?>  =(4 (lent (skim parsed |=(=event:ci =(`%success step-result.event)))))
::  the time parses to the UTC instant
::
?>  =(~2026.9.12..00.33.20 at:(snag 0 parsed))
?>  =(~2026.9.12..00.33.22 at.last)
::  stage and step ids come through; the setup step uses act's lower-case key
::
?>  =(~['--setup-job'] step-id:(snag 0 parsed))
?>  =(~['0'] step-id:(snag 7 parsed))
?>  =(`'Main' stage:(snag 7 parsed))
?>  =(`'actions/checkout@v4' step:(snag 7 parsed))
::  raw output lines are flagged; log lines are not
::
?>  raw:(snag 12 parsed)
?>  !raw:(snag 11 parsed)
?>  =('wired into bin/test.sh: 12\0a' msg:(snag 12 parsed))
::  group, endgroup and summary commands parse
::
?>  =(`[%group 'reports-queue-structural-test.sh '] command:(snag 13 parsed))
?>  =(`[%endgroup ~] command:(snag 16 parsed))
=/  summary=event:ci  (snag 63 parsed)
?>  ?=([~ %summary *] command.summary)
?>  =('### structural pins' (end [3 19] body.u.command.summary))
::  a set-output in the $GITHUB_OUTPUT shape act 0.2.89 emits lands in
::  the attempt's step outputs under its step (Delivery 1B)
::
=/  output-line=@t
  '{"arg":"true","command":"set-output","dryrun":false,"job":"fixture-pass/pass","jobID":"pass","level":"info","matrix":{},"msg":"  ⚙  ::set-output:: suite=true","name":"suite","stage":"Main","step":"emit suite output","stepID":["emit"],"time":"2026-09-12T17:03:50-05:00"}'
=/  output=(each event:ci refusal:ci-event)  (parse output-line)
?>  ?=(%& -.output)
?>  =(`[%set-output 'suite' 'true'] command.p.output)
=/  outputs=(list step-output:ci)  (need (record-output:ci-event ~ p.output %.n))
?>  =(~[[~['emit'] 'suite' 'true' %.n]] outputs)
::  the ::set-output:: workflow-command shape lands too
::
=/  kv-line=@t
  '{"arg":"true","command":"set-output","dryrun":false,"job":"suite/plan","jobID":"plan","kvPairs":{"name":"replay"},"level":"info","matrix":{},"msg":"  ⚙  ::set-output:: replay=true","raw":"::set-output name=replay::true\\n","stage":"Main","step":"plan","stepID":["1"],"time":"2026-09-11T19:33:20-05:00"}'
=/  kv=(each event:ci refusal:ci-event)  (parse kv-line)
?>  ?=(%& -.kv)
?>  =(`[%set-output 'replay' 'true'] command.p.kv)
=.  outputs  (need (record-output:ci-event outputs p.kv %.n))
?>  =(2 (lent outputs))
::  another step's output of the same name is its own entry; the same
::  step's later value replaces its own
::
=/  again=event:ci  p.output(step-id ~['other'])
=.  outputs  (need (record-output:ci-event outputs again %.n))
?>  =(3 (lent outputs))
=/  later=event:ci  p.output(command `[%set-output 'suite' 'false'])
=.  outputs  (need (record-output:ci-event outputs later %.n))
?>  =(3 (lent outputs))
?>  =(~['false'] (murn outputs |=(o=step-output:ci ?.(&(=(~['emit'] step.o) =('suite' name.o)) ~ `value.o))))
::  past 256 entries a set-output is not recorded (~)
::
=/  full=(list step-output:ci)
  (turn (gulf 1 256) |=(n=@ud `step-output:ci`[~[(scot %ud n)] 'x' 'y' %.n]))
?>  =(~ (record-output:ci-event full p.output %.n))
::  nothing but a set-output touches outputs: the spike log has none
::
=/  spike-outputs=(list step-output:ci)
  =/  items=(list event:ci)  parsed
  =|  acc=(list step-output:ci)
  |-
  ?~  items  acc
  $(items t.items, acc (need (record-output:ci-event acc i.items %.n)))
?>  =(~ spike-outputs)
::  a set-output without a name is refused
::
=/  nameless=@t
  '{"arg":"true","command":"set-output","job":"j","jobID":"j","time":"2026-09-11T19:33:20-05:00"}'
=/  nameless-result=(each event:ci refusal:ci-event)  (parse nameless)
?>  ?=(%| -.nameless-result)
?>  =(400 status.p.nameless-result)
::  a 65 KiB line is refused with 413 before it is parsed
::
=/  big=@t
  %+  rap
    3
  ~['{"job":"j","jobID":"j","time":"2026-09-11T19:33:20-05:00","msg":"' (fil 3 66.560 'a') '"}']
?>  (gth (met 3 big) 65.536)
=/  big-result=(each event:ci refusal:ci-event)  (parse big)
?>  ?=(%| -.big-result)
?>  =(413 status.p.big-result)
::  a line just under the bound parses, with its message cut to 4 KiB
::
=/  under=@t
  %+  rap
    3
  ~['{"job":"j","jobID":"j","time":"2026-09-11T19:33:20-05:00","msg":"' (fil 3 65.000 'a') '"}']
?>  (lte (met 3 under) 65.536)
=/  under-result=(each event:ci refusal:ci-event)  (parse under)
?>  ?=(%& -.under-result)
?>  =(4.096 (met 3 msg.p.under-result))
::  a line without time, job or jobID is refused with 400
::
=/  no-time=(each event:ci refusal:ci-event)
  (parse '{"job":"j","jobID":"j","msg":"x"}')
?>  ?=(%| -.no-time)
?>  =(400 status.p.no-time)
=/  no-job=(each event:ci refusal:ci-event)
  (parse '{"jobID":"j","time":"2026-09-11T19:33:20-05:00"}')
?>  ?=(%| -.no-job)
?>  =(400 status.p.no-job)
=/  no-job-id=(each event:ci refusal:ci-event)
  (parse '{"job":"j","time":"2026-09-11T19:33:20-05:00"}')
?>  ?=(%| -.no-job-id)
?>  =(400 status.p.no-job-id)
::  a time that is not RFC 3339 is refused
::
=/  bad-time=(each event:ci refusal:ci-event)
  (parse '{"job":"j","jobID":"j","time":"yesterday"}')
?>  ?=(%| -.bad-time)
?>  =(400 status.p.bad-time)
::  an unknown result word is refused, never defaulted
::
=/  bad-result=(each event:ci refusal:ci-event)
  (parse '{"job":"j","jobID":"j","time":"2026-09-11T19:33:20-05:00","jobResult":"green"}')
?>  ?=(%| -.bad-result)
?>  =(400 status.p.bad-result)
::  an unknown top-level key is ignored
::
=/  extra=(each event:ci refusal:ci-event)
  %-  parse
  '{"job":"j","jobID":"j","time":"2026-09-11T19:33:20Z","surprise":{"deep":[1,2]},"msg":"ok"}'
?>  ?=(%& -.extra)
?>  =('ok' msg.p.extra)
?>  =(~2026.9.11..19.33.20 at.p.extra)
::  an unknown command is carried as %other
::
=/  other=(each event:ci refusal:ci-event)
  %-  parse
  '{"job":"j","jobID":"j","time":"2026-09-11T19:33:20+02:00","command":"add-mask","arg":"x"}'
?>  ?=(%& -.other)
?>  =(`[%other 'add-mask'] command.p.other)
?>  =(~2026.9.11..17.33.20 at.p.other)
::  not JSON, not an object
::
=/  not-json=(each event:ci refusal:ci-event)  (parse 'not json')
?>  ?=(%| -.not-json)
?>  =(400 status.p.not-json)
=/  not-object=(each event:ci refusal:ci-event)  (parse '[1,2,3]')
?>  ?=(%| -.not-object)
?>  =(400 status.p.not-object)
::  the bounds are the ones the contract names
::
?>  =(65.536 max-line:ci-event)
?>  =(4.096 max-msg:ci-event)
?>  =(50.000 max-events:ci-event)
::  the credential scrub (D4): every occurrence of every released value
::  in the message, a set-output value and a summary body becomes ***;
::  nothing else changes, and no value means no change
::
?>  =('token is ***, again ***' (replace-all:ci-event 'token is s3cr3t, again s3cr3t' 's3cr3t'))
?>  =('untouched' (replace-all:ci-event 'untouched' 's3cr3t'))
?>  =('untouched' (replace-all:ci-event 'untouched' ''))
?>  =('*** and ***' (scrub-text:ci-event 'one and two' ~['one' 'two']))
=/  leaky=(each event:ci refusal:ci-event)
  %-  parse
  '{"job":"w/j","jobID":"j","time":"2026-09-16T12:00:00Z","msg":"leak=s3cr3t","command":"set-output","name":"leak","arg":"s3cr3t"}'
?>  ?=(%& -.leaky)
=/  scrubbed=event:ci  (scrub:ci-event p.leaky ~['s3cr3t'])
?>  =('leak=***' msg.scrubbed)
?>  =(`[%set-output 'leak' '***'] command.scrubbed)
?>  =(p.leaky (scrub:ci-event p.leaky ~))
?>  =(`~[[~ 'leak' '***' %.y]] (record-output:ci-event ~ scrubbed %.y))
%.y
