#!/usr/bin/env bash

dropdb oopg
createdb oopg
psql oopg -c "create language plpythonu"

psql oopg -f check_unicity_trigger.sql
psql oopg -f tables.sql
psql oopg -c "insert into parent_a (r, a) values ('a', null)"         # FAILS
echo -n "OK "
psql oopg -c "insert into parent_a (r, a) values ('a', 'a')"         # OK

psql oopg -c "insert into parent_b (r, b) values ('a', 'b')"         # FAILS
echo -n "OK "
psql oopg -c "insert into parent_b (r, b) values ('b', 'b')"         # OK

psql oopg -c "insert into child_c (r, a, b, c) values ('a', 'a', 'c', 'c')"
psql oopg -c "insert into child_c (r, a, b, c) values ('a', 'c', 'c', 'c')" # FAILS
psql oopg -c "insert into child_c (r, a, b, c) values ('a', 'c', 'b', 'c')" # FAILS
echo -n "OK "
psql oopg -c "insert into child_c (r, a, b, c) values ('c', 'c', 'c', 'c')" # OK

psql oopg -c "insert into child_d (r, a, b, d) values ('c', 'c', 'c', 'd')" # FAILS
psql oopg -c "insert into child_d (r, a, b, d) values ('c', 'd', 'd', 'd')" # FAILS
psql oopg -c "insert into child_d (r, a, b, d) values ('c', 'd', 'd', 'd')" # FAILS
echo -n "OK "
psql oopg -c "insert into child_d (r, a, b, d) values ('d', 'd', 'd', 'd')" # OK

# check unicity
psql oopg -c "insert into grand_child_d (r, a, b, d, e) values ('e', 'e', 'e', 'd', 'e')" # FAILS
echo -n "OK "
psql oopg -c "insert into grand_child_d (r, a, b, d, e) values ('e', 'e', 'e', 'e', 'e')" # OK
psql oopg -c "insert into grand_child_d (r, a, b, d, e) values ('f', 'e', 'e', 'e', 'f')" # FAILS
psql oopg -c "insert into grand_child_d (r, a, b, d, e) values ('f', 'f', 'e', 'f', 'f')" # FAILS
psql oopg -c "insert into grand_child_d (r, a, b, d, e) values ('f', 'f', 'f', 'e', 'f')" # FAILS

psql oopg -c "insert into parent_a (r, a) values ('c', 'd')"         # FAILS

psql oopg -c "select * from root"       # {a, c, d}
psql oopg -c "select * from parent_a"       # {a, c, d}
psql oopg -c "select * from parent_b"       # {b, c, d}
psql oopg -c "select * from child_d"

# odd! when I update without constraint the update is confined to
# the table on which it is executed (not the children)? hence:
psql oopg -c "update parent_a set a = 'b' where a = '%'"     # FAILS
psql oopg -c "update parent_a set a = 'b'"                   # OK (update only parent_a)

psql oopg -c "update child_d set a = 'c'"                   # FAILS (child_c)
psql oopg -c "update child_d set a = 'f'"                   # OK
