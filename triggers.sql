create language plpythonu;

--
--
--

CREATE FUNCTION check_pk()
    RETURNS trigger
AS $$
from datetime import datetime
begin = datetime.now()
from sys import stderr

oid = TD['relid']
GD['td'] = TD
ok = plpy.execute(
	"SELECT check_pk_oid({})".format(oid))[0]['check_pk_oid']
stderr.write("check_pk duration: {}\n".format(datetime.now() - begin))
if not ok:
    return 'SKIP'
$$ LANGUAGE plpythonu;

--
--
--

CREATE FUNCTION check_pk_oid(integer)
  returns boolean
AS $$
"""Return False if the key is found in any of the parents."""
from datetime import datetime
begin = datetime.now()
from sys import stderr
from psycopg2.extensions import adapt

oid = args[0]
stderr.write("{} check_pk_oid({})\n".format(8*'=', oid))
TD = GD['td']
stderr.write("GD['td'] = {}\n".format(TD))
parent_oid = plpy.execute(
    "SELECT get_inhparent('{}')".format(oid))[0]['get_inhparent']
stderr.write("oid du parent {}\n".format(parent_oid))
if parent_oid:
   # recurse on parent_oid
   query = ("SELECT check_pk_oid({})".format(parent_oid))
   stderr.write("check uid request: {}\n".format(query))
   return plpy.execute(query)[0]['check_pk_oid']
# Get the FQTN and the field names of the primary key
pk_infos = plpy.execute(
   "SELECT get_pk_fields({})".format(oid))[0]['get_pk_fields']
fqtn, pk_fieldnames = pk_infos[0], pk_infos[1:]
if not pk_fieldnames:
   stderr.write(
       "check_pk_oid duration ok 1: {}\n".format(datetime.now() - begin))
   return True

# Clause for the SELECT request
fields = []
clause = []
for field in pk_fieldnames:
   fields.append(field)
   if TD['new'][field] == 0:
     valeur = 0
   else:
     valeur = TD['new'][field] or ""
     valeur = adapt(valeur)
   clause.append("{} = {}".format(field, str(valeur)))

# construction de la requête d''extraction
req = "SELECT {} FROM {} WHERE {} limit 1".format(
	', '.join(fields), fqtn, ' and '.join(clause))
stderr.write("check_pk_oid: {}\n".format(req))
if len(plpy.execute(req)) == 1:
    stderr.write("CLEF DUPLIQUEE\n")
    stderr.write("check_pk_oid duration: {}\n".format(datetime.now() - begin))
    return False

stderr.write("check_pk_oid duration ok 2: {}\n".format(datetime.now() - begin))
return True
$$ LANGUAGE plpythonu;

--
--
--

CREATE FUNCTION get_inhparent(integer)
    RETURNS integer
AS $$
from sys import stderr
relid = args[0]
stderr.write("{} get_inhparent({})\n".format(8*'=', relid))
query = (
    "SELECT inhparent FROM pg_catalog.pg_inherits WHERE inhrelid = {}".format(
    relid))
stderr.write('get_inhparent: {}\n'.format(query))
rec = plpy.execute(query)
try:
   return rec[0]['inhparent']
except:
   return 0
$$ LANGUAGE plpythonu;

--
--
--

CREATE FUNCTION get_pk_fields(oid)
    RETURNS varchar[]
AS $$
"""
Return the field names in the primary key
"""
from sys import stderr
oid = args[0]
stderr.write("{} get_pk_fields({})\n".format(8*'=', oid))
# rec_st : record contenant schemaname et relname
rec_st = plpy.execute(
   """SELECT schemaname, relname 
      FROM pg_catalog.pg_stat_all_tables
      WHERE relid = {}""".format(oid))
schemaname = rec_st[0]['schemaname']
relname = rec_st[0]['relname']
l_fieldnames = plpy.execute(
   """
SELECT
    a.attrelid AS tableid,
    c.relkind AS tablekind,
    n.nspname::varchar AS schemaname,
    c.relname::varchar AS relationname,
	array_agg(distinct i.inhparent) as parent,
    array_agg(a.attname::varchar) AS fieldnames,
	array_agg(a.attnum) as attnums,
    array_agg(a.attislocal) AS local,
    cn_pk.contype AS pkey
FROM
    pg_class c -- table
    LEFT JOIN pg_namespace n ON
    c.relname = '{}' and
    n.oid = c.relnamespace and
    n.nspname = '{}'
    LEFT JOIN pg_inherits i ON
    i.inhrelid = c.oid
    LEFT JOIN pg_attribute a ON
    a.attrelid = c.oid
    JOIN pg_type pt ON
    a.atttypid = pt.oid
--    LEFT JOIN pg_constraint cn_uniq ON
--    cn_uniq.contype = 'u' AND
--    cn_uniq.conrelid = a.attrelid AND
--    a.attnum = ANY( cn_uniq.conkey )
    JOIN pg_constraint cn_pk ON
    cn_pk.contype = 'p' AND
    cn_pk.conrelid = a.attrelid AND
    a.attnum = ANY( cn_pk.conkey )
WHERE
    n.nspname <> 'pg_catalog'::name AND
    n.nspname <> 'information_schema'::name AND
    ( c.relkind = 'r'::"char" )
GROUP BY
    a.attrelid,
    c.relkind,
    n.nspname,
    c.relname,
    cn_pk.contype""".format(relname, schemaname))[0]['fieldnames']
fqtn = "{}.{}".format(schemaname, relname)
return [fqtn] + l_fieldnames
fieldnames = ','.join(l_fieldnames)
resultat = fqtn + ":" + fieldnames
stderr.write("{}\n".format(resultat))
return resultat
$$ LANGUAGE plpythonu;

------
------ usage
------

create table parent(
   a text primary key
);

CREATE TRIGGER check_pk
    BEFORE INSERT or update ON parent
    FOR EACH ROW
    EXECUTE PROCEDURE check_pk();

--
--
--

create table child(
   b text,
   primary key(a, b)
) inherits(parent);

CREATE TRIGGER check_pk
    BEFORE INSERT or update ON child
    FOR EACH ROW
    EXECUTE PROCEDURE check_pk();
