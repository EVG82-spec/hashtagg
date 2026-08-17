import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/shared/domain/entities/listing.dart';
import 'package:hashtagg/shared/presentation/bloc/favorites_bloc.dart';
import 'package:hashtagg/shared/presentation/view_models/listing_view_model.dart';
import 'package:hashtagg/core/network/api_config.dart';

class FavoriteListingItem extends StatelessWidget {
  final Listing listing;

  const FavoriteListingItem({super.key, required this.listing});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewModel = ListingViewModel(listing);

    return Dismissible(
      key: Key('favorite_${listing.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_outline, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(
              'Удалить',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Удалить из избранного?', style: GoogleFonts.montserrat()),
                content: Text(
                  'Объявление «${listing.title}» будет удалено из избранного.',
                  style: GoogleFonts.montserrat(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('Отмена', style: GoogleFonts.montserrat()),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: Text('Удалить', style: GoogleFonts.montserrat()),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) {
        context.read<FavoritesBloc>().add(RemoveFavorite(listing.id!));
      },
      child: InkWell(
        onTap: () {
          context.push('/listing/${listing.id}');
        },
        splashColor: const Color(0xff917dfa).withValues(alpha: 0.3),
        highlightColor: const Color(0xff917dfa).withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Thumbnail with image support
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 64,
                  height: 64,
                  color: const Color(0xfff0eeff),
                  child: listing.images != null && listing.images!.isNotEmpty
                      ? Image.network(
                          ApiConfig.replaceMediaUrl(listing.images!.first),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.image_outlined,
                              color: Color(0xff917dfa),
                              size: 30,
                            );
                          },
                        )
                      : const Icon(
                          Icons.image_outlined,
                          color: Color(0xff917dfa),
                          size: 30,
                        ),
                ),
              ),

              const SizedBox(width: 14),

              // Info column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xff1a1a1a),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      viewModel.price(),
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff917dfa),
                      ),
                    ),
                    if (listing.location != null &&
                        listing.location!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: Color(0xff808080),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              viewModel.location(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: const Color(0xff808080),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: Color(0xff999999),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
