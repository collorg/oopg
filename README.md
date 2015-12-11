# oopg

This is an attempt to check PK constraints in a graph of inheritance by means of a trigger. The trigger is written in plpython and is relatively slow.
Don't use it on tables with heavy insert/update.

<img src="https://github.com/collorg/oopg/blob/master/hello.png">

Look a tables.sql to see howto use the trigger.

The test.sh shell program drops and creates a database oopg.
