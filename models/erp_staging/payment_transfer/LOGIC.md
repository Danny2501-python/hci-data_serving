# Logic: erp_staging/payment_transfer

Chuyển logic tạo bảng `stag_payment_transfer` (đang chạy Python/pandas trong Airflow DAG
`quentk_1_stag_crm_New_sys.py`, hàm `get_data_payment()` + `write_stag_payment_transfer()`,
cùng `write_temp_crm_id_update()`) sang dbt. Output: `mart_stag_payment_transfer`, alias
vật lý `stag_payment_transfer_dbt` (xem mục "Cutover" — **chưa** ghi đè bảng
`stag_payment_transfer` thật).

Đối chiếu ngày build (2026-07-25): row count khớp **tuyệt đối** (816,719/816,719). Sau khi
sửa lỗi gộp NULL clineid (xem `knowledge.md` mục 1), còn **~421/816,719 dòng (0.05%)** lệch
giá trị — toàn bộ do 1 điểm mơ hồ có sẵn trong thiết kế gốc (tie-break trùng khoá sắp xếp
giữa 2 vế cùng 1 phiếu điều chuyển), không phải lỗi dịch — xem `knowledge.md` mục 2 để biết
chi tiết và lý do quyết định không sửa.

---

## Bài toán gốc

Khác với `stag_products`/`stag_employees` (build lại toàn bộ từ đầu mỗi lần vì bảng nguồn
là danh mục tĩnh), `stag_payment_transfer` là 1 bảng giao dịch **rất lớn** (800K+ dòng, tăng
dần theo thời gian) mà nguồn ERP chi tiết dùng để TÍNH LẠI từng dòng
(`crm_account_payment_detail`, `crm_account_payment_product_detail`,
`crm_transfer_payment_line`...) **chỉ còn lưu được vài tháng gần nhất** — không phải kho
lưu trữ đầy đủ lịch sử. Vì vậy cả bản Python gốc lẫn bản dịch dbt đều **không tính lại toàn
bộ bảng mỗi lần chạy**, mà chia dữ liệu làm 3 phạm vi:

1. **`brand_etl = 0`** (hệ thống cũ trước khi tách brand, trước 01/08/2025) — đóng băng vĩnh
   viễn, không có ETL nào (cũ lẫn mới) tái tạo được.
2. **Brand 1/3/4, `crm_id` KHÔNG có giao dịch/cập nhật gần đây** — giữ nguyên từ bảng thật,
   vì nguồn ERP chi tiết không còn đủ lịch sử để tính lại đúng.
3. **Brand 1/3/4, `crm_id` CÓ giao dịch/cập nhật gần đây** ("Phạm vi tính lại", xem mục dưới)
   — tính lại từ đầu bằng SQL trực tiếp trên nguồn ERP.

`write_stag_payment_transfer()` bản Python cũng theo đúng nguyên tắc này: chỉ
`DELETE ... USING temp_crm_id_update WHERE brand_etl <> 0` (không đụng brand 0) rồi insert
lại kết quả `get_data_payment()` (vốn chỉ tính cho các `crm_id` trong `temp_crm_id_update`).

## Phạm vi tính lại (tương đương `write_temp_crm_id_update()` / `temp_crm_id_update`)

`int_sptr_recent_crm_scope` (tương đương bảng tạm `temp_crm_id_update` Python tạo mỗi lần
chạy): quét 2 bảng ERP theo dõi **toàn bộ** giao dịch (không chỉ phần chi tiết còn giữ được)
— `account_payment` và `crm_transfer_payment` — lấy các `(crm_id, brand_etl)` có
`GREATEST(payment_date, write_date) >= limit_start_date_1m`, với:

```
limit_start_date_1m = GREATEST(ngày 01 của tháng trước (theo ngày build), '2025-12-01')
```

(mốc cứng `2025-12-01` là sàn dưới — tránh cửa sổ tính lại tụt quá xa nếu pipeline không
chạy trong nhiều tháng). Chỉ những `crm_id` nằm trong tập này mới được tính lại từ đầu
(`int_sptr_payment_service/cosmetic`, `int_sptr_transfer_base` đều có `EXISTS` lọc theo
model này); phần còn lại (`int_sptr_cold_brand134`) lấy nguyên xi từ bảng thật.

**Đây là ràng buộc bắt buộc, không phải tối ưu hiệu năng**: `crm_account_payment_detail`/
`crm_account_payment_product_detail`/`crm_transfer_payment_line` chỉ giữ được ~2 tháng gần
nhất — nếu bỏ filter này và quét toàn bộ `crm_id`, các booking cũ sẽ **mất dữ liệu** (nguồn
chi tiết không còn tồn tại để tính lại) thay vì được giữ nguyên từ bảng thật như thiết kế.

Cùng mốc `limit_start_date_1m` này còn được dùng lại ở:
- `int_sptr_new_transaction` (tương đương subquery `new_transaction` lồng trong `df_fdate`
  gốc): `crm_id` đánh số theo hệ thống cũ (`< 2174165` — mốc tách hệ thống, khác với mốc
  `product_id <= 31842` của `erp_staging/products`) mà còn phát sinh thanh toán gần đây.
- `int_sptr_fix_product_id` (tương đương biến `fix_product_id` toàn cục ở Python): quét
  **toàn bộ** bảng đích thật (mọi brand, không riêng phạm vi tính lại) để tìm `product_id`
  "tốt nhất đã biết gần đây" theo `(clineid, brand_id)`, dùng vá các dòng mới tính ra
  `product_id = 0`/`NULL`.

## Cấu trúc model

```
stg/    7 model pass-through nguồn ERP chi tiết (account_payment, crm_line, crm_line_product,
        crm_account_payment_detail(_product), crm_transfer_payment(_line))
        + 2 model đọc bảng ĐÍCH THẬT (sptr_legacy), tách theo brand_etl=0 / brand_etl IN (1,3,4)
int/
  int_sptr_recent_crm_scope   ← "Phạm vi tính lại": crm_id nào được tính lại (xem mục trên)
  int_sptr_new_transaction    ← crm_id đánh số cũ (<2174165) còn phát sinh gần đây
  int_sptr_fdate              ← baseline "ngày thanh toán đầu / lũy kế đã thu" từ brand_etl=0,
                                 giới hạn theo int_sptr_new_transaction
  int_sptr_fix_product_id     ← product_id "tốt nhất đã biết" theo (clineid, brand_id)
  int_sptr_cold_brand134      ← phần "nguội": crm_id KHÔNG nằm trong recent_crm_scope, giữ
                                 nguyên từ bảng thật
  int_sptr_payment_service    ┐ 2 nhánh UNION ALL trong query_pm gốc — quét cả 3 brand
  int_sptr_payment_cosmetic   ┘ (kn/pr/hh) trong 1 lượt, thay vì lặp query đổi brand_etl
  int_sptr_transfer_base      ← query_tf gốc: 1 dòng transfer_payment_line ra 1 raw record
                                 mang cả thông tin 2 vế from/to
  int_sptr_transfer_outbound  ┐ tách raw thành 2 record riêng (dfo/dfi bản Python): outbound
  int_sptr_transfer_inbound   ┘ (-amount, dùng thông tin vế "from") và inbound (+amount, vế "to")
  int_sptr_union              ← nối service + cosmetic + outbound + inbound, vá product_id
                                 qua int_sptr_fix_product_id
  int_sptr_ranked             ← rank/lũy kế lần 1 (first_date_payment, rnk_crm_pmdate,
                                 rnk_clineid_pmdate*) + gộp baseline từ int_sptr_fdate
  int_sptr_final_calc         ← is_priority, sắp lại thứ tự, lũy kế lần 2
                                 (total_received_cumsum), đối chiếu lại tổng tiền đã thu,
                                 total_received_recal
mart/
  stag_payment_transfer  ← UNION ALL 3 phạm vi: legacy (brand_etl=0) + cold (brand134 nguội)
                           + computed (int_sptr_final_calc, brand134 mới tính), alias
                           'stag_payment_transfer_dbt'
```

## `int_sptr_transfer_base` — vì sao phải tự self-join (`ctplt`)

1 phiếu điều chuyển (`crm_transfer_payment`) có thể có nhiều dòng
`crm_transfer_payment_line`, mỗi dòng di chuyển tiền từ 1 clineid "from" sang 1 clineid
"to". `total_receivedt` (tổng tiền đã thu tính đến hiện tại của **vế "to"**) không có sẵn
trực tiếp trên dòng — phải tự self-join `ctplt` để tìm dòng khác **trong cùng phiếu**
(`crm_transfer_payment_id` giống nhau) có `from_crm_line_id` = `to_crm_line_id` của dòng
hiện tại. Nếu 1 phiếu có nhiều dòng cùng khớp điều kiện này, phải chọn 1 — dùng
`ROW_NUMBER() OVER (PARTITION BY id ORDER BY total_receivedt NULLS LAST)`. Bản Python gốc
không có `ORDER BY` khi self-join nên "dòng đầu tiên" vốn **đã không xác định rõ ràng** từ
trước — không phải khoảng lệch phát sinh khi dịch sang dbt.

## `int_sptr_final_calc` — `is_priority` + đối chiếu lại tổng tiền đã thu

- `is_priority = (ma_phieu LIKE 'PDC%') AND (total_received_cline > 0)` — ưu tiên xếp các
  dòng điều chuyển (mã `PDC...`) đã có `total_received_cline` lên trước trong ngày khi cần
  tie-break thứ tự cộng dồn.
- `total_received_cumsum` = `SUM(payment)` lũy kế theo `(crm_id, clineid, product_id)`, sắp
  theo `(payment_date, is_priority DESC, write_date)`, cộng thêm `total_received_old`
  (baseline lấy từ `int_sptr_fdate`).
- Bước "đối chiếu lại" (`reconciled` CTE): nếu cumsum tính ra **khớp** với `total` (hoặc
  `total_received + payment` khớp `total`) thì **lấy `total`** làm cumsum cuối — tránh sai
  số cộng dồn nhỏ tích luỹ qua nhiều dòng thanh toán; nếu `(payment + total_received)`
  **vượt** `total` thì lấy đúng giá trị đó (dữ liệu thực tế vượt kỳ vọng, không ép về
  `total`); còn lại giữ nguyên giá trị cumsum tính được.
- `total_received_recal` = giá trị cumsum **cuối cùng trong ngày** cho mỗi
  `(brand_id, crm_id, clineid, product_id, payment_date)`, dùng
  `last_value(...) OVER (... ROWS UNBOUNDED FOLLOWING)` — broadcast cùng 1 giá trị cho mọi
  dòng phát sinh trong ngày đó.
- 2 điểm còn mơ hồ khi có nhiều dòng trùng ngày cho cùng 1 nhóm (gộp NULL `clineid` — đã
  sửa; tie-break trùng tuyệt đối `payment_date`/`is_priority`/`write_date` giữa 2 vế cùng 1
  phiếu điều chuyển — chưa/không sửa, giữ làm hạn chế đã biết) — xem `knowledge.md`.

## Cutover — kế hoạch chuyển từ Python sang dbt

Theo đúng pattern đã dùng cho `products`/`employees`:

1. Model hiện build ra bảng riêng `stag_payment_transfer_dbt`
   (`{{ config(alias='stag_payment_transfer_dbt') }}` trong `mart/stag_payment_transfer.sql`)
   — **không** đụng bảng thật `stag_payment_transfer`.
2. **Ngay trước khi cutover**: chạy lại đúng quy trình đối chiếu ở `knowledge.md` — dữ liệu
   ERP là sống và "Phạm vi tính lại" trôi theo tháng (`limit_start_date_1m`), nên kết quả đối
   chiếu cũ có thể lệch nếu cách xa thời điểm cutover quá lâu.
3. Xoá task Airflow tương ứng `write_stag_payment_transfer` (và `write_temp_crm_id_update`,
   nếu không còn hàm nào khác dùng bảng tạm `temp_crm_id_update`) khỏi DAG
   `quentk_1_stag_crm_New_sys.py`.
4. Bỏ dòng `config(alias=...)` trong `mart/stag_payment_transfer.sql` để dbt build thẳng ra
   bảng `stag_payment_transfer` (cần đảm bảo quyền DROP/CREATE trên bảng đó).
5. **Chưa dịch `stag_payment_transfer_grby_date`** (tương đương
   `write_stag_payment_transfer_grby_date()`): bảng tổng hợp theo ngày, dùng cho báo cáo
   doanh số group theo `(brand_id, crm_id, product_id, payment_date)` — nối `id`/`ma_phieu`/
   `clineid`/`payment_type` bằng dấu phẩy, `SUM(payment)`, lấy giá trị `.last()` cho các cột
   còn lại (`quantity`, `uom_price`, `total`, `total_received`, `total_received_recal`...).
   Hiện mới có 2 model `stg` pass-through phần brand_etl=0 và brand 1/3/4 của bảng đích thật
   (`stg_sptr_legacy_grby_date_brand0/134`) — **chưa có model `int`/`mart` tính lại bảng
   này**. Cần dựng thêm trước khi cutover được cả 2 bảng cùng lúc (2 bảng luôn được Python
   ghi cùng nhau trong `write_stag_payment_transfer()`).
6. Theo dõi các model/report đang `source()` trực tiếp `stag_payment_transfer` sau cutover
   (vd `report_kn_tele_transfer/int/ktt_payment.sql`) — không đổi tên bảng nên các model này
   không cần sửa gì.
