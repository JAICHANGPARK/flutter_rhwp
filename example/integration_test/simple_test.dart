import 'package:flutter_rhwp/flutter_rhwp.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('can create an empty rhwp document', () async {
    final document = await Rhwp.createEmpty(fileName: 'integration.hwp');
    addTearDown(document.close);

    expect(await document.pageCount, greaterThanOrEqualTo(1));
  });
}
