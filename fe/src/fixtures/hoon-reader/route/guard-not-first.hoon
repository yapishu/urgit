|%
++  on-poke
  |=  site=(list @t)
  |^
  (handle-api site)
  ++  handle-api
    |=  site=(list @t)
    =/  method=@t  'POST'
    |^
      ?+  (slag 3 site)  !!
        [%repository @ *]  repository-api
      ==
    ++  repository-api
      ?+  (slag 5 site)
        ?:  =(method %'GET')  view-api
        settings-api
          [%file *]
        file-api
      ==
    ++  view-api
      ~
    ++  file-api
      ~
    ++  settings-api
      |^
        ?+  [method (slag 3 site)]  !!
            [%'POST' %repository @ %tags ~]
          post-repository-tags
        ==
      ++  post-repository-tags
        =/  x  1
        ?>  ?&  =(%'POST' method)
                ?=([%apps %urgit %api %repository @ %tags ~] site)
            ==
        ~
      --
    --
  --
--
