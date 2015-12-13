# A plpython trigger to insure unicity constraint with PostgreSQL table inheritance

This is an attempt to check unicity constraints in a graph of inheritance by
means of a trigger. The trigger is written in `plpython` and is relatively slow
(> 50 ms by insert or update).
Do not use it on tables with heavy insert/update.

<img src="https://github.com/collorg/oopg/blob/master/datastruct.png">
Data structure used for the test.

## Dependencies
* The trigger requires [psycopg2](http://initd.org/psycopg/) Python module.

## Documentation
* You must use `create language plpythonu;` to use the trigger.
* Have a look at `tables.sql` to see how to use the trigger.
* I have tested it with both `plpython3u` and `plpythonu` and it seems to
be a little faster with `plpythonu`. If you want to use it with `plpython3u`,
just replace `plpythonu` by `plpython3u` at the end of
`check_unicity_trigger.sql`.
* If a table `child` inherits a table `parent`, the primary key of `child`
must be at least the primary key of `parent`.

**WARNING!** The `test.sh` shell program **drops** and recreates a database
named **oopg** (who knows ;).

**Keywords:** `postgresql`, `inheritance`, `plpython`, `trigger`
