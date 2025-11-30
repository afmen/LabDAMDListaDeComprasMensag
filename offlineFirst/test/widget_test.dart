import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlineFirst/main.dart';

void main() {
  // Configuração dos Mocks dos Canais de Plataforma
  // Isso impede que o teste falhe ao tentar acessar recursos nativos reais (SQLite, Rede, etc)
  setUpAll(() {
    // 1. Mock do Path Provider (para o caminho do banco de dados)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.'; // Retorna um caminho fictício
      },
    );

    // 2. Mock do Sqflite (Banco de Dados)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.tekartik.sqflite'),
      (MethodCall methodCall) async {
        // Simula respostas de sucesso para abertura e consultas do banco
        if (methodCall.method == 'getDatabasesPath') {
          return '.';
        }
        if (methodCall.method == 'openDatabase') {
          return 1; // ID do banco simulado
        }
        if (methodCall.method == 'query') {
          return []; // Retorna lista vazia de compras
        }
        return null;
      },
    );

    // 3. Mock do Connectivity Plus (Rede)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (MethodCall methodCall) async {
        return 'wifi'; // Simula conexão ativa
      },
    );
  });

  testWidgets('Smoke test da Lista de Compras', (WidgetTester tester) async {
    // 1. Renderiza a aplicação
    await tester.pumpWidget(const MyApp());
    
    // Aguarda as animações e o carregamento inicial (init do Provider)
    await tester.pumpAndSettle();

    // 2. Verificações Visuais Básicas
    
    // Verifica se o título da AppBar está correto
    expect(find.text('Minhas Compras'), findsOneWidget);

    // Verifica se o estado vazio é exibido (pois o mock do banco retornou lista vazia [])
    // Nota: O texto exato depende do que você colocou no home_screen.dart. 
    // Assumindo 'Nenhuma lista criada' ou similar.
    expect(find.textContaining('Nenhuma lista'), findsOneWidget);

    // Verifica se o botão de adicionar (Floating Action Button) existe
    expect(find.byIcon(Icons.add), findsOneWidget);

    // 3. Interação Básica
    
    // Toca no botão de adicionar
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle(); // Aguarda a navegação

    // Verifica se navegou para a tela de formulário (procura pelo título "Nova Lista")
    expect(find.text('Nova Lista'), findsOneWidget);
  });
}