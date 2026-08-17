// navigation_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/shared/presentation/bloc/loading_notifier.dart';
import 'package:hashtagg/shared/presentation/bloc/navigation_notifier.dart';
import 'package:hashtagg/shared/presentation/utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/features/favorites/screens/favorites.dart';
import 'package:hashtagg/features/chats/screens/chats_screen.dart';
import 'package:hashtagg/features/profile/screens/profile.dart';
import 'package:hashtagg/core/navigation/swipeable_route.dart';
import 'package:hashtagg/core/services/unread_messages_bloc.dart' as unread;

class MainNavigationBar extends StatefulWidget {
  const MainNavigationBar({super.key});

  @override
  State<MainNavigationBar> createState() => _MainNavigationBarState();
}

class _MainNavigationBarState extends State<MainNavigationBar> {
  void _onItemTapped(BuildContext context, int index) {
    var state = context.read<AuthBloc>();
    final navNotifier = context.read<NavigationNotifier>();

    switch (index) {
      case 0:
        navNotifier.setSelectedIndex(index);
        context.go('/');
        break;
      case 1:
        navNotifier.setSelectedIndex(index);
        Navigator.of(context, rootNavigator: true).push(
          createEdgeSwipeRoute(builder: (_) => const FavoritesScreen()),
        );
        break;
      case 2:
        if (state.state.user != null) {
          navNotifier.setSelectedIndex(index);
          context.go('/listing-add');
        } else {
          showAuthModal(context);
        }
        break;
      case 3:
        if (state.state.user != null) {
          navNotifier.setSelectedIndex(index);
          Navigator.of(context, rootNavigator: true).push(
            createSwipeableRoute(builder: (_) => ChatsScreen()),
          );
        } else {
          showAuthModal(context);
        }
        break;
      case 4:
        if (state.state.user != null) {
          navNotifier.setSelectedIndex(index);
          context.go('/profile');
        } else {
          showAuthModal(context);
        }
        break;
      default:
        navNotifier.setSelectedIndex(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<LoadingNotifier>().isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedIndex = context.watch<NavigationNotifier>().selectedIndex;

    // Никаких ручных вычислений bottomPadding — это теперь задача SafeArea в ShellRoute
    return AnimatedOpacity(
      opacity: isLoading ? 0.0 : 1.0,
      duration: Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: isLoading,
        // Только горизонтальные отступы для плавающей плашки
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xff233040)
                : const Color.fromRGBO(0, 0, 0, 0.72),
            borderRadius: BorderRadius.circular(28),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              type: BottomNavigationBarType.fixed,
              iconSize: 24,
              selectedFontSize: 0,
              unselectedFontSize: 0,
              currentIndex: selectedIndex,
              onTap: (index) {
                _onItemTapped(context, index);
              },
              selectedLabelStyle:
                  GoogleFonts.montserrat(fontWeight: FontWeight.w500),
              unselectedLabelStyle:
                  GoogleFonts.montserrat(fontWeight: FontWeight.w500),
              unselectedItemColor: Color(0xff666666),
              selectedItemColor: Color(0xff917dfa),
              showSelectedLabels: false,
              elevation: 0,
              showUnselectedLabels: false,
              unselectedIconTheme: IconThemeData(color: Color(0xff666666)),
              selectedIconTheme: IconThemeData(color: Color(0xff917dfa)),
              items: [
                BottomNavigationBarItem(
                  icon: Image(
                    image: AssetImage('assets/home.png'),
                    height: 24,
                    width: 24,
                  ),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Image(
                    image: AssetImage('assets/favorite.png'),
                    height: 24,
                    width: 24,
                  ),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Image(
                    image: AssetImage('assets/add.png'),
                    height: 24,
                    width: 24,
                  ),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: _buildMailIconWithBadge(context),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Image(
                    image: AssetImage('assets/user.png'),
                    height: 24,
                    width: 24,
                  ),
                  label: '',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMailIconWithBadge(BuildContext context) {
    return BlocBuilder<unread.UnreadMessagesBloc, unread.UnreadMessagesState>(
      builder: (context, state) {
        final unreadCount = state.count;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Image(
              image: AssetImage('assets/mail.png'),
              height: 24,
              width: 24,
            ),
            if (unreadCount > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: unreadCount > 9 ? 4 : 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}