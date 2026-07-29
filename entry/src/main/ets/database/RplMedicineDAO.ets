import { relationalStore } from '@kit.ArkData';
import { MediClearDBConfig } from './MediClearDBConfig';
import { RplMedicineRecord } from './RplMedicineRecord';
import { resultSetToRplRecords } from './RplMedicineMapper';

class RplScoredRecord {
  record: RplMedicineRecord;
  score: number;

  constructor(record: RplMedicineRecord, score: number) {
    this.record = record;
    this.score = score;
  }
}

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

    const candidates: RplMedicineRecord[] = [];
    for (let index = 0; index < terms.length; index++) {
      const predicates = new relationalStore.RdbPredicates(MediClearDBConfig.RPL_TABLE.tableName);
      predicates.like('search_text', '%' + terms[index] + '%');
      predicates.limitAs(20);

      const resultSet = await this.store.query(predicates, MediClearDBConfig.RPL_TABLE.columns);
      const records = resultSetToRplRecords(resultSet);
      resultSet.close();
      this.appendUniqueRecords(candidates, records);
    }

    const scored: RplScoredRecord[] = [];
    for (let index = 0; index < candidates.length; index++) {
      const score = this.scoreRecord(candidates[index], terms);
      if (score > 0) {
        scored.push(new RplScoredRecord(candidates[index], score));
      }
    }
    scored.sort((left: RplScoredRecord, right: RplScoredRecord) => right.score - left.score);

    const matches: RplMedicineRecord[] = [];
    for (let index = 0; index < scored.length && index < 10; index++) {
      matches.push(scored[index].record);
    }
    return matches;
  }

  private extractSearchTerms(text: string): string[] {
    const normalized = text.toLowerCase()
      .replace(',', ' ')
      .replace('.', ' ')
      .replace('-', ' ')
      .replace('/', ' ')
      .replace(':', ' ')
      .replace(';', ' ')
      .replace('(', ' ')
      .replace(')', ' ');
    const rawTokens = normalized.split(' ');
    const terms: string[] = [];

    for (let index = 0; index < rawTokens.length; index++) {
      const token = rawTokens[index].trim();
      if (token.length < 2) {
        continue;
      }
      if (this.isStopWord(token)) {
        continue;
      }
      if (terms.indexOf(token) < 0) {
        terms.push(token);
      }
      if (terms.length >= 24) {
        break;
      }
    }
    return terms;
  }

  private isStopWord(token: string): boolean {
    return token === 'mg' || token === 'g' || token === 'ml' || token === 'lek' || token === 'oraz' ||
      token === 'tabletki' || token === 'kapsulki' || token === 'capsules' || token === 'tablets' ||
      token === 'ulotka' || token === 'pacjenta' || token === 'dawka' || token === 'dla' ||
      token === 'and' || token === 'the' || token === 'for' || token === 'with';
  }

  private appendUniqueRecords(target: RplMedicineRecord[], records: RplMedicineRecord[]): void {
    for (let index = 0; index < records.length; index++) {
      if (!this.containsRecord(target, records[index].id)) {
        target.push(records[index]);
      }
    }
  }

  private containsRecord(records: RplMedicineRecord[], id: number): boolean {
    for (let index = 0; index < records.length; index++) {
      if (records[index].id === id) {
        return true;
      }
    }
    return false;
  }

  private scoreRecord(record: RplMedicineRecord, terms: string[]): number {
    const searchable = record.searchText.toLowerCase();
    const name = record.name.toLowerCase();
    const commonName = record.commonName.toLowerCase();
    const activeSubstance = record.activeSubstance.toLowerCase();
    const strength = record.strength.toLowerCase();
    let score = 0;

    for (let index = 0; index < terms.length; index++) {
      const term = terms[index];
      if (name.indexOf(term) >= 0) {
        score += 10;
      } else if (commonName.indexOf(term) >= 0 || activeSubstance.indexOf(term) >= 0) {
        score += 7;
      } else if (strength.indexOf(term) >= 0) {
        score += 4;
      } else if (searchable.indexOf(term) >= 0) {
        score += 2;
      }
    }
    return score;
  }
}
