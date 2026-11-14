// ============================================================================
// 文件：feature/tool/provider/flashlight_provider.dart
// 模块：工具箱（tool）· 手电筒子工具
//
// 职责：
//   以应用级 Riverpod [Notifier] 持有「相机闪光灯常亮（手电筒）」的开关状态与
//   底层 [CameraController]，并提供 开 / 关 / 释放 控制。复用工程已有的 camera
//   依赖（0.12.0+2），不引入新包，避免在沙箱 / 离线环境下触发依赖解析失败。
//
// 关键设计：
//   - 懒初始化：首次开启时才初始化后置摄像头控制器，避免一进 App 就抢占相机；
//   - 真正开关的是闪光灯 torch 模式，而非开启相机预览，因此不会在屏幕上显示取景画面；
//   - [turnOff]：关闭闪光灯并 dispose 控制器（系统随即灭灯），状态复位为 false；
//   - 应用被关闭由根组件 [FlashlightGuard] 在生命周期 detached / paused 时调用
//     [turnOff]，确保进程退出后闪光灯不会常亮（iOS 进后台也会强制回收相机，故一并处理）。
//
// 权限：iOS 需 NSCameraUsageDescription，Android 需 CAMERA（工程已具备 / 将补齐）。
//   权限被拒时 [toggle] 会抛出 [CameraException]，由调用方捕获并提示用户。
// ============================================================================

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 手电筒（相机闪光灯常亮）控制器 Provider。
///
/// 状态为 [bool]：true = 闪光灯开启，false = 关闭。
/// 通过 `ref.read(flashlightProvider.notifier)` 拿到 [FlashlightController] 进行开关操作，
/// 通过 `ref.watch(flashlightProvider)` 订阅开关状态以驱动 UI（如 ToolPage 卡片图标）。
final flashlightProvider = NotifierProvider<FlashlightController, bool>(
  FlashlightController.new,
);

/// 手电筒控制器。
///
/// 封装 camera 包的 [CameraController] 生命周期：
///   - 开启：懒初始化后置摄像头 → setFlashMode(torch) 常亮；
///   - 关闭：setFlashMode(off) 后 dispose 控制器，系统灭灯；
///   - 任意时刻调用 [turnOff] 都是幂等的，可安全地被生命周期守卫反复调用。
class FlashlightController extends Notifier<bool> {
  /// 底层相机控制器，开启时非空。用可空变量持有（父类 [state] 不可提升为本地 final）。
  CameraController? _controller;

  @override
  bool build() => false;

  /// 切换手电筒：关 → 开；开 → 关。
  ///
  /// 开启失败（权限被拒 / 无相机 / 设备不支持）会重新抛出 [CameraException] 等异常，
  /// 调用方应捕获并向用户提示，不要静默吞掉。
  Future<void> toggle() async {
    if (state) {
      await _disable();
    } else {
      await _enable();
    }
  }

  /// 开启闪光灯：初始化后置摄像头并把闪光灯设为 torch 常亮。
  Future<void> _enable() async {
    try {
      // 列出可用相机，优先选取后置镜头（手电筒必须用后置闪光灯）。
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _controller = CameraController(
        back,
        ResolutionPreset.low, // 尽量低分辨率：仅借相机通道点亮闪光灯，无需预览流。
        enableAudio: false,
      );
      await _controller!.initialize();
      await _controller!.setFlashMode(FlashMode.torch);
      state = true;
    } on CameraException {
      // 权限被拒或设备不支持：先释放已占用的资源，再恢复关闭态并向上抛出。
      await _release();
      state = false;
      rethrow;
    } catch (e) {
      // 其它意外（如 availableCameras 抛错）：同样清理后抛出，便于调用方统一处理。
      await _release();
      state = false;
      rethrow;
    }
  }

  /// 关闭闪光灯：先复位再释放控制器。
  Future<void> _disable() async {
    await _release();
    state = false;
  }

  /// 释放相机控制器并灭灯。
  ///
  /// 控制器 dispose 后系统会收回相机硬件、闪光灯随之熄灭。
  /// 该方法是幂等的——重复调用或控制器已为空都不会出错。
  Future<void> _release() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    // 先尝试把闪光灯关掉再释放，确保硬件状态干净（部分机型 dispose 不自动灭灯）。
    try {
      await controller.setFlashMode(FlashMode.off);
    } catch (_) {
      // 控制器可能已失效，忽略错误，继续 dispose。
    }
    await controller.dispose();
  }

  /// 供应用生命周期守卫调用：关闭手电筒并释放相机资源。
  ///
  /// 在 App 被关闭 / 切后台时由 [FlashlightGuard] 触发，保证闪光灯不会常亮。
  /// 幂等，可反复调用。
  Future<void> turnOff() async {
    if (!state && _controller == null) return;
    await _release();
    state = false;
  }
}

/// 应用生命周期守卫：在 App 关闭或进入后台时关闭手电筒，避免闪光灯常亮。
///
/// 置于根组件 [MaterialApp.router] 之上，通过 [WidgetsBindingObserver] 监听
/// [AppLifecycleState]；当状态变为 detached（进程销毁）或 paused（进入后台）时，
/// 调用 [FlashlightController.turnOff] 灭灯。
///
/// 说明：iOS 在进入后台时会强制回收相机，闪光灯必然熄灭，故 paused 也处理以保持 UI
/// 状态与实际一致；Android 在后台可保留手电筒，但为跨平台一致与省电同样在此关闭。
class FlashlightGuard extends StatefulWidget {
  /// 创建守卫，[child] 为被包裹的根组件（MaterialApp.router）。
  const FlashlightGuard({super.key, required this.child});

  /// 被守卫包裹的根组件。
  final Widget child;

  @override
  State<FlashlightGuard> createState() => _FlashlightGuardState();
}

class _FlashlightGuardState extends State<FlashlightGuard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // 注册生命周期观察者，App 前后台切换 / 销毁时收到回调。
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // 组件销毁时移除观察者，避免泄漏。
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    // detached：用户划掉 App / 系统回收，进程即将消亡，必须灭灯；
    // paused：进入后台（iOS 会强制回收相机），为状态一致也灭灯。
    if (lifecycleState == AppLifecycleState.detached ||
        lifecycleState == AppLifecycleState.paused) {
      // 不 await：生命周期回调里尽快触发释放，剩余交给系统的相机回收兜底。
      unawaited(
        ProviderScope.containerOf(
          context,
        ).read(flashlightProvider.notifier).turnOff(),
      );
    }
    super.didChangeAppLifecycleState(lifecycleState);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
