import { config } from './config.js';

function hasKnownAllergy(allergyHistory = '') {
  const normalized = allergyHistory.trim().toLowerCase();
  return normalized.length > 0 && normalized !== 'none' && normalized !== 'no' && normalized !== 'no known allergies';
}

function formatAllergyHistory(allergyHistory = '') {
  const value = allergyHistory.trim();
  if (value.length === 0) {
    return '';
  }
  return hasKnownAllergy(value) ? value : 'No known allergies reported';
}

function formatPatientContext(patientContext = {}) {
  const rows = [
    ['Sex', patientContext.sex],
    ['Age', patientContext.age],
    ['Weight', patientContext.weightKg ? `${patientContext.weightKg} kg` : ''],
    ['Current symptoms', patientContext.currentSymptoms],
    ['Allergy history', formatAllergyHistory(patientContext.allergyHistory)],
    ['Special status', patientContext.specialStatus]
  ]
    .filter((row) => typeof row[1] === 'string' && row[1].trim().length > 0)
    .map((row) => `- ${row[0]}: ${row[1].trim()}`);

  return rows.length > 0 ? rows.join('\n') : '- Not provided';
}

function buildSystemPrompt(medicineName, contextText, patientContext, dosageFacts = '') {
  const dosageFactBlock = dosageFacts.trim().length > 0
    ? `\nOptional extracted dosage facts for dosage questions:\n${dosageFacts.trim()}\n`
    : '';

  return `You are MediClear, a cautious medicine leaflet assistant.

Identity and boundaries:
- Answer only questions about the current medicine and its official leaflet/package information.
- Do not diagnose disease, prescribe medicines, choose medicines for the user, or replace a doctor or pharmacist.
- If the question is unrelated to the current medicine, politely refuse and ask the user to ask about this medicine.
- If the leaflet context does not contain the answer, say that the official leaflet context does not provide enough information.
- Never introduce dosage, timing, maximum dose, age limit, interactions, contraindications, ingredients, or side effects that are not explicitly present in the provided context or optional extracted facts.
- Keep answers clear, practical, and safety-focused.
- Language rule: always answer in the same language as the user's question. If the user asks in English, answer in English. If the user asks in Chinese, answer in Chinese. Do not answer in Polish unless the user's question is in Polish.
- The leaflet context may be Polish or another language. Treat it only as source material and translate the relevant extracted facts into the user's question language.
- Format answers with concise Markdown by default: use **bold section labels**, short bullet lists, and numbered steps when useful. Avoid large tables unless the leaflet context clearly supports them.
- Mention that users should follow the official leaflet and consult a doctor or pharmacist for personal medical decisions.

User-provided basic context:
${formatPatientContext(patientContext)}

Patient-context rules:
- Use the user's basic context only to explain whether leaflet warnings, contraindications, dosage notes, side effects, or doctor/pharmacist advice may be relevant.
- Do not infer a diagnosis from symptoms.
- Do not change the official leaflet dosage. If age, weight, pregnancy, breastfeeding, allergy history, or symptoms require caution, tell the user to confirm with a doctor or pharmacist.
- Do not claim that a user allergy matches this medicine unless the allergy term exactly or clearly matches an active ingredient, excipient, medicine class, or contraindication stated in the leaflet context.
- If the user allergy is not mentioned in the leaflet context, say it is not specifically listed in the provided leaflet context instead of treating it as a known contraindication.
- Do not repeat all personal context in every answer. Mention only context that is relevant to the user's question.
- If the user's allergy history appears to match the active ingredient, excipients, medicine class, or a leaflet contraindication, clearly say they should not take it unless a doctor/pharmacist confirms.
- If the user's custom symptoms or status are relevant but the leaflet context is insufficient to decide suitability, say that clearly before giving general leaflet usage information.
- If optional extracted dosage facts are provided, use them only when they are relevant to the user's question. Do not answer with dosage facts for symptoms, suitability, or interaction questions unless the user explicitly asks for dosage/how-to-take details.
- For dosage/how-to-take questions, preserve concrete numbers from the context exactly. Do not convert "3 to 4 times daily" into "maximum 3" or invent "empty stomach" unless those exact ideas are present in the context.

Current medicine: ${medicineName || 'Unknown medicine'}
${dosageFactBlock}

Official leaflet knowledge base:
${contextText}`;
}

function detectQuestionLanguage(question) {
  if (/[\u4e00-\u9fff]/.test(question)) {
    return 'Chinese';
  }

  const lower = question.toLowerCase();
  const polishSignals = ['ą', 'ć', 'ę', 'ł', 'ń', 'ó', 'ś', 'ź', 'ż'];
  if (polishSignals.some((signal) => lower.includes(signal))) {
    return 'Polish';
  }

  return 'English';
}

function buildQuestionSpecificInstruction() {
  return `
Before answering, infer the user's intent from the question. Use the official leaflet context and optional extracted facts as evidence.
Treat the user's basic context as exact user-provided facts. Do not replace the user's symptoms with leaflet indications. For example, if the user says their current symptom is fever, evaluate fever against the leaflet context; do not answer as if the user's symptom were bloating unless the user provided bloating.

Intent handling:
- If the user asks how to take the medicine, answer dose per intake, frequency, timing, maximum daily dose or overdose warning, duration, and route/method when present. Do not answer only with reminder times. If a field is missing, say it is not found in the provided leaflet context.
- For how-to-take answers, quote or paraphrase the exact concrete dosage evidence from "Optional extracted dosage facts" and the how-to-take section. Keep numbers unchanged. Do not add any dose limit, food timing, or schedule that is not in those sources.
- If the user asks whether they can take it with their symptoms or personal context, check indications, contraindications, warnings, allergies/excipients, age, weight, sex, special status, and doctor/pharmacist advice first. Do not make dosage the main answer unless the user also asks for dosage. Do not say the user can take it for a symptom unless that exact symptom or a direct synonym appears in the leaflet indication/context. If the symptom is not listed, say the leaflet context is insufficient to confirm suitability for that symptom.
- If the user asks about taking it with other medicines, check interaction/other-medicines warnings first. If not listed or unknown, say so and advise doctor/pharmacist confirmation.
- If the user asks about side effects, use side effects/adverse reactions context first.
- If the user asks about storage or expiration, use storage context first.
- If the question is unrelated to the current medicine, refuse briefly.
`;
}

function extractAnswer(responseJson) {
  const choice = responseJson?.choices?.[0];
  const content = choice?.message?.content;
  if (typeof content === 'string' && content.trim().length > 0) {
    return content.trim();
  }
  throw new Error('LLM response did not include an assistant message');
}

export async function askDeepSeekWithKnowledgeBase(input) {
  const questionLanguage = detectQuestionLanguage(input.question);
  const patientContextBlock = formatPatientContext(input.patientContext);
  const optionalFacts = input.dosageFacts?.trim() ?? '';
  const optionalFactsBlock = optionalFacts.length > 0
    ? `\nOptional extracted dosage facts from the leaflet. Use these only if they match the user's intent:\n${optionalFacts}\n`
    : '';
  const messages = [
    {
      role: 'system',
      content: buildSystemPrompt(input.medicineName, input.contextText, input.patientContext, input.dosageFacts)
    },
    {
      role: 'user',
      content: `User question language: ${questionLanguage}.
Answer language requirement: answer ONLY in ${questionLanguage}. Do not switch to the leaflet language unless it is also ${questionLanguage}.
${buildQuestionSpecificInstruction()}
User-provided basic context for this question:
${patientContextBlock}
${optionalFactsBlock}

Question:
${input.question}`
    }
  ];

  const headers = {
    'Content-Type': 'application/json'
  };
  if (config.llmApiKey) {
    headers.Authorization = `Bearer ${config.llmApiKey}`;
  }

  const response = await fetch(`${config.llmBaseUrl.replace(/\/$/, '')}/chat/completions`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      model: config.llmModel,
      messages,
      temperature: 0,
      max_tokens: 700
    })
  });

  const responseText = await response.text();
  if (!response.ok) {
    throw new Error(`LLM request failed: HTTP ${response.status} ${responseText}`);
  }

  return extractAnswer(JSON.parse(responseText));
}


