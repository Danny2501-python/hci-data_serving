# report_ph_tq_ds_kh — Tổng quan doanh số & khách hàng MKT Sunwoo (Philippines)

Bản Sunwoo của workbook Tableau **"TỔNG QUAN DOANH SỐ VÀ KHÁCH HÀNG MKT KANGNAM (FULL)"**.
Workbook Kangnam dùng 3 custom SQL trên bảng brand 1 (`crm_lead`, `stag_payment_transfer`,
`stag_products`, `stag_sources`, `target_kangnam_chitieu`). Các bảng `stag_*` không có brand 9,
nên dự án này dựng lại 3 bảng **cùng tên cột, thứ tự, kiểu** từ ERP Philippines (schema `ph`, brand 9).
Workbook Sunwoo chỉ cần `select *` từ 3 bảng này.

| Bảng (`sandbox_ph`) | Thay cho | Mỗi dòng là |
|---|---|---|
| `report_ph_tqdskh_khach` | Custom SQL Query | `bang='data'`: lead × dòng dịch vụ; `bang='payment'`: 1 phiếu thu |
| `report_ph_tqdskh_ds` | Custom SQL Query1 | `bang='Ao'`: chỉ tiêu; `bang='DV'`: 1 phiếu thu (`Thanh_toan` = VND/1000) |
| `report_ph_tqdskh_chi_tieu` | Custom SQL Query2 | 1 chỉ tiêu (lần ban hành mới nhất), từ seed `target_sunwoo_chitieu` |

## Khác biệt so với Kangnam

- **Doanh số** lấy từ `stg_frmacph_doanh_so_thu`, tức `amount` × tỷ giá ACB theo ngày, ra VND.
  Không dùng `amount_vnd`. Số khớp với `report_ph_doanh_thu` và báo cáo marketing PH.
- **Xem VND hoặc PHP (thêm 2026-10-13)**: 4 cột cuối, chỉ có giá trị ở dòng phiếu thu
  (`report_ph_tqdskh_khach` dòng `payment`, `report_ph_tqdskh_ds` dòng `DV`):

  | Cột | Ý nghĩa |
  |---|---|
  | `loai_tien`, `so_tien_goc` | Loại tiền & số tiền trên phiếu ERP (hoàn tiền: âm) – để đối chiếu |
  | `doanh_so_php` (_khach) / `Thanh_toan_php` (_ds) | Doanh số quy đổi PHP, **peso đầy đủ** (không chia 1000). Phiếu PHP = đúng `so_tien_goc`; loại tiền khác = doanh số VND ÷ `ty_gia_php` |
  | `ty_gia_php` | Tỷ giá PHP ACB (bán CK) của ngày gần nhất ≤ ngày thu (T7/CN/lễ → ngày trước đó) |

  Tính ở `stg_frmacph_doanh_so_thu` (dùng chung) – các bảng khác dùng model này chọn cột đích danh nên không đổi.
  Tableau: tham số chọn tiền, `IF [Currency]='PHP' THEN [Thanh_toan_php] ELSE [Thanh_toan] END`
  (lưu ý `Thanh_toan` là nghìn đồng, `Thanh_toan_php` là peso). Test `not_null` cho 2 cột PHP ở dòng phiếu thu.
- **Phiếu thu ERP PH gắn theo lead**, không theo dòng dịch vụ. Dịch vụ của phiếu thu lấy theo dòng
  dịch vụ đầu tiên của lead (`stg_phtq_line.rn_lead = 1`).
- **Ngày** cộng 8 giờ (giờ Manila).
- **Chỉ dữ liệu THAT** (`stg_frmacph_trang_thai`). Phiếu thu không gắn lead bị loại, giống KN (`ecl.id is not null`).
- **Nguồn** map lại vì không có `stag_sources`:
  - `nguon_moi` = `utm_source.name` ('MD - Facebook')
  - `nhom_nguon_moi` = `crm_category_source.name`
  - `kenh` = nguồn mới (`new_source_id`: 'Facebook', 'Hotline'…)
  - `nguon_moi_new` = nhóm nguồn ('Others' → 'Nguồn khác')
- **Trạng thái**: ERP PH đổi tên 4 trạng thái sang tiếng Anh. Model trả về tên Kangnam (đã đối chiếu theo id với
  `public.crm_stage` brand 1 ngày 2026-10-10) để công thức Tableau tính giống KN:

  | id | ERP PH | Tên trong bảng |
  |---|---|---|
  | 5 | Not Processed | Chưa xử lý |
  | 7 | Consider | Tham khảo |
  | 18 | Booked | Đặt lịch |
  | 34 | Not Arrived | Khách không đến |
- Workbook Kangnam có filter ẩn `his_service_type = 'wellness'`. Bản Sunwoo đã gỡ filter này, vì PH không có loại wellness.
- `thuong_hieu` gán cứng `Sunwoo`. Bảng `ph.res_brand` chỉ có bản ghi "Kangnam", do ERP nhân bản.
- `loai_pt` (loại phẫu thuật) = NULL, vì ERP PH không có cột tương ứng.
- **Chỉ tiêu**: seed `seeds/ph/target_sunwoo_chitieu.csv`, hiện **để trống**.
  Các ô % hoàn thành / chỉ tiêu trên dashboard sẽ trống cho tới khi điền.
  `company_id` theo `ph.m_res_company` (4 = SUNWOO MEDICAL CENTER).

## Build

```bash
dbt seed  --select target_sunwoo_chitieu --profiles-dir .
dbt run   --select tag:report_ph_tq_ds_kh --profiles-dir .
dbt test  --select tag:report_ph_tq_ds_kh --profiles-dir .
```
(Windows: đặt `PYTHONUTF8=1`.) Chỉ ghi `sandbox_ph`. Cả 3 bảng cũng nằm trong tag `phi`.
