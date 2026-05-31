import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../services/image/image_converter.dart';
import '../services/sftp/sftp_service.dart';
import '../widgets/image_transfer_confirm_dialog.dart';
import 'settings_provider.dart';
import 'ssh_provider.dart';

/// Image transfer phase
enum ImageTransferPhase {
  idle,
  picking,
  confirming,
  converting,
  uploading,
  injecting,
  completed,
  error,
}

/// Image transfer state
class ImageTransferState {
  final ImageTransferPhase phase;
  final double uploadProgress;
  final String? lastUploadedPath;
  final String? errorMessage;
  final Uint8List? pickedImageBytes;
  final String? pickedImageName;
  final String? pendingRemotePath;

  const ImageTransferState({
    this.phase = ImageTransferPhase.idle,
    this.uploadProgress = 0.0,
    this.lastUploadedPath,
    this.errorMessage,
    this.pickedImageBytes,
    this.pickedImageName,
    this.pendingRemotePath,
  });

  bool get canPick => phase == ImageTransferPhase.idle || phase == ImageTransferPhase.completed;

  ImageTransferState copyWith({
    ImageTransferPhase? phase,
    double? uploadProgress,
    String? lastUploadedPath,
    String? errorMessage,
    Uint8List? pickedImageBytes,
    String? pickedImageName,
    String? pendingRemotePath,
  }) {
    return ImageTransferState(
      phase: phase ?? this.phase,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      lastUploadedPath: lastUploadedPath ?? this.lastUploadedPath,
      errorMessage: errorMessage ?? this.errorMessage,
      pickedImageBytes: pickedImageBytes ?? this.pickedImageBytes,
      pickedImageName: pickedImageName ?? this.pickedImageName,
      pendingRemotePath: pendingRemotePath ?? this.pendingRemotePath,
    );
  }
}

/// Notifier to manage image transfer
class ImageTransferNotifier extends Notifier<ImageTransferState> {
  final _imagePicker = ImagePicker();
  final _sftpService = SftpService();
  StreamSubscription? _connectionSub;

  @override
  ImageTransferState build() {
    ref.onDispose(() {
      _connectionSub?.cancel();
    });
    return const ImageTransferState();
  }

  /// Pick an image
  Future<void> pickImage(ImageSource source) async {

    if (!state.canPick) return;

    state = const ImageTransferState(phase: ImageTransferPhase.picking);


    try {
      final xFile = await _imagePicker.pickImage(source: source);
      if (xFile == null) {
        state = const ImageTransferState(phase: ImageTransferPhase.idle);
        return;
      }

      final bytes = await xFile.readAsBytes();
      final settings = ref.read(settingsProvider);
      final filename = SftpService.generateFilename(
        'img_',
        _extensionFromPath(xFile.path),
      );
      final remotePath = '${settings.imageRemotePath}$filename';

      state = ImageTransferState(
        phase: ImageTransferPhase.confirming,
        pickedImageBytes: bytes,
        pickedImageName: xFile.name,
        pendingRemotePath: remotePath,
      );
    } catch (e) {
      state = ImageTransferState(
        phase: ImageTransferPhase.error,
        errorMessage: 'Failed to pick image: $e',
      );
    }
  }

  /// Confirm path and execute upload
  ///
  /// [options] Pass all settings confirmed in the dialog (including overrides).
  Future<String?> confirmAndUpload({
    required ImageTransferOptions options,
  }) async {
    if (state.phase != ImageTransferPhase.confirming || state.pickedImageBytes == null) {
      return null;
    }

    final sshClient = ref.read(sshProvider.notifier).client;
    if (sshClient == null || !sshClient.isConnected) {
      state = ImageTransferState(
        phase: ImageTransferPhase.error,
        errorMessage: 'SSH connection not available',
      );
      return null;
    }

    // Monitor SSH disconnection
    _connectionSub?.cancel();
    _connectionSub = sshClient.connectionStateStream.listen((connState) {
      if (state.phase == ImageTransferPhase.uploading ||
          state.phase == ImageTransferPhase.converting) {
        state = ImageTransferState(
          phase: ImageTransferPhase.error,
          errorMessage: 'SSH connection lost during upload',
        );
      }
    });

    var remotePath = options.remotePath;

    try {
      var bytes = state.pickedImageBytes!;

      // Format conversion and resize (retrieved from options)
      final format = ImageOutputFormat.fromString(options.outputFormat);
      final needsConvert = format != ImageOutputFormat.original || options.needsResize;
      if (needsConvert) {
        state = state.copyWith(phase: ImageTransferPhase.converting);
        final result = await ImageConverter.convert(
          bytes: bytes,
          format: format,
          jpegQuality: options.jpegQuality,
          autoResize: options.needsResize,
          maxWidth: options.effectiveMaxWidth,
          maxHeight: options.effectiveMaxHeight,
        );
        bytes = result.bytes;
        // Update path if extension changed
        final dir = remotePath.substring(0, remotePath.lastIndexOf('/') + 1);
        final baseName = remotePath.substring(remotePath.lastIndexOf('/') + 1);
        final nameWithoutExt = baseName.contains('.')
            ? baseName.substring(0, baseName.lastIndexOf('.'))
            : baseName;
        remotePath = '$dir$nameWithoutExt.${result.extension}';
      }

      // Upload
      state = state.copyWith(
        phase: ImageTransferPhase.uploading,
        uploadProgress: 0.0,
      );

      final sftp = await sshClient.openSftp();
      try {
        final dir = remotePath.substring(0, remotePath.lastIndexOf('/'));
        final filename = remotePath.substring(remotePath.lastIndexOf('/') + 1);

        final result = await _sftpService.upload(
          sftp: sftp,
          remoteDir: dir,
          filename: filename,
          bytes: bytes,
          onProgress: (progress) {
            state = state.copyWith(uploadProgress: progress);
          },
        );

        state = ImageTransferState(
          phase: ImageTransferPhase.completed,
          lastUploadedPath: result.remotePath,
          uploadProgress: 1.0,
        );

        return result.remotePath;
      } finally {
        sftp.close();
      }
    } catch (e) {
      state = ImageTransferState(
        phase: ImageTransferPhase.error,
        errorMessage: 'Upload failed: $e',
      );
      return null;
    } finally {
      _connectionSub?.cancel();
      _connectionSub = null;
    }
  }

  /// Cancel
  void cancel() {
    _connectionSub?.cancel();
    _connectionSub = null;
    state = const ImageTransferState(phase: ImageTransferPhase.idle);
  }

  /// Reset to idle
  void reset() {
    state = const ImageTransferState(phase: ImageTransferPhase.idle);
  }

  String _extensionFromPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1) return 'png';
    return path.substring(dot + 1).toLowerCase();
  }
}

/// Image transfer provider
final imageTransferProvider =
    NotifierProvider<ImageTransferNotifier, ImageTransferState>(() {
  return ImageTransferNotifier();
});
