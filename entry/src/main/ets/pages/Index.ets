import { common } from '@kit.AbilityKit';
import { MediClearDatabase } from '../database/MediClearDatabase';
import { RplMedicineDAO } from '../database/RplMedicineDAO';
import { RplMedicineRecord } from '../database/RplMedicineRecord';
import { CoreVisionOcrService } from '../services/CoreVisionOcrService';
import { PaddleOcrService } from '../services/PaddleOcrService';
import { MedicineGuideMediaHelper, PickedMedicineGuide } from '../services/MedicineGuideMediaHelper';

class ActionItem {
  title: string;
  subtitle: string;
  icon: Resource;
  tint: string;

  constructor(title: string, subtitle: string, icon: Resource, tint: string) {
    this.title = title;
    this.subtitle = subtitle;
    this.icon = icon;
    this.tint = tint;
  }
}

class MedicineRecord {
  name: string;
  subtitle: string;
  date: string;
  status: string;
  tint: string;

  constructor(name: string, subtitle: string, date: string, status: string, tint: string) {
    this.name = name;
    this.subtitle = subtitle;
    this.date = date;
    this.status = status;
    this.tint = tint;
  }
}

class ReminderItem {
  time: string;
  label: string;
  dose: string;
  icon: Resource;
  tint: string;
  background: string;

  constructor(time: string, label: string, dose: string, icon: Resource, tint: string, background: string) {
    this.time = time;
    this.label = label;
    this.dose = dose;
    this.icon = icon;
    this.tint = tint;
    this.background = background;
  }
}

class ParsedMedicineGuide {
  name: string = 'Espumisan';
  subtitle: string = 'Anti-flatulence medicine';
  activeIngredient: string = 'Simeticonum 40 mg';
  ingredientNote: string = 'Each capsule contains 40 mg simethicone';
  howToTake: string = '2 capsules each time\n3-4 times per day\nBefore, during, or after meals\nCan be taken before sleep if needed';
  contraindications: string = 'Allergic to simethicone\nAllergic to E110, E218, or any excipient';
  avoid: string = 'Consult a clinician if abdominal symptoms are new or persistent\nCheck excipients if you have allergy history';
  doctorIf: string = 'New or persistent abdominal discomfort\nSuspected allergic reaction';
  sideEffectOne: string = 'No known Espumisan-specific adverse reactions';
  sideEffectTwo: string = 'E110 may cause allergic reactions';
  sideEffectThree: string = 'E218 may cause delayed allergic reactions';
  reminderOneTime: string = '08:30';
  reminderOneLabel: string = 'With breakfast';
  reminderTwoTime: string = '19:30';
  reminderTwoLabel: string = 'With dinner';
  leafletUrl: string = 'https://rejestry.ezdrowie.gov.pl/api/rpl/medicinal-products/2268/leaflet';
  characteristicUrl: string = 'https://rejestry.ezdrowie.gov.pl/api/rpl/medicinal-products/2268/characteristic';
  rplIdentifier: string = '100022688';
  productId: string = '2268';
  matchedKeywords: string = 'espumisan, simeticonum, 40 mg';
  matchedPackage: string = 'GTIN: 05909990168712 | OTC | Package: 25 capsules';
  sourceNote: string = 'Source: local RPL SQLite match, Espumisan 40 mg capsules';
}

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State selectedGuide: number = 0;
  @State showUploadSheet: boolean = false;
  @State uploadState: string = 'No medicine guide scanned yet';
  @State uploadSource: string = 'Tap Upload Medicine Guide to scan a medicine leaflet.';
  @State selectedGuideUri: string = '';
  @State extractedOcrText: string = '';
  @State medicineName: string = 'Ibuprofen 200 mg';
  @State medicineSubtitle: string = 'Pain reliever / Fever reducer';
  @State activeIngredient: string = 'Ibuprofen 200 mg';
  @State ingredientNote: string = 'Nonsteroidal anti-inflammatory drug (NSAID)';
  @State howToTake: string = '1 tablet each time\nEvery 6-8 hours\nTake after meals\nMax 3 tablets in 24 hours';
  @State contraindications: string = 'Allergic to ibuprofen\nUnder 12 years old';
  @State avoidWarnings: string = 'Avoid alcohol\nDo not combine with similar medicine';
  @State doctorWarnings: string = 'Symptoms last more than 3 days\nSevere allergic reaction';
  @State sideEffectOne: string = 'Nausea';
  @State sideEffectTwo: string = 'Dizziness';
  @State sideEffectThree: string = 'Stomach discomfort';
  @State reminderOneTime: string = '08:30';
  @State reminderOneLabel: string = 'After breakfast';
  @State reminderTwoTime: string = '19:30';
  @State reminderTwoLabel: string = 'After dinner';
  @State sourceNote: string = 'Source: demo medicine guide';
  @State leafletUrl: string = '';
  @State characteristicUrl: string = '';
  @State rplIdentifier: string = '';
  @State productId: string = '';
  @State matchedKeywords: string = '';
  @State matchedPackage: string = '';

  private actions: ActionItem[] = [
    new ActionItem('Upload Medicine Guide', 'Take photo or upload file', $r('app.media.bi_cloud_upload'), '#009F9A'),
    new ActionItem('My Reminders', 'View and manage schedule', $r('app.media.bi_bell'), '#1767C5'),
    new ActionItem('Medicine History', 'Past medicines and guides', $r('app.media.bi_clock_history'), '#6554D9')
  ];

  private medicines: MedicineRecord[] = [
    new MedicineRecord('Ibuprofen 200 mg', 'Pain reliever / Fever reducer', 'May 20, 2024', 'Active', '#009F9A'),
    new MedicineRecord('Vitamin C 500 mg', 'Immune support', 'May 10, 2024', 'Completed', '#E97921'),
    new MedicineRecord('Cetirizine 10 mg', 'Allergy relief', 'Apr 28, 2024', 'Completed', '#1A9D9A'),
    new MedicineRecord('Cold Relief Syrup', 'Cough & cold relief', 'Apr 15, 2024', 'Expired', '#9A6429')
  ];

  private reminders: ReminderItem[] = [
    new ReminderItem('08:30', 'After breakfast', '1 tablet', $r('app.media.bi_sun'), '#009F9A', '#E7FAF6'),
    new ReminderItem('19:30', 'After dinner', '1 tablet', $r('app.media.bi_moon_stars'), '#5648D9', '#F0EEFF')
  ];

  build() {
    Stack() {
      Column() {
        if (this.currentTab === 0) {
          this.Header()
        }

        Scroll() {
          Column({ space: 18 }) {
            if (this.currentTab === 0) {
              this.HomeView()
            } else if (this.currentTab === 1) {
              this.HistoryView()
            } else if (this.currentTab === 2) {
              this.ReminderView()
            } else {
              this.ProfileView()
            }
          }
          .padding({ left: 20, right: 20, top: this.currentTab === 0 ? 8 : 18, bottom: 92 })
          .width('100%')
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)

        this.TabBar()
      }
      .width('100%')
      .height('100%')

      if (this.showUploadSheet) {
        this.UploadChoiceSheet()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6FBFC')
  }

  @Builder
  Header() {
    Row() {
      Row({ space: 10 }) {
        this.LogoMark(34)
        Text('MediClear')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0076B7')
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)

      Stack() {
        Image($r('app.media.bi_bell'))
          .width(24)
          .height(24)
          .fillColor('#294159')
      }
      .width(44)
      .height(44)
      .borderRadius(22)
    }
    .width('100%')
    .height(64)
    .padding({ left: 20, right: 20, top: 10, bottom: 8 })
    .backgroundColor('#F6FBFC')
  }

  @Builder
  HomeView() {
    Column({ space: 18 }) {
      Column({ space: 6 }) {
        Text('Welcome back!')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .width('100%')
        Text('Your smart companion for\nsafer medicine use.')
          .fontSize(15)
          .fontColor('#445267')
          .lineHeight(21)
          .width('100%')
      }
      .width('100%')

      Column({ space: 12 }) {
        ForEach(this.actions, (item: ActionItem, index: number) => {
          this.ActionRow(item, index)
        }, (item: ActionItem) => item.title)
      }
      .padding(16)
      .borderRadius(24)
      .backgroundColor(Color.White)
      .shadow({ radius: 18, color: '#11006472', offsetY: 8 })

      this.UploadAnalysisPanel()
      this.SectionTitle('Recent Medicine', 'See all')
      this.MedicineMiniCard(new MedicineRecord(this.medicineName, this.medicineSubtitle, 'Today', 'Active', '#009F9A'))
      this.PrivacyCard()
      this.GuideTabs()
    }
    .width('100%')
  }

  @Builder
  UploadAnalysisPanel() {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        this.IconBubble($r('app.media.bi_clipboard_check'), '#E8F8F6', '#008A88')
        Column({ space: 4 }) {
          Text('Medicine guide analysis')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
          Text(this.uploadState)
            .fontSize(13)
            .fontColor('#536175')
        }
        .layoutWeight(1)
      }
      Text(this.uploadSource)
        .fontSize(12)
        .fontColor('#005F68')
        .lineHeight(18)
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor('#E8F8F6')
        .borderRadius(10)
      if (this.extractedOcrText.length > 0) {
        Column({ space: 6 }) {
          Text('Extracted text')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
            .width('100%')
          Text(this.extractedOcrText)
            .fontSize(12)
            .fontColor('#334155')
            .lineHeight(18)
            .width('100%')
        }
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor('#F8FCFC')
        .border({ width: 1, color: '#DCEBED' })
        .borderRadius(10)
        .width('100%')
      }
      if (this.leafletUrl.length > 0) {
        this.RplEndpointCard()
      }
      Row({ space: 10 }) {
        Button('Take Photo')
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor('#009F9A')
          .borderRadius(8)
          .height(42)
          .layoutWeight(1)
          .onClick(() => {
            this.takeMedicineGuidePhoto();
          })
        Button('Upload File')
          .fontSize(14)
          .fontColor('#007D83')
          .backgroundColor('#FFFFFF')
          .border({ width: 1, color: '#B7DFDC' })
          .borderRadius(8)
          .height(42)
          .layoutWeight(1)
          .onClick(() => {
            this.selectMedicineGuideFile();
          })
      }
    }
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({ radius: 10, color: '#10006472', offsetY: 4 })
    .width('100%')
  }

  @Builder
  UploadChoiceSheet() {
    Column() {
      Blank()
        .layoutWeight(1)
      Column({ space: 14 }) {
        Row() {
          Text('Upload medicine guide')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
            .layoutWeight(1)
          Button('Close')
            .fontSize(13)
            .fontColor('#536175')
            .backgroundColor('#F1F5F9')
            .borderRadius(8)
            .height(36)
            .onClick(() => {
              this.showUploadSheet = false;
            })
        }
        .width('100%')

        Text('Choose a photo source. MediClear will match the detected medicine against the local RPL database and show the official PDF endpoints.')
          .fontSize(13)
          .fontColor('#536175')
          .lineHeight(19)
          .width('100%')

        Row({ space: 12 }) {
          this.UploadChoiceButton('Take Photo', 'Camera scan', $r('app.media.bi_upc_scan'), '#009F9A', 'camera')
          this.UploadChoiceButton('Choose Photo', 'From gallery', $r('app.media.bi_cloud_upload'), '#1767C5', 'gallery')
        }
        .width('100%')
        Button('Upload PDF or document')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#007D83')
          .height(48)
          .width('100%')
          .backgroundColor('#F0FAF9')
          .border({ width: 1, color: '#B7DFDC' })
          .borderRadius(10)
          .onClick(() => {
            this.selectMedicineGuideFile();
          })
      }
      .padding(18)
      .backgroundColor(Color.White)
      .borderRadius({ topLeft: 20, topRight: 20 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
  }

  @Builder
  UploadChoiceButton(title: string, subtitle: string, icon: Resource, tint: string, sourceType: string) {
    Column({ space: 8 }) {
      this.IconBubble(icon, '#E8F8F6', tint)
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
      Text(subtitle)
        .fontSize(12)
        .fontColor('#536175')
    }
    .layoutWeight(1)
    .height(128)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F8FCFC')
    .border({ width: 1, color: '#DCEBED' })
    .borderRadius(12)
    .onClick(() => {
      if (sourceType === 'camera') {
        this.takeMedicineGuidePhoto();
      } else if (sourceType === 'gallery') {
        this.selectMedicineGuidePhoto();
      } else {
        this.selectMedicineGuideFile();
      }
    })
  }

  @Builder
  RplEndpointCard() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Image($r('app.media.bi_database_lock'))
          .width(18)
          .height(18)
          .fillColor('#007D83')
        Text('Local RPL database match')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
      }
      .width('100%')

      Text('RPL identifier: ' + this.rplIdentifier)
        .fontSize(12)
        .fontColor('#334155')
        .width('100%')
      Text('Product ID: ' + this.productId)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .width('100%')
      Text('Matched keywords: ' + this.matchedKeywords)
        .fontSize(12)
        .fontColor('#334155')
        .lineHeight(17)
        .width('100%')
      Text(this.matchedPackage)
        .fontSize(12)
        .fontColor('#334155')
        .lineHeight(17)
        .width('100%')
      Text('Leaflet PDF endpoint')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#007D83')
        .width('100%')
      Text(this.leafletUrl)
        .fontSize(11)
        .fontColor('#42566F')
        .lineHeight(16)
        .width('100%')
      Text('Characteristic PDF endpoint')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#007D83')
        .width('100%')
      Text(this.characteristicUrl)
        .fontSize(11)
        .fontColor('#42566F')
        .lineHeight(16)
        .width('100%')
    }
    .padding(12)
    .backgroundColor('#F0FAF9')
    .border({ width: 1, color: '#B7DFDC' })
    .borderRadius(10)
    .width('100%')
  }

  @Builder
  GuideTabs() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        this.SegmentButton('Summary', 0)
        this.SegmentButton('Safety', 1)
      }
      .width('100%')

      if (this.selectedGuide === 0) {
        this.SummaryCard()
      } else {
        this.SafetyChecklist()
      }
    }
    .width('100%')
  }

  @Builder
  SegmentButton(label: string, index: number) {
    Button(label)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.selectedGuide === index ? Color.White : '#006D78')
      .backgroundColor(this.selectedGuide === index ? '#009F9A' : '#E5F7F5')
      .borderRadius(10)
      .height(42)
      .layoutWeight(1)
      .onClick(() => {
        this.selectedGuide = index;
      })
  }

  @Builder
  SummaryCard() {
    Column({ space: 14 }) {
      Row({ space: 14 }) {
        this.PillBottle('#00A195')
        Column({ space: 6 }) {
          Text(this.medicineName)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
          Text(this.medicineSubtitle)
            .fontSize(13)
            .fontColor('#4B5563')
          Text('OTC')
            .fontSize(12)
            .fontColor('#057A68')
            .padding({ left: 12, right: 12, top: 5, bottom: 5 })
            .backgroundColor('#DDF8EA')
            .borderRadius(14)
            .alignSelf(ItemAlign.Start)
        }
        .layoutWeight(1)
      }
      .padding(16)
      .backgroundColor(Color.White)
      .borderRadius(14)

      this.InfoCard('Active Ingredient', this.activeIngredient + '\n' + this.ingredientNote, $r('app.media.bi_flask'), '#E0F6F1')
      this.InfoCard('How to Take', this.howToTake, $r('app.media.bi_list_check'), '#EAF2FF')
      this.InfoCard('Set Reminder', this.reminderOneTime + ' ' + this.reminderOneLabel + '\n' + this.reminderTwoTime + ' ' + this.reminderTwoLabel, $r('app.media.bi_bell'), '#E5F7F1')
      this.SourceTraceCard()

      Button('Set Reminders')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor('#009F9A')
        .borderRadius(10)
        .height(54)
        .width('100%')
        .onClick(() => {
          this.currentTab = 2;
        })
    }
    .width('100%')
  }

  @Builder
  SafetyChecklist() {
    Column({ space: 14 }) {
      this.WarningCard('Do not use if', this.contraindications, '#EF4444', '#FFF4F4', $r('app.media.bi_exclamation_triangle'))
      this.WarningCard('Avoid', this.avoidWarnings, '#F59E0B', '#FFF9EA', $r('app.media.bi_exclamation_triangle'))
      this.WarningCard('Contact a doctor if', this.doctorWarnings, '#1767C5', '#F0F7FF', $r('app.media.bi_info_circle'))

      Column({ space: 10 }) {
        Text('Common Side Effects')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .width('100%')
        Flex({ wrap: FlexWrap.Wrap, direction: FlexDirection.Row }) {
          this.Chip(this.sideEffectOne)
          this.Chip(this.sideEffectTwo)
          this.Chip(this.sideEffectThree)
          this.Chip('Heartburn')
          this.Chip('Headache')
          this.Chip('Fatigue')
        }
        this.NoteCard()
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  ReminderView() {
    Column({ space: 16 }) {
      this.PageTop('Medication Reminder')
      Text('Today\'s Schedule')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .width('100%')

      this.ReminderCard(new ReminderItem(this.reminderOneTime, this.reminderOneLabel, '1 tablet', $r('app.media.bi_sun'), '#009F9A', '#E7FAF6'))
      this.ReminderCard(new ReminderItem(this.reminderTwoTime, this.reminderTwoLabel, '1 tablet', $r('app.media.bi_moon_stars'), '#5648D9', '#F0EEFF'))

      Button('Edit Schedule')
        .fontSize(15)
        .fontColor('#007D83')
        .backgroundColor('#F6FBFC')
        .border({ width: 1, color: '#009F9A' })
        .borderRadius(10)
        .height(48)
        .width('100%')

      this.AdherenceCard()
    }
    .width('100%')
  }

  @Builder
  HistoryView() {
    Column({ space: 16 }) {
      this.PageTop('Medicine History')
      Row({ space: 8 }) {
        Text('Search medicines')
          .fontSize(14)
          .fontColor('#7A8797')
          .layoutWeight(1)
          .padding({ left: 14, right: 14 })
          .height(44)
          .backgroundColor(Color.White)
          .borderRadius(10)
          .border({ width: 1, color: '#E4EAF0' })

        Row({ space: 6 }) {
          Text('All')
            .fontSize(14)
            .fontColor('#008A88')
          Image($r('app.media.bi_chevron_down'))
            .width(13)
            .height(13)
            .fillColor('#008A88')
        }
        .padding({ left: 14, right: 14 })
        .height(44)
        .backgroundColor('#E8F8F6')
        .borderRadius(10)
      }
      .width('100%')

      Row() {
        this.IconBubble($r('app.media.bi_clipboard_check'), '#EAF2FF', '#1767C5')
        Column({ space: 3 }) {
          Text('12 medicines saved')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
          Text('Your personal medicine record')
            .fontSize(12)
            .fontColor('#64748B')
        }
        .layoutWeight(1)
        this.ChevronRight('#36506B')
      }
      .padding(14)
      .backgroundColor(Color.White)
      .borderRadius(12)
      .shadow({ radius: 10, color: '#14006472', offsetY: 4 })

      Text('Recent Entries')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .width('100%')

      Column({ space: 0 }) {
        ForEach(this.medicines, (item: MedicineRecord) => {
          this.HistoryRow(item)
        }, (item: MedicineRecord) => item.name)
      }
      .backgroundColor(Color.White)
      .borderRadius(12)
      .clip(true)

      Button('View All History')
        .fontSize(15)
        .fontColor('#263B55')
        .backgroundColor('#FFFFFF')
        .border({ width: 1, color: '#9BA8B6' })
        .borderRadius(10)
        .height(48)
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  ProfileView() {
    Column({ space: 16 }) {
      this.PageTop('Profile')
      Row({ space: 16 }) {
        this.ProfileAvatarIcon()

        Column({ space: 5 }) {
          Text('Chen Song')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
          Text('Private & local\nmedicine assistant')
            .fontSize(14)
            .fontColor('#445267')
        }
        .layoutWeight(1)
      }
      .padding(16)
      .backgroundColor('#DDF7F5')
      .borderRadius(12)

      Text('Settings')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .width('100%')

      Column({ space: 0 }) {
        this.SettingRow('Language', 'English', $r('app.media.bi_globe'), '#EAF2FF', '#1767C5')
        this.SettingRow('Reminder Notifications', 'On', $r('app.media.bi_bell'), '#EEF5FF', '#1767C5')
        this.SettingRow('Data & Privacy', '', $r('app.media.bi_shield_heart'), '#E8F8F6', '#008A88')
        this.SettingRow('Export History', '', $r('app.media.bi_box_arrow_up'), '#F1EDFF', '#6554D9')
      }
      .backgroundColor(Color.White)
      .borderRadius(12)
      .clip(true)

      Row() {
        this.DarkModeIcon()
        Text('Dark Mode')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#263244')
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: true })
          .selectedColor('#009F9A')
      }
      .padding(14)
      .backgroundColor(Color.White)
      .borderRadius(12)

      this.SettingPanel('Help & Support', $r('app.media.bi_question_circle'), '#EAF2FF', '#1767C5')
      this.SettingPanel('About MediClear', $r('app.media.bi_info_circle'), '#E8F8F6', '#008A88')
      this.NoteCard()
    }
    .width('100%')
  }

  @Builder
  PageTop(title: string) {
    Row() {
      Image($r('app.media.bi_chevron_left'))
        .width(22)
        .height(22)
        .fillColor('#20324A')
        .width(36)
      Text(title)
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
      this.LogoMark(30)
    }
    .width('100%')
    .height(42)
  }

  @Builder
  ActionRow(item: ActionItem, index: number) {
    Row({ space: 14 }) {
      this.IconBubble(item.icon, index === 0 ? '#33C6BD' : '#ECFAF8', index === 0 ? Color.White : item.tint)
      Column({ space: 4 }) {
        Text(item.title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(index === 0 ? Color.White : '#1F2A44')
        Text(item.subtitle)
          .fontSize(12)
          .fontColor(index === 0 ? '#E9FFFC' : '#45556C')
      }
      .layoutWeight(1)
      this.ChevronRight(index === 0 ? Color.White : item.tint)
    }
    .height(66)
    .padding({ left: 14, right: 14 })
    .borderRadius(10)
    .backgroundColor(index === 0 ? '#009F9A' : (item.title === 'My Reminders' ? '#EEF5FF' : '#F0EDFF'))
    .onClick(() => {
      if (item.title === 'Upload Medicine Guide') {
        this.showUploadSheet = true;
      } else if (item.title === 'My Reminders') {
        this.currentTab = 2;
      } else if (item.title === 'Medicine History') {
        this.currentTab = 1;
      }
    })
  }

  @Builder
  MedicineMiniCard(record: MedicineRecord) {
    Row({ space: 14 }) {
      this.PillBottle(record.tint)
      Column({ space: 4 }) {
        Text(record.name)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
        Text(record.subtitle)
          .fontSize(12)
          .fontColor('#5B6778')
        Text('Updated ' + record.date)
          .fontSize(11)
          .fontColor('#5B6778')
      }
      .layoutWeight(1)
      this.ChevronRight('#4D6682')
    }
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({ radius: 10, color: '#12006472', offsetY: 4 })
    .width('100%')
  }

  @Builder
  HistoryRow(record: MedicineRecord) {
    Row({ space: 12 }) {
      this.PillBottle(record.tint)
      Column({ space: 3 }) {
        Text(record.name)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
        Text(record.subtitle)
          .fontSize(12)
          .fontColor('#5B6778')
        Text(record.date)
          .fontSize(11)
          .fontColor('#5B6778')
      }
      .layoutWeight(1)
      Text(record.status)
        .fontSize(11)
        .fontColor(record.status === 'Active' ? '#007A68' : (record.status === 'Expired' ? '#7B7F86' : '#1261BA'))
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor(record.status === 'Active' ? '#DDF8EA' : (record.status === 'Expired' ? '#EEF0F2' : '#E6F0FF'))
        .borderRadius(8)
      this.ChevronRight('#4D6682')
    }
    .padding(14)
    .border({ width: { bottom: 1 }, color: '#EEF2F6' })
  }

  @Builder
  InfoCard(title: string, body: string, icon: Resource, background: string) {
    Row({ space: 14 }) {
      this.IconBubble(icon, background, '#007D83')
      Column({ space: 7 }) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
        Text(body)
          .fontSize(13)
          .fontColor('#334155')
          .lineHeight(20)
      }
      .layoutWeight(1)
      this.ChevronRight('#8A98A8')
    }
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({ radius: 8, color: '#10006472', offsetY: 3 })
  }

  @Builder
  WarningCard(title: string, body: string, tint: string, background: string, icon: Resource) {
    Row({ space: 12 }) {
      Stack() {
        Image(icon)
          .width(22)
          .height(22)
          .fillColor(tint)
      }
        .width(34)
        .height(34)
        .border({ width: 2, color: tint })
        .borderRadius(17)
      Column({ space: 8 }) {
        Text(title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(tint)
        Text(body)
          .fontSize(13)
          .fontColor('#111827')
          .lineHeight(20)
      }
      .layoutWeight(1)
    }
    .padding(16)
    .backgroundColor(background)
    .border({ width: 1, color: tint })
    .borderRadius(12)
  }

  @Builder
  ReminderCard(item: ReminderItem) {
    Column({ space: 14 }) {
      Row({ space: 14 }) {
        this.IconBubble(item.icon, item.background, item.tint)
        Column({ space: 4 }) {
          Text(item.time)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
          Text(item.label)
            .fontSize(14)
            .fontColor('#344155')
          Text(item.dose)
            .fontSize(13)
            .fontColor('#344155')
        }
        .layoutWeight(1)
        Text(item.dose)
          .fontSize(12)
          .fontColor('#344155')
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor('#EDF8F7')
          .borderRadius(16)
      }
      Row({ space: 12 }) {
        Button('Mark as Taken')
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor('#009F9A')
          .borderRadius(8)
          .height(44)
          .layoutWeight(1)
        Button('Skip')
          .fontSize(14)
          .fontColor('#111827')
          .backgroundColor('#FFFFFF')
          .border({ width: 1, color: '#D6DEE8' })
          .borderRadius(8)
          .height(44)
          .layoutWeight(1)
      }
    }
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({ radius: 10, color: '#12006472', offsetY: 4 })
  }

  @Builder
  AdherenceCard() {
    Column({ space: 14 }) {
      Row() {
        Text('Adherence - Last 7 Days')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .layoutWeight(1)
        Text('100%')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#009F7A')
      }
      Text('Great job! Keep it up.')
        .fontSize(12)
        .fontColor('#536175')
        .width('100%')
      Row() {
        ForEach(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'], (day: string) => {
          Column({ space: 6 }) {
            Text(day)
              .fontSize(11)
              .fontColor('#536175')
            Image($r('app.media.bi_check_circle_fill'))
              .width(22)
              .height(22)
              .fillColor('#0EA77B')
              .width(22)
              .height(22)
          }
          .layoutWeight(1)
        }, (day: string) => day)
      }
      .width('100%')
      Text('7 / 7 taken on time')
        .fontSize(13)
        .fontColor('#344155')
    }
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({ radius: 10, color: '#12006472', offsetY: 4 })
  }

  @Builder
  PrivacyCard() {
    Row({ space: 12 }) {
      this.IconBubble($r('app.media.bi_lock'), '#CFF6F2', '#008A88')
      Column({ space: 4 }) {
        Text('Local & private')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#007478')
        Text('Your data stays on your device.')
          .fontSize(12)
          .fontColor('#006D78')
      }
      .layoutWeight(1)
      this.LogoMark(28)
    }
    .padding(14)
    .backgroundColor('#E5FAF8')
    .borderRadius(12)
  }

  @Builder
  SectionTitle(title: string, action: string) {
    Row() {
      Text(title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .layoutWeight(1)
      Text(action)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor('#008A88')
    }
    .width('100%')
  }

  @Builder
  Chip(label: string) {
    Text(label)
      .fontSize(12)
      .fontColor('#1663B7')
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .backgroundColor('#E8F1FF')
      .border({ width: 1, color: '#C7DFFF' })
      .borderRadius(16)
      .margin({ right: 8, bottom: 8 })
  }

  @Builder
  NoteCard() {
    Row({ space: 12 }) {
      this.LogoMark(32)
      Text('MediClear does not diagnose or prescribe. Always consult your doctor or pharmacist.')
        .fontSize(13)
        .fontColor('#005F68')
        .lineHeight(18)
        .layoutWeight(1)
    }
    .padding(14)
    .backgroundColor('#E4F8F6')
    .borderRadius(10)
  }

  @Builder
  SourceTraceCard() {
    Row({ space: 12 }) {
      Image($r('app.media.bi_info_circle'))
        .width(20)
        .height(20)
        .fillColor('#1767C5')
      Text(this.sourceNote)
        .fontSize(12)
        .fontColor('#334155')
        .lineHeight(17)
        .layoutWeight(1)
    }
    .padding(12)
    .backgroundColor('#F0F7FF')
    .borderRadius(10)
  }

  @Builder
  SettingRow(label: string, value: string, icon: Resource, background: string, tint: ResourceColor) {
    Row() {
      this.SettingIcon(icon, background, tint)
      Text(label)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#263244')
        .layoutWeight(1)
      if (value.length > 0) {
        Text(value)
          .fontSize(14)
          .fontColor('#617184')
      }
      this.ChevronRight('#42566F')
    }
    .padding(14)
    .border({ width: { bottom: 1 }, color: '#EEF2F6' })
  }

  @Builder
  SettingPanel(label: string, icon: Resource, background: string, tint: ResourceColor) {
    Row() {
      this.SettingIcon(icon, background, tint)
      Text(label)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#263244')
        .layoutWeight(1)
      this.ChevronRight('#42566F')
    }
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  @Builder
  SettingIcon(icon: Resource, background: string, tint: ResourceColor) {
    Stack() {
      Image(icon)
        .width(20)
        .height(20)
        .fillColor(tint)
    }
    .width(38)
    .height(38)
    .backgroundColor(background)
    .borderRadius(12)
    .margin({ right: 12 })
  }

  @Builder
  DarkModeIcon() {
    Stack() {
      Text('')
        .width(20)
        .height(20)
        .backgroundColor('#6554D9')
        .borderRadius(10)
      Text('')
        .width(16)
        .height(16)
        .backgroundColor('#F1EDFF')
        .borderRadius(8)
        .offset({ x: 6, y: -4 })
    }
    .width(38)
    .height(38)
    .backgroundColor('#F1EDFF')
    .borderRadius(12)
    .margin({ right: 12 })
  }

  @Builder
  ProfileAvatarIcon() {
    Stack() {
      Text('')
        .width(24)
        .height(24)
        .backgroundColor('#007D83')
        .borderRadius(12)
        .offset({ y: -12 })
      Text('')
        .width(42)
        .height(24)
        .backgroundColor('#007D83')
        .borderRadius(12)
        .offset({ y: 18 })
      Text('')
        .width(72)
        .height(72)
        .border({ width: 2, color: '#78D5D1' })
        .borderRadius(36)
    }
    .width(72)
    .height(72)
    .backgroundColor('#BFEFED')
    .borderRadius(36)
  }

  @Builder
  TabBar() {
    Row() {
      this.TabButton('Home', 0, $r('app.media.bi_house_door'))
      this.TabButton('History', 1, $r('app.media.bi_clock_history'))
      this.TabButton('Reminders', 2, $r('app.media.bi_bell'))
      this.TabButton('Profile', 3, $r('app.media.bi_person_heart'))
    }
    .height(72)
    .width('100%')
    .padding({ left: 12, right: 12, bottom: 8 })
    .backgroundColor(Color.White)
    .border({ width: { top: 1 }, color: '#E8EDF3' })
  }

  @Builder
  TabButton(label: string, index: number, icon: Resource) {
    Column({ space: 4 }) {
      Image(icon)
        .width(22)
        .height(22)
        .fillColor(this.currentTab === index ? '#00918F' : '#294159')
      Text(label)
        .fontSize(11)
        .fontColor(this.currentTab === index ? '#00918F' : '#294159')
        .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Regular)
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentTab = index;
    })
  }

  @Builder
  LogoMark(size: number) {
    Stack() {
      Image($r('app.media.bi_shield_heart'))
        .width(size * 0.68)
        .height(size * 0.68)
        .fillColor('#009F9A')
    }
    .width(size)
    .height(size)
  }

  @Builder
  IconBubble(icon: Resource, background: string, tint: ResourceColor) {
    Stack() {
      Image(icon)
        .width(25)
        .height(25)
        .fillColor(tint)
    }
      .width(50)
      .height(50)
      .backgroundColor(background)
      .borderRadius(14)
  }

  @Builder
  PillBottle(tint: string) {
    Stack() {
      Image($r('app.media.bi_capsule_pill'))
        .width(34)
        .height(34)
        .fillColor(tint)
    }
    .width(58)
    .height(58)
    .backgroundColor('#F3F7F8')
    .borderRadius(10)
  }

  @Builder
  ChevronRight(tint: ResourceColor) {
    Image($r('app.media.bi_chevron_right'))
      .width(18)
      .height(18)
      .fillColor(tint)
  }

  private async takeMedicineGuidePhoto(): Promise<void> {
    this.showUploadSheet = false;
    this.uploadState = 'Opening camera...';
    this.uploadSource = 'Camera is opening. Take a clear photo of the medicine box, label, or leaflet.';

    try {
      const helper = new MedicineGuideMediaHelper(getContext(this));
      const picked = await helper.takePhoto(getContext(this) as common.UIAbilityContext);
      this.handleMedicineGuidePicked('camera', picked);
    } catch (err) {
      this.uploadState = 'Camera cancelled';
      this.uploadSource = 'No photo was captured. Tap Take Photo to try again.\nError: ' + JSON.stringify(err);
    }
  }

  private async selectMedicineGuideFile(): Promise<void> {
    this.showUploadSheet = false;
    this.uploadState = 'Opening file picker...';
    this.uploadSource = 'Choose a medicine package image, label photo, leaflet image, or PDF.';

    try {
      const helper = new MedicineGuideMediaHelper(getContext(this));
      const picked = await helper.selectFile();
      this.handleMedicineGuidePicked('file', picked);
    } catch (err) {
      this.uploadState = 'File upload cancelled';
      this.uploadSource = 'No file was selected or the file could not be copied.\nError: ' + JSON.stringify(err);
    }
  }

  private async selectMedicineGuidePhoto(): Promise<void> {
    this.showUploadSheet = false;
    this.uploadState = 'Opening photo library...';
    this.uploadSource = 'Choose a medicine package or leaflet photo from your gallery.';

    try {
      const helper = new MedicineGuideMediaHelper(getContext(this));
      const picked = await helper.selectPicture();
      this.handleMedicineGuidePicked('gallery', picked);
    } catch (err) {
      this.uploadState = 'Photo upload cancelled';
      this.uploadSource = 'No photo was selected or the photo could not be copied.\nError: ' + JSON.stringify(err);
    }
  }

  private handleMedicineGuidePicked(sourceType: string, picked: PickedMedicineGuide): void {
    if (picked.sandboxPath.length === 0) {
      this.uploadState = 'No medicine guide selected';
      this.uploadSource = 'MediClear did not receive a photo or file URI from the system picker.';
      console.error('[MediClearOCR] no sandbox path returned from picker');
      return;
    }
    this.uploadState = 'File ready for OCR';
    this.uploadSource = 'Original URI: ' + picked.originalUri + '\nSandbox path: ' + picked.sandboxPath;
    console.info('[MediClearOCR] picked originalUri=' + picked.originalUri);
    console.info('[MediClearOCR] picked sandboxPath=' + picked.sandboxPath);
    this.selectedGuideUri = picked.sandboxPath;
    this.extractedOcrText = '';
    this.productId = '';
    this.rplIdentifier = '';
    this.matchedKeywords = '';
    this.matchedPackage = '';
    this.leafletUrl = '';
    this.characteristicUrl = '';
    this.startMedicineGuideUpload(sourceType);
  }

  private async startMedicineGuideUpload(sourceType: string): Promise<void> {
    this.showUploadSheet = false;
    this.uploadState = 'Extracting medicine guide text...';
    const guideUri = this.selectedGuideUri;
    if (sourceType === 'camera') {
      this.uploadSource = 'Photo captured. MediClear is extracting text from the medicine image.\nURI: ' + guideUri;
    } else if (sourceType === 'gallery') {
      this.uploadSource = 'Photo selected. MediClear is extracting text from the medicine image.\nURI: ' + guideUri;
    } else {
      this.uploadSource = 'File uploaded. PaddleOCR is extracting text from the medicine guide.\nURI: ' + guideUri;
    }
    try {
      console.info('[MediClearOCR] start OCR sourceType=' + sourceType + ' path=' + guideUri);
      this.uploadState = 'OCR 1/4 Reading selected file...';
      const ocrText = await this.extractTextWithPaddleOcr(guideUri, sourceType);
      console.info('[MediClearOCR] OCR text length=' + ocrText.length.toString());
      this.extractedOcrText = ocrText;
      this.uploadState = 'OCR complete - matching local RPL database...';

      const database = await MediClearDatabase.getInstance(getContext(this));
      const dao = new RplMedicineDAO(database.getStore());
      const matches = await dao.searchByOcrText(ocrText);
      if (matches.length === 0) {
        this.uploadState = 'No local RPL match found';
        this.uploadSource = 'OCR text:\n' + ocrText + '\n\nSearch terms:\n' + dao.getDebugSearchTerms(ocrText) +
          '\n\nNo matching local RPL record was found.';
        return;
      }

      const parsed: ParsedMedicineGuide = this.parseMedicineGuide(ocrText);
      this.applyRplMatchToParsedGuide(parsed, matches[0]);
      this.applyParsedMedicineGuide(parsed);
      this.uploadState = 'Analysis complete - official RPL endpoints found';
      this.selectedGuide = 0;
    } catch (err) {
      console.error('[MediClearOCR] OCR failed: ' + JSON.stringify(err));
      this.uploadState = 'Text extraction unavailable';
      this.uploadSource = 'MediClear could not extract text from this file.\nError: ' + JSON.stringify(err);
    }
  }

  private async extractTextWithPaddleOcr(uri: string, sourceType: string): Promise<string> {
    if (uri.length === 0) {
      return '';
    }

    const lowerUri = uri.toLowerCase();
    const isImageSource = (sourceType === 'camera' || sourceType === 'gallery') && !lowerUri.endsWith('.pdf');
    if (isImageSource) {
      try {
        this.uploadState = 'OCR 2/4 Recognizing text locally with Core Vision...';
        const coreVisionService = new CoreVisionOcrService();
        const localText = await coreVisionService.extractTextFromImage(uri);
        if (localText.trim().length > 0) {
          console.info('[MediClearCoreVisionOCR] local OCR succeeded');
          return localText;
        }
        console.warn('[MediClearCoreVisionOCR] empty local OCR result, falling back to PaddleOCR');
      } catch (err) {
        console.error('[MediClearCoreVisionOCR] local OCR failed, falling back to PaddleOCR: ' + JSON.stringify(err));
      }
    }

    const service = new PaddleOcrService();
    this.uploadState = 'OCR 2/4 Uploading file to PaddleOCR...';
    return service.extractTextFromFile(uri);
  }

  private applyParsedMedicineGuide(parsed: ParsedMedicineGuide): void {
    this.medicineName = parsed.name;
    this.medicineSubtitle = parsed.subtitle;
    this.activeIngredient = parsed.activeIngredient;
    this.ingredientNote = parsed.ingredientNote;
    this.howToTake = parsed.howToTake;
    this.contraindications = parsed.contraindications;
    this.avoidWarnings = parsed.avoid;
    this.doctorWarnings = parsed.doctorIf;
    this.sideEffectOne = parsed.sideEffectOne;
    this.sideEffectTwo = parsed.sideEffectTwo;
    this.sideEffectThree = parsed.sideEffectThree;
    this.reminderOneTime = parsed.reminderOneTime;
    this.reminderOneLabel = parsed.reminderOneLabel;
    this.reminderTwoTime = parsed.reminderTwoTime;
    this.reminderTwoLabel = parsed.reminderTwoLabel;
    this.sourceNote = parsed.sourceNote;
    this.leafletUrl = parsed.leafletUrl;
    this.characteristicUrl = parsed.characteristicUrl;
    this.rplIdentifier = parsed.rplIdentifier;
    this.productId = parsed.productId;
    this.matchedKeywords = parsed.matchedKeywords;
    this.matchedPackage = parsed.matchedPackage;
  }

  private parseMedicineGuide(text: string): ParsedMedicineGuide {
    const lower: string = text.toLowerCase();
    const parsed: ParsedMedicineGuide = new ParsedMedicineGuide();

    if (lower.indexOf('espumisan') >= 0) {
      parsed.name = 'Espumisan';
      parsed.subtitle = 'Anti-flatulence medicine';
    }

    if (lower.indexOf('simeticonum') >= 0 || lower.indexOf('simethicone') >= 0) {
      parsed.activeIngredient = 'Simeticonum 40 mg';
      parsed.ingredientNote = 'Each capsule contains 40 mg simethicone';
    }

    if (lower.indexOf('3-4') >= 0 || lower.indexOf('three to four') >= 0) {
      parsed.howToTake = '2 capsules each time\n3-4 times per day\nBefore, during, or after meals\nCan be taken before sleep if needed';
      parsed.reminderOneTime = '08:30';
      parsed.reminderOneLabel = 'With breakfast';
      parsed.reminderTwoTime = '19:30';
      parsed.reminderTwoLabel = 'With dinner';
    }

    if (lower.indexOf('allergic') >= 0 || lower.indexOf('e110') >= 0 || lower.indexOf('e218') >= 0) {
      parsed.contraindications = 'Allergic to simethicone\nAllergic to E110, E218, or any excipient';
    }

    if (lower.indexOf('persistent') >= 0 || lower.indexOf('abdominal') >= 0) {
      parsed.avoid = 'Consult a clinician if abdominal symptoms are new or persistent\nCheck excipients if you have allergy history';
    }

    if (lower.indexOf('reaction') >= 0 || lower.indexOf('allergic') >= 0) {
      parsed.doctorIf = 'New or persistent abdominal discomfort\nSuspected allergic reaction';
    }

    parsed.sideEffectOne = 'No known Espumisan-specific adverse reactions';
    parsed.sideEffectTwo = 'E110 may cause allergic reactions';
    parsed.sideEffectThree = 'E218 may cause delayed allergic reactions';
    parsed.leafletUrl = 'https://rejestry.ezdrowie.gov.pl/api/rpl/medicinal-products/2268/leaflet';
    parsed.characteristicUrl = 'https://rejestry.ezdrowie.gov.pl/api/rpl/medicinal-products/2268/characteristic';
    parsed.rplIdentifier = '100022688';
    parsed.productId = '2268';
    parsed.matchedKeywords = 'espumisan, simeticonum, 40 mg';
    parsed.matchedPackage = 'GTIN: 05909990168712 | OTC | Package: 25 capsules';
    parsed.sourceNote = 'Source: local RPL SQLite match, Espumisan 40 mg capsules. Product endpoint id: 2268.';
    return parsed;
  }

  private applyRplMatchToParsedGuide(parsed: ParsedMedicineGuide, record: RplMedicineRecord): void {
    const matchedName = record.name.toLowerCase();
    parsed.name = record.name + ' ' + record.strength;
    parsed.subtitle = record.dosageForm.length > 0 ? record.dosageForm : 'Medicine matched from local RPL database';
    parsed.activeIngredient = record.activeSubstance.length > 0 ? record.activeSubstance : record.commonName;
    parsed.ingredientNote = 'Official RPL common name: ' + record.commonName;
    parsed.leafletUrl = record.leafletUrl;
    parsed.characteristicUrl = record.characteristicUrl;
    parsed.rplIdentifier = record.rplIdentifier;
    parsed.productId = this.extractRplEndpointId(record);
    parsed.matchedKeywords = this.buildMatchedKeywords(this.extractedOcrText, record);
    parsed.matchedPackage = record.packageInfo;
    parsed.sourceNote = 'Source: local MediClear RDB match. RPL identifier: ' + record.rplIdentifier + '. Product endpoint id: ' + parsed.productId + '.';
    if (matchedName.indexOf('espumisan') < 0) {
      parsed.howToTake = 'Open the official patient leaflet\nFollow the dose prescribed by your doctor or pharmacist\nDo not change dose based only on package OCR\nUse reminders only after confirming the plan';
      parsed.contraindications = 'Check the official leaflet before use\nDo not use if allergic to ' + record.commonName;
      parsed.avoid = 'Do not combine with other medicines without professional advice\nCheck interactions in the official characteristic PDF';
      parsed.doctorIf = 'You are unsure about the dose\nSymptoms change or adverse reactions occur';
      parsed.sideEffectOne = 'See official leaflet';
      parsed.sideEffectTwo = 'Check interactions';
      parsed.sideEffectThree = 'Ask pharmacist';
      parsed.reminderOneLabel = 'After plan confirmation';
      parsed.reminderTwoLabel = 'After plan confirmation';
    }
  }

  private extractRplEndpointId(record: RplMedicineRecord): string {
    const leafletId = this.extractRplEndpointIdFromUrl(record.leafletUrl);
    if (leafletId.length > 0) {
      return leafletId;
    }

    const characteristicId = this.extractRplEndpointIdFromUrl(record.characteristicUrl);
    if (characteristicId.length > 0) {
      return characteristicId;
    }

    return record.id.toString();
  }

  private extractRplEndpointIdFromUrl(url: string): string {
    const marker = '/medicinal-products/';
    const start = url.indexOf(marker);
    if (start < 0) {
      return '';
    }

    const idStart = start + marker.length;
    const tail = url.substring(idStart);
    const slash = tail.indexOf('/');
    if (slash < 0) {
      return tail;
    }
    return tail.substring(0, slash);
  }

  private buildMatchedKeywords(ocrText: string, record: RplMedicineRecord): string {
    const normalizedOcr = this.normalizeMatchText(ocrText);
    const matches: string[] = [];

    this.appendMatchedKeyword(matches, normalizedOcr, record.name);
    this.appendMatchedKeyword(matches, normalizedOcr, record.commonName);
    this.appendMatchedKeyword(matches, normalizedOcr, record.activeSubstance);
    this.appendMatchedKeyword(matches, normalizedOcr, record.strength);
    this.appendMatchedPackageCode(matches, normalizedOcr, record.packageInfo);

    if (matches.length === 0) {
      return record.name + ', ' + record.commonName + ', ' + record.strength;
    }
    return matches.join(', ');
  }

  private appendMatchedKeyword(matches: string[], normalizedOcr: string, value: string): void {
    const keyword = value.trim();
    if (keyword.length === 0) {
      return;
    }

    const normalizedKeyword = this.normalizeMatchText(keyword);
    const parts = normalizedKeyword.split(' ');
    for (let index = 0; index < parts.length; index++) {
      const part = parts[index].trim();
      if (part.length < 4 && !this.isNumericKeyword(part)) {
        continue;
      }
      if (normalizedOcr.indexOf(part) >= 0 && matches.indexOf(keyword) < 0) {
        matches.push(keyword);
        return;
      }
    }
  }

  private appendMatchedPackageCode(matches: string[], normalizedOcr: string, packageInfo: string): void {
    const normalizedPackage = this.normalizeMatchText(packageInfo);
    const parts = normalizedPackage.split(' ');
    for (let index = 0; index < parts.length; index++) {
      const part = parts[index].trim();
      if (!this.isLongNumericKeyword(part)) {
        continue;
      }
      if (normalizedOcr.indexOf(part) >= 0 && matches.indexOf(part) < 0) {
        matches.push(part);
        return;
      }
    }
  }

  private normalizeMatchText(text: string): string {
    return text.toLowerCase()
      .replace(/ą/g, 'a')
      .replace(/ć/g, 'c')
      .replace(/ę/g, 'e')
      .replace(/ł/g, 'l')
      .replace(/ń/g, 'n')
      .replace(/ó/g, 'o')
      .replace(/ś/g, 's')
      .replace(/ź/g, 'z')
      .replace(/ż/g, 'z')
      .replace(/[^a-z0-9]+/g, ' ');
  }

  private isNumericKeyword(value: string): boolean {
    return /^[0-9]+$/.test(value);
  }

  private isLongNumericKeyword(value: string): boolean {
    return /^[0-9]{8,}$/.test(value);
  }

  private sampleMedicineGuideText(): string {
    return 'Espumisan 40 mg capsules. Active ingredient: Simeticonum 40 mg. Adults may take 2 capsules 3-4 times daily, before, during, or after meals, and before sleep if needed. Do not use if allergic to simethicone, E110, E218, or any excipient. Consult a clinician if abdominal symptoms are new or persistent. E110 and E218 may cause allergic reactions.';
  }
}
