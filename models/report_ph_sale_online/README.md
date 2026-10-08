# report_ph_sale_online — Báo cáo sale online Philippines

Bảng output: **`sandbox_ph.report_ph_sale_online`** (tag `report_ph_sale`, `phi`).

Bản Philippines của `report_kn_sale_online`. **23 cột đầu giống hệt** bảng Kangnam (tên, thứ
tự, kiểu) → dashboard Tableau chỉ cần đổi nguồn. Thêm 5 cột cuối:

| Cột | Ý nghĩa |
|---|---|
| `trang_thai_du_lieu` | `THAT` / `TEST` / `NGHI_TEST` (quy tắc chung với báo cáo marketing PH) — **luôn lọc `= 'THAT'`** |
| `ly_do` | Lý do phân loại |
| `lead_id` | `ph.crm_lead.id` |
| `loai_tien`, `so_tien_goc` | Chỉ nhánh DS: loại tiền & số tiền gốc của phiếu thu |

## 1. Luồng dữ liệu

```
ph.crm_lead × ph.crm_line (+ sản phẩm, stage, nguồn, công ty, tỉnh, res_users)
   + stg_frmacph_trang_thai (TEST/THAT)              → stg_phso_map (lead × dòng DV)
                                                          │ cắt 5 nhánh
stg_frmacph_doanh_so_thu (phiếu thu × tỷ giá cố định) → nhánh DS
                                                          │ UNION ALL (liệt kê cột rõ ràng)
team theo email: table_team_sale_trans_field (ưu tiên) + sandbox_ph.team_sale_ph
                                                          ▼
                                         sandbox_ph.report_ph_sale_online
```

## 2. Các nhánh (`bang`)

| bang | Điều kiện | Cột `date` |
|---|---|---|
| `Lead_total` | `type_crm_id = 1`, giai đoạn **Booked / Tiềm năng / Consider / Số mới** (≈ Tiềm năng/Tham khảo/Đặt lịch của KN) | ngày tạo |
| `BK` | `type_crm_id = 2`, bỏ booking bảo hành (`tao_booking_bh`; type 3 tự loại) | ngày tạo |
| `HL` | như BK | ngày hẹn (`booking_date`) |
| `DC` | như BK | ngày đến (`arrival_date`) – có thể NULL như KN |
| `TC` | như BK + `crm_line.total_received > 0` | ngày đến |
| `DS` | phiếu thu `posted`, quy đổi VND theo **tỷ giá cố định** (dùng chung `stg_frmacph_doanh_so_thu`); `sdt` chứa doanh số | ngày thu |

`BK`/`HL`/`DC` là **cùng tập booking** lặp theo 3 mốc ngày (giống KN) → mọi phép đếm phải lọc `bang`.

## 3. Khác biệt so với bản Kangnam (có chủ đích)

- **Không lọc `active = true`**: ERP PH để booking đến/Won/thanh toán ở `active = false`.
- **Giữ lead không có dòng dịch vụ** (`nhom_dv = 'KXĐ'`): lead PH gần như không có `crm_line`;
  KN bắt buộc có sản phẩm → áp nguyên sẽ mất toàn bộ `Lead_total`.
- **Ngày + 8 giờ** (Manila); KN + 7. KN lấy ngày tạo từ `create_date` → bản PH cũng vậy.
- **Doanh số không join vào map** (tránh nhân dòng như KN mục 8.1) — 1 dòng / phiếu thu, gắn thuộc
  tính lead theo dòng dịch vụ đầu tiên.
- **Quy đổi tiền**: `amount_vnd` của ERP PH sai với phiếu PHP → dùng `stg_frmacph_doanh_so_thu`
  (amount × **tỷ giá cố định tạm thời**: PHP = 405 theo sếp chốt, USD = 25.806,79 Techcombank,
  AUD = 18.315,78 – chi tiết ở README `func_report_marketing_ad_cost_ph` mục 1.1). Doanh số khớp
  tuyệt đối với `report_marketing_ad_cost_ph_thu`.
- **Chi nhánh**: không có `stag_crm_booking_arrival_company` cho brand 9 → dùng `company_id`.
- **Team**: nối theo email (`ph.res_users.login`) với `table_team_sale_trans_field` (đội sale quốc tế
  Kangnam đã có sẵn); NV Sunwoo chưa có → `sandbox_ph.team_sale_ph` (user tự điền; hiện gán tạm
  "SALE SUNWOO"). Bảng team gọi qua `source()`.
- **`ma_booking` của `Lead_total`** = mã booking (`BOOK-...`) mà lead đã chuyển thành
  (`booking.lead_id = lead.id`, booking tạo đầu tiên); lead chưa chuyển → NULL. KN để tên khách
  (vì `crm_lead.name` của lead là tên) — bản PH sửa theo yêu cầu 2026-10-07. Tên ở `ten_khach`.
- `page`, `ad_id` giữ placeholder `'page'`, `'ad'` như KN; `surgery_type` = NULL (ERP PH chưa có).

## 4. Build

Chạy cùng toàn bộ dự án Philippines theo tag (không chạy cả project):

```bash
set PYTHONUTF8=1
dbt run  --select tag:phi --profiles-dir .
dbt test --select tag:phi --profiles-dir .
```
Sửa `sandbox_ph.team_sale_ph`, `tk_test`, `danh_dau_thu_cong` hoặc tỷ giá cố định → build lại.
Các bảng cấu hình `sandbox_ph.*` tạo tay trên DB (không do dbt quản lý) – phải tồn tại khi chạy.
