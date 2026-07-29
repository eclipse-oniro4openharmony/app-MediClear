import { common, Want } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import fs from '@ohos.file.fs';

export class PickedMedicineGuide {
  originalUri: string = '';
  sandboxPath: string = '';
}

export class MedicineGuideMediaHelper {
  private context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  async selectPicture(): Promise<PickedMedicineGuide> {
    const options = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    const pickerView = new photoAccessHelper.PhotoViewPicker();
    const result = await pickerView.select(options);
    if (!result || !result.photoUris || result.photoUris.length === 0) {
      throw new Error('No photo selected');
    }
    const originalUri = result.photoUris[0];
    return this.copyPickedUri(originalUri, 'userUploadedMedicineGuide', this.extensionFromUri(originalUri, '.jpg'));
  }

  async selectFile(): Promise<PickedMedicineGuide> {
    const options = new picker.DocumentSelectOptions();
    const documentPicker = new picker.DocumentViewPicker();
    const result = await documentPicker.select(options);
    if (!result || result.length === 0) {
      throw new Error('No file selected');
    }
    const originalUri = result[0];
    return this.copyPickedUri(originalUri, 'userUploadedMedicineGuide', this.extensionFromUri(originalUri, '.pdf'));
  }

  async takePhoto(context: common.UIAbilityContext): Promise<PickedMedicineGuide> {
    const want: Want = {
      uri: '',
      action: 'ohos.want.action.imageCapture'
    };
    const result = await context.startAbilityForResult(want);
    let originalUri = '';
    if (result.want && result.want.parameters && result.want.parameters['resourceUri']) {
      originalUri = result.want.parameters['resourceUri'].toString();
    } else if (result.want && result.want.uri) {
      originalUri = result.want.uri;
    }
    if (originalUri.length === 0) {
      throw new Error('Camera did not return an image URI');
    }

    // ONIROGPT uses this camera URI directly for its media bean. Try to copy if readable;
    // if the device returns a non-readable resource URI, keep the original for upload diagnostics.
    try {
      return this.copyPickedUri(originalUri, 'userCapturedMedicineGuide', this.extensionFromUri(originalUri, '.jpg'));
    } catch (err) {
      const picked = new PickedMedicineGuide();
      picked.originalUri = originalUri;
      picked.sandboxPath = originalUri;
      return picked;
    }
  }

  private copyPickedUri(originalUri: string, filePrefix: string, extension: string): PickedMedicineGuide {
    const sandboxPath = this.context.filesDir + '/' + filePrefix + '_' + Date.now().toString() + extension;
    const source = fs.openSync(originalUri, fs.OpenMode.READ_ONLY);
    const target = fs.openSync(sandboxPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.copyFileSync(source.fd, target.fd);
    } finally {
      fs.closeSync(source.fd);
      fs.closeSync(target.fd);
    }
    const picked = new PickedMedicineGuide();
    picked.originalUri = originalUri;
    picked.sandboxPath = sandboxPath;
    return picked;
  }

  private extensionFromUri(uri: string, fallback: string): string {
    const lower = uri.toLowerCase();
    if (lower.indexOf('.pdf') >= 0) {
      return '.pdf';
    }
    if (lower.indexOf('.png') >= 0) {
      return '.png';
    }
    if (lower.indexOf('.webp') >= 0) {
      return '.webp';
    }
    if (lower.indexOf('.jpeg') >= 0) {
      return '.jpeg';
    }
    if (lower.indexOf('.jpg') >= 0) {
      return '.jpg';
    }
    return fallback;
  }
}
