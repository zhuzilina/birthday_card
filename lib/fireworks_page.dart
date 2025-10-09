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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';

// 条件导入WebView实现
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class FireworksPage extends StatefulWidget {
  const FireworksPage({super.key});

  @override
  State<FireworksPage> createState() => _FireworksPageState();
}

class _FireworksPageState extends State<FireworksPage> {
  WebViewController? _controller;
  double _backButtonOpacity = 1.0;
  Timer? _hideBackButtonTimer;
  final bool _isWindows = Platform.isWindows;
  bool _webViewSupported = true;

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
      setState(() {
        _webViewSupported = false;
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
    if (_isWindows) {
      HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    }
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
                      '烟花效果\n在Windows桌面版暂不可用\n请在移动设备上体验',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        decoration: TextDecoration.none,
                      ),
                    ),
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