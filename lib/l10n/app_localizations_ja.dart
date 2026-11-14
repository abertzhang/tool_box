// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'テーマデモ';

  @override
  String get profile => 'プロフィール';

  @override
  String get tools => 'ツール';

  @override
  String get login => 'ログイン';

  @override
  String get registerTitle => 'アカウント作成';

  @override
  String get nicknameHint => 'ニックネーム（任意）';

  @override
  String get emailHint => 'メールアドレス';

  @override
  String get passwordHint => 'パスワード';

  @override
  String get confirmPasswordHint => 'パスワード（確認）';

  @override
  String get registerSubmit => '新規登録';

  @override
  String get googleSignUp => 'Googleで続ける';

  @override
  String get appleSignUp => 'Appleで続ける';

  @override
  String get appleSignIn => 'Appleでログイン';

  @override
  String get googleSignIn => 'Googleでログイン';

  @override
  String get emailSignIn => 'メールアドレスでログイン';

  @override
  String get haveAccountLogin => 'すでにアカウントをお持ちの方はログイン';

  @override
  String get errEmailInvalid => '有効なメールアドレスを入力してください';

  @override
  String get errPasswordShort => 'パスワードは6文字以上で入力してください';

  @override
  String get errNetworkReset =>
      'サーバーとの接続が切断されました。別のWi-Fi/モバイル回線に切り替えるか、プロキシ/VPNをオフにしてから再試行してください';

  @override
  String get errPasswordMismatch => 'パスワードが一致しません';

  @override
  String get registerSuccess => '登録が完了しました';

  @override
  String get loginSubtitle => 'ポケットツールボックス · ログインしてすべての機能を解放';

  @override
  String get loginSubmit => 'ログイン';

  @override
  String get loginSuccess => 'ログインしました';

  @override
  String get forgotPassword => 'パスワードをお忘れですか？';

  @override
  String get forgotPasswordDesc => 'メールアドレスを入力いただくと、パスワード再設定用のリンクをお送りします。';

  @override
  String get sendResetLink => '再設定リンクを送信';

  @override
  String get resetPasswordSent => 'パスワード再設定リンクを送信しました';

  @override
  String get emailNotRegistered => 'このメールアドレスのアカウントは見つかりません';

  @override
  String get emailCheckFailed => 'メールアドレスを確認できませんでした。もう一度お試しください。';

  @override
  String get resetPasswordTitle => '新しいパスワードを設定';

  @override
  String get resetPasswordDesc => 'アカウントの新しいパスワードを設定してください。';

  @override
  String get newPasswordHint => '新しいパスワード';

  @override
  String get resetPasswordSubmit => 'パスワードを更新';

  @override
  String get resetPasswordSuccess => 'パスワードを更新しました。再度ログインしてください。';

  @override
  String get resetLinkInvalid => 'この再設定リンクは無効または期限切れです。新しいリンクを再発行してください。';

  @override
  String get registerVerifyEmail => '登録が完了しました。メールをご確認のうえ、認証を行ってください。';

  @override
  String get verifyEmailTitle => 'メールアドレスを認証';

  @override
  String get verifyEmailDesc =>
      '6桁の認証コードをメールでお送りしました。以下の欄に入力してアカウントを有効化してください。';

  @override
  String get verifyCodeHint => '6桁のコード';

  @override
  String get verifyEmailSubmit => '認証する';

  @override
  String get verifyEmailResend => 'コードを再送信';

  @override
  String get verifyEmailResent => '新しいコードを送信しました';

  @override
  String get verifyEmailResendFailed => 'コードを再送信できませんでした。もう一度お試しください。';

  @override
  String get verifyEmailSuccess => 'メールアドレスの認証が完了しました';

  @override
  String get verifyEmailContinue => '次へ';

  @override
  String get errCodeInvalid => 'コードが無効または期限切れです';

  @override
  String get errSupabaseNotReady =>
      'Supabaseが初期化されていません。--dart-defineでSUPABASE_URLとSUPABASE_ANON_KEYを指定してください。';

  @override
  String get compassTitle => '方位磁針';

  @override
  String get compassSensorUnavailable => 'この端末ではコンパスを利用できません';

  @override
  String get compassLock => '方位を固定';

  @override
  String get compassUnlock => '固定を解除';

  @override
  String get compassDirN => 'N';

  @override
  String get compassDirNE => 'NE';

  @override
  String get compassDirE => 'E';

  @override
  String get compassDirSE => 'SE';

  @override
  String get compassDirS => 'S';

  @override
  String get compassDirSW => 'SW';

  @override
  String get compassDirW => 'W';

  @override
  String get compassDirNW => 'NW';

  @override
  String get compassHeading => '方位角';

  @override
  String get compassAltitude => '標高';

  @override
  String get compassLatitude => '緯度';

  @override
  String get compassLongitude => '経度';

  @override
  String get compassRecordLocation => '位置を記録';

  @override
  String get compassExport => '書き出し';

  @override
  String get compassHistory => '履歴';

  @override
  String get compassViewAll => 'すべて表示';

  @override
  String get compassCollapse => '折りたたむ';

  @override
  String get compassNoRecords => 'まだ記録がありません。「位置を記録」をタップして地点を保存してください';

  @override
  String get compassRecordDialogTitle => '位置を記録';

  @override
  String get compassRecordNameHint => '名称（例：キャンプ場A）';

  @override
  String get compassSave => '保存';

  @override
  String get compassCancel => 'キャンセル';

  @override
  String get compassRecordSaved => '記録を保存しました';

  @override
  String get compassSaveFailed => '保存に失敗しました。もう一度お試しください';

  @override
  String get compassLocationDenied => '位置情報の権限がオフのため、座標を取得できません';

  @override
  String get compassLocationServiceOff => '位置情報サービスがオフです。設定からオンにしてください';

  @override
  String get compassOpenSettings => '設定を開く';

  @override
  String get compassExported => 'すべての記録をクリップボードにコピーしました';

  @override
  String get compassDelete => '削除';

  @override
  String get compassDeleteConfirm => 'この記録を削除しますか？';

  @override
  String get compassLatLng => '座標';

  @override
  String get compassDirection => '方位';

  @override
  String get noiseTitle => '騒音測定器';

  @override
  String get noiseCurrent => '現在値';

  @override
  String get noiseAverage => '平均値';

  @override
  String get noiseMin => '最小値';

  @override
  String get noiseMax => '最大値';

  @override
  String get noiseRecord => '騒音を記録';

  @override
  String get noiseExport => '書き出し';

  @override
  String get noiseHistory => '履歴';

  @override
  String get noiseViewAll => 'すべて表示';

  @override
  String get noiseCollapse => '折りたたむ';

  @override
  String get noiseNoRecords => 'まだ記録がありません';

  @override
  String get noiseNoReading => 'まだ測定値がありません。しばらくお待ちください';

  @override
  String get noiseZoneQuiet => '静か';

  @override
  String get noiseZoneModerate => 'やや大きい';

  @override
  String get noiseZoneLoud => '大きい';

  @override
  String get noiseZoneQuietEnv => '静かな環境';

  @override
  String get noiseZoneModerateEnv => '中程度の環境';

  @override
  String get noiseZoneLoudEnv => '騒がしい環境';

  @override
  String get noiseCatQuiet => '静か';

  @override
  String get noiseCatModerate => '普通';

  @override
  String get noiseCatLoud => '大きい';

  @override
  String get noiseEnvType => '環境';

  @override
  String get noiseLevel => 'レベル';

  @override
  String get noiseDbUnit => 'dB';

  @override
  String get noiseRecordTitle => '騒音を記録';

  @override
  String get noiseName => '名称';

  @override
  String get noiseNameHint => '名称を入力（例：「キャンプ場周辺」）';

  @override
  String get noiseEnvHint => '環境の種類（任意、例：「林の中」）';

  @override
  String get noiseSave => '保存';

  @override
  String get noiseCancel => 'キャンセル';

  @override
  String get noiseSaved => '端末に保存しました';

  @override
  String get noiseExported => 'クリップボードに書き出しました';

  @override
  String get noiseDelete => '削除';

  @override
  String get noiseDeleteConfirm => 'この記録を削除しますか？';

  @override
  String get noiseMicDenied => 'マイクの権限が拒否されています';

  @override
  String get noiseMicNeedPermission => '騒音を測定するにはマイクへのアクセスが必要です';

  @override
  String get noiseMicRetry => '再試行して許可する';

  @override
  String get noiseMicGrant => '許可して測定を開始';

  @override
  String get noiseMicOpenSettings => '設定を開く';

  @override
  String get commonOpenSettings => '設定を開く';

  @override
  String get noiseToday => '今日';

  @override
  String get noiseYesterday => '昨日';

  @override
  String get levelTitle => '水準器';

  @override
  String get levelBullseye => '丸型水準器';

  @override
  String get levelTubular => '管型水準器';

  @override
  String get levelCalibrated => '調整済み';

  @override
  String get levelUncalibrated => '未調整';

  @override
  String get levelStatusLabel => '状態';

  @override
  String get levelStatusLevel => '水平';

  @override
  String get levelStatusNear => 'ほぼ水平';

  @override
  String get levelStatusTilt => '傾きあり';

  @override
  String get levelVertical => '垂直（Y軸）';

  @override
  String get levelHorizontal => '水平（X軸）';

  @override
  String get levelLock => '表示を固定';

  @override
  String get levelUnlock => '固定解除';

  @override
  String get levelCalibrate => '調整';

  @override
  String get levelCalibratedToast => '現在の角度に調整しました';

  @override
  String get levelHistory => '測定記録';

  @override
  String get levelSave => '保存';

  @override
  String get levelViewAll => 'すべて表示';

  @override
  String get levelCollapse => '折りたたむ';

  @override
  String get levelNoRecords => 'まだ記録がありません';

  @override
  String get levelRecordTitle => '測定を保存';

  @override
  String get levelName => '名称';

  @override
  String get levelNameHint => '名称（任意）';

  @override
  String get levelCancel => 'キャンセル';

  @override
  String get levelSaveAction => '保存';

  @override
  String get levelSavedToast => '測定結果を保存しました';

  @override
  String get levelDelete => '削除';

  @override
  String get levelDeleteConfirm => 'この測定結果を削除しますか？';

  @override
  String get levelDefaultName => '水準器の測定';

  @override
  String get appShareSubject => 'Tool Box - アウトドアツールボックス';

  @override
  String get appShareBody => '水準器、定規、方位磁針、騒音計、懐中電灯などを1つにまとめたアプリ。屋外作業や日々の作業に。';

  @override
  String get appShareFailed => '共有画面を開けませんでした';

  @override
  String get levelDescLevel => '完全に水平です';

  @override
  String get levelDescNear => 'ほぼ水平です';

  @override
  String get levelDescTilt => '水平になっていません';

  @override
  String get rulerTitle => '定規';

  @override
  String get rulerUnitCm => 'cm';

  @override
  String get rulerUnitInch => 'インチ';

  @override
  String get rulerLengthLabel => '長さ';

  @override
  String get rulerCm => 'cm';

  @override
  String get rulerInch => 'インチ';

  @override
  String get rulerTime => '時刻';

  @override
  String get rulerName => '名称';

  @override
  String get rulerNameHint => 'この測定の名称（任意）';

  @override
  String get rulerRecordTitle => '測定を保存';

  @override
  String get rulerCancel => 'キャンセル';

  @override
  String get rulerSaveAction => '保存';

  @override
  String get rulerSavedToast => '測定結果を保存しました';

  @override
  String get rulerExport => '書き出し';

  @override
  String get rulerExported => 'クリップボードに書き出しました';

  @override
  String get rulerHistory => '測定記録';

  @override
  String get rulerNoRecords => 'まだ測定結果がありません';

  @override
  String get rulerViewAll => 'すべて表示';

  @override
  String get rulerCollapse => '折りたたむ';

  @override
  String get rulerDelete => '削除';

  @override
  String get rulerDeleteConfirm => 'この測定結果を削除しますか？';

  @override
  String get rulerDefaultName => '定規の測定';

  @override
  String get flashlightOn => '点灯';

  @override
  String get flashlightPermissionDenied =>
      '懐中電灯を使うにはカメラの権限が必要です。設定から有効にしてください。';

  @override
  String get flashlightUnavailable => 'この端末は懐中電灯に対応していません';

  @override
  String get tideTitle => '潮汐';

  @override
  String get tideRecordCurrent => '現在を記録';

  @override
  String get tideExported => 'クリップボードに書き出しました';

  @override
  String get tideScheduleTitle => '本日の潮汐スケジュール';

  @override
  String get tideCurrentHeight => '現在の潮位';

  @override
  String tideTimeToHigh(Object time) {
    return '満潮まで$time';
  }

  @override
  String get tideNextLow => '次の干潮';

  @override
  String get tideNextHigh => '次の満潮';

  @override
  String get tideHistory => '履歴';

  @override
  String get tideViewAll => 'すべて表示';

  @override
  String get tideCollapse => '折りたたむ';

  @override
  String get tideLowTide => '干潮';

  @override
  String get tideHighTide => '満潮';

  @override
  String get tideRising => '上げ潮';

  @override
  String get tideNoRecords => 'まだ潮汐の記録がありません';

  @override
  String get tideSavedToast => '現在の潮汐を記録しました';

  @override
  String get toolWorldClock => '世界時計';

  @override
  String get toolWorldClockDesc => '世界各地の時刻';

  @override
  String get worldClockTitle => '世界時計';

  @override
  String get worldClockLocalLabel => '現地時刻';

  @override
  String get worldClockLocLabel => '現在地';

  @override
  String get worldClockLocating => '位置を取得中…';

  @override
  String get worldClockLocFailed => '位置情報を取得できないため、端末の時刻を表示しています';

  @override
  String get worldClockCityBeijing => '北京';

  @override
  String get worldClockCityTokyo => '東京';

  @override
  String get worldClockCitySingapore => 'シンガポール';

  @override
  String get worldClockCitySydney => 'シドニー';

  @override
  String get worldClockCityDubai => 'ドバイ';

  @override
  String get worldClockCityLondon => 'ロンドン';

  @override
  String get worldClockCityParis => 'パリ';

  @override
  String get worldClockCityNewYork => 'ニューヨーク';

  @override
  String get worldClockCityLosAngeles => 'ロサンゼルス';

  @override
  String get worldClockRegion => '国・地域';

  @override
  String get worldClockSelectRegion => '国・地域を選択';

  @override
  String get worldClockSelectCity => '都市を選択';

  @override
  String get worldClockCountryCn => '中国';

  @override
  String get worldClockCountryJp => '日本';

  @override
  String get worldClockCountrySg => 'シンガポール';

  @override
  String get worldClockCountryAu => 'オーストラリア';

  @override
  String get worldClockCountryAe => 'アラブ首長国連邦';

  @override
  String get worldClockCountryGb => 'イギリス';

  @override
  String get worldClockCountryFr => 'フランス';

  @override
  String get worldClockCountryUs => 'アメリカ';

  @override
  String get ucTitle => '単位変換';

  @override
  String get ucFormula => '計算式: ';

  @override
  String get ucCommon => 'よく使う変換';

  @override
  String get forceTitle => '力・荷重変換';

  @override
  String get memoTitle => '旅行メモ';

  @override
  String get memoAdd => '新しいメモ';

  @override
  String get memoEmpty => 'メモがありません。「+」をタップして作成しましょう';

  @override
  String get memoTitleHint => 'タイトル';

  @override
  String get memoFieldTitle => 'タイトル';

  @override
  String get memoTravelTime => '旅行時期';

  @override
  String get memoTravelTimeHint => '日時を選択';

  @override
  String get memoKeyHint => '項目';

  @override
  String get memoValueHint => '内容';

  @override
  String get memoAddRow => '行を追加';

  @override
  String get memoSave => '保存';

  @override
  String get memoUntitled => '無題';

  @override
  String get memoNoContent => '内容なし';

  @override
  String get memoDelete => '削除';

  @override
  String get memoDeleteConfirm => 'このメモを削除しますか？';

  @override
  String get memoCancel => 'キャンセル';

  @override
  String get memoEdit => '編集';

  @override
  String get memoTemplateTitle => 'テンプレート';

  @override
  String get memoUseTemplate => '使う';

  @override
  String get memoTemplateApplied => 'テンプレートを適用しました';

  @override
  String get memoTemplateHint => 'テンプレートを選ぶと、すぐにメモを作成できます';

  @override
  String get memoNewTemplate => '新しいテンプレート';

  @override
  String get memoTemplateEmpty => 'テンプレートがありません。「+」をタップして作成しましょう';

  @override
  String get memoTemplateDeleteConfirm => 'このテンプレートを削除しますか？';

  @override
  String get memoDaysLeftPrefix => '';

  @override
  String get memoDaysLeftSuffix => '日後';

  @override
  String get memoTodayDepart => '本日出発';

  @override
  String get memoDeparted => '出発済み';

  @override
  String get memoShare => '共有';

  @override
  String get memoCopy => 'コピー';

  @override
  String get memoCopied => 'コピーしました';

  @override
  String get memoSaveAsTemplate => 'テンプレートとして保存';

  @override
  String get memoTemplateCreated => 'テンプレートとして保存しました';

  @override
  String get memoExpand => '展開';

  @override
  String get memoCollapse => '折りたたむ';

  @override
  String get memoDeleted => '削除しました';

  @override
  String get memoUndo => '元に戻す';

  @override
  String get statToolsUsed => '利用ツール数';

  @override
  String get statAppToolUsage => 'アプリ累計利用回数';

  @override
  String get statFreeRemaining => '残り無料回数';

  @override
  String get vipTitle => 'プロ版アンロック';

  @override
  String get vipDesc => '買い切り・広告なし';

  @override
  String get vipOpen => '今すぐアップグレード';

  @override
  String freeRemainingCount(num count) {
    return '残り$count回、無料で使えます';
  }

  @override
  String get freeLimitTitle => '無料利用回数を使い切りました';

  @override
  String get freeLimitBody => '無料利用の上限（10回）に達しました。プロ版にアップグレードするとすべてのツールが使えます。';

  @override
  String get freeLimitUpgrade => 'プロ版にアップグレード';

  @override
  String get vipSheetProductName => 'プロ版アンロック';

  @override
  String get vipSheetProductDesc => '永久会員権';

  @override
  String get vipSheetOneTime => '買い切り';

  @override
  String get vipSheetConfirm => 'サイドボタンで確定';

  @override
  String get vipDeveloping => '会員機能は準備中です';

  @override
  String get vipPayConfirmTitle => '購入の確認';

  @override
  String vipPayConfirmBody(Object price) {
    return '永久会員権を$priceで購入します。買い切りのため、Apple IDまたはGoogleアカウントで復元できます。';
  }

  @override
  String get vipPayStoreUnavailable => 'ストアを利用できません。しばらくしてからお試しください';

  @override
  String get vipPayProductMissing => '会員商品はまだ利用できません';

  @override
  String get vipPayDebugProductMissing =>
      'デバッグ版ではPlayの商品を照会できません。Playの内部アプリ共有または内部テスト経由でインストールしてから購入してください。';

  @override
  String get vipPaySheetOpened => '決済画面を開きました。お支払い完了後に会員権が有効になります';

  @override
  String get vipRestore => '購入を復元';

  @override
  String get vipRestoreDone => '復元が完了しました。過去に購入済みの場合は会員権が有効になります';

  @override
  String get vipRestoreEmpty => 'このアカウントに購入履歴が見つかりません';

  @override
  String get vipRestoreCheckAccount =>
      '購入履歴が見つかりません。復元はこの端末にサインインしているGoogle Playアカウントのみを確認するため、購入時に使ったアカウントと同じかご確認ください';

  @override
  String get vipRestoreAlready => 'すでにプロ会員です。復元の必要はありません';

  @override
  String get vipBecomeMember => '会員権が有効になりました';

  @override
  String get syncMemberTitle => 'プロ版をアカウントに同期';

  @override
  String get syncMemberBody => 'サインインすると、すべての端末でプロ版が使え、再インストール後も復元できます。';

  @override
  String get syncMemberApple => 'Appleで続ける';

  @override
  String get syncMemberGoogle => 'Googleで続ける';

  @override
  String get syncMemberLater => '後で';

  @override
  String get syncMemberDone => 'プロ版をアカウントに同期しました';

  @override
  String get syncMemberFailed => '同期に失敗しました。しばらくしてからお試しください';

  @override
  String get syncMemberAction => 'プロ版をアカウントに同期';

  @override
  String get vipPurchaseAppBarTitle => 'Tool Box プロ版アンロック';

  @override
  String get vipPurchaseSubtitle => 'すべてのツールが解放されます。買い切り・広告なし。';

  @override
  String get statOffline => 'オフライン保存';

  @override
  String get statCert => 'マイ証明書';

  @override
  String get statRecord => '学習記録';

  @override
  String get countFiles => '5ファイル';

  @override
  String get countCert => '3枚';

  @override
  String get countDays => '12日間';

  @override
  String get countFav => '128件';

  @override
  String get settings => '設定';

  @override
  String get themeColorSetting => 'テーマ';

  @override
  String get themeCoffee => 'コーヒー';

  @override
  String get themeBlue => 'スカイ';

  @override
  String get langSetting => '言語';

  @override
  String get saveNamePromptSetting => '保存ダイアログ';

  @override
  String get clearCache => 'キャッシュを削除';

  @override
  String get calculating => '計算中…';

  @override
  String get notifSetting => '通知';

  @override
  String get notifDeveloping => '通知機能は準備中です';

  @override
  String get accountSecurity => 'アカウントとセキュリティ';

  @override
  String get accountDeveloping => 'アカウントとセキュリティは準備中です';

  @override
  String get aboutGroup => 'アプリについて';

  @override
  String get checkUpdate => 'アップデートを確認';

  @override
  String get rateUs => '評価する';

  @override
  String get rateUsUnavailable => '現在レビューページを開けません。しばらくしてからお試しください';

  @override
  String get aboutUs => '私たちについて';

  @override
  String get userAgreement => '利用規約';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String privacyLastUpdated(String date) {
    return '最終更新日: $date';
  }

  @override
  String get privacyIntro =>
      '本プライバシーポリシーは、本アプリのご利用にあたり、お客様の情報をどのように収集・利用・保存・保護するかを説明するものです。ご利用前に必ずお読みください。';

  @override
  String get privacySecCollect => '1. 収集する情報';

  @override
  String get privacySecCollectBody =>
      'アカウント作成時にお客様のメールアドレスと、任意でご提供いただくニックネームおよびアバターを収集します。方位磁針や騒音測定器などのツール機能では、権限を許可いただいた場合にのみ、関連する端末センサーにアクセスします。本アプリの利用に関係のない個人情報は収集しません。';

  @override
  String get privacySecUse => '2. 情報の利用目的';

  @override
  String get privacySecUseBody =>
      '収集した情報は、アカウントの作成・維持、プロフィールや会員特典の端末間同期、製品体験の向上、および必要に応じたご連絡のためにのみ利用します。本アプリに関係のない目的で利用することはありません。';

  @override
  String get privacySecStore => '3. データの保存とセキュリティ';

  @override
  String get privacySecStoreBody =>
      'アカウントデータはSupabaseのクラウドデータベースに保存され、暗号化通信とアクセス制御により保護されます。画像などのローカルキャッシュは端末内にのみ保持され、設定 > キャッシュを削除からいつでも削除できます。';

  @override
  String get privacySecShare => '4. 情報の共有';

  @override
  String get privacySecShareBody =>
      'お客様の個人情報を販売または貸与することはありません。共有は必要最小限の範囲に限り、会員購入を完了するための決済プラットフォーム（Apple App Store / Google Play）への提供、および法令に基づく要請や当社の法的権利を保護するために必要な場合のみ行います。';

  @override
  String get privacySecAds => '5. 広告について';

  @override
  String get privacySecAdsBody =>
      '無料版ではアプリ内の一部にGoogle AdMobによるバナー広告を表示します。AdMobは広告の選択と効果測定のために、端末識別子や広告の操作データを利用する場合があります。詳細はGoogleのプライバシーポリシーをご確認ください。プロ版アンロックをご購入いただくと広告は一切読み込まれません。本アプリはApp Tracking Transparencyの権限を要求せず、ツールのデータを広告ネットワークに送信することもありません。';

  @override
  String get privacySecRights => '6. お客様の権利';

  @override
  String get privacySecRightsBody =>
      'ニックネームとアバターは「プロフィールを編集」から、ローカルデータは設定 > キャッシュを削除から、クラウドのプロフィールはアカウント削除により、いつでも変更・削除できます。データの書き出しや削除をご希望の場合は、下記の連絡先までご連絡ください。';

  @override
  String get privacySecUpdate => '7. ポリシーの更新';

  @override
  String get privacySecUpdateBody =>
      '本ポリシーは随時更新する場合があります。最新の内容は常にこのページに掲載され、重要な変更についてはアプリ内でお知らせします。定期的にご確認いただくことをおすすめします。';

  @override
  String get privacySecContact => '8. お問い合わせ';

  @override
  String get privacySecContactBody =>
      '本プライバシーポリシーに関するご質問・ご意見は support@aknot.uk までご連絡ください。合理的な期間内に回答いたします。';

  @override
  String get agreementIntro =>
      '本利用規約は、本アプリのご利用にあたって適用される条件、およびお客様と当社の間の権利義務を定めるものです。ご利用前に必ずお読みください。本アプリを利用された場合、本規約に同意いただいたものとみなします。';

  @override
  String get agreementSecAccept => '1. 規約の承諾';

  @override
  String get agreementSecAcceptBody =>
      '本規約はお客様と当社との間の法的拘束力を有する契約です。同意いただけない場合は本アプリのご利用をお控えください。未成年の方は、保護者の方と一緒にご確認ください。';

  @override
  String get agreementSecService => '2. 本サービス';

  @override
  String get agreementSecServiceBody =>
      '本アプリは、メモ、方位磁針、騒音測定器、水準器、定規、懐中電灯、潮汐表などの実用的なツール群を提供します。機能は製品の改善に伴い変更される場合がありますが、安定した体験を維持するよう努めます。';

  @override
  String get agreementSecAccount => '3. アカウント';

  @override
  String get agreementSecAccountBody =>
      '一部の機能にはアカウントが必要です。AppleまたはGoogleでサインインするほか、ゲストとしてもご利用いただけます。アカウント情報の管理、およびアカウント上で行われた行為の責任はお客様にあります。アカウントデータはSupabaseのクラウドデータベースに保存されます。詳しくはプライバシーポリシーをご確認ください。';

  @override
  String get agreementSecFree => '4. 無料利用と広告';

  @override
  String get agreementSecFreeBody =>
      '無料版ではツールの利用回数に上限があり、Google AdMobによるバナー広告が表示されます。アプリ内の広告を視聴すると、上限の範囲内で追加の無料利用回数を獲得できます。利用回数は当社のサーバーに記録され端末識別子に紐付けられるため、アプリを再インストールしてもリセットされません。';

  @override
  String get agreementSecPurchase => '5. 購入と払い戻し';

  @override
  String get agreementSecPurchaseBody =>
      'プロ版アンロックは買い切り型の商品で、広告が非表示になり無料利用の上限が解除されます。お支払いはApple App StoreまたはGoogle Playを通じて処理され、払い戻しは各プラットフォームの規約に従うため、当社では直接対応できません。購入はアカウントに紐付けられ、別の端末でサインインすると特典が復元されます。';

  @override
  String get agreementSecConduct => '6. 利用上のルール';

  @override
  String get agreementSecConductBody =>
      '法令に違反する目的での利用、本アプリの正常な動作の妨害、リバースエンジニアリング・逆コンパイル・ソースコードの抽出の試みを行わないことに同意いただきます。また、自動化された手段による大量アクセスも禁止します。';

  @override
  String get agreementSecIp => '7. 知的財産権';

  @override
  String get agreementSecIpBody =>
      '本アプリ（コード、デザイン、アイコン、テキストその他の素材を含む）は当社に帰属し、適用される法令により保護されます。個人的な目的でのみご利用いただけます。書面による許諾なく、複製・改変・配布・商用利用することはできません。';

  @override
  String get agreementSecDisclaimer => '8. 免責事項';

  @override
  String get agreementSecDisclaimerBody =>
      '方位磁針、騒音測定器、水準器などの計測値は端末のセンサーによる参考値です。専門機器の代替にはならず、建築・医療・法務など精度が安全性に直結する場面では使用しないでください。これらの値に依拠したことによる損害について、当社は責任を負いません。';

  @override
  String get agreementSecUpdate => '9. 規約の変更';

  @override
  String get agreementSecUpdateBody =>
      '本規約は随時更新する場合があります。最新の内容は常にこのページに掲載され、重要な変更についてはアプリ内でお知らせします。更新後も本アプリを継続して利用された場合、変更後の規約に同意いただいたものとみなします。';

  @override
  String get agreementSecContact => '10. お問い合わせ';

  @override
  String get agreementSecContactBody =>
      '本規約に関するご質問・ご意見は support@aknot.uk までご連絡ください。合理的な期間内に回答いたします。';

  @override
  String get cacheCleared => 'キャッシュを削除しました';

  @override
  String get langChinese => '簡体字中国語';

  @override
  String get langEnglish => '英語';

  @override
  String get langJapanese => '日本語';

  @override
  String get langGerman => 'ドイツ語';

  @override
  String get langFrench => 'フランス語';

  @override
  String get toggleLightDark => 'ライト / ダークを切り替え';

  @override
  String get sectionGeneral => '一般ツール';

  @override
  String get toolForce => '力・荷重変換';

  @override
  String get toolForceDesc => '正確な力の換算';

  @override
  String get toolUnitConverter => '単位変換';

  @override
  String get toolUnitConverterDesc => '長さ / 質量 / 力';

  @override
  String get toolTravelMemo => '旅行メモ';

  @override
  String get toolTravelMemoDesc => '旅の準備を万全に';

  @override
  String get toolCompass => '方位磁針';

  @override
  String get toolCompassDesc => 'いつでも方向を確認';

  @override
  String get toolNoise => '騒音測定器';

  @override
  String get toolNoiseDesc => '周囲の音をデシベルで表示';

  @override
  String get toolLevel => '水準器';

  @override
  String get toolLevelDesc => '正確な水平出し';

  @override
  String get toolRuler => '定規';

  @override
  String get toolRulerDesc => '画面上でそのまま計測';

  @override
  String get toolFlashlight => '懐中電灯';

  @override
  String get toolFlashlightDesc => '足元を照らす';

  @override
  String get toolTide => '潮汐';

  @override
  String get toolTideDesc => 'いつでも潮汐を確認';

  @override
  String get ucCatArea => '面積';

  @override
  String get ucCatVolume => '体積';

  @override
  String get ucCatTemp => '温度';

  @override
  String get ucCatSpeed => '速度';

  @override
  String get ucCatWeight => '質量';

  @override
  String get ucCatLength => '長さ';

  @override
  String get unitSquareMeter => '平方メートル（m²）';

  @override
  String get unitSquareKilometer => '平方キロメートル（km²）';

  @override
  String get unitHectare => 'ヘクタール（ha）';

  @override
  String get unitMu => 'ムー';

  @override
  String get unitSquareFoot => '平方フィート（ft²）';

  @override
  String get unitSquareMile => '平方マイル（mi²）';

  @override
  String get unitSquareYard => '平方ヤード（yd²）';

  @override
  String get unitAcre => 'エーカー（ac）';

  @override
  String get unitSquareInch => '平方インチ（in²）';

  @override
  String get unitMeterPerSec => 'メートル毎秒（m/s）';

  @override
  String get unitKmPerHour => 'キロメートル毎時（km/h）';

  @override
  String get unitMilePerHour => 'マイル毎時（mph）';

  @override
  String get unitFootPerSec => 'フィート毎秒（ft/s）';

  @override
  String get unitKnot => 'ノット（kn）';

  @override
  String get unitKilogram => 'キログラム（kg）';

  @override
  String get unitGram => 'グラム（g）';

  @override
  String get unitMilligram => 'ミリグラム（mg）';

  @override
  String get unitTon => 'トン（t）';

  @override
  String get unitPound => 'ポンド（lb）';

  @override
  String get unitOunce => 'オンス（oz）';

  @override
  String get unitJin => '斤';

  @override
  String get unitLiang => '両';

  @override
  String get unitLiter => 'リットル（L）';

  @override
  String get unitMilliliter => 'ミリリットル（mL）';

  @override
  String get unitCubicMeter => '立方メートル（m³）';

  @override
  String get unitCubicCentimeter => '立方センチメートル（cm³）';

  @override
  String get unitGallon => 'ガロン（米）（gal）';

  @override
  String get unitQuart => 'クォート（米）（qt）';

  @override
  String get unitPint => 'パイント（米）（pt）';

  @override
  String get unitCup => 'カップ（米）（cup）';

  @override
  String get unitCubicFoot => '立方フィート（ft³）';

  @override
  String get unitCubicInch => '立方インチ（in³）';

  @override
  String get unitMeter => 'メートル（m）';

  @override
  String get unitKilometer => 'キロメートル（km）';

  @override
  String get unitCentimeter => 'センチメートル（cm）';

  @override
  String get unitMillimeter => 'ミリメートル（mm）';

  @override
  String get unitMile => 'マイル（mi）';

  @override
  String get unitFoot => 'フィート（ft）';

  @override
  String get unitInch => 'インチ（in）';

  @override
  String get unitYard => 'ヤード（yd）';

  @override
  String get unitNauticalMile => '海里（nmi）';

  @override
  String get unitCelsius => '摂氏（°C）';

  @override
  String get unitFahrenheit => '華氏（°F）';

  @override
  String get unitKelvin => 'ケルビン（K）';

  @override
  String get unitNewton => 'ニュートン（N）';

  @override
  String get unitKilonewton => 'キロニュートン（kN）';

  @override
  String get unitKilogramForce => '重量キログラム（kgf）';

  @override
  String get unitPoundForce => '重量ポンド（lbf）';

  @override
  String get unitTonForce => '重量トン（tf）';

  @override
  String get tideHigh => '満潮';

  @override
  String get tideEbbing => '下げ潮';

  @override
  String tideDateFormat(Object month, Object day, Object hour, Object min) {
    return '$month/$day $hour:$min';
  }

  @override
  String get darkModeLabel => 'ダークモード';

  @override
  String devToast(Object title) {
    return '$title（開発中）';
  }

  @override
  String get profileNotLogin => '未ログイン';

  @override
  String get profileTapLogin => 'タップしてログイン / 新規登録';

  @override
  String get profileGuest => 'ユーザー';

  @override
  String get profileNoEmail => 'メールアドレス未連携';

  @override
  String get profileMemberVip => 'VIP';

  @override
  String get profileMemberFree => '無料';

  @override
  String get profileLoadFailed => 'プロフィールを読み込めませんでした';

  @override
  String get profileRetry => '再試行';

  @override
  String get profileSignOut => 'ログアウト';

  @override
  String get profileSignOutConfirm => '現在のアカウントからログアウトしますか？';

  @override
  String get deleteAccount => 'アカウントを削除';

  @override
  String get deleteAccountConfirm => 'アカウントを削除しますか？この操作は取り消せません。';

  @override
  String get deleteAccountWarning => 'ローカルおよびクラウドのすべてのデータが完全に削除され、復元できません。';

  @override
  String get deleteAccountDone => 'アカウントを削除しました';

  @override
  String get deleteAccountFailed => 'アカウントの削除に失敗しました。しばらくしてからお試しください。';

  @override
  String get profileEditTitle => 'プロフィールを編集';

  @override
  String get profileEditName => 'ニックネーム';

  @override
  String get profileEditNameHint => 'ニックネームを入力';

  @override
  String get profileEditNameEmpty => 'ニックネームを入力してください';

  @override
  String get profileEditAvatarTitle => 'アバターを選択';

  @override
  String get profileEditCurrent => '現在のアバター';

  @override
  String get profileEditShuffle => 'シャッフル';

  @override
  String get profileEditSave => '保存';

  @override
  String get profileEditSaved => 'プロフィールを更新しました';

  @override
  String get profileEditFailed => '保存に失敗しました';

  @override
  String get profileEditNeedLogin => 'プロフィールの編集にはログインが必要です';

  @override
  String get dialogCancel => 'キャンセル';

  @override
  String get dialogConfirm => '確認';

  @override
  String get vipActiveTitle => 'プロ版アンロック · 有効';

  @override
  String get vipLifetime => '永久会員・有効期限なし';

  @override
  String vipExpireAt(Object date) {
    return '$dateまで有効';
  }

  @override
  String splashSkip(Object seconds) {
    return '$seconds秒でスキップ';
  }

  @override
  String get thirdPartySdk => 'サードパーティSDK';

  @override
  String adWatchForFreeUses(num count) {
    return '広告を1本見ると、無料利用回数が$count回増えます';
  }

  @override
  String adRewardProgress(num remaining, num max) {
    return '残り無料回数: $remaining/$max';
  }

  @override
  String get adUnavailable => '広告を利用できません。しばらくしてからお試しください';

  @override
  String adRewardSuccess(num count) {
    return '無料利用回数を$count回獲得しました';
  }

  @override
  String get adNotFinished => '広告が最後まで視聴されなかったため、報酬は付与されません';

  @override
  String get adLabel => '広告';

  @override
  String get adPrivacySettings => '広告のプライバシー設定';

  @override
  String get webUnsupported => 'このプラットフォームではアプリ内ブラウザを利用できません';

  @override
  String get webLoadFailed => 'ページを読み込めませんでした';
}
