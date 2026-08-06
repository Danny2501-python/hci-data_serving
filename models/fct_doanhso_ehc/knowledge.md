# Knowledge: fct_doanhso_ehc

Lưu ý kỹ thuật/edge case phát hiện khi build lần đầu (2026-08-06). Xem
`LOGIC.md` để biết bức tranh business logic đầy đủ.

## 1. `ehc_tb_invoice.brand_etl` luôn NULL

Khác với các bảng CRM (`crm_lead`, `crm_line`...) dùng `brand_etl` để phân
biệt thương hiệu (xem `[[feedback_hci_dataserving_brand_etl_collision]]`
trong memory), toàn bộ bảng `ehc_tb_*` (không suffix) có `brand_etl = NULL`
100% — đây là dữ liệu của 1 instance HIS duy nhất, không cần lọc brand khi
join các bảng `ehc_tb_*` với nhau. Biến thể brand khác nằm ở suffix bảng
(`_thv`), không phải cột `brand_etl`.

## 2. `hongha_doanhso_ehc` / `tieuhoaviet_doanhso_ehc` — bảng rác, không dùng

2 bảng này (tồn tại sẵn trên DB, không phải model dbt) trông giống
"doanh số EHC" đã build sẵn theo tên, nhưng data thực tế là **dummy/test**:
cột `ten_bn`/`ma_bn`/`nguon` chứa literal string `'tbn'`/`'ma_bn'`/`'nguon'`
(đúng tên cột, không phải giá trị thật) ở phần lớn các dòng. Đã kiểm tra và
loại trừ, không dùng làm tham chiếu.

## 3. Vì sao 7 query gốc trong `mo_ta_bang_ehc.md` không phải 1 partition

`patientrecordid NOT IN (...)` trong query "Khác" (query 7) loại trừ đồng thời
nhóm 26 (CN-thuê phòng mổ) và rooms `(92,94,211,142,276,262)` — nhưng 6 query
còn lại (1 → 6) **không loại trừ lẫn nhau**. Đây là 7 báo cáo độc lập được
chạy riêng cho từng mục đích/stakeholder khác nhau — khi cộng dồn amount của
cả 7 query lại **sẽ bị double-count** với các bệnh nhân match nhiều điều kiện
(vd. bệnh nhân từng khám PTTM lẫn Ung Bướu). Đừng lấy tổng 7 query này làm
"tổng doanh thu toàn viện" — chỉ dùng riêng lẻ từng query cho đúng mục đích
gốc của nó, hoặc dùng logic invoice-grain đề xuất ở `LOGIC.md` nếu cần 1 bảng
tổng hợp không trùng.

## 4. `roomid` đã có sẵn trên `ehc_tb_invoice`, không cần join `ehc_tb_servicedata` cho phần phòng khám

Test trực tiếp: 1 bệnh nhân có `invoice.roomid = 94` nhưng `servicedata` (join
qua `patientrecordid`) trải trên nhiều `roomid` khác (7, 27, 54, 94, 224,
293, 294...) — chứng minh "phòng gắn với phiếu" và "phòng bệnh nhân từng ghé
qua trong lịch sử" là 2 khái niệm khác nhau. Dùng `invoice.roomid` trực tiếp
cho ra kết quả sát với "phiếu này thuộc nhóm dịch vụ nào" hơn.

`ehc_tb_servicedata` có cột `invoiceid` — nếu cần biết servicecode/nhóm dịch
vụ con của 1 phiếu cụ thể (vd. để xác định IVF), join theo
`sd.invoiceid = inv.invoiceid`, **không** join theo `patientrecordid` (dễ
fan-out nhiều dòng dịch vụ khác kỳ/khác phòng của cùng bệnh nhân → nhân bản
số tiền nếu SUM sau join).

## 5. Mapping `roomid` đã verify trên DB (`ehc_tb_room`, 2026-08-06)

| roomid | roomname | Nhóm dịch vụ (dự kiến) |
|---|---|---|
| 92 | Phòng khám Ung bướu | Ung Bướu |
| 94 | Phòng khám Phẫu thuật thẩm mỹ | PTTM |
| 142 | Phòng khám Sản [213] | Sản |
| 211 | Điều trị ngoại trú [Khoa Phụ sản] | Sản |
| 262 | Phòng Khám IVF | IVF (mới xác nhận — trước đây note "chưa rõ tên") |
| 276 | Phòng khám LGBT | LGBT |

## 6. Kết nối tới DB để đối chiếu số liệu

Không có `psql` trong PATH trên máy này. Dùng Python venv sẵn có của project
(`data_serving/.venv/Scripts/python.exe`, đã có `psycopg2`) để query trực
tiếp, ví dụ:
```
./.venv/Scripts/python.exe -c "import psycopg2; conn = psycopg2.connect(host='10.10.10.214', port=5432, dbname='new_product', user='admin', password='...'); ..."
```
Lưu ý encoding: stdout mặc định của Windows console là `cp1252`, cần
`PYTHONIOENCODING=utf-8` + wrap `sys.stdout` bằng `io.TextIOWrapper(..., encoding='utf-8')`
khi print tiếng Việt có dấu, nếu không sẽ crash `UnicodeEncodeError`. Xem
credential DB tại `profiles.yml` (KHÔNG commit password ra chỗ khác).

## 7. Chạy model

```
cd data_serving
./.venv/Scripts/dbt.exe run --select fct_doanhso_ehc_theo_nguon --profiles-dir .
```
(`python -m dbt` không chạy được trên venv này — thiếu `dbt.__main__`; phải
gọi thẳng `dbt.exe`.)

## 8. Migrate dữ liệu EHC sang sandbox (2026-08-06)

Sandbox (`staging_sci@10.10.10.226`) cần chạy được các model này nhưng:
- 5 bảng Hồng Hà (`ehc_tb_invoice`/`invoicerequest`/`patientrecord`/
  `nguoigioithieu`/`dm_hoahongnguoigioithieu_nguoigioithieu`) đã tồn tại sẵn
  trên sandbox nhưng là **schema/dữ liệu cũ, khác nguồn** (`ehc_tb_invoice`
  sandbox chỉ 75 cột vs 104 cột ở new_product, data dừng ở 2025-12-01, số
  dòng patientrecord lệch hẳn: 355.281 sandbox vs 119.229 new_product) —
  **không phải bản lag của cùng 1 pipeline**, không rõ nguồn gốc/mục đích
  bảng cũ này, có thể đang được thứ khác trên sandbox dùng.
- 5 bảng `_thv` (VDE) hoàn toàn chưa tồn tại trên sandbox.

**Quyết định (user chọn):** KHÔNG đụng 5 bảng Hồng Hà cũ trên sandbox. Copy
dữ liệu mới từ new_product sang bảng đặt tên khác, hậu tố `_v2`
(`ehc_tb_invoice_v2`, `ehc_tb_invoicerequest_v2`, `ehc_tb_patientrecord_v2`,
`ehc_tb_nguoigioithieu_v2`, `ehc_tb_dm_hoahongnguoigioithieu_nguoigioithieu_v2`).
5 bảng `_thv` copy sang với **tên y hệt** (không cần `_v2` vì chưa tồn tại,
không có gì để đụng).

**Chỉ copy đúng các cột model đang SELECT**, không mirror full bảng gốc —
lý do: (1) giảm size transfer đáng kể (`ehc_tb_patientrecord` gốc 566 cột/
468MB, chỉ cần 4 cột `patientrecordid,patientcode,patientname,nguoigioithieuid`),
(2) tránh copy dư thừa dữ liệu nhạy cảm (CCCD, BHYT, chẩn đoán y tế...) sang
sandbox khi không cần dùng tới. Danh sách cột đã copy = đúng những gì
`fct_doanhso_ehc_theo_nguon.sql`/`fct_doanhso_ehc_vde_theo_nguon.sql` SELECT
— nếu sau này model cần thêm cột (vd `roomid` cho "Nhóm dịch vụ"), phải chạy
lại script migrate với cột bổ sung.

Script migrate (dùng `COPY ... TO STDOUT` / `COPY ... FROM STDIN` qua
psycopg2, streaming trực tiếp giữa 2 server không cần fdw/dblink) — không
còn lưu trong repo (đã chạy 1 lần, kết quả nằm trong `knowledge.md` này để
tái tạo lại khi cần):
```python
import io, psycopg2
SRC = dict(host='10.10.10.214', dbname='new_product', user='admin', password='...', port=5432)
DST = dict(host='10.10.10.226', dbname='staging_sci', user='admin', password='...', port=5432)
# với mỗi (src_table, dst_table, [cols]):
#   1. lấy data_type từng cột từ information_schema.columns (src)
#   2. DROP TABLE IF EXISTS dst_table; CREATE TABLE dst_table (...) trên DST
#   3. buf = io.BytesIO(); src_cur.copy_expert(f"COPY (SELECT {cols} FROM {src_table}) TO STDOUT WITH CSV", buf)
#   4. buf.seek(0); dst_cur.copy_expert(f"COPY {dst_table} ({cols}) FROM STDIN WITH CSV", buf)
```

**Kết quả migrate (2026-08-06)** — row count khớp tuyệt đối với new_product:
`ehc_tb_invoice_v2` 165.877, `ehc_tb_invoicerequest_v2` 241,
`ehc_tb_patientrecord_v2` 119.229, `ehc_tb_nguoigioithieu_v2` 384,
`ehc_tb_dm_hoahongnguoigioithieu_nguoigioithieu_v2` 42; `ehc_tb_invoice_thv`
19.275, `ehc_tb_invoicerequest_thv` 0, `ehc_tb_patientrecord_thv` 8.764,
`ehc_tb_nguoigioithieu_thv` 94, `ehc_tb_dm_hoahongnguoigioithieu_nguoigioithieu_thv` 22.

**`source.yml` trỏ động theo target:** 5 source Hồng Hà dùng Jinja trong
`identifier` (`"{{ 'ehc_tb_invoice_v2' if target.name == 'sandbox' else 'ehc_tb_invoice' }}"`)
— chạy `--target dev` (mặc định) đọc bảng gốc trên new_product, chạy
`--target sandbox` tự động đọc bảng `_v2` trên sandbox. 5 bảng `_thv` dùng tên
tĩnh vì giống nhau ở cả 2 nơi.

**Đây là snapshot 1 lần, KHÔNG tự động đồng bộ lại.** Nếu new_product có dữ
liệu EHC mới hơn sau ngày migrate, phải chạy lại script để refresh các bảng
`_v2`/`_thv` trên sandbox — không có job lặp lại nào được thiết lập.

**Target `sandbox`** đã thêm vào `data_serving/profiles.yml` (nội dung lấy từ
`D:\Pythoncode\connection\profiles_connections.yml`, host 10.10.10.226,
db `staging_sci`). Chạy: `./.venv/Scripts/dbt.exe run --select ... --target sandbox --profiles-dir .`

**Lưu ý số Kangnam/Paris khác nhau giữa dev và sandbox** trong
`report_doanh_so_tap_doan_HCI` — đây là **bình thường, không phải lỗi**:
model đó join thẳng `source('crm_base', 'stag_payment_transfer'/'crm_lead')`
(không migrate riêng, dùng thẳng dữ liệu CRM sẵn có trên mỗi DB), và sandbox
226 vốn có dữ liệu CRM đầy đủ/khác new_product 214
(xem [[project_hci_dataserving_dwh_schema]]) — brand_etl=1 sandbox ra
762,88 tỷ/140.336 dòng so với 635,99 tỷ/116.184 dòng trên new_product.
