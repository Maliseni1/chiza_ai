import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:chiza_ai/features/chat/presentation/screens/home_screen.dart';
import 'package:chiza_ai/core/services/download_service.dart';
import 'package:chiza_ai/features/chat/providers/chat_provider.dart';

class ModelSetupScreen extends StatefulWidget {
  const ModelSetupScreen({super.key});

  @override
  State<ModelSetupScreen> createState() => _ModelSetupScreenState();
}

class _ModelSetupScreenState extends State<ModelSetupScreen> {
  final DownloadService _downloadService = DownloadService();
  bool _isDownloading = false;
  double _progress = 0.0;
  String _status = "";

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _status = "Starting download...";
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = "${dir.path}/qwen2.5-1.5b-instruct-q4_k_m.gguf";

      // FIX 1: Use 'const' for the URL string
      const url =
          "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf";

      await _downloadService.downloadModel(
        url: url,
        savePath: savePath,
        onProgress: (received, total) {
          setState(() {
            _progress = received / total;
            _status =
                "Downloading: ${(received / 1024 / 1024).toStringAsFixed(1)} MB / ${(total / 1024 / 1024).toStringAsFixed(1)} MB";
          });
        },
      );

      // FIX 2: Check mounted before using context after async download
      if (!mounted) return;

      setState(() => _status = "Initializing Brain...");

      // Load the model
      await Provider.of<ChatProvider>(
        context,
        listen: false,
      ).loadModelFromPath(savePath);

      // Check mounted AGAIN before navigating
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _status = "Error: $e";
        });
      }
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
              const Icon(Icons.psychology, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 24),
              const Text(
                "Load Qwen AI",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "We need to download the brain (1.5GB) to your device.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),

              if (_isDownloading) ...[
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                ),
                const SizedBox(height: 16),
                Text(_status, textAlign: TextAlign.center),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _startDownload,
                  icon: const Icon(Icons.cloud_download),
                  label: const Text("Download Qwen (Direct)"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                if (_status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Text(
                      _status,
                      style: const TextStyle(color: Colors.red),
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
