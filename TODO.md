# TODO

## Short Term

* Decouple from a dependence on defining the object model to DB by using the database. It should be possible, and indeed, preferable, to define the object model in Ruby, and define the mapping from that model to the database, as well. In a happy happy world, this lets Kansas handle table creation, and migrations, too. How short term is this goal?  Hmm.

* Ditch DBI. It's ancient. There are better maintained options. Adopt one of
  them.

* Improve tests. The codebase still needs proper unit tests of the moving
  parts.

* Improve docs, test it with a sample app or two, and (re) announce it to the world.