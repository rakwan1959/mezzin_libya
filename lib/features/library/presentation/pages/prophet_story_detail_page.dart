import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/glass_theme.dart';
import '../../../../core/widgets/glass_scaffold.dart';

class ProphetStoryDetailPage extends StatefulWidget {
  final String title;
  final String content;

  const ProphetStoryDetailPage({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  State<ProphetStoryDetailPage> createState() => _ProphetStoryDetailPageState();
}

class _ProphetStoryDetailPageState extends State<ProphetStoryDetailPage> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
  }

  void _checkFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList('favorite_stories') ?? [];
    if (mounted) {
      setState(() {
        _isFavorite = favorites.contains(widget.title);
      });
    }
  }

  void _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favorites = prefs.getStringList('favorite_stories') ?? [];
    if (_isFavorite) {
      favorites.remove(widget.title);
    } else {
      favorites.add(widget.title);
    }
    await prefs.setStringList('favorite_stories', favorites);
    setState(() {
      _isFavorite = !_isFavorite;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorite ? 'تمت الإضافة للمفضلة' : 'تمت الإزالة من المفضلة',
            style: GoogleFonts.tajawal(),
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            actions: [
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: _isFavorite ? Colors.redAccent : Colors.white60,
                ),
                onPressed: _toggleFavorite,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                widget.title,
                style: GoogleFonts.tajawal(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.amber,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 1.2,
                    colors: [
                      GlassPalette.gold.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.history_edu_rounded,
                    size: 80,
                    color: Colors.amber.withOpacity(0.1),
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.07),
                    Colors.white.withValues(alpha: 0.02),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Text(
                    widget.content,
                    textAlign: TextAlign.justify,
                    textDirection: TextDirection.rtl,
                    style: GoogleFonts.amiri(
                      fontSize: 20,
                      height: 1.8,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
