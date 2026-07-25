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
`stg_dv_khach_hang_quan_tam.first_product_group` — `product_group` (nhóm
dịch vụ, phân loại theo `his_service_type`/`product_category`) của bản ghi
`crm_line` **đầu tiên** (`cus_bk_line_order = 1`, sắp theo
`cline_created_date`) của khách hàng đó, không phải nhóm dịch vụ mới nhất.

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
