# Logic: func_report_marketing_ad_cost_pr

Báo cáo marketing tổng hợp chi phí quảng cáo, lead, doanh số cho thương hiệu Paris.
Output: `mart_report_marketing_ad_cost_pr`.

---

## Lưu ý — Tiềm năng lệch số liệu với `func_bc_sales_paris`

Model này dùng `stg_frmacpr_leads_lines` (join trực tiếp `crm_lead` + `crm_line`) làm nguồn
CRM, trong khi `func_bc_sales_paris` dùng `view_stag_tongquan_khachhang_sm_pr`.
Hai nguồn có **4 điều kiện khác nhau** khiến DC/BK/Lead có thể lệch:

| # | Điều kiện | stg_frmacpr_leads_lines | View (bc_sales_paris) | Tác động |
|---|-----------|-------------------------|-----------------------|----------|
| 1 | `create_by_department` | **IS NOT NULL** bắt buộc | **không lọc** (NULL được phép) | stg_frmacpr ít lead hơn — bỏ qua lead tự tạo/import không có phòng ban |
| 2 | `active` | **không lọc** | **`= true`** | stg_frmacpr có thêm lead đã archive/cancel |
| 3 | Date filter | **không có** | **`create_date + 7h >= 2022-01-01`** | stg_frmacpr có thêm lead cũ hơn 2022 |
| 4 | Lead không có line | **giữ lại** (LEFT JOIN) | **bị loại** (`product_category IS NOT NULL`) | stg_frmacpr có thêm lead chưa có dịch vụ |

**Nếu cần đồng nhất:** chọn một chuẩn rồi áp điều kiện tương ứng vào model còn lại.
Xem chi tiết tại LOGIC.md của `func_bc_sales_paris`.

---

## Sự cố — source `view_ggs_paris_sm_target_daily` bị mất (2026-08-07)

`stg_frmacpr_targets` (PASS 7 & 8 — Mục tiêu Lead/Chi phí) đọc từ
`source('paris', 'view_ggs_paris_sm_target_daily')`. View này **không do dbt
quản lý** — được sync từ Google Sheet "SM Target Daily" bởi job bên ngoài repo.
Ngày 2026-08-07 phát hiện view không còn tồn tại trong DB `new_product`
(10.10.10.214) → lỗi `relation does not exist` làm sập toàn bộ
`mart_report_marketing_ad_cost_pr` (model `table` duy nhất trong pipeline,
union tất cả nguồn `ephemeral` trong 1 câu query — 1 nguồn lỗi là cả report
không được refresh).

**Fix tạm/graceful degradation đã áp dụng** trong `stg_frmacpr_targets.sql`:
dùng `adapter.get_relation()` kiểm tra view có tồn tại không trước khi query.
Nếu KHÔNG tồn tại → trả về tập rỗng (đúng cấu trúc cột) thay vì lỗi, kèm
cảnh báo `log(..., info=True)` in ra mỗi lần `dbt run`. Kết quả: report vẫn
build được bình thường, nhưng **không có dòng `type_data = target_lead` /
`target_cost`** nào cho đến khi view được khôi phục lại trong DB.

Pattern này **chỉ áp dụng cho model này**, chưa áp dụng cho các source
`view_ggs_*` khác trong `sources.yml` (ví dụ `ggs_google_campaign_ads_list`).

---

## Nguồn dữ liệu chính (`stg_frmacpr_leads_lines`)

```
crm_lead  (brand_etl=3, create_by_department IS NOT NULL)
  └── LEFT JOIN crm_line (brand_etl=3)
```

- Không lọc `active` → bao gồm cả lead đã archive
- Không giới hạn ngày tạo
- Lead không có line: giữ lại với `product_id = NULL`

---

## Cấu trúc model

```
stg/
  stg_frmacpr_leads_lines     ← crm_lead + crm_line (nguồn CRM chính)
  stg_frmacpr_fb_insight_v*   ← Facebook Ads (anti-join v1/v2 → v3)
  stg_frmacpr_google          ← Google Ads
  stg_frmacpr_inbox           ← Inbox Facebook
  stg_frmacpr_doanh_so        ← Doanh số (stag_payment_transfer)
  stg_frmacpr_deal_cs         ← Caresoft deal
  stg_frmacpr_targets         ← KPI targets
int/
  int_frmacpr_erp_conv        ← Xử lý trung gian
  int_frmacpr_union           ← UNION ALL các stream
mart/
  mart_report_marketing_ad_cost_pr  ← Output cuối
```
