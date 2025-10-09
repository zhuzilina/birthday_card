/*
 * Copyright 2025 遇见晴天
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:convert' as convert;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

// 条件导入WebView实现
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FireworksPage extends StatefulWidget {
  const FireworksPage({super.key});

  @override
  State<FireworksPage> createState() => _FireworksPageState();
}

class _FireworksPageState extends State<FireworksPage> {
  WebViewController? _controller;
  double _backButtonOpacity = 1.0;
  Timer? _hideBackButtonTimer;
  final bool _isWindows = !kIsWeb && Platform.isWindows;
  bool _webViewSupported = true;
  HttpServer? _localServer;
  String? _localServerUrl;
  bool _isOpeningBrowser = false;

  @override
  void initState() {
    super.initState();
    _scheduleBackButtonHide();
    if (_isWindows) {
      _setupKeyboardListener();
    }

    // 尝试初始化WebView
    _initializeWebView();
  }

  void _initializeWebView() async {
    try {
      // 根据平台设置WebView实现
      late final PlatformWebViewControllerCreationParams params;
      if (Platform.isAndroid) {
        params = AndroidWebViewControllerCreationParams();
      } else if (Platform.isIOS) {
        params = WebKitWebViewControllerCreationParams();
      } else {
        // Windows和其他平台使用默认实现
        params = const PlatformWebViewControllerCreationParams();
      }

      _controller = WebViewController.fromPlatformCreationParams(params)
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..enableZoom(false)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              // Update loading bar.
            },
            onPageStarted: (String url) {},
            onPageFinished: (String url) {
              // Load audio assets when page is loaded
              _loadAudioAssets();
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('WebView error: $error');
            },
            onNavigationRequest: (NavigationRequest request) {
              // Allow local file requests
              if (request.url.startsWith('file://')) {
                return NavigationDecision.navigate;
              }
              return NavigationDecision.prevent;
            },
          ),
        )
        ..addJavaScriptChannel(
          'AudioLoader',
          onMessageReceived: (JavaScriptMessage message) {
            _handleAudioRequest(message.message);
          },
        )
        ..setUserAgent(_isWindows
            ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            : 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1')
        ..loadFlutterAsset('assets/web/index.html');

      setState(() {
        _webViewSupported = true;
      });
    } catch (e) {
      debugPrint('WebView initialization failed: $e');

      // Windows平台WebView失败时，尝试启动本地服务器
      if (_isWindows) {
        await _startLocalServer();
      }

      setState(() {
        _webViewSupported = false;
      });
    }
  }

  // 启动本地HTTP服务器
  Future<void> _startLocalServer() async {
    try {
      const port = 8080;
      _localServer = await shelf_io.serve(
        _createHandler(),
        'localhost',
        port,
      );

      _localServerUrl = 'http://localhost:$port';
      debugPrint('Local server started at $_localServerUrl');

      // 等待一小段时间确保服务器完全启动
      await Future.delayed(const Duration(milliseconds: 500));

      // 尝试打开浏览器
      await _openInBrowser();
    } catch (e) {
      debugPrint('Failed to start local server: $e');
    }
  }

  // 创建HTTP请求处理器
  Handler _createHandler() {
    // 创建静态文件处理器
    final staticHandler = createStaticHandler('assets/web',
      defaultDocument: 'index.html',
      listDirectories: false,
    );

    // 创建自定义处理器来处理CORS和音频文件
    return (Request request) async {
      // 处理音频文件信息API端点
      if (request.url.path == '/api/audio-files') {
        return _createAudioFilesResponse();
      }

      // 添加CORS头到所有响应
      final response = await staticHandler(request);

      return response.change(
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
          ...response.headers,
        },
      );
    };
  }

  // 创建音频文件列表响应
  Response _createAudioFilesResponse() {
    final audioFiles = [
      'burst1.mp3',
      'burst2.mp3',
      'burst-sm-1.mp3',
      'burst-sm-2.mp3',
      'crackle1.mp3',
      'crackle-sm-1.mp3',
      'lift1.mp3',
      'lift2.mp3',
      'lift3.mp3',
    ];

    final audioData = <String, String>{};
    for (String fileName in audioFiles) {
      audioData[fileName] = '/audio/$fileName';
    }

    return Response.ok(
      convert.jsonEncode(audioData),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  }

  // 在浏览器中打开本地服务器URL
  Future<void> _openInBrowser() async {
    if (_localServerUrl == null || _isOpeningBrowser) return;

    setState(() {
      _isOpeningBrowser = true;
    });

    try {
      final uri = Uri.parse(_localServerUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // 使用外部浏览器
        );
      } else {
        debugPrint('Could not launch $_localServerUrl');
      }
    } catch (e) {
      debugPrint('Error launching browser: $e');
    }
  }

  Future<void> _loadAudioAssets() async {
    try {
      // Load all audio files and send them to WebView
      final audioFiles = [
        'assets/web/audio/burst1.mp3',
        'assets/web/audio/burst2.mp3',
        'assets/web/audio/burst-sm-1.mp3',
        'assets/web/audio/burst-sm-2.mp3',
        'assets/web/audio/crackle1.mp3',
        'assets/web/audio/crackle-sm-1.mp3',
        'assets/web/audio/lift1.mp3',
        'assets/web/audio/lift2.mp3',
        'assets/web/audio/lift3.mp3',
      ];

      // Load audio files as Base64 and send to WebView
      for (String audioPath in audioFiles) {
        try {
          final byteData = await rootBundle.load(audioPath);
          final base64Audio = base64Encode(byteData.buffer.asUint8List());
          final fileName = audioPath.split('/').last;

          // Send audio data to WebView
          if (_controller != null) {
            await _controller!.runJavaScript('''
              window.audioData = window.audioData || {};
              window.audioData['$fileName'] = 'data:audio/mp3;base64,$base64Audio';
              console.log('Audio data loaded for: $fileName');
            ''');
          }
        } catch (e) {
          debugPrint('Failed to load audio file $audioPath: $e');
        }
      }

      debugPrint('Audio assets loaded successfully');
    } catch (e) {
      debugPrint('Failed to load audio assets: $e');
    }
  }

  void _handleAudioRequest(String message) {
    // Handle audio-related requests from JavaScript
    debugPrint('Audio request: $message');
  }

  @override
  void dispose() {
    _hideBackButtonTimer?.cancel();
    if (_isWindows) {
      HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    }

    // 关闭本地服务器
    _localServer?.close();
    _localServer = null;

    super.dispose();
  }

  void _scheduleBackButtonHide() {
    _hideBackButtonTimer?.cancel();
    _hideBackButtonTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _backButtonOpacity = 0.0;
        });
      }
    });
  }

  void _showBackButtonTemporarily() {
    setState(() {
      _backButtonOpacity = 1.0;
    });
    _scheduleBackButtonHide();
  }

  void _setupKeyboardListener() {
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _showBackButtonTemporarily();
        Navigator.pop(context);
        return true;
      }
    }
    return false;
  }


  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // WebView内容或替代方案
          if (_webViewSupported && _controller != null)
            WebViewWidget(controller: _controller!)
          else
            // Windows WebView不支持时的替代方案
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.9),
                    Colors.blue.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.celebration,
                      size: 100,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '烟花效果在桌面版中\n将在浏览器中打开',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    if (_localServerUrl != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              '本地服务器已启动',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _localServerUrl!,
                              style: const TextStyle(
                                color: Colors.cyan,
                                fontSize: 12,
                                decoration: TextDecoration.none,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_localServerUrl != null) ...[
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _isOpeningBrowser ? null : _openInBrowser,
                        icon: _isOpeningBrowser
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.open_in_browser),
                        label: Text(_isOpeningBrowser ? '正在打开浏览器...' : '在浏览器中打开'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.withValues(alpha: 0.8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                    ] else if (_isWindows) ...[
                      const SizedBox(height: 30),
                      Text(
                        '正在启动本地服务器...',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                    if (_isWindows) ...[
                      const SizedBox(height: 30),
                      Text(
                        '按 ESC 键返回',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          // Mouse/Touch detection layer
          if (_webViewSupported)
            Positioned.fill(
              child: GestureDetector(
                onTap: _showBackButtonTemporarily,
                behavior: HitTestBehavior.translucent,
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          // Back button overlay
          Positioned(
            top: _isWindows ? 20 : 50,
            left: _isWindows ? 20 : 20,
            child: AnimatedOpacity(
              opacity: _backButtonOpacity,
              duration: const Duration(milliseconds: 500),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(_isWindows ? 8 : 20),
                  border: _isWindows ? Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1) : null,
                ),
                child: IconButton(
                  icon: Icon(
                    _isWindows ? Icons.close : Icons.arrow_back,
                    color: Colors.white,
                    size: _isWindows ? 20 : 24,
                  ),
                  onPressed: () {
                    _showBackButtonTemporarily();
                    Navigator.pop(context);
                  },
                  tooltip: _isWindows ? '关闭 (ESC)' : '返回',
                ),
              ),
            ),
          ),
          // Windows keyboard hint
          if (_isWindows)
            Positioned(
              bottom: 20,
              right: 20,
              child: AnimatedOpacity(
                opacity: _backButtonOpacity,
                duration: const Duration(milliseconds: 500),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                  ),
                  child: const Text(
                    '按 ESC 键退出',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}