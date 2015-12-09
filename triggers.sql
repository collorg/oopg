create language plpythonu;

--
--
--

CREATE FUNCTION check_pk() RETURNS trigger AS $$
oid = TD['relid']
GD['td'] = TD
plpy.execute("SELECT check_pk_oid('{}', '{}')".format(oid, oid))
$$
LANGUAGE plpythonu;

--
--
--

CREATE FUNCTION check_pk_oid(integer, integer) RETURNS text AS $$
"""
recherche d''éventuelles correspondances dans l'arbre d''héritage.
Si une correspondance est trouvée, déclenche une erreur.
Sinon retourne l'uid correspondants à la concaténation des champs de la clef
primaire et du fqtn à gauche et à droite deux fois signés sha.
"""
import sys
from psycopg2.extensions import adapt

new_uid = ''
#inhf = False
oid_orig = args[0]
oid = args[1]
sys.stderr.write("{} check_pk_oid({}, {})\n".format(
    8*'=', oid_orig, oid))
TD = GD['td']
sys.stderr.write("GD['td'] = {}\n".format(TD))
parent_oid = plpy.execute(
    "SELECT get_inhparent('{}')".format(oid))[0]['get_inhparent']
sys.stderr.write("oid du parent {}\n".format(parent_oid))
if parent_oid:
   # si la table hérite d''une autre table, on recherche l''existence
   # d''un tuple correspondant dans la table mère
   query = ("SELECT check_pk_oid('{}', '{}')".format(oid_orig, parent_oid))
   sys.stderr.write("check uid request: {}\n".format(query))
   rec = plpy.execute(query)
   new_uid = rec[0]['check_pk_oid']
# récupration du fqtn et des champs de la clef primaire
pk_infos = plpy.execute(
   "SELECT get_pk_fields({})".format(oid))[0]['get_pk_fields']
fqtn, pk_fieldnames = pk_infos.split(':')
clause = []
if not pk_fieldnames:
   return new_uid
pklist = pk_fieldnames.split(',')

# construction de la clause pour la requête SELECT
l_pk_val = []
for field in pklist:
   if TD['new'][field] == 0:
     valeur = 0
   else:
     valeur = TD['new'][field] or ""
     valeur = adapt(valeur)
   clause.append("{} = {}".format(field, str(valeur)))

# construction de la requête d''extraction
req = "SELECT * FROM {} WHERE {} limit 1".format(fqtn, ' and '.join(clause))
sys.stderr.write("check_pk_oid: {}\n".format(req))
if len(plpy.execute(req)) == 1:
    plpy.error("clef dupliquee")

return 'ok'
$$
LANGUAGE plpythonu;

--
--
--

CREATE FUNCTION get_fqtn(integer) RETURNS text AS $$
import sys
oid = args[0]
sys.stderr.write("{} get_inhparent({})\n".format(8*'=', oid))
rec = plpy.execute(
   """SELECT schemaname, relname      
      FROM pg_catalog.pg_stat_user_tables
      WHERE relid = '{}'
   """.format(oid))
return rec[0]['schemaname'] + "." + rec[0]['relname']
$$
LANGUAGE plpythonu;

--
--
--

CREATE FUNCTION get_inhparent(integer) RETURNS integer AS $$
import sys
relid = args[0]
sys.stderr.write("{} get_inhparent({})\n".format(8*'=', relid))
query = (
    "SELECT inhparent FROM pg_catalog.pg_inherits WHERE inhrelid = '{}'".format(
    relid))
sys.stderr.write('get_inhparent: {}\n'.format(query))
rec = plpy.execute(query)
try:
   return rec[0]['inhparent']
except:
   return 0
$$
LANGUAGE plpythonu;

--
--
--

CREATE FUNCTION get_pk_fields(oid) RETURNS text AS $$
"""
retourne les noms des champs constituant la clef primaire de la table
dont l'oid est passé en référence. Les champs sont ordonnés par "attnum"
(le numéro de l'attribut ou numéro du champ dans la table). Attention, en
cas d'altération de la table (touchant un ou plusieur de ces champs), 
l'ordre peut être modifié.
"""
import sys
oid = args[0]
sys.stderr.write("{} get_pk_fields({})\n".format(8*'=', oid))
# rec_st : record contenant schemaname et relname
rec_st = plpy.execute(
   """SELECT schemaname, relname 
      FROM pg_catalog.pg_stat_all_tables
      WHERE relid = {}""".format(oid))
schemaname = rec_st[0]['schemaname']
relname = rec_st[0]['relname']
rec_pk_fieldnames = plpy.execute(
   """SELECT pa.attname 
      FROM pg_attribute pa, pg_type pt 
      WHERE pa.attrelid IN (
        SELECT oid 
        FROM pg_class 
        WHERE relname = '{}' 
        AND relnamespace = (
          SELECT oid 
          FROM pg_catalog.pg_namespace 
          WHERE nspname = '{}')
       ) 
        AND pa.atttypid = pt.oid
        AND pa.attnum = ANY (
          ARRAY [ (
          SELECT conkey
          FROM pg_constraint pconst 
          WHERE contype = 'p'
          AND conrelid = (
            SELECT relid
            FROM pg_catalog.pg_stat_all_tables
            WHERE schemaname = '{}'
            AND relname = '{}')) ]
       )""".format(relname, schemaname, schemaname, relname))
l_fieldnames = []
for rec in rec_pk_fieldnames:
  l_fieldnames.insert(0, rec['attname'])
fieldnames = ','.join(l_fieldnames)
fqtn = schemaname + '.' + relname
resultat = fqtn + ":" + fieldnames
sys.stderr.write("{}\n".format(resultat))
return resultat
$$
LANGUAGE plpythonu;

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
