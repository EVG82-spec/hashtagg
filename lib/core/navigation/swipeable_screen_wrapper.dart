import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Wrapper для экранов GoRouter, добавляющий полноэкранный свайп назад
class SwipeableScreenWrapper extends StatefulWidget {
  final Widget child;
  final bool canSwipe;

  const SwipeableScreenWrapper({
    super.key,
    required this.child,
    this.canSwipe = true,
  });

  @override
  State<SwipeableScreenWrapper> createState() => _SwipeableScreenWrapperState();
}

class _SwipeableScreenWrapperState extends State<SwipeableScreenWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragDistance = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    if (!widget.canSwipe) return;
    setState(() {
      _isDragging = true;
      _dragDistance = 0;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!widget.canSwipe || !_isDragging) return;
    setState(() {
      _dragDistance += details.primaryDelta ?? 0;
      if (_dragDistance < 0) _dragDistance = 0;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!widget.canSwipe || !_isDragging) return;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final velocity = details.primaryVelocity ?? 0;
    
    // Если свайп больше 50% экрана или скорость > 900px/s - закрываем
    if (_dragDistance > screenWidth * 0.5 || velocity > 900) {
      _controller.forward().then((_) {
        if (mounted && context.canPop()) {
          context.pop();
        }
      });
    } else {
      // Возвращаем на место
      setState(() {
        _dragDistance = 0;
        _isDragging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final offset = _isDragging ? _dragDistance / screenWidth : 0.0;

    return GestureDetector(
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Transform.translate(
        offset: Offset(screenWidth * offset, 0),
        child: widget.child,
      ),
    );
  }
}
