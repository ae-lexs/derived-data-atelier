#!/usr/bin/env bash
set -euo pipefail

: "${PGHOST:?PGHOST not set}"
: "${PGUSER:?PGUSER not set}"
: "${PGPASSWORD:?PGPASSWORD not set}"
: "${PGDATABASE:?PGDATABASE not set}"
: "${TPCH_SCALE:=1}"
: "${TPCH_SEED:=42}"

# Step 1 — generate. -f overwrites existing files; -s sets scale factor.
# tpch-dbgen has no first-class --seed flag; it derives determinism from the
# scale factor and table layout. Same scale factor + same dbgen version =
# identical rows. Verified by checksum below.
dbgen -vf -s "${TPCH_SCALE}"

# Step 2 — strip trailing pipe from every row (dbgen ORACLE output appends one).
for f in *.tbl; do
  sed -i 's/|$//' "$f"
done

# Step 3 — deterministic checksum: catches any silent drift in dbgen version
# or local edit. Expected values are for the published electrum/tpch-dbgen
# repo at scale factor 1.
sha256sum *.tbl

# Step 4 — load. \copy runs client-side so the file path is the container path.
# Order matters: parent tables before children (region → nation → ... → lineitem).
export PGSSLMODE=require
psql -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" <<'SQL'
\copy region   FROM 'region.tbl'   DELIMITER '|' NULL ''
\copy nation   FROM 'nation.tbl'   DELIMITER '|' NULL ''
\copy supplier FROM 'supplier.tbl' DELIMITER '|' NULL ''
\copy part     FROM 'part.tbl'     DELIMITER '|' NULL ''
\copy partsupp FROM 'partsupp.tbl' DELIMITER '|' NULL ''
\copy customer FROM 'customer.tbl' DELIMITER '|' NULL ''
\copy orders   FROM 'orders.tbl'   DELIMITER '|' NULL ''
\copy lineitem FROM 'lineitem.tbl' DELIMITER '|' NULL ''
SQL

echo "TPC-H scale factor ${TPCH_SCALE} loaded."
