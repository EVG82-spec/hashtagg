import 'package:flutter/material.dart';
import 'package:native_video_player/native_video_player.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';

import 'package:hashtagg/features/home/bloc/categories_bloc.dart';
import 'package:hashtagg/features/home/bloc/stories_bloc.dart';
import 'package:hashtagg/features/home/bloc/banner_bloc.dart';

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const WelcomeScreen({super.key, required this.onComplete});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // ---------- Video ----------
  NativeVideoPlayerController? _controller;
  StreamSubscription<void>? _eventsSubscription;
  bool _isReady = false;
  bool _hasError = false;
  bool _videoEnded = false;
  Timer? _videoTimeoutTimer;

  // ---------- Data ----------
  bool _dataLoaded = false;
  bool _dataLoading = false;

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _controller?.dispose();
    _videoTimeoutTimer?.cancel();
    super.dispose();
  }

  // --------------------------------------------------------------
  //                          VIDEO
  // --------------------------------------------------------------
  void _onViewReady(NativeVideoPlayerController controller) async {
    _controller = controller;

    _eventsSubscription = controller.events.listen((event) {
      switch (event) {
        case PlaybackReadyEvent():
          if (mounted) setState(() => _isReady = true);
          controller.play();

          _videoTimeoutTimer?.cancel();
          _videoTimeoutTimer = Timer(const Duration(seconds: 30), () {
            if (mounted && !_videoEnded) {
              setState(() => _videoEnded = true);
              _tryComplete();
            }
          });
          break;

        case PlaybackEndedEvent():
          _videoTimeoutTimer?.cancel();
          if (mounted) {
            setState(() => _videoEnded = true);
            _tryComplete();
          }
          break;

        case PlaybackStatusChangedEvent():
          break;

        case PlaybackErrorEvent():
          _videoTimeoutTimer?.cancel();
          if (mounted) {
            setState(() {
              _hasError = true;
              _videoEnded = true;
            });
            _tryComplete();
          }
          break;

        default:
          break;
      }
    });

    try {
      await controller
          .loadVideo(
            VideoSource(
              path: 'assets/welcome.mp4',
              type: VideoSourceType.asset,
            ),
          )
          .timeout(const Duration(seconds: 15), onTimeout: () {
            if (mounted) {
              setState(() {
                _hasError = true;
                _videoEnded = true;
              });
              _tryComplete();
            }
          });
    } catch (e) {
      _videoTimeoutTimer?.cancel();
      if (mounted) {
        setState(() {
          _hasError = true;
          _videoEnded = true;
        });
        _tryComplete();
      }
    }

    // Параллельно запускаем загрузку данных
    _startDataLoading();
  }

  // --------------------------------------------------------------
  //                       DATA LOADING
  // --------------------------------------------------------------
  Future<void> _startDataLoading() async {
    if (_dataLoading) return;
    _dataLoading = true;

    final categoriesBloc = context.read<CategoriesBloc>();
    final storiesBloc = context.read<StoriesBloc>();
    final bannerBloc = context.read<BannerBloc>();

    categoriesBloc.add(LoadCategories());
    storiesBloc.add(LoadStories());
    bannerBloc.add(LoadBanner());

    await Future.wait([
      categoriesBloc.stream.firstWhere(
        (s) => s is CategoriesLoaded || s is CategoriesError,
      ),
      storiesBloc.stream.firstWhere(
        (s) => s is StoriesLoaded || s is StoriesError,
      ),
      bannerBloc.stream.firstWhere(
        (s) => s is BannerLoaded || s is BannerError,
      ),
    ]);

    if (!mounted) return;

    setState(() => _dataLoaded = true);
    _tryComplete();
  }

  // --------------------------------------------------------------
  //                  ПРОВЕРКА ГОТОВНОСТИ И ПЕРЕХОД
  // --------------------------------------------------------------
  void _tryComplete() {
    if (_videoEnded && _dataLoaded && mounted) {
      widget.onComplete();
    }
  }

  // --------------------------------------------------------------
  //                            UI
  // --------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height * 2;

    return Scaffold(
      backgroundColor: const Color(0xff7049fc),
      body: Stack(
        children: [
          AnimatedOpacity(
            opacity: _isReady ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: SizedBox(
              height: isLandscape ? screenSize.height * 2 : screenSize.height,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: NativeVideoPlayerView(
                    onViewReady: _onViewReady,
                  ),
                ),
              ),
            ),
          ),
          if (!_isReady && !_hasError)
            Container(
              color: const Color(0xff7049fc),
              child: Center(
                child: Image.asset(
                  'assets/first_frame.png',
                  width: 116,
                ),
              ),
            ),
          if (_hasError)
            const Center(
              child: Icon(Icons.error_outline, color: Colors.white54, size: 48),
            ),
        ],
      ),
    );
  }
}