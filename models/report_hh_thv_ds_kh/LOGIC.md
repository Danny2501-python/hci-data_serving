# Logic: report_hh_thv_ds_kh

Gộp **doanh số, chỉ tiêu, chi phí ads và lead/booking CRM** của 2 thương hiệu
**Hồng Hà** (brand_etl = 4) và **Tiêu Hóa Việt** (brand_etl = 8) vào 1 bảng dạng
dòng (long format), cùng bộ cột, để dựng báo cáo doanh số vs kế hoạch, chi phí
ads và phễu SĐT → booking → đến cửa trên 1 nguồn duy nhất.
Tag dbt: `report_hh_thv_ds_kh`.

Mọi bảng/model đều có `brand_etl` (+ `ten_thuong_hieu`); mọi join sang
`utm_source` / `m_utm_source_old_new_map` đều kèm `brand_etl` (id nguồn KHÔNG
unique giữa các brand).

Model **không tự tính doanh số** — lấy từ 2 model đã có (không sửa):
- `rhh_ehc_payment_service` (folder `report_hh_revenue`)
- `report_thv_revenue` + `rtr_target_latest` (folder `report_thv_revenue`)

→ Logic doanh số gốc xem `report_hh_revenue/LOGIC.md`, `report_thv_revenue/LOGIC.md`.

---

## Materialization

| Tầng | Cấu hình |
|---|---|
| `int/*`, `stag/*` | `ephemeral` (không tạo bảng) |
| `mart/report_hh_thv_ds_kh` | `table` → `public.report_hh_thv_ds_kh` (bảng duy nhất trên DB) |
| `int/rhtdk_noi_soi_thv` | `table` → `public.rhtdk_noi_soi_thv` (booking THV có dịch vụ nội soi; tách bảng để join vào `rhtdk_booking_dc` không bị chậm) |

`int/rhtdk_thv_target` **không còn được dùng** (target THV theo loại md/ml… đã bỏ, chỉ giữ chỉ tiêu tổng).

---

## Kiến trúc

```
report_hh_revenue/rhh_ehc_payment_service ─→ int/rhtdk_hh ──────────┐
report_thv_revenue/report_thv_revenue ─────→ int/rhtdk_thv_ds ──────┤
ggs_target_company + rtr_target_latest ────→ int/rhtdk_target ──────┤
ggs_target_ads_thv_hh ─────────────────────→ int/rhtdk_chi_phi_ads ─┼─→ stag/rhtdk_combine ─→ mart/report_hh_thv_ds_kh
crm_lead ─→ int/rhtdk_lead_base ─┬─→ int/rhtdk_sdt ─────────────────┤
                                 ├─→ int/rhtdk_booking_create ──────┤
                                 ├─→ int/rhtdk_booking ─────────────┤
                                 └─→ int/rhtdk_booking_dc ──────────┘
```

Thứ tự build: cần build `report_hh_revenue` và `report_thv_revenue` **trước**:

```
dbt run -s tag:report_hh_revenue tag:report_thv_revenue tag:report_hh_thv_ds_kh
```

Dữ liệu EHC/CRM được ETL nạp ban đêm (D-1) → số mới nhất là ngày hôm trước.

---

## Tầng INT

### Doanh số

| Model | Brand | Nguồn | Ghi chú |
|---|---|---|---|
| `rhtdk_hh` | 4 | `rhh_ehc_payment_service` | `nguon_du_lieu` Dịch vụ / Nhà thuốc / Target (Target bị loại ở combine). Tính `nhom_md_ml_baocao` (xem dưới) |
| `rhtdk_thv_ds` | 8 | `report_thv_revenue` | `dich_vu`→`Dịch vụ`, `nha_thuoc`→`Nhà thuốc`. `patientcode` lấy thêm từ `ehc_tb_patientrecord_thv` (patientrecordid unique → không nhân dòng). `nhom_md_ml_baocao` giữ nguyên của THV |

Cả 2 xuất cùng 27 cột, cùng thứ tự, ép kiểu tường minh để `union all`.

**`nhom_md_ml_baocao` của Hồng Hà** — gom theo nhóm hoa hồng EHC
(`dm_hoahongnguoigioithieu_nguoigioithieuname`); KHÔNG dùng nguyên rule tên của
THV vì vocab HH khác (nhóm "Marketing"/"[MAR_ON]" sẽ bị rule THV đẩy sang ML).
Thứ tự ưu tiên:

| # | Điều kiện | Nhóm |
|---|---|---|
| 1 | nhóm `[TPM]Thuê phòng mổ` | **ML** (mục tiêu Nguồn Offline của HH gồm cả thuê phòng mổ) |
| 2 | `source_ehc` chứa `CBNV` và không chứa `CTV` | CBNV |
| 3 | `source_ehc` chứa `Vãng lai` | MD, **từ T10/2026 → ML** (giống THV) |
| 4 | nhóm `[MO]` / `[MAR_OFF]` / `Trade Marketing` | MO (tách riêng, chỉ có 2018–2025) |
| 5 | nhóm `Marketing` / `[MAR_ON]` / `[MD]` / `[DGMKT]` | MD |
| 6 | không có cả nhóm lẫn người giới thiệu | NULL; riêng **Nhà thuốc từ T9/2026 → ML** (Thuốc bán lẻ, giống THV) |
| 7 | còn lại (CTV, giới thiệu, loyalty, `[ML]`, DVKH, BP Kinh doanh…) | ML |

### Chỉ tiêu & chi phí ads

| Model | Nội dung | Nguồn |
|---|---|---|
| `rhtdk_target` | Chỉ tiêu doanh số **tổng** theo tháng: `nam, thang, ngay_dau_thang, chi_tieu_doanh_so` | HH: `ggs_target_company` brand_id = 4, active, sum theo tháng (2024–2025 có thêm dòng company 32 target = 0, không lệch). THV: `rtr_target_latest` chỉ `chi_tieu = 'ds'` |
| `rhtdk_target_sm` | Mục tiêu **chỉ số marketing** THV theo tháng (`nguon_du_lieu = 'Target'`, `loai_chi_tieu` = mã chỉ số, `ten_chi_tieu` = tên, `model_nguon = 'target_sm'`): chi phí ads, inbox, SĐT thô/verify, booking tạo, lịch hẹn, đến cửa, thành công, DS MKT không thuốc, tỷ lệ, CPI/CPL/CPB/CPO/CAC, ROI. Tỷ lệ/đơn giá không cộng được | Bảng DB `ggs_target_sm_thv` nếu đã đồng bộ, chưa có thì seed `seed_ggs_target_sm_thv` (chép từ sheet) |
| `rhtdk_target_md_ml` | Mục tiêu doanh số **MD / ML** theo tháng (`loai_chi_tieu` `md` / `ml`) | HH: seed `seed_hh_target_md_ml` (người dùng cung cấp; md = Nguồn MD, ml = Nguồn Offline, 2026). THV: `rtr_target_latest` chi_tieu `md` / `ml` (T7–T12/2026) |
| `rhtdk_chi_phi_ads` | Chi phí ads **theo ngày** + `inbox_moi` (cột `inbox` của bảng DB) + `muc_tieu_tuan`, `muc_tieu_thang` (1 dòng = 1 ngày × 1 brand) | `public.ggs_target_ads_thv_hh` |

HH **chưa có chỉ tiêu theo nguồn** (`ggs_target_company_source` brand 4 chỉ 2
dòng active T1, T3/2026) → chỉ lấy chỉ tiêu tổng cho cả 2 brand.

**Nguồn ads:** `public.ggs_target_ads_thv_hh` (source `rhh_base`), đồng bộ từ
Google Sheet "Báo cáo Kinh doanh tự chủ 2025", tab `ggs_target_ads_thv_hh`.
Cột `date` là **text `dd/mm/yyyy`** → dùng `to_date(date, 'DD/MM/YYYY')`, không
ép `::date`.

### Lead / booking CRM

`rhtdk_lead_base` (ephemeral): `crm_lead` brand_etl 4, 8, `type_crm_id` 1, 2,
**`active = true`**; các mốc thời gian **+7h** (giờ VN).
- `source_id` → `source_name` (nguồn cũ): `utm_source` cùng brand.
- `new_source_id`: `crm_lead.new_source_id`, không có thì đổi từ `source_id`
  qua `m_utm_source_old_new_map` (old_source_id unique theo brand → không nhân
  dòng); `new_source_name` từ `utm_source` cùng brand. HH mới map được 38 nguồn
  cũ → nguồn mới HH còn thiếu nhiều (K - Cho thuê phòng mổ, K - CTV nội bộ…).

| Model | `type_crm_id` | Ngày (`ngay`) theo |
|---|---|---|
| `rhtdk_sdt` | 1, chỉ `stage_id` 7 Tham khảo / 8 Tiềm năng / 18 Đặt lịch | `create_date` + 7h |
| `rhtdk_sdt_tho` | 1, **mọi trạng thái**, chỉ nguồn MD (`nguon_du_lieu = 'SĐT thô'`) | `create_date` + 7h |
| `rhtdk_booking_create` | 2 | `create_date` + 7h |
| `rhtdk_booking` | 2 | `booking_date` + 7h (có lịch hẹn tương lai, giữ nguyên) |
| `rhtdk_booking_dc` | 2 | `arrival_date` + 7h |

Cả 4 bảng `rhtdk_sdt`, `rhtdk_booking_create`, `rhtdk_booking`, `rhtdk_booking_dc`
**chỉ giữ nguồn MD** (Vãng lai tính MD trước T10/2026).

Cột: `brand_etl, ten_thuong_hieu, ngay, <thời điểm +7h>, booking (crm_lead.name),
contact_name, phone, code_customer, source_id, source_name, new_source_id, new_source_name,
nhom_md_ml_baocao`. Bỏ dòng không có ngày tương ứng.

**`nhom_md_ml_baocao` của lead/booking** — gom theo **tên nguồn cũ ERP**
(`source_name`, phủ ~99%), cùng bộ nhóm với doanh số:

| # | `source_name` | Nhóm |
|---|---|---|
| 1 | chứa `Cho thuê phòng mổ` | TPM |
| 2 | chứa `CBNV` hoặc `Đối ngoại` | CBNV |
| 3 | chứa `Vãng lai` | MD, **từ T10/2026 → ML** (theo ngày của từng bảng) |
| 4 | bắt đầu `MO - ` | MO |
| 5 | bắt đầu `MD - ` hoặc `DG - MD - ` | MD |
| 6 | NULL / `Không có nguồn cũ` | NULL |
| 7 | còn lại (ML -, CTV, KH giới thiệu, loyalty, Dr.Giang…) | ML |

⚠ Doanh số gom theo nguồn **EHC**, lead/booking gom theo nguồn **ERP** → cùng
1 khách có thể khác nhóm giữa 2 bên nếu EHC và ERP ghi nguồn khác nhau.

---

## Tầng STAG: `rhtdk_combine`

`union all` 3 khối, cùng bộ cột, **chỉ giữ `invoicedate >= 2026-01-01`**:

| Cột | Doanh số | Target / Chi phí ads | Lead / booking |
|---|---|---|---|
| `brand_etl`, `ten_thuong_hieu` | ✓ | ✓ | ✓ |
| `model_nguon` | `hh` / `thv_ds` | `target` / `chi_phi_ads` | `sdt` / `booking_create` / `booking` / `booking_dc` |
| `nguon_du_lieu` | `Dịch vụ` / `Nhà thuốc` | `Target` / `Chi phí ads` | `SĐT` / `Booking tạo` / `Booking` / `Booking ĐC` |
| `loai_chi_tieu` | NULL | `ds` / `ads` / `ads_tuan` (Target) | NULL |
| `invoicedate` | ngày phiếu | ngày đầu tháng (`ds`, `ads`), ngày đầu tuần (`ads_tuan`), ngày chi (Chi phí ads) | `ngay` của bảng |
| `sophieu` | số phiếu | NULL | mã booking/lead |
| `sotienphieu` | số tiền (hoàn tiền/hoàn ứng đã âm) | chỉ tiêu / chi phí | NULL (đếm `count(*)`) |
| `makh` | `patientcode` (mã khách EHC) | NULL | `code_customer` (mã khách ERP, `CUS...`) |
| `tenkh` | `patientname` | NULL | `contact_name` |
| `sdt` | `patientphone` | NULL | `phone` |
| `phan_loai_coc` | `pl` (chỉ HH: Cọc trong tháng / DT trừ cọc) | NULL | NULL |
| `nguon_ehc`, `nhom_nguon_ehc` | người giới thiệu / nhóm hoa hồng EHC | NULL | NULL |
| `nguon_erp_cu`, `nguon_erp` | nguồn cũ / mới ERP (theo `id_booking`) | NULL | nguồn cũ / mới ERP |
| `nhom_md_ml_baocao` | HH: MD/ML/TPM/MO/CBNV · THV: MD/ML/CBNV | NULL | MD/ML/TPM/MO/CBNV |
| `amount_paid` | NULL | NULL | **chỉ dòng Booking ĐC**: `crm_lead.amount_paid` (tiền khách đã trả; > 0 = khách thành công, có thể âm do hoàn) |
| `nhom_nguon_ty_trong` | **chỉ THV** (HH NULL): Nhà thuốc tách riêng `'Nhà thuốc'`; Dịch vụ gom MD / MGM / CTV / KH cũ / Khác từ `nhom_nguon_ehc` | NULL | NULL |
| `co_line` | NULL | NULL | **chỉ dòng SĐT** (booking NULL): lead có dịch vụ — HH: có nhóm dịch vụ ở `crm_lead_product_category_rel` (`lead_id`); THV: có dòng `crm_line` (`crm_id`); cùng `brand_etl`. Chỉ đánh dấu, không lọc |
| `rnk_sdt` | NULL | NULL | **chỉ dòng SĐT thô / SĐT**: thứ tự lần tạo lead của SĐT (1 = lần tạo đầu tiên; toàn lịch sử CRM từng brand, mọi nguồn/trạng thái). Chỉ đánh dấu — lọc `rnk_sdt = 1` ở báo cáo nếu chỉ tính lần đầu |
| `dc_tc_noi_soi` | NULL | NULL | **chỉ dòng Booking ĐC của THV**: đến cửa thành công (`amount_paid > 0`) có dịch vụ nội soi (EHC THV `servicename` chứa "nội soi"/"gói tầm soát", `soluong > 0`, bỏ nhóm thuốc/vật tư, nối qua `ehc_tb_patientrecord_thv.id_booking`); THV không thỏa = false, HH = NULL |

Target cũ (dòng Target của `rhtdk_hh` + toàn bộ `rhtdk_thv_target`) đã bỏ —
chỉ giữ chỉ tiêu tổng từ `rhtdk_target`, tránh cộng đôi.

## Tầng MART

`report_hh_thv_ds_kh`: `select * from rhtdk_combine`.

---

## Cách dùng đúng

1. **Luôn lọc theo `nguon_du_lieu`** và group theo `brand_etl` — không cộng lẫn các loại dòng.
2. **Doanh số**: `sum(sotienphieu)` với `nguon_du_lieu in ('Dịch vụ', 'Nhà thuốc')`.
   HH gồm cả cọc (`phan_loai_coc = 'Cọc trong tháng'`), không trùng doanh thu.
3. **Chỉ tiêu doanh số**: `loai_chi_tieu = 'ds'`; so theo tháng
   (`date_trunc('month', invoicedate)`), không theo ngày.
4. **Chi phí ads**: `nguon_du_lieu = 'Chi phí ads'` (theo ngày, cộng được).
   **Mục tiêu ads**: `loai_chi_tieu = 'ads'` (tháng) **hoặc** `'ads_tuan'` (tuần)
   — 2 cách chia cùng 1 ngân sách, không cộng chung. Tuần theo cột `tuan` của
   sheet (HH có thể có Tuần 5, THV không).
5. **SĐT / booking**: `count(*)` theo `nguon_du_lieu` tương ứng
   (`SĐT`, `Booking tạo`, `Booking`, `Booking ĐC`).
6. **CBNV**: bảng không loại CBNV. Muốn loại: `coalesce(nhom_md_ml_baocao, '') <> 'CBNV'`.

---

## Vấn đề dữ liệu đã biết

- Nguồn mới ERP của HH mới map 38 nguồn cũ trong `utm_source_old_source_rel`
  → `nguon_erp` HH phủ thấp; cần bổ sung phía ERP.
- Mục tiêu ads THV T9/2026: tổng các tuần 433tr ≠ mục tiêu tháng 546tr (HH khớp 391,6tr) — cần kiểm tra sheet.
- Nhà thuốc HH: ~29.6k dòng thiếu `makh` (dùng chung 1 `patientrecordid` khách lẻ) — giữ nguyên.
- `booking_date` THV có ngày tới 2027-09 (có thể nhập nhầm năm) — giữ nguyên.
