# Logic: report_phone_call_after_service

Báo cáo **cuộc gọi chăm sóc sau dịch vụ** (nhắc tái khám, TBCC, liệu trình…).
Gốc là phone call trên ERP (`crm_phone_call`), ghép thêm:
- cuộc gọi thực tế trên CareSoft (`cs_call_api`);
- khách có đến tái khám đúng ngày hẹn không (`sh_medical_evaluation`);
- doanh số phát sinh (PS) của khách trong ngày hẹn (`crm_line` / `crm_line_product` + `stag_payment_transfer`).

Phạm vi: **không lọc brand** → mọi brand có trong `public.crm_phone_call`.
Tiền tố model: `rpcas`. Thư mục con: `stg` / `int` / `mart`.

Output: bảng **`report_rpcas_phone_call_final`** (mart, `materialized='table'` khai báo ngay
trong file). Materialized và tag của `stg` / `int` lấy theo `dbt_project.yml` (không nằm trong
thư mục này). Theo quy ước dự án chúng là ephemeral, khi đó mart là bảng vật lý duy nhất.

Giờ ERP (Odoo lưu UTC) được `+ 7 giờ` rồi mới lấy ngày, **trừ** `stag_payment_transfer.payment_date`
(lấy nguyên). Giờ CareSoft cũng **không** cộng — xem [Điểm cần xử lý](#điểm-cần-xử-lý--kiểm-tra).

---

## Kiến trúc

```
Sources (phone_call_after_service, schema public)
  ├── crm_phone_call  ← GỐC (lọc type_pc, active, call_date ≥ 2023-08-01)
  │     └── mart/report_rpcas_phone_call_final
  │            ├── res_partner / m_res_company / res_brand / crm_lead / sale_order   (mô tả)
  │            ├── walkin → sh_walkin_service_rel → dịch vụ → view_stag_products   (dịch vụ phiếu khám)
  │            ├── calendar_event                                                  (lịch hẹn)
  │            ├── stg/stg_rpcas_phone_call_history ← crm_phone_call_history
  │            │      ├── view_stag_employees_user                                 (người gọi ERP)
  │            │      └── cs_call_api → cs_agents_api                              (cuộc gọi CareSoft)
  │            ├── stg/stg_rpcas_data_tk ← sh_medical_evaluation + ...             (đúng / sai lịch)
  │            └── int/int_rpcas_ps                                                (doanh số PS)
  │                   ├── stg/stg_rpcas_crm_line_info          ← crm_lead + crm_line + stag_payment_transfer
  │                   └── stg/stg_rpcas_crm_line_product_info  ← crm_lead + crm_line_product + stag_payment_transfer
  └── stg/stg_rpcas_data_pk ← walkin + crm_lead + res_partner                       (KHÔNG được dùng)
```

---

## Tầng STG

### `stg_rpcas_phone_call_history` — lịch sử phone call
- Nguồn `crm_phone_call_history`, giữ nguyên `cpch.*`.
- Lấy dòng có `phone_call_id` không NULL **hoặc** `res_model = 'crm.phone.call'`.
- `id_phonecall = coalesce(phone_call_id, res_id)` → khoá nối về `crm_phone_call.id`.
- Mart dùng: `ticket_id` (nối CareSoft), `call_id`, `write_uid` (người gọi trên ERP), `brand_etl`.
- 1 phone call có thể có **nhiều** dòng lịch sử → nhân dòng ở mart.

### `stg_rpcas_data_tk` — phiếu tái khám hoàn thành, đúng ngày hẹn
- Nguồn `sh_medical_evaluation` (phiếu tái khám), `state = 'Completed'`.
- Chỉ giữ phiếu có **ít nhất 1** `crm_phone_call` thoả cả 3 điều kiện:
  - cùng brand;
  - `cpc.medical_id = sme.walkin` (cùng phiếu khám gốc);
  - ngày hẹn `date(booking_date + 7h)` = ngày tái khám `date(evaluation_start_date + 7h)`.
- Gắn cứng `dung_sai_lich = 'Đúng lịch'`.
- Điều kiện `exists` này **không** áp các bộ lọc của mart (`type_pc`, `active`, `call_date`):
  phone call nào cùng brand cũng tính, kể cả phone call đã `active = false`.
- `loai_tk` lấy qua `sh_evaluation_services_type_rel → sh_medical_evaluation_services`. Đây là
  quan hệ nhiều-nhiều, nên 1 phiếu có nhiều loại thì ra nhiều dòng.
- Không xuất cột `brand_etl`.

### `stg_rpcas_data_pk` — phiếu khám hoàn thành, đúng ngày hẹn
- Nguồn `sh_medical_appointment_register_walkin`, `state = 'Completed'`.
- Chỉ giữ phiếu có phone call cùng brand, `cpc.crm_id = smarw.booking_id`, ngày hẹn = ngày khám.
- Gắn cứng `dung_sai_lich = 'Đúng lịch'`.

> ⚠️ Không model nào trong thư mục `ref` tới `stg_rpcas_data_pk` → nếu ephemeral thì không sinh ra gì.
> Mart chỉ xét đúng / sai lịch theo **phiếu tái khám**, không theo phiếu khám.

### `stg_rpcas_crm_line_info` / `stg_rpcas_crm_line_product_info` — line của booking (nguồn PS)

| | `stg_rpcas_crm_line_info` | `stg_rpcas_crm_line_product_info` |
|---|---|---|
| Bảng line | `crm_line` (nối `crm_id`) | `crm_line_product` (nối `booking_id`) |
| Dịch vụ `dv` | `crm_line.service_id → sh_medical_health_center_service.product_id → view_stag_products` | `crm_line_product.product_id → view_stag_products` |
| Loại line huỷ | `crm_line.stage <> 'cancel'` | `stage_line_product <> 'cancel'` |
| `ngay_tao` | `date(crm_line.create_date + 7h)` | `date(crm_line_product.create_date + 7h)` |
| Thanh toán | `stag_payment_transfer`: `crm_id` + `clineid = crm_line.id` | `crm_id` + `clineid = crm_line_product.id` |

Quy tắc chung:
- `crm_lead.type_crm_id = 2` (comment trong code gọi là "booking line").
- Kèm thêm `crm_stage` (`tt_book`), `stag_sources` theo `old_id` (`nguon_book_ps`), nhân viên từ
  `view_stag_employees_user`. Các join đều kèm brand; riêng `stag_sources` so
  `cl.brand_etl = ss.brand_id` (cột `brand_id`, không phải `brand_etl`).
- Điều kiện `<> 'cancel'` nằm ở WHERE → booking không có line bị loại (left join thành inner),
  line có trạng thái NULL cũng bị loại.
- Chỉ lọc trạng thái **line**, không lọc trạng thái booking (`crm_stage`) hay trạng thái thanh toán
  → line chưa huỷ của booking đã huỷ / thất bại vẫn được tính.
- Grain: 1 dòng / line × phiếu thanh toán. Line chưa thanh toán vẫn có 1 dòng, cột thanh toán NULL.
- `doanh_so = spt.payment`, lấy nguyên giá trị, không xử lý dấu.
- `payment_date` lấy nguyên từ `stag_payment_transfer`, không `+7h`.
- Cùng cột `spt.clineid` được nối với `crm_line.id` ở model này và `crm_line_product.id` ở model
  kia. Code không cho biết `clineid` trỏ tới bảng nào, nên nếu 1 booking có `crm_line` và
  `crm_line_product` trùng id thì cùng 1 phiếu thanh toán bị gắn vào cả 2 model.

> ⚠️ **Hai model gán cột nhân viên khác nhau** (UNION ghép theo vị trí cột):
>
> | Cột | `..._crm_line_info` | `..._crm_line_product_info` |
> |---|---|---|
> | `ng_tao` | tư vấn 1 của line (`consultants_1`) | người tạo booking (`create_by`) |
> | `tu_van1` | người tạo booking | tư vấn 1 của line |
> | `pb_tu_van1` | phòng ban người tạo booking | phòng ban tư vấn 1 |
> | `ma_pb_tu_van1` | phòng ban tư vấn 1 | phòng ban tư vấn 1 |
>
> → Ở `stg_rpcas_crm_line_info`, `ng_tao` và `tu_van1` bị đảo, và `pb_tu_van1` không cùng người
> với `ma_pb_tu_van1`. Mart hiện không lấy các cột này nên **chưa ảnh hưởng số**, nhưng sẽ sai
> nếu sau này dùng.

---

## Tầng INT

### `int_rpcas_ps` — line phát sinh (PS)
- `union all` 2 model line ở trên (20 cột, cùng thứ tự).
- `id_line_ps` **không unique**: lặp theo phiếu thanh toán (grain line × phiếu), lặp giữa các
  brand, và lấy từ 2 dãy id khác nhau (`crm_line.id`, `crm_line_product.id`).
- Không có cột cho biết dòng đến từ `crm_line` hay `crm_line_product`, cũng không có cột `brand_etl`.

---

## Tầng MART — `report_rpcas_phone_call_final`

### Dòng gốc: `crm_phone_call`

| Điều kiện | Giá trị |
|---|---|
| `type_pc` | `Change`, `Change1`–`Change5`, `ReCheck`, `ReCheck1`, `ReCheck4`–`ReCheck11` |
| `active` | `true` |
| `date(call_date + 7h)` | `>= '2023-08-01'` (cố định trong code) |
| brand | không lọc |

- Comment trong code: `ReCheck9` = tái khám, `ReCheck10` = liệu trình. Các mã khác chưa có chú thích.
- **`ReCheck2`, `ReCheck3` không nằm trong danh sách.**

### Các join

| Khối | Nguồn | Điều kiện join | Cột ra | Nhân dòng |
|---|---|---|---|---|
| Khách | `res_partner` | `partner_id` + brand | `ten_kh` | không |
| Chi nhánh / thương hiệu | `m_res_company` → `res_brand` | `company_id` + brand → `brand_id` + brand | `chi_nhanh`, `thuong_hieu` | không |
| Booking / đơn | `crm_lead`, `sale_order` | `crm_id` / `order_id` + brand | `booking`, `so` | không |
| Phiếu khám + dịch vụ | walkin → `sh_walkin_service_rel` → `sh_medical_health_center_service` → `view_stag_products` | `medical_id` + brand, các bước sau đều kèm brand | `pk`, `product_id`, `product`, `product_category`, `his_service_type` | **có** — 1 dòng / dịch vụ của phiếu khám |
| Lịch sử gọi | `stg_rpcas_phone_call_history` | `id_phonecall` + brand | `ticket_id`, `call_id` | **có** |
| Người gọi ERP | `view_stag_employees_user` | `write_uid` của dòng lịch sử + brand | `id_ng_goi_erp`, `ten_ng_goi_erp`, `id_pb_ng_goi_erp`, `pb_ng_goi_erp`, `employee_code` | không |
| Cuộc gọi CareSoft | `cs_call_api` | **chỉ `ticket_id`** (ép `numeric`) | `id_cs_call`, `caller`, `time_bat_dau`, `time_ket_thuc`, `time_goi`, `call_status`, `id_ng_goi` | có thể (nhiều cuộc / ticket) |
| Agent CareSoft | `cs_agents_api` | **chỉ `agent_id`** | `ng_goi` | có thể (nếu `agent_id` trùng giữa các domain) |
| Đúng / sai lịch | `stg_rpcas_data_tk` | `id_pk = medical_id` + ngày hẹn = `ngay_tk`, **không có brand** | `dung_sai_lich` | có thể (nhiều loại TK) |
| Lịch hẹn | `calendar_event` | **chỉ `phonecall = cpc.id`, không có brand** | `id_calendar`, `henlich_calendar` | có thể |
| PS | `int_rpcas_ps` | `ma_kh = code_customer` + `ngay_tao` = ngày hẹn, **không có brand** | `id_line_ps`, `booking_ps`, `id_crm_lead_ps`, `ngay_tao_line_ps`, `payment_ps`, `ngay_tt_ps`, `id_phieu_ps`, `ma_phieu_ps`, `dv_ps` | **có** — 1 dòng / line × phiếu |

### Cột tính toán

| Cột | Cách tính |
|---|---|
| `ngay_goi` | `call_date + 7h` — ngày gọi trên ERP (timestamp) |
| `ngay_hl` | `booking_date + 7h` — ngày hẹn khách đến |
| `ngay_goi_thuc_te` | `date(cs_call_api.start_time)` — **không +7h** |
| `ngay_goi_thuc_te_fulltime` | `cs_call_api.start_time` (trùng giá trị với `time_bat_dau`) |
| `ngay_tt_ps` | `stag_payment_transfer.payment_date`, lấy nguyên |
| `type_crm_id` | lấy nguyên từ `crm_phone_call` |
| `giay_goi` | `extract(epoch from talk_time::interval)` |
| `loai_ket_noi` | `giay_goi >= 15` → `'Kết nối'`; còn lại → `'Không kết nối'` |
| `check_db` | `cs_call_api.caller = crm_phone_call.phone` → `true`, còn lại `false`; so nguyên chuỗi, không chuẩn hoá SĐT |
| `dung_sai_lich` | khớp được `stg_rpcas_data_tk` → `'Đúng lịch'`, còn lại `'Sai lịch'` |

Ý nghĩa của các giá trị "còn lại":
- `'Không kết nối'` gồm cả cuộc gọi dưới 15 giây **và** phone call không tìm thấy cuộc gọi
  CareSoft nào (`giay_goi` NULL).
- `'Sai lịch'` gồm: khách tái khám khác ngày hẹn; khách không đến; phiếu tái khám chưa
  `Completed`; phiếu tái khám gắn với phiếu khám khác `medical_id` của phone call; phone call
  không có `medical_id`; khách đến khám (walkin) đúng hẹn nhưng không có phiếu tái khám (vì
  `stg_rpcas_data_pk` không được dùng).
- `dung_sai_lich` tính cho **mọi** `type_pc` nhưng chỉ so với phiếu tái khám → phone call loại
  `Change*`, `ReCheck10` (liệu trình)… phần lớn sẽ ra `'Sai lịch'` do cách tính, không phải do khách
  sai hẹn.

### Doanh số phát sinh (PS)
Line không huỷ, thuộc booking (`type_crm_id = 2`) của **cùng mã khách** (`ma_kh = code_customer`),
**tạo đúng ngày hẹn** (`ngay_tao = date(booking_date + 7h)`). Comment trong code: "ngày tạo line =
ngày đến tk, tbcc, liệu trình".
- Không yêu cầu khách đã đến hay phiếu đã `Completed`.
- Không yêu cầu line thuộc booking của phone call: mọi booking của khách đều tính.
- `payment_ps` gồm **mọi** phiếu thanh toán của line, không lọc `payment_date` → khách trả ở
  ngày sau vẫn tính.

---

## Cách dùng

Mart **không phải 1 dòng / phone call**: dòng bị nhân theo dịch vụ của phiếu khám × dòng lịch sử ×
cuộc gọi CareSoft × calendar × loại tái khám × line PS × phiếu thanh toán.

| Chỉ số | Cách đếm |
|---|---|
| Số phone call | `count(distinct id_phonecall)` |
| Số cuộc gọi CareSoft thực tế | `count(distinct id_cs_call)` |
| Phone call có kết nối | `count(distinct id_phonecall)` với `loai_ket_noi = 'Kết nối'` |
| Phone call đúng lịch | `count(distinct id_phonecall)` với `dung_sai_lich = 'Đúng lịch'` |
| Doanh số PS | **không** `sum(payment_ps)` thẳng. Lấy distinct theo phiếu (`id_phieu_ps`) trước rồi mới cộng |

- Khách có ≥ 2 phone call cùng ngày hẹn thì PS gắn vào **cả hai** → cộng PS theo từng phone call
  sẽ bị trùng; muốn ra tổng thì gom theo khách + ngày.
- `id_phieu_ps` (= `stag_payment_transfer.id`) nhiều khả năng chỉ unique trong 1 brand. Mart không
  có brand nên distinct theo `id_phieu_ps` có thể gộp nhầm phiếu của 2 brand trùng id (hiếm).
- Mart không có cột `brand_etl`.
  - `brand_id` là cột thô của `crm_phone_call`, không phải `brand_etl` và không được join đi đâu.
  - `thuong_hieu` lấy qua công ty (`company_id → m_res_company.brand_id → res_brand`), không qua
    `brand_id` của phone call.

---

## Điểm cần xử lý / kiểm tra

Rút ra từ đọc code, **chưa đo trên dữ liệu**.

1. **Join thiếu điều kiện brand** — id ERP trùng giữa các brand nên có thể ghép nhầm sang brand khác:
   - `calendar_event` (`phonecall = cpc.id`): id phone call của các ERP rất dễ trùng → nguy cơ cao nhất,
     vừa sai `henlich_calendar` vừa nhân dòng.
   - `int_rpcas_ps` (`ma_kh` + ngày): nếu mã khách trùng giữa các ERP thì PS bị cộng nhầm.
   - `cs_call_api` (`ticket_id`) và `cs_agents_api` (`agent_id`): nếu id trùng giữa các domain
     CareSoft thì ghép nhầm. *(Ngoài code, theo tài liệu hạ tầng:)* CareSoft THV nằm ở các bảng
     `*_thv` riêng, nên phone call THV hoặc không ghép được cuộc gọi nào, hoặc ghép nhầm sang ticket
     trùng số của domain khác.
   - `stg_rpcas_data_tk` (`id_pk` + ngày): phải trùng cả id phiếu khám lẫn ngày nên ít khả năng hơn.
   - Cách sửa: xuất `brand_etl` ở `stg_rpcas_data_tk` và 2 model line (kéo qua `int_rpcas_ps`), rồi
     thêm vào điều kiện join. Với CareSoft, cần xem `cs_call_api` có cột brand / domain không.
2. **Nhân dòng ở mart** — xem [Cách dùng](#cách-dùng). Nếu Tableau đang `SUM` / `COUNT` thẳng thì số bị phóng to.
3. **`stg_rpcas_crm_line_info` đảo cột nhân viên** (`ng_tao` ↔ `tu_van1`, `pb_tu_van1`) — chưa ảnh
   hưởng mart.
4. **`int_rpcas_ps` thiếu cột phân biệt** `crm_line` / `crm_line_product` và `brand_etl`; `clineid`
   được nối với cả 2 bảng line → có thể gắn 1 phiếu thanh toán vào 2 line.
5. **`stg_rpcas_data_pk` không được dùng** — hoặc nối vào `dung_sai_lich`, hoặc xoá. Trước khi xoá,
   tìm `stg_rpcas_data_pk` trong toàn bộ `models/` để chắc không thư mục khác `ref` tới.
6. **`ReCheck2`, `ReCheck3` bị bỏ ngoài danh sách `type_pc`** — cần xác nhận có chủ đích không.
7. **Múi giờ CareSoft**: cột ERP đều `+7h`, `cs_call_api.start_time` thì không. Nếu `start_time`
   lưu UTC thì cuộc gọi trước 7h sáng bị lùi sang ngày hôm trước ở `ngay_goi_thuc_te`.
8. **`res_brand` gọi thẳng tên bảng**, không ghi schema, không qua `source()` và không khai báo
   trong `sources.yml` → dbt không thấy trong lineage, và bảng được tìm theo `search_path` của kết
   nối chứ không cố định `public`.
9. **`cpch.ticket_id::numeric`**: nếu `ticket_id` là kiểu chữ và có giá trị không phải số (kể cả
   chuỗi rỗng) thì cả mart build lỗi.
10. **PS không lọc trạng thái booking** — line của booking đã huỷ / thất bại vẫn tính nếu line chưa huỷ.
11. `check_db` so SĐT nguyên chuỗi → lệch định dạng (`84…` / `0…`, dấu cách) sẽ ra `false`.
12. Mốc `2023-08-01` viết cứng trong mart (có thể chuyển thành var).
13. Comment đầu `stg_rpcas_crm_line_product_info.sql` ghi nhầm tên `stg_rpcas_crm_line_info`.

---

## Lưu ý vận hành

1. Chỉ mart sinh bảng. Các model `stg` / `int` (nếu ephemeral như quy ước) được dịch thẳng vào SQL
   của mart; muốn xem số từng bước thì dùng `dbt show --select <model>` hoặc SQL đã compile trong
   `target/compiled/`.
2. Mart build lại toàn bộ mỗi lần chạy (table, không incremental), lấy lịch sử từ 2023-08-01.
3. Mart không lọc thời gian ngoài mốc trên — phía dùng tự lọc `ngay_goi` / `ngay_hl` /
   `ngay_goi_thuc_te`.
