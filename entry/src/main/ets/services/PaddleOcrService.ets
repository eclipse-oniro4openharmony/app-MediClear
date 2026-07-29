import http from '@ohos.net.http';
import fs from '@ohos.file.fs';
import { image } from '@kit.ImageKit';

class PaddleOptionalPayload {
  useDocOrientationClassify: boolean = false;
  useDocUnwarping: boolean = false;
  useChartRecognition: boolean = false;
}

class TextPart {
  name: string;
  value: string;

  constructor(name: string, value: string) {
    this.name = name;
    this.value = value;
  }
}

class FilePart {
  fieldName: string;
  filename: string;
  mime: string;
  content: Uint8Array;

  constructor(fieldName: string, filename: string, mime: string, content: Uint8Array) {
    this.fieldName = fieldName;
    this.filename = filename;
    this.mime = mime;
    this.content = content;
  }
}

class PaddleFormData implements http.MultiFormData {
  name: string;
  contentType: string;
  remoteFileName?: string;
  data?: string | ArrayBuffer;
  filePath?: string;

  constructor(name: string, contentType: string, data: string | ArrayBuffer | null, filePath: string, remoteFileName: string) {
    this.name = name;
    this.contentType = contentType;
    if (data !== null) {
      this.data = data;
    }
    if (filePath.length > 0) {
      this.filePath = filePath;
    }
    if (remoteFileName.length > 0) {
      this.remoteFileName = remoteFileName;
    }
  }
}

class PaddleJobData {
  jobId: string = '';
  state: string = '';
  errorMsg: string = '';
  resultUrl: PaddleResultUrl = new PaddleResultUrl();
}

class PaddleResultUrl {
  jsonUrl: string = '';
}

class PaddleJobResponse {
  data: PaddleJobData = new PaddleJobData();
}

class PaddleMarkdown {
  text: string = '';
}

class PaddleLayoutResult {
  markdown: PaddleMarkdown = new PaddleMarkdown();
}

class PaddleLineResult {
  layoutParsingResults: PaddleLayoutResult[] = [];
}

class PaddleJsonLine {
  result: PaddleLineResult = new PaddleLineResult();
}

class PaddleHttpError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'PaddleHttpError';
  }
}

export class PaddleOcrService {
  private readonly JOB_URL: string = 'https://paddleocr.aistudio-app.com/api/v2/ocr/jobs';
  private readonly TOKEN: string = '74861f9edddffb5aa3cd598749339b1ff3f82cbc';
  private readonly MODEL: string = 'PP-StructureV3';

  async extractTextFromFile(uri: string): Promise<string> {
    return this.withTimeout(this.extractTextFromFileInternal(uri), 90000, 'PaddleOCR request timed out after 90 seconds');
  }

  private async extractTextFromFileInternal(uri: string): Promise<string> {
    const jobId = await this.submitLocalFile(uri);
    const jsonUrl = await this.pollJob(jobId);
    const text = await this.downloadMarkdownText(jsonUrl);
    if (text.length === 0) {
      throw new Error('PaddleOCR returned an empty OCR result');
    }
    return text;
  }

  private async submitLocalFile(uri: string): Promise<string> {
    console.info('[MediClearOCR] submitLocalFile path=' + uri);
    const filename = this.filenameFromUri(uri);
    const isPdf = filename.toLowerCase().endsWith('.pdf');
    const fileBytes = isPdf ? this.readAllBytes(uri) : await this.compressImageBytes(uri);
    const uploadFilename = isPdf ? filename : 'medicine-guide.jpg';
    const uploadMime = isPdf ? 'application/pdf' : 'image/jpeg';
    console.info('[MediClearOCR] upload bytes=' + fileBytes.length.toString() + ' filename=' + uploadFilename);
    const boundary = '----MediClearPaddleOCR' + Date.now().toString();
    const optionalPayload = new PaddleOptionalPayload();
    const textParts: TextPart[] = [
      new TextPart('model', this.MODEL),
      new TextPart('optionalPayload', JSON.stringify(optionalPayload))
    ];
    const body = this.buildMultipart(
      boundary,
      textParts,
      new FilePart('file', uploadFilename, uploadMime, fileBytes)
    );
    console.info('[MediClearOCR] compressed multipart body bytes=' + body.length.toString());

    const request = http.createHttp();
    try {
      console.info('[MediClearOCR] submit request start');
      const response = await request.request(this.JOB_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Authorization': 'bearer ' + this.TOKEN,
          'Content-Type': 'multipart/form-data; boundary=' + boundary,
          'Accept': 'application/json'
        },
        extraData: body.buffer,
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 120000,
        connectTimeout: 30000
      });

      console.info('[MediClearOCR] submit responseCode=' + response.responseCode.toString());
      if (response.responseCode !== 200) {
        throw new PaddleHttpError('PaddleOCR submit failed: ' + response.responseCode.toString() + ' ' + response.result.toString());
      }

      const parsed = JSON.parse(response.result.toString()) as PaddleJobResponse;
      console.info('[MediClearOCR] jobId=' + parsed.data.jobId);
      return parsed.data.jobId;
    } finally {
      request.destroy();
    }
  }

  private async pollJob(jobId: string): Promise<string> {
    for (let attempt = 0; attempt < 18; attempt++) {
      console.info('[MediClearOCR] poll attempt=' + attempt.toString() + ' jobId=' + jobId);
      const request = http.createHttp();
      try {
        const response = await request.request(this.JOB_URL + '/' + jobId, {
          method: http.RequestMethod.GET,
          header: {
            'Authorization': 'bearer ' + this.TOKEN,
            'Accept': 'application/json'
          },
          expectDataType: http.HttpDataType.STRING,
          readTimeout: 60000,
          connectTimeout: 30000
        });

        if (response.responseCode !== 200) {
          throw new Error('PaddleOCR polling failed: ' + response.responseCode.toString());
        }

        const parsed = JSON.parse(response.result.toString()) as PaddleJobResponse;
        console.info('[MediClearOCR] poll state=' + parsed.data.state);
        if (parsed.data.state === 'done') {
          console.info('[MediClearOCR] result jsonUrl=' + parsed.data.resultUrl.jsonUrl);
          return parsed.data.resultUrl.jsonUrl;
        }
        if (parsed.data.state === 'failed') {
          throw new Error('PaddleOCR job failed: ' + parsed.data.errorMsg);
        }
      } finally {
        request.destroy();
      }
      await this.sleep(3000);
    }
    throw new Error('PaddleOCR polling timed out before the job finished');
  }

  private async downloadMarkdownText(jsonUrl: string): Promise<string> {
    console.info('[MediClearOCR] download jsonUrl=' + jsonUrl);
    const request = http.createHttp();
    try {
      const response = await request.request(jsonUrl, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 120000,
        connectTimeout: 30000
      });

      if (response.responseCode !== 200) {
        throw new Error('PaddleOCR result download failed: ' + response.responseCode.toString());
      }

      const text = this.parseJsonlMarkdown(response.result.toString());
      console.info('[MediClearOCR] parsed markdown length=' + text.length.toString());
      return text;
    } finally {
      request.destroy();
    }
  }

  private parseJsonlMarkdown(jsonl: string): string {
    const lines = jsonl.split('\n');
    const texts: string[] = [];
    for (let lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      const line = lines[lineIndex].trim();
      if (line.length === 0) {
        continue;
      }
      const parsed = JSON.parse(line) as PaddleJsonLine;
      for (let resultIndex = 0; resultIndex < parsed.result.layoutParsingResults.length; resultIndex++) {
        const text = parsed.result.layoutParsingResults[resultIndex].markdown.text;
        if (text.length > 0) {
          texts.push(text);
        }
      }
    }
    return texts.join('\n\n').trim();
  }

  private readAllBytes(path: string): Uint8Array {
    console.info('[MediClearOCR] readAllBytes start path=' + path);
    const stat = fs.statSync(path);
    console.info('[MediClearOCR] readAllBytes stat size=' + stat.size.toString());
    const buffer = new ArrayBuffer(stat.size);
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    let offset = 0;
    try {
      while (offset < stat.size) {
        const readSize = fs.readSync(file.fd, buffer, { offset: offset, length: stat.size - offset });
        if (readSize <= 0) {
          break;
        }
        offset += readSize;
      }
    } finally {
      fs.closeSync(file.fd);
    }
    return new Uint8Array(buffer, 0, offset);
  }

  private async compressImageBytes(path: string): Promise<Uint8Array> {
    const originalSize = fs.statSync(path).size;
    console.info('[MediClearOCR] compress image original bytes=' + originalSize.toString());
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    try {
      const source = image.createImageSource(file.fd);
      const pixelMap = await source.createPixelMap({ editable: false });
      const packer = image.createImagePacker();
      const packed = await packer.packToData(pixelMap, { format: 'image/jpeg', quality: 45 });
      const bytes = new Uint8Array(packed);
      console.info('[MediClearOCR] compressed image bytes=' + bytes.length.toString());
      return bytes;
    } finally {
      fs.closeSync(file.fd);
    }
  }

  private filenameFromUri(uri: string): string {
    const questionIndex = uri.indexOf('?');
    const cleanUri = questionIndex >= 0 ? uri.substring(0, questionIndex) : uri;
    const slashIndex = cleanUri.lastIndexOf('/');
    const filename = slashIndex >= 0 ? cleanUri.substring(slashIndex + 1) : cleanUri;
    if (filename.length === 0) {
      return 'medicine-guide.jpg';
    }
    return filename;
  }

  private mimeFromName(name: string): string {
    const lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  private utf8(value: string): Uint8Array {
    const bytes: number[] = [];
    for (let index = 0; index < value.length; index++) {
      const code = value.charCodeAt(index);
      if (code <= 0x7F) {
        bytes.push(code);
      } else if (code <= 0x7FF) {
        bytes.push(0xC0 | (code >> 6));
        bytes.push(0x80 | (code & 0x3F));
      } else {
        bytes.push(0xE0 | (code >> 12));
        bytes.push(0x80 | ((code >> 6) & 0x3F));
        bytes.push(0x80 | (code & 0x3F));
      }
    }
    return new Uint8Array(bytes);
  }

  private buildMultipart(boundary: string, textParts: TextPart[], filePart: FilePart): Uint8Array {
    const parts: Uint8Array[] = [];
    for (let index = 0; index < textParts.length; index++) {
      const part = textParts[index];
      parts.push(this.utf8('--' + boundary + '\r\n'));
      parts.push(this.utf8('Content-Disposition: form-data; name="' + part.name + '"\r\n\r\n'));
      parts.push(this.utf8(part.value));
      parts.push(this.utf8('\r\n'));
    }

    parts.push(this.utf8('--' + boundary + '\r\n'));
    parts.push(this.utf8(
      'Content-Disposition: form-data; name="' + filePart.fieldName + '"; filename="' + filePart.filename + '"\r\n' +
        'Content-Type: ' + filePart.mime + '\r\n\r\n'
    ));
    parts.push(filePart.content);
    parts.push(this.utf8('\r\n--' + boundary + '--\r\n'));

    let total = 0;
    for (let index = 0; index < parts.length; index++) {
      total += parts[index].length;
    }
    const body = new Uint8Array(total);
    let offset = 0;
    for (let index = 0; index < parts.length; index++) {
      body.set(parts[index], offset);
      offset += parts[index].length;
    }
    return body;
  }

  private sleep(milliseconds: number): Promise<void> {
    return new Promise((resolve: () => void) => {
      setTimeout(resolve, milliseconds);
    });
  }

  private withTimeout(task: Promise<string>, milliseconds: number, message: string): Promise<string> {
    return new Promise((resolve: (value: string) => void, reject: (reason: Error) => void) => {
      const timer = setTimeout(() => {
        reject(new Error(message));
      }, milliseconds);
      task.then((value: string) => {
        clearTimeout(timer);
        resolve(value);
      }).catch((error: Error) => {
        clearTimeout(timer);
        reject(error);
      });
    });
  }
}
