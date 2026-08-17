import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:native_video_player/native_video_player.dart';
import 'package:hive/hive.dart';
import 'package:hashtagg/core/network/stories_api_repository.dart';
import 'package:hashtagg/core/navigation/swipeable_route.dart';
import 'package:hashtagg/features/stories/screens/story_edit_screen.dart';
import 'dart:async';
import 'package:hashtagg/core/network/api_config.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allUsers;
  final int initialUserIndex;

  const StoryViewerScreen({
    super.key,
    required this.allUsers,
    required this.initialUserIndex,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  int _currentUserIndex = 0;
  int _currentStoryIndex = 0;
  Timer? _storyTimer;
  double _progress = 0.0;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _currentUserIndex = widget.initialUserIndex;
    _startStoryTimer();
  }

  @override
  void dispose() {
    _storyTimer?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  void _startStoryTimer() {
    _storyTimer?.cancel();
    _progressTimer?.cancel();
    _progress = 0.0;
    
    final currentUser = widget.allUsers[_currentUserIndex];
    final stories = currentUser['stories'] as List;
    
    if (_currentStoryIndex >= stories.length) return;
    
    final story = stories[_currentStoryIndex];
    final durationValue = story['duration'];
    final duration = durationValue is int ? durationValue : (durationValue is String ? int.tryParse(durationValue) ?? 5 : 5);
    
    // Progress animation
    const updateInterval = 50; // ms
    final totalUpdates = (duration * 1000) ~/ updateInterval;
    var currentUpdate = 0;
    
    _progressTimer = Timer.periodic(Duration(milliseconds: updateInterval), (timer) {
      currentUpdate++;
      setState(() {
        _progress = currentUpdate / totalUpdates;
      });
      
      if (currentUpdate >= totalUpdates) {
        timer.cancel();
        _nextStory();
      }
    });
  }

  void _nextStory() {
    final currentUser = widget.allUsers[_currentUserIndex];
    final stories = currentUser['stories'] as List;
    
    if (_currentStoryIndex < stories.length - 1) {
      setState(() => _currentStoryIndex++);
      _startStoryTimer();
    } else {
      _nextUser();
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      setState(() => _currentStoryIndex--);
      _startStoryTimer();
    } else {
      _previousUser();
    }
  }

  void _nextUser() {
    if (_currentUserIndex < widget.allUsers.length - 1) {
      setState(() {
        _currentUserIndex++;
        _currentStoryIndex = 0;
      });
      _startStoryTimer();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previousUser() {
    if (_currentUserIndex > 0) {
      setState(() {
        _currentUserIndex--;
        final prevUser = widget.allUsers[_currentUserIndex];
        final prevStories = prevUser['stories'] as List;
        _currentStoryIndex = prevStories.length - 1;
      });
      _startStoryTimer();
    }
  }

  // Проверка является ли история своей
  Future<bool> _isMyStory(dynamic userId) async {
    try {
      final box = await Hive.openBox('user');
      
      // Логируем все ключи в Hive для отладки
      print('🔵 [StoryViewer] Hive keys: ${box.keys.toList()}');
      
      // ВСЕГДА берем userId только из user['id'], игнорируем user_id
      final userData = box.get('user');
      if (userData == null || userData is! Map) {
        print('🔴 [StoryViewer] No user data in Hive');
        return false;
      }
      
      final myUserId = userData['id'];
      print('🔵 [StoryViewer] user from Hive: id=${myUserId}');
      
      // Приводим оба значения к int для сравнения
      final myUserIdInt = myUserId is int ? myUserId : int.tryParse(myUserId?.toString() ?? '0');
      final userIdInt = userId is int ? userId : int.tryParse(userId?.toString() ?? '0');
      
      print('🔵 [StoryViewer] Comparing userId: my=$myUserIdInt, story=$userIdInt');
      
      return myUserIdInt == userIdInt && myUserIdInt != null && myUserIdInt != 0;
    } catch (e) {
      print('🔴 [StoryViewer] Error checking if my story: $e');
      return false;
    }
  }

  // Показать экран редактирования
  void _showEditScreen(Map<String, dynamic> story) async {
    // Останавливаем таймер на время редактирования
    _storyTimer?.cancel();
    _progressTimer?.cancel();
    
    // Сохраняем индекс текущей стории для обновления
    final currentUser = widget.allUsers[_currentUserIndex];
    final stories = currentUser['stories'] as List;
    final storyIndex = stories.indexWhere((s) => s['id'].toString() == story['id'].toString());
    
    await Navigator.of(context).push(
      createSwipeableRoute(
        builder: (context) => StoryEditScreen(
          story: story,
          onUpdated: () async {
            // После обновления перезагружаем сторисы из API
            print('🔵 [StoryViewer] Story updated, reloading stories from API');
            await _reloadStories();
            
            // Обновляем текущую историю в списке с новым URL
            if (storyIndex >= 0 && storyIndex < stories.length) {
              stories[storyIndex] = story;
              print('✅ [StoryViewer] Updated story in list at index $storyIndex');
            }
          },
        ),
      ),
    );
    
    // После закрытия экрана редактирования перезапускаем таймер
    if (mounted) {
      _startStoryTimer();
    }
  }

  // Перезагрузка сторисов из API
  Future<void> _reloadStories() async {
    try {
      final storiesApi = StoriesApiRepository();
      final result = await storiesApi.getStories();
      
      if (result['status'] == true && result['data'] != null) {
        // API возвращает {"users": [...]}
        final data = result['data'];
        final newUsers = data is Map ? (data['users'] as List) : (data as List);
        
        // Обновляем данные в widget.allUsers
        widget.allUsers.clear();
        widget.allUsers.addAll(newUsers.cast<Map<String, dynamic>>());
        
        print('✅ [StoryViewer] Stories reloaded: ${widget.allUsers.length} users');
        
        // Обновляем UI
        if (mounted) {
          setState(() {
            // Проверяем, что текущие индексы все еще валидны
            if (_currentUserIndex >= widget.allUsers.length) {
              _currentUserIndex = widget.allUsers.length - 1;
            }
            
            if (_currentUserIndex >= 0) {
              final currentUser = widget.allUsers[_currentUserIndex];
              final stories = currentUser['stories'] as List;
              if (_currentStoryIndex >= stories.length) {
                _currentStoryIndex = stories.length - 1;
              }
            }
          });
        }
      }
    } catch (e) {
      print('🔴 [StoryViewer] Error reloading stories: $e');
    }
  }

  // Показать диалог удаления
  void _showDeleteDialog(Map<String, dynamic> story) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Удалить историю?',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Это действие нельзя отменить',
            style: GoogleFonts.montserrat(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Отмена',
                style: GoogleFonts.montserrat(
                  color: Colors.grey,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _deleteStory(story);
              },
              child: Text(
                'Удалить',
                style: GoogleFonts.montserrat(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Удалить историю
  Future<void> _deleteStory(Map<String, dynamic> story) async {
    try {
      final box = await Hive.openBox('user');
      final token = box.get('auth_token');
      
      // ВСЕГДА берем userId только из user['id'], игнорируем user_id
      final userData = box.get('user');
      int? userId;
      if (userData is Map) {
        userId = userData['id'];
      }

      if (token == null || userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка авторизации'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Приводим userId к int
      final userIdInt = userId is int ? userId : int.tryParse(userId?.toString() ?? '0');
      final storyIdInt = story['id'] is int ? story['id'] : int.tryParse(story['id']?.toString() ?? '0');
      
      if (userIdInt == null || storyIdInt == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка: неверные данные'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      print('🔵 [StoryViewer] Deleting story: userId=$userIdInt, storyId=$storyIdInt');

      final storiesApi = StoriesApiRepository();
      final result = await storiesApi.deleteStory(
        userId: userIdInt,
        token: token,
        storyId: storyIdInt,
      );

      if (mounted) {
        if (result['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('История удалена'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Удаляем историю из списка
          final currentUser = widget.allUsers[_currentUserIndex];
          final stories = currentUser['stories'] as List;
          stories.removeWhere((s) => s['id'].toString() == story['id'].toString());
          
          // Если больше нет историй у пользователя, закрываем экран
          if (stories.isEmpty) {
            Navigator.of(context).pop();
          } else {
            // Переходим к следующей истории или предыдущей
            if (_currentStoryIndex >= stories.length) {
              _currentStoryIndex = stories.length - 1;
            }
            setState(() {});
            _startStoryTimer();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('🔴 [StoryViewer] Delete error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.allUsers[_currentUserIndex];
    final stories = user['stories'] as List;
    final story = stories[_currentStoryIndex];
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: GestureDetector(
          onTapDown: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < screenWidth / 3) {
              _previousStory();
            } else if (details.globalPosition.dx > screenWidth * 2 / 3) {
              _nextStory();
            }
          },
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! > 0) {
              _previousUser();
            } else if (details.primaryVelocity! < 0) {
              _nextUser();
            }
          },
          child: _buildStoryView(user, story, stories),
        ),
      ),
    );
  }

  Widget _buildStoryView(Map<String, dynamic> user, Map<String, dynamic> story, List stories) {
    final userName = user['name'] ?? 'Пользователь';
    final avatarValue = user['avatar'];
    final avatar = avatarValue is String 
        ? ApiConfig.replaceMediaUrl(avatarValue)
        : null;
    final viewCount = story['count_view'] ?? '0 просмотров';
    
    // Определяем тип контента (видео или фото)
    final url = ApiConfig.replaceMediaUrl(
      story['url'] is String ? story['url'] as String : ''
    );
    final isVideo = url.toLowerCase().endsWith('.mp4') || 
                    url.toLowerCase().endsWith('.mov') || 
                    url.toLowerCase().endsWith('.webm');
    
    return Stack(
      children: [
        // Story content
        Positioned.fill(
          child: isVideo 
              ? _StoryVideoPlayer(
                  key: ValueKey(url), // Уникальный ключ для принудительного обновления
                  url: url,
                )
              : Image.network(
                  key: ValueKey(url), // Уникальный ключ для принудительного обновления
                  url,
                  fit: BoxFit.contain,
                  cacheWidth: null,
                  cacheHeight: null,
                  headers: {
                    'Cache-Control': 'no-cache',
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                        color: Colors.white,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Icon(Icons.error, color: Colors.white, size: 48),
                    );
                  },
                ),
        ),
        
        // Progress bars
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          right: 8,
          child: Row(
            children: List.generate(stories.length, (index) {
              return Expanded(
                child: Container(
                  height: 3,
                  margin: EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: index < _currentStoryIndex
                        ? 1.0
                        : index == _currentStoryIndex
                            ? _progress
                            : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        
        // Header
        Positioned(
          top: MediaQuery.of(context).padding.top + 20,
          left: 16,
          right: 16,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[800],
                  image: avatar != null
                      ? DecorationImage(
                          image: NetworkImage(avatar),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: avatar == null
                    ? Icon(Icons.person, color: Colors.white, size: 20)
                    : null,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      viewCount,
                      style: GoogleFonts.montserrat(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              FutureBuilder<bool>(
                future: _isMyStory(user['id']),
                builder: (context, snapshot) {
                  final isMyStory = snapshot.data ?? false;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isMyStory) ...[
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.white),
                          onPressed: () => _showEditScreen(story),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.white),
                          onPressed: () => _showDeleteDialog(story),
                        ),
                      ],
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        
        // Bottom button
        if (story['ad'] != null)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: _buildAdCard(story['ad']),
          )
        else
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () {
                final userId = user['id'];
                if (userId != null) {
                  Navigator.of(context).pop(); // Закрываем сторис
                  context.push('/user/$userId');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xff233040)
                    : Colors.white,
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Открыть профиль',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAdCard(Map<String, dynamic> ad) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleValue = ad['title'];
    final title = titleValue is String ? titleValue : '';
    
    final priceValue = ad['price'];
    final price = priceValue is String 
        ? priceValue 
        : (priceValue is Map ? (priceValue['format'] ?? priceValue['price'] ?? '') : '');
    
    final imageValue = ad['image'];
    final image = imageValue is String
        ? ApiConfig.replaceMediaUrl(imageValue)
        : null;
    
    return GestureDetector(
      onTap: () {
        final adId = ad['id'];
        if (adId != null) {
          Navigator.of(context).pop(); // Закрываем сторис
          context.push('/listing/$adId');
        }
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xff233040) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  image,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    price,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff917dfa),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios, 
              size: 16,
              color: isDark ? Colors.white : Colors.black,
            ),
          ],
        ),
      ),
    );
  }
}


class _StoryVideoPlayer extends StatefulWidget {
  final String url;

  const _StoryVideoPlayer({super.key, required this.url});

  @override
  State<_StoryVideoPlayer> createState() => _StoryVideoPlayerState();
}

class _StoryVideoPlayerState extends State<_StoryVideoPlayer> {
  NativeVideoPlayerController? _controller;
  StreamSubscription<void>? _eventsSubscription;
  bool _isReady = false;
  bool _hasError = false;

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void _onViewReady(NativeVideoPlayerController controller) async {
    _controller = controller;
    
    _eventsSubscription = controller.events.listen((event) {
      switch (event) {
        case PlaybackReadyEvent():
          print('✅ [StoryVideo] Video ready');
          if (mounted) {
            setState(() {
              _isReady = true;
              _hasError = false;
            });
          }
          // Автоплей с зацикливанием
          controller.play();
          break;
          
        case PlaybackEndedEvent():
          print('🔵 [StoryVideo] Playback ended, restarting...');
          controller.stop();
          controller.play();
          break;
          
        case PlaybackErrorEvent():
          print('🔴 [StoryVideo] Playback error: ${event.errorMessage}');
          if (mounted) {
            setState(() {
              _hasError = true;
            });
          }
          break;
          
        default:
          break;
      }
    });

    try {
      print('🔵 [StoryVideo] Loading video from: ${widget.url}');
      await controller.loadVideo(
        VideoSource(
          path: widget.url,
          type: VideoSourceType.network,
        ),
      ).timeout(
        Duration(seconds: 15),
        onTimeout: () {
          print('🔴 [StoryVideo] Video loading timeout');
          if (mounted) {
            setState(() {
              _hasError = true;
            });
          }
        },
      );
    } catch (e) {
      print('🔴 [StoryVideo] Error loading video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.white, size: 48),
            SizedBox(height: 16),
            Text(
              'Не удалось загрузить видео',
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        NativeVideoPlayerView(
          onViewReady: _onViewReady,
        ),
        if (!_isReady)
          Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
      ],
    );
  }
}
