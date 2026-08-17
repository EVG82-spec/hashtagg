import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';
import 'package:hashtagg/core/network/stories_api_repository.dart';
import 'package:native_video_player/native_video_player.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/core/services/permission_service.dart';

class StoryEditScreen extends StatefulWidget {
  final Map<String, dynamic> story;
  final VoidCallback onUpdated;

  const StoryEditScreen({
    super.key,
    required this.story,
    required this.onUpdated,
  });

  @override
  State<StoryEditScreen> createState() => _StoryEditScreenState();
}

class _StoryEditScreenState extends State<StoryEditScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  String? _selectedFilePath;
  String? _contentType; // 'image' or 'video'

  @override
  void initState() {
    super.initState();
    // Определяем текущий тип контента
    final url = widget.story['url'] as String? ?? '';
    _contentType = _isVideoUrl(url) ? 'video' : 'image';
  }

  bool _isVideoUrl(String url) {
    return url.toLowerCase().endsWith('.mp4') || 
           url.toLowerCase().endsWith('.mov') || 
           url.toLowerCase().endsWith('.webm');
  }

  Future<void> _pickMedia(bool isVideo) async {
    try {
      // Запрашиваем разрешение на доступ к файлам
      final hasPermission = await PermissionService.requestStoragePermission(context);
      if (!hasPermission) {
        return;
      }

      final XFile? file = isVideo
          ? await _picker.pickVideo(source: ImageSource.gallery)
          : await _picker.pickImage(source: ImageSource.gallery);

      if (file != null) {
        setState(() {
          _selectedFilePath = file.path;
          _contentType = isVideo ? 'video' : 'image';
        });
      }
    } catch (e) {
      print('🔴 [StoryEdit] Error picking media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка выбора файла: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateStory() async {
    if (_selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Выберите новое фото или видео'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final box = await Hive.openBox('user');
      final token = box.get('auth_token') as String?;
      
      // ВСЕГДА берем userId только из user['id'], игнорируем user_id
      final userData = box.get('user');
      int? userId;
      if (userData is Map) {
        userId = userData['id'];
      }

      if (token == null || userId == null) {
        throw Exception('Не авторизован');
      }

      final userIdInt = userId is int ? userId : int.tryParse(userId?.toString() ?? '0');
      if (userIdInt == null) {
        throw Exception('Неверный ID пользователя');
      }

      print('🔵 [StoryEdit] Updating story: mediaId=${widget.story['id']}, type=$_contentType');

      // Читаем файл и конвертируем в base64
      final file = File(_selectedFilePath!);
      if (!await file.exists()) {
        throw Exception('Файл не найден');
      }

      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      print('🔵 [StoryEdit] File size: ${bytes.length} bytes');

      // Загружаем файл в temp
      final storiesApi = StoriesApiRepository();
      final tempResult = await storiesApi.uploadToTemp(
        userId: userIdInt,
        token: token,
        fileBase64: base64String,
      );

      if (tempResult['status'] != true) {
        throw Exception(tempResult['error'] ?? 'Ошибка загрузки в temp');
      }

      // tempResult['data'] это Map с полями name и link
      final tempData = tempResult['data'];
      final fileName = tempData is Map ? tempData['name'] as String : tempData.toString();
      print('✅ [StoryEdit] Uploaded to temp: $fileName');

      // Обновляем историю
      Map<String, dynamic> result;

      // Приводим mediaId к int
      final mediaId = widget.story['id'] is int 
          ? widget.story['id'] 
          : int.tryParse(widget.story['id']?.toString() ?? '0');
      
      if (mediaId == null || mediaId == 0) {
        throw Exception('Неверный ID истории');
      }

      if (_contentType == 'video') {
        // Для видео передаем base64 напрямую
        const videoDuration = 5000; // 5 секунд по умолчанию
        
        result = await storiesApi.updateVideo(
          userId: userIdInt,
          token: token,
          mediaId: mediaId,
          fileName: fileName,
          fileBase64: base64String,
          videoDuration: videoDuration,
        );
      } else {
        result = await storiesApi.updateImage(
          userId: userIdInt,
          token: token,
          mediaId: mediaId,
          fileName: fileName,
        );
      }

      if (mounted) {
        if (result['status'] == true) {
          // Обновляем URL в story объекте с timestamp для обхода кэша
          final baseUrl = ApiConfig.mediaUrl;
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final newUrl = '$baseUrl/public/media/user_stories/$fileName?t=$timestamp';
          widget.story['url'] = newUrl;
          
          print('✅ [StoryEdit] Story updated with new URL: $newUrl');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('История обновлена'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Закрываем экран и вызываем callback
          Navigator.of(context).pop();
          widget.onUpdated();
        } else {
          throw Exception(result['error'] ?? 'Ошибка обновления');
        }
      }
    } catch (e) {
      print('🔴 [StoryEdit] Update error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff151e27) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? const Color(0xff233040) : Colors.grey[200]!;
    
    final currentUrl = ApiConfig.replaceMediaUrl(
      widget.story['url'] as String? ?? ''
    );
    final isCurrentVideo = _isVideoUrl(currentUrl);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Редактировать историю',
          style: GoogleFonts.montserrat(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isUploading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xff917dfa),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Обновление истории...',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      color: isDark ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Текущее медиа
                  Text(
                    'Текущее ${isCurrentVideo ? 'видео' : 'фото'}',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    height: 400,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: isCurrentVideo
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.videocam, size: 64, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text(
                                    'Видео',
                                    style: GoogleFonts.montserrat(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Image.network(
                              currentUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(Icons.error, color: Colors.red, size: 48),
                                );
                              },
                            ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // Новое медиа (если выбрано)
                  if (_selectedFilePath != null) ...[
                    Text(
                      'Новое ${_contentType == 'video' ? 'видео' : 'фото'}',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 12),
                    Container(
                      height: 400,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _contentType == 'video'
                            ? _VideoPreview(filePath: _selectedFilePath!)
                            : Image.file(
                                File(_selectedFilePath!),
                                fit: BoxFit.contain,
                              ),
                      ),
                    ),
                    SizedBox(height: 24),
                  ],

                  // Кнопки выбора
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickMedia(false),
                          icon: Icon(Icons.photo_library),
                          label: Text('Выбрать фото'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Color(0xff917dfa),
                            backgroundColor: isDark ? const Color(0xff233040) : Colors.white,
                            side: BorderSide(color: Color(0xff917dfa)),
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickMedia(true),
                          icon: Icon(Icons.videocam),
                          label: Text('Выбрать видео'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Color(0xff917dfa),
                            backgroundColor: isDark ? const Color(0xff233040) : Colors.white,
                            side: BorderSide(color: Color(0xff917dfa)),
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),

                  // Кнопка обновления
                  ElevatedButton(
                    onPressed: _selectedFilePath != null ? _updateStory : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xff917dfa),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: isDark ? const Color(0xff233040) : Colors.grey[300],
                      disabledForegroundColor: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                    child: Text(
                      'Обновить историю',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}


// Виджет для превью видео
class _VideoPreview extends StatefulWidget {
  final String filePath;

  const _VideoPreview({required this.filePath});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
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
          print('✅ [VideoPreview] Video ready');
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
          print('🔵 [VideoPreview] Playback ended, restarting...');
          controller.stop();
          controller.play();
          break;
          
        case PlaybackErrorEvent():
          print('🔴 [VideoPreview] Playback error: ${event.errorMessage}');
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
      print('🔵 [VideoPreview] Loading video from: ${widget.filePath}');
      await controller.loadVideo(
        VideoSource(
          path: widget.filePath,
          type: VideoSourceType.file,
        ),
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          print('🔴 [VideoPreview] Video loading timeout');
          if (mounted) {
            setState(() {
              _hasError = true;
            });
          }
        },
      );
    } catch (e) {
      print('🔴 [VideoPreview] Error loading video: $e');
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
            Icon(Icons.error, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              'Не удалось загрузить видео',
              style: GoogleFonts.montserrat(
                color: Colors.grey[600],
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
              color: Color(0xff917dfa),
            ),
          ),
      ],
    );
  }
}
