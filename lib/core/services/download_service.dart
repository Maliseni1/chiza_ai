import 'dart:io';
import 'package:dio/dio.dart';

class DownloadService {
  final Dio _dio = Dio();

  /// Downloads a file from [url] to [savePath] and reports progress.
  Future<void> downloadModel({
    required String url,
    required String savePath,
    Function(int received, int total)? onProgress,
  }) async {
    try {
      // Ensure the directory exists
      final file = File(savePath);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }

      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received, total);
          }
        },
      );
    } catch (e) {
      throw Exception("Download failed: $e");
    }
  }
}
