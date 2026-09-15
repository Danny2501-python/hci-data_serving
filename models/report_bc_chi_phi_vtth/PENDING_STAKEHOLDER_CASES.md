# Danh sách phiếu bị ảnh hưởng — dịch vụ không xác định được bác sĩ mổ chính/phụ

Verify trên `mart_report_bc_chi_phi_vtth` (build 2026-07-25): **8/17,239 phiếu
surgery (~0.05%)** có ít nhất 1 dịch vụ trên phiếu **không có nhân sự nào mang
`roleid = 1` (BS mổ chính) hoặc `roleid = 2` (BS mổ phụ)** trong
`report_kpi_team_service` → theo đúng logic report (xem `LOGIC.md`), phần vật
tư phân bổ cho dịch vụ đó bị loại khỏi output, khiến tổng
`allocated_cost_value` của phiếu thấp hơn giá trị vật tư gốc đã xuất kho.

**Cần hỏi stakeholder nghiệp vụ (phòng dịch vụ/phẫu thuật):** đây là lỗi thiếu
gán vai trò BS mổ chính trong hệ thống nguồn (ERP/CRM), hay là tình huống hợp
lệ (dịch vụ này không cần vai trò BS mổ chính)? Kết quả trả lời sẽ quyết định
có cần thêm fallback role khác vào logic phân bổ hay không.

**Quan sát đáng chú ý:** 6/8 case đều liên quan CÙNG 1 dịch vụ — *"Trị hôi
nách Endo dry"* (`service_product_id = 4673`). Dịch vụ này VẪN có `roleid = 1`
hoặc `2` ở các phiếu khác (không phải lỗi cấu hình dịch vụ), nên nhiều khả
năng là thiếu sót nhập liệu cho từng ca cụ thể chứ không phải lỗi hệ thống.

---

| # | form_id | Booking | Khách hàng | Mã KH | Dịch vụ thiếu BS | Tiền bị loại (đ) | % giá trị phiếu |
|---|---------|---------|------------|-------|-------------------|-------------------:|-----------------:|
| 1 | 112374 | BOOK-260603-00433 | Hồ Thanh Hải | CUS714990 | Giảm mỡ Lipo 360 toàn bụng 71-80kg (Bụng trên + dưới + eo) — `13718` | 1,507,993 | 76.3% |
| 2 | 111663 | BOOK-260606-00272 | Dương Thị Thủy | CUS713836 | Trị hôi nách Endo dry — `4673` | 1,011,429 | 15.5% |
| 3 | 113285 | BOOK-260617-00203 | Lê Anh Tuấn | CUS718640 | Trị hôi nách Endo dry — `4673` | 398,846 | 10.7% |
| 4 | 113932 | BOOK-260604-00233 | Tống Thị Thu Huyền | CUS715378 | Trị hôi nách Endo dry — `4673` | 278,027 | 10.3% |
| 5 | 112860 | BOOK-260618-00221 | Nguyễn Thị Tuyết Nhi | CUS718900 | Trị hôi nách Endo dry — `4673` | 137,113 | 8.1% |
| 6 | 111093 | BOOK-260516-00269 | Đinh Thị Hà | CUS513173 | Nhổ răng khôn mọc lệch - Tiểu phẫu ca khó mức 2 — `1197` | 98,738 | 3.1% |
| 7 | 111553 | BOOK-260606-00317 | Trần Thị Mỹ Trâm | CUS715935 | Trị hôi nách Endo dry — `4673` | 60,767 | 18.2% |
| 8 | 113856 | BOOK-260703-00445 | Nguyễn Kim Đào | CUS722001 | Trị hôi nách Endo dry — `4673` | 58,258 | 24.7% |

Tất cả 8 phiếu đều thuộc `brand_etl = 1` (Kangnam), `company = BỆNH VIỆN
KANGNAM HÀ NỘI`.

---

## Chi tiết vai trò đã ghi nhận cho dịch vụ bị thiếu (để đối chiếu với nghiệp vụ)

Các `roleid` sau ĐÃ có nhân sự gán trên chính dịch vụ đó của từng phiếu —
chỉ thiếu đúng `roleid 1`/`2`:

| form_id | Dịch vụ | roleid đã có (nhân sự) |
|---------|---------|--------------------------|
| 112374 | 13718 | 4 (Phạm Thị Phượng), 7 (Trần Ngô Cẩm Nhung), 18 (Nguyễn Văn Kim), 45 (Nguyễn Hồng Sơn) |
| 111663 | 4673 | 4 (Bùi Thị Nhài), 5 (Nguyễn Thị Thắm), 5 (Nguyễn Thị Tuyết Nhung), 7 (Nguyễn Thị Hậu), 18 (Ngô Văn Vinh), 22 (Trần Mai Lan) |
| 113285 | 4673 | 4 (Phạm Thị Phượng), 5 (Trần Văn Việt), 7 (Trần Ngô Cẩm Nhung), 18 (Nguyễn Văn Kim) |
| 113932 | 4673 | 4 (Trịnh Thị Hồng), 5 (Nguyễn Quang Huy), 7 (Trần Ngô Cẩm Nhung), 18 (Nguyễn Văn Kim) |
| 112860 | 4673 | 4 (Nguyễn Đức Thuận), 5 (Trần Văn Việt), 7 (Trần Ngô Cẩm Nhung), 18 (Dương Hữu Oánh) |
| 111093 | 1197 | 4 (Mai Thị Duyên), 5 (Đỗ Đình Sơn), 5 (Nguyễn Quang Huy), 18 (Ngô Văn Vinh) |
| 111553 | 4673 | 4 (Phạm Văn Ninh), 5 (Nguyễn Thị Thắm), 5 (Trần Văn Việt), 7 (Nguyễn Thị Hậu), 18 (Nguyễn Văn Kim), 22 (Trần Mai Lan) |
| 113856 | 4673 | 4 (Trịnh Thị Hồng), 5 (Nguyễn Thị Thắm), 5 (Nguyễn Thị Tuyết Nhung), 7 (Nguyễn Thị Hậu), 18 (Dương Hữu Oánh), 22 (Trần Mai Lan) |

---

## Query để tái tạo danh sách này (chạy trên warehouse `new_product`, sau khi build lại `report_bc_chi_phi_vtth`)

```sql
WITH orig AS (
    SELECT form_id, brand_etl, SUM(supply_cost_value) AS orig_cost
    FROM (SELECT DISTINCT form_supply_id, form_id, brand_etl, supply_cost_value
          FROM mart_report_bc_chi_phi_vtth) t
    GROUP BY form_id, brand_etl
),
alloc AS (
    SELECT form_id, brand_etl, SUM(allocated_cost_value) AS alloc_cost
    FROM mart_report_bc_chi_phi_vtth
    GROUP BY form_id, brand_etl
)
SELECT o.form_id, o.brand_etl, o.orig_cost, a.alloc_cost, o.orig_cost - a.alloc_cost AS gap
FROM orig o JOIN alloc a ON a.form_id = o.form_id AND a.brand_etl = o.brand_etl
WHERE ABS(o.orig_cost - a.alloc_cost) > 1
ORDER BY gap DESC;

-- Dịch vụ nào trên phiếu đó bị thiếu bác sĩ (đối chiếu int_bcvtth_service_rate
-- với int_bcvtth_doctor_rate, dịch vụ nào không match là dịch vụ bị loại):
SELECT DISTINCT sr.form_id, sr.service_product_id, sr.service_name
FROM int_bcvtth_service_rate sr
LEFT JOIN int_bcvtth_doctor_rate dr
    ON dr.form_id = sr.form_id AND dr.brand_etl = sr.brand_etl
   AND dr.service_product_id = sr.service_product_id
WHERE dr.form_id IS NULL AND sr.service_product_id IS NOT NULL;
```
