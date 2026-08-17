import 'package:hashtagg/data/repositories/base_repository.dart';

class ChatRepository extends BaseRepository {
  Future<List<Map<String, dynamic>>> getDialogs() async {
    final response = await get('profile/chat/getUsers');
    return response['dialogs'] ?? [];
  }

  Future<Map<String, dynamic>> getDialog(String hash) async {
    final response = await get('profile/chat/getDialog', queryParameters: {'id': hash});
    return response;
  }

  Future<void> sendMessage(String hash, String text) async {
    await post('profile/chat/sendMessage', data: {
      'id': hash,
      'text': text,
    });
  }

  Future<void> deleteDialog(String hash) async {
    await post('profile/chat/deleteDialog', data: {'id': hash});
  }
}