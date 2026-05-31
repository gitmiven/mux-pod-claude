import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/ssh_provider.dart';
import '../../services/sftp/sftp_browser_service.dart';
import '../../services/viewer/file_parsers.dart';
import '../../services/viewer/file_viewer_type.dart';
import '../../services/viewer/markdown_image.dart';

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
      case FileViewerType.csv:
        return _buildCsv(bytes);
      case FileViewerType.archive:
        return _buildArchive(bytes);
      case FileViewerType.external:
        // External files are downloaded + opened by the browser, not here.
        return _message('This file opens in an external app.');
    }
  }

  Widget _buildCsv(Uint8List bytes) {
    final List<List<String>> rows;
    try {
      rows = parseCsvRows(utf8.decode(bytes, allowMalformed: true));
    } catch (_) {
      return _message("Couldn't read this CSV.");
    }
    if (rows.isEmpty) return _message('Empty CSV.');

    // Cap what we render so a huge sheet stays responsive.
    const maxRows = 500;
    final shown = rows.length > maxRows ? rows.sublist(0, maxRows) : rows;
    final columns = shown.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    final header = shown.first;
    final body = shown.skip(1).toList();

    String cell(List<String> r, int i) => i < r.length ? r[i] : '';

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            for (var i = 0; i < columns; i++)
              DataColumn(
                label: Text(
                  cell(header, i),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
          rows: [
            for (final r in body)
              DataRow(
                cells: [
                  for (var i = 0; i < columns; i++)
                    DataCell(Text(
                      cell(r, i),
                      style: GoogleFonts.jetBrainsMono(fontSize: 12),
                    )),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchive(Uint8List bytes) {
    final List<ZipEntry> entries;
    try {
      entries = listZipEntries(bytes);
    } catch (_) {
      return _message("Couldn't read this archive.");
    }
    if (entries.isEmpty) return _message('Empty archive.');
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final e = entries[index];
        return ListTile(
          dense: true,
          leading: Icon(e.isFile ? Icons.insert_drive_file_outlined : Icons.folder_outlined),
          title: Text(
            e.name,
            style: GoogleFonts.jetBrainsMono(fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: e.isFile ? Text(_formatBytes(e.size)) : null,
        );
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
    return Markdown(
      data: text,
      selectable: true,
      imageBuilder: _markdownImage,
    );
  }

  /// Renders an embedded markdown image: SFTP for remote/relative paths
  /// (resolved against this .md file's directory), network for http(s), and
  /// inline bytes for data URIs.
  Widget _markdownImage(Uri uri, String? title, String? alt) {
    if (uri.scheme == 'data') {
      final data = uri.data;
      if (data == null) return _brokenImage();
      return Image.memory(
        data.contentAsBytes(),
        errorBuilder: (context, error, stack) => _brokenImage(),
      );
    }
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return Image.network(
        uri.toString(),
        errorBuilder: (context, error, stack) => _brokenImage(),
      );
    }
    final path = resolveRemoteImagePath(widget.path, uri);
    if (path == null) return _brokenImage();
    return _SftpImage(path: path);
  }

  Widget _brokenImage() => const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.broken_image_outlined),
      );

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

/// An embedded markdown image fetched over SFTP (size-capped), with loading and
/// broken-image placeholders. The fetch future is created once so the image
/// isn't refetched on every rebuild.
class _SftpImage extends ConsumerStatefulWidget {
  final String path;
  const _SftpImage({required this.path});

  @override
  ConsumerState<_SftpImage> createState() => _SftpImageState();
}

class _SftpImageState extends ConsumerState<_SftpImage> {
  final SftpBrowserService _browser = SftpBrowserService();
  late final Future<Uint8List> _future = _fetch();

  Future<Uint8List> _fetch() async {
    final client = ref.read(sshProvider.notifier).client;
    if (client == null || !client.isConnected) {
      throw StateError('not connected');
    }
    final sftp = await client.openSftp();
    return _browser.readFileBytes(sftp, widget.path);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final bytes = snapshot.data;
        if (snapshot.hasError || bytes == null) return _broken();
        return Image.memory(
          bytes,
          errorBuilder: (context, error, stack) => _broken(),
        );
      },
    );
  }

  Widget _broken() => const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.broken_image_outlined),
      );
}
