# report_kn_sale_online — Logic Model

Báo cáo hiệu suất sale online Kangnam. Output cuối cùng là bảng
`report_kn_sale_online`.

Số liệu đo trong tài liệu này có **hai mốc**, và chúng lệch nhau rất lớn:

| Mốc | Trạng thái dữ liệu nguồn |
|---|---|
| **2026-09-17** | `crm_line` brand 1 có 138.436 dòng — **thiếu ~234k dòng** lịch sử |
| **2026-10-08** | `crm_line` brand 1 có 372.296 dòng — sau backfill, **đầy đủ** |

Mọi con số dưới đây đều ghi rõ thuộc mốc nào. Nguyên nhân lệch: **backfill ở tầng
nguồn**, không phải thay đổi logic model — xem mục 8.11.

---

## 1. Sơ đồ luồng dữ liệu

```
      9 BẢNG NGUỒN (schema public của DWH)
              │
    ┌─────────┴──────────────────────────────────┐
    │  Lớp int/  — 11 model `kso_*` (ephemeral)  │  đổi tên cột + lọc brand_etl = 1
    └─────────┬──────────────────────────────────┘
              │
    ┌─────────┴──────────────────────────────────┐
    │  stg_kso_map  ←  TRÁI TIM của model        │  join 11 nguồn → ~406.180 dòng
    └─────────┬──────────────────────────────────┘
              │  cùng 1 tập dữ liệu, cắt 6 lát theo loại bản ghi + mốc thời gian
   ┌──────┬───┴───┬───────┬───────┬───────┐
 Lead_total  BK    HL      DC      TC      DS
   └──────┴───┬───┴───────┴───────┴───────┘
              │  UNION ALL
      report_kn_sale_online  →  1.129.859 dòng × 25 cột   (2026-10-08)
```

---

## 2. Lưu ý về quy ước phân tầng — `int/` và `stg/` bị ĐẢO VAI TRÒ

Khác với các model còn lại trong project (ví dụ `func_report_marketing_ad_cost_kn`),
model này đặt tên thư mục ngược với ý nghĩa thông thường của dbt:

| Thư mục | Nội dung thực tế | Lẽ ra nên là |
|---|---|---|
| `int/` | Lớp bọc mỏng quanh bảng nguồn, **không có nghiệp vụ nào** | `stg/` |
| `stg/` | Nơi join toàn bộ + chứa logic nghiệp vụ duy nhất | `int/` |

Ghi nhận lại để người đọc sau không đi tìm nghiệp vụ nhầm chỗ. **Không đổi tên thư mục**
vì `dbt_project.yml` đang cấu hình `materialized` theo đúng tên thư mục hiện tại,
và việc đổi tên không mang lại giá trị nghiệp vụ nào.

---

## 3. Lớp `int/` — 11 model `kso_*`

Tất cả đều `materialized: ephemeral`, chỉ làm 2 việc: **đổi tên cột sang tiếng Việt**
và **lọc `brand_etl = 1`** (Kangnam).

| Model | Bảng nguồn | Vai trò | Số dòng |
|---|---|---|---|
| `kso_crm_lead` | `crm_lead` | Xương sống. Lọc thêm `active is true`. **Nơi sinh ra cột `vk`** (xem mục 7) | 283.325 |
| `kso_cline` | `crm_line` **UNION ALL** `crm_line_product` | Dòng dịch vụ của booking | 138.436 + 13.645 |
| `kso_spt` | `stag_payment_transfer` | Thu tiền. Lọc thêm `payment_date >= '2025-08-01'` (hard-code, không dùng `var start_date`) | 156.815 |
| `kso_product` | `view_stag_products` | Tên / nhóm dịch vụ, `his_service_type`, `surgery_type` | 20.767 |
| `kso_source` | `stag_sources` | Nguồn khách (`nguon_moi`, `nhom_nguon_moi`) | — |
| `kso_company` | `m_res_company` | Tên chi nhánh | — |
| `kso_employees` | `view_stag_employees_user` | Nhân viên tạo booking | — |
| `kso_crm_stage` | `crm_stage` | Trạng thái booking | — |
| `kso_country_state` | `res_country_state` | Tỉnh / thành | — |
| `kso_cline_product` | `crm_line_product` | **MODEL CHẾT** — không model nào `ref()` tới. Nội dung trùng hoàn toàn nửa dưới của `kso_cline` | 13.645 |
| `kso_page` | `cs_chat_api` + `m_facebook_page_kangnam` | **MODEL CHẾT** — không ai `ref()`. Ngoài ra gọi `cs_chat_api` trần (không qua `source()`) | — |

---

## 4. Lớp `stg/` — `stg_kso_map`: nơi mọi thứ được ghép lại

### 4.1. CTE `mapping` — join 11 nguồn quanh `kso_crm_lead`

```
kso_crm_lead (cl)                                       ← gốc
  ├─ kso_cline (cl2)       ON cl.id = cl2.crm_id                   ← NHÂN DÒNG
  ├─ kso_product (sp)      ON sp.product_id = cl2.product_id
  ├─ kso_spt (spt)         ON clineid + crm_id + product_id        ← NHÂN DÒNG
  ├─ kso_company (mrc2)    ON mrc2.id = cl.company_id      → chi nhánh phân quyền
  ├─ kso_company (mrc3)    ON mrc3.id = spt.company_id     → chi nhánh thu tiền
  ├─ kso_employees (se)    ON se.user_id = cl.create_uid
  ├─ kso_crm_stage (cs)    ON cs.id = cl.stage_id
  ├─ kso_country_state     ON rcs.id = cl.state_id
  └─ kso_source (ss)       ON ss.old_id = cl.nguon_bk_id
WHERE sp.nhom_dv <> 'SAN PHAM' AND sp.nhom_dv IS NOT NULL   ← loại sản phẩm bán lẻ
```

Cột `date_time` = `ngay_dc` nếu có, ngược lại `ngay_tao`.

### 4.2. SELECT bọc ngoài — ghi đè chi nhánh theo nơi khách thực đến

Đây là **logic nghiệp vụ duy nhất đáng kể của cả model**:

```sql
LEFT JOIN (select * from stag_crm_booking_arrival_company where brand_etl = 1) sh
       ON m.id = sh.crm_id
```

- Nếu `sh.arrival_company_id` có giá trị **và khác** chi nhánh phân quyền
  → lấy chi nhánh **thực đến** (`chinhanh`, `chinhanhphanquyen`).
- Ngược lại → giữ chi nhánh cũ (`chinhanh_old`, `chinhanhphanquyen_old`).

Vì vậy tồn tại song song 2 cặp cột. Nhánh `DS` cố ý dùng cặp `_old`
(xem mục 5), 5 nhánh còn lại dùng cặp đã ghi đè.

### 4.3. Số liệu đo thực tế

| Chỉ số | 2026-09-17 | 2026-10-08 |
|---|---|---|
| Số dòng `stg_kso_map` | 152.383 | **~406.180** |
| `crm_lead` brand 1 + `active` | 283.325 | **295.854** (+4,4%) |
| `crm_line` brand 1 | 138.436 | **372.296** (+169%) |
| `crm_line_product` brand 1 | 13.645 | **15.705** |

Ở **cả hai** mốc, `stg_kso_map` ≈ `kso_cline` (= `crm_line` + `crm_line_product`) cộng
một ít fan-out — tức model **không nhân dòng** ở mốc nào. Toàn bộ chênh lệch đến từ
`crm_line` ở tầng nguồn (mục 8.11).

---

## 5. Lớp `stg/` — 6 lát cắt

Cả 6 file đều `select ... from stg_kso_map`, khác nhau **chỉ ở bộ lọc** và
**cột nào được gán làm `date`**:

| Nhánh (`bang`) | Bộ lọc | Cột làm `date` | Cột chi nhánh | Số dòng |
|---|---|---|---|---|
| `Lead_total` | `loai_ban_ghi = 1` + `trang_thai IN ('Tiềm năng','Tham khảo','Đặt lịch')` | `ngay_tao` | đã ghi đè | 55.376 |
| `BK` | `loai_ban_ghi = 2`, loại `reason_cancel_booking = 'tao_booking_bh'` | `ngay_tao` | đã ghi đè | 94.465 |
| `DC` | y hệt `BK` | `ngay_den_cua` | đã ghi đè | 94.465 |
| `HL` | y hệt `BK` | `ngay_hl` | đã ghi đè | 94.465 |
| `TC` | như `BK` + `tong_tien > 0` | `ngay_den_cua` | đã ghi đè | 37.814 |
| `DS` | `loai_ban_ghi = 2`, **không** loại booking bảo hành | `ngay_tt` | **`_old`** | 51.712 |

### 5.1. `BK` = `DC` = `HL` — cùng một tập dữ liệu, KHÔNG phải lỗi

Ba nhánh này có **cùng bộ lọc và cùng 94.465 dòng**; chỉ khác nhãn `bang` và
cột nào được đưa vào `date`. Đây là thiết kế cố ý dạng *long format*: cùng một
booking được lặp 3 lần dưới 3 mốc thời gian (ngày tạo / ngày đến / ngày hẹn lịch)
để báo cáo đếm phễu theo từng mốc.

> **Cảnh báo sử dụng:** mọi phép `count()` / `sum()` trên bảng mart **bắt buộc phải
> lọc theo cột `bang`**. Quên lọc sẽ đếm bội 3 lần nhóm booking.

### 5.2. Gán nhân viên / team theo thời điểm

Cả 6 nhánh đều có:

```sql
LEFT JOIN LATERAL (
    select sc.name, sc.group_name, sc.group, sc.work_email
    from table_team_sale_trans_field sc
    where sc.work_email = stks.work_email
      and date(sc.expiration_date) >= date(stks.<cột ngày của nhánh>)
    order by expiration_date limit 1
) tts on true
```

Xử lý đúng việc nhân viên đổi team theo thời gian: lấy bản ghi team **có hiệu lực
tại đúng mốc thời gian của nhánh đó**. Bảng có 779 dòng / 380 email (nhiều dòng mỗi
email), nhưng `LIMIT 1` nên **không gây nhân dòng**.

> **Nợ kỹ thuật:** `table_team_sale_trans_field` bị gọi **trần** trong cả 6 file
> (`from table_team_sale_trans_field sc`) thay vì qua `{{ source(...) }}`, dù đã được
> khai báo trong `int/kn_sale_online/source.yml`. Hệ quả: dbt **không thấy phụ thuộc
> này trong lineage**, nên không đảm bảo thứ tự build và không cảnh báo khi bảng đổi.

---

## 6. Lớp `mart` — `report_kn_sale_online`

```sql
{{ config(materialized = 'table') }}

with a as (
        select * from stg_kso_lead
  union all select * from stg_kso_bk
  union all select * from stg_kso_hl
  union all select * from stg_kso_dc
  union all select * from stg_kso_tc
  union all select * from stg_kso_ds where ma_phieu is not null
)
select * from a
```

Chỉ nhánh `DS` bị lọc thêm `ma_phieu is not null`.

Kết quả **2026-10-08: 1.129.859 dòng × 25 cột**.

| `bang` | 2026-09-17 | 2026-10-08 | Tỉ lệ |
|---|---|---|---|
| `Lead_total` | 55.376 | **143.684** | 2,59× |
| `BK` | 94.465 | **253.430** | 2,68× |
| `DC` | 94.465 | **253.430** | 2,68× |
| `HL` | 94.465 | **253.430** | 2,68× |
| `TC` | 37.814 | **104.359** | 2,76× |
| `DS` | 51.712 | **121.526** | 2,35× |
| **Tổng** | 428.297 | **1.129.859** | **2,64×** |

Mọi lát phình gần như đồng đều → nguồn phình ở `stg_kso_map` dùng chung, không ở lát
nào riêng. Xem mục 8.11.

### 6.1. Danh sách cột

| # | Cột | Nguồn | Ghi chú |
|---|---|---|---|
| 1 | `page` | hằng `'page'` | **Placeholder**, chưa nối vào `kso_page` |
| 2 | `ad_id` | hằng `'ad'` | **Placeholder** |
| 3 | `bang` | hằng theo nhánh | `Lead_total` / `BK` / `HL` / `DC` / `TC` / `DS` |
| 4 | `ticket_id` | `crm_lead.ticket_id` | |
| 5 | `sdt` | `crm_lead.phone` | Nhánh `DS` đưa `doanh_so::text` vào đây |
| 6 | `nhan_vien_tts` | `table_team_sale_trans_field.name` | |
| 7 | `nhom_nv` | `table_team_sale_trans_field.group_name` | |
| 8 | `team_id` | `table_team_sale_trans_field.group` | |
| 9 | `date` | tuỳ nhánh | xem mục 5 |
| 10 | `nguon` | `stag_sources.source` | |
| 11 | `chi_nhanh` | `m_res_company.name` | `DS` dùng bản `_old` |
| 12 | `nhom_dv` | `view_stag_products.product_category` | |
| 13 | `his_service_type` | `view_stag_products` | |
| 14 | `work_email` | `view_stag_employees_user` | |
| 15 | `ten_khach` | `crm_lead.contact_name` | |
| 16 | `ma_kh` | `crm_lead.code_customer` | |
| 17 | `ma_booking` | `crm_lead.name` | **Không duy nhất** — xem mục 8.3 |
| 18 | `surgery_type` | `view_stag_products` | |
| 19 | `tinh` | `res_country_state.name` | |
| 20 | `chinhanhphanquyen` | `company_id` | `DS` dùng bản `_old` |
| 21 | `ten_dv` | `view_stag_products.product` | |
| 22 | `ma_phieu` | `stag_payment_transfer.ma_phieu` | Đặt tên nội bộ là `vao_so` |
| 23 | `vk` | `crm_lead.overseas_vietnamese` | Bổ sung 2026-09-17 — xem mục 7 |
| 24 | `nhom_dv_kh_quan_tam` | `stg_dv_khach_hang_quan_tam.first_product_group` | Bổ sung 2026-10-07 — xem mục 7b |
| 25 | `nhom_dv_kh_quan_tam_goc` | `stg_dv_khach_hang_quan_tam.first_product_category` | Bổ sung 2026-10-07 — danh mục GỐC, chưa gom nhóm |

---

## 7. Cột `vk` — Việt kiều / quốc tế (bổ sung 2026-09-17)

### 7.1. Đường đi

```
crm_lead.overseas_vietnamese
  → kso_crm_lead.sql          AS vk
  → stg_kso_map.sql           cl.vk
  → stg_kso_{lead,bk,hl,dc,tc,ds}.sql   stks.vk
  → report_kn_sale_online     cột 23
```

`vk` **đã luôn tồn tại** trong `stg_kso_map` từ trước; trước ngày 2026-09-17 nó chỉ
không được `select` ra ở 6 file lát cắt nên không tới được mart. Việc bổ sung vì vậy
**không thêm join nào và không thêm nguồn nào**.

### 7.2. Miền giá trị — giữ nguyên mã thô của CRM

| `vk` | Số dòng | % |
|---|---|---|
| `no` | 378.068 | 88,27% |
| `marketing` | 35.590 | 8,31% |
| `NULL` | 5.855 | 1,37% |
| `mkt_oversea` | 5.278 | 1,23% |
| `expat` | 2.376 | 0,55% |
| `branch` | 893 | 0,21% |
| `branch_oversea` | 237 | 0,06% |

### 7.3. KHÔNG so khớp trực tiếp được với `report_marketing_ad_cost_kn_v2`

Model `func_report_marketing_ad_cost_kn` cũng có cột `vk` từ **cùng cột nguồn**
`crm_lead.overseas_vietnamese`, nhưng **miền giá trị khác hẳn**:

| | `report_kn_sale_online` | `report_marketing_ad_cost_kn_v2` |
|---|---|---|
| Nguồn `vk` | Chỉ CRM | CRM **và** parse từ tên campaign quảng cáo |
| `expat` | giữ nguyên `expat` | map lại thành `exp` |
| Có `'VIỆT KIỀU'` / `'QUỐC TẾ'` | **Không** | Có (sinh từ token thứ 3 của campaign name) |

Muốn đối chiếu 2 báo cáo trên chiều `vk` thì phải thống nhất quy ước trước.

### 7.4. Kết quả kiểm chứng khi bổ sung (2026-09-17)

| Kiểm tra | Kết quả |
|---|---|
| Số dòng trước / sau | 428.297 = 428.297 |
| 22 cột cũ: thứ tự, tên, kiểu | Giống hệt |
| `EXCEPT ALL` (bảng cũ → bảng mới) trên 22 cột chung | **0 dòng** |
| `EXCEPT ALL` (bảng mới → bảng cũ) trên 22 cột chung | **0 dòng** |
| Đối chiếu ngược `vk` về `crm_lead` | 417.401 dòng kiểm được → **417.401 khớp, 0 lệch** |
| 5.855 dòng `vk` NULL | **Cả 5.855 đều đúng là NULL ở nguồn**, không dòng nào mất giá trị |

10.896 dòng không đối chiếu ngược được — không phải lỗi dữ liệu, mà do chúng có
`ma_booking` trùng với nhiều bản ghi `crm_lead` mang `vk` khác nhau nên phép kiểm
không xác định được đáp án đúng. Bản thân model **không dùng `ma_booking` để lấy `vk`**
(lấy thẳng `cl.vk` trên cùng dòng join theo `crm_lead.id`), nên đường đi của model
chặt hơn phép kiểm.

---

## 7b. Cột `nhom_dv_kh_quan_tam` — nhóm dịch vụ KH quan tâm (bổ sung 2026-10-07)

Nhãn **nhóm dịch vụ mà khách quan tâm ĐẦU TIÊN** khi vào booking. Dùng **chung
nguyên model** `models/common/stg_dv_khach_hang_quan_tam.sql` với
`func_report_marketing_ad_cost_kn` (cột `nhom_dv_KH_quan_tam` của model đó) —
không copy lại CASE WHEN, nên 2 báo cáo không thể lệch nhãn theo thời gian.

### 7b.1. Logic gán nhãn

```
crm_line (cln)  ⟕ crm_lead  ⟕ view_stag_products (sp)
      │
      │  ROW_NUMBER() OVER (PARTITION BY crm_id
      │                     ORDER BY cline_created_date, cline_id)   ← tie-break cline_id
      ▼
   lấy dòng cus_bk_line_order = 1
      ├─ first_product_group    = sp.product_group     → nhom_dv_kh_quan_tam
      └─ first_product_category = sp.product_category  → nhom_dv_kh_quan_tam_goc
      ▼
   coalesce(..., 'KXĐ')
```

Hai cột là **cặp đôi**, khác nhau ở mức gom nhóm:

| Cột | Nguồn | Ví dụ giá trị |
|---|---|---|
| `nhom_dv_kh_quan_tam` | `product_group` — ĐÃ gom nhóm | `PTTM MẮT`, `BEAUTY & SPA` |
| `nhom_dv_kh_quan_tam_goc` | `product_category` — danh mục GỐC, input thô của CASE WHEN gom nhóm | `HÚT MỠ`, `GIẢM BÉO KHÔNG PT` |

Nhiều giá trị `_goc` khác nhau có thể cùng đổ về 1 nhãn ở cột đã gom nhóm.

Nhãn lấy **thẳng** `view_stag_products.product_group` (đã bake sẵn trong view,
dùng chung toàn hệ thống) — ví dụ `PTTM MẮT`, `BEAUTY & SPA`, `SẢN PHẨM`… —
**không** phải bộ 9 nhóm có tiền tố số (`1.MẮT`, `8.BEAUTY & SPA`) đã bỏ từ
2026-08-05.

### 7b.2. Đường đi trong model

```
common/stg_dv_khach_hang_quan_tam.sql      first_product_group
  → stg_kso_map.sql     left join dkq on dkq.crm_id = cl.id and dkq.brand_etl = cl.brand_etl
                        coalesce(dkq.first_product_group,    'KXĐ') as nhom_dv_KH_quan_tam
                        coalesce(dkq.first_product_category, 'KXĐ') as nhom_dv_KH_quan_tam_goc
  → stg_kso_{lead,bk,hl,dc,tc,ds}.sql      stks.nhom_dv_KH_quan_tam, stks.nhom_dv_KH_quan_tam_goc
                                           (cột 24 & 25, cuối cùng)
  → mart/report_kn_sale_online.sql         union all select *
```

`stg_dv_khach_hang_quan_tam` là `ephemeral` và đã lọc `cus_bk_line_order = 1`
→ **1 dòng / `crm_id`**, nên join này **không nhân dòng** (428.297 dòng giữ nguyên).
Join có `brand_etl` vì model common không lọc brand.

### 7b.3. Phân biệt với `nhom_dv` (cột 12) — ĐỪNG nhầm

| | `nhom_dv` (cột 12) | `nhom_dv_kh_quan_tam` (cột 24) |
|---|---|---|
| Grain | Theo **từng dòng dịch vụ** (`crm_line` của dòng đang xét) | Theo **booking** — chỉ dịch vụ của `crm_line` ĐẦU TIÊN |
| Nguồn | `view_stag_products.product_category` | `product_group` (cột 24) / `product_category` (cột 25) |
| 1 booking nhiều dịch vụ | Mỗi dòng 1 giá trị khác nhau | Mọi dòng cùng 1 giá trị |
| Lọc `<> 'SAN PHAM'` | Có (ở `where` của `stg_kso_map`) | **Không** — nhãn `SẢN PHẨM` vẫn xuất hiện được |

### 7b.4. Hiệu suất — build 155s → 354s khi mới thêm, và cách đã xử lý

Lần build đầu sau khi thêm 2 cột: **354,1s** (`target/run_results.json`), so với mốc
155s trước đó → **+199s**. Đọc SQL compile ra thì thấy `stg_dv_khach_hang_quan_tam`
quét lại 4 bảng mà model đã quét ở trên, nhưng **không có `WHERE` nào** (mọi brand):

| Bảng | Lần 1 (qua `kso_*`) | Lần 2 (qua `dkq`) |
|---|---|---|
| `crm_line` | `brand_etl = 1` | **không lọc** — 1.711.031 dòng |
| `crm_lead` | `brand_etl = 1 and active` | **không lọc** |
| `view_stag_products` | `brand_etl = 1` | **không lọc** |
| `stag_sources` | `brand_etl = 1` | **không lọc** |

Đã xử lý bằng 2 thay đổi trong `models/common/stg_dv_khach_hang_quan_tam.sql`
(xem mục 8.8 — hoá ra là **bug**, không chỉ là chậm):

1. **Thêm `WHERE cln.brand_etl = 1`** — 1.711.031 → ~138.436 dòng vào window function.
2. ~~Bỏ join `stag_sources` + 5 cột chưa dùng~~ — **đã hoàn nguyên 2026-10-08.**
   5 cột `code_customer` / `source` / `category_source_code` / `booking_report_date` /
   `stage` được **giữ lại** theo quyết định của chủ sở hữu báo cáo: đó là thông tin của
   booking, để dùng khi cần. Hiện chưa consumer nào đọc (cả 3 chỉ dùng `crm_id`,
   `brand_etl`, `first_product_group`, `first_product_category`) nhưng **không được xoá
   vì lý do "không ai dùng"**.

   ⚠️ Con số **36,12s** đo được khi 5 cột + join `stag_sources` **đã bị bỏ**. Join này
   giờ quay lại nên thời gian build có thể nhúc nhích lên — cần đo lại. Phần cắt chính
   (vật hoá `kso_team_sale`, mục 8.9) không bị ảnh hưởng.

### 7b.5. KHÔNG chuyển `stg_dv_khach_hang_quan_tam` sang `view` + index

**View trong Postgres không đặt được index** — chỉ `table` / `materialized view` mới
index được. Và view còn chậm hơn `ephemeral`: không lưu dữ liệu, mỗi lần tham chiếu
là chạy lại toàn bộ logic, mất luôn cơ hội được planner materialize như CTE.

Giữ `ephemeral` **không bị tính lặp**: dbt khai báo mỗi model ephemeral đúng **1 CTE**,
`stg_dv_khach_hang_quan_tam` chỉ có 1 chỗ tham chiếu (`stg_kso_map`) → 1 lần / 1 lần
build mart. (`stg_kso_map` mới là CTE bị tham chiếu 6 lần, Postgres 12+ materialize
nó đúng 1 lần.)

Nếu sau này vẫn chậm thì đòn đúng là `materialized = 'table'` + config `indexes` của
dbt-postgres, **kèm `tags: ["report_kn", "report_kso"]`** cho cả 2 DAG đang dùng nó —
thiếu tag là lặp lại đúng lỗi `relation does not exist` của
`stg_common_tongquan_khachhang_sm_pr` (xem comment trong `dbt_project.yml`).

---

## 8. Rủi ro & nợ kỹ thuật đã phát hiện

### 8.1. Nhân dòng từ `stag_payment_transfer`

`kso_spt` join theo `(crm_id, clineid, product_id)` nhưng khóa này **không duy nhất**:
trong 156.815 dòng có **33.465 dòng trùng khóa** (một dòng dịch vụ được thu tiền
nhiều lần). Đây là nguyên nhân `stg_kso_map` có 152.383 dòng trong khi chỉ có
138.230 dòng dịch vụ phân biệt.

Cần xác nhận với nghiệp vụ: `doanh_so` và `tong_tien` có bị tính trùng không.

`stag_crm_booking_arrival_company` thì **an toàn** — 3.985 dòng / 3.985 `crm_id`, duy nhất.

### 8.2. Chất lượng cột `date`

| Nhánh | `date` NULL | Khoảng thời gian |
|---|---|---|
| `BK` | 0 | 2021-10-05 → 2026-09-16 |
| `DC` | **22.997** (24%) | 2022-03-22 → 2026-09-16 |
| `HL` | 0 | 2019-06-21 → **2202-06-22** |
| `Lead_total` | 0 | 2026-01-01 → 2026-09-16 |
| `DS` | 0 | 2025-08-01 → 2026-09-16 |
| `TC` | 894 | 2022-06-22 → 2026-09-16 |

- **`HL` có `date` = `2202-06-22`**: lỗi nhập liệu `booking_date` ở nguồn (năm 2202
  thay vì 2022). Sẽ phá vỡ trục thời gian của mọi biểu đồ nếu không chặn.
- **`DC` có 22.997 dòng NULL**: hợp lý về nghiệp vụ (`arrival_date` chưa có khi khách
  chưa đến), nhưng cần lọc khi vẽ báo cáo.

### 8.3. `union all select *` ở mart rất mong manh

Mart union 6 nhánh bằng `select *`. Chỉ cần một file `stg_kso_*` thêm/bớt cột lệch
thứ tự là dữ liệu **trộn sai cột mà không báo lỗi** nếu kiểu tương thích.

> **Quy tắc bắt buộc khi sửa:** thêm hay bớt cột thì phải làm **đồng thời ở cả 6 file**
> `stg_kso_{lead,bk,hl,dc,tc,ds}.sql` và **ở đúng cùng một vị trí**. Sau khi sửa,
> chạy `EXCEPT ALL` hai chiều trên các cột cũ để xác nhận không xê dịch dữ liệu
> (xem mục 7.4).

### 8.4. `ma_booking` không phải khóa duy nhất

`crm_lead.name` có 283.325 dòng nhưng chỉ 197.015 giá trị phân biệt. **Không dùng
`ma_booking` làm khóa join** từ bảng mart ngược về CRM — sẽ nhân dòng.

### 8.5. Hai model chết

`kso_cline_product` và `kso_page` không được model nào `ref()`. Vì là `ephemeral` nên
dbt không build, lỗi (nếu có) sẽ bị ẩn.

### 8.6. `stg_kso_tongquan_kh_sm.sql` — file nháp có lỗi cú pháp

File này **không được model nào `ref()`**, gần như là bản nháp trùng lặp của
`stg_kso_map`, và **có lỗi cú pháp thật**:

- `leftj join` (thừa chữ `j`)
- `spt.crm_id = ecl.id` — alias `ecl` không tồn tại trong scope

Vì là `ephemeral` không ai ref nên dbt không build và lỗi bị ẩn hoàn toàn.
Cần xoá hoặc sửa, nhưng **chưa xử lý** vì nằm ngoài phạm vi thay đổi hiện tại.

### 8.7. Hard-code mốc thời gian

`kso_spt` lọc `payment_date >= '2025-08-01'` viết cứng trong SQL, trong khi project đã
có biến `var('start_date')` (hiện cũng là `'2025-08-01'`). Nếu backfill đổi
`start_date` thì nhánh doanh số sẽ không đổi theo.

### 8.8. `stg_dv_khach_hang_quan_tam` thiếu `WHERE brand_etl` (đã sửa 2026-10-08)

File `models/common/stg_dv_khach_hang_quan_tam.sql` **không có `WHERE` nào** kể từ khi
tạo, dù bản song sinh `stg_dv_khach_hang_quan_tam_paris.sql` có `WHERE cln.brand_etl = 3`
và comment đầu file bản Paris ghi rõ *"bản gốc chỉ tính brand_etl = 1 - Kangnam"*.

Số đo trên DWH ngày **2026-10-08**:

| Phép đo | Kết quả |
|---|---|
| `crm_line` tổng số dòng | **1.711.031** |
| `crm_line` brand_etl = 1 | ~138.436 (8%) |
| `crm_id` xuất hiện ở **nhiều hơn 1** `brand_etl` | **61.408** |
| `crm_line` không khớp `crm_lead` (orphan) | 16 |

Vì `crm_lead.id` **không unique toàn cục**, `ROW_NUMBER() OVER (PARTITION BY crm_id ...)`
gộp các brand khác nhau vào cùng 1 partition → chỉ 1 dòng sống sót cho mỗi `crm_id`.
Nếu dòng thắng không thuộc brand 1 thì join của consumer
(`dkq.crm_id = cl.id AND dkq.brand_etl = cl.brand_etl`) bị MISS → nhãn ra `KXĐ` **sai**.

**Phạm vi ảnh hưởng: cả `func_report_marketing_ad_cost_kn`** (2 cột
`nhom_dv_KH_quan_tam`, `nhom_dv_KH_quan_tam_goc`), không chỉ báo cáo này. Sau khi thêm
`WHERE cln.brand_etl = 1`, số của 2 cột đó ở `func_report_marketing_ad_cost_kn`
**sẽ đổi** — phải đối chiếu lại.

`stg_dv_khach_hang_quan_tam_paris.sql` **không** bị bug sai nhãn vì đã có
`WHERE cln.brand_etl = 3` đúng. Nó cũng giữ 5 cột thông tin booking như bản KN
(xem mục 7b.4 điểm 2) — nhất quán, không cần dọn.

### 8.9. `table_team_sale_trans_field` là VIEW — nút cổ chai thật của model (đã sửa 2026-10-08)

Chẩn đoán bằng `EXPLAIN` của đúng câu SQL đã chạy ra **383,7s** (2026-10-08).

**Nó không phải bảng mà là VIEW** (`relkind = 'v'`, **799 dòng**) — nên `CREATE INDEX`
trả `SQL Error 42809`. Thân view là `UNION ALL` 2 nhánh + 1 `EXISTS`:

```
cs_agents_api_trans_field      WHERE EXISTS (table_team_sale_group_trans_field)
UNION ALL
table_team_sale_trans_field_backup
```

6 slice gọi view này trong `join lateral` **tương quan**, nên mỗi vòng lặp Postgres
chạy lại toàn bộ thân view:

| Node trong lateral | cost |
|---|---|
| `Seq Scan on cs_agents_api_trans_field` | 132.55 |
| `HashAggregate on table_team_sale_group_trans_field` | 17.00 |
| `Seq Scan on table_team_sale_trans_field_backup` | 4.77 |
| **tổng / 1 vòng lặp** | **157.15** |

Nhân với số vòng lặp ước lượng (~2,0M/slice × 6 slice) → **~1,31 tỷ** trên tổng cost
**1,426 tỷ** của cả query. Đây là term chiếm gần hết chi phí — không phải
`stg_dv_khach_hang_quan_tam` như phỏng đoán ban đầu.

**Cách sửa đã áp dụng:** thêm `int/kn_sale_online/kso_team_sale.sql` vật hoá view thành
**bảng có index** `(work_email, expiration_date)` do dbt quản lý (`materialized = 'table'`
+ config `indexes`), rồi 6 slice đổi từ gọi view trần sang `{{ ref('kso_team_sale') }}`.
Mỗi vòng lặp từ 3 seq scan → 1 index scan trên 799 dòng.

Kèm theo: **bỏ `date()` ở phía cột** trong 6 slice
(`date(sc.expiration_date) >= X` → `sc.expiration_date >= X`) để điều kiện sargable,
index mới dùng được cho cả phần range. Tương đương tuyệt đối, chứng minh ở mục 8.9.1.

Phụ: 6 slice trước đây gọi bảng **trần**, không qua `{{ source() }}`, dù
`int/kn_sale_online/source.yml` **đã khai báo sẵn** `kso_crm_base.table_team_sale_trans_field`
(các báo cáo khác như `ktt_combine`, `hso_combine` đều gọi đúng qua `source()`). Nay đã
đi qua `ref()` nên dbt quản lý được lineage.

#### 8.9.1. Chứng minh bỏ `date()` không đổi kết quả

`expiration_date` kiểu `timestamp without time zone`. Với mọi `d` kiểu `date`:

```
date(ts) >= d   ⟺   ts >= d::timestamp        (d::timestamp = 00:00:00 của ngày d)
  (→) date(ts) >= d      ⟹ ts >= đầu ngày date(ts) >= đầu ngày d
  (←) ts >= đầu ngày d   ⟹ date(ts) >= d
```

NULL khớp cả 2 chiều. `date()` ở **phía phải** giữ nguyên: nhánh `DS` dùng
`date(stks.ngay_tt)` mà `ngay_tt` = `stag_payment_transfer.payment_date` **thô**
(khác `ngay_tao`/`ngay_den_cua`/`ngay_hl` đã là `date` sẵn từ `kso_crm_lead`) — bỏ
`date()` bên phải **sẽ** làm nhánh `DS` lệch.

#### 8.9.2. Nondeterminism có sẵn trong lateral

`order by expiration_date limit 1` **không có tie-break**: 2 dòng cùng `work_email`
trùng `expiration_date` thì dòng nào thắng là không xác định, có thể đổi giữa các lần
chạy. Đây là hành vi có sẵn từ trước; vật hoá không làm nặng thêm. Muốn tiền định phải
thêm tie-break → sẽ đổi số, nên chưa làm.

### 8.10. Row estimate của `stg_kso_map` lệch ~2.600× — cần `ANALYZE`

Cũng từ `EXPLAIN` ngày 2026-10-08:

```
CTE __dbt__cte__stg_kso_map
  ->  Merge Left Join  (cost=20251482.42..80333455.60 rows=401512766 ...)
```

Planner ước lượng `stg_kso_map` ra **401.512.766 dòng**, thực tế là **152.383**
(mục 4.3) — lệch **~2.600 lần**. Hai chỗ phình:

| Nhánh | Ước lượng | Nguyên nhân |
|---|---|---|
| `kso_cline ⟕ kso_product` on `product_id` | 382.449 → **39.352.090** (~103×) | planner tưởng `view_stag_products` có `product_id` trùng nhiều |
| `crm_lead ⟕ kso_employees` on `user_id` | 321.878 → **2.278.339** (~7×) | planner tưởng `stag_employees.user_id` trùng |

Ước lượng sai cỡ này khiến planner chọn plan tệ: `Sort` 39M dòng
(cost 16.2M), `Materialize` 2,27M dòng, và bật **JIT với 349 functions**
(`Inlining true, Optimization true`) — JIT compile trên plan lớn là chi phí thuần.

Việc cần làm (DBA, an toàn, không khoá bảng lâu):

```sql
ANALYZE crm_line, crm_line_product, crm_lead, stag_products, product_template,
        product_category, stag_employees, stag_payment_transfer;
```

Nếu sau `ANALYZE` mà estimate vẫn lệch thì cân nhắc nâng `default_statistics_target`
cho các cột join, hoặc `CREATE STATISTICS` cho cặp cột tương quan.

Nếu JIT vẫn là phần đáng kể (xem dòng `JIT:` trong `EXPLAIN (ANALYZE)`), tắt riêng cho
model này:

```
{{ config(pre_hook = "set local jit = off") }}
```

### 8.11. `crm_line` to ra 2,69× do backfill ở TẦNG NGUỒN (phát hiện 2026-10-08)

Sau lần build 2026-10-08, mart ra **1.129.859 dòng** thay vì **428.297**. Đã truy đến gốc
và kết luận: **`1.129.859` là số ĐÚNG, `428.297` là số THIẾU dữ liệu.** Model không có
lỗi nhân dòng ở mốc nào.

#### 8.11.1. Bằng chứng loại trừ

| Phép kiểm | Kết quả | Loại trừ được gì |
|---|---|---|
| `crm_line` brand 1: `count(*)` vs `count(distinct id)` | 372.296 / 372.296, **trùng = 0** | không nạp trùng thô |
| `count(*)` / `count(distinct (crm_id, product_id))` | **1,023×** | không phải ETL nạp lại cấp `id` mới (nếu vậy sẽ ≈ 2,0). 2,3% trùng khoá là hành vi nghiệp vụ bình thường |
| dòng `crm_line` lọt filter product | 372.261 / 372.296 = **99,99%** | filter `product_category <> 'SAN PHAM'` chỉ loại 35 dòng → không phải nguyên nhân |
| `view_stag_products` brand 1 | 20.782 dòng, **0 dòng `product_category` NULL** | không phải do backfill `product_category` |
| `stag_payment_transfer` fan-out | 165.921 dòng / 129.717 khoá = **1,28×**, T3 372.039 → T4 406.180 (**+1,09×**) | `kso_spt` (mục 8.1) **không** phải nguyên nhân chính |
| `stg_kso_map` vs `kso_cline` | ≈ nhau ở **cả 2** mốc | model không nhân dòng |
| `dkq` (2 cột mới, mục 7b) | 230.737 dòng / 230.736 `crm_id` + 1 dòng NULL | join này đúng 1 dòng/`crm_id`, **không thể** fan-out |

#### 8.11.2. Bằng chứng xác định — phân bố `create_date`

`crm_line` brand 1 theo tháng `create_date` (2026-10-08):

```
2021-10 → 2025-06 :   ~300–1.700 / tháng    (cửa sổ ETL cũ, thưa)
2025-07           :    4.679
2025-08           :   30.323   ← bậc nhảy, trùng var start_date = '2025-08-01'
2025-09 → 2026-09 :  20.000–28.000 / tháng
2026-10 (dở dang) :    5.250
                     ─────────
                      372.296
```

Từ 2025-08 đến 2026-09 là 14 tháng × ~24k ≈ **336k dòng**. Nhưng ngày 2026-09-17 bảng
chỉ có **138.436** dòng — để tổng chỉ 138k thì mỗi tháng lúc đó phải ~10k, hôm nay là
~24k. **Mọi tháng trong quá khứ đều xấp xỉ gấp đôi.** Dữ liệu phát sinh mới không thể
làm tháng 2025-08 dày lên ⇒ chữ ký của **một lần backfill rải khắp lịch sử, xảy ra giữa
2026-09-17 và 2026-10-08**.

(Bậc nhảy ở 2025-08 là cửa sổ ETL có sẵn, trùng đúng `var start_date` trong
`dbt_project.yml` và mốc "Từ 01/08/2025" của báo cáo Tableau — không phải chuyện mới.)

#### 8.11.3. Hệ quả

**Báo cáo trước 2026-10-08 đang báo THIẾU.** Lead / Booking / Đến cửa / Hẹn lịch /
Thành công / Doanh số giai đoạn 08/2025–09/2026 tăng **2,35–2,76×** sau build này. Đây
không phải lỗi mới mà là dữ liệu được hoàn thiện — nhưng **phải thông báo trước** cho
người đọc dashboard.

`crm_line` nằm ở **tầng nguồn**, nên **mọi** model đọc nó đều đổi số, không riêng báo
cáo này: `func_report_marketing_ad_cost_kn`, `report_hh_sale_online`,
`report_thv_sale_online`, `report_convert_kangnam`, `report_kn_tele_transfer`…

#### 8.11.4. Việc còn mở

Chưa xác định **ngày** và **chủ sở hữu** của lần backfill. Query để truy (cần biết tên
cột dấu vết thời điểm nạp của `crm_line`, thường là `write_date`):

```sql
select column_name, data_type from information_schema.columns
where table_name = 'crm_line' order by ordinal_position;

select date_trunc('day', write_date)::date as ngay_ghi, count(*)
from crm_line where brand_etl = 1 and write_date >= '2026-09-01'
group by 1 order by 1;
```

Việc này thuộc đội vận hành pipeline nạp `crm_line`, không thuộc model này. Ghi lại ở
đây để không ai phải điều tra lại từ đầu.

---

## 9. So sánh với `func_report_marketing_ad_cost_kn`

| | `report_kn_sale_online` | `func_report_marketing_ad_cost_kn` |
|---|---|---|
| Chủ đề | Hiệu suất sale online theo nhân viên / team | Chi phí & hiệu quả marketing |
| Số nhánh nguồn | **6**, thuần CRM | **9** (thêm FB insight, Google Ads, Inbox, Caresoft deal) |
| Nghiệp vụ | Gói trong đúng 1 file (`stg_kso_map`) + 6 bộ lọc | 3 tầng xử lý thật (`fb_cost` → `union` → `region`) |
| Tái sử dụng `models/common/` | Có từ 2026-10-07 — `stg_dv_khach_hang_quan_tam` (xem mục 7b); phần còn lại tự dựng `kso_*` | Có — dùng `stg_common_tongquan_khachhang` |
| Cột ngày tạo từ `crm_lead` | `create_date` | `create_on` (lệch 1.423 bản ghi) |
| Lọc `crm_lead` | `brand_etl = 1`, `active is true` | `brand_etl = 1`, `active = true`, `create_on >= 2024-01-01` |
| Parse tên campaign | Không | Có (token 2/3/5/8) |

Hai model đọc **cùng một bảng vật lý** `crm_lead` ở **cùng một schema** — các tên
source `kso_crm_base`, `crm_base`, `kangnam` chỉ là alias logic khác nhau trỏ về
cùng chỗ.

---

## 10. Lệnh chạy

```bash
dbt run --select tag:report_kso
```

Thời gian build thực tế:

| Mốc | Thời gian | Dòng | Ghi chú |
|---|---|---|---|
| 2026-09-17 | ~155s | 428.297 | 23 cột, dữ liệu nguồn còn thiếu |
| 2026-10-07 | 354,1s | — | vừa thêm 2 cột `nhom_dv_kh_quan_tam*` |
| 2026-10-07 | 383,7s | — | sau khi sửa `WHERE brand_etl = 1` (sửa bug, không phải tối ưu) |
| **2026-10-08** | **36,12s** | **1.129.859** | sau khi vật hoá `kso_team_sale` (mục 8.9) — **10,6×** |

DAG giờ có 2 model: `kso_team_sale` (0,22s, 799 dòng) → `report_kn_sale_online` (36,12s).

> **Lịch sử tên bảng đích:**
>
> | Thời điểm | Cấu hình | Bảng đích |
> |---|---|---|
> | Trước 2026-09-17 | không alias | `report_kn_sale_online` (22 cột) |
> | 2026-09-17 | `alias = 'report_kn_sale_online_v2'` | `report_kn_sale_online_v2` (23 cột, thêm `vk`) |
> | 2026-09-18 | **bỏ alias** | `report_kn_sale_online` (23 cột, có `vk`) |
> | 2026-10-07 | không đổi cấu hình | `report_kn_sale_online` (25 cột, thêm `nhom_dv_kh_quan_tam` + `nhom_dv_kh_quan_tam_goc`) |
>
> Sau khi bỏ alias, `dbt run` ghi thẳng vào `report_kn_sale_online` — dashboard giữ
> nguyên tên cũ, không cần trỏ lại. Bảng `report_kn_sale_online_v2` trở thành bảng
> **mồ côi**: dbt không còn quản lý, không được cập nhật, và **dbt cũng không tự xoá
> nó** — cần xoá tay khi đã xác nhận không còn ai dùng.
