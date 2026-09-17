# -*- coding: utf-8 -*-
import json
import os

with open('extracted_database/Libya/libya_cities.json', 'r', encoding='utf-8') as f:
    cities = json.load(f)

print(f"Total APK 4.02 Cities: {len(cities)}")
for c in cities:
    cid = c['id']
    ar = c['cityNameAR']
    en = c['cityNameEN']
    lat = c['lat']
    lng = c['lng']
    print(f"{cid:2d}: {ar:<20} | {en:<18} | Lat: {lat:<10} | Lng: {lng:<10}")
