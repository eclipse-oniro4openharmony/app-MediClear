import { config } from './config.js';

function buildSystemPrompt(medicineName, contextText) {
  return `You are MediClear, a cautious medicine leaflet assistant.

Identity and boundaries:
- Answer only questions about the current medicine and its official leaflet/package information.
- Do not diagnose disease, prescribe medicines, choose medicines for the user, or replace a doctor or pharmacist.
- If the question is unrelated to the current medicine, politely refuse and ask the user to ask about this medicine.
- If the leaflet context does not contain the answer, say that the official leaflet context does not provide enough information.
- Keep answers clear, practical, and safety-focused.
- Answer in the same language as the user's question. If the leaflet context is in another language, translate only the relevant extracted facts.
- Use plain text only. Do not use Markdown formatting such as **bold**, tables, or headings.
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
  throw new Error('DeepSeek response did not include an assistant message');
}

export async function askDeepSeekWithKnowledgeBase(input) {
  if (!config.deepseekApiKey) {
    throw new Error('DEEPSEEK_API_KEY is not configured');
  }

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

  const response = await fetch(`${config.deepseekBaseUrl}/chat/completions`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${config.deepseekApiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: config.deepseekModel,
      messages,
      temperature: 0.2,
      max_tokens: 700
    })
  });

  const responseText = await response.text();
  if (!response.ok) {
    throw new Error(`DeepSeek request failed: HTTP ${response.status} ${responseText}`);
  }

  return extractAnswer(JSON.parse(responseText));
}
