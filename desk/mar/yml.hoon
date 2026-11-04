::  YAML carried as text.  Nothing on the ship parses it; the mark exists
::  so workflow fixtures under /tests/ci can live on the desk.
::
|_  txt=wain
++  grab
  |%
  ++  mime  |=((pair mite octs) (to-wain:format q.q))
  ++  noun  wain
  --
++  grow
  |%
  ++  mime  [/text/yaml (as-octs:mimes:html (of-wain:format txt))]
  --
++  grad  %mime
--
