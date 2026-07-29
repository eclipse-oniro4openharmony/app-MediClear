import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import fs from '@ohos.file.fs';

const RPL_RAWFILE_NAME = 'rpl_seed.sqlite';
const RPL_LOCAL_DB_NAME = 'rpl_seed.sqlite';
const MIN_PREBUILT_DB_SIZE = 1024 * 1024;

export class RplPrebuiltDatabase {
  static async open(context: common.Context): Promise<relationalStore.RdbStore> {
    const localPath = context.filesDir + '/' + RPL_LOCAL_DB_NAME;
    await RplPrebuiltDatabase.ensureCopied(context, localPath);

    const config: relationalStore.StoreConfig = {
      name: RPL_LOCAL_DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1,
      rootDir: context.filesDir,
      isReadOnly: true
    };

    const store = await relationalStore.getRdbStore(context, config);
    console.info('[MediClearRPL] opened full prebuilt RPL database at ' + localPath);
    return store;
  }

  private static async ensureCopied(context: common.Context, localPath: string): Promise<void> {
    if (RplPrebuiltDatabase.hasValidLocalDatabase(localPath)) {
      console.info('[MediClearRPL] full RPL database already copied');
      return;
    }

    console.info('[MediClearRPL] copying full RPL database from rawfile');
    const content = await context.resourceManager.getRawFileContent(RPL_RAWFILE_NAME);
    const file = fs.openSync(localPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, content.buffer);
    } finally {
      fs.closeSync(file.fd);
    }
    console.info('[MediClearRPL] copied full RPL database bytes=' + content.byteLength.toString());
  }

  private static hasValidLocalDatabase(localPath: string): boolean {
    try {
      const stat = fs.statSync(localPath);
      return stat.size > MIN_PREBUILT_DB_SIZE;
    } catch (err) {
      return false;
    }
  }
}
