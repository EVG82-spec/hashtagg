import 'package:flutter_bloc/flutter_bloc.dart';

enum FeedCategory { recommendations, fresh, companies }

sealed class FeedEvent {}

class FeedCategoryChangeEvent extends FeedEvent {
  FeedCategory category;
  FeedCategoryChangeEvent({required this.category});
}

class FeedLoadMoreEvent extends FeedEvent {}

class FeedState {
  FeedCategory category;
  int currentPage;
  bool isLoadingMore;

  FeedState({
    this.category = FeedCategory.recommendations,
    this.currentPage = 1,
    this.isLoadingMore = false,
  });

  FeedState copyWith({
    FeedCategory? category,
    int? currentPage,
    bool? isLoadingMore,
  }) {
    return FeedState(
      category: category ?? this.category,
      currentPage: currentPage ?? this.currentPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  FeedBloc() : super(FeedState()) {
    on<FeedEvent>((event, emit) {
      switch (event) {
        case FeedCategoryChangeEvent():
          emit(FeedState(category: event.category, currentPage: 1));
        case FeedLoadMoreEvent():
          emit(state.copyWith(
            currentPage: state.currentPage + 1,
            isLoadingMore: true,
          ));
      }
    });
  }
}