# Knowledge: report_doanh_so_tap_doan_HCI

## 1. Sanity check khi build lần đầu (2026-08-06, DB `new_product@10.10.10.214`)

Tổng 328.074 dòng:

| Brand | Dòng | Tổng so_tien | Khoảng ngày |
|---|---|---|---|
| Kangnam | 116.184 | 635.992.657.444 | 2021-10-31 → 2026-08-05 |
| Paris | 29.854 | 90.594.722.500 | 2023-09-06 → 2026-08-05 |
| Hồng Hà | 163.254 | 511.275.108.337,89 | 2018-10-16 → 2026-08-05 |
| Tiêu Hóa Việt | 18.782 | 33.206.348.182,75 | 2024-12-29 → 2026-08-05 |

Tổng `so_tien` từng brand đối chiếu khớp **tuyệt đối** với `SUM(payment)` lọc
trực tiếp trên `stag_payment_transfer` theo `brand_etl` — xác nhận UNION
không làm lệch số tiền.

## 2. NULL `ma_khach_hang` cao ở Kangnam/Paris — data quality có sẵn, không phải bug

`ma_khach_hang` NULL: Hồng Hà 82/163.254 (~0.05%, bình thường — khách vãng
lai), nhưng **Kangnam 75.924/116.184 (~65%)** và **Paris 21.166/29.854
(~71%)**.

Điều tra: join trực tiếp `stag_payment_transfer.crm_id = crm_lead.id`
(không lọc brand) cho brand_etl=1 (Kangnam):
```
crm_lead.brand_etl khớp:  1→40.260   3→11.961   4→1.615   7→10   8→18.227   (không tìm thấy)→47.571
```
brand_etl=3 (Paris):
```
crm_lead.brand_etl khớp:  1→542   3→8.688   4→1.144   8→13.220   (không tìm thấy)→7.802
```
→ Rất nhiều `crm_id` trên `stag_payment_transfer` (được gắn nhãn brand_etl=1
hoặc 3) thực ra trỏ tới `crm_lead.id` thuộc **brand khác** (hay gặp nhất là
brand_etl=8) hoặc **không còn tồn tại** trong `crm_lead` — đây là hệ quả trực
tiếp của vấn đề id trùng chéo giữa các brand đã ghi nhận ở
`[[feedback_hci_dataserving_brand_etl_collision]]`. Model đã lọc
`crm_lead.brand_etl` đúng theo từng CTE trước khi join (an toàn — không lấy
nhầm tên khách brand khác), nên các trường hợp không khớp brand chính xác sẽ
ra NULL thay vì dữ liệu sai. **Chưa điều tra tiếp** vì sao nhiều crm_id của
brand 1/3 lại trỏ sang brand 8 hoặc biến mất — nếu cần tỷ lệ match cao hơn,
đây là điểm cần hỏi lại đội CRM/ERP thay vì tự đoán logic join khác.

## 2b. `nguon`/`nhom_nguon_khach` Kangnam/Paris NULL cùng tỷ lệ với `ma_khach_hang` — cùng 1 nguyên nhân gốc

Thêm 2026-08-06. Vì lấy qua `cl.source_id` (CTE `crm_lead` đã lọc brand,
alias `cl`) nên khi `cl` không match (xem mục 2 ở trên — id trùng chéo
brand/không tồn tại), `nguon`/`nhom_nguon_khach` cũng NULL theo, dù bản thân
join `stag_sources` (`old_id`) hoạt động rất tốt (~99.8% match khi `cl` có
dữ liệu). Số liệu thực tế: Kangnam 75.971/116.184 NULL, Paris 21.166/29.854
NULL — gần như trùng khớp con số NULL của `ma_khach_hang`. Muốn giảm tỷ lệ
này phải giải quyết gốc rễ join `crm_id -> crm_lead.id` (mục 2), không phải
sửa ở bước join `stag_sources`.

**Đã thử và loại bỏ:** join trực tiếp `utm_source.category_id -> crm_category_source.id`
(kể cả sau khi lọc `brand_etl` cả 2 bên) — 75.424/75.675 dòng Kangnam không
khớp. 2 cột `category_id` này rõ ràng không cùng hệ giá trị (số trong
`utm_source.category_id` như 105/108/117/101... không nằm trong tập id của
`crm_category_source` cho cùng brand, vốn chỉ có vài chục id như 120-131).
Chuyển hẳn sang dùng `stag_sources` (bảng tổng hợp sẵn, đã được dùng ở nơi
khác trong repo — `common/stg_common_tongquan_khachhang.sql` — cho đúng mục
đích này) thay vì tự nối lại từ `utm_source` thô.

## 3. Vì sao không dùng `stag_payment_transfer_dbt`

`erp_staging/payment_transfer` (dbt) build ra bảng riêng
`stag_payment_transfer_dbt`, theo `LOGIC.md` của folder đó **chưa cutover**
thay bảng thật — chỉ dùng để đối chiếu, còn ~0.05% dòng lệch giá trị do 1
điểm mơ hồ tie-break có sẵn trong thiết kế gốc. Report này dùng thẳng bảng
thật `stag_payment_transfer` (qua `source('crm_base', ...)`) để tránh phụ
thuộc vào 1 pipeline đang trong giai đoạn thử nghiệm.

## 4. Type cast khi UNION

`stag_payment_transfer.id` là `varchar`, còn `invoiceid` bên EHC là
`integer` — phải `::text` cả 2 phía mới UNION được. Tương tự `payment`
(numeric) và `so_tien_phieu` (double precision) đã ép chung về `numeric`.

## 5. Chạy model

```
cd data_serving
./.venv/Scripts/dbt.exe run --select fct_doanhso_ehc_vde_theo_nguon report_doanh_so_tap_doan_HCI --profiles-dir .
```
Bảng vật lý tạo ra có tên **giữ nguyên hoa/thường**
(`"report_doanh_so_tap_doan_HCI"`, có quote) do dbt-postgres quote theo đúng
tên file model — khi query trực tiếp bằng SQL client phải để trong dấu
ngoặc kép `"report_doanh_so_tap_doan_HCI"`, không viết thường tự do.
