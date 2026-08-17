//G:\hashtagg_app\lib\features\home\widgets\category_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/core/theme/theme_colors.dart';
import 'package:hashtagg/features/search/screens/search_filters_screen.dart';

class CategoryCard extends StatelessWidget {
  final double width;
  final double imageSize;
  final String uri;
  final String name;
  final int? categoryId;
  final SearchFilters? filters; // Добавляем фильтры

  const CategoryCard({
    super.key,
    required this.width,
    required this.imageSize,
    required this.uri,
    required this.name,
    this.categoryId,
    this.filters, // Опциональные фильтры
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        // Если есть ID категории, передаем его вместе с фильтрами
        if (categoryId != null) {
          // Создаем новые фильтры с категорией
          final searchFilters = (filters ?? const SearchFilters()).copyWith(
            categoryId: categoryId,
            category: name,
          );
          context.push('/search', extra: searchFilters);
        } else {
          context.push('/search', extra: name);
        }
      },
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            Container(
              clipBehavior: Clip.hardEdge,
              width: imageSize,
              height: imageSize,
              decoration: BoxDecoration(
                color: isDark 
                    ? ThemeColors.getCategoryCardColor(context) 
                    : const Color(0xff917dfa),
                borderRadius: BorderRadiusGeometry.all(Radius.circular(10)),
              ),
              child: uri.isNotEmpty
                  ? Image.network(
                      ApiConfig.replaceMediaUrl(uri),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.category,
                            color: Colors.white,
                            size: 40,
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Icon(
                        Icons.category,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
            ),
            SizedBox(height: 4),
            Text(
              name,
              style: GoogleFonts.montserrat(
                color: ThemeColors.getTextColor(context),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
