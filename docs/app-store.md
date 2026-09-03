# App Store submission — Waymark v1.0

Everything needed to fill in App Store Connect. English is the primary locale;
Turkish (`tr`) is the localized locale and the primary market. Character limits
are Apple's; counts below are current.

---

## 1. App information (static)

| Field | Value |
|---|---|
| **Name** | Waymark |
| **Bundle ID** | `tr.com.yakupad.waymark` |
| **SKU** | `waymark-ios-v1` |
| **Primary language** | English (U.S.) |
| **Primary category** | Navigation |
| **Secondary category** | Travel |
| **Content rights** | Does not contain, show, or access third-party content (map tiles are Apple Maps via MapKit; place data is first-party embedded) |
| **Age rating** | 4+ (no objectionable content). Answer "None" to every questionnaire item. |
| **Pricing** | Free, no in-app purchases |
| **Availability** | All territories (works anywhere; data is Turkey-only in v1 — noted in the description) |

### Name availability / trademark
"Waymark" is a common English noun. Before submitting, check App Store name
availability and the [TÜRKPATENT](https://www.turkpatent.gov.tr/) / USPTO marks.
Fallbacks (spec §17.1): **Milepost**, **Crossing**, **Passage**.

---

## 2. Version information (per release, v1.0)

### 2.1 Subtitle — 30 char max

| Locale | Text | Count |
|---|---|---|
| en | `Notice the towns you pass` | 25 |
| tr | `Geçtiğin yerleri fark et` | 24 |

### 2.2 Promotional text — 170 char max (editable without review)

**en**
```
On a long drive you pass forty towns without noticing one. Waymark names each place the moment you enter it — population, a line of history — fully offline.
```

**tr**
```
Uzun bir yolculukta fark etmeden kırk kasabadan geçersin. Waymark her yere girdiğin anda adını söyler — nüfusu, kısa tarihçesi — tamamen çevrimdışı.
```

### 2.3 Description — 4000 char max

**en**
```
Waymark is a quiet travel companion for intercity drives. The moment you cross into a new province, district or town, it tells you where you are — the name, the population, and a short note on why the place matters — right on your lock screen.

FULLY OFFLINE
Boundary detection, place data and history all work with no signal. Waymark is most useful exactly where the network isn't: mountain passes, empty highways, the long gap between two cities. Nothing to download mid-trip.

YOUR LOCATION STAYS ON YOUR DEVICE
No account. No sign-up. No server. No third-party location or analytics SDK. Your location is used only on your iPhone to figure out which administrative area you're in, and it is never uploaded — there is nowhere for it to go.

NOTIFICATION-LIGHT BY DESIGN
By default you get a handful of alerts per trip — roughly one per province — not forty. If you want more detail, switch the sensitivity to districts or towns in Settings. Quiet hours and a per-place cooldown keep it from ever nagging.

LIVE ACTIVITY FIRST
The current place, the administrative hierarchy and your running count live on the lock screen and in the Dynamic Island. Glance, don't unlock.

TRIP HISTORY & ROUTE MAP
Every trip is saved on device with a route line and a timeline of everywhere you passed, biggest and smallest places highlighted. Share a trip as an image with the start and end automatically trimmed, so your home and destination aren't in the picture.

COVERAGE
Version 1 covers Turkey: all 81 provinces, 970 districts and about 44,000 villages and towns, with population figures and short encyclopaedia summaries for provinces and districts.

Data sources: OpenStreetMap (ODbL), Wikidata & Wikipedia (CC BY-SA). Maps by Apple.
```

**tr**
```
Waymark, şehirlerarası yolculuklar için sessiz bir yol arkadaşıdır. Yeni bir ile, ilçeye veya kasabaya girdiğiniz anda nerede olduğunuzu söyler — adını, nüfusunu ve orayı önemli kılan kısa bir notu — doğrudan kilit ekranınızda.

TAMAMEN ÇEVRİMDIŞI
Sınır tespiti, yer verileri ve geçmiş; hepsi şebeke olmadan çalışır. Waymark tam da ağın olmadığı yerlerde en işe yarar olanıdır: dağ geçitleri, boş yollar, iki şehir arasındaki uzun boşluk. Yolculuk ortasında indirilecek bir şey yok.

KONUMUNUZ CİHAZINIZDA KALIR
Hesap yok. Kayıt yok. Sunucu yok. Üçüncü taraf konum veya analiz SDK'sı yok. Konumunuz yalnızca iPhone'unuzda, hangi idari bölgede olduğunuzu belirlemek için kullanılır ve asla yüklenmez — gidecek bir yeri yoktur.

TASARIM GEREĞİ AZ BİLDİRİM
Varsayılan olarak yolculuk başına birkaç bildirim alırsınız — kabaca il başına bir tane — kırk tane değil. Daha fazla ayrıntı isterseniz Ayarlar'dan hassasiyeti ilçe veya kasabaya alın. Sessiz saatler ve yer başına bekleme süresi, uygulamanın sizi hiç rahatsız etmemesini sağlar.

ÖNCE LIVE ACTIVITY
Mevcut yer, idari hiyerarşi ve sayacınız kilit ekranında ve Dynamic Island'da yaşar. Bakın, kilidi açmayın.

YOLCULUK GEÇMİŞİ VE ROTA HARİTASI
Her yolculuk, bir rota çizgisi ve geçtiğiniz her yerin zaman çizelgesiyle cihazda saklanır; en büyük ve en küçük yerler öne çıkarılır. Bir yolculuğu görsel olarak paylaşın; başlangıç ve bitiş otomatik kırpılır, böylece eviniz ve varış noktanız karede olmaz.

KAPSAM
Sürüm 1 Türkiye'yi kapsar: 81 il, 970 ilçe ve yaklaşık 44.000 köy ve kasaba; il ve ilçeler için nüfus bilgileri ve kısa ansiklopedi özetleri.

Veri kaynakları: OpenStreetMap (ODbL), Wikidata & Vikipedi (CC BY-SA). Haritalar Apple.
```

### 2.4 Keywords — 100 char max per locale, comma-separated, no spaces

**en**
```
road trip,offline maps,province,district,travel log,GPS,live activity,turkey,intercity,journey,drive
```
(96 chars)

**tr**
```
yolculuk,çevrimdışı harita,il,ilçe,plaka,seyahat,gezi,şehirlerarası,rota,karayolu,tatil,yol
```
(90 chars)

> Do not repeat words already in the app name/subtitle. Singular forms cover
> plurals. "app", "free" etc. are wasted — Apple ignores them.

### 2.5 What's New — 4000 char max

**en**
```
First release. Waymark tells you the name, population and a line of history for every province, district and town you drive through — fully offline, with your location never leaving the phone.
```

**tr**
```
İlk sürüm. Waymark, geçtiğiniz her il, ilçe ve kasaba için adı, nüfusu ve kısa bir tarihçeyi söyler — tamamen çevrimdışı, konumunuz telefondan hiç çıkmadan.
```

### 2.6 Support URL (required)  &  Marketing URL (optional)

Served by GitHub Pages from `docs/` on `main` (see §6):

- **Support URL:** `https://yakupad.github.io/waymark/support/`
- **Marketing URL:** `https://yakupad.github.io/waymark/` (or leave blank for v1)
- **Privacy Policy URL (required):** `https://yakupad.github.io/waymark/privacy/`

Support contact is the public GitHub issue tracker
(`https://github.com/yakupad/waymark/issues`). App Review accepts this; if they
push back, add an email in App Store Connect › App Information › Support.

### 2.7 Copyright
`2026 Yakup Ad`

### 2.8 Routing App Coverage File
N/A — Waymark is not a turn-by-turn navigation app; leave blank.

---

## 3. App Privacy (nutrition label — App Store Connect › App Privacy)

Answer: **"No, we do not collect data from this app."**

Rationale, matching `waymark/Resources/PrivacyInfo.xcprivacy`:
- `NSPrivacyTracking` = false, no tracking domains.
- `NSPrivacyCollectedDataTypes` = empty. Location is processed on-device only and
  never leaves it; trip history is stored only in the app's local SwiftData store.
  Under Apple's definition this is **not** "collection".
- `NSPrivacyAccessedAPITypes`: `NSPrivacyAccessedAPICategoryUserDefaults`, reason
  `CA92.1` (app's own settings).

If App Review pushes back on "not collected" because of the `location`
background mode, the honest answer is still *Data Not Collected* — cite the
review notes in §5 and the privacy manifest. Location that never leaves the
device is not collected data.

---

## 4. Build & signing

| Setting | Value |
|---|---|
| Marketing version | `1.0` |
| Build | `1` (bump every upload) |
| Deployment target | iOS 27.0 |
| Device family | iPhone only (`TARGETED_DEVICE_FAMILY = 1`) |
| Supported platforms | `iphoneos iphonesimulator` (no iPad / visionOS / Catalyst in v1) |
| Widget extension | `WaymarkWidgets.appex` — embedded, bundle id `tr.com.yakupad.waymark.WaymarkWidgets` |
| Capabilities | Background Modes → Location updates; Live Activities (`NSSupportsLiveActivities`) |
| Entitlements | none beyond the defaults (no push, no iCloud, no App Groups in v1) |
| Encryption | Uses only standard OS crypto (HTTPS via `MKMapSnapshotter`). Set `ITSAppUsesNonExemptEncryption = NO` in Info.plist to skip the yearly self-classification prompt. |

Archive: `Product › Archive` on a **generic iOS device** destination (Release),
then `Distribute App › App Store Connect`.

### Info.plist / permission strings
Source of truth: `waymark/Resources/InfoPlist.xcstrings` (en + tr).

- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSLocationTemporaryUsageDescriptionDictionary` — n/a (not used)

TR copy (spec §13):
> Uygulama arka plandayken de yeni bir şehre veya ilçeye girdiğinizde sizi
> bilgilendirebilmemiz için konumunuza ihtiyaç duyuyoruz. Konum bilginiz
> cihazınızdan hiçbir yere gönderilmez.

---

## 5. App Review notes (paste into "Notes" field)

```
Waymark tells the user which Turkish administrative area (province / district /
town) they are currently in, and notifies them when it changes during a drive.

WHY "ALWAYS" LOCATION
The core feature is detecting an administrative-boundary crossing while the
screen is off and the app is backgrounded during a long drive. This is not
possible with "When In Use". Permission is requested progressively: the app is
fully functional in the foreground with "When In Use", and only asks for
"Always" during the first trip, with an on-screen explanation. The user can
decline and keep using the app in the foreground.

BACKGROUND MODES
"location" only. pausesLocationUpdatesAutomatically is off; the app runs a 15s
heartbeat so a trip is never silently dropped when the vehicle is stationary.

NO NETWORK FOR THE CORE LOOP
All boundary detection and place content comes from an embedded SQLite pack
(tr.pack, ~8 MB) built from OpenStreetMap + Wikidata + Wikipedia. The only
network call in the app is MKMapSnapshotter, used to render the optional
shareable trip image. There is no server, account, or analytics.

LIVE ACTIVITY
Starts when the user taps "Start a trip"; ends when they tap "End" or the trip
is detected as stale.

HOW TO TEST WITHOUT DRIVING
This build includes a simulated-location mode. Launching the app in the
Simulator (or tapping "Start a trip") plays a short demo drive across central
Anatolia automatically, so the full trip → notification → summary → share flow
can be reviewed at a desk. A debug menu (Settings › Developer) can inject
locations and replay a GPX file.

DEMO ACCOUNT
Not applicable — the app has no accounts or login.
```

---

## 6. Screenshots

**Required:** at least one 6.9" iPhone screenshot (1320 × 2868 px, portrait).
Apple up-scales 6.9" to fill the 6.5"/6.7" slots, so one set is enough.

Delivered in `docs/app-store/screenshots/`, framed, for both locales:

| File | Screen |
|---|---|
| `{en,tr}/*-home.png` | Home — start button, current place, recent trips |
| `{en,tr}/*-active.png` | Active trip — direction panel, live map, places passed |
| `{en,tr}/*-summary.png` | Trip summary — route, stats, highlights, timeline |
| `{en,tr}/*-place.png` | Place detail — population, area, Wikipedia summary |

Raw (unframed) device captures are in `screenshots/raw/`.

**Optional extras** (grab on a real device during field testing): Settings,
a real lock-screen Live Activity.

Captured with the `-waymarkScreen active|summary|place` launch hook (see
`waymark/App/waymarkApp.swift`) plus `-AppleLanguages '(tr)' -AppleLocale tr_TR`
for the Turkish set. Regenerate the framed images:
```
xcrun simctl launch <sim> tr.com.yakupad.waymark -waymarkScreen active
xcrun simctl io <sim> screenshot raw/en-active.png
swift tools/appstore/frame.swift <rawDir> docs/app-store/screenshots/en en
# then: sips -z 2868 1320 on each (lockFocus renders @2x)
```

---

## 7. App icon

`waymark/Assets.xcassets/AppIcon.appiconset/` — single 1024×1024 with light,
dark and tinted variants (`AppIcon-1024*.png`). Generator:
`tools/appstore/makeicon.swift`. A route of waypoint dots leading to a map pin,
on the brand-blue gradient.

---

## 8. Pre-submission checklist

- [ ] Bump build number
- [ ] `ITSAppUsesNonExemptEncryption = NO` in the app Info.plist
- [ ] Support URL + Privacy Policy URL live and reachable
- [ ] Screenshots uploaded for `en` and `tr`
- [ ] App Privacy answered ("Data Not Collected")
- [ ] Review notes pasted (§5)
- [ ] Age rating questionnaire = all "None" → 4+
- [ ] Export-compliance answered
- [ ] TestFlight: one real-device pass of trip → notification → Live Activity → summary → share
- [ ] Field test (spec §12.4): battery < 8%/hr screen-off, signal-gap behaviour

---

## 9. Data provenance (for the review notes / legal)

- **Boundaries:** OpenStreetMap `admin_level` 4 (il) & 6 (ilçe), Geofabrik
  `turkey-latest` extract 2026-08-31. © OpenStreetMap contributors, ODbL.
- **Population:** Wikidata P1082 (mostly 2021–2023 values). TÜİK ADNKS is the
  intended v1 source once a machine-readable CSV is available.
- **Summaries:** Wikipedia REST API (tr + en), fetched 2026-09-03. CC BY-SA 4.0,
  attributed in-app on every place detail screen with a link to the article.
- **Map tiles:** Apple Maps via MapKit (no third-party tile provider).
- Pack: 81 provinces, 970 districts, 44,042 settlements, ~8 MB, embedded in the
  app bundle (`waymark/Resources/tr.pack`).
