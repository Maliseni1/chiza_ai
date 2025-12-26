import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // Needed for debugPrint
import 'package:path_provider/path_provider.dart';

class ModelService {
  static const String _modelUrl =
      "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf?download=true";

  static const String _modelFileName = "qwen2.5-1.5b-instruct-q4_k_m.gguf";

  final Dio _dio = Dio();

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_modelFileName';
  }

  Future<bool> isModelDownloaded() async {
    final path = await _localPath;
    return File(path).exists();
  }

  Future<String> downloadModel({required Function(int, int) onProgress}) async {
    final savePath = await _localPath;

    try {
      debugPrint("⬇️ Starting download from: $_modelUrl"); // Fixed

      await _dio.download(
        _modelUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            if (int.parse(progress) % 10 == 0) {
              debugPrint("📦 Downloading: $progress%"); // Fixed
            }
          }
          onProgress(received, total);
        },
      );

      debugPrint("✅ Download Complete: $savePath"); // Fixed
      return savePath;
    } catch (e) {
      debugPrint("❌ Download Failed: $e"); // Fixed
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }
      throw Exception("Failed to download model: $e");
    }
  }

  Future<String?> getModelPath() async {
    if (await isModelDownloaded()) {
      return await _localPath;
    }
    return null;
  }
}
