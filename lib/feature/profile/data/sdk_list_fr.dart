// ============================================================================
// 文件：feature/profile/data/sdk_list_fr.dart
// 模块：我的 / 个人中心（profile）/ 第三方 SDK 清单 · 法文整篇
//
// 职责：
//   提供法文版「第三方 SDK 清单」的完整内容（分组、条目、说明章节）。
//   与 sdk_list_en.dart / sdk_list_zh.dart / sdk_list_ja.dart / sdk_list_de.dart
//   一一对应：字段名与条目顺序必须保持一致，否则切换语言时数据错位。
//
// 维护约定：
//   1. 版本号取自 pubspec.lock 的实际解析结果；
//   2. 新增 / 移除依赖时，各语种文件都要同步改；
//   3. 正文改动后请同步更新 updatedAt。
// ============================================================================

import '../model/sdk_list.dart';

/// 法文版清单内容。
const SdkListContent sdkListFr = SdkListContent(
  updatedAt: '2026-09-25',
  intro:
      'Cette page répertorie toutes les bibliothèques tierces intégrées à '
      'l''application au moment de l''exécution, ainsi que les autorisations '
      'qu''elles sollicitent et les données qu''elles traitent. Elle est '
      'destinée à l''examen des stores et à la déclaration de confidentialité. '
      'Les outils utilisés uniquement au build sont exclus car ils ne sont '
      'jamais distribués avec l''application. Touchez un lien de politique pour '
      'le copier.',
  filterAll: 'Tous',
  filterSensitive: 'Sensibles uniquement',
  labelVendor: 'Fournisseur',
  labelPurpose: 'Usage',
  labelPermissions: 'Autorisations',
  labelData: 'Données collectées',
  labelPolicy: 'Politique de confidentialité',
  tapCopyHint: 'Touchez pour copier',
  copiedToast: 'Lien copié',
  groups: <SdkGroup>[
    // —— 框架与基础工具 ——
    SdkGroup(
      title: 'Framework et utilitaires',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'Flutter SDK (flutter, flutter_localizations)',
          version: '3.44 / Dart 3.12+',
          vendor: 'Google LLC',
          purpose:
              'Framework d''interface multiplateforme et délégués de '
              'localisation Material / Cupertino intégrés.',
          permissions: 'Aucune',
          data: 'Non collectées',
          privacyUrl: 'https://policies.google.com/privacy',
        ),
        SdkEntry(
          name: 'intl',
          version: '0.20.3',
          vendor: 'Dart team',
          purpose: 'Formatage des dates, nombres et messages pour la localisation.',
          permissions: 'Aucune',
          data: 'Non collectées',
          privacyUrl: 'https://pub.dev/packages/intl',
        ),
        SdkEntry(
          name: 'yaml',
          version: '3.1.4',
          vendor: 'Dart team',
          purpose: 'Analyse la configuration d''environnement locale incluse dans les ressources.',
          permissions: 'Aucune',
          data: 'Non collectées',
          privacyUrl: 'https://pub.dev/packages/yaml',
        ),
        SdkEntry(
          name: 'package_info_plus',
          version: '10.2.1',
          vendor: 'Flutter team (Google)',
          purpose: 'Lit la version de l''application affichée dans la section À propos.',
          permissions: 'Aucune',
          data: 'Non collectées',
          privacyUrl: 'https://pub.dev/packages/package_info_plus',
        ),
        SdkEntry(
          name: 'flutter_screenutil_plus',
          version: '1.6.0',
          vendor: 'Community',
          purpose: 'Adapte l''interface à la référence de conception 393x852.',
          permissions: 'Aucune',
          data: 'Non collectées',
          privacyUrl: 'https://pub.dev/packages/flutter_screenutil_plus',
        ),
        SdkEntry(
          name: 'shared_preferences',
          version: '2.5.5',
          vendor: 'Dart team (Google)',
          purpose: 'Persiste de légères préférences de type commutateur (thème, '
              'langue, récompenses d''utilisation gratuite et autres valeurs '
              'bool / int isolées) sans ouvrir de base de données.',
          permissions: 'Aucune',
          data: 'Stockées uniquement sur l''appareil, jamais envoyées',
          privacyUrl: 'https://pub.dev/packages/shared_preferences',
        ),
        SdkEntry(
          name: 'share_plus',
          version: '13.3.0',
          vendor: 'Flutter team (Google)',
          purpose: 'Affiche la feuille de partage système couvrant des cibles '
              'comme WeChat, le courrier et Messages installés sur '
              'l''appareil, utilisée pour partager le contenu mémo et d''autres éléments.',
          permissions: 'Aucune (gérée par la feuille de partage système)',
          data: 'Non collectées ; le contenu partagé ne sort que par la feuille système',
          privacyUrl: 'https://pub.dev/packages/share_plus',
        ),
      ],
    ),
    // —— 架构与网络 ——
    SdkGroup(
      title: 'Architecture et réseau',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'flutter_riverpod',
          version: '3.3.2',
          vendor: 'Remi Rousselet (community)',
          purpose: 'Gestion réactive de l''état partagée dans toute l''application.',
          permissions: 'Aucune',
          data: 'Non collectées',
          privacyUrl: 'https://pub.dev/packages/flutter_riverpod',
        ),
        SdkEntry(
          name: 'go_router',
          version: '17.3.0',
          vendor: 'Flutter team (Google)',
          purpose: 'Navigation déclarative, y compris l''écran de démarrage et le shell à onglets.',
          permissions: 'Aucune',
          data: 'Non collectées',
          privacyUrl: 'https://pub.dev/packages/go_router',
        ),
        SdkEntry(
          name: 'dio',
          version: '5.10.0',
          vendor: 'Community',
          purpose: 'Client HTTP utilisé pour les requêtes sortantes.',
          permissions: 'Aucune (INTERNET sur Android ne nécessite aucune invite)',
          data: 'Non collectées par la bibliothèque elle-même',
          privacyUrl: 'https://pub.dev/packages/dio',
        ),
      ],
    ),
    // —— 数据与存储 ——
    SdkGroup(
      title: 'Données et stockage',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'hive / hive_flutter',
          version: '2.2.3 / 1.1.0',
          vendor: 'Community',
          purpose:
              'Stockage local clé-valeur pour des réglages légers tels que la '
              'langue et le thème.',
          permissions: 'Aucune',
          data: 'Stockées uniquement sur l''appareil, jamais envoyées',
          privacyUrl: 'https://pub.dev/packages/hive',
        ),
        SdkEntry(
          name: 'isar_community (+ flutter libs)',
          version: '3.3.2',
          vendor: 'Community fork of Isar',
          purpose: 'Base de données locale embarquée pour les enregistrements d''outils.',
          permissions: 'Aucune',
          data: 'Stockées uniquement sur l''appareil, jamais envoyées',
          privacyUrl: 'https://pub.dev/packages/isar_community',
        ),
        SdkEntry(
          name: 'path_provider',
          version: '2.1.6',
          vendor: 'Flutter team (Google)',
          purpose: 'Résout les répertoires de l''application utilisés par le cache et la base de données.',
          permissions: 'Aucune',
          data: 'Non collectées',
          privacyUrl: 'https://pub.dev/packages/path_provider',
        ),
        SdkEntry(
          name: 'supabase_flutter',
          version: '2.17.2',
          vendor: 'Supabase Inc.',
          purpose:
              'Authentification par e-mail, synchronisation du profil cloud et '
              'passerelle de Edge Function utilisée pour les événements '
              'd''utilisation anonymes.',
          permissions: 'Aucune (accès réseau uniquement)',
          data:
              'Adresse e-mail, pseudonyme, URL d''avatar, état d''abonnement et '
              'événements d''utilisation anonymes',
          privacyUrl: 'https://supabase.com/privacy',
          sensitive: true,
        ),
        SdkEntry(
          name: 'sign_in_with_apple',
          version: '8.2.0',
          vendor: 'Community maintained (bridge recommended by Flutter)',
          purpose:
              'Affiche la feuille système native « Se connecter avec Apple » '
              'sur iOS et macOS. Non utilisé sur Android (Apple ne fournit pas '
              'de SDK Android).',
          permissions: 'Aucune',
          data:
              'Le plugin ne collecte rien ; les utilisateurs peuvent choisir de '
              'masquer leur adresse e-mail, auquel cas Apple fournit une adresse '
              'relais privée à la place de la réelle',
          privacyUrl: 'https://www.apple.com/legal/privacy/data/',
        ),
        SdkEntry(
          name: 'crypto',
          version: '3.0.7',
          vendor: 'Dart team',
          purpose:
              'Calcule le SHA-256, utilisé pour hacher le nonce anti-rejeu '
              'requis par la connexion native avec Apple.',
          permissions: 'Aucune',
          data: 'Non collectées',
          privacyUrl: 'https://pub.dev/packages/crypto',
        ),
        SdkEntry(
          name: 'google_sign_in',
          version: '6.3.0',
          vendor: 'Flutter team (Google)',
          purpose: 'Affiche la feuille de connexion Google système sur Android et '
              'iOS non-Apple, transmettant l''identité Google à Supabase pour '
              'créer une session en une seule touche.',
          permissions: 'Aucune (gérée par la feuille Google système)',
          data: 'Identité du compte Google (idToken / accessToken) ainsi que le '
              'profil public tel que l''avatar et le pseudonyme, utilisés par '
              'Supabase pour la connexion et la session',
          privacyUrl: 'https://policies.google.com/privacy',
          sensitive: true,
        ),
        SdkEntry(
          name: 'device_info_plus',
          version: '13.2.0',
          vendor: 'Flutter team (Google)',
          purpose: 'Lit l''identifiant anonyme de l''appareil (IDFV iOS / '
              'ANDROID_ID Android) afin que le quota d''utilisation gratuite '
              'puisse reconnaître le même appareil après une réinstallation.',
          permissions: 'Aucune (la lecture de l''id appareil ne nécessite aucune autorisation)',
          data: 'L''identifiant est haché en SHA-256 et signalé comme un id '
              'appareil anonyme non réversible vers l''original ; utilisé '
              'uniquement pour reconnaître les appareils anonymes, aucune autre '
              'donnée n''est envoyée',
          privacyUrl: 'https://pub.dev/packages/device_info_plus',
          sensitive: true,
        ),
      ],
    ),
    // —— 设备能力 ——
    SdkGroup(
      title: 'Capacités de l''appareil',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'flutter_compass',
          version: '0.8.1',
          vendor: 'Community',
          purpose: 'Cap de la boussole pour l''outil de boussole.',
          permissions: 'Aucune (le magnétomètre ne nécessite aucune autorisation)',
          data: 'Uniquement sur l''appareil',
          privacyUrl: 'https://pub.dev/packages/flutter_compass',
        ),
        SdkEntry(
          name: 'geolocator',
          version: '14.0.3',
          vendor: 'Baseflow (Flutter community)',
          purpose: 'Altitude et coordonnées affichées avec la boussole.',
          permissions:
              'Localisation : iOS When-In-Use, Android ACCESS_FINE_LOCATION / '
              'ACCESS_COARSE_LOCATION',
          data: 'Uniquement sur l''appareil, jamais envoyées',
          privacyUrl: 'https://pub.dev/packages/geolocator',
          sensitive: true,
        ),
        SdkEntry(
          name: 'noise_meter',
          version: '5.1.0',
          vendor: 'Community',
          purpose: 'Échantillonnage du microphone pour l''outil sonomètre.',
          permissions:
              'Microphone : iOS NSMicrophoneUsageDescription, Android '
              'RECORD_AUDIO',
          data: 'Uniquement sur l''appareil ; aucun audio n''est enregistré, sauvegardé ou envoyé',
          privacyUrl: 'https://pub.dev/packages/noise_meter',
          sensitive: true,
        ),
        SdkEntry(
          name: 'sensors_plus',
          version: '7.1.0',
          vendor: 'Flutter team (Google)',
          purpose: 'Données de l''accéléromètre pour l''outil de niveau à bulle.',
          permissions: 'Aucune',
          data: 'Uniquement sur l''appareil',
          privacyUrl: 'https://pub.dev/packages/sensors_plus',
        ),
        SdkEntry(
          name: 'camera',
          version: '0.12.0+2',
          vendor: 'Flutter team (Google)',
          purpose: 'Accès caméra utilisé uniquement pour piloter la lampe torche.',
          permissions: 'Caméra : iOS NSCameraUsageDescription, Android CAMERA',
          data: 'Aucune image ou vidéo n''est capturée, sauvegardée ou envoyée',
          privacyUrl: 'https://pub.dev/packages/camera',
          sensitive: true,
        ),
        SdkEntry(
          name: 'permission_handler',
          version: '12.0.3',
          vendor: 'Baseflow (Flutter community)',
          purpose: 'Affiche les fenêtres de dialogue d''autorisation système listées ci-dessus.',
          permissions: 'Aucune (il ne fait que demander des autorisations pour le compte de l''application)',
          data: 'Non collectées',
          privacyUrl: 'https://pub.dev/packages/permission_handler',
        ),
      ],
    ),
    // —— 支付与评分 ——
    SdkGroup(
      title: 'Paiements et évaluations',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'in_app_purchase',
          version: '3.3.0',
          vendor: 'Flutter team (Google)',
          purpose: 'Achat d''abonnement unique (non consommable).',
          permissions: 'Aucune (gérée par le store)',
          data:
              'La transaction est traitée par Apple ou Google ; l''application '
              'ne reçoit que l''état des droits',
          privacyUrl: 'https://www.apple.com/legal/privacy/',
          sensitive: true,
        ),
        SdkEntry(
          name: 'in_app_purchase_storekit',
          version: '0.4.13',
          vendor: 'Flutter team (Google)',
          purpose:
              'API StoreKit 2 d''iOS, utilisées pour rafraîchir les droits '
              'quand l''utilisateur touche Restaurer les achats.',
          permissions: 'Aucune (gérée par le store)',
          data: 'État des droits uniquement',
          privacyUrl: 'https://www.apple.com/legal/privacy/',
          sensitive: true,
        ),
        SdkEntry(
          name: 'in_app_review',
          version: '2.0.12',
          vendor: 'Flutter team (Google)',
          purpose:
              'Affiche l''invite de notation système intégrée, avec repli vers '
              'la page du store si indisponible.',
          permissions: 'Aucune',
          data: 'Non collectées',
          privacyUrl: 'https://pub.dev/packages/in_app_review',
        ),
      ],
    ),
    // —— 广告变现 ——
    SdkGroup(
      title: 'Publicité',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'google_mobile_ads',
          version: '9.1.0',
          vendor: 'Google LLC',
          purpose:
              'Demande et affiche des bannières adaptatives dans l''application. '
              'Aucune publicité n''est demandée une fois Pro Unlock possédé.',
          permissions: 'Aucune déclarée par l''application (le SDK utilise le réseau)',
          data:
              'Données de l''appareil et d''interaction publicitaire gérées par '
              'Google AdMob comme décrit dans la politique de confidentialité Google',
          privacyUrl: 'https://policies.google.com/privacy',
          sensitive: true,
        ),
      ],
    ),
    // —— In-app web view ——
    SdkGroup(
      title: 'Vue web intégrée',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'webview_flutter',
          version: '4.14.1',
          vendor: 'Flutter team (Google)',
          purpose: 'Affiche les documents en ligne (conditions d''utilisation, '
              'politique de confidentialité, liens de la liste SDK) dans '
              'l''application plutôt qu''en sautant vers un navigateur externe.',
          permissions: 'Réseau (macOS nécessite l''entitlement sandbox '
              'com.apple.security.network.client)',
          data: 'Ne charge que les URL de documents publics spécifiées par '
              'l''application ; aucun script n''est injecté et le contenu rendu '
              'n''est pas collecté',
          privacyUrl: 'https://pub.dev/packages/webview_flutter',
        ),
      ],
    ),
  ],
  // —— 系统平台框架（非第三方 SDK，仅补充说明）——
  platformTitle: 'Frameworks de plateforme',
  platformNote:
      'Ce qui suit est fourni avec le système d''exploitation et ne constitue '
      'pas des SDK tiers. Ils sont listés car les examens et déclarations de '
      'confidentialité les demandent souvent. Ils sont régis par les conditions '
      'de la plateforme Apple ou Google.',
  platforms: <SdkEntry>[
    SdkEntry(
      name: 'StoreKit 2 / Google Play Billing',
      version: 'System',
      vendor: 'Apple Inc. / Google LLC',
      purpose: 'Traite l''achat d''abonnement unique.',
      permissions: 'Aucune',
      data: 'Données de paiement gérées par Apple ou Google',
      sensitive: true,
    ),
    SdkEntry(
      name: 'Core Location / Location Services',
      version: 'System',
      vendor: 'Apple Inc. / Google LLC',
      purpose: 'Fournit l''altitude et les coordonnées.',
      permissions: 'Localisation',
      data: 'Uniquement sur l''appareil',
      sensitive: true,
    ),
    SdkEntry(
      name: 'AVFoundation / Camera2',
      version: 'System',
      vendor: 'Apple Inc. / Google LLC',
      purpose: 'Fournit le contrôle de la torche pour la lampe.',
      permissions: 'Caméra',
      data: 'Aucun média n''est capturé',
      sensitive: true,
    ),
    SdkEntry(
      name: 'CoreMotion / Sensor Framework',
      version: 'System',
      vendor: 'Apple Inc. / Google LLC',
      purpose: 'Fournit les échantillons accéléromètre, gyroscope et magnétomètre.',
      permissions: 'Aucune',
      data: 'Uniquement sur l''appareil',
      sensitive: true,
    ),
  ],
  // —— 说明 ——
  noteTitle: 'Notes',
  noteBody:
      'Périmètre : seules les bibliothèques livrées dans le binaire publié sont '
      'listées. Les outils de build tels que flutter_native_splash sont des '
      'dépendances de dev et ne sont jamais distribués avec l''application.\n\n'
      'La colonne données décrit comment cette application utilise chaque '
      'bibliothèque, et non ce que le fournisseur fait sur ses propres services.\n\n'
      'Publicité : la version gratuite affiche des bannières Google AdMob à '
      'quelques endroits dans l''application. Aucune publicité n''est demandée '
      'une fois Pro Unlock possédé. Cette application ne demande pas '
      'l''autorisation App Tracking Transparency et n''envoie aucune donnée '
      'd''outil aux réseaux publicitaires.\n\n'
      'Toucher un lien le copie dans le presse-papiers. Aucune dépendance de '
      'navigateur intégré n''est volontairement incluse, l''application ne '
      'demande donc aucune autorisation supplémentaire pour afficher cette page.',
);
