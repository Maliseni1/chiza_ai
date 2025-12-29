import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:chiza_ai/features/chat/providers/chat_provider.dart';
import 'package:chiza_ai/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:chiza_ai/core/services/download_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final DownloadService _downloader = DownloadService();

  bool _isReady = false;
  bool _isLoading = false;
  String _statusMessage = "Select Qwen Model";
  double _progress = 0.0;

  // DIRECT LINK for Qwen 2.5 1.5B (GGUF) - No Sign-in required
  final String _qwenUrl =
      "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf";

  @override
  void initState() {
    super.initState();
    _checkModelLoaded();
  }

  void _checkModelLoaded() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (chatProvider.isModelLoaded) {
      setState(() => _isReady = true);
    }
  }

  Future<void> _downloadQwen() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Downloading Qwen (Wait for it...)...";
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = "${dir.path}/qwen2.5-1.5b-instruct-q4_k_m.gguf";

      // If file exists, skip download
      if (await File(savePath).exists()) {
        _loadModel(savePath);
        return;
      }

      await _downloader.downloadModel(
        url: _qwenUrl,
        savePath: savePath,
        onProgress: (received, total) {
          setState(() {
            _progress = received / total;
            _statusMessage =
                "Downloading: ${(received / 1024 / 1024).toStringAsFixed(1)} MB / ${(total / 1024 / 1024).toStringAsFixed(1)} MB";
          });
        },
      );

      _loadModel(savePath);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "Download Failed: $e";
      });
    }
  }

  Future<void> _pickModelFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        _loadModel(result.files.single.path!);
      }
    } catch (e) {
      setState(() => _statusMessage = "Error: $e");
    }
  }

  Future<void> _loadModel(String path) async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Initializing Qwen Brain...";
    });

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    await chatProvider.loadModelFromPath(path);

    setState(() {
      _isLoading = false;
      _isReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.psychology,
                  size: 80,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 24),
                const Text(
                  "Load Qwen AI",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  "We need the Qwen 2.5 (1.5B) GGUF model file.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                if (_isLoading) ...[
                  LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                  ),
                  const SizedBox(height: 16),
                  Text(_statusMessage, textAlign: TextAlign.center),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: _downloadQwen,
                    icon: const Icon(Icons.cloud_download),
                    label: const Text("Download Qwen (Direct)"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _pickModelFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text("I already have the file"),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chiza (Qwen)"),
        backgroundColor: Colors.deepPurple[100],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: chatProvider.messages.length,
              itemBuilder: (context, index) {
                return ChatBubble(message: chatProvider.messages[index]);
              },
            ),
          ),
          if (chatProvider.isTyping)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                "Qwen is thinking...",
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Ask Qwen...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: chatProvider.isTyping
                      ? null
                      : () {
                          if (_controller.text.isNotEmpty) {
                            chatProvider.sendMessage(_controller.text);
                            _controller.clear();
                          }
                        },
                  icon: const Icon(Icons.send),
                  color: Colors.deepPurple,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
