#!/usr/bin/env python3
"""
git_sync.py — Tự động sync nhánh hiện tại với main và push thay đổi.

Quy trình:
  1. Lấy tên nhánh hiện tại (checkout)
  2. Fetch + pull origin/main về local
  3. Merge main vào nhánh hiện tại
  4. git add -A
  5. git commit (với message tuỳ chọn hoặc mặc định)
  6. git push origin <nhánh hiện tại>

Cách dùng:
  python git_sync.py                          # commit message mặc định
  python git_sync.py "feat: update dbt model" # tuỳ chỉnh commit message
"""

import subprocess
import sys
from datetime import datetime


def run(cmd: list[str], check: bool = True, stream: bool = False) -> subprocess.CompletedProcess:
    """Chạy lệnh git và in ra stdout/stderr.
    stream=True: không capture output, cho phép GCM hiển thị dialog xác thực.
    """
    print(f"  $ {' '.join(cmd)}")
    if stream:
        result = subprocess.run(cmd)
        result.stdout = ""
        result.stderr = ""
    else:
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.stdout.strip():
            print(f"    {result.stdout.strip()}")
        if result.stderr.strip():
            print(f"    {result.stderr.strip()}")
    if check and result.returncode != 0:
        raise RuntimeError(f"Lệnh thất bại (exit {result.returncode}): {' '.join(cmd)}")
    return result


def main():
    commit_message = sys.argv[1] if len(sys.argv) > 1 else f"chore: sync {datetime.now().strftime('%Y-%m-%d %H:%M')}"

    print("=" * 55)
    print("  GIT SYNC — pull main → merge → add → commit → push")
    print("=" * 55)

    # 1. Lấy tên nhánh hiện tại
    result = run(["git", "branch", "--show-current"])
    current_branch = result.stdout.strip()
    print(f"\n[1] Nhánh hiện tại: {current_branch}\n")

    if not current_branch:
        raise RuntimeError("Không xác định được nhánh hiện tại (có thể đang ở detached HEAD).")

    # 2. Fetch từ origin
    print("[2] Fetch origin...")
    run(["git", "fetch", "origin"])

    # 3. Pull main về local (cập nhật refs/remotes/origin/main)
    print("\n[3] Pull origin/main...")
    run(["git", "pull", "origin", "main"])

    # 4. Nếu đang ở nhánh khác main → merge main vào nhánh hiện tại
    if current_branch != "main":
        print(f"\n[4] Merge main vào '{current_branch}'...")
        run(["git", "merge", "main", "--no-edit"])
    else:
        print(f"\n[4] Đang ở nhánh main — bỏ qua bước merge.")

    # 5. Kiểm tra có thay đổi nào không
    status = run(["git", "status", "--porcelain"], check=False)
    if not status.stdout.strip():
        print("\n✅ Không có thay đổi mới — không cần commit.")
        return

    # 6. git add -A
    print("\n[5] Staging toàn bộ thay đổi...")
    run(["git", "add", "-A"])

    # 7. git commit
    print(f"\n[6] Commit: '{commit_message}'")
    run(["git", "commit", "-m", commit_message])

    # 8. git push — stream=True để GCM có thể hiện auth dialog nếu cần
    print(f"\n[7] Push lên origin/{current_branch}...")
    run(["git", "push", "origin", current_branch], stream=True)

    print(f"\n✅ Hoàn thành! Đã sync và push lên origin/{current_branch}")
    print("=" * 55)


if __name__ == "__main__":
    main()
