import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';

class FireworksPage extends StatefulWidget {
  const FireworksPage({super.key});

  @override
  State<FireworksPage> createState() => _FireworksPageState();
}

class _FireworksPageState extends State<FireworksPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
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
          onWebResourceError: (WebResourceError error) {},
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
      ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1')
      ..loadFlutterAsset('assets/web/index.html');
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
          await _controller.runJavaScript('''
            window.audioData = window.audioData || {};
            window.audioData['$fileName'] = 'data:audio/mp3;base64,$base64Audio';
            console.log('Audio data loaded for: $fileName');
          ''');
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        color: Colors.black,
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            // Back button overlay
            Positioned(
              top: 40,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}