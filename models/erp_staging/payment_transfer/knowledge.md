# knowledge.md — erp_staging/payment_transfer: bài học mới so với products/employees

Quy trình đối chiếu chung (dbt show --inline, EXCEPT 2 chiều, cách kiểm tra khoá tự
nhiên không lịch sử hoá...) đã ghi ở `erp_staging/products/knowledge.md` — không lặp
lại ở đây. File này chỉ ghi **những gì mới** phát hiện khi làm `stag_payment_transfer`.

## Kết quả đối chiếu (build ngày 2026-07-25)

Row count khớp tuyệt đối: **816,719 / 816,719**. Diff 2 chiều (EXCEPT toàn bộ 33 cột)
ban đầu ra **440 dòng lệch** (0.054%). Sau khi sửa lỗi mục 1 bên dưới: còn **421 dòng**,
toàn bộ tập trung ở mục 2 (không phải lỗi dịch, xem giải thích).

## 1. [ĐÃ SỬA] `PARTITION BY` gộp mọi NULL `clineid` làm 1 nhóm — lặp lại đúng bẫy đã
   ghi ở `products/knowledge.md` mục 3, lần này ở `int_sptr_ranked.sql`

Thanh toán cosmetic "mồ côi" (dòng `crm_account_payment_product_detail` mà
`crm_line_product_id` không còn tồn tại trong `crm_line_product` — left join thất bại)
có `clineid IS NULL`. `windowed` CTE tính 3 cột bằng window function
`PARTITION BY (brand_etl, clineid, product_type)`:
`first_date_payment_calc`, `rnk_clineid_pmdate_calc`, `rnk_clineid_pmdate_desc`.

Postgres gộp **toàn bộ** dòng `clineid IS NULL` (mọi `crm_id` khác nhau) vào **1 partition
chung**, tính ra `MIN(payment_date)`/`DENSE_RANK()` thật cho nhóm đó. Bản Python gốc dùng
`df_spt.groupby(['brand_etl','clineid','product_type'])['payment_date'].transform(...)`
— `pandas.groupby` mặc định `dropna=True`: dòng có key `NaN` không thuộc nhóm nào,
`transform` trả `NaN` cho toàn bộ chúng, **độc lập với nhau** (không gộp NaN với NaN).

Hậu quả trước khi sửa: 47 dòng có `first_date_payment`/`rnk_clineid_pmdate`/
`rnk_clineid_pmdate_desc` là 1 giá trị tính "hộ" từ các dòng mồ côi khác (thường không
liên quan gì tới dòng đó), trong khi bảng thật đúng ra phải là `NULL`.

**Cách sửa**: ép `NULL` tường minh khi `clineid IS NULL`, giữ nguyên window function cho
các dòng còn lại (partition theo `clineid` khác NULL vốn đã đúng — Postgres chỉ gộp sai
riêng nhánh NULL):
```sql
case when b.clineid is not null then
    min(b.payment_date) over (partition by b.brand_etl, b.clineid, b.product_type)
end as first_date_payment_calc
```
Xác nhận: sau khi sửa, 3 cột trên **0 lệch** trên toàn bộ 816,719 dòng (giảm từ 47/47/47).

Lưu ý: bước `COALESCE(ci.first_date_payment, w.first_date_payment_calc)` và
`w.rnk_clineid_pmdate_calc + COALESCE(fd.rnk_clineid_pmdate, 0)` phía sau **không cần
sửa** — 2 bước đó vốn là fallback qua `crm_id`/`(crm_id,clineid)` từ `int_sptr_fdate`,
độc lập với lỗi partition, và đúng ngay từ đầu (khớp cấu trúc 2 bước fillna của Python).

## 2. [KHÔNG SỬA — hạn chế đã biết] Trùng tuyệt đối khoá sắp xếp giữa 2 vế điều chuyển
   cùng 1 giao dịch → thứ tự cộng dồn không xác định được

`int_sptr_final_calc.sql` tính `total_received_cumsum`/`total_received_recal` bằng
`SUM(...) OVER (... ORDER BY payment_date, is_priority DESC, write_date)`. Với 2 vế
outbound/inbound của **cùng 1 phiếu điều chuyển** (`int_sptr_transfer_base`), khi rơi
vào cùng `(crm_id, clineid, product_id)` (2 dòng transfer chéo giữa cùng 1 cặp dịch vụ),
`payment_date`, `is_priority`, và **`write_date` (tới micro-giây)** có thể **trùng tuyệt
đối** — đã xác minh trực tiếp trên dữ liệu thật (`ti-172968-1`/`to-172969-1`,
`payment_date = 2026-07-03`, `write_date = 2026-07-03T09:39:06.470870` giống hệt nhau).

Khi khoá `ORDER BY` trùng hoàn toàn, Postgres **không đảm bảo thứ tự tie-break ổn định**
— và quan trọng hơn: 2 window function khác nhau trong cùng 1 câu query (cumsum dùng
`ROWS UNBOUNDED PRECEDING`, recal dùng `ROWS UNBOUNDED FOLLOWING`, 2 partition khác nhau)
**có thể tự chọn thứ tự tie-break khác nhau**, nên `total_received_cumsum` của 1 dòng và
`total_received_recal` (lẽ ra phải là giá trị cumsum cuối cùng của cùng nhóm) có thể
không khớp nhau nếu chỉ nhìn qua loa.

Đã xác minh đây **không phải lỗi dịch** (không phải do `clineid`/`product_id` tính sai,
không phải do dữ liệu nguồn đã đổi): với 4 dòng mẫu lệch, `clineid`/`product_id` giữa
bảng thật và dbt khớp 100% — chỉ có thứ tự cộng dồn/tổng lệch, và tổng của từng partition
lúc bị lệch **không cộng đúng bằng tổng payment thật của partition đó phía dbt**, cho thấy
2 window function trong cùng batch cũng có thể tie-break khác nhau nội bộ.

Bản Python gốc **cũng không có tiêu chí phân định** khi trùng khoá này
(`sort_values([...,'write_date'])` không có cột phụ nào để phá trùng) — thứ tự phụ thuộc
thứ tự dòng tới trước khi sort (thứ tự trả về của query gốc, vốn không có `ORDER BY` rõ
ràng). Vì vậy đây là **sự mơ hồ có sẵn trong thiết kế gốc**, không phải khoảng lệch phát
sinh khi dịch sang dbt.

**Quyết định**: không thêm tiêu chí phân định nhân tạo (vd `id`) vào `ORDER BY` — vì làm
vậy sẽ tạo ra 1 thứ tự "ổn định" nhưng **không có căn cứ nghiệp vụ**, khác với bất kỳ thứ
tự nào bản Python từng tạo ra, dễ gây hiểu lầm là đã "khớp đúng" trong khi thực chất chỉ
là chọn 1 trong nhiều đáp án đều hợp lệ như nhau. Ghi nhận là hạn chế đã biết: khoảng 420
dòng (~0.05%) liên quan tới các vế điều chuyển trùng timestamp có thể lệch
`total_received_cumsum`/`total_received_recal`/(hiếm hơn) `quantity`/`number_used`/
`total_received` giữa các lần build, và có thể lệch so với bảng thật đã đóng băng trước
đó — không ảnh hưởng tới `total`/`payment`/`total_received` (số tiền gốc luôn đúng), chỉ
ảnh hưởng cột lũy kế/thứ tự hiển thị.

## 3. [2026-09-08, CỐ Ý KHÁC bản gốc] Lọc `is_delete` ở 3 bảng nguồn — bản Python gốc KHÔNG lọc

Phát hiện khi đối chiếu doanh số Kangnam T8/2026 với `report_kpi_bonus_commission`/Tableau (workbook
"KANGNAM - BỘ CHỈ SỐ KINH DOANH - 2025.twbx", đã verify) — lệch +56.300.000đ, truy ra: 1 phiếu thanh
toán bị ERP sửa/huỷ, `crm_account_payment_detail` lưu CẢ 2 bản (bản cũ `is_delete=true` — tombstone
CDC, bản mới thay thế `is_delete=null`), `stag_payment_transfer` cộng dồn cả 2 → trùng doanh số.

Cột `is_delete` có ở `crm_account_payment_detail` (595/104,480 dòng), `crm_account_payment_product_detail`
(77/26,685), `crm_transfer_payment` (2/2,143 — bảng header, CHƯA xử lý, xem chú thích ở
`stg_sptr_crm_transfer_payment_line.sql`), `crm_transfer_payment_line` (9/17,175). Đã thêm
`where coalesce(is_delete, false) = false` vào 3 stg model tương ứng (trừ header
`crm_transfer_payment`).

**Đây là sai lệch CÓ CHỦ Ý so với bản Python gốc** — đối chiếu 2026-07-25 (mục 1/LOGIC.md) khớp
TUYỆT ĐỐI 816,719/816,719 dòng với bảng thật, nghĩa là bản gốc **cũng KHÔNG lọc `is_delete`** (bảng
thật cũng chứa các dòng tombstone này). Nếu đối chiếu lại theo đúng quy trình `knowledge.md` mục 3
sau ngày 2026-09-08, số dòng sẽ **lệch có chủ đích** (ít hơn bảng thật đúng bằng số dòng
`is_delete=true` hiện có) — không phải lỗi dịch mới phát sinh.

## 4. Cách đối chiếu nhanh khi lệch chỉ vài trăm dòng trên tổng ~800K

Đừng dừng ở diff tổng (EXCEPT ra bao nhiêu dòng) — pair lại theo khoá `id` (đã xác nhận
duy nhất) rồi đếm lệch **theo từng cột** (`count(*) filter (where r.col is distinct from
d.col)`) để biết ngay cột nào đứng sau phần lớn số dòng lệch, từ đó khoanh vùng CTE gây
lỗi thay vì dò từng dòng một:
```sql
select count(*) filter (where r.col1 is distinct from d.col1) as col1, ...
from real_t r join dbt_t d on d.id = r.id
```
