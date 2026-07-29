import argparse
import csv
import sqlite3
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

RPL_CSV_URL = "https://api.dane.gov.pl/resources/65520,wykaz-produktow-leczniczych-plik-w-formacie-csv/file"
RPL_XML_URL = "https://rejestry.ezdrowie.gov.pl/api/rpl/medicinal-products/public-pl-report/6.0.0/overall.xml"

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CSV = ROOT / "rpl-products.csv"
DEFAULT_XML = ROOT / "rpl-products.xml"
DEFAULT_DB = ROOT / "data" / "rpl_seed.sqlite"


def download_csv(target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    print(f"Downloading RPL CSV -> {target}")
    urllib.request.urlretrieve(RPL_CSV_URL, target)


def download_xml(target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    print(f"Downloading RPL XML -> {target}")
    urllib.request.urlretrieve(RPL_XML_URL, target)


def connect_database(path: Path) -> sqlite3.Connection:
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS rpl_products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            rpl_identifier TEXT NOT NULL,
            name TEXT NOT NULL,
            common_name TEXT,
            medicine_type TEXT,
            route TEXT,
            strength TEXT,
            dosage_form TEXT,
            procedure_type TEXT,
            permit_number TEXT,
            permit_validity TEXT,
            atc_code TEXT,
            responsible_entity TEXT,
            package_info TEXT,
            active_substance TEXT,
            manufacturer TEXT,
            manufacturer_country TEXT,
            leaflet_url TEXT,
            characteristic_url TEXT,
            parallel_leaflet_url TEXT,
            source_date TEXT,
            search_text TEXT NOT NULL
        )
        """
    )
    conn.execute("CREATE INDEX IF NOT EXISTS idx_rpl_name ON rpl_products(name)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_rpl_common_name ON rpl_products(common_name)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_rpl_strength ON rpl_products(strength)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_rpl_atc ON rpl_products(atc_code)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_rpl_search ON rpl_products(search_text)")
    return conn


def row_text(row: dict[str, str]) -> str:
    return " ".join(value for value in row.values() if value).lower()


def should_import(row: dict[str, str], keywords: list[str]) -> bool:
    if not keywords:
        return True
    text = row_text(row)
    return any(keyword.lower() in text for keyword in keywords)


def import_csv(csv_path: Path, db_path: Path, keywords: list[str], limit: int) -> int:
    conn = connect_database(db_path)
    conn.execute("DELETE FROM rpl_products")

    inserted = 0
    with csv_path.open("r", encoding="utf-8-sig", newline="") as file:
        reader = csv.DictReader(file, delimiter=";")
        for row in reader:
            if not should_import(row, keywords):
                continue
            values = {
                "rpl_identifier": row.get("Identyfikator Produktu Leczniczego", ""),
                "name": row.get("Nazwa Produktu Leczniczego", ""),
                "common_name": row.get("Nazwa powszechnie stosowana", ""),
                "medicine_type": row.get("Rodzaj preparatu", ""),
                "route": row.get("Droga podania - Gatunek - Tkanka - Okres karencji", ""),
                "strength": row.get("Moc", ""),
                "dosage_form": row.get("Postać farmaceutyczna", ""),
                "procedure_type": row.get("Typ procedury", ""),
                "permit_number": row.get("Numer pozwolenia", ""),
                "permit_validity": row.get("Ważność pozwolenia", ""),
                "atc_code": row.get("Kod ATC", ""),
                "responsible_entity": row.get("Podmiot odpowiedzialny", ""),
                "package_info": row.get("Opakowanie", ""),
                "active_substance": row.get("Substancja czynna", ""),
                "manufacturer": row.get("Nazwa wytwórcy", ""),
                "manufacturer_country": row.get("Kraj wytwórcy", ""),
                "leaflet_url": row.get("Ulotka", ""),
                "characteristic_url": row.get("Charakterystyka", ""),
                "parallel_leaflet_url": row.get("Ulotka importu równoległego", ""),
                "source_date": "",
            }
            values["search_text"] = " ".join(str(value) for value in values.values()).lower()
            conn.execute(
                """
                INSERT INTO rpl_products (
                    rpl_identifier, name, common_name, medicine_type, route, strength,
                    dosage_form, procedure_type, permit_number, permit_validity, atc_code,
                    responsible_entity, package_info, active_substance, manufacturer,
                    manufacturer_country, leaflet_url, characteristic_url,
                    parallel_leaflet_url, source_date, search_text
                ) VALUES (
                    :rpl_identifier, :name, :common_name, :medicine_type, :route, :strength,
                    :dosage_form, :procedure_type, :permit_number, :permit_validity, :atc_code,
                    :responsible_entity, :package_info, :active_substance, :manufacturer,
                    :manufacturer_country, :leaflet_url, :characteristic_url,
                    :parallel_leaflet_url, :source_date, :search_text
                )
                """,
                values,
            )
            inserted += 1
            if limit > 0 and inserted >= limit:
                break

    conn.commit()
    conn.close()
    print(f"Imported {inserted} rows -> {db_path}")
    return inserted


def attr_any(element: ET.Element, names: list[str]) -> str:
    for name in names:
        value = element.attrib.get(name)
        if value:
            return value.strip()
    return ""


def children_text(element: ET.Element, tag_keywords: list[str]) -> str:
    values: list[str] = []
    for child in element.iter():
        tag = child.tag.split("}")[-1].lower()
        if any(keyword in tag for keyword in tag_keywords):
            text = " ".join(part.strip() for part in child.itertext() if part.strip())
            if text:
                values.append(text)
    return "\n".join(dict.fromkeys(values))


def children_attrs_text(element: ET.Element, tag_name: str, attr_names: list[str]) -> str:
    values: list[str] = []
    for child in element.iter():
        tag = child.tag.split("}")[-1]
        if tag != tag_name:
            continue
        parts: list[str] = []
        for attr_name in attr_names:
            value = child.attrib.get(attr_name)
            if value:
                parts.append(value.strip())
        if parts:
            values.append(" | ".join(parts))
    return "\n".join(dict.fromkeys(values))


def is_product_node(element: ET.Element) -> bool:
    return element.tag.split("}")[-1] == "produktLeczniczy"


def import_xml(xml_path: Path, db_path: Path, keywords: list[str], limit: int) -> int:
    conn = connect_database(db_path)
    conn.execute("DELETE FROM rpl_products")

    inserted = 0
    for event, element in ET.iterparse(xml_path, events=("end",)):
        if not is_product_node(element):
            continue

        values = {
            "rpl_identifier": attr_any(element, ["id", "identyfikator", "identyfikatorProduktuLeczniczego"]),
            "name": attr_any(element, ["nazwaProduktu", "nazwa", "nazwaProduktuLeczniczego", "produktLeczniczyNazwa"]),
            "common_name": attr_any(element, ["nazwaPowszechnieStosowana", "nazwa_powszechnie_stosowana"]),
            "medicine_type": attr_any(element, ["rodzajPreparatu", "rodzaj_preparatu"]),
            "route": attr_any(element, ["drogaPodania", "droga_podania"]),
            "strength": attr_any(element, ["moc"]),
            "dosage_form": attr_any(element, ["nazwaPostaciFarmaceutycznej", "postac", "postać", "postacFarmaceutyczna", "postaćFarmaceutyczna"]),
            "procedure_type": attr_any(element, ["typProcedury", "typ_procedury"]),
            "permit_number": attr_any(element, ["numerPozwolenia", "pozwolenie"]),
            "permit_validity": attr_any(element, ["waznoscPozwolenia", "ważnośćPozwolenia"]),
            "atc_code": children_text(element, ["kodatc"]) or attr_any(element, ["kodATC", "atc"]),
            "responsible_entity": attr_any(element, ["podmiotOdpowiedzialny"]),
            "package_info": children_attrs_text(element, "opakowanie", ["kodGTIN", "kategoriaDostepnosci", "id"]),
            "active_substance": children_attrs_text(element, "substancjaCzynna", ["nazwaSubstancji", "iloscSubstancji", "jednostkaMiaryIlosciSubstancji"]),
            "manufacturer": children_attrs_text(element, "wytworcy", ["nazwaWytworcyImportera"]),
            "manufacturer_country": children_attrs_text(element, "wytworcy", ["krajWytworcyImportera"]),
            "leaflet_url": attr_any(element, ["ulotka"]),
            "characteristic_url": attr_any(element, ["charakterystyka"]),
            "parallel_leaflet_url": attr_any(element, ["ulotkaImportuRownoleglego", "ulotkaImportuRównoległego"]),
            "source_date": attr_any(element, ["stanNaDzien", "data"]),
        }
        values["search_text"] = " ".join(str(value) for value in values.values()).lower()

        if not values["name"] or not should_import(values, keywords):
            element.clear()
            continue

        conn.execute(
            """
            INSERT INTO rpl_products (
                rpl_identifier, name, common_name, medicine_type, route, strength,
                dosage_form, procedure_type, permit_number, permit_validity, atc_code,
                responsible_entity, package_info, active_substance, manufacturer,
                manufacturer_country, leaflet_url, characteristic_url,
                parallel_leaflet_url, source_date, search_text
            ) VALUES (
                :rpl_identifier, :name, :common_name, :medicine_type, :route, :strength,
                :dosage_form, :procedure_type, :permit_number, :permit_validity, :atc_code,
                :responsible_entity, :package_info, :active_substance, :manufacturer,
                :manufacturer_country, :leaflet_url, :characteristic_url,
                :parallel_leaflet_url, :source_date, :search_text
            )
            """,
            values,
        )
        inserted += 1
        element.clear()
        if limit > 0 and inserted >= limit:
            break

    conn.commit()
    conn.close()
    print(f"Imported {inserted} rows -> {db_path}")
    return inserted


def search(db_path: Path, terms: list[str]) -> None:
    conn = connect_database(db_path)
    clauses = ["search_text LIKE ?" for _ in terms]
    params = [f"%{term.lower()}%" for term in terms]
    sql = (
        "SELECT name, common_name, strength, dosage_form, package_info, leaflet_url, characteristic_url "
        "FROM rpl_products"
    )
    if clauses:
        sql += " WHERE " + " AND ".join(clauses)
    sql += " LIMIT 20"
    rows = conn.execute(sql, params).fetchall()
    for index, row in enumerate(rows, start=1):
        print(f"\n--- result {index} ---")
        print(f"name: {row[0]}")
        print(f"common_name: {row[1]}")
        print(f"strength: {row[2]}")
        print(f"dosage_form: {row[3]}")
        print(f"package: {row[4]}")
        print(f"leaflet_url: {row[5]}")
        print(f"characteristic_url: {row[6]}")
    conn.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Sync official Polish RPL medicine data into SQLite.")
    parser.add_argument("--csv", type=Path, default=DEFAULT_CSV)
    parser.add_argument("--xml", type=Path, default=DEFAULT_XML)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--download", action="store_true")
    parser.add_argument("--format", choices=["csv", "xml"], default="xml")
    parser.add_argument("--import", dest="do_import", action="store_true")
    parser.add_argument("--keyword", action="append", default=[])
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--search", nargs="*", default=None)
    args = parser.parse_args()

    if args.download:
        if args.format == "xml":
            download_xml(args.xml)
        else:
            download_csv(args.csv)
    if args.do_import:
        if args.format == "xml":
            import_xml(args.xml, args.db, args.keyword, args.limit)
        else:
            import_csv(args.csv, args.db, args.keyword, args.limit)
    if args.search is not None:
        search(args.db, args.search)


if __name__ == "__main__":
    main()
