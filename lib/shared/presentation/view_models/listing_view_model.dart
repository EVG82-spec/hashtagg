import 'package:hashtagg/shared/domain/entities/listing.dart';

class ListingViewModel {
  final Listing _listing;

  static const int maxTitleLength = 20;

  ListingViewModel(this._listing);

  String getCurrencySymbol() {
    switch (_listing.currency) {
      case 'RUB':
        return '₽';
      
      default:
       return '₽';
    }
  }

  String price() {
    return "${_listing.price} ${getCurrencySymbol()}";
  }
  String title() {
    if (_listing.title.isEmpty) return '';

    if (_listing.title.length > ListingViewModel.maxTitleLength) {
      return "${_listing.title.substring(0, ListingViewModel.maxTitleLength - 3)}...";
    } else {
      return _listing.title;
    }
  }
   String fullTitle() {
    if (_listing.title.isEmpty) return '';

    return _listing.title;
  }

  String description() {
    if (_listing.description.isEmpty) return '';

    return _listing.description;
  }

  String location() {
    if (_listing.location == null) return '';

    return _listing.location!;
  }
}