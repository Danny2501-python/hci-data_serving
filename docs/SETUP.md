# Cài đặt môi trường DBT trên máy Windows mới

Tài liệu dành cho người lần đầu dựng môi trường chạy project `data_serving` trên một máy Windows chưa có gì.

Toàn bộ quy trình mất khoảng 15 phút, trong đó phần lâu nhất là tải Python.

---

## Trước khi bắt đầu: 3 thứ phải có

Kiểm tra đủ 3 mục dưới đây rồi mới sang phần cài đặt. Thiếu bất kỳ mục nào thì các bước sau sẽ fail ở giữa chừng.

### 1. Python 3.9 trở lên

Mở PowerShell, gõ:

```powershell
python --version
```

Nếu báo lỗi *"not recognized"* hoặc version thấp hơn 3.9, cài một trong hai:

- **Miniconda** — https://docs.conda.io/miniconda (máy chuẩn hiện tại đang dùng bản này, Python 3.14.6)
- **Python.org** — https://www.python.org/downloads (nhớ tick **"Add Python to PATH"** khi cài)

Cả hai đều chạy được. Chọn Miniconda nếu muốn khớp tuyệt đối với máy chuẩn.

### 2. Git và quyền truy cập Gitea nội bộ

Project nằm trên Gitea nội bộ, **không phải GitHub**:

```
https://gitea.lakehouse.com/namnt2/data_serving.git
```

Nghĩa là máy phải:

- Cài Git for Windows — https://git-scm.com/download/win (kèm **Git Credential Manager**, mặc định đã có trong bộ cài)
- Nằm trong **mạng nội bộ hoặc đã kết nối VPN** — ngoài mạng sẽ không resolve được domain `gitea.lakehouse.com`
- Có **tài khoản Gitea** được cấp quyền đọc repo

Kiểm tra nhanh:

```powershell
git --version
ping gitea.lakehouse.com
```

> Git Credential Manager là bắt buộc nếu định dùng script `git_sync.py` — script này chạy git ở chế độ stream để GCM hiện được cửa sổ đăng nhập.

### 3. Kết nối mạng tới Postgres

Đây là thứ hay bị bỏ sót nhất. Cài đặt có thể thành công hoàn toàn nhưng `dbt debug` vẫn fail nếu máy không reach được database server.

Máy mới phải thông tới **host và port Postgres** ghi trong `profiles.yml` (thường là port `5432`). Nếu chưa rõ host, hỏi người quản trị hệ thống.

Kiểm tra sau khi đã có thông tin host:

```powershell
Test-NetConnection -ComputerName <host_postgres> -Port 5432
```

Kết quả `TcpTestSucceeded : True` là đạt.

**Không cần** cài PostgreSQL hay công cụ `psql` trên máy. Thư viện `psycopg2-binary` đã đóng gói sẵn driver kết nối.

---

## Các bước cài đặt

### Bước 1 — Clone project

```powershell
git clone https://gitea.lakehouse.com/namnt2/data_serving.git C:\Project\data_serving
cd C:\Project\data_serving
```

Lần đầu clone sẽ hiện cửa sổ đăng nhập Gitea. Đăng nhập xong, credential được lưu lại cho các lần sau.

### Bước 2 — Tạo môi trường ảo (virtualenv)

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

Thành công thì đầu dòng lệnh xuất hiện tiền tố `(.venv)`:

```
(.venv) PS C:\Project\data_serving>
```

> **Nếu PowerShell chặn script** với lỗi *"running scripts is disabled on this system"*, chạy một lần duy nhất rồi thử activate lại:
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
> ```

Môi trường ảo được tạo trong thư mục `.venv` ngay trong project và **không được commit lên git** (đã nằm trong `.gitignore`). Mỗi máy tự dựng riêng.

### Bước 3 — Cài DBT

Chỉ cần đúng **một dòng**:

```powershell
python -m pip install --upgrade pip
pip install dbt-postgres==1.11.0
```

Gói `dbt-postgres` tự kéo về toàn bộ phần còn lại: `dbt-core`, `dbt-adapters`, `psycopg2-binary`, `Jinja2` và khoảng 60 package phụ thuộc khác. Không cần cài thêm gì.

Kiểm tra:

```powershell
dbt --version
```

Kết quả mong đợi:

```
Core:
  - installed: 1.12.5
Plugins:
  - postgres: 1.11.0
```

> **Lưu ý:** lệnh `dbt` chỉ tồn tại **bên trong môi trường ảo**. Mở PowerShell mới mà gõ `dbt` sẽ báo *"not recognized"* — đó là bình thường, không phải lỗi. Phải `Activate.ps1` trước mỗi phiên làm việc.

### Bước 4 — Cấu hình kết nối database

File `profiles.yml` ở thư mục gốc project chứa thông tin kết nối Postgres.

**Tuyệt đối không** tự gõ hay copy thông tin kết nối từ tài liệu, chat hay email. Liên hệ người quản trị để nhận file cấu hình qua kênh nội bộ được phép, rồi đặt vào:

```
C:\Project\data_serving\profiles.yml
```

Project này đọc `profiles.yml` **ngay tại thư mục gốc**, không dùng đường dẫn mặc định `%USERPROFILE%\.dbt\profiles.yml`.

### Bước 5 — Kiểm tra

```powershell
dbt debug
```

Lệnh này kiểm tra lần lượt: tìm thấy project, đọc được profile, và kết nối được tới database. Tất cả đều `OK` là môi trường đã sẵn sàng.

Chạy thêm một lệnh nữa để chắc chắn phần biên dịch SQL hoạt động:

```powershell
dbt compile
```

Lệnh này render toàn bộ model trong `models/` thành SQL thật mà **không** ghi gì xuống database — an toàn để chạy thử.

Không cần chạy `dbt deps` vì project hiện không dùng package ngoài nào.

---

## Sau khi cài xong

Mỗi lần mở phiên làm việc mới:

```powershell
cd C:\Project\data_serving
.\.venv\Scripts\Activate.ps1
dbt run --select <tên_model>
```

Nếu không muốn activate, có thể gọi thẳng:

```powershell
& C:\Project\data_serving\.venv\Scripts\dbt.exe run --select <tên_model>
```

---

## Phiên bản tham chiếu

Đây là cấu hình của máy chuẩn tại thời điểm viết tài liệu. Dùng để đối chiếu khi môi trường có biểu hiện lạ.

| Thành phần | Phiên bản |
|---|---|
| Python | 3.14.6 (Miniconda) |
| dbt-core | 1.12.5 |
| dbt-postgres | 1.11.0 |
| psycopg2-binary | 2.9.13 |
| Jinja2 | 3.1.6 |

---

*Cập nhật: 21/09/2026*
