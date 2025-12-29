import 'dart:io';
import 'package:dio/dio.dart'; // We use Dio for better download handling
import 'package:flutter/foundation.dart';
import 'package:chiza_ai/core/model_constants.dart';

class DownloadProvider extends ChangeNotifier {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusMessage = "";
  final Dio _dio = Dio();
  CancelToken? _cancelToken;

  bool get isDownloading => _isDownloading;
  double get progress => _progress;
  String get statusMessage => _statusMessage;

  Future<void> downloadModel(String destinationPath) async {
    if (_isDownloading) return;

    // 1. check if file already exists manually to avoid re-download
    if (File(destinationPath).existsSync()) {
      _statusMessage = "Model already exists!";
      _progress = 1.0;
      notifyListeners();
      return;
    }

    _isDownloading = true;
    _progress = 0.0;
    _statusMessage = "Starting download...";
    _cancelToken = CancelToken();
    notifyListeners();

    try {
      debugPrint("Downloading from: ${ModelConstants.downloadUrl}");
      debugPrint("Saving to: $destinationPath");

      await _dio.download(
        ModelConstants.downloadUrl,
        destinationPath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _progress = received / total;
            _statusMessage =
                "Downloading: ${(received / 1024 / 1024).toStringAsFixed(1)} MB / ${(total / 1024 / 1024).toStringAsFixed(1)} MB";
            notifyListeners();
          }
        },
      );

      _statusMessage = "Download Complete!";
      _progress = 1.0;
      debugPrint("Download finished successfully.");
    } catch (e) {
      if (CancelToken.isCancel(e as DioException)) {
        _statusMessage = "Download Cancelled";
      } else {
        _statusMessage = "Error: $e";
        debugPrint("Download Error: $e");
      }
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel();
    _isDownloading = false;
    notifyListeners();
  }
}
