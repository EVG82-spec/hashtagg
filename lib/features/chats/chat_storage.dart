import 'package:hive/hive.dart';

class StoredDialog {
  final String id;
  final String userName;
  final String lastMessage;
  final String time;
  final String? avatarUrl;
  final String listingTitle;
  final String listingPrice;
  final String listingStatus;
  final String? listingImageUrl;

  StoredDialog({
    required this.id,
    required this.userName,
    required this.lastMessage,
    required this.time,
    this.avatarUrl,
    required this.listingTitle,
    required this.listingPrice,
    required this.listingStatus,
    this.listingImageUrl,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userName': userName,
        'lastMessage': lastMessage,
        'time': time,
        'avatarUrl': avatarUrl,
        'listingTitle': listingTitle,
        'listingPrice': listingPrice,
        'listingStatus': listingStatus,
        'listingImageUrl': listingImageUrl,
      };

  factory StoredDialog.fromMap(Map<dynamic, dynamic> map) => StoredDialog(
        id: map['id'] as String,
        userName: map['userName'] as String,
        lastMessage: map['lastMessage'] as String,
        time: map['time'] as String,
        avatarUrl: map['avatarUrl'] as String?,
        listingTitle: map['listingTitle'] as String,
        listingPrice: map['listingPrice'] as String,
        listingStatus: map['listingStatus'] as String,
        listingImageUrl: map['listingImageUrl'] as String?,
      );
}

class StoredMessage {
  final String id;
  final String dialogId;
  final String text;
  final String time;
  final bool isOutgoing;

  StoredMessage({
    required this.id,
    required this.dialogId,
    required this.text,
    required this.time,
    required this.isOutgoing,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'dialogId': dialogId,
        'text': text,
        'time': time,
        'isOutgoing': isOutgoing,
      };

  factory StoredMessage.fromMap(Map<dynamic, dynamic> map) => StoredMessage(
        id: map['id'] as String,
        dialogId: map['dialogId'] as String,
        text: map['text'] as String,
        time: map['time'] as String,
        isOutgoing: map['isOutgoing'] as bool,
      );
}

class ChatStorageService {
  static final ChatStorageService _instance = ChatStorageService._internal();
  factory ChatStorageService() => _instance;
  ChatStorageService._internal();

  static const _dialogsBox = 'chats';
  static const _messagesBox = 'chat_messages';

  Box get _dialogs => Hive.box(_dialogsBox);
  Box get _messages => Hive.box(_messagesBox);

  static Future<void> initialize() async {
    if (!Hive.isBoxOpen(_dialogsBox)) await Hive.openBox(_dialogsBox);
    if (!Hive.isBoxOpen(_messagesBox)) await Hive.openBox(_messagesBox);
  }

  Future<void> saveDialog(StoredDialog dialog) async {
    await _dialogs.put(dialog.id, dialog.toMap());
  }

  List<StoredDialog> getDialogs() {
    return _dialogs.values
        .map((v) => StoredDialog.fromMap(v as Map))
        .toList();
  }

  StoredDialog? getDialog(String id) {
    final v = _dialogs.get(id);
    return v != null ? StoredDialog.fromMap(v as Map) : null;
  }

  Future<void> deleteDialog(String id) async {
    await _dialogs.delete(id);
    await deleteMessagesForDialog(id);
  }

  Future<void> saveMessage(StoredMessage message) async {
    await _messages.put(message.id, message.toMap());
  }

  List<StoredMessage> getMessagesForDialog(String dialogId) {
    return _messages.values
        .where((v) => (v as Map)['dialogId'] == dialogId)
        .map((v) => StoredMessage.fromMap(v as Map))
        .toList();
  }

  Future<void> deleteMessagesForDialog(String dialogId) async {
    final keys = _messages.keys
        .where((k) => (_messages.get(k) as Map)['dialogId'] == dialogId)
        .toList();
    await _messages.deleteAll(keys);
  }

  Future<void> clearAll() async {
    await _dialogs.clear();
    await _messages.clear();
  }
}
