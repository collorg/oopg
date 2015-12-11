#!/usr/bin/env bash

dropdb oopg
createdb oopg
psql oopg -f trigger.sql
psql oopg -f tables.sql
psql oopg -c "insert into parent_a (a) values ('a')"         # OK
psql oopg -c "insert into parent_b (b) values ('b')"         # OK
psql oopg -c "insert into child_c (a, b, c) values ('a', 'c', 'c')" # FAILS
psql oopg -c "insert into child_c (a, b, c) values ('c', 'b', 'c')" # FAILS
psql oopg -c "insert into child_c (a, b, c) values ('c', 'c', 'c')" # OK
exit
psql oopg -c "insert into childb (a, b) values ('b', 'a')" # OK
psql oopg -c "insert into parent (a) values ('b')"         # FAILS
psql oopg -c "insert into childc (a, c) values ('b', 'a')" # FAILS
psql oopg -c "insert into childc (a, c) values ('c', 'a')" # OK
psql oopg -c "select * from parent"       # a, b, c
psql oopg -c "update parent set a = 'b'"                   # FAILS
psql oopg -c "update childb set a = 'c'"                   # FAILS
psql oopg -c "update childb set a = 'd'"                   # OK
