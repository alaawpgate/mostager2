import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_endpoints.dart';
import 'storage_service.dart';

class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;
  final int statusCode;

  ApiResponse({
    required this.success,
    this.message,
    this.data,
    required this.statusCode,
  });
}

class ApiService {
  static String get baseUrl {
    return StorageService.getCustomBaseUrl() ?? ApiEndpoints.defaultBaseUrl;
  }

  static Map<String, String> _buildHeaders({bool isMultipart = false}) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (!isMultipart) {
      headers['Content-Type'] = 'application/json';
    }
    final token = StorageService.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // GET Request
  static Future<ApiResponse<dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _buildHeaders()).timeout(timeout);
      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // POST Request
  static Future<ApiResponse<dynamic>> post(
    String endpoint, {
    dynamic body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .post(
            uri,
            headers: _buildHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);
      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // PUT Request
  static Future<ApiResponse<dynamic>> put(
    String endpoint, {
    dynamic body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .put(
            uri,
            headers: _buildHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);
      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // DELETE Request
  static Future<ApiResponse<dynamic>> delete(
    String endpoint, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http.delete(uri, headers: _buildHeaders()).timeout(timeout);
      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  static ApiResponse<dynamic> _handleResponse(http.Response response) {
    dynamic decodedData;
    String? message;
    bool success = response.statusCode >= 200 && response.statusCode < 300;

    try {
      if (response.body.isNotEmpty) {
        decodedData = jsonDecode(utf8.decode(response.bodyBytes));
        if (decodedData is Map<String, dynamic>) {
          if (decodedData.containsKey('success')) {
            success = decodedData['success'] == true;
          }
          if (decodedData.containsKey('message')) {
            message = decodedData['message']?.toString();
          } else if (decodedData.containsKey('error')) {
            message = decodedData['error']?.toString();
          }
        }
      }
    } catch (_) {
      decodedData = response.body;
    }

    return ApiResponse(
      success: success,
      message: message ?? (success ? 'تمت العملية بنجاح' : 'حدث خطأ في الاستجابة'),
      data: decodedData,
      statusCode: response.statusCode,
    );
  }

  static ApiResponse<dynamic> _handleError(dynamic error) {
    String msg = 'حدث خطأ غير متوقع';
    if (error is SocketException) {
      msg = 'تعذر الاتصال بالخادم. يرجى التأكد من تشغيل النظام أو اتصال الشبكة.';
    } else if (error is TimeoutException) {
      msg = 'استغرقت الاستجابة وقتاً أطول من المتوقع، حاول مجدداً.';
    } else {
      msg = error.toString();
    }
    return ApiResponse(
      success: false,
      message: msg,
      data: null,
      statusCode: 0,
    );
  }
}
