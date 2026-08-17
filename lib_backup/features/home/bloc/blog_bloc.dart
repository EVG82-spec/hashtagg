import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/core/network/blog_api_repository.dart';

// Events
abstract class BlogEvent {}

class LoadArticles extends BlogEvent {
  final int? categoryId;
  final int page;
  LoadArticles({this.categoryId, this.page = 1});
}

class LoadArticle extends BlogEvent {
  final int articleId;
  LoadArticle(this.articleId);
}

// States
abstract class BlogState {}

class BlogInitial extends BlogState {}

class BlogLoading extends BlogState {}

class ArticlesLoaded extends BlogState {
  final List<dynamic> articles;
  final List<dynamic>? categories;
  final int count;
  final int pages;
  
  ArticlesLoaded({
    required this.articles,
    this.categories,
    required this.count,
    required this.pages,
  });
}

class ArticleLoaded extends BlogState {
  final Map<String, dynamic> article;
  final ArticlesLoaded? previousArticlesState; // Сохраняем предыдущее состояние списка
  
  ArticleLoaded(this.article, {this.previousArticlesState});
}

class BlogError extends BlogState {
  final String message;
  BlogError(this.message);
}

// BLoC
class BlogBloc extends Bloc<BlogEvent, BlogState> {
  final BlogApiRepository _apiRepository;
  ArticlesLoaded? _lastArticlesState; // Кешируем последнее состояние списка

  BlogBloc({BlogApiRepository? apiRepository})
      : _apiRepository = apiRepository ?? BlogApiRepository(),
        super(BlogInitial()) {
    on<LoadArticles>(_onLoadArticles);
    on<LoadArticle>(_onLoadArticle);
  }

  Future<void> _onLoadArticles(
    LoadArticles event,
    Emitter<BlogState> emit,
  ) async {
    emit(BlogLoading());
    
    try {
      print('🔵 [BlogBloc] Loading articles - categoryId: ${event.categoryId}, page: ${event.page}');
      
      final response = await _apiRepository.getArticles(
        categoryId: event.categoryId,
        page: event.page,
      );
      
      if (response['status'] == false) {
        emit(BlogError(response['error'] ?? 'Failed to load articles'));
        return;
      }
      
      final articles = response['data'] as List? ?? [];
      final categories = response['categories'] as List?;
      final count = _parseInt(response['count']);
      final pages = _parseInt(response['pages']);
      
      print('✅ [BlogBloc] Loaded ${articles.length} articles');
      
      final articlesState = ArticlesLoaded(
        articles: articles,
        categories: categories,
        count: count,
        pages: pages,
      );
      
      _lastArticlesState = articlesState; // Сохраняем состояние
      emit(articlesState);
    } catch (e) {
      print('🔴 [BlogBloc] Error loading articles: $e');
      emit(BlogError(e.toString()));
    }
  }

  Future<void> _onLoadArticle(
    LoadArticle event,
    Emitter<BlogState> emit,
  ) async {
    emit(BlogLoading());
    
    try {
      print('🔵 [BlogBloc] Loading article: ${event.articleId}');
      
      final response = await _apiRepository.getArticle(
        articleId: event.articleId,
      );
      
      if (response['status'] == false) {
        emit(BlogError(response['error'] ?? 'Failed to load article'));
        return;
      }
      
      print('✅ [BlogBloc] Article loaded: ${response['title']}');
      
      emit(ArticleLoaded(response, previousArticlesState: _lastArticlesState));
    } catch (e) {
      print('🔴 [BlogBloc] Error loading article: $e');
      emit(BlogError(e.toString()));
    }
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
