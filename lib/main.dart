import 'package:flutter/material.dart';
import 'package:quran_app_2025/core/routes.dart';
import 'package:quran_app_2025/core/themes/text_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quran App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(textTheme: CustomTextTheme.theme),
      initialRoute: Routes.initalRoute,
      routes: Routes.routes,
    );
  }
}
