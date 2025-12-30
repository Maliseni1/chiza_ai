import 'dart:io';
import 'package:dio/dio.dart';

class DownloadService {
  // 1. Configure Dio with longer timeouts for large model downloads
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 60), // Wait up to 60s to connect
      receiveTimeout: const Duration(
        minutes: 60,
      ), // Allow up to 1 hour for the download
    ),
  );

  /// Downloads a file from [url] to [savePath] and reports progress.
  Future<void> downloadModel({
    required String url,
    required String savePath,
    Function(int received, int total)? onProgress,
  }) async {
    try {
      // 2. Ensure the directory exists (Kept from your old code - good practice)
      final file = File(savePath);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }

      // 3. Start Download
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received, total);
          }
        },
        // 4. Critical: Auto-delete partial file if download fails
        deleteOnError: true,
      );
    } catch (e) {
      throw Exception("Download failed: $e");
    }
  }
}
