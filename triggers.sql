create language plpythonu;
-- create extension uuid;

--
-- Name: tuple_uid; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tuple_uid (
    uid text NOT NULL,
    fqtn text NOT NULL,
    changeset integer DEFAULT 0,
    CONSTRAINT tuple_uid_uid_check CHECK ((uid ~~ '________________________________________________________________________________'::text))
);


--
-- Name: after_delete_tuple(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION after_delete_tuple() RETURNS trigger
    AS $$

oid = TD['relid']
uid = TD['old']['tpl_uid']
fqtn = plpy.execute("""SELECT get_fqtn('%s')""" %
   oid)[0]['get_fqtn']
try:
   plpy.execute(
      """DELETE FROM tuple_uid WHERE uid = '%s' and fqtn = '%s'""" % (
      uid, fqtn))
except:
   pass
$$
    LANGUAGE plpythonu;


ALTER FUNCTION after_delete_tuple() OWNER TO postgres;

--
-- Name: before_insert_tuple(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION before_insert_tuple() RETURNS trigger
    AS $$

oid = TD['relid']
fqtn = plpy.execute("""SELECT get_fqtn('%s')""" % oid)[0]['get_fqtn']
GD['td'] = TD
rec = plpy.execute(
   """SELECT check_uid('%s', '%s', '%s')""" % (oid, fqtn, oid))
new_uid = rec[0]['check_uid']
try:
   TD['new']['tpl_uid'] = new_uid
   TD['new']['tpl_fqtn'] = fqtn
   plpy.execute(
      """INSERT INTO tuple_uid (uid, fqtn) VALUES ('%s', '%s')""" % (
      new_uid, fqtn))
   return 'MODIFY'
except:
   return 'SKIP'
$$
    LANGUAGE plpythonu;


ALTER FUNCTION before_insert_tuple() OWNER TO postgres;

--
-- Name: before_update_tuple(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION before_update_tuple() RETURNS trigger
    AS $$
from mx import DateTime

oid = TD['relid']
old_uid = TD['old']['tpl_uid']
fqtn = TD['old']['tpl_fqtn']
changeset = TD['old']['tpl_changeset'] + 1
GD['td'] = TD
rec = plpy.execute(
   """SELECT check_uid('%s', '%s', '%s')""" % (
      oid, fqtn, oid))
new_uid = rec[0]['check_uid']
try:
   TD['new']['tpl_uid'] = new_uid
   TD['new']['tpl_fqtn'] = fqtn
   TD['new']['tpl_modification_date'] = DateTime.now()
   TD['new']['tpl_changeset'] = changeset
   plpy.execute(
      "UPDATE tuple_uid SET uid = '%s', changeset = '%s' WHERE uid = '%s'" % (
      new_uid, changeset, old_uid))
   return 'MODIFY'
except:
   return 'SKIP'
$$
    LANGUAGE plpythonu;


ALTER FUNCTION before_update_tuple() OWNER TO postgres;

--
-- Name: check_uid(integer, text, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION check_uid(integer, text, integer) RETURNS text
    AS $$
"""
recherche d''éventuelles correspondances dans l'arbre d''héritage.
Si une correspondance est trouvée, déclenche une erreur.
Sinon retourne l'uid correspondants à la concaténation des champs de la clef
primaire et du fqtn à gauche et à droite deux fois signés sha.
"""
import sys
import sha

new_uid = ''
#inhf = False
oid_orig = args[0]
fqtn_orig = args[1]
oid = args[2]
sys.stderr.write("{} check_uid({}, {}, {})\n".format(
    8*'=', oid_orig, fqtn_orig, oid))
TD = GD['td']
sys.stderr.write("GD['td'] = {}\n".format(TD))
parent_oid = plpy.execute(
   """SELECT get_inhparent('%s')
   """ % oid)[0]['get_inhparent']
sys.stderr.write("oid du parent {}\n".format(parent_oid))
if parent_oid:
   # si la table hérite d''une autre table, on recherche l''existence
   # d''un tuple correspondant dans la table mère
   query = ("""SELECT check_uid('%s', '%s', '%s')""" % (
      oid_orig, fqtn_orig, parent_oid))
   sys.stderr.write("check uid request: {}\n".format(query))
   rec = plpy.execute(query)
   new_uid = rec[0]['check_uid']
# récupration du fqtn et des champs de la clef primaire
pk_infos = plpy.execute(
   """SELECT get_pk_fields(%s)""" % (oid))[0]['get_pk_fields']
fqtn, pk_fieldnames = pk_infos.split(':')
clause = []
if not pk_fieldnames:
   return new_uid
pklist = pk_fieldnames.split(',')

if TD['event'] == 'UPDATE':
   # on aura besoin de vérifier que s'il y a quelque chose
   # qui a changé dans la clef
   to_check = False
   for field in pklist:
      if TD['old'][field] != TD['new'][field]:
         # quelque chose a changé dans la clef
	 to_check = True
   if not to_check:
      return TD['old']['tpl_uid']

# construction de la clause pour la requête SELECT
l_pk_val = []
for field in pklist:
   if field == 'tpl_fqtn':
      TD['new'][field] = fqtn_orig
   if TD['new'][field] == 0:
     valeur = 0
   else:
     valeur = TD['new'][field] or ""
   valeur = str(valeur).replace("'", "''")
   valeur = valeur.replace("\\", "\\\\")
   l_pk_val.append(field + ":" + valeur)
   clause.append(field + " = '" + valeur + "'")

# construction de la requête d''extraction
req = "SELECT * FROM {} WHERE {} limit 1".format(fqtn, ' and '.join(clause))
sys.stderr.write("check_uid: {}\n".format(req))
if len(plpy.execute(req)) == 1:
    plpy.error("clef dupliquee")

# le calcul (dans les deux sens) de la clef
pk_val = ']-+#=-['.join(l_pk_val)
if len(l_pk_val) > 1:
   pk_val = '[' + pk_val + ']'
l_pk_val = pk_val + "." + fqtn
r_pk_val = fqtn + "." + pk_val
uid_text = l_pk_val
l_uid_val = sha.sha(l_pk_val).hexdigest()
r_uid_val = sha.sha(r_pk_val).hexdigest()
uid_val = l_uid_val + r_uid_val
if uid_val:
   new_uid = uid_val
# seule le dernier uid est pris en compte.
return new_uid
$$
    LANGUAGE plpythonu;


ALTER FUNCTION check_uid(integer, text, integer) OWNER TO postgres;

--
-- Name: get_fqtn(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_fqtn(integer) RETURNS text
    AS $$
import sys
oid = args[0]
sys.stderr.write("{} get_inhparent({})\n".format(8*'=', oid))
rec = plpy.execute(
   """SELECT schemaname, relname      
      FROM pg_catalog.pg_stat_user_tables
      WHERE relid = '%s'
   """ % (oid))
return rec[0]['schemaname'] + "." + rec[0]['relname']
$$
    LANGUAGE plpythonu;


ALTER FUNCTION get_fqtn(integer) OWNER TO postgres;

--
-- Name: get_inhparent(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_inhparent(integer) RETURNS integer
    AS $$
import sys
relid = args[0]
sys.stderr.write("{} get_inhparent({})\n".format(8*'=', relid))
query = ("SELECT inhparent FROM pg_catalog.pg_inherits WHERE inhrelid = '%s'" %
    relid)
sys.stderr.write('{}\n'.format(query))
rec = plpy.execute(query)
try:
   return rec[0]['inhparent']
except:
   return 0
$$
    LANGUAGE plpythonu;


ALTER FUNCTION get_inhparent(integer) OWNER TO postgres;

--
-- Name: get_pk_fields(oid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_pk_fields(oid) RETURNS text
    AS $$
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
      WHERE relid = %s""" % oid)
schemaname = rec_st[0]['schemaname']
relname = rec_st[0]['relname']
rec_pk_fieldnames = plpy.execute(
   """SELECT pa.attname 
      FROM pg_attribute pa, pg_type pt 
      WHERE pa.attrelid IN (
        SELECT oid 
        FROM pg_class 
        WHERE relname = '%s' 
        AND relnamespace = (
          SELECT oid 
          FROM pg_catalog.pg_namespace 
          WHERE nspname = '%s')
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
            WHERE schemaname = '%s'
            AND relname = '%s')) ]
       )""" % (relname, schemaname, schemaname, relname))
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


ALTER FUNCTION get_pk_fields(oid) OWNER TO postgres;

------
------ usage
------

create table parent(
   tpl_uid text unique not null,
   tpl_fqtn text not null,
   a text primary key
);

--
-- Name: before_insert_tuple; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER before_insert_tuple
    BEFORE INSERT ON parent
    FOR EACH ROW
    EXECUTE PROCEDURE before_insert_tuple();

--
-- Name: before_update_tuple; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER before_update_tuple
    BEFORE UPDATE ON parent
    FOR EACH ROW
    EXECUTE PROCEDURE before_update_tuple();

--
-- Name: after_delete_tuple; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER after_delete_tuple
    AFTER DELETE ON parent
    FOR EACH ROW
    EXECUTE PROCEDURE after_delete_tuple();

create table child(
   tpl_uid text unique not null,
   b text,
   primary key(a, b)
) inherits(parent);

--
-- Name: before_insert_tuple; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER before_insert_tuple
    BEFORE INSERT ON child
    FOR EACH ROW
    EXECUTE PROCEDURE before_insert_tuple();

--
-- Name: before_update_tuple; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER before_update_tuple
    BEFORE UPDATE ON child
    FOR EACH ROW
    EXECUTE PROCEDURE before_update_tuple();

--
-- Name: after_delete_tuple; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER after_delete_tuple
    AFTER DELETE ON child
    FOR EACH ROW
    EXECUTE PROCEDURE after_delete_tuple();
