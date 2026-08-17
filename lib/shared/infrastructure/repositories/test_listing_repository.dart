import 'package:hashtagg/shared/domain/entities/listing.dart';
import 'package:hashtagg/shared/domain/repositories/listing_repository.dart';
import 'package:hashtagg/shared/presentation/test_data.dart';

class TestListingRepository implements ListingRepository {
  TestListingRepository();

  Listing? findById(int id) {
    return test_listings.firstWhere(
      (listing) => listing.id == id,
    );
  }
}