import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/state/auth_controller.dart';
import '../../../../core/state/lesson_assets_state.dart';

class AssetViewPage extends ConsumerStatefulWidget {
  const AssetViewPage({
    super.key,
    required this.lessonId,
    required this.assetId,
  });

  final String lessonId;
  final String assetId;

  @override
  ConsumerState<AssetViewPage> createState() => _AssetViewPageState();
}

class _AssetViewPageState extends ConsumerState<AssetViewPage> {
  int _totalPages = 0;
  int _lastPage = 1;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assets = ref.watch(lessonAssetsProvider(widget.lessonId)).valueOrNull ?? const [];
    final match = assets.where((e) => e.id == widget.assetId);
    final asset = match.isEmpty ? null : match.first;
    if (asset == null) return const Scaffold(body: Center(child: Text("Fayl topilmadi")));

    final isPpt = asset.fileType.toLowerCase().startsWith('ppt');
    if (isPpt) {
      final isDataUrl = asset.fileUrl.trim().startsWith('data:');
      return Scaffold(
        appBar: AppBar(title: Text(asset.title)),
        body: Center(
          child: isDataUrl
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "PPT data-url formatida saqlangan. Tashqi viewerda ochish uchun Cloudflare R2 bucket sozlang va fayl public URL bilan saqlansin.",
                    textAlign: TextAlign.center,
                  ),
                )
              : FilledButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(asset.fileUrl);
                    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
                    await _saveProgress();
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('PPT ni ochish'),
                ),
        ),
      );
    }

    final isPdfDataUrl = asset.fileUrl.trim().startsWith('data:application/pdf');
    return Scaffold(
      appBar: AppBar(title: Text(asset.title)),
      body: isPdfDataUrl ? _buildPdfMemory(asset.fileUrl) : _buildPdfNetwork(asset.fileUrl),
    );
  }

  Widget _buildPdfMemory(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    if (comma <= 0) return const Center(child: Text("PDF formati noto'g'ri."));
    try {
      final bytes = base64Decode(dataUrl.substring(comma + 1).replaceAll(RegExp(r'\s'), ''));
      return SfPdfViewer.memory(
        bytes,
        onDocumentLoaded: (details) => _totalPages = details.document.pages.count,
        onPageChanged: (details) {
          _lastPage = details.newPageNumber;
          _debounce?.cancel();
          _debounce = Timer(const Duration(seconds: 2), _saveProgress);
        },
      );
    } catch (_) {
      return const Center(child: Text("PDF ni o'qib bo'lmadi."));
    }
  }

  Widget _buildPdfNetwork(String url) {
    return FutureBuilder<Uint8List>(
      future: _downloadPdfBytes(url),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                snapshot.error is Exception ? (snapshot.error as Exception).toString().replaceFirst('Exception: ', '') : "PDF yuklanmadi.",
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return SfPdfViewer.memory(
          snapshot.data!,
          onDocumentLoaded: (details) => _totalPages = details.document.pages.count,
          onPageChanged: (details) {
            _lastPage = details.newPageNumber;
            _debounce?.cancel();
            _debounce = Timer(const Duration(seconds: 2), _saveProgress);
          },
        );
      },
    );
  }

  Future<Uint8List> _downloadPdfBytes(String url) async {
    final normalized = url.trim();
    final uri = Uri.tryParse(normalized);
    if (uri == null) throw Exception("PDF URL noto'g'ri.");
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      final body = response.body.toLowerCase();
      if (body.contains('bucket not found')) {
        throw Exception("Storage bucket topilmadi. Admin panelda `content-assets` bucketni yarating.");
      }
      throw Exception("PDF yuklanmadi (status: ${response.statusCode}).");
    }
    return response.bodyBytes;
  }

  Future<void> _saveProgress() async {
    final userId = ref.read(authControllerProvider).userId ?? '';
    if (userId.isEmpty) return;
    final progress = _totalPages > 0 ? ((_lastPage / _totalPages) * 100).clamp(0, 100).toDouble() : 0.0;
    await ref.read(lessonAssetsRepositoryProvider).upsertProgress(
          userId: userId,
          assetId: widget.assetId,
          pageNo: _lastPage,
          progressPercent: progress,
        );
  }
}
