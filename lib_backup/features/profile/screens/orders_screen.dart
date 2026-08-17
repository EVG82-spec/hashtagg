import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/network/orders_api_repository.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OrdersApiRepository _ordersApi = OrdersApiRepository();

  final List<String> _tabs = ['Покупки', 'Продажи', 'Бронирование/Аренда'];
  
  bool _isLoading = true;
  List<dynamic> _buyOrders = [];
  List<dynamic> _sellOrders = [];
  List<dynamic> _bookingOrders = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    try {
      final box = Hive.box('user');
      final token = box.get('auth_token') as String?;
      final userData = box.get('user') as Map?;
      
      if (token == null || userData == null) {
        print('🔴 [OrdersScreen] No token or userData found');
        setState(() => _isLoading = false);
        return;
      }

      // Безопасное преобразование userId
      final userId = userData['id'] is int 
          ? userData['id'] as int
          : int.parse(userData['id'].toString());

      print('🔵 [OrdersScreen] Loading orders for user: $userId');

      final result = await _ordersApi.getOrders(
        userId: userId,
        token: token,
      );

      if (result['status'] == true) {
        setState(() {
          _buyOrders = result['buy'] ?? [];
          _sellOrders = result['sell'] ?? [];
          _bookingOrders = result['booking'] ?? [];
          _isLoading = false;
        });
        print('✅ [OrdersScreen] Loaded ${_buyOrders.length} buy, ${_sellOrders.length} sell, ${_bookingOrders.length} booking orders');
      } else {
        print('🔴 [OrdersScreen] Failed to load orders: ${result['error']}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('🔴 [OrdersScreen] Error loading orders: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Заказы',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: const Color(0xff917dfa),
              indicatorWeight: 3,
              labelColor: isDark ? Colors.white : Colors.black,
              unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
              labelStyle: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              unselectedLabelStyle: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              tabs: [
                Tab(text: '${_tabs[0]} ${_buyOrders.length}'),
                Tab(text: '${_tabs[1]} ${_sellOrders.length}'),
                Tab(text: '${_tabs[2]} ${_bookingOrders.length}'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xff917dfa)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersList(_buyOrders, 'Покупок пока нет'),
                _buildOrdersList(_sellOrders, 'Продаж пока нет'),
                _buildOrdersList(_bookingOrders, 'Бронирований пока нет'),
              ],
            ),
    );
  }

  Widget _buildOrdersList(List<dynamic> orders, String emptyLabel) {
    if (orders.isEmpty) {
      return _EmptyTab(label: emptyLabel);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _OrderCard(order: order);
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = order['date'] ?? '';
    final statusName = order['status_name'] ?? '';
    final orderId = order['order_id'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff233040) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.transparent : const Color(0xffEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Заказ #$orderId',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xff917dfa).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusName,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xff917dfa),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Color(0xffAAAAAA)),
              const SizedBox(width: 6),
              Text(
                date,
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  color: const Color(0xffAAAAAA),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final String label;
  const _EmptyTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Color(0xff917dfa).withValues(alpha: 0.325),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_search_outlined,
              size: 60,
              color: Color(0xff917dfa),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 15,
              color: const Color(0xffAAAAAA),
            ),
          ),
        ],
      ),
    );
  }
}
