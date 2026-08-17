import 'package:hashtagg/data/models/listing_model.dart';
import 'package:hashtagg/data/repositories/base_repository.dart';

class ListingRepository extends BaseRepository {
  Future<List<ListingModel>> getAds({
    int? page,
    int? cityId,
    int? regionId,
    int? countryId,
    int? catId,
    String? search,
    bool? recommendations,
    bool? fresh,
    bool? auction,
  }) async {
    final response = await get('ads/getAds', queryParameters: {
      if (page != null) 'page': page,
      if (cityId != null) 'city_id': cityId,
      if (regionId != null) 'region_id': regionId,
      if (countryId != null) 'country_id': countryId,
      if (catId != null) 'cat_id': catId,
      if (search != null && search.isNotEmpty) 'search': search,
      if (recommendations != null) 'recommendations': recommendations,
      if (fresh != null) 'fresh': fresh,
      if (auction != null) 'auction': auction,
    });

    final List<dynamic> data = response['data'] ?? [];
    return data.map((json) => ListingModel.fromJson(json)).toList();
  }

  Future<ListingModel> getAdById(int id) async {
    final response = await get('card_ad/getCard', queryParameters: {'id': id});
    return ListingModel.fromJson(response);
  }
}