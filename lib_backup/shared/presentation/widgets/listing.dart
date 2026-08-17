import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/features/listing/screens/listing_screen.dart';
import 'package:hashtagg/shared/domain/repositories/listing_repository.dart';
import 'package:hashtagg/shared/infrastructure/repositories/test_listing_repository.dart';
import 'package:hashtagg/shared/presentation/bloc/favorites_bloc.dart';
import 'package:hashtagg/shared/presentation/bloc/listing_bloc.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/shared/presentation/view_models/listing_view_model.dart';

class Listing extends StatelessWidget {
  final int listingId;

  const Listing({super.key, required this.listingId});

  @override
  Widget build(BuildContext context) {
    //TODO
    var listing = TestListingRepository().findById(listingId)!;
    print("listing id: ${listing.id}");
    var listingViewModel = ListingViewModel(listing);
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Проверяем VIP статус (пока используем заглушку, нужно добавить поле в модель)
    // final isVip = listing.vip == 1;
    final isVip = false; // TODO: добавить поле vip в модель Listing

    return BlocProvider(
      create: (context) => ListingBloc(
        listing: listing!,
        authBloc: context.read<AuthBloc>(),
      ),
      child: BlocBuilder<FavoritesBloc, FavoritesState>(
        builder: (context, state) {
          return GestureDetector(
            onTap: () {
              context.push("/listing/${listing.id}");
            },
            child: Container(
              height: 300,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                // Желтоватый фон для VIP объявлений
                color: isVip 
                    ? (isDark ? const Color(0xFF2A3A1F) : const Color(0xFFFFF8E1))
                    : null,
                borderRadius: BorderRadius.all(Radius.circular(10)),
                // Золотая рамка для VIP
                border: isVip
                    ? Border.all(
                        color: Colors.amber.withOpacity(0.3),
                        width: 2,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 1,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: AnimatedImageSlider(
                          imageUrls: [
                            'https://hashtagg.ru/media/others/0d2d3064105f566413575dfe6c094d71.jpg',
                            'https://hashtagg.ru/media/images_boards/big/6999a60e9249c.jpg',
                            'https://hashtagg.ru/media/images_boards/big/699a36e627d55.jpg',
                            // добавьте свои URL
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 100,
                        child: Container(
                          color: isVip 
                              ? (isDark ? const Color(0xFF2A3A1F) : const Color(0xFFFFF8E1))
                              : Colors.white,
                          padding: EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      softWrap: true,
                                      overflow: TextOverflow.ellipsis,
                                      listingViewModel.title(),
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight(500),
                                      ),
                                    ),
                                  ),

                                  GestureDetector(
                                      onTap: () {
                                        final isFavorite = context
                                            .read<FavoritesBloc>()
                                            .state
                                            .ids
                                            .contains(listingId);
                                        if (isFavorite) {
                                          context.read<FavoritesBloc>().add(
                                            RemoveFavorite(listingId),
                                          );
                                        } else {
                                          context.read<FavoritesBloc>().add(
                                            AddFavorite(listingId, listing),
                                          );
                                        }
                                      },
                                      child: Icon(
                                        context
                                                    .read<FavoritesBloc>()
                                                    .state
                                                    .ids
                                                    .contains(listingId) ==
                                                true
                                            ? Icons.favorite
                                            : Icons.favorite_border_outlined,
                                        color: Color(0xff917dfa),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                listingViewModel.price(),
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight(700),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                listingViewModel.location(),
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  color: Color(0xff808080),
                                ),
                              ),
                              Text(
                                '09 декабря 2025',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  color: Color(0xff808080),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // VIP бейджик сверху карточки
                  if (isVip)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.workspace_premium,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'VIP',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
