import fs from '@ohos.file.fs';
import http from '@ohos.net.http';
import { image } from '@kit.ImageKit';
import { buildMedicineOcrUrl } from './BackendConfig';

class MedicineImageOcrResponse {
  text: string = '';
}

class MedicineImageOcrErrorResponse {
  error: string = '';
}

export class MedicineImageOcrService {
  async extractTextFromImage(path: string): Promise<string> {
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    let imageSource: image.ImageSource | undefined;
    let pixelMap: image.PixelMap | undefined;
    let imagePacker: image.ImagePacker | undefined;
    let imageData: ArrayBuffer;
    try {
      const source = image.createImageSource(file.fd);
      imageSource = source;
      const imageInfo = await source.getImageInfo();
      const sourceWidth = imageInfo.size.width;
      const sourceHeight = imageInfo.size.height;
      if (sourceWidth <= 0 || sourceHeight <= 0) {
        throw new Error('The selected image has invalid dimensions');
      }

      const maxDimension = 1600;
      const scale = Math.min(1, maxDimension / Math.max(sourceWidth, sourceHeight));
      const resizedPixelMap = await source.createPixelMap({
        desiredSize: {
          width: Math.max(1, Math.round(sourceWidth * scale)),
          height: Math.max(1, Math.round(sourceHeight * scale))
        }
      });
      pixelMap = resizedPixelMap;

      const packer = image.createImagePacker();
      imagePacker = packer;
      imageData = await packer.packToData(resizedPixelMap, {
        format: 'image/jpeg',
        quality: 85
      });
    } finally {
      if (imagePacker) {
        try {
          await imagePacker.release();
        } catch (error) {
          console.warn('[MediClearOCR] failed to release image packer: ' + JSON.stringify(error));
        }
      }
      if (pixelMap) {
        try {
          await pixelMap.release();
        } catch (error) {
          console.warn('[MediClearOCR] failed to release pixel map: ' + JSON.stringify(error));
        }
      }
      if (imageSource) {
        try {
          await imageSource.release();
        } catch (error) {
          console.warn('[MediClearOCR] failed to release image source: ' + JSON.stringify(error));
        }
      }
      fs.closeSync(file.fd);
    }

    const request = http.createHttp();
    try {
      const response = await request.request(buildMedicineOcrUrl(), {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/octet-stream',
          'X-File-Name': 'medicine-image.jpg',
          'X-File-Type': 'image/jpeg',
          'Accept': 'application/json'
        },
        extraData: imageData,
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 90000,
        connectTimeout: 15000
      });

      if (response.responseCode !== 200) {
        let errorMessage = 'Cloud OCR request failed: ' + response.responseCode.toString();
        try {
          const errorResult = JSON.parse(response.result.toString()) as MedicineImageOcrErrorResponse;
          if (typeof errorResult.error === 'string' && errorResult.error.length > 0) {
            errorMessage = errorResult.error;
          }
        } catch (_error) {
        }
        throw new Error(errorMessage);
      }

      const result = JSON.parse(response.result.toString()) as MedicineImageOcrResponse;
      return result.text.trim();
    } finally {
      request.destroy();
    }
  }
}
