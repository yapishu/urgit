|%
++  on-poke
  |=  act=[tag=@tas ~]
  |^
  (handle-action act)
  ++  handle-action
    |=  act=[tag=@tas ~]
    |^
    ?+  tag.act  !!
      @  wrong
      %set-ref  set-ref
    ==
    ++  set-ref
      0
    ++  wrong
      1
    --
  --
--
