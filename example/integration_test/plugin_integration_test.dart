import 'package:flutter_rhwp/flutter_rhwp.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the example app', (tester) async {
    final document = await Rhwp.createEmpty(fileName: 'viewer.hwp');
    addTearDown(document.close);

    await tester.pumpWidget(RhwpViewer(document: document));
    await tester.pumpAndSettle();

    expect(find.byType(RhwpViewer), findsOneWidget);
  });
}
