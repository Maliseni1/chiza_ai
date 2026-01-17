import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:chiza_ai/features/chat/presentation/screens/home_screen.dart';
import 'package:chiza_ai/features/chat/providers/chat_provider.dart';

class ModelSetupScreen extends StatefulWidget {
  const ModelSetupScreen({super.key});

  @override
  State<ModelSetupScreen> createState() => _ModelSetupScreenState();
}

class _ModelSetupScreenState extends State<ModelSetupScreen> {
  // Logic Variables
  bool _isChecking = true;
  bool _isDownloading = false;
  String _status = "Checking for existing brain...";
  
  // Display Variables
  double _progressValue = 0.0;
  String _progressText = "0%";
  String _sizeText = "";
  String _speedText = "";
  String _etaText = "";

  // Download Control
  HttpClientResponse? _response;
  IOSink? _sink;
  bool _cancelDownload = false;

  final String _modelFileName = "qwen2.5-1.5b-instruct-q4_k_m.gguf";
  // Fallback size if header is missing (1.23 GB)
  static const int _kFallbackSize = 1230000000;

  @override
  void initState() {
    super.initState();
    _checkExistingFile();
  }

  @override
  void dispose() {
    _cancelDownload = true;
    _sink?.close(); 
    super.dispose();
  }

  // Use Internal App Sandbox (100% Safe, No Permissions Needed)
  Future<String> _getSafeDir() async {
    final dir = await getApplicationSupportDirectory();
    return dir.path;
  }

  Future<void> _checkExistingFile() async {
    try {
      final dirPath = await _getSafeDir();
      final file = File("$dirPath/$_modelFileName");

      // Check if exists and is big enough
      if (await file.exists() && await file.length() > 100000000) {
        setState(() {
          _isChecking = false;
          _status = "Brain found! Initializing...";
        });
        _finalizeSetup();
      } else {
        if (mounted) {
          setState(() { 
            _isChecking = false; 
            _status = ""; 
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { 
          _isChecking = false; 
          _status = ""; 
        });
      }
    }
  }

  // --- THE UNORTHODOX DOWNLOADER ---
  Future<void> _startForegroundDownload() async {
    setState(() {
      _isDownloading = true;
      _cancelDownload = false;
      _status = "Connecting to Neural Network...";
      _progressValue = 0.0;
    });

    try {
      final dirPath = await _getSafeDir();
      final file = File("$dirPath/$_modelFileName");
      
      // 1. Create the Client
      final client = HttpClient();
      // Bypass SSL errors if any (common 'hack' for stability)
      client.badCertificateCallback = (cert, host, port) => true;

      // 2. Open Connection
      final request = await client.getUrl(Uri.parse(
        "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf?download=true"
      ));
      
      // Close the request to get the response stream
      _response = await request.close();

      if (_response!.statusCode != 200) {
        throw Exception("Server Error: ${_response!.statusCode}");
      }

      // 3. Setup File Writing
      _sink = file.openWrite();
      
      // 4. Setup Progress Tracking
      int totalBytes = _response!.contentLength;
      if (totalBytes == -1) {
        totalBytes = _kFallbackSize;
      }
      
      int receivedBytes = 0;
      int lastBytes = 0;
      int lastTime = DateTime.now().millisecondsSinceEpoch;
      
      // 5. Listen to the Stream (The Loop)
      await for (var chunk in _response!) {
        if (_cancelDownload) {
          await _sink?.close();
          await file.delete(); // Delete partial file
          return;
        }

        // Write chunk
        _sink?.add(chunk);
        receivedBytes += chunk.length;

        // UI Updates (Throttled to every 500ms to save resources)
        int now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastTime > 500 || receivedBytes == totalBytes) {
          double progress = receivedBytes / totalBytes;
          
          // Speed calc
          int bytesDiff = receivedBytes - lastBytes;
          int timeDiff = now - lastTime;
          double speed = (bytesDiff / 1024) / (timeDiff / 1000); // KB/s
          
          // ETA calc
          int remaining = totalBytes - receivedBytes;
          double eta = (bytesDiff > 0) ? (remaining / bytesDiff) * (timeDiff/1000) : 0;

          if (mounted) {
            setState(() {
              _progressValue = progress;
              _progressText = "${(progress * 100).toStringAsFixed(1)}%";
              _sizeText = "${_formatBytes(receivedBytes)} / ${_formatBytes(totalBytes)}";
              _speedText = _formatSpeed(speed);
              _etaText = _formatDuration(Duration(seconds: eta.toInt()));
            });
          }

          lastBytes = receivedBytes;
          lastTime = now;
        }
      }

      // 6. Done
      await _sink?.flush();
      await _sink?.close();
      
      if (mounted) {
        setState(() {
            _status = "Verifying...";
            _progressValue = 1.0;
        });
        _finalizeSetup();
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _status = "Download Failed: $e";
        });
      }
    }
  }

  // --- Formatters ---
  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return "0 B";
    }
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes <= 0) ? 0 : (bytes.toString().length - 1) ~/ 3; 
    if (i > 4) {
      i = 4;
    }
    double value = bytes / (1 << (10 * i));
    return "${value.toStringAsFixed(1)} ${suffixes[i]}";
  }

  String _formatSpeed(double kbps) {
    if (kbps > 1024) {
      return "${(kbps / 1024).toStringAsFixed(1)} MB/s";
    }
    return "${kbps.toStringAsFixed(0)} KB/s";
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return "${d.inHours}h ${d.inMinutes.remainder(60)}m";
    }
    if (d.inMinutes > 0) {
      return "${d.inMinutes}m ${d.inSeconds.remainder(60)}s";
    }
    return "${d.inSeconds}s";
  }

  Future<void> _finalizeSetup() async {
    setState(() => _status = "Initializing Brain...");
    try {
      final dirPath = await _getSafeDir();
      final path = "$dirPath/$_modelFileName";

      if (!mounted) {
        return;
      }
      await Provider.of<ChatProvider>(context, listen: false).loadModelFromPath(path);

      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _status = "Initialization Failed: $e");
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
              
              if (!_isChecking && !_isDownloading)
                const Text(
                  "Downloading brain directly (1.2 GB).\nPlease keep the app OPEN.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                
              const SizedBox(height: 32),

              if (_isChecking) ...[
                 const CircularProgressIndicator(),
                 const SizedBox(height: 16),
                 Text(_status),
              ]
              else if (_isDownloading) ...[
                // PROGRESS UI
                LinearProgressIndicator(value: _progressValue, minHeight: 10, borderRadius: BorderRadius.circular(5)),
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_progressText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(_etaText, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_sizeText, style: const TextStyle(color: Colors.grey)),
                    Text(_speedText, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
                
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    // FIXED: Use withValues instead of withOpacity
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    // FIXED: Use withValues instead of withOpacity
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3))
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Do not close or switch apps.\nThe download will fail if you leave.",
                          style: TextStyle(fontSize: 12, color: Colors.deepOrange),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _startForegroundDownload,
                  icon: const Icon(Icons.flash_on),
                  label: const Text("Start Direct Download"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
                if (_status.isNotEmpty && !_status.contains("Starting"))
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Text(_status, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}