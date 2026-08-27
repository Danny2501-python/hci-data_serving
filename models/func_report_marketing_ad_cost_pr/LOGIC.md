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
  stg_frmacpr_target_daily_view ← Materialize view_ggs_paris_sm_target_daily (materialized='view')
  stg_frmacpr_targets         ← KPI targets (ref stg_frmacpr_target_daily_view)
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

---

## `view_ggs_paris_sm_target_daily` — chuyển thành dbt model (materialized view) — 2026-08-09

**Vấn đề:** view `public.view_ggs_paris_sm_target_daily` (nguồn cho `stg_frmacpr_targets`)
trước đây được tạo tay ngoài DB, không do dbt/code nào trong repo quản lý. Bảng gốc
`ggs_paris_sm_target` là bảng ingest kiểu Google Sheet (có
`snapshot_date`/`ingestion_timestamp`/`source_server`, cùng dạng `tiktok_raw_ad`) —
nghi ngờ job sync định kỳ DROP + tạo lại bảng, kéo theo view phụ thuộc bị drop
theo. Đã gặp thực tế 2026-08-09: `dbt run` báo lỗi `relation
"view_ggs_paris_sm_target_daily" does not exist`, sau đó view tự nhiên tồn tại
lại mà không rõ ai/job nào tạo.

**Fix:** thêm model mới `stg_frmacpr_target_daily_view.sql`, port y hệt định
nghĩa view gốc (lấy từ `pg_get_viewdef()`), đọc trực tiếp từ
`source('paris', 'ggs_paris_sm_target')`, cấu hình:
```sql
{{ config(materialized = 'view', alias = 'view_ggs_paris_sm_target_daily') }}
```
`alias` giữ nguyên tên object cũ (`view_ggs_paris_sm_target_daily`) để báo cáo/
dashboard khác đang query trực tiếp view này (ngoài phạm vi dbt) không bị ảnh
hưởng. `stg_frmacpr_targets.sql` đổi từ `source('paris', 'view_ggs_paris_sm_target_daily')`
sang `ref('stg_frmacpr_target_daily_view')`. `sources.yml` đổi entry Targets từ
view sang bảng gốc `ggs_paris_sm_target`.

**Hiệu quả:** mỗi lần `dbt run --select tag:report_pr` (Airflow DAG
`data_serving_pr_etl`, chạy hằng ngày) sẽ tự `CREATE OR REPLACE VIEW` lại object
này — không còn phụ thuộc ai tạo tay ngoài DB nữa, miễn bảng gốc
`ggs_paris_sm_target` còn tồn tại đúng schema (`date_from`, `date_to`, `type`,
`product_category`, `value`).

**Verify (2026-08-09):** `dbt run --select func_report_marketing_ad_cost_pr` chạy
thành công (4/4 model, gồm `view_ggs_paris_sm_target_daily` materialize kiểu
`CREATE VIEW`). View vẫn ra đúng 184 dòng, mart vẫn ra 92 `target_lead` +
92 `target_cost` — khớp số liệu trước khi chuyển.

**Script chạy tay dự phòng** (nếu cả bảng gốc `ggs_paris_sm_target` bị drop, cần
đợi job ingest tạo lại bảng trước khi dbt chạy được):
`analyses/func_report_marketing_ad_cost_pr/create_view_ggs_paris_sm_target_daily.sql`.

---

## Thêm `nguon_moi_v2`/`nhom_nguon_moi_v2` — "nguồn mới"/"nhóm nguồn mới" — 2026-08-09

Thêm 2 cột mới vào `mart_report_marketing_ad_cost_pr`, cùng cơ chế và cùng
tên cột đã dùng ở `func_report_marketing_ad_cost_kn` (xem `README.md` bên đó
mục 15): lấy từ hệ "nguồn mới" `crm_lead.new_source_id → utm_source.name`,
**khác** hệ nguồn cũ `nguon`/`nhom_nguon` (từ `stag_sources` qua
`crm_lead.source_id` — 2 hệ bảng độc lập, không suy ra lẫn nhau).

```
crm_lead.new_source_id
  → utm_source.id (kèm utm_source.brand_id = crm_lead.brand_etl)
        → nguon_moi_v2 = utm_source.name
  → utm_source.category_id → crm_category_source.id
        (kèm crm_category_source.brand_etl = crm_lead.brand_etl)
        → nhom_nguon_moi_v2 = crm_category_source.name
```

**Luôn kèm `brand_etl`/`brand_id` khi join `id`** — gotcha "id trùng chéo
giữa brand_etl" (`common/knowledge.md` mục 1), áp dụng chung cho mọi bảng
join mới trong `data_serving`, không riêng model này.

**Thay đổi theo file:**
- `stg/sources.yml`: thêm nguồn `utm_source`, `crm_category_source`
- `stg_frmacpr_leads_lines.sql`: expose thêm `new_source_id`
- `int_frmacpr_erp_conv.sql`: join `utm_source`/`crm_category_source` trong
  CTE `base`, propagate qua các nhánh Lead/BK/BKHL/DC/TC
- `stg_frmacpr_doanh_so.sql`: join tương tự (nhánh DS, đã có sẵn `crm_lead`
  join từ trước)
- `int_frmacpr_union.sql`, `mart_report_marketing_ad_cost_pr.sql`: propagate
  ra output cuối

**Populate:** chỉ cho các `type_data` có liên kết CRM (Lead/BK/BKHL/DC/TC/DS),
và ngay trong nhóm đó cũng không phải 100% — phụ thuộc `crm_lead.new_source_id`
có được ERP điền hay không (thực đo ~53–66% trên dữ liệu Paris, thấp hơn
Kangnam do coverage ERP khác nhau giữa 2 brand).

### Mặc định cứng theo kênh cho các nhánh không có CRM linkage — 2026-08-09

Theo yêu cầu người dùng: các nhánh **không join CRM** nhưng kênh đã xác định
rõ từ chính loại dữ liệu (không cần tra CRM) được mặc định cứng theo tên
thật trong catalog `utm_source` của Paris (verify: id=731 `Facebook`, id=735
`Google_Ads`, id=733 `Tiktok`, cả 3 cùng `category_id=126` →
`crm_category_source.name = 'Online'`), thay vì để `NULL`:

| Nhánh | File | Căn cứ xác định kênh | Mặc định |
|---|---|---|---|
| `Deal_cs` (DealCS) | `int_frmacpr_erp_conv.sql` | `stg_frmacpr_deal_cs` chỉ lấy Deal Caresoft có `ctsda.utm_source ilike '%Google_Search%'` | `'Google_Ads'` / `'Online'` |
| `Cost_fb_cd`/`Cost_fb_th` | `stg_frmacpr_fb_insight_v3.sql` | Chi phí quảng cáo Facebook | `'Facebook'` / `'Online'` |
| `ib` (Inbox) | `stg_frmacpr_inbox.sql` | `nguon` đã set cứng `'MD - Facebook'` | `'Facebook'` / `'Online'` |
| `google` | `stg_frmacpr_google.sql` | Chi phí quảng cáo Google Ads | `'Google_Ads'` / `'Online'` |
| `tiktok` | `stg_frmacpr_tiktok.sql` | Chi phí quảng cáo TikTok | `'Tiktok'` / `'Online'` |
| `target_lead`/`target_cost` | `stg_frmacpr_targets.sql` | **Giữ NULL** — "Mục tiêu", không phải traffic thật, không gắn 1 kênh cụ thể | NULL |

**Lưu ý khác với `func_report_marketing_ad_cost_kn`:** bên KN, `DealCS` lấy
theo tiêu chí **FB `ad_id`** (`stg_frmack_deal.sql`) nên mặc định
`'Facebook'`; bên PR, `DealCS` lấy theo tiêu chí **Google Search**
(`ctsda.utm_source ilike '%Google_Search%'`) nên mặc định `'Google_Ads'` — 2
pipeline cùng `type_data = 'Deal_cs'`/`'DealCS'` nhưng nguồn gốc dữ liệu khác
nhau, đã đọc code thật của từng bên trước khi áp dụng, không copy máy móc.

**Verify (2026-08-09):** `dbt run --select func_report_marketing_ad_cost_pr`
build lại thành công (338,865 dòng). Populate 100% cho `Cost_fb_cd`
(166,988), `Cost_fb_th` (65,930), `Deal_cs` (1,178), `google` (2,932),
`tiktok` (31), `ib` (17,741) — đúng giá trị mặc định theo bảng trên;
`target_lead`/`target_cost` (92 dòng mỗi loại) vẫn `NULL` đúng như thiết kế.

---

### Fallback: suy ra nguồn mới từ nguồn cũ qua `master_data.m_utm_source_old_new_map` — 2026-08-09

Theo yêu cầu người dùng: với các dòng có liên kết CRM nhưng
`crm_lead.new_source_id` NULL (không tra được nguồn mới trực tiếp), tự động
suy ra `nguon_moi_v2`/`nhom_nguon_moi_v2` từ **nguồn cũ**
(`crm_lead.source_id`) qua bảng mapping `m_utm_source_old_new_map`
(model `master_data`, xem `data_serving/models/master_data/schema.yml`).

**Verify trước khi áp dụng:** `crm_lead.source_id` join thẳng
`utm_source.id` (kèm `brand_id = brand_etl`) khớp **100%** (37,906/37,906
lead Paris có `source_id`) — xác nhận `source_id` cùng ID-space với
`utm_source`, không phải hệ khác. Join tiếp qua
`m_utm_source_old_new_map.old_source_id` khớp **97.7%** (37,051/37,906).

**Gotcha fan-out:** bảng mapping có 1 số `old_source_id` ứng với **nhiều**
`new_source_id` (không phải quan hệ 1-1 tuyệt đối — xem
`master_data/m_utm_source_old_new_map.sql`). JOIN thẳng theo
`old_source_id + brand_etl` sẽ nhân dòng — đo được **659 lead** (brand
1/3/4/8, `new_source_id IS NULL`) bị fan-out nếu không xử lý. **Fix:**
`LEFT JOIN LATERAL (... ORDER BY new_source_id LIMIT 1) ON TRUE` thay vì
JOIN thẳng — chọn 1 dòng deterministic (nhỏ nhất `new_source_id`) mỗi
`(old_source_id, brand_etl)`.

Áp dụng ở `int_frmacpr_erp_conv.sql` (CTE `base`, cho Lead/BK/BKHL/DC/TC) và
`stg_frmacpr_doanh_so.sql` (DS):

```sql
LEFT JOIN source('paris', 'utm_source') us
       ON us.id = ll.new_source_id AND us.brand_id = ll.brand_etl
LEFT JOIN LATERAL (
    SELECT new_source_name, new_source_category_id
    FROM ref('m_utm_source_old_new_map') m
    WHERE m.old_source_id = ll.source_id AND m.brand_etl = ll.brand_etl
      AND ll.new_source_id IS NULL
    ORDER BY m.new_source_id
    LIMIT 1
) monm ON TRUE
LEFT JOIN source('paris', 'crm_category_source') cat
       ON cat.id = COALESCE(us.category_id, monm.new_source_category_id)
       AND cat.brand_etl = ll.brand_etl
...
COALESCE(us.name, monm.new_source_name) AS nguon_moi_v2,
cat.name AS nhom_nguon_moi_v2
```
*(bỏ dấu `{{ }}` Jinja trong đoạn minh họa trên để không bị hiểu nhầm là code
thật khi đọc file này — xem code thật ở `int_frmacpr_erp_conv.sql`.)*

`cat` (nhóm nguồn) dùng chung 1 join, key = `COALESCE(us.category_id,
monm.new_source_category_id)` — không cần join `crm_category_source` 2 lần.

**Verify sau fix (2026-08-09):** `dbt run --select func_report_marketing_ad_cost_pr`
build lại thành công (338,865 dòng, không đổi tổng số dòng — chỉ đổi giá trị
2 cột). Coverage `nguon_moi_v2` tăng mạnh:

| type_data | Trước fallback | Sau fallback |
|---|---|---|
| BK | 7,479/12,613 (59.3%) | 12,454/12,613 (98.7%) |
| BKHL | 7,479/12,613 (59.3%) | 12,454/12,613 (98.7%) |
| DC | 6,238/10,532 (59.2%) | 10,407/10,532 (98.8%) |
| Lead | 6,136/11,439 (53.6%) | 11,303/11,439 (98.8%) |
| TC | 4,235/6,417 (66.0%) | 6,379/6,417 (99.4%) |
| DS | 5,806/30,267 (19.2%) | 9,052/30,267 (29.9%) |

DS thấp hơn hẳn các nhánh khác kể cả sau fallback — nhiều dòng
`stag_payment_transfer` không map được `crm_id`/`source_id` hợp lệ sang
`crm_lead`, giới hạn dữ liệu nguồn chứ không phải lỗi join (đã kiểm tra
join logic giống hệt các nhánh khác).

### Đào sâu nguyên nhân DS coverage thấp (29.9%) — 2026-08-09

Tách funnel để tìm bước rớt dữ liệu (brand_etl=3, `start_date=2025-08-01`,
30,267 dòng `stag_payment_transfer`):

| Bước | Số dòng | Tỷ lệ |
|---|---|---|
| Match `crm_lead` (`spt.crm_id = cl.id AND cl.brand_etl = spt.brand_etl`) | 9,111 | 30.1% |
| → có `new_source_id` trực tiếp | 5,806 | — |
| → chỉ có `source_id` (cũ), cần fallback | 3,305 | — |
| → không có nguồn nào (cả 2 đều NULL) | 0 | — |

**Kết luận: nút thắt nằm hoàn toàn ở bước match `crm_lead`, không phải ở
logic `new_source_id`/fallback** — một khi lead đã match được, gần như
100% có nguồn (trực tiếp hoặc qua fallback).

**Root cause — backlog đồng bộ `crm_lead`, không phải lỗi join:** tách theo
tháng `payment_date`:

| Tháng | Số dòng | % match `crm_lead` |
|---|---|---|
| 2025-08 → 2026-04 | 21,017 | ~0% |
| 2026-05 | 970 | 82.0% |
| 2026-06 → 2026-08 | 8,280 | 100% |

Đây là **cùng hiện tượng đã ghi nhận cho `brand_etl=1`** ở
`common/knowledge.md` mục 8 ("Coverage gap `new_product` vs `staging_sci`
cho `crm_lead`... tháng 1–5/2026 chỉ đạt 19.6–49.2%, tháng 6/2026 trở đi
100%") — lần này xảy ra ở `brand_etl=3` (Paris), với ranh giới rõ hơn: gần
như 0% trước tháng 5/2026, 100% từ tháng 6/2026. `crm_lead` brand Paris
trong `new_product` chỉ được đồng bộ đầy đủ dữ liệu lịch sử từ ~tháng
6/2026 — dữ liệu payment cũ hơn (69% tổng số dòng DS trong scope
`start_date` mặc định) hầu như không map được lead nào, kéo tổng coverage
xuống thấp dù coverage riêng tháng 6-8/2026 đã tốt (~98%, tương đương các
nhánh khác).

**Hệ quả thực tế:** `nguon_moi_v2`/`nhom_nguon_moi_v2` cho `DS` chỉ đáng tin
cậy với dữ liệu **từ tháng 6/2026 trở đi**; báo cáo dùng dữ liệu lịch sử xa
hơn (2025-08 → 2026-04) sẽ thấy coverage rất thấp cho nhánh này — đây là
giới hạn dữ liệu nguồn ERP, không sửa được ở tầng dbt model.

---

## Việc còn tồn (chưa xử lý, chỉ để theo dõi)

Kiểm tra toàn bộ campaign_id Paris trong `cs_facebook_insight` bằng "tên mới nhất
theo campaign_id" cho thấy **420/487
campaign_id** vẫn chưa đổi tên theo convention mới, nhưng đa số đã ngừng chạy (data
cuối từ 2026-07-21 trở về trước). Chỉ **4 campaign_id còn phát sinh chi phí đến hôm
nay (2026-08-08)** vẫn dùng tên cũ: `120246226473180478`, `120250915229370478`
(act_503362870590760), `6906714304515`, `6941857090315` (act_1741025749489548) — cần
nhắc actor đổi tên; trong lúc chờ, các campaign này vẫn ra kết quả đúng nhờ fallback
vị trí 2/3, không bị gán nhầm thành mã tài khoản nữa.
