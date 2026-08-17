import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/core/network/reviews_api_repository.dart';
import 'package:hive/hive.dart';

// Events
abstract class ReviewsEvent {}

class LoadReviews extends ReviewsEvent {
  final int userId;
  final int page;
  LoadReviews(this.userId, {this.page = 1});
}

class AddReview extends ReviewsEvent {
  final int userIdTo;
  final int adId;
  final int rating;
  final String text;
  final int deal;
  
  AddReview({
    required this.userIdTo,
    required this.adId,
    required this.rating,
    required this.text,
    required this.deal,
  });
}

// States
abstract class ReviewsState {}

class ReviewsInitial extends ReviewsState {}

class ReviewsLoading extends ReviewsState {}

class ReviewsLoaded extends ReviewsState {
  final List<dynamic> reviews;
  final double totalRating;
  final int count;
  final String countString;
  final int pages;
  
  ReviewsLoaded({
    required this.reviews,
    required this.totalRating,
    required this.count,
    required this.countString,
    required this.pages,
  });
}

class ReviewsError extends ReviewsState {
  final String message;
  ReviewsError(this.message);
}

class ReviewAdded extends ReviewsState {}

// BLoC
class ReviewsBloc extends Bloc<ReviewsEvent, ReviewsState> {
  final ReviewsApiRepository _apiRepository;

  ReviewsBloc({ReviewsApiRepository? apiRepository})
      : _apiRepository = apiRepository ?? ReviewsApiRepository(),
        super(ReviewsInitial()) {
    on<LoadReviews>(_onLoadReviews);
    on<AddReview>(_onAddReview);
  }

  Future<void> _onLoadReviews(
    LoadReviews event,
    Emitter<ReviewsState> emit,
  ) async {
    emit(ReviewsLoading());
    
    try {
      print('🔵 [ReviewsBloc] Loading reviews for user: ${event.userId}, page: ${event.page}');
      
      final response = await _apiRepository.getReviews(
        userId: event.userId,
        page: event.page,
      );
      
      if (response['status'] == false) {
        emit(ReviewsError(response['error'] ?? 'Failed to load reviews'));
        return;
      }
      
      final reviews = response['data'] as List? ?? [];
      final totalRating = _parseDouble(response['total_rating']);
      final count = _parseInt(response['count']);
      final countString = response['total_count_reviews_string']?.toString() ?? '0 отзывов';
      final pages = _parseInt(response['pages']);
      
      print('✅ [ReviewsBloc] Loaded ${reviews.length} reviews, rating: $totalRating');
      
      emit(ReviewsLoaded(
        reviews: reviews,
        totalRating: totalRating,
        count: count,
        countString: countString,
        pages: pages,
      ));
    } catch (e) {
      print('🔴 [ReviewsBloc] Error loading reviews: $e');
      emit(ReviewsError(e.toString()));
    }
  }

  Future<void> _onAddReview(
    AddReview event,
    Emitter<ReviewsState> emit,
  ) async {
    emit(ReviewsLoading());
    
    try {
      print('🔵 [ReviewsBloc] Adding review');
      
      final box = Hive.box('user');
      final token = box.get('auth_token') as String?;
      final userData = box.get('user');
      
      int? userId;
      if (userData != null && userData['id'] != null) {
        userId = int.tryParse(userData['id'].toString());
      }

      if (token == null || userId == null) {
        print('🔴 [ReviewsBloc] No auth data for add review');
        emit(ReviewsError('Необходима авторизация'));
        return;
      }

      final result = await _apiRepository.addReview(
        token: token,
        userIdFrom: userId,
        userIdTo: event.userIdTo,
        adId: event.adId,
        rating: event.rating,
        text: event.text,
        deal: event.deal,
      );

      if (result['status'] == true) {
        print('✅ [ReviewsBloc] Review added successfully');
        emit(ReviewAdded());
        // Перезагружаем отзывы
        add(LoadReviews(event.userIdTo));
      } else {
        print('🔴 [ReviewsBloc] Failed to add review');
        emit(ReviewsError(result['error'] ?? 'Ошибка добавления отзыва'));
      }
    } catch (e, stackTrace) {
      print('🔴 [ReviewsBloc] Error adding review: $e');
      print('🔴 [ReviewsBloc] Stack trace: $stackTrace');
      emit(ReviewsError(e.toString()));
    }
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
