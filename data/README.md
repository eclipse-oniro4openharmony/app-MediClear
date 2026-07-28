# Local RPL Medicine Index

This folder contains the local medicine lookup data used by MediClear.

## Files

- `rpl_seed.sqlite` - a small SQLite seed database generated from the official Polish RPL source CSV.

The seed database is intentionally small and is suitable for prototype lookup. The full official CSV is not committed because it is large and changes daily.

## Official Source

Official dataset:

`https://dane.gov.pl/pl/dataset/397,rejestr-produktow-leczniczych`

CSV download endpoint:

`https://api.dane.gov.pl/resources/65520,wykaz-produktow-leczniczych-plik-w-formacie-csv/file`

## Sync Workflow

Download the latest official CSV:

```bash
python tools/rpl_sync.py --download
```

Build or refresh the small prototype seed database:

```bash
python tools/rpl_sync.py --import --keyword Espumisan --keyword Ibuprofen --keyword Paracetamol --limit 300
```

Search the local database:

```bash
python tools/rpl_sync.py --search Espumisan "40 mg" Kapsułki
```

## App Lookup Strategy

1. OCR extracts text from a package photo.
2. The app searches the local SQLite index first.
3. If a matching row exists, the app uses `leaflet_url` or `characteristic_url`.
4. If no matching row exists, the backend can download the latest RPL CSV, import the missing medicine row, and update the local cache.
