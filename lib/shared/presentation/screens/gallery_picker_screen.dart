import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/shared/presentation/utils.dart';

class GalleryPickerScreen extends StatefulWidget {
  final int maxCount; // максимальное количество выбираемых фото
  const GalleryPickerScreen({super.key, this.maxCount = 30});

  @override
  State<GalleryPickerScreen> createState() => _GalleryPickerScreenState();
}

class _GalleryPickerScreenState extends State<GalleryPickerScreen>
    with SingleTickerProviderStateMixin {
  // ── Галерея (все фото) ─────────────────────────────────────────────────────
  List<AssetEntity> _galleryAssets = [];
  AssetPathEntity? _galleryPath;
  int _galleryPage = 0;
  bool _galleryHasMore = true;
  bool _isLoadingGallery = true;
  final ScrollController _galleryScrollController = ScrollController();

  // ── Загрузки (папка Download) ──────────────────────────────────────────────
  List<AssetEntity> _downloadAssets = [];
  AssetPathEntity? _downloadPath;
  int _downloadPage = 0;
  bool _downloadHasMore = true;
  bool _isLoadingDownloads = true;
  final ScrollController _downloadScrollController = ScrollController();

  static const int _pageSize = 200;

  // Общий набор выбранных ассетов (по id)
  final Set<String> _selectedIds = {};

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _galleryScrollController.addListener(() => _onScroll(_galleryScrollController,
        _loadMoreGalleryAssets, _galleryHasMore, _isLoadingGallery));
    _downloadScrollController.addListener(() => _onScroll(_downloadScrollController,
        _loadMoreDownloadAssets, _downloadHasMore, _isLoadingDownloads));
    _loadAllAssets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _galleryScrollController.dispose();
    _downloadScrollController.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Первоначальная загрузка обоих источников
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _loadAllAssets() async {
    print('🔵 [GalleryPicker] _loadAllAssets() START');

    final permission = await PhotoManager.requestPermissionExtend();
    print('🔵 [GalleryPicker] Permission result: ${permission.isAuth}');

    if (!permission.isAuth) {
      print('🔴 [GalleryPicker] Permission denied!');
      if (mounted) PhotoManager.openSetting();
      return;
    }

    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    print('🔵 [GalleryPicker] Found ${albums.length} albums');

    if (albums.isEmpty) {
      print('🔴 [GalleryPicker] No albums found!');
      setState(() {
        _isLoadingGallery = false;
        _isLoadingDownloads = false;
      });
      return;
    }

    // Первый альбом — «Все фото»
    _galleryPath = albums.first;
    print('🔵 [GalleryPicker] Gallery album: ${_galleryPath!.name}');

    // Ищем альбом "Download"
    for (final album in albums) {
      print('🔵 [GalleryPicker] Album: ${album.name}');
      if (album.name.toLowerCase() == 'download') {
        _downloadPath = album;
        print('🔵 [GalleryPicker] Found Download album!');
        break;
      }
    }

    // Загружаем первые страницы
    await Future.wait([
      _loadGalleryAssets(page: 0),
      if (_downloadPath != null) _loadDownloadAssets(page: 0),
    ]);

    if (_downloadPath == null) {
      print('⚠️ [GalleryPicker] Download album not found');
      setState(() => _isLoadingDownloads = false);
    }

    print('✅ [GalleryPicker] _loadAllAssets() COMPLETE');
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Галерея: загрузка страницы
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _loadGalleryAssets({required int page}) async {
    if (_galleryPath == null) return;
    final assets =
        await _galleryPath!.getAssetListPaged(page: page, size: _pageSize);
    setState(() {
      if (page == 0) {
        _galleryAssets = assets;
      } else {
        _galleryAssets.addAll(assets);
      }
      _galleryHasMore = assets.length == _pageSize;
      _galleryPage = page;
      _isLoadingGallery = false;
    });
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Загрузки: загрузка страницы
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _loadDownloadAssets({required int page}) async {
    if (_downloadPath == null) return;
    final assets =
        await _downloadPath!.getAssetListPaged(page: page, size: _pageSize);
    setState(() {
      if (page == 0) {
        _downloadAssets = assets;
      } else {
        _downloadAssets.addAll(assets);
      }
      _downloadHasMore = assets.length == _pageSize;
      _downloadPage = page;
      _isLoadingDownloads = false;
    });
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Подгрузка при скролле (общая логика)
  // ────────────────────────────────────────────────────────────────────────────
  void _onScroll(ScrollController controller, Future<void> Function() loadMore,
      bool hasMore, bool isLoading) {
    if (controller.position.pixels >=
            controller.position.maxScrollExtent - 200 &&
        hasMore &&
        !isLoading) {
      loadMore();
    }
  }

  Future<void> _loadMoreGalleryAssets() async {
    if (!_galleryHasMore || _isLoadingGallery) return;
    setState(() => _isLoadingGallery = true);
    await _loadGalleryAssets(page: _galleryPage + 1);
  }

  Future<void> _loadMoreDownloadAssets() async {
    if (!_downloadHasMore || _isLoadingDownloads) return;
    setState(() => _isLoadingDownloads = true);
    await _loadDownloadAssets(page: _downloadPage + 1);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Выбор / отмена выбора
  // ────────────────────────────────────────────────────────────────────────────
  void _toggleSelection(AssetEntity asset) {
    final id = asset.id;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        if (_selectedIds.length >= widget.maxCount) {
          showSwipeDownNotification(
              context, message: 'Максимум ${widget.maxCount} фото');
          return;
        }
        _selectedIds.add(id);
      }
    });
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Подтверждение выбора – сбор файлов из обоих списков
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _confirmSelection() async {
    print('🔵 [GalleryPicker] _confirmSelection() START');
    print('🔵 [GalleryPicker] Selected IDs: ${_selectedIds.length}');

    if (_selectedIds.isEmpty) {
      print('⚠️ [GalleryPicker] No selected IDs');
      Navigator.pop(context, <File>[]);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
      const Center(child: CircularProgressIndicator(color: Color(0xff917dfa))),
    );

    final files = <File>[];
    final allAssets = [..._galleryAssets, ..._downloadAssets];
    print('🔵 [GalleryPicker] Total assets: ${allAssets.length}');

    for (final id in _selectedIds) {
      try {
        final asset = allAssets.firstWhere((a) => a.id == id);
        print('🔵 [GalleryPicker] Getting file for asset: ${asset.id}');
        final file = await asset.file;
        if (file != null) {
          files.add(file);
          print('✅ [GalleryPicker] File added: ${file.path}');
        } else {
          print('⚠️ [GalleryPicker] File is null for asset: ${asset.id}');
        }
      } catch (e) {
        print('🔴 [GalleryPicker] Error getting file: $e');
      }
    }

    print('✅ [GalleryPicker] Total files: ${files.length}');

    if (!mounted) return;
    Navigator.pop(context); // закрываем индикатор
    Navigator.pop(context, files);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Построение миниатюры с водяным знаком и индикатором выбора
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildAssetThumbnail(AssetEntity asset, bool isSelected) {
    return GestureDetector(
      onTap: () => _toggleSelection(asset),
      child: Container(
        decoration: isSelected
            ? BoxDecoration(
                border: Border.all(color: const Color(0xff917dfa), width: 3),
              )
            : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: AssetEntityImageProvider(
                asset,
                isOriginal: false,
                thumbnailSize: const ThumbnailSize.square(200),
                thumbnailFormat: ThumbnailFormat.jpeg,
              ),
              fit: BoxFit.cover,
            ),
            // Водяной знак
            Center(
              child: Opacity(
                opacity: 0.15,
                child: Image.asset(
                  'assets/logo.png',
                  width: 50,
                  height: 50,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Галочка выбора
            if (isSelected)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xff917dfa),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Сетка для конкретного источника
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildGrid({
    required List<AssetEntity> assets,
    required ScrollController controller,
    required bool isLoading,
    required bool hasMore,
  }) {
    return Stack(
      children: [
        GridView.builder(
          controller: controller,
          padding: const EdgeInsets.all(4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: assets.length,
          itemBuilder: (context, index) {
            final asset = assets[index];
            final isSelected = _selectedIds.contains(asset.id);
            return _buildAssetThumbnail(asset, isSelected);
          },
        ),
        // Индикатор подгрузки
        if (isLoading && assets.isNotEmpty)
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(color: Color(0xff917dfa)),
          ),
        // Начальная загрузка
        if (isLoading && assets.isEmpty)
          const Center(
              child: CircularProgressIndicator(color: Color(0xff917dfa))),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Основной build
  // ────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff151e27) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          'Выберите фото (${_selectedIds.length}/${widget.maxCount})',
          style: GoogleFonts.montserrat(color: textColor, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: _selectedIds.isNotEmpty ? _confirmSelection : null,
            child: Text(
              'Готово',
              style: GoogleFonts.montserrat(
                color: _selectedIds.isNotEmpty
                    ? const Color(0xff917dfa)
                    : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xff917dfa),
          labelColor: const Color(0xff917dfa),
          unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
          labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Галерея'),
            Tab(text: 'Загрузки'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Вкладка «Галерея»
          _buildGrid(
            assets: _galleryAssets,
            controller: _galleryScrollController,
            isLoading: _isLoadingGallery,
            hasMore: _galleryHasMore,
          ),
          // Вкладка «Загрузки»
          _buildGrid(
            assets: _downloadAssets,
            controller: _downloadScrollController,
            isLoading: _isLoadingDownloads,
            hasMore: _downloadHasMore,
          ),
        ],
      ),
    );
  }
}