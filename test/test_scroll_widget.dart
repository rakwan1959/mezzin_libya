import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muezzin_libya_app/features/quran/domain/entities/surah.dart';
import 'package:muezzin_libya_app/features/quran/presentation/bloc/quran_audio_bloc.dart';
import 'package:muezzin_libya_app/features/quran/presentation/pages/quran_view_page.dart';
import 'package:muezzin_libya_app/injection_container.dart' as di;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await di.init();
  });

  testWidgets('QuranViewPage accepts initialAyah without crashing', (WidgetTester tester) async {
    const surah = Surah(
      id: 1,
      name: "الفاتحة",
      revelationType: "مكية",
      ayahsCount: 7,
      nameArabic: "الفاتحة",
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<QuranAudioBloc>(
          create: (_) => di.sl<QuranAudioBloc>(),
          child: const QuranViewPage(
            surah: surah,
            initialAyah: 4,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // انتظار انتهاء مؤقت إزالة تمييز الآية (5 ثوانٍ) والتمرير حتى لا يبقى أي مؤقت معلّق
    await tester.pump(const Duration(seconds: 6));

    expect(find.byType(QuranViewPage), findsOneWidget);
  });
}
