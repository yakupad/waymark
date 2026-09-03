# Waymark — Proje Spesifikasyonu ve Kod Üretim Dokümanı

> `Waymark`: yol üzerindeki işaret taşı. App Store'da isim müsaitliği ve marka
> çakışması **doğrulanmalıdır** — bu doküman ismi kesinleşmiş varsayar.
>
> Bu doküman iki işi birden görür: (1) projenin tek kaynaklı teknik referansı,
> (2) kod üretimi sırasında bölüm bölüm beslenecek prompt seti (bkz. Bölüm 16).

**Versiyon:** 0.10 — v1 kapsamı Türkiye, mimari global
**Platform:** iOS 27.0+ (F1 kararı; v0.2'de 17.0 idi — bkz. Bölüm 17.2)
**Dil:** Swift 6+ / SwiftUI (Xcode 27 toolchain)
**Mimari:** MVVM-C
**Kod ve commit dili:** İngilizce
**Arayüz dilleri (v1):** İngilizce (base) + Türkçe
**Coğrafi kapsam (v1):** Türkiye

---

## 0. Sürüm stratejisi

| Sürüm | Coğrafi kapsam | Arayüz dilleri | Yeni altyapı |
|---|---|---|---|
| **v1** | Türkiye | EN, TR | Tek gömülü bölge paketi |
| **v2** | + Avrupa'nın yoğun turizm ülkeleri | + FR, ES | Paket indirme yöneticisi |
| **v3** | Global | + AR, ZH, JA | Dünya ADM0/ADM1 temel katmanı, çok dilli ad çözümleme |

**Bu tablonun tek amacı v1'de yanlış soyutlama seçmemektir.** Aşağıdaki kararlar
(K6–K8) bugün neredeyse sıfır maliyetli, sonra ertelenirse F1–F5'i baştan yazdırır.
Buna karşılık paket indirme yöneticisi, 200 ülkelik `admin_level` eşlemesi ve çok dilli
ad geri düşüş zinciri v1'de **yazılmayacaktır** — onlar gerçek iş ve erken yapılırsa israf.

Ölçüm notu: dünyanın ADM0 + ADM1 katmanı, Bölüm 5.4 kodlamasıyla ve 100 m toleransta
**12,4 MB** (258 ülke → 3,9 MB; 4.596 birinci düzey birim → 8,5 MB). v3'te bundle'a girer.
v1'de taşınmaz — Türkiye'nin kendi ADM0 poligonu "kapsama alanı dışı" tespitine yeter.

---

## 1. Ürün özeti

Şehirlerarası yolculuk sırasında kullanıcı yeni bir idari birime (il / ilçe / köy) girdiğinde
onu bilgilendiren, girdiği yer hakkında nüfus ve kısa tarihçe sunan iOS uygulaması.

**Çekirdek değer önermesi:** "Yoldan geçtiğin yerleri artık fark ediyorsun."
Kullanıcı 10 saatlik bir yolculukta pencereden geçip gittiği 40 yerin adını, nüfusunu
ve neden dikkate değer olduğunu öğreniyor.

**Referans senaryo:** İstanbul → Ordu (~750 km, ~10 saat). Rota; Kocaeli, Sakarya, Düzce,
Bolu, Çankırı/Ankara, Çorum, Amasya, Tokat, Ordu illerinden ve onlarca ilçeden geçer.
Güzergâhın önemli bir kısmında hücresel şebeke zayıf veya yoktur.

---

## 2. Tasarım ilkeleri (ihlal edilemez)

Bu dört madde tüm teknik kararların üzerindedir. Bir tasarım tercihi bunlardan biriyle
çakışıyorsa tercih değişir, ilke değil.

**İ1 — Çekirdek işlev tamamen çevrimdışıdır.**
Konum tespiti, idari birim çözümleme, nüfus ve tarihçe içeriği; hiçbiri ağ gerektirmez.
Ağ yalnızca isteğe bağlı zenginleştirme (v2 fotoğraf, yakındaki yerler) için kullanılır.
Gerekçe: uygulamanın en çok değer ürettiği anlar (dağ yolları, ıssız güzergâhlar) tam olarak
şebekenin olmadığı anlardır.

**İ2 — Kullanıcının konumu cihazı terk etmez.**
Sunucu yok, analitikte ham koordinat yok, üçüncü taraf konum SDK'sı yok.
Bu hem gizlilik duruşu hem App Store inceleme kolaylığı hem de pazarlama argümanıdır.

Rota izi cihazda saklanır (Bölüm 7.7) ve bu İ2'yi ihlal etmez — veri hiçbir yere gönderilmez.
Ancak izin varlığı iki yeni yükümlülük doğurur: kullanıcı iz kaydını kapatabilmeli ve
paylaşılan görselde uç noktalar kırpılabilmelidir. Detay 7.7'de.

**İ3 — Bildirim kıtlık kaynağıdır.**
Uygulamayı batıracak tek şey bildirim bombardımanıdır. Varsayılan davranış az bildirim
göndermektir; kullanıcı isterse artırır. Detay için Bölüm 8.

**İ4 — Yanlış bilgi vermektense hiç bilgi vermemek yeğdir.**
Küçük yerleşimler için uydurma tarihçe üretilmez. Kaynağı olmayan alan boş bırakılır.

**İ5 — v1 Türkiye'yi teslim eder, şema dünyayı bekler.**
Kod ve şemada "il" ve "ilçe" kavramları **hard-code edilmez**. Bunlar `tier 1` ve `tier 2`
olarak modellenir; Türkçe etiketleri veriden gelir. Aynı şekilde içerik tablosu `lang`
sütunu taşır, ad alanları çok dilli genişlemeye hazır durur.
Bu ilke tasarım için geçerlidir, **kapsam için değil**: v1'de yalnızca Türkiye verisi ve
yalnızca EN/TR metinleri üretilir.

---

## 3. Kapsam

### v1 (ilk sürüm)

| Özellik | Kapsam |
|---|---|
| Coğrafi kapsam | Yalnızca Türkiye (tek gömülü bölge paketi) |
| Arayüz dilleri | İngilizce (base) + Türkçe |
| Hassasiyet seviyeleri | Tier 1 (il), tier 2 (ilçe), köy/kasaba |
| Tespit yöntemi | Çevrimdışı poligon (il/ilçe) + en yakın nokta (köy) |
| Yolculuk başlatma | Manuel (kullanıcı butona basar) |
| Birincil yüzey | Live Activity (kilit ekranı + Dynamic Island) |
| Push bildirim | Yalnızca kullanıcının seçtiği hassasiyet seviyesinde |
| İçerik | Nüfus, yüzölçümü, rakım, kısa tarihçe (Vikipedi özeti) |
| Rota izi | Cihazda kaydedilir, haritada çizgi olarak gösterilir |
| Yolculuk geçmişi | Geçilen yerlerin zaman çizelgesi, yolculuk sonu özeti |
| Paylaşım | Rota haritası + istatistik içeren görsel, uç noktalar kırpılmış |

### v2

- Bölge paketi indirme yöneticisi ve ilk yabancı ülkeler
- Fransızca ve İspanyolca arayüz
- Landmark yakınlığı ("solunda Abant Gölü var")
- Otomatik yolculuk tespiti (`CMMotionActivityManager` → `automotive`)
- Yakındaki yerler (Places API, yalnızca kullanıcı talebiyle)
- Fotoğraf zenginleştirme
- Apple Watch companion
- CarPlay

### Kapsam dışı (bilinçli olarak yapılmayacak)

- Navigasyon / rota tarifi — Apple Maps'in işi, rekabet etmiyoruz
- Sosyal özellikler, arkadaş takibi, canlı konum paylaşımı
- Sunucu tarafı hesap sistemi
- Yaya veya şehir içi kullanım senaryosu (v1 için araç odaklı)

---

## 4. Mimari kararlar ve gerekçeleri

Bu bölüm kod üretirken tartışmaya kapalıdır. Her karar bir alternatifin elenmesiyle alınmıştır.

### K1 — Reverse geocoding kullanılmayacak

`CLGeocoder` da, Google Geocoding API de, Mapbox da hayır.

Gerekçeler:
- **Ağ bağımlılığı** — İ1 ile doğrudan çakışıyor.
- **Maliyet** — Geçiş tespiti için sürekli sorgulama gerekir. 2 km'de bir sorgu = yolculuk
  başına ~375 istek. Google'ın Essentials kategorisindeki 10.000 ücretsiz aylık çağrı,
  tüm kullanıcı tabanında ayda ~26 yolculuk demektir.
- **Lisans** — Google, geocoding sonuçlarının kalıcı saklanmasını yasaklıyor (30 gün önbellek
  sınırı). Türkiye'nin ilçelerini bir kere çekip gömme planı ToS ihlalidir.
- **Doğruluk** — Şehirlerarası yolun ortasında reverse geocoding en yakın adreslenebilir
  nesneyi döner; bu genelde bir yol segmentidir, yerleşim değil.
- **Rate limit** — `CLGeocoder` agresif şekilde kısıtlanır ve sessizce hata döndürmeye başlar.

### K2 — `CLLocationManager` / `CLMonitor` region monitoring **tespit için** kullanılmayacak

Bu karar iOS 17'nin yeni `CLMonitor` API'si çıktıktan sonra yeniden gözden geçirilmiş ve
korunmuştur.

**Gerekçe 1 — 20 koşul sınırı kalkmadı.** `CLMonitor.CircularGeographicCondition`,
`CLCircularRegion`'ın eşzamanlı 20 bölge sınırını devralıyor; Apple mühendisleri geliştirici
forumunda bunu açıkça teyit etti. 973 ilçe için "kayan pencere" yönetimi gerekir ve bu,
çözdüğünden fazla karmaşıklık üretir.

**Gerekçe 2 (asıl olan) — geofence dairedir, ilçe değildir.**
973 Türkiye ilçesinin gerçek sınır poligonları üzerinde ölçüldü:

| Yaklaşım | Sonuç |
|---|---|
| **İç teğet çember** (yanlış bildirim üretmez) | İlçe alanının yalnızca **%47'sini** kapsar (medyan). En kötü %10'luk dilimde %32 |
| **Çevrel çember** (hiçbir yeri kaçırmaz) | Gerçek alanın **2,08 katını** kapsar (medyan); en kötü %10'luk dilimde 3,11 kat |

Yani daire ile ya ilçenin yarısını kaçırırsın ya da komşu ilçelerde tetiklenirsin.
Ortada makul bir ayar noktası yok — ilçeler dairesel değil, uzun ve düzensiz şekillerdir.
İç teğet çember yarıçapı medyanı 9,7 km; ilçe alanı medyanı 645 km².

**Gerekçe 3 — gecikme.** Apple, sahte bildirimleri engellemek için sınır geçişinden sonra
kullanıcının minimum bir mesafe kat etmesini **ve en az 20 saniye** aynı tarafta kalmasını
bekler. Buna sistem tarafındaki öngörülemez gecikme eklenir. "Merzifon'a yeni girdin"
hissiyatı için bu davranış uygun değildir; kendi histerezisimizi (7.5) yönetmek hem daha
hızlı hem de ayarlanabilir.

**Gerekçe 4 — içerideysen giriş olayı gelmez.** Kullanıcı yolculuğu bir ilçenin ortasında
başlatırsa o ilçe için `didEnterRegion` tetiklenmez; durumu ayrıca sorgulaman gerekir.

**Bunun yerine:** konum güncellemesi geldiğinde doğrudan poligon testi yapılır. Ölçülen
maliyet zaten ihmal edilebilir (< 5 ms).

#### K2-b — Ancak geofence'in meşru bir rolü var: **uygulamayı uyandırmak**

Poligon testi yalnızca uygulama çalışırken yapılabilir. Geofence'in yapabildiği ve bizim
yapamadığımız tek şey, uygulama sistem tarafından sonlandırılmışken onu **yeniden
başlatmaktır**.

Bu, v1'de gerekli değildir (yolculuk manuel başlatılır ve `UIBackgroundModes: location`
süreci ayakta tutar), ama iki yerde işe yarar:

- **v2 otomatik yolculuk tespiti** — kullanıcının evi/işi çevresinde birkaç geniş yarıçaplı
  koşul, araca binip uzaklaşınca uygulamayı uyandırır.
- **R4 kurtarma** — arka planda sonlandırma sonrası yeniden canlanma.

Bu kullanımda daire-poligon uyumsuzluğu **sorun değildir**, çünkü daire bir sınır tanımı
değil, sadece bir tetikleyicidir. Uyandıktan sonra gerçek tespiti yine poligon motoru yapar.
20 koşul sınırı da bu ölçekte fazlasıyla yeterlidir.

### K3 — Veri build-time'da hazırlanır, runtime'da indirilmez

OSM verisi bir Python pipeline'ı ile işlenip SQLite dosyası olarak app bundle'a gömülür.
Veri güncellemesi = pipeline'ı çalıştır + yeni uygulama sürümü yayınla. Yılda bir yeterlidir.

Gerekçe: uzaktan veri indirme; sunucu, sürümleme, kısmi indirme hatası, ilk açılışta bekleme
gibi bir dizi problem getirir ve İ1'i zayıflatır.

### K4 — Köy/kasaba için poligon değil, nokta kullanılır

~35.000 yerleşim için poligon taşımak dosyayı gereksiz şişirir. Ayrıca köy sınırları OSM'de
tutarsızdır. En yakın yerleşim merkezi + yarıçap yaklaşımı hem küçük hem de daha doğal sonuç
verir: yol kenarındaki tabelanın mantığına karşılık gelir.

### K5 — Live Activity birincil yüzeydir, push bildirim ikincil

İ3'ün doğrudan uygulaması. Detay Bölüm 8'de.

### K6 — İdari birimler `tier` ile modellenir, `province`/`district` tablolarıyla değil

`admin_level=4 → il`, `admin_level=6 → ilçe` eşlemesi Türkiye'de temizdir ama evrensel değildir:
Fransa'da 6 = *département*, Japonya'da 6 seviyesi **hiç yoktur** (4 → 7'ye atlar),
ABD'de county'siz eyaletler vardır, Birleşik Krallık'ta eşleme İngiltere ve İskoçya arasında
bile değişir.

Bu yüzden tek bir `admin_unit` tablosu ve `tier` sütunu kullanılır. `osm_admin_level → tier`
eşlemesi ve kullanıcıya gösterilen etiket (`İl` / `Province`) `tier_label` tablosundan gelir.
v1'de bu tabloda yalnızca Türkiye'nin iki satırı vardır.

**Bugünkü maliyeti sıfırdır** — sadece isimlendirme tercihidir. Sonra yapılırsa
`GeoData`, `LocationEngine` ve tüm UI katmanı yeniden yazılır.

### K7 — Wikidata birleştirme anahtarıdır, TÜİK tek kaynak değildir

TÜİK Türkiye için doğru ve otoriter kaynaktır; v1'de nüfus oradan gelir. Ancak 200 ülkenin
istatistik kurumuyla tek tek entegrasyon kurmak ölçeklenmez.

Bu yüzden her idari birim ve yerleşim, `wikidata_id` sütunu taşır. Wikidata **CC0**'dır
(atıf yükü yok), OSM relation'larına `wikidata=*` etiketiyle zaten bağlıdır ve tek sorguda
nüfusu (P1082), yedi dildeki etiketi ve Vikipedi makale bağlantılarını verir.

v1'de bu sütun doldurulur ama nüfus için TÜİK kullanılır (`population_source` ile işaretlenir).
v2+ ülkelerinde Wikidata devreye girer. Sütunu şimdi eklemenin maliyeti bir `JOIN`'dir.

### K8 — Veri, "bölge paketi" formatında üretilir; v1'de tek paket bundle'a gömülür

v1'de indirme yöneticisi **yazılmaz**. Ancak Türkiye verisi, ileride indirilecek paketlerle
aynı dosya formatında, `region` ve `pack_version` meta bilgisiyle üretilir ve bundle'a konur.

Böylece v2'de eklenecek şey yalnızca indirme ve dosya yönetimi olur; veri formatı,
şema ve okuma katmanı değişmez.

---

## 5. Veri katmanı

### 5.1 Kaynaklar

| Veri | Kaynak | Lisans | Atıf gereksinimi |
|---|---|---|---|
| İl sınırları (`admin_level=4` → tier 1) | OpenStreetMap / Geofabrik Türkiye extract | ODbL | Evet |
| İlçe sınırları (`admin_level=6` → tier 2) | OpenStreetMap | ODbL | Evet |
| Yerleşim noktaları (`place=village\|town\|hamlet\|suburb`) | OpenStreetMap | ODbL | Evet |
| Nüfus (v1) | TÜİK ADNKS | Açık veri | Kaynak belirtilir |
| Birleştirme anahtarı + İngilizce ad | Wikidata | **CC0** | Gerekmiyor |
| Tarihçe özeti (tr) | Vikipedi | CC BY-SA 4.0 | Evet — link + lisans |
| Tarihçe özeti (en) | Wikipedia | CC BY-SA 4.0 | Evet — link + lisans |
| Rakım | SRTM / OSM `ele` etiketi | Kamu malı / ODbL | — |

İngilizce içerik kapsaması Türkçe'den belirgin şekilde düşük olacaktır — küçük ilçelerin
İngilizce Vikipedi makalesi çoğu zaman yoktur. Geri düşüş: `kullanıcı dili → en → yok`.
İ4 gereği eksik içerikte kart gizlenir; İngilizce arayüzde Türkçe metin gösterilmez.
Yer **adı** ise her zaman yerel biçimiyle gösterilir (`Merzifon`), çünkü kullanıcı yol
tabelasında onu görür. İngilizce ad varsa ikincil olarak eklenir.

**Atıf ekranı zorunludur.** Ayarlar > Hakkında altında OSM, TÜİK ve Vikipedi atıfları,
Vikipedi için CC BY-SA lisans linki ve her madde detayında kaynak makale linki bulunur.

### 5.2 Pipeline (`tools/build_pack.py`)

Girdi: `turkey-latest.osm.pbf` (Geofabrik), TÜİK CSV, Wikidata sorgusu.
Çıktı: `tr.pack` (SQLite).

#### F0 doğrulama sonucu (tamamlandı — OSM yeterli, plan B gerekmiyor)

Geofabrik Türkiye extract'i (614 MB) üzerinde ölçülen `admin_level` dağılımı:

| Seviye | Adet | Not |
|---|---|---|
| 2 | 9 | Türkiye + 8 komşu → extract sınır ötesini de içeriyor |
| 4 | **101** | Beklenen 81; fazlası komşu ülkelerden |
| 5 | 40 | Türkiye'de kullanılmıyor |
| 6 | **1041** | Beklenen 973; fazlası komşu ülkelerden |
| 7 | 131 | v1'de kullanılmıyor |
| 8 | 13.805 | v2 köy/mahalle değerlendirmesi için not |
| 9 / 10 | 20 / 24 | Seyrek, kullanılamaz |
| **88** | **1** | **OSM'de yazım hatası — pipeline çökmeden atlamalı** |

**Sonuç: hiçbir idari birim eksik değil, fazlalık var.** Fazlalık komşu ülkelerin
birimleridir; adları Arapça (ناحية), Kürtçe (قەزای) ve Farsça (بخش) idari terimler taşır.

Bu üç zorunluluğu doğurur:

1. **Ülke filtresi (yeni), iki kademeli.** Ölçüldü:
   `ISO3166-2=TR-` etiketi tier-1'de **81/81** eşleşiyor, tier-2'de **0** —
   ISO 3166-2 Türkiye için yalnızca il seviyesini tanımladığından bu beklenen sonuçtur.
   - **Tier 1:** `ISO3166-2=TR-*` etiketiyle filtrelenir. Kesin ve geometri gerektirmez.
     Ek kazanç: etiketin sayısal kısmı doğrudan **plaka kodudur** → `admin_code`
     ayrı bir TÜİK eşleştirmesi olmadan doldurulur.
   - **Tier 2:** doğrulanmış 81 il poligonuna karşı **maksimum kesişim alanı** ile atanır.
     Centroid testi kullanılmaz — hilal biçimli kıyı ilçelerinde centroid poligonun dışına
     düşebilir. Bu tek işlem hem yabancı ilçeleri eler hem `parent_id` atar.
     Kesişim oranı %50'nin altındaki kayıtlar şüpheli olarak raporlanır.

   Hedef: **81 tier-1, 973 tier-2.** Tutmuyorsa pipeline hata verir.
2. **Ad birleştirme anahtarı olamaz.** 1041 relation yalnızca 1013 benzersiz ad üretiyor —
   28 çakışma var. Eşleştirme OSM relation id + `parent_id` üzerinden yapılır;
   TÜİK eşleştirmesi ad değil kod üzerinden gider.
3. **Bozuk seviye değerleri tolere edilmeli.** `admin_level=88` gibi kayıtlar sessizce
   atlanır ve rapora yazılır; pipeline durmaz.

OPL çıktısında ASCII dışı karakterler `%XXXX%` biçiminde kodlanır (Türkçe karakterler dahil);
okuma katmanı bunu çözmek zorundadır.

#### Adımlar

1. **Ayıklama** — `osmium` ile `admin_level` 4 ve 6 relation'larını, `place=*` node'larını çıkar.
2. **Ülke filtresi** — Türkiye `admin_level=2` poligonuna göre komşu ülke birimlerini ele.
   Etiket bazlı (`ISO3166-2=TR-`) kontrolü de çalıştır, iki sayıyı karşılaştır ve raporla.
3. **Doğrulama** — 81 tier-1 ve 973 tier-2 var mı? Her tier-1'in en az 1 tier-2'si var mı?
   Kapanmamış ring var mı? Geçersiz `admin_level` değeri olan kayıtlar atlanıp raporlanır.
   Ad çakışmaları (28 bekleniyor) rapora yazılır ama hata değildir.
4. **Sadeleştirme** — Shapely `simplify(tolerance=0.001, preserve_topology=True)`.
   0.001 derece ≈ 100 m. GPS'in kendisi ±20 m saparken daha yüksek çözünürlük anlamsızdır.
5. **Eşleştirme** — OSM birimlerini TÜİK plaka/ilçe koduna eşle. Ad normalizasyonu Türkçe
   karakter ve büyük/küçük harf (`İ`/`ı` tuzağı) dikkate alınarak yapılır.
6. **İçerik** — Vikipedi API'sinden yalnızca il ve ilçeler için özet çek (~1.050 kayıt).
   Köyler için özet çekilmez (İ4 ve boyut gerekçesiyle).
7. **Paketleme** — SQLite yaz, R\*Tree indeksleri kur, `VACUUM`, boyut raporu bas.

Pipeline deterministik olmalı: aynı girdi aynı çıktıyı üretmeli (hash ile doğrulanır).

### 5.3 Şema

```sql
-- Bir bölge paketi = bir ülke. v1'de tek satır: Türkiye.
CREATE TABLE region (
    id              INTEGER PRIMARY KEY,
    iso_code        TEXT NOT NULL UNIQUE,  -- 'TR'
    name_local      TEXT NOT NULL,         -- 'Türkiye'
    name_en         TEXT NOT NULL,         -- 'Turkey'
    wikidata_id     TEXT,                  -- 'Q43'
    pack_version    INTEGER NOT NULL,
    data_date       TEXT NOT NULL
);

-- osm_admin_level -> tier eşlemesi ve kullanıcıya gösterilecek etiketler (K6).
-- v1'de yalnızca iki satır. Yeni ülke = yeni satırlar, şema değişmez.
CREATE TABLE tier_label (
    region_id       INTEGER NOT NULL REFERENCES region(id),
    tier            INTEGER NOT NULL,      -- 1, 2, 3...
    osm_admin_level INTEGER,               -- TR: tier1=4, tier2=6
    label_local     TEXT NOT NULL,         -- 'İl', 'İlçe'
    label_en        TEXT NOT NULL,         -- 'Province', 'District'
    PRIMARY KEY (region_id, tier)
);

-- TÜM idari birimler tek tabloda. il/ilçe ayrımı tier sütunundadır (K6).
CREATE TABLE admin_unit (
    id              INTEGER PRIMARY KEY,
    region_id       INTEGER NOT NULL REFERENCES region(id),
    parent_id       INTEGER REFERENCES admin_unit(id),  -- tier 1 için NULL
    tier            INTEGER NOT NULL,
    name_local      TEXT NOT NULL,         -- 'Merzifon'
    name_en         TEXT,                  -- varsa
    names_extra     TEXT,                  -- JSON {"fr":..,"ja":..} — v1'de NULL
    osm_id          INTEGER,
    wikidata_id     TEXT,                  -- K7
    admin_code      TEXT,                  -- TR: plaka / TÜİK kodu
    population      INTEGER,
    population_year INTEGER,
    population_src  TEXT,                  -- 'tuik' | 'wikidata'
    area_km2        REAL,
    centroid_lat    REAL NOT NULL,
    centroid_lon    REAL NOT NULL
);
CREATE INDEX idx_admin_parent ON admin_unit(parent_id);
CREATE INDEX idx_admin_tier   ON admin_unit(region_id, tier);

CREATE TABLE settlement (
    id              INTEGER PRIMARY KEY,
    parent_id       INTEGER NOT NULL REFERENCES admin_unit(id),
    name_local      TEXT NOT NULL,
    name_en         TEXT,
    names_extra     TEXT,
    kind            INTEGER NOT NULL,      -- 0=village 1=town 2=hamlet
    geonames_id     INTEGER,
    wikidata_id     TEXT,
    lat             REAL NOT NULL,
    lon             REAL NOT NULL,
    population      INTEGER,
    elevation_m     INTEGER
);

-- Tarihçe metni. lang sütunu çok dilliliğin taşıyıcısıdır (İ5).
-- v1'de yalnızca 'tr' ve 'en' satırları üretilir; yeni dil = yeni satır.
CREATE TABLE article (
    entity_kind     INTEGER NOT NULL,      -- 0=admin_unit 1=settlement
    entity_id       INTEGER NOT NULL,
    lang            TEXT NOT NULL,         -- 'tr' | 'en'
    summary         TEXT NOT NULL,
    source_url      TEXT NOT NULL,
    PRIMARY KEY (entity_kind, entity_id, lang)
);

-- Poligon geometrisi ayrı tabloda: liste sorgularında okunmasın diye
CREATE TABLE geometry (
    entity_id       INTEGER PRIMARY KEY REFERENCES admin_unit(id),
    blob            BLOB NOT NULL
);

-- Uzamsal ön filtre
CREATE VIRTUAL TABLE admin_rtree      USING rtree(id, min_lon, max_lon, min_lat, max_lat);
CREATE VIRTUAL TABLE settlement_rtree USING rtree(id, min_lon, max_lon, min_lat, max_lat);

CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
-- meta: schema_version, pack_format_version, osm_extract_date, tuik_year, build_hash
```

**Şemadaki üç global hazırlık noktası:** `admin_unit.tier` (K6), `wikidata_id` (K7),
`article.lang` (İ5). Üçü de v1'de neredeyse hiçbir ek iş çıkarmıyor ama v2/v3'te
şema göçü gerektirmeden genişliyor.

### 5.4 Poligon binary formatı

Little-endian, sabit boyutlu, `Data` üzerinden doğrudan okunabilir:

```
uint8   version            (= 1)
uint16  ringCount
her ring için:
    uint8   isHole         (0 = dış ring, 1 = iç ring/enklav)
    uint32  pointCount
    pointCount × {
        int32 lon_e6       (derece × 1_000_000)
        int32 lat_e6
    }
```

`int32 × 1e6` yaklaşık 11 cm çözünürlük verir; 100 m sadeleştirme toleransının çok altında.
`float32` yerine tam sayı tercih edildi çünkü davranışı platformdan bağımsız ve deterministiktir.

**İç ring desteği zorunludur.** Türkiye'de enklav durumları vardır (bir ilçenin içinde kalan
başka bir ilçeye ait alan). Ray casting bunları hesaba katmalıdır.

### 5.5 Boyut bütçesi

| Bileşen | Tahmini |
|---|---|
| İl poligonları (81) | ~1.5 MB |
| İlçe poligonları (~970) | ~3 MB |
| Yerleşim noktaları (~35.000) | ~2 MB |
| Vikipedi özetleri (~1.050) | ~1 MB |
| İndeksler + ek | ~1 MB |
| **Toplam** | **~9 MB** |

Sert üst sınır: **20 MB**. Aşılırsa önce sadeleştirme toleransı 150 m'ye çıkarılır,
sonra özet metinleri kısaltılır.

---

## 6. Uygulama mimarisi

### 6.1 Modüller (yerel Swift Package'lar)

```
Waymark/
├── App/                    # SwiftUI App, Coordinator'lar, DI kökü
├── Packages/
│   ├── GeoData/            # SQLite okuma, PIP motoru, mekânsal sorgular
│   ├── LocationEngine/     # CoreLocation sarmalayıcı + durum makinesi
│   ├── TripKit/            # Yolculuk modeli, geçmiş, kalıcılık
│   ├── Presence/           # Live Activity + bildirim yönetimi
│   └── DesignSystem/       # Renk, tipografi, ortak bileşenler
└── tools/
    └── build_pack.py
```

Modül sınırları test edilebilirlik içindir: `GeoData` ve `LocationEngine` UIKit/SwiftUI
bağımlılığı içermez ve saf birim testleriyle doğrulanabilir.

### 6.2 Bağımlılık yönü

```
App → TripKit → LocationEngine → GeoData
App → Presence → TripKit
```

Ters yön bağımlılık yasaktır. `GeoData` hiçbir şeye bağımlı değildir.

### 6.3 Protokol sınırları

Test edilebilirlik için şu üç sınır protokol arkasına alınır:

```swift
public protocol LocationProviding: AnyObject {
    var delegate: LocationProvidingDelegate? { get set }
    func startTracking(configuration: TrackingConfiguration)
    func stopTracking()
    var authorizationStatus: CLAuthorizationStatus { get }
}

public protocol GeoResolving {
    func resolve(coordinate: Coordinate) throws -> PlaceResolution
    func nearestSettlement(to: Coordinate, within meters: Double) throws -> Settlement?
}

public protocol PresencePresenting {
    func startActivity(for trip: Trip) async
    func update(with event: PlaceEvent) async
    func endActivity(summary: TripSummary) async
    func notify(_ event: PlaceEvent) async
}
```

Testlerde her biri fake ile değiştirilir. Böylece durum makinesi CoreLocation olmadan,
tamamen deterministik şekilde test edilir.

### 6.4 MVVM-C uygulaması

- **Coordinator** — navigasyon akışı, ekranlar arası geçiş, deep link. `AppCoordinator`,
  `TripCoordinator`, `HistoryCoordinator`, `SettingsCoordinator`.
- **ViewModel** — `@Observable` (iOS 17 Observation framework), `@MainActor` işaretli.
  İş mantığı yok, servis çağrısı + durum sunumu.
- **View** — SwiftUI, saf sunum, ViewModel dışında bağımlılık yok.
- **Service/Repository** — `TripRepository`, `GeoRepository`, `SettingsStore`.

---

## 7. Konum motoru ve durum makinesi

Bu bölüm uygulamanın kalbidir. Hissiyat buradan gelir.

### 7.1 Konum yapılandırması

```swift
struct TrackingConfiguration {
    var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyHundredMeters
    var distanceFilter: CLLocationDistance = 100
    var allowsBackgroundLocationUpdates = true
    var pausesLocationUpdatesAutomatically = false   // biz yönetiyoruz
    var activityType: CLActivityType = .automotiveNavigation
    var showsBackgroundLocationIndicator = true
}
```

`pausesLocationUpdatesAutomatically = false` bilinçlidir: sistem duraklattığında yeniden
başlatma davranışı öngörülemez ve yolculuk ortasında sessiz kalma riski taşır.
Duraklatma mantığını kendimiz yönetiriz (bkz. 7.5).

`distanceFilter = 100` seçimi rota çizgisi içindir, tespit için 500 m fazlasıyla yeterdi.
GPS radyosu yolculuk boyunca zaten sürekli açık olduğu için geri çağrı sıklığını artırmanın
pil maliyeti ihmal edilebilir — tüketim radyodadır, callback'te değil. 750 km'de ~7.500
çözümleme × 5 ms ≈ 40 saniye CPU, 10 saate yayılmış halde önemsizdir. Buna karşılık 500 m
örnekleme dağ yollarında virajları keser ve rota çizgisi görsel olarak bozulur.

### 7.2 Örnek filtreleme

Bir `CLLocation` şu durumlarda **atılır**:

| Koşul | Eşik |
|---|---|
| Yatay doğruluk kötü | `horizontalAccuracy > 200 m` veya `< 0` |
| Örnek bayat | `timestamp` 30 sn'den eski |
| Fiziksel olarak imkânsız sıçrama | önceki örnekten hız > 60 m/s (216 km/s) |

### 7.3 Durumlar

```swift
enum PresenceState {
    case unknown
    case candidate(place: PlaceRef, since: Date, entryPoint: Coordinate)
    case confirmed(place: PlaceRef, since: Date)
    case exiting(place: PlaceRef, since: Date)
}
```

Her seviye — mevcut her `tier` ve ayrıca yerleşim — **kendi bağımsız durum makinesini**
yürütür. Tier 1 geçişi tier 2 makinesini sıfırlamaz; paralel çalışırlar.
Makine sayısı veriden gelir, koda gömülmez (K6): üç kademeli bir ülke eklendiğinde
üçüncü makine kendiliğinden oluşur.

### 7.4 Geçiş kuralları

```
unknown ──(poligon eşleşti)──────────────► candidate

candidate ──(süre ≥ 60s VEYA mesafe ≥ 2000m)──► confirmed  [OLAY ÜRET]
candidate ──(farklı poligona geçildi)─────────► candidate (yenisiyle)
candidate ──(hiçbir poligonda değil)──────────► unknown

confirmed ──(poligon dışına çıkıldı)──────────► exiting
exiting   ──(sınırdan ≥ 750m uzak VE ≥ 90s)───► unknown → yeni candidate
exiting   ──(poligona geri girildi)───────────► confirmed (olay üretilmez)
```

### 7.5 Parametreler

Tümü `PresenceTuning` struct'ında toplanır, hard-code edilmez. Debug menüsünden değiştirilebilir.

| Parametre | Değer | Gerekçe |
|---|---|---|
| `confirmDwellTime` | 60 sn | Sınıra teğet geçişte yanlış bildirimi önler |
| `confirmDwellDistance` | 2.000 m | Otoyolda hızlı geçişte 60 sn beklemeye gerek kalmaz |
| `exitBufferDistance` | 750 m | Histerezis — sınırda GPS titremesini emer |
| `exitDwellTime` | 90 sn | Aynı |
| `settlementRadius` | 1.500 m | Köy tabelası mesafesi hissiyatı |
| `regionCooldown` | 24 saat | Aynı yerden dönüşte tekrar bildirim yok |
| `maxNotificationsPerHour` | 6 | Güvenlik supabı — mantık hata yapsa bile koruma |
| `staleTripTimeout` | 20 dk | Bu süre boyunca < 3 m/s → yolculuk bitti öner |

**Histerezis kritik.** Giriş ve çıkış eşiklerinin farklı olması zorunludur; eşit olursa
sınır çizgisinde GPS gürültüsü sonsuz giriş-çıkış döngüsü üretir.

### 7.6 Çözümleme algoritması

```
resolve(coordinate):
    1. admin_rtree'den bbox sorgusu, tier=1 filtresi → aday birimler (genelde 1-3)
    2. her aday için geometry blob'unu oku (LRU cache, kapasite 8)
    3. ray casting, iç ringler hariç tutularak
    4. eşleşen tier-1 birimi bulunduysa: parent_id = o birim olan tier-2'lerde aynı işlem
       (tier sayısı veriden gelir — 3. kademeli bir ülke eklenirse döngü uzar, kod değişmez)
    5. settlement_rtree'de settlementRadius yarıçapında haversine ile en yakın nokta
    6. PlaceResolution(administrative: [tier: ref], settlement:) döndür
```

**Performans hedefi:** tek çözümleme < 5 ms (iPhone 12 ve üzeri).
500 m'de bir çağrıldığında CPU maliyeti ihmal edilebilir. Asıl pil tüketimi GPS
radyosundadır ve araç içinde şarj varken kabul edilebilir.

**Geometri cache'i** LRU olmalı: yolculuk boyunca aynı 2-3 poligon tekrar tekrar sorgulanır,
her seferinde SQLite'tan blob okumak gereksizdir.

### 7.7 Rota izi kaydı

Tespit ve iz kaydı **ayrı sorumluluklardır**. Aynı konum akışını tüketirler ama birbirine
bağımlı değildirler; iz kaydı kapatıldığında tespit aynen çalışmaya devam eder.

**Kayıt akışı**

1. Filtreden geçen her konum örneği bellekteki ham tampona yazılır.
2. Tampon her 200 noktada bir diske flush edilir — arka planda sonlandırılma durumunda
   (R4) veri kaybını sınırlar.
3. Yolculuk bittiğinde Douglas-Peucker ile **20 m toleransta** sadeleştirilir ve kalıcı
   hale getirilir. Ham tampon silinir.
4. Depolama biçimi: Bölüm 5.4'teki `int32 × 1e6` kodlaması, tek `Data` blob.

> **SwiftData'da her nokta ayrı model nesnesi olarak saklanmayacak.** 1.500 nesnelik ilişki
> hem yazma hem okuma tarafında performansı yok eder. Tek blob, tek attribute.

**Boşluk yönetimi**

Tünel ve şebekesiz bölgelerde konum akışı kesilir. İki ardışık nokta arasında **> 2 km**
veya **> 5 dakika** fark varsa segment kesilir ve yeni segment başlatılır.

Rota `[[Coordinate]]` — yani segment dizisi — olarak saklanır ve çizilir. Boşluklar ya hiç
çizilmez ya da soluk kesikli çizgiyle gösterilir. Bolu tünelinde 30 km'lik düz çizgi çizmek
hem yanlış hem de kalitesiz görünür.

**Uç nokta gizliliği**

Bu, özelliğin en önemli tasarım detayıdır. Paylaşılan bir rota görseli, yolculuğun başladığı
evi ifşa eder. Sosyal medyada paylaşılan bir görselden ev adresi çıkarmak, gerçek bir
doxxing vektörüdür ve benzer uygulamalarda somut olarak yaşanmıştır.

- Paylaşım görselinde rotanın **ilk ve son 1.000 m'si varsayılan olarak kırpılır**.
- Kullanıcı kırpma mesafesini `0 / 500 m / 1 km / 2 km` olarak ayarlayabilir.
- Kırpma yalnızca **paylaşıma** uygulanır; kullanıcı kendi geçmişinde tam rotayı görür.
- Paylaşım ekranında kırpmanın aktif olduğu görsel olarak belirtilir ("Başlangıç ve bitiş
  gizlendi") — kullanıcı korumadan haberdar olmalı ki güvensin.

**Kullanıcı kontrolü**

- Ayarlarda "Rota izini kaydet" anahtarı. Varsayılan: **açık**.
- Kapatıldığında yalnızca olaylar ve toplam mesafe saklanır.
- Yolculuk detayında "Rotayı sil" — yolculuğun kendisini silmeden yalnızca izi kaldırır.
- Geçmiş silindiğinde iz de silinir, artık kalmaz.

**Render**

| Bağlam | Yöntem |
|---|---|
| Uygulama içi harita | MapKit SwiftUI `MapPolyline`, segment başına bir polyline |
| Paylaşım görseli | `MKMapSnapshotter` + Core Graphics ile polyline çizimi |

`ImageRenderer` içinde SwiftUI `Map` kullanma — snapshot davranışı güvenilir değil, harita
karoları çoğu zaman boş render edilir. `MKMapSnapshotter` bu iş için tasarlanmış API'dir;
snapshot alındıktan sonra koordinatlar `snapshot.point(for:)` ile piksel uzayına çevrilip
polyline `CGContext` üzerine çizilir.

**Boyut**

750 km rota, 100 m örnekleme → ~7.500 ham nokta. 20 m toleransta sadeleştirme sonrası
~1.500 nokta × 8 bayt ≈ **12 KB**. 1.000 yolculuk ≈ 12 MB. Kaygı verici bir rakam değil,
ama geçmiş kalıcılığı politikası (Bölüm 17, madde 5) yine de kararlaştırılmalı.

---

## 8. Bildirim ve Live Activity politikası

İ3'ün somut karşılığı. Bu tablo ürünün karakterini belirler.

### 8.1 Olay → yüzey matrisi

| Olay | Live Activity | Zaman çizelgesi | Push bildirim |
|---|---|---|---|
| Tier 1 değişimi (il) | ✅ güncellenir | ✅ | ✅ her zaman |
| Tier 2 değişimi (ilçe) | ✅ güncellenir | ✅ | Yalnızca hassasiyet ≥ tier 2 |
| Yerleşim girişi | ✅ güncellenir | ✅ | Yalnızca hassasiyet = köy |
| Landmark yakınlığı (v2) | ✅ | ✅ | ❌ asla |

**Varsayılan hassasiyet: tier 1 (Türkiye'de il).** Kullanıcı ilk yolculukta 4-5 bildirim alır, 40 değil.
Ayarlarda seviyeyi yükseltebilir; yükseltirken beklenen bildirim sayısı hakkında
uyarı gösterilir ("İlçe seviyesinde İstanbul–Ordu yolculuğunda ~35 bildirim alırsınız").

### 8.2 Live Activity içeriği

**Kilit ekranı (genişletilmiş):**
- Büyük: mevcut yerleşim veya ilçe adı
- Alt satır: `İlçe, İl` hiyerarşisi
- Sağ: nüfus rozeti
- Alt şerit: bu yolculukta geçilen il/ilçe sayısı

**Dynamic Island:**
- Compact leading: küçük ikon
- Compact trailing: ilçe adı (kısaltılmış)
- Expanded: kilit ekranının küçültülmüş hali
- Minimal: ikon

**Güncelleme sıklığı:** ActivityKit'in bütçesi sınırlıdır. Yerleşim seviyesinde her geçişte
güncelleme yapmak bütçeyi tüketebilir. Bu yüzden Live Activity güncellemeleri
**en fazla 60 saniyede bir** yapılır; bu aralıkta biriken olaylar tek güncellemede birleştirilir.

### 8.3 Bildirim biçimi

```
Başlık:  Merzifon'dasın
Gövde:   Amasya · 52.000 nüfus
Thread:  trip-{tripID}          → aynı yolculuğun bildirimleri gruplanır
```

Bildirime dokunulduğunda ilgili yerin detay ekranı açılır (deep link).

### 8.4 Sessiz saatler

Kullanıcı 23:00–07:00 arası bildirim almak istemeyebilir. Bu aralıkta Live Activity
güncellenmeye devam eder ama push gönderilmez. Varsayılan: kapalı (kullanıcı açar).

---

## 9. Veri modelleri

```swift
public struct Coordinate: Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double
}

public enum PlaceKind: Int, Sendable {
    case administrative     // tier ile ayrışır (K6)
    case settlement
}

/// İdari kademe. 1 = Türkiye'de il, 2 = ilçe. Etiket veriden gelir, koda gömülmez.
public struct Tier: RawRepresentable, Hashable, Sendable {
    public let rawValue: Int
    public static let first  = Tier(rawValue: 1)
    public static let second = Tier(rawValue: 2)
}

public struct PlaceRef: Hashable, Sendable {
    public let kind: PlaceKind
    public let tier: Tier?          // settlement için nil
    public let id: Int
}

public struct Place: Identifiable, Sendable {
    public let ref: PlaceRef
    public let nameLocal: String            // 'Merzifon' — her zaman gösterilir
    public let nameLocalized: String?       // kullanıcı dilinde, varsa
    public let tierLabel: String            // 'İlçe' / 'District' — veriden
    public let parentName: String?          // 'Amasya'
    public let population: Int?
    public let populationYear: Int?
    public let areaKm2: Double?
    public let elevationM: Int?
    public let article: Article?            // dil geri düşüşü uygulanmış
    public let centroid: Coordinate
}

public struct Article: Sendable {
    public let summary: String
    public let language: String             // 'tr' | 'en'
    public let sourceURL: URL
}

public struct PlaceResolution: Sendable {
    /// tier -> eşleşen birim. v1'de 1 ve 2 anahtarları dolar.
    public let administrative: [Tier: PlaceRef]
    public let settlement: PlaceRef?
    public let settlementDistance: CLLocationDistance?
}

public struct PlaceEvent: Identifiable, Sendable {
    public let id: UUID
    public let place: PlaceRef
    public let enteredAt: Date
    public let coordinate: Coordinate
}

public struct RouteSegment: Sendable {
    public let points: [Coordinate]
    public let startedAt: Date
    public let endedAt: Date
}

public struct RouteTrace: Sendable {
    public let segments: [RouteSegment]      // boşluklar segmentleri ayırır
    public var pointCount: Int { segments.reduce(0) { $0 + $1.points.count } }

    /// Paylaşım için uç noktaları kırpılmış kopya döndürür (bkz. 7.7)
    public func trimmed(by meters: CLLocationDistance) -> RouteTrace
}

public struct Trip: Identifiable, Sendable {
    public let id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var events: [PlaceEvent]
    public var distanceMeters: Double
    public var title: String?            // "İstanbul → Ordu"
    public var route: RouteTrace?        // iz kaydı kapalıysa nil
}

public struct TripSummary: Sendable {
    public let provinceCount: Int
    public let districtCount: Int
    public let settlementCount: Int
    public let distanceMeters: Double
    public let duration: TimeInterval
    public let highlights: [Place]       // en büyük / en küçük / en yüksek rakımlı
}
```

**Kalıcılık:** SwiftData (iOS 17+). Yolculuk geçmişi cihazda kalır; CloudKit senkronizasyonu
v2'de değerlendirilir.

Rota izi, `Trip` modelinde tek bir `Data` attribute'u olarak saklanır (Bölüm 5.4 kodlaması,
segment sınırları dahil). Nokta başına model nesnesi oluşturulmaz.
`Trip.title` ilk ve son ilden otomatik üretilir; kullanıcı düzenleyebilir.

---

## 10. Ekranlar

| Ekran | İçerik |
|---|---|
| **Ana ekran** | Büyük "Yolculuğa Başla" butonu, mevcut konum kartı, son yolculuklar |
| **Aktif yolculuk** | Şu anki yer (büyük), canlı rota çizgisi haritada, geçilenler listesi (ters kronolojik), "Bitir" |
| **Yer detayı** | Ad, hiyerarşi, nüfus, yüzölçümü, rakım, tarihçe metni, kaynak linki, haritada konum |
| **Yolculuk özeti** | Rota haritası, istatistikler, geçilen yerler zaman çizelgesi, paylaş butonu |
| **Paylaşım önizleme** | Oluşturulan görsel, kırpma mesafesi kontrolü, "Başlangıç ve bitiş gizlendi" rozeti |
| **Geçmiş** | Tüm yolculuklar listesi, her satırda küçük rota önizlemesi |
| **Ayarlar** | Hassasiyet, rota izi anahtarı, kırpma mesafesi, sessiz saatler, izinler, atıf, debug menüsü |

**Debug menüsü** (yalnızca DEBUG build): `PresenceTuning` parametrelerini canlı değiştirme,
sahte konum enjekte etme, durum makinesi mevcut durumunu görüntüleme, GPX oynatma.
Bu menü geliştirme hızının en büyük belirleyicisidir, baştan yazılmalıdır.

---

## 11. İzinler ve Info.plist

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Yolculuğunuz sırasında hangi il ve ilçelerden geçtiğinizi gösterebilmek için konumunuza ihtiyaç duyuyoruz.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Uygulama arka plandayken de yeni bir şehre veya ilçeye girdiğinizde sizi bilgilendirebilmemiz için konumunuza ihtiyaç duyuyoruz. Konum bilginiz cihazınızdan hiçbir yere gönderilmez.</string>

<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>

<key>NSSupportsLiveActivities</key>
<true/>
```

Bu metinler `InfoPlist.xcstrings` üzerinden hem İngilizce hem Türkçe sağlanır.
Yukarıdakiler Türkçe sürümdür; İngilizce base metin de yazılmalıdır.

### İzin akışı

1. İlk açılışta izin **istenmez**. Önce uygulama tanıtılır.
2. Kullanıcı "Yolculuğa Başla" dediğinde önce `whenInUse` istenir.
3. `whenInUse` ile uygulama **çalışır** — ön planda tam işlevlidir.
4. İlk yolculuk sırasında, ekran kapandığında değer kaybı yaşanacağı açıklanarak
   `always` yükseltmesi istenir.

Bu kademeli akış hem dönüşüm oranını artırır hem de App Store incelemesinde
"neden always gerekiyor" sorusuna somut cevap üretir.

### Gizlilik

- `PrivacyInfo.xcprivacy` dosyası zorunludur.
- `NSPrivacyCollectedDataTypes`: **boş** — hiçbir veri toplanmıyor.
- `NSPrivacyAccessedAPITypes`: `UserDefaults` (sebep kodu `CA92.1`).
- Analitik eklenirse: yalnızca olay sayacı, asla koordinat.

---

## 11.5 Lokalizasyon

**v1 dilleri:** İngilizce (base, geliştirme dili) + Türkçe.

| Konu | Kural |
|---|---|
| Arayüz metinleri | `Localizable.xcstrings`, base `en`. Hiçbir metin koda gömülmez |
| İzin metinleri | `InfoPlist.xcstrings` |
| Kademe etiketleri | Koda gömülmez — `tier_label` tablosundan gelir (K6) |
| Yer adları | Yerel ad her zaman gösterilir; kullanıcı dilindeki ad ikincil |
| Tarihçe dili | `kullanıcı dili → en → gizle` (İ4) |
| Sayı biçimlendirme | `NumberFormatter`, asla elle string birleştirme |
| Tarih/süre | `Date.FormatStyle`, `Duration.UnitsFormatStyle` |

**Şimdiden uyulacak, sonra pahalıya patlayacak alışkanlıklar:**

- Layout'ta `.leading` / `.trailing` kullan, asla `.left` / `.right`.
  Arapça v3'te geliyor; RTL'e hazır yazmak bugün sıfır maliyetli.
- Dynamic Island etiket genişliğini en uzun Türkçe ilçe adıyla test et
  (`Şereflikoçhisar`, `Aşağıpınarbaşı`). CJK v3'te daha da daraltacak.
- Türkçe metin işlemlerinde **her zaman** `Locale(identifier: "tr_TR")` ver.
  `"İSTANBUL".lowercased()` varsayılan locale'de yanlış sonuç üretir (R6).
- Pseudo-localization ile test et: uzun metin şişmesini erken yakalar.

---

## 12. Test stratejisi

### 12.1 Birim testleri

| Alan | Kapsam |
|---|---|
| Ray casting | Bilinen noktalar, sınır üstü noktalar, enklav (iç ring) senaryosu, antimeridian yok ama kutup yok kontrolü |
| Binary decoder | Bozuk blob, sıfır ring, tek nokta ring — hepsi crash etmeden hata döndürmeli |
| Durum makinesi | Sentetik konum akışları, CoreLocation olmadan |
| Örnek filtreleme | Kötü doğruluk, bayat timestamp, imkânsız sıçrama |
| Cooldown / rate limit | Zaman kontrolü enjekte edilebilir `Clock` ile |
| Rota sadeleştirme | Douglas-Peucker doğruluğu, uç noktaların korunması, tek noktalı iz |
| Segment kesme | 2 km / 5 dk eşikleri, arka arkaya boşluk, iz başında ve sonunda boşluk |
| Uç nokta kırpma | Kırpma mesafesi rota uzunluğunu aşarsa boş sonuç, negatif değer reddi |

### 12.2 Replay harness (kritik)

GPX dosyasını okuyup `LocationEngine`'e besleyerek üretilen olay dizisini doğrulayan
bir test altyapısı yazılır:

```swift
func testIstanbulToOrduProducesExpectedProvinceSequence() throws {
    let engine = PresenceEngine(resolver: realResolver, tuning: .default)
    let events = GPXReplayer(file: "istanbul-ordu.gpx").replay(into: engine)
    let provinces = events.filter { $0.kind == .province }.map(\.placeName)

    XCTAssertEqual(provinces, [
        "İstanbul", "Kocaeli", "Sakarya", "Düzce", "Bolu",
        "Çankırı", "Çorum", "Amasya", "Tokat", "Ordu"
    ])
}
```

Bu test regresyonlara karşı en güçlü kalkandır. Parametre değiştirdiğinde ne bozulduğunu
anında gösterir. **Kod yazmadan önce GPX rotaları hazırlanmalıdır.**

### 12.3 Gerekli GPX rotaları

| Dosya | Amaç |
|---|---|
| `istanbul-ordu.gpx` | Ana senaryo, uzun mesafe |
| `boundary-oscillation.gpx` | Sınır boyunca ilerleyen rota — histerezisi test eder |
| `village-cluster.gpx` | Köylerin yoğun olduğu bölge — bildirim sıklığı testi |
| `urban-slow.gpx` | Şehir içi düşük hız — yanlış tetikleme testi |
| `poor-signal.gpx` | Konum boşlukları içeren rota — kesinti dayanıklılığı |

### 12.4 Saha testi

Simülatör her şeyi göstermez. En az bir gerçek yolculukta:
- Pil tüketim yüzdesi ölçülür (hedef: saatte < %8, ekran kapalı)
- Bildirim sayısı ve zamanlaması not edilir
- Şebeke kesintisi bölgelerinde davranış gözlenir

---

## 13. Performans ve pil bütçesi

| Metrik | Hedef |
|---|---|
| Tek çözümleme süresi | < 5 ms |
| Uygulama açılış süresi (cold) | < 800 ms |
| Bundle boyutu (veri dahil) | < 40 MB |
| Bellek (aktif yolculuk) | < 60 MB |
| Pil (ekran kapalı, aktif yolculuk) | saatte < %8 |
| Live Activity güncelleme aralığı | ≥ 60 sn |
| Rota izi boyutu (750 km yolculuk) | < 20 KB |
| Paylaşım görseli üretimi | < 2 sn |
| Geçmiş listesi kaydırma | 60 fps — rota önizlemeleri önbelleğe alınmalı |

Pil ölçümü Xcode Energy Log ve Instruments Location Energy şablonuyla yapılır.

---

## 14. Riskler

| # | Risk | Etki | Azaltma |
|---|---|---|---|
| ~~R1~~ | ~~OSM'de ilçe relation'ları eksik olabilir~~ | **KAPANDI** | F0'da doğrulandı: eksik yok, 1041 kayıt bulundu (973 hedef + komşu ülkeler). Bkz. 5.2 |
| **R1b** | Ülke filtresi hatalı kurulursa komşu ülke ilçeleri veriye sızar | Orta | Çift yöntemli filtre + sayı doğrulaması (81/973), pipeline'da sert kontrol |
| R2 | Bildirim sıklığı kullanıcıyı rahatsız eder | Yüksek | Varsayılan il seviyesi, Live Activity birincil, rate limit |
| R3 | `always` konum izni App Store incelemesinde takılır | Orta | Kademeli izin akışı, inceleme notlarına ekran videosu |
| R4 | Arka planda uygulamanın sistem tarafından sonlandırılması | Orta | `pausesLocationUpdatesAutomatically = false`, durum kalıcılığı, yeniden başlatmada kurtarma |
| R5 | Vikipedi özetleri bazı ilçeler için yok veya alakasız | Düşük | İ4 — boş bırak, kart gizlensin |
| R6 | Türkçe ad eşleştirmesinde `İ`/`ı` kaynaklı hatalar | Düşük | Normalizasyonda `Locale(identifier: "tr_TR")` kullan, testle doğrula |
| R7 | Bundle boyutu sınırı aşar | Düşük | Tolerans artır, özet kısalt |
| **R8** | Paylaşılan rota görselinden ev adresi tespit edilir | **Yüksek** | Varsayılan 1 km uç kırpma, kullanıcıya görünür rozet (7.7) |
| R9 | Tünel/şebekesiz bölgede rota düz çizgiyle atlanır, kalitesiz görünür | Orta | Segment kesme eşikleri, boşlukların çizilmemesi (7.7) |
| R10 | Geçmiş listesinde rota önizlemeleri kaydırmayı yavaşlatır | Orta | Önizleme görsellerini üret-ve-önbellekle, listede canlı harita kullanma |
| **R11** | v3'te tartışmalı sınırlar (Kıbrıs, Kırım, Keşmir, Tayvan, Batı Sahra) siyasi iddia üretir; ülke bazlı kaldırma riski | **Yüksek — v3** | Veri setlerindeki `disputed` bayrağını taşı; bu bölgelerde ülke adı söyleme, yalnızca coğrafi ad göster. Karar v2'de verilmeli |
| R12 | v1 şeması Türkiye'ye özelleşirse v2/v3'te F1–F5 baştan yazılır | Yüksek | K6, K7, K8 — bugün alınan sıfır maliyetli önlemler |
| R13 | İngilizce Vikipedi kapsaması Türkçe'nin çok altında; EN arayüzde içerik boş görünür | Orta | İ4 gereği kart gizlenir. Pipeline kapsama oranını raporlar; %40'ın altındaysa EN içerik stratejisi gözden geçirilir |

---

## 15. Uygulama sırası

### Adım 0 — Fizibilite doğrulaması ✅ TAMAMLANDI

Sonuçlar ve doğurduğu zorunluluklar Bölüm 5.2'dedir. Özet: OSM verisi yeterli,
plan B'ye gerek yok, ülke filtresi eklendi.

*(Aşağıdaki orijinal kontrol listesi referans olarak korunmuştur.)*

1. Geofabrik'ten `turkey-latest.osm.pbf` indir.
2. `admin_level=4` ve `admin_level=6` relation'larını çıkar, say.
3. **81 il var mı? Her ilin ilçe sayısı TÜİK ile uyuşuyor mu?**
4. Rastgele 10 ilçe seç, sınırlarını görsel olarak doğrula (QGIS veya geojson.io).
5. Sadeleştirme sonrası boyutu ölç.
6. Rapor: eksik/hatalı olan idari birimler listesi.

R1 gerçekleşirse (ilçe verisi yetersizse) proje mimarisi değişir. Bunu üç ay sonra
öğrenmek istemezsin.

### Fazlar

| Faz | İçerik | Çıktı |
|---|---|---|
| ~~F0~~ | ~~Fizibilite doğrulaması~~ | **TAMAM** — OSM yeterli (5.2) |
| ~~F1~~ | ~~`tools/build_pack.py` pipeline (bölge-agnostik)~~ | **TAMAM** — gerçek `tr.pack` üretildi (81 il, 970 ilçe, 44k yerleşim, nüfus + Vikipedi %100, 7.5 MB) |
| ~~F2~~ | ~~`GeoData` paketi: SQLite okuma, decoder, PIP motoru~~ | **TAMAM** — 35 test geçen paket |
| ~~F3~~ | ~~`LocationEngine`: durum makinesi + GPX replay harness~~ | **KISMEN** — 39 test yeşil; `istanbul-ordu` iskeleti gerçek veri bekliyor |
| ~~F4~~ | ~~`Presence`: Live Activity + bildirimler~~ | **KISMEN** — 37 test yeşil; widget UI + cihaz doğrulaması kaldı |
| ~~F5~~ | ~~Rota izi motoru (sadeleştirme, segment, kırpma)~~ | **TAMAM** — `TripKit`, 33 test geçen saf Swift modül |
| ~~F6~~ | ~~`TripKit` + ana ekranlar (SwiftUI, MVVM-C)~~ | **TAMAM** — simülatörde uçtan uca çalışıyor, 7 ekran + debug menüsü |
| ~~F7~~ | ~~Harita çizimi, yolculuk özeti, paylaşım görseli~~ | **TAMAM** — `MKMapSnapshotter` paylaşım görseli + önizleme önbelleği simülatörde doğrulandı |
| ~~F8~~ | ~~Debug menüsü, ayarlar, atıf ekranı, gizlilik dosyası~~ | **TAMAM** — privacy manifest, Widget Extension, App Store taslağı; app + widget Release derleniyor |
| **F9** | Saha testi, parametre ayarı, App Store | v1.0 |

F2 ve F3 projenin en riskli ve en değerli kısımlarıdır. Zamanın çoğu oraya ayrılmalıdır.
UI kısmı (F5–F6) görece rutindir.

**F1 durumu (2026-09-02):** `tools/build_pack.py` pipeline iskeleti yazıldı —
bölge-agnostik config (`tools/config/tr.toml`), tam şema (5.3), poligon binary
encoder/decoder (5.4), iki kademeli ülke filtresi, doğrulama, Wikipedia/Wikidata/TÜİK
okuma katmanları, deterministik `build_hash`, rapor üretimi ve sentetik `tr.pack`
fixture üretici. 51 pytest testi geçiyor. Gerçek girdiler (Geofabrik PBF, TÜİK CSV,
Wikidata JSON) henüz işlenmedi — `tools/README.md` temin yolunu açıklar. Fixture
pack F2'nin `GeoData` testlerinde kullanılacak.

**F2 durumu (2026-09-02):** `Packages/GeoData` yerel SPM paketi — GRDB bağımlılığı,
Xcode projesine `XCLocalSwiftPackageReference` ile bağlandı (app derleniyor).
İçerik: `PolygonDecoder` (5.4, `polygon.py` ile birebir bayt sözleşmesi, bozuk blob'da
`throws`), iç-ring destekli `PointInPolygon` ray casting (7.6, enklav), `Haversine`,
kapasite-8 LRU `GeometryCache`, `GeoResolving` + `PlaceRepository` uygulayan
`SQLiteGeoResolver` (7.6 algoritması: R\*Tree bbox → PIP → en yakın yerleşim; kademe
sayısı `tier_label`'dan, koda gömülü değil). Dil geri düşüş zinciri (`dil → en → yok`,
İ4/11.5) uygulandı. `Sendable`, thread-safe. Swift Testing ile 35 test 4 suite'te
geçiyor (`swift test`), sentetik `tr.pack` fixture'ına karşı — enklav noktasının C2'ye
çözülmesi dahil. Not: `SQLiteGeoResolver` iOS/macOS'ta çalışıyor; `Mutex` yerine
`NSLock` kullanıldı (paket tabanı iOS 17).

**F3 durumu (2026-09-02):** `Packages/LocationEngine` yerel SPM paketi (GeoData'ya
bağımlı), Xcode projesine bağlandı, app derleniyor. İçerik: `SampleFilter` (7.2 —
doğruluk/bayatlık/imkânsız sıçrama, sıra dışı örnek), `PresenceMachine` (7.3–7.4 tam
geçiş tablosu: unknown→candidate→confirmed→exiting, histerezis, enklav re-entry),
`PresenceEngine` (7.2→7.6 zinciri: filtre → çözümle → her kademe + yerleşim için paralel
bağımsız makine; makine sayısı `tier_label`'dan türüyor, koda gömülü değil — K6),
`PresenceTuning` (7.5 tüm parametreler tek struct), enjekte edilebilir `TimeSource`
(`MutableTimeSource` replay için), `LocationProviding`/`LocationProvidingDelegate` seam
+ `TrackingConfiguration` (7.1) + `CoreLocationProvider` (üretim CL sarmalayıcı,
test edilmiyor), `GPXReplayer` (12.2 replay harness — GPX parse + motora besleme,
debug menüsü GPX oynatması için de kullanılır). Zamanlama örnek zaman damgasından ölçülür
(replay ms'de deterministik çalışır). 39 Swift Testing testi 5 suite'te geçiyor
(`swift test`). **`ReplayRouteTests` devre dışı iskelet** — spec 12.2 `istanbul-ordu`
il dizisi + 12.3'ün beş rotası; gerçek kayıtlı GPX izleri ve gerçek `tr.pack` bekliyor
(F1/F2 ile aynı durum). Sentetik GPX fixture'ları (A→B geçişi, sınır salınımı) aynı
kabloyu bugün fixture pack'e karşı kanıtlıyor.

**F5 durumu (2026-09-03):** `Packages/TripKit` yerel SPM paketi (yalnızca GeoData'ya
bağımlı — `Coordinate`/`Haversine`; `LocationEngine` kenarı F6'da eklenecek), Xcode
projesine bağlandı (4 paket, app derleniyor). Bölüm 7.7 saf Swift olarak:
`RouteRecorder` (bellek tamponu, 200 noktada flush sinyali, 2 km / 5 dk segment kesme,
sıra dışı zaman damgası da keser, `finish()` her segmenti 20 m'de sadeleştirir,
`snapshot()` canlı çizim için açık segmenti dahil eder), `DouglasPeucker` (20 m,
uç noktalar korunur, ekvatoral projeksiyonla metrik dik mesafe), `RouteTrimmer` +
`RouteTrace.trimmed(by:)` (paylaşım için uç kırpma — R8; `meters ≤ 0` no-op, rota
uzunluğunu aşarsa boş, segment boşlukları korunur), `RouteBlob` (tek `Data`: spec 5.4
`int32 × 1e6` koordinat kodlaması + segment sınırları + int64 ms zaman damgaları;
bozuk blob'da `throws`). 33 Swift Testing testi 4 suite'te geçiyor. SwiftData kalıcılığı
ve `Trip`/`TripSummary` F6'da (`TripKit` bu paketi genişletecek).

**F4 durumu (2026-09-03):** `Packages/Presence` yerel SPM paketi (GeoData + LocationEngine
+ TripKit'e bağımlı — TripKit'e `Trip`/`TripSummary` değer tipleri eklendi, LocationEngine
kenarı aktifleşti). Xcode projesi artık 5 paket link ediyor, app derleniyor (iOS).
Bölüm 8 routing/gating mantığı saf ve test edilmiş: `PresencePolicy` (8.1 matrisi —
`NotificationSensitivity`, varsayılan `.tier1`; tier-1 her zaman push, tier-2 hassasiyet
≥ tier2, yerleşim yalnız `.settlement`; push rank'i `tier.rawValue`'dan türüyor, K6 uyumlu),
`NotificationGate` (7.5/8.4 — yer başına 24 saat cooldown, kayan saatte ≤ 6 push tavanı,
sessiz saatler — gece yarısını saran ve sarmayan; bastırılan push bütçe tüketmez),
`UpdateCoalescer` (8.2 — 60 sn'de bir Live Activity, ilk olay hemen, aradakiler birleşir),
`NotificationCopy` (8.3 — "Merzifon'dasın" · "Amasya · 52.000 nüfus"; Türkçe locative
ünlü uyumu + sert ünsüz kuralı, R6; enjekte edilebilir protokol, F8 xcstrings ile değişir),
`PresenceCoordinator` (`actor`, `PresencePresenting` uygular — 6.3 seam; yolculuk döngüsü
`startActivity`→`update`→`endActivity`, enjekte `TimeSource`). Gerçek yüzey sarmalayıcıları
var ama test edilmiyor: `UserNotificationSurface` (UN), `LiveActivitySurface` +
`WaymarkActivityAttributes` (ActivityKit, `#if os(iOS)`). **Kaldı (F6–F8):** Live Activity
**widget UI** (kilit ekranı + 4 Dynamic Island durumu — Widget Extension target gerekir),
`NSSupportsLiveActivities` Info.plist, bildirim izin akışı, cihazda gerçek bildirim
doğrulaması. 37 Swift Testing testi 6 suite'te geçiyor.

**F6 durumu (2026-09-03):** Uçtan uca çalışan uygulama — iOS 27 simülatöründe doğrulandı
(Ana ekran → Aktif yolculuk → Yolculuk özeti → Geçmiş akışı ekran görüntüleriyle test
edildi; SimulatedLocationProvider demo rotası fixture geometrisi üzerinden
İlçe C1 → Test İli A → Test İli B → İlçe D1 dizisini üretti, TripKit'e kalıcı yazıldı).
- **P8 — TripKit kalıcılık:** SwiftData `TripRecord` (`@Model`, rota tek `Data` blob,
  olaylar JSON blob — 7.7/§9), `TripStore` (@MainActor CRUD + R4 `unfinishedTrip()`
  kurtarma), `RouteTracePreference`, `TripSummary.make` (öne çıkanlar: en büyük/küçük/
  yüksek), `Trip.autoTitle` ("İstanbul → Ordu"). TripKit 49 test.
- **P10 — 5. paket `DesignSystem`** (token'lar + `Card`/`PrimaryButton`/`StatTile`/
  `EmptyStateView`) + **6. paket** ile Xcode 6 yerel SPM paketi.
- **Uygulama hedefi:** DI kökü `AppEnvironment`, SwiftUI-native MVVM-C (`AppModel`
  @Observable coordinator + tab başına `NavigationStack` path + tipli `AppRoute`),
  servisler (`SettingsStore` @Observable/UserDefaults, `LiveTripController` —
  LocationEngine + Presence + TripKit entegrasyonu, `SimulatedLocationProvider` —
  simülatör/debug için enjekte edilebilir `MutableTimeSource`'lu sahte sağlayıcı).
- **7 ekran (§10):** Ana ekran, Aktif yolculuk (canlı `MapPolyline` + geçilenler),
  Yer detayı (İ4 — içerik yoksa kart gizli), Yolculuk özeti (istatistik + öne çıkanlar +
  zaman çizelgesi), Paylaşım önizleme (kırpma kontrolü + "Başlangıç ve bitiş gizlendi"
  rozeti; `Canvas` polyline — `ImageRenderer`+`Map` boş render eder, 7.7; **gerçek
  `MKMapSnapshotter` görseli F7/P9**), Geçmiş (kaydır-sil + toplu sil + GPX export —
  17.6), Ayarlar (hassasiyet + bildirim uyarısı, rota izi, sessiz saatler, izinler,
  atıf — Ek A), + **Debug menüsü** (DEBUG: canlı `PresenceTuning`, sahte konum, GPX
  oynatma, makine durumu).
- `Localizable.xcstrings` (en base + ~55 tr çeviri), `NSLocation*UsageDescription` +
  `UIBackgroundModes: location` + `NSSupportsLiveActivities` Info.plist anahtarları.
- **Kaldı:** Live Activity widget UI (Widget Extension target — F8), gerçek `tr.pack`
  (F1 — şu an fixture bundle'da), saha testi (F9).

**F7 durumu (2026-09-03):** Harita + paylaşım görseli, iOS 27 simülatöründe doğrulandı
(demo rota → özet → Paylaş → iOS paylaş sayfası önizlemesinde gerçek `MKMapSnapshotter`
görseli: harita + mavi polyline + istatistik kutusu "242,8 km · 2 provinces · 2 districts
· 2 hr, 35 min" + "Start and end hidden" rozeti).
- **`ShareImageRenderer`** (uygulama hedefi, `waymark/Services`): `MKMapSnapshotter`
  options (rota bbox × 1.4, `.excludingAll` POI, light trait) → `async start()` →
  `UIGraphicsImageRenderer` ile `snapshot.image` üzerine `snapshot.point(for:)` ile
  polyline (segment başına), Core Graphics ile istatistik kutusu ve kırpma rozeti.
  `ImageRenderer`+`Map` KULLANILMADI (boş karo — 7.7).
- **`RoutePreviewCache`** (R10): `NSCache<NSString, UIImage>` (cap 200), Core Graphics
  ile çevrimdışı rota eskizi (uniform ölçek, degenerate düz rota için min span). Geçmiş
  satırlarında `RoutePreviewThumbnail`, canlı harita yok.
- `SharePreviewView` yeniden yazıldı: ekranda anlık `RouteSketch` (Canvas) önizleme +
  `.task(id: trimMeters)` ile `ShareImageRenderer` async render → `ShareLink(item: Image)`.
  Trim değişince görsel yeniden üretilir. Çevrimdışı hata durumu ele alınıyor.
- `TripKit.TripStore.finishTrip` `startedAt:` opsiyonel parametresi aldı — `LiveTripController`
  yolculuk süresini ilk/son fix zaman damgasından hesaplıyor (simüle zamanda "0 min"
  hatasını düzeltir; gerçek sağlayıcıda duvar saati = gerçek zaman). TripKit 49 test.
- `StatTile` sığmama düzeltmesi (`minimumScaleFactor`). `SimulatedLocationProvider` demo
  rotası: hafif sinüs dalgası + 1.1 km fix aralığı (segment kesme eşiğinin altında).
- **Kaldı:** gerçek `tr.pack` (F1), saha testi (F9).

**F8 durumu (2026-09-03):** Yayın hazırlığı. App + Widget Extension iOS 27'de Debug
ve Release derleniyor.
- **`WaymarkWidgets` Widget Extension target** (pbxproj elle eklendi — yeni
  `PBXNativeTarget` + `com.apple.product-type.app-extension`, embed phase, target
  dependency, `Presence`+`DesignSystem` paket bağımlılıkları, `Info.plist` istisna seti).
  `WaymarkWidgetsBundle` (`WidgetBundle`) + `TripLiveActivity`
  (`ActivityConfiguration<WaymarkActivityAttributes>`): kilit ekranı görünümü + 4
  Dynamic Island durumu (compact leading/trailing, expanded 3 bölge, minimal).
  `PlugIns/WaymarkWidgets.appex` app'e gömülüyor, `NSExtension` =
  `com.apple.widgetkit-extension`, bundle id `tr.com.yakupad.waymark.WaymarkWidgets`.
  **Not:** Live Activity'nin canlı görüntüsü simülatörde güvenilir değil (F9 cihaz
  doğrulaması); `Activity.request` çökme olmadan çağrılıyor.
- **`PrivacyInfo.xcprivacy`** (spec 11): `NSPrivacyTracking=false`,
  `NSPrivacyCollectedDataTypes` boş, tek erişilen API `UserDefaults` (`CA92.1`).
  App bundle'ında.
- **`InfoPlist.xcstrings`**: `NSLocation*UsageDescription` en + tr (spec 11 metinleri).
  `tr.lproj/InfoPlist.strings` derleniyor.
- **`docs/app-store.md`**: ad/altbaşlık/açıklama (en+tr), gizlilik etiketi, anahtar
  kelimeler, **App Review notları** ("neden Always konum", arka plan modları, çevrimdışı
  çekirdek, demo rota).
- Atıf ekranı (`AboutView`, F6) — OSM ODbL, TÜİK, Vikipedi CC BY-SA + lisans linki (Ek A).
- **Kaldı (F9):** cihazda Live Activity + bildirim akışı doğrulaması, pil/parametre
  saha ayarı, App Store gönderimi.

**F9 durumu (2026-09-03):**
- **Gerçek `tr.pack` üretildi ve app'e gömüldü.** 644 MB Geofabrik PBF işlendi. F1
  pipeline bug'ları düzeltildi (`extract.py`: `osmium export` id vermiyordu →
  `--add-unique-id=type_id`; adalar `admin_level=6` → `boundary=administrative`+isim
  filtresi). Yeni `wikidata_fetch.py` (`wbgetentities` batch → P1082 nüfus + sitelink
  başlıkları + en label, disk cache). `content.py` yeniden yazıldı: throttle + 429
  retry + disk cache → Vikipedi kapsaması %8'den **%100'e** (tr 1046/1051, en 1047).
  `count_tolerance` config'i (973 ±10). Nüfus < 500 = bozuk link, atılır. **Sonuç:
  81 il, 970 ilçe, 44k yerleşim, 999/1051 nüfus, 2093 makale, deterministik, 7.5 MB.**
  Simülatörde doğrulandı: Kırşehir Merkez → 150.700 nüfus, 1742 km², Vikipedi özeti +
  CC BY-SA linki, gerçek harita.
- **Cihaz crash düzeltmesi:** `Config/waymark-Info.plist` (`UIBackgroundModes:[location]`
  `INFOPLIST_FILE` ile — Xcode 27 `INFOPLIST_KEY_UIBackgroundModes`'u yok sayıyor),
  `CoreLocationProvider` guard, `requestAuthorization()` kademeli izin.
- **Aktif yolculuk UX:** ilk 60 sn "Locating…" yerine çözülen yer soluk + "Confirming…";
  fix yoksa "Waiting for GPS…".
- `tools/data/` gitignore'da (625 MB PBF + 46 MB cache commit edilmez).

**F8/F9 cila + App Store hazırlığı (2026-09-03):**
**Görsel yeniden tasarım + GitHub (2026-09-03):**
- Repo `github.com/yakupad/waymark` (public) — F1→redesign alt-sistem bazlı commit'ler.
  GitHub Pages'i kullanıcı elle açacak (Settings → Pages → main → /docs).
- **"Yol tabelası" görsel dili:** DesignSystem yeniden yazıldı — `SignPanel` (mavi
  üstüne beyaz yön levhası + ince keyline), `TierShield` (İL/İLÇE/KÖY), `SignStat`
  (tabeladaki km gibi rakam), `MilestoneRow` (chevron). Tüm ekranlar + Live Activity +
  en/tr metinler. Rota çizgisi beyaz kılıf + mavi; işaretçi kuzey-oku chevron.
- **Screenshot hook:** `-waymarkScreen active|summary|place` demo yolculuğa atlar;
  `PermissionsModel.demoMode` sistem uyarılarını bastırır. 8 çerçeveli görüntü
  (`tools/appstore/frame.swift`) `docs/app-store/screenshots/{en,tr}/`.

- `PermissionsModel` — ilk yolculukta bildirim izni + kademeli "Always" konum yükseltme
  kartı (`ActiveTripView`). R4 kurtarma artık `HomeView`'da modal olmayan kart.
- `SQLiteGeoResolver.settlementPlace(...)` — `place(for:)` artık yerleşimleri de doldurur
  (eskiden nil). `LiveTripController` ardışık aynı yeri tekrar eklemez.
- **App icon** — `AppIcon.appiconset` gerçek görsel (1024 + dark + tinted),
  `tools/appstore/makeicon.swift`. **Sadece iPhone:** `TARGETED_DEVICE_FAMILY = 1`,
  `SUPPORTED_PLATFORMS` iphone-only, app deployment target 26.6 → **27.0**.
  `ITSAppUsesNonExemptEncryption = false`.
- **`docs/app-store.md`** tam App Store Connect kontrol listesine dönüştürüldü;
  **`docs/privacy-policy.md`** + **`docs/support.md`** (en+tr, host'lanabilir);
  `docs/app-store/screenshots/` — en 3 çerçeveli + tr 1 (Türkçe UI) + ham kareler,
  `tools/appstore/frame.swift`.
- **Bilinen F1 veri hatası:** yerleşim `parent_id` çoğu zaman yanlış (geniş alandaki
  köyler aynı ilçeyi gösteriyor). Bir sonraki pack üretiminde düzeltilecek.

**Kalan F9 (gerçek cihaz / Apple hesabı):** cihazda pil ölçümü (saatte <%8, ekran
kapalı), cihazda Live Activity + bildirim akışı, şebekesiz bölge davranışı, cihazda
tr aktif+özet ekran görüntüleri, TÜİK nüfus (CSV gelirse), App Store yükleme.

---

## 16. Kod üretim promptları

Aşağıdaki promptlar sırayla kullanılır. Her biri bu dokümanın tamamıyla birlikte verilir.
**Sıra atlanmaz** — her faz bir öncekinin çıktısına dayanır.

---

**P1 — Veri pipeline'ı**

> Bölüm 5'teki spesifikasyona göre `tools/build_pack.py` yaz. Girdi: Geofabrik
> `turkey-latest.osm.pbf`, TÜİK nüfus CSV'si, Wikidata sorgu sonucu.
> Çıktı: 5.3'teki şemaya uygun `tr.pack` (SQLite).
>
> Script **bölge-agnostik** olmalı: ülke kodu ve `osm_admin_level → tier` eşlemesi
> bir yapılandırma dosyasından okunmalı, koda gömülmemeli (K6, K8). v1'de yalnızca
> `TR` yapılandırması bulunacak ama yeni ülke eklemek yeni bir config dosyası olmalı,
> script değişikliği değil.
>
> **Ülke filtresini uygula** (5.2): extract komşu ülkelerin birimlerini de içeriyor.
> Hedef 81 tier-1, 973 tier-2 — tutmuyorsa hata ver, sessizce devam etme.
> Birleştirmede **ad kullanma**, OSM relation id + parent kullan (28 ad çakışması var).
> Geçersiz `admin_level` değerlerinde çökme, atla ve raporla.
>
> `wikidata_id` sütunlarını doldur (K7), nüfusu TÜİK'ten al ve `population_src='tuik'`
> işaretle. Vikipedi özetlerini `tr` ve `en` için ayrı `article` satırları olarak yaz;
> sonunda **dil bazında kapsama oranını raporla** (R13 için gerekli).
>
> Poligonlar 5.4'teki binary formatta kodlanacak. `osmium`, `shapely`, `sqlite3` kullan.
> Bölüm 5.2 adım 2'deki doğrulamaları çalıştır, eksik idari birimleri ayrı rapora yaz,
> tablo bazında boyut raporu bas. Ad normalizasyonunda `tr_TR` locale kullan.
> İdempotent ve deterministik olsun.

**P2 — Binary decoder ve PIP motoru**

> `GeoData` paketinde şunları yaz: (a) 5.4'teki formatı çözen `PolygonDecoder`,
> (b) iç ring destekli ray casting yapan `PointInPolygon`, (c) haversine mesafe yardımcısı.
> Hiçbir üçüncü taraf bağımlılık kullanma. `Data` üzerinde sıfır kopya okuma yap.
> Bozuk girdide crash etme, `throws` ile hata döndür. Bölüm 12.1'deki senaryoları
> kapsayan birim testlerini de yaz — özellikle enklav (iç ring) durumunu.

**P3 — Mekânsal çözümleyici**

> `GeoData` paketinde `GeoResolving` protokolünü uygulayan `SQLiteGeoResolver` yaz.
> Bölüm 7.6'daki algoritmayı izle: R\*Tree bbox ön filtresi → poligon testi →
> en yakın yerleşim. Kademe sayısını `tier_label` tablosundan oku, 1 ve 2'yi koda gömme (K6).
> Ad ve tarihçe çözümlemesinde dil geri düşüş zincirini uygula (Bölüm 11.5).
> Geometri blob'ları için kapasitesi 8 olan LRU cache kullan.
> `GRDB` veya `SQLite.swift` kullanabilirsin; tercihini gerekçelendir.
> Thread-safe olmalı, `Sendable` uyumlu.

**P4 — Durum makinesi**

> `LocationEngine` paketinde Bölüm 7.3–7.5'teki durum makinesini yaz.
> Üç seviye (il/ilçe/yerleşim) paralel ve bağımsız çalışacak. `PresenceTuning` struct'ı
> tüm parametreleri barındıracak, hiçbir sabit koda gömülmeyecek.
> CoreLocation'a doğrudan bağımlı olma — `LocationProviding` protokolü arkasında kal.
> Zaman için enjekte edilebilir bir `Clock` kullan ki testler deterministik olsun.
> Bölüm 7.2'deki örnek filtrelemeyi de uygula.

**P5 — GPX replay harness ve testler**

> `LocationEngine` için GPX dosyasını okuyup durum makinesine besleyen bir test
> altyapısı yaz. Zaman damgalarını hızlandırılmış şekilde simüle etsin.
> Bölüm 12.3'teki beş rota için test iskeletlerini oluştur ve
> `istanbul-ordu` il dizisi testini tam olarak yaz.

**P6 — Live Activity ve bildirimler**

> `Presence` paketini yaz: Bölüm 8'deki matrise göre olayları yüzeylere yönlendiren
> `PresenceCoordinator`, ActivityKit widget'ı (kilit ekranı + üç Dynamic Island durumu),
> `UNUserNotificationCenter` sarmalayıcısı. 60 saniyelik güncelleme birleştirme (coalescing)
> mantığını, cooldown'ı ve saatlik bildirim limitini uygula. Sessiz saatler desteği ekle.

**P7 — Rota izi motoru**

> `TripKit` içinde Bölüm 7.7'yi uygula: ham nokta tamponu ve 200 noktalık disk flush'ı,
> Douglas-Peucker sadeleştirme (20 m), 2 km / 5 dk eşikleriyle segment kesme,
> `RouteTrace.trimmed(by:)` uç nokta kırpması, Bölüm 5.4 kodlamasıyla blob serileştirme.
> Saf Swift olsun, MapKit'e bağımlı olma. Bölüm 12.1'deki rota testlerini de yaz.

**P8 — TripKit ve kalıcılık**

> SwiftData ile yolculuk modeli, kayıt ve geçmiş sorgulamayı yaz. Bölüm 9'daki modelleri
> temel al. Rota izi tek `Data` attribute'u olarak saklansın, nokta başına nesne oluşturma.
> `TripSummary` hesaplamasını (öne çıkanlar dahil) ve `title` otomatik üretimini uygula.
> Arka planda sonlandırma sonrası kurtarma mekanizmasını ekle (R4).
> "Rota izini kaydet" anahtarı ve "Rotayı sil" işlemini destekle.

**P9 — Harita ve paylaşım görseli**

> İki render yolu yaz: (a) uygulama içi `MapPolyline` tabanlı segment çizimi,
> (b) `MKMapSnapshotter` + Core Graphics ile paylaşılabilir görsel üretimi.
> `ImageRenderer` içinde `Map` kullanma. Paylaşım görselinde kırpma uygulanmış rotayı çiz,
> yolculuk istatistiklerini görsele işle ve "Başlangıç ve bitiş gizlendi" rozetini ekle.
> Geçmiş listesi için önizleme görseli üretip önbellekleyen bir katman da yaz (R10).

**P10 — UI katmanı**

> Bölüm 10'daki ekranları SwiftUI + MVVM-C ile yaz. Coordinator'lar navigasyonu yönetsin,
> ViewModel'ler `@Observable` ve `@MainActor` olsun, View'lar saf sunum olsun.
> Debug menüsünü de dahil et. Tüm kullanıcı metinleri `Localizable.xcstrings` üzerinden
> gelsin; base dil İngilizce, ayrıca Türkçe. Bölüm 11.5'teki kuralların tamamına uy —
> özellikle `.leading`/`.trailing` kullanımı ve kademe etiketlerinin veriden gelmesi.
> Dinamik yazı tipi boyutu ve VoiceOver desteği zorunlu.

**P11 — Yayın hazırlığı**

> `PrivacyInfo.xcprivacy`, atıf/hakkında ekranı (OSM ODbL, TÜİK, Vikipedi CC BY-SA),
> Info.plist izin metinleri, App Store açıklaması ve inceleme notları taslağı.

---

## 17. Açık kararlar

Kod üretimine başlamadan önce netleşmesi gerekenler:

1. ~~Ürün adı~~ — **Waymark**. App Store isim müsaitliği ve marka çakışması hâlâ
   doğrulanmalı; çakışma çıkarsa alternatifler: Milepost, Crossing, Passage.
2. ~~Minimum iOS sürümü~~ — **27.0** (güncellendi). Xcode 27 projesi bu hedefle
   oluşturuldu; bugün başlayan v1 için Observation, SwiftData, olgun Live Activity
   ve SDK 27 API'leri gerekçe. (Spec v0.2 metni 17.0 diyordu; F1 kararıyla 27.0'a çekildi.)
3. ~~SQLite kütüphanesi~~ — **GRDB** (F1 kararı). Olgun R\*Tree desteği, `Sendable`/
   concurrency uyumu, SPM ile tek temiz bağımlılık. F2'de `GeoData` bunu kullanır.
4. **Ücretlendirme** — Ücretsiz mi, tek seferlik satın alma mı, abonelik mi?
   Sunucu maliyeti sıfır olduğu için tek seferlik satın alma modele uygun görünüyor.
5. **Yolculuk geçmişi kalıcılığı** — Sınırsız mı, son N yolculuk mu? Rota izi eklendiği için
   yolculuk başına ~12 KB birikiyor; sınırsız tutmak teknik olarak sorun değil ama
   kullanıcıya toplu silme ve dışa aktarma (GPX export) sunulmalı.
6. **GPX dışa aktarma** — v1'e girsin mi? Teknik maliyeti düşük (iz zaten var), ama
   "verilerim bende kalsın" duruşunu güçlendirir ve gizlilik odaklı kullanıcıya hitap eder.
7. **v1'de İngilizce içerik** — İngilizce Vikipedi kapsaması düşükse EN arayüz içerik
   bakımından zayıf kalır. Seçenekler: (a) İ4'e uy, boş bırak; (b) EN'i yalnızca arayüz
   dili yap, içeriği TR'de tut ve kaynak dilini belirt. Kapsama ölçüldükten sonra karar ver.
8. **Bölge paketi teslimi (v2)** — App Store'un On-Demand Resources mekanizması mı,
   kendi CDN'in mi? ODR ücretsiz ve Apple altyapısında ama esnekliği düşük.

---

## Ek A — Atıf metinleri

**Ayarlar > Hakkında ekranında birebir yer alacak:**

> **Harita ve idari sınır verileri**
> © OpenStreetMap katkıcıları. ODbL 1.0 lisansı ile kullanılmaktadır.
>
> **Nüfus verileri**
> Türkiye İstatistik Kurumu (TÜİK), Adrese Dayalı Nüfus Kayıt Sistemi.
>
> **Yer bilgileri**
> Vikipedi'den alınmıştır. CC BY-SA 4.0 lisansı ile kullanılmaktadır.
> Her yerin detay sayfasında ilgili kaynak makalenin bağlantısı bulunur.

---

## Ek B — Sözlük

| Terim | Anlam |
|---|---|
| PIP | Point-in-polygon — bir noktanın poligon içinde olup olmadığı testi |
| Histerezis | Giriş ve çıkış eşiklerinin farklı olması; sınırdaki titremeyi emer |
| Cooldown | Aynı yer için tekrar bildirim gönderilmeden önce beklenen süre |
| Coalescing | Kısa aralıkta biriken güncellemelerin tek işlemde birleştirilmesi |
| Enklav | Bir idari birimin içinde kalan, başka bir birime ait alan (iç ring) |
| Replay harness | Kayıtlı konum verisini motora besleyip çıktıyı doğrulayan test altyapısı |
| Douglas-Peucker | Bir çizgiyi görsel olarak bozmadan nokta sayısını azaltan sadeleştirme algoritması |
| Segment | Rotanın kesintisiz bir parçası; boşluklar segmentleri birbirinden ayırır |
| Uç nokta kırpma | Paylaşılan rotanın başından ve sonundan belirli mesafenin çıkarılması |
| Tier | Kademe. Ülkeden bağımsız idari düzey numarası; Türkiye'de 1=il, 2=ilçe |
| Bölge paketi | Bir ülkenin tüm coğrafi verisini içeren tek dosya. v1'de bundle'a gömülü |
| ADM0/ADM1/ADM2 | Uluslararası idari kademe gösterimi; sırasıyla ülke, birinci, ikinci düzey |
