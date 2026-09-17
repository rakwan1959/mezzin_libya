// مشغّل لقطات الشاشة — يكتب كل صورة يلتقطها الاختبار إلى مجلد screenshots/.
//
// التشغيل (على macOS مع محاكي iOS):
//   flutter drive \
//     --driver=test_driver/screenshot_driver.dart \
//     --target=integration_test/app_store_screenshots_test.dart \
//     -d <simulator-udid>
//
// أو عبر سير العمل الجاهز: .github/workflows/ios_screenshots.yml
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (
      String name,
      List<int> bytes, [
      Map<String, Object?>? args,
    ]) async {
      final Directory dir = Directory('screenshots');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final File file = File('${dir.path}/$name.png');
      file.writeAsBytesSync(bytes);
      stdout.writeln('  📸 screenshots/$name.png (${bytes.length} bytes)');
      return true;
    },
  );
}
