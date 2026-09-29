# report_kn_sale_online — Logic Model

Báo cáo hiệu suất sale online Kangnam. Output cuối cùng là bảng
`report_kn_sale_online`.

Toàn bộ số liệu đo trong tài liệu này được lấy trực tiếp từ DWH ngày **2026-09-17**.

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
    │  stg_kso_map  ←  TRÁI TIM của model        │  join 11 nguồn → 152.383 dòng
    └─────────┬──────────────────────────────────┘
              │  cùng 1 tập dữ liệu, cắt 6 lát theo loại bản ghi + mốc thời gian
   ┌──────┬───┴───┬───────┬───────┬───────┐
 Lead_total  BK    HL      DC      TC      DS
   └──────┴───┬───┴───────┴───────┴───────┘
              │  UNION ALL
      report_kn_sale_online  →  428.297 dòng × 23 cột
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

| Chỉ số | Giá trị |
|---|---|
| Số dòng `stg_kso_map` | **152.383** |
| Số booking (`crm_lead`) phân biệt | 87.594 |
| Số dòng dịch vụ (`line_id`) phân biệt | 138.230 |

Chênh lệch **152.383 − 138.230 ≈ 14.153 dòng bị nhân thêm** — xem mục 8.1.

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

Kết quả: **428.297 dòng × 23 cột** = 55.376 + 94.465×3 + 37.814 + 51.712.

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

---

## 9. So sánh với `func_report_marketing_ad_cost_kn`

| | `report_kn_sale_online` | `func_report_marketing_ad_cost_kn` |
|---|---|---|
| Chủ đề | Hiệu suất sale online theo nhân viên / team | Chi phí & hiệu quả marketing |
| Số nhánh nguồn | **6**, thuần CRM | **9** (thêm FB insight, Google Ads, Inbox, Caresoft deal) |
| Nghiệp vụ | Gói trong đúng 1 file (`stg_kso_map`) + 6 bộ lọc | 3 tầng xử lý thật (`fb_cost` → `union` → `region`) |
| Tái sử dụng `models/common/` | Không — tự dựng riêng `kso_*` | Có — dùng `stg_common_tongquan_khachhang` |
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

Thời gian build thực tế: **~155 giây** (1 model table, 428.297 dòng).

> **Lịch sử tên bảng đích:**
>
> | Thời điểm | Cấu hình | Bảng đích |
> |---|---|---|
> | Trước 2026-09-17 | không alias | `report_kn_sale_online` (22 cột) |
> | 2026-09-17 | `alias = 'report_kn_sale_online_v2'` | `report_kn_sale_online_v2` (23 cột, thêm `vk`) |
> | 2026-09-18 | **bỏ alias** | `report_kn_sale_online` (23 cột, có `vk`) |
>
> Sau khi bỏ alias, `dbt run` ghi thẳng vào `report_kn_sale_online` — dashboard giữ
> nguyên tên cũ, không cần trỏ lại. Bảng `report_kn_sale_online_v2` trở thành bảng
> **mồ côi**: dbt không còn quản lý, không được cập nhật, và **dbt cũng không tự xoá
> nó** — cần xoá tay khi đã xác nhận không còn ai dùng.
