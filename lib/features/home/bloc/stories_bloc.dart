import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/core/network/stories_api_repository.dart';

// ── События ──────────────────────────────────────────────────────────────────

abstract class StoriesEvent {}

class LoadStories extends StoriesEvent {
  final int? userId;
  final int? idUserAuth;
  final int? cityId;
  final int? regionId;
  final int? countryId;
  final int? catId;

  LoadStories({
    this.userId,
    this.idUserAuth,
    this.cityId,
    this.regionId,
    this.countryId,
    this.catId,
  });
}

class UpdateStoryView extends StoriesEvent {
  final int storyId;
  final String ip;

  UpdateStoryView({required this.storyId, required this.ip});
}

// ── Состояния ────────────────────────────────────────────────────────────────

abstract class StoriesState {}

class StoriesInitial extends StoriesState {}

class StoriesLoading extends StoriesState {}

class StoriesLoaded extends StoriesState {
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> categories;

  StoriesLoaded({required this.users, required this.categories});
}

class StoriesError extends StoriesState {
  final String message;

  StoriesError(this.message);
}

// ── BLoC ─────────────────────────────────────────────────────────────────────

class StoriesBloc extends Bloc<StoriesEvent, StoriesState> {
  final StoriesApiRepository _repository;

  StoriesBloc({StoriesApiRepository? repository})
      : _repository = repository ?? StoriesApiRepository(),
        super(StoriesInitial()) {
    on<LoadStories>(_onLoadStories);
    on<UpdateStoryView>(_onUpdateStoryView);
  }

  Future<void> _onLoadStories(
    LoadStories event,
    Emitter<StoriesState> emit,
  ) async {
    print('🔵 [StoriesBloc] Loading stories');
    emit(StoriesLoading());

    try {
      final result = await _repository.getStories(
        userId: event.userId,
        idUserAuth: event.idUserAuth,
        cityId: event.cityId,
        regionId: event.regionId,
        countryId: event.countryId,
        catId: event.catId,
      );

      print('🔵 [StoriesBloc] API result: $result');

      if (result['status'] == true) {
        final data = result['data'];
        print('🔵 [StoriesBloc] Data type: ${data.runtimeType}');
        print('🔵 [StoriesBloc] Data content: $data');
        
        final users = (data['users'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final categories = (data['categories'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        
        print('✅ [StoriesBloc] Stories loaded: ${users.length} users, ${categories.length} categories');
        
        if (users.isEmpty) {
          print('⚠️ [StoriesBloc] No stories found - showing empty state');
        }
        
        emit(StoriesLoaded(users: users, categories: categories));
      } else {
        print('🔴 [StoriesBloc] Failed to load stories: ${result['error']}');
        emit(StoriesError(result['error'] ?? 'Не удалось загрузить истории'));
      }
    } catch (e, stackTrace) {
      print('🔴 [StoriesBloc] Stories error: $e');
      print('🔴 [StoriesBloc] Stack trace: $stackTrace');
      emit(StoriesError('Ошибка загрузки историй: $e'));
    }
  }

  Future<void> _onUpdateStoryView(
    UpdateStoryView event,
    Emitter<StoriesState> emit,
  ) async {
    print('🔵 [StoriesBloc] Updating story view: ${event.storyId}');

    try {
      await _repository.updateCountView(
        storyId: event.storyId,
        ip: event.ip,
      );
      print('✅ [StoriesBloc] Story view updated');
    } catch (e) {
      print('🔴 [StoriesBloc] Update view error: $e');
    }
  }
}
