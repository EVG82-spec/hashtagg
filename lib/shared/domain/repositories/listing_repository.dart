import 'package:hashtagg/shared/domain/entities/listing.dart';

abstract class ListingRepository {
  ListingRepository();

  Listing? findById(int id);
}