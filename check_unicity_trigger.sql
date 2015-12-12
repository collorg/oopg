-- Copyright (c) 2015 Joël Maïzi <joel.maizi@lirmm.fr>
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.


CREATE FUNCTION check_unicity()
    RETURNS trigger
AS $$
from datetime import datetime
begin = datetime.now()
from sys import stderr

trace = False

def log(message):
    stderr.write(message)

def get_pk_fields(oid):
    """Return a list of the field names of the primary key.
    """
    trace and log("{} get_pk_fields({})\n".format(8*'=', oid))
    res = plpy.execute("""
        select distinct
            c.oid,
            array_agg(distinct a.attname::text) AS fieldnames
        from
            pg_class c
            left join pg_attribute a on
            c.oid = {} and
            a.attrelid = c.oid
            join pg_type pt on
            a.atttypid = pt.oid
            join pg_constraint cn_pk on
            cn_pk.conrelid = c.oid and
            (cn_pk.contype = 'p' or cn_pk.contype = 'u') and
            a.attnum = any( cn_pk.conkey )
        where
            c.relkind = 'r'::"char"
        group by
            c.oid, cn_pk.conname""".format(oid))
    l_fieldnames = [elt['fieldnames'] for elt in res]
    trace and log("pk_fields: {}\n".format(l_fieldnames))
    trace and log("get_pk_fields duration: {}\n".format(datetime.now() - begin))
    return l_fieldnames

def get_parents(relid):
    """Return the list of the oids if any of the parents.
    """
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
    """Return False if the key is found in any of the parents, True otherwise.
    """
    from psycopg2.extensions import adapt

    trace and log("{} check_pk_oid({})\n".format(8*'=', oid))
    parent_oids = get_parents(oid)
    trace and log("oid du parent {}\n".format(parent_oids))
    for parent_oid in parent_oids:
        # recurse on parent_oid
        if not check_pk_oid(parent_oid):
            return False
    ok = True
    for pk_fieldnames in get_pk_fields(oid):
        if not pk_fieldnames:
            trace and log(
                "check_pk_oid duration ok 1: {}\n".format(
                    datetime.now() - begin))
            continue

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
            trace and log("No change on constraint!\n")
            continue
        # FQTN: fully qualified table name (in the database)
        rec_fqtn = plpy.execute("""
            SELECT schemaname, relname
            FROM pg_catalog.pg_stat_all_tables
            WHERE relid = {}""".format(oid))[0]
        fqtn = '"{}"."{}"'.format(rec_fqtn['schemaname'], rec_fqtn['relname'])
        req = "SELECT 1 FROM {} WHERE {} limit 1".format(
            fqtn, ' and '.join(clause))
        trace and log("check_pk_oid: {}\n".format(req))
        if len(plpy.execute(req)) == 1:
            trace and log("DUPLICATE KEY\n")
            trace and log(
                "check_pk_oid duration: {}\n".format(datetime.now() - begin))
            ok = False
            break

        trace and log(
            "check_pk_oid duration ok 2: {}\n".format(datetime.now() - begin))
    return ok

ok = check_pk_oid(TD['relid'])
trace and log("check_pk duration: {}\n".format(datetime.now() - begin))
if not ok:
    return 'SKIP'
$$ LANGUAGE plpythonu;
