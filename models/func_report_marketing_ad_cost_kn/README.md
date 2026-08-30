# func_report_marketing_ad_cost_kn — Logic Model

Báo cáo chi phí & hiệu quả marketing Kangnam (bản refactor từ report gốc nhiều pass
"Pass 1 → Pass 15"). Output cuối cùng là bảng
`mart_report_marketing_ad_cost_kn` (alias `report_marketing_ad_cost_kn_v3`).

## 1. Sơ đồ luồng dữ liệu

```
stg_frmack_crm_base ─┐
stg_frmack_doanh_so ─┤
stg_frmack_inbox    ─┤
stg_frmack_google   ─┼──► int_frmack_union ──► int_frmack_region ──┐
stg_frmack_deal     ─┤                                             │
(BK/HL dùng lại        │                                             ▼
 crm_base)     ─┘                                        mart_report_marketing_ad_cost_kn
                                                                     ▲
stg_frmack_cs_tickets ──► stg_frmack_deal                          │
stg_frmack_fb_insight_v3 ──► int_frmack_fb_cost ────────────────────┘
```

## 2. Lớp `stg` (staging)

| Model | Nguồn | Vai trò |
|---|---|---|
| `stg_frmack_crm_base` | `stg_common_tongquan_khachhang` + `crm_lead` + `res_country_state` + `res_country` + `cs_ticket_api` + `stg_dv_khach_hang_quan_tam` | Bảng khách hàng gốc (CRM), dùng chung cho DC / Lead / TC / BK / HL. Tính `kenh`, `local_k`, `chi_nhanh_new`, `ngay_den_cua`/`ngay_tao`/`ngay_hl`, **`ad_id`** = số được trích từ `cs_ticket_api.ad_id_value`, và **`nhom_dv_KH_quan_tam`** (xem mục 11). **Không có cột `page_name`** — cột này chỉ được sinh ra ở lớp `int`. |
| `stg_frmack_doanh_so` | `stag_payment_transfer` + `crm_lead` + `stg_dv_khach_hang_quan_tam` + ... | Doanh số (DS), cũng trích `ad_id` từ `cs_ticket_api` và **`nhom_dv_KH_quan_tam`** (join `crm_id`/`brand_etl` trực tiếp, không qua `stg_frmack_crm_base` — xem mục 11). |
| `stg_frmack_inbox` | `m_inbox_kangnam` | Dữ liệu inbox, đã có sẵn `page_name`, `page_id`, `campaign` (= `ten_ad`). |
| `stg_frmack_google` | `cp_google_kangnam` | Chi phí Google, không có khái niệm `page_name` (luôn `NULL`). |
| `stg_frmack_fb_insight_v1/v2/v3` | `cs_facebook_insight` | Chi phí quảng cáo Facebook. |
| `stg_frmack_cs_tickets` | `cs_ticket_api` (lọc `ticket_source IN ('Inbox Facebook','Inbox Facebook Out')`, `updated_at >= 2025-01-01`) | 1 dòng/ticket (rnk=1). Map `ticket_id → service_id`; trích `sdt` (số điện thoại, từ `requester.phone_no`), `ad_id` (từ `ad_id_value`) — dùng bởi `stg_frmack_deal` (xem mục 9) — và **`nhom_dv_chinh_cs`** (từ `custom_fields`, xem mục 12). `service_id` **không còn được dùng trong `mart`** (xem mục 5), chỉ `sdt`/`ad_id` còn dùng. |
| `stg_frmack_cs_services` | `cs_services_api` (lọc `service_type = 'Inbox Facebook'`, `detail IS NOT NULL`) | Map `service_id → service_name, page_id`. **Không còn được dùng trong `mart`** (xem mục 5). |
| `stg_frmack_deal` | `stg_frmack_cs_tickets` + `dim_camp_adset_ad` + `dim_campaign` + `dim_account` + `ucbt_page_config` | Khối "DealCS": ticket Caresoft có gắn FB ad (`ad_id NOT NULL`), `metric` = số điện thoại (`sdt`). Xem mục 9. |

## 3. Lớp `int` (intermediate)

### `int_frmack_union` — UNION ALL 9 nguồn (DC, DS, Lead, Inbox, TC, GG, BK, HL, DealCS)

Với các nguồn xuất phát từ **`stg_frmack_crm_base`** (DC, Lead, TC, BK, HL) và
`stg_frmack_doanh_so` (DS), `page_name` được suy ra qua **2 path, có thứ tự ưu
tiên**, trong 2 CTE dùng chung `crm_base_with_page` (cho DC/Lead/TC/BK/HL) và
`payment_with_page` (cho DS) — xem thêm mục 13:

```
Path A (ưu tiên) — cb.ticket_id
  → LEFT JOIN stg_frmack_cs_tickets (rnk=1, theo ticket_id) → service_id
  → LEFT JOIN stg_frmack_cs_services (dedup rn=1 theo service_id) → service_name
        page_name_ticket = service_name

Path B (fallback, khi Path A NULL) — cb.ad_id
  → LEFT JOIN dim_camp_adset_ad  (theo ad_id)
  → LEFT JOIN dim_campaign       (theo ad_campaign_id) → campaign_name
  → page_code = split_part(campaign_name, '_', 2)
        CHỈ KHI token đầu tiên IN var('all_brand_mkt_camp')
              (whitelist brand code, xem mục 7 — trước đây dùng blacklist
              "NOT ILIKE 'MIEN%'", đã đổi sang whitelist)
        [Đã bỏ guard `cardinality(split '_') >= 9`] Guard này chỉ còn check
              token đầu tiên IN whitelist — điều kiện cardinality từng có
              trước đây (yêu cầu ≥9 token) đã bị bỏ khỏi code ở mọi chỗ dùng
              guard này (`int_frmack_union`, `stg_frmack_inbox`,
              `stg_frmack_fb_insight_v2`, `stg_frmack_deal`). Đã xác nhận đây
              là chủ ý — giữ nguyên, không khôi phục lại check cardinality.
        (không có ELSE ⇒ các trường hợp khác page_code = NULL)
  → LEFT JOIN ucbt_page_config (theo page_code) → page_name

page_name (cuối cùng) = COALESCE(page_name_ticket, page_name, 'KXĐ')
campaign  (cuối cùng) = COALESCE(campaign_name, 'KXĐ')
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

**Fix đã áp dụng (tại thời điểm đó):** Stream 1 và Stream 2 chuyển sang lấy
`page` trực tiếp từ `dim_page`/`m.page_name` (map theo `campaign_name` →
`page_code` → `ucbt_page_config`), bỏ hẳn phụ thuộc vào
`stg_frmack_cs_tickets`/`stg_frmack_cs_services` trong `mart`.

> ⚠️ **[Cập nhật — xem mục 13]** Phụ thuộc vào `stg_frmack_cs_tickets`/
> `stg_frmack_cs_services` đã được **thêm lại**, nhưng lần này làm **path ưu
> tiên** (không phải path duy nhất, không có fallback như bản cũ từng gây
> bug) — đặt ở lớp `int_frmack_union` (CTE dùng chung), không phải ở `mart`.
> Path campaign_name/`ucbt_page_config` mô tả ở mục 3 vẫn còn nguyên, đóng
> vai trò **fallback** khi path ticket không resolve được.

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
(mục 3): chỉ tách khi token đầu tiên
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

| Nguồn | Nơi tách `actor_code` | Ghi chú |
|---|---|---|
| DC/DS/Lead/TC/BK/HL | `int_frmack_union.crm_base_with_page`/`payment_with_page`, từ `dc.campaign_name` (join qua `dim_camp_adset_ad`→`dim_campaign`) | Cùng CTE, cùng guard với `page_code` |
| Inbox | `stg_frmack_inbox`, từ `mik."tên chiến dịch"` | Tách ngay tại `stg`, giống cách `page_code` được tách ở đây |
| FB Cost (Stream 1) | `stg_frmack_fb_insight_v2`, từ `f.ad_campaign_name` → truyền qua `stg_frmack_fb_insight_v3` → `int_frmack_fb_cost` | `stg_frmack_fb_insight_v1` (nguồn legacy) luôn `actor_code = NULL` vì không có parse campaign name |
| Google (GG) | — | Luôn `NULL`, Google không theo convention đặt tên này |
| DealCS | `stg_frmack_deal`, từ `dc.campaign_name` (cùng chuỗi join `dim_camp_adset_ad`→`dim_campaign` như nhóm CRM) | Xem mục 9 |

Ở `mart`, cả 3 stream đều dùng `COALESCE(actor_code, 'KXĐ')` — `actor` không
bao giờ `NULL` ở bảng cuối (trước đây Stream 1 & 2 expose `actor` thô, có thể
`NULL`; đã đồng nhất theo cách xử lý `page`/`page_id`/`account_fb` ở Stream 3).

## 8. Chiều `account_fb` cho non-FB-cost stream (DC/DS/Lead/TC/BK/HL/Inbox/DealCS)

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
`COALESCE(account_fb, 'KXĐ')` — đồng nhất với cách xử lý `page` ở stream này.
(`actor` thì nay được `COALESCE(..., 'KXĐ')` ở **cả 3 stream**, xem mục 7 —
khác với `account_fb`/`page` vốn chỉ coalesce ở Stream 3.)

## 9. Khối `DealCS` — ticket Caresoft có gắn FB ad, metric = số điện thoại

Thêm nhánh UNION thứ 9 vào `int_frmack_union` (`stg_frmack_deal.sql`), tách
từ `cs_ticket_api.requester` (dữ liệu dạng
`{"id":..., "username":..., "email":..., "phone_no": "0386461784", ...}`)
và `cs_ticket_api.ad_id_value`:

```
cs_ticket_api (ticket_source IN ('Inbox Facebook','Inbox Facebook Out'), updated_at >= 2025-01-01)
  → stg_frmack_cs_tickets (rnk=1 mỗi ticket_id)
        sdt   = SUBSTRING(requester   FROM '"phone_no":\s*"([^"]+)"')
        ad_id = SUBSTRING(ad_id_value FROM '\d+')
  → stg_frmack_deal
        WHERE sdt IS NOT NULL AND ad_id IS NOT NULL AND ngay_tao >= start_date
        ad_id → dim_camp_adset_ad → dim_campaign (campaign_name) → dim_account (account_fb)
        campaign_name → page_code/actor_code/nhom_dv_muc_tieu_code (cùng guard,
              vị trí 2/8/5, xem mục 3, 7 & 10)
        page_code → ucbt_page_config → page_name (KHÔNG dùng cs_services — xem mục 5)
  → int_frmack_union (nhánh DealCS, cùng schema 19 cột như các nhánh khác)
```

Đặc điểm riêng của khối này:
- `type_data = 'DealCS'`, `nguon = 'MD - Facebook'`, `nhom_nguon = 'Facebook'`, `kenh = 'FB'`.
- **`metric` = số điện thoại (`sdt`)**, không phải chi phí/doanh số/lead count như các khối khác.
- `local_k` luôn hard-code `'KXĐ'` vì ticket Caresoft không có vùng (region) của ad impression — không suy ra được tỉnh/thành như FB Cost.
- `chi_nhanh`/`quoc_gia` chỉ suy ra được VIỆT KIỀU/QUỐC TẾ (từ token `cn` vị trí 3 của campaign name) hoặc `'KXĐ'`/`'Việt Nam'` mặc định — không có mapping chi nhánh nội địa chi tiết như CRM base.
- `ticket_id` là ticket thật từ `cs_ticket_api` (không phải `0`) nên tự động rơi vào **Stream 2** của `mart` (`WHERE m.ticket_id <> 0`) — không cần sửa `mart_report_marketing_ad_cost_kn.sql`.
- Tham khảo logic từ branch cũ `func_report_marketing_ad_cost_kn_2026-06-30_actor_ad` (`stg_frmack_deal.sql`, `type_data = 'Deal'`), nhưng đổi `type_data` thành `'DealCS'` và đổi cách map `page_name` sang `page_code + ucbt_page_config` (nhất quán với mục 5) thay vì `cs_services`.

## 10. Chiều `nhom_dv_muc_tieu` — token vị trí 5 của campaign name, tra qua `campaign_name_split`

Tách thêm cột `nhom_dv_muc_tieu` trong `mart`. Gồm 2 bước:

1. **Tách mã thô** `nhom_dv_muc_tieu_code` = **token vị trí 5** của campaign
   name (`{brand}_{page}_{local}_{chinhanh}_{nhomdichvu}_{muctieu}_{funnel}_
   {actor}_{angle}...`, xem mục 7) — cùng guard với `page_code`/`actor_code`.
2. **Tra cứu chính xác qua `campaign_name_split`** (ở `mart`, cùng cơ chế
   lookup đã dùng cho cột `nhom_dv` ở Inbox/FB Cost/DealCS):
   ```sql
   LEFT JOIN LATERAL (
       SELECT nhom_dv FROM campaign_name_split
       WHERE UPPER(campain_name_split) = UPPER(<nhom_dv_muc_tieu_code>) LIMIT 1
   ) cns_mt ON TRUE
   ```
   Giá trị cuối cùng của `nhom_dv_muc_tieu` = `cns_mt.nhom_dv` (không phải mã
   thô) — join này áp dụng đồng nhất cho **cả 3 stream** trong `mart.sql`,
   không phải ở lớp `stg`/`int`.

Cột này **độc lập** với cột `nhom_dv` đã có sẵn trong report (vốn cũng tra
`campaign_name_split` nhưng dùng mã nguồn khác: `nhom_dv_qc`/`nhom_dv`+`nhom_dv2`
fallback/`nhom_dv_raw` tùy nguồn — xem bảng dưới; với DC/DS/Lead/TC/BK/HL,
`nhom_dv` đến từ CRM/product, hoàn toàn không liên quan campaign name).

| Nguồn | Nơi tách `nhom_dv_muc_tieu_code` (mã thô, trước khi tra `campaign_name_split` ở mart) | Ghi chú |
|---|---|---|
| DC/DS/Lead/TC/BK/HL | `int_frmack_union.crm_base_with_page`/`payment_with_page`, từ `dc.campaign_name` | **Mới hoàn toàn** — các khối CRM trước đây không có giá trị nào lấy từ campaign name cho vị trí này. |
| Inbox | `stg_frmack_inbox`, từ `mik."tên chiến dịch"` | Mã thô tách riêng — không đụng vào `nhom_dv_qc`/`nhom_dv` hiện có (vốn có fallback về token vị trí 2 khi guard fail, còn `nhom_dv_muc_tieu_code` thì NULL khi guard fail, giống `page_code`/`actor_code`; và `nhom_dv_qc` tra `campaign_name_split` riêng ở `stg`, không phải ở `mart`). |
| FB Cost (Stream 1) | `stg_frmack_fb_insight_v2`, từ `f.ad_campaign_name` → truyền qua `stg_frmack_fb_insight_v3` → `int_frmack_fb_cost` | `stg_frmack_fb_insight_v1` (nguồn legacy) luôn `nhom_dv_muc_tieu_code = NULL`. Không đụng vào `nhom_dv`/`nhom_dv2` hiện có (v2 tính 2 cột đó riêng, tra `campaign_name_split` ở `int_frmack_fb_cost`, không phải ở `mart`). |
| Google (GG) | — | Luôn `NULL`, Google không theo convention đặt tên này. |
| DealCS | `stg_frmack_deal`, từ `dc.campaign_name` | Tái sử dụng trực tiếp cột nội bộ `nhom_dv_raw` đã có sẵn (vốn dùng để tra `nhom_dv_sys` ngay tại `stg`), expose thêm ra ngoài với tên `nhom_dv_muc_tieu_code`. |

Ở `mart`, Stream 1 & 2 expose `cns_mt.nhom_dv` thô (có thể `NULL` — khi mã
token 5 không khớp guard, hoặc khớp guard nhưng không có dòng nào trong
`campaign_name_split` map tới); Stream 3 dùng `COALESCE(cns_mt.nhom_dv,
'KXĐ')` — đồng nhất với cách xử lý `page`/`account_fb` ở stream này (khác với
`actor`, nay coalesce ở cả 3 stream — mục 7).

## 11. Chiều `nhom_dv_KH_quan_tam` — nhóm dịch vụ khách hàng quan tâm (từ `crm_line` đầu tiên)

Tách thêm cột `nhom_dv_KH_quan_tam`, lấy từ
`stg_dv_khach_hang_quan_tam.first_product_group` — `product_group` của bản ghi
`crm_line` **đầu tiên** (`cus_bk_line_order = 1`, sắp theo
`cline_created_date`, tie-break `cline_id`) của khách hàng đó, không phải
nhóm dịch vụ mới nhất.

**[Đổi 2026-08-05]** `product_group` giờ lấy **trực tiếp từ
`view_stag_products.product_group`** (đã bake sẵn CASE WHEN trong view, khớp
100% với DB sandbox `staging_sci` — xem `common/knowledge.md` mục 8), thay vì
`stg_dv_khach_hang_quan_tam` tự tính CASE WHEN riêng. Nhãn đổi từ dạng cũ có
tiền tố số (`1.MẮT`, `8.BEAUTY & SPA`...) sang đúng nhãn `view_stag_products`:
`PTTM MẮT`, `PTTM MŨI`, `PTTM HÀM MẶT`, `PTTM NGỰC/MÔNG`, `CẤY MỠ`,
`BEAUTY & SPA`, `BÉO ĐA CHUYÊN KHOA`, `WELLNESS`, `DỊCH VỤ KHÁC`, `SẢN PHẨM`
(nhóm mới, trước đây không có — sản phẩm vật lý thay vì dịch vụ). Điều kiện
phụ `category_source_code='MBS'` (định tuyến theo nguồn khách) đã **bỏ** —
sandbox không dùng điều kiện này.

```
stg_dv_khach_hang_quan_tam (ref, ephemeral)
  crm_id, brand_etl, first_product_group
        │
        ├─ LEFT JOIN ON dkq.crm_id = cl.id  AND dkq.brand_etl = cl.brand_etl
        │  stg_frmack_crm_base.x   (cl = crm_lead đã JOIN ở CTE x)
        │        │
        │        ▼ cb.* (propagate qua toàn bộ chuỗi CTE x → kh → SELECT cuối)
        │  int_frmack_union.crm_base_with_page  (cbwp.nhom_dv_KH_quan_tam)
        │        ▼ nhánh DC/Lead/TC/BK/HL
        │
        └─ LEFT JOIN ON dkq.crm_id = cl3.id AND dkq.brand_etl = cl3.brand_etl
           stg_frmack_doanh_so.a   (cl3 = crm_lead đã JOIN ở CTE a)
                 ▼ a.nhom_dv_KH_quan_tam (propagate qua SELECT cuối)
           int_frmack_union.payment_with_page  (pwp.nhom_dv_KH_quan_tam)
                 ▼ nhánh DS

int_frmack_union → int_frmack_region → mart (Stream 2/3)
```

**Populate cho DC/Lead/TC/BK/HL/DS** — 6 nhánh có liên kết `crm_lead`
(`stg_frmack_crm_base` cho 5 nhánh đầu qua CTE dùng chung `crm_base_with_page`;
`stg_frmack_doanh_so` cho DS, join `crm_lead` trực tiếp — không qua
`stg_frmack_crm_base` nhưng vẫn có `crm_id`/`brand_etl` để join
`stg_dv_khach_hang_quan_tam` độc lập). Các nhánh còn lại **không có liên kết
CRM** nên `nhom_dv_KH_quan_tam` luôn `NULL` ngay từ `int_frmack_union`:

| Nguồn | `nhom_dv_KH_quan_tam` ở `int_frmack_union` | Lý do |
|---|---|---|
| DC/Lead/TC/BK/HL | `cbwp.nhom_dv_KH_quan_tam` (từ `crm_base_with_page`, join qua `stg_frmack_crm_base`) | Có `crm_id`/`brand_etl` (từ `crm_lead` đã JOIN trong `stg_frmack_crm_base.x`) |
| DS | `pwp.nhom_dv_KH_quan_tam` (từ `payment_with_page`, join qua `stg_frmack_doanh_so`) | Có `crm_id`/`brand_etl` (từ `crm_lead` đã JOIN trực tiếp trong `stg_frmack_doanh_so.a`, **không** qua `stg_frmack_crm_base`) |
| Inbox | `NULL` | Từ `m_inbox_kangnam`, không có liên kết CRM |
| GG | `NULL` | Từ `cp_google_kangnam`, không có khái niệm khách hàng CRM |
| DealCS | `NULL` | Từ `cs_ticket_api` qua `stg_frmack_cs_tickets`/`stg_frmack_deal`, không qua CRM |

Ở `mart`: Stream 1 (FB Cost, từ `int_frmack_fb_cost` — hoàn toàn không liên
quan `crm_base`) expose `NULL::text` cứng. Stream 2 & 3 (từ
`int_frmack_region`) dùng `COALESCE(m.nhom_dv_KH_quan_tam, 'KXĐ')` — đồng
nhất với cách xử lý `actor` (mục 7), khác với `page`/`account_fb`/
`nhom_dv_muc_tieu` (vốn chỉ coalesce ở Stream 3, để raw `NULL` ở Stream 2).

## 12. Cột `nhom_dv_chinh_cs` — "Nhóm dịch vụ chính" từ `custom_fields` của Caresoft ticket

Thêm cột `nhom_dv_chinh_cs` ở `stg_frmack_cs_tickets`, lấy từ trường
`custom_fields` của `cs_ticket_api` — một JSON array dạng text, mỗi phần tử
có cấu trúc `{"code", "id", "label", "type", "value"}`, ví dụ:

```json
[{"code": null, "id": 9790, "label": "Phân loại công việc", "type": "Single drop-down list", "value": null},
 {"code": null, "id": 9791, "label": "Nhân viên seeding", "type": "Single drop-down list", "value": null}]
```

`nhom_dv_chinh_cs` = `value` của phần tử có `id = 9794` (label thực tế trong
dữ liệu: **"Nhóm dịch vụ chính"**). Cách tách:

```sql
LEFT JOIN LATERAL (
    SELECT elem ->> 'value' AS nhom_dv_chinh_cs
    FROM jsonb_array_elements(cta.custom_fields::jsonb) AS elem
    WHERE (elem ->> 'id')::int = 9794
    LIMIT 1
) ndc ON TRUE
```

Dùng `LATERAL ... LIMIT 1` (không unnest trực tiếp trong SELECT list) để
không nhân dòng — mỗi ticket chỉ có tối đa 1 phần tử `id = 9794` trong
`custom_fields`, nhưng cách viết an toàn cho cả trường hợp trùng `id`. Với
`brand_id = 1` + điều kiện lọc hiện có (`updated_at >= 2025-01-01`,
`ticket_source IN ('Inbox Facebook','Inbox Facebook Out')`), `custom_fields`
luôn là JSON array hợp lệ (không `NULL`/`'NaN'`) nên không cần guard trước
khi `::jsonb`.

Cột này **chưa được propagate** sang `stg_frmack_deal`/`int_frmack_union`/
`mart` — hiện chỉ có ở `stg_frmack_cs_tickets`.

## 13. `page_name` cho DC/DS/Lead/TC/BK/HL — ưu tiên path `ticket_id`, fallback `campaign_name`

**Vấn đề:** Path `campaign_name` (mục 3) chỉ resolve được `page` khi ticket có
`ad_id` join được xuyên suốt `dim_camp_adset_ad → dim_campaign` **và**
campaign đặt tên đúng convention 9+ token với brand code hợp lệ. Rất nhiều
Lead/DC/TC/BK/HL hợp lệ không thỏa 1 trong 2 điều kiện này (không có `ad_id`,
hoặc `ad_id` không map được, hoặc campaign cũ/đặt tên sai convention) →
`page` = `'KXĐ'` dù thực tế ticket Caresoft của khách hàng đó **có** gắn với
1 page cụ thể qua `service_id`.

**Thêm path ưu tiên** (dùng lại đúng cơ chế đã có ở `mms.service_name` từ bản
trước khi bị bỏ ở mục 5, nhưng lần này **có fallback** thay vì thay thế hoàn
toàn):

```
cb.ticket_id (có sẵn trong stg_frmack_crm_base/stg_frmack_doanh_so, từ crm_lead.ticket_id)
  → LEFT JOIN stg_frmack_cs_tickets (subquery WHERE rnk = 1) theo ticket_id → service_id
  → LEFT JOIN stg_frmack_cs_services (subquery dedup ROW_NUMBER PARTITION BY
        service_id ORDER BY created_at DESC, rn = 1) theo service_id
  → page_name_ticket = service_name
        (service_name trong stg_frmack_cs_services CHÍNH LÀ tên page — không
        cần tra thêm qua page_id/ucbt_page_config/dim_page)
```

Cả 2 join đều **1:1 theo key** (`stg_frmack_cs_tickets` unique theo
`ticket_id` nhờ `rnk=1`; `stg_frmack_cs_services` unique theo `service_id`
nhờ `rn=1`) nên không có rủi ro nhân dòng (fan-out) khi thêm vào CTE dùng
chung `crm_base_with_page`/`payment_with_page`.

**Công thức cuối cùng** ở cả 6 nhánh (DC/DS/Lead/TC/BK/HL):

```sql
COALESCE(page_name_ticket, <page_name từ path campaign_name>, 'KXĐ')
```

Path `campaign_name` (mục 3) **không bị xoá** — vẫn chạy nguyên vẹn, chỉ lùi
xuống làm fallback khi `page_name_ticket IS NULL` (ticket không có/không map
được `service_id`, hoặc `service_id` không có trong `stg_frmack_cs_services`).

**Vì sao không lặp lại bug ở mục 5:** Bug cũ là do path `ticket_id →
service_id` là path **duy nhất** và **không có fallback** — khi ticket không
thoả điều kiện lọc của `stg_frmack_cs_tickets`/`stg_frmack_cs_services`
(`ticket_source`, `service_type`, `updated_at >= 2025-01-01`...), `page` rơi
thẳng xuống NULL. Lần này path đó chỉ là **ưu tiên đầu tiên**; khi nó NULL,
COALESCE rơi xuống path `campaign_name` đã có sẵn (mục 3) trước khi mới rơi
xuống `'KXĐ'` — không có trường hợp nào bị mất `page` so với hành vi trước
khi thêm thay đổi này.

**Impact đo được** (dữ liệu thật, `date >= '2026-07-01'`, đếm số dòng
`campaign = 'KXĐ'` — tức path campaign_name fail — nhưng `page <> 'KXĐ'` —
tức được path ticket cứu):

| type_data | total_rows | page = 'KXĐ' (sau fix) | resolved qua path ticket |
|---|---|---|---|
| DC | 10014 | 5956 | 885 |
| DS | 11280 | 7199 | 950 |
| Lead | 8603 | 2510 | 838 |
| TC | 6467 | 3990 | 557 |
| BKHL | 11727 | 6725 | 943 |
| HL | 23092 | 13422 | 2896 |

Vẫn còn nhiều dòng `'KXĐ'` sau fix — tức là ticket của các dòng đó **cũng**
không map được `service_id`/`service_name` (ví dụ ticket không phải nguồn
`Inbox Facebook`/`Inbox Facebook Out`, `updated_at` trước 2025-01-01, hoặc
không có `ticket_id` liên kết) **và** campaign cũng không parse được — không
phải lỗi của thay đổi này, mà là giới hạn dữ liệu nguồn ở cả 2 path.

Cột `page_id` (khác với `page_name`) **không đổi** — vẫn chỉ lấy từ
`page_code` (path campaign_name), path ticket không có khái niệm `page_id`
tương ứng để expose (chỉ có `service_name`, không có ID Facebook Page thô).

## 14. Chiều `nhom_dv_chinh_booking` — nhóm dịch vụ chính của booking (từ `common/stg_booking_nhom_dich_vu_chinh`)

Thêm cột `nhom_dv_chinh_booking`, nguồn lấy từ model dùng chung
`{{ ref('stg_booking_nhom_dich_vu_chinh') }}` (`data_serving/models/common/`
— xem `LOGIC.md`/`knowledge.md` ở đó).

**[Đổi 2026-08-05] Model common đã khớp lại logic theo `view_stag_crm_lead_first_product_group`
bên DB sandbox** (`staging_sci` — xem `common/knowledge.md` mục 8): bỏ 3 tầng
ưu tiên cũ, chuyển sang **1 nguồn duy nhất** (cline có `cln.id` nhỏ nhất
trong booking), `nhom_dich_vu_chinh` = `view_stag_products.product_group`
(nhãn **đã phân nhóm sẵn**: `PTTM MẮT`, `PTTM MŨI`, `PTTM HÀM MẶT`,
`PTTM NGỰC/MÔNG`, `CẤY MỠ`, `BEAUTY & SPA`, `BÉO ĐA CHUYÊN KHOA`, `WELLNESS`,
`DỊCH VỤ KHÁC`, `SẢN PHẨM`).

Vì giá trị đã là nhãn phân nhóm sẵn, CASE ở `stg_frmack_crm_base`/
`stg_frmack_doanh_so` giờ chỉ cần **so trực tiếp**, không cần `his_service_type`
hay ILIKE nữa:

```sql
CASE
    WHEN sbn.nhom_dich_vu_chinh IS NULL THEN NULL
    WHEN sbn.nhom_dich_vu_chinh = 'BEAUTY & SPA' THEN '8.BEAUTY & SPA'
    WHEN sbn.nhom_dich_vu_chinh = 'PTTM HÀM MẶT' THEN '3.HÀM MẶT/NHA KHOA'
    WHEN sbn.nhom_dich_vu_chinh = 'WELLNESS' THEN '9.WELLNESS'
    WHEN sbn.nhom_dich_vu_chinh = 'BÉO ĐA CHUYÊN KHOA' THEN '7.BÉO ĐA CHUYÊN KHOA'
    WHEN sbn.nhom_dich_vu_chinh = 'PTTM MẮT' THEN '1.MẮT'
    WHEN sbn.nhom_dich_vu_chinh = 'PTTM MŨI' THEN '2.MŨI'
    WHEN sbn.nhom_dich_vu_chinh = 'CẤY MỠ' THEN '5.CẤY MỠ'
    WHEN sbn.nhom_dich_vu_chinh = 'PTTM NGỰC/MÔNG' THEN '4.NGỰC/MÔNG'
    ELSE '6.DỊCH VỤ KHÁC'
END AS nhom_dv_chinh_booking
```

(`'SẢN PHẨM'` rơi vào `ELSE → '6.DỊCH VỤ KHÁC'`, không có bucket riêng ở đây.)

**[Lịch sử]** 2 bản trước đó (không còn dùng, chỉ ghi lại để hiểu quá trình):
(1) bản đầu dùng `business_line` tính sẵn qua text-match `UPPER(TRIM(product_category))`
— sai vì text-match fail với nhiều category hợp lệ; (2) bản thứ 2 sửa
`business_line`/`his_service_type` sang join theo ID
(`product_category_id → stag_products_dbt.product_ctg_id`) nhưng vẫn giữ 3
tầng ưu tiên cũ + ILIKE trên text — đã bỏ hẳn khi khớp lại theo sandbox (bản
hiện tại), vì sandbox chỉ dùng 1 nguồn duy nhất và không cần ILIKE (giá trị
đã là nhãn phân nhóm sẵn).

Đã verify khớp sandbox trên dữ liệu thật (doanh số tháng 7/2026, so theo
`stg_dv_khach_hang_quan_tam` — cùng cơ chế `product_group`, xem
`common/knowledge.md` mục 8): DỊCH VỤ KHÁC và WELLNESS khớp tuyệt đối 100%,
các nhóm còn lại trong khoảng 99.8–101.9%.

Join **cùng cơ chế** với `nhom_dv_KH_quan_tam` (mục 11) — theo `crm_id`/
`brand_etl` — vào `stg_frmack_crm_base` (DC/Lead/TC/BK/HL, qua `cl.id`) và
riêng vào `stg_frmack_doanh_so` (DS, qua `cl3.id`, không qua
`stg_frmack_crm_base`), rồi propagate qua `int_frmack_union` →
`int_frmack_region` (`r.*`, không đụng) → `mart`.

**Không nhầm với `nhom_dv_chinh_cs`** (mục 12, `stg_frmack_cs_tickets`, hiện
vẫn đang comment out/chưa dùng): tuy cùng khai thác custom field id=9794,
`nhom_dv_chinh_cs` lấy từ `cs_ticket_api` (grain **ticket** Caresoft, chỉ
scope `ticket_source IN ('Inbox Facebook','Inbox Facebook Out')`,
`updated_at >= 2025-01-01`, không có tầng fallback nào), còn
`nhom_dv_chinh_booking` lấy từ `cs_deal_detail_api_v2` (bảng khác) với grain
**booking**, có đủ 3 tầng ưu tiên, áp dụng cho toàn bộ booking `brand_etl=1`
không giới hạn theo ticket.

| Nguồn | `nhom_dv_chinh_booking` ở `int_frmack_union` | Lý do |
|---|---|---|
| DC/Lead/TC/BK/HL | `cbwp.nhom_dv_chinh_booking` (từ `crm_base_with_page`, join qua `stg_frmack_crm_base`) | Có `crm_id`/`brand_etl` (từ `crm_lead` đã JOIN trong `stg_frmack_crm_base.x`) |
| DS | `pwp.nhom_dv_chinh_booking` (từ `payment_with_page`, join qua `stg_frmack_doanh_so`) | Có `crm_id`/`brand_etl` (từ `crm_lead` đã JOIN trực tiếp trong `stg_frmack_doanh_so.a`) |
| Inbox / GG / DealCS | `NULL` | Không có liên kết CRM |

Ở `mart`: Stream 1 (FB Cost) expose `NULL::text` cứng (không liên quan
`crm_base`). Stream 2 expose raw (`m.nhom_dv_chinh_booking`, có thể `NULL`).
Stream 3 dùng `COALESCE(m.nhom_dv_chinh_booking, 'KXĐ')` — đồng nhất cách xử
lý `page`/`account_fb`/`nhom_dv_muc_tieu` (chỉ coalesce ở Stream 3, khác với
`actor`/`nhom_dv_KH_quan_tam` vốn coalesce ở cả 2 stream 2 & 3).

## 15. Chiều `nguon_moi_v2` / `nhom_nguon_moi_v2` — bộ nguồn mới (`crm_lead.new_source_id`), KHÔNG PHẢI `stag_sources`

Thêm 2 cột lấy từ hệ "nguồn mới" của `crm_lead.new_source_id` — **quan
trọng: không join vào `stag_sources`** (bảng đang dùng cho cột `nguon`/
`Nguon` cũ qua `crm_lead.source_id`). Đã test trực tiếp trên dữ liệu thật:

- `stag_sources.old_id = crm_lead.new_source_id` → **0 dòng khớp**
- `stag_sources.id = crm_lead.new_source_id` → **0 dòng khớp**

Bảng đúng chứa "bộ nguồn mới" là **`utm_source`** (khác hẳn `stag_sources`,
2 hệ bảng độc lập nhau):

```
crm_lead.new_source_id
  → utm_source.id  (kèm utm_source.brand_id = crm_lead.brand_etl)
        → nguon_moi_v2 = utm_source.name
              (vd: Facebook, Zalo, Google_Ads, Tiktok, Hotline,
               Return_Customer, Referral_Customer, Partner_CTV...)
  → utm_source.category_id → crm_category_source.id
        (kèm crm_category_source.brand_etl = crm_lead.brand_etl)
        → nhom_nguon_moi_v2 = crm_category_source.name
              (Online / Offline / Partner / Referral / CRM/Return / Khác)
```

Đã verify trên dữ liệu thật (`crm_lead.brand_etl = 1`, 34,614 lead có
`new_source_id`):
- Join `utm_source.id = new_source_id AND utm_source.brand_id = brand_etl` →
  khớp đúng **34,614/34,614** (100%).
- **Gotcha `crm_category_source.id` trùng chéo giữa `brand_etl`** (đúng
  pattern đã ghi ở `common/knowledge.md` mục 1 — không riêng bảng nào, áp
  dụng cho mọi bảng mới join): vd `id=121` vừa là `Online` (`brand_etl=1`)
  vừa là `Partner` (`brand_etl=8`). Thiếu điều kiện `cat.brand_etl =
  cl.brand_etl` sẽ fan-out 2x và lấy nhầm nhóm của brand khác. Đã verify:
  không có điều kiện này → fan-out; có điều kiện này → khớp đúng 34,614,
  không nhân bản.

Join **cùng cơ chế** với `nhom_dv_KH_quan_tam`/`nhom_dv_chinh_booking` — theo
`crm_id`/`brand_etl`, thực chất join trực tiếp `cl.new_source_id`/
`cl.brand_etl` (không cần `crm_id` trung gian vì đã có sẵn `crm_lead` trong
CTE) — vào `stg_frmack_crm_base` (`cl.id`, DC/Lead/TC/BK/HL) và riêng vào
`stg_frmack_doanh_so` (`cl3.id`, DS), rồi propagate qua `int_frmack_union` →
`int_frmack_region` (`r.*`, không đụng) → `mart`.

| Nguồn | `nguon_moi_v2`/`nhom_nguon_moi_v2` ở `int_frmack_union` | Lý do |
|---|---|---|
| DC/Lead/TC/BK/HL | `cbwp.nguon_moi_v2`/`cbwp.nhom_nguon_moi_v2` (từ `crm_base_with_page`) | Có `crm_lead` đã JOIN trong `stg_frmack_crm_base.x` |
| DS | `pwp.nguon_moi_v2`/`pwp.nhom_nguon_moi_v2` (từ `payment_with_page`) | Có `crm_lead` đã JOIN trực tiếp trong `stg_frmack_doanh_so.a` |
| Inbox / GG / DealCS | `NULL` | Không có liên kết CRM |

Ở `mart`: Stream 2 expose raw (có thể `NULL`). Stream 3 dùng
`COALESCE(..., 'KXĐ')` cho cả 2 cột — đồng nhất cách xử lý
`nhom_dv_chinh_booking`. **[Cập nhật — xem mục 16]** Stream 1 và các nhánh
Inbox/GG/DealCS (thuộc Stream 2/3) **không còn** để `NULL` — đã đổi sang mặc
định cứng theo kênh đã biết.

Có 2 dòng `new_source_id` (772 `K_CBNV`, 773 `K_Người nhà CBNV`) map sang
`category_id=108` ("Khác") nhưng không có bản ghi `crm_category_source`
tương ứng cho `brand_etl=1` → `nhom_nguon_moi_v2` ra `NULL`/`'KXĐ'` dù
`nguon_moi_v2` vẫn có giá trị — đây là giới hạn dữ liệu nguồn, không phải
lỗi join.

## 16. `nguon_moi_v2`/`nhom_nguon_moi_v2` cho các nhánh không có CRM linkage — mặc định cứng theo kênh thay vì NULL (2026-08-09)

Mục 15 để `NULL` cho Stream 1 (FB Cost) và nhánh Inbox/GG/DealCS vì các nhánh
này không join `crm_lead` nên không tra được `new_source_id`. Nhưng bản thân
loại dữ liệu của các nhánh này **đã xác định rõ kênh** mà không cần tra CRM —
theo yêu cầu người dùng, đổi sang mặc định cứng theo tên thật trong catalog
`utm_source` của Kangnam (đã verify tồn tại: id=751 `Facebook`, id=755
`Google_Ads`, cả 2 cùng `category_id=121` → `crm_category_source.name =
'Online'`):

| Nhánh | Sửa ở file | Căn cứ xác định kênh | Mặc định |
|---|---|---|---|
| Stream 1 (FB Cost) | `mart/mart_report_marketing_ad_cost_kn.sql` | Nguồn `int_frmack_fb_cost`, toàn bộ là chi phí quảng cáo Facebook | `'Facebook'` / `'Online'` |
| `inbox` | `int/int_frmack_union.sql` | `stg_frmack_inbox` đọc từ `m_inbox_kangnam` — Inbox Facebook | `'Facebook'` / `'Online'` |
| `DealCS` | `int/int_frmack_union.sql` | `stg_frmack_deal.sql` set cứng `nguon = 'MD - Facebook'`, `kenh = 'FB'` — ticket Caresoft có gắn FB `ad_id` | `'Facebook'` / `'Online'` |
| `Google_cd`/`Google_th` | `int/int_frmack_union.sql` | `stg_frmack_google` đọc từ `cp_google_kangnam` — chi phí Google Ads | `'Google_Ads'` / `'Online'` |

**Lưu ý khác với `func_report_marketing_ad_cost_pr`:** bên PR, nhánh `DealCS`
lấy Deal Caresoft theo tiêu chí **Google Search** (`ctsda.utm_source ilike
'%Google_Search%'`) nên mặc định `'Google_Ads'`; bên KN, `DealCS` lấy theo
tiêu chí **FB `ad_id`** nên mặc định `'Facebook'` — 2 pipeline có cùng
`type_data = 'DealCS'` nhưng nguồn gốc dữ liệu hoàn toàn khác nhau, đã kiểm
tra code thật của từng bên trước khi áp dụng, không copy máy móc.

Vì Stream 2/3 (`int_frmack_region`) đọc `r.*` nguyên vẹn từ
`int_frmack_union` (mục 3), giá trị mặc định gán ở `int_frmack_union` tự
động lan xuống `mart` mà không cần sửa `mart_report_marketing_ad_cost_kn.sql`
cho Stream 2/3 — chỉ Stream 1 (đọc trực tiếp từ `int_frmack_fb_cost`, không
qua `int_frmack_union`) mới cần sửa riêng ở `mart`.

**Verify (2026-08-09):** `dbt run --select func_report_marketing_ad_cost_kn`
build lại thành công (4,384,136 dòng). Populate 100% cho `Cost_fb_cd`
(3,326,298 dòng), `Cost_fb_th` (458,357), `DealCS` (61,022), `Google_cd`
(13,950), `inbox` (162,188) — tất cả đúng giá trị mặc định theo bảng trên,
không còn `NULL` ở các nhánh này.

## 17. Fallback: suy ra `nguon_moi_v2`/`nhom_nguon_moi_v2` từ nguồn cũ qua `master_data.m_utm_source_old_new_map` (2026-08-09)

Theo yêu cầu người dùng: với các dòng có liên kết CRM (DC/Lead/TC/BK/HL/DS)
nhưng `crm_lead.new_source_id` NULL, tự động suy ra từ **nguồn cũ**
(`crm_lead.source_id`) qua bảng mapping `m_utm_source_old_new_map` (model
`master_data`) thay vì để `NULL`.

**Verify trước khi áp dụng:** `crm_lead.source_id` (brand_etl=1) join thẳng
`utm_source.id` (kèm `brand_id = brand_etl`) khớp **100%**
(156,221/156,221 lead có `source_id` nhưng `new_source_id` NULL). Join tiếp
qua `m_utm_source_old_new_map.old_source_id` khớp **99.9%**
(156,031/156,221).

**Gotcha fan-out:** bảng mapping có 1 số `old_source_id` ứng với nhiều
`new_source_id` (không phải quan hệ 1-1 — xem
`master_data/m_utm_source_old_new_map.sql`). JOIN thẳng theo
`old_source_id + brand_etl` sẽ nhân dòng lead. **Fix:** dùng
`LEFT JOIN LATERAL (... ORDER BY new_source_id LIMIT 1) ON TRUE` thay vì
JOIN thẳng, chọn 1 dòng deterministic mỗi `(old_source_id, brand_etl)` —
cùng kỹ thuật đã áp dụng bên `func_report_marketing_ad_cost_pr` (đo được 659
lead Paris bị fan-out nếu không xử lý; con số tương ứng bên Kangnam không đo
riêng nhưng cùng cơ chế rủi ro).

Áp dụng ở `stg_frmack_crm_base.sql` (DC/Lead/TC/BK/HL) và
`stg_frmack_doanh_so.sql` (DS):

```sql
LEFT JOIN utm_source us ON us.id = cl.new_source_id AND us.brand_id = cl.brand_etl
LEFT JOIN LATERAL (
    SELECT new_source_name, new_source_category_id
    FROM m_utm_source_old_new_map m
    WHERE m.old_source_id = cl.source_id AND m.brand_etl = cl.brand_etl
      AND cl.new_source_id IS NULL
    ORDER BY m.new_source_id
    LIMIT 1
) monm ON TRUE
LEFT JOIN crm_category_source cat
       ON cat.id = COALESCE(us.category_id, monm.new_source_category_id)
       AND cat.brand_etl = cl.brand_etl
...
COALESCE(us.name, monm.new_source_name) AS nguon_moi_v2,
cat.name AS nhom_nguon_moi_v2
```
*(đã bỏ dấu ngoặc kép Jinja trong đoạn minh họa; xem code thật ở 2 file trên.)*

`cat` dùng chung 1 join, key = `COALESCE(us.category_id,
monm.new_source_category_id)` — không cần join `crm_category_source` 2 lần.

**Verify sau fix (2026-08-09):** `dbt run --select func_report_marketing_ad_cost_kn`
build lại thành công (4,384,136 dòng, không đổi tổng số dòng). Coverage
`nguon_moi_v2` tăng lên gần như tuyệt đối:

| type_data | Trước fallback | Sau fallback |
|---|---|---|
| Lead | ~47% | 41,487/41,487 (100%) |
| BKHL | ~54% | 64,233/64,290 (99.9%) |
| HL | ~53% | 65,251/65,308 (99.9%) |
| DC | ~53% | 47,945/47,965 (99.96%) |
| TC | ~61% | 25,556/25,568 (99.95%) |
| DS | ~85% | 117,680/117,703 (99.98%) |

(Cột "trước fallback" lấy từ số liệu đo ở mục 15/16 trước khi thêm mục này —
KN vốn đã có coverage tốt hơn PR ngay từ đầu do ERP Kangnam điền
`new_source_id` đầy đủ hơn.)

## 18. Tối ưu hiệu năng build `mart` — `MATERIALIZED` CTE (2026-08-09)

Người dùng hỏi vì sao `dbt run --select func_report_marketing_ad_cost_kn`
mất ~10 phút (chủ yếu ở bước build `report_marketing_ad_cost_kn_v2`, 591-593s
đo được nhiều lần). Đã điều tra bằng `EXPLAIN` (không `ANALYZE`, chỉ xem
plan — xem kỹ thuật ở `knowledge.md` mục 1, nhưng lần này không cần
`run-operation` vì có sẵn compiled SQL từ `target/compiled/` sau khi
`dbt run` thành công):

**Phát hiện:** CTE `crm_base_with_page` (định nghĩa trong
`int_frmack_union.sql`) được **UNION lại 5 lần** (DC/Lead/TC/BK/HL). Postgres
14 mặc định **inline** CTE không đệ quy thay vì materialize (khác hành vi
Postgres ≤11) — plan cho thấy `"Subquery Scan on crm_base_with_page"` xuất
hiện đúng **5 lần**, tức toàn bộ chuỗi join bên trong nó (`dim_campaign`/
`dim_account`/`ucbt_page_config`/`campaign_name_split` LATERAL/
`stg_frmack_cs_tickets`/`stg_frmack_cs_services`) bị tính lại từ đầu cho mỗi
nhánh UNION thay vì tính 1 lần rồi tái sử dụng.

**Fix:** đổi `WITH crm_base_with_page as (` thành
`WITH crm_base_with_page as MATERIALIZED (` (cú pháp Postgres 12+, ép
materialize thay vì để planner tự quyết). `payment_with_page` (chỉ dùng 1
lần ở nhánh DS) không cần đổi.

**Kết quả đo (2026-08-09, cùng máy/cùng data):**

| Lần chạy | Thời gian build mart |
|---|---|
| Trước MATERIALIZED | 591.64s / 592.98s (2 lần đo) |
| Sau MATERIALIZED | 579.59s |

Chỉ giảm **~2%** — không phải nút thắt chính. Đã kiểm tra tiếp: Stream 1 (FB
Cost, từ `int_frmack_fb_cost`) chiếm **3.78 triệu/4.38 triệu dòng output
(86%)**; các bảng lookup dùng trong luồng này (`dim_page`, `ggs_region_map`,
`ucbt_country_continent`, `campaign_name_split`) đều rất nhỏ (51-106 dòng,
không thiếu index) → thời gian chủ yếu do khối lượng dòng lớn × nhiều phép
xử lý per-row (CASE WHEN, SUBSTRING, split_part, LATERAL lookup) chạy đơn
luồng trong 1 câu `CREATE TABLE AS SELECT`, không phải lỗi thiết kế hay
thiếu tối ưu dễ sửa. Đã hỏi người dùng có muốn đào sâu thêm (chuyển Stream 1
sang `incremental`, hoặc tăng `max_parallel_workers_per_gather` ở Postgres
server) — người dùng xác nhận **10 phút chấp nhận được**, dừng ở
`MATERIALIZED` (giữ lại vì đúng và có lợi dù nhỏ, không có tác dụng phụ).

**Bug phát sinh trong lúc điều tra (đã fix):** khi thử đưa
`{{ ref('m_utm_source_old_new_map') }}` (cú pháp Jinja) vào text mô tả cột
trong `mart/schema.yml` bên `func_report_marketing_ad_cost_pr`, `dbt
run`/`dbt compile` báo lỗi `'ref' is undefined` cho **toàn bộ project**
(không chỉ model đó) — dbt Jinja-render mọi property file (`.yml`) trước khi
build bất kỳ node nào, nhưng context Jinja của property file **không có**
`ref`/`source` (khác với file `.sql` model, nơi `ref`/`source` luôn sẵn
sàng). **Bài học:** không dùng cú pháp `{{ ref(...) }}`/`{{ source(...) }}`
trong mô tả `schema.yml` — chỉ dùng backtick code thường (`` `tên_model` ``).
File `.md` (README/LOGIC) thì an toàn, không bị render kiểu này (đã có sẵn
`{{ ref(...) }}` ở nhiều chỗ trong chính file README này, ví dụ mục 14, chạy
bình thường).

## 19. [Đã fix] Lead nguồn "Tái khai thác" bị loại nhầm khỏi toàn bộ model (2026-08-18)

**Bối cảnh phát hiện:** Đối chiếu số liệu 2 báo cáo Tableau tính "Khách đến
cửa"/"Khách thành công" từ 2 nguồn khác nhau — 1 báo cáo dùng
`report_marketing_ad_cost_kn_v2` (output của model này), 1 báo cáo tính trực
tiếp từ CRM (`report_crm_lead_customer_out_sold`). Sau khi khớp đúng
`brand_etl`/filter, 2 báo cáo lệch nhau ~0.2-1.3% (tháng 6-7/2026), và soi chi
tiết từng khách hàng lệch thì **16/18 case (tháng 7) đều thuộc nguồn "MD/MBS -
Tái khai thác"** — đúng nguồn vừa được bổ sung vào 1 trong 2 báo cáo, dẫn tới
việc lần theo tận model dbt này.

**Nguyên nhân:** `stg_frmack_crm_base.sql` JOIN `crm_lead` với điều kiện:

```sql
-- BUG (đã sửa):
JOIN {{ source('kangnam', 'crm_lead') }} cl
  ON cl.id = stks.id AND cl.brand_etl = 1 AND cl.create_by_department IS NOT NULL
```

`create_by_department IS NOT NULL` nằm trong mệnh đề `ON` của **INNER JOIN**
→ bất kỳ lead nào có `create_by_department` rỗng sẽ bị loại thẳng khỏi
`stg_frmack_crm_base`, kéo theo mất luôn ở `crm_base_with_page` và **cả 5
nhánh CRM** dùng chung CTE này (DC/Lead/TC/BK/HL — xem mục 3).

Đã verify trực tiếp trên DB (join chính xác theo `crm_lead.id = crm_id`, không
chỉ theo số điện thoại — 1 số điện thoại có thể ứng với nhiều `lead id` do
khách quay lại nhiều lần): **15/20 lead thuộc nguồn "Tái khai thác"** có
`create_by_department = NULL`, đều do phòng **"Sales & Marketing Thương hiệu
Kangnam"** tạo — nhiều khả năng quy trình tạo lead tái khai thác (tự động/bán
tự động) không đi qua luồng gán `create_by_department` chuẩn như lead mới do
các phòng kinh doanh/dịch vụ tạo thủ công, nên trường này bị bỏ trống có hệ
thống cho cả nhóm nguồn này — không phải lỗi dữ liệu ngẫu nhiên.

Case minh chứng rõ nhất: khách hàng `CUS723749` có 2 lead record khác nhau
trong `crm_lead` — 1 lead nguồn `MD - Facebook` có `create_by_department` =
"Sales & Marketing Thương hiệu Kangnam" (có giá trị), và 1 lead nguồn `MD -
Tái khai thác` có `create_by_department = NULL`. Phía CRM (không có điều kiện
lọc này) chọn đúng lead "Tái khai thác" làm bản ghi chính cho lượt đến gần
nhất, còn model này đánh rớt nó ngay từ vòng JOIN.

**Fix đã áp dụng:** bỏ điều kiện `cl.create_by_department IS NOT NULL` khỏi
`ON` clause, giữ nguyên `JOIN` trên `cl.id = stks.id AND cl.brand_etl = 1`.
Không đổi sang `LEFT JOIN` vì `stks.id` luôn phải khớp 1 lead thật (INNER JOIN
ở đây không phải nguồn gây mất data — chỉ điều kiện business rule thừa mới
là nguyên nhân).

**Chưa xác nhận được:** mục đích ban đầu của điều kiện `create_by_department
IS NOT NULL` khi được thêm vào (loại lead rác/test data?). Nếu về sau phát
hiện lại rác lẫn vào do bỏ điều kiện này, cần tìm lọc khác đặc thù hơn (ví dụ
theo nguồn tạo lead) thay vì lọc chung theo `create_by_department`.

## 20. [Đã fix] Cột `kenh` phân loại sai Google Ads trả phí và giao thoa với Facebook/Cộng đồng (2026-08-31)

**Bối cảnh phát hiện:** Đối chiếu logic ticket-level (`cs_ticket_api` →
`cs_ticket_source_api` → `cs_ticket_source_detail_api`, lấy `channel`/
`utm_source` thật) với cột `kenh` đang tính trong `stg_frmack_crm_base.sql`/
`stg_frmack_doanh_so.sql` (text-match trên `nguon_moi`/`ss.source`). Kết quả
đối chiếu trên toàn bộ ticket có `ctsd.channel ILIKE 'web'`:

| Phân loại đúng theo ticket (channel/utm_source) | `kenh` cũ đang gán | Số lượng | Tỷ lệ |
|---|---|---|---|
| Ads – Google Search (utm_source chứa "google"+"search") | `Khác` | 6.360 | 99,9% nhóm này |
| Ads – Google Search | `FB` | 8 | 0,1% |
| SEO (channel=Web, không phải Google Ads) | `Web - SEO` | 24.245 | 66,5% nhóm này |
| SEO | `Khác` | 10.348 | 28,4% |
| SEO | `FB` | 1.688 | 4,6% |
| SEO | `Web` | 160 | 0,4% |

**Nguyên nhân:** CASE cũ chỉ dựa vào text-match trên `nguon_moi` (trường do
CRM/sale tự gán thủ công), hoàn toàn không dùng `channel`/`utm_source` thật
của ticket:

```sql
-- CŨ:
CASE WHEN stks.nguon_moi ~~ '%Facebook%' THEN 'FB'
     WHEN stks.nguon_moi ~~ '%Seo%'      THEN 'Web'
     WHEN stks.nguon_moi ~~ '%Google%'   THEN 'Web'
     WHEN stks.nguon_moi ~~ '%Hotline%'  THEN 'Web'
     when ctsd.source_name not like '%utm_source%' THEN 'Web - SEO'
     ELSE 'Khác'
END AS kenh
```

Hai lỗi cụ thể:
1. **Google Ads Search/Display trả phí rơi vào `Khác`**: `nguon_moi` của các
   lead này ghi `'MD - Search'` — không chứa chữ "Google" nên không khớp
   `~~ '%Google%'`; đồng thời vì ticket có tracking UTM thật,
   `ctsd.source_name` có chứa chuỗi `'utm_source'` nên cũng trượt luôn nhánh
   fallback `'Web - SEO'` → rơi thẳng xuống `ELSE 'Khác'`. Gần như 100%
   Google Ads Search trả phí bị mất khỏi kênh `Web`.
2. **SEO thật bị "cướp" sang `FB`/`Khác`**: điều kiện `nguon_moi ~~
   '%Facebook%'` được xét trước tiên, nên ticket `channel='Web'` (SEO/Google
   Ads xác định rõ ràng) nhưng `nguon_moi` bị gán nhầm `'MD - Facebook'`/
   `'MBS - Facebook'` vẫn bị tính là kênh Facebook. Tương tự, phần lớn SEO có
   `ctsd.source_name` chứa `'utm_source'` (tracking rõ ràng) lại trượt nhánh
   fallback cũ, rơi vào `Khác`.

**Fix đã áp dụng:** thêm 2 nhánh mới lên **đầu** CASE, dùng trực tiếp
`ctsd.channel`/`ctsd.utm_source` — ưu tiên dữ liệu ticket-level thật hơn
text-match trên `nguon_moi` (theo yêu cầu người dùng: ticket-level thắng khi
có xung đột):

```sql
-- MỚI:
CASE WHEN ctsd.channel ILIKE 'web'
          AND (ctsd.utm_source ILIKE '%google%search%' OR ctsd.utm_source ILIKE '%google%display%')
          THEN 'Web'
     WHEN ctsd.channel ILIKE 'web'       THEN 'Web - SEO'
     WHEN stks.nguon_moi ~~ '%Facebook%' THEN 'FB'
     WHEN stks.nguon_moi ~~ '%Seo%'      THEN 'Web'
     WHEN stks.nguon_moi ~~ '%Google%'   THEN 'Web'
     WHEN stks.nguon_moi ~~ '%Hotline%'  THEN 'Web'
     ELSE 'Khác'
END AS kenh
```

Giữ nguyên nhãn `'Web'`/`'Web - SEO'` (không đổi tên) để không phải sửa công
thức `Platform kênh` bên Tableau — Google Ads trả phí giờ khớp đúng
`kenh = 'Web'` (điều kiện `[kenh]='Web' AND [Nguon] IN (...)` trong công thức
Tableau sẽ cần bổ sung thêm giá trị `Nguon` thực tế là `'MD - Search'` nếu
muốn hiển thị đúng — cột `Nguon` này đã có sẵn trong danh sách kiểm tra của
công thức). Nhánh `nguon_moi ~~ '%Seo%'/'%Google%'/'%Hotline%'` cũ được giữ
lại làm fallback cho các ticket không có `ctsd.channel = 'Web'` (ví dụ nguồn
Hotline qua kênh `Voice`/`Api`, không đi qua channel `Web`).

**Tác động số liệu:** sau fix, kênh `Web` sẽ tăng thêm ~6.368 bản ghi (Google
Ads Search trả phí, trước đó nằm trong `Khác`); kênh `Web - SEO` tăng thêm
~10.508 bản ghi (10.348 từ `Khác` + 160 từ `Web`); kênh `FB` giảm 1.688 bản
ghi (chuyển sang `Web`/`Web - SEO` tuỳ theo có phải Google Ads hay không);
kênh `Khác` giảm tương ứng ~16.708 bản ghi. Số liệu ước tính dựa trên dữ liệu
đối chiếu tại thời điểm phát hiện (2026-08-31), **chưa build lại dbt để xác
nhận số cuối cùng sau khi filter theo `int_frmack_union`/`mart`** — cần chạy
`dbt run --select func_report_marketing_ad_cost_kn` và đối chiếu lại trước
khi publish báo cáo Tableau.

**Chưa xác nhận được:** ngưỡng phân biệt "Google Ads trả phí" hiện chỉ dựa
`utm_source` chứa cả 2 từ "google" và "search"/"display" — nếu về sau xuất
hiện thêm kênh trả phí khác cần phân biệt riêng (Facebook Ads đi qua
`channel='Web'`, TikTok Ads, ...), cần mở rộng thêm điều kiện tương tự thay
vì gộp chung vào `'Web - SEO'`.

## 21. Chặn cứng nhóm "Cộng đồng" (Tiktok/Zalo/Youtube) về `'Khác'` — an toàn khi đọc thẳng cột `kenh` (2026-08-31)

**Bối cảnh:** Sau khi áp fix mục 20, kiểm tra riêng các bản ghi `nguon_moi ~~
'%Tiktok%'` (tương tự cho Zalo/Youtube) phát hiện: ~10.284/11.407 bản ghi có
`ctsd.channel = 'Web'` (chỉ mang mã tracking chung `utm_source = MD007`,
không có dấu hiệu TikTok thật) → theo logic mục 20, các bản ghi này bị gán
`kenh = 'Web - SEO'`.

Điều này **không ảnh hưởng số liệu hiển thị trên Tableau**, vì công thức
`Platform kênh` đã có nhánh riêng, ưu tiên cao hơn nhánh Web:

```
ELSEIF [kenh] IN ('Tiktok','Zalo','Youtube')
   OR [Nguon] IN ('MD - Tiktok','MD - Zalo','MKT_Zalo','MD - Youtube', ...)
THEN 'Cộng đồng'
```

→ Bất kể `kenh` (dbt) là gì, `Nguon = 'MD - Tiktok'` luôn hiển thị `'Cộng
đồng'` trên report. Đã verify: trường `[kenh]` thô không được đặt trực tiếp
lên rows/cols/marks ở bất kỳ worksheet nào trong workbook (chỉ dùng bên trong
công thức `Platform kênh` + 1 action filter ẩn) — nên hiện tại không có rủi ro
thực tế.

**Fix bổ sung theo yêu cầu người dùng (chủ động phòng ngừa):** dù không ảnh
hưởng Tableau hiện tại, để tránh rủi ro cho các báo cáo/tính toán khác sau
này lỡ đọc thẳng cột `kenh` (không qua công thức `Platform kênh`), thêm 1
nhánh **lên đầu CASE**, chặn cứng toàn bộ danh sách `Nguon` thuộc nhóm "Cộng
đồng" (đúng theo danh sách trong công thức Tableau) về `'Khác'`, đứng trước
cả nhánh channel/utm_source lẫn Facebook:

```sql
CASE WHEN <nguồn> IN ('MD - Tiktok','MD - Zalo','MKT_Zalo','MD - Youtube',
                        'MD - Phát triển cộng đồng (Seeding)','MD - Phát triển cộng đồng')
          THEN 'Khác'
     WHEN ctsd.channel ILIKE 'web' AND (...) THEN 'Web'
     ...
END AS kenh
```

**Tác động số liệu:** kênh `Web - SEO` giảm lại ~10.371 bản ghi (đúng phần
Tiktok mục 20 vừa thêm vào), quay về `Khác`. Facebook (`kenh = 'FB'`) **không
đổi** — nhóm này vẫn ưu tiên channel/utm_source thật như mục 20 (người dùng
chỉ yêu cầu chặn riêng "Cộng đồng", không yêu cầu chặn Facebook).

**Chưa xác nhận được:** danh sách `Nguon` thuộc "Cộng đồng" lấy đúng y hệt
danh sách trong công thức Tableau hiện tại — nếu công thức Tableau đổi danh
sách này sau này, cần đồng bộ lại cả 2 file `stg_frmack_crm_base.sql`/
`stg_frmack_doanh_so.sql` theo.
