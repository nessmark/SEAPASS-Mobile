import 'package:flutter/material.dart';

/// A global [RouteObserver] used by screens that need lifecycle callbacks
/// (e.g. [RouteAware]) when other routes are pushed on top of them.
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

/// Global navigator key allowing headless navigation (such as 401 Unauthorized redirects).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
