// ============================================================================
// 文件：feature/profile/data/sdk_list_ja.dart
// 模块：我的 / 个人中心（profile）/ 第三方 SDK 清单 · 日文整篇
//
// 职责：
//   提供日文版「第三方 SDK 清单」的完整内容。与 sdk_list_en.dart 严格一一对应：
//   分组数量、条目顺序、sensitive 标记必须一致，否则切换语言时对应关系会错位。
//
// 维护约定：
//   1. 版本号取自 pubspec.lock 的实际解析结果（不是 pubspec.yaml 的约束区间）；
//   2. 新增 / 移除依赖时，三份文件（en / zh / ja）都要同步改；
//   3. 正文改动后请同步更新 updatedAt；
//   4. name / version / privacyUrl 三字段在多语言间保持一致，不做翻译。
// ============================================================================

import '../model/sdk_list.dart';

/// 日文版清单内容。
const SdkListContent sdkListJa = SdkListContent(
  updatedAt: '2026-09-25',
  intro:
      '本ページでは、アプリの実行時に実際にインストールパッケージに含まれる'
      'すべてのサードパーティ製ライブラリと、それぞれが関わるシステム権限および'
      'データの取り扱いについて掲載しています。アプリストアの審査およびプライバシー'
      '開示のためのものです。ビルド時にのみ使用される開発ツールはアプリとともに'
      '配布されないため、記載していません。規約のリンクをタップするとクリップボードにコピーされます。',
  filterAll: 'すべて',
  filterSensitive: '機微な項目のみ',
  labelVendor: '提供元',
  labelPurpose: '用途',
  labelPermissions: '関連する権限',
  labelData: 'データ収集',
  labelPolicy: 'プライバシーポリシー',
  tapCopyHint: 'タップしてコピー',
  copiedToast: 'リンクをコピーしました',
  groups: <SdkGroup>[
    // —— 框架与基础工具 ——
    SdkGroup(
      title: 'フレームワークと基盤ツール',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'Flutter SDK（flutter、flutter_localizations）',
          version: '3.44 / Dart 3.12+',
          vendor: 'Google LLC',
          purpose:
              'クロスプラットフォーム UI フレームワーク。Material / Cupertino 標準コンポーネントの多言語対応にも使用します。',
          permissions: 'なし',
          data: '収集しません',
          privacyUrl: 'https://policies.google.com/privacy',
        ),
        SdkEntry(
          name: 'intl',
          version: '0.20.3',
          vendor: 'Dart 公式チーム',
          purpose: '日付・数値・多言語メッセージの書式設定。',
          permissions: 'なし',
          data: '収集しません',
          privacyUrl: 'https://pub.dev/packages/intl',
        ),
        SdkEntry(
          name: 'yaml',
          version: '3.1.4',
          vendor: 'Dart 公式チーム',
          purpose: 'assets 配下に同梱されたローカル環境設定を解析します。',
          permissions: 'なし',
          data: '収集しません',
          privacyUrl: 'https://pub.dev/packages/yaml',
        ),
        SdkEntry(
          name: 'package_info_plus',
          version: '10.2.1',
          vendor: 'Flutter 公式チーム（Google）',
          purpose: 'アプリのバージョン番号を取得し、「アプリについて」の表示に使用します。',
          permissions: 'なし',
          data: '収集しません',
          privacyUrl: 'https://pub.dev/packages/package_info_plus',
        ),
        SdkEntry(
          name: 'flutter_screenutil_plus',
          version: '1.6.0',
          vendor: 'コミュニティ保守',
          purpose: '393×852 のデザイン基準に基づく画面サイズの調整を行います。',
          permissions: 'なし',
          data: '収集しません',
          privacyUrl: 'https://pub.dev/packages/flutter_screenutil_plus',
        ),
        SdkEntry(
          name: 'shared_preferences',
          version: '2.5.5',
          vendor: 'Dart 公式チーム（Google）',
          purpose:
              'テーマ・言語・無料回数のボーナスなど、単一の bool / int 値を保存します。データベースを開かずに読み書きできます。',
          permissions: 'なし',
          data: '端末内のみに保存し、アップロードしません',
          privacyUrl: 'https://pub.dev/packages/shared_preferences',
        ),
        SdkEntry(
          name: 'share_plus',
          version: '13.3.0',
          vendor: 'Flutter 公式チーム（Google）',
          purpose:
              '端末にインストールされている各種アプリを宛先としてシステムの共有パネルを開き、メモなどの内容を共有します。',
          permissions: 'なし（システムの共有パネルが処理します）',
          data: '収集しません。共有内容はシステムの共有パネルを通じてのみ送出されます',
          privacyUrl: 'https://pub.dev/packages/share_plus',
        ),
      ],
    ),
    // —— 架构与网络 ——
    SdkGroup(
      title: 'アーキテクチャとネットワーク',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'flutter_riverpod',
          version: '3.3.2',
          vendor: 'Remi Rousselet（コミュニティ保守）',
          purpose: 'アプリ全体で共有するリアクティブな状態管理。',
          permissions: 'なし',
          data: '収集しません',
          privacyUrl: 'https://pub.dev/packages/flutter_riverpod',
        ),
        SdkEntry(
          name: 'go_router',
          version: '17.3.0',
          vendor: 'Flutter 公式チーム（Google）',
          purpose: '宣言的ルーティング。起動画面と下部タブのナビゲーションを担います。',
          permissions: 'なし',
          data: '収集しません',
          privacyUrl: 'https://pub.dev/packages/go_router',
        ),
        SdkEntry(
          name: 'dio',
          version: '5.10.0',
          vendor: 'コミュニティ保守',
          purpose: 'HTTP クライアント。外部へのネットワークリクエストに使用します。',
          permissions: 'なし（Android の INTERNET 権限は実行時の申請が不要です）',
          data: 'ライブラリ自体はデータを一切収集しません',
          privacyUrl: 'https://pub.dev/packages/dio',
        ),
      ],
    ),
    // —— 数据与存储 ——
    SdkGroup(
      title: 'データとストレージ',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'hive / hive_flutter',
          version: '2.2.3 / 1.1.0',
          vendor: 'コミュニティ保守',
          purpose: 'ローカルのキーバリューストア。言語やテーマなどの軽量な設定を保存します。',
          permissions: 'なし',
          data: '端末内のみに保存し、アップロードしません',
          privacyUrl: 'https://pub.dev/packages/hive',
        ),
        SdkEntry(
          name: 'isar_community（含 flutter libs）',
          version: '3.3.2',
          vendor: 'Isar コミュニティ保守ブランチ',
          purpose: 'ローカル組み込みデータベース。各ツールの記録を保存します。',
          permissions: 'なし',
          data: '端末内のみに保存し、アップロードしません',
          privacyUrl: 'https://pub.dev/packages/isar_community',
        ),
        SdkEntry(
          name: 'path_provider',
          version: '2.1.6',
          vendor: 'Flutter 公式チーム（Google）',
          purpose: 'アプリのディレクトリを解決し、キャッシュの削除やデータベースで使用します。',
          permissions: 'なし',
          data: '収集しません',
          privacyUrl: 'https://pub.dev/packages/path_provider',
        ),
        SdkEntry(
          name: 'supabase_flutter',
          version: '2.17.2',
          vendor: 'Supabase Inc.',
          purpose:
              'メールアドレスでの登録・ログイン、クラウド上のプロフィール同期、および匿名のイベント送信を担う Edge Function ゲートウェイ。',
          permissions: 'なし（ネットワークのみ使用）',
          data: 'メールアドレス、ニックネーム、アバターの URL、会員特典の状態、匿名の利用イベント',
          privacyUrl: 'https://supabase.com/privacy',
          sensitive: true,
        ),
        SdkEntry(
          name: 'sign_in_with_apple',
          version: '8.2.0',
          vendor: 'コミュニティ保守（Flutter 公式が推奨するブリッジプラグイン）',
          purpose:
              'iOS / macOS でシステム標準の「Apple でサインイン」認証画面を開き、ワンタップでの登録とログインに使用します。'
              'Android では本プラグインを使用しません（Apple が Android 向け SDK を提供していないため）。',
          permissions: 'なし',
          data:
              'プラグイン自体はデータを収集しません。認証時に「メールアドレスを非公開」を選択した場合、'
              '実際のアドレスではなく Apple のプライベートリレーのメールアドレスが提供されます',
          privacyUrl: 'https://www.apple.com/legal/privacy/data/',
        ),
        SdkEntry(
          name: 'crypto',
          version: '3.0.7',
          vendor: 'Dart 公式チーム',
          purpose:
              'SHA-256 の計算。Apple のネイティブサインインで、リプレイ攻撃防止用のランダム値（nonce）をハッシュ化するために使用します。',
          permissions: 'なし',
          data: '収集しません',
          privacyUrl: 'https://pub.dev/packages/crypto',
        ),
        SdkEntry(
          name: 'google_sign_in',
          version: '6.3.0',
          vendor: 'Flutter 公式チーム（Google）',
          purpose:
              'Android および（Apple 以外の）iOS でシステムレベルの Google 認証を起動し、取得した Google アカウントの識別子を Supabase でログインセッションに交換します。ワンタップログインの入口として使用します。',
          permissions: 'なし（システムの Google 認証画面が処理します）',
          data:
              'Google アカウントの識別子（idToken / accessToken）とアバター・ニックネームなどの公開プロフィール。Supabase がログインとセッションに使用します',
          privacyUrl: 'https://policies.google.com/privacy',
          sensitive: true,
        ),
        SdkEntry(
          name: 'device_info_plus',
          version: '13.2.0',
          vendor: 'Flutter 公式チーム（Google）',
          purpose:
              'ゲスト端末の一意識別子（iOS の IDFV / Android の ANDROID_ID）を取得し、再インストール後も無料利用回数を同一端末として識別できるようにします。',
          permissions: 'なし（端末識別子の取得に実行時の権限は不要です）',
          data:
              '端末識別子は SHA-256 でハッシュ化した匿名の端末 ID として送信され、元の ID には復元できません。'
              '匿名ゲスト端末の識別のみに使用し、それ以外のデータはアップロードしません',
          privacyUrl: 'https://pub.dev/packages/device_info_plus',
          sensitive: true,
        ),
      ],
    ),
    // —— 设备能力 ——
    SdkGroup(
      title: 'デバイス機能',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'flutter_compass',
          version: '0.8.1',
          vendor: 'コミュニティ保守',
          purpose: '磁力計の方位角を取得し、方位磁針ツールで使用します。',
          permissions: 'なし（磁力計に実行時の権限は不要です）',
          data: '端末内でのみ処理します',
          privacyUrl: 'https://pub.dev/packages/flutter_compass',
        ),
        SdkEntry(
          name: 'geolocator',
          version: '14.0.3',
          vendor: 'Baseflow（Flutter コミュニティ）',
          purpose: '標高と緯度・経度を取得し、方位磁針の結果とあわせて表示します。',
          permissions:
              '位置情報：iOS はアプリの使用中のみ / Android は ACCESS_FINE_LOCATION、ACCESS_COARSE_LOCATION',
          data: '端末内でのみ処理し、アップロードしません',
          privacyUrl: 'https://pub.dev/packages/geolocator',
          sensitive: true,
        ),
        SdkEntry(
          name: 'noise_meter',
          version: '5.1.0',
          vendor: 'コミュニティ保守',
          purpose: 'マイクのサンプリング。騒音測定ツールで使用します。',
          permissions: 'マイク：iOS NSMicrophoneUsageDescription / Android RECORD_AUDIO',
          data: '端末内でのみ処理し、録音・保存・アップロードを行いません',
          privacyUrl: 'https://pub.dev/packages/noise_meter',
          sensitive: true,
        ),
        SdkEntry(
          name: 'sensors_plus',
          version: '7.1.0',
          vendor: 'Flutter 公式チーム（Google）',
          purpose: '加速度センサーのデータを取得し、水準器ツールで使用します。',
          permissions: 'なし',
          data: '端末内でのみ処理します',
          privacyUrl: 'https://pub.dev/packages/sensors_plus',
        ),
        SdkEntry(
          name: 'camera',
          version: '0.12.0+2',
          vendor: 'Flutter 公式チーム（Google）',
          purpose: 'カメラにアクセスします。フラッシュ（懐中電灯）の制御のみに使用します。',
          permissions: 'カメラ：iOS NSCameraUsageDescription / Android CAMERA',
          data: '画像や動画の撮影・保存・アップロードは一切行いません',
          privacyUrl: 'https://pub.dev/packages/camera',
          sensitive: true,
        ),
        SdkEntry(
          name: 'permission_handler',
          version: '12.0.3',
          vendor: 'Baseflow（Flutter コミュニティ）',
          purpose: '上記の各システム権限の許可ダイアログを表示します。',
          permissions: 'なし（本アプリの権限申請を代行するのみ）',
          data: '収集しません',
          privacyUrl: 'https://pub.dev/packages/permission_handler',
        ),
      ],
    ),
    // —— 支付与评分 ——
    SdkGroup(
      title: '決済とレビュー',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'in_app_purchase',
          version: '3.3.0',
          vendor: 'Flutter 公式チーム（Google）',
          purpose: '買い切り型（非消耗型）の会員アプリ内課金。',
          permissions: 'なし（アプリストアが処理します）',
          data: '取引は Apple または Google が処理し、本アプリは特典の状態のみを取得します',
          privacyUrl: 'https://www.apple.com/legal/privacy/',
          sensitive: true,
        ),
        SdkEntry(
          name: 'in_app_purchase_storekit',
          version: '0.4.13',
          vendor: 'Flutter 公式チーム（Google）',
          purpose: 'iOS の StoreKit 2 インターフェース。「購入を復元」をタップしたときに特典を更新します。',
          permissions: 'なし（アプリストアが処理します）',
          data: '特典の状態のみ',
          privacyUrl: 'https://www.apple.com/legal/privacy/',
          sensitive: true,
        ),
        SdkEntry(
          name: 'in_app_review',
          version: '2.0.12',
          vendor: 'Flutter 公式チーム（Google）',
          purpose:
              'システムのアプリ内レビュー画面を開きます。利用できない場合はストアの詳細ページにフォールバックします。',
          permissions: 'なし',
          data: '収集しません',
          privacyUrl: 'https://pub.dev/packages/in_app_review',
        ),
      ],
    ),
    // —— 广告变现 ——
    SdkGroup(
      title: '広告収益化',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'google_mobile_ads',
          version: '9.1.0',
          vendor: 'Google LLC',
          purpose:
              'アプリ内の一部ページでアダプティブバナー広告をリクエスト・表示します。Pro Unlock を購入すると広告のリクエストを中止します。',
          permissions: '本アプリは追加の権限を宣言していません（SDK はネットワークを使用します）',
          data:
              '端末および広告のインタラクションに関するデータは Google AdMob が処理します。詳細は Google のプライバシーポリシーをご確認ください',
          privacyUrl: 'https://policies.google.com/privacy',
          sensitive: true,
        ),
      ],
    ),
    // —— 应用内网页容器 ——
    SdkGroup(
      title: 'アプリ内ウェブビュー',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'webview_flutter',
          version: '4.14.1',
          vendor: 'Flutter 公式チーム（Google）',
          purpose:
              '利用規約、プライバシーポリシー、SDK 一覧のリンクなどのオンラインドキュメントをアプリ内で直接表示し、外部ブラウザに遷移することによる分断を避けます。',
          permissions:
              'ネットワーク（macOS では com.apple.security.network.client のサンドボックス権限が必要です）',
          data: '本アプリが指定した公開ドキュメントの URL のみを読み込みます。スクリプトの注入や表示内容の収集は行いません',
          privacyUrl: 'https://pub.dev/packages/webview_flutter',
        ),
      ],
    ),
  ],
  // —— 系统平台框架（非第三方 SDK，仅补充说明）——
  platformTitle: 'システムプラットフォームのフレームワーク',
  platformNote:
      '以下のフレームワークは OS が提供するもので、サードパーティ製 SDK には該当しません。'
      '補足として掲載しています（アプリストアの審査やプライバシー開示でよく問われるため）。'
      'これらは Apple または Google の各プラットフォーム規約に従います。',
  platforms: <SdkEntry>[
    SdkEntry(
      name: 'StoreKit 2 / Google Play Billing',
      version: 'システム内蔵',
      vendor: 'Apple Inc. / Google LLC',
      purpose: '買い切り型会員の決済を処理します。',
      permissions: 'なし',
      data: '決済データは Apple または Google が処理します',
      sensitive: true,
    ),
    SdkEntry(
      name: 'Core Location / 位置情報サービス',
      version: 'システム内蔵',
      vendor: 'Apple Inc. / Google LLC',
      purpose: '標高と緯度・経度を提供します。',
      permissions: '位置情報',
      data: '端末内でのみ処理します',
      sensitive: true,
    ),
    SdkEntry(
      name: 'AVFoundation / Camera2',
      version: 'システム内蔵',
      vendor: 'Apple Inc. / Google LLC',
      purpose: 'フラッシュ（懐中電灯）の制御機能を提供します。',
      permissions: 'カメラ',
      data: 'メディアコンテンツは一切取得しません',
      sensitive: true,
    ),
    SdkEntry(
      name: 'CoreMotion / センサーフレームワーク',
      version: 'システム内蔵',
      vendor: 'Apple Inc. / Google LLC',
      purpose: '加速度計、ジャイロスコープ、磁力計のサンプリングを提供します。',
      permissions: 'なし',
      data: '端末内でのみ処理します',
      sensitive: true,
    ),
  ],
  // —— 说明 ——
  noteTitle: 'ご注意',
  noteBody:
      '集計範囲：リリースパッケージに含まれ、実行時に実際に動作するライブラリのみを'
      '掲載しています。flutter_native_splash などビルド時にのみ使用する開発依存は'
      'アプリとともに配布されないため記載していません。\n\n'
      '「データ収集」の欄は本アプリにおける各ライブラリの利用方法を示すものであり、'
      '提供元が自社サービスで行うデータ処理を示すものではありません。\n\n'
      '広告について：無料版ではアプリ内の一部ページに Google AdMob のバナー広告を'
      '表示します。Pro Unlock を購入すると広告のリクエスト・表示を行いません。'
      '本アプリは「App Tracking Transparency」の許可を要求せず、ツールの利用データを'
      '広告ネットワークに送信することもありません。\n\n'
      'リンクをタップするとクリップボードにコピーされます。本ページでは意図的に'
      'アプリ内ブラウザの依存を追加していないため、このページを表示するだけで'
      '追加の権限が必要になることはありません。',
);
