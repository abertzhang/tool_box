// 文件职责：Dio 错误拦截器，保留统一错误处理的扩展点。
//
// 所属模块：common/http_util/middleware（网络拦截器层）。
// 关键依赖：dio 的 Interceptor 体系。
//
// 当前不改写异常内容，仅将原始异常继续向上传递。
import 'package:dio/dio.dart';

/// 捕获 Dio 网络异常并保留统一处理的扩展点。
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 保持原始异常继续传递，不在基础层改变上层依赖的错误内容。
    handler.next(err);
  }
}
