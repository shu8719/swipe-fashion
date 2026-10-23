"""週次バッチ: K-meansクラスタリングを手動実行するスクリプト。
使い方: python -m backend.jobs.weekly_cluster [--clusters 4]
"""
import argparse
import sys
import os

# プロジェクトルートをパスに追加
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", ".."))

from dotenv import load_dotenv  # noqa: E402
load_dotenv()

from backend.db import init_db  # noqa: E402
from backend.ai.cluster import run_clustering  # noqa: E402


def main():
    parser = argparse.ArgumentParser(description="K-meansクラスタリングバッチ")
    parser.add_argument("--clusters", type=int, default=4, help="クラスタ数 (default: 4)")
    args = parser.parse_args()

    init_db()
    result = run_clustering(n_clusters=args.clusters)
    print(result)


if __name__ == "__main__":
    main()
