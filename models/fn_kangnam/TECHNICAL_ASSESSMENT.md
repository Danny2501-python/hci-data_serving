# Tài liệu Kỹ thuật: So sánh Giải pháp dbt vs Stored Function Legacy

**Mục tiêu:** Đánh giá hiệu quả kỹ thuật và vận hành của việc chuyển đổi logic báo cáo `bc_sales_kangnam` từ Stored Function (PL/pgSQL) sang dbt (Data Build Tool).

## 1. Tổng quan Kiến trúc

| Tiêu chí | Stored Function (Cũ) | dbt Modern Data Stack (Mới) | Đánh giá |
| :--- | :--- | :--- | :--- |
| **Mô hình xử lý** | **Procedural (Thủ tục)**: Viết lệnh tuần tự `CREATE TEMP TABLE` -> `INSERT` -> `DROP`. | **Declarative (Khai báo)**: Chỉ định nghĩa logic `SELECT`, dbt lo việc tạo/xóa bảng, view, cte. | dbt hiện đại hơn, code tập trung vào logic nghiệp vụ thay vì logic quản lý bảng. |
| **Lưu trữ trung gian** | **Disk-based Temp Tables**: Ghi/xóa liên tục xuống ổ cứng, gây I/O cao và phân mảnh. | **In-memory CTEs / Ephemeral**: Xử lý chủ yếu trên RAM, tối ưu hóa bởi Query Optimizer. | dbt giảm tải I/O, tận dụng tối đa sức mạnh của Optimizer. |
| **Quản lý Code** | Logic nằm trong DB, khó version control, khó review chi tiết. | Code nằm trên Git, dễ dàng Review (PR), Rollback, CI/CD. | dbt chuẩn hóa quy trình phát triển phần mềm (Software Engineering Best Practices). |

## 2. Chi tiết Cải tiến Kỹ thuật

### 2.1. Loại bỏ Code Lặp (DRY Principle)
*   **Vấn đề cũ**: Logic xác định nhân viên Sale (`LEFT JOIN LATERAL ...`) bị copy-paste **6 lần** ở các đoạn code khác nhau. Rủi ro cao: sửa 1 chỗ nhưng quên 5 chỗ còn lại -> Dữ liệu sai lệch.
*   **Giải pháp dbt**: Sử dụng **Macro** `get_sale_team`. Logic được định nghĩa **DUY NHẤT 1 LẦN**. Khi cần thay đổi logic chia sale, chỉ cần sửa 1 dòng code macro.

### 2.2. Tối ưu hóa Luồng dữ liệu (Data Lineage)
*   **Vấn đề cũ**: "Hộp đen" logic. Muốn biết bảng Booking lấy dữ liệu từ đâu, phải đọc ngược hàng trăm dòng code PL/pgSQL đầy biến tạm.
*   **Giải pháp dbt**: Minh bạch hóa dòng chảy dữ liệu.
    *   `Source` -> `Staging` (Làm sạch) -> `Intermediate` (Xử lý chung) -> `Mart` (Báo cáo).
    *   Có thể tự động sinh biểu đồ Lineage Graph để visualize sự phụ thuộc.

### 2.3. Khả năng Kiểm thử (Testing)
*   **Vấn đề cũ**: Không có cơ chế test tự động. Dữ liệu sai (null, duplicate) chỉ được phát hiện khi người dùng báo cáo lỗi.
*   **Giải pháp dbt**: Tích hợp sẵn (`schema.yml`).
    *   Đảm bảo `ticket_id` là duy nhất (`unique`).
    *   Đảm bảo các trường quan trọng không null (`not_null`).
    *   Test được chạy tự động mỗi lần build.

### 2.4. Hiệu năng & Tài nguyên
*   **Function cũ**: Tạo nhiều bảng tạm -> Tốn dung lượng Transaction Log (WAL), gây bloat database nếu chạy tần suất cao.
*   **dbt (Ephemeral Model)**: Dùng CTE (Common Table Expression), giúp Postgres Planner nhìn thấy toàn bộ bức tranh query và tối ưu hóa plan thực thi tốt hơn là từng lệnh rời rạc.

## 3. Khả năng Mở rộng (Scalability)

### Kịch bản: Dữ liệu tăng gấp 10 lần?
*   **Function cũ**: Phải viết lại logic để xử lý `INSERT/UPDATE` (Incremental Load) cực kỳ phức tạp và dễ lỗi (deadlock, consistency).
*   **dbt**: Chỉ cần đổi config `materialized='incremental'` trong 1 dòng. dbt tự động xử lý logic lấy dữ liệu mới và gộp vào bảng cũ.

## 4. Kết luận

Việc chuyển đổi sang dbt không chỉ là "viết lại code", mà là **nâng cấp toàn bộ quy trình sản xuất dữ liệu**:
1.  **An toàn hơn**: Nhờ Testing và Version Control.
2.  **Nhanh hơn**: Nhờ tối ưu hóa Query Planner và giảm I/O.
3.  **Dễ bảo trì hơn**: Nhờ cấu trúc Modular và DRY.
4.  **Chuyên nghiệp hơn**: Tách biệt logic nghiệp vụ khỏi logic quản trị database.

*Đây là bước đi cần thiết để xây dựng một nền tảng dữ liệu (Data Platform) bền vững và sẵn sàng mở rộng trong tương lai.*
