# Dashboard (iOS)

iPhone için yatay, premium araç paneli: MapKit navigasyon, Spotify, Open-Meteo hava durumu ve GPS hız göstergesi.
Swift 6 · SwiftUI · MVVM · iOS 26+ · Liquid Glass.

> **Kontrol:** GitHub Actions, iOS Release derlemesini ve simgenin uygulama paketinde bulunduğunu denetler. Canlı Spotify, konum ve görünümün gerçek cihazda ayrıca denenmesi gerekir.

## Kurulum

```bash
brew install xcodegen
xcodegen generate        # Dashboard.xcodeproj üretir (repoda tutulmaz)
open Dashboard.xcodeproj
```

Xcode 26+ gerekir. Signing & Capabilities'ta kendi Team'inizi seçin, bundle id'yi gerekirse değiştirin
(`project.yml` → `PRODUCT_BUNDLE_IDENTIFIER`; imzalı CI için `ios-build.yml` içindeki
`ExportOptions` bundle id'sini de güncelleyin).

## Hava durumu

Hava verileri [Open-Meteo](https://open-meteo.com/) üzerinden alınır; API anahtarı veya WeatherKit yetkisi gerekmez. Konum koordinatları yalnızca hava tahmini isteği için bu servise gönderilir. Güncel sıcaklık, hissedilen sıcaklık, üç günlük tahmin ve güneş doğuş/batış saatleri kullanılır. Veriler 15 dakikada bir veya konum 5 km değiştiğinde yenilenir. Hata durumunda yeniden deneme en erken 60 saniye sonra yapılır; bağlantı yoksa gerçek dışı veri üretilmez.

## Spotify
1. developer.spotify.com/dashboard → uygulama oluşturun, **Redirect URI** olarak `dashboard-spotify://callback` ekleyin.
2. Client ID'yi uygulamada **Ayarlar → Spotify Client ID**'ye girin (veya derlemede `SPOTIFY_CLIENT_ID` build ayarı).
3. "Spotify'a Bağlan" → OAuth Authorization Code + PKCE. Tokenlar Keychain'de saklanır, otomatik yenilenir.
4. Development modundaki Spotify uygulamasında kullanıcı e-postanızı "User Management"e eklemeniz gerekir.

Sınırlar: oynatma kontrolü (oynat/duraklat/sonraki/önceki/seek) **Spotify Premium** ve **aktif bir cihaz** (Spotify uygulaması açık) ister.
Dashboard sesi kendisi çalmaz; iPhone'daki Spotify veya başka bir cihazı uzaktan kontrol eder.

## Navigasyon — gerçek yetenekler ve sınırlar
- MapKit haritası uygulama içinde; canlı konum, trafik katmanı, adres/mekan arama, alternatif rotalar, rota çizimi, ETA.
- Dönüş talimatları `MKRoute.steps`'ten gösterilir; sesli yönlendirme `AVSpeechSynthesizer` ile **kendi uygulamamızdadır** (Apple Maps'in tam navigasyon motoru değildir).
- Adım takibi ve rotadan sapınca yeniden hesaplama basit mesafe tabanlıdır; şerit önerisi, hız limiti uyarısı, trafiğe göre canlı yeniden rota yoktur.
- Arka planda konum/navigasyon için `UIBackgroundModes: location` eklenmedi; uygulama ekranda açık kullanım için tasarlandı.

## GitHub Actions ile IPA

[Actions → iOS Build](https://github.com/berkecaan/dashboard-ios/actions/workflows/ios-build.yml) iş akışı `main` dalına her yüklemede ve pull request açıldığında çalışır. Elle başlatmak için **Run workflow → main → Run workflow** seçin.

1. macOS 26 üzerinde Xcode 26 ve XcodeGen kullanılır; `project.yml` dosyasından `Dashboard.xcodeproj` üretilir.
2. **Unsigned build and IPA**, Release sürümünü imzasız derler. Başarılı olduğunda çalıştırmanın **Artifacts → Dashboard-unsigned-ipa** bölümünden ZIP'i indirin.
3. ZIP içindeki `Dashboard-unsigned.ipa` yeniden imzalama içindir; iPhone'a doğrudan kurulmaz. `.sha256` dosyası IPA'nın bütünlük kontrolüdür.
4. Sertifika ve provisioning profile secret değerleri tanımlıysa **Signed IPA (optional)** ayrıca imzalı IPA üretir: **Artifacts → Dashboard-ipa**. Secret değerleri yoksa bu iş imzalama adımlarını atlar.

İmzasız IPA her başarılı derlemede üretilir; bunun için Apple hesabı veya imza secret değeri gerekmez. İmzalı IPA'nın kurulabilmesi cihazın kullanılan provisioning profile kapsamında olmasını gerektirir.

İmzalı derleme için **Settings → Secrets and variables → Actions** bölümüne ekleyin:

| Secret | İçerik |
|---|---|
| `IOS_CERT_P12_BASE64` | `base64 -i cert.p12` çıktısı |
| `IOS_CERT_PASSWORD` | .p12 parolası; parolasız sertifikada boş bırakılabilir |
| `IOS_PROVISION_PROFILE_BASE64` | `base64 -i profile.mobileprovision` çıktısı |
| `IOS_TEAM_ID` | Apple Team ID |

İsteğe bağlı repository değişkenleri: `IOS_SIGN_IDENTITY` (varsayılan `Apple Distribution`) ve `IOS_EXPORT_METHOD` (varsayılan `release-testing`; profile türüne uygun olmalı).
Provisioning profile, `com.berkecaan.dashboard` bundle ID'siyle eşleşmelidir. Sertifika, token ve anahtarlar kaynak koda eklenmez. Derleme hata verirse ilgili çalıştırmadaki hata günlüğünü inceleyin; `xcodebuild` hataları iş akışını başarısız yapar.

## Yapı
```
Dashboard/App        giriş noktası
Dashboard/Core       Keychain, ayarlar, favoriler, tema, ağ durumu
Dashboard/Features   Navigation · Spotify · Weather · Vehicle(Location) · Dashboard
Dashboard/Resources  Info.plist, entitlement ve asset kataloğu
project.yml          XcodeGen proje tanımı
.github/workflows/ios-build.yml  iOS derleme ve IPA iş akışı
```

Arşivin dış `dashboard-ios/` klasörü depo köküne açılır. Yanlışlıkla oluşturulmuş `{Dashboard/...` boş klasörleri, arşiv dosyaları, derleme çıktıları ve kişisel Xcode ayarları depoya eklenmez. `Dashboard.xcodeproj` XcodeGen ile üretildiği için `.gitignore` kapsamındadır.

## 1.0.1 — ekran ve simge düzeltmeleri

- Kullanılabilir ekran alanına göre hesaplanan sütunlar; kısa yatay ekrana uygun müzik ve hava kartları.
- Kalıcı sol menü: panel, tam ekran harita, müzik, uygulama simgeleri ve ayarlar. Uygulamalar ekranı iç modülleri açar; iOS'ta yüklü tüm uygulamaları listelemez.
- Spotify kartında uygulama içi oynat/duraklat, parça geçişi ve ilerleme kontrolleri. Oynatma için Spotify Premium ve erişilebilir cihaz gereksinimi devam eder.
- Ana ekranda kullanılmak üzere opak 1024×1024 Dashboard uygulama simgesi; build numarası 2.

Derleme kontrolü gerçek iPhone üzerinde görsel veya Spotify oturum testi yerine geçmez.

## 1.0.2 — Spotify kontrolleri Dashboard içinde

Spotify kartı artık şarkı yokken de oynatıcıyı gösterir. Cihaz adı düğmesinden Dashboard içindeki Spotify Connect cihaz listesi açılır. Kullanıcı seçtiğinde cihazda oynatma başlatılır; hiçbir oynatma düğmesi Spotify uygulamasını veya web sitesini açmaz. Oynatma, duraklatma, önceki/sonraki parça ve zaman çizgisi Dashboard içinde yönetilir. Hesap bağlantısının OAuth izin ekranı değişmez.

Dashboard bir Spotify ses cihazı değildir. Spotify uygulaması veya başka bir Spotify Connect cihazı erişilebilir olmalıdır; hiçbir cihaz bulunamazsa uygulama bunu açıkça bildirir. Web API oynatma komutları Premium gerektirir. API cihaz kimlikleri kalıcı olarak saklanmaz; kontrol kısıtlaması olan cihazlar seçilemez.

Kaynaklar: [Spotify cihaz listesi](https://developer.spotify.com/documentation/web-api/reference/get-a-users-available-devices), [cihaz aktarımı](https://developer.spotify.com/documentation/web-api/reference/transfer-a-users-playback), [oynatma](https://developer.spotify.com/documentation/web-api/reference/start-a-users-playback).
