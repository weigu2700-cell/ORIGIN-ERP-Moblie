import 'package:flutter/material.dart';
import 'package:origin_mobile/app/app.dart';
import 'package:origin_mobile/core/api.dart';
import 'package:origin_mobile/core/config.dart';
import 'package:origin_mobile/core/session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session(
    ApiClient(AppConfig.apiBaseUrl),
    SecureTokenVault(key: AppConfig.tokenKey),
  );
  runApp(OriginApp(session));
  session.restore();
}
