//G:\hashtagg_app\lib\features\shop\screens\shop_pages_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/features/shop/bloc/shop_bloc.dart';
import 'package:hashtagg/features/shop/bloc/shop_event.dart';
import 'package:hashtagg/features/shop/bloc/shop_state.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:hashtagg/core/utils/shop_access_checker.dart';
import 'package:hashtagg/core/navigation/swipeable_route.dart';
import 'package:hashtagg/features/shop/screens/shop_page_edit_screen.dart';

class ShopPagesScreen extends StatefulWidget {
  final int shopId;
  final List<ShopPage> initialPages;

  const ShopPagesScreen({
    super.key,
    required this.shopId,
    required this.initialPages,
  });

  @override
  State<ShopPagesScreen> createState() => _ShopPagesScreenState();
}

class _ShopPagesScreenState extends State<ShopPagesScreen> {
  static const int maxPages = 10;
  List<ShopPage> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages = List.from(widget.initialPages);
  }

  void _addPage() async {
    // Проверяем доступ к страницам
    final authState = context.read<AuthBloc>().state;
    final user = authState.user;

    if (user != null && !ShopAccessChecker.hasShopPagesAccess(user)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ShopAccessChecker.getFeatureAccessDeniedMessage('shop_page'),
          ),
          action: SnackBarAction(
            label: 'Тарифы',
            onPressed: () => context.push('/tariffs'),
          ),
        ),
      );
      return;
    }

    if (_pages.length >= maxPages) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Максимум $maxPages страниц')));
      return;
    }

    final result = await Navigator.of(context, rootNavigator: true).push(
      createSwipeableRoute(
        builder: (_) => ShopPageEditScreen(shopId: widget.shopId, page: null),
      ),
    );

    if (result == true && mounted) {
      _reloadPages();
    }
  }

  void _editPage(ShopPage page) async {
    final result = await Navigator.of(context, rootNavigator: true).push(
      createSwipeableRoute(
        builder: (_) => ShopPageEditScreen(shopId: widget.shopId, page: page),
      ),
    );

    if (result == true && mounted) {
      _reloadPages();
    }
  }

  void _deletePage(ShopPage page) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить страницу?'),
        content: Text('Страница "${page.name}" будет удалена безвозвратно'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performDelete(page);
            },
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _performDelete(ShopPage page) {
    final authState = context.read<AuthBloc>().state;
    final user = authState.user;

    if (user != null) {
      context.read<ShopBloc>().add(
        DeleteShopPage(
          userId: user.id,
          token: user.token ?? '',
          pageId: page.id,
        ),
      );
    }
  }

  void _reloadPages() {
    final authState = context.read<AuthBloc>().state;
    final user = authState.user;

    if (user != null) {
      context.read<ShopBloc>().add(
        LoadShop(
          userId: user.id,
          token: user.token ?? '',
          shopId: widget.shopId,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => context.pop(true),
        ),
        title: Text(
          'Страницы (${_pages.length}/$maxPages)',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          if (_pages.length < maxPages)
            IconButton(
              icon: Icon(
                Icons.add,
                color: isDark ? Colors.white : Colors.black,
              ),
              onPressed: _addPage,
            ),
        ],
      ),
      body: BlocConsumer<ShopBloc, ShopState>(
        listener: (context, state) {
          if (state is ShopError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          } else if (state is ShopPageDeleted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Страница удалена')));
            _reloadPages();
          } else if (state is ShopLoaded) {
            setState(() {
              _pages = state.shop.pages ?? [];
            });
          }
        },
        builder: (context, state) {
          if (_pages.isEmpty) {
            return _buildEmptyState(isDark);
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              final page = _pages[index];
              return _buildPageCard(page, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Нет страниц',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Создайте первую страницу магазина',
            style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addPage,
            icon: Icon(Icons.add, color: Colors.white),
            label: Text(
              'Создать страницу',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xff917dfa),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageCard(ShopPage page, bool isDark) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _editPage(page),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xff917dfa).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.description_outlined,
                    color: Color(0xff917dfa),
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              page.name,
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (page.status == 1)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Активна',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (page.text.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          _stripHtmlTags(page.text),
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (page.alias != null && page.alias!.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          'Алиас: ${page.alias}',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editPage(page);
                    } else if (value == 'delete') {
                      _deletePage(page);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20, color: Colors.grey),
                          SizedBox(width: 12),
                          Text('Редактировать'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Удалить', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Удаляет HTML теги из текста для отображения в списке
String _stripHtmlTags(String html) {
  return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}
