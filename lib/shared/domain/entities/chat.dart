/// Модель диалога
import 'package:hashtagg/core/network/api_config.dart';

class ChatDialog {
  final String id;
  final String view; // 'ad' или 'user'
  final String title;
  final String? text;
  final String date;
  final String? image;
  final int countMessages;
  final int? statusLastMessage; // 0 - не прочитано, 1 - прочитано
  final ChatUser? user;
  final ChatAd? ad;

  ChatDialog({
    required this.id,
    required this.view,
    required this.title,
    this.text,
    required this.date,
    this.image,
    required this.countMessages,
    this.statusLastMessage,
    this.user,
    this.ad,
  });

  factory ChatDialog.fromJson(Map<String, dynamic> json) {
    String? image = json['image']?.toString();
    // Заменяем localhost на настроенный mediaUrl
    if (image != null) {
      image = ApiConfig.replaceMediaUrl(image);
    }
    
    return ChatDialog(
      id: json['id']?.toString() ?? '',
      view: json['view']?.toString() ?? 'user',
      title: json['title']?.toString() ?? '',
      text: json['text']?.toString(),
      date: ChatMessage.formatTime(json['date']?.toString() ?? ''),
      image: image,
      countMessages: _parseInt(json['countMessages']),
      statusLastMessage: json['status_last_message'] != null 
          ? _parseInt(json['status_last_message']) 
          : null,
      user: json['user'] != null 
          ? ChatUser.fromJson(json['user']) 
          : null,
      ad: json['ad'] != null 
          ? ChatAd.fromJson(json['ad']) 
          : null,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// Модель пользователя в чате
class ChatUser {
  final String name;
  final String? avatar;
  final int? id;
  final String? statusOnline;
  final bool? isShop;

  ChatUser({
    required this.name,
    this.avatar,
    this.id,
    this.statusOnline,
    this.isShop,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    String? avatar = json['avatar']?.toString();
    // Заменяем localhost на настроенный mediaUrl
    if (avatar != null) {
      avatar = ApiConfig.replaceMediaUrl(avatar);
    }
    
    return ChatUser(
      name: json['name']?.toString() ?? '',
      avatar: avatar,
      id: json['id'] != null ? _parseInt(json['id']) : null,
      statusOnline: json['statusOnline']?.toString(),
      isShop: json['is_shop'] == true,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class ChatAd {
  final int id;
  final String title;
  final String? image;
  final String? price;
  final String? status;
  final String? statusName;
  final int? catId;

  ChatAd({
    required this.id,
    required this.title,
    this.image,
    this.price,
    this.status,
    this.statusName,
    this.catId,
  });

  factory ChatAd.fromJson(Map<String, dynamic> json) {
    String? image = json['image']?.toString();
    if (image != null) {
      image = ApiConfig.replaceMediaUrl(image);
    }
    
    return ChatAd(
      id: _parseInt(json['id']),
      title: json['title']?.toString() ?? '',
      image: image,
      price: json['price'] is Map 
          ? json['price']['now']?.toString() 
          : json['price']?.toString(),
      status: json['status']?.toString(),
      statusName: json['status_name']?.toString(),
      catId: json['cat_id'] != null ? _parseInt(json['cat_id']) : null,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class ChatMessage {
  final String action; // 'message', 'date', 'notification'
  final String? text;
  final String? date;
  final String? align; // 'left', 'right'
  final ChatUser? user;
  final List<String>? attach;
  final String? image;

  ChatMessage({
    required this.action,
    this.text,
    this.date,
    this.align,
    this.user,
    this.attach,
    this.image,
  });

  static String formatTime(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '';

    // Если это дата-разделитель вида "31.03.2026" – не трогаем
    if (RegExp(r'^\d{2}\.\d{2}\.\d{4}$').hasMatch(rawDate)) return rawDate;

    // Ищем первое вхождение HH:mm
    final timeMatch = RegExp(r'(\d{2}):(\d{2})').firstMatch(rawDate);
    if (timeMatch == null) return rawDate;

    final hour = int.parse(timeMatch.group(1)!);
    final minute = int.parse(timeMatch.group(2)!);

    // Конвертируем московское время (UTC+3) в локальное
    final nowUtc = DateTime.now().toUtc();
    final moscowAsUtc = DateTime.utc(
      nowUtc.year, nowUtc.month, nowUtc.day,
      hour - 3, minute,
    );
    final local = moscowAsUtc.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }



  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    List<String>? attach;
    if (json['attach'] != null) {
      attach = List<String>.from(json['attach']).map((url) {
        return ApiConfig.replaceMediaUrl(url);
      }).toList();
    }
    
    String? image = json['image']?.toString();
    if (image != null) {
      image = ApiConfig.replaceMediaUrl(image);
    }
    
    return ChatMessage(
      action: json['action']?.toString() ?? 'message',
      text: json['text']?.toString(),
      date: formatTime(json['date']?.toString()),
      align: json['align']?.toString(),
      user: json['user'] != null 
          ? ChatUser.fromJson(json['user']) 
          : null,
      attach: attach,
      image: image,
    );
  }

  bool get isOutgoing => align == 'right';
  bool get isIncoming => align == 'left';
  bool get isDate => action == 'date';
  bool get isNotification => action == 'notification';
}

class ChatDialogFull {
  final String idHash;
  final List<ChatMessage> messages;
  final ChatUser? user;
  final ChatAd? ad;
  final bool blockedSend;
  final bool blockedUser;

  ChatDialogFull({
    required this.idHash,
    required this.messages,
    this.user,
    this.ad,
    required this.blockedSend,
    required this.blockedUser,
  });

  factory ChatDialogFull.fromJson(Map<String, dynamic> json) {
    return ChatDialogFull(
      idHash: json['id_hash']?.toString() ?? '',
      messages: json['dialog'] != null
          ? (json['dialog'] as List)
              .map((m) => ChatMessage.fromJson(m))
              .toList()
          : [],
      user: json['user'] != null 
          ? ChatUser.fromJson(json['user']) 
          : null,
      ad: json['ad'] != null 
          ? ChatAd.fromJson(json['ad']) 
          : null,
      blockedSend: json['blocked_send'] == true,
      blockedUser: json['blocked_user'] == true,
    );
  }
}

class ChatSupport {
  final String title1;
  final String title2;
  final String image;
  final int countMessages;

  ChatSupport({
    required this.title1,
    required this.title2,
    required this.image,
    required this.countMessages,
  });

  factory ChatSupport.fromJson(Map<String, dynamic> json) {
    return ChatSupport(
      title1: json['title1']?.toString() ?? 'Поддержка',
      title2: json['title2']?.toString() ?? 'Будем рады помочь',
      image: json['image']?.toString() ?? '',
      countMessages: _parseInt(json['countMessages']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
