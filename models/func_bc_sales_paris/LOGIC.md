# Logic: func_bc_sales_paris

Báo cáo sales tổng hợp thương hiệu Paris (brand_id = 3).
Refactored từ PostgreSQL function `bc_sales_paris()`.
Output: bảng `bc_sales_paris_v2`.

---

## Lưu ý — Tiềm năng lệch số liệu với `func_report_marketing_ad_cost_pr`

Model này dùng `view_stag_tongquan_khachhang_sm_pr` làm nguồn CRM, trong khi
`func_report_marketing_ad_cost_pr` dùng `stg_frmacpr_leads_lines` (join trực tiếp
`crm_lead` + `crm_line`). Hai nguồn có **4 điều kiện khác nhau** khiến DC/BK có thể lệch:

| # | Điều kiện | View (bc_sales_paris) | stg_frmacpr_leads_lines | Tác động |
|---|-----------|----------------------|--------------------------|----------|
| 1 | `create_by_department` | **không lọc** (NULL được phép) | **IS NOT NULL** bắt buộc | View có thêm lead tự tạo/import không có phòng ban |
| 2 | `active` | **`= true`** | **không lọc** | stg_frmacpr có thêm lead đã archive/cancel |
| 3 | Date filter | **`create_date + 7h >= 2022-01-01`** | **không có** | stg_frmacpr có thêm lead cũ hơn 2022 |
| 4 | Lead không có line | **bị loại** (`product_category IS NOT NULL`) | **giữ lại** (LEFT JOIN) | stg_frmacpr có thêm lead chưa có dịch vụ |

**Nếu cần đồng nhất:** chọn một chuẩn rồi áp điều kiện tương ứng vào model còn lại.
Xem chi tiết tại LOGIC.md của `func_report_marketing_ad_cost_pr`.

---

## Kiến trúc tổng thể

```
Sources (raw)
  └── stg/   ← làm sạch, parse JSON custom_fields, chuẩn hóa CRM
       └── int/   ← inbox transformation, CRM union, FB cost
            └── mart/  ← UNION ALL 3 stream → output cuối
```

---

## Tầng STG (Staging)

### `stg_bsp_ranked_contacts` — Pass 1
- **Nguồn**: `cs_contact_api` (brand_id=3), `cs_ticket_api`, `cs_chat_api`
- Lấy ticket Inbox Facebook **đầu tiên** per khách (ROW_NUMBER ORDER BY created_at)
- Lấy cuộc hội thoại **đầu tiên** có `group_name` per ticket (ROW_NUMBER ORDER BY start_time ASC)
- `rank` = ROW_NUMBER PARTITION BY khach_id ORDER BY conversation_id → dùng để lọc rank=1 ở int
- Filter: `brand_id=3`, `created_at > 2022-01-01`, `facebook_page_id <> ' '`
- Output: ngay_tao_khach, khach_id, page, nv, mail_nv, ticket, page_fb, ad_id, nguon, rank, username

---

### `stg_bsp_cs_service_category` — Pass 2.1
- **Nguồn**: `cs_contact_api`
- Unnest JSON array `custom_fields`, lọc `extracted_id = 6920` (nhóm dịch vụ)
- Giá trị dạng CSV → unnest thành từng dòng qua `string_to_array(..., ',')`
- NULL → fallback `'0,0'`
- Output: id, extracted_value_not_null (1 dòng/giá trị)

---

### `stg_bsp_cs_company` — Pass 2.2
- **Nguồn**: `cs_ticket_api` (brand_id=3)
- GROUP BY ticket_id, lấy `MAX(custom_fields)` (custom_fields mới nhất)
- Unnest JSON array, lọc `extracted_id = 5981` (chi nhánh), loại giá trị `-1`
- Output: ticket_id, extracted_value (mã chi nhánh dạng `[CODE]`)

---

### `stg_bsp_crm_base` — Pass 4
- **Nguồn**: `view_stag_tongquan_khachhang_sm_pr`
- Thin wrapper — chuẩn hóa `nv = UPPER(nhan_vien)`, `ticket_id = TEXT(...)`
- Giữ toàn bộ cột cần cho 6 stream CRM: ngay_tao, ngay_hl, ngay_dc, ngay_den_cua, ngay_tt, doanh_so, v.v.

---

## Tầng INT (Intermediate)

### `int_bsp_inbox` — Pass 3
- **Nguồn**: stg_bsp_ranked_contacts (filter rank=1)
- Map **nhóm dịch vụ**: ranked_contacts → cs_service_category → cs_custom_fields_kh
- Map **chi nhánh**: ranked_contacts → cs_company → cs_custom_fields → m_res_company (brand_etl=3)
  - Tách mã từ format `[CODE]`: `REPLACE(LEFT(value_lable, POSITION(']')-1), '[', '')`
- Map **nhân viên**: join `table_team_sale_paris` theo work_email
- **phong_ban**: nếu tồn tại trong table_team_sale_paris → `'Sales & Marketing Thương hiệu Paris'`, ngược lại lấy từ `view_stag_employees_user.department`
- `bang = 'Inbox'`, `ma_booking = NULL`

---

### `int_bsp_crm_union` — Pass 5–10
UNION ALL 6 stream từ `stg_bsp_crm_base`. Filter chung: `nhom_dv NOT IN ('SAN PHAM', 'Sản Phẩm') AND nhom_dv IS NOT NULL`.

| # | bang | date | Filter thêm | Cột 4 (requester_id) | phong_ban |
|---|------|------|-------------|----------------------|-----------|
| 1 | Lead_total | ngay_tao | loai_ban_ghi=1, trang_thai IN ('Tiềm năng','Tham khảo','Đặt lịch') | sdt | phong_ban_nguoi_tao |
| 2 | BK | ngay_tao | loai_ban_ghi=2 | sdt | phong_ban_nguoi_tao |
| 3 | HL | ngay_hl | loai_ban_ghi=2 | sdt | phong_ban_nguoi_tao |
| 4 | DC | ngay_dc | loai_ban_ghi=2 | sdt | phong_ban_nguoi_tao |
| 5 | TC | ngay_den_cua | loai_ban_ghi=2, doanh_so > 0 | sdt | phong_ban_nguoi_tao |
| 6 | DS | ngay_tt | loai_ban_ghi=2 | TEXT(doanh_so) | **phong_ban_nguoi_tao1** |

> DS khác các stream còn lại: cột 4 là doanh_so (không phải sdt), dùng `phong_ban_nguoi_tao1`.

---

### `int_bsp_fb_cost` — Pass 11
- **Nguồn**: `core_facebook_ad_ad_insight` JOIN `core_facebook_ad_ad`, `core_facebook_ad_set`, `core_facebook_ad_campaign`, `core_facebook_ad_account`
- Filter: `cfaa2.id IN (7, 8, 9)` (tài khoản Paris), `date > 2022-01-01`
- Quy đổi: `spend * 23500` nếu `fb_account_currency = 'USD'`
- `nhom_dv` = segment 2 của tên ad set (split `_`)
- `chi_nhanh_raw` = segment 1, map sang tên đầy đủ:

| Viết tắt | Chi nhánh đầy đủ |
|----------|-----------------|
| HN | HÀ NỘI |
| HCM / CH / BV / NTH | HỒ CHÍ MINH |
| VK / VIET KIEU | Việt Kiều |
| BN | NHA KHOA PARIS BẮC NINH |
| HP | NHA KHOA PARIS HẢI PHÒNG |
| BMT | NHA KHOA PARIS BUÔN MÊ THUỘT |
| ĐN | NHA KHOA PARIS ĐÀ NẴNG |
| VINH | NHA KHOA PARIS VINH |
| TN | NHA KHOA PARIS THÁI NGUYÊN |
| TH | NHA KHOA PARIS THANH HÓA |
| BD | NHA KHOA PARIS BÌNH DƯƠNG |
| QN | NHA KHOA PARIS QUẢNG NINH |

- Placeholder cứng: nv=`'nhanvien'`, work_email=`'email'`, ten_khach=`'ten_khach'`, ma_booking=`'ma_booking'`, phong_ban=`'phong_ban'`
- `bang = 'Chi_phi'`, `nguon = 'Facebook'`

---

## Tầng MART — Output cuối

**`mart_bc_sales_paris`** → alias `bc_sales_paris_v2`

```
Stream 1: int_bsp_inbox        (Inbox Caresoft)
Stream 2: int_bsp_crm_union    (Lead / BK / HL / DC / TC / DS)
Stream 3: int_bsp_fb_cost      (Chi phí Facebook Ads)
```

---

## Schema cột output

| Cột | Mô tả |
|-----|-------|
| ad_id | Ad ID Facebook (Inbox) hoặc `'ad'` (CRM/Chi phí) |
| bang | Loại record: Inbox / Lead_total / BK / HL / DC / TC / DS / Chi_phi |
| ticket_id | Ticket ID Caresoft hoặc CRM |
| requester_id | Khách ID (Inbox) / SĐT (CRM) / doanh_so text (DS) / chi phí text (Chi_phi) |
| nv | Tên nhân viên (UPPER) |
| work_email | Email nhân viên |
| date | Ngày phát sinh theo loại record |
| nguon | Nguồn khách (tên source CRM hoặc 'Facebook') |
| chi_nhanh | Tên chi nhánh đầy đủ |
| nhom_dv | Nhóm dịch vụ |
| ten_khach | Tên khách hàng |
| ma_booking | Mã booking |
| phong_ban | Phòng ban nhân viên |

---

## Nguồn dữ liệu (sources.yml)

| Bảng | Dùng cho |
|------|----------|
| cs_contact_api | stg_ranked_contacts, stg_cs_service_category |
| cs_ticket_api | stg_ranked_contacts, stg_cs_company |
| cs_chat_api | stg_ranked_contacts |
| cs_custom_fields_kh | int_bsp_inbox (map nhóm dịch vụ) |
| cs_custom_fields | int_bsp_inbox (map chi nhánh) |
| m_res_company | int_bsp_inbox (tên chi nhánh) |
| table_team_sale_paris | int_bsp_inbox (phong_ban Sales) |
| view_stag_employees_user | int_bsp_inbox (phong_ban fallback) |
| m_facebook_page_kangnam | int_bsp_inbox (join phụ, chưa dùng trong SELECT) |
| view_stag_tongquan_khachhang_sm_pr | stg_bsp_crm_base |
| core_facebook_ad_ad_insight | int_bsp_fb_cost |
| core_facebook_ad_ad | int_bsp_fb_cost |
| core_facebook_ad_set | int_bsp_fb_cost |
| core_facebook_ad_campaign | int_bsp_fb_cost |
| core_facebook_ad_account | int_bsp_fb_cost (filter id IN 7,8,9) |
