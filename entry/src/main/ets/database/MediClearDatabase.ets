import { Context } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { MediClearDBConfig } from './MediClearDBConfig';
import { RplSeedData } from './RplSeedData';
import { rplRecordToBucket } from './RplMedicineMapper';
import { RplMedicineRecord } from './RplMedicineRecord';
import { RplPrebuiltDatabase } from './RplPrebuiltDatabase';

export class MediClearDatabase {
  private static instance: MediClearDatabase | null = null;
  private store: relationalStore.RdbStore;

  private constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  static async getInstance(context: Context): Promise<MediClearDatabase> {
    if (MediClearDatabase.instance === null) {
      const store = await MediClearDatabase.openRplStore(context);
      const database = new MediClearDatabase(store);
      MediClearDatabase.instance = database;
    }
    return MediClearDatabase.instance;
  }

  private static async openRplStore(context: Context): Promise<relationalStore.RdbStore> {
    try {
      return await RplPrebuiltDatabase.open(context);
    } catch (err) {
      console.error('[MediClearRPL] full prebuilt RPL database unavailable, using seed records: ' + JSON.stringify(err));
      const store = await relationalStore.getRdbStore(context, MediClearDBConfig.STORE_CONFIG);
      await store.executeSql(MediClearDBConfig.RPL_TABLE.sqlCreate);
      await store.executeSql(MediClearDBConfig.SEARCH_INDEX_SQL);
      const database = new MediClearDatabase(store);
      await database.seedRplProducts();
      return store;
    }
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
