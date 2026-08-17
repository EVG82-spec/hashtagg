import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/shared/domain/entities/chat.dart';
import 'package:hashtagg/core/network/chat_api_repository.dart';
import 'package:hashtagg/core/network/dio_client.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hive/hive.dart';

import 'package:hashtagg/core/services/unread_messages_bloc.dart' as unread;

// Events
abstract class ChatEvent {}

class LoadDialogs extends ChatEvent {}

class LoadDialog extends ChatEvent {
  final String dialogId;
  final int? adId;
  final int? userToId;
  final bool isSupport;

  LoadDialog({
    required this.dialogId,
    this.adId,
    this.userToId,
    this.isSupport = false,
  });
}

class SendMessage extends ChatEvent {
  final String dialogId;
  final String text;
  final List<String>? attachments;
  final bool isSupport;

  SendMessage({
    required this.dialogId,
    required this.text,
    this.attachments,
    this.isSupport = false,
  });
}

class UpdateDialog extends ChatEvent {
  final String dialogId;
  final bool isSupport;

  UpdateDialog({
    required this.dialogId,
    this.isSupport = false,
  });
}

class DeleteDialog extends ChatEvent {
  final String dialogId;

  DeleteDialog(this.dialogId);
}

class ClearAllDialogs extends ChatEvent {}

class LoadUnreadCount extends ChatEvent {}

class BlockUser extends ChatEvent {
  final int userToId;

  BlockUser(this.userToId);
}

class ReportUser extends ChatEvent {
  final int userToId;
  final String text;

  ReportUser({
    required this.userToId,
    required this.text,
  });
}

class MessageReceivedFromSocket extends ChatEvent {
  final Map<String, dynamic> data;
  MessageReceivedFromSocket(this.data);
}

class CloseDialog extends ChatEvent {}

// State
class ChatState {
  final List<ChatDialog> dialogs;
  final ChatDialogFull? currentDialog;
  final ChatSupport? support;
  final int unreadCount;
  final bool isLoading;
  final bool isSending;
  final String? error;

  static String? currentOpenDialogId;

  ChatState({
    this.dialogs = const [],
    this.currentDialog,
    this.support,
    this.unreadCount = 0,
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatDialog>? dialogs,
    ChatDialogFull? currentDialog,
    ChatSupport? support,
    int? unreadCount,
    bool? isLoading,
    bool? isSending,
    String? error,
    bool clearCurrentDialog = false,
  }) {
    return ChatState(
      dialogs: dialogs ?? this.dialogs,
      currentDialog: clearCurrentDialog ? null : (currentDialog ?? this.currentDialog),
      support: support ?? this.support,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }
}

// BLoC
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  late ChatApiRepository _apiRepository;
  final AuthBloc? _authBloc;
  final unread.UnreadMessagesBloc? _unreadBloc;
  StreamSubscription? _authSubscription;

  static String? currentOpenDialogId;

  ChatBloc({AuthBloc? authBloc, unread.UnreadMessagesBloc? unreadBloc})
      : _authBloc = authBloc,
        _unreadBloc = unreadBloc,
        super(ChatState()) {
    _updateRepository();

    // Подписываемся на изменения AuthBloc
    _authSubscription = _authBloc?.stream.listen((authState) {
      if (kDebugMode) {
        debugPrint('🔵 [ChatBloc] Auth state changed, updating repository...');
      }
      _updateRepository();
    });

    on<LoadDialogs>(_onLoadDialogs);
    on<LoadDialog>(_onLoadDialog);
    on<SendMessage>(_onSendMessage);
    on<UpdateDialog>(_onUpdateDialog);
    on<DeleteDialog>(_onDeleteDialog);
    on<ClearAllDialogs>(_onClearAllDialogs);
    on<LoadUnreadCount>(_onLoadUnreadCount);
    on<BlockUser>(_onBlockUser);
    on<ReportUser>(_onReportUser);
    on<MessageReceivedFromSocket>(_onMessageReceivedFromSocket);
    on<CloseDialog>(_onCloseDialog);
  }

  Future<void> _onCloseDialog(CloseDialog event, Emitter<ChatState> emit) async {
    ChatBloc.currentOpenDialogId = null;
    emit(state.copyWith(clearCurrentDialog: true));
  }


  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }

  void _updateRepository() {
    final user = _authBloc?.state.user;
    final box = Hive.box('user');
    final token = box.get('auth_token') as String?;
    
    if (kDebugMode) {
      debugPrint('🔵 [ChatBloc] Updating repository - userId: ${user?.id}, token: ${token != null ? token.substring(0, 10) + '...' : 'NULL'}');
    }
    
    _apiRepository = ChatApiRepository(
      DioClient.createDio(),
      userId: user?.id,
      token: token,
    );
  }

  Future<void> _onLoadDialogs(
    LoadDialogs event,
    Emitter<ChatState> emit,
  ) async {
    print('🔵 [ChatBloc] Loading dialogs...');
    emit(state.copyWith(isLoading: true));

    final result = await _apiRepository.getDialogs();

    if (result.success && result.data != null) {
      final data = result.data!;
      final dialogs = data['dialogs'] != null
          ? (data['dialogs'] as List)
              .map((d) => ChatDialog.fromJson(d))
              .toList()
          : <ChatDialog>[];

      final support = data['support'] != null
          ? ChatSupport.fromJson(data['support'])
          : null;

      print('✅ [ChatBloc] Loaded ${dialogs.length} dialogs');
      emit(state.copyWith(
        dialogs: dialogs,
        support: support,
        isLoading: false,
      ));
    } else {
      print('🔴 [ChatBloc] Failed to load dialogs: ${result.error}');
      emit(state.copyWith(
        isLoading: false,
        error: result.error,
      ));
    }
  }

  Future<void> _onLoadDialog(
    LoadDialog event,
    Emitter<ChatState> emit,
  ) async {
    print('🔵 [ChatBloc] Loading dialog: ${event.dialogId}');
    emit(state.copyWith(isLoading: true));

    ChatBloc.currentOpenDialogId = event.dialogId;

    final result = await _apiRepository.getDialog(
      dialogId: event.dialogId,
      adId: event.adId,
      userToId: event.userToId,
      isSupport: event.isSupport,
    );

    if (result.success && result.data != null) {
      final dialog = ChatDialogFull.fromJson(result.data!);
      print('✅ [ChatBloc] Dialog loaded with ${dialog.messages.length} messages');
      emit(state.copyWith(
        currentDialog: dialog,
        isLoading: false,
      ));
    } else {
      print('🔴 [ChatBloc] Failed to load dialog: ${result.error}');
      emit(state.copyWith(
        isLoading: false,
        error: result.error,
      ));
    }
  }

  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<ChatState> emit,
  ) async {
    print('🔵 [ChatBloc] Sending message...');
    print('🔵 [ChatBloc] Event attachments: ${event.attachments}');
    emit(state.copyWith(isSending: true));

    final result = await _apiRepository.sendMessage(
      dialogId: event.dialogId,
      text: event.text,
      attachments: event.attachments,
      isSupport: event.isSupport,
    );

    if (result.success) {
      print('✅ [ChatBloc] Message sent');
      
      // Reload dialog to get updated messages
      add(LoadDialog(
        dialogId: event.dialogId,
        isSupport: event.isSupport,
      ));
      
      emit(state.copyWith(isSending: false));
    } else {
      print('🔴 [ChatBloc] Failed to send message: ${result.error}');
      emit(state.copyWith(
        isSending: false,
        error: result.error,
      ));
    }
  }

  Future<void> _onUpdateDialog(
    UpdateDialog event,
    Emitter<ChatState> emit,
  ) async {
    final result = await _apiRepository.updateDialog(
      dialogId: event.dialogId,
      isSupport: event.isSupport,
    );

    if (result.success && result.data != null) {
      final data = result.data!;
      final newMessages = data['messages'] != null
          ? (data['messages'] as List)
              .map((m) => ChatMessage.fromJson(m))
              .toList()
          : <ChatMessage>[];

      if (newMessages.isNotEmpty && state.currentDialog != null) {
        final updatedDialog = ChatDialogFull(
          idHash: state.currentDialog!.idHash,
          messages: [...state.currentDialog!.messages, ...newMessages],
          user: state.currentDialog!.user,
          ad: state.currentDialog!.ad,
          blockedSend: data['blocked_send'] == true,
          blockedUser: data['blocked_user'] == true,
        );

        emit(state.copyWith(currentDialog: updatedDialog));
      }
    }
  }

  Future<void> _onDeleteDialog(
    DeleteDialog event,
    Emitter<ChatState> emit,
  ) async {
    print('🔵 [ChatBloc] Deleting dialog: ${event.dialogId}');

    final result = await _apiRepository.deleteDialog(event.dialogId);

    if (result.success) {
      print('✅ [ChatBloc] Dialog deleted');
      
      // Remove from local list
      final updatedDialogs = state.dialogs
          .where((d) => d.id != event.dialogId)
          .toList();

      emit(state.copyWith(
        dialogs: updatedDialogs,
        clearCurrentDialog: true,
      ));
    } else {
      print('🔴 [ChatBloc] Failed to delete dialog: ${result.error}');
      emit(state.copyWith(error: result.error));
    }
  }

  Future<void> _onClearAllDialogs(
    ClearAllDialogs event,
    Emitter<ChatState> emit,
  ) async {
    print('🔵 [ChatBloc] Clearing all dialogs...');

    final result = await _apiRepository.clearAllDialogs();

    if (result.success) {
      print('✅ [ChatBloc] All dialogs cleared');
      emit(state.copyWith(
        dialogs: [],
        clearCurrentDialog: true,
      ));
    } else {
      print('🔴 [ChatBloc] Failed to clear dialogs: ${result.error}');
      emit(state.copyWith(error: result.error));
    }
  }

  Future<void> _onLoadUnreadCount(
    LoadUnreadCount event,
    Emitter<ChatState> emit,
  ) async {
    final result = await _apiRepository.getUnreadCount();

    if (result.success && result.data != null) {
      emit(state.copyWith(unreadCount: result.data!));
    }
  }

  Future<void> _onBlockUser(
    BlockUser event,
    Emitter<ChatState> emit,
  ) async {
    print('🔵 [ChatBloc] Toggling block for user: ${event.userToId}');

    final result = await _apiRepository.blockUser(event.userToId);

    if (result.success) {
      final status = result.data;
      print('✅ [ChatBloc] Block status: $status');
      
      // Обновляем текущий диалог
      if (state.currentDialog != null) {
        final isBlocked = status == 'added';
        final updatedDialog = ChatDialogFull(
          idHash: state.currentDialog!.idHash,
          messages: state.currentDialog!.messages,
          user: state.currentDialog!.user,
          ad: state.currentDialog!.ad,
          blockedSend: state.currentDialog!.blockedSend,
          blockedUser: isBlocked,
        );
        
        emit(state.copyWith(currentDialog: updatedDialog));
      }
    } else {
      print('🔴 [ChatBloc] Failed to toggle block: ${result.error}');
      emit(state.copyWith(error: result.error));
    }
  }

  // Метод для загрузки файла (вызывается напрямую из UI)
  Future<ApiResult<Map<String, dynamic>>> uploadChatFile(String base64Data) async {
    return await _apiRepository.uploadChatFile(base64Data);
  }

  Future<void> _onReportUser(
    ReportUser event,
    Emitter<ChatState> emit,
  ) async {
    print('🔵 [ChatBloc] Reporting user: ${event.userToId}');

    final result = await _apiRepository.reportUser(
      userToId: event.userToId,
      text: event.text,
    );

    if (result.success) {
      print('✅ [ChatBloc] User reported: ${result.data}');
      emit(state.copyWith(error: null));
    } else {
      print('🔴 [ChatBloc] Failed to report user: ${result.error}');
      emit(state.copyWith(error: result.error));
    }
  }

  Future<void> _onMessageReceivedFromSocket(
    MessageReceivedFromSocket event,
    Emitter<ChatState> emit,
  ) async {
    final data = event.data;
    final dialogId = data['dialog_id'] as String?;
    if (dialogId == null) return;

    final isSupport = data['is_support'] == true;
    final fromUserId = data['from_user_id'] as int?;
    final fromUserName = data['from_user_name'] as String? ?? '';
    final message = data['message'] as String? ?? '';
    final now = DateTime.now();
    final timestamp = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final currentUserId = _authBloc?.state.user?.id;
    if (fromUserId == currentUserId) return;

    final isCurrentDialog = state.currentDialog != null && state.currentDialog!.idHash == dialogId;

    // 1. Диалог открыт – добавляем сообщение и делаем фоновый getDialog
    if (isCurrentDialog) {
      final newMessage = ChatMessage(
        action: 'message',
        text: message,
        date: timestamp,
        align: 'left',
        user: ChatUser(name: fromUserName, id: fromUserId),
      );
      final updatedMessages = [...state.currentDialog!.messages, newMessage];
      emit(state.copyWith(
        currentDialog: ChatDialogFull(
          idHash: state.currentDialog!.idHash,
          messages: updatedMessages,
          user: state.currentDialog!.user,
          ad: state.currentDialog!.ad,
          blockedSend: state.currentDialog!.blockedSend,
          blockedUser: state.currentDialog!.blockedUser,
        ),
      ));

      // Фоновый запрос getDialog, чтобы сервер пометил сообщения прочитанными
      _apiRepository.getDialog(dialogId: dialogId, isSupport: isSupport)
        .then((result) {
          if (result.success && _unreadBloc != null) {
            _unreadBloc!.add(unread.LoadUnreadCount());
          }
        }).catchError((e) {
          print('❌ [ChatBloc] Background getDialog failed: $e');
        });

      // Обновляем список диалогов без увеличения счётчика
      if (!isSupport) {
        final dialogs = List<ChatDialog>.from(state.dialogs);
        final index = dialogs.indexWhere((d) => d.id == dialogId);
        if (index != -1) {
          final existing = dialogs[index];
          dialogs[index] = ChatDialog(
            id: existing.id,
            view: existing.view,
            title: existing.title,
            text: message,
            date: timestamp,
            image: existing.image,
            countMessages: existing.countMessages,
            statusLastMessage: 1,
            user: existing.user,
            ad: existing.ad,
          );
          emit(state.copyWith(dialogs: dialogs));
        }
      }
      return;
    }

    // 2. Диалог НЕ открыт – увеличиваем счётчик непрочитанных
    if (isSupport) {
      final support = state.support;
      if (support != null) {
        final updatedSupport = ChatSupport(
          title1: support.title1,
          title2: support.title2,
          image: support.image,
          countMessages: support.countMessages + 1,
        );
        emit(state.copyWith(support: updatedSupport));
      } else {
        add(LoadDialogs());
      }
      _incrementUnread();
    } else {
      final dialogs = List<ChatDialog>.from(state.dialogs);
      final index = dialogs.indexWhere((d) => d.id == dialogId);
      if (index != -1) {
        final existing = dialogs[index];
        dialogs[index] = ChatDialog(
          id: existing.id,
          view: existing.view,
          title: existing.title,
          text: message,
          date: timestamp,
          image: existing.image,
          countMessages: existing.countMessages + 1,
          statusLastMessage: 0,
          user: existing.user,
          ad: existing.ad,
        );
        emit(state.copyWith(dialogs: dialogs));
        _incrementUnread();
      } else {
        _incrementUnread();
      }
    }
  }


void _incrementUnread() {
  _unreadBloc?.add(unread.IncrementUnreadCount());
}


}
