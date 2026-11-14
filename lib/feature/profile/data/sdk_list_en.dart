// ============================================================================
// 文件：feature/profile/data/sdk_list_en.dart
// 模块：我的 / 个人中心（profile）/ 第三方 SDK 清单 · 英文整篇
//
// 职责：
//   提供英文版「第三方 SDK 清单」的完整内容（分组、条目、说明章节）。
//   与 sdk_list_zh.dart 一一对应：字段名与条目顺序必须保持一致，
//   否则切换语言时两组数据的对应关系会错位。
//
// 维护约定：
//   1. 版本号取自 pubspec.lock 的实际解析结果（不是 pubspec.yaml 的约束区间）；
//   2. 新增 / 移除依赖时，两份文件都要同步改；
//   3. 正文改动后请同步更新 updatedAt。
// ============================================================================

import '../model/sdk_list.dart';

/// 英文版清单内容。
const SdkListContent sdkListEn = SdkListContent(
  updatedAt: '2026-09-25',
  intro:
      'This page lists every third-party library packaged into the app at '
      'runtime, together with the permissions it touches and the data it '
      'handles. It is intended for app store review and privacy disclosure. '
      'Build-time tooling is excluded because it never ships with the app. '
      'Tap a policy link to copy it.',
  filterAll: 'All',
  filterSensitive: 'Sensitive only',
  labelVendor: 'Provider',
  labelPurpose: 'Purpose',
  labelPermissions: 'Permissions',
  labelData: 'Data collected',
  labelPolicy: 'Privacy policy',
  tapCopyHint: 'Tap to copy',
  copiedToast: 'Link copied',
  groups: <SdkGroup>[
    // —— 框架与基础工具 ——
    SdkGroup(
      title: 'Framework and utilities',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'Flutter SDK (flutter, flutter_localizations)',
          version: '3.44 / Dart 3.12+',
          vendor: 'Google LLC',
          purpose:
              'Cross-platform UI framework and the built-in Material / '
              'Cupertino localisation delegates.',
          permissions: 'None',
          data: 'Not collected',
          privacyUrl: 'https://policies.google.com/privacy',
        ),
        SdkEntry(
          name: 'intl',
          version: '0.20.3',
          vendor: 'Dart team',
          purpose: 'Date, number and message formatting for localisation.',
          permissions: 'None',
          data: 'Not collected',
          privacyUrl: 'https://pub.dev/packages/intl',
        ),
        SdkEntry(
          name: 'yaml',
          version: '3.1.4',
          vendor: 'Dart team',
          purpose: 'Parses the local environment config bundled in assets.',
          permissions: 'None',
          data: 'Not collected',
          privacyUrl: 'https://pub.dev/packages/yaml',
        ),
        SdkEntry(
          name: 'package_info_plus',
          version: '10.2.1',
          vendor: 'Flutter team (Google)',
          purpose: 'Reads the app version shown in the About section.',
          permissions: 'None',
          data: 'Not collected',
          privacyUrl: 'https://pub.dev/packages/package_info_plus',
        ),
        SdkEntry(
          name: 'flutter_screenutil_plus',
          version: '1.6.0',
          vendor: 'Community',
          purpose: 'Scales the UI to the 393x852 design baseline.',
          permissions: 'None',
          data: 'Not collected',
          privacyUrl: 'https://pub.dev/packages/flutter_screenutil_plus',
        ),
        SdkEntry(
          name: 'shared_preferences',
          version: '2.5.5',
          vendor: 'Dart team (Google)',
          purpose: 'Persists lightweight switch-style preferences (theme, '
              'language, free-use rewards and similar single bool / int '
              'values) without opening a database.',
          permissions: 'None',
          data: 'Stored on device only, never uploaded',
          privacyUrl: 'https://pub.dev/packages/shared_preferences',
        ),
        SdkEntry(
          name: 'share_plus',
          version: '13.3.0',
          vendor: 'Flutter team (Google)',
          purpose: 'Presents the system share sheet covering targets such as '
              'WeChat, mail and Messages installed on the device, used for '
              'sharing memo content and similar items.',
          permissions: 'None (handled by the system share sheet)',
          data: 'Not collected; shared content only leaves through the '
              'system sheet',
          privacyUrl: 'https://pub.dev/packages/share_plus',
        ),
      ],
    ),
    // —— 架构与网络 ——
    SdkGroup(
      title: 'Architecture and networking',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'flutter_riverpod',
          version: '3.3.2',
          vendor: 'Remi Rousselet (community)',
          purpose: 'Reactive state management shared across the app.',
          permissions: 'None',
          data: 'Not collected',
          privacyUrl: 'https://pub.dev/packages/flutter_riverpod',
        ),
        SdkEntry(
          name: 'go_router',
          version: '17.3.0',
          vendor: 'Flutter team (Google)',
          purpose: 'Declarative navigation, including the splash and tab shell.',
          permissions: 'None',
          data: 'Not collected',
          privacyUrl: 'https://pub.dev/packages/go_router',
        ),
        SdkEntry(
          name: 'dio',
          version: '5.10.0',
          vendor: 'Community',
          purpose: 'HTTP client used for outbound requests.',
          permissions: 'None (Android INTERNET needs no runtime prompt)',
          data: 'Not collected by the library itself',
          privacyUrl: 'https://pub.dev/packages/dio',
        ),
      ],
    ),
    // —— 数据与存储 ——
    SdkGroup(
      title: 'Data and storage',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'hive / hive_flutter',
          version: '2.2.3 / 1.1.0',
          vendor: 'Community',
          purpose:
              'Local key-value store for lightweight settings such as '
              'language and theme.',
          permissions: 'None',
          data: 'Stored on device only, never uploaded',
          privacyUrl: 'https://pub.dev/packages/hive',
        ),
        SdkEntry(
          name: 'isar_community (+ flutter libs)',
          version: '3.3.2',
          vendor: 'Community fork of Isar',
          purpose: 'Embedded local database for tool records.',
          permissions: 'None',
          data: 'Stored on device only, never uploaded',
          privacyUrl: 'https://pub.dev/packages/isar_community',
        ),
        SdkEntry(
          name: 'path_provider',
          version: '2.1.6',
          vendor: 'Flutter team (Google)',
          purpose: 'Resolves app directories used by the cache and database.',
          permissions: 'None',
          data: 'Not collected',
          privacyUrl: 'https://pub.dev/packages/path_provider',
        ),
        SdkEntry(
          name: 'supabase_flutter',
          version: '2.17.2',
          vendor: 'Supabase Inc.',
          purpose:
              'Email authentication, cloud profile sync and the Edge Function '
              'gateway used for anonymous usage events.',
          permissions: 'None (network access only)',
          data:
              'Email address, nickname, avatar URL, membership state and '
              'anonymous usage events',
          privacyUrl: 'https://supabase.com/privacy',
          sensitive: true,
        ),
        SdkEntry(
          name: 'sign_in_with_apple',
          version: '8.2.0',
          vendor: 'Community maintained (bridge recommended by Flutter)',
          purpose:
              'Presents the native system sheet for Sign in with Apple on iOS '
              'and macOS. Not used on Android (Apple provides no Android SDK).',
          permissions: 'None',
          data:
              'The plugin itself collects nothing; users may choose to hide '
              'their email address, in which case Apple supplies a private '
              'relay address instead of the real one',
          privacyUrl: 'https://www.apple.com/legal/privacy/data/',
        ),
        SdkEntry(
          name: 'crypto',
          version: '3.0.7',
          vendor: 'Dart team',
          purpose:
              'Computes SHA-256, used to hash the anti-replay nonce required '
              'by native Sign in with Apple.',
          permissions: 'None',
          data: 'Not collected',
          privacyUrl: 'https://pub.dev/packages/crypto',
        ),
        SdkEntry(
          name: 'google_sign_in',
          version: '6.3.0',
          vendor: 'Flutter team (Google)',
          purpose: 'Presents the system Google sign-in sheet on Android and '
              'non-Apple iOS, handing the Google identity to Supabase to mint '
              'a session as a one-tap sign-in entry.',
          permissions: 'None (handled by the system Google sheet)',
          data: 'Google account identity (idToken / accessToken) plus public '
              'profile such as avatar and nickname, used by Supabase for '
              'sign-in and session',
          privacyUrl: 'https://policies.google.com/privacy',
          sensitive: true,
        ),
        SdkEntry(
          name: 'device_info_plus',
          version: '13.2.0',
          vendor: 'Flutter team (Google)',
          purpose: 'Reads the anonymous device identifier (iOS IDFV / Android '
              'ANDROID_ID) so the free-use quota can still recognise the same '
              'device after a reinstall.',
          permissions: 'None (reading device id needs no runtime permission)',
          data: 'The identifier is SHA-256 hashed and reported as an '
              'anonymous device id that cannot be reversed to the original; '
              'used only to recognise anonymous devices, no other data is '
              'uploaded',
          privacyUrl: 'https://pub.dev/packages/device_info_plus',
          sensitive: true,
        ),
      ],
    ),
    // —— 设备能力 ——
    SdkGroup(
      title: 'Device capabilities',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'flutter_compass',
          version: '0.8.1',
          vendor: 'Community',
          purpose: 'Magnetometer heading for the compass tool.',
          permissions: 'None (magnetometer needs no runtime permission)',
          data: 'On-device only',
          privacyUrl: 'https://pub.dev/packages/flutter_compass',
        ),
        SdkEntry(
          name: 'geolocator',
          version: '14.0.3',
          vendor: 'Baseflow (Flutter community)',
          purpose: 'Altitude and coordinates shown alongside the compass.',
          permissions:
              'Location: iOS When-In-Use, Android ACCESS_FINE_LOCATION / '
              'ACCESS_COARSE_LOCATION',
          data: 'On-device only, never uploaded',
          privacyUrl: 'https://pub.dev/packages/geolocator',
          sensitive: true,
        ),
        SdkEntry(
          name: 'noise_meter',
          version: '5.1.0',
          vendor: 'Community',
          purpose: 'Microphone sampling for the noise meter tool.',
          permissions:
              'Microphone: iOS NSMicrophoneUsageDescription, Android '
              'RECORD_AUDIO',
          data: 'On-device only; no audio is recorded, saved or uploaded',
          privacyUrl: 'https://pub.dev/packages/noise_meter',
          sensitive: true,
        ),
        SdkEntry(
          name: 'sensors_plus',
          version: '7.1.0',
          vendor: 'Flutter team (Google)',
          purpose: 'Accelerometer data for the spirit level tool.',
          permissions: 'None',
          data: 'On-device only',
          privacyUrl: 'https://pub.dev/packages/sensors_plus',
        ),
        SdkEntry(
          name: 'camera',
          version: '0.12.0+2',
          vendor: 'Flutter team (Google)',
          purpose: 'Camera access used only to drive the flashlight torch.',
          permissions: 'Camera: iOS NSCameraUsageDescription, Android CAMERA',
          data: 'No image or video is captured, saved or uploaded',
          privacyUrl: 'https://pub.dev/packages/camera',
          sensitive: true,
        ),
        SdkEntry(
          name: 'permission_handler',
          version: '12.0.3',
          vendor: 'Baseflow (Flutter community)',
          purpose: 'Presents the system permission dialogs listed above.',
          permissions: 'None (it only requests permissions on behalf of the app)',
          data: 'Not collected',
          privacyUrl: 'https://pub.dev/packages/permission_handler',
        ),
      ],
    ),
    // —— 支付与评分 ——
    SdkGroup(
      title: 'Payments and reviews',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'in_app_purchase',
          version: '3.3.0',
          vendor: 'Flutter team (Google)',
          purpose: 'One-time (non-consumable) membership purchase.',
          permissions: 'None (handled by the store)',
          data:
              'The transaction is processed by Apple or Google; the app '
              'receives only the entitlement state',
          privacyUrl: 'https://www.apple.com/legal/privacy/',
          sensitive: true,
        ),
        SdkEntry(
          name: 'in_app_purchase_storekit',
          version: '0.4.13',
          vendor: 'Flutter team (Google)',
          purpose:
              'iOS StoreKit 2 APIs, used to refresh entitlements when the '
              'user taps Restore Purchases.',
          permissions: 'None (handled by the store)',
          data: 'Entitlement state only',
          privacyUrl: 'https://www.apple.com/legal/privacy/',
          sensitive: true,
        ),
        SdkEntry(
          name: 'in_app_review',
          version: '2.0.12',
          vendor: 'Flutter team (Google)',
          purpose:
              'Shows the system in-app rating prompt, falling back to the '
              'store listing when unavailable.',
          permissions: 'None',
          data: 'Not collected',
          privacyUrl: 'https://pub.dev/packages/in_app_review',
        ),
      ],
    ),
    // —— 广告变现 ——
    SdkGroup(
      title: 'Advertising',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'google_mobile_ads',
          version: '9.1.0',
          vendor: 'Google LLC',
          purpose:
              'Requests and renders adaptive banner ads within the app. '
              'No ad is requested once Pro Unlock is owned.',
          permissions: 'None declared by the app (the SDK uses the network)',
          data:
              'Device and ad-interaction data handled by Google AdMob as '
              'described in the Google privacy policy',
          privacyUrl: 'https://policies.google.com/privacy',
          sensitive: true,
        ),
      ],
    ),
    // —— In-app web view ——
    SdkGroup(
      title: 'In-app web view',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'webview_flutter',
          version: '4.14.1',
          vendor: 'Flutter team (Google)',
          purpose: 'Renders online documents (terms of service, privacy '
              'policy, SDK list links) inside the app instead of jumping to an '
              'external browser.',
          permissions: 'Network (macOS needs the '
              'com.apple.security.network.client sandbox entitlement)',
          data: 'Only loads the public document URLs specified by the app; no '
              'script is injected and the rendered content is not collected',
          privacyUrl: 'https://pub.dev/packages/webview_flutter',
        ),
      ],
    ),
  ],
  // —— 系统平台框架（非第三方 SDK，仅补充说明）——
  platformTitle: 'Platform frameworks',
  platformNote:
      'The following ship with the operating system and are not third-party '
      'SDKs. They are listed because review and privacy disclosures often ask '
      'about them. They are governed by the Apple or Google platform terms.',
  platforms: <SdkEntry>[
    SdkEntry(
      name: 'StoreKit 2 / Google Play Billing',
      version: 'System',
      vendor: 'Apple Inc. / Google LLC',
      purpose: 'Processes the one-time membership purchase.',
      permissions: 'None',
      data: 'Payment data handled by Apple or Google',
      sensitive: true,
    ),
    SdkEntry(
      name: 'Core Location / Location Services',
      version: 'System',
      vendor: 'Apple Inc. / Google LLC',
      purpose: 'Provides altitude and coordinates.',
      permissions: 'Location',
      data: 'On-device only',
      sensitive: true,
    ),
    SdkEntry(
      name: 'AVFoundation / Camera2',
      version: 'System',
      vendor: 'Apple Inc. / Google LLC',
      purpose: 'Provides torch control for the flashlight.',
      permissions: 'Camera',
      data: 'No media is captured',
      sensitive: true,
    ),
    SdkEntry(
      name: 'CoreMotion / Sensor Framework',
      version: 'System',
      vendor: 'Apple Inc. / Google LLC',
      purpose: 'Provides accelerometer, gyroscope and magnetometer samples.',
      permissions: 'None',
      data: 'On-device only',
      sensitive: true,
    ),
  ],
  // —— 说明 ——
  noteTitle: 'Notes',
  noteBody:
      'Scope: only libraries that ship in the released binary are listed. '
      'Build-time tooling such as flutter_native_splash is a dev dependency '
      'and is never distributed with the app.\n\n'
      'The data column describes how this app uses each library, not what the '
      'vendor does on its own services.\n\n'
      'Advertising: the free version shows Google AdMob banner ads at a few '
      'places within the app. No ad is requested once Pro Unlock is owned. '
      'This app does not request the App Tracking Transparency permission and '
      'does not send tool data to ad networks.\n\n'
      'Tapping a link copies it to the clipboard. No in-app browser dependency '
      'is bundled on purpose, so the app itself requests no extra permission '
      'to display this page.',
);
