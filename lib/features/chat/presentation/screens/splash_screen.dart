import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:chiza_ai/core/services/download_service.dart';
import 'package:chiza_ai/features/chat/presentation/screens/home_screen.dart';
import 'package:chiza_ai/features/chat/presentation/providers/chat_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final DownloadService _downloadService = DownloadService();

  // State variables
  bool _showBranding = true;
  double _progress = 0.0;
  String _status = ""; // Empty initially so it doesn't show during branding
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Start the strict 3-second timer
    _runSplashSequence();
  }

  Future<void> _runSplashSequence() async {
    // 1. WAIT exactly 3 seconds (Branding visible)
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // 2. HIDE Branding
    setState(() {
      _showBranding = false;
      _status = "Checking permissions...";
    });

    // 3. CHECK Permission (Only after branding is gone)
    await _checkPermissionAndStart();
  }

  Future<void> _checkPermissionAndStart() async {
    // On Android 13+, simple file storage often doesn't need explicit runtime
    // permissions if we use the App Sandbox (which we are).
    // However, to satisfy your requirement for a dialog flow:

    if (Platform.isAndroid) {
      // Requesting 'storage' on Android 13+ usually returns denied implicitly.
      // We try it, but if it fails, we assume we can proceed because we
      // updated DownloadService to use the App Sandbox (DocumentsDirectory).
      await Permission.storage.request();
    }

    // Proceed regardless of result because we are using a safe directory now
    _startDownload();
  }

  Future<void> _startDownload() async {
    setState(() {
      _status = "Connecting to Chiza Brain...";
      _hasError = false;
    });

    try {
      final path = await _downloadService.downloadModel((percentage) {
        if (mounted) {
          setState(() {
            _progress = percentage / 100;
            _status = "Downloading Brain... $percentage%";
          });
        }
      });

      if (mounted) {
        setState(() => _status = "Initializing AI...");
        await Provider.of<ChatProvider>(
          context,
          listen: false,
        ).loadModelFromPath(path);
        _navigateToHome();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = "Connection Failed.\nCheck Internet.";
          _hasError = true;
        });
      }
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // CENTER CONTENT
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LOGO - Ensure "assets/icon/" is in pubspec.yaml
                Image.asset("assets/icon/app_logo.png", width: 150),

                const SizedBox(height: 30),

                // Status & Progress (HIDDEN during first 3 seconds)
                if (!_showBranding) ...[
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (!_hasError && _progress < 1.0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 50),
                      child: LinearProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                  if (_hasError)
                    ElevatedButton(
                      onPressed: _startDownload,
                      child: const Text("Retry"),
                    ),
                ],
              ],
            ),
          ),

          // BOTTOM BRANDING (Visible ONLY when _showBranding is true)
          if (_showBranding)
            const Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    "From",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Chiza Labs",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
