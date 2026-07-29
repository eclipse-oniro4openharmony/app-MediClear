import fs from '@ohos.file.fs';
import { image } from '@kit.ImageKit';
import { textRecognition } from '@kit.CoreVisionKit';

class CoreVisionInfo implements textRecognition.VisionInfo {
  pixelMap: image.PixelMap;

  constructor(pixelMap: image.PixelMap) {
    this.pixelMap = pixelMap;
  }
}

class CoreVisionTextConfig implements textRecognition.TextRecognitionConfiguration {
  isDirectionDetectionSupported: boolean = true;
}

export class CoreVisionOcrService {
  async extractTextFromImage(path: string): Promise<string> {
    console.info('[MediClearCoreVisionOCR] start path=' + path);
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    try {
      const source = image.createImageSource(file.fd);
      const pixelMap = await source.createPixelMap({ editable: false });
      const visionInfo = new CoreVisionInfo(pixelMap);
      const config = new CoreVisionTextConfig();
      const result = await textRecognition.recognizeText(visionInfo, config);
      const text = result.value.trim();
      console.info('[MediClearCoreVisionOCR] text length=' + text.length.toString());
      return text;
    } finally {
      fs.closeSync(file.fd);
    }
  }
}
