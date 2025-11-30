import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/list_provider.dart';
import 'screens/home_screen.dart';
import 'services/connectivity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConnectivityService.instance.initialize(); // Inicia monitoramento de rede

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ListProvider()..initialize(),
      child: MaterialApp(
        title: 'Lista de Compras Offline',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}