import 'package:flutter/material.dart';

import 'pages/home_page.dart';

class AppRoute {
  static const homePage = '/home_page';

  static Route<Object>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case homePage:
        return MaterialPageRoute(
          builder: (_) => const HomePage(),
          settings: settings,
        );
      default:
        return null;
    }
  }
}
