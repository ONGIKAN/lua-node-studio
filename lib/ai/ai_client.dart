import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ai_config.dart';

class AiMessage {
  const AiMessage(this.role, this.content);

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class AiException implements Exception {
  AiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// 网络层抽象，测试时注入假实现即可，界面不依赖真实网络。
abstract class AiTransport {
  Future<String> complete(
    AiConfig config,
    List<AiMessage> messages, {
    Duration timeout = const Duration(seconds: 90),
  });
}

class HttpAiTransport implements AiTransport {
  const HttpAiTransport();

  @override
  Future<String> complete(
    AiConfig config,
    List<AiMessage> messages, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final uri = Uri.tryParse(config.endpoint);
    if (uri == null || !uri.hasScheme) {
      throw AiException('API 地址不合法：${config.baseUrl}');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.postUrl(uri).timeout(timeout);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      final key = config.apiKey.trim();
      if (key.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
      }
      request.add(utf8.encode(jsonEncode({
        'model': config.model.trim(),
        'messages': messages.map((m) => m.toJson()).toList(),
        'temperature': 0.2,
        'stream': false,
      })));
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw AiException(
          'API 返回 ${response.statusCode}：${_shorten(body)}',
          statusCode: response.statusCode,
        );
      }
      final decoded = jsonDecode(body);
      String? content;
      if (decoded is Map<String, dynamic>) {
        final choices = decoded['choices'];
        if (choices is List && choices.isNotEmpty) {
          final first = choices.first;
          if (first is Map) {
            final message = first['message'];
            if (message is Map) {
              final c = message['content'];
              if (c is String) content = c;
            }
          }
        }
      }
      if (content == null || content.trim().isEmpty) {
        throw AiException('API 返回内容为空：${_shorten(body)}');
      }
      return content;
    } on AiException {
      rethrow;
    } on TimeoutException {
      throw AiException('请求超时，请检查网络或 API 地址');
    } on SocketException catch (e) {
      throw AiException('网络连接失败：${e.message}');
    } catch (e) {
      throw AiException('请求失败：$e');
    } finally {
      client.close(force: true);
    }
  }

  static String _shorten(String s) =>
      s.length <= 400 ? s : '${s.substring(0, 400)}…';
}

class AiClient {
  AiClient({AiTransport? transport})
      : transport = transport ?? const HttpAiTransport();

  final AiTransport transport;

  Future<String> chat(
    AiConfig config,
    List<AiMessage> messages, {
    Duration timeout = const Duration(seconds: 90),
  }) =>
      transport.complete(config, messages, timeout: timeout);
}
