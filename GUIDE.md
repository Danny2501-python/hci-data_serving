# dbt (Data Build Tool) - Hướng dẫn sử dụng cơ bản

Tài liệu này tổng hợp các lệnh dbt thường dùng và quy trình làm việc từ A-Z dựa trên project `data_serving` hiện tại.

## 1. Khởi tạo & Cấu hình Project

### Tạo Project mới
```bash
dbt init <project_name>
# Ví dụ: dbt init data_serving
# Điền thông tin database khi được hỏi để dbt tạo file profiles.yml
```

### Kiểm tra kết nối Database
```bash
dbt debug
# Kiểm tra file dbt_project.yml và profiles.yml có khớp nhau không
# Kiểm tra kết nối tới database thành công hay thất bại
```

### Cài đặt dependencies (Packages)
Nếu trong `packages.yml` có khai báo thư viện:
```bash
dbt deps
```

---

## 2. Phát triển (Development)

### Chạy Models (Tạo bảng/view)
```bash
dbt run
# Chạy tất cả models trong project

dbt run --select <model_name>
# Chỉ chạy 1 model cụ thể (ví dụ: dbt run -s my_first_dbt_model)

dbt run --full-refresh
# Xóa bảng cũ và tạo lại từ đầu (cần thiết khi đổi schema/cấu trúc bảng)
```

### Load dữ liệu tĩnh (Seeds)
```bash
dbt seed
# Load dữ liệu từ file CSV trong thư mục seeds/ vào database

dbt seed --full-refresh
# Xóa bảng cũ, load lại toàn bộ dữ liệu mới (khi file CSV thay đổi)
```

### Chụp ảnh dữ liệu (Snapshots)
```bash
dbt snapshot
# Chạy các file trong snapshots/ để lưu lịch sử thay đổi dữ liệu (SCD Type 2)
```

### Kiểm thử dữ liệu (Tests)
```bash
dbt test
# Chạy các test định nghĩa trong schema.yml và thư mục tests/

dbt test --select <model_name>
# Chỉ test một model cụ thể
```

### Biên dịch code (Compile)
```bash
dbt compile
# Chỉ biên dịch Jinja ra SQL thuần (lưu trong target/compiled/), KHÔNG chạy vào database.
# Dùng để debug hoặc copy query ra chạy tay.
```

---

## 3. Tiện ích & Bảo trì

### Dọn dẹp Project (Clean)
```bash
dbt clean
# Xóa thư mục target/ và dbt_packages/
# Nên chạy khi gặp lỗi lạ hoặc muốn build lại từ đầu cho sạch
```

### Chạy Macro (Run Operation)
```bash
dbt run-operation <macro_name>
# Ví dụ: dbt run-operation drop_specific_relations --args '{relation_names: ["table1", "table2"]}'
```

---

## 4. Tài liệu (Documentation)

### Sinh tài liệu
```bash
dbt docs generate
# Đọc toàn bộ project và sinh ra file catalog.json, index.html mô tả database
```

### Xem tài liệu (Web Server)
```bash
dbt docs serve
# Dựng một web server local (thường ở port 8080) để xem Document & Lineage Graph
```

## 5. Quy trình làm việc tiêu chuẩn (Workflow)
1.  **Code**: Viết file `.sql` trong `models/`.
2.  **Test**: Chạy `dbt run` để tạo bảng, kiểm tra dữ liệu.
3.  **Docs**: Viết mô tả trong file `.yml` đi kèm.
4.  **Verify**: Chạy `dbt test` để đảm bảo logic đúng.
5.  **Commit**: Đẩy code lên Git (nhớ `.gitignore` các file `target/`, `logs/`, `profiles.yml`).
