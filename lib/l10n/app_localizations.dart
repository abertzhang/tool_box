import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart' deferred as app_localizations_de;
import 'app_localizations_en.dart' deferred as app_localizations_en;
import 'app_localizations_fr.dart' deferred as app_localizations_fr;
import 'app_localizations_ja.dart' deferred as app_localizations_ja;
import 'app_localizations_zh.dart' deferred as app_localizations_zh;

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('fr'),
    Locale('ja'),
    Locale('zh'),
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Theme Demo'**
  String get appTitle;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @tools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get login;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get registerTitle;

  /// No description provided for @nicknameHint.
  ///
  /// In en, this message translates to:
  /// **'Nickname (optional)'**
  String get nicknameHint;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailHint;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordHint;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordHint;

  /// No description provided for @registerSubmit.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get registerSubmit;

  /// No description provided for @googleSignUp.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get googleSignUp;

  /// No description provided for @appleSignUp.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get appleSignUp;

  /// No description provided for @appleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple'**
  String get appleSignIn;

  /// No description provided for @googleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get googleSignIn;

  /// No description provided for @emailSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Email'**
  String get emailSignIn;

  /// No description provided for @haveAccountLogin.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get haveAccountLogin;

  /// No description provided for @errEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get errEmailInvalid;

  /// No description provided for @errPasswordShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get errPasswordShort;

  /// No description provided for @errNetworkReset.
  ///
  /// In en, this message translates to:
  /// **'The connection was reset by the server. Try another Wi-Fi/cellular network, or turn off any proxy/VPN, then retry'**
  String get errNetworkReset;

  /// No description provided for @errPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get errPasswordMismatch;

  /// No description provided for @registerSuccess.
  ///
  /// In en, this message translates to:
  /// **'Registration successful'**
  String get registerSuccess;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your pocket toolkit · Sign in to unlock everything'**
  String get loginSubtitle;

  /// No description provided for @loginSubmit.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginSubmit;

  /// No description provided for @loginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Signed in successfully'**
  String get loginSuccess;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @forgotPasswordDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we will send you a link to reset your password.'**
  String get forgotPasswordDesc;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @resetPasswordSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset link sent'**
  String get resetPasswordSent;

  /// No description provided for @emailNotRegistered.
  ///
  /// In en, this message translates to:
  /// **'No account found with this email'**
  String get emailNotRegistered;

  /// No description provided for @emailCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not verify this email. Please try again.'**
  String get emailCheckFailed;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a new password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password for your account.'**
  String get resetPasswordDesc;

  /// No description provided for @newPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordHint;

  /// No description provided for @resetPasswordSubmit.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get resetPasswordSubmit;

  /// No description provided for @resetPasswordSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your password has been updated. Please sign in again.'**
  String get resetPasswordSuccess;

  /// No description provided for @resetLinkInvalid.
  ///
  /// In en, this message translates to:
  /// **'This reset link is invalid or has expired. Please request a new one.'**
  String get resetLinkInvalid;

  /// No description provided for @registerVerifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Registered. Please check your email to verify.'**
  String get registerVerifyEmail;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailDesc.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to your email. Enter it below to activate your account.'**
  String get verifyEmailDesc;

  /// No description provided for @verifyCodeHint.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get verifyCodeHint;

  /// No description provided for @verifyEmailSubmit.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyEmailSubmit;

  /// No description provided for @verifyEmailResend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get verifyEmailResend;

  /// No description provided for @verifyEmailResent.
  ///
  /// In en, this message translates to:
  /// **'A new code has been sent'**
  String get verifyEmailResent;

  /// No description provided for @verifyEmailResendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not resend the code. Please try again.'**
  String get verifyEmailResendFailed;

  /// No description provided for @verifyEmailSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your email has been verified.'**
  String get verifyEmailSuccess;

  /// No description provided for @verifyEmailContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get verifyEmailContinue;

  /// No description provided for @errCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired code'**
  String get errCodeInvalid;

  /// No description provided for @errSupabaseNotReady.
  ///
  /// In en, this message translates to:
  /// **'Supabase is not initialized. Provide SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define.'**
  String get errSupabaseNotReady;

  /// No description provided for @compassTitle.
  ///
  /// In en, this message translates to:
  /// **'Compass'**
  String get compassTitle;

  /// No description provided for @compassSensorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Compass is not available on this device.'**
  String get compassSensorUnavailable;

  /// No description provided for @compassLock.
  ///
  /// In en, this message translates to:
  /// **'Lock heading'**
  String get compassLock;

  /// No description provided for @compassUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock heading'**
  String get compassUnlock;

  /// No description provided for @compassDirN.
  ///
  /// In en, this message translates to:
  /// **'N'**
  String get compassDirN;

  /// No description provided for @compassDirNE.
  ///
  /// In en, this message translates to:
  /// **'NE'**
  String get compassDirNE;

  /// No description provided for @compassDirE.
  ///
  /// In en, this message translates to:
  /// **'E'**
  String get compassDirE;

  /// No description provided for @compassDirSE.
  ///
  /// In en, this message translates to:
  /// **'SE'**
  String get compassDirSE;

  /// No description provided for @compassDirS.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get compassDirS;

  /// No description provided for @compassDirSW.
  ///
  /// In en, this message translates to:
  /// **'SW'**
  String get compassDirSW;

  /// No description provided for @compassDirW.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get compassDirW;

  /// No description provided for @compassDirNW.
  ///
  /// In en, this message translates to:
  /// **'NW'**
  String get compassDirNW;

  /// No description provided for @compassHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get compassHeading;

  /// No description provided for @compassAltitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get compassAltitude;

  /// No description provided for @compassLatitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get compassLatitude;

  /// No description provided for @compassLongitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get compassLongitude;

  /// No description provided for @compassRecordLocation.
  ///
  /// In en, this message translates to:
  /// **'Record Location'**
  String get compassRecordLocation;

  /// No description provided for @compassExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get compassExport;

  /// No description provided for @compassHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get compassHistory;

  /// No description provided for @compassViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get compassViewAll;

  /// No description provided for @compassCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get compassCollapse;

  /// No description provided for @compassNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No records yet. Tap \"Record Location\" to save a point.'**
  String get compassNoRecords;

  /// No description provided for @compassRecordDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Record Location'**
  String get compassRecordDialogTitle;

  /// No description provided for @compassRecordNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name (e.g. Camp A)'**
  String get compassRecordNameHint;

  /// No description provided for @compassSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get compassSave;

  /// No description provided for @compassCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get compassCancel;

  /// No description provided for @compassRecordSaved.
  ///
  /// In en, this message translates to:
  /// **'Record saved'**
  String get compassRecordSaved;

  /// No description provided for @compassSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed. Please try again'**
  String get compassSaveFailed;

  /// No description provided for @compassLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission is off, so coordinates are unavailable'**
  String get compassLocationDenied;

  /// No description provided for @compassLocationServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Location services are off. Turn them on in Settings'**
  String get compassLocationServiceOff;

  /// No description provided for @compassOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get compassOpenSettings;

  /// No description provided for @compassExported.
  ///
  /// In en, this message translates to:
  /// **'All records copied to clipboard'**
  String get compassExported;

  /// No description provided for @compassDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get compassDelete;

  /// No description provided for @compassDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this record?'**
  String get compassDeleteConfirm;

  /// No description provided for @compassLatLng.
  ///
  /// In en, this message translates to:
  /// **'Coordinates'**
  String get compassLatLng;

  /// No description provided for @compassDirection.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get compassDirection;

  /// No description provided for @noiseTitle.
  ///
  /// In en, this message translates to:
  /// **'Noise Detector'**
  String get noiseTitle;

  /// No description provided for @noiseCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get noiseCurrent;

  /// No description provided for @noiseAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get noiseAverage;

  /// No description provided for @noiseMin.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get noiseMin;

  /// No description provided for @noiseMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get noiseMax;

  /// No description provided for @noiseRecord.
  ///
  /// In en, this message translates to:
  /// **'Record Noise'**
  String get noiseRecord;

  /// No description provided for @noiseExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get noiseExport;

  /// No description provided for @noiseHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get noiseHistory;

  /// No description provided for @noiseViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get noiseViewAll;

  /// No description provided for @noiseCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get noiseCollapse;

  /// No description provided for @noiseNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No records yet'**
  String get noiseNoRecords;

  /// No description provided for @noiseNoReading.
  ///
  /// In en, this message translates to:
  /// **'No reading yet, please wait'**
  String get noiseNoReading;

  /// No description provided for @noiseZoneQuiet.
  ///
  /// In en, this message translates to:
  /// **'Quiet'**
  String get noiseZoneQuiet;

  /// No description provided for @noiseZoneModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get noiseZoneModerate;

  /// No description provided for @noiseZoneLoud.
  ///
  /// In en, this message translates to:
  /// **'Loud'**
  String get noiseZoneLoud;

  /// No description provided for @noiseZoneQuietEnv.
  ///
  /// In en, this message translates to:
  /// **'Quiet'**
  String get noiseZoneQuietEnv;

  /// No description provided for @noiseZoneModerateEnv.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get noiseZoneModerateEnv;

  /// No description provided for @noiseZoneLoudEnv.
  ///
  /// In en, this message translates to:
  /// **'Loud'**
  String get noiseZoneLoudEnv;

  /// No description provided for @noiseCatQuiet.
  ///
  /// In en, this message translates to:
  /// **'Quiet'**
  String get noiseCatQuiet;

  /// No description provided for @noiseCatModerate.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get noiseCatModerate;

  /// No description provided for @noiseCatLoud.
  ///
  /// In en, this message translates to:
  /// **'Loud'**
  String get noiseCatLoud;

  /// No description provided for @noiseEnvType.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get noiseEnvType;

  /// No description provided for @noiseLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get noiseLevel;

  /// No description provided for @noiseDbUnit.
  ///
  /// In en, this message translates to:
  /// **'dB'**
  String get noiseDbUnit;

  /// No description provided for @noiseRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Record Noise'**
  String get noiseRecordTitle;

  /// No description provided for @noiseName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get noiseName;

  /// No description provided for @noiseNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a name (e.g. \"Campsite surroundings\")'**
  String get noiseNameHint;

  /// No description provided for @noiseEnvHint.
  ///
  /// In en, this message translates to:
  /// **'Environment type (optional, e.g. \"Woodland\")'**
  String get noiseEnvHint;

  /// No description provided for @noiseSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get noiseSave;

  /// No description provided for @noiseCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get noiseCancel;

  /// No description provided for @noiseSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved locally'**
  String get noiseSaved;

  /// No description provided for @noiseExported.
  ///
  /// In en, this message translates to:
  /// **'Exported to clipboard'**
  String get noiseExported;

  /// No description provided for @noiseDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get noiseDelete;

  /// No description provided for @noiseDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this record?'**
  String get noiseDeleteConfirm;

  /// No description provided for @noiseMicDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission denied'**
  String get noiseMicDenied;

  /// No description provided for @noiseMicNeedPermission.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is needed to measure noise'**
  String get noiseMicNeedPermission;

  /// No description provided for @noiseMicRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry & Grant'**
  String get noiseMicRetry;

  /// No description provided for @noiseMicGrant.
  ///
  /// In en, this message translates to:
  /// **'Grant & Start Measuring'**
  String get noiseMicGrant;

  /// No description provided for @noiseMicOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get noiseMicOpenSettings;

  /// No description provided for @commonOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get commonOpenSettings;

  /// No description provided for @noiseToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get noiseToday;

  /// No description provided for @noiseYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get noiseYesterday;

  /// No description provided for @levelTitle.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get levelTitle;

  /// No description provided for @levelBullseye.
  ///
  /// In en, this message translates to:
  /// **'Bullseye Level'**
  String get levelBullseye;

  /// No description provided for @levelTubular.
  ///
  /// In en, this message translates to:
  /// **'Tubular Level'**
  String get levelTubular;

  /// No description provided for @levelCalibrated.
  ///
  /// In en, this message translates to:
  /// **'Calibrated'**
  String get levelCalibrated;

  /// No description provided for @levelUncalibrated.
  ///
  /// In en, this message translates to:
  /// **'Uncalibrated'**
  String get levelUncalibrated;

  /// No description provided for @levelStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get levelStatusLabel;

  /// No description provided for @levelStatusLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get levelStatusLevel;

  /// No description provided for @levelStatusNear.
  ///
  /// In en, this message translates to:
  /// **'Near Level'**
  String get levelStatusNear;

  /// No description provided for @levelStatusTilt.
  ///
  /// In en, this message translates to:
  /// **'Tilted'**
  String get levelStatusTilt;

  /// No description provided for @levelVertical.
  ///
  /// In en, this message translates to:
  /// **'Vertical (Y-Axis)'**
  String get levelVertical;

  /// No description provided for @levelHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Horizontal (X-Axis)'**
  String get levelHorizontal;

  /// No description provided for @levelLock.
  ///
  /// In en, this message translates to:
  /// **'Lock Reading'**
  String get levelLock;

  /// No description provided for @levelUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get levelUnlock;

  /// No description provided for @levelCalibrate.
  ///
  /// In en, this message translates to:
  /// **'Calibrate'**
  String get levelCalibrate;

  /// No description provided for @levelCalibratedToast.
  ///
  /// In en, this message translates to:
  /// **'Calibrated to current angle'**
  String get levelCalibratedToast;

  /// No description provided for @levelHistory.
  ///
  /// In en, this message translates to:
  /// **'Measurements'**
  String get levelHistory;

  /// No description provided for @levelSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get levelSave;

  /// No description provided for @levelViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get levelViewAll;

  /// No description provided for @levelCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get levelCollapse;

  /// No description provided for @levelNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No records yet'**
  String get levelNoRecords;

  /// No description provided for @levelRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Save Measurement'**
  String get levelRecordTitle;

  /// No description provided for @levelName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get levelName;

  /// No description provided for @levelNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get levelNameHint;

  /// No description provided for @levelCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get levelCancel;

  /// No description provided for @levelSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get levelSaveAction;

  /// No description provided for @levelSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Measurement saved'**
  String get levelSavedToast;

  /// No description provided for @levelDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get levelDelete;

  /// No description provided for @levelDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this measurement?'**
  String get levelDeleteConfirm;

  /// No description provided for @levelDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Level measurement'**
  String get levelDefaultName;

  /// No description provided for @appShareSubject.
  ///
  /// In en, this message translates to:
  /// **'Tool Box - Outdoor Toolbox'**
  String get appShareSubject;

  /// No description provided for @appShareBody.
  ///
  /// In en, this message translates to:
  /// **'Level, ruler, compass, noise meter, flashlight and more, all in one app for outdoor work and home projects.'**
  String get appShareBody;

  /// No description provided for @appShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the share sheet'**
  String get appShareFailed;

  /// No description provided for @levelDescLevel.
  ///
  /// In en, this message translates to:
  /// **'Perfectly leveled'**
  String get levelDescLevel;

  /// No description provided for @levelDescNear.
  ///
  /// In en, this message translates to:
  /// **'Nearly level'**
  String get levelDescNear;

  /// No description provided for @levelDescTilt.
  ///
  /// In en, this message translates to:
  /// **'Off level'**
  String get levelDescTilt;

  /// No description provided for @rulerTitle.
  ///
  /// In en, this message translates to:
  /// **'Ruler'**
  String get rulerTitle;

  /// No description provided for @rulerUnitCm.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get rulerUnitCm;

  /// No description provided for @rulerUnitInch.
  ///
  /// In en, this message translates to:
  /// **'inch'**
  String get rulerUnitInch;

  /// No description provided for @rulerLengthLabel.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get rulerLengthLabel;

  /// No description provided for @rulerCm.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get rulerCm;

  /// No description provided for @rulerInch.
  ///
  /// In en, this message translates to:
  /// **'inch'**
  String get rulerInch;

  /// No description provided for @rulerTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get rulerTime;

  /// No description provided for @rulerName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get rulerName;

  /// No description provided for @rulerNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name this measurement (optional)'**
  String get rulerNameHint;

  /// No description provided for @rulerRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Save measurement'**
  String get rulerRecordTitle;

  /// No description provided for @rulerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get rulerCancel;

  /// No description provided for @rulerSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get rulerSaveAction;

  /// No description provided for @rulerSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Measurement saved'**
  String get rulerSavedToast;

  /// No description provided for @rulerExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get rulerExport;

  /// No description provided for @rulerExported.
  ///
  /// In en, this message translates to:
  /// **'Exported to clipboard'**
  String get rulerExported;

  /// No description provided for @rulerHistory.
  ///
  /// In en, this message translates to:
  /// **'Measurements'**
  String get rulerHistory;

  /// No description provided for @rulerNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No measurements yet'**
  String get rulerNoRecords;

  /// No description provided for @rulerViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get rulerViewAll;

  /// No description provided for @rulerCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get rulerCollapse;

  /// No description provided for @rulerDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get rulerDelete;

  /// No description provided for @rulerDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this measurement?'**
  String get rulerDeleteConfirm;

  /// No description provided for @rulerDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Ruler measurement'**
  String get rulerDefaultName;

  /// No description provided for @flashlightOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get flashlightOn;

  /// No description provided for @flashlightPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required to use the flashlight. Please enable it in Settings.'**
  String get flashlightPermissionDenied;

  /// No description provided for @flashlightUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This device does not support a flashlight'**
  String get flashlightUnavailable;

  /// No description provided for @tideTitle.
  ///
  /// In en, this message translates to:
  /// **'Tides'**
  String get tideTitle;

  /// No description provided for @tideRecordCurrent.
  ///
  /// In en, this message translates to:
  /// **'Record Now'**
  String get tideRecordCurrent;

  /// No description provided for @tideExported.
  ///
  /// In en, this message translates to:
  /// **'Exported to clipboard'**
  String get tideExported;

  /// No description provided for @tideScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'\'s Tide Schedule'**
  String get tideScheduleTitle;

  /// No description provided for @tideCurrentHeight.
  ///
  /// In en, this message translates to:
  /// **'Current Height'**
  String get tideCurrentHeight;

  /// No description provided for @tideTimeToHigh.
  ///
  /// In en, this message translates to:
  /// **'High in {time}'**
  String tideTimeToHigh(Object time);

  /// No description provided for @tideNextLow.
  ///
  /// In en, this message translates to:
  /// **'Next Low'**
  String get tideNextLow;

  /// No description provided for @tideNextHigh.
  ///
  /// In en, this message translates to:
  /// **'Next High'**
  String get tideNextHigh;

  /// No description provided for @tideHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tideHistory;

  /// No description provided for @tideViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get tideViewAll;

  /// No description provided for @tideCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get tideCollapse;

  /// No description provided for @tideLowTide.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get tideLowTide;

  /// No description provided for @tideHighTide.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get tideHighTide;

  /// No description provided for @tideRising.
  ///
  /// In en, this message translates to:
  /// **'Rising'**
  String get tideRising;

  /// No description provided for @tideNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No tide records yet'**
  String get tideNoRecords;

  /// No description provided for @tideSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Current tide recorded'**
  String get tideSavedToast;

  /// No description provided for @toolWorldClock.
  ///
  /// In en, this message translates to:
  /// **'World Clock'**
  String get toolWorldClock;

  /// No description provided for @toolWorldClockDesc.
  ///
  /// In en, this message translates to:
  /// **'Times around the globe'**
  String get toolWorldClockDesc;

  /// No description provided for @worldClockTitle.
  ///
  /// In en, this message translates to:
  /// **'World Clock'**
  String get worldClockTitle;

  /// No description provided for @worldClockLocalLabel.
  ///
  /// In en, this message translates to:
  /// **'Local Time'**
  String get worldClockLocalLabel;

  /// No description provided for @worldClockLocLabel.
  ///
  /// In en, this message translates to:
  /// **'Located Place'**
  String get worldClockLocLabel;

  /// No description provided for @worldClockLocating.
  ///
  /// In en, this message translates to:
  /// **'Locating…'**
  String get worldClockLocating;

  /// No description provided for @worldClockLocFailed.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable, showing device time'**
  String get worldClockLocFailed;

  /// No description provided for @worldClockCityBeijing.
  ///
  /// In en, this message translates to:
  /// **'Beijing'**
  String get worldClockCityBeijing;

  /// No description provided for @worldClockCityTokyo.
  ///
  /// In en, this message translates to:
  /// **'Tokyo'**
  String get worldClockCityTokyo;

  /// No description provided for @worldClockCitySingapore.
  ///
  /// In en, this message translates to:
  /// **'Singapore'**
  String get worldClockCitySingapore;

  /// No description provided for @worldClockCitySydney.
  ///
  /// In en, this message translates to:
  /// **'Sydney'**
  String get worldClockCitySydney;

  /// No description provided for @worldClockCityDubai.
  ///
  /// In en, this message translates to:
  /// **'Dubai'**
  String get worldClockCityDubai;

  /// No description provided for @worldClockCityLondon.
  ///
  /// In en, this message translates to:
  /// **'London'**
  String get worldClockCityLondon;

  /// No description provided for @worldClockCityParis.
  ///
  /// In en, this message translates to:
  /// **'Paris'**
  String get worldClockCityParis;

  /// No description provided for @worldClockCityNewYork.
  ///
  /// In en, this message translates to:
  /// **'New York'**
  String get worldClockCityNewYork;

  /// No description provided for @worldClockCityLosAngeles.
  ///
  /// In en, this message translates to:
  /// **'Los Angeles'**
  String get worldClockCityLosAngeles;

  /// No description provided for @worldClockRegion.
  ///
  /// In en, this message translates to:
  /// **'Country / Region'**
  String get worldClockRegion;

  /// No description provided for @worldClockSelectRegion.
  ///
  /// In en, this message translates to:
  /// **'Select country / region'**
  String get worldClockSelectRegion;

  /// No description provided for @worldClockSelectCity.
  ///
  /// In en, this message translates to:
  /// **'Select city'**
  String get worldClockSelectCity;

  /// No description provided for @worldClockCountryCn.
  ///
  /// In en, this message translates to:
  /// **'China'**
  String get worldClockCountryCn;

  /// No description provided for @worldClockCountryJp.
  ///
  /// In en, this message translates to:
  /// **'Japan'**
  String get worldClockCountryJp;

  /// No description provided for @worldClockCountrySg.
  ///
  /// In en, this message translates to:
  /// **'Singapore'**
  String get worldClockCountrySg;

  /// No description provided for @worldClockCountryAu.
  ///
  /// In en, this message translates to:
  /// **'Australia'**
  String get worldClockCountryAu;

  /// No description provided for @worldClockCountryAe.
  ///
  /// In en, this message translates to:
  /// **'UAE'**
  String get worldClockCountryAe;

  /// No description provided for @worldClockCountryGb.
  ///
  /// In en, this message translates to:
  /// **'UK'**
  String get worldClockCountryGb;

  /// No description provided for @worldClockCountryFr.
  ///
  /// In en, this message translates to:
  /// **'France'**
  String get worldClockCountryFr;

  /// No description provided for @worldClockCountryUs.
  ///
  /// In en, this message translates to:
  /// **'USA'**
  String get worldClockCountryUs;

  /// No description provided for @ucTitle.
  ///
  /// In en, this message translates to:
  /// **'Unit Converter'**
  String get ucTitle;

  /// No description provided for @ucFormula.
  ///
  /// In en, this message translates to:
  /// **'Formula: '**
  String get ucFormula;

  /// No description provided for @ucCommon.
  ///
  /// In en, this message translates to:
  /// **'Common Conversions'**
  String get ucCommon;

  /// No description provided for @forceTitle.
  ///
  /// In en, this message translates to:
  /// **'Force & Load Converter'**
  String get forceTitle;

  /// No description provided for @memoTitle.
  ///
  /// In en, this message translates to:
  /// **'Travel Memo'**
  String get memoTitle;

  /// No description provided for @memoAdd.
  ///
  /// In en, this message translates to:
  /// **'New Memo'**
  String get memoAdd;

  /// No description provided for @memoEmpty.
  ///
  /// In en, this message translates to:
  /// **'No memos yet, tap + to create'**
  String get memoEmpty;

  /// No description provided for @memoTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get memoTitleHint;

  /// No description provided for @memoFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get memoFieldTitle;

  /// No description provided for @memoTravelTime.
  ///
  /// In en, this message translates to:
  /// **'Travel Time'**
  String get memoTravelTime;

  /// No description provided for @memoTravelTimeHint.
  ///
  /// In en, this message translates to:
  /// **'Select time'**
  String get memoTravelTimeHint;

  /// No description provided for @memoKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get memoKeyHint;

  /// No description provided for @memoValueHint.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get memoValueHint;

  /// No description provided for @memoAddRow.
  ///
  /// In en, this message translates to:
  /// **'Add row'**
  String get memoAddRow;

  /// No description provided for @memoSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get memoSave;

  /// No description provided for @memoUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get memoUntitled;

  /// No description provided for @memoNoContent.
  ///
  /// In en, this message translates to:
  /// **'No content'**
  String get memoNoContent;

  /// No description provided for @memoDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get memoDelete;

  /// No description provided for @memoDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this memo?'**
  String get memoDeleteConfirm;

  /// No description provided for @memoCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get memoCancel;

  /// No description provided for @memoEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get memoEdit;

  /// No description provided for @memoTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get memoTemplateTitle;

  /// No description provided for @memoUseTemplate.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get memoUseTemplate;

  /// No description provided for @memoTemplateApplied.
  ///
  /// In en, this message translates to:
  /// **'Template applied'**
  String get memoTemplateApplied;

  /// No description provided for @memoTemplateHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a template to quickly create a memo'**
  String get memoTemplateHint;

  /// No description provided for @memoNewTemplate.
  ///
  /// In en, this message translates to:
  /// **'New Template'**
  String get memoNewTemplate;

  /// No description provided for @memoTemplateEmpty.
  ///
  /// In en, this message translates to:
  /// **'No templates yet, tap + to create'**
  String get memoTemplateEmpty;

  /// No description provided for @memoTemplateDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this template?'**
  String get memoTemplateDeleteConfirm;

  /// No description provided for @memoDaysLeftPrefix.
  ///
  /// In en, this message translates to:
  /// **''**
  String get memoDaysLeftPrefix;

  /// No description provided for @memoDaysLeftSuffix.
  ///
  /// In en, this message translates to:
  /// **' days left'**
  String get memoDaysLeftSuffix;

  /// No description provided for @memoTodayDepart.
  ///
  /// In en, this message translates to:
  /// **'Departing today'**
  String get memoTodayDepart;

  /// No description provided for @memoDeparted.
  ///
  /// In en, this message translates to:
  /// **'Departed'**
  String get memoDeparted;

  /// No description provided for @memoShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get memoShare;

  /// No description provided for @memoCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get memoCopy;

  /// No description provided for @memoCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get memoCopied;

  /// No description provided for @memoSaveAsTemplate.
  ///
  /// In en, this message translates to:
  /// **'Save as Template'**
  String get memoSaveAsTemplate;

  /// No description provided for @memoTemplateCreated.
  ///
  /// In en, this message translates to:
  /// **'Saved as template'**
  String get memoTemplateCreated;

  /// No description provided for @memoExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get memoExpand;

  /// No description provided for @memoCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get memoCollapse;

  /// No description provided for @memoDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get memoDeleted;

  /// No description provided for @memoUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get memoUndo;

  /// No description provided for @statToolsUsed.
  ///
  /// In en, this message translates to:
  /// **'Tools Used'**
  String get statToolsUsed;

  /// No description provided for @statAppToolUsage.
  ///
  /// In en, this message translates to:
  /// **'App Total Uses'**
  String get statAppToolUsage;

  /// No description provided for @statFreeRemaining.
  ///
  /// In en, this message translates to:
  /// **'Free Left'**
  String get statFreeRemaining;

  /// No description provided for @vipTitle.
  ///
  /// In en, this message translates to:
  /// **'Pro Unlock'**
  String get vipTitle;

  /// No description provided for @vipDesc.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase. No ads.'**
  String get vipDesc;

  /// No description provided for @vipOpen.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Now'**
  String get vipOpen;

  /// Remaining free uses shown next to Pro Unlock, decrements after each tool use
  ///
  /// In en, this message translates to:
  /// **'Free {count} uses left'**
  String freeRemainingCount(num count);

  /// No description provided for @freeLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Free trial used up'**
  String get freeLimitTitle;

  /// No description provided for @freeLimitBody.
  ///
  /// In en, this message translates to:
  /// **'You\'\'ve reached the free usage limit (10). Upgrade to Pro to unlock all tools.'**
  String get freeLimitBody;

  /// No description provided for @freeLimitUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Pro'**
  String get freeLimitUpgrade;

  /// No description provided for @vipSheetProductName.
  ///
  /// In en, this message translates to:
  /// **'Pro Unlock'**
  String get vipSheetProductName;

  /// No description provided for @vipSheetProductDesc.
  ///
  /// In en, this message translates to:
  /// **'Lifetime membership'**
  String get vipSheetProductDesc;

  /// No description provided for @vipSheetOneTime.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase'**
  String get vipSheetOneTime;

  /// No description provided for @vipSheetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm with Side Button'**
  String get vipSheetConfirm;

  /// No description provided for @vipDeveloping.
  ///
  /// In en, this message translates to:
  /// **'Membership activation coming soon'**
  String get vipDeveloping;

  /// No description provided for @vipPayConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Purchase'**
  String get vipPayConfirmTitle;

  /// vipPayConfirmBody
  ///
  /// In en, this message translates to:
  /// **'Pay {price} for the lifetime membership. One-time purchase, restorable with your Apple ID or Google account.'**
  String vipPayConfirmBody(Object price);

  /// No description provided for @vipPayStoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'App store unavailable. Please try again later'**
  String get vipPayStoreUnavailable;

  /// No description provided for @vipPayProductMissing.
  ///
  /// In en, this message translates to:
  /// **'Membership product is not available yet'**
  String get vipPayProductMissing;

  /// No description provided for @vipPayDebugProductMissing.
  ///
  /// In en, this message translates to:
  /// **'Debug build cannot query Play products. Install via Play internal app sharing or internal testing track, then purchase.'**
  String get vipPayDebugProductMissing;

  /// No description provided for @vipPaySheetOpened.
  ///
  /// In en, this message translates to:
  /// **'Payment sheet opened. Membership activates after payment'**
  String get vipPaySheetOpened;

  /// No description provided for @vipRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get vipRestore;

  /// No description provided for @vipRestoreDone.
  ///
  /// In en, this message translates to:
  /// **'Restore finished. Membership activated if previously purchased'**
  String get vipRestoreDone;

  /// No description provided for @vipRestoreEmpty.
  ///
  /// In en, this message translates to:
  /// **'No purchases found for this account'**
  String get vipRestoreEmpty;

  /// No description provided for @vipRestoreCheckAccount.
  ///
  /// In en, this message translates to:
  /// **'No purchase found. Restoring only checks the Google Play account signed in on this device, so make sure it is the same account you used to buy'**
  String get vipRestoreCheckAccount;

  /// No description provided for @vipRestoreAlready.
  ///
  /// In en, this message translates to:
  /// **'You are already a Pro member. No need to restore.'**
  String get vipRestoreAlready;

  /// No description provided for @vipBecomeMember.
  ///
  /// In en, this message translates to:
  /// **'Membership activated'**
  String get vipBecomeMember;

  /// No description provided for @syncMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Pro to your account'**
  String get syncMemberTitle;

  /// No description provided for @syncMemberBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep Pro on all your devices and restore it after reinstalling.'**
  String get syncMemberBody;

  /// No description provided for @syncMemberApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get syncMemberApple;

  /// No description provided for @syncMemberGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get syncMemberGoogle;

  /// No description provided for @syncMemberLater.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get syncMemberLater;

  /// No description provided for @syncMemberDone.
  ///
  /// In en, this message translates to:
  /// **'Pro synced to your account'**
  String get syncMemberDone;

  /// No description provided for @syncMemberFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed. Please try again later'**
  String get syncMemberFailed;

  /// No description provided for @syncMemberAction.
  ///
  /// In en, this message translates to:
  /// **'Sync Pro to account'**
  String get syncMemberAction;

  /// No description provided for @vipPurchaseAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Tool Box Pro Unlock'**
  String get vipPurchaseAppBarTitle;

  /// No description provided for @vipPurchaseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock all tools. One-time purchase. No ads.'**
  String get vipPurchaseSubtitle;

  /// No description provided for @statOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline Downloads'**
  String get statOffline;

  /// No description provided for @statCert.
  ///
  /// In en, this message translates to:
  /// **'My Certificates'**
  String get statCert;

  /// No description provided for @statRecord.
  ///
  /// In en, this message translates to:
  /// **'Study Records'**
  String get statRecord;

  /// No description provided for @countFiles.
  ///
  /// In en, this message translates to:
  /// **'5 files'**
  String get countFiles;

  /// No description provided for @countCert.
  ///
  /// In en, this message translates to:
  /// **'3 cards'**
  String get countCert;

  /// No description provided for @countDays.
  ///
  /// In en, this message translates to:
  /// **'12 days'**
  String get countDays;

  /// No description provided for @countFav.
  ///
  /// In en, this message translates to:
  /// **'128 items'**
  String get countFav;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @themeColorSetting.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeColorSetting;

  /// No description provided for @themeCoffee.
  ///
  /// In en, this message translates to:
  /// **'Coffee'**
  String get themeCoffee;

  /// No description provided for @themeBlue.
  ///
  /// In en, this message translates to:
  /// **'Sky'**
  String get themeBlue;

  /// No description provided for @langSetting.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get langSetting;

  /// No description provided for @saveNamePromptSetting.
  ///
  /// In en, this message translates to:
  /// **'Save Dialog'**
  String get saveNamePromptSetting;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCache;

  /// No description provided for @calculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get calculating;

  /// No description provided for @notifSetting.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifSetting;

  /// No description provided for @notifDeveloping.
  ///
  /// In en, this message translates to:
  /// **'Notifications coming soon'**
  String get notifDeveloping;

  /// No description provided for @accountSecurity.
  ///
  /// In en, this message translates to:
  /// **'Account Security'**
  String get accountSecurity;

  /// No description provided for @accountDeveloping.
  ///
  /// In en, this message translates to:
  /// **'Account & Security coming soon'**
  String get accountDeveloping;

  /// No description provided for @aboutGroup.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutGroup;

  /// No description provided for @checkUpdate.
  ///
  /// In en, this message translates to:
  /// **'Check for Update'**
  String get checkUpdate;

  /// No description provided for @rateUs.
  ///
  /// In en, this message translates to:
  /// **'Rate Us'**
  String get rateUs;

  /// No description provided for @rateUsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Cannot open the rating page right now. Please try again later'**
  String get rateUsUnavailable;

  /// No description provided for @aboutUs.
  ///
  /// In en, this message translates to:
  /// **'About Us'**
  String get aboutUs;

  /// No description provided for @userAgreement.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get userAgreement;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// privacyLastUpdated
  ///
  /// In en, this message translates to:
  /// **'Last updated: {date}'**
  String privacyLastUpdated(String date);

  /// No description provided for @privacyIntro.
  ///
  /// In en, this message translates to:
  /// **'This Privacy Policy explains how we collect, use, store and protect your information when you use this app. Please read it carefully before you start.'**
  String get privacyIntro;

  /// No description provided for @privacySecCollect.
  ///
  /// In en, this message translates to:
  /// **'1. Information We Collect'**
  String get privacySecCollect;

  /// No description provided for @privacySecCollectBody.
  ///
  /// In en, this message translates to:
  /// **'When you create an account, we collect your email address along with the nickname and avatar you choose to provide. For tool features such as the compass and noise detector, the app accesses the relevant device sensors only after you grant permission. We do not collect personal information unrelated to your use of this app.'**
  String get privacySecCollectBody;

  /// No description provided for @privacySecUse.
  ///
  /// In en, this message translates to:
  /// **'2. How We Use Information'**
  String get privacySecUse;

  /// No description provided for @privacySecUseBody.
  ///
  /// In en, this message translates to:
  /// **'Collected information is used only to create and maintain your account, sync your profile and membership benefits across devices, improve the product experience, and contact you when necessary. We never use your information for purposes unrelated to this app.'**
  String get privacySecUseBody;

  /// No description provided for @privacySecStore.
  ///
  /// In en, this message translates to:
  /// **'3. Data Storage and Security'**
  String get privacySecStore;

  /// No description provided for @privacySecStoreBody.
  ///
  /// In en, this message translates to:
  /// **'Account data is stored in a Supabase cloud database and protected with encrypted transfers and access control. Local caches such as images stay on your device only, and you can clear them anytime in Settings > Clear Cache.'**
  String get privacySecStoreBody;

  /// No description provided for @privacySecShare.
  ///
  /// In en, this message translates to:
  /// **'4. Information Sharing'**
  String get privacySecShare;

  /// No description provided for @privacySecShareBody.
  ///
  /// In en, this message translates to:
  /// **'We do not sell or rent your personal information. We share only the minimum data required in these cases: with payment platforms (Apple App Store / Google Play) to complete membership purchases, and where required by law or necessary to protect our legal rights.'**
  String get privacySecShareBody;

  /// No description provided for @privacySecAds.
  ///
  /// In en, this message translates to:
  /// **'5. Advertising'**
  String get privacySecAds;

  /// No description provided for @privacySecAdsBody.
  ///
  /// In en, this message translates to:
  /// **'The free version shows banner ads at a few places within the app, served by Google AdMob. AdMob may use device identifiers and ad interaction data to select and measure ads, as described in the Google privacy policy. No ad is loaded once you purchase Pro Unlock. This app does not request the App Tracking Transparency permission and does not send your tool data to ad networks.'**
  String get privacySecAdsBody;

  /// No description provided for @privacySecRights.
  ///
  /// In en, this message translates to:
  /// **'6. Your Rights'**
  String get privacySecRights;

  /// No description provided for @privacySecRightsBody.
  ///
  /// In en, this message translates to:
  /// **'You may at any time change your nickname and avatar in Edit Profile, delete local data in Settings > Clear Cache, and delete your cloud profile by deleting your account. To export or request deletion of your data, contact us using the details below.'**
  String get privacySecRightsBody;

  /// No description provided for @privacySecUpdate.
  ///
  /// In en, this message translates to:
  /// **'7. Policy Updates'**
  String get privacySecUpdate;

  /// No description provided for @privacySecUpdateBody.
  ///
  /// In en, this message translates to:
  /// **'We may update this policy from time to time. The latest version is always published on this page, and we will notify you in the app for significant changes. We recommend reviewing this page periodically.'**
  String get privacySecUpdateBody;

  /// No description provided for @privacySecContact.
  ///
  /// In en, this message translates to:
  /// **'8. Contact Us'**
  String get privacySecContact;

  /// No description provided for @privacySecContactBody.
  ///
  /// In en, this message translates to:
  /// **'If you have any questions or suggestions about this Privacy Policy, please reach us at support@aknot.uk. We will respond within a reasonable period.'**
  String get privacySecContactBody;

  /// No description provided for @agreementIntro.
  ///
  /// In en, this message translates to:
  /// **'This User Agreement sets out the terms that apply when you use this app, and the rights and obligations between you and us. Please read it carefully before you start. By using this app, you agree to be bound by this Agreement.'**
  String get agreementIntro;

  /// No description provided for @agreementSecAccept.
  ///
  /// In en, this message translates to:
  /// **'1. Acceptance of the Agreement'**
  String get agreementSecAccept;

  /// No description provided for @agreementSecAcceptBody.
  ///
  /// In en, this message translates to:
  /// **'This Agreement is a binding contract between you and us. If you do not agree to any part of it, please stop using the app. If you are a minor, please read it together with your parent or guardian.'**
  String get agreementSecAcceptBody;

  /// No description provided for @agreementSecService.
  ///
  /// In en, this message translates to:
  /// **'2. The Service'**
  String get agreementSecService;

  /// No description provided for @agreementSecServiceBody.
  ///
  /// In en, this message translates to:
  /// **'This app provides a set of practical on-device tools, including memo, compass, noise detector, level, ruler, flashlight and tide tables. Features may be adjusted as the product evolves, and we will do our best to keep the experience stable.'**
  String get agreementSecServiceBody;

  /// No description provided for @agreementSecAccount.
  ///
  /// In en, this message translates to:
  /// **'3. Your Account'**
  String get agreementSecAccount;

  /// No description provided for @agreementSecAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Some features require an account. You can sign in with Apple or Google, or continue as a guest. You are responsible for keeping your account credentials safe and for activity carried out under your account. Your account data is stored in a Supabase cloud database, as described in our Privacy Policy.'**
  String get agreementSecAccountBody;

  /// No description provided for @agreementSecFree.
  ///
  /// In en, this message translates to:
  /// **'4. Free Usage and Advertising'**
  String get agreementSecFree;

  /// No description provided for @agreementSecFreeBody.
  ///
  /// In en, this message translates to:
  /// **'The free version includes a limited number of tool uses and shows banner ads served by Google AdMob. You can watch an in-app ad to earn additional free uses, up to the free limit. Usage counts are recorded on our servers and linked to a device identifier, so reinstalling the app does not reset them.'**
  String get agreementSecFreeBody;

  /// No description provided for @agreementSecPurchase.
  ///
  /// In en, this message translates to:
  /// **'5. Purchases and Refunds'**
  String get agreementSecPurchase;

  /// No description provided for @agreementSecPurchaseBody.
  ///
  /// In en, this message translates to:
  /// **'Pro Unlock is a one-time purchase that removes ads and lifts the free usage limit. All payments are processed by the Apple App Store or Google Play, and refunds are handled under the rules of that platform, so we cannot process refunds directly. Purchases are tied to your account; signing in on another device restores your benefits.'**
  String get agreementSecPurchaseBody;

  /// No description provided for @agreementSecConduct.
  ///
  /// In en, this message translates to:
  /// **'6. Acceptable Use'**
  String get agreementSecConduct;

  /// No description provided for @agreementSecConductBody.
  ///
  /// In en, this message translates to:
  /// **'You agree not to use this app for any unlawful purpose, not to interfere with its normal operation, and not to reverse engineer, decompile or attempt to extract its source code. You also agree not to use automated means to access the service in bulk.'**
  String get agreementSecConductBody;

  /// No description provided for @agreementSecIp.
  ///
  /// In en, this message translates to:
  /// **'7. Intellectual Property'**
  String get agreementSecIp;

  /// No description provided for @agreementSecIpBody.
  ///
  /// In en, this message translates to:
  /// **'The app, including its code, design, icons, text and other materials, is owned by us and protected by applicable laws. You may use the app for personal purposes only, and may not copy, modify, distribute or use any part of it commercially without our written permission.'**
  String get agreementSecIpBody;

  /// No description provided for @agreementSecDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'8. Disclaimer'**
  String get agreementSecDisclaimer;

  /// No description provided for @agreementSecDisclaimerBody.
  ///
  /// In en, this message translates to:
  /// **'Tool readings such as those from the compass, noise detector and level come from your device sensors and are indicative only. They are not a substitute for professional instruments and must not be used where accuracy is safety-critical, such as in construction, medical or legal contexts. We do not accept liability for losses arising from reliance on these readings.'**
  String get agreementSecDisclaimerBody;

  /// No description provided for @agreementSecUpdate.
  ///
  /// In en, this message translates to:
  /// **'9. Changes to This Agreement'**
  String get agreementSecUpdate;

  /// No description provided for @agreementSecUpdateBody.
  ///
  /// In en, this message translates to:
  /// **'We may update this Agreement from time to time. The latest version is always shown on this page, and we will notify you in the app for significant changes. Continuing to use the app after an update means you accept the revised Agreement.'**
  String get agreementSecUpdateBody;

  /// No description provided for @agreementSecContact.
  ///
  /// In en, this message translates to:
  /// **'10. Contact Us'**
  String get agreementSecContact;

  /// No description provided for @agreementSecContactBody.
  ///
  /// In en, this message translates to:
  /// **'If you have any questions or suggestions about this Agreement, please reach us at support@aknot.uk. We will respond within a reasonable period.'**
  String get agreementSecContactBody;

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get cacheCleared;

  /// No description provided for @langChinese.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get langChinese;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @langJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get langJapanese;

  /// No description provided for @langGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get langGerman;

  /// No description provided for @langFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get langFrench;

  /// No description provided for @toggleLightDark.
  ///
  /// In en, this message translates to:
  /// **'Toggle light / dark'**
  String get toggleLightDark;

  /// No description provided for @sectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General Tools'**
  String get sectionGeneral;

  /// No description provided for @toolForce.
  ///
  /// In en, this message translates to:
  /// **'Force & Load Converter'**
  String get toolForce;

  /// No description provided for @toolForceDesc.
  ///
  /// In en, this message translates to:
  /// **'Precise force conversion'**
  String get toolForceDesc;

  /// No description provided for @toolUnitConverter.
  ///
  /// In en, this message translates to:
  /// **'Unit Converter'**
  String get toolUnitConverter;

  /// No description provided for @toolUnitConverterDesc.
  ///
  /// In en, this message translates to:
  /// **'Length / Weight / Force'**
  String get toolUnitConverterDesc;

  /// No description provided for @toolTravelMemo.
  ///
  /// In en, this message translates to:
  /// **'Travel Memo'**
  String get toolTravelMemo;

  /// No description provided for @toolTravelMemoDesc.
  ///
  /// In en, this message translates to:
  /// **'Prepare for Every Great Trip'**
  String get toolTravelMemoDesc;

  /// No description provided for @toolCompass.
  ///
  /// In en, this message translates to:
  /// **'Compass'**
  String get toolCompass;

  /// No description provided for @toolCompassDesc.
  ///
  /// In en, this message translates to:
  /// **'Know your direction anytime'**
  String get toolCompassDesc;

  /// No description provided for @toolNoise.
  ///
  /// In en, this message translates to:
  /// **'Noise Detector'**
  String get toolNoise;

  /// No description provided for @toolNoiseDesc.
  ///
  /// In en, this message translates to:
  /// **'Ambient sound in decibels'**
  String get toolNoiseDesc;

  /// No description provided for @toolLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get toolLevel;

  /// No description provided for @toolLevelDesc.
  ///
  /// In en, this message translates to:
  /// **'Precise leveling'**
  String get toolLevelDesc;

  /// No description provided for @toolRuler.
  ///
  /// In en, this message translates to:
  /// **'Ruler'**
  String get toolRuler;

  /// No description provided for @toolRulerDesc.
  ///
  /// In en, this message translates to:
  /// **'Measure right on screen'**
  String get toolRulerDesc;

  /// No description provided for @toolFlashlight.
  ///
  /// In en, this message translates to:
  /// **'Flashlight'**
  String get toolFlashlight;

  /// No description provided for @toolFlashlightDesc.
  ///
  /// In en, this message translates to:
  /// **'Light your way'**
  String get toolFlashlightDesc;

  /// No description provided for @toolTide.
  ///
  /// In en, this message translates to:
  /// **'Tides'**
  String get toolTide;

  /// No description provided for @toolTideDesc.
  ///
  /// In en, this message translates to:
  /// **'Check tides anytime'**
  String get toolTideDesc;

  /// No description provided for @ucCatArea.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get ucCatArea;

  /// No description provided for @ucCatVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get ucCatVolume;

  /// No description provided for @ucCatTemp.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get ucCatTemp;

  /// No description provided for @ucCatSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get ucCatSpeed;

  /// No description provided for @ucCatWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get ucCatWeight;

  /// No description provided for @ucCatLength.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get ucCatLength;

  /// No description provided for @unitSquareMeter.
  ///
  /// In en, this message translates to:
  /// **'Square meter (m²)'**
  String get unitSquareMeter;

  /// No description provided for @unitSquareKilometer.
  ///
  /// In en, this message translates to:
  /// **'Square kilometer (km²)'**
  String get unitSquareKilometer;

  /// No description provided for @unitHectare.
  ///
  /// In en, this message translates to:
  /// **'Hectare (ha)'**
  String get unitHectare;

  /// No description provided for @unitMu.
  ///
  /// In en, this message translates to:
  /// **'Mu'**
  String get unitMu;

  /// No description provided for @unitSquareFoot.
  ///
  /// In en, this message translates to:
  /// **'Square foot (ft²)'**
  String get unitSquareFoot;

  /// No description provided for @unitSquareMile.
  ///
  /// In en, this message translates to:
  /// **'Square mile (mi²)'**
  String get unitSquareMile;

  /// No description provided for @unitSquareYard.
  ///
  /// In en, this message translates to:
  /// **'Square yard (yd²)'**
  String get unitSquareYard;

  /// No description provided for @unitAcre.
  ///
  /// In en, this message translates to:
  /// **'Acre (ac)'**
  String get unitAcre;

  /// No description provided for @unitSquareInch.
  ///
  /// In en, this message translates to:
  /// **'Square inch (in²)'**
  String get unitSquareInch;

  /// No description provided for @unitMeterPerSec.
  ///
  /// In en, this message translates to:
  /// **'Meter/second (m/s)'**
  String get unitMeterPerSec;

  /// No description provided for @unitKmPerHour.
  ///
  /// In en, this message translates to:
  /// **'Kilometer/hour (km/h)'**
  String get unitKmPerHour;

  /// No description provided for @unitMilePerHour.
  ///
  /// In en, this message translates to:
  /// **'Mile/hour (mph)'**
  String get unitMilePerHour;

  /// No description provided for @unitFootPerSec.
  ///
  /// In en, this message translates to:
  /// **'Foot/second (ft/s)'**
  String get unitFootPerSec;

  /// No description provided for @unitKnot.
  ///
  /// In en, this message translates to:
  /// **'Knot (kn)'**
  String get unitKnot;

  /// No description provided for @unitKilogram.
  ///
  /// In en, this message translates to:
  /// **'Kilogram (kg)'**
  String get unitKilogram;

  /// No description provided for @unitGram.
  ///
  /// In en, this message translates to:
  /// **'Gram (g)'**
  String get unitGram;

  /// No description provided for @unitMilligram.
  ///
  /// In en, this message translates to:
  /// **'Milligram (mg)'**
  String get unitMilligram;

  /// No description provided for @unitTon.
  ///
  /// In en, this message translates to:
  /// **'Ton (t)'**
  String get unitTon;

  /// No description provided for @unitPound.
  ///
  /// In en, this message translates to:
  /// **'Pound (lb)'**
  String get unitPound;

  /// No description provided for @unitOunce.
  ///
  /// In en, this message translates to:
  /// **'Ounce (oz)'**
  String get unitOunce;

  /// No description provided for @unitJin.
  ///
  /// In en, this message translates to:
  /// **'Jin'**
  String get unitJin;

  /// No description provided for @unitLiang.
  ///
  /// In en, this message translates to:
  /// **'Liang'**
  String get unitLiang;

  /// No description provided for @unitLiter.
  ///
  /// In en, this message translates to:
  /// **'Liter (L)'**
  String get unitLiter;

  /// No description provided for @unitMilliliter.
  ///
  /// In en, this message translates to:
  /// **'Milliliter (mL)'**
  String get unitMilliliter;

  /// No description provided for @unitCubicMeter.
  ///
  /// In en, this message translates to:
  /// **'Cubic meter (m³)'**
  String get unitCubicMeter;

  /// No description provided for @unitCubicCentimeter.
  ///
  /// In en, this message translates to:
  /// **'Cubic centimeter (cm³)'**
  String get unitCubicCentimeter;

  /// No description provided for @unitGallon.
  ///
  /// In en, this message translates to:
  /// **'Gallon (US) (gal)'**
  String get unitGallon;

  /// No description provided for @unitQuart.
  ///
  /// In en, this message translates to:
  /// **'Quart (US) (qt)'**
  String get unitQuart;

  /// No description provided for @unitPint.
  ///
  /// In en, this message translates to:
  /// **'Pint (US) (pt)'**
  String get unitPint;

  /// No description provided for @unitCup.
  ///
  /// In en, this message translates to:
  /// **'Cup (US) (cup)'**
  String get unitCup;

  /// No description provided for @unitCubicFoot.
  ///
  /// In en, this message translates to:
  /// **'Cubic foot (ft³)'**
  String get unitCubicFoot;

  /// No description provided for @unitCubicInch.
  ///
  /// In en, this message translates to:
  /// **'Cubic inch (in³)'**
  String get unitCubicInch;

  /// No description provided for @unitMeter.
  ///
  /// In en, this message translates to:
  /// **'Meter (m)'**
  String get unitMeter;

  /// No description provided for @unitKilometer.
  ///
  /// In en, this message translates to:
  /// **'Kilometer (km)'**
  String get unitKilometer;

  /// No description provided for @unitCentimeter.
  ///
  /// In en, this message translates to:
  /// **'Centimeter (cm)'**
  String get unitCentimeter;

  /// No description provided for @unitMillimeter.
  ///
  /// In en, this message translates to:
  /// **'Millimeter (mm)'**
  String get unitMillimeter;

  /// No description provided for @unitMile.
  ///
  /// In en, this message translates to:
  /// **'Mile (mi)'**
  String get unitMile;

  /// No description provided for @unitFoot.
  ///
  /// In en, this message translates to:
  /// **'Foot (ft)'**
  String get unitFoot;

  /// No description provided for @unitInch.
  ///
  /// In en, this message translates to:
  /// **'Inch (in)'**
  String get unitInch;

  /// No description provided for @unitYard.
  ///
  /// In en, this message translates to:
  /// **'Yard (yd)'**
  String get unitYard;

  /// No description provided for @unitNauticalMile.
  ///
  /// In en, this message translates to:
  /// **'Nautical mile (nmi)'**
  String get unitNauticalMile;

  /// No description provided for @unitCelsius.
  ///
  /// In en, this message translates to:
  /// **'Celsius (°C)'**
  String get unitCelsius;

  /// No description provided for @unitFahrenheit.
  ///
  /// In en, this message translates to:
  /// **'Fahrenheit (°F)'**
  String get unitFahrenheit;

  /// No description provided for @unitKelvin.
  ///
  /// In en, this message translates to:
  /// **'Kelvin (K)'**
  String get unitKelvin;

  /// No description provided for @unitNewton.
  ///
  /// In en, this message translates to:
  /// **'Newton (N)'**
  String get unitNewton;

  /// No description provided for @unitKilonewton.
  ///
  /// In en, this message translates to:
  /// **'Kilonewton (kN)'**
  String get unitKilonewton;

  /// No description provided for @unitKilogramForce.
  ///
  /// In en, this message translates to:
  /// **'Kilogram-force (kgf)'**
  String get unitKilogramForce;

  /// No description provided for @unitPoundForce.
  ///
  /// In en, this message translates to:
  /// **'Pound-force (lbf)'**
  String get unitPoundForce;

  /// No description provided for @unitTonForce.
  ///
  /// In en, this message translates to:
  /// **'Ton-force (tf)'**
  String get unitTonForce;

  /// No description provided for @tideHigh.
  ///
  /// In en, this message translates to:
  /// **'High tide'**
  String get tideHigh;

  /// No description provided for @tideEbbing.
  ///
  /// In en, this message translates to:
  /// **'Ebbing'**
  String get tideEbbing;

  /// tideDateFormat
  ///
  /// In en, this message translates to:
  /// **'{month}/{day} {hour}:{min}'**
  String tideDateFormat(Object month, Object day, Object hour, Object min);

  /// No description provided for @darkModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkModeLabel;

  /// devToast
  ///
  /// In en, this message translates to:
  /// **'{title} (In development)'**
  String devToast(Object title);

  /// No description provided for @profileNotLogin.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get profileNotLogin;

  /// No description provided for @profileTapLogin.
  ///
  /// In en, this message translates to:
  /// **'Tap to sign in / sign up'**
  String get profileTapLogin;

  /// No description provided for @profileGuest.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get profileGuest;

  /// No description provided for @profileNoEmail.
  ///
  /// In en, this message translates to:
  /// **'No email linked'**
  String get profileNoEmail;

  /// No description provided for @profileMemberVip.
  ///
  /// In en, this message translates to:
  /// **'VIP'**
  String get profileMemberVip;

  /// No description provided for @profileMemberFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get profileMemberFree;

  /// No description provided for @profileLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile'**
  String get profileLoadFailed;

  /// No description provided for @profileRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get profileRetry;

  /// No description provided for @profileSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get profileSignOut;

  /// No description provided for @profileSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out of the current account?'**
  String get profileSignOutConfirm;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete your account? This cannot be undone.'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'All your local and cloud data will be permanently removed and cannot be recovered.'**
  String get deleteAccountWarning;

  /// No description provided for @deleteAccountDone.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get deleteAccountDone;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account. Please try again later.'**
  String get deleteAccountFailed;

  /// No description provided for @profileEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEditTitle;

  /// No description provided for @profileEditName.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get profileEditName;

  /// No description provided for @profileEditNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a nickname'**
  String get profileEditNameHint;

  /// No description provided for @profileEditNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nickname cannot be empty'**
  String get profileEditNameEmpty;

  /// No description provided for @profileEditAvatarTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose an avatar'**
  String get profileEditAvatarTitle;

  /// No description provided for @profileEditCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current avatar'**
  String get profileEditCurrent;

  /// No description provided for @profileEditShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get profileEditShuffle;

  /// No description provided for @profileEditSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileEditSave;

  /// No description provided for @profileEditSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileEditSaved;

  /// No description provided for @profileEditFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get profileEditFailed;

  /// No description provided for @profileEditNeedLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in to edit your profile'**
  String get profileEditNeedLogin;

  /// No description provided for @dialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dialogCancel;

  /// No description provided for @dialogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get dialogConfirm;

  /// No description provided for @vipActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Pro Unlock · Active'**
  String get vipActiveTitle;

  /// No description provided for @vipLifetime.
  ///
  /// In en, this message translates to:
  /// **'Lifetime membership, no expiry'**
  String get vipLifetime;

  /// vipExpireAt
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}'**
  String vipExpireAt(Object date);

  /// splashSkip
  ///
  /// In en, this message translates to:
  /// **'Skip {seconds}s'**
  String splashSkip(Object seconds);

  /// thirdPartySdk
  ///
  /// In en, this message translates to:
  /// **'Third-party SDKs'**
  String get thirdPartySdk;

  /// adWatchForFreeUses
  ///
  /// In en, this message translates to:
  /// **'Watch one ad to get {count} free uses'**
  String adWatchForFreeUses(num count);

  /// adRewardProgress
  ///
  /// In en, this message translates to:
  /// **'Free uses left: {remaining}/{max}'**
  String adRewardProgress(num remaining, num max);

  /// adUnavailable
  ///
  /// In en, this message translates to:
  /// **'Ad unavailable, please try again later'**
  String get adUnavailable;

  /// adRewardSuccess
  ///
  /// In en, this message translates to:
  /// **'Earned {count} free uses'**
  String adRewardSuccess(num count);

  /// adNotFinished
  ///
  /// In en, this message translates to:
  /// **'Ad not finished, no reward this time'**
  String get adNotFinished;

  /// adLabel
  ///
  /// In en, this message translates to:
  /// **'Ad'**
  String get adLabel;

  /// adPrivacySettings
  ///
  /// In en, this message translates to:
  /// **'Ad privacy settings'**
  String get adPrivacySettings;

  /// webUnsupported
  ///
  /// In en, this message translates to:
  /// **'The in-app browser is not available on this platform'**
  String get webUnsupported;

  /// webLoadFailed
  ///
  /// In en, this message translates to:
  /// **'Failed to load the page'**
  String get webLoadFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return lookupAppLocalizations(locale);
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'fr', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

Future<AppLocalizations> lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return app_localizations_de.loadLibrary().then(
        (dynamic _) => app_localizations_de.AppLocalizationsDe(),
      );
    case 'en':
      return app_localizations_en.loadLibrary().then(
        (dynamic _) => app_localizations_en.AppLocalizationsEn(),
      );
    case 'fr':
      return app_localizations_fr.loadLibrary().then(
        (dynamic _) => app_localizations_fr.AppLocalizationsFr(),
      );
    case 'ja':
      return app_localizations_ja.loadLibrary().then(
        (dynamic _) => app_localizations_ja.AppLocalizationsJa(),
      );
    case 'zh':
      return app_localizations_zh.loadLibrary().then(
        (dynamic _) => app_localizations_zh.AppLocalizationsZh(),
      );
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
