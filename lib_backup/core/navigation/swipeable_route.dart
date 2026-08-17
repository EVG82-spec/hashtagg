import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:full_swipe_back_gesture/full_swipe_back_gesture.dart';

BackSwipePageRoute<T> createSwipeableRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool maintainState = true,
  bool fullscreenDialog = false,
  double? edgeStartWidthPx,
}) {
  return BackSwipePageRoute<T>(
    builder: builder,
    settings: settings,
    edgeStartWidthPx: edgeStartWidthPx ?? 0.0,
  );
}

CupertinoPageRoute<T> createEdgeSwipeRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool maintainState = true,
  bool fullscreenDialog = false,
}) {
  return CupertinoPageRoute<T>(
    builder: builder,
    settings: settings,
    maintainState: maintainState,
    fullscreenDialog: fullscreenDialog,
  );
}
