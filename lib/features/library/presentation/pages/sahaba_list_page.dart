import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/islamic_data.dart';
import '../../../../main.dart'; // for pushDark
import '../../../../core/widgets/glass_scaffold.dart';
import '../../../../core/widgets/glass_widgets.dart';
import 'prophet_story_detail_page.dart';

class SahabaListPage extends StatefulWidget {
  const SahabaListPage({super.key});

  @override
  State<SahabaListPage> createState() => _SahabaListPageState();
}

class _SahabaListPageState extends State<SahabaListPage> {
  late List<String> allSahaba;
  List<String> filteredSahaba = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    allSahaba = IslamicData.menAroundTheMessenger;
    filteredSahaba = allSahaba;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      filteredSahaba = allSahaba
          .where((s) => s.contains(_searchController.text))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'رجال حول الرسول',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 18),
            ),
            Text(
              'المرجع: كتاب خالد محمد خالد',
              style: GoogleFonts.tajawal(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'بحث عن صحابي...',
                hintStyle: GoogleFonts.tajawal(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.amber),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
      ),
      body: filteredSahaba.isEmpty
          ? Center(
              child: Text(
                'لم يتم العثور على نتائج',
                style: GoogleFonts.tajawal(color: Colors.white54),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredSahaba.length,
              itemBuilder: (context, index) {
                final entry = filteredSahaba[index];
                final parts = entry.split(':\n');
                final name = parts[0];
                final brief = parts.length > 1 ? parts[1] : '';

                return GlassPanel(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(15),
                  accent: Colors.amber,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    title: Text(
                      name,
                      style: GoogleFonts.tajawal(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        brief,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.tajawal(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.amber, size: 16),
                    onTap: () {
                      pushDark(context, ProphetStoryDetailPage(
                        title: name,
                        content: brief,
                      ));
                    },
                  ),
                );
              },
            ),
    );
  }
}
