import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/ssh_provider.dart';
import '../../services/sftp/sftp_browser_service.dart';
import '../../services/viewer/file_viewer_type.dart';

/// In-app viewer for a remote file: fetches the bytes over SFTP (size-capped)
/// and renders them as an Image, Markdown, or Text view. Nothing is sent to the
/// terminal.
class FileViewerScreen extends ConsumerStatefulWidget {
  final String path;
  final String name;
  final FileViewerType type;

  const FileViewerScreen({
    super.key,
    required this.path,
    required this.name,
    required this.type,
  });

  @override
  ConsumerState<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends ConsumerState<FileViewerScreen> {
  final SftpBrowserService _browser = SftpBrowserService();

  bool _loading = true;
  String? _error;
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = ref.read(sshProvider.notifier).client;
    if (client == null || !client.isConnected) {
      setState(() {
        _loading = false;
        _error = 'Not connected.';
      });
      return;
    }
    try {
      final sftp = await client.openSftp();
      final bytes = await _browser.readFileBytes(sftp, widget.path);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } on FileTooLargeException catch (e) {
      if (!mounted) return;
      final mb = (e.limit / (1024 * 1024)).toStringAsFixed(0);
      setState(() {
        _loading = false;
        _error = 'File is too large to preview (max $mb MB).';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't open the file.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _message(_error!);
    }
    final bytes = _bytes;
    if (bytes == null) return _message("Couldn't open the file.");

    switch (widget.type) {
      case FileViewerType.image:
        return _buildImage(bytes);
      case FileViewerType.markdown:
        return _buildMarkdown(bytes);
      case FileViewerType.text:
        return _buildText(bytes);
    }
  }

  Widget _buildImage(Uint8List bytes) {
    return Center(
      child: InteractiveViewer(
        maxScale: 8,
        child: Image.memory(
          bytes,
          errorBuilder: (context, error, stack) =>
              _message("Can't display this image."),
        ),
      ),
    );
  }

  Widget _buildMarkdown(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    return Markdown(data: text, selectable: true);
  }

  Widget _buildText(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        text,
        style: GoogleFonts.jetBrainsMono(fontSize: 13),
      ),
    );
  }

  Widget _message(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
