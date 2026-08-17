import 'package:hashtagg/shared/domain/services/listing_service.dart';

class FavoriteUseCase {
  final ListingService _listingService;
  FavoriteUseCase(this._listingService);

  void execute(int id) {
    return _listingService.favorite(id);
  }
}