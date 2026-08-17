import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class _BlacklistedUser {
  final String name;
  final String? avatar;

  const _BlacklistedUser({required this.name, this.avatar});
}

class BlacklistScreen extends StatefulWidget {
  const BlacklistScreen({super.key});

  @override
  State<BlacklistScreen> createState() => _BlacklistScreenState();
}

class _BlacklistScreenState extends State<BlacklistScreen> {
  // Тестовые данные — пустой список (заглушка)
  final List<_BlacklistedUser> _blacklist = [];

  void _removeFromBlacklist(int index) {
    setState(() => _blacklist.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Чёрный список',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _blacklist.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.block, size: 80, color: Color(0xffcccccc)),
                  const SizedBox(height: 20),
                  Text(
                    'Чёрный список пуст',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      color: const Color(0xff999999),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _blacklist.length,
              itemBuilder: (context, index) {
                final user = _blacklist[index];
                return InkWell(
                  splashColor: const Color(0xff917dfa).withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        // Аватар
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: const Color(0xfff0f0f0),
                            image: user.avatar != null
                                ? DecorationImage(
                                    image: NetworkImage(user.avatar!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: user.avatar == null
                              ? const Icon(Icons.person,
                                  color: Color(0xffcccccc), size: 24)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        // Имя
                        Expanded(
                          child: Text(
                            user.name,
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        // Кнопка удалить из ЧС
                        TextButton(
                          onPressed: () => _removeFromBlacklist(index),
                          child: Text(
                            'Разблокировать',
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              color: const Color(0xff917dfa),
                              fontWeight: FontWeight.w500,
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
