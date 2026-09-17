# -*- coding: utf-8 -*-
import os
import sqlite3
import json
import csv
import io

def export_database(db_path, out_dir_base, country_name):
    print(f"\n================ Exporting {country_name} from {db_path} ================")
    out_dir = os.path.join(out_dir_base, country_name)
    os.makedirs(out_dir, exist_ok=True)
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # 1. SQL Dump
    sql_dump_path = os.path.join(out_dir, f"{country_name}_dump.sql")
    with open(sql_dump_path, 'w', encoding='utf-8') as f:
        for line in conn.iterdump():
            f.write(f"{line}\n")
    print(f"Generated SQL Dump: {sql_dump_path} ({os.path.getsize(sql_dump_path)} bytes)")
    
    # 2. Cities Export
    cursor.execute("SELECT id, cityNameEN, cityNameAR, lat, lng FROM CitesTable ORDER BY id")
    cities_rows = cursor.fetchall()
    
    cities_list = []
    cities_dict = {}
    for r in cities_rows:
        cid, en, ar, lat, lng = r
        city_obj = {
            "id": cid,
            "cityNameEN": en or "",
            "cityNameAR": ar or "",
            "lat": lat or "0",
            "lng": lng or "0"
        }
        cities_list.append(city_obj)
        cities_dict[cid] = city_obj
        
    cities_json_path = os.path.join(out_dir, f"{country_name.lower()}_cities.json")
    with open(cities_json_path, 'w', encoding='utf-8') as f:
        json.dump(cities_list, f, ensure_ascii=False, indent=2)
    print(f"Generated Cities JSON: {cities_json_path} ({len(cities_list)} cities)")
    
    cities_csv_path = os.path.join(out_dir, f"{country_name.lower()}_cities.csv")
    with open(cities_csv_path, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=["id", "cityNameAR", "cityNameEN", "lat", "lng"])
        writer.writeheader()
        writer.writerows(cities_list)
    print(f"Generated Cities CSV: {cities_csv_path}")
    
    # 3. Prayer Times Export
    cursor.execute("SELECT prayerId, cityId, monthh, dayy, fajerTime, sunRiseTime, duhirTime, aserTime, mugribTime, eshaTime FROM Prayer ORDER BY cityId, monthh, dayy")
    prayer_rows = cursor.fetchall()
    
    prayer_all_list = []
    per_city_prayers = {cid: [] for cid in cities_dict}
    
    for r in prayer_rows:
        pid, cid, month, day, fajr, sunrise, dhuhr, asr, maghrib, isha = r
        
        # Clean up time formats if needed (e.g. 06:08:00 -> 06:08 or preserve original)
        date_str = f"{month:02d}-{day:02d}"
        
        city_info = cities_dict.get(cid, {"cityNameAR": "", "cityNameEN": ""})
        
        row_dict = {
            "prayerId": pid,
            "cityId": cid,
            "cityNameAR": city_info["cityNameAR"],
            "cityNameEN": city_info["cityNameEN"],
            "month": month,
            "day": day,
            "date": date_str,
            "fajr": str(fajr).strip(),
            "sunrise": str(sunrise).strip(),
            "dhuhr": str(dhuhr).strip(),
            "asr": str(asr).strip(),
            "maghrib": str(maghrib).strip(),
            "isha": str(isha).strip()
        }
        prayer_all_list.append(row_dict)
        
        # Format for per-city JSON
        per_city_prayers[cid].append({
            "date": date_str,
            "fajr": str(fajr).strip(),
            "sunrise": str(sunrise).strip(),
            "dhuhr": str(dhuhr).strip(),
            "asr": str(asr).strip(),
            "maghrib": str(maghrib).strip(),
            "isha": str(isha).strip()
        })
    
    # Full Prayer CSV
    prayers_csv_path = os.path.join(out_dir, f"{country_name.lower()}_prayer_times.csv")
    with open(prayers_csv_path, 'w', encoding='utf-8-sig', newline='') as f:
        fieldnames = ["prayerId", "cityId", "cityNameAR", "cityNameEN", "month", "day", "date", "fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(prayer_all_list)
    print(f"Generated Prayers CSV: {prayers_csv_path} ({len(prayer_all_list)} rows)")
    
    # Full Prayer JSON
    prayers_json_path = os.path.join(out_dir, f"{country_name.lower()}_prayer_times_all.json")
    with open(prayers_json_path, 'w', encoding='utf-8') as f:
        json.dump(prayer_all_list, f, ensure_ascii=False, indent=2)
    print(f"Generated Consolidated Prayers JSON: {prayers_json_path}")
    
    # Per-City JSON directory
    city_json_dir = os.path.join(out_dir, "cities_json")
    os.makedirs(city_json_dir, exist_ok=True)
    
    for cid, plist in per_city_prayers.items():
        city_info = cities_dict[cid]
        en_name = city_info["cityNameEN"].strip()
        if not en_name:
            en_name = f"city_{cid}"
        # Sanitize filename
        safe_en_name = "".join(c for c in en_name if c.isalnum() or c in ('_', '-')).lower()
        file_path = os.path.join(city_json_dir, f"{safe_en_name}.json")
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(plist, f, ensure_ascii=False, indent=2)
            
    print(f"Generated {len(per_city_prayers)} per-city JSON files in {city_json_dir}")
    
    # 4. Sounds table if exists
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='Sounds'")
    if cursor.fetchone():
        cursor.execute("SELECT id, soundName, soundFileName, soundUri, isDefault, soundSize FROM Sounds")
        sounds = []
        for s in cursor.fetchall():
            sounds.append({
                "id": s[0],
                "soundName": s[1],
                "soundFileName": s[2],
                "soundUri": s[3],
                "isDefault": s[4],
                "soundSize": s[5]
            })
        sounds_path = os.path.join(out_dir, "sounds.json")
        with open(sounds_path, 'w', encoding='utf-8') as f:
            json.dump(sounds, f, ensure_ascii=False, indent=2)
        print(f"Generated Sounds JSON: {sounds_path}")

    conn.close()

if __name__ == "__main__":
    desktop_out = r"C:\Users\Admin\Desktop\PrayerTimes_Database_Extracted"
    workspace_out = r"C:\Users\Admin\Desktop\PrayerTimes_Latest\extracted_database"
    
    for out_base in [desktop_out, workspace_out]:
        export_database(os.path.join(workspace_out, "Libya.sqlite"), out_base, "Libya")
        export_database(os.path.join(workspace_out, "Algeria.sqlite"), out_base, "Algeria")
    
    print("\nAll database exports completed successfully!")
