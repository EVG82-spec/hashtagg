import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/core/models/category.dart';
import 'package:hashtagg/core/network/categories_api_repository.dart';
import 'package:hashtagg/core/network/dio_client.dart';

// Events
abstract class CategoriesEvent {}

class LoadCategories extends CategoriesEvent {
  final int parentId;
  LoadCategories({this.parentId = 0});
}

// States
abstract class CategoriesState {}

class CategoriesInitial extends CategoriesState {}

class CategoriesLoading extends CategoriesState {}

class CategoriesLoaded extends CategoriesState {
  final List<Category> categories;
  final bool isMain;

  CategoriesLoaded(this.categories, {this.isMain = true});
}

class CategoriesError extends CategoriesState {
  final String message;
  CategoriesError(this.message);
}

// BLoC
class CategoriesBloc extends Bloc<CategoriesEvent, CategoriesState> {
  final CategoriesApiRepository _repository;

  CategoriesBloc()
      : _repository = CategoriesApiRepository(),
        super(CategoriesInitial()) {
    on<LoadCategories>(_onLoadCategories);
  }

  Future<void> _onLoadCategories(
    LoadCategories event,
    Emitter<CategoriesState> emit,
  ) async {
    emit(CategoriesLoading());

    final result = await _repository.getCategories(parentId: event.parentId);

    print('🔵 [CategoriesBloc] Result: $result');

    if (result['status'] == true && result['data'] != null) {
      final data = result['data'];
      print('🔵 [CategoriesBloc] Data type: ${data.runtimeType}');
      
      final List<Category> categories = [];
      
      // API возвращает список категорий напрямую
      if (data is List) {
        print('✅ [CategoriesBloc] Found ${data.length} categories');
        for (var item in data) {
          try {
            categories.add(Category.fromJson(item));
          } catch (e) {
            print('🔴 [CategoriesBloc] Error parsing category: $e');
            print('🔴 [CategoriesBloc] Item: $item');
          }
        }
      } else {
        print('🔴 [CategoriesBloc] Invalid data format: expected List, got ${data.runtimeType}');
      }
      
      emit(CategoriesLoaded(
        categories,
        isMain: result['main'] == true,
      ));
    } else {
      emit(CategoriesError(result['error']?.toString() ?? 'Failed to load categories'));
    }
  }
}
