#!/usr/bin/env bash

dropdb oopg
createdb oopg
psql oopg -c "create language plpythonu"

psql oopg -f check_unique_trigger.sql
psql oopg -f tables.sql
echo -n "OK "; psql oopg -c "insert into root (r) values ('r')"         # OK

psql oopg -c "insert into parent_a (r, a) values ('r', 'a')"         # FAILS root(r)pk
echo -n "OK "; psql oopg -c "insert into parent_a (r, a) values ('a', 'a')"         # OK

psql oopg -c "insert into parent_b (r, b) values ('a', 'b')"         # FAILS root(r)pk from parent_a

echo -n "OK "; psql oopg -c "insert into parent_b (r, b) values ('b', 'b')"         # OK
echo -n "OK "; psql oopg -c "insert into parent_b (r, b) values ('b1', null)"         # OK
echo -n "OK "; psql oopg -c "insert into parent_b (r, b) values ('b2', null)"         # OK

psql oopg -c "insert into child_c (r, a, b, c) values ('a', 'a', 'c', 'c')" # FAILS parent_a(r, a)pk
psql oopg -c "insert into child_c (r, a, b, c) values ('x', 'x', 'b', 'x')" # FAILS parent_b(b)unique

echo -n "OK "; psql oopg -c "insert into child_c (r, a, b, c) values ('c', 'c', 'c', 'c')" # OK

psql oopg -c "insert into child_d (r, a, b, d) values ('c', 'c', 'c', 'd')" # FAILS
psql oopg -c "insert into child_d (r, a, b, d) values ('c', 'd', 'd', 'd')" # FAILS
psql oopg -c "insert into child_d (r, a, b, d) values ('c', 'd', 'd', 'd')" # FAILS

echo -n "OK "; psql oopg -c "insert into child_d (r, a, b, d) values ('d', 'd', 'd', 'd')" # OK

psql oopg -c "insert into grand_child_d (r, a, b, d, e) values ('e', 'e', 'e', 'd', 'e')" # FAILS

echo -n "OK "; psql oopg -c "insert into grand_child_d (r, a, b, d, e) values ('e', 'e', 'e', 'e', 'e')" # OK
psql oopg -c "insert into grand_child_d (r, a, b, d, e) values ('f', 'e', 'e', 'e', 'f')" # FAILS
psql oopg -c "insert into grand_child_d (r, a, b, d, e) values ('f', 'f', 'e', 'f', 'f')" # FAILS
psql oopg -c "insert into grand_child_d (r, a, b, d, e) values ('f', 'f', 'f', 'e', 'f')" # FAILS

echo -n "OK "; psql oopg -c "insert into grand_child_d (r, a, b, d, e) values ('gc1', 'x', 'x', 'x', 'gc1')" # OK
psql oopg -c "insert into grand_child_d (r, a, b, d, e) values ('gc2', 'x', 'x', 'x', 'gc1')" # FAILS (a, b, d)unique

psql oopg -c "insert into parent_a (r, a) values ('c', 'd')"         # FAILS

psql oopg -c "select * from root"
psql oopg -c "select * from parent_a"
psql oopg -c "select * from parent_b"
psql oopg -c "select * from child_d"

# UPDATE DOESN'T WORK. HOW TO DETERMINE THE NUMBER OF ROWS
psql oopg -c "update parent_a set a = 'b' where a like '%'"     # FAILS
echo -n "OK "; psql oopg -c "update parent_a set a = 'b'"                   # OK (update only parent_a)

psql oopg -c "update child_d set a = 'c'"                   # FAILS (child_c)
echo -n "OK "; psql oopg -c "update child_d set a = 'f'"                   # OK
