# func_report_marketing_ad_cost_kn — Logic Model

Báo cáo chi phí & hiệu quả marketing Kangnam (bản refactor từ report gốc nhiều pass
"Pass 1 → Pass 15"). Output cuối cùng là bảng
`mart_report_marketing_ad_cost_kn` (alias `report_marketing_ad_cost_kn_v3`).

## 1. Sơ đồ luồng dữ liệu

```
stg_frmack_crm_base ─┐
stg_frmack_doanh_so ─┤
stg_frmack_inbox    ─┼──► int_frmack_union ──► int_frmack_region ──┐
stg_frmack_google   ─┤                                             │
(BK/HL dùng lại        │                                             ▼
 crm_base)     ─┘                                        mart_report_marketing_ad_cost_kn
                                                                     ▲
stg_frmack_fb_insight_v3 ──► int_frmack_fb_cost ──────────────────┘
```

## 2. Lớp `stg` (staging)

| Model | Nguồn | Vai trò |
|---|---|---|
| `stg_frmack_crm_base` | `stg_common_tongquan_khachhang` + `crm_lead` + `res_country_state` + `res_country` + `cs_ticket_api` | Bảng khách hàng gốc (CRM), dùng chung cho DC / Lead / TC / BK / HL. Tính `kenh`, `local_k`, `chi_nhanh_new`, `ngay_den_cua`/`ngay_tao`/`ngay_hl`, và **`ad_id`** = số được trích từ `cs_ticket_api.ad_id_value`. **Không có cột `page_name`** — cột này chỉ được sinh ra ở lớp `int`. |
| `stg_frmack_doanh_so` | `stag_payment_transfer` + `crm_lead` + ... | Doanh số (DS), cũng trích `ad_id` từ `cs_ticket_api`. |
| `stg_frmack_inbox` | `m_inbox_kangnam` | Dữ liệu inbox, đã có sẵn `page_name`, `page_id`, `campaign` (= `ten_ad`). |
| `stg_frmack_google` | `cp_google_kangnam` | Chi phí Google, không có khái niệm `page_name` (luôn `NULL`). |
| `stg_frmack_fb_insight_v1/v2/v3` | `cs_facebook_insight` | Chi phí quảng cáo Facebook. |
| `stg_frmack_cs_tickets` | `cs_ticket_api` (lọc `ticket_source IN ('Inbox Facebook','Inbox Facebook Out')`, `updated_at >= 2025-01-01`) | 1 dòng/ticket (rnk=1) để map `ticket_id → service_id`. **Không còn được dùng trong `mart`** (xem mục 5). |
| `stg_frmack_cs_services` | `cs_services_api` (lọc `service_type = 'Inbox Facebook'`, `detail IS NOT NULL`) | Map `service_id → service_name, page_id`. **Không còn được dùng trong `mart`** (xem mục 5). |

## 3. Lớp `int` (intermediate)

### `int_frmack_union` — UNION ALL 7 nguồn (DC, DS, Lead, Inbox, TC, GG, BK, HL)

Với các nguồn xuất phát từ **`stg_frmack_crm_base`** (DC, Lead, TC, BK, HL), `page_name`
và `campaign` được suy ra qua chuỗi join sau, trong 2 CTE dùng chung
`crm_base_with_page` (cho DC/Lead/TC/BK/HL) và `payment_with_page` (cho DS):

```
cb.ad_id
  → LEFT JOIN dim_camp_adset_ad  (theo ad_id)
  → LEFT JOIN dim_campaign       (theo ad_campaign_id) → campaign_name
  → page_code = split_part(campaign_name, '_', 2)
        CHỈ KHI cardinality(split '_') >= 9
              VÀ token đầu tiên IN var('all_brand_mkt_camp')
              (whitelist brand code, xem mục 7 — trước đây dùng blacklist
              "NOT ILIKE 'MIEN%'", đã đổi sang whitelist)
        (không có ELSE ⇒ các trường hợp khác page_code = NULL)
  → LEFT JOIN ucbt_page_config (theo page_code) → page_name
  → COALESCE(page_name, 'KXĐ'), COALESCE(campaign_name, 'KXĐ')
        ← luôn có giá trị, KHÔNG BAO GIỜ NULL ở bước này
```

**Quan trọng — filter ngày theo từng nhánh, KHÔNG filter trong CTE dùng chung:**
`crm_base_with_page`/`payment_with_page` chỉ chứa phần JOIN campaign, **không**
filter theo ngày. Mỗi nhánh UNION filter ngày bằng đúng field nghiệp vụ của nó
ở outer `WHERE`:

| Nhánh | `loai_ban_ghi` | Field ngày filter |
|---|---|---|
| DC | 2 | `ngay_den_cua` |
| DS | — | `ngay` (đã filter sẵn trong `payment_with_page`) |
| Lead | 1 | `ngay_tao` |
| TC | 2 | `ngay_den_cua` |
| BK (BKHL) | 2 | `ngay_tao` |
| HL | 2 | `ngay_hl` |

> ⚠️ Xem mục 6 — đây là chỗ từng có bug khiến khối `Lead` biến mất hoàn toàn.

Nguồn GG (Google) set cứng `page_name = NULL` (không có khái niệm page).

### `int_frmack_region` — chỉ tính thêm `tinh_noi`, `region`; **giữ nguyên** `page_name`
từ `int_frmack_union` (`r.*`), không đụng vào cột này.

## 4. Lớp `mart` — `mart_report_marketing_ad_cost_kn` (alias `report_marketing_ad_cost_kn_v3`)

3 stream UNION ALL, mỗi stream lấy `page` theo cách khác nhau:

| Stream | Điều kiện | Nguồn `page` |
|---|---|---|
| 1 — FB cost | từ `int_frmack_fb_cost` | `dim_page.page_name` theo `page_id` (`'N/A'` → `'KXĐ'`) |
| 2 — non-FB, `ticket_id ≠ 0` | từ `int_frmack_region` | `m.page_name` (campaign-based, đã tính ở `int_frmack_union`) |
| 3 — non-FB, `ticket_id = 0/NULL` | từ `int_frmack_region` | `COALESCE(m.page_name, 'KXĐ')` |

## 5. [Đã fix] `page_name` NULL với dữ liệu từ `stg_frmack_crm_base`

**Nguyên nhân (bản cũ):** Stream 2 của `mart_report_marketing_ad_cost_kn.sql` từng
bỏ qua `page_name` đã tính sẵn ở `int_frmack_union`, thay vào đó map lại qua
`stg_frmack_cs_tickets → stg_frmack_cs_services` (theo `ticket_id`), **không có
COALESCE fallback**. Pipeline này chỉ khớp khi ticket được Caresoft gắn nhãn đúng
là `ticket_source IN ('Inbox Facebook','Inbox Facebook Out')` và có `service_type
= 'Inbox Facebook'` — rất nhiều ticket hợp lệ (gọi điện, walk-in, ticket cũ trước
2025-01-01...) không thỏa, khiến `page` = NULL.

**Fix đã áp dụng:** Stream 1 và Stream 2 chuyển sang lấy `page` trực tiếp từ
`dim_page`/`m.page_name` (map theo `campaign_name` → `page_code` →
`ucbt_page_config`), bỏ hẳn phụ thuộc vào `stg_frmack_cs_tickets`/
`stg_frmack_cs_services` trong `mart`. Hai model stg này hiện không còn được
`ref()` ở đâu trong `mart` nữa.

## 6. [Đã fix] Khối `Lead` biến mất hoàn toàn

**Nguyên nhân:** Khi thêm CTE `crm_base_with_page` dùng chung cho 5 nhánh
(DC/Lead/TC/BK/HL), filter ngày bị đặt **bên trong CTE** và khoá cứng theo field
của nhánh DC:

```sql
-- BUG (đã sửa):
WITH crm_base_with_page as (
    SELECT cb.*, ...
    FROM {{ ref('stg_frmack_crm_base') }} cb
    ...
    WHERE cb.ngay_den_cua >= '{{ var("start_date") }}'::date   -- áp cho CẢ Lead/BK/HL
)
```

Theo `stg_common_tongquan_khachhang.sql`:

```sql
DATE(ecl.arrival_date + '07:00:00'::interval) AS Ngay_den_cua
...
WHEN ecl.arrival_date IS NULL AND ecl.type_crm_id = '1' THEN 'Lead'
```

Một bản ghi được phân loại `loai_ban_ghi = 1` (Lead) **luôn có `arrival_date
IS NULL`** (khách chưa đến cửa) ⇒ `ngay_den_cua IS NULL`. Vì `NULL >=
'2025-08-01'` không bao giờ `TRUE`, toàn bộ record Lead bị loại khỏi CTE
**trước khi** filter `loai_ban_ghi = 1` ở nhánh Lead kịp chạy → khối `Lead`
mất 100% khỏi `int_frmack_union`.

Cùng cơ chế cũng ảnh hưởng một phần nhánh **BK** (lọc theo `ngay_tao`, không
phải `ngay_den_cua`) và **HL** (lọc theo `ngay_hl`): booking/hẹn lịch mà khách
chưa đến cửa cũng bị rớt oan dù `ngay_tao`/`ngay_hl` nằm trong khoảng lọc.

**Fix đã áp dụng** (`int_frmack_union.sql`): bỏ filter ngày ra khỏi CTE dùng
chung, filter riêng theo field ngày đúng nghiệp vụ của từng nhánh ở outer
`WHERE` (xem bảng ở mục 3) — khớp lại với hành vi bản gốc trước refactor.

## 7. Chiều `actor` — token vị trí 8 của campaign name

Tách thêm cột `actor` (mã người thực hiện campaign) trong `mart`, lấy từ
**token vị trí 8** (1-based, tính từ trái) của campaign name theo convention
đặt tên Facebook: `{brand}_{page}_{local}_{chinhanh}_{nhomdichvu}_{muctieu}_
{funnel}_{actor}_{angle}...`. Dùng **đúng guard điều kiện** như `page_code`
(mục 3): chỉ tách khi `cardinality(split '_') >= 9` VÀ token đầu tiên
`IN {{ var('all_brand_mkt_camp') }}`; nếu không thỏa → `NULL`. Không join
sang seed `ucbt_camp_actor.csv` (name/email/actor_code) — cột `actor` chỉ
chứa mã thô.

**[Đổi guard] Blacklist `MIEN%` → whitelist `all_brand_mkt_camp`:** guard
điều kiện dùng để nhận diện naming convention mới (9+ token) trước đây là
`token đầu KHÔNG ILIKE 'MIEN%'` (blacklist — nhận mọi campaign trừ tiền tố
`MIEN`). Đã đổi thống nhất sang whitelist qua dbt var:

```yaml
# dbt_project.yml
vars:
  all_brand_mkt_camp: "('kgs','kbs','kwl','kwn','kdt','kal','prd','hh','vde')"
```

Áp dụng cho **toàn bộ** chỗ dùng guard này (không chỉ `actor`):
`page_code`, `cn`, `nhom_dv`, `nhom_dv2` ở `int_frmack_union.sql`,
`stg_frmack_inbox.sql`, `stg_frmack_fb_insight_v2.sql`. Vì đây là whitelist
chặt hơn blacklist cũ, **campaign nào có token đầu không nằm trong 9 brand
code trên** (kể cả không phải `MIEN%`) sẽ chuyển từ "có parse được" (dưới
guard cũ) sang `NULL` (dưới guard mới) cho `page_code`/`cn`/`nhom_dv`/
`nhom_dv2`/`actor_code`.

## 8. Chiều `account_fb` cho non-FB-cost stream (DC/DS/Lead/TC/BK/HL/Inbox)

Trước đây `account_fb` (tên Ad Account Facebook) **chỉ có giá trị ở Stream 1**
(FB Cost); Stream 2/3 trong `mart` luôn hard-code `NULL::text AS account_fb`.
Đã bổ sung để `account_fb` được suy ra nhất quán ở mọi stream, tham khảo
logic từ branch cũ `func_report_marketing_ad_cost_kn_2026-06-30_actor_ad`:

| Nguồn | Chuỗi join lấy `account_fb` |
|---|---|
| DC/DS/Lead/TC/BK/HL | `int_frmack_union.crm_base_with_page`/`payment_with_page`: `cb.ad_id → dim_camp_adset_ad (account_id) → dim_account (account_name)`. Dùng lại đúng `dcaa` đã join sẵn cho `page_code`/`campaign_name`, chỉ thêm 1 `LEFT JOIN dim_account`. |
| Inbox | `stg_frmack_inbox`: **không có** `ad_id_value`/Caresoft ticket trong `m_inbox_kangnam`, nên dùng cột có sẵn `"id chiến dịch"` → `dim_campaign (ad_account_id) → dim_account (account_name)`. Khác cơ chế với nhóm CRM ở trên — đã xác nhận với người dùng trước khi áp dụng. |
| FB Cost (Stream 1) | Không đổi — vẫn lấy trực tiếp từ `cs_facebook_insight.ad_account_name` (qua `stg_frmack_fb_insight_v2`). |
| Google (GG) | Luôn `NULL` — cột `account_fb` mang nghĩa "Facebook Ad Account", Google có khái niệm account riêng (`cp_google_kangnam.account`) nhưng không map vào đây. |

Ở `mart`, Stream 2 expose `account_fb` thô (có thể `NULL`); Stream 3 dùng
`COALESCE(account_fb, 'KXĐ')` — đồng nhất với cách xử lý `page`/`actor` ở
stream này.

| Nguồn | Nơi tách `actor_code` | Ghi chú |
|---|---|---|
| DC/DS/Lead/TC/BK/HL | `int_frmack_union.crm_base_with_page`/`payment_with_page`, từ `dc.campaign_name` (join qua `dim_camp_adset_ad`→`dim_campaign`) | Cùng CTE, cùng guard với `page_code` |
| Inbox | `stg_frmack_inbox`, từ `mik."tên chiến dịch"` | Tách ngay tại `stg`, giống cách `page_code` được tách ở đây |
| FB Cost (Stream 1) | `stg_frmack_fb_insight_v2`, từ `f.ad_campaign_name` → truyền qua `stg_frmack_fb_insight_v3` → `int_frmack_fb_cost` | `stg_frmack_fb_insight_v1` (nguồn legacy) luôn `actor_code = NULL` vì không có parse campaign name |
| Google (GG) | — | Luôn `NULL`, Google không theo convention đặt tên này |

Ở `mart`, Stream 1 & 2 expose `actor` thô (có thể `NULL`); Stream 3 (non-FB,
`ticket_id = 0/NULL`) dùng `COALESCE(actor_code, 'KXĐ')` để đồng nhất với
cách xử lý `page`/`page_id` ở stream này.
