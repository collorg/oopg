# A plpython trigger to insure unicity constraint with PostgreSQL table inheritance

This is an attempt to check unicity constraints in a graph of inheritance by means of a trigger. The trigger is written in plpython and is relatively slow (> 50 ms by insert or update).
Do not use it on tables with heavy insert/update.

<img src="https://github.com/collorg/oopg/blob/master/hello.png">

## Documentation
* Have a look at `tables.sql` to see how to use the trigger.
* You must use `create language plpythonu` to use the trigger.
* I have tested it with both `plpython3u` and `plpythonu` and it seems to be a little faster with `plpythonu`.
* If a table `child` inherits a table `parent`, the primary key of `child` must be at least the primary key of `parent`.

**WARNING!** The test.sh shell program **drops** and creates a database named **oopg**.

**Keywords:** postgresql, inheritance, plpython, trigger
