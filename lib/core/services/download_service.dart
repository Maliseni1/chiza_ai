import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class DownloadService {
  // ✅ FIX: Correct URL with underscores (_) instead of hyphens where needed
  static const String modelUrl =
      "https://huggingface.co/Qwen/Qwen1.5-1.8B-Chat-GGUF/resolve/main/qwen1_5-1_8b-chat-q4_k_m.gguf";

  // ✅ FIX: Match the exact filename
  static const String fileName = "qwen1_5-1_8b-chat-q4_k_m.gguf";
  final Dio _dio = Dio();

  Future<String> downloadModel(Function(int) onProgress) async {
    try {
      // 1. Get the correct folder (App Sandbox)
      // We use getApplicationDocumentsDirectory for iOS/Android internal storage.
      // This DOES NOT require complex permissions on modern Android.
      final Directory dir = await getApplicationDocumentsDirectory();
      final savePath = "${dir.path}/$fileName";

      // 2. Check if file already exists
      if (File(savePath).existsSync()) {
        debugPrint("✅ File already exists at: $savePath");
        return savePath;
      }

      debugPrint("⬇️ Starting Dio Download to: $savePath");

      // 3. Start Download
      await _dio.download(
        modelUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            int percentage = ((received / total) * 100).floor();
            onProgress(percentage);
          }
        },
      );

      debugPrint("✅ Download Complete!");
      return savePath;
    } catch (e) {
      debugPrint("❌ Download Error: $e");
      throw Exception("Download Failed: $e");
    }
  }
}
