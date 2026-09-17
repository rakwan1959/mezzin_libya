# -*- coding: utf-8 -*-
import os
import sys
import zipfile
import sqlite3
import json

apk_path = os.path.join(r"C:\Users\Admin\Desktop", "\u0627\u0644\u0645\u0624\u0630\u0646+-+\u0644\u064a\u0628\u064a\u0627_4.02_APKPure.apk")

print(f"Opening APK: {apk_path}")
if not os.path.exists(apk_path):
    print("APK does not exist!")
    # Check if there are other matching files on Desktop
    desktop = r"C:\Users\Admin\Desktop"
    for f in os.listdir(desktop):
        if "4.02" in f or "APKPure" in f or "apk" in f.lower():
            print(f"Found candidate: {f}")
            apk_path = os.path.join(desktop, f)

with zipfile.ZipFile(apk_path, 'r') as z:
    for filename in z.namelist():
        if filename.startswith("assets/") and (filename.endswith(".sqlite") or filename.endswith(".db")):
            print(f"\n================ Found DB File: {filename} ================")
            data = z.read(filename)
            print(f"Size: {len(data)} bytes")
            
            tmp_name = "temp_" + os.path.basename(filename)
            with open(tmp_name, "wb") as f:
                f.write(data)
                
            try:
                conn = sqlite3.connect(tmp_name)
                c = conn.cursor()
                c.execute("SELECT name, type, sql FROM sqlite_master;")
                items = c.fetchall()
                print("Schema objects:")
                for name, typ, sql in items:
                    print(f"  [{typ}] {name}")
                    if typ == 'table':
                        c.execute(f"SELECT count(*) FROM `{name}`")
                        count = c.fetchone()[0]
                        print(f"    Row count: {count}")
                        c.execute(f"SELECT * FROM `{name}` LIMIT 3")
                        cols = [desc[0] for desc in c.description]
                        print(f"    Columns: {cols}")
                        rows = c.fetchall()
                        for r in rows:
                            print(f"      {r}")
                conn.close()
            except Exception as e:
                print(f"Error reading SQLite db: {e}")
            finally:
                if os.path.exists(tmp_name):
                    try:
                        os.remove(tmp_name)
                    except:
                        pass

