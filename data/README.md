# Local RPL Medicine Index

This folder contains the local medicine lookup data used by MediClear.

## Files

- `rpl_seed.sqlite` - SQLite seed database generated from the official Polish RPL XML export.

The current seed database contains 22,822 medicine records imported from the full official XML export. Each product row stores the official `ulotka` and `charakterystyka` PDF endpoints when they are present in the XML.

## Official Source

Official RPL dataset page:

`https://dane.gov.pl/pl/dataset/397,rejestr-produktow-leczniczych`

Official full XML export:

`https://rejestry.ezdrowie.gov.pl/api/rpl/medicinal-products/public-pl-report/6.0.0/overall.xml`

The XML product rows include fields such as medicine name, common name, strength, dosage form, GTIN/package data, active substances, permit number, `ulotka`, and `charakterystyka`.

## Sync Workflow

Download the latest official XML and refresh the local SQLite seed database:

```bash
python tools/rpl_sync.py --format xml --download --import
```

Search the local database:

```bash
python tools/rpl_sync.py --search Espumisan "40 mg" kapsu
```

CSV import is still supported for fallback/testing:

```bash
python tools/rpl_sync.py --format csv --download --import
```

## App Lookup Strategy

1. OCR extracts text from a package photo or leaflet.
2. The app searches the local SQLite index first by GTIN, medicine name, active substance, strength, and package text.
3. If a matching row exists, the app uses the row's official `leaflet_url` or `characteristic_url`.
4. If no matching row exists, the backend can download the latest RPL XML, import it, and update the local cache.
