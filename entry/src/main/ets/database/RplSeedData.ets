import { RplMedicineRecord } from './RplMedicineRecord';

export class RplSeedData {
  static getRecords(): RplMedicineRecord[] {
    const espumisan = new RplMedicineRecord();
    espumisan.id = 2268;
    espumisan.rplIdentifier = '100022688';
    espumisan.name = 'Espumisan';
    espumisan.commonName = 'Simeticonum';
    espumisan.strength = '40 mg';
    espumisan.dosageForm = 'Kapsulki';
    espumisan.packageInfo = '05909990168712 | OTC | 25 capsules\n05909990168729 | OTC | 100 capsules';
    espumisan.activeSubstance = 'Simeticonum 40 mg';
    espumisan.leafletUrl = 'https://rejestry.ezdrowie.gov.pl/api/rpl/medicinal-products/2268/leaflet';
    espumisan.characteristicUrl = 'https://rejestry.ezdrowie.gov.pl/api/rpl/medicinal-products/2268/characteristic';
    espumisan.searchText = 'espumisan simeticonum simethicone 40 mg kapsulki capsules 05909990168712 otc';

    const milurit = new RplMedicineRecord();
    milurit.id = 4394;
    milurit.rplIdentifier = 'RPL-MILURIT-100MG';
    milurit.name = 'Milurit';
    milurit.commonName = 'Allopurinolum';
    milurit.strength = '100 mg';
    milurit.dosageForm = 'Tabletki';
    milurit.packageInfo = '05909990163212 | Rp | 6572\nRp | 7132\n05909991332860 | Rp | 122591';
    milurit.activeSubstance = 'Allopurinolum 100 mg';
    milurit.leafletUrl = 'https://rejestry.ezdrowie.gov.pl/api/rpl/medicinal-products/4394/leaflet';
    milurit.characteristicUrl = 'https://rejestry.ezdrowie.gov.pl/api/rpl/medicinal-products/4394/characteristic';
    milurit.searchText = 'milurit allopurinol allopurinolum 100 mg tabletki tablets';

    const ibuprofen = new RplMedicineRecord();
    ibuprofen.id = 11880;
    ibuprofen.rplIdentifier = '100118805';
    ibuprofen.name = 'Ibuprofen';
    ibuprofen.commonName = 'Ibuprofenum';
    ibuprofen.strength = '200 mg';
    ibuprofen.dosageForm = 'Tabletki';
    ibuprofen.packageInfo = 'Ibuprofen 200 mg tablets';
    ibuprofen.activeSubstance = 'Ibuprofenum 200 mg';
    ibuprofen.leafletUrl = 'https://rejestry.ezdrowie.gov.pl/api/rpl/medicinal-products/11880/leaflet';
    ibuprofen.characteristicUrl = 'https://rejestry.ezdrowie.gov.pl/api/rpl/medicinal-products/11880/characteristic';
    ibuprofen.searchText = 'ibuprofen ibuprofenum 200 mg tabletki tablets pain fever nsaid';

    return [espumisan, milurit, ibuprofen];
  }
}
