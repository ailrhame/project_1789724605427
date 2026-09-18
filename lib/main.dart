import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// ═══════════════════════════════════════════════════════════
// الألوان
// ═══════════════════════════════════════════════════════════
class AppColors {
  static const bgDark = Color(0xFF121212);
  static const bgCard = Color(0xFF1E1E1E);
  static const bgHover = Color(0xFF2A2A2A);
  static const textMain = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFFA0A0A0);
  static const accentGold = Color(0xFFFFD700);
  static const accentRed = Color(0xFFFF4757);
  static const success = Color(0xFF00FF88);
  static const black = Color(0xFF0A0A0A);
}

// ═══════════════════════════════════════════════════════════
// النماذج
// ═══════════════════════════════════════════════════════════
class ImageItem {
  final String path;
  final String name;
  final int size;
  ImageItem({required this.path, required this.name, required this.size});
}

class ImageGroup {
  final int id;
  String name;
  List<ImageItem> files;
  bool expanded;
  ImageGroup({
    required this.id,
    required this.name,
    required this.files,
    this.expanded = false,
  });
}

// ═══════════════════════════════════════════════════════════
// نقطة البداية
// ═══════════════════════════════════════════════════════════
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const BlackWarpApp());
}

// ═══════════════════════════════════════════════════════════
// التطبيق الرئيسي
// ═══════════════════════════════════════════════════════════
class BlackWarpApp extends StatelessWidget {
  const BlackWarpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlackWarp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bgDark,
        primaryColor: AppColors.accentGold,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accentGold,
          secondary: AppColors.accentGold,
          surface: AppColors.bgCard,
        ),
        useMaterial3: true,
      ),
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const HomeScreen(),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// الشاشة الرئيسية
// ═══════════════════════════════════════════════════════════
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'BlackWarp',
                  style: TextStyle(
                    color: AppColors.accentGold,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 70),
                _mainButton(
                  context,
                  icon: Icons.construction_outlined,
                  label: 'إنشاء أجزاء HTML',
                  isGold: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BuilderScreen()),
                  ),
                ),
                const SizedBox(height: 15),
                _mainButton(
                  context,
                  icon: Icons.menu_book_outlined,
                  label: 'عرض ملف HTML',
                  isGold: false,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReaderScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mainButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isGold,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 25),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isGold ? AppColors.accentGold : Colors.white.withOpacity(0.1),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isGold ? AppColors.accentGold : AppColors.textMain,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isGold ? AppColors.accentGold : AppColors.textMain,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// شاشة البناء
// ═══════════════════════════════════════════════════════════
class BuilderScreen extends StatefulWidget {
  const BuilderScreen({super.key});

  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _titleController = TextEditingController();

  List<ImageGroup> _groups = [];
  int _groupIdCounter = 0;
  double _quality = 0.7;
  bool _isProcessing = false;

  bool _showProgress = false;
  double _progressValue = 0;
  String _progressText = '';

  String _notificationText = '';
  Color _notificationColor = AppColors.accentGold;
  bool _showNotification = false;

  int get _totalImages => _groups.fold(0, (sum, g) => sum + g.files.length);

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _notify(String msg, {Color color = AppColors.accentGold}) {
    setState(() {
      _notificationText = msg;
      _notificationColor = color;
      _showNotification = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showNotification = false);
    });
  }

  // ─────────────────────────────────────────────────────────
  // اختيار الصور
  // ─────────────────────────────────────────────────────────
  Future<void> _pickImages() async {
    if (_isProcessing) {
      _notify('⏳ جارٍ معالجة الملفات السابقة...', color: AppColors.textMuted);
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;

      final files = result.files
          .where((f) => f.path != null)
          .map((f) => ImageItem(path: f.path!, name: f.name, size: f.size))
          .toList();
      await _addFiles(files);
    } catch (e) {
      _notify('❌ خطأ: $e', color: AppColors.accentRed);
    }
  }

  Future<void> _pickFolder() async {
    if (_isProcessing) {
      _notify('⏳ جارٍ معالجة الملفات السابقة...', color: AppColors.textMuted);
      return;
    }
    try {
      final dirPath = await FilePicker.platform.getDirectoryPath();
      if (dirPath == null) return;

      final dir = Directory(dirPath);
      final entries = await dir.list(recursive: false).toList();
      final files = entries
          .whereType<File>()
          .where((f) {
            final p = f.path.toLowerCase();
            return p.endsWith('.jpg') ||
                p.endsWith('.jpeg') ||
                p.endsWith('.png') ||
                p.endsWith('.webp') ||
                p.endsWith('.gif') ||
                p.endsWith('.bmp');
          })
          .map((f) => ImageItem(
                path: f.path,
                name: f.path.split('/').last,
                size: f.lengthSync(),
              ))
          .toList();
      await _addFiles(files);
    } catch (e) {
      _notify('❌ خطأ: $e', color: AppColors.accentRed);
    }
  }

  Future<void> _addFiles(List<ImageItem> files) async {
    if (files.isEmpty) {
      _notify('⚠️ لم يتم العثور على صور.', color: AppColors.accentRed);
      return;
    }

    setState(() => _isProcessing = true);

    files.sort((a, b) {
      final numA = int.tryParse(
              RegExp(r'\d+').firstMatch(a.name)?.group(0) ?? '0') ??
          0;
      final numB = int.tryParse(
              RegExp(r'\d+').firstMatch(b.name)?.group(0) ?? '0') ??
          0;
      return numA.compareTo(numB);
    });

    const autoSplit = 100;
    const defaultChunk = 50;
    const maxChunk = 150;

    if (files.length > autoSplit) {
      final chunkSize = (files.length / (files.length / defaultChunk).ceil())
          .ceil()
          .clamp(defaultChunk, maxChunk);

      for (int i = 0; i < files.length; i += chunkSize) {
        final end = (i + chunkSize < files.length) ? i + chunkSize : files.length;
        _groupIdCounter++;
        _groups.add(ImageGroup(
          id: _groupIdCounter,
          name: 'القائمة ${_groups.length + 1}',
          files: files.sublist(i, end),
        ));
      }
      _notify('✅ تم تقسيم ${files.length} صورة إلى ${_groups.length} قائمة',
          color: AppColors.success);
    } else {
      _groupIdCounter++;
      _groups.add(ImageGroup(
        id: _groupIdCounter,
        name: 'القائمة ${_groups.length + 1}',
        files: files,
      ));
      _notify('✅ تمت إضافة ${files.length} صورة', color: AppColors.success);
    }

    setState(() => _isProcessing = false);
  }

  // ─────────────────────────────────────────────────────────
  // ضغط الصورة
  // ─────────────────────────────────────────────────────────
  Future<Uint8List> _compressImage(
      String path, int maxWidth, double quality) async {
    final bytes = await File(path).readAsBytes();
    if (bytes.length < 200 * 1024) return bytes;

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final resized =
        decoded.width > maxWidth ? img.copyResize(decoded, width: maxWidth) : decoded;
    final encoded = img.encodeJpg(resized, quality: (quality * 100).round());
    return Uint8List.fromList(encoded);
  }

  // ─────────────────────────────────────────────────────────
  // توليد الأجزاء + ZIP
  // ─────────────────────────────────────────────────────────
  Future<void> _generateParts() async {
    final allImages = _groups.expand((g) => g.files).toList();
    if (allImages.isEmpty) {
      _notify('⚠️ يجب رفع الصور أولاً.', color: AppColors.accentRed);
      return;
    }

    setState(() {
      _showProgress = true;
      _progressValue = 0;
      _progressText = 'جاري التجهيز...';
    });

    try {
      double quality = _quality;
      final total = allImages.length;
      if (total > 500) quality = 0.3;
      else if (total > 200) quality = 0.5;

      final title = _titleController.text.trim().isEmpty
          ? 'صفحة المانجا'
          : _titleController.text.trim();
      const imagesPerPart = 40;
      final totalParts = (total / imagesPerPart).ceil();

      final archive = Archive();

      // الفهرس
      final StringBuffer indexHtml = StringBuffer();
      indexHtml.write('<!DOCTYPE html><html lang="ar" dir="rtl"><head>');
      indexHtml.write(
          '<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>$title - الفهرس</title>');
      indexHtml.write(
          '<style>body{background:#121212;color:#fff;text-align:center;font-family:sans-serif;padding:20px;}a{display:block;margin:10px auto;padding:15px;background:#1e1e1e;color:#ffd700;text-decoration:none;border-radius:12px;max-width:300px;border:1px solid #ffd700;}a:hover{background:#2a2a2a;}h1{color:#ffd700;}</style></head><body>');
      indexHtml.write('<h1>$title</h1><p>عدد الصور: $total</p>');
      indexHtml.write(
          '<a href="part_1.html">▶️ ابدأ القراءة (الجزء 1)</a><hr style="border-color:#333;margin:20px;"><div style="display:flex;flex-wrap:wrap;justify-content:center;gap:10px;">');
      for (int p = 1; p <= totalParts; p++) {
        indexHtml.write(
            '<a href="part_$p.html" style="display:inline-block;padding:10px 20px;margin:0;">الجزء $p</a>');
      }
      indexHtml.write('</div></body></html>');
      final idxBytes = utf8.encode(indexHtml.toString());
      archive.addFile(ArchiveFile('index.html', idxBytes.length, idxBytes));

      // الأجزاء
      for (int p = 0; p < totalParts; p++) {
        final start = p * imagesPerPart;
        final end =
            (start + imagesPerPart < total) ? start + imagesPerPart : total;
        final partImages = allImages.sublist(start, end);
        final partNumber = p + 1;

        final StringBuffer partContent = StringBuffer();
        for (int i = 0; i < partImages.length; i++) {
          final compressed =
              await _compressImage(partImages[i].path, 800, quality);
          final base64 = base64Encode(compressed);
          partContent.write(
              '<img src="data:image/jpeg;base64,$base64" style="max-width:100%;height:auto;display:block;margin:0;padding:0;border:none;">');
          _progressValue = (start + i + 1) / total;
          _progressText = 'جاري إنشاء الجزء $partNumber من $totalParts...';
          if (mounted) setState(() {});
        }

        final StringBuffer partHtml = StringBuffer();
        partHtml.write('<!DOCTYPE html><html lang="ar" dir="rtl"><head>');
        partHtml.write(
            '<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>$title - الجزء $partNumber</title>');
        partHtml.write(
            '<style>body{background:#121212;margin:0;padding:0;text-align:center;}img{max-width:100%;height:auto;display:block;margin:0;padding:0;}.nav{position:fixed;bottom:0;left:0;width:100%;background:rgba(0,0,0,0.9);padding:10px;display:flex;justify-content:center;gap:15px;backdrop-filter:blur(5px);border-top:1px solid #ffd700;z-index:10;}.nav a{padding:10px 20px;background:#1e1e1e;color:#ffd700;text-decoration:none;border-radius:8px;border:1px solid #ffd700;font-size:14px;}.nav a:hover{background:#2a2a2a;}</style></head><body>');
        partHtml.write(partContent.toString());
        partHtml.write('<div class="nav"><a href="index.html">🏠 الفهرس</a>');
        if (partNumber > 1) {
          partHtml.write('<a href="part_${partNumber - 1}.html">◀ السابق</a>');
        }
        if (partNumber < totalParts) {
          partHtml.write('<a href="part_${partNumber + 1}.html">التالي ▶</a>');
        }
        partHtml.write('</div></body></html>');

        final partBytes = utf8.encode(partHtml.toString());
        archive.addFile(
            ArchiveFile('part_$partNumber.html', partBytes.length, partBytes));
      }

      _progressText = 'جاري ضغط الملفات في ZIP...';
      if (mounted) setState(() {});

      final zipBytes = ZipEncoder().encode(archive);
      final dir = await getApplicationDocumentsDirectory();
      final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${dir.path}/${safeTitle}_parts.zip');
      await file.writeAsBytes(zipBytes);

      _progressValue = 1.0;
      _progressText = '✅ اكتمل!';
      if (mounted) setState(() {});

      await Share.shareXFiles([XFile(file.path)], subject: title);
      _notify('✅ تم إنشاء $totalParts جزء + الفهرس.', color: AppColors.success);
    } catch (e) {
      _notify('❌ خطأ: $e', color: AppColors.accentRed);
    } finally {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _showProgress = false;
          _progressValue = 0;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  // ملف واحد
  // ─────────────────────────────────────────────────────────
  Future<void> _generateSingleFile() async {
    final total = _totalImages;
    if (total == 0) {
      _notify('⚠️ يجب رفع الصور أولاً.', color: AppColors.accentRed);
      return;
    }
    if (total > 2000) {
      _notify('❌ لا يمكن إنشاء ملف واحد مع 2000+ صورة.',
          color: AppColors.accentRed);
      return;
    }

    setState(() {
      _showProgress = true;
      _progressValue = 0;
      _progressText = 'جاري التجهيز...';
    });

    try {
      double quality = _quality;
      int maxWidth = 700;
      if (total > 800) {
        quality = 0.2;
        maxWidth = 400;
      } else if (total > 400) {
        quality = 0.25;
        maxWidth = 500;
      }

      final title = _titleController.text.trim().isEmpty
          ? 'صفحة المانجا'
          : _titleController.text.trim();

      final StringBuffer body = StringBuffer();
      body.write(
          '<div style="line-height:normal;background:#0a0a0a;padding:20px 15px;text-align:center;"><h1 style="color:#ffd700;">$title</h1><p style="color:#999;">إجمالي الصور: $total</p></div>');

      int processed = 0;
      for (final group in _groups) {
        body.write(
            '<div style="background:#000;color:#ffd700;padding:14px;text-align:center;font-weight:bold;">📁 ${group.name} (${group.files.length} صورة)</div>');
        for (final item in group.files) {
          final compressed = await _compressImage(item.path, maxWidth, quality);
          final base64 = base64Encode(compressed);
          body.write(
              '<img src="data:image/jpeg;base64,$base64" loading="lazy" style="max-width:100%;height:auto;display:block;margin:0;padding:0;">');
          processed++;
          _progressValue = processed / total;
          _progressText = 'جاري المعالجة: $processed / $total';
          if (mounted) setState(() {});
        }
      }

      final fullHtml =
          '<!DOCTYPE html><html lang="ar" dir="rtl"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>$title</title><style>body{background:#121212;margin:0;padding:0;text-align:center;}img{max-width:100%;height:auto;display:block;margin:0;padding:0;}</style></head><body>$body</body></html>';

      final dir = await getApplicationDocumentsDirectory();
      final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${dir.path}/$safeTitle.html');
      await file.writeAsString(fullHtml);

      _progressValue = 1.0;
      _progressText = '✅ اكتمل!';
      if (mounted) setState(() {});

      await Share.shareXFiles([XFile(file.path)], subject: title);
      _notify('✅ تم إنشاء الملف ($total صورة).', color: AppColors.success);
    } catch (e) {
      _notify('❌ خطأ: $e', color: AppColors.accentRed);
    } finally {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _showProgress = false;
          _progressValue = 0;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  // مسح الكل
  // ─────────────────────────────────────────────────────────
  void _clearAll() {
    if (_groups.isEmpty) {
      _notify('لا توجد صور.', color: AppColors.textMuted);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('تأكيد',
            style: TextStyle(color: AppColors.textMain)),
        content: const Text('هل أنت متأكد من مسح جميع الصور وكل القوائم؟',
            style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              setState(() => _groups = []);
              Navigator.pop(ctx);
              _notify('🗑️ تم مسح جميع الصور.', color: AppColors.textMuted);
            },
            child: const Text('مسح',
                style: TextStyle(color: AppColors.accentRed)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // إعادة تسمية قائمة
  // ─────────────────────────────────────────────────────────
  void _renameGroup(ImageGroup group) {
    final controller = TextEditingController(text: group.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('اسم جديد',
            style: TextStyle(color: AppColors.textMain)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textMain),
          decoration: const InputDecoration(
            hintText: 'أدخل الاسم الجديد',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                group.name = controller.text.trim().isEmpty
                    ? group.name
                    : controller.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: const Text('حفظ',
                style: TextStyle(color: AppColors.accentGold)),
          ),
        ],
      ),
    );
  }

  void _deleteGroup(ImageGroup group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('تأكيد الحذف',
            style: TextStyle(color: AppColors.textMain)),
        content: Text(
          'هل تريد حذف القائمة "${group.name}" (${group.files.length} صورة)؟',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              setState(() => _groups.remove(group));
              Navigator.pop(ctx);
            },
            child: const Text('حذف',
                style: TextStyle(color: AppColors.accentRed)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // بناء الواجهة
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _buildDrawer(),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildAppBar(),
                _buildQualityRow(),
                _buildTitleRow(),
                _buildDropZone(),
                if (_showProgress) _buildProgressBar(),
                _buildActionButtons(),
                Expanded(child: _buildPreview()),
              ],
            ),
            if (_showNotification) _buildNotification(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'Builder ($_totalImages صورة)',
              style: const TextStyle(
                color: AppColors.accentGold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: AppColors.textMain),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          const Text('جودة الضغط:',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const Spacer(),
          DropdownButton<double>(
            value: _quality,
            dropdownColor: AppColors.bgCard,
            underline: const SizedBox(),
            style: const TextStyle(color: AppColors.textMain),
            items: const [
              DropdownMenuItem(value: 0.7, child: Text('متوسطة')),
              DropdownMenuItem(value: 0.5, child: Text('منخفضة')),
              DropdownMenuItem(value: 0.3, child: Text('فائقة الانخفاض')),
            ],
            onChanged: (v) => setState(() => _quality = v ?? 0.7),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          const Text('العنوان:',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _titleController,
              style: const TextStyle(color: AppColors.textMain),
              decoration: const InputDecoration(
                hintText: 'عنوان الصفحة (اختياري)',
                hintStyle: TextStyle(color: Color(0xFF666666)),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropZone() {
    return GestureDetector(
      onTap: _pickImages,
      onLongPress: _pickFolder,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.accentGold.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.accentGold.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            const Icon(Icons.add_photo_alternate_outlined,
                color: AppColors.accentGold, size: 40),
            const SizedBox(height: 10),
            const Text(
              '✦ إضافة صور ✦',
              style: TextStyle(
                color: AppColors.accentGold,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'اضغط لاختيار ملفات — اضغط مطولاً لاختيار مجلد',
              style: TextStyle(
                color: AppColors.textMuted.withOpacity(0.8),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _progressValue,
              backgroundColor: const Color(0xFF333333),
              valueColor: const AlwaysStoppedAnimation(AppColors.accentGold),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(_progressText,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _generateParts,
              icon: const Icon(Icons.folder_zip_outlined, size: 18),
              label: const Text('إنشاء ZIP'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isProcessing ? null : _generateSingleFile,
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('ملف واحد'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentGold,
                side: const BorderSide(color: AppColors.accentGold),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_groups.isEmpty) {
      return const Center(
        child: Text('لا توجد صور بعد',
            style: TextStyle(color: Color(0xFF555555))),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(() => group.expanded = !group.expanded),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_outlined,
                          color: AppColors.accentGold, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${group.name} (${group.files.length} صورة)',
                          style: const TextStyle(
                            color: AppColors.textMain,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            size: 18, color: AppColors.textMuted),
                        onPressed: () => _renameGroup(group),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: AppColors.accentRed),
                        onPressed: () => _deleteGroup(group),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        group.expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: AppColors.accentGold,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              if (group.expanded)
                Container(
                  padding: const EdgeInsets.all(8),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: group.files.length,
                    itemBuilder: (context, i) {
                      final item = group.files[i];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(item.path),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.bgHover,
                                child: const Icon(Icons.broken_image,
                                    color: AppColors.textMuted),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  group.files.removeAt(i);
                                  if (group.files.isEmpty) {
                                    _groups.remove(group);
                                  }
                                });
                              },
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: AppColors.accentRed,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotification() {
    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: AnimatedOpacity(
        opacity: _showNotification ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF222222),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _notificationColor),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Text(
            _notificationText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _notificationColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF181818),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'القائمة',
                style: TextStyle(
                  color: AppColors.accentGold,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              _drawerButton(
                icon: Icons.folder_zip_outlined,
                label: '📄 إنشاء أجزاء ZIP',
                color: AppColors.accentGold,
                onTap: () {
                  Navigator.pop(context);
                  _generateParts();
                },
              ),
              const SizedBox(height: 10),
              _drawerButton(
                icon: Icons.description_outlined,
                label: '📘 إنشاء ملف واحد',
                color: AppColors.accentGold,
                isOutlined: true,
                onTap: () {
                  Navigator.pop(context);
                  _generateSingleFile();
                },
              ),
              const SizedBox(height: 10),
              _drawerButton(
                icon: Icons.delete_forever_outlined,
                label: '🗑️ مسح كل الصور',
                color: AppColors.accentRed,
                isOutlined: true,
                onTap: () {
                  Navigator.pop(context);
                  _clearAll();
                },
              ),
              const Spacer(),
              _drawerButton(
                icon: Icons.home_outlined,
                label: '🏠 العودة للرئيسية',
                color: AppColors.textMuted,
                isOutlined: true,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isOutlined = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isOutlined ? color : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, color: isOutlined ? color : Colors.black, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isOutlined ? color : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// شاشة القارئ
// ═══════════════════════════════════════════════════════════
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  List<Uint8List> _images = [];
  bool _loading = false;

  Future<void> _pickHtmlFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['html', 'htm'],
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;

      setState(() => _loading = true);

      final content = await File(path).readAsString();
      final images = _extractImagesFromHtml(content);

      setState(() {
        _images = images;
        _loading = false;
      });

      if (images.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ لا توجد صور في الملف'),
              backgroundColor: AppColors.accentRed,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ تم عرض ${images.length} صورة'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ: $e'),
            backgroundColor: AppColors.accentRed,
          ),
        );
      }
    }
  }

  List<Uint8List> _extractImagesFromHtml(String html) {
    final regex = RegExp(r'<img[^>]+src="data:image/[^;]+;base64,([^"]+)"');
    final matches = regex.allMatches(html);
    final result = <Uint8List>[];
    for (final m in matches) {
      try {
        result.add(base64Decode(m.group(1)!));
      } catch (_) {}
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.textMain),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'BlackWarp Reader',
                      style: TextStyle(
                        color: AppColors.accentGold,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_images.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => _images = []),
                      child: const Text('إغلاق',
                          style: TextStyle(color: AppColors.accentRed)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 25),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.upload_file,
                        color: AppColors.accentGold, size: 40),
                    const SizedBox(height: 10),
                    const Text(
                      'اختر ملف HTML من هاتفك',
                      style: TextStyle(
                        color: AppColors.accentGold,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _pickHtmlFile,
                      icon: const Icon(Icons.folder_open),
                      label: Text(_loading ? 'جارٍ التحميل...' : 'اختيار ملف'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGold,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _images.isEmpty
                  ? const Center(
                      child: Text(
                        'لم يتم تحميل أي صور بعد',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : Container(
                      margin: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AppColors.black,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.05)),
                      ),
                      child: ListView.builder(
                        itemCount: _images.length,
                        itemBuilder: (context, i) {
                          return Image.memory(
                            _images[i],
                            fit: BoxFit.contain,
                            width: double.infinity,
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}