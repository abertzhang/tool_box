// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Themen-Demo';

  @override
  String get profile => 'Profil';

  @override
  String get tools => 'Werkzeuge';

  @override
  String get login => 'Anmelden';

  @override
  String get registerTitle => 'Konto erstellen';

  @override
  String get nicknameHint => 'Spitzname (optional)';

  @override
  String get emailHint => 'E-Mail';

  @override
  String get passwordHint => 'Passwort';

  @override
  String get confirmPasswordHint => 'Passwort bestätigen';

  @override
  String get registerSubmit => 'Registrieren';

  @override
  String get googleSignUp => 'Mit Google fortfahren';

  @override
  String get appleSignUp => 'Mit Apple fortfahren';

  @override
  String get appleSignIn => 'Mit Apple anmelden';

  @override
  String get googleSignIn => 'Mit Google anmelden';

  @override
  String get emailSignIn => 'Mit E-Mail anmelden';

  @override
  String get haveAccountLogin => 'Bereits ein Konto? Anmelden';

  @override
  String get errEmailInvalid => 'Bitte eine gültige E-Mail-Adresse eingeben';

  @override
  String get errPasswordShort =>
      'Das Passwort muss mindestens 6 Zeichen lang sein';

  @override
  String get errNetworkReset =>
      'Die Verbindung wurde vom Server zurückgesetzt. Versuchen Sie ein anderes WLAN/Mobilfunknetz oder deaktivieren Sie Proxy/VPN und versuchen Sie es erneut';

  @override
  String get errPasswordMismatch => 'Passwörter stimmen nicht überein';

  @override
  String get registerSuccess => 'Registrierung erfolgreich';

  @override
  String get loginSubtitle =>
      'Ihr Werkzeugkoffer · Anmelden, um alles freizuschalten';

  @override
  String get loginSubmit => 'Anmelden';

  @override
  String get loginSuccess => 'Erfolgreich angemeldet';

  @override
  String get forgotPassword => 'Passwort vergessen?';

  @override
  String get forgotPasswordDesc =>
      'Geben Sie Ihre E-Mail ein, und wir senden Ihnen einen Link zum Zurücksetzen des Passworts.';

  @override
  String get sendResetLink => 'Reset-Link senden';

  @override
  String get resetPasswordSent => 'Passwort-Reset-Link gesendet';

  @override
  String get emailNotRegistered => 'Kein Konto mit dieser E-Mail gefunden';

  @override
  String get emailCheckFailed =>
      'Diese E-Mail konnte nicht verifiziert werden. Bitte erneut versuchen.';

  @override
  String get resetPasswordTitle => 'Neues Passwort festlegen';

  @override
  String get resetPasswordDesc =>
      'Wählen Sie ein neues Passwort für Ihr Konto.';

  @override
  String get newPasswordHint => 'Neues Passwort';

  @override
  String get resetPasswordSubmit => 'Passwort aktualisieren';

  @override
  String get resetPasswordSuccess =>
      'Ihr Passwort wurde aktualisiert. Bitte melden Sie sich erneut an.';

  @override
  String get resetLinkInvalid =>
      'Dieser Reset-Link ist ungültig oder abgelaufen. Bitte fordern Sie einen neuen an.';

  @override
  String get registerVerifyEmail =>
      'Registriert. Bitte prüfen Sie Ihre E-Mail zur Verifizierung.';

  @override
  String get verifyEmailTitle => 'E-Mail bestätigen';

  @override
  String get verifyEmailDesc =>
      'Wir haben einen 6-stelligen Code an Ihre E-Mail gesendet. Geben Sie ihn unten ein, um Ihr Konto zu aktivieren.';

  @override
  String get verifyCodeHint => '6-stelliger Code';

  @override
  String get verifyEmailSubmit => 'Bestätigen';

  @override
  String get verifyEmailResend => 'Code erneut senden';

  @override
  String get verifyEmailResent => 'Ein neuer Code wurde gesendet';

  @override
  String get verifyEmailResendFailed =>
      'Code konnte nicht erneut gesendet werden. Bitte erneut versuchen.';

  @override
  String get verifyEmailSuccess => 'Ihre E-Mail wurde verifiziert.';

  @override
  String get verifyEmailContinue => 'Weiter';

  @override
  String get errCodeInvalid => 'Ungültiger oder abgelaufener Code';

  @override
  String get errSupabaseNotReady =>
      'Supabase ist nicht initialisiert. Geben Sie SUPABASE_URL und SUPABASE_ANON_KEY über --dart-define an.';

  @override
  String get compassTitle => 'Kompass';

  @override
  String get compassSensorUnavailable =>
      'Dieses Gerät unterstützt keinen Kompass.';

  @override
  String get compassLock => 'Richtung fixieren';

  @override
  String get compassUnlock => 'Richtung lösen';

  @override
  String get compassDirN => 'N';

  @override
  String get compassDirNE => 'NO';

  @override
  String get compassDirE => 'O';

  @override
  String get compassDirSE => 'SO';

  @override
  String get compassDirS => 'S';

  @override
  String get compassDirSW => 'SW';

  @override
  String get compassDirW => 'W';

  @override
  String get compassDirNW => 'NW';

  @override
  String get compassHeading => 'Missweisung';

  @override
  String get compassAltitude => 'Höhe';

  @override
  String get compassLatitude => 'Breitengrad';

  @override
  String get compassLongitude => 'Längengrad';

  @override
  String get compassRecordLocation => 'Standort speichern';

  @override
  String get compassExport => 'Exportieren';

  @override
  String get compassHistory => 'Verlauf';

  @override
  String get compassViewAll => 'Alle ansehen';

  @override
  String get compassCollapse => 'Einklappen';

  @override
  String get compassNoRecords =>
      'Noch keine Einträge. Tippe auf „Standort speichern\", um einen Punkt zu sichern.';

  @override
  String get compassRecordDialogTitle => 'Standort speichern';

  @override
  String get compassRecordNameHint => 'Name (z. B. Camp A)';

  @override
  String get compassSave => 'Speichern';

  @override
  String get compassCancel => 'Abbrechen';

  @override
  String get compassRecordSaved => 'Eintrag gespeichert';

  @override
  String get compassSaveFailed =>
      'Speichern fehlgeschlagen. Bitte erneut versuchen.';

  @override
  String get compassLocationDenied =>
      'Der Standortzugriff ist ausgeschaltet, daher sind keine Koordinaten verfügbar';

  @override
  String get compassLocationServiceOff =>
      'Die Standortdienste sind aus. Aktivieren Sie sie in den Einstellungen.';

  @override
  String get compassOpenSettings => 'Einstellungen öffnen';

  @override
  String get compassExported => 'Alle Einträge in die Zwischenablage kopiert';

  @override
  String get compassDelete => 'Löschen';

  @override
  String get compassDeleteConfirm => 'Diesen Eintrag löschen?';

  @override
  String get compassLatLng => 'Koordinaten';

  @override
  String get compassDirection => 'Richtung';

  @override
  String get noiseTitle => 'Geräuschmesser';

  @override
  String get noiseCurrent => 'Aktuell';

  @override
  String get noiseAverage => 'Durchschnitt';

  @override
  String get noiseMin => 'Minimum';

  @override
  String get noiseMax => 'Maximum';

  @override
  String get noiseRecord => 'Geräusch aufnehmen';

  @override
  String get noiseExport => 'Exportieren';

  @override
  String get noiseHistory => 'Verlauf';

  @override
  String get noiseViewAll => 'Alle ansehen';

  @override
  String get noiseCollapse => 'Einklappen';

  @override
  String get noiseNoRecords => 'Noch keine Aufzeichnungen';

  @override
  String get noiseNoReading => 'Noch keine Messung, bitte warten';

  @override
  String get noiseZoneQuiet => 'Ruhig';

  @override
  String get noiseZoneModerate => 'Mäßig';

  @override
  String get noiseZoneLoud => 'Laut';

  @override
  String get noiseZoneQuietEnv => 'Ruhige Umgebung';

  @override
  String get noiseZoneModerateEnv => 'Mäßige Umgebung';

  @override
  String get noiseZoneLoudEnv => 'Lautes Umgebung';

  @override
  String get noiseCatQuiet => 'Ruhig';

  @override
  String get noiseCatModerate => 'Normal';

  @override
  String get noiseCatLoud => 'Laut';

  @override
  String get noiseEnvType => 'Umgebungstyp';

  @override
  String get noiseLevel => 'Pegel';

  @override
  String get noiseDbUnit => 'dB';

  @override
  String get noiseRecordTitle => 'Geräusch aufnehmen';

  @override
  String get noiseName => 'Name';

  @override
  String get noiseNameHint => 'Namen eingeben (z. B. „Campingplatz“)';

  @override
  String get noiseEnvHint => 'Umgebungstyp (optional, z. B. „Wald“)';

  @override
  String get noiseSave => 'Speichern';

  @override
  String get noiseCancel => 'Abbrechen';

  @override
  String get noiseSaved => 'Lokal gespeichert';

  @override
  String get noiseExported => 'In die Zwischenablage exportiert';

  @override
  String get noiseDelete => 'Löschen';

  @override
  String get noiseDeleteConfirm => 'Diesen Eintrag löschen?';

  @override
  String get noiseMicDenied => 'Mikrofonzugriff verweigert';

  @override
  String get noiseMicNeedPermission =>
      'Für die Geräuschmessung ist der Mikrofonzugriff nötig';

  @override
  String get noiseMicRetry => 'Erneut versuchen & gewähren';

  @override
  String get noiseMicGrant => 'Gewähren & messen starten';

  @override
  String get noiseMicOpenSettings => 'In den Einstellungen öffnen';

  @override
  String get commonOpenSettings => 'Einstellungen öffnen';

  @override
  String get noiseToday => 'Heute';

  @override
  String get noiseYesterday => 'Gestern';

  @override
  String get levelTitle => 'Wasserwaage';

  @override
  String get levelBullseye => 'Kreisel-Wasserwaage';

  @override
  String get levelTubular => 'Röhren-Wasserwaage';

  @override
  String get levelCalibrated => 'Kalibriert';

  @override
  String get levelUncalibrated => 'Nicht kalibriert';

  @override
  String get levelStatusLabel => 'Status';

  @override
  String get levelStatusLevel => 'Waagerecht';

  @override
  String get levelStatusNear => 'Fast waagerecht';

  @override
  String get levelStatusTilt => 'Geneigt';

  @override
  String get levelVertical => 'Vertikal (Y-Achse)';

  @override
  String get levelHorizontal => 'Horizontal (X-Achse)';

  @override
  String get levelLock => 'Messwert fixieren';

  @override
  String get levelUnlock => 'Lösen';

  @override
  String get levelCalibrate => 'Wasserwaage kalibrieren';

  @override
  String get levelCalibratedToast => 'Auf den aktuellen Winkel kalibriert';

  @override
  String get levelHistory => 'Messungen';

  @override
  String get levelSave => 'Speichern';

  @override
  String get levelViewAll => 'Alle ansehen';

  @override
  String get levelCollapse => 'Einklappen';

  @override
  String get levelNoRecords => 'Noch keine Messungen';

  @override
  String get levelRecordTitle => 'Messung speichern';

  @override
  String get levelName => 'Name';

  @override
  String get levelNameHint => 'Name (optional)';

  @override
  String get levelCancel => 'Abbrechen';

  @override
  String get levelSaveAction => 'Speichern';

  @override
  String get levelSavedToast => 'Messung gespeichert';

  @override
  String get levelDelete => 'Löschen';

  @override
  String get levelDeleteConfirm => 'Diese Messung löschen?';

  @override
  String get levelDefaultName => 'Wasserwaagen-Messung';

  @override
  String get appShareSubject => 'Tool Box – Outdoor-Werkzeugkoffer';

  @override
  String get appShareBody =>
      'Wasserwaage, Lineal, Kompass, Geräuschmesser, Taschenlampe und mehr – alles in einer App für Outdoor-Arbeiten und Heimwerkerprojekte.';

  @override
  String get appShareFailed => 'Freigabe-Sheet kann nicht geöffnet werden';

  @override
  String get levelDescLevel => 'Perfekt waagerecht';

  @override
  String get levelDescNear => 'Fast waagerecht';

  @override
  String get levelDescTilt => 'Außer Waage';

  @override
  String get rulerTitle => 'Lineal';

  @override
  String get rulerUnitCm => 'cm';

  @override
  String get rulerUnitInch => 'Zoll';

  @override
  String get rulerLengthLabel => 'Länge';

  @override
  String get rulerCm => 'cm';

  @override
  String get rulerInch => 'Zoll';

  @override
  String get rulerTime => 'Zeit';

  @override
  String get rulerName => 'Name';

  @override
  String get rulerNameHint => 'Diese Messung benennen (optional)';

  @override
  String get rulerRecordTitle => 'Messung speichern';

  @override
  String get rulerCancel => 'Abbrechen';

  @override
  String get rulerSaveAction => 'Speichern';

  @override
  String get rulerSavedToast => 'Messung gespeichert';

  @override
  String get rulerExport => 'Exportieren';

  @override
  String get rulerExported => 'In die Zwischenablage exportiert';

  @override
  String get rulerHistory => 'Messungen';

  @override
  String get rulerNoRecords => 'Noch keine Messungen';

  @override
  String get rulerViewAll => 'Alle ansehen';

  @override
  String get rulerCollapse => 'Einklappen';

  @override
  String get rulerDelete => 'Löschen';

  @override
  String get rulerDeleteConfirm => 'Diese Messung löschen?';

  @override
  String get rulerDefaultName => 'Lineal-Messung';

  @override
  String get flashlightOn => 'An';

  @override
  String get flashlightPermissionDenied =>
      'Für die Taschenlampe ist die Kameraberechtigung nötig. Bitte in den Einstellungen aktivieren.';

  @override
  String get flashlightUnavailable =>
      'Dieses Gerät unterstützt keine Taschenlampe';

  @override
  String get tideTitle => 'Gezeiten';

  @override
  String get tideRecordCurrent => 'Jetzt aufnehmen';

  @override
  String get tideExported => 'In die Zwischenablage exportiert';

  @override
  String get tideScheduleTitle => 'Heutiger Gezeitenplan';

  @override
  String get tideCurrentHeight => 'Aktuelle Höhe';

  @override
  String tideTimeToHigh(Object time) {
    return 'Hochwasser in $time';
  }

  @override
  String get tideNextLow => 'Nächstes Niedrigwasser';

  @override
  String get tideNextHigh => 'Nächstes Hochwasser';

  @override
  String get tideHistory => 'Verlauf';

  @override
  String get tideViewAll => 'Alle ansehen';

  @override
  String get tideCollapse => 'Einklappen';

  @override
  String get tideLowTide => 'Niedrigwasser';

  @override
  String get tideHighTide => 'Hochwasser';

  @override
  String get tideRising => 'Steigend';

  @override
  String get tideNoRecords => 'Noch keine Gezeitenaufzeichnungen';

  @override
  String get tideSavedToast => 'Aktuelle Gezeiten aufgezeichnet';

  @override
  String get toolWorldClock => 'Weltuhr';

  @override
  String get toolWorldClockDesc => 'Uhrzeiten rund um den Globus';

  @override
  String get worldClockTitle => 'Weltuhr';

  @override
  String get worldClockLocalLabel => 'Ortszeit';

  @override
  String get worldClockLocLabel => 'Aktueller Ort';

  @override
  String get worldClockLocating => 'Ort wird ermittelt…';

  @override
  String get worldClockLocFailed =>
      'Standort nicht verfügbar, Gerätezeit wird angezeigt';

  @override
  String get worldClockCityBeijing => 'Peking';

  @override
  String get worldClockCityTokyo => 'Tokio';

  @override
  String get worldClockCitySingapore => 'Singapur';

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
  String get worldClockRegion => 'Land / Region';

  @override
  String get worldClockSelectRegion => 'Land / Region auswählen';

  @override
  String get worldClockSelectCity => 'Stadt auswählen';

  @override
  String get worldClockCountryCn => 'China';

  @override
  String get worldClockCountryJp => 'Japan';

  @override
  String get worldClockCountrySg => 'Singapur';

  @override
  String get worldClockCountryAu => 'Australien';

  @override
  String get worldClockCountryAe => 'VAE';

  @override
  String get worldClockCountryGb => 'UK';

  @override
  String get worldClockCountryFr => 'Frankreich';

  @override
  String get worldClockCountryUs => 'USA';

  @override
  String get ucTitle => 'Einheitenrechner';

  @override
  String get ucFormula => 'Formel: ';

  @override
  String get ucCommon => 'Häufige Umrechnungen';

  @override
  String get forceTitle => 'Kraft- & Lastrechner';

  @override
  String get memoTitle => 'Reisemerkzettel';

  @override
  String get memoAdd => 'Neuer Merkzettel';

  @override
  String get memoEmpty => 'Noch keine Merkzettel, tippe auf + zum Erstellen';

  @override
  String get memoTitleHint => 'Titel';

  @override
  String get memoFieldTitle => 'Titel';

  @override
  String get memoTravelTime => 'Reisezeit';

  @override
  String get memoTravelTimeHint => 'Zeit auswählen';

  @override
  String get memoKeyHint => 'Schlüssel';

  @override
  String get memoValueHint => 'Wert';

  @override
  String get memoAddRow => 'Zeile hinzufügen';

  @override
  String get memoSave => 'Speichern';

  @override
  String get memoUntitled => 'Ohne Titel';

  @override
  String get memoNoContent => 'Kein Inhalt';

  @override
  String get memoDelete => 'Löschen';

  @override
  String get memoDeleteConfirm => 'Diesen Merkzettel löschen?';

  @override
  String get memoCancel => 'Abbrechen';

  @override
  String get memoEdit => 'Bearbeiten';

  @override
  String get memoTemplateTitle => 'Vorlagen';

  @override
  String get memoUseTemplate => 'Verwenden';

  @override
  String get memoTemplateApplied => 'Vorlage angewendet';

  @override
  String get memoTemplateHint =>
      'Wählen Sie eine Vorlage, um schnell einen Merkzettel zu erstellen';

  @override
  String get memoNewTemplate => 'Neue Vorlage';

  @override
  String get memoTemplateEmpty =>
      'Noch keine Vorlagen, tippe auf + zum Erstellen';

  @override
  String get memoTemplateDeleteConfirm => 'Diese Vorlage löschen?';

  @override
  String get memoDaysLeftPrefix => 'Noch ';

  @override
  String get memoDaysLeftSuffix => ' Tage';

  @override
  String get memoTodayDepart => 'Heute Abreise';

  @override
  String get memoDeparted => 'Abgereist';

  @override
  String get memoShare => 'Teilen';

  @override
  String get memoCopy => 'Kopieren';

  @override
  String get memoCopied => 'Kopiert';

  @override
  String get memoSaveAsTemplate => 'Als Vorlage speichern';

  @override
  String get memoTemplateCreated => 'Als Vorlage gespeichert';

  @override
  String get memoExpand => 'Erweitern';

  @override
  String get memoCollapse => 'Einklappen';

  @override
  String get memoDeleted => 'Gelöscht';

  @override
  String get memoUndo => 'Rückgängig';

  @override
  String get statToolsUsed => 'Genutzte Werkzeuge';

  @override
  String get statAppToolUsage => 'App-Gesamtnutzung';

  @override
  String get statFreeRemaining => 'Kostenlos übrig';

  @override
  String get vipTitle => 'Pro freischalten';

  @override
  String get vipDesc => 'Einmalzahlung. Keine Werbung.';

  @override
  String get vipOpen => 'Jetzt upgraden';

  @override
  String freeRemainingCount(num count) {
    return 'Noch $count kostenlose Nutzungen';
  }

  @override
  String get freeLimitTitle => 'Kostenlose Testnutzung aufgebraucht';

  @override
  String get freeLimitBody =>
      'Sie haben das kostenlose Nutzungslimit (10) erreicht. Upgraden Sie auf Pro, um alle Werkzeuge freizuschalten.';

  @override
  String get freeLimitUpgrade => 'Pro upgraden';

  @override
  String get vipSheetProductName => 'Pro freischalten';

  @override
  String get vipSheetProductDesc => 'Mitgliedschaft auf Lebenszeit';

  @override
  String get vipSheetOneTime => 'Einmalzahlung';

  @override
  String get vipSheetConfirm => 'Mit Seitenknopf bestätigen';

  @override
  String get vipDeveloping => 'Mitgliedsaktivierung folgt in Kürze';

  @override
  String get vipPayConfirmTitle => 'Kauf bestätigen';

  @override
  String vipPayConfirmBody(Object price) {
    return 'Bezahlen Sie $price für die lebenslange Mitgliedschaft. Einmalzahlung, wiederherstellbar mit Ihrer Apple-ID oder Ihrem Google-Konto.';
  }

  @override
  String get vipPayStoreUnavailable =>
      'App-Store nicht verfügbar. Bitte später erneut versuchen.';

  @override
  String get vipPayProductMissing => 'Mitgliedsprodukt noch nicht verfügbar';

  @override
  String get vipPayDebugProductMissing =>
      'Debug-Build kann keine Play-Produkte abfragen. Installieren Sie über die interne App-Sharing- oder Testspur von Play und kaufen Sie dann.';

  @override
  String get vipPaySheetOpened =>
      'Zahlung geöffnet. Mitgliedschaft wird nach Zahlung aktiviert.';

  @override
  String get vipRestore => 'Käufe wiederherstellen';

  @override
  String get vipRestoreDone =>
      'Wiederherstellung abgeschlossen. Mitgliedschaft aktiviert, falls zuvor gekauft.';

  @override
  String get vipRestoreEmpty => 'Keine Käufe für dieses Konto gefunden';

  @override
  String get vipRestoreCheckAccount =>
      'Kein Kauf gefunden. Die Wiederherstellung prüft nur das auf diesem Gerät angemeldete Google-Play-Konto – stellen Sie sicher, dass es dasselbe Konto ist, mit dem Sie gekauft haben.';

  @override
  String get vipRestoreAlready =>
      'Sie sind bereits Pro-Mitglied. Keine Wiederherstellung nötig.';

  @override
  String get vipBecomeMember => 'Mitgliedschaft aktiviert';

  @override
  String get syncMemberTitle => 'Pro mit Ihrem Konto synchronisieren';

  @override
  String get syncMemberBody =>
      'Melden Sie sich an, um Pro auf allen Geräten zu behalten und nach Neuinstallation wiederherzustellen.';

  @override
  String get syncMemberApple => 'Über Apple fortfahren';

  @override
  String get syncMemberGoogle => 'Über Google fortfahren';

  @override
  String get syncMemberLater => 'Später';

  @override
  String get syncMemberDone => 'Pro mit Konto synchronisiert';

  @override
  String get syncMemberFailed =>
      'Synchronisierung fehlgeschlagen. Bitte später erneut versuchen.';

  @override
  String get syncMemberAction => 'Pro mit Konto synchronisieren';

  @override
  String get vipPurchaseAppBarTitle => 'Tool Box Pro freischalten';

  @override
  String get vipPurchaseSubtitle =>
      'Alle Werkzeuge auf einmal freischalten. Einmalzahlung. Keine Werbung.';

  @override
  String get statOffline => 'Offline-Downloads';

  @override
  String get statCert => 'Meine Zertifikate';

  @override
  String get statRecord => 'Lernstatistik';

  @override
  String get countFiles => '5 Dateien';

  @override
  String get countCert => '3 Karten';

  @override
  String get countDays => '12 Tage';

  @override
  String get countFav => '128 Einträge';

  @override
  String get settings => 'Einstellungen';

  @override
  String get themeColorSetting => 'Design';

  @override
  String get themeCoffee => 'Kaffee';

  @override
  String get themeBlue => 'Himmel';

  @override
  String get langSetting => 'Sprache';

  @override
  String get saveNamePromptSetting => 'Speicherdialog';

  @override
  String get clearCache => 'Cache leeren';

  @override
  String get calculating => 'Berechne…';

  @override
  String get notifSetting => 'Benachrichtigungen';

  @override
  String get notifDeveloping => 'Benachrichtigungen folgen in Kürze';

  @override
  String get accountSecurity => 'Kontosicherheit';

  @override
  String get accountDeveloping => 'Konto & Sicherheit folgen in Kürze';

  @override
  String get aboutGroup => 'Über';

  @override
  String get checkUpdate => 'Nach Update suchen';

  @override
  String get rateUs => 'Bewerten';

  @override
  String get rateUsUnavailable =>
      'Bewertungsseite kann gerade nicht geöffnet werden. Bitte später erneut versuchen.';

  @override
  String get aboutUs => 'Über uns';

  @override
  String get userAgreement => 'Nutzungsbedingungen';

  @override
  String get privacyPolicy => 'Datenschutz';

  @override
  String privacyLastUpdated(String date) {
    return 'Zuletzt aktualisiert: $date';
  }

  @override
  String get privacyIntro =>
      'Diese Datenschutzerklärung erläutert, wie wir die Informationen erheben, verwenden, speichern und schützen, die bei der Nutzung dieser App anfallen. Bitte lesen Sie sie vor der Nutzung sorgfältig durch.';

  @override
  String get privacySecCollect => '1. Informationen, die wir erheben';

  @override
  String get privacySecCollectBody =>
      'Bei der Kontoerstellung erheben wir Ihre E-Mail-Adresse sowie den von Ihnen gewählten Spitznamen und Avatar. Für Werkzeuge wie Kompass und Gerätmesser greift die App erst nach Ihrer Genehmigung auf die entsprechenden Sensors zu. Wir erheben keine personenbezogenen Daten, die nicht mit der Nutzung dieser App zusammenhängen.';

  @override
  String get privacySecUse => '2. Verwendung der Informationen';

  @override
  String get privacySecUseBody =>
      'Die erhobenen Informationen dienen ausschließlich der Erstellung und Verwaltung Ihres Kontos, der Synchronisierung von Profil und Mitgliedschaftsrechten über Geräte hinweg, der Verbesserung des Produkterlebnisses und der Kontaktaufnahme bei Bedarf. Wir verwenden Ihre Daten nie für Zwecke außerhalb dieser App.';

  @override
  String get privacySecStore => '3. Speicherung und Sicherheit der Daten';

  @override
  String get privacySecStoreBody =>
      'Kontodaten werden in einer Supabase-Cloud-Datenbank gespeichert und durch verschlüsselte Übertragung sowie Zugriffskontrolle geschützt. Lokale Caches wie Bilder verbleiben nur auf Ihrem Gerät und können jederzeit unter Einstellungen > Cache leeren entfernt werden.';

  @override
  String get privacySecShare => '4. Weitergabe von Informationen';

  @override
  String get privacySecShareBody =>
      'Wir verkaufen oder vermieten Ihre personenbezogenen Daten nicht. Wir geben nur die minimal erforderlichen Daten in folgenden Fällen weiter: an Zahlungsplattformen (Apple App Store / Google Play) zum Abschluss von Mitgliedschaftskäufen sowie dort, wo es gesetzlich vorgeschrieben ist oder zum Schutz unserer Rechte nötig ist.';

  @override
  String get privacySecAds => '5. Werbung';

  @override
  String get privacySecAdsBody =>
      'Die Gratisversion zeigt an wenigen Stellen Bannerwerbung von Google AdMob. AdMob kann Gerätekennungen und Werbeinteraktionsdaten verwenden, um Anzeigen auszuwählen und zu messen, wie in der Google-Datenschutzerklärung beschrieben. Nach dem Kauf von Pro wird keine Werbung mehr geladen. Diese App fordert die App-Tracking-Transparenz-Berechtigung nicht an und sendet keine Werkzeugdaten an Werbenetzwerke.';

  @override
  String get privacySecRights => '6. Ihre Rechte';

  @override
  String get privacySecRightsBody =>
      'Sie können jederzeit Ihren Spitznamen und Avatar unter „Profil bearbeiten“ ändern, lokale Daten unter Einstellungen > Cache leeren löschen und Ihr Cloud-Profil durch Löschen des Kontos entfernen. Um Ihre Daten zu exportieren oder löschen zu lassen, kontaktieren Sie uns über die unten stehenden Angaben.';

  @override
  String get privacySecUpdate => '7. Aktualisierungen dieser Richtlinie';

  @override
  String get privacySecUpdateBody =>
      'Wir können diese Richtlinie gelegentlich aktualisieren. Die jeweils aktuelle Version wird stets auf dieser Seite veröffentlicht, und bei wesentlichen Änderungen informieren wir Sie in der App. Wir empfehlen, diese Seite regelmäßig einzusehen.';

  @override
  String get privacySecContact => '8. Kontakt';

  @override
  String get privacySecContactBody =>
      'Wenn Sie Fragen oder Anregungen zu dieser Datenschutzerklärung haben, erreichen Sie uns unter support@aknot.uk. Wir antworten innerhalb angemessener Frist.';

  @override
  String get agreementIntro =>
      'Dieser Nutzervertrag legt die Bedingungen fest, die für die Nutzung dieser App gelten, sowie die Rechte und Pflichten zwischen Ihnen und uns. Bitte lesen Sie ihn vor der Nutzung sorgfältig durch. Durch die Nutzung dieser App erklären Sie sich mit diesem Vertrag einverstanden.';

  @override
  String get agreementSecAccept => '1. Annahme des Vertrags';

  @override
  String get agreementSecAcceptBody =>
      'Dieser Vertrag ist ein bindender Vertrag zwischen Ihnen und uns. Stimmen Sie keinem Teil davon zu, bitten wir Sie, die Nutzung der App zu beenden. Falls Sie minderjährig sind, lesen Sie ihn bitte zusammen mit Ihrem Elternteil oder Erziehungsberechtigten.';

  @override
  String get agreementSecService => '2. Der Dienst';

  @override
  String get agreementSecServiceBody =>
      'Diese App bietet eine Reihe praktischer, geräteinterner Werkzeuge: Merkzettel, Kompass, Gerätmesser, Wasserwaage, Lineal, Taschenlampe und Gezeiten. Funktionen können sich mit der Produktentwicklung ändern; wir bemühen uns, das Erlebnis stabil zu halten.';

  @override
  String get agreementSecAccount => '3. Ihr Konto';

  @override
  String get agreementSecAccountBody =>
      'Einige Funktionen erfordern ein Konto. Sie können sich mit Apple oder Google anmelden oder als Gast fortfahren. Sie sind für den Schutz Ihrer Kontodaten verantwortlich. Ihre Kontodaten werden in einer Supabase-Cloud-Datenbank gespeichert, wie in unserer Datenschutzerklärung beschrieben.';

  @override
  String get agreementSecFree => '4. Kostenlose Nutzung und Werbung';

  @override
  String get agreementSecFreeBody =>
      'Die Gratisversion enthält eine begrenzte Anzahl von Werkzeugnutzungen und zeigt von Google AdMob ausgelieferte Bannerwerbung. Sie können durch das Ansehen einer In-App-Werbung zusätzliche kostenlose Nutzungen erhalten, bis zum kostenlosen Limit. Nutzungszähler werden auf unseren Servern erfasst und mit einer Gerätekennung verknüpft, sodass eine Neuinstallation sie nicht zurücksetzt.';

  @override
  String get agreementSecPurchase => '5. Käufe und Rückerstattungen';

  @override
  String get agreementSecPurchaseBody =>
      'Pro freischalten ist ein einmaliger Kauf, der Werbung entfernt und das kostenlose Nutzungslimit aufhebt. Alle Zahlungen werden über den Apple App Store oder Google Play abgewickelt, und Rückerstattungen unterliegen den Regeln dieser Plattform, sodass wir direkte Rückerstattungen nicht bearbeiten können. Käufe sind an Ihr Konto gebunden; die Anmeldung auf einem anderen Gerät stellt Ihre Vorteile wieder her.';

  @override
  String get agreementSecConduct => '6. Angemessene Nutzung';

  @override
  String get agreementSecConductBody =>
      'Sie verpflichten sich, diese App nicht für rechtswidrige Zwecke zu nutzen, ihren normalen Betrieb nicht zu stören und sie nicht umzukehren, zu dekompilieren oder ihren Quellcode zu extrahieren. Ebenso verpflichten Sie sich, nicht automatisiert massenhaft auf den Dienst zuzugreifen.';

  @override
  String get agreementSecIp => '7. Geistiges Eigentum';

  @override
  String get agreementSecIpBody =>
      'Die App, einschließlich ihres Codes, Designs, Symbole, Textes und anderer Materialien, ist unser Eigentum und gesetzlich geschützt. Sie dürfen die App nur für persönliche Zwecke nutzen und dürfen keinen Teil davon ohne unsere schriftliche Genehmigung kopieren, modifizieren, verbreiten oder kommerziell verwenden.';

  @override
  String get agreementSecDisclaimer => '8. Haftungsausschluss';

  @override
  String get agreementSecDisclaimerBody =>
      'Messwerte von Werkzeugen wie Kompass, Gerätmesser und Wasserwaage stammen von den Sensoren Ihres Geräts und dienen nur als Hinweis. Sie ersetzen keine professionellen Messgeräte und dürfen nicht dort verwendet werden, wo Genauigkeit sicherheitskritisch ist, etwa im Bauwesen, in der Medizin oder vor Gericht. Wir übernehmen keine Haftung für Schäden durch Verlass auf diese Messwerte.';

  @override
  String get agreementSecUpdate => '9. Änderungen dieses Vertrags';

  @override
  String get agreementSecUpdateBody =>
      'Wir können diesen Vertrag gelegentlich aktualisieren. Die jeweils aktuelle Version wird stets auf dieser Seite angezeigt, und bei wesentlichen Änderungen informieren wir Sie in der App. Die weitere Nutzung nach einer Aktualisierung gilt als Annahme der überarbeiteten Fassung.';

  @override
  String get agreementSecContact => '10. Kontakt';

  @override
  String get agreementSecContactBody =>
      'Wenn Sie Fragen oder Anregungen zu diesem Nutzervertrag haben, erreichen Sie uns unter support@aknot.uk. Wir antworten innerhalb angemessener Frist.';

  @override
  String get cacheCleared => 'Cache geleert';

  @override
  String get langChinese => 'Chinesisch';

  @override
  String get langEnglish => 'Englisch';

  @override
  String get langJapanese => 'Japanisch';

  @override
  String get langGerman => 'Deutsch';

  @override
  String get langFrench => 'Französisch';

  @override
  String get toggleLightDark => 'Hell / Dunkel umschalten';

  @override
  String get sectionGeneral => 'Allgemeine Werkzeuge';

  @override
  String get toolForce => 'Kraft- & Lastrechner';

  @override
  String get toolForceDesc => 'Präzise Kraftumrechnung';

  @override
  String get toolUnitConverter => 'Einheitenrechner';

  @override
  String get toolUnitConverterDesc => 'Länge / Gewicht / Kraft';

  @override
  String get toolTravelMemo => 'Reisemerkzettel';

  @override
  String get toolTravelMemoDesc => 'Bereit für jede große Reise';

  @override
  String get toolCompass => 'Kompass';

  @override
  String get toolCompassDesc => 'Richtung jederzeit wissen';

  @override
  String get toolNoise => 'Geräuschmesser';

  @override
  String get toolNoiseDesc => 'Umgebungslärm in Dezibel';

  @override
  String get toolLevel => 'Wasserwaage';

  @override
  String get toolLevelDesc => 'Präzise Ausrichtung';

  @override
  String get toolRuler => 'Lineal';

  @override
  String get toolRulerDesc => 'Direkt auf dem Bildschirm messen';

  @override
  String get toolFlashlight => 'Taschenlampe';

  @override
  String get toolFlashlightDesc => 'Leuchtet den Weg aus';

  @override
  String get toolTide => 'Gezeiten';

  @override
  String get toolTideDesc => 'Gezeiten jederzeit prüfen';

  @override
  String get ucCatArea => 'Fläche';

  @override
  String get ucCatVolume => 'Volumen';

  @override
  String get ucCatTemp => 'Temperatur';

  @override
  String get ucCatSpeed => 'Geschwindigkeit';

  @override
  String get ucCatWeight => 'Gewicht';

  @override
  String get ucCatLength => 'Länge';

  @override
  String get unitSquareMeter => 'Quadratmeter (m²)';

  @override
  String get unitSquareKilometer => 'Quadratkilometer (km²)';

  @override
  String get unitHectare => 'Hektar (ha)';

  @override
  String get unitMu => 'Mu';

  @override
  String get unitSquareFoot => 'Quadratfuß (ft²)';

  @override
  String get unitSquareMile => 'Quadratmeile (mi²)';

  @override
  String get unitSquareYard => 'Quadratyard (yd²)';

  @override
  String get unitAcre => 'Acre (ac)';

  @override
  String get unitSquareInch => 'Quadratzoll (in²)';

  @override
  String get unitMeterPerSec => 'Meter/Sekunde (m/s)';

  @override
  String get unitKmPerHour => 'Kilometer/Stunde (km/h)';

  @override
  String get unitMilePerHour => 'Meile/Stunde (mph)';

  @override
  String get unitFootPerSec => 'Fuß/Sekunde (ft/s)';

  @override
  String get unitKnot => 'Knoten (kn)';

  @override
  String get unitKilogram => 'Kilogramm (kg)';

  @override
  String get unitGram => 'Gramm (g)';

  @override
  String get unitMilligram => 'Milligramm (mg)';

  @override
  String get unitTon => 'Tonne (t)';

  @override
  String get unitPound => 'Pfund (lb)';

  @override
  String get unitOunce => 'Unze (oz)';

  @override
  String get unitJin => 'Jin';

  @override
  String get unitLiang => 'Liang';

  @override
  String get unitLiter => 'Liter (L)';

  @override
  String get unitMilliliter => 'Milliliter (mL)';

  @override
  String get unitCubicMeter => 'Kubikmeter (m³)';

  @override
  String get unitCubicCentimeter => 'Kubikzentimeter (cm³)';

  @override
  String get unitGallon => 'Gallon (US) (gal)';

  @override
  String get unitQuart => 'Quart (US) (qt)';

  @override
  String get unitPint => 'Pint (US) (pt)';

  @override
  String get unitCup => 'Tasse (US) (cup)';

  @override
  String get unitCubicFoot => 'Kubikfuß (ft³)';

  @override
  String get unitCubicInch => 'Kubikzoll (in³)';

  @override
  String get unitMeter => 'Meter (m)';

  @override
  String get unitKilometer => 'Kilometer (km)';

  @override
  String get unitCentimeter => 'Zentimeter (cm)';

  @override
  String get unitMillimeter => 'Millimeter (mm)';

  @override
  String get unitMile => 'Meile (mi)';

  @override
  String get unitFoot => 'Fuß (ft)';

  @override
  String get unitInch => 'Zoll (in)';

  @override
  String get unitYard => 'Yard (yd)';

  @override
  String get unitNauticalMile => 'Seemeile (nmi)';

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
  String get unitKilogramForce => 'Kilogramm-Kraft (kgf)';

  @override
  String get unitPoundForce => 'Pfund-Kraft (lbf)';

  @override
  String get unitTonForce => 'Tonnen-Kraft (tf)';

  @override
  String get tideHigh => 'Hochwasser';

  @override
  String get tideEbbing => 'Ebbe';

  @override
  String tideDateFormat(Object month, Object day, Object hour, Object min) {
    return '$month/$day $hour:$min';
  }

  @override
  String get darkModeLabel => 'Dunkelmodus';

  @override
  String devToast(Object title) {
    return '$title (In Entwicklung)';
  }

  @override
  String get profileNotLogin => 'Nicht angemeldet';

  @override
  String get profileTapLogin => 'Tippen zum Anmelden / Registrieren';

  @override
  String get profileGuest => 'Benutzer';

  @override
  String get profileNoEmail => 'Keine E-Mail verknüpft';

  @override
  String get profileMemberVip => 'VIP';

  @override
  String get profileMemberFree => 'Kostenlos';

  @override
  String get profileLoadFailed => 'Profil konnte nicht geladen werden';

  @override
  String get profileRetry => 'Erneut versuchen';

  @override
  String get profileSignOut => 'Abmelden';

  @override
  String get profileSignOutConfirm => 'Aktuelles Konto abmelden?';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get deleteAccountConfirm =>
      'Konto löschen? Dies kann nicht rückgängig gemacht werden.';

  @override
  String get deleteAccountWarning =>
      'Alle Ihre lokalen und Cloud-Daten werden dauerhaft entfernt und können nicht wiederhergestellt werden.';

  @override
  String get deleteAccountDone => 'Konto gelöscht';

  @override
  String get deleteAccountFailed =>
      'Konto löschen fehlgeschlagen. Bitte später erneut versuchen.';

  @override
  String get profileEditTitle => 'Profil bearbeiten';

  @override
  String get profileEditName => 'Spitzname';

  @override
  String get profileEditNameHint => 'Spitznamen eingeben';

  @override
  String get profileEditNameEmpty => 'Spitzname darf nicht leer sein';

  @override
  String get profileEditAvatarTitle => 'Avatar wählen';

  @override
  String get profileEditCurrent => 'Aktueller Avatar';

  @override
  String get profileEditShuffle => 'Neu mischen';

  @override
  String get profileEditSave => 'Speichern';

  @override
  String get profileEditSaved => 'Profil aktualisiert';

  @override
  String get profileEditFailed => 'Speichern fehlgeschlagen';

  @override
  String get profileEditNeedLogin =>
      'Bitte zuerst anmelden, um das Profil zu bearbeiten';

  @override
  String get dialogCancel => 'Abbrechen';

  @override
  String get dialogConfirm => 'Bestätigen';

  @override
  String get vipActiveTitle => 'Pro freigeschaltet · Aktiv';

  @override
  String get vipLifetime => 'Mitgliedschaft auf Lebenszeit, unbefristet';

  @override
  String vipExpireAt(Object date) {
    return 'Gültig bis $date';
  }

  @override
  String splashSkip(Object seconds) {
    return 'Überspringen ${seconds}s';
  }

  @override
  String get thirdPartySdk => 'Drittanbieter-SDKs';

  @override
  String adWatchForFreeUses(num count) {
    return 'Ein Werbevideo ansehen, um $count kostenlose Nutzungen zu erhalten';
  }

  @override
  String adRewardProgress(num remaining, num max) {
    return 'Kostenlose Nutzungen übrig: $remaining/$max';
  }

  @override
  String get adUnavailable =>
      'Werbung nicht verfügbar, bitte später erneut versuchen';

  @override
  String adRewardSuccess(num count) {
    return 'Habe $count kostenlose Nutzungen erhalten';
  }

  @override
  String get adNotFinished => 'Werbung nicht beendet, diesmal keine Belohnung';

  @override
  String get adLabel => 'Werbung';

  @override
  String get adPrivacySettings => 'Werbe-Datenschutzeinstellungen';

  @override
  String get webUnsupported =>
      'Der integrierte Browser ist auf dieser Plattform nicht verfügbar';

  @override
  String get webLoadFailed => 'Seite konnte nicht geladen werden';
}
