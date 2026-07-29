import { relationalStore } from '@kit.ArkData';

export class RplTableConfig {
  tableName: string = '';
  sqlCreate: string = '';
  columns: string[] = [];
}

export class MediClearDBConfig {
  static readonly STORE_CONFIG: relationalStore.StoreConfig = {
    name: 'mediclear_rpl.db',
    securityLevel: relationalStore.SecurityLevel.S1
  };

  static readonly RPL_TABLE: RplTableConfig = {
    tableName: 'rpl_products',
    sqlCreate: 'CREATE TABLE IF NOT EXISTS rpl_products(' +
      'id INTEGER PRIMARY KEY,' +
      'rpl_identifier TEXT NOT NULL UNIQUE,' +
      'name TEXT NOT NULL,' +
      'common_name TEXT,' +
      'strength TEXT,' +
      'dosage_form TEXT,' +
      'package_info TEXT,' +
      'active_substance TEXT,' +
      'leaflet_url TEXT,' +
      'characteristic_url TEXT,' +
      'search_text TEXT NOT NULL)',
    columns: [
      'id', 'rpl_identifier', 'name', 'common_name', 'strength', 'dosage_form',
      'package_info', 'active_substance', 'leaflet_url', 'characteristic_url', 'search_text'
    ]
  };

  static readonly SEARCH_INDEX_SQL: string =
    'CREATE INDEX IF NOT EXISTS idx_rpl_products_search ON rpl_products(search_text)';
}
