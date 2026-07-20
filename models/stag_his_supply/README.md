# stag_his_supply — Logic Model

Gom **vật tư/thuốc đã sử dụng** (supply) từ 5 nghiệp vụ khác nhau trong HIS
(khám chuyên khoa, phẫu thuật, đánh giá/evaluation, nội trú, xét nghiệm), chuẩn
hoá về **cùng một schema cột**, rồi union lại thành một luồng "vật tư theo
form dịch vụ" duy nhất, enrich thêm thông tin khách hàng/địa điểm/quy đổi đơn
vị trước khi publish ra mart.

Output chính: `mart_shs_form_supply` (alias `stag_his_form_supply_2`).

## 1. Sơ đồ pipeline (bottom-up)

```
stg (1 file/1 bảng nguồn shs_his, SELECT * không filter brand_etl)
        │
        ├─► int_shs_specialty_supply  (data_union='specialty')  WHERE state='Done'
        ├─► int_shs_surgery_supply    (data_union='surgery')    WHERE state='Done'
        ├─► int_shs_evaluation_supply (data_union='evaluation') WHERE state='Completed'
        ├─► int_shs_inpatient_supply  (data_union='inpatient')  WHERE state='Completed'
        └─► int_shs_lab_test_supply   (data_union='lab_test')   WHERE state='Completed'
                    │  (mỗi nhánh JOIN service_rel + supply-detail + form-cha,
                    │   remap về cùng 1 bộ cột chung)
                    ▼
        int_shs_supplies_union  (UNION ALL 5 nhánh trên)
                    ▼
        int_shs_form_supply
          - rn_form_supply = row_number() theo (brand_etl, data_union, id)
          - JOIN thêm: sh_medical_medicines (loại vật tư/thuốc + product_id),
            uom_uom (tên đơn vị), sh_medical_appointment_register_walkin (walkin),
            crm_lead (booking, khách hàng), sh_medical_health_center (công ty),
            stock_location x2 (địa điểm + địa điểm cha = phòng ban),
            sh_medical_health_center_service (product_id của dịch vụ),
            stock_picking (tên phiếu kho)
          - id_etl = khoá tổng hợp: data_union-id-service_product_id-supply_product_id-brand_etl
                    ▼
        mart_shs_form_supply (alias stag_his_form_supply_2)
          incremental append; pre_hook: DELETE WHERE brand_etl <> 0 trước khi insert
```

## 2. Lớp `stg`

Toàn bộ model `stg` trong thư mục này chỉ là `SELECT * FROM source` (1
file/1 bảng nguồn, **không filter `brand_etl`** — khác với các model khác
trong repo, filter được đẩy xuống tầng `int`): `sh_surgery_specialty_service_rel`,
`sh_medical_specialty_supply`, `sh_medical_specialty`,
`sh_surgery_supply_service_rel`, `sh_medical_surgery_supply`,
`sh_medical_surgery`, `sh_evaluation_supply_service_rel`,
`sh_medical_evaluation_supply`, `sh_medical_evaluation`,
`sh_medical_patient_rounding_medicines`, `sh_medical_patient_rounding`,
`sh_rounding_service_rel`, `sh_medical_inpatient`,
`sh_medical_lab_test_material`, `sh_medical_lab_test`,
`sh_medical_medicines`, `uom_uom`, `sh_medical_appointment_register_walkin`,
`sh_medical_health_center`, `stock_location`, `crm_lead`,
`sh_medical_health_center_service`, `stock_picking`.

## 3. Lớp `int` — 5 nhánh "supply theo nghiệp vụ"

Mỗi nhánh JOIN 1 bảng *service_rel* (hoặc *material*) với bảng chi tiết vật
tư và bảng form nghiệp vụ (cha), rồi remap về **cùng một bộ cột chung**:
`data_union, id, name, qty, uom_id, supply, notes, qty_used, location_id,
medicament_type, sequence, create_uid, create_date, write_uid, write_date,
picking_id, explanation_supply, form_id, form_name, services_date, patient,
service_id, walkinid, ward_id, room_id, institution, department_type, brand_etl`
— đây là điều kiện tiên quyết để `UNION ALL` ở bước sau hoạt động đúng.

### `int_shs_specialty_supply` (`data_union='specialty'`)
`sh_surgery_specialty_service_rel` → JOIN `sh_medical_specialty_supply`
(theo `sh_medical_specialty_supply_id`) → JOIN `sh_medical_specialty`
(form cha, theo `smss.name = sms.id`). Lọc `sms.state = 'Done'` và
`service_rel.brand_etl <> 0`. `department_type` lấy **giá trị thật** từ
`sms.department_type`.

### `int_shs_surgery_supply` (`data_union='surgery'`)
Tương tự nhánh specialty nhưng nguồn là `sh_surgery_supply_service_rel` →
`sh_medical_surgery_supply` → `sh_medical_surgery`. Lọc
`smsurg.state = 'Done'`. `ward_id = department`, `room_id = operating_room`,
`department_type` cũng lấy giá trị thật từ `smsurg.department_type`.

### `int_shs_evaluation_supply` (`data_union='evaluation'`)
`sh_evaluation_supply_service_rel` → `sh_medical_evaluation_supply` →
`sh_medical_evaluation`. Lọc `sme.state = 'Completed'`.
`explanation_supply` **luôn NULL** (bảng nguồn không có cột tương ứng).
`services_date = sme.evaluation_start_date`. `department_type` **hard-code
`'Surgery'`** dù đây là nghiệp vụ khám/đánh giá, không phải phẫu thuật.

### `int_shs_inpatient_supply` (`data_union='inpatient'`)
CTE gốc `sh_medical_patient_rounding_medicines` remap cột (`medicine → supply`,
`qty` dùng lại cho cả `qty_used`, `dosage → explanation_supply`), lọc
`brand_etl <> 0` ngay trong CTE. JOIN `sh_medical_patient_rounding` (form cha,
theo `name = id`) → `sh_rounding_service_rel` (lấy `service_id`) →
`sh_medical_inpatient` (theo `inpatient_id`, lấy `ward_id`/`room_id`/`institution`).
Lọc `smpr.state = 'Completed'`. `services_date = smpr.evaluation_end_date`.
`department_type` **hard-code `'Surgery'`**.

### `int_shs_lab_test_supply` (`data_union='lab_test'`)
CTE gốc `sh_medical_lab_test_material` remap cột (`lab_test_id → name`,
`init_quantity → qty`, `product_id → supply`, `quantity → qty_used`,
`explanation_supply = ''` hard-code), lọc `brand_etl <> 0` trong CTE. JOIN
`sh_medical_lab_test` (form cha, theo `name = id`). Lọc
`smlt.state = 'Completed'`. **`service_id = NULL`** (không có bảng
service_rel cho lab test). `department_type` **hard-code `'Surgery'`**.

### `int_shs_supplies_union`
`UNION ALL` 5 nhánh trên, theo thứ tự: specialty, surgery, evaluation,
inpatient, lab_test.

### `int_shs_form_supply`
Enrich thêm cho toàn bộ union:
- `rn_form_supply = ROW_NUMBER() OVER (PARTITION BY brand_etl, data_union, id)`
  — đánh dấu trùng lặp trong từng nhóm (id gốc không unique giữa các nhánh,
  cần kèm `data_union` + `brand_etl` để phân biệt).
- `supply_category`: `'THUỐC'` nếu `sh_medical_medicines.medicament_type = 'Medicine'`,
  ngược lại `'VẬT TƯ'` (join theo `s.supply = smm.id`).
- `supply = smm.name_use`, `supply_product_id = smm.product_id`,
  `uom = uu.name` (join `uom_uom` theo `uom_id`).
- `location = sl.name` (join `stock_location` theo `location_id`);
  `location_department = slw.name` — **join thêm 1 lớp nữa**
  (`sl.location_id = slw.id`, tức lấy **location cha của location**) để suy
  ra phòng ban cấp kho.
- `booking/walkin/khách hàng`: `s.walkinid → sh_medical_appointment_register_walkin
  → crm_lead` (qua `booking_id`), lấy `crm_id`, `booking`, `code_customer`,
  `contact_name`.
- `company = sh_medical_health_center.company_name`,
  `company_id = smhc.his_company` (join theo `s.institution`).
- `product_id = sh_medical_health_center_service.product_id` (join theo
  `s.service_id`) — product_id phía **dịch vụ**, khác `supply_product_id`
  (product_id phía **vật tư**).
- `picking = stock_picking.name` (join theo `s.picking_id`).
- `id_etl = data_union || '-' || id || '-' || product_id(service) || '-' ||
  supply_product_id || '-' || brand_etl` (mỗi phần `COALESCE(...,'0')` nếu
  NULL) — khoá tổng hợp duy nhất cho từng dòng vật tư trên toàn bộ union.

## 4. Lớp `mart`

### `mart_shs_form_supply` (alias `stag_his_form_supply_2`)
`SELECT * FROM int_shs_form_supply`, materialize `incremental` +
`incremental_strategy='append'`. `pre_hook`: nếu đang chạy incremental,
**`DELETE FROM {{ this }} WHERE brand_etl <> 0`** trước khi insert — tức mỗi
lần chạy đều xoá sạch toàn bộ dữ liệu của các brand thật (`brand_etl <> 0`)
rồi nạp lại từ đầu (full refresh theo brand), chỉ append thêm chứ không xoá
những dòng `brand_etl = 0` (nếu có, thường là dữ liệu legacy/seed).

## 5. Rủi ro / điểm cần lưu ý khi sửa đổi

1. **`department_type` hard-code `'Surgery'`** ở 3/5 nhánh (`evaluation`,
   `inpatient`, `lab_test`) dù các nghiệp vụ này không phải phẫu thuật — chỉ
   `specialty` và `surgery` lấy giá trị thật từ bảng nguồn. Nhiều khả năng là
   copy-paste khi tạo mới các nhánh sau; cần xác nhận với nghiệp vụ trước khi
   sửa vì mart đang phụ thuộc vào giá trị này để phân loại.
2. **`explanation_supply` không nhất quán giữa các nhánh**: giá trị thật ở
   `surgery`/`specialty`/`inpatient`, luôn `NULL` ở `evaluation`, luôn chuỗi
   rỗng `''` ở `lab_test` — 3 kiểu "rỗng" khác nhau (`NULL` vs `''`) có thể
   gây lệch khi lọc/so sánh phía downstream.
3. **`service_id = NULL` cứng ở nhánh `lab_test`** — không có bảng
   `service_rel` tương ứng nên mọi dòng lab_test không map được sang
   `sh_medical_health_center_service` → `product_id` (phía dịch vụ) luôn NULL
   cho nhánh này trong `int_shs_form_supply`.
4. **`location_department` là "location cha của location"** (tự join
   `stock_location` 2 lần) — phụ thuộc hoàn toàn vào cấu trúc phân cấp kho
   trong Odoo có đúng 1 cấp cha là "phòng ban"; nếu cấu trúc kho thay đổi
   (thêm/bớt cấp), cột này sẽ sai mà không có lỗi rõ ràng.
5. **`state` filter khác nhau theo nghiệp vụ**: `specialty`/`surgery` dùng
   `'Done'`, còn `evaluation`/`inpatient`/`lab_test` dùng `'Completed'` — đúng
   theo từng module Odoo gốc, không phải lỗi, nhưng dễ gõ nhầm khi thêm nhánh
   mới.
6. **`pre_hook` xoá toàn bộ `brand_etl <> 0` mỗi lần chạy incremental** — nếu
   một run bị lỗi giữa chừng (ví dụ 1 trong 5 nhánh int bị fail hoặc source
   thiếu dữ liệu tạm thời), bảng mart có thể mất dữ liệu của các brand khác
   cho tới lần chạy thành công kế tiếp, vì đây thực chất là "xoá rồi nạp lại
   toàn bộ" chứ không phải incremental theo đúng nghĩa merge/upsert.
7. **`brand_etl <> 0` được lọc ở tầng `int`** (trong CTE của `inpatient`,
   `lab_test`, hoặc điều kiện `WHERE` của `specialty`/`surgery`/`evaluation`)
   trong khi tầng `stg` không filter gì — cần nhớ thứ tự này khi debug thiếu
   dữ liệu theo brand.
