# Data Dictionary — Nguồn EHC

Tổng hợp các bảng/trường được dùng trong các câu query doanh thu EHC (xem `mo_ta_bang_ehc.md` để xem full SQL mẫu).

> **Lưu ý naming:** Khi các bảng nguồn EHC được kéo về DWH, tên bảng được bổ sung tiền tố `ehc_` (VD: `tb_invoice` → `ehc_tb_invoice`).

## 1. tb_invoice — Phiếu thu/chi

Bảng gốc chứa các phiếu thu tiền / hoàn tiền của bệnh nhân.

| Trường | Kiểu dữ liệu (suy ra) | Mô tả |
|---|---|---|
| `invoiceid` | id | Khóa của phiếu thu/chi |
| `invoicedate` | datetime | Ngày lập phiếu, dùng để lọc theo khoảng thời gian báo cáo |
| `patientrecordid` | id | FK tới `tb_patientrecord`, xác định bệnh nhân |
| `sotienphieu` | số tiền | Số tiền trên phiếu (giá trị dương) |
| `dm_invoice_typeid` | int | Loại phiếu: `1` = phiếu thu (cộng `sotienphieu`), `2` = phiếu hoàn/trừ (trừ `sotienphieu`). Dùng công thức `case dm_invoice_typeid when 1 then sotienphieu when 2 then -sotienphieu end` để ra doanh thu thực (net) |
| `huyphieu_status` | int (flag) | Trạng thái hủy phiếu: `0` = phiếu chưa bị hủy (điều kiện lọc bắt buộc trong mọi báo cáo doanh thu) |

**Điều kiện lọc chuẩn khi tính doanh thu:**
```sql
huyphieu_status = 0
and invoiceid not in (select invoiceid from tb_invoicerequest)
```

## 2. tb_invoicerequest — Yêu cầu phiếu

| Trường | Mô tả |
|---|---|
| `invoiceid` | FK tới `tb_invoice`. Các `invoiceid` xuất hiện ở bảng này bị **loại trừ** khỏi doanh thu (phiếu đang ở dạng yêu cầu, chưa phải phiếu thu chính thức) |

## 3. tb_patientrecord — Hồ sơ bệnh nhân

| Trường | Mô tả |
|---|---|
| `patientrecordid` | Khóa hồ sơ bệnh nhân |
| `patientcode` | Mã bệnh nhân |
| `patientname` | Tên bệnh nhân |
| `tongnguonkhac` | Tổng nguồn khác của bệnh nhân (nguồn giới thiệu/kênh khác) |
| `nguoigioithieuid` | FK tới `tb_nguoigioithieu`, người/nguồn giới thiệu bệnh nhân |

## 4. tb_nguoigioithieu — Người giới thiệu

| Trường | Mô tả |
|---|---|
| `nguoigioithieuid` | Khóa người giới thiệu |
| `nguoigioithieuname` | Tên người giới thiệu |
| `dm_hoahongnguoigioithieu_nguoigioithieuid` | FK tới `tb_dm_hoahongnguoigioithieu_nguoigioithieu`, xác định nhóm hoa hồng/nguồn của người giới thiệu này |

## 5. tb_dm_hoahongnguoigioithieu_nguoigioithieu — Danh mục nhóm hoa hồng người giới thiệu

| Trường | Mô tả |
|---|---|
| `dm_hoahongnguoigioithieu_nguoigioithieuid` | Khóa nhóm hoa hồng người giới thiệu |
| `dm_hoahongnguoigioithieu_nguoigioithieuname` | Tên nhóm hoa hồng người giới thiệu |

**Mã đã biết:**
- `26` = nhóm **CN - Thuê phòng mổ**

## 6. tb_servicedata — Dịch vụ được chỉ định

| Trường | Mô tả |
|---|---|
| `patientrecordid` | FK tới `tb_patientrecord` |
| `roomid` | Phòng chỉ định dịch vụ |
| `do_roomid` | Phòng thực hiện dịch vụ (có thể khác `roomid` nếu dịch vụ được thực hiện ở phòng khác) |
| `servicecode` | Mã dịch vụ |
| `dm_servicesubgroupid` | Nhóm dịch vụ con (danh mục) |

**Mã phòng khám (`roomid` / `do_roomid`) đã biết:**

| ID | Phòng khám |
|---|---|
| 94 | PTTM |
| 276 | LGBT |
| 92 | Ung Bướu |
| 142, 211 | Sản (bao gồm cả nhóm IVF, cần trừ riêng bằng `servicecode`/`dm_servicesubgroupid`) |
| 262 | Xuất hiện trong điều kiện loại trừ ở báo cáo "chuyên khoa khác" nhưng chưa có mô tả tên phòng — cần xác nhận thêm |

**Mã/dịch vụ liên quan nhóm IVF** (dùng để tách doanh thu sản thường vs IVF):
- `servicecode`: `KHAM_TIENIVF01`, `SA_TIENIVF01`, `GOI_IVF01`, `GOI_IVF02`, `GOI_IVF03`
- `dm_servicesubgroupid = 10004`

## Quan hệ giữa các bảng

```
tb_invoice.patientrecordid ──► tb_patientrecord.patientrecordid
tb_invoice.invoiceid       ──► tb_invoicerequest.invoiceid (dùng để loại trừ)
tb_patientrecord.nguoigioithieuid ──► tb_nguoigioithieu.nguoigioithieuid
tb_nguoigioithieu.dm_hoahongnguoigioithieu_nguoigioithieuid ──► tb_dm_hoahongnguoigioithieu_nguoigioithieu.dm_hoahongnguoigioithieu_nguoigioithieuid
tb_servicedata.patientrecordid ──► tb_patientrecord.patientrecordid
```

## Công thức tính doanh thu chuẩn (net revenue)

```sql
with temp as(
  select invoicedate, patientrecordid,
    case dm_invoice_typeid when 1 then sotienphieu when 2 then -sotienphieu end as sotienphieu,
    huyphieu_status, dm_invoice_typeid
  from tb_invoice
  where invoicedate >= :from and invoicedate <= :to
    and huyphieu_status = 0
    and invoiceid not in (select invoiceid from tb_invoicerequest)
)
```
Sau đó lọc `patientrecordid` theo điều kiện nghiệp vụ (phòng khám qua `tb_servicedata`, nguồn giới thiệu qua `tb_patientrecord`/`tb_nguoigioithieu`, hoặc loại trừ nhóm dịch vụ IVF).

Xem chi tiết các query mẫu đầy đủ (theo từng báo cáo) tại `mo_ta_bang_ehc.md`.
