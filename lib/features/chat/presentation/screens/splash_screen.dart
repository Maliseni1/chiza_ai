import 'package:flutter/material.dart';
import 'package:chiza_ai/core/services/model_service.dart'; // Ensure this import path matches yours
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ModelService _modelService = ModelService();

  // State variables
  bool _isDownloading = false;
  String _statusMessage = "Checking AI Brain...";
  double _progress = 0.0;
  String _downloadedMB = "0";
  String _totalMB = "0";

  @override
  void initState() {
    super.initState();
    _checkModel();
  }

  Future<void> _checkModel() async {
    bool exists = await _modelService.isModelDownloaded();
    if (exists) {
      _navigateToHome();
    } else {
      setState(() {
        _statusMessage = "AI Model Missing.\nDownload required (~1GB).";
      });
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _statusMessage = "Initializing Download...";
    });

    try {
      await _modelService.downloadModel(
        onProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
              _downloadedMB = (received / 1024 / 1024).toStringAsFixed(1);
              _totalMB = (total / 1024 / 1024).toStringAsFixed(1);
              _statusMessage = "Downloading Brain...";
            });
          }
        },
      );
      // Success!
      _navigateToHome();
    } catch (e) {
      // Check if the widget is still on screen before updating UI
      if (!mounted) return;

      setState(() {
        _isDownloading = false;
        _statusMessage = "Download Failed.\nPlease check your connection.";
        _progress = 0.0;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.psychology, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 20),

              const Text(
                "Chiza AI",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),

              if (_isDownloading) ...[
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 10),
                Text(
                  "${(_progress * 100).toStringAsFixed(0)}%  ($_downloadedMB / $_totalMB MB)",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _startDownload,
                  icon: const Icon(Icons.download),
                  label: const Text("Download AI Model (1 GB)"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
