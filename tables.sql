create table root(
   r text primary key
);

create trigger check_unique_constraint
    before insert or update on root
    for each row execute procedure check_unique_constraint();

create table parent_a(
   a text,
   primary key(r, a)
) inherits(root);

create trigger check_unique_constraint
    before insert or update on parent_a
    for each row execute procedure check_unique_constraint();

create table parent_b(
   b text unique,
   unique(r, b)
) inherits(root);

create trigger check_unique_constraint
    before insert or update on parent_b
    for each row execute procedure check_unique_constraint();

create table child_c(
   c text
) inherits(parent_a, parent_b);

create trigger check_unique_constraint
    before insert or update on child_c
    for each row execute procedure check_unique_constraint();

create table child_d(
   d text unique,
   primary key(a, b, d)
) inherits(parent_a, parent_b);

create trigger check_unique_constraint
    before insert or update on child_d
    for each row execute procedure check_unique_constraint();

create table grand_child_d(
   e text
) inherits(child_d);

create trigger check_unique_constraint
    before insert or update on grand_child_d
    for each row execute procedure check_unique_constraint();
