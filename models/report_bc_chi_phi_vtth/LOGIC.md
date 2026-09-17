# Logic: report_bc_chi_phi_vtth

Báo cáo vật tư tiêu hao (phiếu phẫu thuật) phân bổ theo **bác sĩ mổ chính** và
**dịch vụ tương ứng**. Output: `mart_report_bc_chi_phi_vtth`.

---

## Quy tắc phân bổ

1. **Theo dịch vụ**: 1 vật tư có thể gắn với nhiều dịch vụ trên cùng 1 phiếu
   (qua bảng quan hệ nhiều-nhiều `sh_surgery_supply_service_rel`, đã được xử
   lý sẵn trong `stag_his_form_supply_2`/`mart_shs_form_supply`).
   - Vật tư chỉ gắn **1 dịch vụ** → 100% cho dịch vụ đó.
   - Vật tư gắn **N dịch vụ (N ≥ 2)** → chia theo **tỷ lệ doanh thu** của từng
     dịch vụ trên phiếu (`revenue` từ `report_kpi_team_service`).
   - Nếu tổng doanh thu nhóm = 0 (mọi dịch vụ trong nhóm đều 0đ, hoặc không
     tra được doanh thu) → chia đều theo số dịch vụ trong nhóm.
2. **Theo bác sĩ mổ chính**: xác định **ở cấp từng dịch vụ**
   (`form_id + service_product_id`), không phải cấp cả phiếu.
   - Dịch vụ có **1 bác sĩ mổ chính** (`roleid = 1`) → 100% cho bác sĩ đó.
   - Dịch vụ có **N bác sĩ mổ chính (N ≥ 2)** → chia đều cho N bác sĩ.
   - Dịch vụ **không có bác sĩ mổ chính nào** → fallback sang **bác sĩ mổ phụ**
     (`roleid = 2`) của chính dịch vụ đó, cũng chia đều nếu có nhiều người.
   - Dịch vụ không có cả 2 vai trò này (không xác định được bác sĩ) → phần
     vật tư phân bổ cho dịch vụ đó **bị loại khỏi report** (không có đối tượng
     để gán).
3. Hai trục phân bổ (dịch vụ, bác sĩ) độc lập nhau và nhân với nhau:
   `allocated_x = giá_trị_gốc × service_rate × doctor_rate`.

---

## Phạm vi dữ liệu

- Chỉ lấy phiếu **`data_union = 'surgery'`** (phẫu thuật/thủ thuật).
  **Đã loại `specialty`**: verify thực tế trên warehouse cho thấy phiếu
  `specialty` **không có bất kỳ bản ghi `roleid = 1` nào** (0/73,835 phiếu) —
  khái niệm "bác sĩ mổ chính" không tồn tại ở nghiệp vụ này.
- Trong phạm vi `surgery`: 17,237/18,708 phiếu có `roleid = 1`; phần còn lại
  fallback `roleid = 2` (ở mức dịch vụ, xem trên). Sau khi đổi sang phân bổ
  cấp dịch vụ, khoảng 96.2% dòng vật tư gốc (400,919/416,852 `form_supply_id`)
  còn ánh xạ được tới ít nhất 1 dịch vụ có bác sĩ; phần ~3.8% còn lại không có
  bác sĩ ở bất kỳ dịch vụ nào nó gắn tới nên bị loại hoàn toàn.

---

## Sơ đồ quan hệ các bảng nguồn

3 domain dữ liệu độc lập, đều JOIN chốt lại vào cặp khoá chung
**`(form_id, brand_etl, service_product_id[, supply_id])`**:

```
┌─────────────────────────── DOMAIN 1: VẬT TƯ & GIÁ TRỊ ────────────────────────────┐
│                                                                                     │
│  mart_shs_form_supply (= stag_his_form_supply_2, REF model, không phải source)     │
│  [form_id, brand_etl, form_supply_id, supply_id, supply_product_id,                │
│   product_id (→ service_product_id), picking_id, qty_used]                         │
│  đã fan-out sẵn 1 vật tư → N dịch vụ qua sh_surgery_supply_service_rel             │
│        │                                                                           │
│        │ ON (picking_id, product_id = supply_product_id, brand_etl)                │
│        ▼                                                                           │
│  stock_move  [id, picking_id, product_id, brand_etl]                               │
│        │                                                                           │
│        │ ON (stock_move_id = stock_move.id, brand_etl)                             │
│        │ ⚠ id KHÔNG unique toàn cục (mỗi brand 1 Odoo riêng) → BẮT BUỘC kèm       │
│        │   brand_etl, nếu không SUM(value) sẽ cộng nhầm giữa các brand             │
│        ▼                                                                           │
│  stock_valuation_layer  [stock_move_id, value, brand_etl]                          │
│        → GROUP BY (stock_move_id, brand_etl), SUM(value) = supply_cost_value       │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌────────────────────── DOMAIN 2: DỊCH VỤ & BÁC SĨ (THỰC TẾ) ───────────────────────┐
│                                                                                     │
│  report_kpi_team_service                                                           │
│  [form_id, brand_etl, product_id, roleid, employee_id, employee, revenue, product] │
│        │                                                                           │
│        │ ON (form_id, brand_etl, product_id = service_product_id [Domain 1])       │
│        ├─→ revenue, product → tính service_rate (int_bcvtth_service_rate)          │
│        └─→ roleid=1 (BS mổ chính) / fallback roleid=2 (BS mổ phụ), GROUP theo      │
│            (form_id, brand_etl, service_product_id) → doctor_rate                  │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────── DOMAIN 3: ĐỊNH MỨC BOM ──────────────────────────────┐
│                                                                                     │
│  sh_surgery_bom_rel  [surgery_id (= form_id), bom_id, brand_etl]                   │
│        │                                                    │                      │
│        │ ON (bom_id = id, brand_etl)                        │ ON (bom_id = bundle, │
│        ▼                                                    │     brand_etl)       │
│  sh_medical_product_bundle                                   ▼                      │
│  [id, service_id, brand_etl]                          sh_medical_products_line     │
│        │ 1 bundle = ĐÚNG 1 dịch vụ                    [bundle, product_id           │
│        │ (khác Domain 1: không cần chia tỷ lệ)         (→ bom_supply_id),          │
│        │ ON (service_id = id, brand_etl)               quantity, brand_etl]        │
│        ▼                                                     │ SUM(quantity) GROUP │
│  sh_medical_health_center_service                             │ BY (bundle,         │
│  [id, product_id, brand_etl]                                  │ product_id, brand_etl)
│        → service_product_id (khớp Domain 1 & 2)               → bom_qty            │
│                                                                                     │
│  Cả 4 bảng có id NỘI BỘ THEO BRAND (Odoo riêng từng brand) → BẮT BUỘC join kèm    │
│  brand_etl (đã verify: 16,870 id bundle + 118,311 id products_line trùng chéo     │
│  giữa các brand nếu join không kèm brand_etl).                                     │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘

Ghép 3 domain vào mart:
  Domain 1 (form_id, brand_etl, service_product_id, supply_id)
    ⋈ Domain 2 doctor_rate  ON (form_id, brand_etl, service_product_id)
    ⋈ Domain 3 bom_qty      ON (form_id, brand_etl, service_product_id, bom_supply_id = supply_id)
```

**Logic quan hệ chốt lại (mart):**
- `qty_used`/`supply_cost_value` (Domain 1) × `service_rate` (Domain 2, theo doanh thu)
  × `doctor_rate` (Domain 2, theo BS mổ chính/phụ) = `allocated_qty`/`allocated_cost_value`
  (số **thực tế**).
- `bom_qty` (Domain 3, đã cố định theo đúng 1 dịch vụ) × `doctor_rate` (dùng lại của
  Domain 2, không có `service_rate` vì BOM không mơ hồ về dịch vụ) = `bom_allocated_qty`.
  Đơn giá quy đổi `bom_qty` ra tiền lấy từ chính đơn giá thực tế của dòng đó
  (`supply_cost_value / qty_used`) để nhất quán 2 cột so sánh.

---

## Điểm dữ liệu quan trọng cần nhớ khi sửa đổi

1. **Khoá nhóm fan-out dịch vụ phải là `form_supply_id`**, KHÔNG được dùng
   `(supply_id, supply_product_id, picking_id, qty_used)` — đã verify có ~95
   cặp `form_supply_id` khác nhau (2 lần xuất vật tư thật sự khác nhau) nhưng
   trùng ngẫu nhiên cả 4 giá trị này; dùng khoá giá trị sẽ gộp nhầm 2 sự kiện
   xuất vật tư thành 1 nhóm và làm sai lệch tiền phân bổ.
2. **`report_kpi_team_service.revenue` (và `product` — tên dịch vụ) không
   phải lúc nào cũng duy nhất theo `(form_id, product_id)`** — một dịch vụ có
   thể có 2 dòng doanh thu khác nhau trên cùng phiếu (đặt lại dòng dịch vụ ở
   giá khác) vì bảng này không có `order_product_id` để phân biệt dòng gốc.
   Phải `MAX(revenue)`/`MAX(product)` `GROUP BY form_id, brand_etl,
   product_id` trước khi JOIN — dùng `DISTINCT` trực tiếp sẽ gây JOIN
   fan-out và trùng khoá output.
3. **`employee` (tên nhân viên) không đảm bảo duy nhất theo `employee_id`**
   trên vài dòng hiếm — group theo `employee_id` và lấy `MAX(employee)` thay
   vì `SELECT DISTINCT` cả 2 cột, để tránh trùng khoá do lệch text.
4. Các rủi ro dữ liệu ở tầng nguồn (`department_type` hard-code, `state`
   filter khác nhau theo nghiệp vụ, pre_hook xoá toàn bộ brand mỗi lần chạy
   incremental...) xem thêm `models/stag_his_supply/README.md`.
5. **Các bảng `id` là auto-increment RIÊNG THEO TỪNG BRAND (mỗi brand 1 Odoo)
   nên số `id` có thể trùng giữa 2 brand khác nhau** — đã thực sự gây bug
   (không phải rủi ro lý thuyết): `stock_valuation_layer.stock_move_id` từng
   được `GROUP BY` không kèm `brand_etl`, khiến `SUM(value)` cộng nhầm tiền
   của brand khác vào (verify: 416 giá trị `stock_move_id` trùng số giữa các
   brand, bao gồm cả brand_etl=1 đang dùng trong report này) — đã fix bằng
   cách `GROUP BY (stock_move_id, brand_etl)` và JOIN kèm `brand_etl`. Áp dụng
   quy tắc này cho MỌI bảng `sh_medical_*`/`stock_*` khác: không bao giờ JOIN
   hay GROUP BY chỉ theo `id`/`*_id` mà thiếu `brand_etl`.
6. **`sh_medical_products_line` có ~0.43% dòng trùng nội dung**
   (`bundle, product_id, quantity` giống hệt nhau nhưng khác `id`, do dữ liệu
   nguồn) — dùng `SUM(quantity)` thay vì `DISTINCT`/lấy 1 dòng, coi đây là 2
   dòng nguyên liệu cộng dồn trong cùng công thức.

---

## Cấu trúc model

```
stg/
  sources.yml                  ← khai báo report_kpi_team_service, stock_move, stock_valuation_layer,
                                  sh_surgery_bom_rel, sh_medical_product_bundle,
                                  sh_medical_health_center_service, sh_medical_products_line (source dwh_public)
  stg_bcvtth_form_supply       ← ref('mart_shs_form_supply'), filter data_union='surgery'
  stg_bcvtth_supply_cost       ← stock_move + stock_valuation_layer → giá trị tiền theo (picking_id, supply_product_id, brand_etl)
  stg_bcvtth_team_service      ← report_kpi_team_service: form_id, product_id, product (tên dịch vụ), roleid, employee_id, employee, revenue
  stg_bcvtth_bom               ← sh_surgery_bom_rel + sh_medical_product_bundle + sh_medical_health_center_service
                                  + sh_medical_products_line → định mức bom_qty theo (form_id, service_product_id, bom_supply_id)
int/
  int_bcvtth_supply_with_cost  ← form_supply LEFT JOIN supply_cost
  int_bcvtth_service_rate      ← tính service_rate + kèm service_name (window theo form_supply_id)
  int_bcvtth_doctor_rate       ← danh sách bác sĩ + doctor_rate (window theo form_id + service_product_id)
mart/
  mart_report_bc_chi_phi_vtth  ← JOIN service_rate x doctor_rate theo (form_id, brand_etl, service_product_id),
                                  LEFT JOIN stg_bcvtth_bom theo thêm supply_id = bom_supply_id
  schema.yml                   ← doc cột output
```

Unique key output: `(form_supply_id, service_product_id, employee_id)`.

---

## Hiệu năng — tại sao TẤT CẢ model trong folder này là `table`, không phải `ephemeral`

`dbt_project.yml` đặt mặc định `stg`/`int` là `ephemeral` cho toàn bộ project,
nhưng **mọi model trong `report_bc_chi_phi_vtth` đều override bằng
`{{ config(materialized='table') }}`**. Lý do: pipeline này chạm vào các bảng
nhiều triệu dòng (`report_kpi_team_service` 2.18tr, `mart_shs_form_supply`
1.78tr, `sh_medical_products_line` 603k) và có model bị `ref()` nhiều lần
(`stg_bcvtth_team_service` được dùng 3 lần: 1 lần trong `int_bcvtth_service_rate`,
2 lần trong `int_bcvtth_doctor_rate`). Nếu để `ephemeral`, dbt sẽ **inline**
toàn bộ các CTE này vào 1 câu SQL duy nhất khi build `mart` — khiến logic bị
tính toán lặp lại nhiều lần và Postgres planner chọn execution plan rất tệ
trên 1 câu query khổng lồ.

**Đã đo thực tế trên warehouse:**
- Từng model chạy riêng lẻ (không có index nào ngoài PK) đều nhanh: `stg_bcvtth_bom`
  ~5s/737k dòng, `stg_bcvtth_team_service` ~4s/2.18tr dòng — chứng tỏ bottleneck
  KHÔNG phải do thiếu index/scan chậm.
- Để `ephemeral` (bản gốc trước khi fix): build `mart` chạy **41 phút rồi lỗi**
  `SSL connection has been closed unexpectedly` (query quá lâu, kết nối bị rớt).
- Vật lý hoá riêng `stg_bcvtth_bom` (giữ nguyên phần còn lại ephemeral): còn
  **8.5 phút rồi vẫn lỗi** SSL tương tự — xác nhận `stg_bcvtth_team_service`
  (bị ref 3 lần) mới là bottleneck chính.
- Vật lý hoá TOÀN BỘ 7 model stg/int thành `table`: build cả 8 model (kể cả
  mart) chỉ còn **48 giây, thành công**.

**Kết luận:** nếu sửa/thêm model mới trong folder này mà pipeline lại chậm bất
thường, ưu tiên kiểm tra materialization trước khi nghĩ tới việc thêm index —
`+materialized: ephemeral` chỉ phù hợp khi model nhỏ và không bị `ref()` nhiều
lần trong cùng 1 lần build.

---

## Verify đã chạy (warehouse thực tế, không phải ước lượng)

- Unique key sạch tuyệt đối trên toàn bộ dữ liệu build (799,055/799,055 dòng
  duy nhất theo `form_supply_id, service_product_id, employee_id`).
- `SUM(allocated_qty)` / `SUM(allocated_cost_value)` khớp với tổng `qty_used`/
  giá trị tiền gốc của `form_supply_id` **NGOẠI TRỪ** trường hợp 1 phiếu có
  dịch vụ hoàn toàn không xác định được bác sĩ (xem mục "Dịch vụ không có cả
  2 vai trò" ở trên) — đã verify cụ thể: **8/17,239 phiếu surgery (~0.05%)**
  bị thiếu 1 phần tiền phân bổ vì đúng lý do này (vd. form_id=112374: dịch vụ
  13718 chiếm 76.3% giá trị 1 vật tư nhưng chỉ có nhân sự roleid 4/7/18/45,
  không có roleid 1 hay 2 → bị loại). Đây là hành vi ĐÚNG THIẾT KẾ, không
  phải bug — xem cột `allocated_cost_value`/`service_rate` trong `schema.yml`
  để biết cách phát hiện các trường hợp này khi query.
- `bom_qty` phủ 486,093/799,055 dòng (~61%) — phần còn lại là vật tư dùng
  thực tế nhưng không nằm trong định mức BOM chuẩn của dịch vụ tương ứng
  (hoặc dịch vụ/phiếu chưa khai báo BOM).
