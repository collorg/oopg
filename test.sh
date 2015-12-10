#!/usr/bin/env bash

dropdb oopg
createdb oopg
psql oopg -f triggers.sql
psql oopg -c "insert into parent (a) values ('a')"
psql oopg -c "insert into child (a, b) values ('a', 'a')"
psql oopg -c "insert into child (a, b) values ('b', 'a')"
psql oopg -c "insert into parent (a) values ('b')"
psql oopg -c "select * from parent"
psql oopg -c "update parent set a = 'b'"
psql oopg -c "update parent set a = 'c'"
