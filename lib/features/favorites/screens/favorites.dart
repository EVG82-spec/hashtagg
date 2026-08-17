import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/features/favorites/widgets/favorite_listing_item.dart';
import 'package:hashtagg/shared/presentation/bloc/favorites_bloc.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Theme.of(context).appBarTheme.backgroundColor,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () {
            context.pop();
          },
        ),
        title: Text(
          'Избранное', 
          style: GoogleFonts.montserrat(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: BlocBuilder<FavoritesBloc, FavoritesState>(
        builder: (context, state) {
          final favorites = state.favoriteListings;

          if (state.isLoading && favorites.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xff917dfa),
              ),
            );
          }

          if (favorites.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                // Проверяем авторизацию и вызываем соответствующее событие
                final authState = context.read<AuthBloc>().state;
                if (authState is Authenticated) {
                  context.read<FavoritesBloc>().add(LoadFavoritesFromServer());
                } else {
                  context.read<FavoritesBloc>().add(LoadFavorites());
                }
                await Future.delayed(Duration(milliseconds: 500));
              },
              color: Color(0xff917dfa),
              edgeOffset: 40.0,
              displacement: 20.0,
              strokeWidth: 3.0,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.favorite_outline,
                          size: 64,
                          color: Color(0xffcccccc),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Нет избранных объявлений',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            color: const Color(0xff999999),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Добавляйте объявления в избранное,\nчтобы не потерять их',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            color: const Color(0xffbbbbbb),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  '${favorites.length} ${_pluralize(favorites.length)}',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: const Color(0xff999999),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    // Проверяем авторизацию и вызываем соответствующее событие
                    final authState = context.read<AuthBloc>().state;
                    if (authState is Authenticated) {
                      context.read<FavoritesBloc>().add(LoadFavoritesFromServer());
                    } else {
                      context.read<FavoritesBloc>().add(LoadFavorites());
                    }
                    await Future.delayed(Duration(milliseconds: 500));
                  },
                  color: Color(0xff917dfa),
                  edgeOffset: 40.0,
                  displacement: 20.0,
                  strokeWidth: 3.0,
                  child: ListView.separated(
                  itemCount: favorites.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 20,
                    endIndent: 20,
                    color: Color(0xfff0f0f0),
                  ),
                  itemBuilder: (context, index) {
                    return FavoriteListingItem(listing: favorites[index]);
                  },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _pluralize(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'объявлений';
    if (mod10 == 1) return 'объявление';
    if (mod10 >= 2 && mod10 <= 4) return 'объявления';
    return 'объявлений';
  }
}
