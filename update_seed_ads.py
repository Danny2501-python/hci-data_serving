#!/usr/bin/env python3
"""
update_seed_ads.py — Cập nhật seed chi phí ads (HH + THV) từ file CSV tải về
Google Sheets, rồi nạp seed + build model.

Quy trình:
  1. Tìm file CSV: tham số dòng lệnh, hoặc file .csv mới nhất trong
     ~/Downloads có tên chứa "ggs_target_ads_thv_hh"
  2. Chuẩn hoá: ngày dd/mm/yyyy -> yyyy-mm-dd, bỏ dấu phân cách nghìn
     ("100,000,000" -> 100000000), bỏ dòng trống
  3. Kiểm tra: đủ cột, ngày khớp cột "Tháng N", brand_etl là 4/8,
     báo (không xoá) dòng trùng (date, brand_etl)
  4. Ghi đè seeds/seed_ggs_target_ads_thv_hh.csv
  5. dbt seed -s seed_ggs_target_ads_thv_hh
     dbt run  -s rhtdk_chi_phi_ads

Cách tải CSV: mở Google Sheet "Báo cáo Kinh doanh tự chủ 2025", chọn tab
ggs_target_ads_thv_hh -> Tệp -> Tải xuống -> Giá trị được phân tách bằng dấu
phẩy (.csv, trang tính hiện tại).

Cách dùng:
  python update_seed_ads.py                      # lấy file mới nhất trong Downloads
  python update_seed_ads.py "D:\\path\\file.csv"  # chỉ định file
  python update_seed_ads.py --no-run             # chỉ ghi seed, không chạy dbt
"""

import csv
import re
import subprocess
import sys
from datetime import date, timedelta
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent
SEED_NAME = "seed_ggs_target_ads_thv_hh"
SEED_PATH = PROJECT_DIR / "seeds" / f"{SEED_NAME}.csv"
MODEL_NAME = "rhtdk_chi_phi_ads"
DOWNLOAD_PATTERN = "*ggs_target_ads_thv_hh*.csv"

COLUMNS = ["date", "thang", "tuan", "brand_etl", "muc_tieu_tuan", "muc_tieu_thang", "chi_phi"]
NUMBER_COLUMNS = ["brand_etl", "muc_tieu_tuan", "muc_tieu_thang", "chi_phi"]
VALID_BRANDS = {4, 8}


def fail(msg):
    print(f"[LỖI] {msg}")
    sys.exit(1)


def find_input_file(args):
    if args:
        path = Path(args[0])
        if not path.exists():
            fail(f"Không tìm thấy file: {path}")
        return path
    candidates = sorted(
        (Path.home() / "Downloads").glob(DOWNLOAD_PATTERN),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    if not candidates:
        fail(f"Không có file nào khớp {DOWNLOAD_PATTERN} trong ~/Downloads. "
             "Tải CSV từ Google Sheets hoặc truyền đường dẫn file.")
    return candidates[0]


def parse_date(raw, line_no):
    s = raw.strip()
    # yyyy-mm-dd
    m = re.fullmatch(r"(\d{4})-(\d{1,2})-(\d{1,2})", s)
    if m:
        return date(int(m[1]), int(m[2]), int(m[3]))
    # dd/mm/yyyy (định dạng hiển thị của sheet)
    m = re.fullmatch(r"(\d{1,2})/(\d{1,2})/(\d{4})", s)
    if m:
        return date(int(m[3]), int(m[2]), int(m[1]))
    # số serial kiểu Excel/Sheets
    if re.fullmatch(r"\d+(\.0+)?", s):
        return date(1899, 12, 30) + timedelta(days=int(float(s)))
    fail(f"Dòng {line_no}: không đọc được ngày '{raw}'")


def parse_number(raw, col, line_no):
    s = raw.strip().replace(" ", "").replace("\u00a0", "")
    if s in ("", "-"):
        return 0
    # "100,000,000" hoặc "100.000.000" -> 100000000
    if re.fullmatch(r"-?\d{1,3}([,.]\d{3})+", s):
        s = re.sub(r"[,.]", "", s)
    else:
        s = s.replace(",", "")
    try:
        value = float(s)
    except ValueError:
        fail(f"Dòng {line_no}: cột {col} không phải số '{raw}'")
    return int(round(value))


def read_rows(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        header = [h.strip() for h in (reader.fieldnames or [])]
        missing = [c for c in COLUMNS if c not in header]
        if missing:
            fail(f"File thiếu cột {missing}. Cột đọc được: {header}")
        reader.fieldnames = header

        rows = []
        for line_no, raw in enumerate(reader, start=2):
            if not any((raw.get(c) or "").strip() for c in COLUMNS):
                continue  # bỏ dòng trống cuối sheet
            d = parse_date(raw["date"], line_no)
            row = {
                "date": d,
                "thang": raw["thang"].strip(),
                "tuan": raw["tuan"].strip(),
            }
            for col in NUMBER_COLUMNS:
                row[col] = parse_number(raw[col] or "", col, line_no)

            # Ngày phải khớp "Tháng N" -> bắt lỗi đảo ngày/tháng
            m = re.search(r"\d+", row["thang"])
            if m and int(m[0]) != d.month:
                fail(f"Dòng {line_no}: ngày {d} không khớp cột thang '{row['thang']}' "
                     "(có thể bị đảo ngày/tháng)")
            if row["brand_etl"] not in VALID_BRANDS:
                fail(f"Dòng {line_no}: brand_etl = {row['brand_etl']} không phải 4 (HH) / 8 (THV)")
            rows.append(row)
    if not rows:
        fail("File không có dòng dữ liệu nào")
    return rows


def warn_duplicates(rows):
    seen = {}
    for r in rows:
        key = (r["date"], r["brand_etl"])
        seen[key] = seen.get(key, 0) + 1
    dups = {k: n for k, n in seen.items() if n > 1}
    if dups:
        print(f"[CẢNH BÁO] {len(dups)} cặp (date, brand_etl) bị trùng — giữ nguyên, "
              "kiểm tra lại sheet:")
        for (d, b), n in sorted(dups.items()):
            print(f"    {d} brand {b}: {n} dòng")


def write_seed(rows):
    rows = sorted(rows, key=lambda r: (r["date"], -r["brand_etl"]))
    with open(SEED_PATH, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(COLUMNS)
        for r in rows:
            w.writerow([r["date"].isoformat()] + [r[c] for c in COLUMNS[1:]])


def summary(rows):
    print(f"    {len(rows)} dòng, từ {min(r['date'] for r in rows)} đến {max(r['date'] for r in rows)}")
    for b, name in ((4, "Hồng Hà"), (8, "Tiêu hóa Việt")):
        br = [r for r in rows if r["brand_etl"] == b]
        if not br:
            continue
        cost = sum(r["chi_phi"] for r in br)
        last = max((r["date"] for r in br if r["chi_phi"] != 0), default=None)
        print(f"    {name:<14} chi phí = {cost:,.0f}  (có chi phí đến {last})")


def run(cmd):
    print(f"\n>>> {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=PROJECT_DIR)
    if result.returncode != 0:
        fail(f"Lệnh thất bại: {' '.join(cmd)}")


def main():
    args = [a for a in sys.argv[1:] if a != "--no-run"]
    no_run = "--no-run" in sys.argv[1:]

    src = find_input_file(args)
    print(f"[1] Đọc file: {src}")
    rows = read_rows(src)
    warn_duplicates(rows)
    summary(rows)

    write_seed(rows)
    print(f"[2] Đã ghi seed: {SEED_PATH.relative_to(PROJECT_DIR)}")

    if no_run:
        print("[3] Bỏ qua dbt (--no-run)")
        return
    run(["dbt", "seed", "-s", SEED_NAME])
    run(["dbt", "run", "-s", MODEL_NAME])
    print("\n[XONG] Seed + model đã cập nhật.")


if __name__ == "__main__":
    main()
