import sqlite3
import sys

# Ensure UTF-8 output
sys.stdout.reconfigure(encoding='utf-8')

db_path = 'assets/database/quran/quran_qaloun.db'
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# We want to know each Juz starting verse: (juz_number, surah_number, ayah_number)
# Based on the exact 30 Ajzaa of the Holy Quran:
# 1. Al-Fatiha 1
# 2. Al-Baqarah 141 ("سيقول السفهاء")
# 3. Al-Baqarah 251 ("تلك الرسل")
# 4. Al-Imran 91 ("لن تنالوا البر")
# 5. An-Nisa 24 ("والمحصنات")
# 6. An-Nisa 147 ("لا يحب الله الجهر")
# 7. Al-Ma'idah 84 ("لتجدن أشد الناس")
# 8. Al-An'am 112 ("ولو أننا نزلنا")
# 9. Al-A'raf 87 ("قال الملأ الذين استكبروا")
# 10. Al-Anfal 41 ("واعلموا أنما غنمتم")
# 11. At-Tawbah 94 ("إنما السبيل / يعتذرون")
# 12. Hud 6 ("وما من دابة")
# 13. Yusuf 53 ("وما أبرئ نفسي")
# 14. Al-Hijr 1
# 15. Al-Isra 1
# 16. Al-Kahf 74 ("قال ألم أقل لك")
# 17. Al-Anbiya 1
# 18. Al-Mu'minun 1
# 19. Al-Furqan 21 ("وقال الذين لا يرجون")
# 20. An-Naml 58 ("فما كان جواب قومه")
# 21. Al-Ankabut 45 ("اتل ما أوحي")
# 22. Al-Ahzab 31 ("ومن يقنت")
# 23. Ya-Sin 27 ("وما أنزلنا على قومه")
# 24. Az-Zumar 32 ("فمن أظلم ممن كذب")
# 25. Fussilat 46 ("إليه يرد علم الساعة")
# 26. Al-Ahqaf 1
# 27. Adh-Dhariyat 31 ("قال فما خطبكم")
# 28. Al-Mujadilah 1
# 29. Al-Mulk 1
# 30. An-Naba 1

# Let's verify by finding the exact id in `verses` for each starting verse!
cursor.execute('SELECT id, surah, number, text_pure FROM verses ORDER BY id ASC')
all_verses = cursor.fetchall()
print(f'Loaded {len(all_verses)} verses from database.')

# Let's inspect starting points
juz_checkpoints = [
    (1, 1, 1),
    (2, 2, "سيقول"),
    (3, 2, "تلك الرسل"),
    (4, 3, "لن تنالوا"),
    (5, 4, "والمحصنات"),
    (6, 4, "لا يحب الله"),
    (7, 5, "لتجدن"),
    (8, 6, "ولو اننا"),
    (9, 7, "قال الملا"),
    (10, 8, "واعلموا"),
    (11, 9, "يعتذرون"), # أو "إنما السبيل"
    (12, 11, "وما من دابه"),
    (13, 12, "وما ابري"),
    (14, 15, 1),
    (15, 17, 1),
    (16, 18, "قال الم اقل"),
    (17, 21, 1),
    (18, 23, 1),
    (19, 25, "وقال الذين لا يرجون"),
    (20, 27, "فما كان جواب"),
    (21, 29, "اتل ما اوحي"),
    (22, 33, "ومن يقنت"),
    (23, 36, "وما انزلنا"),
    (24, 39, "فمن اظلم"),
    (25, 41, "اليه يرد"),
    (26, 46, 1),
    (27, 51, "قال فما خطبكم"),
    (28, 58, 1),
    (29, 67, 1),
    (30, 78, 1),
]

def normalize(s):
    if not s: return ""
    return (s.replace('أ', 'ا')
            .replace('إ', 'ا')
            .replace('آ', 'ا')
            .replace('ة', 'ه')
            .replace('ى', 'ي')
            .replace('ء', '')
            .replace('ئ', 'ي')
            .replace('ؤ', 'و')
            .replace(' ', '')
            .replace('۞', '')
            .strip())

juz_start_ids = {}

for j_num, surah_id, target in juz_checkpoints:
    found_id = None
    if isinstance(target, int):
        # Ayah number in surah
        for v_id, s_num, a_num, t_pure in all_verses:
            if s_num == surah_id and a_num == target:
                found_id = v_id
                break
    else:
        # Phrase search in that surah
        norm_target = normalize(target)
        for v_id, s_num, a_num, t_pure in all_verses:
            if s_num == surah_id:
                norm_text = normalize(t_pure)
                if norm_target in norm_text:
                    found_id = v_id
                    break
    if found_id:
        juz_start_ids[j_num] = found_id
        # get details
        v = next(x for x in all_verses if x[0] == found_id)
        print(f"Juz {j_num:2d} -> verse_id={v[0]:4d}, Surah {v[1]:2d}, Ayah {v[2]:3d}: {v[3][:40]}")
    else:
        print(f"NOT FOUND: Juz {j_num} (Surah {surah_id}, target: {target})")

conn.close()
