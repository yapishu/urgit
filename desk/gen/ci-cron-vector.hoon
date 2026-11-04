::  ci-cron-vector: schedules on the ship (Delivery 1C).  The catalog
::  and the occurrence table embedded below are the pinned compiler's own
::  output, which runner/internal/plan vector_pin_test.go pins byte for
::  byte: testdata/schedules/schedules.yml compiled by CatalogOf, with the
::  zone tables of America/New_York, Asia/Kolkata, Australia/Lord_Howe and
::  Europe/London from the pinned Go 1.27.1 zoneinfo.zip; and every
::  accepted entry's next four occurrences from nine instants (DST weeks,
::  a leap February, the horizon's last days) as the compiler computes
::  them, itself checked against a minute-by-minute oracle and Go's own
::  zone engine.  Checked here:
::    - the catalog: seventeen entries, two refused by the compiler with
::      their reasons kept, four zone tables;
::    - the occurrence table, row by row: the same instants, and a refusal
::      where the compiler refused;
::    - by hand: a skipped local time runs at the transition, several
::      skipped times are one run, a repeated time runs once at its first
::      instance (New York, London, Lord Howe's half hour), a zone without
::      daylight saving, both day rules, the leap day, the horizon refusing
::      at either end, the five-minute rule with the midnight wrap, a day
::      that never comes, malformed fields;
::    - a due wake: on time, late with the missed interval, early, and
::      ignored for a duplicate, a replaced definition, another armed
::      occurrence, a retired or refused schedule;
::    - display: ISO UTC and the zone's wall clock with its offset.
::  Every case names the verdict it expects; prints `passed=N of=M` and
::  ends in a loobean.
::
/-  ci
/+  ci-cron, ci-trigger
:-  %say
|=  *
:-  %noun
=/  schedules-1=@t
  %+  rap  3
  :~  '{"version":1,"workflows":[{"workflow":"schedules.yml","name":"Schedules"'
      ',"events":[{"event":"schedule","refusal":"","branches":null,"tags":null,'
      '"paths":null,"types":null,"typesDeclared":false,"schedules":[{"cron":"30'
      ' 2 * * *","timezone":"America/New_York","refusal":"","minutes":[30],"hou'
      'rs":[2],"days":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22'
      ',23,24,25,26,27,28,29,30,31],"months":[1,2,3,4,5,6,7,8,9,10,11,12],"week'
      'days":[0,1,2,3,4,5,6],"dayStar":true,"weekdayStar":true},{"cron":"*/15 2'
      ' * * *","timezone":"America/New_York","refusal":"","minutes":[0,15,30,45'
      '],"hours":[2],"days":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20'
      ',21,22,23,24,25,26,27,28,29,30,31],"months":[1,2,3,4,5,6,7,8,9,10,11,12]'
      ',"weekdays":[0,1,2,3,4,5,6],"dayStar":true,"weekdayStar":true},{"cron":"'
      '0,30 2,3 * * *","timezone":"America/New_York","refusal":"","minutes":[0,'
      '30],"hours":[2,3],"days":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,1'
      '9,20,21,22,23,24,25,26,27,28,29,30,31],"months":[1,2,3,4,5,6,7,8,9,10,11'
      ',12],"weekdays":[0,1,2,3,4,5,6],"dayStar":true,"weekdayStar":true},{"cro'
      'n":"0 3 * * *","timezone":"America/New_York","refusal":"","minutes":[0],'
      '"hours":[3],"days":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,2'
      '1,22,23,24,25,26,27,28,29,30,31],"months":[1,2,3,4,5,6,7,8,9,10,11,12],"'
      'weekdays":[0,1,2,3,4,5,6],"dayStar":true,"weekdayStar":true},{"cron":"30'
      ' 1 * * *","timezone":"America/New_York","refusal":"","minutes":[30],"hou'
      'rs":[1],"days":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22'
      ',23,24,25,26,27,28,29,30,31],"months":[1,2,3,4,5,6,7,8,9,10,11,12],"week'
      'days":[0,1,2,3,4,5,6],"dayStar":true,"weekdayStar":true},{"cron":"0 2 * '
      '* *","timezone":"America/New_York","refusal":"","minutes":[0],"hours":[2'
      '],"days":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24'
      ',25,26,27,28,29,30,31],"months":[1,2,3,4,5,6,7,8,9,10,11,12],"weekdays":'
      '[0,1,2,3,4,5,6],"dayStar":true,"weekdayStar":true},{"cron":"30 5 * * 1-5'
      '","timezone":"America/New_York","refusal":"","minutes":[30],"hours":[5],'
      '"days":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,2'
      '5,26,27,28,29,30,31],"months":[1,2,3,4,5,6,7,8,9,10,11,12],"weekdays":[1'
      ',2,3,4,5],"dayStar":true,"weekdayStar":false},{"cron":"30 5 * * *","time'
      'zone":"Asia/Kolkata","refusal":"","minutes":[30],"hours":[5],"days":[1,2'
      ',3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,'
      '29,30,31],"months":[1,2,3,4,5,6,7,8,9,10,11,12],"weekdays":[0,1,2,3,4,5,'
      '6],"dayStar":true,"weekdayStar":true},{"cron":"15 2 * * *","timezone":"A'
      'ustralia/Lord_Howe","refusal":"","minutes":[15],"hours":[2],"days":[1,2,'
      '3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,2'
      '9,30,31],"months":[1,2,3,4,5,6,7,8,9,10,11,12],"weekdays":[0,1,2,3,4,5,6'
      '],"dayStar":true,"weekdayStar":true},{"cron":"45 1 * * *","timezone":"Au'
      'stralia/Lord_Howe","refusal":"","minutes":[45],"hours":[1],"days":[1,2,3'
      ',4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29'
      ',30,31],"months":[1,2,3,4,5,6,7,8,9,10,11,12],"weekdays":[0,1,2,3,4,5,6]'
      ',"dayStar":true,"weekdayStar":true},{"cron":"15 1 * * *","timezone":"Eur'
      'ope/London","refusal":"","minutes":[15],"hours":[1],"days":[1,2,3,4,5,6,'
      '7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31]'
      ',"months":[1,2,3,4,5,6,7,8,9,10,11,12],"weekdays":[0,1,2,3,4,5,6],"daySt'
      'ar":true,"weekdayStar":true},{"cron":"0 0 29 2 *","timezone":"","refusal'
      '":"","minutes":[0],"hours":[0],"days":[29],"months":[2],"weekdays":[0,1,'
  ==
=/  schedules-2=@t
  %+  rap  3
  :~  '2,3,4,5,6],"dayStar":false,"weekdayStar":true},{"cron":"0 0 13 * 5","tim'
      'ezone":"","refusal":"","minutes":[0],"hours":[0],"days":[13],"months":[1'
      ',2,3,4,5,6,7,8,9,10,11,12],"weekdays":[5],"dayStar":false,"weekdayStar":'
      'false},{"cron":"0 12 */2 * 1","timezone":"","refusal":"","minutes":[0],"'
      'hours":[12],"days":[1,3,5,7,9,11,13,15,17,19,21,23,25,27,29,31],"months"'
      ':[1,2,3,4,5,6,7,8,9,10,11,12],"weekdays":[1],"dayStar":true,"weekdayStar'
      '":false},{"cron":"0 0 * * *","timezone":"America/New_York","refusal":"",'
      '"minutes":[0],"hours":[0],"days":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16'
      ',17,18,19,20,21,22,23,24,25,26,27,28,29,30,31],"months":[1,2,3,4,5,6,7,8'
      ',9,10,11,12],"weekdays":[0,1,2,3,4,5,6],"dayStar":true,"weekdayStar":tru'
      'e},{"cron":"*/4 * * * *","timezone":"","refusal":"the schedule runs 4 mi'
      'nute(s) apart; GitHub Actions runs scheduled workflows at most once ever'
      'y five minutes, and this one is refused rather than clamped","minutes":n'
      'ull,"hours":null,"days":null,"months":null,"weekdays":null,"dayStar":fal'
      'se,"weekdayStar":false},{"cron":"0 3 * * *","timezone":"Mars/Olympus","r'
      'efusal":"timezone \\"Mars/Olympus\\" is not in the pinned timezone databas'
      'e (Go 1.27.1 zoneinfo)","minutes":null,"hours":null,"days":null,"months"'
      ':null,"weekdays":null,"dayStar":false,"weekdayStar":false}],"line":8,"co'
      'l":3}],"refusal":"","concurrency":{"v":2,"kind":"none"}}],"zones":{"Amer'
      'ica/New_York":{"start":1577836800,"end":2208988800,"offset":-18000,"tran'
      'sitions":[[1583650800,-14400],[1604210400,-18000],[1615705200,-14400],[1'
      '636264800,-18000],[1647154800,-14400],[1667714400,-18000],[1678604400,-1'
      '4400],[1699164000,-18000],[1710054000,-14400],[1730613600,-18000],[17415'
      '03600,-14400],[1762063200,-18000],[1772953200,-14400],[1793512800,-18000'
      '],[1805007600,-14400],[1825567200,-18000],[1836457200,-14400],[185701680'
      '0,-18000],[1867906800,-14400],[1888466400,-18000],[1899356400,-14400],[1'
      '919916000,-18000],[1930806000,-14400],[1951365600,-18000],[1962860400,-1'
      '4400],[1983420000,-18000],[1994310000,-14400],[2014869600,-18000],[20257'
      '59600,-14400],[2046319200,-18000],[2057209200,-14400],[2077768800,-18000'
      '],[2088658800,-14400],[2109218400,-18000],[2120108400,-14400],[214066800'
      '0,-18000],[2152162800,-14400],[2172722400,-18000],[2183612400,-14400],[2'
      '204172000,-18000]]},"Asia/Kolkata":{"start":1577836800,"end":2208988800,'
      '"offset":19800,"transitions":[]},"Australia/Lord_Howe":{"start":15778368'
      '00,"end":2208988800,"offset":39600,"transitions":[[1586012400,37800],[16'
      '01739000,39600],[1617462000,37800],[1633188600,39600],[1648911600,37800]'
      ',[1664638200,39600],[1680361200,37800],[1696087800,39600],[1712415600,37'
      '800],[1728142200,39600],[1743865200,37800],[1759591800,39600],[177531480'
      '0,37800],[1791041400,39600],[1806764400,37800],[1822491000,39600],[18382'
      '14000,37800],[1853940600,39600],[1869663600,37800],[1885995000,39600],[1'
      '901718000,37800],[1917444600,39600],[1933167600,37800],[1948894200,39600'
      '],[1964617200,37800],[1980343800,39600],[1996066800,37800],[2011793400,3'
      '9600],[2027516400,37800],[2043243000,39600],[2058966000,37800],[20752974'
      '00,39600],[2091020400,37800],[2106747000,39600],[2122470000,37800],[2138'
      '196600,39600],[2153919600,37800],[2169646200,39600],[2185369200,37800],['
      '2201095800,39600]]},"Europe/London":{"start":1577836800,"end":2208988800'
      ',"offset":0,"transitions":[[1585443600,3600],[1603587600,0],[1616893200,'
      '3600],[1635642000,0],[1648342800,3600],[1667091600,0],[1679792400,3600],'
      '[1698541200,0],[1711846800,3600],[1729990800,0],[1743296400,3600],[17614'
  ==
=/  schedules-3=@t
  %+  rap  3
  :~  '40400,0],[1774746000,3600],[1792890000,0],[1806195600,3600],[1824944400,'
      '0],[1837645200,3600],[1856394000,0],[1869094800,3600],[1887843600,0],[19'
      '01149200,3600],[1919293200,0],[1932598800,3600],[1950742800,0],[19640484'
      '00,3600],[1982797200,0],[1995498000,3600],[2014246800,0],[2026947600,360'
      '0],[2045696400,0],[2058397200,3600],[2077146000,0],[2090451600,3600],[21'
      '08595600,0],[2121901200,3600],[2140045200,0],[2153350800,3600],[21720996'
      '00,0],[2184800400,3600],[2203549200,0]]}}}'
  ==
=/  schedules=@t
  %+  rap  3
  :~  schedules-1
      schedules-2
      schedules-3
  ==
=/  occurrences-1=@t
  %+  rap  3
  :~  '[{"entry":0,"after":1792108800,"next":[1792132200,1792218600,1792305000,'
      '1792391400],"refusal":""},{"entry":0,"after":1804939200,"next":[18050076'
      '00,1805092200,1805178600,1805265000],"refusal":""},{"entry":0,"after":18'
      '25502400,"next":[1825572600,1825659000,1825745400,1825831800],"refusal":'
      '""},{"entry":0,"after":1806148800,"next":[1806215400,1806301800,18063882'
      '00,1806474600],"refusal":""},{"entry":0,"after":1824897600,"next":[18249'
      '64200,1825050600,1825137000,1825223400],"refusal":""},{"entry":0,"after"'
      ':1806710400,"next":[1806733800,1806820200,1806906600,1806993000],"refusa'
      'l":""},{"entry":0,"after":1822435200,"next":[1822458600,1822545000,18226'
      '31400,1822717800],"refusal":""},{"entry":0,"after":1835222400,"next":[18'
      '35249400,1835335800,1835422200,1835508600],"refusal":""},{"entry":0,"aft'
      'er":2208729600,"next":[2208756600,2208843000,2208929400],"refusal":"the '
      'next occurrence is beyond the timezone horizon 2040-01-01T00:00:00Z of t'
      'he pinned table: resolve the workflow again with a newer compiler"},{"en'
      'try":1,"after":1792108800,"next":[1792130400,1792131300,1792132200,17921'
      '33100],"refusal":""},{"entry":1,"after":1804939200,"next":[1805007600,18'
      '05090400,1805091300,1805092200],"refusal":""},{"entry":1,"after":1825502'
      '400,"next":[1825570800,1825571700,1825572600,1825573500],"refusal":""},{'
      '"entry":1,"after":1806148800,"next":[1806213600,1806214500,1806215400,18'
      '06216300],"refusal":""},{"entry":1,"after":1824897600,"next":[1824962400'
      ',1824963300,1824964200,1824965100],"refusal":""},{"entry":1,"after":1806'
      '710400,"next":[1806732000,1806732900,1806733800,1806734700],"refusal":""'
      '},{"entry":1,"after":1822435200,"next":[1822456800,1822457700,1822458600'
      ',1822459500],"refusal":""},{"entry":1,"after":1835222400,"next":[1835247'
      '600,1835248500,1835249400,1835250300],"refusal":""},{"entry":1,"after":2'
      '208729600,"next":[2208754800,2208755700,2208756600,2208757500],"refusal"'
      ':""},{"entry":2,"after":1792108800,"next":[1792130400,1792132200,1792134'
      '000,1792135800],"refusal":""},{"entry":2,"after":1804939200,"next":[1805'
      '007600,1805009400,1805090400,1805092200],"refusal":""},{"entry":2,"after'
      '":1825502400,"next":[1825570800,1825572600,1825574400,1825576200],"refus'
      'al":""},{"entry":2,"after":1806148800,"next":[1806213600,1806215400,1806'
      '217200,1806219000],"refusal":""},{"entry":2,"after":1824897600,"next":[1'
      '824962400,1824964200,1824966000,1824967800],"refusal":""},{"entry":2,"af'
      'ter":1806710400,"next":[1806732000,1806733800,1806735600,1806737400],"re'
      'fusal":""},{"entry":2,"after":1822435200,"next":[1822456800,1822458600,1'
      '822460400,1822462200],"refusal":""},{"entry":2,"after":1835222400,"next"'
      ':[1835247600,1835249400,1835251200,1835253000],"refusal":""},{"entry":2,'
      '"after":2208729600,"next":[2208754800,2208756600,2208758400,2208760200],'
      '"refusal":""},{"entry":3,"after":1792108800,"next":[1792134000,179222040'
      '0,1792306800,1792393200],"refusal":""},{"entry":3,"after":1804939200,"ne'
      'xt":[1805007600,1805094000,1805180400,1805266800],"refusal":""},{"entry"'
      ':3,"after":1825502400,"next":[1825574400,1825660800,1825747200,182583360'
      '0],"refusal":""},{"entry":3,"after":1806148800,"next":[1806217200,180630'
      '3600,1806390000,1806476400],"refusal":""},{"entry":3,"after":1824897600,'
      '"next":[1824966000,1825052400,1825138800,1825225200],"refusal":""},{"ent'
      'ry":3,"after":1806710400,"next":[1806735600,1806822000,1806908400,180699'
      '4800],"refusal":""},{"entry":3,"after":1822435200,"next":[1822460400,182'
      '2546800,1822633200,1822719600],"refusal":""},{"entry":3,"after":18352224'
  ==
=/  occurrences-2=@t
  %+  rap  3
  :~  '00,"next":[1835251200,1835337600,1835424000,1835510400],"refusal":""},{"'
      'entry":3,"after":2208729600,"next":[2208758400,2208844800,2208931200],"r'
      'efusal":"the next occurrence is beyond the timezone horizon 2040-01-01T0'
      '0:00:00Z of the pinned table: resolve the workflow again with a newer co'
      'mpiler"},{"entry":4,"after":1792108800,"next":[1792128600,1792215000,179'
      '2301400,1792387800],"refusal":""},{"entry":4,"after":1804939200,"next":['
      '1805005800,1805088600,1805175000,1805261400],"refusal":""},{"entry":4,"a'
      'fter":1825502400,"next":[1825565400,1825655400,1825741800,1825828200],"r'
      'efusal":""},{"entry":4,"after":1806148800,"next":[1806211800,1806298200,'
      '1806384600,1806471000],"refusal":""},{"entry":4,"after":1824897600,"next'
      '":[1824960600,1825047000,1825133400,1825219800],"refusal":""},{"entry":4'
      ',"after":1806710400,"next":[1806730200,1806816600,1806903000,1806989400]'
      ',"refusal":""},{"entry":4,"after":1822435200,"next":[1822455000,18225414'
      '00,1822627800,1822714200],"refusal":""},{"entry":4,"after":1835222400,"n'
      'ext":[1835245800,1835332200,1835418600,1835505000],"refusal":""},{"entry'
      '":4,"after":2208729600,"next":[2208753000,2208839400,2208925800],"refusa'
      'l":"the next occurrence is beyond the timezone horizon 2040-01-01T00:00:'
      '00Z of the pinned table: resolve the workflow again with a newer compile'
      'r"},{"entry":5,"after":1792108800,"next":[1792130400,1792216800,17923032'
      '00,1792389600],"refusal":""},{"entry":5,"after":1804939200,"next":[18050'
      '07600,1805090400,1805176800,1805263200],"refusal":""},{"entry":5,"after"'
      ':1825502400,"next":[1825570800,1825657200,1825743600,1825830000],"refusa'
      'l":""},{"entry":5,"after":1806148800,"next":[1806213600,1806300000,18063'
      '86400,1806472800],"refusal":""},{"entry":5,"after":1824897600,"next":[18'
      '24962400,1825048800,1825135200,1825221600],"refusal":""},{"entry":5,"aft'
      'er":1806710400,"next":[1806732000,1806818400,1806904800,1806991200],"ref'
      'usal":""},{"entry":5,"after":1822435200,"next":[1822456800,1822543200,18'
      '22629600,1822716000],"refusal":""},{"entry":5,"after":1835222400,"next":'
      '[1835247600,1835334000,1835420400,1835506800],"refusal":""},{"entry":5,"'
      'after":2208729600,"next":[2208754800,2208841200,2208927600],"refusal":"t'
      'he next occurrence is beyond the timezone horizon 2040-01-01T00:00:00Z o'
      'f the pinned table: resolve the workflow again with a newer compiler"},{'
      '"entry":6,"after":1792108800,"next":[1792143000,1792402200,1792488600,17'
      '92575000],"refusal":""},{"entry":6,"after":1804939200,"next":[1805103000'
      ',1805189400,1805275800,1805362200],"refusal":""},{"entry":6,"after":1825'
      '502400,"next":[1825669800,1825756200,1825842600,1825929000],"refusal":""'
      '},{"entry":6,"after":1806148800,"next":[1806312600,1806399000,1806485400'
      ',1806571800],"refusal":""},{"entry":6,"after":1824897600,"next":[1825061'
      '400,1825147800,1825234200,1825320600],"refusal":""},{"entry":6,"after":1'
      '806710400,"next":[1806917400,1807003800,1807090200,1807176600],"refusal"'
      ':""},{"entry":6,"after":1822435200,"next":[1822642200,1822728600,1822815'
      '000,1822901400],"refusal":""},{"entry":6,"after":1835222400,"next":[1835'
      '346600,1835433000,1835519400,1835605800],"refusal":""},{"entry":6,"after'
      '":2208729600,"next":[2208767400,2208853800],"refusal":"the next occurren'
      'ce is beyond the timezone horizon 2040-01-01T00:00:00Z of the pinned tab'
      'le: resolve the workflow again with a newer compiler"},{"entry":7,"after'
      '":1792108800,"next":[1792195200,1792281600,1792368000,1792454400],"refus'
      'al":""},{"entry":7,"after":1804939200,"next":[1804982400,1805068800,1805'
  ==
=/  occurrences-3=@t
  %+  rap  3
  :~  '155200,1805241600],"refusal":""},{"entry":7,"after":1825502400,"next":[1'
      '825545600,1825632000,1825718400,1825804800],"refusal":""},{"entry":7,"af'
      'ter":1806148800,"next":[1806192000,1806278400,1806364800,1806451200],"re'
      'fusal":""},{"entry":7,"after":1824897600,"next":[1824940800,1825027200,1'
      '825113600,1825200000],"refusal":""},{"entry":7,"after":1806710400,"next"'
      ':[1806796800,1806883200,1806969600,1807056000],"refusal":""},{"entry":7,'
      '"after":1822435200,"next":[1822521600,1822608000,1822694400,1822780800],'
      '"refusal":""},{"entry":7,"after":1835222400,"next":[1835308800,183539520'
      '0,1835481600,1835568000],"refusal":""},{"entry":7,"after":2208729600,"ne'
      'xt":[2208816000,2208902400],"refusal":"the next occurrence is beyond the'
      ' timezone horizon 2040-01-01T00:00:00Z of the pinned table: resolve the '
      'workflow again with a newer compiler"},{"entry":8,"after":1792108800,"ne'
      'xt":[1792163700,1792250100,1792336500,1792422900],"refusal":""},{"entry"'
      ':8,"after":1804939200,"next":[1804950900,1805037300,1805123700,180521010'
      '0],"refusal":""},{"entry":8,"after":1825502400,"next":[1825514100,182560'
      '0500,1825686900,1825773300],"refusal":""},{"entry":8,"after":1806148800,'
      '"next":[1806160500,1806246900,1806333300,1806419700],"refusal":""},{"ent'
      'ry":8,"after":1824897600,"next":[1824909300,1824995700,1825082100,182516'
      '8500],"refusal":""},{"entry":8,"after":1806710400,"next":[1806767100,180'
      '6853500,1806939900,1807026300],"refusal":""},{"entry":8,"after":18224352'
      '00,"next":[1822491000,1822576500,1822662900,1822749300],"refusal":""},{"'
      'entry":8,"after":1835222400,"next":[1835277300,1835363700,1835450100,183'
      '5536500],"refusal":""},{"entry":8,"after":2208729600,"next":[2208784500,'
      '2208870900,2208957300],"refusal":"the next occurrence is beyond the time'
      'zone horizon 2040-01-01T00:00:00Z of the pinned table: resolve the workf'
      'low again with a newer compiler"},{"entry":9,"after":1792108800,"next":['
      '1792161900,1792248300,1792334700,1792421100],"refusal":""},{"entry":9,"a'
      'fter":1804939200,"next":[1804949100,1805035500,1805121900,1805208300],"r'
      'efusal":""},{"entry":9,"after":1825502400,"next":[1825512300,1825598700,'
      '1825685100,1825771500],"refusal":""},{"entry":9,"after":1806148800,"next'
      '":[1806158700,1806245100,1806331500,1806417900],"refusal":""},{"entry":9'
      ',"after":1824897600,"next":[1824907500,1824993900,1825080300,1825166700]'
      ',"refusal":""},{"entry":9,"after":1806710400,"next":[1806763500,18068517'
      '00,1806938100,1807024500],"refusal":""},{"entry":9,"after":1822435200,"n'
      'ext":[1822490100,1822574700,1822661100,1822747500],"refusal":""},{"entry'
      '":9,"after":1835222400,"next":[1835275500,1835361900,1835448300,18355347'
      '00],"refusal":""},{"entry":9,"after":2208729600,"next":[2208782700,22088'
      '69100,2208955500],"refusal":"the next occurrence is beyond the timezone '
      'horizon 2040-01-01T00:00:00Z of the pinned table: resolve the workflow a'
      'gain with a newer compiler"},{"entry":10,"after":1792108800,"next":[1792'
      '109700,1792196100,1792282500,1792368900],"refusal":""},{"entry":10,"afte'
      'r":1804939200,"next":[1804986900,1805073300,1805159700,1805246100],"refu'
      'sal":""},{"entry":10,"after":1825502400,"next":[1825550100,1825636500,18'
      '25722900,1825809300],"refusal":""},{"entry":10,"after":1806148800,"next"'
      ':[1806195600,1806279300,1806365700,1806452100],"refusal":""},{"entry":10'
      ',"after":1824897600,"next":[1824941700,1825031700,1825118100,1825204500]'
      ',"refusal":""},{"entry":10,"after":1806710400,"next":[1806711300,1806797'
      '700,1806884100,1806970500],"refusal":""},{"entry":10,"after":1822435200,'
  ==
=/  occurrences-4=@t
  %+  rap  3
  :~  '"next":[1822436100,1822522500,1822608900,1822695300],"refusal":""},{"ent'
      'ry":10,"after":1835222400,"next":[1835226900,1835313300,1835399700,18354'
      '86100],"refusal":""},{"entry":10,"after":2208729600,"next":[2208734100,2'
      '208820500,2208906900],"refusal":"the next occurrence is beyond the timez'
      'one horizon 2040-01-01T00:00:00Z of the pinned table: resolve the workfl'
      'ow again with a newer compiler"},{"entry":11,"after":1792108800,"next":['
      '1835395200,1961625600,2087856000,2214086400],"refusal":""},{"entry":11,"'
      'after":1804939200,"next":[1835395200,1961625600,2087856000,2214086400],"'
      'refusal":""},{"entry":11,"after":1825502400,"next":[1835395200,196162560'
      '0,2087856000,2214086400],"refusal":""},{"entry":11,"after":1806148800,"n'
      'ext":[1835395200,1961625600,2087856000,2214086400],"refusal":""},{"entry'
      '":11,"after":1824897600,"next":[1835395200,1961625600,2087856000,2214086'
      '400],"refusal":""},{"entry":11,"after":1806710400,"next":[1835395200,196'
      '1625600,2087856000,2214086400],"refusal":""},{"entry":11,"after":1822435'
      '200,"next":[1835395200,1961625600,2087856000,2214086400],"refusal":""},{'
      '"entry":11,"after":1835222400,"next":[1835395200,1961625600,2087856000,2'
      '214086400],"refusal":""},{"entry":11,"after":2208729600,"next":[22140864'
      '00,2340316800,2466547200,2592777600],"refusal":""},{"entry":12,"after":1'
      '792108800,"next":[1792713600,1793318400,1793923200,1794528000],"refusal"'
      ':""},{"entry":12,"after":1804939200,"next":[1805414400,1806019200,180662'
      '4000,1807228800],"refusal":""},{"entry":12,"after":1825502400,"next":[18'
      '25977600,1826064000,1826582400,1827187200],"refusal":""},{"entry":12,"af'
      'ter":1806148800,"next":[1806624000,1807228800,1807574400,1807833600],"re'
      'fusal":""},{"entry":12,"after":1824897600,"next":[1825372800,1825977600,'
      '1826064000,1826582400],"refusal":""},{"entry":12,"after":1806710400,"nex'
      't":[1807228800,1807574400,1807833600,1808438400],"refusal":""},{"entry":'
      '12,"after":1822435200,"next":[1822953600,1823385600,1823558400,182416320'
      '0],"refusal":""},{"entry":12,"after":1835222400,"next":[1835654400,18362'
      '59200,1836518400,1836864000],"refusal":""},{"entry":12,"after":220872960'
      '0,"next":[2208816000,2209420800,2210025600,2210630400],"refusal":""},{"e'
      'ntry":13,"after":1792108800,"next":[1792411200,1794225600,1795435200,179'
      '6644800],"refusal":""},{"entry":13,"after":1804939200,"next":[1805112000'
      ',1806321600,1806926400,1808136000],"refusal":""},{"entry":13,"after":182'
      '5502400,"next":[1826280000,1827489600,1828699200,1829908800],"refusal":"'
      '"},{"entry":13,"after":1806148800,"next":[1806321600,1806926400,18081360'
      '00,1809345600],"refusal":""},{"entry":13,"after":1824897600,"next":[1825'
      '070400,1826280000,1827489600,1828699200],"refusal":""},{"entry":13,"afte'
      'r":1806710400,"next":[1806926400,1808136000,1809345600,1810555200],"refu'
      'sal":""},{"entry":13,"after":1822435200,"next":[1823256000,1824465600,18'
      '25070400,1826280000],"refusal":""},{"entry":13,"after":1835222400,"next"'
      ':[1836561600,1837771200,1838376000,1839585600],"refusal":""},{"entry":13'
      ',"after":2208729600,"next":[2209723200,2210932800,2212747200,2213956800]'
      ',"refusal":""},{"entry":14,"after":1792108800,"next":[1792123200,1792209'
      '600,1792296000,1792382400],"refusal":""},{"entry":14,"after":1804939200,'
      '"next":[1805000400,1805083200,1805169600,1805256000],"refusal":""},{"ent'
      'ry":14,"after":1825502400,"next":[1825560000,1825650000,1825736400,18258'
      '22800],"refusal":""},{"entry":14,"after":1806148800,"next":[1806206400,1'
      '806292800,1806379200,1806465600],"refusal":""},{"entry":14,"after":18248'
  ==
=/  occurrences-5=@t
  %+  rap  3
  :~  '97600,"next":[1824955200,1825041600,1825128000,1825214400],"refusal":""}'
      ',{"entry":14,"after":1806710400,"next":[1806724800,1806811200,1806897600'
      ',1806984000],"refusal":""},{"entry":14,"after":1822435200,"next":[182244'
      '9600,1822536000,1822622400,1822708800],"refusal":""},{"entry":14,"after"'
      ':1835222400,"next":[1835240400,1835326800,1835413200,1835499600],"refusa'
      'l":""},{"entry":14,"after":2208729600,"next":[2208747600,2208834000,2208'
      '920400],"refusal":"the next occurrence is beyond the timezone horizon 20'
      '40-01-01T00:00:00Z of the pinned table: resolve the workflow again with '
      'a newer compiler"}]'
  ==
=/  occurrences=@t
  %+  rap  3
  :~  occurrences-1
      occurrences-2
      occurrences-3
      occurrences-4
      occurrences-5
  ==
=/  has-text
  |=  [text=@t part=@t]
  ^-  ?
  ?=(^ (find (trip part) (trip text)))
=/  parsed=(each (unit trigger-catalog:ci) @t)
  (parse-catalog:ci-trigger (de:json:html schedules))
=/  cat=trigger-catalog:ci
  ?:  ?=(%| -.parsed)  [~ ~]
  (fall p.parsed [~ ~])
=/  entries=(list schedule-def:ci)
  ?.  ?=([* ~] workflows.cat)  ~
  =/  e=(unit trigger-event:ci)  (event-of:ci-trigger i.workflows.cat 'schedule')
  ?~(e ~ schedules.u.e)
=/  zone-of
  |=  name=@t
  ^-  (unit zone:ci)
  (~(get by zones.cat) name)
=/  ny=(unit zone:ci)  (zone-of 'America/New_York')
=/  kolkata=(unit zone:ci)  (zone-of 'Asia/Kolkata')
=/  lord-howe=(unit zone:ci)  (zone-of 'Australia/Lord_Howe')
=/  london=(unit zone:ci)  (zone-of 'Europe/London')
::  a cron line's fields, by hand
::
=/  gulf-by
  |=  [lo=@ud hi=@ud step=@ud]
  ^-  (list @ud)
  ?:  (gth lo hi)  ~
  [lo $(lo (add lo step))]
=/  all
  |=  [lo=@ud hi=@ud]
  ^-  (list @ud)
  (gulf lo hi)
=/  spec
  |=  [minutes=(list @ud) hours=(list @ud)]
  ^-  cron-spec:ci
  [minutes hours (all 1 31) (all 1 12) (all 0 6) %.y %.y]
::  the next due instant, or ~ when refused
::
=/  next
  |=  [s=cron-spec:ci zone=(unit zone:ci) after=@da]
  ^-  (unit @da)
  =/  n=(each @da @t)  (next-after:ci-cron s zone after)
  ?:(?=(%| -.n) ~ `p.n)
=/  refusal-of
  |=  [s=cron-spec:ci zone=(unit zone:ci) after=@da]
  ^-  @t
  =/  n=(each @da @t)  (next-after:ci-cron s zone after)
  ?:(?=(%| -.n) p.n '')
::  ---- the occurrence table ----
::
=/  occ-rows=(list json)
  =/  j=(unit json)  (de:json:html occurrences)
  ?.  ?=([~ %a *] j)  ~
  p.u.j
=/  occ-cases=(list [name=@t expect=? got=?])
  %+  turn  occ-rows
  |=  row=json
  ^-  [name=@t expect=? got=?]
  ?.  ?=([%o *] row)  ['an occurrence row is an object' %.y %.n]
  =/  entry=(unit @ud)  (ud-at:ci-trigger p.row 'entry')
  =/  after=(unit @ud)  (ud-at:ci-trigger p.row 'after')
  =/  want=(unit (list @ud))  (uds-at:ci-trigger p.row 'next')
  =/  refused=?  !=('' (fall (text-at:ci-trigger p.row 'refusal') ''))
  ?.  &(?=(^ entry) ?=(^ after) ?=(^ want))  ['an occurrence row is well formed' %.y %.n]
  ?.  (lth u.entry (lent entries))  ['an occurrence row names an entry' %.y %.n]
  =/  def=schedule-def:ci  (snag u.entry entries)
  =/  name=@t
    %+  rap  3
    :~  'entry '
        (crip (a-co:co u.entry))
        ' ('
        cron.def
        ?~(timezone.def '' (rap 3 ~[' ' u.timezone.def]))
        ') from '  (iso-utc:ci-cron (from-unix:ci-cron u.after))
    ==
  ?~  spec.def  [name %.y %.n]
  =/  zone=(unit zone:ci)  ?~(timezone.def ~ (zone-of u.timezone.def))
  ?:  &(?=(^ timezone.def) ?=(~ zone))  [name %.y %.n]
  =/  at=@da  (from-unix:ci-cron u.after)
  =/  k=@ud  0
  =|  got=(list @ud)
  =/  result=[got=(list @ud) refused=?]
    |-
    ?:  =(k 4)  [(flop got) %.n]
    =/  n=(each @da @t)  (next-after:ci-cron u.spec.def zone at)
    ?:  ?=(%| -.n)  [(flop got) %.y]
    $(k +(k), got [(unix:ci-cron p.n) got], at p.n)
  [name %.y &(=(got.result u.want) =(refused.result refused))]
::  ---- a due wake ----
::
=/  hourly=cron-spec:ci  (spec ~[0] (all 0 23))
=/  hourly-def=schedule-def:ci  ['0 * * * *' ~ ~ `hourly]
=/  ten  ~2026.10.16..10.00.00
=/  entry=schedule-entry:ci
  :*  'Hourly'  hourly-def  ~  0v1.ddddd  'refs/heads/main'  0xb1  0x77  0v9.eeeee
      ~zod  ~2026.10.1  ~2026.10.1  %active  ~  `ten  ~  ~  ~  ~  0
  ==
=/  on-time  (on-wake:ci-cron entry ten 0v1.ddddd 0v2.ooooo (add ten ~s5))
=/  late  (on-wake:ci-cron entry ten 0v1.ddddd 0v2.ooooo ~2026.10.16..12.30.00)
=/  early  (on-wake:ci-cron entry ten 0v1.ddddd 0v2.ooooo (sub ten ~s2))
=/  ignored
  |=  [w=wake:ci-cron part=@t]
  ^-  ?
  ?.  ?=(%ignore -.w)  %.n
  (has-text why.w part)
::  ---- the cases ----
::
=/  catalog-cases=(list [name=@t expect=? got=?])
  :~  ['the pinned schedule catalog parses' %.y ?=([%& ^] parsed)]
      ['seventeen schedule entries, in order' %.y =(17 (lent entries))]
      :+  'the entries keep their text and zone'  %.y
      ?&  =('30 2 * * *' cron:(snag 0 entries))
          =(`'America/New_York' timezone:(snag 0 entries))
          =('0 0 29 2 *' cron:(snag 11 entries))
          =(~ timezone:(snag 11 entries))
      ==
      :+  'the compiler\'s refusals are kept, with no fields'  %.y
      =/  four=schedule-def:ci  (snag 15 entries)
      =/  mars=schedule-def:ci  (snag 16 entries)
      ?&  ?=(^ refusal.four)  (has-text u.refusal.four 'five minutes')  ?=(~ spec.four)
          ?=(^ refusal.mars)  (has-text u.refusal.mars 'pinned timezone database')  ?=(~ spec.mars)
      ==
      :+  'the ship\'s own rules accept every entry the compiler accepted'  %.y
      %+  levy  (scag 15 entries)
      |=(d=schedule-def:ci &(?=(~ refusal.d) ?=(^ spec.d)))
      :+  'four zone tables, and no table for the refused zone'  %.y
      ?&  =(4 ~(wyt by zones.cat))  ?=(^ ny)  ?=(^ kolkata)  ?=(^ lord-howe)  ?=(^ london)
          !(~(has by zones.cat) 'Mars/Olympus')
      ==
      :+  'New York: EST at the horizon\'s start, forty transitions'  %.y
      ?&(?=(^ ny) =(-18.000 offset.u.ny) =(40 (lent transitions.u.ny)) =(~2020.1.1 start.u.ny) =(~2040.1.1 end.u.ny))
      :+  'Kolkata: one offset, no transition'  %.y
      ?&(?=(^ kolkata) =(--19.800 offset.u.kolkata) =(~ transitions.u.kolkata))
      :+  'Lord Howe: daylight time at the horizon\'s start, half-hour shifts'  %.y
      ?&  ?=(^ lord-howe)  =(--39.600 offset.u.lord-howe)
          ?=(^ transitions.u.lord-howe)  =(--37.800 offset.i.transitions.u.lord-howe)
      ==
      ['the occurrence table has 135 rows' %.y =(135 (lent occ-rows))]
  ==
=/  by-hand=(list [name=@t expect=? got=?])
  :~  :+  'New York 02:30 on spring-forward day runs at the transition, 03:00 EDT'  %.y
      =(`~2027.3.14..07.00.00 (next (spec ~[30] ~[2]) ny ~2027.3.13..12.00.00))
      :+  'and the next day at 02:30 EDT'  %.y
      =(`~2027.3.15..06.30.00 (next (spec ~[30] ~[2]) ny ~2027.3.14..07.00.00))
      :+  'several skipped times are one run at the transition'  %.y
      ?&  =(`~2027.3.14..07.00.00 (next (spec ~[0 15 30 45] ~[2]) ny ~2027.3.14..06.50.00))
          =(`~2027.3.15..06.00.00 (next (spec ~[0 15 30 45] ~[2]) ny ~2027.3.14..07.00.00))
      ==
      :+  'a skipped time and the valid time at the transition are one run'  %.y
      ?&  =(`~2027.3.14..07.00.00 (next (spec ~[0 30] ~[2 3]) ny ~2027.3.14..06.00.00))
          =(`~2027.3.14..07.30.00 (next (spec ~[0 30] ~[2 3]) ny ~2027.3.14..07.00.00))
      ==
      :+  'New York 01:30 on fall-back day runs once, at its first instance (EDT)'  %.y
      ?&  =(`~2027.11.7..05.30.00 (next (spec ~[30] ~[1]) ny ~2027.11.7..04.00.00))
          =(`~2027.11.8..06.30.00 (next (spec ~[30] ~[1]) ny ~2027.11.7..05.30.00))
      ==
      :+  'the repeated instance never runs, even when asked from between the two'  %.y
      =(`~2027.11.8..06.30.00 (next (spec ~[30] ~[1]) ny ~2027.11.7..06.15.00))
      :+  '02:00 on fall-back day is 02:00 EST'  %.y
      =(`~2027.11.7..07.00.00 (next (spec ~[0] ~[2]) ny ~2027.11.7..05.00.00))
      :+  'the reference\'s example: 05:30 New York on weekdays'  %.y
      =/  s=cron-spec:ci  [~[30] ~[5] (all 1 31) (all 1 12) (all 1 5) %.y %.n]
      ?&  =(`~2026.10.19..09.30.00 (next s ny ~2026.10.16..12.00.00))
          =(`~2026.12.7..10.30.00 (next s ny ~2026.12.4..12.00.00))
      ==
      :+  'a zone without daylight saving: 05:30 Kolkata is 00:00 UTC'  %.y
      =(`~2026.10.17 (next (spec ~[30] ~[5]) kolkata ~2026.10.16..01.00.00))
      :+  'Lord Howe\'s half-hour spring-forward: 02:15 runs at the transition'  %.y
      =(`~2027.10.2..15.30.00 (next (spec ~[15] ~[2]) lord-howe ~2027.10.2))
      :+  'Lord Howe\'s half-hour fall-back: 01:45 runs once, at its first instance'  %.y
      ?&  =(`~2027.4.3..14.45.00 (next (spec ~[45] ~[1]) lord-howe ~2027.4.3))
          =(`~2027.4.4..15.15.00 (next (spec ~[45] ~[1]) lord-howe ~2027.4.3..14.45.00))
      ==
      :+  'London: a skipped 01:15 runs at 01:00 UTC; a repeated one once, in BST'  %.y
      ?&  =(`~2027.3.28..01.00.00 (next (spec ~[15] ~[1]) london ~2027.3.27..12.00.00))
          =(`~2027.10.31..00.15.00 (next (spec ~[15] ~[1]) london ~2027.10.30..12.00.00))
          =(`~2027.11.1..01.15.00 (next (spec ~[15] ~[1]) london ~2027.10.31..00.15.00))
      ==
      :+  'either day rule: the 13th or a Friday'  %.y
      =/  s=cron-spec:ci  [~[0] ~[0] ~[13] (all 1 12) ~[5] %.n %.n]
      ?&  =(`~2026.10.16 (next s ~ ~2026.10.15..12.00.00))
          (day-matches:ci-cron s 10 13 2)
          (day-matches:ci-cron s 10 16 5)
          !(day-matches:ci-cron s 10 14 3)
      ==
      :+  'both day rule when a day field begins with *: an odd day and a Monday'  %.y
      =/  s=cron-spec:ci  [~[0] ~[12] (gulf-by 1 31 2) (all 1 12) ~[1] %.y %.n]
      ?&  =(`~2026.10.19..12.00.00 (next s ~ ~2026.10.16))
          (day-matches:ci-cron s 10 19 1)
          !(day-matches:ci-cron s 10 26 1)
          !(day-matches:ci-cron s 10 17 6)
      ==
      :+  'the leap day: 29 February, four years apart'  %.y
      =/  s=cron-spec:ci  [~[0] ~[0] ~[29] ~[2] (all 0 6) %.n %.y]
      ?&  =(`~2028.2.29 (next s ~ ~2026.10.16))
          =(`~2032.2.29 (next s ~ ~2028.2.29))
      ==
      ['strictly after: a due instant is not its own next' %.y =(`~2026.10.16..05.15.00 (next (spec ~[15] ~[4 5]) ~ ~2026.10.16..04.15.00))]
      :+  'inside the horizon\'s last day'  %.y
      =(`~2039.12.30..05.00.00 (next (spec ~[0] ~[0]) ny ~2039.12.30..04.00.00))
      :+  'past the horizon\'s end refuses, naming it; never falls back to UTC'  %.y
      ?&  =(~ (next (spec ~[0] ~[0]) ny ~2039.12.31..06.00.00))
          %+  has-text
            (refusal-of (spec ~[0] ~[0]) ny ~2039.12.31..06.00.00)
          'beyond the timezone horizon'
      ==
      :+  'before the horizon\'s start refuses'  %.y
      %+  has-text
        (refusal-of (spec ~[0] ~[0]) ny ~2019.12.31)
      'outside the timezone horizon 2020-01-01T00:00:00Z to 2040-01-01T00:00:00Z'
      :+  'UTC has no horizon'  %.y
      =(`~2040.1.2 (next (spec ~[0] ~[0]) ~ ~2040.1.1..12.00.00))
  ==
=/  rules=(list [name=@t expect=? got=?])
  :~  ['every five minutes is accepted' %.y =(~ (spec-problem:ci-cron (spec (gulf-by 0 59 5) (all 0 23))))]
      ['every four minutes is refused' %.y (has-text (fall (spec-problem:ci-cron (spec (gulf-by 0 59 4) (all 0 23))) '') '4 minute(s) apart')]
      ['two minutes within an hour are refused' %.y (has-text (fall (spec-problem:ci-cron (spec ~[0 3] (all 0 23))) '') '3 minute(s) apart')]
      ['an hour\'s end to the next hour\'s start counts' %.y (has-text (fall (spec-problem:ci-cron (spec ~[2 58] ~[4 5])) '') '4 minute(s) apart')]
      ['the midnight wrap counts, whatever the days' %.y (has-text (fall (spec-problem:ci-cron (spec ~[0 58] ~[0 23])) '') '2 minute(s) apart')]
      ['two hours apart do not wrap' %.y =(~ (spec-problem:ci-cron (spec ~[0 55] ~[0 12])))]
      ['five minutes across an hour is accepted' %.y =(~ (spec-problem:ci-cron (spec ~[0 55] ~[0 1])))]
      :+  'a day no month has never occurs'  %.y
      %+  has-text
        (fall (spec-problem:ci-cron [~[0] ~[0] ~[30] ~[2] (all 0 6) %.n %.y]) '')
      'never occurs'
      ['the 31st of a month that has one occurs' %.y =(~ (spec-problem:ci-cron [~[0] ~[0] ~[31] (all 1 12) (all 0 6) %.n %.y]))]
      ['unsorted minutes are refused' %.y ?=(^ (spec-problem:ci-cron (spec ~[5 0] ~[1])))]
      ['a duplicated hour is refused' %.y ?=(^ (spec-problem:ci-cron (spec ~[0] ~[1 1])))]
      ['minute 60 is refused' %.y ?=(^ (spec-problem:ci-cron (spec ~[60] ~[1])))]
      ['weekday 7 is refused' %.y ?=(^ (spec-problem:ci-cron [~[0] ~[0] (all 1 31) (all 1 12) ~[7] %.y %.n]))]
      ['no hour at all is refused' %.y ?=(^ (spec-problem:ci-cron (spec ~[0] ~)))]
  ==
=/  wakes=(list [name=@t expect=? got=?])
  :~  :+  'an on-time wake admits its occurrence, arms the next hour, misses nothing'  %.y
      =([%admit %.n [%& ~2026.10.16..11.00.00] ~] on-time)
      :+  'a late wake admits once, late, arms after now, and records the missed hours'  %.y
      =([%admit %.y [%& ~2026.10.16..13.00.00] `[~2026.10.16..11.00.00 ~2026.10.16..12.00.00 2]] late)
      :+  'an early wake arms after its due instant, never the same one again'  %.y
      =([%admit %.n [%& ~2026.10.16..11.00.00] ~] early)
      :+  'a duplicate wake is ignored'  %.y
      %+  ignored
        (on-wake:ci-cron entry(admitted ~[0v2.ooooo]) ten 0v1.ddddd 0v2.ooooo (add ten ~s5))
      'admitted already'
      :+  'a wake for a replaced definition is ignored'  %.y
      (ignored (on-wake:ci-cron entry ten 0v3.rrrrr 0v2.ooooo (add ten ~s5)) 'replaced or revoked')
      :+  'a wake for another occurrence than the armed one is ignored'  %.y
      %+  ignored
        (on-wake:ci-cron entry ~2026.10.16..11.00.00 0v1.ddddd 0v2.ooooo ~2026.10.16..11.00.01)
      'not for the occurrence armed now'
      :+  'a retired schedule\'s wake is ignored'  %.y
      %+  ignored
        (on-wake:ci-cron entry(state %retired) ten 0v1.ddddd 0v2.ooooo (add ten ~s5))
      'not active'
      :+  'a refused schedule never admits'  %.y
      %+  ignored
        (on-wake:ci-cron entry(def hourly-def(spec ~)) ten 0v1.ddddd 0v2.ooooo (add ten ~s5))
      'refused'
      :+  'a wake exactly a minute late is on time; a second more is late'  %.y
      ?&  ?=([%admit %.n *] (on-wake:ci-cron entry ten 0v1.ddddd 0v2.ooooo (add ten ~s60)))
          ?=([%admit %.y *] (on-wake:ci-cron entry ten 0v1.ddddd 0v2.ooooo (add ten ~s61)))
      ==
      :+  'a day of five-minute occurrences missed is one interval of 288'  %.y
      .=  `[~2026.1.1..00.05.00 ~2026.1.2 288]
      (missed-between:ci-cron (spec (gulf-by 0 59 5) (all 0 23)) ~ ~2026.1.1 ~2026.1.2)
      ['nothing between two adjacent occurrences is missed' %.y =(~ (missed-between:ci-cron hourly ~ ten ~2026.10.16..10.59.59))]
  ==
=/  display=(list [name=@t expect=? got=?])
  :~  ['ISO UTC to the second' %.y =('2026-10-16T09:30:05Z' (iso-utc:ci-cron ~2026.10.16..09.30.05))]
      ['New York\'s wall clock, with its daylight offset' %.y =('2026-10-19 05:30 UTC-04:00' (local-text:ci-cron ny ~2026.10.19..09.30.00))]
      ['and its standard one' %.y =('2026-12-07 05:30 UTC-05:00' (local-text:ci-cron ny ~2026.12.7..10.30.00))]
      ['Kolkata\'s half-hour offset' %.y =('2026-10-17 05:30 UTC+05:30' (local-text:ci-cron kolkata ~2026.10.17))]
      ['Lord Howe at the instant its daylight time begins' %.y =('2027-10-03 02:30 UTC+11:00' (local-text:ci-cron lord-howe ~2027.10.2..15.30.00))]
      ['no zone is UTC' %.y =('2028-02-29 00:00 UTC' (local-text:ci-cron ~ ~2028.2.29))]
  ==
=/  cases=(list [name=@t expect=? got=?])
  :(weld catalog-cases occ-cases by-hand rules wakes display)
=/  failed=(list @t)
  %+  murn  cases
  |=  [name=@t expect=? got=?]
  ?:(=(expect got) ~ `name)
=/  passed=@ud  (sub (lent cases) (lent failed))
~&  [%failed failed]
~&  (crip "passed={<passed>} of={<(lent cases)>}")
?=(~ failed)
