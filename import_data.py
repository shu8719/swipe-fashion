#!/usr/bin/env python3
"""楽天JSONからDB投入 + ベクトル化の一括スクリプト"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dotenv import load_dotenv
load_dotenv()

from backend.db import init_db, load_rakuten_json_dir
from recommender.vectorizer import vectorize_all
from backend import config

print(f"DB_PATH: {config.DB_PATH}")

if "--reinit" in sys.argv:
    init_db()
    loaded = load_rakuten_json_dir(os.getenv("RAKUTEN_JSON_DIR", ""))
    print(f"商品投入: {loaded}件")

if "--vectorize" in sys.argv:
    count = vectorize_all()
    print(f"ベクトル化完了: {count}件")

if "--reinit" not in sys.argv and "--vectorize" not in sys.argv:
    print("使い方: python3 import_data.py [--reinit] [--vectorize]")
    print("  --reinit     DB初期化 + JSON投入")
    print("  --vectorize  全商品ベクトル化")
