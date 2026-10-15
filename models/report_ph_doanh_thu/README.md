# report_ph_doanh_thu — Doanh thu và chi phí Philippines

Hai bảng output, cùng tag `report_ph_doanh_thu` và `phi`:

| Bảng | Mỗi dòng là | Dùng để |
|---|---|---|
| **`sandbox_ph.report_ph_doanh_thu`** | 1 phiếu thu đã ghi sổ của ERP Philippines (ERP SUN, `brand_etl = 9`), quy đổi ra VND, kèm thông tin khách | Chi tiết doanh thu theo khách, dịch vụ, nguồn |
| **`sandbox_ph.report_ph_doanh_thu_chi_phi`** | 1 khoản tiền: doanh thu hoặc chi phí, theo ngày | Lãi/lỗ: doanh thu − chi phí, theo ngày, tháng, chi nhánh |

## 1. Cách ly để không ảnh hưởng database

| Quy tắc | Thực hiện |
|---|---|
| Chỉ đọc dữ liệu Philippines | Đọc schema `ph`, và `public.ty_gia_acb` khi bật tỷ giá ACB. Luôn lọc `brand_etl = 9` |
| Không lẫn với Việt Nam | Không join id của `ph` với bảng `public`: ERP SUN nhân bản từ ERP Kangnam nên id trùng, ví dụ `company_id = 4` |
| Chỉ ghi `sandbox_ph` | Ghi qua `schema='sandbox_ph'` và macro `generate_schema_name`. Không bao giờ ghi vào `public` hay `ph` |
| Chạy riêng | Chỉ chạy `dbt build --select tag:phi`, không chạy cả project |
| Sai thì dừng | Test lỗi thì model phía sau không chạy, nên bảng giữ số của lần chạy trước |

## 2. Logic

```
ph.account_payment (posted, brand_etl = 9, customer, inbound/outbound, ngày thu ≥ go-live)
   × ph.res_currency × tỷ giá ngày gần nhất ≤ ngày thu        → stg_frmacph_doanh_so_thu
   + ph.crm_lead + stg_frmacph_crm_base + stg_frmacph_trang_thai → report_ph_doanh_thu
```

- **Doanh thu VND**: `doanh_thu_vnd = round(so_tien_goc × ty_gia)`.
  - `so_tien_goc` là `amount` theo loại tiền của phiếu; phiếu hoàn tiền (outbound) mang dấu âm.
  - Không dùng `amount_vnd` của ERP, vì với phiếu PHP cột này vẫn là số peso.
- **Tỷ giá**: **chỉ dùng tỷ giá ACB theo ngày** (`stg_frmacph_ty_gia`, từ 09/10/2026).
  - Lấy từ `public.ty_gia_acb`, giá **bán chuyển khoản** (`ASK` / `TRANSFER`) của ngày thu. Nếu ngày đó không có số thì lấy ngày gần nhất trước đó.
  - VND luôn bằng 1.
  - Cột `nguon_ty_gia` ghi rõ tỷ giá lấy từ đâu: `VND` / `ACB` / `THIEU_TY_GIA`.
  - Lịch sử: 07–08/10/2026 từng dùng tạm tỷ giá cố định (PHP 405, USD 25.806,79, AUD 18.315,78) qua công tắc `ph_nguon_ty_gia` – đã bỏ.
- **Ngày go-live**: `var('ph_go_live_date')`, mặc định `2026-09-10`.
- **Phiếu draft không được tính.** Ngày 07/10/2026 có 49 phiếu draft so với 94 phiếu posted, cần xác nhận với kế toán Philippines.
- **Thuộc tính khách**:
  - `nguon`, `kenh`, `nhom_dv`… cùng định nghĩa với báo cáo marketing (`stg_frmacph_crm_base`);
  - `ma_booking`, `ten_khach`, `sdt` lấy từ `ph.crm_lead`;
  - phiếu không gắn lead thì các cột này là `KXĐ`.
- **Dữ liệu test**: `trang_thai_du_lieu` theo quy tắc chung của PH (`stg_frmacph_trang_thai`). **Luôn lọc `= 'THAT'`.**
- **Khớp 3 báo cáo**: báo cáo này, `report_marketing_ad_cost_ph_thu` (dòng DS) và `report_ph_sale_online` (nhánh DS) cùng lấy số từ `stg_frmacph_doanh_so_thu`, nên doanh số luôn khớp nhau.

## 3. Bảng doanh thu + chi phí (`report_ph_doanh_thu_chi_phi`)

| `nhom` | `khoan_muc` | Nguồn | Ghi chú |
|---|---|---|---|
| DOANH_THU | `THU_TIEN` / `HOAN_TIEN` | `report_ph_doanh_thu` | 1 dòng / phiếu, có `trang_thai_du_lieu` |
| CHI_PHI | `QUANG_CAO_FACEBOOK` | `stg_frmacph_fb_cost`: campaign `sun_` trong `cs_facebook_insight` (brand 1, VND) | Cùng nguồn với báo cáo marketing PH. 1 dòng / ngày / campaign. Chi nhánh gán `SUNWOO MEDICAL CENTER` |
| CHI_PHI | `VAT_TU_TIEU_HAO` | `stg_frmacph_vat_tu`: `stock_valuation_layer` của ERP PH | Cách tính giống Kangnam (`report_bc_chi_phi_vtth`). Xem bên dưới |

- **`so_tien_vnd`**: số tiền VND theo đúng bản chất. Doanh thu dương, hoàn tiền âm; chi phí dương, trả lại kho âm.
- **`tac_dong_loi_nhuan`**: doanh thu giữ nguyên dấu, chi phí đổi dấu. Vì vậy **`SUM(tac_dong_loi_nhuan)` chính là lãi gộp**.
- **Bộ lọc khi làm báo cáo**: luôn lọc `trang_thai_du_lieu = 'THAT'`. Dòng chi phí luôn là `THAT`.

**Chi phí vật tư (`stg_frmacph_vat_tu`)**
- **Dòng được tính**:
  - Lấy các dòng định giá kho đi qua ranh giới kho nội bộ.
  - `internal → production / customer / inventory` (xuất dùng, bán, hao hụt) là chi phí dương.
  - `production / customer / inventory → internal` (trả lại kho) làm giảm chi phí.
- **Dòng bị loại**: nhập mua từ nhà cung cấp và chuyển giữa các kho nội bộ không tính là chi phí.
- **Lọc ngày**: bắt buộc lọc ngày ≥ go-live và `brand_etl = 9`, vì bảng kho của ERP SUN mang theo lịch sử sao chép từ Kangnam (`stock_move` có 1,48 triệu dòng, chỉ 325 dòng từ go-live).
- **Đơn vị tiền**: công tắc `var('ph_vat_tu_don_vi')`, mặc định `VND`. Kiểm tra ngày 08/10/2026 cho thấy:
  - công ty trong ERP PH dùng **PHP**: bút toán sổ kho 922 ghi PHP;
  - nhưng **giá vốn vật tư là số VND** sao nguyên từ ERP Kangnam. Ví dụ khẩu trang 576, bơm tiêm 5ml 735, Profhilo 5.194.444 mỗi hộp.
  - Nếu hiểu những số này là PHP thì 35 lần xuất từ 11 đến 21/09 thành khoảng 5,1 tỷ VND thay vì khoảng 12 triệu.
  - Mặc định `VND` lấy nguyên số làm VND. Khi đội ERP sửa giá vốn sang PHP thì đặt `ph_vat_tu_don_vi: PHP` để quy đổi theo tỷ giá PHP của ngày xuất.
  - Cột `ly_do` ghi rõ giá vốn đang được hiểu theo đơn vị nào.
- **Chi phí khác**: đến 07/10/2026 ERP PH **chưa ghi nhận** hoá đơn mua hàng, phiếu chi cho nhà cung cấp hay chi phí nhân viên. Các bút toán khác ngoài sổ kho đều là phiếu thu, cộng thêm 1 hoá đơn bán 43.000. Khi ERP có thêm loại chi phí nào thì bổ sung khoản mục mới vào phần `UNION` của model.

## 4. Test (`dbt build --select tag:phi`)

| Test | Bắt lỗi gì |
|---|---|
| `payment_id` unique + not_null | Join bị nhân dòng |
| `tests/ph/assert_ph_doanh_thu_co_ty_gia.sql` | Phiếu `THAT` thiếu tỷ giá: loại tiền mới, hoặc `ty_gia_acb` chưa có ngày đó |
| `tests/ph/assert_ph_doanh_thu_khop_phieu_thu.sql` | Số phiếu và tổng tiền gốc theo loại tiền lệch so với `ph.account_payment` |
| `tests/ph/assert_ph_dtcp_khong_thieu_tien.sql` | Dòng `THAT` của bảng doanh thu + chi phí không có số tiền VND |
| `tests/ph/assert_ph_dtcp_khop_nguon.sql` | Từng khoản mục lệch so với nguồn: doanh thu so với `report_ph_doanh_thu`, quảng cáo so với `cs_facebook_insight`, vật tư so với `stock_valuation_layer` |
| `unique` trên `sandbox_ph.tk_test.user_id` và `sandbox_ph.danh_dau_thu_cong.lead_id` | Bảng nhập tay bị trùng thì mọi báo cáo PH, kể cả doanh số, sẽ nhân dòng |

## 5. Ví dụ dùng

```sql
SELECT thang, chi_nhanh, sum(doanh_thu_vnd) AS doanh_thu_vnd
FROM sandbox_ph.report_ph_doanh_thu
WHERE trang_thai_du_lieu = 'THAT'
GROUP BY 1, 2
ORDER BY 1, 2;
```

```sql
-- Lãi gộp theo tháng
SELECT thang,
       sum(so_tien_vnd) FILTER (WHERE nhom = 'DOANH_THU') AS doanh_thu,
       sum(so_tien_vnd) FILTER (WHERE nhom = 'CHI_PHI')   AS chi_phi,
       sum(tac_dong_loi_nhuan)                            AS lai_gop
FROM sandbox_ph.report_ph_doanh_thu_chi_phi
WHERE trang_thai_du_lieu = 'THAT'
GROUP BY 1
ORDER BY 1;
```
