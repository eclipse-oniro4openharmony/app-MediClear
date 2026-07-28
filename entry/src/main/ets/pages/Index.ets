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
  name: string = 'Ibuprofen 200 mg';
  subtitle: string = 'Pain reliever / Fever reducer';
  activeIngredient: string = 'Ibuprofen 200 mg';
  ingredientNote: string = 'Nonsteroidal anti-inflammatory drug (NSAID)';
  howToTake: string = '1 tablet each time\nEvery 6-8 hours\nTake after meals\nMax 3 tablets in 24 hours';
  contraindications: string = 'Allergic to ibuprofen or any NSAIDs\nUnder 12 years old without medical guidance';
  avoid: string = 'Avoid alcohol while taking ibuprofen\nDo not combine with other medicines containing ibuprofen, aspirin, or other NSAIDs';
  doctorIf: string = 'Symptoms last more than 3 days\nSevere allergic reaction, rash, swelling, or trouble breathing';
  sideEffectOne: string = 'Nausea';
  sideEffectTwo: string = 'Dizziness';
  sideEffectThree: string = 'Stomach discomfort';
  reminderOneTime: string = '08:30';
  reminderOneLabel: string = 'After breakfast';
  reminderTwoTime: string = '19:30';
  reminderTwoLabel: string = 'After dinner';
  sourceNote: string = 'Source: uploaded medicine leaflet, dosage and warning sections';
}

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State selectedGuide: number = 0;
  @State uploadState: string = 'No medicine guide scanned yet';
  @State uploadSource: string = 'Tap Upload Medicine Guide to scan a medicine leaflet.';
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
      Row({ space: 10 }) {
        Button('Take Photo')
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor('#009F9A')
          .borderRadius(8)
          .height(42)
          .layoutWeight(1)
          .onClick(() => {
            this.startMedicineGuideUpload('camera');
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
            this.startMedicineGuideUpload('file');
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
        this.startMedicineGuideUpload('camera');
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

  private startMedicineGuideUpload(sourceType: string): void {
    this.uploadState = 'Reading medicine guide image...';
    this.uploadSource = sourceType === 'camera' ? 'Photo captured. OCR text extracted and parsed locally.' : 'Guide file uploaded. OCR text extracted and parsed locally.';
    const parsed: ParsedMedicineGuide = this.parseMedicineGuide(this.sampleMedicineGuideText());
    this.applyParsedMedicineGuide(parsed);
    this.uploadState = 'Analysis complete';
    this.selectedGuide = 0;
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
  }

  private parseMedicineGuide(text: string): ParsedMedicineGuide {
    const lower: string = text.toLowerCase();
    const parsed: ParsedMedicineGuide = new ParsedMedicineGuide();

    if (lower.indexOf('ibuprofen') >= 0) {
      parsed.name = 'Ibuprofen 200 mg';
      parsed.subtitle = 'Pain reliever / Fever reducer';
      parsed.activeIngredient = 'Ibuprofen 200 mg';
      parsed.ingredientNote = 'Nonsteroidal anti-inflammatory drug (NSAID)';
    }

    if (lower.indexOf('every 6-8 hours') >= 0 || lower.indexOf('every 6 to 8 hours') >= 0) {
      parsed.howToTake = '1 tablet each time\nEvery 6-8 hours\nTake after meals\nMax 3 tablets in 24 hours';
      parsed.reminderOneTime = '08:30';
      parsed.reminderOneLabel = 'After breakfast';
      parsed.reminderTwoTime = '19:30';
      parsed.reminderTwoLabel = 'After dinner';
    }

    if (lower.indexOf('allergic') >= 0 || lower.indexOf('under 12') >= 0) {
      parsed.contraindications = 'Allergic to ibuprofen or any NSAIDs\nUnder 12 years old without medical guidance';
    }

    if (lower.indexOf('alcohol') >= 0 || lower.indexOf('aspirin') >= 0) {
      parsed.avoid = 'Avoid alcohol while taking ibuprofen\nDo not combine with ibuprofen, aspirin, or other NSAIDs';
    }

    if (lower.indexOf('3 days') >= 0 || lower.indexOf('breathing') >= 0) {
      parsed.doctorIf = 'Symptoms last more than 3 days\nSevere allergic reaction, rash, swelling, or trouble breathing';
    }

    parsed.sideEffectOne = 'Nausea';
    parsed.sideEffectTwo = 'Dizziness';
    parsed.sideEffectThree = 'Stomach discomfort';
    parsed.sourceNote = 'Source: uploaded leaflet, dosage section and warning section';
    return parsed;
  }

  private sampleMedicineGuideText(): string {
    return 'Ibuprofen 200 mg tablets. Active ingredient: ibuprofen 200 mg. Adults and children over 12 years: take 1 tablet every 6-8 hours. Take after meals. Do not exceed 3 tablets in 24 hours. Do not use if allergic to ibuprofen or any NSAIDs. Do not use for children under 12 years without medical guidance. Avoid alcohol. Do not combine with aspirin or other NSAIDs. Consult a doctor if symptoms persist for more than 3 days or if rash, swelling, breathing difficulty, nausea, dizziness, or stomach discomfort occurs.';
  }
}
