import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'injection_container.dart' as di;
import 'presentation/game/game_controller.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/state/mission_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await di.init();
  runApp(const KampusApp());
}

class KampusApp extends StatelessWidget {
  const KampusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => di.sl<MissionProvider>()..initMission(),
        ),
        ChangeNotifierProvider(create: (_) => di.sl<GameController>()),
      ],
      child: MaterialApp(
        title: 'Kampüs Uygulaması',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF1a1a2e),
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFFe94560),
            secondary: const Color(0xFF7c3aed),
            surface: const Color(0xFF16213e),
          ),
          fontFamily: 'Segoe UI',
        ),
        home: const HomePage(),
      ),
    );
  }
}
