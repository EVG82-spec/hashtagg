import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/shared/domain/entities/user.dart';
import 'package:hashtagg/core/network/api_config.dart';

class ProfileCard extends StatelessWidget {
  final User user;
  const ProfileCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    String avatarUrl = user.avatar ?? 'https://hashtagg.ru/media/others/no_avatar.png';
    avatarUrl = ApiConfig.replaceMediaUrl(avatarUrl);
    
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: NetworkImage(avatarUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
        SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user.name,
                style: GoogleFonts.montserrat(
                  fontSize: 17,
                  fontWeight: FontWeight(700),
                ),
              ),
              if (user.status != null && user.status!.isNotEmpty)
                Text(
                  user.status!,
                  style: GoogleFonts.montserrat(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Color(0xff666666),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
