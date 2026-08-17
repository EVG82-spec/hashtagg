import 'package:hashtagg/data/models/user_model.dart';
import 'package:hashtagg/data/repositories/base_repository.dart';

class SubscriptionsRepository extends BaseRepository {
  Future<bool> toggleSubscription(int userId) async {
    final response = await post('card_user/subscribe', data: {
      'id_user_to': userId,
    });
    return response['status'] == 'added';
  }

  Future<List<UserModel>> getSubscriptions() async {
    final response = await get('profile/subscriptions/getSubscriptions');
    final List<dynamic> data = response ?? [];
    return data.map((json) => UserModel.fromJson(json)).toList();
  }
}