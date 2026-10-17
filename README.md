# Dashboard (iOS)

iPhone için yatay, premium araç paneli: MapKit navigasyon, Spotify, WeatherKit, GPS hız göstergesi.
Swift 6 · SwiftUI · MVVM · iOS 26+ · Liquid Glass.

> **Durum:** Kod Linux ortamında yazıldı; **Xcode ile derlenmedi/test edilmedi.**
> İlk derleme hataları çıkabilir. Doğrulama için [GitHub Actions](https://github.com/berkecaan/dashboard-ios/actions/workflows/ios-build.yml) içindeki "Unsigned build and IPA" işini kontrol edin.

## Kurulum

```bash
brew install xcodegen
xcodegen generate        # Dashboard.xcodeproj üretir (repoda tutulmaz)
open Dashboard.xcodeproj
```

Xcode 26+ gerekir. Signing & Capabilities'ta kendi Team'inizi seçin, bundle id'yi gerekirse değiştirin
(`project.yml` → `PRODUCT_BUNDLE_IDENTIFIER`; imzalı CI için `ios-build.yml` içindeki
`ExportOptions` bundle id'sini de güncelleyin).

## WeatherKit
1. Apple Developer Program üyeliği gerekir.
2. developer.apple.com → Identifiers → App ID'nizde **WeatherKit** hizmetini etkinleştirin.
3. Xcode → Signing & Capabilities → **+ Capability → WeatherKit** (entitlement dosyada hazır).
4. Etkinleştirme sonrası birkaç dakika bekleyin; imzasız derlemede WeatherKit çalışmaz.

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

İmzasız IPA her başarılı derlemede üretilir; bunun için Apple hesabı veya imza secret değeri gerekmez. İmzalı IPA'nın kurulabilmesi cihazın kullanılan provisioning profile kapsamında olmasını gerektirir. WeatherKit'in çalışması için uygulamanın WeatherKit yetkisi içeren geçerli bir profile ile imzalanması gerekir.

İmzalı derleme için **Settings → Secrets and variables → Actions** bölümüne ekleyin:

| Secret | İçerik |
|---|---|
| `IOS_CERT_P12_BASE64` | `base64 -i cert.p12` çıktısı |
| `IOS_CERT_PASSWORD` | .p12 parolası; parolasız sertifikada boş bırakılabilir |
| `IOS_PROVISION_PROFILE_BASE64` | `base64 -i profile.mobileprovision` çıktısı |
| `IOS_TEAM_ID` | Apple Team ID |

İsteğe bağlı repository değişkenleri: `IOS_SIGN_IDENTITY` (varsayılan `Apple Distribution`) ve `IOS_EXPORT_METHOD` (varsayılan `release-testing`; profile türüne uygun olmalı).
Provisioning profile, `com.berkecaan.dashboard` bundle ID'si ve WeatherKit capability'siyle eşleşmelidir. Sertifika, token ve anahtarlar kaynak koda eklenmez. Derleme hata verirse ilgili çalıştırmadaki hata günlüğünü inceleyin; `xcodebuild` hataları iş akışını başarısız yapar.

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
