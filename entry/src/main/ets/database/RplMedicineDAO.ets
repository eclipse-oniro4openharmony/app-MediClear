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

  getDebugSearchTerms(ocrText: string): string {
    const terms = this.extractSearchTerms(ocrText);
    if (terms.length === 0) {
      return 'No searchable terms extracted';
    }

    const preview: string[] = [];
    for (let index = 0; index < terms.length && index < 20; index++) {
      preview.push(terms[index]);
    }
    return preview.join(', ');
  }

  private extractSearchTerms(text: string): string[] {
    const normalized = this.normalizeOcrText(text);
    const rawTokens = normalized.split(' ');
    const terms: string[] = [];

    for (let index = 0; index < rawTokens.length; index++) {
      const token = rawTokens[index].trim();
      if (token.length < 4 && !this.isNumericToken(token)) {
        continue;
      }
      if (this.isStopWord(token)) {
        continue;
      }
      if (terms.indexOf(token) < 0) {
        terms.push(token);
      }
      if (terms.length >= 80) {
        break;
      }
    }
    return terms;
  }

  private normalizeOcrText(text: string): string {
    return text.toLowerCase()
      .replace(/ą/g, 'a')
      .replace(/ć/g, 'c')
      .replace(/ę/g, 'e')
      .replace(/ł/g, 'l')
      .replace(/ń/g, 'n')
      .replace(/ó/g, 'o')
      .replace(/ś/g, 's')
      .replace(/ź/g, 'z')
      .replace(/ż/g, 'z')
      .replace(/[^a-z0-9]+/g, ' ');
  }

  private isNumericToken(token: string): boolean {
    return /^[0-9]+$/.test(token);
  }

  private isStopWord(token: string): boolean {
    return token === 'mg' || token === 'g' || token === 'ml' || token === 'mcg' || token === 'lek' || token === 'oraz' ||
      token === 'tabletki' || token === 'kapsulki' || token === 'kapsulek' || token === 'capsules' || token === 'tablets' ||
      token === 'ulotka' || token === 'pacjenta' || token === 'dawka' || token === 'dla' ||
      token === 'and' || token === 'the' || token === 'for' || token === 'with' || token === 'pl' ||
      token === 'www' || token === 'com' || token === 'nr' || token === 'lot' || token === 'exp' ||
      token === 'medium' || token === 'task' || token === 'chatgpt' || token === 'berlin' ||
      token === 'chemie' || token === 'menarini' || token === 'przeciw' || token === 'wzdeciom';
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
    const packageInfo = record.packageInfo.toLowerCase();
    let score = 0;
    let identityScore = 0;
    let packageScore = 0;
    let genericScore = 0;

    for (let index = 0; index < terms.length; index++) {
      const term = terms[index];
      if (this.fieldContainsToken(name, term)) {
        identityScore += 60;
      } else if (this.fieldContainsToken(commonName, term) || this.fieldContainsToken(activeSubstance, term)) {
        identityScore += 40;
      } else if (this.isLongNumericToken(term) && (packageInfo.indexOf(term) >= 0 || searchable.indexOf(term) >= 0)) {
        packageScore += 45;
      } else if (strength.indexOf(term) >= 0) {
        genericScore += 8;
      } else if (searchable.indexOf(term) >= 0) {
        genericScore += 1;
      }
    }

    if (identityScore === 0 && packageScore === 0) {
      return 0;
    }

    if (genericScore > 12) {
      genericScore = 12;
    }
    score = identityScore + packageScore + genericScore;
    return score;
  }

  private fieldContainsToken(field: string, term: string): boolean {
    if (term.length < 4) {
      return false;
    }
    return field.indexOf(term) >= 0;
  }

  private isLongNumericToken(term: string): boolean {
    return /^[0-9]{8,}$/.test(term);
  }
}
