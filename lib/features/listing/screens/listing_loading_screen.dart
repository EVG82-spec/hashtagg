import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hashtagg/core/network/listing_api_repository.dart';
import 'package:hashtagg/core/network/dio_client.dart';
import 'package:hashtagg/shared/domain/entities/listing.dart';
import 'package:hashtagg/shared/presentation/bloc/listing_bloc.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'listing_screen.dart';

/// Промежуточный экран загрузки объявления
class ListingLoadingScreen extends StatefulWidget {
  final String itemId;

  const ListingLoadingScreen({super.key, required this.itemId});

  @override
  State<ListingLoadingScreen> createState() => _ListingLoadingScreenState();
}

class _ListingLoadingScreenState extends State<ListingLoadingScreen> {
  late Future<ApiResult<Listing>> _loadingFuture;

  @override
  void initState() {
    super.initState();
    final repository = ListingApiRepository(DioClient.createDio());
    
    // Получаем токен и ID пользователя из Hive (если авторизован)
    final box = Hive.box('user');
    final token = box.get('auth_token') as String?;
    final userData = box.get('user') as Map?;
    final userId = userData?['id'] as int?;
    
    // Загружаем объявление и увеличиваем счётчик просмотров
    // Счётчик увеличивается ВСЕГДА, независимо от авторизации
    _loadingFuture = repository.getListingById(
      widget.itemId,
      token: token,
      userId: userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ApiResult<Listing>>(
      future: _loadingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Загрузка объявления...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Ошибка загрузки'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Вернуться'),
                  ),
                ],
              ),
            ),
          );
        }

        final result = snapshot.data!;

        if (!result.success || result.data == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
                  SizedBox(height: 16),
                  Text('Объявление не найдено'),
                  SizedBox(height: 8),
                  Text(
                    result.error ?? 'Неизвестная ошибка',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Вернуться'),
                  ),
                ],
              ),
            ),
          );
        }

        return BlocProvider(
          create: (context) => ListingBloc(
            listing: result.data!,
            authBloc: context.read<AuthBloc>(),
          ),
          child: ListingScreen(
            itemId: widget.itemId,
            listing: result.data,
          ),
        );
      },
    );
  }
}
