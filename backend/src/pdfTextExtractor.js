import { createHash } from 'node:crypto';
import { config } from './config.js';

export function sha256(buffer) {
  return createHash('sha256').update(buffer).digest('hex');
}

export async function downloadPdf(url) {
  const response = await fetch(url, {
    headers: {
      Accept: 'application/pdf'
    }
  });

  if (!response.ok) {
    throw new Error(`PDF download failed: HTTP ${response.status}`);
  }

  const contentType = response.headers.get('content-type') ?? '';
  if (!contentType.toLowerCase().includes('application/pdf')) {
    throw new Error(`Expected PDF, got ${contentType || 'unknown content type'}`);
  }

  return Buffer.from(await response.arrayBuffer());
}

export async function extractPdfText(buffer) {
  const pdfjs = await import('pdfjs-dist/legacy/build/pdf.mjs');
  const loadingTask = pdfjs.getDocument({
    data: new Uint8Array(buffer),
    disableFontFace: true,
    isEvalSupported: false,
    useSystemFonts: true
  });

  const pdf = await loadingTask.promise;
  const pages = [];

  for (let pageNumber = 1; pageNumber <= pdf.numPages; pageNumber += 1) {
    const page = await pdf.getPage(pageNumber);
    const textContent = await page.getTextContent();
    const text = textContent.items
      .map((item) => typeof item.str === 'string' ? item.str : '')
      .join(' ')
      .replace(/\s+/g, ' ')
      .trim();

    pages.push({ pageNumber, text });
  }

  await pdf.destroy();

  return {
    method: 'pdfjs-dist',
    pages,
    text: pages.map((page) => page.text).join('\n\n').trim()
  };
}

export function splitIntoChunks(pages) {
  const chunks = [];
  let chunkIndex = 0;

  for (const section of splitPagesIntoSections(pages)) {
    let start = 0;
    const text = section.text.trim();
    while (start < text.length) {
      const end = Math.min(start + config.chunkSize, text.length);
      const chunkText = text.slice(start, end).trim();

      if (chunkText.length > 0) {
        chunks.push({
          chunkIndex,
          pageNumber: section.pageNumber,
          sectionType: section.sectionType,
          sectionTitle: section.sectionTitle,
          chunkText
        });
        chunkIndex += 1;
      }

      if (end === text.length) {
        break;
      }
      start = Math.max(end - config.chunkOverlap, start + 1);
    }
  }

  return chunks;
}

function splitPagesIntoSections(pages) {
  const fullTextParts = [];
  const pageOffsets = [];
  let offset = 0;

  for (const page of pages) {
    pageOffsets.push({
      pageNumber: page.pageNumber,
      start: offset,
      end: offset + page.text.length
    });
    fullTextParts.push(page.text);
    offset += page.text.length + 2;
  }

  const fullText = fullTextParts.join('\n\n').trim();
  if (fullText.length === 0) {
    return [];
  }

  const sectionBoundaries = detectLeafletSectionBoundaries(fullText);
  if (sectionBoundaries.length === 0) {
    return pages.map((page) => ({
      sectionType: null,
      sectionTitle: null,
      pageNumber: page.pageNumber,
      text: page.text
    }));
  }

  const sections = [];
  if (sectionBoundaries[0].index > 0) {
    sections.push({
      sectionType: null,
      sectionTitle: null,
      pageNumber: pageNumberForOffset(pageOffsets, 0),
      text: fullText.slice(0, sectionBoundaries[0].index).trim()
    });
  }

  for (let i = 0; i < sectionBoundaries.length; i += 1) {
    const current = sectionBoundaries[i];
    const next = sectionBoundaries[i + 1];
    sections.push({
      sectionType: current.sectionType,
      sectionTitle: current.sectionTitle,
      pageNumber: pageNumberForOffset(pageOffsets, current.index),
      text: fullText.slice(current.index, next?.index ?? fullText.length).trim()
    });
  }

  return sections.filter((section) => section.text.length > 0);
}

function detectLeafletSectionBoundaries(text) {
  const tocBoundaries = detectSectionBoundariesFromToc(text);
  if (tocBoundaries.length > 0) {
    return tocBoundaries;
  }

  const candidates = Array.from(text.matchAll(/(?:^|\s)(\d{1,2})\s*[\.\)]\s+.{0,90}/g))
    .map((match) => ({
      sectionType: sectionTypeForNumber(match[1]),
      sectionTitle: cleanSectionTitle(match[0] ?? ''),
      sectionNumber: Number.parseInt(match[1], 10),
      index: Math.max(match.index ?? 0, 0),
    }))
    .filter((candidate) => candidate.sectionNumber > 0);

  const orderedBoundaries = findBestOrderedSectionRun(candidates);
  if (orderedBoundaries.length > 0) {
    return orderedBoundaries;
  }

  const lastCandidateBySection = new Map();
  for (const candidate of candidates) {
    lastCandidateBySection.set(candidate.sectionNumber, candidate);
  }

  return Array.from(lastCandidateBySection.values())
    .sort((left, right) => left.index - right.index);
}

function detectSectionBoundariesFromToc(text) {
  const numberMatches = Array.from(text.matchAll(/(?:^|\s)(\d{1,2})\s*[\.\)]\s+/g))
    .map((match) => ({
      sectionNumber: Number.parseInt(match[1], 10),
      index: Math.max(match.index ?? 0, 0),
      end: Math.max(match.index ?? 0, 0) + (match[0]?.length ?? 0)
    }))
    .filter((match) => match.sectionNumber > 0);

  const tocRun = findTocRun(numberMatches);
  if (tocRun.length < 3) {
    return [];
  }

  const compact = compactTextWithMap(text);
  const matchAfterToc = numberMatches.find((match) => match.index > tocRun[tocRun.length - 1].index);
  const tocEnd = matchAfterToc?.index ?? tocRun[tocRun.length - 1].end;
  const boundaries = [];

  for (let i = 0; i < tocRun.length; i += 1) {
    const current = tocRun[i];
    const next = tocRun[i + 1];
    const titleEnd = next?.index ?? tocEnd;
    const title = text.slice(current.end, titleEnd).trim();
    const compactTitle = compactPlainText(title);

    if (compactTitle.length < 8) {
      continue;
    }

    const compactSearchStart = compact.map.findIndex((originalIndex) => originalIndex >= tocEnd);
    const foundAt = compact.text.indexOf(compactTitle, Math.max(compactSearchStart, 0));
    if (foundAt < 0) {
      continue;
    }

    boundaries.push({
      sectionType: sectionTypeForNumber(current.sectionNumber.toString()),
      sectionTitle: cleanSectionTitle(title),
      sectionNumber: current.sectionNumber,
      index: compact.map[foundAt] ?? current.index
    });
  }

  return boundaries
    .sort((left, right) => left.index - right.index);
}

function findTocRun(matches) {
  let bestRun = [];

  for (let startIndex = 0; startIndex < matches.length; startIndex += 1) {
    const run = [matches[startIndex]];
    let expectedNumber = matches[startIndex].sectionNumber + 1;
    let previousIndex = matches[startIndex].index;

    for (let i = startIndex + 1; i < matches.length; i += 1) {
      const candidate = matches[i];
      if (candidate.sectionNumber !== expectedNumber) {
        continue;
      }

      const gap = candidate.index - previousIndex;
      if (gap > 220) {
        break;
      }

      run.push(candidate);
      expectedNumber += 1;
      previousIndex = candidate.index;
    }

    if (run.length > bestRun.length) {
      bestRun = run;
    }
  }

  return bestRun;
}

function findBestOrderedSectionRun(candidates) {
  let bestRun = [];

  for (let startIndex = 0; startIndex < candidates.length; startIndex += 1) {
    const start = candidates[startIndex];
    const run = [start];
    let expectedNumber = start.sectionNumber + 1;
    let previousIndex = start.index;

    for (let i = startIndex + 1; i < candidates.length; i += 1) {
      const candidate = candidates[i];
      if (candidate.sectionNumber !== expectedNumber) {
        continue;
      }

      const gap = candidate.index - previousIndex;
      if (gap < 180) {
        continue;
      }

      run.push(candidate);
      expectedNumber += 1;
      previousIndex = candidate.index;
    }

    if (run.length > bestRun.length ||
      (run.length === bestRun.length && run[0].index > (bestRun[0]?.index ?? -1))) {
      bestRun = run;
    }
  }

  return bestRun.length >= 2 ? bestRun : [];
}

function normalizeSectionText(text) {
  return text
    .replace(/\s+/g, ' ')
    .replace(/M ożliwe/g, 'Możliwe')
    .replace(/J ak/g, 'Jak')
    .replace(/C o/g, 'Co')
    .trim();
}

function compactTextWithMap(text) {
  let compact = '';
  const map = [];

  for (let i = 0; i < text.length; i += 1) {
    const char = text[i].toLowerCase();
    if (/[\p{L}\p{N}]/u.test(char)) {
      compact += char;
      map.push(i);
    }
  }

  return { text: compact, map };
}

function compactPlainText(text) {
  return text
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]/gu, '');
}

function cleanSectionTitle(text) {
  return normalizeSectionText(text)
    .replace(/^\d{1,2}\s*[\.\)]\s*/, '')
    .replace(/\s+\d{1,2}\s*[\.\)]?\s*$/, '')
    .trim();
}

function sectionTypeForNumber(sectionNumber) {
  switch (sectionNumber) {
    case '1':
      return 'what_is_it';
    case '2':
      return 'before_use';
    case '3':
      return 'how_to_take';
    case '4':
      return 'side_effects';
    case '5':
      return 'storage';
    case '6':
      return 'contents';
    default:
      return `section_${sectionNumber}`;
  }
}

function pageNumberForOffset(pageOffsets, textOffset) {
  for (const page of pageOffsets) {
    if (textOffset >= page.start && textOffset <= page.end) {
      return page.pageNumber;
    }
  }
  return pageOffsets[pageOffsets.length - 1]?.pageNumber ?? null;
}
