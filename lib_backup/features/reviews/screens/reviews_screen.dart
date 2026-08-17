import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/features/reviews/bloc/reviews_bloc.dart';

class ReviewsScreen extends StatefulWidget {
  final int userId;
  
  const ReviewsScreen({
    super.key,
    required this.userId,
  });

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ReviewsBloc>().add(LoadReviews(widget.userId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Отзывы',
          style: GoogleFonts.montserrat(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: BlocBuilder<ReviewsBloc, ReviewsState>(
        builder: (context, state) {
          if (state is ReviewsLoading) {
            return Center(
              child: CircularProgressIndicator(
                color: Color(0xff917dfa),
              ),
            );
          }
          
          if (state is ReviewsError) {
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
          
          if (state is ReviewsLoaded) {
            return Column(
              children: [
                // Блок с рейтингом
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Средний рейтинг
                      Text(
                        state.totalRating.toStringAsFixed(1),
                        style: GoogleFonts.montserrat(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 8),
                      // Звезды
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return Icon(
                            index < state.totalRating.floor()
                                ? Icons.star
                                : (index < state.totalRating
                                    ? Icons.star_half
                                    : Icons.star_border),
                            color: state.count > 0
                                ? Color(0xffFFC107)
                                : Colors.grey[400],
                            size: 32,
                          );
                        }),
                      ),
                      SizedBox(height: 8),
                      // Количество отзывов
                      Text(
                        state.countString,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Список отзывов или пустое состояние
                Expanded(
                  child: state.reviews.isEmpty
                      ? _buildEmptyState()
                      : _buildReviewsList(state.reviews),
                ),
              ],
            );
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'Отзывов нет',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList(List<dynamic> reviews) {
    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: reviews.length,
      separatorBuilder: (context, index) => Divider(
        height: 32,
        color: Colors.grey[200],
      ),
      itemBuilder: (context, index) {
        final review = reviews[index];
        return _buildReviewItem(review);
      },
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> review) {
    final rating = _parseInt(review['rating']);
    final userName = review['name']?.toString() ?? 'Пользователь';
    final avatar = review['avatar']?.toString();
    final text = review['text']?.toString() ?? '';
    final date = review['date']?.toString();
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Аватар
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[200],
            image: avatar != null && avatar.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(avatar),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: avatar == null || avatar.isEmpty
              ? Icon(Icons.person, color: Colors.grey[400], size: 24)
              : null,
        ),
        SizedBox(width: 12),
        // Контент отзыва
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Имя и рейтинг
              Row(
                children: [
                  Expanded(
                    child: Text(
                      userName,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  // Звезды рейтинга
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Color(0xffFFC107),
                        size: 16,
                      );
                    }),
                  ),
                ],
              ),
              SizedBox(height: 4),
              // Дата
              if (date != null)
                Text(
                  _formatDate(date),
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              SizedBox(height: 8),
              // Текст отзыва
              Text(
                text,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays == 0) {
        return 'Сегодня';
      } else if (difference.inDays == 1) {
        return 'Вчера';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} дней назад';
      } else {
        // Форматируем дату вручную: dd.MM.yyyy
        final day = date.day.toString().padLeft(2, '0');
        final month = date.month.toString().padLeft(2, '0');
        final year = date.year.toString();
        return '$day.$month.$year';
      }
    } catch (e) {
      return dateStr;
    }
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
