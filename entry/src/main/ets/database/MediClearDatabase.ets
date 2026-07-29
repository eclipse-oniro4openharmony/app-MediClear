import { Context } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { MediClearDBConfig } from './MediClearDBConfig';
import { RplSeedData } from './RplSeedData';
import { rplRecordToBucket } from './RplMedicineMapper';
import { RplMedicineRecord } from './RplMedicineRecord';

export class MediClearDatabase {
  private static instance: MediClearDatabase | null = null;
  private store: relationalStore.RdbStore;

  private constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  static async getInstance(context: Context): Promise<MediClearDatabase> {
    if (MediClearDatabase.instance === null) {
      const store = await relationalStore.getRdbStore(context, MediClearDBConfig.STORE_CONFIG);
      await store.executeSql(MediClearDBConfig.RPL_TABLE.sqlCreate);
      await store.executeSql(MediClearDBConfig.SEARCH_INDEX_SQL);
      const database = new MediClearDatabase(store);
      await database.seedRplProducts();
      MediClearDatabase.instance = database;
    }
    return MediClearDatabase.instance;
  }

  getStore(): relationalStore.RdbStore {
    return this.store;
  }

  private async seedRplProducts(): Promise<void> {
    const records: RplMedicineRecord[] = RplSeedData.getRecords();
    for (let index = 0; index < records.length; index++) {
      await this.store.insert(
        MediClearDBConfig.RPL_TABLE.tableName,
        rplRecordToBucket(records[index]),
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
      );
    }
  }
}
