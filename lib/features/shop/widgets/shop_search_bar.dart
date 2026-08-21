import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hashtagg/core/network/shop_api_repository.dart';

class ShopSearchBar extends StatefulWidget {
  final int shopId;

  const ShopSearchBar({Key? key, required this.shopId}) : super(key: key);

  @override
  State<ShopSearchBar> createState() => _ShopSearchBarState();
}

class _ShopSearchBarState extends State<ShopSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  List<dynamic> _tags = [];
  List<dynamic> _ads = [];
  final LayerLink _layerLink =
      LayerLink(); // 👈 ДЛЯ ПРАВИЛЬНОГО ПОЗИЦИОНИРОВАНИЯ
  OverlayEntry? _overlayEntry;

  void _onSearchChanged(String query) async {
    print('🔍 [ShopSearchBar] _onSearchChanged: "$query"');

    if (query.length < 2) {
      setState(() {
        _tags = [];
        _ads = [];
      });
      _hideOverlay();
      return;
    }

    setState(() => _isLoading = true);

    final repository = context.read<ShopApiRepository>();
    final result = await repository.quickSearchShop(
      shopId: widget.shopId,
      query: query,
    );

    setState(() {
      _isLoading = false;
      if (result.success && result.data != null) {
        final data = result.data!;
        _tags = data['tags'] as List? ?? [];
        _ads = data['ads'] as List? ?? [];
        print(
          '🔍 [ShopSearchBar] Found ${_tags.length} tags, ${_ads.length} ads',
        );
      }
    });

    _showOverlay();
  }

  void _showOverlay() {
    _hideOverlay();
    if (_tags.isEmpty && _ads.isEmpty) return;

    try {
      // ✅ ПОЛУЧАЕМ РАЗМЕРЫ ПОЛЯ
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final size = renderBox.size;

      _overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            offset: Offset(0, 50),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.3,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_tags.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Категории',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                        ..._tags.map(
                          (tag) => ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            leading: Icon(
                              Icons.category,
                              size: 18,
                              color: Color(0xFF8956FF),
                            ),
                            title: Text(
                              tag['cat_name']?.toString() ??
                                  tag['tag']?.toString() ??
                                  '',
                              style: TextStyle(fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle:
                                tag['tag'] != null &&
                                    tag['tag'] != tag['cat_name']
                                ? Text(
                                    tag['tag'].toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            onTap: () => _onTagSelected(tag),
                          ),
                        ),
                        Divider(height: 1),
                      ],
                      if (_ads.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Товары',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                        ..._ads.map(
                          (ad) => ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            leading: _buildImage(ad['image']),
                            title: Text(
                              ad['title']?.toString() ?? '',
                              style: TextStyle(fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              _getPrice(ad['price']),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8956FF),
                              ),
                            ),
                            onTap: () => _onAdSelected(ad),
                          ),
                        ),
                      ],
                      SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      Overlay.of(context).insert(_overlayEntry!);
    } catch (e) {
      print('❌ [ShopSearchBar] Error showing overlay: $e');
    }
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onTagSelected(Map<String, dynamic> tag) {
    print('🔍 [ShopSearchBar] Tag selected: ${tag['tag']}');
    _controller.clear();
    _focusNode.unfocus();
    setState(() {
      _tags = [];
      _ads = [];
    });
    _hideOverlay();
    // TODO: Фильтровать товары по категории tag['cat_id']
  }

  void _onAdSelected(Map<String, dynamic> ad) {
    print('🔍 [ShopSearchBar] Ad selected: ${ad['title']}');
    _controller.clear();
    _focusNode.unfocus();
    setState(() {
      _tags = [];
      _ads = [];
    });
    _hideOverlay();
    context.push('/listing/${ad['id']}');
  }

  String _getPrice(dynamic price) {
    if (price == null) return '';
    if (price is Map) {
      return price['now']?.toString() ?? '';
    }
    return price.toString();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: Colors.grey.shade500, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Поиск по магазину...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            if (_isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF8956FF),
                ),
              ),
            if (_controller.text.isNotEmpty && !_isLoading)
              GestureDetector(
                onTap: () {
                  _controller.clear();
                  setState(() {
                    _tags = [];
                    _ads = [];
                  });
                  _hideOverlay();
                },
                child: Icon(Icons.clear, size: 18, color: Colors.grey.shade500),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(dynamic imageUrl) {
    final String url = imageUrl?.toString() ?? '';

    if (url.isEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.image, color: Colors.grey.shade400, size: 20),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 40,
          height: 40,
          color: Colors.grey.shade200,
          child: Icon(
            Icons.broken_image,
            color: Colors.grey.shade400,
            size: 20,
          ),
        ),
      ),
    );
  }
}
