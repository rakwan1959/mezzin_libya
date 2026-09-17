# -*- coding: utf-8 -*-
import os
import sqlite3
import json
import shutil

def format_time(t_str):
    if not t_str:
        return ""
    parts = t_str.strip().split(':')
    if len(parts) >= 2:
        return f"{int(parts[0]):02d}:{int(parts[1]):02d}"
    return t_str.strip()

def apply_updates():
    db_path = r"extracted_database\Libya.sqlite"
    target_dir = r"assets\database\Libya"
    os.makedirs(target_dir, exist_ok=True)
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # 1. Read cities
    cursor.execute("SELECT id, cityNameEN, cityNameAR, lat, lng FROM CitesTable ORDER BY id")
    cities = cursor.fetchall()
    
    # Mapping of APK 4.02 names to all project filenames
    aliases = {
        'mslata': ['mslata', 'mesalatah'],
        'gaser_lhiar': ['gaser_lhiar'],
        'alzintan': ['alzintan', 'zintan'],
        'gharyan': ['gharyan', 'gherian'],
        'jakharrah': ['jakharrah', 'ejkhara'],
        'murzuq': ['murzuq', 'morzuk'],
        'sarir_field': ['sarir_field', 'sareer'],
        'tamssah': ['tamssah', 'temesa'],
        'tarhunah': ['tarhunah', 'tarhona'],
        'bore_field': ['bore_field', 'bori'],
        'tbqa': ['tbqa', 'tabaqah'],
        'hamada_field': ['hamada_field', 'hamada'],
        'qariat_shargea': ['qariat_shargea', 'sharqeyah'],
    }
    
    updated_files = set()
    
    for cid, en, ar, lat, lng in cities:
        clean_en = en.strip().lower()
        
        # Query 366 days for this city
        cursor.execute("""
            SELECT monthh, dayy, fajerTime, sunRiseTime, duhirTime, aserTime, mugribTime, eshaTime 
            FROM Prayer 
            WHERE cityId = ? 
            ORDER BY monthh, dayy
        """, (cid,))
        rows = cursor.fetchall()
        
        city_prayers = []
        for m, d, f, s, dh, a, mg, ish in rows:
            date_str = f"{m:02d}-{d:02d}"
            city_prayers.append({
                "fajr": format_time(f),
                "sunrise": format_time(s),
                "dhuhr": format_time(dh),
                "asr": format_time(a),
                "maghrib": format_time(mg),
                "isha": format_time(ish),
                "date": date_str
            })
            
        target_names = aliases.get(clean_en, [clean_en])
        for name in target_names:
            out_file = os.path.join(target_dir, f"{name}.json")
            with open(out_file, 'w', encoding='utf-8') as f_out:
                json.dump(city_prayers, f_out, ensure_ascii=False, indent=2)
            updated_files.add(f"{name}.json")
            print(f"Updated {out_file} ({len(city_prayers)} days)")
            
    # 2. Fix trailing commas in all other existing files in assets/database/Libya/
    all_files = [f for f in os.listdir(target_dir) if f.endswith('.json')]
    for fname in all_files:
        fpath = os.path.join(target_dir, fname)
        try:
            with open(fpath, 'r', encoding='utf-8') as f:
                content = f.read().strip()
            # Clean possible trailing comma before closing bracket
            if content.endswith(',]') or ',]' in content or ',\n]' in content or ',\r\n]' in content:
                # parse and re-dump
                cleaned = content.replace(',]', ']').replace(',\n]', '\n]').replace(',\r\n]', '\r\n]')
                data = json.loads(cleaned)
                with open(fpath, 'w', encoding='utf-8') as f:
                    json.dump(data, f, ensure_ascii=False, indent=2)
                print(f"Cleaned syntax in {fname}")
        except Exception as e:
            print(f"Warning on {fname}: {e}")

    # 3. Copy SQLite database into assets/database/
    shutil.copy2(db_path, r"assets\database\Libya.sqlite")
    print("Copied assets/database/Libya.sqlite")
    
    # 4. Copy SQL Dump into assets/database/
    sql_dump_src = r"extracted_database\Libya\Libya_dump.sql"
    if os.path.exists(sql_dump_src):
        shutil.copy2(sql_dump_src, r"assets\database\muezzin_libya_prayer_times.sql")
        print("Updated assets/database/muezzin_libya_prayer_times.sql")
        
    conn.close()
    print(f"\nTotal files updated from 4.02: {len(updated_files)}")
    print("Database integration successfully applied!")

if __name__ == "__main__":
    apply_updates()
