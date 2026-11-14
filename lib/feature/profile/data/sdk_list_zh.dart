// ============================================================================
// 文件：feature/profile/data/sdk_list_zh.dart
// 模块：我的 / 个人中心（profile）/ 第三方 SDK 清单 · 中文整篇
//
// 职责：
//   提供中文版「第三方 SDK 清单」的完整内容。与 sdk_list_en.dart 严格一一对应：
//   分组数量、条目顺序、sensitive 标记必须一致，否则切换语言时对应关系会错位。
//
// 维护约定：
//   1. 版本号取自 pubspec.lock 的实际解析结果（不是 pubspec.yaml 的约束区间）；
//   2. 新增 / 移除依赖时，两份文件都要同步改；
//   3. 正文改动后请同步更新 updatedAt。
// ============================================================================

import '../model/sdk_list.dart';

/// 中文版清单内容。
const SdkListContent sdkListZh = SdkListContent(
  updatedAt: '2026-09-25',
  intro:
      '本页面列出 App 运行期实际打包进安装包的全部第三方库，并说明各自涉及的'
      '系统权限与数据处理情况，供应用商店审核与隐私披露使用。仅构建期使用的'
      '开发工具不会随应用分发，故不列入。点击政策链接可复制到剪贴板。',
  filterAll: '全部',
  filterSensitive: '仅看敏感项',
  labelVendor: '提供方',
  labelPurpose: '用途',
  labelPermissions: '涉及权限',
  labelData: '数据收集',
  labelPolicy: '隐私政策',
  tapCopyHint: '点击复制',
  copiedToast: '链接已复制',
  groups: <SdkGroup>[
    // —— 框架与基础工具 ——
    SdkGroup(
      title: '框架与基础工具',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'Flutter SDK（flutter、flutter_localizations）',
          version: '3.44 / Dart 3.12+',
          vendor: 'Google LLC',
          purpose: '跨平台 UI 框架，以及 Material / Cupertino 内置组件的本地化委托。',
          permissions: '无',
          data: '不收集',
          privacyUrl: 'https://policies.google.com/privacy',
        ),
        SdkEntry(
          name: 'intl',
          version: '0.20.3',
          vendor: 'Dart 官方团队',
          purpose: '日期、数字与本地化消息的格式化。',
          permissions: '无',
          data: '不收集',
          privacyUrl: 'https://pub.dev/packages/intl',
        ),
        SdkEntry(
          name: 'yaml',
          version: '3.1.4',
          vendor: 'Dart 官方团队',
          purpose: '解析打包在 assets 目录下的本地环境配置。',
          permissions: '无',
          data: '不收集',
          privacyUrl: 'https://pub.dev/packages/yaml',
        ),
        SdkEntry(
          name: 'package_info_plus',
          version: '10.2.1',
          vendor: 'Flutter 官方团队（Google）',
          purpose: '读取应用版本号，用于「关于」分组展示。',
          permissions: '无',
          data: '不收集',
          privacyUrl: 'https://pub.dev/packages/package_info_plus',
        ),
        SdkEntry(
          name: 'flutter_screenutil_plus',
          version: '1.6.0',
          vendor: '社区维护',
          purpose: '按 393×852 设计稿基准做屏幕适配缩放。',
          permissions: '无',
          data: '不收集',
          privacyUrl: 'https://pub.dev/packages/flutter_screenutil_plus',
        ),
        SdkEntry(
          name: 'shared_preferences',
          version: '2.5.5',
          vendor: 'Dart 官方团队（Google）',
          purpose:
              '持久化轻量开关类偏好（如主题、语言、免费次数奖励等单一 bool / int 值），读写无需开启数据库。',
          permissions: '无',
          data: '仅存储在本机，不上传',
          privacyUrl: 'https://pub.dev/packages/shared_preferences',
        ),
        SdkEntry(
          name: 'share_plus',
          version: '13.3.0',
          vendor: 'Flutter 官方团队（Google）',
          purpose:
              '调起系统分享面板，覆盖本机已安装的微信、邮件、信息等目标，用于备忘录等内容的分享。',
          permissions: '无（由系统分享面板处理）',
          data: '不收集；分享内容仅经由系统分享面板传出',
          privacyUrl: 'https://pub.dev/packages/share_plus',
        ),
      ],
    ),
    // —— 架构与网络 ——
    SdkGroup(
      title: '架构与网络',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'flutter_riverpod',
          version: '3.3.2',
          vendor: 'Remi Rousselet（社区维护）',
          purpose: '全应用共享的响应式状态管理。',
          permissions: '无',
          data: '不收集',
          privacyUrl: 'https://pub.dev/packages/flutter_riverpod',
        ),
        SdkEntry(
          name: 'go_router',
          version: '17.3.0',
          vendor: 'Flutter 官方团队（Google）',
          purpose: '声明式路由，承载启动屏与底部 Tab 壳层的导航。',
          permissions: '无',
          data: '不收集',
          privacyUrl: 'https://pub.dev/packages/go_router',
        ),
        SdkEntry(
          name: 'dio',
          version: '5.10.0',
          vendor: '社区维护',
          purpose: 'HTTP 客户端，用于对外网络请求。',
          permissions: '无（Android INTERNET 权限无需运行时申请）',
          data: '库本身不收集任何数据',
          privacyUrl: 'https://pub.dev/packages/dio',
        ),
      ],
    ),
    // —— 数据与存储 ——
    SdkGroup(
      title: '数据与存储',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'hive / hive_flutter',
          version: '2.2.3 / 1.1.0',
          vendor: '社区维护',
          purpose: '本地键值存储，保存语言、主题等轻量设置。',
          permissions: '无',
          data: '仅存储在本机，不上传',
          privacyUrl: 'https://pub.dev/packages/hive',
        ),
        SdkEntry(
          name: 'isar_community（含 flutter libs）',
          version: '3.3.2',
          vendor: 'Isar 社区维护分支',
          purpose: '本地嵌入式数据库，保存各子工具的记录。',
          permissions: '无',
          data: '仅存储在本机，不上传',
          privacyUrl: 'https://pub.dev/packages/isar_community',
        ),
        SdkEntry(
          name: 'path_provider',
          version: '2.1.6',
          vendor: 'Flutter 官方团队（Google）',
          purpose: '解析应用目录，供缓存清理与数据库使用。',
          permissions: '无',
          data: '不收集',
          privacyUrl: 'https://pub.dev/packages/path_provider',
        ),
        SdkEntry(
          name: 'supabase_flutter',
          version: '2.17.2',
          vendor: 'Supabase Inc.',
          purpose:
              '邮箱注册登录、云端资料同步，以及承载匿名埋点事件的 Edge Function 网关。',
          permissions: '无（仅使用网络）',
          data: '邮箱地址、昵称、头像 URL、会员权益状态与匿名使用事件',
          privacyUrl: 'https://supabase.com/privacy',
          sensitive: true,
        ),
        SdkEntry(
          name: 'sign_in_with_apple',
          version: '8.2.0',
          vendor: '社区维护（Flutter 官方推荐的桥接插件）',
          purpose:
              '在 iOS / macOS 上调起系统原生的「通过 Apple 登录」授权弹窗，用于一键注册与登录。'
              'Android 平台不使用本插件（Apple 未提供 Android SDK）。',
          permissions: '无',
          data:
              '插件自身不收集数据；用户可在授权时选择「隐藏我的邮箱」，'
              '此时 Apple 会提供隐私中继邮箱而非真实邮箱',
          privacyUrl: 'https://www.apple.com/legal/privacy/data/',
        ),
        SdkEntry(
          name: 'crypto',
          version: '3.0.7',
          vendor: 'Dart 官方团队',
          purpose:
              '计算 SHA-256，用于 Apple 原生登录时对防重放随机数（nonce）取哈希。',
          permissions: '无',
          data: '不收集',
          privacyUrl: 'https://pub.dev/packages/crypto',
        ),
        SdkEntry(
          name: 'google_sign_in',
          version: '6.3.0',
          vendor: 'Flutter 官方团队（Google）',
          purpose:
              '在 Android 与（非 Apple 的）iOS 平台拉起系统级 Google 授权，拿到 Google 账号标识后由 Supabase 换取登录会话，作为一键登录入口。',
          permissions: '无（由系统 Google 授权面板处理）',
          data:
              'Google 账号标识（idToken / accessToken）与头像、昵称等公开资料，经 Supabase 用于登录与会话',
          privacyUrl: 'https://policies.google.com/privacy',
          sensitive: true,
        ),
        SdkEntry(
          name: 'device_info_plus',
          version: '13.2.0',
          vendor: 'Flutter 官方团队（Google）',
          purpose:
              '读取游客设备唯一标识（iOS 的 IDFV / Android 的 ANDROID_ID），用于免费使用次数在重装后仍可识别同一设备的持久化。',
          permissions: '无（读取设备标识无需运行时权限）',
          data:
              '设备标识经 SHA-256 哈希后以匿名设备标识上报，无法反推原始 ID；用于识别匿名游客设备，不上传其它数据',
          privacyUrl: 'https://pub.dev/packages/device_info_plus',
          sensitive: true,
        ),
      ],
    ),
    // —— 设备能力 ——
    SdkGroup(
      title: '设备能力',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'flutter_compass',
          version: '0.8.1',
          vendor: '社区维护',
          purpose: '读取磁力计方位角，供指南针工具使用。',
          permissions: '无（磁力计无需运行时权限）',
          data: '仅在本机处理',
          privacyUrl: 'https://pub.dev/packages/flutter_compass',
        ),
        SdkEntry(
          name: 'geolocator',
          version: '14.0.3',
          vendor: 'Baseflow（Flutter 社区）',
          purpose: '获取海拔与经纬度，与指南针结果一并展示。',
          permissions: '定位：iOS 使用期间 / Android ACCESS_FINE_LOCATION、ACCESS_COARSE_LOCATION',
          data: '仅在本机处理，不上传',
          privacyUrl: 'https://pub.dev/packages/geolocator',
          sensitive: true,
        ),
        SdkEntry(
          name: 'noise_meter',
          version: '5.1.0',
          vendor: '社区维护',
          purpose: '麦克风采样，供噪音检测工具使用。',
          permissions: '麦克风：iOS NSMicrophoneUsageDescription / Android RECORD_AUDIO',
          data: '仅在本机处理，不录音、不保存、不上传',
          privacyUrl: 'https://pub.dev/packages/noise_meter',
          sensitive: true,
        ),
        SdkEntry(
          name: 'sensors_plus',
          version: '7.1.0',
          vendor: 'Flutter 官方团队（Google）',
          purpose: '读取加速度计数据，供水平仪工具使用。',
          permissions: '无',
          data: '仅在本机处理',
          privacyUrl: 'https://pub.dev/packages/sensors_plus',
        ),
        SdkEntry(
          name: 'camera',
          version: '0.12.0+2',
          vendor: 'Flutter 官方团队（Google）',
          purpose: '访问相机，仅用于控制闪光灯（手电筒）。',
          permissions: '相机：iOS NSCameraUsageDescription / Android CAMERA',
          data: '不拍摄、不保存、不上传任何图像或视频',
          privacyUrl: 'https://pub.dev/packages/camera',
          sensitive: true,
        ),
        SdkEntry(
          name: 'permission_handler',
          version: '12.0.3',
          vendor: 'Baseflow（Flutter 社区）',
          purpose: '拉起上述各项系统权限的申请弹窗。',
          permissions: '无（仅代本应用申请权限）',
          data: '不收集',
          privacyUrl: 'https://pub.dev/packages/permission_handler',
        ),
      ],
    ),
    // —— 支付与评分 ——
    SdkGroup(
      title: '支付与评分',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'in_app_purchase',
          version: '3.3.0',
          vendor: 'Flutter 官方团队（Google）',
          purpose: '买断型（非消耗品）会员内购。',
          permissions: '无（由应用商店处理）',
          data: '交易由 Apple 或 Google 处理，本应用仅获取权益状态',
          privacyUrl: 'https://www.apple.com/legal/privacy/',
          sensitive: true,
        ),
        SdkEntry(
          name: 'in_app_purchase_storekit',
          version: '0.4.13',
          vendor: 'Flutter 官方团队（Google）',
          purpose: 'iOS StoreKit 2 接口，用户点击「恢复购买」时刷新权益。',
          permissions: '无（由应用商店处理）',
          data: '仅权益状态',
          privacyUrl: 'https://www.apple.com/legal/privacy/',
          sensitive: true,
        ),
        SdkEntry(
          name: 'in_app_review',
          version: '2.0.12',
          vendor: 'Flutter 官方团队（Google）',
          purpose: '唤起系统应用内评分弹窗，不可用时回落到商店详情页。',
          permissions: '无',
          data: '不收集',
          privacyUrl: 'https://pub.dev/packages/in_app_review',
        ),
      ],
    ),
    // —— 广告变现 ——
    SdkGroup(
      title: '广告变现',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'google_mobile_ads',
          version: '9.1.0',
          vendor: 'Google LLC',
          purpose: '在 App 内的部分页面请求并展示自适应横幅广告；购买 Pro Unlock 后不再请求广告。',
          permissions: '本应用未额外声明权限（SDK 使用网络）',
          data: '设备与广告互动数据由 Google AdMob 处理，详见 Google 隐私政策',
          privacyUrl: 'https://policies.google.com/privacy',
          sensitive: true,
        ),
      ],
    ),
    // —— 应用内网页容器 ——
    SdkGroup(
      title: '应用内网页容器',
      entries: <SdkEntry>[
        SdkEntry(
          name: 'webview_flutter',
          version: '4.14.1',
          vendor: 'Flutter 官方团队（Google）',
          purpose:
              '在应用内直接渲染在线文档（用户协议、隐私政策、SDK 清单链接等），避免跳出外部浏览器造成的割裂感。',
          permissions:
              '网络（macOS 需开启 com.apple.security.network.client 沙盒权限）',
          data: '仅加载由本应用指定的公开文档 URL，不注入脚本、不收集所渲染内容',
          privacyUrl: 'https://pub.dev/packages/webview_flutter',
        ),
      ],
    ),
  ],
  // —— 系统平台框架（非第三方 SDK，仅补充说明）——
  platformTitle: '系统平台框架',
  platformNote:
      '以下框架随操作系统提供，不属于第三方 SDK。此处仅作补充说明——应用商店'
      '审核与隐私披露常会问及。它们受 Apple 或 Google 各自平台条款约束。',
  platforms: <SdkEntry>[
    SdkEntry(
      name: 'StoreKit 2 / Google Play Billing',
      version: '系统内置',
      vendor: 'Apple Inc. / Google LLC',
      purpose: '处理买断型会员支付。',
      permissions: '无',
      data: '支付数据由 Apple 或 Google 处理',
      sensitive: true,
    ),
    SdkEntry(
      name: 'Core Location / 定位服务',
      version: '系统内置',
      vendor: 'Apple Inc. / Google LLC',
      purpose: '提供海拔与经纬度。',
      permissions: '定位',
      data: '仅在本机处理',
      sensitive: true,
    ),
    SdkEntry(
      name: 'AVFoundation / Camera2',
      version: '系统内置',
      vendor: 'Apple Inc. / Google LLC',
      purpose: '提供闪光灯（手电筒）控制能力。',
      permissions: '相机',
      data: '不采集任何媒体内容',
      sensitive: true,
    ),
    SdkEntry(
      name: 'CoreMotion / 传感器框架',
      version: '系统内置',
      vendor: 'Apple Inc. / Google LLC',
      purpose: '提供加速度计、陀螺仪与磁力计采样。',
      permissions: '无',
      data: '仅在本机处理',
      sensitive: true,
    ),
  ],
  // —— 说明 ——
  noteTitle: '说明',
  noteBody:
      '统计范围：仅列出会打进发布包、运行期真正生效的库。flutter_native_splash '
      '等仅在构建期使用的开发依赖不会随应用分发，故不列入。\n\n'
      '「数据收集」一栏描述的是本 App 对各库的使用方式，不代表库提供方在其'
      '自有服务中的数据处理行为。\n\n'
      '广告说明：免费版会在 App 内的部分页面展示 Google AdMob 横幅广告，'
      '购买 Pro Unlock 后不再请求与展示广告。本 App 不申请「应用跟踪透明度」'
      '授权，也不向广告网络回传任何工具使用数据。\n\n'
      '点击链接即复制到剪贴板。本页刻意不引入应用内浏览器依赖，因此展示该页面'
      '本身不额外申请任何权限。',
);
