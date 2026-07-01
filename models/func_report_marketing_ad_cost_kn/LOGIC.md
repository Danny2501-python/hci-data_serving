# Logic: func_report_marketing_ad_cost_kn

Báo cáo marketing tổng hợp chi phí quảng cáo, lead, doanh số cho thương hiệu Kangnam.
Output: bảng `report_marketing_ad_cost_kn_v2`.

---

## Kiến trúc tổng thể

```
Sources (raw)
  └── stg/   ← làm sạch, parse campaign name, chuẩn hóa địa danh
       └── int/   ← gom nguồn, tính vùng địa lý
            └── mart/  ← output cuối (3 stream UNION ALL)
```

---

## Tầng STG (Staging)

### Facebook Insight — 3 bước anti-join

**`stg_frmack_fb_insight_v1`**
- Nguồn: `stg_fb_insight_old_zero` (dữ liệu legacy)
- Loại trừ 3 page_id cố định: `805410602664141`, `839493609256431`, `948044848396128`
- Thêm cột `country = null`

**`stg_frmack_fb_insight_v2`** ← materialized table `stg_fb_insight_new`
- Nguồn: `cs_facebook_insight` (brand_etl = 1, date > start_date)
- Loại trừ cùng 3 page_id
- Parse `ad_campaign_name` để lấy `cn`, `nhom_dv`, `nhom_dv2`, `actor`:

  | Điều kiện | cn | nhom_dv / nhom_dv2 | actor |
  |-----------|----|--------------------|-------|
  | segments ≥ 9 VÀ segment 1 NOT ILIKE 'MIEN%' (naming mới) | segment 3 | segment 5 | segment 8 |
  | Còn lại (naming cũ) | segment 1 | segment 2 / segment 3 | NULL |

- `chi_nhanh_no_camp`: LATERAL JOIN `location_kangnam_adnet` lấy bản ghi hợp lệ gần nhất theo `ngay_hh ≤ date`
- `type_data`: `Cost_fb_th` nếu account = `act_651294956930454`, còn lại `Cost_fb_cd`

**`stg_frmack_fb_insight_v3`** ← materialized table `stg_fb_insight_full`
- **Anti-join**: lấy toàn bộ v1 + các record v2 KHÔNG tồn tại trong v1
- Key anti-join: `(ad_account_id, fb_ad_ad_id, ngay_chi_phi, vung)`
- v1 → `source = 'old'`, `actor = NULL` | v2 → `source = 'new'`, `actor` từ parse

---

### `stg_frmack_google` — Chi phí Google Ads
- Nguồn: `cp_google_kangnam`
- Quy đổi tiền: `cost * 23500` (USD → VND, hardcode)
- Parse campaign name (split `_` và ` - `) → `chi_nhanh`
- `nhom_dv`: code `88888` → VIỆT KIỀU | `99999` / `XLKH` → THƯƠNG HIỆU | còn lại → join `product_category`
- `type_data`: `Google_th` nếu account = "Thương hiệu - Brand", còn lại `Google_cd`
- `nguon = 'GG'`, `kenh = 'Web'`

---

### `stg_frmack_inbox` — Inbox Facebook
- Nguồn: `m_inbox_kangnam`
- LATERAL JOIN `location_kangnam_adnet` → `chi_nhanh` theo ngày hiệu lực
- Parse campaign name → `page_code`, `cn`, `nhom_dv_qc` (cùng logic naming mới/cũ như v2)
- Map `nhom_dv` via `campaign_name_split`, `page_name/page_id` via `ucbt_page_config`
- Metric = `người liên hệ qua nhắn tin mới`
- `type_data = 'inbox'`, `nguon = 'IB'`, `kenh = 'FB'`

---

### `stg_frmack_crm_base` — Dữ liệu CRM (dùng chung cho 5 type)
- Nguồn: `stg_common_tongquan_khachhang` JOIN `crm_lead` (brand_etl=1, create_by_department IS NOT NULL)
- JOIN `res_country_state`, `res_country` → `local_k`, `quoc_gia`
- `local_k`: TP.HCM → 'SÀI GÒN' | TP.HN → 'Hà Nội' | NULL → 'KXĐ' | code không chứa 'VN-' → 'VIỆT KIỀU'
- `chi_nhanh_new`: remap tên cũ:
  - BẠCH MAI → BỆNH VIỆN KANGNAM HÀ NỘI
  - NGUYỄN TRÃI → BỆNH VIỆN KANGNAM SÀI GÒN
- `vk`: `marketing` → VIỆT KIỀU | `mkt_oversea` → QUỐC TẾ | `expat` → `exp`

---

### `stg_frmack_doanh_so` — Doanh số
- Nguồn: `stag_payment_transfer` + join `crm_lead`, `res_country_state`, `res_country`, `view_stag_products`, `stag_sources`, `m_res_company`
- `type_data = 'DS'`, metric = số tiền thanh toán
- Cùng logic remap `chi_nhanh` và `local_k` như CRM base

---

### Caresoft (2 model phụ trợ)
- **`stg_frmack_cs_services`**: parse JSON `detail` → lấy `page_id` + `created_at` từ `cs_services_api` (brand_id=1, service_type='Inbox Facebook')
- **`stg_frmack_cs_tickets`**: lấy `service_id` đầu tiên per `ticket_id` (ROW_NUMBER ORDER BY ticket_id) từ `cs_ticket_api` (brand_id=1, ticket_source IN ('Inbox Facebook','Inbox Facebook Out'), updated_at ≥ 2025-01-01)

---

## Tầng INT (Intermediate)

### `int_frmack_fb_cost` — Chi phí Facebook
- Nguồn: `stg_frmack_fb_insight_v3`
- Phân loại `vk` từ `cn`: `Hai Ngoai` / `vki` → VIỆT KIỀU | `QUOC TE` / `qte` → QUỐC TẾ | `exp/expat` → exp
- Map `nhom_dv_sys`: LATERAL JOIN `campaign_name_split` theo `nhom_dv`, fallback sang `nhom_dv2`
- Chuẩn hóa `chi_nhanh` từ raw về tên đầy đủ (HCM → BỆNH VIỆN KANGNAM SÀI GÒN, v.v.)
- `local_k` từ `vung`: Ho Chi Minh City → SÀI GÒN | Hanoi → Hà Nội | v.v. | VK/QT → dùng `continent_vn`
- `quoc_gia`: VK/QT → `country_name_vn` (từ `fb_country_code_mapping`), còn lại → 'Việt Nam'
- Pass-through: `actor`
- `nguon = 'CP'`, `kenh = 'FB'`

---

### `int_frmack_union` — UNION ALL 8 luồng

| # | type_data | Nguồn | Filter chính |
|---|-----------|--------|--------------|
| 1 | DC | crm_base | loai_ban_ghi=2, ngay_den_cua ≥ start_date, nhom_dv≠'SAN PHAM', không phải booking bảo hành |
| 2 | DS | stg_doanh_so | — |
| 3 | Lead | crm_base | loai_ban_ghi=1, ngay_tao ≥ start_date, nhom_dv≠'SAN PHAM' |
| 4 | inbox | stg_inbox | — |
| 5 | TC | crm_base | loai_ban_ghi=2, tong_tien > 0, ngay_den_cua ≥ start_date, nhom_dv≠'SAN PHAM' |
| 6 | Google_cd / Google_th | stg_google | — |
| 7 | BKHL | crm_base | loai_ban_ghi=2, ngay_tao ≥ start_date, nhom_dv≠'SAN PHAM' |
| 8 | HL | crm_base | loai_ban_ghi=2, ngay_hl ≥ start_date, nhom_dv≠'SAN PHAM' |

> `start_date` mặc định `2025-08-01`, override qua dbt var.
> `reason_cancel_booking ≠ 'tao_booking_bh'` áp dụng cho DC, TC, BKHL.

---

### `int_frmack_region` — Chuẩn hóa vùng địa lý
- Nguồn: `int_frmack_union`
- Chuẩn hóa `tinh_noi` từ `local_k`: bỏ tiền tố "Thành phố " / "Tỉnh ", chuẩn hóa "Bà Rịa%"
- Lookup `region` từ `ggs_region_map` theo `tinh_noi`, với override cứng:
  - Bà Rịa - Vũng Tàu → Hồ Chí Minh và lân cận
  - Lào Cai, Yên Bái → Miền Bắc mở rộng
  - Huế → Đà nẵng lân cận
  - KXĐ → KXĐ

---

## Tầng MART — Output cuối

**`mart_report_marketing_ad_cost_kn`** → alias `report_marketing_ad_cost_kn_v2`

3 stream UNION ALL:

### Stream 1 — Chi phí Facebook (FB cost)
- Nguồn: `int_frmack_fb_cost`
- Tính `tinh_noi` inline qua LATERAL (cùng công thức re_map)
- Lookup `region` từ `ggs_region_map`
- Map `page` (tên page) từ `stg_frmack_cs_services` theo `page_id`, dedup bởi `created_at DESC`
- Join `ucbt_country_continent` → `chau_luc`
- Có cột `actor` (từ parse campaign name)

### Stream 2 — Non-FB, ticket_id ≠ 0
- Nguồn: `int_frmack_region`
- Map page: `ticket_id` → `service_id` (cs_tickets, rnk=1) → `page_name` + `page_id` (cs_services)
- `region`: dùng `continent` từ `ucbt_country_continent` nếu có, fallback về `region` từ int
- `actor = NULL`, `account_fb = NULL`

### Stream 3 — Non-FB, ticket_id = 0 hoặc NULL
- Nguồn: `int_frmack_region`
- `page` = `page_name` (từ inbox) hoặc `'KXĐ'`
- `page_id` = `page_id_from_camp` (từ inbox) hoặc `'KXĐ'`
- `actor = NULL`, `account_fb = NULL`

---

## Cột output

| Cột | Mô tả |
|-----|-------|
| vk | Phân loại Việt kiều / Quốc tế / no / exp |
| ten_dv | Tên dịch vụ |
| Nguon | Nguồn (Facebook, Google, v.v.) |
| Nhom_nguon | Nhóm nguồn |
| kenh | Kênh: FB / Web / Khác |
| date | Ngày phát sinh record |
| nhom_dv | Nhóm dịch vụ |
| chi_nhanh | Tên chi nhánh chuẩn hóa đầy đủ |
| local_k | Địa điểm thô (tỉnh/thành) |
| quoc_gia | Quốc gia |
| chau_luc | Châu lục |
| Metric | Giá trị: chi phí / doanh số / SĐT lead |
| type_data | Loại record: DC / DS / Lead / inbox / TC / Google_cd / Google_th / BKHL / HL / Cost_fb_cd / Cost_fb_th |
| page | Tên Facebook Page |
| page_id | Facebook Page ID |
| region | Vùng kinh doanh |
| tinh_noi | Tỉnh/thành chuẩn hóa (bỏ tiền tố) |
| campaign | Tên chiến dịch |
| account_fb | Tên tài khoản quảng cáo FB (chỉ Stream 1) |
| actor | Người thực hiện (segment 8 tên campaign FB, naming mới) |

---

## Biến dbt

| Var | Default | Tác dụng |
|-----|---------|----------|
| `start_date` | `2025-08-01` | Ngưỡng lọc ngày cho toàn bộ pipeline |
