import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:hashtagg/core/network/shop_api_repository.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:hashtagg/features/shop/bloc/shop_event.dart';
import 'package:hashtagg/features/shop/bloc/shop_state.dart';

class ShopBloc extends Bloc<ShopEvent, ShopState> {
  final ShopApiRepository _repository;

  ShopBloc(this._repository) : super(ShopInitial()) {
    on<LoadShop>(_onLoadShop);
    on<CreateShop>(_onCreateShop);
    on<UpdateShop>(_onUpdateShop);
    on<LoadShopForEdit>(_onLoadShopForEdit);
    on<AddShopPage>(_onAddShopPage);
    on<UpdateShopPage>(_onUpdateShopPage);
    on<DeleteShopPage>(_onDeleteShopPage);
    on<UploadShopImage>(_onUploadShopImage);
  }

  Future<void> _onLoadShop(LoadShop event, Emitter<ShopState> emit) async {
    try {
      emit(ShopLoading());
      
      final shop = await _repository.getShop(
        shopId: event.shopId.toString(),
        userId: event.userId,
        token: event.token,
      );

      emit(ShopLoaded(shop));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ShopBloc] ❌ Error loading shop: $e');
      }
      
      if (e.toString().contains('not found')) {
        emit(ShopNotFound());
      } else {
        emit(ShopError(e.toString()));
      }
    }
  }

  Future<void> _onCreateShop(CreateShop event, Emitter<ShopState> emit) async {
    try {
      emit(ShopLoading());
      
      final response = await _repository.createShop(
        userId: event.userId,
        token: event.token,
      );

      if (response['status'] == true && response['id'] != null) {
        emit(ShopCreated(response['id']));
      } else {
        emit(ShopError(response['errors'] ?? 'Ошибка создания магазина'));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ShopBloc] ❌ Error creating shop: $e');
      }
      emit(ShopError(e.toString()));
    }
  }

  Future<void> _onUpdateShop(UpdateShop event, Emitter<ShopState> emit) async {
    try {
      emit(ShopLoading());
      
      final response = await _repository.updateShop(
        userId: event.userId,
        token: event.token,
        shopId: event.shopId,
        title: event.title,
        description: event.description,
        themeCategoryId: event.themeCategoryId,
        shopIdHash: event.shopIdHash,
        sliders: event.sliders,
        logo: event.logo,
        links: event.links,
      );

      if (response['status'] == true) {
        emit(ShopUpdated());
      } else {
        emit(ShopError(response['errors'] ?? 'Ошибка обновления магазина'));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ShopBloc] ❌ Error updating shop: $e');
      }
      emit(ShopError(e.toString()));
    }
  }

  Future<void> _onLoadShopForEdit(LoadShopForEdit event, Emitter<ShopState> emit) async {
    try {
      emit(ShopLoading());
      
      final response = await _repository.getShopData(
        userId: event.userId,
        token: event.token,
        shopId: event.shopId,
      );

      if (response['status'] == true && response['data'] != null) {
        final data = response['data'];
        final categoriesData = data['categories'] as List?;
        
        final categories = categoriesData?.map((c) => ShopCategory.fromJson(c)).toList() ?? [];
        
        emit(ShopEditDataLoaded(
          data: data,
          categories: categories,
        ));
      } else {
        emit(ShopError('Не удалось загрузить данные магазина'));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ShopBloc] ❌ Error loading shop for edit: $e');
      }
      emit(ShopError(e.toString()));
    }
  }

  Future<void> _onAddShopPage(AddShopPage event, Emitter<ShopState> emit) async {
    try {
      emit(ShopLoading());
      
      final response = await _repository.addShopPage(
        userId: event.userId,
        token: event.token,
        shopId: event.shopId,
        name: event.name,
        text: event.text,
        alias: event.alias,
      );

      if (response['status'] == true) {
        emit(ShopPageAdded());
      } else {
        emit(ShopError(response['errors'] ?? 'Ошибка добавления страницы'));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ShopBloc] ❌ Error adding shop page: $e');
      }
      emit(ShopError(e.toString()));
    }
  }

  Future<void> _onUpdateShopPage(UpdateShopPage event, Emitter<ShopState> emit) async {
    try {
      emit(ShopLoading());
      
      final response = await _repository.updateShopPage(
        userId: event.userId,
        token: event.token,
        pageId: event.pageId,
        name: event.name,
        text: event.text,
        alias: event.alias,
      );

      if (response['status'] == true) {
        emit(ShopPageUpdated());
      } else {
        emit(ShopError(response['errors'] ?? 'Ошибка обновления страницы'));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ShopBloc] ❌ Error updating shop page: $e');
      }
      emit(ShopError(e.toString()));
    }
  }

  Future<void> _onDeleteShopPage(DeleteShopPage event, Emitter<ShopState> emit) async {
    try {
      emit(ShopLoading());
      
      final response = await _repository.deleteShopPage(
        userId: event.userId,
        token: event.token,
        pageId: event.pageId,
      );

      if (response['status'] == true) {
        emit(ShopPageDeleted());
      } else {
        emit(ShopError(response['errors'] ?? 'Ошибка удаления страницы'));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ShopBloc] ❌ Error deleting shop page: $e');
      }
      emit(ShopError(e.toString()));
    }
  }

  Future<void> _onUploadShopImage(UploadShopImage event, Emitter<ShopState> emit) async {
    try {
      emit(ShopLoading());
      
      final response = await _repository.uploadTempImage(
        filePath: event.filePath,
        userId: event.userId,
        token: event.token,
      );

      if (response['name'] != null && response['link'] != null) {
        emit(ShopImageUploaded(
          imageName: response['name'],
          imageUrl: response['link'],
        ));
      } else {
        emit(ShopError('Ошибка загрузки изображения'));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ShopBloc] ❌ Error uploading image: $e');
      }
      emit(ShopError(e.toString()));
    }
  }
}
