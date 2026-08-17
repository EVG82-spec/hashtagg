import 'package:flutter/foundation.dart';
import 'package:hashtagg/shared/domain/entities/user.dart';
import 'package:hashtagg/shared/domain/services/listing_service.dart';
import 'package:hive/hive.dart';

class BasicListingService implements ListingService {
  BasicListingService();

  @override
  void favorite(int id) {
    var box = Hive.box('favorites');
    box.put(id, 1);

    if (kDebugMode) {
      debugPrint("favorite listing $id");
    }
  }

  @override
  void unfavorite(int id) {
    var box = Hive.box('favorites');
    box.put(id, 0);

    if (kDebugMode) {
      debugPrint("unfavorite listing $id");
    }
  }
}