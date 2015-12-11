create table root(
   r text primary key
);

create trigger check_pk
    before insert or update on root
    for each row execute procedure check_pk();

create table parent_a(
   a text,
   primary key(r, a)
) inherits(root);

create trigger check_pk
    before insert or update on parent_a
    for each row execute procedure check_pk();

create table parent_b(
   b text,
   primary key(r, b)
) inherits(root);

create trigger check_pk
    before insert or update on parent_b
    for each row execute procedure check_pk();

create table child_c(
   c text,
   primary key(r, a, b, c)
) inherits(parent_a, parent_b);

create trigger check_pk
    before insert or update on child_c
    for each row execute procedure check_pk();

create table child_d(
   d text,
   primary key(r, a, b, d)
) inherits(parent_a, parent_b);

create trigger check_pk
    before insert or update on child_d
    for each row execute procedure check_pk();