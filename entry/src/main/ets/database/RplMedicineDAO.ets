import { relationalStore } from '@kit.ArkData';
import { MediClearDBConfig } from './MediClearDBConfig';
import { RplMedicineRecord } from './RplMedicineRecord';
import { resultSetToRplRecords } from './RplMedicineMapper';

export class RplMedicineDAO {
  private store: relationalStore.RdbStore;

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  async searchByOcrText(ocrText: string): Promise<RplMedicineRecord[]> {
    const terms: string[] = this.extractSearchTerms(ocrText);
    if (terms.length === 0) {
      return [];
    }

    const predicates = new relationalStore.RdbPredicates(MediClearDBConfig.RPL_TABLE.tableName);
    for (let index = 0; index < terms.length; index++) {
      predicates.like('search_text', '%' + terms[index] + '%');
    }
    predicates.limitAs(10);

    const resultSet = await this.store.query(predicates, MediClearDBConfig.RPL_TABLE.columns);
    const records = resultSetToRplRecords(resultSet);
    resultSet.close();
    return records;
  }

  private extractSearchTerms(text: string): string[] {
    const normalized = text.toLowerCase()
      .replace(',', ' ')
      .replace('.', ' ')
      .replace('-', ' ');
    const rawTokens = normalized.split(' ');
    const terms: string[] = [];

    for (let index = 0; index < rawTokens.length; index++) {
      const token = rawTokens[index].trim();
      if (token.length < 2) {
        continue;
      }
      if (token === 'mg' || token === 'g' || token === 'ml') {
        continue;
      }
      if (terms.indexOf(token) < 0) {
        terms.push(token);
      }
      if (terms.length >= 4) {
        break;
      }
    }
    return terms;
  }
}
