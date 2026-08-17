import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/core/network/settings_api_repository.dart';
import 'package:hashtagg/core/models/banner.dart';

// ── События ──────────────────────────────────────────────────────────────────

abstract class BannerEvent {}

class LoadBanner extends BannerEvent {}

// ── Состояния ────────────────────────────────────────────────────────────────

abstract class BannerState {}

class BannerInitial extends BannerState {}

class BannerLoading extends BannerState {}

class BannerLoaded extends BannerState {
  final AppBanner? banner;
  final bool isEnabled;
  final List<AppBanner> promoBanners;

  BannerLoaded({
    this.banner, 
    required this.isEnabled,
    this.promoBanners = const [],
  });
}

class BannerError extends BannerState {
  final String message;

  BannerError(this.message);
}

// ── BLoC ─────────────────────────────────────────────────────────────────────

class BannerBloc extends Bloc<BannerEvent, BannerState> {
  final SettingsApiRepository _repository;

  BannerBloc({SettingsApiRepository? repository})
      : _repository = repository ?? SettingsApiRepository(),
        super(BannerInitial()) {
    on<LoadBanner>(_onLoadBanner);
  }

  Future<void> _onLoadBanner(
    LoadBanner event,
    Emitter<BannerState> emit,
  ) async {
    print('🔵 [BannerBloc] Loading banner');
    emit(BannerLoading());

    try {
      final result = await _repository.getSettings();

      if (result['status'] == true) {
        final data = result['data'];
        
        // Проверяем статус баннера в шапке
        final isEnabled = data['home_adv_header_status'] == true;
        
        AppBanner? banner;
        if (isEnabled && data['home_adv_header'] != null) {
          banner = AppBanner.fromJson(data['home_adv_header']);
          print('✅ [BannerBloc] Banner loaded: ${banner.image}');
        } else {
          print('⚠️ [BannerBloc] Banner is disabled or not configured');
        }
        
        // Загружаем промо-баннеры
        List<AppBanner> promoBanners = [];
        if (data['home_promo_banner_list'] != null && data['home_promo_banner_list'] is List) {
          promoBanners = (data['home_promo_banner_list'] as List)
              .map((item) => AppBanner.fromJson(item))
              .toList();
          print('✅ [BannerBloc] Loaded ${promoBanners.length} promo banners');
        }
        
        emit(BannerLoaded(
          banner: banner, 
          isEnabled: isEnabled,
          promoBanners: promoBanners,
        ));
      } else {
        print('🔴 [BannerBloc] Failed to load banner: ${result['error']}');
        emit(BannerError(result['error'] ?? 'Не удалось загрузить баннер'));
      }
    } catch (e, stackTrace) {
      print('🔴 [BannerBloc] Banner error: $e');
      print('🔴 [BannerBloc] Stack trace: $stackTrace');
      emit(BannerError('Ошибка загрузки баннера: $e'));
    }
  }
}
