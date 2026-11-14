// 文件职责：Dio 响应拦截器，统一解析后端「业务响应壳」，
// 只把 data 字段透传给上层，并按业务码做分支处理。
//
// 所属模块：common/http_util/middleware（网络拦截器层）。
// 关键依赖：dio 的 Interceptor 体系。
//
// 约定的响应结构：{ "code": int, "msg": String, "data": dynamic }。
import 'package:dio/dio.dart';

/// 统一处理后端业务响应：剥离业务壳、按 code 分发成功/鉴权失效/业务错误。
class ResponseInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // 约定后端返回带 code/msg/data 字段的 JSON 对象
    Map<String, dynamic> resData = response.data;
    int code = resData["code"];

    if (code == 200) {
      // 正常，只向外抛出data部分
      response.data = resData["data"];
      handler.next(response);
    } else if (code == 401) {
      // token失效，跳转登录
      throw DioException(
        requestOptions: response.requestOptions,
        message: "登录已过期，请重新登录",
      );
    } else {
      // 业务错误抛出异常
      throw DioException(
        requestOptions: response.requestOptions,
        message: resData["msg"] ?? "请求失败",
      );
    }
  }
}
