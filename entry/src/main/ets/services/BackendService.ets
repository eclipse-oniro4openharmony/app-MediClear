import http from '@ohos.net.http';
import {
  buildDocumentFactsUrl,
  buildLatestDocumentByProductUrl,
  buildLatestLeafletByProductUrl,
  buildMedicineChatUrl,
  buildReminderPlanUrl,
  buildRplDocumentExtractUrl,
  MEDICLEAR_BACKEND_HEALTH_URL
} from './BackendConfig';

class RplDocumentExtractRequest {
  productId: string = '';
  medicineName: string = '';
  leafletUrl: string = '';
  characteristicUrl: string = '';
  documentType: string = 'leaflet';

  constructor(productId: string, medicineName: string, leafletUrl: string = '', characteristicUrl: string = '') {
    this.productId = productId;
    this.medicineName = medicineName;
    this.leafletUrl = leafletUrl;
    this.characteristicUrl = characteristicUrl;
  }
}

export class PatientContext {
  sex: string = '';
  age: string = '';
  weightKg: string = '';
  currentSymptoms: string = '';
  allergyHistory: string = '';
  specialStatus: string = '';

  constructor(sex: string, age: string, weightKg: string, currentSymptoms: string, allergyHistory: string,
    specialStatus: string) {
    this.sex = sex;
    this.age = age;
    this.weightKg = weightKg;
    this.currentSymptoms = currentSymptoms;
    this.allergyHistory = allergyHistory;
    this.specialStatus = specialStatus;
  }
}

class MedicineChatRequest {
  question: string = '';
  documentId: number = 0;
  medicineName: string = '';
  patientContext: PatientContext = new PatientContext('', '', '', '', '', '');
  limit: number = 6;

  constructor(question: string, documentId: number, medicineName: string, patientContext: PatientContext) {
    this.question = question;
    this.documentId = documentId;
    this.medicineName = medicineName;
    this.patientContext = patientContext;
  }
}

class ReminderPlanRequest {
  documentId: number = 0;
  medicineName: string = '';
  patientContext: PatientContext = new PatientContext('', '', '', '', '', '');

  constructor(documentId: number, medicineName: string, patientContext: PatientContext) {
    this.documentId = documentId;
    this.medicineName = medicineName;
    this.patientContext = patientContext;
  }
}

export class BackendDocumentResponse {
  id: number = 0;
  product_id: string = '';
  medicine_name: string = '';
  document_type: string = '';
  source_url: string = '';
  source_hash: string = '';
  source_size: number = 0;
  extraction_method: string = '';
  status: string = '';
  text_length: number = 0;
  preview: string = '';
  error_message: string | null = null;
  created_at: string = '';
  updated_at: string = '';
}

export class BackendHealthResponse {
  ok: boolean = false;
  service: string = '';
}

export class BackendChatCitation {
  chunkIndex: number = 0;
  pageNumber: number | null = null;
  sectionTitle: string | null = null;
}

export class BackendChatResponse {
  answer: string = '';
  documentId: number = 0;
  medicineName: string = '';
  citations: BackendChatCitation[] = [];
}

export class BackendReminderPlanItem {
  time: string = '';
  label: string = '';
  dose: string = '';
  source: string = '';
}

export class BackendReminderPlanResponse {
  status: string = '';
  medicineName: string = '';
  summary: string = '';
  howToTake: string = '';
  dose: string = '';
  frequency: string = '';
  timing: string = '';
  duration: string = '';
  warning: string = '';
  reminders: BackendReminderPlanItem[] = [];
}

export class BackendMedicineFactsResponse {
  documentId: number = 0;
  medicineName: string = '';
  activeIngredient: string = '';
  howToTake: string = '';
  contraindications: string = '';
  warnings: string = '';
  source: string = '';
}

export class BackendService {
  async checkHealth(): Promise<BackendHealthResponse> {
    const request = http.createHttp();
    try {
      console.info('[MediClearBackend] health request start url=' + MEDICLEAR_BACKEND_HEALTH_URL);
      const response = await request.request(MEDICLEAR_BACKEND_HEALTH_URL, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'application/json'
        },
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 15000,
        connectTimeout: 8000
      });

      console.info('[MediClearBackend] health responseCode=' + response.responseCode.toString());
      if (response.responseCode !== 200) {
        throw new Error('Backend health failed: ' + response.responseCode.toString() + ' ' + response.result.toString());
      }

      return JSON.parse(response.result.toString()) as BackendHealthResponse;
    } finally {
      request.destroy();
    }
  }

  async extractRplLeaflet(productId: string, medicineName: string, leafletUrl: string = '',
    characteristicUrl: string = ''): Promise<BackendDocumentResponse> {
    const requestBody = new RplDocumentExtractRequest(productId, medicineName, leafletUrl, characteristicUrl);
    const request = http.createHttp();
    try {
      console.info('[MediClearBackend] extract request start productId=' + productId + ' url=' + buildRplDocumentExtractUrl());
      const response = await request.request(buildRplDocumentExtractUrl(), {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        extraData: JSON.stringify(requestBody),
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 120000,
        connectTimeout: 15000
      });

      console.info('[MediClearBackend] extract responseCode=' + response.responseCode.toString());
      if (response.responseCode !== 200) {
        throw new Error('Backend extraction failed: ' + response.responseCode.toString() + ' ' + response.result.toString());
      }

      return JSON.parse(response.result.toString()) as BackendDocumentResponse;
    } finally {
      request.destroy();
    }
  }

  async getLatestDocumentByProduct(productId: string): Promise<BackendDocumentResponse> {
    const request = http.createHttp();
    try {
      const response = await request.request(buildLatestDocumentByProductUrl(productId), {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'application/json'
        },
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 30000,
        connectTimeout: 10000
      });

      if (response.responseCode !== 200) {
        throw new Error('Backend document lookup failed: ' + response.responseCode.toString() + ' ' + response.result.toString());
      }

      return JSON.parse(response.result.toString()) as BackendDocumentResponse;
    } finally {
      request.destroy();
    }
  }

  async getLatestLeafletByProduct(productId: string): Promise<BackendDocumentResponse> {
    const request = http.createHttp();
    try {
      const response = await request.request(buildLatestLeafletByProductUrl(productId), {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'application/json'
        },
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 15000,
        connectTimeout: 8000
      });

      if (response.responseCode !== 200) {
        throw new Error('Backend leaflet lookup failed: ' + response.responseCode.toString() + ' ' +
        response.result.toString());
      }

      return JSON.parse(response.result.toString()) as BackendDocumentResponse;
    } finally {
      request.destroy();
    }
  }

  async getMedicineFacts(documentId: number): Promise<BackendMedicineFactsResponse> {
    const request = http.createHttp();
    try {
      const response = await request.request(buildDocumentFactsUrl(documentId), {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'application/json'
        },
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 30000,
        connectTimeout: 10000
      });

      if (response.responseCode !== 200) {
        throw new Error('Backend medicine facts lookup failed: ' + response.responseCode.toString() + ' ' +
        response.result.toString());
      }

      return JSON.parse(response.result.toString()) as BackendMedicineFactsResponse;
    } finally {
      request.destroy();
    }
  }

  async askMedicineQuestion(question: string, documentId: number, medicineName: string,
    patientContext: PatientContext): Promise<BackendChatResponse> {
    const requestBody = new MedicineChatRequest(question, documentId, medicineName, patientContext);
    const request = http.createHttp();
    try {
      console.info('[MediClearChat] chat request start documentId=' + documentId.toString());
      const response = await request.request(buildMedicineChatUrl(), {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        extraData: JSON.stringify(requestBody),
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 120000,
        connectTimeout: 15000
      });

      console.info('[MediClearChat] chat responseCode=' + response.responseCode.toString());
      if (response.responseCode !== 200) {
        throw new Error('Backend chat failed: ' + response.responseCode.toString() + ' ' + response.result.toString());
      }

      return JSON.parse(response.result.toString()) as BackendChatResponse;
    } finally {
      request.destroy();
    }
  }

  async planMedicationReminders(documentId: number, medicineName: string,
    patientContext: PatientContext): Promise<BackendReminderPlanResponse> {
    const requestBody = new ReminderPlanRequest(documentId, medicineName, patientContext);
    const request = http.createHttp();
    try {
      console.info('[MediClearReminder] reminder plan request start documentId=' + documentId.toString());
      const response = await request.request(buildReminderPlanUrl(), {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        extraData: JSON.stringify(requestBody),
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 30000,
        connectTimeout: 10000
      });

      console.info('[MediClearReminder] reminder plan responseCode=' + response.responseCode.toString());
      if (response.responseCode !== 200) {
        throw new Error('Backend reminder planning failed: ' + response.responseCode.toString() + ' ' +
        response.result.toString());
      }

      return JSON.parse(response.result.toString()) as BackendReminderPlanResponse;
    } finally {
      request.destroy();
    }
  }
}
