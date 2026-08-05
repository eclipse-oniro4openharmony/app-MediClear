import express from 'express';
import { z } from 'zod';
import { config } from './config.js';
import {
  closeDatabase,
  getChunks,
  getDocument,
  getLatestDocumentByProductIdAndType,
  getLatestDocumentByProductId,
  initializeDatabase,
  searchChunks,
  upsertDocumentWithChunks
} from './database.js';
import { askDeepSeekWithKnowledgeBase } from './deepseekClient.js';
import { extractPdfText, downloadPdf, sha256, splitIntoChunks } from './pdfTextExtractor.js';

const app = express();
app.use(express.json({ limit: '1mb' }));
app.use((request, response, next) => {
  const startedAt = Date.now();
  console.log(`[http] ${request.method} ${request.originalUrl} start`);
  response.on('finish', () => {
    console.log(`[http] ${request.method} ${request.originalUrl} ${response.statusCode} ${Date.now() - startedAt}ms`);
  });
  response.on('close', () => {
    if (!response.writableEnded) {
      console.warn(`[http] ${request.method} ${request.originalUrl} closed before response after ${Date.now() - startedAt}ms`);
    }
  });
  next();
});

const extractUrlSchema = z.object({
  url: z.string().url(),
  productId: z.string().optional(),
  medicineName: z.string().optional(),
  documentType: z.string().min(1).default('leaflet'),
  forceOcr: z.boolean().optional().default(false)
});

const rplSchema = z.object({
  productId: z.union([z.string(), z.number()]).transform((value) => String(value)),
  medicineName: z.string().optional(),
  leafletUrl: z.union([z.string().url(), z.literal('')]).optional().default(''),
  characteristicUrl: z.union([z.string().url(), z.literal('')]).optional().default(''),
  documentType: z.enum(['leaflet', 'characteristic']).default('leaflet'),
  forceOcr: z.boolean().optional().default(false)
});

const searchSchema = z.object({
  query: z.string().min(1),
  documentId: z.number().int().positive().optional(),
  limit: z.number().int().positive().max(50).default(8)
});

const patientContextSchema = z.object({
  sex: z.string().optional().default(''),
  age: z.string().optional().default(''),
  weightKg: z.string().optional().default(''),
  currentSymptoms: z.string().optional().default(''),
  allergyHistory: z.string().optional().default(''),
  specialStatus: z.string().optional().default('')
}).default({});

const chatSchema = z.object({
  question: z.string().min(1).max(1000),
  documentId: z.number().int().positive(),
  medicineName: z.string().optional().default(''),
  patientContext: patientContextSchema,
  limit: z.number().int().positive().max(12).default(6)
});

const reminderPlanSchema = z.object({
  documentId: z.number().int().positive(),
  medicineName: z.string().optional().default(''),
  patientContext: patientContextSchema
});

app.get('/health', (_request, response) => {
  response.json({
    ok: true,
    service: 'mediclear-backend'
  });
});

app.post('/api/debug/echo', (request, response) => {
  response.json({
    ok: true,
    body: request.body
  });
});

app.post('/api/documents/rpl', async (request, response, next) => {
  try {
    const input = rplSchema.parse(request.body);
    const document = await extractRplDocumentWithFallback(input);
    response.json(document);
  } catch (error) {
    next(error);
  }
});

app.post('/api/documents/extract-url', async (request, response, next) => {
  try {
    const input = extractUrlSchema.parse(request.body);
    const document = await extractAndStore(input);
    response.json(document);
  } catch (error) {
    next(error);
  }
});

app.get('/api/documents/by-product/:productId', async (request, response, next) => {
  try {
    const document = await getLatestDocumentByProductId(request.params.productId);
    if (!document) {
      response.status(404).json({ error: 'Document not found' });
      return;
    }

    response.json(document);
  } catch (error) {
    next(error);
  }
});

app.get('/api/documents/:id/chunks', async (request, response, next) => {
  try {
    const documentId = Number.parseInt(request.params.id, 10);
    response.json({
      documentId,
      chunks: await getChunks(documentId)
    });
  } catch (error) {
    next(error);
  }
});

app.get('/api/documents/:id', async (request, response, next) => {
  try {
    const document = await getDocument(Number.parseInt(request.params.id, 10));
    if (!document) {
      response.status(404).json({ error: 'Document not found' });
      return;
    }

    response.json(document);
  } catch (error) {
    next(error);
  }
});

app.post('/api/search', async (request, response, next) => {
  try {
    const input = searchSchema.parse(request.body);
    response.json({
      results: await searchChunks(input.query, input.documentId, input.limit)
    });
  } catch (error) {
    next(error);
  }
});

app.post('/api/chat', async (request, response, next) => {
  try {
    const input = chatSchema.parse(request.body);
    const document = await getDocument(input.documentId);
    if (!document) {
      response.status(404).json({ error: 'Knowledge base document not found' });
      return;
    }

    const allChunks = await getChunks(input.documentId);
    const selectedChunks = selectKnowledgeChunks(allChunks, input.question, input.patientContext, input.limit);

    const contextText = selectedChunks
      .map((chunk) => {
        const sectionLabel = chunk.section_title || chunk.section_type || '';
        return `Page ${chunk.page_number ?? 'unknown'}${sectionLabel ? `, section ${sectionLabel}` : ''}:\n${chunk.chunk_text}`;
      })
      .join('\n\n---\n\n');
    const dosageFacts = extractDosageFacts(selectedChunks);
    const answer = await askDeepSeekWithKnowledgeBase({
      question: input.question,
      medicineName: input.medicineName || document.medicine_name,
      contextText,
      dosageFacts,
      patientContext: input.patientContext
    });

    response.json({
      answer,
      documentId: input.documentId,
      medicineName: input.medicineName || document.medicine_name,
      citations: selectedChunks.map((chunk) => ({
        chunkIndex: chunk.chunk_index,
        pageNumber: chunk.page_number,
        sectionType: chunk.section_type,
        sectionTitle: chunk.section_title
      }))
    });
  } catch (error) {
    next(error);
  }
});

app.post('/api/reminders/plan', async (request, response, next) => {
  try {
    const input = reminderPlanSchema.parse(request.body);
    const document = await getDocument(input.documentId);
    if (!document) {
      response.status(404).json({ error: 'Knowledge base document not found' });
      return;
    }

    const allChunks = await getChunks(input.documentId);
    response.json(buildReminderPlan({
      medicineName: input.medicineName || document.medicine_name,
      chunks: allChunks,
      patientContext: input.patientContext
    }));
  } catch (error) {
    next(error);
  }
});

function selectKnowledgeChunks(allChunks, question, patientContext, limit) {
  const selected = [];
  const prioritySections = [
    'how_to_take',
    'before_use',
    'side_effects',
    'storage',
    'contents',
    'what_is_it'
  ];

  for (const sectionType of prioritySections) {
    for (const chunk of allChunks) {
      if (chunk.section_type === sectionType && !selected.includes(chunk)) {
        selected.push(chunk);
      }
    }
  }

  for (const chunk of allChunks) {
    if ((chunk.section_type === null || chunk.section_type === undefined) && !selected.includes(chunk)) {
      selected.push(chunk);
    }
  }

  for (const chunk of allChunks) {
    if (selected.includes(chunk)) {
      continue;
    }
    selected.push(chunk);
  }

  return fitChunksToContext(selected, 18000);
}

function extractDosageFacts(chunks) {
  const howToTakeText = chunks
    .filter((chunk) => chunk.section_type === 'how_to_take')
    .map((chunk) => chunk.chunk_text)
    .join(' ')
    .replace(/\s+/g, ' ')
    .trim();

  if (howToTakeText.length === 0) {
    return '';
  }

  const facts = [];
  const recommendedDose = firstMatch(howToTakeText, [
    /(\d+\s*(?:do|-|–)?\s*\d*\s*(?:kapsułki|kapsułek|tabletki|tabletek|tablet|capsules?|drops?|ml)(?:\s*\([^)]*\))?)/i,
    /(?:recommended dose|dose)[^.:;]*[:.]?\s*([^.;]{0,120}(?:capsules?|tablets?|drops?|ml)[^.;]{0,120})/i
  ]);
  const frequency = firstMatch(howToTakeText, [
    /(\d+\s*(?:do|-|–)?\s*\d+\s*razy\s+na\s+dobę)/i,
    /(\d+\s*(?:to|-|–)?\s*\d+\s*times\s+(?:a|per)\s+day)/i,
    /(every\s+\d+\s*(?:-|–|to)?\s*\d*\s*hours?)/i
  ]);
  const timing = firstMatch(howToTakeText, [
    /(bezpośrednio przed,\s*w trakcie lub po posiłkach[^.]*\.?)/i,
    /(before,\s*during,?\s*or after meals[^.]*\.?)/i,
    /(with meals[^.]*\.?)/i,
    /(after meals[^.]*\.?)/i,
    /(before meals[^.]*\.?)/i
  ]);
  const duration = firstMatch(howToTakeText, [
    /(należy przyjmować tak długo jak występują dolegliwości[^.]*\.?)/i,
    /(take[^.]{0,80}as long as symptoms[^.]*\.?)/i
  ]);

  pushFact(facts, 'Dose per intake', recommendedDose);
  pushFact(facts, 'Frequency', frequency);
  pushFact(facts, 'Timing', timing);
  pushFact(facts, 'Duration', duration);

  const sourcePassage = extractDosageSourcePassage(howToTakeText);
  if (sourcePassage.length > 0) {
    facts.push(`Source dosage passage: ${sourcePassage}`);
  }

  return facts.join('\n');
}

function firstMatch(text, patterns) {
  for (const pattern of patterns) {
    const match = text.match(pattern);
    if (match?.[1]) {
      return match[1].trim();
    }
  }
  return '';
}

function pushFact(facts, label, value) {
  if (value.length > 0) {
    facts.push(`${label}: ${formatExtractedFactValue(value)}`);
  } else {
    facts.push(`${label}: Not found in the provided leaflet context`);
  }
}

function formatExtractedFactValue(value) {
  const translated = value
    .replace(/kapsułki|kapsułek/gi, 'capsules')
    .replace(/tabletki|tabletek/gi, 'tablets')
    .replace(/co odpowiada/gi, 'equivalent to')
    .replace(/symetykonu/gi, 'simethicone')
    .replace(/razy na dobę/gi, 'times daily')
    .replace(/(\d+)\s+do\s+(\d+)\s+times daily/gi, '$1 to $2 times daily')
    .replace(/bezpośrednio przed,\s*w trakcie lub po posiłkach/gi, 'immediately before, during, or after meals')
    .replace(/w razie konieczności,\s*również przed snem/gi, 'if needed, also before bedtime')
    .replace(/należy przyjmować tak długo jak występują dolegliwości/gi, 'take as long as symptoms persist');

  return translated === value ? value : `${value} [English: ${translated}]`;
}

function extractDosageSourcePassage(text) {
  const startSignals = ['Dawkowanie', 'Recommended dose', 'Zalecana dawka'];
  const endSignals = ['Sposób podawania', 'Method of administration', 'Zastosowanie większej', 'Pominięcie'];
  let start = -1;
  for (const signal of startSignals) {
    const index = text.toLowerCase().indexOf(signal.toLowerCase());
    if (index >= 0 && (start < 0 || index < start)) {
      start = index;
    }
  }
  if (start < 0) {
    start = 0;
  }

  let end = -1;
  for (const signal of endSignals) {
    const index = text.toLowerCase().indexOf(signal.toLowerCase(), start + 20);
    if (index > start && (end < 0 || index < end)) {
      end = index;
    }
  }
  const passage = text.slice(start, end > start ? end : Math.min(text.length, start + 900)).trim();
  return passage.length > 900 ? passage.slice(0, 900) : passage;
}

function buildReminderPlan(input) {
  const safetyAssessment = buildReminderSafetyAssessment(input.chunks, input.patientContext ?? {});
  const howToTakeText = input.chunks
    .filter((chunk) => chunk.section_type === 'how_to_take')
    .map((chunk) => chunk.chunk_text)
    .join(' ')
    .replace(/\s+/g, ' ')
    .trim();

  if (safetyAssessment.blocked) {
    return {
      status: 'blocked',
      medicineName: input.medicineName || '',
      summary: safetyAssessment.summary,
      howToTake: 'Automatic reminders were not created because the leaflet safety check needs attention.',
      dose: 'Not set',
      frequency: 'Not set',
      timing: 'Not set',
      warning: safetyAssessment.warning,
      reminders: []
    };
  }

  if (howToTakeText.length === 0) {
    return {
      status: 'needs_confirmation',
      medicineName: input.medicineName || '',
      summary: 'The official leaflet context does not include a clear how-to-take section.',
      howToTake: 'Confirm the dose and timing with a doctor or pharmacist before setting reminders.',
      dose: 'Not found in the provided leaflet context',
      frequency: 'Not found in the provided leaflet context',
      timing: 'Not found in the provided leaflet context',
      warning: combineReminderMessages([
        safetyAssessment.warning,
        'No automatic reminders were created because the leaflet usage plan was not clear.'
      ]),
      reminders: []
    };
  }

  const dose = firstMatch(howToTakeText, [
    /((?:jedna|jeden|1)\s+tabletka\s+\d+\s*mg)/i,
    /((?:dwie|dwa|2)\s+tabletki\s+\d*\s*mg?)/i,
    /(\d+\s*(?:do|-|–)?\s*\d*\s*(?:kapsułki|kapsułek|tabletki|tabletek|tablet|capsules?|drops?|ml)(?:\s*\([^)]*\))?)/i,
    /(?:recommended dose|dose)[^.:;]*[:.]?\s*([^.;]{0,120}(?:capsules?|tablets?|drops?|ml)[^.;]{0,120})/i
  ]);
  const frequency = firstMatch(howToTakeText, [
    /(raz\s+na\s+dobę)/i,
    /(once\s+(?:daily|a day|per day))/i,
    /(\d+\s*(?:do|-|–)?\s*\d+\s*razy\s+na\s+dobę)/i,
    /(\d+\s*(?:to|-|–)?\s*\d+\s*times\s+(?:a|per)\s+day)/i,
    /(every\s+\d+\s*(?:-|–|to)?\s*\d*\s*hours?)/i
  ]);
  const timing = firstMatch(howToTakeText, [
    /(rano)/i,
    /(bezpośrednio przed,\s*w trakcie lub po posiłkach[^.]*\.?)/i,
    /(before,\s*during,?\s*or after meals[^.]*\.?)/i,
    /(with meals[^.]*\.?)/i,
    /(after meals[^.]*\.?)/i,
    /(before meals[^.]*\.?)/i
  ]);
  const duration = firstMatch(howToTakeText, [
    /(należy przyjmować tak długo jak występują dolegliwości[^.]*\.?)/i,
    /(take[^.]{0,80}as long as symptoms[^.]*\.?)/i
  ]);
  const reminderCount = chooseReminderCount(frequency);
  const displayDose = conciseFact(dose);
  const displayFrequency = conciseFact(frequency);
  const displayTiming = conciseFact(timing);
  const displayDuration = conciseFact(duration);

  if (displayDose.indexOf('Not found') >= 0 || displayFrequency.indexOf('Not found') >= 0) {
    return {
      status: 'needs_confirmation',
      medicineName: input.medicineName || '',
      summary: 'The leaflet usage section did not provide enough structured dose and frequency information for automatic reminders.',
      howToTake: buildHowToTakeText(displayDose, displayFrequency, displayTiming, displayDuration),
      dose: displayDose,
      frequency: displayFrequency,
      timing: displayTiming,
      warning: combineReminderMessages([
        safetyAssessment.warning,
        'No automatic reminders were created. Confirm the dose and timing with a doctor or pharmacist.'
      ]),
      reminders: []
    };
  }

  const reminders = buildReminderItems(reminderCount, displayDose, displayTiming);
  const status = reminders.length > 0 && displayDose.indexOf('Not found') < 0 && !safetyAssessment.needsConfirmation
    ? 'ready'
    : 'needs_confirmation';
  const warning = buildReminderWarning(safetyAssessment.warning, reminders.length, displayFrequency);

  return {
    status,
    medicineName: input.medicineName || '',
    summary: status === 'ready'
      ? `Suggested ${reminders.length} daily reminder${reminders.length === 1 ? '' : 's'} from the official leaflet usage section.`
      : 'The leaflet has partial usage information. Confirm the plan before relying on reminders.',
    howToTake: buildHowToTakeText(displayDose, displayFrequency, displayTiming, displayDuration),
    dose: displayDose,
    frequency: displayFrequency,
    timing: displayTiming,
    warning,
    reminders
  };
}

function buildReminderSafetyAssessment(chunks, patientContext) {
  const safetyText = buildSafetyText(chunks);
  const findings = [];
  const cautions = [];

  const ageFinding = findAgeSafetyFinding(safetyText, patientContext.age ?? '');
  if (ageFinding.blocked) {
    findings.push(ageFinding.message);
  } else if (ageFinding.message.length > 0) {
    cautions.push(ageFinding.message);
  }

  const allergyFinding = findAllergySafetyFinding(safetyText, patientContext.allergyHistory ?? '');
  if (allergyFinding.blocked) {
    findings.push(allergyFinding.message);
  } else if (allergyFinding.message.length > 0) {
    cautions.push(allergyFinding.message);
  }

  const specialStatusFinding = findSpecialStatusSafetyFinding(safetyText, patientContext.specialStatus ?? '');
  if (specialStatusFinding.blocked) {
    findings.push(specialStatusFinding.message);
  } else if (specialStatusFinding.message.length > 0) {
    cautions.push(specialStatusFinding.message);
  }

  if (findings.length > 0) {
    const warning = combineReminderMessages(findings.concat([
      'Automatic reminders were not created. Check the leaflet and ask a doctor or pharmacist before use.'
    ]));
    return {
      blocked: true,
      needsConfirmation: true,
      summary: findings[0],
      warning
    };
  }

  const warning = cautions.length > 0
    ? combineReminderMessages(cautions.concat(['Confirm the plan before use. MediClear does not prescribe medicine.']))
    : '';
  return {
    blocked: false,
    needsConfirmation: cautions.length > 0,
    summary: cautions.length > 0 ? cautions[0] : 'No obvious safety block found in the leaflet excerpts used for reminders.',
    warning
  };
}

function buildSafetyText(chunks) {
  const priority = ['before_use', 'how_to_take', null, undefined];
  const selected = [];
  for (const sectionType of priority) {
    for (const chunk of chunks) {
      if (chunk.section_type === sectionType && !selected.includes(chunk)) {
        selected.push(chunk);
      }
    }
  }
  if (selected.length === 0) {
    selected.push(...chunks.slice(0, 8));
  }
  return selected
    .map((chunk) => chunk.chunk_text)
    .join(' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function findAgeSafetyFinding(text, ageValue) {
  const age = Number.parseInt(String(ageValue).trim(), 10);
  if (!Number.isFinite(age)) {
    return {
      blocked: false,
      message: 'Age is missing, so reminders need manual confirmation.'
    };
  }

  const lower = text.toLowerCase();
  const underAgePatterns = [
    /(?:not recommended|do not use|must not be used|should not be used)[^.]{0,140}(?:children|adolescents|patients)[^.]{0,80}(?:under|below)\s+(\d+)/i,
    /(?:children|adolescents|patients)[^.]{0,100}(?:under|below)\s+(\d+)[^.]{0,140}(?:not recommended|do not use|must not be used|should not be used)/i,
    /(?:nie zaleca się|nie stosować|nie należy stosować)[^.]{0,140}(?:dzieci|młodzieży|pacjentów)[^.]{0,80}(?:poniżej|do)\s+(\d+)/i,
    /(?:dzieci|młodzieży|pacjentów)[^.]{0,100}(?:poniżej|do)\s+(\d+)[^.]{0,140}(?:nie zaleca się|nie stosować|nie należy stosować)/i
  ];

  for (const pattern of underAgePatterns) {
    const match = text.match(pattern);
    if (match?.[1]) {
      const minimumAge = Number.parseInt(match[1], 10);
      if (age < minimumAge) {
        return {
          blocked: true,
          message: `The leaflet indicates this medicine is not recommended for patients under ${minimumAge}. User age: ${age}.`
        };
      }
      return {
        blocked: false,
        message: ''
      };
    }
  }

  if (age < 18 && (lower.includes('children and adolescents') || lower.includes('dzieci i młodzieży'))) {
    return {
      blocked: false,
      message: 'The leaflet contains a children/adolescents warning. Confirm use before setting reminders.'
    };
  }

  const youngAdultWarning = text.match(/(?:poniżej|under|below)\s+25\s+lat|under\s+25/i);
  if (youngAdultWarning && age < 25) {
    return {
      blocked: false,
      message: 'The leaflet contains an increased-risk warning for adults under 25. Confirm with a doctor or pharmacist before reminders.'
    };
  }

  return {
    blocked: false,
    message: ''
  };
}

function findAllergySafetyFinding(text, allergyHistory) {
  const allergies = normalizePatientList(allergyHistory);
  if (allergies.length === 0) {
    return {
      blocked: false,
      message: ''
    };
  }

  const normalizedText = normalizeSafetyText(text);
  const matchedAllergies = [];
  for (const allergy of allergies) {
    if (allergy.length < 3) {
      continue;
    }
    if (normalizedText.includes(allergy)) {
      matchedAllergies.push(allergy);
    }
  }

  if (matchedAllergies.length > 0) {
    return {
      blocked: true,
      message: `Saved allergy history matches leaflet safety text: ${matchedAllergies.join(', ')}.`
    };
  }

  return {
    blocked: false,
    message: ''
  };
}

function findSpecialStatusSafetyFinding(text, specialStatus) {
  const statuses = normalizePatientList(specialStatus);
  if (statuses.length === 0) {
    return {
      blocked: false,
      message: ''
    };
  }

  const normalizedText = normalizeSafetyText(text);
  const statusMap = [
    { tokens: ['pregnant', 'pregnancy', 'ciaza', 'ciazy'], label: 'pregnancy' },
    { tokens: ['breastfeeding', 'breast feeding', 'karmienie', 'karmi'], label: 'breastfeeding' },
    { tokens: ['liver', 'hepatic', 'watroba', 'watroby'], label: 'liver condition' },
    { tokens: ['kidney', 'renal', 'nerki', 'nerek'], label: 'kidney condition' },
    { tokens: ['epilepsy', 'seizure', 'padaczka', 'drgawki'], label: 'seizure/epilepsy history' }
  ];

  const matched = [];
  for (const status of statuses) {
    for (const entry of statusMap) {
      const patientMentionsStatus = entry.tokens.some((token) => status.includes(normalizeSafetyText(token)));
      const leafletMentionsStatus = entry.tokens.some((token) => normalizedText.includes(normalizeSafetyText(token)));
      if (patientMentionsStatus && leafletMentionsStatus && !matched.includes(entry.label)) {
        matched.push(entry.label);
      }
    }
  }

  return {
    blocked: false,
    message: matched.length > 0
      ? `Saved special status matches leaflet warning topics: ${matched.join(', ')}. Confirm with a doctor or pharmacist before reminders.`
      : ''
  };
}

function conciseFact(value) {
  if (!value || value.trim().length === 0) {
    return 'Not found in the provided leaflet context';
  }

  const formatted = formatExtractedFactValue(value);
  const englishStart = formatted.indexOf('[English: ');
  if (englishStart >= 0) {
    return formatted.substring(englishStart + 10, formatted.length - 1).trim();
  }
  return translateLeafletFactToEnglish(formatted.trim());
}

function translateLeafletFactToEnglish(value) {
  return value
    .replace(/\bjedna\s+tabletka\s+(\d+\s*mg)\b/gi, '1 tablet $1')
    .replace(/\bjeden\s+tabletka\s+(\d+\s*mg)\b/gi, '1 tablet $1')
    .replace(/\b1\s+tabletka\s+(\d+\s*mg)\b/gi, '1 tablet $1')
    .replace(/\bdwie\s+tabletki\s+(\d+\s*mg)?\b/gi, (_match, strength) => `2 tablets${strength ? ` ${strength.trim()}` : ''}`)
    .replace(/\b2\s+tabletki\s+(\d+\s*mg)?\b/gi, (_match, strength) => `2 tablets${strength ? ` ${strength.trim()}` : ''}`)
    .replace(/\braz\s+na\s+dobę\b/gi, 'once daily')
    .replace(/\brano\b/gi, 'morning')
    .replace(/\bna\s+dobę\b/gi, 'daily')
    .replace(/\bdobę\b/gi, 'day')
    .replace(/\btabletka\b/gi, 'tablet')
    .replace(/\btabletki\b/gi, 'tablets')
    .replace(/\s+/g, ' ')
    .trim();
}

function chooseReminderCount(frequency) {
  const lower = frequency.toLowerCase();
  if (lower.includes('raz na dobę') || lower.includes('once daily') || lower.includes('once a day') ||
    lower.includes('once per day')) {
    return 1;
  }

  const rangeMatch = lower.match(/(\d+)\s*(?:do|-|–|to)\s*(\d+)/);
  if (rangeMatch?.[1]) {
    const minimum = Number.parseInt(rangeMatch[1], 10);
    return Math.max(1, Math.min(minimum, 4));
  }

  const singleMatch = lower.match(/(\d+)\s*(?:razy|times)/);
  if (singleMatch?.[1]) {
    return Math.max(1, Math.min(Number.parseInt(singleMatch[1], 10), 4));
  }

  const hourMatch = lower.match(/every\s+(\d+)/);
  if (hourMatch?.[1]) {
    const hours = Number.parseInt(hourMatch[1], 10);
    if (hours > 0) {
      return Math.max(1, Math.min(Math.floor(16 / hours) + 1, 4));
    }
  }

  return 2;
}

function buildReminderItems(count, dose, timing) {
  const templates = [
    ['08:30', timingLabel('Morning dose', timing)],
    ['14:00', timingLabel('Midday dose', timing)],
    ['19:30', timingLabel('Evening dose', timing)],
    ['22:30', timingLabel('Optional bedtime dose', timing)]
  ];
  const reminders = [];
  for (let index = 0; index < count && index < templates.length; index += 1) {
    reminders.push({
      time: templates[index][0],
      label: templates[index][1],
      dose,
      source: 'Official leaflet how-to-take section'
    });
  }
  return reminders;
}

function timingLabel(defaultLabel, timing) {
  const lower = timing.toLowerCase();
  if (lower.includes('rano') || lower.includes('morning')) {
    return 'Morning dose';
  }
  if (lower.includes('before') && lower.includes('during') && lower.includes('after')) {
    return `${defaultLabel} - before, during, or after meals`;
  }
  if (lower.includes('after')) {
    return `${defaultLabel} - after meals`;
  }
  if (lower.includes('before')) {
    return `${defaultLabel} - before meals`;
  }
  if (lower.includes('with')) {
    return `${defaultLabel} - with meals`;
  }
  return defaultLabel;
}

function buildHowToTakeText(dose, frequency, timing, duration) {
  return [
    `Dose: ${dose}`,
    `Frequency: ${frequency}`,
    `Timing: ${timing}`,
    `Duration: ${duration}`
  ].join('\n');
}

function buildReminderWarning(ageMessage, reminderCount, frequency) {
  const parts = [];
  if (ageMessage.length > 0) {
    parts.push(ageMessage);
  }
  if (frequency.toLowerCase().match(/\d+\s*(?:to|-|–)\s*\d+/) || frequency.toLowerCase().match(/\d+\s*do\s*\d+/)) {
    parts.push('The leaflet gives a frequency range, so MediClear schedules the lower end by default. Add an extra dose only if the leaflet and your pharmacist/doctor allow it.');
  }
  if (reminderCount === 0) {
    parts.push('No automatic reminders were created.');
  }
  if (!parts.join(' ').includes('MediClear does not prescribe medicine')) {
    parts.push('Confirm the plan before use. MediClear does not prescribe medicine.');
  }
  return combineReminderMessages(parts);
}

function normalizePatientList(value) {
  const normalized = normalizeSafetyText(value);
  if (normalized.length === 0 || ['none', 'no', 'no known allergies', 'brak'].includes(normalized)) {
    return [];
  }
  return normalized
    .split(/[,;/]+|\s+and\s+|\s+or\s+/)
    .map((item) => item.trim())
    .filter((item) => item.length > 0 && !['none', 'no', 'brak'].includes(item));
}

function normalizeSafetyText(value) {
  return String(value ?? '')
    .toLowerCase()
    .replace(/ą/g, 'a')
    .replace(/ć/g, 'c')
    .replace(/ę/g, 'e')
    .replace(/ł/g, 'l')
    .replace(/ń/g, 'n')
    .replace(/ó/g, 'o')
    .replace(/ś/g, 's')
    .replace(/ź/g, 'z')
    .replace(/ż/g, 'z')
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function combineReminderMessages(messages) {
  const kept = [];
  for (const message of messages) {
    const clean = String(message ?? '').replace(/\s+/g, ' ').trim();
    if (clean.length > 0 && !kept.includes(clean)) {
      kept.push(clean);
    }
  }
  return kept.join(' ');
}

function fitChunksToContext(chunks, maxCharacters) {
  const selected = [];
  let total = 0;
  for (const chunk of chunks) {
    const length = chunk.chunk_text.length;
    if (selected.length > 0 && total + length > maxCharacters) {
      break;
    }
    selected.push(chunk);
    total += length;
  }
  return selected;
}

async function extractAndStore(input) {
  console.log(`[extract] start documentType=${input.documentType ?? 'leaflet'} productId=${input.productId ?? ''} url=${input.url}`);
  const pdfBuffer = await downloadPdf(input.url);
  console.log(`[extract] downloaded bytes=${pdfBuffer.length}`);
  const sourceHash = sha256(pdfBuffer);

  const extracted = await extractPdfText(pdfBuffer);
  console.log(`[extract] extracted method=${extracted.method} pages=${extracted.pages.length} textLength=${extracted.text.length}`);

  const chunks = splitIntoChunks(extracted.pages);
  console.log(`[extract] split chunks=${chunks.length}`);
  const status = extracted.text.length >= config.pdfTextMinLength ? 'ready' : 'text_too_short';

  const document = await upsertDocumentWithChunks({
    productId: input.productId ?? null,
    medicineName: input.medicineName ?? null,
    documentType: input.documentType ?? 'leaflet',
    sourceUrl: input.url,
    sourceHash,
    sourceSize: pdfBuffer.length,
    extractionMethod: extracted.method,
    status,
    textLength: extracted.text.length,
    preview: extracted.text.slice(0, 600),
    errorMessage: null
  }, chunks);
  console.log(`[extract] stored documentId=${document.id} status=${document.status}`);
  return document;
}

async function extractRplDocumentWithFallback(input) {
  if (!input.forceOcr) {
    const cached = await getLatestDocumentByProductIdAndType(input.productId, input.documentType);
    if (cached?.status === 'ready') {
      console.log(`[extract] using cached ${input.documentType} documentId=${cached.id} productId=${input.productId}`);
      return cached;
    }
  }

  const preferredTypes = input.documentType === 'characteristic'
    ? ['characteristic', 'leaflet']
    : ['leaflet', 'characteristic'];
  const errors = [];

  for (const documentType of preferredTypes) {
    const url = documentUrlForType(input, documentType);
    try {
      return await extractAndStore({
        url,
        productId: input.productId,
        medicineName: input.medicineName,
        documentType,
        forceOcr: input.forceOcr
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      errors.push(`${documentType}: ${message}`);
      if (!message.includes('HTTP 404')) {
        throw error;
      }
      console.warn(`[extract] ${documentType} unavailable for productId=${input.productId}; trying fallback`);
    }
  }

  const notFound = new Error(`No RPL PDF document is available for productId=${input.productId}. ${errors.join(' | ')}`);
  notFound.statusCode = 404;
  throw notFound;
}

function documentUrlForType(input, documentType) {
  if (documentType === 'leaflet' && input.leafletUrl?.length > 0) {
    return input.leafletUrl;
  }
  if (documentType === 'characteristic' && input.characteristicUrl?.length > 0) {
    return input.characteristicUrl;
  }
  return `https://rejestry.ezdrowie.gov.pl/api/rpl/medicinal-products/${input.productId}/${documentType}`;
}

app.use((error, _request, response, _next) => {
  console.error('[error]', error);
  if (error instanceof z.ZodError) {
    response.status(400).json({
      error: 'Invalid request',
      details: error.errors
    });
    return;
  }

  response.status(error.statusCode ?? 500).json({
    error: error instanceof Error ? error.message : 'Unknown server error'
  });
});

await initializeDatabase();

const server = app.listen(config.port, config.host, () => {
  console.log(`MediClear backend listening on http://${config.host}:${config.port}`);
});

async function shutdown() {
  server.close();
  await closeDatabase();
  process.exit(0);
}

process.on('SIGINT', () => {
  void shutdown();
});

process.on('SIGTERM', () => {
  void shutdown();
});



