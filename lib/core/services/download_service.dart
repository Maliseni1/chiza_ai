import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class DownloadService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(minutes: 60),
    ),
  );

  /// Downloads to a .temp file and renames to [savePath] only when complete.
  Future<void> downloadModel({
    required String url,
    required String savePath,
    required Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    // 1. We download to "filename.gguf.temp" first
    final tempPath = "$savePath.temp";
    final tempFile = File(tempPath);

    // If the final file already exists, we assume it's done (caller should have checked)
    if (await File(savePath).exists()) {
      return;
    }

    try {
      int downloadedBytes = 0;

      // 2. Check if we have a partial .temp file to resume
      if (await tempFile.exists()) {
        downloadedBytes = await tempFile.length();
        debugPrint("Resuming download from: $downloadedBytes bytes");
      } else {
        await tempFile.parent.create(recursive: true);
      }

      // 3. Request only the missing bytes
      final options = Options(
        headers: {'Range': 'bytes=$downloadedBytes-'},
        responseType: ResponseType.stream,
        validateStatus: (status) =>
            status != null && (status == 200 || status == 206),
      );

      final response = await _dio.get(
        url,
        options: options,
        cancelToken: cancelToken,
      );

      // Calculate total size
      int totalBytes = -1;
      final contentRange = response.headers.value('content-range');
      if (contentRange != null) {
        final parts = contentRange.split('/');
        if (parts.length == 2) totalBytes = int.tryParse(parts[1]) ?? -1;
      }
      if (totalBytes == -1) {
        totalBytes =
            (int.tryParse(response.headers.value('content-length') ?? '') ??
                0) +
            downloadedBytes;
      }

      // 4. Append data to the .temp file
      final sink = tempFile.openWrite(mode: FileMode.append);
      await response.data.stream
          .listen(
            (List<int> chunk) {
              sink.add(chunk);
              downloadedBytes += chunk.length;
              onProgress(downloadedBytes, totalBytes);
            },
            onDone: () async {
              await sink.flush();
              await sink.close();
            },
            onError: (e) async {
              await sink.flush();
              await sink.close();
              throw e;
            },
            cancelOnError: true,
          )
          .asFuture();

      // 5. SUCCESS: Rename .temp -> .gguf
      // This is the atomic switch. The app will only see the file now.
      await tempFile.rename(savePath);
      debugPrint("Download Complete. Renamed to: $savePath");
    } catch (e) {
      debugPrint("Download interrupted: $e");
      // Do not delete the temp file; let the user resume later.
      rethrow;
    }
  }
}
