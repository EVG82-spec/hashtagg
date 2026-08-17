class AppBanner {
  final String? image;
  final String? link;
  final String? title;

  AppBanner({
    this.image,
    this.link,
    this.title,
  });

  factory AppBanner.fromJson(Map<String, dynamic> json) {
    return AppBanner(
      image: json['image'] as String?,
      link: json['link'] as String?,
      title: json['title'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'image': image,
      'link': link,
      'title': title,
    };
  }
}
