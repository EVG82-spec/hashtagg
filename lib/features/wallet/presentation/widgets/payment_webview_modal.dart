import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

class PaymentWebViewModal extends StatefulWidget {
  final String url;
  final int orderId;
  final VoidCallback onPaymentComplete;

  const PaymentWebViewModal({
    Key? key,
    required this.url,
    required this.orderId,
    required this.onPaymentComplete,
  }) : super(key: key);

  @override
  State<PaymentWebViewModal> createState() => _PaymentWebViewModalState();
}

class _PaymentWebViewModalState extends State<PaymentWebViewModal> {
  InAppWebViewController? webViewController;
  bool _isLoading = true;
  bool _is3DSPage = false; // "Липкий" флаг для 3DS

  // 🔥 Добавляем таймер для проверки статуса
  Timer? _pollingTimer;
  bool _isCheckingStatus = false;

  @override
  void initState() {
    super.initState();
    _startPolling(); // Запускаем проверку при открытии
  }

  @override
  void dispose() {
    _pollingTimer?.cancel(); // Очищаем таймер при закрытии
    super.dispose();
  }

  // 🔥 Логика Polling'а
  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_isCheckingStatus) return;
      _isCheckingStatus = true;

      try {
        // Замените на ваш реальный домен Laravel-бэкенда
        final response = await http.get(
          Uri.parse('https://back.hashtagg.ru/systems/api/check_order_status.php?order_id=${widget.orderId}'),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'succeeded') {
            print('✅ [Polling] Оплата подтверждена сервером!');
            _pollingTimer?.cancel();
            _finishPayment();
          }
        }
      } catch (e) {
        print('⚠️ [Polling] Ошибка проверки: $e');
      } finally {
        _isCheckingStatus = false;
      }
    });
  }

  void _finishPayment() {
    widget.onPaymentComplete();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      javaScriptCanOpenWindowsAutomatically: true,
                      useShouldOverrideUrlLoading: true,
                      cacheEnabled: false,
                      userAgent: 'Mozilla/5.0 (Linux; Android 10; SM-G973F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.106 Mobile Safari/537.36',
                    ),
                    onLoadStart: (controller, url) {
                      final urlString = url?.toString() ?? '';
                      print('📍 [Start] $urlString');

                      if (_isReal3DS(urlString)) {
                        print('🔐 [3DS Detected] Скрываем лоадер');
                        setState(() {
                          _is3DSPage = true;
                          _isLoading = false;
                        });
                      } else if (!_is3DSPage) {
                        setState(() {
                          _isLoading = true;
                        });
                      }
                    },
                    onLoadStop: (controller, url) {
                      final urlString = url?.toString() ?? '';
                      print('✅ [Stop] $urlString');

                      if (_isReal3DS(urlString)) {
                        setState(() {
                          _is3DSPage = true;
                          _isLoading = false;
                        });
                      } else if (!_is3DSPage) {
                        setState(() {
                          _isLoading = false;
                        });
                      }

                      // Если вдруг редирект сработал
                      if (urlString.contains('payment/success')) {
                        _finishPayment();
                      }
                    },
                    shouldOverrideUrlLoading: (controller, navigationRequest) async {
                      final url = navigationRequest.request.url?.toString() ?? '';

                      if (url.startsWith('hashtagg://') || url.contains('payment/success')) {
                        _finishPayment();
                        return NavigationActionPolicy.CANCEL;
                      }

                      return NavigationActionPolicy.ALLOW;
                    },
                  ),
                  if (_isLoading && !_is3DSPage) _buildLoadingIndicator(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isReal3DS(String url) {
    final lower = url.toLowerCase();
    return lower.contains('acs-prod.rsb.ru') ||
        lower.contains('3ds-gate.yoomoney.ru') ||
        lower.contains('/3ds2/') ||
        lower.contains('securecode') ||
        lower.contains('auth');
  }

  // 🔥 Методы теперь ВНУТРИ класса
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Оплата', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              _pollingTimer?.cancel(); // Теперь эта переменная доступна
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(child: CircularProgressIndicator(color: Color(0xff917dfa)));
  }
}