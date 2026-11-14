import 'package:dio/dio.dart';

import 'middleware/error_interceptor.dart';
import 'middleware/request_interceptor.dart';
import 'middleware/response_interceptor.dart';

/// 文件职责：封装基于 Dio 的 HTTP 网络请求客户端，对外提供统一的
/// GET / POST / 表单上传 / PUT / DELETE 方法。
///
/// 所属模块：common/http_util（网络层）。
/// 关键依赖：
/// - [dio]：底层 HTTP 库；
/// - 三个拦截器：[RequestInterceptor]、[ResponseInterceptor]、[ErrorInterceptor]，
///   分别负责统一注入鉴权头、解析业务响应体、统一错误文案。
///
/// 注意：本类采用「懒加载单例」模式，全局共享同一个 [Dio] 实例与拦截器链。
class HttpUtil {
  // 单例
  static HttpUtil? _instance;
  late final Dio _dio;

  /// 工厂构造函数，返回全局唯一的 [HttpUtil] 实例（懒加载单例）。
  ///
  /// 首次访问时才会创建实例并初始化 [Dio] 及其拦截器链，
  /// 后续访问直接复用同一实例，避免重复创建连接池。
  factory HttpUtil() {
    _instance ??= HttpUtil._internal();
    return _instance!;
  }

  /// 私有命名构造函数，仅在 [factory] 中创建首个实例时调用一次。
  ///
  /// 负责配置 [Dio] 的基础选项（域名、超时时间、默认请求头），
  /// 并按「请求 -> 响应 -> 错误」的顺序挂载三个拦截器。
  HttpUtil._internal() {
    BaseOptions options = BaseOptions(
      baseUrl: "https://api.xxx.com", // 替换成你的基础域名
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {"Content-Type": "application/json"},
    );
    _dio = Dio(options);

    // 添加拦截器
    _dio.interceptors.add(RequestInterceptor());
    _dio.interceptors.add(ResponseInterceptor());
    _dio.interceptors.add(ErrorInterceptor());
  }

  /// 暴露底层 [Dio] 实例，供需要直接操作 Dio 的场景（如文件下载、流式请求）使用。
  Dio get dio => _dio;

  /// 发送 GET 请求。
  ///
  /// 参数：
  /// - [path]：接口路径（会自动拼接 [baseUrl]）；
  /// - [params]：query 查询参数；
  /// - [cancelToken]：用于取消本次请求的令牌；
  /// - [options]：额外的 Dio 请求选项，可覆盖默认配置。
  ///
  /// 返回：解析后的响应体数据（[T] 类型）。
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? params,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    Response response = await _dio.get(
      path,
      queryParameters: params,
      cancelToken: cancelToken,
      options: options,
    );
    return response.data;
  }

  /// 发送 POST 请求（请求体为 JSON）。
  ///
  /// 参数：
  /// - [path]：接口路径；
  /// - [data]：请求体数据（会被序列化为 JSON）；
  /// - [params]：拼接到 URL 上的 query 参数；
  /// - [cancelToken] / [options]：含义同 [get]。
  ///
  /// 返回：[T] 类型的响应数据。
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? params,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    Response response = await _dio.post(
      path,
      data: data,
      queryParameters: params,
      cancelToken: cancelToken,
      options: options,
    );
    return response.data;
  }

  /// 以 multipart/form-data 表单形式上传数据（常用于文件上传）。
  ///
  /// 参数：
  /// - [path]：上传接口路径；
  /// - [data]：必填的 [FormData]，包含需要上传的字段与文件；
  /// - [cancelToken]：用于取消上传。
  ///
  /// 返回：[T] 类型的响应数据。
  Future<T> postForm<T>(
    String path, {
    required FormData data,
    CancelToken? cancelToken,
  }) async {
    Response response = await _dio.post(
      path,
      data: data,
      cancelToken: cancelToken,
      options: Options(contentType: Headers.multipartFormDataContentType),
    );
    return response.data;
  }

  /// 发送 PUT 请求（通常用于更新资源）。
  ///
  /// 参数：
  /// - [path]：接口路径；
  /// - [data]：请求体数据。
  ///
  /// 返回：[T] 类型的响应数据。
  Future<T> put<T>(String path, {dynamic data}) async {
    Response response = await _dio.put(path, data: data);
    return response.data;
  }

  /// 发送 DELETE 请求（通常用于删除资源）。
  ///
  /// 参数：
  /// - [path]：接口路径；
  /// - [data]：可选请求体数据。
  ///
  /// 返回：[T] 类型的响应数据。
  Future<T> delete<T>(String path, {dynamic data}) async {
    Response response = await _dio.delete(path, data: data);
    return response.data;
  }
}
