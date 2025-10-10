import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:path/path.dart' as path;

class WebService {
  late HttpServer _server;
  final int port;
  final String assetsPath;
  final String baseUrl = 'http://localhost';

  WebService({
    this.port = 8080,
    this.assetsPath = 'assets/web-desktop',
  });

  Future<void> start() async {
    // 创建一个静态文件处理器
    final staticHandler = createStaticHandler(assetsPath, defaultDocument: 'index.html');

    // 创建资源 API 处理器
    final resourceHandler = _createResourceApiHandler();

    // 创建路由处理器
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler((Request request) async {
          // 处理所有 API 请求
          if (request.url.path.startsWith('api/resource')) {
            return await resourceHandler(request);
          }

          // 处理根路径重定向到 index.html
          if (request.url.path.isEmpty || request.url.path == '/') {
            final indexResponse = await staticHandler(Request('GET', Uri.parse('$baseUrl:$port/index.html')));
            return indexResponse;
          }

          // 处理其他静态文件请求
          return await staticHandler(request);
        });

    // 启动服务器
    _server = await shelf_io.serve(handler, 'localhost', port);
    print('✅ Web服务已启动: $baseUrl:$port');
    print('📁 资源目录: $assetsPath');
    print('🔗 API接口: $baseUrl:$port/api/resource/{filename}');
    print('🌐 主页: $baseUrl:$port');
  }

  Handler _createResourceApiHandler() {
    return (Request request) async {
      final url = request.url.path;

      // 解析 API 路径: /api/resource/{filename}
      if (url.startsWith('api/resource/')) {
        final filename = url.substring('api/resource/'.length);
        final filePath = path.join(assetsPath, filename);

        try {
          final file = File(filePath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final contentType = _getContentType(filename);

            return Response.ok(
              bytes,
              headers: {
                'Content-Type': contentType,
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type',
              },
            );
          } else {
            return Response.notFound('文件未找到: $filename');
          }
        } catch (e) {
          return Response.internalServerError(
            body: '服务器错误: ${e.toString()}',
          );
        }
      }

      // 处理目录列表 API
      if (url == 'api/resource') {
        return await _handleDirectoryList();
      }

      return Response.notFound('API 端点未找到');
    };
  }

  Future<Response> _handleDirectoryList() async {
    try {
      final dir = Directory(assetsPath);
      if (!await dir.exists()) {
        return Response.notFound('资源目录不存在');
      }

      final files = <String, dynamic>{};

      // 递归扫描目录
      await _scanDirectory(dir, files, '');

      return Response.ok(
        jsonEncode({
          'status': 'success',
          'data': {
            'directory': assetsPath,
            'files': files,
            'total_count': _countFiles(files),
          },
          'api_base_url': '$baseUrl:$port/api/resource/',
        }),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'status': 'error',
          'message': '扫描目录失败: ${e.toString()}',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<void> _scanDirectory(Directory dir, Map<String, dynamic> files, String relativePath) async {
    await for (final entity in dir.list()) {
      final name = path.basename(entity.path);
      final relativeName = relativePath.isEmpty ? name : path.join(relativePath, name);

      if (entity is File) {
        final fileSize = await entity.length();
        final lastModified = await entity.lastModified();
        files[name] = {
          'type': 'file',
          'size': fileSize,
          'last_modified': lastModified.toIso8601String(),
          'relative_path': relativeName,
          'api_url': '$baseUrl:$port/api/resource/$relativeName',
        };
      } else if (entity is Directory) {
        files[name] = {
          'type': 'directory',
          'relative_path': relativeName,
          'files': <String, dynamic>{},
        };
        await _scanDirectory(entity, files[name]['files'], relativeName);
      }
    }
  }

  int _countFiles(Map<String, dynamic> files) {
    int count = 0;
    for (final entry in files.values) {
      if (entry['type'] == 'file') {
        count++;
      } else if (entry['type'] == 'directory') {
        count += _countFiles(entry['files']);
      }
    }
    return count;
  }

  String _getContentType(String filename) {
    final extension = path.extension(filename).toLowerCase();
    switch (extension) {
      case '.html':
        return 'text/html; charset=utf-8';
      case '.css':
        return 'text/css; charset=utf-8';
      case '.js':
        return 'application/javascript; charset=utf-8';
      case '.json':
        return 'application/json; charset=utf-8';
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.svg':
        return 'image/svg+xml';
      case '.ico':
        return 'image/x-icon';
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      case '.ogg':
        return 'audio/ogg';
      case '.ttf':
        return 'font/ttf';
      case '.otf':
        return 'font/otf';
      case '.woff':
        return 'font/woff';
      case '.woff2':
        return 'font/woff2';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> stop() async {
    await _server.close();
    print('🛑 Web服务已停止');
  }

  String get url => '$baseUrl:$port';

  // 获取资源的 API URL
  String getResourceUrl(String relativePath) {
    return '$baseUrl:$port/api/resource/$relativePath';
  }
}

// 全局服务实例
WebService? _webService;

// 启动 Web 服务
Future<WebService> startWebService({int port = 8080}) async {
  if (_webService != null) {
    print('⚠️  Web服务已经在运行');
    return _webService!;
  }

  _webService = WebService(port: port);
  await _webService!.start();
  return _webService!;
}

// 停止 Web 服务
Future<void> stopWebService() async {
  if (_webService != null) {
    await _webService!.stop();
    _webService = null;
  }
}

// 获取当前运行的 Web 服务
WebService? get currentWebService => _webService;