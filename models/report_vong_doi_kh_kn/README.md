# report_vong_doi_kh_kn — Logic Model

Báo cáo **vòng đời khách hàng** (customer lifecycle) Kangnam. Với mỗi khách hàng
đã đến cửa, xác định tư vấn viên (TVV) nào được "ghi công" (attribution) cho các
dịch vụ thành công, dựa trên nguyên tắc: *TVV chốt được khách ngay từ lần đến cửa
đầu tiên sẽ được tính công cho các lần chốt tiếp theo, MIỄN LÀ khách vẫn liên tục
quay lại gặp đúng TVV đó — hễ đứt mạch (khách gặp TVV khác xen giữa) thì các
thành công sau điểm đứt không tính công cho TVV ban đầu nữa.*

Output chính: `mart_rvdkk_data_vong_doi` (bảng vòng đời) và `mart_rvdkk_data_sankey`
(dữ liệu cho biểu đồ Sankey, alias `func_data_vong_doi_khach_hang`).

## 1. Sơ đồ pipeline (bottom-up)

```
stg (crm_lead, crm_line, stag_products, stag_payment_transfer,
     crm_information_consultant, res_users/res_partner/hr_employee/hr_department, ...)
        │
        ├─► int_rvdkk_tu_van1 (tv1)          — resolve tên + phòng ban TVV (2 cách join, fallback theo email)
        │
        ▼
int_rvdkk_data_final  — JOIN cốt lõi: mỗi crm_line = 1 dịch vụ trong booking
        │   dv_tc = 'DV thành công' nếu SUM(payment) theo cl2.id > 0
        ▼
int_rvdkk_data1   — bỏ crm_type='Lead new', bắt buộc ngay_den_cua NOT NULL (khách đã đến cửa)
        ▼
int_rvdkk_data2   — tong_da_nhan_book (SUM theo id_lead), book_tc, ma_kh_new = coalesce(ma_kh, phone)
        ▼
int_rvdkk_data3   — CHỈ với book_tc='Book thành công':
                    rnk        = dense_rank lần đến cửa (theo brand_id, ma_kh_new, order ngay_den_cua)
                    ngay_dc_truoc = lag(ngay_den_cua)
                    min_dc     = ngày đến cửa đầu tiên (mốc bắt đầu vòng đời)
                    (khách chưa Book TC thì 3 cột này = NULL)
        │
        ├──────────────────────────────────────────────┐
        ▼                                                │ (nhánh dv_tc IS NULL — book nhưng
int_rvdkk_data3_1111                                     │  chưa từng có DV thành công)
  filter dv_tc='DV thành công'                           │
  + kh_tv = ma_kh_new-tu_van1_id  (khoá "khách+TVV")     │
        ▼                                                │
int_rvdkk_tv_rnk1: kh_tv có dv_tc TC ngay rnk=1           │
        ▼                                                │
int_rvdkk_data4                                           │
  check_tv_rk1 = 'T' nếu kh_tv ∈ tv_rnk1 (TVV chốt ngay   │
                 từ lần đến cửa đầu), else 'F'             │
        ▼                                                │
int_rvdkk_data5                                           │
  check_rnk_ago: với check_tv_rk1='T', so rnk hiện tại    │
    với rnk liền trước (LEAD...ORDER BY rnk DESC) —       │
    lệch >1 ⇒ 'F' (đứt mạch), lệch=1 ⇒ 'T' (liên tục)     │
    check_tv_rk1='F' ⇒ luôn check_rnk_ago='F'             │
        ▼                                                │
int_rvdkk_stt_table: stt = row_number() theo kh_tv,       │
    order by rnk, check_rnk_ago                           │
        ▼                                                │
int_rvdkk_min_false: với mỗi kh_tv, tìm stt nhỏ nhất       │
    có check_rnk_ago='F'  → điểm đứt mạch đầu tiên         │
        ▼                                                │
int_rvdkk_data_dv_tc:                                     │
    final_result='F' nếu stt >= min_value (từ điểm đứt    │
                    trở đi — không tính công nữa)          │
    final_result='T' nếu trước điểm đứt (hoặc không đứt)   │
        └──────────────────────┬─────────────────────────┘
                                ▼
                    mart_rvdkk_vong_doi (UNION ALL 2 nhánh trên)
                                ▼
                    mart_rvdkk_data_vong_doi
                      filter: brand_id = 1
                              date(min_dc) >= '2022-06-01'
                      + hard-code brand_id=1, thuong_hieu='Kangnam'
                        riêng cho id_lead = 1430632
```

## 2. Lớp `stg`

Toàn bộ model `stg` trong thư mục này chỉ là `SELECT * FROM source WHERE brand_etl = 1`
(1 file/1 bảng nguồn): `crm_lead`, `crm_line`, `crm_stage`, `crm_type`,
`crm_category_source`, `crm_information_consultant`, `stag_sources`,
`stag_products` (không filter `brand_etl` — giữ đúng hành vi bản gốc),
`stag_payment_transfer`, `res_users`, `res_partner`, `hr_employee`,
`hr_department`, `m_res_company`, `res_brand`.

## 3. Lớp `int` — chi tiết từng bước

### `int_rvdkk_tu_van1` (tv1)
Resolve tên + phòng ban của tư vấn viên từ `res_users`:
- Tên: `res_partner.name` theo `partner_id`.
- Phòng ban: ưu tiên join trực tiếp `hr_employee.user_id = ru2.id`; nếu
  không có, fallback join theo email (`lower(work_email) = lower(login)`).

### `int_rvdkk_data_final` (data_final)
JOIN cốt lõi — mỗi dòng là 1 `crm_line` (1 dịch vụ trong 1 booking):
`crm_lead` → `crm_category_source`, `stag_sources`, `crm_stage`, `crm_line`,
`stag_products`, `crm_type`, `stag_payment_transfer` (theo `crm_id`+`clineid`),
tư vấn viên (ưu tiên `crm_line.consultants_1`, fallback
`crm_information_consultant.user_id`), công ty/thương hiệu theo `company_id`
của bản ghi thanh toán.
`dv_tc = 'DV thành công'` nếu `SUM(payment) OVER (PARTITION BY cl2.id) > 0`
(dịch vụ đó có tiền thu, bất kể dòng thanh toán nào trong cùng line).

### `int_rvdkk_data1`
Lọc `crm_type <> 'Lead new'` và `ngay_den_cua IS NOT NULL` — chỉ giữ khách
**đã thực sự đến cửa** (loại Lead thuần chưa từng ghé).

### `int_rvdkk_data2`
Thêm:
- `tong_da_nhan_book` = tổng `doanh_so` theo `id_lead` (toàn bộ booking, mọi dịch vụ).
- `book_tc = 'Book thành công'` nếu `tong_da_nhan_book > 0`.
- `ma_kh_new = COALESCE(ma_kh, phone)` — khoá định danh khách khi chưa có mã KH chính thức.

### `int_rvdkk_data3`
Chỉ tính window function cho khách có `book_tc = 'Book thành công'`
(nhóm theo `brand_id, ma_kh_new`, sắp theo `ngay_den_cua`):
- `rnk` = `dense_rank()` → số thứ tự lần đến cửa.
- `ngay_dc_truoc` = `lag(ngay_den_cua)` → ngày đến cửa lần trước.
- `min_dc` = `min(ngay_den_cua)` → ngày đến cửa đầu tiên, dùng làm mốc vòng đời.
Khách chưa `Book thành công` → 3 cột trên giữ `NULL` (nhánh union riêng).

**Tiêu chí xếp hạng `rnk` (áp dụng đến tận báo cáo cuối `mart_rvdkk_data_vong_doi`):**

```sql
DENSE_RANK() OVER (
    PARTITION BY data2.brand_id, data2.ma_kh_new
    ORDER BY data2.ngay_den_cua
) AS rnk
```

- **Nhóm theo** `brand_id` + `ma_kh_new` — xếp hạng riêng cho từng khách
  trong từng brand (không lẫn giữa các khách/brand khác nhau).
- **Sắp theo** `ngay_den_cua` tăng dần — lần đến cửa sớm nhất = `rnk = 1`,
  kế tiếp = `2`, v.v.
- Dùng **`DENSE_RANK`** (không phải `RANK`/`ROW_NUMBER`): các dòng có **cùng
  ngày đến cửa** (ví dụ nhiều `crm_line`/dịch vụ trong cùng 1 booking — do
  cùng thừa hưởng `ngay_den_cua` từ `crm_lead`) nhận **cùng một `rnk`**; ngày
  kế tiếp không bị nhảy số (không có khoảng trống giữa các `rnk`).
- Nói cách khác, `rnk` = **số thứ tự lần đến cửa** (theo ngày) của khách đó,
  là mốc nền tảng cho toàn bộ logic attribution TVV ở các bước sau
  (`int_rvdkk_tv_rnk1` dùng `rnk = 1` để xác định "công đầu",
  `int_rvdkk_data5` dùng `rnk` để xác định điểm đứt mạch).

**`min_dc` — ngày đến cửa đầu tiên (mốc bắt đầu vòng đời):**

```sql
MIN(data2.ngay_den_cua) OVER (
    PARTITION BY data2.brand_id, data2.ma_kh_new
) AS min_dc
```

- Cùng khoá nhóm với `rnk` (`brand_id, ma_kh_new`), nhưng **không có `ORDER BY`**
  nên lấy giá trị nhỏ nhất `ngay_den_cua` trên **toàn bộ nhóm** (không phải
  cumulative/rolling) — mọi dòng của cùng 1 khách đều nhận **cùng một giá trị**
  `min_dc`, chính là ngày ứng với `rnk = 1`.
- Chỉ tính cho khách có `book_tc = 'Book thành công'`; nhánh 2 (`book_tc IS NULL`)
  thì `min_dc = NULL`.
- **Vai trò downstream:** cả `mart_rvdkk_data_vong_doi` lẫn `mart_rvdkk_data_sankey`
  đều filter `date(min_dc) >= '2022-06-01'` — chỉ khách có lần đến cửa đầu tiên
  từ mốc này trở đi mới nằm trong phạm vi báo cáo (khách cũ hơn bị loại hoàn
  toàn, kể cả các lần đến cửa sau này của họ).

### `int_rvdkk_data3_1111`
Lọc `dv_tc = 'DV thành công'` từ `data3`, thêm khoá
`kh_tv = ma_kh_new || '-' || tu_van1_id` (định danh cặp "khách + tư vấn viên").

### `int_rvdkk_tv_rnk1`
Danh sách `kh_tv` mà TVV đó chốt được dịch vụ thành công **ngay ở lần đến cửa
đầu tiên** (`rnk = 1`).

### `int_rvdkk_data4`
`check_tv_rk1 = 'T'` nếu `kh_tv` nằm trong `tv_rnk1` (TVV có công đầu), else `'F'`.

### `int_rvdkk_data5`
`check_rnk_ago` — đánh dấu tính liên tục của chuỗi lần-đến-cửa với cùng TVV:
- Với `check_tv_rk1 = 'T'`: so `rnk` hiện tại với `rnk` liền trước (lấy bằng
  `LEAD(rnk,1) OVER (PARTITION BY kh_tv ORDER BY rnk DESC)` — cách viết ngược
  để lấy giá trị rnk nhỏ hơn kế tiếp mà không cần subquery). Chênh lệch > 1
  ⇒ `'F'` (đứt mạch — có lần khách đến cửa gặp TVV khác xen giữa); chênh lệch
  = 1 ⇒ `'T'` (liên tục).
- Với `check_tv_rk1 = 'F'`: luôn `'F'` (TVV này vốn không có công đầu nên
  không tính chuỗi liên tục).

### `int_rvdkk_stt_table`
`stt = ROW_NUMBER() OVER (PARTITION BY kh_tv ORDER BY rnk, check_rnk_ago)` —
đánh số thứ tự trong từng nhóm `kh_tv` để xác định vị trí điểm đứt mạch.

### `int_rvdkk_min_false`
Với mỗi `kh_tv`, tìm `stt` nhỏ nhất có `check_rnk_ago = 'F'` → vị trí đứt
mạch đầu tiên (`min_value`).

### `int_rvdkk_data_dv_tc`
`final_result = 'F'` nếu `stt >= min_value` (từ điểm đứt mạch trở đi — không
còn tính công cho TVV này nữa); `final_result = 'T'` nếu trước điểm đứt (hoặc
`kh_tv` đó chưa từng đứt mạch).

## 4. Lớp `mart`

### `mart_rvdkk_vong_doi` (alias `func_data_vong_doi_khach_hang`)
`UNION ALL` 2 nhánh:
1. `int_rvdkk_data_dv_tc` — toàn bộ dịch vụ thành công đã được gắn `final_result`.
2. `int_rvdkk_data3` `WHERE dv_tc IS NULL` — booking có đến cửa nhưng **chưa
   từng** có dịch vụ thành công; `kh_tv`, `check_tv_rk1`, `check_rnk_ago`,
   `stt`, `final_result` set cứng `NULL` (không tham gia tính attribution,
   chỉ giữ để báo cáo đầy đủ lịch sử đến cửa).

### `mart_rvdkk_data_vong_doi`
Wrapper mỏng trên `mart_rvdkk_vong_doi`:
- `WHERE brand_id = 1 AND date(min_dc) >= '2022-06-01'`.
- Vá cứng dữ liệu: `id_lead = 1430632` → ép `brand_id = 1`,
  `thuong_hieu = 'Kangnam'` (bản ghi gốc có brand/thương hiệu sai, không rõ
  nguyên nhân gốc — cần lưu ý khi refactor vì không có comment giải thích).

### `mart_rvdkk_data_sankey`
Dùng chung `mart_rvdkk_vong_doi`, lọc thêm `dv_tc = 'DV thành công'`, loại 2
mã booking `BOOK-220507-00429` và `BOOK-221106-00350` (nghi dữ liệu lỗi/trùng),
cùng điều kiện `min_dc >= 2022-06-01`. Kết quả là **UNION của chính nó với
chính nó**, chỉ khác cột `data_type` (`'data_goc'` / `'data_duplicate'`) —
kỹ thuật tạo cặp node nguồn/đích cho biểu đồ Sankey (mỗi khách cần xuất hiện
ở cả 2 phía luồng).

## 5. Rủi ro / điểm cần lưu ý khi sửa đổi

1. **`ma_kh_new = COALESCE(ma_kh, phone)`** dùng làm khoá nhóm vòng đời —
   nếu khách đổi SĐT hoặc 1 SĐT dùng chung cho nhiều người, vòng đời sẽ bị
   tách/gộp sai.
2. **`dv_tc` (cấp dịch vụ) khác `book_tc` (cấp booking)** — một booking có
   thể `book_tc = 'Book thành công'` nhưng từng dòng dịch vụ riêng lẻ vẫn
   `dv_tc IS NULL` nếu tiền được ghi nhận ở dòng khác trong cùng booking.
3. **Hard-code `id_lead = 1430632`** ở `mart_rvdkk_data_vong_doi` và
   `mart_rvdkk_data_sankey` — patch dữ liệu tạm thời tại tầng mart thay vì
   sửa ở nguồn, dễ bị bỏ sót khi refactor về sau.
4. **`stag_products` không filter `brand_etl`** (khác với các bảng còn lại) —
   giữ đúng hành vi bản gốc nhưng là điểm bất thường nên biết trước khi
   troubleshoot lệch số liệu theo brand.
