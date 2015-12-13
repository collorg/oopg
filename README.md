# A plpython trigger to insure unique constraint with PostgreSQL table inheritance

This is an attempt to check unique constraints in a graph of inheritance by
means of a trigger. The trigger is written in `plpython` and is relatively slow
(> 50 ms by insert or update).

THE TRIGGER DOESN'T WORK WITH UPDATE...

<img src="https://github.com/collorg/oopg/blob/master/datastruct.png">
The database structure used to test the trigger.

## Dependencies
* The trigger requires [psycopg2](http://initd.org/psycopg/) Python module.

## Documentation
* You must use `create language plpythonu;` to use the trigger.
* Have a look at `tables.sql` to see how to use the trigger.
* I have tested it with both `plpython3u` and `plpythonu` and it seems to
be a little faster with `plpythonu`. If you want to use it with `plpython3u`,
just replace `plpythonu` by `plpython3u` at the end of
`check_unicity_trigger.sql`.

**WARNING!** The `test.sh` shell program **drops** and recreates a database
named **oopg** (who knows ;).

**Keywords:** `postgresql`, `inheritance`, `plpython`, `trigger`
