// ============================================================================
// 文件：common/util/device_id.dart
// 模块：common/util（游客设备识别）
//
// 职责：
//   为「未登录游客」生成一个跨 App 重装仍然稳定的设备唯一号，用于把免费使用次数
//   绑定到设备（防止用户靠卸载重装清零 30 次免费额度）。
//
// 设备号来源（均为系统级、跨重装稳定，无需任何权限）：
//   - iOS     ：identifierForVendor（IDFV）。只要同开发者还有别的 App 在设备上，
//               重装本 App 后 IDFV 不变。
//   - Android ：Settings.Secure.ANDROID_ID（SSAID）。同签名密钥下重装不变，
//               仅恢复出厂 / 新建用户档案才会变。
//
// 隐私处理：
//   上报到服务端的不是明文设备标识，而是 SHA-256 哈希值（见 [getDeviceId]）。
//   服务端只存哈希设备号，即便库泄露也无法反推真实设备 ID。
//
// 兜底：
//   模拟器 / 取不到原生 ID 的极端情况下，生成本机随机 UUID 存 SharedPreferences。
//   这种兜底号重装会丢（SP 被清），但真实设备走原生 ID，本就跨重装稳定，不受影响。
// ============================================================================

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 中缓存兜底 UUID 的键（仅极端兜底用，重装会丢）。
const String _spFallbackKey = 'device_id_fallback';

/// 取游客设备唯一号（已做 SHA-256 哈希）。
///
/// 返回值是哈希串（长度固定 64 字符），可直接作为 `anonymous_devices.device_id`
/// 主键写入服务端。同一设备每次调用返回值一致，因此服务端能跨重装识别同一台手机。
Future<String> getDeviceId() async {
  // 1) 优先取系统级原生设备号（跨重装稳定）。
  String? raw;
  try {
    final DeviceInfoPlugin plugin = DeviceInfoPlugin();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final IosDeviceInfo ios = await plugin.iosInfo;
      raw = ios.identifierForVendor;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidDeviceInfo android = await plugin.androidInfo;
      final String id = android.id;
      // 已知 AOSP 模拟器 / 坏值（Genymotion、部分定制 ROM 会返回这个固定串），
      // 它既不唯一也不稳定，不能作为设备号。
      if (id.isNotEmpty && id != '9774d56d682e549c') {
        raw = id;
      }
    }
  } catch (_) {
    // 取原生信息异常（权限、channel 失败等）：落到兜底，不影响限额功能。
    raw = null;
  }

  // 2) 兜底：本机随机 UUID（sha256.convert(时间 + 随机数)），存 SP 保证同安装内稳定。
  if (raw == null || raw.isEmpty) {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    String? fallback = sp.getString(_spFallbackKey);
    if (fallback == null) {
      final Random rnd = Random();
      final List<int> bytes = <int>[
        ...DateTime.now().microsecondsSinceEpoch.toString().codeUnits,
        ...List<int>.generate(16, (_) => rnd.nextInt(256)),
      ];
      fallback = sha256.convert(bytes).toString();
      await sp.setString(_spFallbackKey, fallback);
    }
    raw = fallback;
  }

  // 3) 哈希后再上报：服务端只存哈希设备号，降低明文设备标识泄露风险。
  final List<int> hashInput = utf8.encode(raw);
  return sha256.convert(hashInput).toString();
}
