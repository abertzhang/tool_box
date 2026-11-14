// ============================================================================
// 文件：feature/profile/data/sdk_list_de.dart
// 模块：我的 / 个人中心（profile）/ 第三方 SDK 清单 · 德文整篇
//
// 职责：
//   提供德文版「第三方 SDK 清单」的完整内容（分组、条目、说明章节）。
//   与 sdk_list_en.dart / sdk_list_zh.dart / sdk_list_ja.dart 一一对应：
//   字段名与条目顺序必须保持一致，否则切换语言时数据错位。
//
// 维护约定：
//   1. 版本号取自 pubspec.lock 的实际解析结果；
//   2. 新增 / 移除依赖时，各语种文件都要同步改；
//   3. 正文改动后请同步更新 updatedAt。
// ============================================================================

import '../model/sdk_list.dart';

/// 德文版清单内容。
const SdkListContent sdkListDe = SdkListContent(
  updatedAt: '2026-09-25',
  intro:
      'Diese Seite listet jede Bibliothek von Drittanbietern auf, die zur '
      'Laufzeit in die App eingebunden ist, zusammen mit den Berechtigungen, '
      'die sie verwendet, und den Daten, die sie verarbeitet. Sie dient der '
      'App-Store-Prüfung und der Datenschutoffenlegung. Build-Zeit-Werkzeuge '
      'sind ausgeschlossen, da sie nie mit der App ausgeliefert werden. '
      'Tippe auf einen Richtlinienlink, um ihn zu kopieren.',
  filterAll: 'Alle',
  filterSensitive: 'Nur sensibel',
  labelVendor: 'Anbieter',
  labelPurpose: 'Zweck',
  labelPermissions: 'Berechtigungen',
  labelData: 'Erhobene Daten',
  labelPolicy: 'Datenschutzerklärung',
  tapCopyHint: 'Zum Kopieren tippen',
  copiedToast: 'Link kopiert',
  groups: <SdkGroup>[
    // —— 框架与基础工具 ——
    SdkGroup(
      title: 'Framework und Hilfsmittel',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'Flutter SDK (flutter, flutter_localizations)',
          version: '3.44 / Dart 3.12+',
          vendor: 'Google LLC',
          purpose:
              'Plattformübergreifendes UI-Framework und die eingebauten '
              'Material-/Cupertino-Lokalisierungsdelegaten.',
          permissions: 'Keine',
          data: 'Nicht erhoben',
          privacyUrl: 'https://policies.google.com/privacy',
        ),
        SdkEntry(
          name: 'intl',
          version: '0.20.3',
          vendor: 'Dart team',
          purpose:
              'Datums-, Zahlen- und Nachrichtenformatierung für die '
              'Lokalisierung.',
          permissions: 'Keine',
          data: 'Nicht erhoben',
          privacyUrl: 'https://pub.dev/packages/intl',
        ),
        SdkEntry(
          name: 'yaml',
          version: '3.1.4',
          vendor: 'Dart team',
          purpose:
              'Parst die lokal in den Assets gebündelte '
              'Umgebungskonfiguration.',
          permissions: 'Keine',
          data: 'Nicht erhoben',
          privacyUrl: 'https://pub.dev/packages/yaml',
        ),
        SdkEntry(
          name: 'package_info_plus',
          version: '10.2.1',
          vendor: 'Flutter team (Google)',
          purpose: 'Liest die in der Über-Sektion angezeigte App-Version.',
          permissions: 'Keine',
          data: 'Nicht erhoben',
          privacyUrl: 'https://pub.dev/packages/package_info_plus',
        ),
        SdkEntry(
          name: 'flutter_screenutil_plus',
          version: '1.6.0',
          vendor: 'Community',
          purpose: 'Skaliert die UI auf die Design-Baseline 393x852.',
          permissions: 'Keine',
          data: 'Nicht erhoben',
          privacyUrl: 'https://pub.dev/packages/flutter_screenutil_plus',
        ),
        SdkEntry(
          name: 'shared_preferences',
          version: '2.5.5',
          vendor: 'Dart team (Google)',
          purpose:
              'Speichert leichte Schalter-Präferenzen (Design, Sprache, '
              'Frei-Nutzungs-Belohnungen und ähnliche einzelne bool-/'
              'int-Werte), ohne eine Datenbank zu öffnen.',
          permissions: 'Keine',
          data: 'Nur auf dem Gerät gespeichert, nie hochgeladen',
          privacyUrl: 'https://pub.dev/packages/shared_preferences',
        ),
        SdkEntry(
          name: 'share_plus',
          version: '13.3.0',
          vendor: 'Flutter team (Google)',
          purpose:
              'Zeigt das System-Teilen-Sheet mit Zielen wie WeChat, E-Mail '
              'und Nachrichten, die auf dem Gerät installiert sind, zum Teilen '
              'von Memo-Inhalten und ähnlichem.',
          permissions: 'Keine (vom System-Teilen-Sheet verarbeitet)',
          data:
              'Nicht erhoben; geteilter Inhalt verlässt das Gerät nur über '
              'das System-Sheet',
          privacyUrl: 'https://pub.dev/packages/share_plus',
        ),
      ],
    ),
    // —— 架构与网络 ——
    SdkGroup(
      title: 'Architektur und Netzwerk',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'flutter_riverpod',
          version: '3.3.2',
          vendor: 'Remi Rousselet (community)',
          purpose: 'Reaktive Zustandsverwaltung, über die App verteilt.',
          permissions: 'Keine',
          data: 'Nicht erhoben',
          privacyUrl: 'https://pub.dev/packages/flutter_riverpod',
        ),
        SdkEntry(
          name: 'go_router',
          version: '17.3.0',
          vendor: 'Flutter team (Google)',
          purpose:
              'Deklarative Navigation, einschließlich Splash- und Tab-Shell.',
          permissions: 'Keine',
          data: 'Nicht erhoben',
          privacyUrl: 'https://pub.dev/packages/go_router',
        ),
        SdkEntry(
          name: 'dio',
          version: '5.10.0',
          vendor: 'Community',
          purpose: 'HTTP-Client für ausgehende Anfragen.',
          permissions: 'Keine (Android INTERNET braucht keine Laufzeitabfrage)',
          data: 'Von der Bibliothek selbst nicht erhoben',
          privacyUrl: 'https://pub.dev/packages/dio',
        ),
      ],
    ),
    // —— 数据与存储 ——
    SdkGroup(
      title: 'Daten und Speicher',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'hive / hive_flutter',
          version: '2.2.3 / 1.1.0',
          vendor: 'Community',
          purpose:
              'Lokaler Schlüssel-Wert-Speicher für leichte Einstellungen wie '
              'Sprache und Design.',
          permissions: 'Keine',
          data: 'Nur auf dem Gerät gespeichert, nie hochgeladen',
          privacyUrl: 'https://pub.dev/packages/hive',
        ),
        SdkEntry(
          name: 'isar_community (+ flutter libs)',
          version: '3.3.2',
          vendor: 'Community fork of Isar',
          purpose: 'Eingebettete lokale Datenbank für Werkzeugaufzeichnungen.',
          permissions: 'Keine',
          data: 'Nur auf dem Gerät gespeichert, nie hochgeladen',
          privacyUrl: 'https://pub.dev/packages/isar_community',
        ),
        SdkEntry(
          name: 'path_provider',
          version: '2.1.6',
          vendor: 'Flutter team (Google)',
          purpose:
              'Ermittelt die App-Verzeichnisse, die von Cache und Datenbank '
              'genutzt werden.',
          permissions: 'Keine',
          data: 'Nicht erhoben',
          privacyUrl: 'https://pub.dev/packages/path_provider',
        ),
        SdkEntry(
          name: 'supabase_flutter',
          version: '2.17.2',
          vendor: 'Supabase Inc.',
          purpose:
              'E-Mail-Authentifizierung, Cloud-Profil-Synchronisierung und das '
              'Edge-Function-Gateway für anonyme Nutzungsereignisse.',
          permissions: 'Keine (nur Netzwerkzugriff)',
          data:
              'E-Mail-Adresse, Spitzname, Avatar-URL, Mitgliedschaftsstatus '
              'und anonyme Nutzungsereignisse',
          privacyUrl: 'https://supabase.com/privacy',
          sensitive: true,
        ),
        SdkEntry(
          name: 'sign_in_with_apple',
          version: '8.2.0',
          vendor: 'Community maintained (bridge recommended by Flutter)',
          purpose:
              'Zeigt das native System-Sheet für „Anmelden mit Apple“ unter '
              'iOS und macOS. Unter Android nicht verwendet (Apple bietet '
              'kein Android-SDK).',
          permissions: 'Keine',
          data:
              'Das Plugin selbst erhebt nichts; Nutzer können ihre '
              'E-Mail-Adresse verbergen, in diesem Fall liefert Apple eine '
              'private Weiterleitungsadresse statt der echten',
          privacyUrl: 'https://www.apple.com/legal/privacy/data/',
        ),
        SdkEntry(
          name: 'crypto',
          version: '3.0.7',
          vendor: 'Dart team',
          purpose:
              'Berechnet SHA-256, das zum Hashen des Anti-Replay-Nonces '
              'benötigt wird, das für das native „Anmelden mit Apple“ nötig '
              'ist.',
          permissions: 'Keine',
          data: 'Nicht erhoben',
          privacyUrl: 'https://pub.dev/packages/crypto',
        ),
        SdkEntry(
          name: 'google_sign_in',
          version: '6.3.0',
          vendor: 'Flutter team (Google)',
          purpose:
              'Zeigt das systemeigene Google-Anmelde-Sheet unter Android und '
              'nicht-Apple-iOS und übergibt die Google-Identität an Supabase, '
              'um eine Sitzung als Ein-Tipp-Anmeldung zu erzeugen.',
          permissions: 'Keine (vom System-Google-Sheet verarbeitet)',
          data:
              'Google-Konto-Identität (idToken / accessToken) plus '
              'öffentliches Profil wie Avatar und Spitzname, von Supabase für '
              'Anmeldung und Sitzung verwendet',
          privacyUrl: 'https://policies.google.com/privacy',
          sensitive: true,
        ),
        SdkEntry(
          name: 'device_info_plus',
          version: '13.2.0',
          vendor: 'Flutter team (Google)',
          purpose:
              'Liest den anonymen Gerätekenner (iOS IDFV / Android '
              'ANDROID_ID), damit das Frei-Nutzungs-Kontingent auch nach '
              'einer Neuinstallation dasselbe Gerät erkennt.',
          permissions:
              'Keine (das Lesen der Geräte-ID braucht keine '
              'Laufzeitberechtigung)',
          data:
              'Der Kenner wird mit SHA-256 gehasht und als anonymer '
              'Gerätekenner gemeldet, der nicht auf das Original '
              'zurückführbar ist; nur zum Erkennen anonymer Geräte verwendet, '
              'es werden keine weiteren Daten hochgeladen',
          privacyUrl: 'https://pub.dev/packages/device_info_plus',
          sensitive: true,
        ),
      ],
    ),
    // —— 设备能力 ——
    SdkGroup(
      title: 'Gerätefunktionen',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'flutter_compass',
          version: '0.8.1',
          vendor: 'Community',
          purpose: 'Magnetometer-Peilung für das Kompass-Werkzeug.',
          permissions:
              'Keine (Magnetometer braucht keine Laufzeitberechtigung)',
          data: 'Nur auf dem Gerät',
          privacyUrl: 'https://pub.dev/packages/flutter_compass',
        ),
        SdkEntry(
          name: 'geolocator',
          version: '14.0.3',
          vendor: 'Baseflow (Flutter community)',
          purpose: 'Höhe und Koordinaten, die neben dem Kompass angezeigt werden.',
          permissions:
              'Standort: iOS When-In-Use, Android ACCESS_FINE_LOCATION / '
              'ACCESS_COARSE_LOCATION',
          data: 'Nur auf dem Gerät, nie hochgeladen',
          privacyUrl: 'https://pub.dev/packages/geolocator',
          sensitive: true,
        ),
        SdkEntry(
          name: 'noise_meter',
          version: '5.1.0',
          vendor: 'Community',
          purpose: 'Mikrofon-Abtastung für das Geräuschmesser-Werkzeug.',
          permissions:
              'Mikrofon: iOS NSMicrophoneUsageDescription, Android '
              'RECORD_AUDIO',
          data:
              'Nur auf dem Gerät; es werden keine Audiodaten aufgezeichnet, '
              'gespeichert oder hochgeladen',
          privacyUrl: 'https://pub.dev/packages/noise_meter',
          sensitive: true,
        ),
        SdkEntry(
          name: 'sensors_plus',
          version: '7.1.0',
          vendor: 'Flutter team (Google)',
          purpose: 'Beschleunigungssensor-Daten für das Wasserwaagen-Werkzeug.',
          permissions: 'Keine',
          data: 'Nur auf dem Gerät',
          privacyUrl: 'https://pub.dev/packages/sensors_plus',
        ),
        SdkEntry(
          name: 'camera',
          version: '0.12.0+2',
          vendor: 'Flutter team (Google)',
          purpose:
              'Kamerazugriff, der nur zur Ansteuerung der '
              'Taschenlampen-Leuchte dient.',
          permissions:
              'Kamera: iOS NSCameraUsageDescription, Android CAMERA',
          data: 'Es werden keine Bilder oder Videos aufgezeichnet, gespeichert '
              'oder hochgeladen',
          privacyUrl: 'https://pub.dev/packages/camera',
          sensitive: true,
        ),
        SdkEntry(
          name: 'permission_handler',
          version: '12.0.3',
          vendor: 'Baseflow (Flutter community)',
          purpose: 'Zeigt die oben aufgeführten System-Berechtigungsdialoge.',
          permissions:
              'Keine (fordert nur im Auftrag der App Berechtigungen an)',
          data: 'Nicht erhoben',
          privacyUrl: 'https://pub.dev/packages/permission_handler',
        ),
      ],
    ),
    // —— 支付与评分 ——
    SdkGroup(
      title: 'Zahlungen und Bewertungen',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'in_app_purchase',
          version: '3.3.0',
          vendor: 'Flutter team (Google)',
          purpose: 'Einmaliger (nicht verbrauchbarer) Mitgliedschaftskauf.',
          permissions: 'Keine (vom Store verarbeitet)',
          data:
              'Die Transaktion wird von Apple oder Google abgewickelt; die '
              'App erhält nur den Berechtigungsstatus',
          privacyUrl: 'https://www.apple.com/legal/privacy/',
          sensitive: true,
        ),
        SdkEntry(
          name: 'in_app_purchase_storekit',
          version: '0.4.13',
          vendor: 'Flutter team (Google)',
          purpose:
              'iOS StoreKit-2-APIs, die verwendet werden, um Berechtigungen '
              'zu aktualisieren, wenn der Nutzer auf „Käufe wiederherstellen“ '
              'tippt.',
          permissions: 'Keine (vom Store verarbeitet)',
          data: 'Nur Berechtigungsstatus',
          privacyUrl: 'https://www.apple.com/legal/privacy/',
          sensitive: true,
        ),
        SdkEntry(
          name: 'in_app_review',
          version: '2.0.12',
          vendor: 'Flutter team (Google)',
          purpose:
              'Zeigt die systemeigene In-App-Bewertungsaufforderung, mit '
              'Rückfall auf die Store-Liste, wenn nicht verfügbar.',
          permissions: 'Keine',
          data: 'Nicht erhoben',
          privacyUrl: 'https://pub.dev/packages/in_app_review',
        ),
      ],
    ),
    // —— 广告变现 ——
    SdkGroup(
      title: 'Werbung',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'google_mobile_ads',
          version: '9.1.0',
          vendor: 'Google LLC',
          purpose:
              'Fordert und rendert adaptive Bannerwerbung innerhalb der App '
              'an. Sobald Pro freigeschaltet ist, wird keine Werbung mehr '
              'angefordert.',
          permissions: 'Von der App nicht deklariert (das SDK nutzt das Netzwerk)',
          data:
              'Geräte- und Werbeinteraktionsdaten, die von Google AdMob '
              'gemäß der Google-Datenschutzerklärung verarbeitet werden',
          privacyUrl: 'https://policies.google.com/privacy',
          sensitive: true,
        ),
      ],
    ),
    // —— In-app web view ——
    SdkGroup(
      title: 'In-App-WebView',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'webview_flutter',
          version: '4.14.1',
          vendor: 'Flutter team (Google)',
          purpose:
              'Rendert Online-Dokumente (Nutzungsbedingungen, Datenschutz, '
              'SDK-Listen-Links) innerhalb der App, anstatt zu einem '
              'externen Browser zu springen.',
          permissions:
              'Netzwerk (macOS braucht das Sandbox-Entitlement '
              'com.apple.security.network.client)',
          data:
              'Lädt nur die von der App vorgegebenen öffentlichen '
              'Dokument-URLs; es wird kein Skript injiziert und der '
              'gerenderte Inhalt nicht erhoben',
          privacyUrl: 'https://pub.dev/packages/webview_flutter',
        ),
      ],
    ),
  ],
  // —— 系统平台框架（非第三方 SDK，仅补充说明）——
  platformTitle: 'Plattform-Frameworks',
  platformNote:
      'Folgende gehören zum Betriebssystem und sind keine SDKs von '
      'Drittanbietern. Sie werden aufgeführt, weil Prüf- und '
      'Datenschutzoffenlegungen oft danach fragen. Sie unterliegen den '
      'Apple- oder Google-Plattformbedingungen.',
  platforms: <SdkEntry>[
    SdkEntry(
      name: 'StoreKit 2 / Google Play Billing',
      version: 'System',
      vendor: 'Apple Inc. / Google LLC',
      purpose: 'Wickelt den einmaligen Mitgliedschaftskauf ab.',
      permissions: 'Keine',
      data: 'Zahlungsdaten, die von Apple oder Google verarbeitet werden',
      sensitive: true,
    ),
    SdkEntry(
      name: 'Core Location / Location Services',
      version: 'System',
      vendor: 'Apple Inc. / Google LLC',
      purpose: 'Liefert Höhe und Koordinaten.',
      permissions: 'Standort',
      data: 'Nur auf dem Gerät',
      sensitive: true,
    ),
    SdkEntry(
      name: 'AVFoundation / Camera2',
      version: 'System',
      vendor: 'Apple Inc. / Google LLC',
      purpose: 'Stellt die Leuchtensteuerung für die Taschenlampe bereit.',
      permissions: 'Kamera',
      data: 'Es werden keine Medien aufgezeichnet',
      sensitive: true,
    ),
    SdkEntry(
      name: 'CoreMotion / Sensor Framework',
      version: 'System',
      vendor: 'Apple Inc. / Google LLC',
      purpose:
          'Liefert Beschleunigungs-, Gyro- und Magnetometersamples.',
      permissions: 'Keine',
      data: 'Nur auf dem Gerät',
      sensitive: true,
    ),
  ],
  // —— 说明 ——
  noteTitle: 'Hinweise',
  noteBody:
      'Umfang: Es werden nur Bibliotheken aufgeführt, die im veröffentlichten '
      'Binärprogramm enthalten sind. Build-Zeit-Werkzeuge wie '
      'flutter_native_splash sind eine Entwickler-Abhängigkeit und werden '
      'nie mit der App verteilt.\n\n'
      'Die Daten-Spalte beschreibt, wie diese App jede Bibliothek nutzt, '
      'nicht was der Anbieter auf seinen eigenen Diensten tut.\n\n'
      'Werbung: Die Gratisversion zeigt an wenigen Stellen in der App '
      'Google-AdMob-Bannerwerbung. Sobald Pro freigeschaltet ist, wird keine '
      'Werbung mehr angefordert. Diese App fordert die '
      'App-Tracking-Transparenz-Berechtigung nicht an und sendet keine '
      'Werkzeugdaten an Werbenetzwerke.\n\n'
      'Das Tippen auf einen Link kopiert ihn in die Zwischenablage. Es wird '
      'bewusst keine In-App-Browser-Abhängigkeit eingebunden, sodass diese '
      'App zum Anzeigen dieser Seite keine zusätzliche Berechtigung anfordert.',
);
