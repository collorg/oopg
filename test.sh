#!/usr/bin/env bash

dropdb oopg
createdb oopg
psql oopg -f triggers.sql
psql oopg -c "insert into parent (a) values ('a')"         # OK
psql oopg -c "insert into childb (a, b) values ('a', 'a')" # FAILS
psql oopg -c "insert into childb (a, b) values ('b', 'a')" # OK
psql oopg -c "insert into parent (a) values ('b')"         # FAILS
psql oopg -c "insert into childc (a, c) values ('b', 'a')" # FAILS
psql oopg -c "insert into childc (a, c) values ('c', 'a')" # OK
psql oopg -c "select * from parent"       # a, b, c
psql oopg -c "update parent set a = 'b'"                   # FAILS
psql oopg -c "update childb set a = 'c'"                   # FAILS
psql oopg -c "update childb set a = 'd'"                   # OK
