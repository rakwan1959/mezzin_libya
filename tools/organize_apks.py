# -*- coding: utf-8 -*-
import os
import shutil

desktop_dir = r"C:\Users\Admin\Desktop\MuezzinLibya_Release_APKs"
os.makedirs(desktop_dir, exist_ok=True)

apk_source_dir = r"build\app\outputs\flutter-apk"

mapping = [
    ('app-release.apk', 'MuezzinLibya_v3.3.1_Universal_AllDevices.apk', 'نسخة شاملة تعمل على جميع الأجهزة القديمة والحديثة (32bit + 64bit)'),
    ('app-armeabi-v7a-release.apk', 'MuezzinLibya_v3.3.1_OldDevices_32bit.apk', 'نسخة مخصصة وخفيفة للأجهزة القديمة والضعيفة (armeabi-v7a 32-bit)'),
    ('app-arm64-v8a-release.apk', 'MuezzinLibya_v3.3.1_ModernDevices_64bit.apk', 'نسخة فائقة السرعة للأجهزة الحديثة (arm64-v8a 64-bit)'),
    ('app-x86_64-release.apk', 'MuezzinLibya_v3.3.1_Emulators_x86_64.apk', 'نسخة للمحاكيات وأجهزة الكمبيوتر والأجهزة بنظام x86_64')
]

print("=== Organizing Built APKs ===")
for src_name, dest_name, desc in mapping:
    src_path = os.path.join(apk_source_dir, src_name)
    if os.path.exists(src_path):
        dest_path = os.path.join(desktop_dir, dest_name)
        shutil.copy2(src_path, dest_path)
        shutil.copy2(src_path, dest_name)
        size_mb = os.path.getsize(dest_path) / (1024 * 1024)
        print(f"[OK] {dest_name} ({size_mb:.1f} MB)")
    else:
        print(f"[MISSING] Source not found: {src_path}")

with open(os.path.join(desktop_dir, 'README.txt'), 'w', encoding='utf-8') as f:
    f.write('🕌 تطبيق مؤذن ليبيا - النسخ الجاهزة والمبنية بنجاح (الإصدار المحدث مع قاعدة بيانات 4.02)\n')
    f.write('====================================================================================\n\n')
    for src_name, dest_name, desc in mapping:
        f.write(f'📌 {dest_name}:\n   - {desc}\n\n')
    f.write('💡 ملاحظة التوافقية والاستخدام:\n')
    f.write('1. للعمل على أي جهاز بدون استثناء: استخدم النسخة الشاملة (Universal_AllDevices).\n')
    f.write('2. للأجهزة الحديثة (معظم هواتف 2018 فما فوق): استخدم (ModernDevices_64bit) لأداء أسرع واستهلاك رام أقل.\n')
    f.write('3. للأجهزة القديمة والضعيفة: استخدم (OldDevices_32bit) لحجم أخف وتوافق تام.\n')
    f.write('4. للمحاكيات وأجهزة الكمبيوتر بنظام أندرويد: استخدم (Emulators_x86_64).\n')

print("All APKs organized successfully!")
