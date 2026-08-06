# Logic: fct_doanhso_ehc

Bảng fact doanh số EHC theo nguồn (người giới thiệu), grain = 1 dòng/phiếu thu
(`ehc_tb_invoice`). Xây dựng dựa trên tài liệu tham chiếu tại
`models/common/data_dictionary_ehc.md` và `models/common/mo_ta_bang_ehc.md`
(các câu query gốc do EHC cung cấp — không phải model, chỉ dùng để tra cứu chuẩn).

Model: `fct_doanhso_ehc_theo_nguon.sql` (materialized = `table`, xem
`dbt_project.yml`). Nguồn dữ liệu: source `ehc` (`source.yml` trong cùng
folder) — các bảng gốc HIS, **không** có tiền tố brand (khác với biến thể
`_thv` dùng trong `report_thv_sale_online`, xem mục "Biến thể `_thv`" bên dưới).

## Trạng thái hiện tại (2026-08-06)

**Đã làm:** Mã phiếu, mã/tên bệnh nhân, số tiền phiếu (net), ngày thu, Nguồn,
Nhóm nguồn khách.

**Tạm hoãn theo yêu cầu user:** cột "Nhóm dịch vụ" (mỗi query trong
`mo_ta_bang_ehc.md` tương ứng 1 nhóm: PTTM, CN - Thuê phòng mổ, LGBT, Sản trừ
IVF, IVF, Ung Bướu, Khác). Đã phân tích xong logic phân nhóm (xem mục dưới) —
**chưa đưa vào model**, cần làm tiếp khi user quay lại yêu cầu.

## Công thức doanh thu (đúng theo data_dictionary_ehc.md)

```sql
case dm_invoice_typeid when 1 then sotienphieu when 2 then -sotienphieu end
```
Lọc: `huyphieu_status = 0` và `invoiceid NOT IN (select invoiceid from ehc_tb_invoicerequest)`.

## Nguồn / Nhóm nguồn khách

```
ehc_tb_invoice.patientrecordid → ehc_tb_patientrecord.nguoigioithieuid
  → ehc_tb_nguoigioithieu.nguoigioithieuname                                  (= Nguồn)
  → ehc_tb_nguoigioithieu.dm_hoahongnguoigioithieu_nguoigioithieuid
    → ehc_tb_dm_hoahongnguoigioithieu_nguoigioithieu.dm_hoahongnguoigioithieu_nguoigioithieuname  (= Nhóm nguồn khách)
```
Toàn bộ join là LEFT JOIN — khách vãng lai không qua giới thiệu sẽ có
`nguon`/`nhom_nguon_khach` = NULL (xem số liệu thực tế ở `knowledge.md`).

## Sanity check khi build lần đầu (2026-08-06, DB `new_product@10.10.10.214`)

- 163.254 dòng, tổng `so_tien_phieu` ≈ 511,3 tỷ VNĐ, khoảng thời gian
  2018-10-16 → 2026-08-05.
- Nhóm nguồn khách lớn nhất: `[TPM]Thuê phòng mổ` (60.073 phiếu, ~333 tỷ) —
  khớp hướng với "CN - Thuê phòng mổ" nhắc tới trong `mo_ta_bang_ehc.md` (2
  tên gọi khác nhau cho cùng khái niệm thương mại, cần xác nhận thêm nếu dùng
  để đối chiếu số báo cáo cũ).
- 1.226/163.254 phiếu không có nguồn (NULL) — khách vãng lai.
- 82/163.254 phiếu thiếu mã bệnh nhân.

## Phân tích logic "Nhóm dịch vụ" (đã phân tích, CHƯA implement)

Đọc kỹ từng điều kiện WHERE trong 7 query của `mo_ta_bang_ehc.md` + đối chiếu
dữ liệu thật trên DB, kết luận:

**Vấn đề với query gốc:** mỗi query gốc lọc theo
`patientrecordid IN (SELECT patientrecordid FROM tb_servicedata WHERE roomid = X ...)`
— tức "bệnh nhân từng có dịch vụ ở phòng X **bất kỳ lúc nào**", rồi áp kết quả
đó lên **mọi phiếu thu** của bệnh nhân trong kỳ báo cáo, kể cả phiếu không
liên quan phòng X. Test thực tế: 1 bệnh nhân có phiếu `invoice.roomid=94`
(PTTM) nhưng `servicedata` của họ trải trên nhiều phòng khác (7, 27, 54...).
→ Không phù hợp khi grain là 1 dòng/phiếu (sẽ 1 phiếu có thể match nhiều
nhóm, hoặc gán nhầm nhóm cho phiếu không liên quan).

**Đề xuất grain đúng cho fact table (invoice-level):**
`ehc_tb_invoice` có sẵn cột `roomid` — dùng trực tiếp cột này (phòng gắn với
CHÍNH phiếu đó) thay vì join qua `tb_servicedata` theo `patientrecordid`.
Verify trên DB: `roomid` 92/94/142/211/276 khớp đúng tên phòng trong
`ehc_tb_room` như mô tả trong `data_dictionary_ehc.md`. Phát hiện thêm:
**`roomid = 262` = "Phòng Khám IVF"** — giải quyết mục "cần xác nhận thêm"
từng nêu trong `data_dictionary_ehc.md`.

**Thứ tự ưu tiên phân nhóm đề xuất (1 phiếu chỉ nhận 1 nhóm)**, suy ra từ
chính các điều kiện trong file gốc:

1. **CN - Thuê phòng mổ** — `nguoigioithieu` của bệnh nhân thuộc nhóm hoa hồng
   `dm_hoahongnguoigioithieu_nguoigioithieuid = 26`. Ưu tiên cao nhất vì query
   gốc (query 2) **không giới hạn theo phòng khám** — đây là kênh cắt ngang
   mọi chuyên khoa (thuê phòng mổ = đối tác ngoài thực hiện thủ thuật dưới
   danh nghĩa viện), nếu để phòng khám xét trước sẽ "nuốt" mất doanh số của
   kênh này vào nhóm phòng.
2. **IVF** — `roomid = 262` HOẶC tồn tại dòng `ehc_tb_servicedata` cùng
   `invoiceid` có `servicecode IN ('KHAM_TIENIVF01','SA_TIENIVF01','GOI_IVF01','GOI_IVF02','GOI_IVF03')`
   hoặc `dm_servicesubgroupid = 10004`. Ưu tiên trước Sản vì query 4 (Sản)
   trong file gốc **explicit trừ** đúng các mã dịch vụ này ra khỏi Sản.
3. **PTTM** — `roomid = 94`.
4. **LGBT** — `roomid = 276`.
5. **Ung Bướu** — `roomid = 92`.
6. **Sản** — `roomid IN (142, 211)` (đã loại IVF ở bước 2).
7. **Khác** — còn lại.

Lưu ý: đây là quyết định thiết kế (cách xử lý invoice vừa match phòng chuyên
khoa vừa match CN-26) chứ không phải sự thật minh bạch 100% từ file gốc — file
gốc gồm 7 báo cáo độc lập, có thể trùng lẫn nhau khi cộng dồn (xem
`knowledge.md` mục "Vì sao 7 query gốc không phải partition"). Cần user
confirm lại trước khi code nếu muốn add cột này.

## Biến thể `_thv`

`report_thv_sale_online/int/tso_ehc_payment.sql` là 1 pipeline khác, dùng bảng
`ehc_tb_invoice_thv`/`ehc_tb_patientrecord_thv`/`ehc_tb_nguoigioithieu_thv`
(thương hiệu/instance HIS khác), lấy thẳng `nguoigioithieuname` làm nguồn
(không phân nhóm hoa hồng), và coi CẢ `dm_invoice_typeid IN (2,4)` là số âm
(khác công thức chuẩn ở đây chỉ trừ type=2), lại **không** loại trừ
`tb_invoicerequest`. Model `fct_doanhso_ehc_theo_nguon` hiện **chỉ cover bảng
gốc không suffix** — chưa gộp brand `_thv`.
