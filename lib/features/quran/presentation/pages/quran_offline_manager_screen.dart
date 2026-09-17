import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../injection_container.dart';
import '../../data/datasources/quran_download_service.dart';
import '../../../../core/widgets/glass_scaffold.dart';

const Color _gold = Color(0xFFDFBA6B);
const Color _bgCard = Color(0xFF0F264A);
const Color _green = Color(0xFF10B981);

/// زر ذهبي كبير (مثل «ابدأ التحميل») لا يُقتطع نصّه أبداً.
///
/// الخط الأميري يمتد حبره فوق وبين السطر، وحجم خط الجهاز قد يكبّر النص،
/// لذلك نترك ارتفاع الزر **ينمو مع المحتوى** بدل تثبيته على ارتفاع صغير
/// كان يقصّ أسفل الكلمة (تظهر بعض الحروف فقط).
Widget buildStartDownloadButton({
  required VoidCallback onPressed,
  String label = 'ابدأ التحميل',
  IconData icon = Icons.download_rounded,
  Color background = _gold,
  Color foreground = const Color(0xFF07152B),
  double elevation = 4,
}) {
  return ElevatedButton.icon(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      minimumSize: const Size.fromHeight(56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: elevation,
    ),
    icon: Icon(icon, size: 20),
    label: Text(
      label,
      maxLines: 1,
      softWrap: false,
      style: GoogleFonts.amiri(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        height: 1.2,
      ),
    ),
  );
}

class QuranOfflineManagerScreen extends StatefulWidget {
  const QuranOfflineManagerScreen({super.key});

  @override
  State<QuranOfflineManagerScreen> createState() => _QuranOfflineManagerScreenState();
}

class _QuranOfflineManagerScreenState extends State<QuranOfflineManagerScreen> {
  final QuranDownloadService _downloadService = sl<QuranDownloadService>();

  int _totalStorageBytes = 0;
  Map<String, int> _reciterStorageBytes = {};
  Map<String, int> _reciterDownloadedCounts = {};
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  Future<void> _refreshStats() async {
    setState(() => _isLoadingStats = true);
    int totalBytes = 0;
    final Map<String, int> storageMap = {};
    final Map<String, int> countMap = {};

    for (final key in QuranDownloadService.reciterNames.keys) {
      final bytes = await _downloadService.getReciterStorageSize(key);
      final count = await _downloadService.getDownloadedCount(key);
      storageMap[key] = bytes;
      countMap[key] = count;
      totalBytes += bytes;
    }

    if (mounted) {
      setState(() {
        _totalStorageBytes = totalBytes;
        _reciterStorageBytes = storageMap;
        _reciterDownloadedCounts = countMap;
        _isLoadingStats = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: GlassScaffold(
        animated: false,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'إدارة التنزيلات',
              style: GoogleFonts.amiri(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _gold),
              tooltip: 'تحديث الإحصائيات',
              onPressed: _refreshStats,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: _gold.withValues(alpha: 0.25),
            ),
          ),
        ),
        body: Container(
          color: Colors.transparent,
          child: SafeArea(
            child: ValueListenableBuilder<bool>(
              valueListenable: _downloadService.isGlobalDownloading,
              builder: (context, isGlobalDownloading, _) {
                return ValueListenableBuilder<Map<String, ReciterDownloadState>>(
                  valueListenable: _downloadService.downloadStates,
                  builder: (context, states, _) {
                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildStorageOverviewCard(isGlobalDownloading),
                        const SizedBox(height: 14),
                        _buildMasterDownloadCard(isGlobalDownloading),
                        const SizedBox(height: 20),
                        _buildSectionHeader('قراء القرآن الكريم', '${QuranDownloadService.reciterNames.length} قراء • رواية حفص وقالون'),
                        const SizedBox(height: 10),
                        ...QuranDownloadService.reciterNames.keys.map((key) {
                          final reciterName = QuranDownloadService.reciterNames[key]!;
                          final totalItems = _downloadService.getTotalItemsForReciter(key);
                          final isFullSurah = _downloadService.isFullSurahReciter(key);
                          final state = states[key];
                          final isDownloading = state?.isDownloading ?? false;
                          final completed = isDownloading
                              ? (state?.completedItems ?? 0)
                              : (_reciterDownloadedCounts[key] ?? 0);
                          final double progress = totalItems > 0 ? (completed / totalItems) : 0.0;
                          final bytes = _reciterStorageBytes[key] ?? 0;

                          return _buildReciterCard(
                            reciterKey: key,
                            reciterName: reciterName,
                            isFullSurah: isFullSurah,
                            completedItems: completed,
                            totalItems: totalItems,
                            storageBytes: bytes,
                            progress: progress,
                            isDownloading: isDownloading,
                            downloadState: state,
                            isGlobalDownloading: isGlobalDownloading,
                          );
                        }),
                        const SizedBox(height: 30),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── عنوان القسم ──────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3,
            height: 28,
            decoration: BoxDecoration(
              color: _gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.amiri(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _gold,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.amiri(
                    fontSize: 13,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── كارد المساحة الإجمالية ────────────────────────────────────────────────
  Widget _buildStorageOverviewCard(bool isGlobalDownloading) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: _gold.withValues(alpha: 0.5), width: 1.2),
                ),
                child: const Icon(Icons.sd_storage_rounded, color: _gold, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المساحة الصوتية المحملة',
                      style: GoogleFonts.amiri(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _isLoadingStats
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
                          )
                        : Text(
                            QuranDownloadService.formatBytes(_totalStorageBytes),
                            style: GoogleFonts.amiri(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _gold,
                            ),
                          ),
                  ],
                ),
              ),
              if (_totalStorageBytes > 0 && !isGlobalDownloading)
                _buildIconTextButton(
                  icon: Icons.delete_sweep_rounded,
                  label: 'تفريغ',
                  color: Colors.redAccent,
                  onPressed: _confirmDeleteAllAudio,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _green.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.offline_pin_rounded, color: _green, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'التلاوات المحملة تعمل 100% بدون إنترنت',
                    style: GoogleFonts.amiri(
                      fontSize: 13,
                      color: _green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── كارد تحميل الكل ──────────────────────────────────────────────────────
  Widget _buildMasterDownloadCard(bool isGlobalDownloading) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E3A8A).withValues(alpha: 0.90),
            const Color(0xFF172554).withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: 0.45), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _gold.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.cloud_download_rounded, color: _gold, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تحميل لجميع القراء',
                      style: GoogleFonts.amiri(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'تحميل كامل لجميع القراء بالتتابع',
                      style: GoogleFonts.amiri(
                        fontSize: 13,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: _downloadService.globalStatusText,
            builder: (context, status, _) {
              if (status.isEmpty && !isGlobalDownloading) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'يتطلب اتصال واي فاي ومساحة كافية (10-14 جيجابايت). يمكنك تحميل قارئ محدد من القائمة أدناه.',
                    style: GoogleFonts.amiri(
                      fontSize: 12,
                      color: Colors.white54,
                      height: 1.5,
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(_gold),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    status,
                    style: GoogleFonts.amiri(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _gold,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: isGlobalDownloading
                ? buildStartDownloadButton(
                    onPressed: () => _downloadService.cancelDownload(),
                    label: 'إلغاء التحميل',
                    icon: Icons.stop_circle_rounded,
                    background: Colors.redAccent.withValues(alpha: 0.85),
                    foreground: Colors.white,
                    elevation: 0,
                  )
                : buildStartDownloadButton(onPressed: _confirmDownloadAll),
          ),
        ],
      ),
    );
  }

  // ── كارد القارئ ──────────────────────────────────────────────────────────
  Widget _buildReciterCard({
    required String reciterKey,
    required String reciterName,
    required bool isFullSurah,
    required int completedItems,
    required int totalItems,
    required int storageBytes,
    required double progress,
    required bool isDownloading,
    required ReciterDownloadState? downloadState,
    required bool isGlobalDownloading,
  }) {
    final bool isCompleted = completedItems >= totalItems && totalItems > 0;
    final Color borderColor = isCompleted
        ? _green.withValues(alpha: 0.55)
        : isDownloading
            ? _gold.withValues(alpha: 0.75)
            : Colors.white.withValues(alpha: 0.14);

    // استخراج اسم القارئ والرواية/النوع بشكل منسق ومنفصل
    final String cleanName;
    final String? narrationTag;
    if (reciterName.contains('(')) {
      final parts = reciterName.split('(');
      cleanName = parts[0].trim();
      narrationTag = parts[1].replaceAll(')', '').trim();
    } else {
      cleanName = reciterName.trim();
      narrationTag = null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1F3D).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: isDownloading || isCompleted ? 1.5 : 1.0),
        boxShadow: [
          if (isDownloading)
            BoxShadow(color: _gold.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── صف الاسم والأزرار ──────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // أيقونة الحالة
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? _green.withValues(alpha: 0.15)
                      : isDownloading
                          ? _gold.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted
                        ? _green
                        : isDownloading
                            ? _gold
                            : Colors.white12,
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : isDownloading
                          ? Icons.sync_rounded
                          : Icons.mic_rounded,
                  color: isCompleted ? _green : _gold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // اسم القارئ ومعلوماته
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cleanName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.amiri(
                        fontSize: (reciterKey == 'ar.sudais' || cleanName.contains('السديس')) ? 12.0 : 13.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (narrationTag != null && narrationTag.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: _gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _gold.withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              narrationTag.replaceAll('-', '•').trim(),
                              style: GoogleFonts.amiri(
                                fontSize: 10.5,
                                color: _gold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            _buildStatusText(
                              isCompleted: isCompleted,
                              isDownloading: isDownloading,
                              completed: completedItems,
                              total: totalItems,
                              bytes: storageBytes,
                              isFullSurah: isFullSurah,
                              downloadState: downloadState,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.amiri(
                              fontSize: 11.5,
                              color: isCompleted
                                  ? _green
                                  : isDownloading
                                      ? _gold
                                      : Colors.white54,
                              fontWeight: isCompleted || isDownloading
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // أزرار التحكم
              _buildReciterActions(
                reciterKey: reciterKey,
                reciterName: reciterName,
                isDownloading: isDownloading,
                isCompleted: isCompleted,
                isGlobalDownloading: isGlobalDownloading,
                storageBytes: storageBytes,
                completedItems: completedItems,
              ),
            ],
          ),
          // ── شريط التقدم ────────────────────────────────────────────────
          if (isDownloading || (completedItems > 0 && !isCompleted)) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted ? _green : _gold,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.amiri(fontSize: 11, color: _gold, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$completedItems / $totalItems',
                  style: GoogleFonts.amiri(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _buildStatusText({
    required bool isCompleted,
    required bool isDownloading,
    required int completed,
    required int total,
    required int bytes,
    required bool isFullSurah,
    required ReciterDownloadState? downloadState,
  }) {
    final unit = isFullSurah ? 'سورة' : 'آية';
    if (isCompleted) return 'مكتمل • ${QuranDownloadService.formatBytes(bytes)}';
    if (isDownloading) return '${downloadState?.currentStatus ?? 'جاري التحميل...'} ($completed/$total)';
    if (completed > 0) return '$completed/$total $unit • ${QuranDownloadService.formatBytes(bytes)}';
    return '$total $unit';
  }

  Widget _buildReciterActions({
    required String reciterKey,
    required String reciterName,
    required bool isDownloading,
    required bool isCompleted,
    required bool isGlobalDownloading,
    required int storageBytes,
    required int completedItems,
  }) {
    if (isDownloading) {
      return IconButton(
        icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 24),
        tooltip: 'إلغاء التحميل',
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(),
        onPressed: () => _downloadService.cancelDownload(),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (storageBytes > 0) ...[
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent.withValues(alpha: 0.8),
              size: 20,
            ),
            tooltip: 'حذف تنزيلات هذا القارئ',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: () => _confirmDeleteReciter(reciterKey, reciterName),
          ),
          const SizedBox(width: 4),
        ],
        if (!isCompleted)
          ElevatedButton(
            onPressed: isGlobalDownloading ? null : () => _startDownloadReciter(reciterKey),
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: const Color(0xFF07152B),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(60, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              completedItems > 0 ? 'استكمال' : 'تحميل',
              style: GoogleFonts.amiri(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _green.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.done_all_rounded, color: _green, size: 14),
                const SizedBox(width: 3),
                Text(
                  'جاهز',
                  style: GoogleFonts.amiri(fontSize: 11, color: _green, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildIconTextButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.4)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: GoogleFonts.amiri(fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ── منطق التنزيل والحذف ──────────────────────────────────────────────────

  void _startDownloadReciter(String reciterKey) async {
    final success = await _downloadService.downloadReciter(reciterKey);
    await _refreshStats();
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'اكتمل تحميل المصحف للقارئ بنجاح!',
            textAlign: TextAlign.center,
            style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      );
    }
  }

  void _confirmDownloadAll() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: _gold, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'تحميل القرآن لجميع القراء',
                  style: GoogleFonts.amiri(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          content: Text(
            'سيتم تنزيل التلاوات الكاملة لجميع القراء (أكثر من 31 ألف ملف صوتي بحجم 10-14 جيجابايت).\n\nيُرجى التأكد من توفر مساحة كافية والاتصال بشبكة واي فاي سريعة.\n\nهل تود البدء الآن؟',
            style: GoogleFonts.amiri(fontSize: 14, color: Colors.white70, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.amiri(color: Colors.white60, fontSize: 14)),
            ),
            buildStartDownloadButton(
              onPressed: () {
                Navigator.pop(ctx);
                _downloadService.downloadAllReciters().then((_) => _refreshStats());
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteReciter(String reciterKey, String reciterName) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'حذف تنزيلات القارئ',
            style: GoogleFonts.amiri(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          content: Text(
            'هل أنت متأكد من حذف التلاوات المحملة لـ $reciterName وتفريغ المساحة؟',
            style: GoogleFonts.amiri(fontSize: 14, color: Colors.white70, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.amiri(color: Colors.white60, fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _downloadService.deleteReciterAudio(reciterKey);
                await _refreshStats();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('حذف وتفريغ', style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAllAudio() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'تفريغ جميع الصوتيات المحملة',
            style: GoogleFonts.amiri(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          content: Text(
            'سيتم حذف جميع ملفات الصوت المحملة للقرآن الكريم لكافة القراء، هل أنت متأكد؟',
            style: GoogleFonts.amiri(fontSize: 14, color: Colors.white70, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.amiri(color: Colors.white60, fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _downloadService.deleteAllAudio();
                await _refreshStats();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('حذف الكل', style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
