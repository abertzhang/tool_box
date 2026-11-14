// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Theme Demo';

  @override
  String get profile => 'Profile';

  @override
  String get tools => 'Tools';

  @override
  String get login => 'Sign In';

  @override
  String get registerTitle => 'Create Account';

  @override
  String get nicknameHint => 'Nickname (optional)';

  @override
  String get emailHint => 'Email';

  @override
  String get passwordHint => 'Password';

  @override
  String get confirmPasswordHint => 'Confirm Password';

  @override
  String get registerSubmit => 'Sign Up';

  @override
  String get googleSignUp => 'Continue with Google';

  @override
  String get appleSignUp => 'Continue with Apple';

  @override
  String get appleSignIn => 'Sign in with Apple';

  @override
  String get googleSignIn => 'Sign in with Google';

  @override
  String get emailSignIn => 'Sign in with Email';

  @override
  String get haveAccountLogin => 'Already have an account? Sign in';

  @override
  String get errEmailInvalid => 'Please enter a valid email address';

  @override
  String get errPasswordShort => 'Password must be at least 6 characters';

  @override
  String get errNetworkReset =>
      'The connection was reset by the server. Try another Wi-Fi/cellular network, or turn off any proxy/VPN, then retry';

  @override
  String get errPasswordMismatch => 'Passwords do not match';

  @override
  String get registerSuccess => 'Registration successful';

  @override
  String get loginSubtitle =>
      'Your pocket toolkit · Sign in to unlock everything';

  @override
  String get loginSubmit => 'Sign In';

  @override
  String get loginSuccess => 'Signed in successfully';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get forgotPasswordDesc =>
      'Enter your email and we will send you a link to reset your password.';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get resetPasswordSent => 'Password reset link sent';

  @override
  String get emailNotRegistered => 'No account found with this email';

  @override
  String get emailCheckFailed =>
      'Could not verify this email. Please try again.';

  @override
  String get resetPasswordTitle => 'Set a new password';

  @override
  String get resetPasswordDesc => 'Choose a new password for your account.';

  @override
  String get newPasswordHint => 'New password';

  @override
  String get resetPasswordSubmit => 'Update password';

  @override
  String get resetPasswordSuccess =>
      'Your password has been updated. Please sign in again.';

  @override
  String get resetLinkInvalid =>
      'This reset link is invalid or has expired. Please request a new one.';

  @override
  String get registerVerifyEmail =>
      'Registered. Please check your email to verify.';

  @override
  String get verifyEmailTitle => 'Verify your email';

  @override
  String get verifyEmailDesc =>
      'We sent a 6-digit code to your email. Enter it below to activate your account.';

  @override
  String get verifyCodeHint => '6-digit code';

  @override
  String get verifyEmailSubmit => 'Verify';

  @override
  String get verifyEmailResend => 'Resend code';

  @override
  String get verifyEmailResent => 'A new code has been sent';

  @override
  String get verifyEmailResendFailed =>
      'Could not resend the code. Please try again.';

  @override
  String get verifyEmailSuccess => 'Your email has been verified.';

  @override
  String get verifyEmailContinue => 'Continue';

  @override
  String get errCodeInvalid => 'Invalid or expired code';

  @override
  String get errSupabaseNotReady =>
      'Supabase is not initialized. Provide SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define.';

  @override
  String get compassTitle => 'Compass';

  @override
  String get compassSensorUnavailable =>
      'Compass is not available on this device.';

  @override
  String get compassLock => 'Lock heading';

  @override
  String get compassUnlock => 'Unlock heading';

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
  String get compassHeading => 'Heading';

  @override
  String get compassAltitude => 'Altitude';

  @override
  String get compassLatitude => 'Latitude';

  @override
  String get compassLongitude => 'Longitude';

  @override
  String get compassRecordLocation => 'Record Location';

  @override
  String get compassExport => 'Export';

  @override
  String get compassHistory => 'History';

  @override
  String get compassViewAll => 'View All';

  @override
  String get compassCollapse => 'Collapse';

  @override
  String get compassNoRecords =>
      'No records yet. Tap \"Record Location\" to save a point.';

  @override
  String get compassRecordDialogTitle => 'Record Location';

  @override
  String get compassRecordNameHint => 'Name (e.g. Camp A)';

  @override
  String get compassSave => 'Save';

  @override
  String get compassCancel => 'Cancel';

  @override
  String get compassRecordSaved => 'Record saved';

  @override
  String get compassSaveFailed => 'Save failed. Please try again';

  @override
  String get compassLocationDenied =>
      'Location permission is off, so coordinates are unavailable';

  @override
  String get compassLocationServiceOff =>
      'Location services are off. Turn them on in Settings';

  @override
  String get compassOpenSettings => 'Open Settings';

  @override
  String get compassExported => 'All records copied to clipboard';

  @override
  String get compassDelete => 'Delete';

  @override
  String get compassDeleteConfirm => 'Delete this record?';

  @override
  String get compassLatLng => 'Coordinates';

  @override
  String get compassDirection => 'Direction';

  @override
  String get noiseTitle => 'Noise Detector';

  @override
  String get noiseCurrent => 'Current';

  @override
  String get noiseAverage => 'Average';

  @override
  String get noiseMin => 'Min';

  @override
  String get noiseMax => 'Max';

  @override
  String get noiseRecord => 'Record Noise';

  @override
  String get noiseExport => 'Export';

  @override
  String get noiseHistory => 'History';

  @override
  String get noiseViewAll => 'View All';

  @override
  String get noiseCollapse => 'Collapse';

  @override
  String get noiseNoRecords => 'No records yet';

  @override
  String get noiseNoReading => 'No reading yet, please wait';

  @override
  String get noiseZoneQuiet => 'Quiet';

  @override
  String get noiseZoneModerate => 'Moderate';

  @override
  String get noiseZoneLoud => 'Loud';

  @override
  String get noiseZoneQuietEnv => 'Quiet';

  @override
  String get noiseZoneModerateEnv => 'Moderate';

  @override
  String get noiseZoneLoudEnv => 'Loud';

  @override
  String get noiseCatQuiet => 'Quiet';

  @override
  String get noiseCatModerate => 'Normal';

  @override
  String get noiseCatLoud => 'Loud';

  @override
  String get noiseEnvType => 'Environment';

  @override
  String get noiseLevel => 'Level';

  @override
  String get noiseDbUnit => 'dB';

  @override
  String get noiseRecordTitle => 'Record Noise';

  @override
  String get noiseName => 'Name';

  @override
  String get noiseNameHint => 'Enter a name (e.g. \"Campsite surroundings\")';

  @override
  String get noiseEnvHint => 'Environment type (optional, e.g. \"Woodland\")';

  @override
  String get noiseSave => 'Save';

  @override
  String get noiseCancel => 'Cancel';

  @override
  String get noiseSaved => 'Saved locally';

  @override
  String get noiseExported => 'Exported to clipboard';

  @override
  String get noiseDelete => 'Delete';

  @override
  String get noiseDeleteConfirm => 'Delete this record?';

  @override
  String get noiseMicDenied => 'Microphone permission denied';

  @override
  String get noiseMicNeedPermission =>
      'Microphone access is needed to measure noise';

  @override
  String get noiseMicRetry => 'Retry & Grant';

  @override
  String get noiseMicGrant => 'Grant & Start Measuring';

  @override
  String get noiseMicOpenSettings => 'Open Settings';

  @override
  String get commonOpenSettings => 'Open Settings';

  @override
  String get noiseToday => 'Today';

  @override
  String get noiseYesterday => 'Yesterday';

  @override
  String get levelTitle => 'Level';

  @override
  String get levelBullseye => 'Bullseye Level';

  @override
  String get levelTubular => 'Tubular Level';

  @override
  String get levelCalibrated => 'Calibrated';

  @override
  String get levelUncalibrated => 'Uncalibrated';

  @override
  String get levelStatusLabel => 'Status';

  @override
  String get levelStatusLevel => 'Level';

  @override
  String get levelStatusNear => 'Near Level';

  @override
  String get levelStatusTilt => 'Tilted';

  @override
  String get levelVertical => 'Vertical (Y-Axis)';

  @override
  String get levelHorizontal => 'Horizontal (X-Axis)';

  @override
  String get levelLock => 'Lock Reading';

  @override
  String get levelUnlock => 'Unlock';

  @override
  String get levelCalibrate => 'Calibrate';

  @override
  String get levelCalibratedToast => 'Calibrated to current angle';

  @override
  String get levelHistory => 'Measurements';

  @override
  String get levelSave => 'Save';

  @override
  String get levelViewAll => 'View All';

  @override
  String get levelCollapse => 'Collapse';

  @override
  String get levelNoRecords => 'No records yet';

  @override
  String get levelRecordTitle => 'Save Measurement';

  @override
  String get levelName => 'Name';

  @override
  String get levelNameHint => 'Name (optional)';

  @override
  String get levelCancel => 'Cancel';

  @override
  String get levelSaveAction => 'Save';

  @override
  String get levelSavedToast => 'Measurement saved';

  @override
  String get levelDelete => 'Delete';

  @override
  String get levelDeleteConfirm => 'Delete this measurement?';

  @override
  String get levelDefaultName => 'Level measurement';

  @override
  String get appShareSubject => 'Tool Box - Outdoor Toolbox';

  @override
  String get appShareBody =>
      'Level, ruler, compass, noise meter, flashlight and more, all in one app for outdoor work and home projects.';

  @override
  String get appShareFailed => 'Unable to open the share sheet';

  @override
  String get levelDescLevel => 'Perfectly leveled';

  @override
  String get levelDescNear => 'Nearly level';

  @override
  String get levelDescTilt => 'Off level';

  @override
  String get rulerTitle => 'Ruler';

  @override
  String get rulerUnitCm => 'cm';

  @override
  String get rulerUnitInch => 'inch';

  @override
  String get rulerLengthLabel => 'Length';

  @override
  String get rulerCm => 'cm';

  @override
  String get rulerInch => 'inch';

  @override
  String get rulerTime => 'Time';

  @override
  String get rulerName => 'Name';

  @override
  String get rulerNameHint => 'Name this measurement (optional)';

  @override
  String get rulerRecordTitle => 'Save measurement';

  @override
  String get rulerCancel => 'Cancel';

  @override
  String get rulerSaveAction => 'Save';

  @override
  String get rulerSavedToast => 'Measurement saved';

  @override
  String get rulerExport => 'Export';

  @override
  String get rulerExported => 'Exported to clipboard';

  @override
  String get rulerHistory => 'Measurements';

  @override
  String get rulerNoRecords => 'No measurements yet';

  @override
  String get rulerViewAll => 'View all';

  @override
  String get rulerCollapse => 'Collapse';

  @override
  String get rulerDelete => 'Delete';

  @override
  String get rulerDeleteConfirm => 'Delete this measurement?';

  @override
  String get rulerDefaultName => 'Ruler measurement';

  @override
  String get flashlightOn => 'On';

  @override
  String get flashlightPermissionDenied =>
      'Camera permission is required to use the flashlight. Please enable it in Settings.';

  @override
  String get flashlightUnavailable =>
      'This device does not support a flashlight';

  @override
  String get tideTitle => 'Tides';

  @override
  String get tideRecordCurrent => 'Record Now';

  @override
  String get tideExported => 'Exported to clipboard';

  @override
  String get tideScheduleTitle => 'Today\'s Tide Schedule';

  @override
  String get tideCurrentHeight => 'Current Height';

  @override
  String tideTimeToHigh(Object time) {
    return 'High in $time';
  }

  @override
  String get tideNextLow => 'Next Low';

  @override
  String get tideNextHigh => 'Next High';

  @override
  String get tideHistory => 'History';

  @override
  String get tideViewAll => 'View All';

  @override
  String get tideCollapse => 'Collapse';

  @override
  String get tideLowTide => 'Low';

  @override
  String get tideHighTide => 'High';

  @override
  String get tideRising => 'Rising';

  @override
  String get tideNoRecords => 'No tide records yet';

  @override
  String get tideSavedToast => 'Current tide recorded';

  @override
  String get toolWorldClock => 'World Clock';

  @override
  String get toolWorldClockDesc => 'Times around the globe';

  @override
  String get worldClockTitle => 'World Clock';

  @override
  String get worldClockLocalLabel => 'Local Time';

  @override
  String get worldClockLocLabel => 'Located Place';

  @override
  String get worldClockLocating => 'Locating…';

  @override
  String get worldClockLocFailed => 'Location unavailable, showing device time';

  @override
  String get worldClockCityBeijing => 'Beijing';

  @override
  String get worldClockCityTokyo => 'Tokyo';

  @override
  String get worldClockCitySingapore => 'Singapore';

  @override
  String get worldClockCitySydney => 'Sydney';

  @override
  String get worldClockCityDubai => 'Dubai';

  @override
  String get worldClockCityLondon => 'London';

  @override
  String get worldClockCityParis => 'Paris';

  @override
  String get worldClockCityNewYork => 'New York';

  @override
  String get worldClockCityLosAngeles => 'Los Angeles';

  @override
  String get worldClockRegion => 'Country / Region';

  @override
  String get worldClockSelectRegion => 'Select country / region';

  @override
  String get worldClockSelectCity => 'Select city';

  @override
  String get worldClockCountryCn => 'China';

  @override
  String get worldClockCountryJp => 'Japan';

  @override
  String get worldClockCountrySg => 'Singapore';

  @override
  String get worldClockCountryAu => 'Australia';

  @override
  String get worldClockCountryAe => 'UAE';

  @override
  String get worldClockCountryGb => 'UK';

  @override
  String get worldClockCountryFr => 'France';

  @override
  String get worldClockCountryUs => 'USA';

  @override
  String get ucTitle => 'Unit Converter';

  @override
  String get ucFormula => 'Formula: ';

  @override
  String get ucCommon => 'Common Conversions';

  @override
  String get forceTitle => 'Force & Load Converter';

  @override
  String get memoTitle => 'Travel Memo';

  @override
  String get memoAdd => 'New Memo';

  @override
  String get memoEmpty => 'No memos yet, tap + to create';

  @override
  String get memoTitleHint => 'Title';

  @override
  String get memoFieldTitle => 'Title';

  @override
  String get memoTravelTime => 'Travel Time';

  @override
  String get memoTravelTimeHint => 'Select time';

  @override
  String get memoKeyHint => 'Key';

  @override
  String get memoValueHint => 'Value';

  @override
  String get memoAddRow => 'Add row';

  @override
  String get memoSave => 'Save';

  @override
  String get memoUntitled => 'Untitled';

  @override
  String get memoNoContent => 'No content';

  @override
  String get memoDelete => 'Delete';

  @override
  String get memoDeleteConfirm => 'Delete this memo?';

  @override
  String get memoCancel => 'Cancel';

  @override
  String get memoEdit => 'Edit';

  @override
  String get memoTemplateTitle => 'Templates';

  @override
  String get memoUseTemplate => 'Use';

  @override
  String get memoTemplateApplied => 'Template applied';

  @override
  String get memoTemplateHint => 'Pick a template to quickly create a memo';

  @override
  String get memoNewTemplate => 'New Template';

  @override
  String get memoTemplateEmpty => 'No templates yet, tap + to create';

  @override
  String get memoTemplateDeleteConfirm => 'Delete this template?';

  @override
  String get memoDaysLeftPrefix => '';

  @override
  String get memoDaysLeftSuffix => ' days left';

  @override
  String get memoTodayDepart => 'Departing today';

  @override
  String get memoDeparted => 'Departed';

  @override
  String get memoShare => 'Share';

  @override
  String get memoCopy => 'Copy';

  @override
  String get memoCopied => 'Copied';

  @override
  String get memoSaveAsTemplate => 'Save as Template';

  @override
  String get memoTemplateCreated => 'Saved as template';

  @override
  String get memoExpand => 'Expand';

  @override
  String get memoCollapse => 'Collapse';

  @override
  String get memoDeleted => 'Deleted';

  @override
  String get memoUndo => 'Undo';

  @override
  String get statToolsUsed => 'Tools Used';

  @override
  String get statAppToolUsage => 'App Total Uses';

  @override
  String get statFreeRemaining => 'Free Left';

  @override
  String get vipTitle => 'Pro Unlock';

  @override
  String get vipDesc => 'One-time purchase. No ads.';

  @override
  String get vipOpen => 'Upgrade Now';

  @override
  String freeRemainingCount(num count) {
    return 'Free $count uses left';
  }

  @override
  String get freeLimitTitle => 'Free trial used up';

  @override
  String get freeLimitBody =>
      'You\'ve reached the free usage limit (10). Upgrade to Pro to unlock all tools.';

  @override
  String get freeLimitUpgrade => 'Upgrade Pro';

  @override
  String get vipSheetProductName => 'Pro Unlock';

  @override
  String get vipSheetProductDesc => 'Lifetime membership';

  @override
  String get vipSheetOneTime => 'One-time purchase';

  @override
  String get vipSheetConfirm => 'Confirm with Side Button';

  @override
  String get vipDeveloping => 'Membership activation coming soon';

  @override
  String get vipPayConfirmTitle => 'Confirm Purchase';

  @override
  String vipPayConfirmBody(Object price) {
    return 'Pay $price for the lifetime membership. One-time purchase, restorable with your Apple ID or Google account.';
  }

  @override
  String get vipPayStoreUnavailable =>
      'App store unavailable. Please try again later';

  @override
  String get vipPayProductMissing => 'Membership product is not available yet';

  @override
  String get vipPayDebugProductMissing =>
      'Debug build cannot query Play products. Install via Play internal app sharing or internal testing track, then purchase.';

  @override
  String get vipPaySheetOpened =>
      'Payment sheet opened. Membership activates after payment';

  @override
  String get vipRestore => 'Restore Purchases';

  @override
  String get vipRestoreDone =>
      'Restore finished. Membership activated if previously purchased';

  @override
  String get vipRestoreEmpty => 'No purchases found for this account';

  @override
  String get vipRestoreCheckAccount =>
      'No purchase found. Restoring only checks the Google Play account signed in on this device, so make sure it is the same account you used to buy';

  @override
  String get vipRestoreAlready =>
      'You are already a Pro member. No need to restore.';

  @override
  String get vipBecomeMember => 'Membership activated';

  @override
  String get syncMemberTitle => 'Sync Pro to your account';

  @override
  String get syncMemberBody =>
      'Sign in to keep Pro on all your devices and restore it after reinstalling.';

  @override
  String get syncMemberApple => 'Continue with Apple';

  @override
  String get syncMemberGoogle => 'Continue with Google';

  @override
  String get syncMemberLater => 'Not now';

  @override
  String get syncMemberDone => 'Pro synced to your account';

  @override
  String get syncMemberFailed => 'Sync failed. Please try again later';

  @override
  String get syncMemberAction => 'Sync Pro to account';

  @override
  String get vipPurchaseAppBarTitle => 'Tool Box Pro Unlock';

  @override
  String get vipPurchaseSubtitle =>
      'Unlock all tools. One-time purchase. No ads.';

  @override
  String get statOffline => 'Offline Downloads';

  @override
  String get statCert => 'My Certificates';

  @override
  String get statRecord => 'Study Records';

  @override
  String get countFiles => '5 files';

  @override
  String get countCert => '3 cards';

  @override
  String get countDays => '12 days';

  @override
  String get countFav => '128 items';

  @override
  String get settings => 'Settings';

  @override
  String get themeColorSetting => 'Theme';

  @override
  String get themeCoffee => 'Coffee';

  @override
  String get themeBlue => 'Sky';

  @override
  String get langSetting => 'Language';

  @override
  String get saveNamePromptSetting => 'Save Dialog';

  @override
  String get clearCache => 'Clear Cache';

  @override
  String get calculating => 'Calculating…';

  @override
  String get notifSetting => 'Notifications';

  @override
  String get notifDeveloping => 'Notifications coming soon';

  @override
  String get accountSecurity => 'Account Security';

  @override
  String get accountDeveloping => 'Account & Security coming soon';

  @override
  String get aboutGroup => 'About';

  @override
  String get checkUpdate => 'Check for Update';

  @override
  String get rateUs => 'Rate Us';

  @override
  String get rateUsUnavailable =>
      'Cannot open the rating page right now. Please try again later';

  @override
  String get aboutUs => 'About Us';

  @override
  String get userAgreement => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String privacyLastUpdated(String date) {
    return 'Last updated: $date';
  }

  @override
  String get privacyIntro =>
      'This Privacy Policy explains how we collect, use, store and protect your information when you use this app. Please read it carefully before you start.';

  @override
  String get privacySecCollect => '1. Information We Collect';

  @override
  String get privacySecCollectBody =>
      'When you create an account, we collect your email address along with the nickname and avatar you choose to provide. For tool features such as the compass and noise detector, the app accesses the relevant device sensors only after you grant permission. We do not collect personal information unrelated to your use of this app.';

  @override
  String get privacySecUse => '2. How We Use Information';

  @override
  String get privacySecUseBody =>
      'Collected information is used only to create and maintain your account, sync your profile and membership benefits across devices, improve the product experience, and contact you when necessary. We never use your information for purposes unrelated to this app.';

  @override
  String get privacySecStore => '3. Data Storage and Security';

  @override
  String get privacySecStoreBody =>
      'Account data is stored in a Supabase cloud database and protected with encrypted transfers and access control. Local caches such as images stay on your device only, and you can clear them anytime in Settings > Clear Cache.';

  @override
  String get privacySecShare => '4. Information Sharing';

  @override
  String get privacySecShareBody =>
      'We do not sell or rent your personal information. We share only the minimum data required in these cases: with payment platforms (Apple App Store / Google Play) to complete membership purchases, and where required by law or necessary to protect our legal rights.';

  @override
  String get privacySecAds => '5. Advertising';

  @override
  String get privacySecAdsBody =>
      'The free version shows banner ads at a few places within the app, served by Google AdMob. AdMob may use device identifiers and ad interaction data to select and measure ads, as described in the Google privacy policy. No ad is loaded once you purchase Pro Unlock. This app does not request the App Tracking Transparency permission and does not send your tool data to ad networks.';

  @override
  String get privacySecRights => '6. Your Rights';

  @override
  String get privacySecRightsBody =>
      'You may at any time change your nickname and avatar in Edit Profile, delete local data in Settings > Clear Cache, and delete your cloud profile by deleting your account. To export or request deletion of your data, contact us using the details below.';

  @override
  String get privacySecUpdate => '7. Policy Updates';

  @override
  String get privacySecUpdateBody =>
      'We may update this policy from time to time. The latest version is always published on this page, and we will notify you in the app for significant changes. We recommend reviewing this page periodically.';

  @override
  String get privacySecContact => '8. Contact Us';

  @override
  String get privacySecContactBody =>
      'If you have any questions or suggestions about this Privacy Policy, please reach us at support@aknot.uk. We will respond within a reasonable period.';

  @override
  String get agreementIntro =>
      'This User Agreement sets out the terms that apply when you use this app, and the rights and obligations between you and us. Please read it carefully before you start. By using this app, you agree to be bound by this Agreement.';

  @override
  String get agreementSecAccept => '1. Acceptance of the Agreement';

  @override
  String get agreementSecAcceptBody =>
      'This Agreement is a binding contract between you and us. If you do not agree to any part of it, please stop using the app. If you are a minor, please read it together with your parent or guardian.';

  @override
  String get agreementSecService => '2. The Service';

  @override
  String get agreementSecServiceBody =>
      'This app provides a set of practical on-device tools, including memo, compass, noise detector, level, ruler, flashlight and tide tables. Features may be adjusted as the product evolves, and we will do our best to keep the experience stable.';

  @override
  String get agreementSecAccount => '3. Your Account';

  @override
  String get agreementSecAccountBody =>
      'Some features require an account. You can sign in with Apple or Google, or continue as a guest. You are responsible for keeping your account credentials safe and for activity carried out under your account. Your account data is stored in a Supabase cloud database, as described in our Privacy Policy.';

  @override
  String get agreementSecFree => '4. Free Usage and Advertising';

  @override
  String get agreementSecFreeBody =>
      'The free version includes a limited number of tool uses and shows banner ads served by Google AdMob. You can watch an in-app ad to earn additional free uses, up to the free limit. Usage counts are recorded on our servers and linked to a device identifier, so reinstalling the app does not reset them.';

  @override
  String get agreementSecPurchase => '5. Purchases and Refunds';

  @override
  String get agreementSecPurchaseBody =>
      'Pro Unlock is a one-time purchase that removes ads and lifts the free usage limit. All payments are processed by the Apple App Store or Google Play, and refunds are handled under the rules of that platform, so we cannot process refunds directly. Purchases are tied to your account; signing in on another device restores your benefits.';

  @override
  String get agreementSecConduct => '6. Acceptable Use';

  @override
  String get agreementSecConductBody =>
      'You agree not to use this app for any unlawful purpose, not to interfere with its normal operation, and not to reverse engineer, decompile or attempt to extract its source code. You also agree not to use automated means to access the service in bulk.';

  @override
  String get agreementSecIp => '7. Intellectual Property';

  @override
  String get agreementSecIpBody =>
      'The app, including its code, design, icons, text and other materials, is owned by us and protected by applicable laws. You may use the app for personal purposes only, and may not copy, modify, distribute or use any part of it commercially without our written permission.';

  @override
  String get agreementSecDisclaimer => '8. Disclaimer';

  @override
  String get agreementSecDisclaimerBody =>
      'Tool readings such as those from the compass, noise detector and level come from your device sensors and are indicative only. They are not a substitute for professional instruments and must not be used where accuracy is safety-critical, such as in construction, medical or legal contexts. We do not accept liability for losses arising from reliance on these readings.';

  @override
  String get agreementSecUpdate => '9. Changes to This Agreement';

  @override
  String get agreementSecUpdateBody =>
      'We may update this Agreement from time to time. The latest version is always shown on this page, and we will notify you in the app for significant changes. Continuing to use the app after an update means you accept the revised Agreement.';

  @override
  String get agreementSecContact => '10. Contact Us';

  @override
  String get agreementSecContactBody =>
      'If you have any questions or suggestions about this Agreement, please reach us at support@aknot.uk. We will respond within a reasonable period.';

  @override
  String get cacheCleared => 'Cache cleared';

  @override
  String get langChinese => 'Simplified Chinese';

  @override
  String get langEnglish => 'English';

  @override
  String get langJapanese => 'Japanese';

  @override
  String get langGerman => 'German';

  @override
  String get langFrench => 'French';

  @override
  String get toggleLightDark => 'Toggle light / dark';

  @override
  String get sectionGeneral => 'General Tools';

  @override
  String get toolForce => 'Force & Load Converter';

  @override
  String get toolForceDesc => 'Precise force conversion';

  @override
  String get toolUnitConverter => 'Unit Converter';

  @override
  String get toolUnitConverterDesc => 'Length / Weight / Force';

  @override
  String get toolTravelMemo => 'Travel Memo';

  @override
  String get toolTravelMemoDesc => 'Prepare for Every Great Trip';

  @override
  String get toolCompass => 'Compass';

  @override
  String get toolCompassDesc => 'Know your direction anytime';

  @override
  String get toolNoise => 'Noise Detector';

  @override
  String get toolNoiseDesc => 'Ambient sound in decibels';

  @override
  String get toolLevel => 'Level';

  @override
  String get toolLevelDesc => 'Precise leveling';

  @override
  String get toolRuler => 'Ruler';

  @override
  String get toolRulerDesc => 'Measure right on screen';

  @override
  String get toolFlashlight => 'Flashlight';

  @override
  String get toolFlashlightDesc => 'Light your way';

  @override
  String get toolTide => 'Tides';

  @override
  String get toolTideDesc => 'Check tides anytime';

  @override
  String get ucCatArea => 'Area';

  @override
  String get ucCatVolume => 'Volume';

  @override
  String get ucCatTemp => 'Temperature';

  @override
  String get ucCatSpeed => 'Speed';

  @override
  String get ucCatWeight => 'Weight';

  @override
  String get ucCatLength => 'Length';

  @override
  String get unitSquareMeter => 'Square meter (m²)';

  @override
  String get unitSquareKilometer => 'Square kilometer (km²)';

  @override
  String get unitHectare => 'Hectare (ha)';

  @override
  String get unitMu => 'Mu';

  @override
  String get unitSquareFoot => 'Square foot (ft²)';

  @override
  String get unitSquareMile => 'Square mile (mi²)';

  @override
  String get unitSquareYard => 'Square yard (yd²)';

  @override
  String get unitAcre => 'Acre (ac)';

  @override
  String get unitSquareInch => 'Square inch (in²)';

  @override
  String get unitMeterPerSec => 'Meter/second (m/s)';

  @override
  String get unitKmPerHour => 'Kilometer/hour (km/h)';

  @override
  String get unitMilePerHour => 'Mile/hour (mph)';

  @override
  String get unitFootPerSec => 'Foot/second (ft/s)';

  @override
  String get unitKnot => 'Knot (kn)';

  @override
  String get unitKilogram => 'Kilogram (kg)';

  @override
  String get unitGram => 'Gram (g)';

  @override
  String get unitMilligram => 'Milligram (mg)';

  @override
  String get unitTon => 'Ton (t)';

  @override
  String get unitPound => 'Pound (lb)';

  @override
  String get unitOunce => 'Ounce (oz)';

  @override
  String get unitJin => 'Jin';

  @override
  String get unitLiang => 'Liang';

  @override
  String get unitLiter => 'Liter (L)';

  @override
  String get unitMilliliter => 'Milliliter (mL)';

  @override
  String get unitCubicMeter => 'Cubic meter (m³)';

  @override
  String get unitCubicCentimeter => 'Cubic centimeter (cm³)';

  @override
  String get unitGallon => 'Gallon (US) (gal)';

  @override
  String get unitQuart => 'Quart (US) (qt)';

  @override
  String get unitPint => 'Pint (US) (pt)';

  @override
  String get unitCup => 'Cup (US) (cup)';

  @override
  String get unitCubicFoot => 'Cubic foot (ft³)';

  @override
  String get unitCubicInch => 'Cubic inch (in³)';

  @override
  String get unitMeter => 'Meter (m)';

  @override
  String get unitKilometer => 'Kilometer (km)';

  @override
  String get unitCentimeter => 'Centimeter (cm)';

  @override
  String get unitMillimeter => 'Millimeter (mm)';

  @override
  String get unitMile => 'Mile (mi)';

  @override
  String get unitFoot => 'Foot (ft)';

  @override
  String get unitInch => 'Inch (in)';

  @override
  String get unitYard => 'Yard (yd)';

  @override
  String get unitNauticalMile => 'Nautical mile (nmi)';

  @override
  String get unitCelsius => 'Celsius (°C)';

  @override
  String get unitFahrenheit => 'Fahrenheit (°F)';

  @override
  String get unitKelvin => 'Kelvin (K)';

  @override
  String get unitNewton => 'Newton (N)';

  @override
  String get unitKilonewton => 'Kilonewton (kN)';

  @override
  String get unitKilogramForce => 'Kilogram-force (kgf)';

  @override
  String get unitPoundForce => 'Pound-force (lbf)';

  @override
  String get unitTonForce => 'Ton-force (tf)';

  @override
  String get tideHigh => 'High tide';

  @override
  String get tideEbbing => 'Ebbing';

  @override
  String tideDateFormat(Object month, Object day, Object hour, Object min) {
    return '$month/$day $hour:$min';
  }

  @override
  String get darkModeLabel => 'Dark Mode';

  @override
  String devToast(Object title) {
    return '$title (In development)';
  }

  @override
  String get profileNotLogin => 'Not signed in';

  @override
  String get profileTapLogin => 'Tap to sign in / sign up';

  @override
  String get profileGuest => 'User';

  @override
  String get profileNoEmail => 'No email linked';

  @override
  String get profileMemberVip => 'VIP';

  @override
  String get profileMemberFree => 'Free';

  @override
  String get profileLoadFailed => 'Failed to load profile';

  @override
  String get profileRetry => 'Retry';

  @override
  String get profileSignOut => 'Sign Out';

  @override
  String get profileSignOutConfirm => 'Sign out of the current account?';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountConfirm =>
      'Delete your account? This cannot be undone.';

  @override
  String get deleteAccountWarning =>
      'All your local and cloud data will be permanently removed and cannot be recovered.';

  @override
  String get deleteAccountDone => 'Account deleted';

  @override
  String get deleteAccountFailed =>
      'Failed to delete account. Please try again later.';

  @override
  String get profileEditTitle => 'Edit Profile';

  @override
  String get profileEditName => 'Nickname';

  @override
  String get profileEditNameHint => 'Enter a nickname';

  @override
  String get profileEditNameEmpty => 'Nickname cannot be empty';

  @override
  String get profileEditAvatarTitle => 'Choose an avatar';

  @override
  String get profileEditCurrent => 'Current avatar';

  @override
  String get profileEditShuffle => 'Shuffle';

  @override
  String get profileEditSave => 'Save';

  @override
  String get profileEditSaved => 'Profile updated';

  @override
  String get profileEditFailed => 'Save failed';

  @override
  String get profileEditNeedLogin => 'Sign in to edit your profile';

  @override
  String get dialogCancel => 'Cancel';

  @override
  String get dialogConfirm => 'Confirm';

  @override
  String get vipActiveTitle => 'Pro Unlock · Active';

  @override
  String get vipLifetime => 'Lifetime membership, no expiry';

  @override
  String vipExpireAt(Object date) {
    return 'Valid until $date';
  }

  @override
  String splashSkip(Object seconds) {
    return 'Skip ${seconds}s';
  }

  @override
  String get thirdPartySdk => 'Third-party SDKs';

  @override
  String adWatchForFreeUses(num count) {
    return 'Watch one ad to get $count free uses';
  }

  @override
  String adRewardProgress(num remaining, num max) {
    return 'Free uses left: $remaining/$max';
  }

  @override
  String get adUnavailable => 'Ad unavailable, please try again later';

  @override
  String adRewardSuccess(num count) {
    return 'Earned $count free uses';
  }

  @override
  String get adNotFinished => 'Ad not finished, no reward this time';

  @override
  String get adLabel => 'Ad';

  @override
  String get adPrivacySettings => 'Ad privacy settings';

  @override
  String get webUnsupported =>
      'The in-app browser is not available on this platform';

  @override
  String get webLoadFailed => 'Failed to load the page';
}
