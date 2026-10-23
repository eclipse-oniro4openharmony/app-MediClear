import fs from '@ohos.file.fs';
import http from '@ohos.net.http';
import { buildMedicineOcrUrl } from './BackendConfig';

class MedicineImageOcrResponse {
  text: string = '';
}

export class MedicineImageOcrService {
  async extractTextFromImage(path: string): Promise<string> {
    const fileSize = fs.statSync(path).size;
    if (fileSize <= 0) {
      throw new Error('The selected image is empty');
    }
    if (fileSize > 10 * 1024 * 1024) {
      throw new Error('Cloud OCR supports images up to 10 MB');
    }

    const contentType = this.getContentType(path);
    const fileName = path.substring(path.lastIndexOf('/') + 1);
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    let imageData: ArrayBuffer;
    try {
      imageData = new ArrayBuffer(fileSize);
      const bytesRead = fs.readSync(file.fd, imageData);
      if (bytesRead !== fileSize) {
        throw new Error('Could not read the complete selected image');
      }
    } finally {
      fs.closeSync(file.fd);
    }

    const request = http.createHttp();
    try {
      const response = await request.request(buildMedicineOcrUrl(), {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/octet-stream',
          'X-File-Name': fileName,
          'X-File-Type': contentType,
          'Accept': 'application/json'
        },
        extraData: imageData,
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 90000,
        connectTimeout: 15000
      });

      if (response.responseCode !== 200) {
        throw new Error('Cloud OCR request failed: ' + response.responseCode.toString());
      }

      const result = JSON.parse(response.result.toString()) as MedicineImageOcrResponse;
      return result.text.trim();
    } finally {
      request.destroy();
    }
  }

  private getContentType(path: string): string {
    const lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.png')) {
      return 'image/png';
    }
    if (lowerPath.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lowerPath.endsWith('.bmp')) {
      return 'image/bmp';
    }
    if (lowerPath.endsWith('.gif')) {
      return 'image/gif';
    }
    if (lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    throw new Error('Cloud OCR does not support this image format');
  }
}
