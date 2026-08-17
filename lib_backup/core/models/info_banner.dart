class InfoBanner {
  final int id;
  final String title;
  final String image;
  final String link;
  final int order;

  InfoBanner({
    required this.id,
    required this.title,
    required this.image,
    required this.link,
    required this.order,
  });

  factory InfoBanner.fromJson(Map<String, dynamic> json) {
    return InfoBanner(
      id: json['id'] as int,
      title: json['title'] as String,
      image: json['image'] as String,
      link: json['link'] as String,
      order: json['order'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image': image,
      'link': link,
      'order': order,
    };
  }
}
