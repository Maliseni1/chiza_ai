import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chiza_ai/features/chat/presentation/screens/home_screen.dart';
import 'package:chiza_ai/features/chat/providers/chat_provider.dart';

class ModelSetupScreen extends StatefulWidget {
  const ModelSetupScreen({super.key});

  @override
  State<ModelSetupScreen> createState() => _ModelSetupScreenState();
}

class _ModelSetupScreenState extends State<ModelSetupScreen> {
  final ReceivePort _port = ReceivePort();

  bool _isChecking = true;
  bool _isDownloading = false;
  String _status = "Checking for existing brain...";
  String? _taskId;
  Timer? _monitorTimer;

  double _progressValue = 0.0;
  String _progressText = "0%";
  String _sizeText = "";
  String _speedText = "";
  String _etaText = "";

  int _lastBytes = 0;
  int _lastTime = 0;

  final String _modelFileName = "qwen2.5-1.5b-instruct-q4_k_m.gguf";
  static const int _kModelTotalBytes = 1230000000;

  @override
  void initState() {
    super.initState();
    _bindBackgroundIsolate();
    _checkExistingFile();
  }

  @override
  void dispose() {
    _unbindBackgroundIsolate();
    _stopMonitor();
    super.dispose();
  }

  Future<String> _getSaveDir() async {
    if (Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      if (dir != null) {
        return dir.path;
      }
    }
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<void> _checkExistingFile() async {
    try {
      final dirPath = await _getSaveDir();
      final file = File("$dirPath/$_modelFileName");

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

  void _bindBackgroundIsolate() {
    bool isSuccess = IsolateNameServer.registerPortWithName(
      _port.sendPort,
      'downloader_send_port',
    );
    if (!isSuccess) {
      _unbindBackgroundIsolate();
      _bindBackgroundIsolate();
      return;
    }
    _port.listen((dynamic data) {
      String id = data[0];
      DownloadTaskStatus status = data[1];

      if (_taskId == id && mounted) {
        if (status == DownloadTaskStatus.complete) {
          _stopMonitor();
          setState(() {
            _status = "Download Complete!";
            _isDownloading = false;
            _progressValue = 1.0;
          });
          _finalizeSetup();
        } else if (status == DownloadTaskStatus.failed) {
          _stopMonitor();
          setState(() {
            _status = "Download Failed. Retrying...";
            _isDownloading = false;
          });
          _retryDownload();
        } else if (status == DownloadTaskStatus.canceled) {
          _stopMonitor();
          setState(() {
            _isDownloading = false;
          });
        }
      }
    });
    FlutterDownloader.registerCallback(downloadCallback);
  }

  void _unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName(
      'downloader_send_port',
    );
    send?.send([id, DownloadTaskStatus.fromInt(status), progress]);
  }

  Future<void> _startBackgroundDownload() async {
    await Permission.notification.request();

    var storageStatus = await Permission.storage.status;
    if (!storageStatus.isGranted) {
      await Permission.storage.request();
    }
    if (await Permission.storage.isDenied) {
      await Permission.manageExternalStorage.request();
    }

    setState(() {
      _isDownloading = true;
      _status = "Starting...";
      _progressValue = 0.0;
      _lastBytes = 0;
      _lastTime = DateTime.now().millisecondsSinceEpoch;
    });

    try {
      final saveDir = await _getSaveDir();
      final savedDirObj = Directory(saveDir);
      if (!savedDirObj.existsSync()) {
        savedDirObj.createSync(recursive: true);
      }

      if (_taskId != null) {
        await FlutterDownloader.cancel(taskId: _taskId!);
      }

      const url =
          "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf?download=true";

      _taskId = await FlutterDownloader.enqueue(
        url: url,
        headers: {
          "User-Agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        },
        savedDir: saveDir,
        fileName: _modelFileName,
        showNotification: true,
        openFileFromNotification: false,
        saveInPublicStorage: false,
      );

      _startMonitor();
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _status = "Error: $e";
      });
    }
  }

  void _retryDownload() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_isDownloading) {
        _startBackgroundDownload();
      }
    });
  }

  void _startMonitor() {
    _stopMonitor();
    _monitorTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_taskId == null) {
        return;
      }

      final tasks = await FlutterDownloader.loadTasksWithRawQuery(
        query: "SELECT * FROM task WHERE task_id = '$_taskId'",
      );

      if (tasks != null && tasks.isNotEmpty) {
        final task = tasks.first;

        if (task.status == DownloadTaskStatus.running) {
          int total = _kModelTotalBytes;
          int received = (total * (task.progress / 100)).toInt();

          int now = DateTime.now().millisecondsSinceEpoch;
          int timeDiff = now - _lastTime;

          if (timeDiff >= 1000) {
            int bytesDiff = received - _lastBytes;
            if (bytesDiff < 0) {
              bytesDiff = 0;
            }

            double speed = (bytesDiff / 1024) / (timeDiff / 1000);

            int remainingBytes = total - received;
            double etaSeconds = (bytesDiff > 0)
                ? (remainingBytes / bytesDiff) * (timeDiff / 1000)
                : 0;

            if (mounted) {
              setState(() {
                _progressValue = task.progress / 100;
                _progressText = "${task.progress}%";
                _sizeText =
                    "${_formatBytes(received)} / ${_formatBytes(total)}";
                _speedText = _formatSpeed(speed);
                _etaText = _formatDuration(
                  Duration(seconds: etaSeconds.toInt()),
                );
              });
            }

            _lastBytes = received;
            _lastTime = now;
          }
        }
      }
    });
  }

  void _stopMonitor() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

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
      final dirPath = await _getSaveDir();
      final path = "$dirPath/$_modelFileName";

      if (!mounted) {
        return;
      }
      await Provider.of<ChatProvider>(
        context,
        listen: false,
      ).loadModelFromPath(path);

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
                "Setup Chiza AI",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              if (!_isChecking && !_isDownloading)
                const Text(
                  "We need to download the brain (1.2 GB) to your device.\nUse Wi-Fi if possible.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),

              const SizedBox(height: 32),

              if (_isChecking) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_status),
              ] else if (_isDownloading) ...[
                LinearProgressIndicator(
                  value: _progressValue,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _progressText,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _etaText,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_sizeText, style: const TextStyle(color: Colors.grey)),
                    Text(
                      _speedText,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Text(
                  "You can exit the app. Download continues in background.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _startBackgroundDownload,
                  icon: const Icon(Icons.cloud_download),
                  label: const Text("Download Qwen (1.2 GB)"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                if (_status.isNotEmpty && !_status.contains("Starting"))
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Text(
                      _status,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
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
