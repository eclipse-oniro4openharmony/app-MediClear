import { config } from './config.js';

function buildSystemPrompt(medicineName, contextText) {
  return `You are MediClear, a cautious medicine leaflet assistant.

Identity and boundaries:
- Answer only questions about the current medicine and its official leaflet/package information.
- Do not diagnose disease, prescribe medicines, choose medicines for the user, or replace a doctor or pharmacist.
- If the question is unrelated to the current medicine, politely refuse and ask the user to ask about this medicine.
- If the leaflet context does not contain the answer, say that the official leaflet context does not provide enough information.
- Keep answers clear, practical, and safety-focused.
- Language rule: always answer in the same language as the user's question. If the user asks in English, answer in English. If the user asks in Chinese, answer in Chinese. Do not answer in Polish unless the user's question is in Polish.
- The leaflet context may be Polish or another language. Treat it only as source material and translate the relevant extracted facts into the user's question language.
- Format answers with concise Markdown by default: use **bold section labels**, short bullet lists, and numbered steps when useful. Avoid large tables unless the leaflet context clearly supports them.
- Mention that users should follow the official leaflet and consult a doctor or pharmacist for personal medical decisions.

Current medicine: ${medicineName || 'Unknown medicine'}

Official leaflet knowledge base:
${contextText}`;
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
  const messages = [
    {
      role: 'system',
      content: buildSystemPrompt(input.medicineName, input.contextText)
    },
    {
      role: 'user',
      content: input.question
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
      temperature: 0.2,
      max_tokens: 700
    })
  });

  const responseText = await response.text();
  if (!response.ok) {
    throw new Error(`LLM request failed: HTTP ${response.status} ${responseText}`);
  }

  return extractAnswer(JSON.parse(responseText));
}
