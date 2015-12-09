#!/usr/bin/env bash

dropdb pgo
createdb pgo
psql pgo -f triggers.sql
psql pgo -c "insert into parent (a) values ('a')"
psql pgo -c "insert into child (a, b) values ('a', 'a')"
psql pgo -c "insert into child (a, b) values ('b', 'a')"
psql pgo -c "insert into parent (a) values ('b')"
psql pgo -c "select * from parent"
psql pgo -c "update parent set a = 'b'"
