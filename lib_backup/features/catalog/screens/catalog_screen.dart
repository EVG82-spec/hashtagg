import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

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
          icon: Icon(Icons.grid_view, color: isDark ? Colors.white : Colors.black),
          onPressed: () {},
        ),
        title: SizedBox(
          height: 40,
          child: GestureDetector(
            onTap: () => context.push('/search'),
            child: AbsorbPointer(
              child: SearchBar(
                leading: const Icon(Icons.search),
                hintText: 'Поиск во Владивостоке',
                hintStyle: WidgetStateProperty.all(
                  GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Color(0xff999999),
                  ),
                ),
                elevation: WidgetStateProperty.all(0.0),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Center(child: Text('Экран каталога!', style: GoogleFonts.montserrat())),
    );
  }
}
