import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart' show rootBundle;

class WebService {
  late HttpServer _server;
  final int port;
  final String assetsPath;
  final String baseUrl = 'http://localhost';
  late String _resolvedAssetsPath;
  Directory? _tempAssetsDir;

  WebService({
    this.port = 8080,
    this.assetsPath = 'assets/web-desktop',
  });

  /// 解析资源路径，确保在各种环境中都能正确找到资源文件
  Future<String> _resolveAssetsPath() async {
    print('🔍 开始解析资源路径: $assetsPath');

    // 1. 检查原始路径是否直接存在（开发环境）
    if (await Directory(assetsPath).exists()) {
      print('✅ 使用原始路径: $assetsPath');
      return assetsPath;
    }

    // 2. 检查当前工作目录下的相对路径
    final currentDir = Directory.current.path;
    final relativePath = path.join(currentDir, assetsPath);
    if (await Directory(relativePath).exists()) {
      print('✅ 使用相对路径: $relativePath');
      return relativePath;
    }

    // 3. 检查 Flutter Release 模式下的资源路径
    final releasePath1 = path.join(currentDir, 'data', 'flutter_assets', assetsPath);
    if (await Directory(releasePath1).exists()) {
      print('✅ 使用 Release 路径 1: $releasePath1');
      return releasePath1;
    }

    // 4. 检查另一种可能的 Release 路径结构
    final releasePath2 = path.join(currentDir, 'data', 'flutter_assets', 'assets', path.basename(assetsPath));
    if (await Directory(releasePath2).exists()) {
      print('✅ 使用 Release 路径 2: $releasePath2');
      return releasePath2;
    }

    // 5. 检查可执行文件目录下的资源路径
    final executablePath = path.dirname(Platform.resolvedExecutable);
    final executableAssetsPath = path.join(executablePath, 'data', 'flutter_assets', assetsPath);
    if (await Directory(executableAssetsPath).exists()) {
      print('✅ 使用可执行文件路径: $executableAssetsPath');
      return executableAssetsPath;
    }

    // 6. 检查用户文档目录（适用于安装包）
    try {
      final homeDir = Platform.environment['USERPROFILE'] ??
                      Platform.environment['HOME'] ??
                      currentDir;
      final appDataPath = path.join(homeDir, 'AppData', 'Local', 'birthday_card');
      final appDataAssetsPath = path.join(appDataPath, 'data', 'flutter_assets', assetsPath);
      if (await Directory(appDataAssetsPath).exists()) {
        print('✅ 使用用户数据路径: $appDataAssetsPath');
        return appDataAssetsPath;
      }
    } catch (e) {
      print('⚠️ 检查用户数据路径失败: $e');
    }

    // 7. 尝试使用 rootBundle（Flutter 资源管理）
    try {
      print('🔍 尝试使用 Flutter rootBundle...');
      final testAsset = await rootBundle.load('assets/${path.basename(assetsPath)}/index.html');
      if (testAsset.lengthInBytes > 0) {
        print('✅ 使用 Flutter rootBundle，创建临时资源目录');
        return await _createTempAssetsDirectory();
      }
    } catch (e) {
      print('⚠️ Flutter rootBundle 访问失败: $e');
    }

    // 如果所有路径都失败，返回原始路径并打印警告
    print('❌ 无法找到资源目录，将使用默认路径: $assetsPath');
    print('📊 调试信息:');
    print('   - 当前目录: $currentDir');
    print('   - 可执行文件: ${Platform.resolvedExecutable}');
    print('   - 平台: ${Platform.operatingSystem}');

    return assetsPath;
  }

  /// 创建临时资源目录并从 Flutter 资源中复制文件
  Future<String> _createTempAssetsDirectory() async {
    _tempAssetsDir = Directory.systemTemp.createTempSync('birthday_card_assets_');
    print('📁 创建临时目录: ${_tempAssetsDir!.path}');

    try {
      // 需要复制的文件和目录列表
      final assetFiles = [
        'index.html',
        'js/',
        'css/',
        'fonts/',
        'images/',
        'audio/'
      ];

      for (final assetFile in assetFiles) {
        if (assetFile.endsWith('/')) {
          // 处理目录
          await _copyAssetDirectory(assetFile, _tempAssetsDir!);
        } else {
          // 处理单个文件
          await _copyAssetFile(assetFile, _tempAssetsDir!);
        }
      }

      print('✅ 临时资源目录创建完成');
      return _tempAssetsDir!.path;
    } catch (e) {
      print('❌ 创建临时资源目录失败: $e');
      _tempAssetsDir?.deleteSync(recursive: true);
      _tempAssetsDir = null;
      rethrow;
    }
  }

  /// 复制单个资源文件
  Future<void> _copyAssetFile(String assetFile, Directory targetDir) async {
    try {
      final assetKey = 'assets/${path.basename(assetsPath)}/$assetFile';
      final data = await rootBundle.load(assetKey);
      final file = File(path.join(targetDir.path, assetFile));
      await file.writeAsBytes(data.buffer.asUint8List());
      print('📄 复制文件: $assetFile');
    } catch (e) {
      print('⚠️ 复制文件失败 $assetFile: $e');
    }
  }

  /// 复制资源目录
  Future<void> _copyAssetDirectory(String dirName, Directory targetDir) async {
    try {
      final assetDir = Directory(path.join(targetDir.path, dirName));
      assetDir.createSync();

      // 这里我们需要知道具体的文件列表，因为 rootBundle 无法列出目录内容
      // 可以预先定义文件列表或者使用清单文件
      final knownFiles = _getKnownFilesForDirectory(dirName);

      for (final fileName in knownFiles) {
        await _copyAssetFile(path.join(dirName, fileName), targetDir);
      }

      print('📁 复制目录: $dirName');
    } catch (e) {
      print('⚠️ 复制目录失败 $dirName: $e');
    }
  }

  /// 获取已知目录中的文件列表
  List<String> _getKnownFilesForDirectory(String dirName) {
    switch (dirName) {
      case 'js/':
        return ['script.js', 'Stage.js', 'MyMath.js', 'fscreen.js', 'desktop-fix.js'];
      case 'css/':
        return ['style.css'];
      case 'fonts/':
        return ['华文琥珀.ttf', 'css.css'];
      case 'images/':
        return ['favicon.png'];
      case 'audio/':
        return ['burst1.mp3', 'burst2.mp3', 'burst-sm-1.mp3', 'burst-sm-2.mp3',
                'crackle1.mp3', 'crackle-sm-1.mp3', 'lift1.mp3', 'lift2.mp3', 'lift3.mp3'];
      default:
        return [];
    }
  }

  Future<void> start() async {
    // 解析实际的资源路径
    _resolvedAssetsPath = await _resolveAssetsPath();

    // 验证资源目录是否存在
    if (!await Directory(_resolvedAssetsPath).exists()) {
      throw Exception('资源目录不存在: $_resolvedAssetsPath');
    }

    // 创建一个静态文件处理器
    final staticHandler = createStaticHandler(_resolvedAssetsPath, defaultDocument: 'index.html');

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
    print('📁 资源目录: $_resolvedAssetsPath');
    print('🔗 API接口: $baseUrl:$port/api/resource/{filename}');
    print('🌐 主页: $baseUrl:$port');
  }

  Handler _createResourceApiHandler() {
    return (Request request) async {
      final url = request.url.path;

      // 解析 API 路径: /api/resource/{filename}
      if (url.startsWith('api/resource/')) {
        final filename = url.substring('api/resource/'.length);
        final filePath = path.join(_resolvedAssetsPath, filename);

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
      final dir = Directory(_resolvedAssetsPath);
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
            'directory': _resolvedAssetsPath,
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

    // 清理临时资源目录
    if (_tempAssetsDir != null) {
      try {
        if (_tempAssetsDir!.existsSync()) {
          _tempAssetsDir!.deleteSync(recursive: true);
          print('🧹 已清理临时资源目录');
        }
      } catch (e) {
        print('⚠️ 清理临时目录失败: $e');
      } finally {
        _tempAssetsDir = null;
      }
    }

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