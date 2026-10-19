#!/usr/bin/env python3
"""
update_ty_gia_ph.py — Tự động cập nhật tỷ giá ngày cho báo cáo Philippines.

Quy trình:
  1. Đọc seeds/ucbt_ty_gia_ph.csv, lấy ngày cuối cùng đã có
  2. Lấy tỷ giá PHP/USD/AUD → VND các ngày còn thiếu tới hôm nay
     (fawazahmed0/currency-api, tỷ giá trung bình thị trường; ngày nào API chưa có thì dừng)
  3. Ghi thêm vào CSV
  4. dbt seed --select ucbt_ty_gia_ph
  5. dbt run  --select mart_report_marketing_ad_cost_ph_thu

Dùng tạm cho tới khi bảng tỷ giá ERP PH được ETL về schema ph.

Cách dùng:
  python update_ty_gia_ph.py            # cập nhật CSV + seed + build bảng thử
  python update_ty_gia_ph.py --no-dbt   # chỉ cập nhật CSV
"""

import csv
import json
import os
import subprocess
import sys
import urllib.request
from datetime import date, datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SEED = ROOT / "seeds" / "ucbt_ty_gia_ph.csv"
LOG = ROOT / "logs" / "update_ty_gia_ph.log"
LOAI_TIEN = ["PHP", "USD", "AUD"]
NGUON = "fawazahmed0/currency-api"
URLS = [  # URL chính + URL dự phòng của cùng bộ dữ liệu
    "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@{d}/v1/currencies/{c}.json",
    "https://{d}.currency-api.pages.dev/v1/currencies/{c}.json",
]


def log(msg: str) -> None:
    line = f"[{datetime.now():%Y-%m-%d %H:%M:%S}] {msg}"
    print(line)
    LOG.parent.mkdir(exist_ok=True)
    with LOG.open("a", encoding="utf-8") as f:
        f.write(line + "\n")


def lay_ty_gia(d: date, cur: str) -> float | None:
    """Số VND / 1 đơn vị `cur` ngày `d`; None nếu API chưa có ngày đó."""
    for url in URLS:
        try:
            with urllib.request.urlopen(url.format(d=d, c=cur.lower()), timeout=30) as r:
                return round(json.load(r)[cur.lower()]["vnd"], 4)
        except Exception:
            continue
    return None


def cap_nhat_csv() -> int:
    with SEED.open(encoding="utf-8") as f:
        ngay_cuoi = max(date.fromisoformat(r["ngay"]) for r in csv.DictReader(f))
    them = []
    d = ngay_cuoi + timedelta(days=1)
    while d <= date.today():
        rows = [(cur, lay_ty_gia(d, cur)) for cur in LOAI_TIEN]
        if any(v is None for _, v in rows):
            log(f"API chưa có tỷ giá ngày {d} → dừng, lần chạy sau lấy tiếp")
            break
        them += [f"{d},{cur},{v},{NGUON}" for cur, v in rows]
        d += timedelta(days=1)
    if them:
        with SEED.open("a", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(them) + "\n")
    log(f"Ngày cuối trước khi chạy: {ngay_cuoi}; thêm {len(them)} dòng")
    return len(them)


def chay_dbt(*args: str) -> None:
    dbt = Path(sys.executable).parent / "Scripts" / "dbt.exe"
    cmd = [str(dbt) if dbt.exists() else "dbt", *args, "--profiles-dir", "."]
    env = {**os.environ, "PYTHONUTF8": "1"}
    r = subprocess.run(cmd, cwd=ROOT, env=env, capture_output=True, text=True, encoding="utf-8")
    tom_tat = [l for l in r.stdout.splitlines() if " OK " in l or "ERROR" in l or "Done." in l]
    log(f"$ dbt {' '.join(args)} → exit {r.returncode}\n    " + "\n    ".join(tom_tat))
    if r.returncode != 0:
        raise RuntimeError(f"dbt {' '.join(args)} lỗi (exit {r.returncode})")


def main() -> None:
    so_dong = cap_nhat_csv()
    if "--no-dbt" in sys.argv:
        return
    if so_dong:
        chay_dbt("seed", "--select", "ucbt_ty_gia_ph")
    # Luôn build lại bảng thử để lấy phiếu thu / chi phí mới nhất
    chay_dbt("run", "--select", "mart_report_marketing_ad_cost_ph_thu")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log(f"LỖI: {e}")
        sys.exit(1)
