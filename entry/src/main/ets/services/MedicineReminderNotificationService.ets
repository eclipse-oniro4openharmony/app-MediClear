import { common } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import vibrator from '@ohos.vibrator';

export interface MedicineReminderAlertRequest {
  medicineName: string;
  dose: string;
  time: string;
}

const REMINDER_NOTIFICATION_ID = 410001;
const REMINDER_NOTIFICATION_LABEL = 'mediclear_medicine_reminder';
const REMINDER_VIBRATION_MS = 260;
const REMINDER_VIBRATION_INTERVAL_MS = 900;
const REMINDER_VIBRATION_TOTAL_MS = 60000;

export class MedicineReminderNotificationService {
  private static instance: MedicineReminderNotificationService | null = null;
  private context: common.UIAbilityContext | null = null;
  private activeVibrationTimeouts: number[] = [];

  static getInstance(): MedicineReminderNotificationService {
    if (MedicineReminderNotificationService.instance === null) {
      MedicineReminderNotificationService.instance = new MedicineReminderNotificationService();
    }
    return MedicineReminderNotificationService.instance;
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  async requestNotificationPermission(): Promise<void> {
    if (this.context === null) {
      return;
    }
    try {
      await notificationManager.requestEnableNotification(this.context);
    } catch (error) {
      console.warn('[MediClearReminderNotify] request notification permission failed: ' + JSON.stringify(error));
    }
  }

  async alertMedicineReminder(request: MedicineReminderAlertRequest): Promise<void> {
    this.stopIntermittentVibration();
    await this.publishSystemNotification(request);
    this.startIntermittentVibration();
  }

  stopActiveReminderAlert(): void {
    this.stopIntermittentVibration();
  }

  private async publishSystemNotification(request: MedicineReminderAlertRequest): Promise<void> {
    const medicineName = request.medicineName.trim().length > 0 ? request.medicineName.trim() : 'Medicine';
    const dose = request.dose.trim().length > 0 ? request.dose.trim() : 'Take your scheduled dose';
    const content: notificationManager.NotificationContent = {
      notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
      normal: {
        title: 'Time to take medicine',
        text: request.time + ' · ' + medicineName,
        additionalText: dose
      }
    };

    const notificationRequest: notificationManager.NotificationRequest = {
      id: REMINDER_NOTIFICATION_ID,
      label: REMINDER_NOTIFICATION_LABEL,
      content,
      notificationSlotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
      isAlertOnce: false,
      tapDismissed: true,
      isFloatingIcon: true
    };

    try {
      await notificationManager.publish(notificationRequest);
    } catch (error) {
      console.warn('[MediClearReminderNotify] publish failed: ' + JSON.stringify(error));
    }
  }

  private startIntermittentVibration(): void {
    const vibrationCount = Math.floor(REMINDER_VIBRATION_TOTAL_MS / REMINDER_VIBRATION_INTERVAL_MS);
    for (let index = 0; index < vibrationCount; index++) {
      const timeoutId = setTimeout(() => {
        this.vibrateOnce();
      }, index * REMINDER_VIBRATION_INTERVAL_MS);
      this.activeVibrationTimeouts.push(timeoutId);
    }
  }

  private stopIntermittentVibration(): void {
    for (let index = 0; index < this.activeVibrationTimeouts.length; index++) {
      clearTimeout(this.activeVibrationTimeouts[index]);
    }
    this.activeVibrationTimeouts = [];
  }

  private async vibrateOnce(): Promise<void> {
    try {
      await vibrator.vibrate(REMINDER_VIBRATION_MS);
    } catch (error) {
      console.warn('[MediClearReminderNotify] vibration failed: ' + JSON.stringify(error));
    }
  }
}
