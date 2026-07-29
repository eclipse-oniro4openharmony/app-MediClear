import sqlite3
import sys


db_path = sys.argv[1] if len(sys.argv) > 1 else "data/rpl_seed.sqlite"
lookup = sys.argv[2] if len(sys.argv) > 2 else "30925"

con = sqlite3.connect(db_path)
con.row_factory = sqlite3.Row

tables = [row[0] for row in con.execute("select name from sqlite_master where type='table'")]
print("tables:", tables)

for table in tables:
    columns = [row[1] for row in con.execute(f"pragma table_info({table})")]
    print("table:", table)
    print("columns:", columns)
    id_columns = [name for name in columns if name.lower() in ("id", "product_id", "productid", "rpl_product_id")]
    text_columns = [name for name in columns if name.lower() in ("leaflet_url", "leafleturl", "characteristic_url", "characteristicurl", "name", "product_name")]
    for column in id_columns:
        try:
            rows = con.execute(f"select * from {table} where {column} = ? limit 5", (lookup,)).fetchall()
        except sqlite3.Error as error:
            print("query error:", table, column, error)
            continue
        for row in rows:
            print("match by", column)
            for key in row.keys():
                print(f"  {key}: {row[key]}")
    for column in text_columns:
        if column.lower() in ("leaflet_url", "leafleturl", "characteristic_url", "characteristicurl"):
            try:
                rows = con.execute(f"select * from {table} where {column} like ? limit 5", (f"%/{lookup}/%",)).fetchall()
            except sqlite3.Error:
                continue
            for row in rows:
                print("match by url", column)
                for key in row.keys():
                    print(f"  {key}: {row[key]}")
