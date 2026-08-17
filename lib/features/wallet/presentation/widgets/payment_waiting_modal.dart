import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:app_links/app_links.dart';

class PaymentWaitingModal extends StatefulWidget {
  final int orderId;
  final VoidCallback onPaymentComplete;

  const PaymentWaitingModal({
    Key? key,
    required this.orderId,
    required this.onPaymentComplete,
  }) : super(key: key);

  @override
  State<PaymentWaitingModal> createState() => _PaymentWaitingModalState();
}

class _PaymentWaitingModalState extends State<PaymentWaitingModal> {
  Timer? _pollingTimer;
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    print('🚀 [PaymentWaitingModal] initState ЗАПУЩЕН! orderId = ${widget.orderId}');
    _initDeepLinks();
    _startPolling();
  }

  @override
  void dispose() {
    print('🛑 [PaymentWaitingModal] dispose вызван, очищаем таймеры');
    _pollingTimer?.cancel();
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initDeepLinks() {
    print('🔗 [PaymentWaitingModal] Инициализация Deep Links...');
    _appLinks = AppLinks();

    _linkSubscription = _appLinks!.uriLinkStream.listen((uri) {
      print('📥 [PaymentWaitingModal] Получен URI: $uri');
      if (uri.scheme == 'hashtagg' && uri.host == 'payment') {
        print('🚀 [DeepLink] Поймали возврат из браузера! Закрываем окно.');
        _finishPayment();
      }
    });

    _appLinks!.getInitialLink().then((uri) {
      if (uri != null && uri.scheme == 'hashtagg' && uri.host == 'payment') {
        print('🚀 [DeepLink] Поймали холодный старт по ссылке! Закрываем окно.');
        _finishPayment();
      }
    });
  }

  void _startPolling() {
    print('⏱️ [PaymentWaitingModal] Таймер запущен! Будем стучаться каждые 3 сек.');

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      print('🔄 [Polling] Тик таймера! Проверяем статус заказа ${widget.orderId}...');

      if (_isChecking) {
        print('⏳ [Polling] Предыдущий запрос еще идет, пропускаем этот тик.');
        return;
      }
      _isChecking = true;

      try {
        final url = 'https://hashtagg.ru/systems/payment/yookassa/check_order_status.php?order_id=${widget.orderId}';
        print('🌐 [Polling] Делаем GET запрос: $url');

        final response = await http.get(Uri.parse(url));
        print('📥 [Polling] Ответ сервера: ${response.statusCode} - ${response.body}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'succeeded') {
            print('✅ [Polling] Сервер подтвердил оплату (succeeded)! Закрываем окно.');
            _finishPayment();
          } else {
            print('⏳ [Polling] Статус пока не succeeded: ${data['status']}');
          }
        } else {
          print('⚠️ [Polling] Ошибка HTTP: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ [Polling] КРИТИЧЕСКАЯ ОШИБКА в try-catch: $e');
      } finally {
        _isChecking = false;
      }
    });
  }

  void _finishPayment() {
    print('🏁 [PaymentWaitingModal] _finishPayment вызван!');
    _pollingTimer?.cancel();
    _linkSubscription?.cancel();
    widget.onPaymentComplete();
    if (mounted) {
      print('🏁 [PaymentWaitingModal] Navigator.pop(context)');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xff917dfa)),
            const SizedBox(height: 24),
            const Text(
              'Ожидаем подтверждения',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Завершите оплату в открывшемся браузере.\nОкно закроется автоматически.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () {
                print('❌ [PaymentWaitingModal] Пользователь нажал Отменить');
                _pollingTimer?.cancel();
                _linkSubscription?.cancel();
                Navigator.pop(context);
              },
              child: const Text('Отменить и закрыть', style: TextStyle(color: Colors.red)),
            )
          ],
        ),
      ),
    );
  }
}