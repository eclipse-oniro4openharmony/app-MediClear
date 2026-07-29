import sqlite3
import sys


query = (sys.argv[1] if len(sys.argv) > 1 else "milurit").lower()
con = sqlite3.connect("data/rpl_seed.sqlite")
con.row_factory = sqlite3.Row
rows = con.execute(
    """
    select id, rpl_identifier, name, common_name, strength, dosage_form,
           leaflet_url, characteristic_url, package_info
    from rpl_products
    where lower(name) like ? or lower(common_name) like ? or lower(search_text) like ?
    limit 50
    """,
    (f"%{query}%", f"%{query}%", f"%{query}%"),
).fetchall()
for row in rows:
    print(dict(row))
