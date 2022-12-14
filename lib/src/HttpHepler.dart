
// ignore_for_file: depend_on_referenced_packages, file_names, deprecated_member_use

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime_type/mime_type.dart' as mime;

enum HttpMethod { get, post, delete, put, patch }

int timeOut = 30000;

class HttpHelper {

  static Future<bool> Function()? refeshToken;
  static Future Function()? actionNotRefeshToken;
  static Future<String> Function()? funcGetToken;
  static String? finger;

  static Future<Response> requestApi(
    String url,
    dynamic params,
    HttpMethod httpMethod,
    bool auth, {
    bool body = true,
    Map<String, dynamic>? headers,
  }) async {
    Response? response;
    Options options;
    var dio = Dio();
    dio.options.connectTimeout = timeOut; //5s
    dio.options.receiveTimeout = timeOut;
    dio.interceptors.add(
      InterceptorsWrapper(
        // handle onRequest
        onRequest: (
          RequestOptions requestOptions,
          RequestInterceptorHandler handler,
        ) async {
          dio.interceptors.requestLock.lock();
          if (auth) {
            String token = funcGetToken == null ? '' : await funcGetToken!.call();
            if (token != '') {
              requestOptions.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
              if (finger != null) {
                requestOptions.headers['Finger'] = finger;
              }
              dio.interceptors.requestLock.unlock();
              return handler.next(requestOptions);
            }
          }
          dio.interceptors.requestLock.unlock();
          return handler.next(requestOptions);
        },
        // handle onResponse
        onResponse: (
          Response response,
          ResponseInterceptorHandler handler,
        ) async {
          // Do something with response data
          bool isValidData = response.data != null;
          if (isValidData) {
            return handler.next(response);
          }
          return handler.next(response); // continue
        },
        // handle onError
        onError: (
          DioError error,
          ErrorInterceptorHandler handler,
        ) async {
          // print(error.toString());
          // await DialogBuilder.showSimpleDialog(error.toString());
          //SnackbarBuilder.showSnackbar(content: 'Máy chủ đang bảo trì');
          switch (error.type) {
            case DioErrorType.cancel:
              debugPrint('requestCancelled');
              break;
            case DioErrorType.connectTimeout:
              debugPrint('requestTimeout');
              break;
            case DioErrorType.receiveTimeout:
              debugPrint('sendTimeout');
              break;
            case DioErrorType.response:
              debugPrint('response error ${error.response?.realUri} ${error.response?.statusCode}');
              if (error.response?.statusCode == 401 ||
                  error.response?.statusCode == 403) {
                if (error.response!.realUri.toString().contains('user/login')) {
                  return handler.next(error);
                }
                // await handleEventAuthError(error);  // code removed to fix case: only 1 device can be used at a time
                // remove code below when backend fix bug use token on multiple devices
                if (!error.response!.realUri.toString().contains('firebase/unsubscribe-device')) {
                  //UserService.unRegisterFirebase();
                }
                if (error.response?.statusCode == 401) {
                  if (refeshToken != null && actionNotRefeshToken != null) {
                    var isGetAccessTokenSuccess = await refeshToken!.call();
                    if (isGetAccessTokenSuccess) {
                      requestApi(url, params, httpMethod, auth, body: body, headers: headers);
                    } else {
                      await actionNotRefeshToken!.call();
                    }
                  } else if (actionNotRefeshToken != null) {
                    await actionNotRefeshToken!.call();
                  }
                }
              }
              break;
            case DioErrorType.sendTimeout:
              break;
            case DioErrorType.other:
              debugPrint('Dio onError DioErrorType.other');
              break;
          }
          return handler.next(error);
        },
      ),
    );

    // creatFile
    // headers ??= <String, dynamic>{};
    // headers["client"] = "mobile_app";
    // headers["platform"] = TrackingHelper.platform;
    // headers["appVersion"] = TrackingHelper.appVersion;
    // headers["deviceInfo"] = TrackingHelper.deviceInfo;

    if (body) {
      options = Options(
        headers: headers,
        contentType: Headers.jsonContentType,
        followRedirects: false,
        responseType: ResponseType.json,
        validateStatus: (status) {
          return status! <= 500;
        },
      );
    } else {
      options = Options(
        headers: headers,
        contentType: Headers.formUrlEncodedContentType,
        followRedirects: false,
        responseType: ResponseType.json,
        validateStatus: (status) {
          return status! <= 500;
        },
      );
    }

    try {
      ///GET
      if (httpMethod == HttpMethod.get) {
        response = await dio.get(
          url,
          queryParameters: params,
          options: options,
        );
      }

      ///POST
      if (httpMethod == HttpMethod.post) {
        response = await dio.post(
          url,
          data: params,
          options: options,
        );
      }

      ///PUT
      if (httpMethod == HttpMethod.put) {
        response = await dio.put(
          url,
          data: params,
          options: options,
        );
      }

      ///DELETE
      if (httpMethod == HttpMethod.delete) {
        response = await dio.delete(
          url,
          data: params,
          options: options,
        );
      }

      ///PATCH
      if (httpMethod == HttpMethod.patch) {
        response = await dio.patch(
          url,
          data: params,
          options: options,
        );
      }
    } catch (ex) {
      debugPrint("=======Lỗi try catch api=====");
      debugPrint(ex.toString());
      response = Response(requestOptions: RequestOptions(path: ""), statusCode: 696969);
    }
    if (response == null || response.statusCode == null) {
      response = Response(requestOptions: RequestOptions(path: ""), statusCode: 696969);
    }
    return response;
  }

  static Future<Response> uploadMultiImage({
    required String url,
    bool auth = false,
    bool isSocial = false,
    bool isSingleImage = false,
    required List<File> listFile,
    Function(int total, int process, {CancelToken cancelToken})? onCallBackUpload,
  }) async {
    late Response response;
    try {
      var dio = Dio();
      dio.interceptors.add(LogInterceptor(
        responseBody: true,
        requestBody: true,
        requestHeader: true,
        request: true,
      ));
      var headers = <String, String>{};
      if (auth) {
        String token = funcGetToken == null ? '' : await funcGetToken!.call();
        if (token != '') {
          headers["Authorization"] = token;
        }
      }
      // headers["platform"] = TrackingHelper.platform;
      // headers["appVersion"] = TrackingHelper.appVersion;
      // headers["deviceInfo"] = TrackingHelper.deviceInfo;

      var text = "";
      var time = DateTime.now().toString();
      var timeStart = DateTime.now();
      Options options;

      options = Options(
        headers: headers,
        followRedirects: false,
        validateStatus: (status) {
          return status! <= 500;
        },
      );
      options.contentType = Headers.jsonContentType;

      var formData = FormData();
      for (var file in listFile) {
        var mimeType = mime.mime(file.path);
        String mimeeee = "";
        String type = "";
        if (mimeType != null) {
          mimeeee = mimeType.split('/')[0];
          type = mimeType.split('/')[1];
        }
        if (isSingleImage) {
          formData.files.addAll([
            MapEntry("images", await MultipartFile.fromFile(file.path, contentType: MediaType(mimeeee, type))),
          ]);
        } else {
          formData.files.addAll([
            MapEntry(isSocial ? "files[]" : "files", await MultipartFile.fromFile(file.path, contentType: MediaType(mimeeee, type))),
          ]);
        }
      }
      // print(fileName);
      // if (file is File)
      //   data = FormData.fromMap({
      //     "file": await MultipartFile.fromFile(
      //       file.path,
      //       filename: path.basename(file.path),
      //     ),
      //   });
      // else
      //   data = FormData.fromMap({
      //     "file": MultipartFile.fromBytes(
      //       file,
      //       filename: fileName,
      //     ),
      //   });
      CancelToken cancelToken = CancelToken();
      try {
        response = await dio.post(
          url,
          data: formData,
          cancelToken: cancelToken,
          onSendProgress: (int sent, int total) {
            debugPrint("$sent $total");
            if (onCallBackUpload != null) onCallBackUpload(sent, total, cancelToken: cancelToken);
          },
          options: options,
        );
      } catch (ex) {
        debugPrint("=======Lỗi try catch api=====");
        debugPrint(ex.toString());
        response = Response(requestOptions: RequestOptions(path: ""), statusCode: 696969);
      }
      text += "url: $url \n";
      text += "httpMethod: httpMethod.post \n";
      text += "param: ${formData.files} \n";
      text += "header: ${options.headers.toString()} \n";
      text += "contentType: ${options.contentType} \n";
      text += "timeStartRequest: $time \n";
      var timeEnd = DateTime.now();
      final difference = timeEnd.difference(timeStart).inMilliseconds;
      text += "RequestTime: $difference \n";
      text += "responseStatusCode: ${response.statusCode.toString()} \n";
      text += "response: $response";
      debugPrint(text);
      return response;
    } catch (e) {
      debugPrint(e.toString());
      return response;
    }
  }

  static Future<Response> uploadMultiFile({
    required String url,
    bool auth = false,
    bool isSingleFile = false,
    required List<File> listFile,
    Function(int total, int process, {CancelToken cancelToken})? onCallBackUpload,
  }) async {
    late Response response;
    try {
      var dio = Dio();
      dio.interceptors.add(LogInterceptor(
        responseBody: true,
        requestBody: true,
        requestHeader: true,
        request: true,
      ));
      var headers = <String, String>{};
      if (auth) {
        String token = funcGetToken == null ? '' : await funcGetToken!.call();
        if (token != '') {
          headers["Authorization"] = token;
        }
      }
      // headers["platform"] = TrackingHelper.platform;
      // headers["appVersion"] = TrackingHelper.appVersion;
      // headers["deviceInfo"] = TrackingHelper.deviceInfo;

      var text = "";
      var time = DateTime.now().toString();
      var timeStart = DateTime.now();
      Options options;

      options = Options(
        headers: headers,
        followRedirects: false,
        validateStatus: (status) {
          return status! <= 500;
        },
      );
      options.contentType = Headers.jsonContentType;

      var formData = FormData();
      for (var file in listFile) {
        var mimeType = mime.mime(file.path);
        String mimeeee = "";
        String type = "";
        if (mimeType != null) {
          mimeeee = mimeType.split('/')[0];
          type = mimeType.split('/')[1];
        }
        formData.files.addAll([
          MapEntry("files", await MultipartFile.fromFile(file.path, contentType: MediaType(mimeeee, type))),
        ]);
      }
      // print(fileName);
      // if (file is File)
      //   data = FormData.fromMap({
      //     "file": await MultipartFile.fromFile(
      //       file.path,
      //       filename: path.basename(file.path),
      //     ),
      //   });
      // else
      //   data = FormData.fromMap({
      //     "file": MultipartFile.fromBytes(
      //       file,
      //       filename: fileName,
      //     ),
      //   });
      CancelToken cancelToken = CancelToken();
      try {
        response = await dio.post(
          url,
          data: formData,
          cancelToken: cancelToken,
          onSendProgress: (int sent, int total) {
            debugPrint("$sent $total");
            if (onCallBackUpload != null) onCallBackUpload(sent, total, cancelToken: cancelToken);
          },
          options: options,
        );
      } catch (ex) {
        debugPrint("=======Lỗi try catch api=====");
        debugPrint(ex.toString());
        response = Response(requestOptions: RequestOptions(path: ""), statusCode: 696969);
      }
      text += "url: $url \n";
      text += "httpMethod: httpMethod.post \n";
      text += "param: ${formData.files} \n";
      text += "header: ${options.headers.toString()} \n";
      text += "contentType: ${options.contentType} \n";
      text += "timeStartRequest: $time \n";
      var timeEnd = DateTime.now();
      final difference = timeEnd.difference(timeStart).inMilliseconds;
      text += "RequestTime: $difference \n";
      text += "responseStatusCode: ${response.statusCode.toString()} \n";
      text += "response: $response";
      debugPrint(text);
      return response;
    } catch (e) {
      debugPrint(e.toString());
      return response;
    }
  }
}
