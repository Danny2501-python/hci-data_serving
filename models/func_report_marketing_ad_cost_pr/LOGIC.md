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

---

## Thêm `campaign`/`actor` — phục vụ trang báo cáo `camp_actor` — 2026-09-10

Theo yêu cầu người dùng: bổ sung 2 cột `campaign`/`actor` vào
`mart_report_marketing_ad_cost_pr` (`report_marketing_ad_cost_pr_v2`), cùng cơ
chế `actor` (token vị trí 8 của `campaign_name`, guard `token 1 IN
var('all_brand_mkt_camp')`) đã dùng ở `func_report_marketing_ad_cost_kn`
(README.md mục 7 bên đó). Paris trước đó **hoàn toàn chưa có** 2 cột này.

**Phát hiện quan trọng trước khi implement:** `dim_camp_adset_ad`/
`dim_campaign`/`dim_account` (`models/master_data/*.sql`) — 3 bảng KN dùng để
join `ad_id → campaign_name` — build từ `source('public', 'cs_facebook_insight')`,
**cùng 1 bảng vật lý** với `source('paris', 'cs_facebook_insight')` mà
`stg_frmacpr_fb_insight_v2` đang đọc (không lọc brand). Nghĩa là 3 bảng dim này
dùng chung được cho Paris, không cần tạo bảng dim mới. Đồng thời, cả `int_frmacpr_erp_conv.base`
(Lead/BK/BKHL/DC/TC) và `stg_frmacpr_doanh_so` (DS) đã sẵn LEFT JOIN
`cs_ticket_api cta` qua `ticket_id` — chỉ cần trích thêm `cta.ad_id_value`
(regex lấy số) để nối tiếp sang `dim_camp_adset_ad → dim_campaign`.

**Nguồn `campaign`/cách tách `actor` theo từng kênh:**

| Kênh (`type_data`) | Nguồn `campaign` | Cách tách `actor` |
|---|---|---|
| Cost_fb_cd/th | `f.ad_campaign_name` (đã có sẵn trong `stg_frmacpr_fb_insight_v2`, trước đây chỉ dùng tách `nhom_dv_p2/p3` rồi drop) | Token vị trí 8, cùng guard |
| google | `gap.campaign` (đã có sẵn, trước đây chỉ tách 3 phần rồi drop) | Luôn `NULL` — convention Google Paris là `{chi_nhanh}_{nhom_dv}_{extra}`, không phải 9-token |
| tiktok | `tra."tên chiến dịch"` (đã có sẵn) | Token vị trí 8 — **100% dòng hiện có token 1 = `prd`** (verify 2026-09-10), hoạt động đầy đủ |
| ib (Inbox) | `ipf."tên quảng cáo"` (đã có sẵn, trước đây tách vị trí 2 rồi **GROUP BY làm mất chi tiết** — nay thêm `campaign_raw` vào GROUP BY, độ chi tiết kết quả tăng nhẹ) | Viết dạng guard (không hard-code NULL) nhưng **luôn ra `NULL` trên dữ liệu thật** — verify token 1 toàn bộ là mã chi nhánh (`ALL`/`HCM`/`ĐN`/`HN`/...), không phải mã brand |
| Deal_cs | `COALESCE(ggcal.campaign_name, ctsda.utm_campaign)` (đã có sẵn trong CTE, trước đây drop) | Luôn `NULL` — nhánh này lấy theo tiêu chí Google Search, không phải FB convention |
| Lead/BK/BKHL/DC/TC | **Mới**: `cta.ad_id_value` (regex `\d+`) → `ref('dim_camp_adset_ad')` (theo `ad_id`) → `ref('dim_campaign')` (theo `ad_campaign_id`) → `campaign_name`, join thêm vào CTE `base` (`int_frmacpr_erp_conv.sql`) | Token vị trí 8 của `campaign_name` vừa join, cùng guard |
| DS | Y hệt cơ chế trên, join thêm vào `stg_frmacpr_doanh_so.sql` (qua `cl.ticket_id`) | Y hệt trên |
| target_lead/target_cost | `NULL` — giữ nguyên, "Mục tiêu" không phải traffic thật, không gắn 1 campaign cụ thể | `NULL` |

**Coverage đo thực tế trên dữ liệu thật (2026-09-10, `new_product` DB, từ
`start_date = 2025-08-01`)** — dùng để quyết định phạm vi (người dùng chọn
"làm toàn bộ kể cả DS" dù coverage thấp, để đồng nhất cấu trúc pipeline, kỳ
vọng tăng dần theo thời gian giống pattern `nguon_moi_v2`):

| Bước | Lead/BK/BKHL/DC/TC (85.153 lead) | DS (42.583 payment) |
|---|---|---|
| Có `ticket_id` | 63.750 (74,9%) | 42.531 (99,9%, qua `crm_lead`) |
| Có `cs_ticket_api.ad_id_value` | 25.488 (29,9%) | — |
| Có numeric `ad_id` trích được | 15.943 (18,7%) | 3.832 (9,0%) |
| **Khớp `dim_camp_adset_ad`/`dim_campaign`** (→ có `campaign_name`) | **11.529 (13,5%)** | **1.446 (3,4%)** |

Trong 11.529 dòng Lead-nhóm khớp được, `campaign_name` lẫn cả 2 convention:
một phần vẫn kiểu cũ (`TK3_NKK_MOFUB_MSG_KM_ALL_260506_ANT` — token 1 `TK3`
KHÔNG thuộc whitelist → `actor = NULL`), một phần theo convention mới
(`prd_prfb001_{}_{}_khac_ib_mofub_trangnn_promo_...` — token 1 `prd` thuộc
whitelist → `actor` tách được) — nên coverage `actor` thực tế cho nhóm CRM
còn thấp hơn 13,5%/3,4% nêu trên.

`stg_frmacpr_fb_insight_v1` (nguồn legacy `stg_fb_insight_old_pr`) đã verify
**không có cột campaign_name nào** (information_schema) → `campaign = 'KXĐ'`,
`actor = NULL` cố định cho nhánh này trong `stg_frmacpr_fb_insight_v3`, giống
cách KN xử lý fb_insight_v1 legacy.

**Verify sau khi thêm:** `dbt compile --select func_report_marketing_ad_cost_pr+`
chạy thành công (exit 0), không lỗi `ref`/cú pháp trên cả 14 model liên quan.

**Build thử nghiệm (2026-09-10):** theo yêu cầu người dùng, `alias` của
`mart_report_marketing_ad_cost_pr.sql` tạm đổi từ `report_marketing_ad_cost_pr_v2`
sang **`report_marketing_ad_cost_pr_v3`** (bảng mới, không đụng `v2` production)
để `dbt run --select func_report_marketing_ad_cost_pr+` build thử mà không ảnh
hưởng dữ liệu đang chạy thật. Kết quả: 511.298 dòng, coverage `campaign`/`actor`
theo từng `type_data` khớp đúng dự đoán ở bảng trên (vd. DS ra chính xác 1.446
dòng có `campaign` như số đã đo trước khi build; `tiktok` 100%/100%; `ib`/`google`/
`Deal_cs` 100% `campaign` nhưng 0% `actor` đúng thiết kế).

**`report_marketing_ad_cost_pr_v3` hiện là bảng thử nghiệm, CHƯA vào lịch chạy
Airflow (`data_serving_pr_etl`)** — DAG vẫn chạy model gốc ra `v2` hằng ngày như
cũ, `v3` sẽ không tự cập nhật. Người dùng chọn giữ nguyên trạng thái này (chưa
quyết định thay `v2` hay thêm `v3` vào DAG) để tự kiểm tra thêm trước. Khi nào
chốt phương án, cần: (a) nếu thay `v2` — đổi `alias` trở lại
`report_marketing_ad_cost_pr_v2` rồi `dbt run` (ghi đè bảng production, cần xác
nhận riêng); hoặc (b) nếu giữ song song — thêm model vào DAG
`data_serving_pr_etl` để `v3` tự chạy hằng ngày cùng `tag:report_pr`.

**So sánh v2 vs v3 (verify 2026-09-10):** tổng dòng v2=478.986, v3=511.298
(chênh lệch +32.312 đúng bằng phần tăng của nhánh `ib` do đổi grain — 12/13
`type_data` còn lại khớp tuyệt đối 1:1 số dòng). `SUM(dt::numeric)` theo từng
`type_data` khớp tuyệt đối (delta 0.00) ở mọi nhánh có metric dạng số — xác
nhận việc thêm `campaign`/`actor` không làm sai lệch bất kỳ số liệu tính toán
nào đang có. Không phát hiện fan-out từ JOIN `dim_camp_adset_ad` mới thêm (số
dòng mỗi `type_data` khớp y hệt v2).

---

## GOTCHA nghiêm trọng — `ad_id`/`ad_campaign_id` Facebook KHÔNG tách biệt theo
## `brand_etl` trong `cs_facebook_insight` — phát hiện & vá 2026-09-10

Khi review lại phần join `dim_camp_adset_ad`/`dim_campaign` cho nhánh
Lead/BK/BKHL/DC/TC/DS (mục trên), người dùng đặt câu hỏi liệu `campaign`/
`actor` lấy ra có bị lẫn dữ liệu Kangnam không. Verify trên dữ liệu thật xác
nhận **CÓ rủi ro thật**:

- `dim_camp_adset_ad`/`dim_campaign`/`dim_account` (`models/master_data/*.sql`)
  build từ **toàn bộ** `cs_facebook_insight`, không `WHERE brand_etl = ...` —
  gộp cả `brand_etl=1` (Kangnam, 40 ad account), `brand_etl=3` (Paris, 6 ad
  account), `brand_etl=4` (3 ad account).
- Verify trực tiếp: **cùng 1 `ad_id` (thậm chí cùng `ad_campaign_id`) xuất hiện
  đồng thời ở cả `brand_etl=1` VÀ `brand_etl=3`** trong `cs_facebook_insight`
  (ví dụ `ad_id = 120244671738000205` và ≥19 ID khác tương tự) — Facebook ID
  trong bảng này KHÔNG đảm bảo tách biệt theo brand như giả định ban đầu.
- `dim_camp_adset_ad.sql` dedupe bằng
  `ROW_NUMBER() OVER (PARTITION BY ad_id, adset_id, ad_campaign_id ORDER BY
  date DESC)` — **không phân biệt brand** trong partition, nên nếu bản ghi
  Kangnam trùng `(ad_id, adset_id, ad_campaign_id)` có `date` mới hơn bản Paris,
  `dim_camp_adset_ad` sẽ trả về `account_id` của Kangnam cho một `ad_id` vốn
  thuộc về lead Paris.
- Đo tác động cụ thể (555 `ad_id` distinct mà lead Paris match được): 498
  thuộc `brand_etl=3` (đúng Paris), nhưng **57 cũng đồng thời tồn tại ở
  `brand_etl=1`** (Kangnam) — tức ~10% ad_id match được có nguy cơ lẫn brand.
  Tại thời điểm verify, join thực tế (qua `dim_camp_adset_ad`→`dim_account`)
  **vẫn resolve đúng 100% về 1 trong 6 tài khoản Paris thật** — nhưng đây là
  **may mắn do tie-break `ORDER BY date DESC`**, không phải do có lọc brand
  tường minh → không an toàn về lâu dài (dữ liệu Kangnam mới hơn trong tương
  lai có thể làm campaign/actor của Paris âm thầm đổi thành dữ liệu Kangnam).

**Fix áp dụng** (`int_frmacpr_erp_conv.sql`, `stg_frmacpr_doanh_so.sql`): thêm
CTE `paris_fb_accounts` (danh sách `ad_account_id` THẬT của Paris, lấy động từ
`cs_facebook_insight WHERE brand_etl = 3` — không hard-code) và `LEFT JOIN`
thêm vào chuỗi `dcaa → pfa`. Biểu thức `campaign`/`actor_code` chỉ nhận giá trị
từ `dcam.campaign_name` khi `pfa.ad_account_id IS NOT NULL` (account_id resolve
được thực sự thuộc Paris), ngược lại rơi về `'KXĐ'`/`NULL` như không match được
— an toàn cho cả 2 trường hợp fan-out (dù `dim_camp_adset_ad` trả về bản Paris
hay bản Kangnam, chỉ bản đã verify account thuộc Paris mới được chấp nhận).

**Verify sau fix (2026-09-10):** `dbt run` build lại `v3` thành công, tổng số
dòng không đổi (511.298). Coverage `campaign`/`actor` theo từng `type_data`
(Lead/BK/BKHL/DC/TC/DS) **giữ nguyên y hệt trước fix** (vd. DS vẫn 1.446/327,
Lead vẫn 3.888/1.599) — xác nhận fix không làm mất dữ liệu Paris hợp lệ nào,
chỉ chặn đường rò rỉ. Kiểm tra riêng: **0 campaign_name nào trong kết quả CRM
Paris thuộc nhóm campaign CHỈ tồn tại ở brand khác Paris** (`bool_and(brand_etl
<> 3)` trên toàn bộ dòng cùng tên trong `cs_facebook_insight`).

Nhánh **Cost_fb_cd/Cost_fb_th** (đọc trực tiếp `cs_facebook_insight WHERE
brand_etl=3`, không qua `dim_camp_adset_ad`) và nhánh **google/tiktok/ib/
Deal_cs** (đọc từ bảng nguồn riêng của Paris — `google_ad_paris`,
`tiktok_raw_ad`, `inbox_paris_fb`, `ggs_google_campaign_ads_list`) **không bị
ảnh hưởng bởi gotcha này** — chỉ 2 nhánh join qua `dim_camp_adset_ad`/
`dim_campaign` (Lead/BK/BKHL/DC/TC/DS) mới có rủi ro và đã được vá.

## Bổ sung cụm cột đối chiếu `func_report_marketing_ad_cost_kn` — 2026-09-11

Theo yêu cầu người dùng: sau khi đối chiếu 2 model, PR thiếu 11 trường tính
toán so với KN (`vk`, `ten_dv`, `local_k`, `tinh_noi`, `region`, `quoc_gia`,
`chau_luc`, `page`/`page_id`, `account_fb`, `nhom_dv_KH_quan_tam`,
`nhom_dv_chinh_booking`). Đã verify khả thi từng cột trên DB thật (2026-09-11)
rồi bổ sung toàn bộ:

**Nguồn dữ liệu mới thêm vào `stg/sources.yml`:** `res_country_state`,
`res_country`, `ucbt_country_continent`, `ggs_region_map`, `ucbt_page_config`
— đều là bảng dùng chung với `func_report_marketing_ad_cost_kn` (cùng vật lý,
không brand-scoped, verify có dữ liệu Paris: `ucbt_page_config.brand = 'Paris
- Dental'` 19 dòng, `cs_services_api.brand_id = 3` 210 dòng).

**2 model `common/` mới** (bản Paris của 2 model KN, vốn hard-code
`brand_etl = 1`): `stg_dv_khach_hang_quan_tam_paris.sql`,
`stg_booking_nhom_dich_vu_chinh_paris.sql` — logic giữ nguyên y hệt bản KN,
chỉ đổi `brand_etl = 3` và `source('paris', ...)` thay vì `source('crm_base',
...)`/`source('kangnam', ...)`. Không sửa 2 model gốc của KN (tránh rủi ro
ảnh hưởng production KN).

**Cơ chế từng cột** (tách raw code ở `stg`/`int`, tra tên chuẩn ở `mart` —
cùng triết lý đã dùng cho `nhom_dv_muc_tieu`):

| Cột | Nguồn raw (stg/int) | Tra tên ở mart |
|---|---|---|
| `vk` | `crm_lead.overseas_vietnamese` (Lead/BK/BKHL/DC/TC/DS) | — (tính thẳng) |
| `ten_dv` | `view_stag_products.product` (`sp` đã join sẵn) | — |
| `local_k` | CRM: `res_country_state.name` qua `state_id`. FB Cost: `vung` (region quảng cáo) | — |
| `tinh_noi` | — | Chuẩn hoá `local_k` (regex, giống KN) |
| `region` | — | `ggs_region_map` theo `tinh_noi` |
| `quoc_gia` | `res_country.name` qua `country_id` (CRM only) | — |
| `chau_luc` | — | `ucbt_country_continent` theo `quoc_gia` |
| `page`/`page_id` | FB Cost: `facebook_page_id`. Inbox: `inbox_paris_fb."id page"`. CRM: `page_code` = token vị trí 2 `campaign` (cùng guard `actor`) | `dim_page` (FB Cost/Inbox) hoặc `ucbt_page_config` (CRM) |
| `account_fb` | FB Cost: `ad_account_id`. CRM: `dcaa.account_id` (đã verify Paris qua `pfa`) | `dim_account` |
| `nhom_dv_KH_quan_tam` | `stg_dv_khach_hang_quan_tam_paris` (CRM only) | — |
| `nhom_dv_chinh_booking` | `stg_booking_nhom_dich_vu_chinh_paris` (CRM only) | — |

**Khác biệt có chủ đích so với KN** (đơn giản hoá để giảm rủi ro/độ phức tạp
implement, không phải thiếu sót):
1. `page` cho nhóm CRM: bỏ qua bước ưu tiên "page theo ticket/service"
   (`cs_services_api` qua `ticket_id`) mà KN có — chỉ dùng `ucbt_page_config`.
2. Tất cả cột mới **luôn `COALESCE(...,'KXĐ')`** ở mart (không để raw `NULL`
   như KN làm ở 1-2 stream) — nhất quán với cách `campaign`/`actor`/
   `nhom_dv_muc_tieu` đã xử lý ở model Paris này.
3. `vk` đơn giản hơn KN — dữ liệu Paris chỉ có `overseas_vietnamese =
   'marketing'` cho Việt Kiều thật (verify 2026-09-11), không có
   `'expat'`/`'mkt_oversea'` để tách `'QUỐC TẾ'` riêng.

**Giới hạn đã biết** (không phải bug, ghi lại để tránh hiểu nhầm khi đọc số
liệu):
- `chau_luc`: `ucbt_country_continent` không có dòng nào cho `'Việt Nam'` →
  coverage rất thấp trên dữ liệu Paris (đa số khách Việt Nam).
- `region` cho Cost_fb_cd/th: `local_k` ở đây là `region` quảng cáo tiếng Anh
  (`cs_facebook_insight.region`, vd `"Ho Chi Minh City"`), khác định dạng với
  `res_country_state.name` tiếng Việt mà `ggs_region_map` kỳ vọng → khớp thấp.
- `region`: các override thủ công (Bà Rịa/Lào Cai/Yên Bái/Huế) copy nguyên từ
  KN, hiệu chỉnh theo mạng lưới chi nhánh Kangnam, CHƯA rà soát lại có đúng
  với cách Paris tự phân vùng hay không.
- `nhom_dv_chinh_booking`: taxonomy 9-bucket dùng chung toàn hệ thống thiết kế
  cho danh mục dịch vụ đa dạng của Kangnam — verify trên dữ liệu Paris thật,
  hầu như 100% rơi vào đúng 1 bucket `'3.HÀM MẶT/NHA KHOA'` (Paris chỉ chuyên
  nha khoa) → cột có giá trị phân biệt thấp cho Paris, dù vẫn đúng cơ chế.

**Build & verify (2026-09-11):** `dbt compile`/`dbt run --select
func_report_marketing_ad_cost_pr+` PASS 4/4, `v3` = 512.493 dòng (khớp mức
tăng tự nhiên so với 512.434 trước đó, không fan-out). `SUM(dt::numeric)`
theo từng `type_data` không đổi. Sample giá trị thật hợp lý: `ten_dv` ra tên
dịch vụ nha khoa thật ("Lấy cao răng - Mức 2", "Niềng Răng Mắc Cài", "Trám bít
hố rãnh"...), `page` ra tên Trang Facebook thật ("Nha Khoa Paris", "Nha Khoa
Paris Hải Phòng"...). Coverage theo `type_data` (mẫu số = tổng dòng, tử số =
khác `'KXĐ'`):

| type_data | vk | ten_dv | local_k | quoc_gia | page | account_fb |
|---|---|---|---|---|---|---|
| Lead | 100% | 20,4% | 83,7% | 100% | 4,36% | 9,93% |
| BK/BKHL | 100% | 35,4% | 90,7% | 100% | 2,87% | 6,77% |
| DC | 100% | 39,4% | 97,5% | 100% | 1,92% | 4,73% |
| TC | 100% | 100% | 98,6% | 100% | 2,91% | 4,67% |
| DS | 100% | 100% | 98,6% | 100% | 0,83% | 3,40% |
| Cost_fb_cd | — (luôn `'KXĐ'`, không có CRM) | — | 100% | — | 52,9% | 52,9% |
| Cost_fb_th | — | — | 100% | — | 45,1% | 45,1% |
| ib | — | — | — | — | 93,9% | — (không có account) |

`page`/`account_fb` ở nhóm CRM bám sát coverage `actor` (cùng guard). `ib` có
coverage `page` cao nhất (93,9%) nhờ tra thẳng `"id page"` có sẵn trong
`inbox_paris_fb`, không phải suy luận qua campaign như KN. `chau_luc` không
đưa vào bảng trên vì coverage đồng loạt rất thấp (~1% mọi nhánh CRM) — lý do
đã giải thích ở trên (giới hạn của `ucbt_country_continent`, không phải lỗi).

### GOTCHA nghiêm trọng thứ 2 — `dim_page`/`dim_account` KHÔNG tách biệt theo
### `brand_etl` — phát hiện & vá 2026-09-11

Trong lúc rà soát lại toàn bộ model theo yêu cầu người dùng ("check lại logic
... có khớp hoàn toàn với nhánh Paris chưa"), phát hiện bản đầu tiên của cột
`page`/`account_fb` (mục trên) dùng `dim_page`/`dim_account`
(`models/master_data`) — **CÙNG LỚP GOTCHA** đã tìm và vá cho `dim_campaign`
(xem mục gotcha đầu tiên ở trên), nhưng lần này chưa được vá khi mới thêm.

**Verify trên dữ liệu thật (2026-09-11):**
- `facebook_page_id` **CÓ** trùng chéo giữa `brand_etl=1` (Kangnam) và
  `brand_etl=3` (Paris) trong `cs_facebook_insight` (vd. `1002878482918663`,
  `129515624270996`, `185061704983484`).
- `ad_account_id` **CÓ** trùng chéo tương tự (vd.
  `act_1741025749489548` — chính account PR dùng để phân biệt `Cost_fb_th`
  trong `stg_frmacpr_fb_insight_v2.sql` — cũng xuất hiện ở `brand_etl=1`).
- `dim_page`/`dim_account` dedupe THUẦN theo `page_id`/`account_id`
  (`ROW_NUMBER() OVER (PARTITION BY ... ORDER BY date DESC)`), **không phân
  biệt brand** — y hệt cơ chế đã gây lỗi cho `dim_campaign`.
- Kiểm tra trực tiếp 3 `page_id` collision ví dụ: **hiện tại** dedupe vẫn
  "thắng" về đúng brand_etl=3 (ra tên Paris thật) — nhưng đây là **may mắn**
  (tie-break theo `date DESC`), không phải do có lọc brand tường minh, giống
  hệt tình huống `dim_campaign` trước khi vá.

**Fix áp dụng** (`mart_report_marketing_ad_cost_pr.sql`): bỏ hẳn
`dim_page`/`dim_account`, thay bằng 2 CTE dedupe **chỉ trong phạm vi Paris**
(`paris_pages`, `paris_accounts_named` — `SELECT DISTINCT ON (...) ...
WHERE brand_etl = 3 ... ORDER BY ..., date DESC`, cùng cơ chế dedupe nhưng
đã lọc brand trước) rồi `LEFT JOIN` thường (không phải LATERAL) vào các CTE
này.

**Bài học hiệu năng:** bản vá đầu tiên dùng `LEFT JOIN LATERAL (SELECT ...
FROM cs_facebook_insight WHERE ... AND brand_etl=3 ORDER BY date DESC LIMIT
1)` — quét lại bảng `cs_facebook_insight` (~500K dòng) cho **từng dòng**
trong ~512K dòng output → quá chậm (`dbt run` chạy >5 phút chưa xong, phải
huỷ). Đổi sang dedupe 1 lần bằng CTE (giống cách `paris_fb_accounts` đã làm
ở `int_frmacpr_erp_conv.sql`) rồi `JOIN` thường — nhanh hơn nhiều bậc (mart
build lại chỉ ~96s).

**Sự cố vận hành khi vá (2026-09-11):** lần chạy đầu (bản LATERAL chậm) bị
huỷ giữa chừng qua kill process phía client, nhưng **query phía server
(Postgres) không bị huỷ theo** — chạy ngầm tiếp 12+ phút, giữ lock khiến lần
`dbt run` kế tiếp bị treo ở bước không liên quan (`CREATE VIEW
view_ggs_paris_sm_target_daily`, chờ ~376s). Xử lý bằng
`pg_cancel_backend()` trên đúng PID của query mồ côi đó (xác định qua
`pg_stat_activity`, tự tạo ra trong session này, không đụng session nào
khác) — sau đó lần chạy đang chờ tự tiếp tục bình thường.

**Verify sau fix (2026-09-11):** `dbt compile`/`dbt run` PASS 4/4, `v3` vẫn
512.493 dòng (không đổi). Coverage `page`/`account_fb` theo từng `type_data`
**giữ nguyên y hệt trước fix** (vd. `ib` vẫn 47.055, `Cost_fb_cd` vẫn
97.140/97.140) — xác nhận fix không làm mất dữ liệu Paris hợp lệ nào, chỉ
chặn đường rò rỉ. Kiểm tra lại đúng 3 `page_id` collision đã nêu ở trên: kết
quả cuối cùng trong `report_marketing_ad_cost_pr_v3` vẫn ra đúng tên Paris
(`N/A`, `Nha Khoa Paris`, `Nha Khoa Paris Hải Phòng`) — không có tên Kangnam
nào lọt vào.

**Phạm vi ảnh hưởng:** chỉ 2 cột `page`/`account_fb` (và gián tiếp `page_id`
khi dùng `page_id_raw`) bị ảnh hưởng — các cột khác thêm cùng đợt
(`vk`/`ten_dv`/`local_k`/`quoc_gia`/`nhom_dv_KH_quan_tam`/
`nhom_dv_chinh_booking`) đều lấy từ `crm_lead`/`view_stag_products` đã lọc
sẵn `brand_etl=3` ngay từ nguồn, không đi qua bảng dim dùng chung nào nên
không có rủi ro tương tự.

### Rà soát các JOIN không lọc brand còn lại — không phát hiện thêm rủi ro

Trong lúc rà soát, kiểm tra thêm join `stag_sources` (dùng cho cột `nguon`/
`nhom_nguon`/`kenh` — cột nền tảng nhất của cả report) — join hiện tại
(`ss1.old_id = ll.source_id`, `ss2.old_id = ss1.id_pr`) **không lọc
`brand_id`**. Verify trên dữ liệu thật: **0 `old_id` nào trùng chéo giữa
nhiều `brand_id`** trong tập `source_id` mà lead Paris thực tế dùng — khác
với `ad_id`/`ad_campaign_id`/`facebook_page_id`/`ad_account_id` (đều đã xác
nhận CÓ trùng chéo), `old_id` của `stag_sources` an toàn trong thực tế dù
không có filter tường minh. Không cần sửa.

### Vá tiếp phần còn sót — `dim_campaign` chưa được lọc qua `pfa` — 2026-09-11

Review lại fix trên phát hiện lỗ hổng còn sót: CTE `paris_fb_accounts`/`pfa`
chỉ kiểm tra **`dcaa.account_id`** (từ `dim_camp_adset_ad`, dedupe theo
`(ad_id, adset_id, ad_campaign_id)`), nhưng giá trị `campaign_name` thực tế
lại lấy từ **`dcam`** (`dim_campaign`) — một bảng dim dedupe **độc lập, chỉ
theo `ad_campaign_id`** (`ROW_NUMBER() OVER (PARTITION BY ad_campaign_id
ORDER BY date DESC)`), **không hề bị lọc qua `pfa`**.

Vì `ad_campaign_id` đã verify là có thể trùng chéo giữa brand_etl=1 và
brand_etl=3 (mục gotcha ở trên), nên dù `pfa` xác nhận đúng account Paris
cho `dcaa.account_id`, `dcam.campaign_name` (join riêng theo `campaign_id`)
vẫn có thể lấy nhầm dòng mới nhất **của Kangnam** cho cùng `campaign_id` đó —
không có điều kiện nào chặn việc này trước khi vá.

**Fix:** thêm điều kiện `dcam.ad_account_id = dcaa.account_id` thẳng vào JOIN
với `dim_campaign` (thay vì chỉ dựa vào `pfa` ở CASE phía sau), đảm bảo
`campaign_name` chỉ được nhận khi **cùng account** đã verify qua `dcaa`/`pfa`:

```sql
LEFT JOIN dim_campaign dcam
       ON dcam.campaign_id::text = dcaa.ad_campaign_id::text
      AND dcam.ad_account_id = dcaa.account_id
```

Áp dụng ở cả `int_frmacpr_erp_conv.sql` (CTE `base`) và
`stg_frmacpr_doanh_so.sql`. `pfa` vẫn giữ nguyên vai trò (chặn trường hợp
chính `dcaa.account_id` resolve nhầm sang brand khác) — 2 điều kiện bổ trợ
nhau, không thừa: `pfa` đảm bảo account của **ad** là Paris, điều kiện mới
đảm bảo `campaign_name` lấy ra thuộc **đúng account đó**, không phải account
khác trùng `campaign_id`.

**Verify sau fix (2026-09-11):** `dbt compile` PASS (không lỗi cú pháp),
`dbt run --select func_report_marketing_ad_cost_pr+` PASS 4/4, `v3` build lại
thành công (512.434 dòng — chênh lệch tự nhiên so với 511.298 dòng đo
2026-09-10 do +1 ngày dữ liệu mới phát sinh trên DB thật, không phải do fix).
Coverage `campaign`/`actor` **không sụt bất thường** so với baseline trước
fix (DS 1.449/329 so với 1.446/327; Lead 3.913/1.620 so với 3.888/1.599) —
xác nhận điều kiện `dcam.ad_account_id = dcaa.account_id` mới thêm không
chặn nhầm dữ liệu Paris hợp lệ nào. Đối chiếu lại toàn bộ 224 `campaign`
distinct (khác `'KXĐ'`) trong nhóm CRM Lead/BK/BKHL/DC/TC/DS: **0 campaign
nào không có dòng gốc `brand_etl = 3` trong `cs_facebook_insight`** — đóng
hẳn lỗ hổng rò rỉ brand đã nêu ở trên.

### Thêm `nhom_dv_muc_tieu` — "nhóm dịch vụ mục tiêu" — 2026-09-11

Theo yêu cầu người dùng: bổ sung cột `nhom_dv_muc_tieu` vào
`mart_report_marketing_ad_cost_pr`, cùng cơ chế đã dùng ở
`func_report_marketing_ad_cost_kn` (README.md mục 10 bên đó). Paris trước đó
hoàn toàn chưa có cột này.

**Cơ chế (giống hệt KN):**
1. Tách mã thô `nhom_dv_muc_tieu_code` = **token vị trí 5** của `campaign`
   (cùng nguồn `campaign`/cùng guard whitelist `var('all_brand_mkt_camp')` đã
   dùng cho `actor_code`, xem mục "Thêm `campaign`/`actor`" ở trên) — tách
   **ngay tại các tầng `stg`/`int` đã tách `campaign`/`actor_code`**
   (`stg_frmacpr_fb_insight_v2`, `stg_frmacpr_tiktok`, `stg_frmacpr_inbox`
   viết dạng guard nhưng luôn NULL trên dữ liệu thật, `int_frmacpr_erp_conv`,
   `stg_frmacpr_doanh_so`); các nhánh không theo convention 9-token
   (`stg_frmacpr_google`, `stg_frmacpr_deal_cs`, `stg_frmacpr_targets`) để
   `NULL` — y hệt cách `actor_code` được xử lý ở từng nhánh.
2. Propagate `nhom_dv_muc_tieu_code` qua `stg_frmacpr_fb_insight_v3` →
   `int_frmacpr_union` (thêm 1 cột vào toàn bộ 7 nhánh UNION).
3. **Tra cứu chính xác qua `campaign_name_split`** — thực hiện **tại
   `mart`** (không phải ở `stg`/`int`), `LEFT JOIN LATERAL` case-insensitive
   (`UPPER(campain_name_split) = UPPER(nhom_dv_muc_tieu_code) LIMIT 1`), lấy
   `nhom_dv` từ bảng mapping làm giá trị cuối cùng — cùng hệt cơ chế KN.

**`campaign_name_split` — bảng dùng chung, không brand-scoped:** bảng này
trước đây chỉ khai báo dưới `source('kangnam', ...)`. Verify: bảng vật lý
nằm cùng schema `public`/database `staging_sci` mà cả `kangnam` và `paris`
đều trỏ tới (giống pattern đã áp dụng cho `cs_facebook_insight` dùng chung
giữa 2 brand) — KN tự đọc bảng này không lọc brand ở bất kỳ đâu, xác nhận nó
là mapping token→nhóm dịch vụ **dùng chung cho toàn bộ quy ước đặt tên
campaign của tập đoàn** (cùng whitelist `all_brand_mkt_camp`), không phải
bảng riêng của Kangnam. Đã thêm khai báo `campaign_name_split` vào
`stg/sources.yml` dưới source `paris` (trỏ cùng bảng vật lý) để dùng trực
tiếp `source('paris', 'campaign_name_split')` ở `mart`, nhất quán namespace
với các bảng nguồn Paris khác thay vì mượn qua `source('kangnam', ...)`.

**Khác biệt có chủ đích so với KN:** KN để raw `NULL` ở Stream 1 & 2 (chỉ
COALESCE `'KXĐ'` ở Stream 3). Paris **luôn `COALESCE(..., 'KXĐ')`** — nhất
quán với cách `actor`/`campaign` đã xử lý ở model này (không có kiến trúc
3-stream như KN, toàn bộ nguồn đã hợp nhất qua 1 `int_frmacpr_union`).

**Độc lập với cột `nhom_dv` hiện có:** `nhom_dv` (Lead/BK/BKHL/DC/TC/DS) đến
từ CRM/product qua `m_nhom_dv_adnet_paris`, không liên quan campaign name;
`nhom_dv` (FB/Google/TikTok/Inbox) tách trực tiếp bằng CASE WHEN ngay trong
từng `stg`, không qua `campaign_name_split`. `nhom_dv_muc_tieu` là cột hoàn
toàn mới, không sửa/không ảnh hưởng giá trị `nhom_dv` ở bất kỳ nhánh nào.

**Chưa build lại để verify** — cần `dbt run --select
func_report_marketing_ad_cost_pr+` rồi kiểm coverage `nhom_dv_muc_tieu` theo
từng `type_data` (kỳ vọng tương tự pattern coverage của `actor`, vì cùng
guard, chỉ khác bước tra thêm `campaign_name_split` có thể làm giảm thêm nếu
token 5 không khớp dòng nào trong bảng mapping).

---

### Thêm `product_type` — tách Doanh số Dịch vụ / Doanh số Sản phẩm — 2026-09-24

Theo yêu cầu người dùng: bảng `report_marketing_ad_cost_pr_v2` lấy doanh số
(`type_data = 'DS'`) gồm **cả** Dịch vụ lẫn Sản phẩm nhưng trước đây không
có cột phân biệt. Thêm cột `product_type`, lấy nguyên từ
`stag_payment_transfer.product_type`:

- `'service'` = Doanh số Dịch vụ: thu tiền `crm_account_payment_detail` →
  `crm_line` (id `ps-`) + chuyển tiền từ/đến `crm_line` (id `to-`/`ti-`)
- `'cosmetic'` = Doanh số Sản phẩm: thu tiền
  `crm_account_payment_product_detail` → `crm_line_product` (id `pc-`) +
  chuyển tiền từ/đến `crm_line_product`

Chỉ có giá trị ở nhánh DS; mọi nhánh khác `NULL` (không COALESCE `'KXĐ'`).

**Thay đổi theo file:** `stg_frmacpr_doanh_so.sql` (expose cột),
`int_frmacpr_union.sql` (thêm vào cả 7 nhánh, `NULL::text` ngoài nhánh DS),
`mart_report_marketing_ad_cost_pr.sql` (đưa ra output), `mart/schema.yml`.

**Verify trên dữ liệu thật trước khi sửa** (2026-09-24, DB `new_product`,
`brand_etl = 3`, dữ liệu 27/05–23/09/2026, query read-only):
- 0 dòng `product_type` NULL; `'cosmetic'` (764 dòng) trùng khớp 100% với
  `view_stag_products.product_category = 'SAN PHAM'`, `'service'` không
  có dòng nào thuộc danh mục này.
- DV 22.495.927.000 + SP 159.070.000 = 22.654.997.000 = đúng tổng DS hiện
  có trong `report_marketing_ad_cost_pr_v2` (7.003 dòng) → thêm cột không
  đổi số dòng/tổng.
- Chuyển tiền (`ti-`/`to-`): 72 cặp service→service, 1 cặp
  cosmetic→cosmetic, chưa có cặp chuyển chéo DV↔SP; vẫn phải cộng đủ mọi
  dòng (kể cả âm) vì nếu có chuyển chéo thì DV/SP sẽ lệch dù tổng không đổi.

**Chưa build lại** — cần `dbt run --select func_report_marketing_ad_cost_pr+`
rồi kiểm: `SUM(dt::numeric) GROUP BY product_type WHERE type_data='DS'` khớp
số trên; `product_type IS NULL` với mọi `type_data <> 'DS'`.

### Thêm `product_category` — danh mục dịch vụ/sản phẩm — 2026-09-24

Theo yêu cầu người dùng (phục vụ biểu đồ cơ cấu doanh số theo dịch vụ/sản
phẩm). Lấy `view_stag_products.product_category` từ chính `sp` đã join sẵn
cho `ten_dv` — không thêm JOIN mới, không đổi số dòng.

- `int_frmacpr_erp_conv.sql`: thêm vào CTE `base` + 5 nhánh Lead/BK/BKHL/DC/TC;
  nhánh `Deal_cs` để `NULL`.
- `stg_frmacpr_doanh_so.sql`: thêm cho nhánh DS.
- `int_frmacpr_union.sql`: lấy thật từ ERP conv và DS, `NULL::text` ở FB/
  Google/TikTok/Inbox/Targets.
- `mart_report_marketing_ad_cost_pr.sql`, `mart/schema.yml`: đưa ra output,
  không COALESCE `'KXĐ'` (giống `product_type`).

**Lý do không dùng `his_service_type`** (cách Kangnam chia Phẫu thuật/Da liễu/
Nha khoa/...): query read-only 2026-09-24 (`new_product`, brand_etl=3) cho
thấy 99,30% DS Paris là `Odontology`, 0,70% là sản phẩm — cấp này không phân
biệt được gì. `product_category` tách được Niềng răng/Implant/Răng sứ/Nha khoa
khác/Sản phẩm. Lưu ý: `NHA KHOA KHÁC` chứa nhiều dịch vụ duy trì/khí cụ chỉnh
nha, và `NIỀNG RĂNG MẮC CÀI KHÁC` có lẫn "Niềng Răng Khay Trong Invisalign" —
nếu cần nhóm chính xác phải phân loại thêm theo `ten_dv`.

**Chưa build lại** — sau `dbt run --select func_report_marketing_ad_cost_pr+`
kiểm: tổng DS theo `product_category` khớp query trực tiếp trên
`stag_payment_transfer` (`SAN PHAM` = 159.070.000 cho 27/05–23/09/2026).
