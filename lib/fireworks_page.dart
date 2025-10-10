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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'web_service.dart';

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
  final bool _isLinux = !kIsWeb && Platform.isLinux;
  bool _webViewSupported = true;
  WebService? _webService;
  bool _isOpeningBrowser = false;

  @override
  void initState() {
    super.initState();
    _scheduleBackButtonHide();
    if (_isWindows || _isLinux) {
      _setupKeyboardListener();
    }

    // Linux和Windows平台直接启动Web服务
    if (_isLinux || _isWindows) {
      _startWebService();
      setState(() {
        _webViewSupported = false;
      });
    } else {
      // 其他平台尝试初始化WebView
      _initializeWebView();
    }
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

      // Windows或Linux平台WebView失败时，尝试启动Web服务
      if (_isWindows || _isLinux) {
        await _startWebService();
      }

      setState(() {
        _webViewSupported = false;
      });
    }
  }

  // 启动Web服务
  Future<void> _startWebService() async {
    try {
      const port = 8080;
      final assetsPath = _isWindows || _isLinux ? 'assets/web-desktop' : 'assets/web';

      _webService = WebService(port: port, assetsPath: assetsPath);
      await _webService!.start();

      debugPrint('Web服务已启动: ${_webService!.url}');

      // 等待一小段时间确保服务器完全启动
      await Future.delayed(const Duration(milliseconds: 1000));

      // 尝试打开浏览器
      await _openInBrowser();
    } catch (e) {
      debugPrint('Failed to start web service: $e');
      _showErrorDialog('Web服务启动失败', '错误信息: $e');
    }
  }

  // 显示错误对话框
  void _showErrorDialog(String title, String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startWebService(); // 重试启动
                },
                child: const Text('重试'),
              ),
            ],
          );
        },
      );
    }
  }

  // 在浏览器中打开Web服务URL
  Future<void> _openInBrowser() async {
    if (_webService == null || _isOpeningBrowser) return;

    setState(() {
      _isOpeningBrowser = true;
    });

    try {
      // 添加桌面模式和全屏参数到 URL
      final uri = Uri.parse('${_webService!.url}?desktop=true&fullscreen=true');
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // 使用外部浏览器
        );
      } else {
        debugPrint('Could not launch ${_webService!.url}');
      }
    } catch (e) {
      debugPrint('Error launching browser: $e');
    } finally {
      setState(() {
        _isOpeningBrowser = false;
      });
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
    if (_isWindows || _isLinux) {
      HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    }

    // 关闭Web服务
    _webService?.stop();
    _webService = null;

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
              decoration: const BoxDecoration(
                color: Color(0xFF0a1033),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 80,
                      color: Colors.purple.withValues(alpha: 0.9),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '✨ 烟花秀 ✨',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '桌面版烟花效果将在浏览器中呈现',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 16,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    if (_webService != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: Colors.green.withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Web服务已启动',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Column(
                              children: [
                                Text(
                                  _webService!.url,
                                  style: const TextStyle(
                                    color: Colors.cyan,
                                    fontSize: 12,
                                    decoration: TextDecoration.none,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // 点击查看按钮
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.cyan.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: _isOpeningBrowser ? null : _openInBrowser,
                                    icon: _isOpeningBrowser
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.visibility, size: 16),
                                    label: Text(
                                      _isOpeningBrowser ? '正在打开...' : '点击查看',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.cyan.withValues(alpha: 0.8),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      elevation: 0,
                                      minimumSize: const Size(100, 32),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_webService != null) ...[
                      const SizedBox(height: 30),
                      // 点击查看烟花按钮
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withValues(alpha: 0.3),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _isOpeningBrowser ? null : _openInBrowser,
                          icon: _isOpeningBrowser
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome, size: 22),
                          label: Text(
                            _isOpeningBrowser ? '正在打开...' : '点击查看烟花',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.withValues(alpha: 0.8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 重新打开按钮
                      TextButton.icon(
                        onPressed: _isOpeningBrowser ? null : () {
                          _openInBrowser();
                        },
                        icon: _isOpeningBrowser
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Colors.cyan,
                                ),
                              )
                            : const Icon(Icons.refresh, size: 16),
                        label: Text(
                          _isOpeningBrowser ? '正在打开...' : '重新打开',
                          style: TextStyle(
                            color: Colors.cyan.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ] else if (_isWindows || _isLinux) ...[
                      const SizedBox(height: 30),
                      Text(
                        '正在启动Web服务...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '浏览器将自动打开',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                    if (_isWindows || _isLinux) ...[
                      const SizedBox(height: 30),
                      Text(
                        '按 ESC 键返回',
                        style: const TextStyle(
                          color: Colors.white,
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
            top: (_isWindows || _isLinux) ? 20 : 50,
            left: (_isWindows || _isLinux) ? 20 : 20,
            child: AnimatedOpacity(
              opacity: _backButtonOpacity,
              duration: const Duration(milliseconds: 500),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular((_isWindows || _isLinux) ? 8 : 20),
                  border: (_isWindows || _isLinux) ? Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1) : null,
                ),
                child: IconButton(
                  icon: Icon(
                    (_isWindows || _isLinux) ? Icons.close : Icons.arrow_back,
                    color: Colors.white,
                    size: (_isWindows || _isLinux) ? 20 : 24,
                  ),
                  onPressed: () {
                    _showBackButtonTemporarily();
                    Navigator.pop(context);
                  },
                  tooltip: (_isWindows || _isLinux) ? '关闭 (ESC)' : '返回',
                ),
              ),
            ),
          ),
          // Windows/Linux keyboard hint
          if (_isWindows || _isLinux)
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