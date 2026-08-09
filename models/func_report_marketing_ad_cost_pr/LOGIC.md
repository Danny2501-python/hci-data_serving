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
  stg_frmacpr_tiktok          ← TikTok Ads (tiktok_raw_ad)
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

---

## Nguồn TikTok Ads (`stg_frmacpr_tiktok`) — thêm 2026-08-09

Nguồn: bảng `tiktok_raw_ad` (`new_product`, schema `public`), đồng bộ thủ công từ
Google Sheet (`source_server = 'Google Sheet'`). Cột: `tên chiến dịch`, `id chiến
dịch`, `date created` (thực chất là ngày phát sinh chi phí theo ngày, không phải
ngày tạo campaign), `chi phí` (VND), `tiền tệ`, `snapshot_date`,
`ingestion_timestamp`, `source_server`.

**campaign_name pattern quan sát được (8 campaign, 31 dòng tính đến 2026-08-08):**
```
prd_prtk002_{}_{}_<nieng|implant|rangsu>_ib_mofub_trangnn_<variant>_<datecode>[_smart]
   1    2    3 4        5              6    7      8         9         10
```
- Vị trí 5 (`SPLIT_PART(..., '_', 5)`) → `nhom_dv_raw`.
- Vị trí 3 và 4 hiện là literal `"{}"` chưa được điền ở **toàn bộ** campaign hiện
  có (không phải lỗi vài dòng riêng lẻ) — đây thường là chỗ đặt mã chi nhánh theo
  quy ước của Google/FB, nhưng chưa dùng được ở đây.

**Các giả định đã thống nhất với người dùng (2026-08-09), cần rà soát lại khi có
campaign_name đầy đủ hơn:**

| Vấn đề | Quyết định | Ghi chú |
|---|---|---|
| `chi_nhanh` | Gán cứng `'KXĐ'` | Campaign_name chưa điền vị trí chi nhánh, bảng nguồn cũng không có cột branch/company. Khi quy ước đặt tên đầy đủ, sửa lại bằng SPLIT_PART đúng vị trí. |
| Lọc theo brand | Không lọc gì thêm | Bảng `tiktok_raw_ad` không có cột brand_etl; toàn bộ bảng được coi là dữ liệu Paris. |
| `nhom_dv` cho `nieng` | Map thành `'Niềng răng'` (gộp chung, không tách khay trong/mắc cài) | Người dùng xác nhận vị trí 5 dùng chung "nieng" cho cả 2 loại niềng, không phân biệt được từ campaign_name hiện tại — khác với logic Google/FB (có tách theo NRKT). `implant`→`Implant`, `rangsu`→`Răng sứ`, giá trị khác → `UPPER(raw)` (theo pattern mặc định của Google/FB). |
| `type_data` | `'tiktok'` (lowercase, giống `'google'`) | — |
| Dedup theo `snapshot_date` | Không xử lý — đọc thẳng cả bảng | Toàn bộ 31 dòng hiện tại chỉ có 1 `snapshot_date` duy nhất (2026-08-08), gợi ý job ingest có thể là truncate-and-load. **Nếu sau này ingestion chuyển sang append nhiều snapshot_date cho cùng (campaign, ngày)**, cần thêm logic lấy snapshot mới nhất để tránh cộng dồn trùng chi phí. |

Đưa vào `int_frmacpr_union` cùng nhánh với Google Ads (union theo `channel AS kenh`).

---

## Bug fix — `nhom_dv` bị gán nhầm thành mã tài khoản (`PRFB001`) trong `stg_frmacpr_fb_insight_v2` — sửa 2026-08-09

**Phát hiện khi nào:** trong lúc tìm hiểu lý do tồn tại `nhom_dv = 'PRFB001'` trong output (phát sinh cùng đợt research thêm nguồn TikTok ở trên).

**Nguyên nhân:** Tập đoàn đã thống nhất chung 1 quy ước đặt tên campaign quảng cáo 9+
token (giống hệt pattern của `stg_frmacpr_tiktok`/model `func_report_marketing_ad_cost_kn`):

```
prd_prfb001_dng_prdn_implant_view_mofua_dainq_doctorcase
 1     2     3    4     5      6     7      8       9
```

`nhom_dv` thật nằm ở **vị trí 5**, còn vị trí 2 là mã tài khoản/sản phẩm (`prfb001`,
tương đương `prtk002` bên TikTok). Nhưng `stg_frmacpr_fb_insight_v2.sql` (nguồn
`cs_facebook_insight`) vẫn đang parse `nhom_dv_p2 = SPLIT_PART(ad_campaign_name, '_', 2)`
theo convention **cũ** (nơi vị trí 2 chính là nhóm dịch vụ) — với các campaign đã đổi
tên sang convention mới, vị trí 2 chỉ còn là mã tài khoản, không khớp bất kỳ nhánh
`CASE` nào → rơi vào `ELSE UPPER(nhom_dv_p2)` → ra `'PRFB001'`.

**Quy mô trước khi sửa (đo trên DB thật, 2026-08-09):** 6.840 dòng trong
`stg_fb_insight_new_pr`, từ **2026-07-22 đến 2026-08-08** (đang phát sinh, không phải
dữ liệu cũ), tổng chi phí **~370.411.085 VND** bị gán sai thành `'PRFB001'` thay vì
`Niềng răng mắc cài` (`NIENG`, vị trí 5) / `Implant` (`IMPLANT`) / fallback `KHAC`.
Từ 30 campaign_name, 2 tài khoản: `act_1741025749489548`, `act_6217684194909373`.

**Model KN (`func_report_marketing_ad_cost_kn/stg/stg_frmack_fb_insight_v2.sql`) đã xử
lý đúng vấn đề này từ trước** bằng cách branch theo whitelist token 1
(`var('all_brand_mkt_camp')` trong `dbt_project.yml`, dùng chung toàn project — hiện
gồm `('kgs','kbs','kwl','kwn','kdt','kal','prd','hh','vde')`): nếu token 1 nằm trong
whitelist thì campaign đã theo convention mới (đọc vị trí 5), ngược lại vẫn đọc theo
vị trí cũ.

**Fix áp dụng cho Paris:** đổi cách tính `nhom_dv_p2`/`nhom_dv_p3` trong
`stg_frmacpr_fb_insight_v2.sql` sang branch tương tự (dùng chung `var('all_brand_mkt_camp')`
với model KN, không tạo var riêng):

```sql
CASE
    WHEN SPLIT_PART(f.ad_campaign_name, '_', 1) IN {{ var('all_brand_mkt_camp') }}
        THEN SPLIT_PART(f.ad_campaign_name, '_', 5)   -- convention mới (đã đổi tên)
    ELSE SPLIT_PART(f.ad_campaign_name, '_', 2)        -- convention cũ (chưa đổi tên) — fallback
END AS nhom_dv_p2
-- (nhom_dv_p3 tương tự, fallback vị trí 3)
```

Chỉ sửa `nhom_dv_p2`/`nhom_dv_p3` — **không đụng `chi_nhanh`**, vì `chi_nhanh` của
Facebook lấy từ `lpa.branch` (join theo `region`), không parse từ `campaign_name`, nên
không bị ảnh hưởng bởi vụ đổi convention này.

**Quyết định khi sửa (đã thống nhất với người dùng 2026-08-09):**
- Dùng `ad_campaign_name` **theo từng dòng/ngày** để parse (giống cách model KN đang
  làm), **không** resolve về "tên mới nhất theo campaign_id" bằng JOIN LATERAL — dù
  thực tế actor đổi tên nhưng giữ nguyên `campaign_id`, những dòng chi phí cũ (trước
  khi đổi tên) vẫn được parse theo tên tại thời điểm đó, không hồi tố theo tên mới.
- Với campaign chưa đổi tên (token 1 không thuộc whitelist): giữ nguyên logic parse
  cũ (vị trí 2/3) làm fallback — không tự "sửa" hay loại bỏ, chỉ để actor tự đổi tên
  khi sẵn sàng.

**Verify sau fix (2026-08-09):** `dbt run --select stg_frmacpr_fb_insight_v2+` build
lại thành công tới `report_marketing_ad_cost_pr_v2`. `PRFB001` = 0 dòng. 6.840 dòng
được phân bổ lại: +4.019 dòng vào `Niềng răng mắc cài`, +2.336 dòng vào `Implant`,
485 dòng còn lại → `KHAC` (giá trị thật ở vị trí 5 là `khac`, không khớp category
nào — không còn là lỗi parse, là service chưa phân loại thật sự).

**Việc còn tồn (chưa xử lý, chỉ để theo dõi):** kiểm tra toàn bộ campaign_id Paris
trong `cs_facebook_insight` bằng "tên mới nhất theo campaign_id" cho thấy **420/487
campaign_id** vẫn chưa đổi tên theo convention mới, nhưng đa số đã ngừng chạy (data
cuối từ 2026-07-21 trở về trước). Chỉ **4 campaign_id còn phát sinh chi phí đến hôm
nay (2026-08-08)** vẫn dùng tên cũ: `120246226473180478`, `120250915229370478`
(act_503362870590760), `6906714304515`, `6941857090315` (act_1741025749489548) — cần
nhắc actor đổi tên; trong lúc chờ, các campaign này vẫn ra kết quả đúng nhờ fallback
vị trí 2/3, không bị gán nhầm thành mã tài khoản nữa.
