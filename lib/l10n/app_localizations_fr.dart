// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Démo de thème';

  @override
  String get profile => 'Profil';

  @override
  String get tools => 'Outils';

  @override
  String get login => 'Se connecter';

  @override
  String get registerTitle => 'Créer un compte';

  @override
  String get nicknameHint => 'Pseudonyme (facultatif)';

  @override
  String get emailHint => 'E-mail';

  @override
  String get passwordHint => 'Mot de passe';

  @override
  String get confirmPasswordHint => 'Confirmer le mot de passe';

  @override
  String get registerSubmit => 'S\'inscrire';

  @override
  String get googleSignUp => 'Continuer avec Google';

  @override
  String get appleSignUp => 'Continuer avec Apple';

  @override
  String get appleSignIn => 'Se connecter avec Apple';

  @override
  String get googleSignIn => 'Se connecter avec Google';

  @override
  String get emailSignIn => 'Se connecter par e-mail';

  @override
  String get haveAccountLogin => 'Vous avez déjà un compte ? Se connecter';

  @override
  String get errEmailInvalid => 'Veuillez saisir une adresse e-mail valide';

  @override
  String get errPasswordShort =>
      'Le mot de passe doit comporter au moins 6 caractères';

  @override
  String get errNetworkReset =>
      'La connexion a été réinitialisée par le serveur. Essayez un autre réseau Wi-Fi/cellulaire, ou désactivez tout proxy/VPN, puis réessayez';

  @override
  String get errPasswordMismatch => 'Les mots de passe ne correspondent pas';

  @override
  String get registerSuccess => 'Inscription réussie';

  @override
  String get loginSubtitle =>
      'Votre boîte à outils · Connectez-vous pour tout débloquer';

  @override
  String get loginSubmit => 'Se connecter';

  @override
  String get loginSuccess => 'Connexion réussie';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get forgotPasswordDesc =>
      'Saisissez votre e-mail et nous vous enverrons un lien pour réinitialiser votre mot de passe.';

  @override
  String get sendResetLink => 'Envoyer le lien de réinitialisation';

  @override
  String get resetPasswordSent =>
      'Lien de réinitialisation du mot de passe envoyé';

  @override
  String get emailNotRegistered => 'Aucun compte trouvé avec cet e-mail';

  @override
  String get emailCheckFailed =>
      'Impossible de vérifier cet e-mail. Veuillez réessayer.';

  @override
  String get resetPasswordTitle => 'Définir un nouveau mot de passe';

  @override
  String get resetPasswordDesc =>
      'Choisissez un nouveau mot de passe pour votre compte.';

  @override
  String get newPasswordHint => 'Nouveau mot de passe';

  @override
  String get resetPasswordSubmit => 'Mettre à jour le mot de passe';

  @override
  String get resetPasswordSuccess =>
      'Votre mot de passe a été mis à jour. Veuillez vous reconnecter.';

  @override
  String get resetLinkInvalid =>
      'Ce lien de réinitialisation est invalide ou a expiré. Veuillez en demander un nouveau.';

  @override
  String get registerVerifyEmail =>
      'Inscrit. Veuillez vérifier votre e-mail pour confirmer.';

  @override
  String get verifyEmailTitle => 'Vérifiez votre e-mail';

  @override
  String get verifyEmailDesc =>
      'Nous avons envoyé un code à 6 chiffres à votre e-mail. Saisissez-le ci-dessous pour activer votre compte.';

  @override
  String get verifyCodeHint => 'Code à 6 chiffres';

  @override
  String get verifyEmailSubmit => 'Vérifier';

  @override
  String get verifyEmailResend => 'Renvoyer le code';

  @override
  String get verifyEmailResent => 'Un nouveau code a été envoyé';

  @override
  String get verifyEmailResendFailed =>
      'Impossible de renvoyer le code. Veuillez réessayer.';

  @override
  String get verifyEmailSuccess => 'Votre e-mail a été vérifié.';

  @override
  String get verifyEmailContinue => 'Continuer';

  @override
  String get errCodeInvalid => 'Code invalide ou expiré';

  @override
  String get errSupabaseNotReady =>
      'Supabase n\'est pas initialisé. Fournissez SUPABASE_URL et SUPABASE_ANON_KEY via --dart-define.';

  @override
  String get compassTitle => 'Boussole';

  @override
  String get compassSensorUnavailable =>
      'La boussole n\'est pas disponible sur cet appareil.';

  @override
  String get compassLock => 'Verrouiller le cap';

  @override
  String get compassUnlock => 'Déverrouiller le cap';

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
  String get compassDirSW => 'SO';

  @override
  String get compassDirW => 'O';

  @override
  String get compassDirNW => 'NO';

  @override
  String get compassHeading => 'Cap';

  @override
  String get compassAltitude => 'Altitude';

  @override
  String get compassLatitude => 'Latitude';

  @override
  String get compassLongitude => 'Longitude';

  @override
  String get compassRecordLocation => 'Enregistrer la position';

  @override
  String get compassExport => 'Exporter';

  @override
  String get compassHistory => 'Historique';

  @override
  String get compassViewAll => 'Tout voir';

  @override
  String get compassCollapse => 'Réduire';

  @override
  String get compassNoRecords =>
      'Aucun enregistrement pour l\'instant. Appuyez sur « Enregistrer la position » pour sauvegarder un point.';

  @override
  String get compassRecordDialogTitle => 'Enregistrer la position';

  @override
  String get compassRecordNameHint => 'Nom (ex. Camp A)';

  @override
  String get compassSave => 'Enregistrer';

  @override
  String get compassCancel => 'Annuler';

  @override
  String get compassRecordSaved => 'Enregistrement sauvegardé';

  @override
  String get compassSaveFailed =>
      'Échec de l\'enregistrement. Veuillez réessayer.';

  @override
  String get compassLocationDenied =>
      'L\'accès à la localisation est désactivé, les coordonnées sont donc indisponibles';

  @override
  String get compassLocationServiceOff =>
      'Les services de localisation sont désactivés. Activez-les dans les réglages.';

  @override
  String get compassOpenSettings => 'Ouvrir les réglages';

  @override
  String get compassExported =>
      'Tous les enregistrements copiés dans le presse-papiers';

  @override
  String get compassDelete => 'Supprimer';

  @override
  String get compassDeleteConfirm => 'Supprimer cet enregistrement ?';

  @override
  String get compassLatLng => 'Coordonnées';

  @override
  String get compassDirection => 'Direction';

  @override
  String get noiseTitle => 'Sonomètre';

  @override
  String get noiseCurrent => 'Actuel';

  @override
  String get noiseAverage => 'Moyenne';

  @override
  String get noiseMin => 'Min';

  @override
  String get noiseMax => 'Max';

  @override
  String get noiseRecord => 'Enregistrer le bruit';

  @override
  String get noiseExport => 'Exporter';

  @override
  String get noiseHistory => 'Historique';

  @override
  String get noiseViewAll => 'Tout voir';

  @override
  String get noiseCollapse => 'Réduire';

  @override
  String get noiseNoRecords => 'Aucun enregistrement pour l\'instant';

  @override
  String get noiseNoReading => 'Pas encore de lecture, veuillez patienter';

  @override
  String get noiseZoneQuiet => 'Calme';

  @override
  String get noiseZoneModerate => 'Modéré';

  @override
  String get noiseZoneLoud => 'Fort';

  @override
  String get noiseZoneQuietEnv => 'Environnement calme';

  @override
  String get noiseZoneModerateEnv => 'Environnement modéré';

  @override
  String get noiseZoneLoudEnv => 'Environnement bruyant';

  @override
  String get noiseCatQuiet => 'Calme';

  @override
  String get noiseCatModerate => 'Normal';

  @override
  String get noiseCatLoud => 'Fort';

  @override
  String get noiseEnvType => 'Type d\'environnement';

  @override
  String get noiseLevel => 'Niveau';

  @override
  String get noiseDbUnit => 'dB';

  @override
  String get noiseRecordTitle => 'Enregistrer le bruit';

  @override
  String get noiseName => 'Nom';

  @override
  String get noiseNameHint =>
      'Saisissez un nom (ex. « alentours du campement »)';

  @override
  String get noiseEnvHint =>
      'Type d\'environnement (facultatif, ex. « forêt »)';

  @override
  String get noiseSave => 'Enregistrer';

  @override
  String get noiseCancel => 'Annuler';

  @override
  String get noiseSaved => 'Enregistré localement';

  @override
  String get noiseExported => 'Exporté vers le presse-papiers';

  @override
  String get noiseDelete => 'Supprimer';

  @override
  String get noiseDeleteConfirm => 'Supprimer cet enregistrement ?';

  @override
  String get noiseMicDenied => 'Accès au microphone refusé';

  @override
  String get noiseMicNeedPermission =>
      'L\'accès au microphone est nécessaire pour mesurer le bruit';

  @override
  String get noiseMicRetry => 'Réessayer et autoriser';

  @override
  String get noiseMicGrant => 'Autoriser et commencer';

  @override
  String get noiseMicOpenSettings => 'Ouvrir les réglages';

  @override
  String get commonOpenSettings => 'Ouvrir les réglages';

  @override
  String get noiseToday => 'Aujourd\'hui';

  @override
  String get noiseYesterday => 'Hier';

  @override
  String get levelTitle => 'Niveau';

  @override
  String get levelBullseye => 'Niveau à bulle centrale';

  @override
  String get levelTubular => 'Niveau à bulle tubulaire';

  @override
  String get levelCalibrated => 'Calibré';

  @override
  String get levelUncalibrated => 'Non calibré';

  @override
  String get levelStatusLabel => 'État';

  @override
  String get levelStatusLevel => 'Niveau';

  @override
  String get levelStatusNear => 'Presque niveau';

  @override
  String get levelStatusTilt => 'Incliné';

  @override
  String get levelVertical => 'Vertical (axe Y)';

  @override
  String get levelHorizontal => 'Horizontal (axe X)';

  @override
  String get levelLock => 'Verrouiller la lecture';

  @override
  String get levelUnlock => 'Déverrouiller';

  @override
  String get levelCalibrate => 'Calibrer le niveau';

  @override
  String get levelCalibratedToast => 'Calibré sur l\'angle actuel';

  @override
  String get levelHistory => 'Mesures';

  @override
  String get levelSave => 'Enregistrer';

  @override
  String get levelViewAll => 'Tout voir';

  @override
  String get levelCollapse => 'Réduire';

  @override
  String get levelNoRecords => 'Aucune mesure pour l\'instant';

  @override
  String get levelRecordTitle => 'Enregistrer la mesure';

  @override
  String get levelName => 'Nom';

  @override
  String get levelNameHint => 'Nom (facultatif)';

  @override
  String get levelCancel => 'Annuler';

  @override
  String get levelSaveAction => 'Enregistrer';

  @override
  String get levelSavedToast => 'Mesure enregistrée';

  @override
  String get levelDelete => 'Supprimer';

  @override
  String get levelDeleteConfirm => 'Supprimer cette mesure ?';

  @override
  String get levelDefaultName => 'Mesure de niveau';

  @override
  String get appShareSubject => 'Tool Box – Boîte à outils de plein air';

  @override
  String get appShareBody =>
      'Niveau, règle, boussole, sonomètre, lampe de poche et plus encore, le tout dans une application pour le travail de plein air et les projets maison.';

  @override
  String get appShareFailed => 'Impossible d\'ouvrir la feuille de partage';

  @override
  String get levelDescLevel => 'Parfaitement niveau';

  @override
  String get levelDescNear => 'Presque niveau';

  @override
  String get levelDescTilt => 'Hors niveau';

  @override
  String get rulerTitle => 'Règle';

  @override
  String get rulerUnitCm => 'cm';

  @override
  String get rulerUnitInch => 'pouce';

  @override
  String get rulerLengthLabel => 'Longueur';

  @override
  String get rulerCm => 'cm';

  @override
  String get rulerInch => 'pouce';

  @override
  String get rulerTime => 'Heure';

  @override
  String get rulerName => 'Nom';

  @override
  String get rulerNameHint => 'Donnez un nom à cette mesure (facultatif)';

  @override
  String get rulerRecordTitle => 'Enregistrer la mesure';

  @override
  String get rulerCancel => 'Annuler';

  @override
  String get rulerSaveAction => 'Enregistrer';

  @override
  String get rulerSavedToast => 'Mesure enregistrée';

  @override
  String get rulerExport => 'Exporter';

  @override
  String get rulerExported => 'Exporté vers le presse-papiers';

  @override
  String get rulerHistory => 'Mesures';

  @override
  String get rulerNoRecords => 'Aucune mesure pour l\'instant';

  @override
  String get rulerViewAll => 'Tout voir';

  @override
  String get rulerCollapse => 'Réduire';

  @override
  String get rulerDelete => 'Supprimer';

  @override
  String get rulerDeleteConfirm => 'Supprimer cette mesure ?';

  @override
  String get rulerDefaultName => 'Mesure de règle';

  @override
  String get flashlightOn => 'Allumé';

  @override
  String get flashlightPermissionDenied =>
      'L\'accès à l\'appareil photo est requis pour utiliser la lampe de poche. Veuillez l\'activer dans les réglages.';

  @override
  String get flashlightUnavailable =>
      'Cet appareil ne prend pas en charge la lampe de poche';

  @override
  String get tideTitle => 'Marées';

  @override
  String get tideRecordCurrent => 'Enregistrer maintenant';

  @override
  String get tideExported => 'Exporté vers le presse-papiers';

  @override
  String get tideScheduleTitle => 'Horaires des marées du jour';

  @override
  String get tideCurrentHeight => 'Hauteur actuelle';

  @override
  String tideTimeToHigh(Object time) {
    return 'Pleine mer dans $time';
  }

  @override
  String get tideNextLow => 'Prochale basse';

  @override
  String get tideNextHigh => 'Prochale haute';

  @override
  String get tideHistory => 'Historique';

  @override
  String get tideViewAll => 'Tout voir';

  @override
  String get tideCollapse => 'Réduire';

  @override
  String get tideLowTide => 'Basse mer';

  @override
  String get tideHighTide => 'Pleine mer';

  @override
  String get tideRising => 'Montante';

  @override
  String get tideNoRecords => 'Aucun enregistrement de marée pour l\'instant';

  @override
  String get tideSavedToast => 'Marée actuelle enregistrée';

  @override
  String get toolWorldClock => 'Horloge mondiale';

  @override
  String get toolWorldClockDesc => 'Heures à travers le monde';

  @override
  String get worldClockTitle => 'Horloge mondiale';

  @override
  String get worldClockLocalLabel => 'Heure locale';

  @override
  String get worldClockLocLabel => 'Lieu actuel';

  @override
  String get worldClockLocating => 'Localisation…';

  @override
  String get worldClockLocFailed =>
      'Localisation indisponible, heure de l\'appareil affichée';

  @override
  String get worldClockCityBeijing => 'Pékin';

  @override
  String get worldClockCityTokyo => 'Tokyo';

  @override
  String get worldClockCitySingapore => 'Singapour';

  @override
  String get worldClockCitySydney => 'Sydney';

  @override
  String get worldClockCityDubai => 'Dubaï';

  @override
  String get worldClockCityLondon => 'Londres';

  @override
  String get worldClockCityParis => 'Paris';

  @override
  String get worldClockCityNewYork => 'New York';

  @override
  String get worldClockCityLosAngeles => 'Los Angeles';

  @override
  String get worldClockRegion => 'Pays / Région';

  @override
  String get worldClockSelectRegion => 'Sélectionnez un pays / une région';

  @override
  String get worldClockSelectCity => 'Sélectionnez une ville';

  @override
  String get worldClockCountryCn => 'Chine';

  @override
  String get worldClockCountryJp => 'Japon';

  @override
  String get worldClockCountrySg => 'Singapour';

  @override
  String get worldClockCountryAu => 'Australie';

  @override
  String get worldClockCountryAe => 'Émirats arabes unis';

  @override
  String get worldClockCountryGb => 'Royaume-Uni';

  @override
  String get worldClockCountryFr => 'France';

  @override
  String get worldClockCountryUs => 'États-Unis';

  @override
  String get ucTitle => 'Convertisseur d\'unités';

  @override
  String get ucFormula => 'Formule : ';

  @override
  String get ucCommon => 'Conversions courantes';

  @override
  String get forceTitle => 'Convertisseur de force et de charge';

  @override
  String get memoTitle => 'Mémo de voyage';

  @override
  String get memoAdd => 'Nouveau mémo';

  @override
  String get memoEmpty =>
      'Aucun mémo pour l\'instant, appuyez sur + pour en créer';

  @override
  String get memoTitleHint => 'Titre';

  @override
  String get memoFieldTitle => 'Titre';

  @override
  String get memoTravelTime => 'Heure de départ';

  @override
  String get memoTravelTimeHint => 'Sélectionnez l\'heure';

  @override
  String get memoKeyHint => 'Clé';

  @override
  String get memoValueHint => 'Valeur';

  @override
  String get memoAddRow => 'Ajouter une ligne';

  @override
  String get memoSave => 'Enregistrer';

  @override
  String get memoUntitled => 'Sans titre';

  @override
  String get memoNoContent => 'Aucun contenu';

  @override
  String get memoDelete => 'Supprimer';

  @override
  String get memoDeleteConfirm => 'Supprimer ce mémo ?';

  @override
  String get memoCancel => 'Annuler';

  @override
  String get memoEdit => 'Modifier';

  @override
  String get memoTemplateTitle => 'Modèles';

  @override
  String get memoUseTemplate => 'Utiliser';

  @override
  String get memoTemplateApplied => 'Modèle appliqué';

  @override
  String get memoTemplateHint =>
      'Choisissez un modèle pour créer rapidement un mémo';

  @override
  String get memoNewTemplate => 'Nouveau modèle';

  @override
  String get memoTemplateEmpty =>
      'Aucun modèle pour l\'instant, appuyez sur + pour en créer';

  @override
  String get memoTemplateDeleteConfirm => 'Supprimer ce modèle ?';

  @override
  String get memoDaysLeftPrefix => 'Il reste ';

  @override
  String get memoDaysLeftSuffix => ' jours';

  @override
  String get memoTodayDepart => 'Départ aujourd\'hui';

  @override
  String get memoDeparted => 'Parti';

  @override
  String get memoShare => 'Partager';

  @override
  String get memoCopy => 'Copier';

  @override
  String get memoCopied => 'Copié';

  @override
  String get memoSaveAsTemplate => 'Enregistrer comme modèle';

  @override
  String get memoTemplateCreated => 'Modèle enregistré';

  @override
  String get memoExpand => 'Déployer';

  @override
  String get memoCollapse => 'Réduire';

  @override
  String get memoDeleted => 'Supprimé';

  @override
  String get memoUndo => 'Annuler';

  @override
  String get statToolsUsed => 'Outils utilisés';

  @override
  String get statAppToolUsage => 'Utilisation totale de l\'appli';

  @override
  String get statFreeRemaining => 'Gratuit restant';

  @override
  String get vipTitle => 'Débloquer Pro';

  @override
  String get vipDesc => 'Achat unique. Sans publicité.';

  @override
  String get vipOpen => 'Mettre à niveau';

  @override
  String freeRemainingCount(num count) {
    return 'Il reste $count utilisations gratuites';
  }

  @override
  String get freeLimitTitle => 'Période d\'essai gratuite épuisée';

  @override
  String get freeLimitBody =>
      'Vous avez atteint la limite d\'utilisation gratuite (10). Passez à Pro pour débloquer tous les outils.';

  @override
  String get freeLimitUpgrade => 'Passer à Pro';

  @override
  String get vipSheetProductName => 'Débloquer Pro';

  @override
  String get vipSheetProductDesc => 'Adhésion à vie';

  @override
  String get vipSheetOneTime => 'Achat unique';

  @override
  String get vipSheetConfirm => 'Confirmer avec le bouton latéral';

  @override
  String get vipDeveloping => 'L\'activation de l\'abonnement arrive bientôt';

  @override
  String get vipPayConfirmTitle => 'Confirmer l\'achat';

  @override
  String vipPayConfirmBody(Object price) {
    return 'Payez $price pour l\'adhésion à vie. Achat unique, restaurable avec votre identifiant Apple ou votre compte Google.';
  }

  @override
  String get vipPayStoreUnavailable =>
      'Magasin d\'applications indisponible. Veuillez réessayer plus tard.';

  @override
  String get vipPayProductMissing =>
      'Le produit d\'abonnement n\'est pas encore disponible';

  @override
  String get vipPayDebugProductMissing =>
      'La version debug ne peut pas interroger les produits Play. Installez via le partage d\'applications interne ou le canal de test de Play, puis effectuez l\'achat.';

  @override
  String get vipPaySheetOpened =>
      'Feuille de paiement ouverte. L\'abonnement s\'active après le paiement.';

  @override
  String get vipRestore => 'Restaurer les achats';

  @override
  String get vipRestoreDone =>
      'Restauration terminée. Abonnement activé si acheté précédemment.';

  @override
  String get vipRestoreEmpty => 'Aucun achat trouvé pour ce compte';

  @override
  String get vipRestoreCheckAccount =>
      'Aucun achat trouvé. La restauration ne vérifie que le compte Google Play connecté sur cet appareil, assurez-vous que c\'est le même compte que lors de l\'achat.';

  @override
  String get vipRestoreAlready =>
      'Vous êtes déjà membre Pro. Aucune restauration nécessaire.';

  @override
  String get vipBecomeMember => 'Adhésion activée';

  @override
  String get syncMemberTitle => 'Synchroniser Pro avec votre compte';

  @override
  String get syncMemberBody =>
      'Connectez-vous pour conserver Pro sur tous vos appareils et le restaurer après réinstallation.';

  @override
  String get syncMemberApple => 'Continuer avec Apple';

  @override
  String get syncMemberGoogle => 'Continuer avec Google';

  @override
  String get syncMemberLater => 'Plus tard';

  @override
  String get syncMemberDone => 'Pro synchronisé avec le compte';

  @override
  String get syncMemberFailed =>
      'Échec de la synchronisation. Veuillez réessayer plus tard.';

  @override
  String get syncMemberAction => 'Synchroniser Pro avec le compte';

  @override
  String get vipPurchaseAppBarTitle => 'Débloquer Tool Box Pro';

  @override
  String get vipPurchaseSubtitle =>
      'Débloquez tous les outils en un achat unique. Sans publicité.';

  @override
  String get statOffline => 'Téléchargements hors ligne';

  @override
  String get statCert => 'Mes certificats';

  @override
  String get statRecord => 'Historique d\'apprentissage';

  @override
  String get countFiles => '5 fichiers';

  @override
  String get countCert => '3 cartes';

  @override
  String get countDays => '12 jours';

  @override
  String get countFav => '128 éléments';

  @override
  String get settings => 'Réglages';

  @override
  String get themeColorSetting => 'Thème';

  @override
  String get themeCoffee => 'Café';

  @override
  String get themeBlue => 'Ciel';

  @override
  String get langSetting => 'Langue';

  @override
  String get saveNamePromptSetting => 'Boîte de dialogue d\'enregistrement';

  @override
  String get clearCache => 'Vider le cache';

  @override
  String get calculating => 'Calcul…';

  @override
  String get notifSetting => 'Notifications';

  @override
  String get notifDeveloping => 'Notifications bientôt disponibles';

  @override
  String get accountSecurity => 'Sécurité du compte';

  @override
  String get accountDeveloping => 'Compte et sécurité bientôt disponibles';

  @override
  String get aboutGroup => 'À propos';

  @override
  String get checkUpdate => 'Vérifier les mises à jour';

  @override
  String get rateUs => 'Notez-nous';

  @override
  String get rateUsUnavailable =>
      'Impossible d\'ouvrir la page de notation maintenant. Veuillez réessayer plus tard.';

  @override
  String get aboutUs => 'À propos de nous';

  @override
  String get userAgreement => 'Conditions d\'utilisation';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String privacyLastUpdated(String date) {
    return 'Dernière mise à jour : $date';
  }

  @override
  String get privacyIntro =>
      'Cette politique de confidentialité explique comment nous collectons, utilisons, stockons et protégeons vos informations lorsque vous utilisez cette application. Veuillez la lire attentivement avant de commencer.';

  @override
  String get privacySecCollect => '1. Informations que nous collectons';

  @override
  String get privacySecCollectBody =>
      'Lors de la création d\'un compte, nous collectons votre adresse e-mail ainsi que le pseudonyme et l\'avatar que vous choisissez de fournir. Pour des fonctions comme la boussole et le sonomètre, l\'application n\'accède aux capteurs qu\'après autorisation. Nous ne collectons aucune information personnelle non liée à l\'utilisation de cette application.';

  @override
  String get privacySecUse => '2. Utilisation des informations';

  @override
  String get privacySecUseBody =>
      'Les informations collectées servent uniquement à créer et maintenir votre compte, à synchroniser votre profil et vos avantages d\'abonnement entre les appareils, à améliorer l\'expérience produit et à vous contacter si nécessaire. Nous n\'utilisons jamais vos informations à des fins étrangères à cette application.';

  @override
  String get privacySecStore => '3. Stockage et sécurité des données';

  @override
  String get privacySecStoreBody =>
      'Les données de compte sont stockées dans une base de données cloud Supabase et protégées par un transfert chiffré et un contrôle d\'accès. Les caches locaux tels que les images restent uniquement sur votre appareil et peuvent être effacés à tout moment dans Réglages > Vider le cache.';

  @override
  String get privacySecShare => '4. Partage des informations';

  @override
  String get privacySecShareBody =>
      'Nous ne vendons ni ne louons vos informations personnelles. Nous ne partageons que les données minimales requises dans ces cas : avec les plateformes de paiement (Apple App Store / Google Play) pour finaliser les achats d\'abonnement, et lorsque la loi l\'exige ou pour protéger nos droits légaux.';

  @override
  String get privacySecAds => '5. Publicité';

  @override
  String get privacySecAdsBody =>
      'La version gratuite affiche des bannières publicitaires à quelques endroits dans l\'application, servies par Google AdMob. AdMob peut utiliser les identifiants d\'appareil et les données d\'interaction publicitaire pour sélectionner et mesurer les annonces, comme décrit dans la politique de confidentialité de Google. Aucune annonce n\'est chargée une fois Pro débloqué. Cette application ne demande pas l\'autorisation App Tracking Transparency et n\'envoie pas vos données d\'outils aux réseaux publicitaires.';

  @override
  String get privacySecRights => '6. Vos droits';

  @override
  String get privacySecRightsBody =>
      'Vous pouvez à tout moment modifier votre pseudonyme et votre avatar dans « Modifier le profil », supprimer les données locales dans Réglages > Vider le cache, et supprimer votre profil cloud en supprimant votre compte. Pour exporter ou demander la suppression de vos données, contactez-nous aux coordonnées ci-dessous.';

  @override
  String get privacySecUpdate => '7. Mises à jour de cette politique';

  @override
  String get privacySecUpdateBody =>
      'Nous pouvons mettre à jour cette politique de temps à autre. La dernière version est toujours publiée sur cette page, et nous vous en informerons dans l\'application pour les changements importants. Nous vous recommandons de consulter cette page périodiquement.';

  @override
  String get privacySecContact => '8. Nous contacter';

  @override
  String get privacySecContactBody =>
      'Si vous avez des questions ou des suggestions concernant cette politique de confidentialité, veuillez nous contacter à support@aknot.uk. Nous répondrons dans un délai raisonnable.';

  @override
  String get agreementIntro =>
      'Ce contrat d\'utilisation définit les conditions applicables lorsque vous utilisez cette application, ainsi que les droits et obligations entre vous et nous. Veuillez le lire attentivement avant de commencer. En utilisant cette application, vous acceptez d\'être lié par ce contrat.';

  @override
  String get agreementSecAccept => '1. Acceptation du contrat';

  @override
  String get agreementSecAcceptBody =>
      'Ce contrat est un contrat contraignant entre vous et nous. Si vous n\'acceptez aucune partie, veuillez cesser d\'utiliser l\'application. Si vous êtes mineur, veuillez le lire avec votre parent ou tuteur.';

  @override
  String get agreementSecService => '2. Le service';

  @override
  String get agreementSecServiceBody =>
      'Cette application fournit un ensemble d\'outils pratiques sur l\'appareil : mémo, boussole, sonomètre, niveau, règle, lampe de poche et marées. Les fonctions peuvent évoluer avec le produit, et nous ferons de notre mieux pour préserver une expérience stable.';

  @override
  String get agreementSecAccount => '3. Votre compte';

  @override
  String get agreementSecAccountBody =>
      'Certaines fonctions nécessitent un compte. Vous pouvez vous connecter avec Apple ou Google, ou continuer en tant qu\'invité. Vous êtes responsable de la sécurité de vos identifiants et des activités sous votre compte. Vos données de compte sont stockées dans une base de données cloud Supabase, comme décrit dans notre politique de confidentialité.';

  @override
  String get agreementSecFree => '4. Utilisation gratuite et publicité';

  @override
  String get agreementSecFreeBody =>
      'La version gratuite comprend un nombre limité d\'utilisations des outils et affiche des bannières publicitaires servies par Google AdMob. Vous pouvez regarder une publicité intégrée à l\'application pour obtenir des utilisations gratuites supplémentaires, jusqu\'à la limite gratuite. Les compteurs d\'utilisation sont enregistrés sur nos serveurs et liés à un identifiant d\'appareil, donc la réinstallation de l\'application ne les réinitialise pas.';

  @override
  String get agreementSecPurchase => '5. Achats et remboursements';

  @override
  String get agreementSecPurchaseBody =>
      'Le déblocage Pro est un achat unique qui supprime la publicité et lève la limite d\'utilisation gratuite. Tous les paiements sont traités par l\'Apple App Store ou Google Play, et les remboursements relèvent des règles de ces plateformes, nous ne pouvons donc pas traiter les remboursements directement. Les achats sont liés à votre compte ; la connexion sur un autre appareil restaure vos avantages.';

  @override
  String get agreementSecConduct => '6. Utilisation acceptable';

  @override
  String get agreementSecConductBody =>
      'Vous acceptez de ne pas utiliser cette application à des fins illégales, de ne pas perturber son fonctionnement normal, et de ne pas l\'ingénierie inverse, la décompiler ou tenter d\'extraire son code source. Vous acceptez également de ne pas accéder au service en masse par des moyens automatisés.';

  @override
  String get agreementSecIp => '7. Propriété intellectuelle';

  @override
  String get agreementSecIpBody =>
      'L\'application, y compris son code, son design, ses icônes, ses textes et autres éléments, nous appartient et est protégée par la loi. Vous ne pouvez utiliser l\'application qu\'à des fins personnelles, et ne pouvez copier, modifier, distribuer ou utiliser commercialement aucune partie sans notre autorisation écrite.';

  @override
  String get agreementSecDisclaimer => '8. Avertissement';

  @override
  String get agreementSecDisclaimerBody =>
      'Les lectures d\'outils telles que la boussole, le sonomètre et le niveau proviennent des capteurs de votre appareil et sont indicatives uniquement. Elles ne remplacent pas d\'instruments professionnels et ne doivent pas être utilisées lorsque la précision est critique pour la sécurité, par exemple dans la construction, le médical ou le juridique. Nous déclinons toute responsabilité pour les pertes découlant de la confiance accordée à ces lectures.';

  @override
  String get agreementSecUpdate => '9. Modifications de ce contrat';

  @override
  String get agreementSecUpdateBody =>
      'Nous pouvons mettre à jour ce contrat de temps à autre. La dernière version est toujours affichée sur cette page, et nous vous en informerons dans l\'application pour les changements importants. Continuer à utiliser l\'application après une mise à jour signifie que vous acceptez le contrat révisé.';

  @override
  String get agreementSecContact => '10. Nous contacter';

  @override
  String get agreementSecContactBody =>
      'Si vous avez des questions ou des suggestions concernant ce contrat d\'utilisation, veuillez nous contacter à support@aknot.uk. Nous répondrons dans un délai raisonnable.';

  @override
  String get cacheCleared => 'Cache vidé';

  @override
  String get langChinese => 'Chinois';

  @override
  String get langEnglish => 'Anglais';

  @override
  String get langJapanese => 'Japonais';

  @override
  String get langGerman => 'Allemand';

  @override
  String get langFrench => 'Français';

  @override
  String get toggleLightDark => 'Basculer clair / sombre';

  @override
  String get sectionGeneral => 'Outils généraux';

  @override
  String get toolForce => 'Convertisseur de force et de charge';

  @override
  String get toolForceDesc => 'Conversion précise des forces';

  @override
  String get toolUnitConverter => 'Convertisseur d\'unités';

  @override
  String get toolUnitConverterDesc => 'Longueur / Poids / Force';

  @override
  String get toolTravelMemo => 'Mémo de voyage';

  @override
  String get toolTravelMemoDesc => 'Préparé pour chaque grand voyage';

  @override
  String get toolCompass => 'Boussole';

  @override
  String get toolCompassDesc => 'Connaissez votre direction à tout moment';

  @override
  String get toolNoise => 'Sonomètre';

  @override
  String get toolNoiseDesc => 'Niveau sonore ambiant en décibels';

  @override
  String get toolLevel => 'Niveau';

  @override
  String get toolLevelDesc => 'Nivellement précis';

  @override
  String get toolRuler => 'Règle';

  @override
  String get toolRulerDesc => 'Mesurez directement à l\'écran';

  @override
  String get toolFlashlight => 'Lampe de poche';

  @override
  String get toolFlashlightDesc => 'Éclairez votre chemin';

  @override
  String get toolTide => 'Marées';

  @override
  String get toolTideDesc => 'Consultez les marées à tout moment';

  @override
  String get ucCatArea => 'Surface';

  @override
  String get ucCatVolume => 'Volume';

  @override
  String get ucCatTemp => 'Température';

  @override
  String get ucCatSpeed => 'Vitesse';

  @override
  String get ucCatWeight => 'Poids';

  @override
  String get ucCatLength => 'Longueur';

  @override
  String get unitSquareMeter => 'Mètre carré (m²)';

  @override
  String get unitSquareKilometer => 'Kilomètre carré (km²)';

  @override
  String get unitHectare => 'Hectare (ha)';

  @override
  String get unitMu => 'Mu';

  @override
  String get unitSquareFoot => 'Pied carré (ft²)';

  @override
  String get unitSquareMile => 'Mille carré (mi²)';

  @override
  String get unitSquareYard => 'Yard carré (yd²)';

  @override
  String get unitAcre => 'Acre (ac)';

  @override
  String get unitSquareInch => 'Pouce carré (in²)';

  @override
  String get unitMeterPerSec => 'Mètre/seconde (m/s)';

  @override
  String get unitKmPerHour => 'Kilomètre/heure (km/h)';

  @override
  String get unitMilePerHour => 'Mille/heure (mph)';

  @override
  String get unitFootPerSec => 'Pied/seconde (ft/s)';

  @override
  String get unitKnot => 'Nœud (kn)';

  @override
  String get unitKilogram => 'Kilogramme (kg)';

  @override
  String get unitGram => 'Gramme (g)';

  @override
  String get unitMilligram => 'Milligramme (mg)';

  @override
  String get unitTon => 'Tonne (t)';

  @override
  String get unitPound => 'Livre (lb)';

  @override
  String get unitOunce => 'Once (oz)';

  @override
  String get unitJin => 'Jin';

  @override
  String get unitLiang => 'Liang';

  @override
  String get unitLiter => 'Litre (L)';

  @override
  String get unitMilliliter => 'Millilitre (mL)';

  @override
  String get unitCubicMeter => 'Mètre cube (m³)';

  @override
  String get unitCubicCentimeter => 'Centimètre cube (cm³)';

  @override
  String get unitGallon => 'Gallon (US) (gal)';

  @override
  String get unitQuart => 'Quart (US) (qt)';

  @override
  String get unitPint => 'Pinte (US) (pt)';

  @override
  String get unitCup => 'Tasse (US) (cup)';

  @override
  String get unitCubicFoot => 'Pied cube (ft³)';

  @override
  String get unitCubicInch => 'Pouce cube (in³)';

  @override
  String get unitMeter => 'Mètre (m)';

  @override
  String get unitKilometer => 'Kilomètre (km)';

  @override
  String get unitCentimeter => 'Centimètre (cm)';

  @override
  String get unitMillimeter => 'Millimètre (mm)';

  @override
  String get unitMile => 'Mille (mi)';

  @override
  String get unitFoot => 'Pied (ft)';

  @override
  String get unitInch => 'Pouce (in)';

  @override
  String get unitYard => 'Yard (yd)';

  @override
  String get unitNauticalMile => 'Mille nautique (nmi)';

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
  String get unitKilogramForce => 'Kilogramme-force (kgf)';

  @override
  String get unitPoundForce => 'Livre-force (lbf)';

  @override
  String get unitTonForce => 'Tonne-force (tf)';

  @override
  String get tideHigh => 'Pleine mer';

  @override
  String get tideEbbing => 'Descendante';

  @override
  String tideDateFormat(Object month, Object day, Object hour, Object min) {
    return '$month/$day $hour:$min';
  }

  @override
  String get darkModeLabel => 'Mode sombre';

  @override
  String devToast(Object title) {
    return '$title (En développement)';
  }

  @override
  String get profileNotLogin => 'Non connecté';

  @override
  String get profileTapLogin => 'Appuyez pour vous connecter / inscrire';

  @override
  String get profileGuest => 'Utilisateur';

  @override
  String get profileNoEmail => 'Aucun e-mail lié';

  @override
  String get profileMemberVip => 'VIP';

  @override
  String get profileMemberFree => 'Gratuit';

  @override
  String get profileLoadFailed => 'Échec du chargement du profil';

  @override
  String get profileRetry => 'Réessayer';

  @override
  String get profileSignOut => 'Se déconnecter';

  @override
  String get profileSignOutConfirm => 'Se déconnecter du compte actuel ?';

  @override
  String get deleteAccount => 'Supprimer le compte';

  @override
  String get deleteAccountConfirm =>
      'Supprimer votre compte ? Cette action est irréversible.';

  @override
  String get deleteAccountWarning =>
      'Toutes vos données locales et cloud seront supprimées définitivement et ne pourront pas être récupérées.';

  @override
  String get deleteAccountDone => 'Compte supprimé';

  @override
  String get deleteAccountFailed =>
      'Échec de la suppression du compte. Veuillez réessayer plus tard.';

  @override
  String get profileEditTitle => 'Modifier le profil';

  @override
  String get profileEditName => 'Pseudonyme';

  @override
  String get profileEditNameHint => 'Saisissez un pseudonyme';

  @override
  String get profileEditNameEmpty => 'Le pseudonyme ne peut pas être vide';

  @override
  String get profileEditAvatarTitle => 'Choisir un avatar';

  @override
  String get profileEditCurrent => 'Avatar actuel';

  @override
  String get profileEditShuffle => 'Mélanger';

  @override
  String get profileEditSave => 'Enregistrer';

  @override
  String get profileEditSaved => 'Profil mis à jour';

  @override
  String get profileEditFailed => 'Échec de l\'enregistrement';

  @override
  String get profileEditNeedLogin =>
      'Connectez-vous d\'abord pour modifier votre profil';

  @override
  String get dialogCancel => 'Annuler';

  @override
  String get dialogConfirm => 'Confirmer';

  @override
  String get vipActiveTitle => 'Pro débloqué · Actif';

  @override
  String get vipLifetime => 'Adhésion à vie, sans expiration';

  @override
  String vipExpireAt(Object date) {
    return 'Valable jusqu\'au $date';
  }

  @override
  String splashSkip(Object seconds) {
    return 'Passer ${seconds}s';
  }

  @override
  String get thirdPartySdk => 'SDK tiers';

  @override
  String adWatchForFreeUses(num count) {
    return 'Regardez une publicité pour obtenir $count utilisations gratuites';
  }

  @override
  String adRewardProgress(num remaining, num max) {
    return 'Utilisations gratuites restantes : $remaining/$max';
  }

  @override
  String get adUnavailable =>
      'Publicité indisponible, veuillez réessayer plus tard';

  @override
  String adRewardSuccess(num count) {
    return 'Vous avez gagné $count utilisations gratuites';
  }

  @override
  String get adNotFinished =>
      'Publicité non terminée, aucune récompense cette fois';

  @override
  String get adLabel => 'Publicité';

  @override
  String get adPrivacySettings => 'Paramètres de confidentialité publicitaire';

  @override
  String get webUnsupported =>
      'Le navigateur intégré n\'est pas disponible sur cette plateforme';

  @override
  String get webLoadFailed => 'Échec du chargement de la page';
}
