import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/repositories/quran_repository.dart';
import '../../domain/entities/bookmark.dart';
import '../widgets/islamic_surah_name.dart';
import 'quran_view_page.dart';
import '../../../../injection_container.dart';
import '../../../../core/theme/glass_theme.dart';
import '../../../../core/widgets/glass_scaffold.dart';
import '../../../../core/widgets/glass_widgets.dart';

class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  List<Bookmark> _bookmarks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final result = await sl<QuranRepository>().getBookmarks();
    result.fold(
      (failure) => setState(() => _isLoading = false),
      (bookmarks) => setState(() {
        _bookmarks = bookmarks;
        _isLoading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: GlassAppBar(
        title: Text(
          'العلامات المرجعية',
          style: GoogleFonts.notoKufiArabic(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        accent: GlassPalette.gold,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: GlassPalette.gold))
          : _bookmarks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              GlassPalette.gold.withValues(alpha: 0.20),
                              GlassPalette.gold.withValues(alpha: 0.02),
                            ],
                          ),
                          border: Border.all(color: GlassPalette.gold.withValues(alpha: 0.28)),
                        ),
                        child: Icon(
                          Icons.bookmark_border,
                          size: 54,
                          color: GlassPalette.gold.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'لا توجد علامات مرجعية حالياً',
                        style: GoogleFonts.notoKufiArabic(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
                  itemCount: _bookmarks.length,
                  itemBuilder: (context, index) {
                    final b = _bookmarks[index];
                    return GlassPanel(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(16),
                      accent: GlassPalette.gold,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuranViewPage(
                              initialSurahId: b.surahId,
                              initialAyah: b.ayahNumber,
                            ),
                          ),
                        );
                      },
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                GlassPalette.gold.withValues(alpha: 0.24),
                                GlassPalette.gold.withValues(alpha: 0.05),
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: GlassPalette.gold.withValues(alpha: 0.32)),
                          ),
                          child: const Icon(Icons.bookmark, color: GlassPalette.gold),
                        ),
                        title: IslamicSurahName(
                          surahName: b.surahName,
                          style: GoogleFonts.amiri(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          ornamentColor: GlassPalette.gold.withValues(alpha: 0.55),
                          ornamentWidth: 20,
                          ornamentHeight: 11,
                          mainAxisAlignment: MainAxisAlignment.start,
                        ),
                        subtitle: Text(
                          'آية رقم ${b.ayahNumber}',
                          style: GoogleFonts.notoKufiArabic(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.58),
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: GlassPalette.danger),
                          onPressed: () async {
                            await sl<QuranRepository>().removeBookmark(b.surahId, b.ayahNumber);
                            _loadBookmarks();
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
