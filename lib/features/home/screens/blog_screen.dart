import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/features/home/bloc/blog_bloc.dart';

class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key});

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    // Проверяем, есть ли сохраненное состояние списка статей
    final currentState = context.read<BlogBloc>().state;
    if (currentState is ArticleLoaded && currentState.previousArticlesState != null) {
      // Восстанавливаем предыдущее состояние списка
      // Не нужно загружать заново
    } else if (currentState is! ArticlesLoaded) {
      // Загружаем статьи только если их еще нет
      context.read<BlogBloc>().add(LoadArticles());
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
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Theme.of(context).appBarTheme.backgroundColor,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Блог',
          style: GoogleFonts.montserrat(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: BlocBuilder<BlogBloc, BlogState>(
        builder: (context, state) {
          // Если мы в состоянии ArticleLoaded с сохраненным списком, показываем список
          if (state is ArticleLoaded && state.previousArticlesState != null) {
            final articlesState = state.previousArticlesState!;
            return _buildArticlesList(articlesState);
          }
          
          if (state is BlogLoading) {
            return Center(
              child: CircularProgressIndicator(
                color: Color(0xff917dfa),
              ),
            );
          }
          
          if (state is BlogError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    state.message,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          
          if (state is ArticlesLoaded) {
            return _buildArticlesList(state);
          }
          
          // Initial state
          return Center(
            child: CircularProgressIndicator(
              color: Color(0xff917dfa),
            ),
          );
        },
      ),
    );
  }

  Widget _buildArticlesList(ArticlesLoaded state) {
    return Column(
      children: [
        // Категории (табы)
        if (state.categories != null && state.categories!.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                _TabChip(
                  label: 'Все',
                  badge: state.count,
                  isActive: _selectedCategoryId == null,
                  onTap: () {
                    setState(() => _selectedCategoryId = null);
                    context.read<BlogBloc>().add(LoadArticles());
                  },
                ),
                const SizedBox(width: 10),
                ...state.categories!.map((category) {
                  final catId = _parseInt(category['id']);
                  final catName = category['name']?.toString() ?? '';
                  final catCount = _parseInt(category['count']);
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _TabChip(
                      label: catName,
                      badge: catCount,
                      isActive: _selectedCategoryId == catId,
                      onTap: () {
                        setState(() => _selectedCategoryId = catId);
                        context.read<BlogBloc>().add(
                          LoadArticles(categoryId: catId),
                        );
                      },
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

        // Список статей
        Expanded(
          child: state.articles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.article_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Статей нет',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: state.articles.length,
                  itemBuilder: (context, index) {
                    final article = state.articles[index];
                    return _ArticleCard(article: article);
                  },
                ),
        ),
      ],
    );
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

// ── Таб-чип ───────────────────────────────────────────────────────────────────

class _TabChip extends StatelessWidget {
  final String label;
  final int? badge;
  final bool isActive;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    this.badge,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive 
              ? (isDark ? const Color(0xff233040) : Colors.white)
              : (isDark ? const Color(0xff1a2530) : const Color(0xFFF5F7FA)),
          borderRadius: BorderRadius.circular(24),
          border: isActive
              ? Border.all(
                  color: isDark ? const Color(0xff2a3a4a) : const Color(0xFFE0E0E0), 
                  width: 1,
                )
              : null,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: isDark ? Colors.black26 : Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFF2196F3),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$badge',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Карточка статьи ───────────────────────────────────────────────────────────

class _ArticleCard extends StatelessWidget {
  final Map<String, dynamic> article;

  const _ArticleCard({required this.article});

  @override
  Widget build(BuildContext context) {
    final id = _parseInt(article['id']);
    final title = article['title']?.toString() ?? '';
    final catName = article['cat_name']?.toString() ?? '';
    final catAlias = article['cat_alias']?.toString() ?? '';
    final articleAlias = article['article_alias']?.toString() ?? '';
    final dateAdd = article['date_add']?.toString() ?? '';
    final countView = _parseInt(article['count_view']);
    final image = article['image']?.toString();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GestureDetector(
        onTap: () {
          context.push(
            '/article/$id',
            extra: {
              'cat_alias': catAlias,
              'article_alias': articleAlias,
            },
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Фото
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: image != null && image.isNotEmpty
                  ? Image.network(
                      image,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          width: double.infinity,
                          height: 220,
                          color: const Color(0xFFF0F0F0),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xff917dfa),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stack) => Container(
                        width: double.infinity,
                        height: 220,
                        color: const Color(0xFFF0F0F0),
                        child: const Icon(
                          Icons.image_outlined,
                          color: Color(0xFFCCCCCC),
                          size: 48,
                        ),
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      height: 220,
                      color: const Color(0xFFF0F0F0),
                      child: const Icon(
                        Icons.article_outlined,
                        color: Color(0xFFCCCCCC),
                        size: 48,
                      ),
                    ),
            ),

            const SizedBox(height: 10),

            // Категория + дата + просмотры
            Row(
              children: [
                if (catName.isNotEmpty) ...[
                  Text(
                    catName,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: const Color(0xFF999999),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: Color(0xFF999999),
                ),
                const SizedBox(width: 4),
                Text(
                  dateAdd,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: const Color(0xFF999999),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.remove_red_eye_outlined,
                  size: 13,
                  color: Color(0xFF999999),
                ),
                const SizedBox(width: 4),
                Text(
                  '$countView',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: const Color(0xFF999999),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Заголовок статьи
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.black,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
