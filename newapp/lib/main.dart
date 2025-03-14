import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:newapp/services/pocketbase_service.dart';
import 'package:newapp/screens/home_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Web-specific initialization if needed
  if (kIsWeb) {
    // Any web-specific setup can go here
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PocketbaseService()),
      ],
      child: MaterialApp(
        title: 'Truck Center Inventory',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
} 