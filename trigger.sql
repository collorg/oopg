create language plpythonu;

CREATE FUNCTION check_pk()
    RETURNS trigger
AS $$
from datetime import datetime
begin = datetime.now()
from sys import stderr
trace = False
def log(message):
    stderr.write(message)

def get_pk_fields(oid):
    """
    Return the field names in the primary key
    """
    trace and log("{} get_pk_fields({})\n".format(8*'=', oid))
    l_fieldnames = plpy.execute("""
    SELECT
        array_agg(distinct a.attname::varchar) AS fieldnames,
        cn_pk.contype AS pkey
    FROM
        pg_class c -- table
        LEFT JOIN pg_attribute a ON
        a.attrelid = c.oid and
        c.oid = {}
    --    JOIN pg_type pt ON
    --    a.atttypid = pt.oid
    --    LEFT JOIN pg_constraint cn_uniq ON
    --    cn_uniq.contype = 'u' AND
    --    cn_uniq.conrelid = a.attrelid AND
    --    a.attnum = ANY( cn_uniq.conkey )
        JOIN pg_constraint cn_pk ON
        cn_pk.contype = 'p' AND
        cn_pk.conrelid = a.attrelid AND
        a.attnum = ANY( cn_pk.conkey )
    WHERE
        c.relkind = 'r'::"char"
    GROUP BY
        cn_pk.contype""".format(oid))[0]['fieldnames']
    trace and log("pk_fields: {}\n".format(l_fieldnames))
    trace and log("get_pk_fields duration: {}\n".format(datetime.now() - begin))
    return set(l_fieldnames)

def get_parents(relid):
    """Return the list of the oids if any of the parents."""
    trace and log("{} get_parents({})\n".format(8*'=', relid))
    query = (
        "SELECT inhparent FROM pg_catalog.pg_inherits "
        "WHERE inhrelid = {}".format(relid))
    trace and log('get_parents: {}\n'.format(query))
    rec = plpy.execute(query)
    res = []
    if len(rec):
        res = [elt['inhparent'] for elt in rec]
    trace and log("get_parents duration: {}\n".format(datetime.now() - begin))
    return res

def check_pk_oid(oid):
    """Return False if the key is found in any of the parents."""
    from psycopg2.extensions import adapt

    trace and log("{} check_pk_oid({})\n".format(8*'=', oid))
    parent_oids = get_parents(oid)
    trace and log("oid du parent {}\n".format(parent_oids))
    for parent_oid in parent_oids:
        # recurse on parent_oid
        if not check_pk_oid(parent_oid):
            return False
    pk_fieldnames = get_pk_fields(oid)
    if not pk_fieldnames:
        trace and log(
            "check_pk_oid duration ok 1: {}\n".format(datetime.now() - begin))
        return True

    # Clause for the SELECT request
    clause = []
    for field in pk_fieldnames:
        if TD['old'] is not None:
            if TD['old'][field] == TD['new'][field]:
                continue
        if TD['new'][field] == 0:
            valeur = 0
        else:
            valeur = TD['new'][field] or ""
            valeur = adapt(valeur)
        clause.append("{} = {}".format(field, str(valeur)))

    if not clause:
        trace and log("NOTHING HAS CHANGED!\n")
        return True
    # FQTN: fully qualified table name (in the database)
    rec_fqtn = plpy.execute("""
        SELECT schemaname, relname
        FROM pg_catalog.pg_stat_all_tables
        WHERE relid = {}""".format(oid))[0]
    fqtn = "{}.{}".format(rec_fqtn['schemaname'], rec_fqtn['relname'])
    req = "SELECT 1 FROM {} WHERE {} limit 1".format(fqtn, ' and '.join(clause))
    trace and log("check_pk_oid: {}\n".format(req))
    if len(plpy.execute(req)) == 1:
        trace and log("DUPLICATE KEY\n")
        trace and log(
            "check_pk_oid duration: {}\n".format(datetime.now() - begin))
        return False

    trace and log(
        "check_pk_oid duration ok 2: {}\n".format(datetime.now() - begin))
    return True

ok = check_pk_oid(TD['relid'])
trace and log("check_pk duration: {}\n".format(datetime.now() - begin))
if not ok:
    return 'SKIP'
$$ LANGUAGE plpythonu;
