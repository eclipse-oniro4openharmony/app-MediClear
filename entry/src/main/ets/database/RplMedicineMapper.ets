import { relationalStore } from '@kit.ArkData';
import { RplMedicineRecord } from './RplMedicineRecord';

export function rplRecordToBucket(record: RplMedicineRecord): relationalStore.ValuesBucket {
  const bucket: relationalStore.ValuesBucket = {};
  bucket.id = record.id;
  bucket.rpl_identifier = record.rplIdentifier;
  bucket.name = record.name;
  bucket.common_name = record.commonName;
  bucket.strength = record.strength;
  bucket.dosage_form = record.dosageForm;
  bucket.package_info = record.packageInfo;
  bucket.active_substance = record.activeSubstance;
  bucket.leaflet_url = record.leafletUrl;
  bucket.characteristic_url = record.characteristicUrl;
  bucket.search_text = record.searchText;
  return bucket;
}

export function resultSetToRplRecords(resultSet: relationalStore.ResultSet): RplMedicineRecord[] {
  const records: RplMedicineRecord[] = [];
  while (resultSet.goToNextRow()) {
    const record = new RplMedicineRecord();
    record.id = resultSet.getLong(resultSet.getColumnIndex('id'));
    record.rplIdentifier = resultSet.getString(resultSet.getColumnIndex('rpl_identifier'));
    record.name = resultSet.getString(resultSet.getColumnIndex('name'));
    record.commonName = resultSet.getString(resultSet.getColumnIndex('common_name'));
    record.strength = resultSet.getString(resultSet.getColumnIndex('strength'));
    record.dosageForm = resultSet.getString(resultSet.getColumnIndex('dosage_form'));
    record.packageInfo = resultSet.getString(resultSet.getColumnIndex('package_info'));
    record.activeSubstance = resultSet.getString(resultSet.getColumnIndex('active_substance'));
    record.leafletUrl = resultSet.getString(resultSet.getColumnIndex('leaflet_url'));
    record.characteristicUrl = resultSet.getString(resultSet.getColumnIndex('characteristic_url'));
    record.searchText = resultSet.getString(resultSet.getColumnIndex('search_text'));
    records.push(record);
  }
  return records;
}
