# Logic: report_hh_revenue

Doanh số Bệnh viện **Hồng Hà** (brand_etl = 4) — dữ liệu chính lấy từ HIS/EHC
(`ehc_tb_*`), một số khoản bổ sung lấy từ ERP (`stag_payment_transfer`).
Tag dbt: `report_hh_revenue` (`int`/`stag` = ephemeral, `mart` = table).

Output vật lý duy nhất: bảng **`rhh_ehc_payment_service`** (mart). Mọi model
`stag/rhh_doanh_so_*` là ephemeral — xem mục [Lưu ý vận hành](#lưu-ý-vận-hành).

Chi tiết từng điều kiện lọc + số đã verify nằm ở comment đầu mỗi file `.sql`;
tài liệu này là bản đồ tổng thể.

---

## Kiến trúc

```
Sources (rhh_base, schema public)
  ├── ehc_tb_invoice / ehc_tb_invoicerequest / ehc_tb_patientrecord / ehc_tb_nguoigioithieu ...
  │     └── int/rhh_ehc_payment_service_base   ← doanh thu viện phí (ds + cọc)
  │            ├── stag/rhh_doanh_so_tpm / pttm / lgbt / san_khoa / ung_buou / phong_khac / ksk ...
  │            └── mart/rhh_ehc_payment_service  ← + nhà thuốc + target + nguồn ERP + tên phòng
  ├── ehc_tb_invoicemedicine / ehc_tb_medicinebill
  │     └── stag/rhh_doanh_so_nha_thuoc ──────────┘ (union vào mart)
  ├── ehc_tb_phieuthuchi / tondauky / hoahongbacsiinvoice / ...
  │     └── int/rhh_thuchi                     ← sổ thu chi
  │            └── stag/rhh_doanh_so_thu_khac / ksk / chuyen_khoa_khac
  ├── stag_payment_transfer + view_stag_products + crm_lead + stag_sources   (ERP)
  │     └── stag/rhh_doanh_so_lgbt_erp_hh / _vpth / pttm_erp
  └── ggs_target_company (brand_id = 4)        ← target, union vào mart
```

---

## Tầng INT

### `rhh_ehc_payment_service_base` — doanh thu viện phí
Model nền cho mọi model doanh số EHC phía sau. `union all` 2 nhánh:

| Nhánh | Nguồn | Ngày | `pl` | Ghi chú |
|---|---|---|---|---|
| `ds` | `ehc_tb_invoice` | `invoicedate` | `'DT trừ cọc trong tháng'` | `huyphieu_status = 0`, **loại** `invoiceid` đã có trong `ehc_tb_invoicerequest` (tránh đếm trùng với cọc) |
| `dc` | `ehc_tb_invoicerequest` | `ngayyeucau` | `'Cọc trong tháng'` | `roomid` cố định = 0 (bảng không có cột phòng) |

- **Dấu tiền**: `dm_invoice_typeid` 2 (Hoàn tiền) / 4 (Hoàn ứng) → `-sotienphieu`.
  Mọi model con cộng thẳng `sotienphieu` là ra doanh thu ròng, **không đảo dấu lại**.
- `loaiphieu`: 1 Phiếu thu · 2 Hoàn tiền · 3 Tạm ứng · 4 Hoàn ứng · 5 Miễn giảm · 6 Thu 0đ · 7 Chi BHYT.
- Người giới thiệu: `patientrecord.nguoigioithieuid → ehc_tb_nguoigioithieu`
  (`source_ehc` = TÊN người giới thiệu) → nhóm hoa hồng
  `dm_hoahongnguoigioithieu_nguoigioithieuname`, join theo
  **`..._nguoigioithieuid`, KHÔNG phải `dbid`** (join `dbid` ra nhóm sai).
- Hai cột phòng:
  - `roomid` — phòng của **từng phiếu** (`ehc_tb_invoice`).
  - `roomid_kb` — phòng của **hồ sơ bệnh nhân** (`ehc_tb_patientrecord`).
  - Xác định khách thuộc phòng nào **luôn phải check cả hai** (`roomid = X or roomid_kb = X`).
- `patientcode` = mã khách ổn định qua nhiều `patientrecordid`/booking → dùng để
  nhận diện 1 khách thật.

### `rhh_thuchi` — sổ thu chi
Port nguyên view HIS `public.view_thuchi1` (đổi `tb_X → ehc_tb_X`, verify trùng md5 từng dòng).
7 nhánh `union all`: tồn đầu kỳ (bị loại ở select cuối) · phiếu thu/chi tay ·
invoice · invoicemedicine · chi hoa hồng bác sĩ · chi người giới thiệu · chi PTTT.
`heso` 1/-1 tách thành `sotien_thu` / `sotien_chi` (cột `sotien` luôn = 0).
Bỏ filter `{DATE_FROM}/{DATE_TO}` của HIS → giữ toàn lịch sử, phía dùng tự lọc `ngay`.

---

## Tầng STAG — các "rổ" doanh số

### Nhóm EHC theo phòng / nhóm nguồn (từ `rhh_ehc_payment_service_base`)

| Model | Rổ | Cách nhận diện | Kiểu lọc |
|---|---|---|---|
| `rhh_doanh_so_tpm` | Thuê phòng mổ | nhóm NGT = `'[TPM]Thuê phòng mổ'` | từng dòng |
| `rhh_doanh_so_pttm` | PTTM (room 94) | khách có ≥1 phiếu `roomid/roomid_kb = 94` **trong tháng** | **gom theo patientcode + tháng**: lấy toàn bộ DT tháng đó của khách |
| `rhh_doanh_so_lgbt` | LGBT (room 276) | như PTTM, room 276 | gom theo patientcode + tháng |
| `rhh_doanh_so_san_khoa` | Sản (room 142) | `roomid/roomid_kb = 142`; `source_ehc` không NULL/rỗng, không chứa `cbnv`; **loại khách IVF** (từng có `servicecode = 'SA_TIENIVF01'` trong `ehc_tb_servicedata`, lọc theo patientcode) | từng dòng |
| `rhh_doanh_so_ung_buou` | Ung bướu (room 92) | `roomid/roomid_kb = 92`; `source_ehc` không chứa `cbnv`; nhóm NGT không NULL/rỗng, không chứa `thuê phòng mổ` | từng dòng |
| `rhh_doanh_so_phong_khac` | Phòng còn lại | loại nhóm `thuê phòng mổ` và loại room 92/276/94/142 (cả `roomid` lẫn `roomid_kb`) | từng dòng |

Hai kiểu lọc khác nhau là **có chủ đích** (đã đối chiếu với danh sách thực tế
của người dùng): PTTM/LGBT gom theo khách, Sản/Ung bướu lọc thẳng từng dòng.

> ⚠️ `rhh_doanh_so_phong_khac` loại nguyên room 142/92 nhưng 2 model chuyên khoa
> lại có lọc CBNV riêng → phần CBNV của phòng Sản/Ung bướu **không nằm ở rổ nào**.
> Tổng các rổ < doanh số thật (chủ đích theo yêu cầu người dùng).

### Nhóm sổ thu chi (từ `rhh_thuchi`)

| Model | Điều kiện |
|---|---|
| `rhh_doanh_so_thu_khac` | `noidung = 'Thu tiền khác (Ghi nhận DS)'` (so **chính xác** — tránh nhầm `'Thu tiền khác (0 ghi nhận DS)'`), `ghichu` không chứa `bao hiem` / `KSK`. Lấy `sotien_thu`. |
| `rhh_doanh_so_ksk` | 2 phần: (1) `'KSK'` — `rhh_thuchi.noidung ilike '%ksk%'`, lấy `sotien_thu`; (2) `'NGT chưa gán nhóm'` — dòng viện phí có nhóm NGT NULL. |
| `rhh_doanh_so_chuyen_khoa_khac` | 4 phần: `'San khoa'` (toàn bộ `rhh_doanh_so_san_khoa`) · `'Phong khac'` (`rhh_doanh_so_phong_khac` + lọc `source_ehc` không NULL/rỗng/cbnv) · `'Thu khac BHXH'` (`Thu tiền khác (Ghi nhận DS)` + `ghichu ilike '%bao hiem%'` — phần bù của `thu_khac`) · `'KSK khong nguon'` (viện phí `invoiceremark ilike '%ksk%'` + nhóm NGT NULL). |

`ghichu` trong dữ liệu viết **không dấu** (`BAO HIEM XA HOI ...`) nên `ilike '%bao hiem%'` là đủ.

> ⚠️ Chồng lấn: phần 2 của `rhh_doanh_so_ksk` (mọi dòng nhóm NGT NULL) **chứa**
> phần 4 của `rhh_doanh_so_chuyen_khoa_khac` (nhóm NGT NULL + remark có `ksk`).
> Không cộng 2 model này với nhau khi chưa trừ phần giao.

### Nhà thuốc — `rhh_doanh_so_nha_thuoc`
Port báo cáo HIS "Thu tiền nhà thuốc theo thời gian thu tiền": `ehc_tb_invoicemedicine`
(`huyphieu_status = 0`), left join medicinebill / patientrecord / người giới thiệu
(đều 1-1). Toàn bộ phiếu là `dm_invoice_typeid = 1` → không đảo dấu. Nhà thuốc
**tách riêng** khỏi viện phí (không nằm trong `rhh_ehc_payment_service_base`).

### Nhóm ERP (`stag_payment_transfer`)

| Model | Pháp nhân | Lọc nhóm DV | Lọc nguồn |
|---|---|---|---|
| `rhh_doanh_so_lgbt_erp_hh` | brand 4 (mọi company) | `product_category ilike '%lgbt%'` (lọc xuôi) | loại `cbnv` |
| `rhh_doanh_so_lgbt_erp_vpth` | brand 1, company 54 (VP Thương hiệu Kangnam) | `product_category <> 'PTTM HÀM MẶT'` (lọc ngược — pháp nhân chỉ chạy LGBT + hàm mặt) | whitelist: `%hợp tác doanh nghiệp%`, `%hợp tác%bệnh viện%`, `%ctv khách hàng%` |
| `rhh_doanh_so_lgbt_erp` | union 2 model trên | | |
| `rhh_doanh_so_pttm_erp` | cả 2 pháp nhân trên (rule nguồn tương ứng) | `product_category = 'PTTM HÀM MẶT'` + **cohort khách**: SĐT `crm_lead.phone` khớp `ehc_tb_patientrecord.patientphone` có `roomid_kb = 94` | như 2 dòng trên |

Quy tắc chung nhánh ERP:
- `view_stag_products` **bắt buộc join kèm `brand_etl`** — `product_id` không unique toàn cục.
- `spt.payment` âm là bình thường → **không đảo dấu**.
- Cột `la_coc = ma_phieu ilike 'CUST.IN%'`. Khoản cọc CUST.IN có ở **cả EHC lẫn ERP** —
  khi cộng `rhh_doanh_so_lgbt` + `rhh_doanh_so_lgbt_erp` phải bỏ cọc 1 bên
  (`la_coc = false` bên ERP, hoặc `pl <> 'Cọc trong tháng'` bên EHC).
- Dòng "Phẫu thuật thẩm mỹ" của báo cáo = `rhh_doanh_so_pttm` + `rhh_doanh_so_pttm_erp`.

---

## Tầng MART — `rhh_ehc_payment_service`

`union all` 3 khối, phân biệt bằng cột `nguon_du_lieu`:

| `nguon_du_lieu` | Nguồn | Ghi chú |
|---|---|---|
| `'Dịch vụ'` | `rhh_ehc_payment_service_base` | viện phí + cọc |
| `'Nhà thuốc'` | `rhh_doanh_so_nha_thuoc` | `roomid` NULL, `roomid_kb` lấy lại từ patientrecord, `pl = 'DT trừ cọc trong tháng'` |
| `'Target'` | `ggs_target_company` (`brand_id = 4`, `active`) | `sotienphieu` = target, `invoicedate` = tháng, `patientname` = company |

Sau union join thêm:
- **Nguồn ERP** theo `id_booking = crm_lead.name` (brand 4):
  `crm_lead` dedup `distinct on (name)` giữ bản ghi `write_date` mới nhất;
  `crm_lead.source_id` là **id cũ** → `erp_source_id_old`;
  `old_source_name` = tên trong `utm_source` brand 4 (fallback tên trong bảng map);
  `erp_source_id_new` từ `m_utm_source_old_new_map` (brand 4, `old_source_id` unique → không nhân dòng);
  `new_source_name` hiện **NULL 100%** vì danh mục nguồn mới của Hồng Hà chưa được đồng bộ sang `utm_source`.
- **Tên phòng**: `roomname` (theo `roomid`), `roomname_kb` (theo `roomid_kb`) từ `ehc_tb_room`.

Cách dùng:
- Doanh số thực tế: `nguon_du_lieu in ('Dịch vụ','Nhà thuốc')`, cộng thẳng `sotienphieu`.
- Target: `nguon_du_lieu = 'Target'`.
- Model này là nguồn Hồng Hà của `report_hh_thv_ds_kh`.

---

## Lưu ý vận hành

1. **Các model `stag/rhh_doanh_so_*` không sinh bảng.** Chúng ephemeral và không
   được model materialized nào `ref` (trừ `rhh_doanh_so_nha_thuoc` → mart, và
   `san_khoa`/`phong_khac` → `chuyen_khoa_khac`, cũng ephemeral). `dbt build
   --select tag:report_hh_revenue` sẽ bỏ qua chúng. Muốn xem số thì dùng
   `dbt show --select <model>` hoặc lấy SQL đã compile trong `target/compiled/`.
   Nếu cần đưa lên BI thì đổi `materialized` riêng cho model đó.
2. Không model nào lọc thời gian — phía dùng tự lọc `thang`/`ngay`/`invoicedate`.
