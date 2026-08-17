import 'package:hashtagg/data/models/listing_model.dart';
import 'package:hashtagg/data/repositories/base_repository.dart';

class FavoritesRepository extends BaseRepository {
  Future<bool> toggleFavorite(int adId) async {
    final response = await post('favorite/actionFavorite', data: {'id_ad': adId});
    return response['action'] == 'added';
  }

  Future<List<ListingModel>> getFavorites() async {
    final response = await get('profile/favorites/getFavorites');
    final List<dynamic> data = response ?? [];
    return data.map((json) => ListingModel.fromJson(json)).toList();
  }
}