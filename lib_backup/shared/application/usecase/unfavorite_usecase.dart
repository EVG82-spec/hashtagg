import 'package:hashtagg/shared/domain/services/listing_service.dart';

class UnfavoriteUseCase {
  final ListingService _listingService;
  UnfavoriteUseCase(this._listingService);

  void execute(int id) {
    return _listingService.unfavorite(id);
  }
}