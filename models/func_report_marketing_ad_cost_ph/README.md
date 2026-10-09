# func_report_marketing_ad_cost_ph — Báo cáo marketing Philippines

Bảng output (cùng tag **`phi`**):

| Bảng | Model | Doanh số (DS) |
|---|---|---|
| `sandbox_ph.report_marketing_ad_cost_ph_thu` | `mart_report_marketing_ad_cost_ph_thu` | Quy đổi VND theo tỷ giá (mục 1.1) + 4 cột tỷ giá |
| `sandbox_ph.report_marketing_ad_cost_ph` | `mart_report_marketing_ad_cost_ph` | Quy đổi VND theo tỷ giá (mục 1.1) – **cùng số với `_thu`** |

**[2026-10-08]** Trước đây bảng `report_marketing_ad_cost_ph` lấy `amount_vnd` của ERP (SAI với phiếu
PHP – thấp ~400 lần). Nay cả 2 bảng cùng lấy `stg_frmacph_doanh_so_thu`; model `stg_frmacph_doanh_so`
(bản `amount_vnd`) đã xoá. Bản `_thu` chỉ thêm 4 cột cuối: `loai_tien`, `so_tien_goc`,
`ngay_ty_gia`, `ty_gia` (chỉ có giá trị ở dòng DS). Dashboard dùng bảng nào cũng đúng.

26 cột đầu **giống hệt** `report_marketing_ad_cost_kn_v2` (tên, thứ tự) → dashboard Tableau của
Kangnam chỉ cần đổi nguồn bảng. Thêm 4 cột cuối:

| Cột | Ý nghĩa |
|---|---|
| `trang_thai_du_lieu` | `THAT` / `TEST` / `NGHI_TEST` — **luôn lọc `= 'THAT'`** khi làm báo cáo |
| `ly_do` | Lý do phân loại |
| `lead_id` | `ph.crm_lead.id` (NULL với chi phí/inbox) |
| `nguon_he_thong` | Dòng đến từ FB brand 1 hay ERP PH brand 9 |

## 1. Nguồn dữ liệu

| type_data | Nguồn | Ghi chú |
|---|---|---|
| `Cost_fb_cd` | `cs_facebook_insight` (brand_etl = 1), campaign `ILIKE 'sun\_%'` | Toàn bộ campaign `sun_` thuộc TK "Kangnam Surgery - Quốc tế 06 - Phil" (act_27957337653894035), bắt đầu 19/09/2026 |
| `inbox` | `m_inbox_sunwoo` (từ 06/10/2026; trước đó là các dòng `sun_` trong `m_inbox_kangnam`, nay đã chuyển hết sang bảng mới) | Không có quốc gia → `quoc_gia = 'QUỐC TẾ'` (giống KN). **Không dùng cột "vùng"** (từ 08/10/2026 sheet tổng hợp theo campaign, cột vùng trống, kiểu dữ liệu không ổn định) → `local_k`, `tinh_noi` của inbox = `KXĐ`. **Chống nạp trùng** (từ 09/10/2026): mỗi ngày × chiến dịch chỉ lấy lần nạp mới nhất (`ingestion_timestamp`). Cột `chi phí facebook` không dùng – chi phí lấy từ `cs_facebook_insight` |
| `Lead` | `ph.crm_lead` type_crm_id = 1, theo ngày tạo (`create_on`) | Metric = SĐT |
| `BKHL` | type_crm_id = 2, theo ngày tạo | |
| `HL` | type_crm_id = 2, theo ngày hẹn (`booking_date`) | |
| `DC` | type_crm_id = 2, theo ngày đến (`arrival_date`) | |
| `TC` | như DC + tổng `crm_line.total_received` > 0 | |
| `DS` | `ph.account_payment` state = `posted` (outbound trừ). `amount` × tỷ giá theo loại tiền (`stg_frmacph_doanh_so_thu`, tỷ giá ACB theo ngày) – cả 2 bảng | Nhiều loại tiền (PHP/VND/USD/AUD) – xem mục 1.1 |

Không có `Google_*` và `DealCS` (PH chưa có dữ liệu tương ứng).

### 1.1. Tỷ giá (DS) — chỉ dùng tỷ giá ACB theo ngày

ERP PH **không quy đổi** phiếu thu PHP: `amount_vnd` = nguyên số peso (doanh thu peso bị ghi thấp
~400 lần). Kho dữ liệu chưa có bảng tỷ giá của ERP PH (`res_currency_rate`).

`stg_frmacph_doanh_so_thu.sql` quy đổi `amount × tỷ giá`, tỷ giá lấy từ `stg_frmacph_ty_gia` = **tỷ giá
ACB theo ngày** (`public.ty_gia_acb`, pipeline `data_ops/dags/acb_fx`, DAG `acb_fx_etl` 06:15 giờ VN,
chốt 23:59, có từ 10/09/2026 – Techcombank / Vietcombank không niêm yết PHP):
- giá **bán chuyển khoản** (`deal_type = 'ASK'`, `instrument_type = 'TRANSFER'`) của ngày thu; thiếu
  ngày → ngày gần nhất trước đó. PHP khoảng 421–425 (10/09 → 07/10/2026). VND = 1.
- ngày / loại tiền chưa có trong `ty_gia_acb` → `nguon_ty_gia = 'THIEU_TY_GIA'`, doanh số NULL, test
  `assert_ph_doanh_thu_co_ty_gia` báo lỗi (không âm thầm cộng sai).

Lịch sử: seed tỷ giá thị trường + script máy cá nhân (đến 06/10) → tỷ giá **cố định** tạm theo chỉ đạo
sếp (07–08/10: PHP 405, USD 25.806,79 Techcombank, AUD 18.315,78) qua công tắc `ph_nguon_ty_gia` →
sếp duyệt ACB (08/10) → **từ 09/10/2026 bỏ hẳn tỷ giá cố định và công tắc, chỉ dùng ACB**.

Cột `nguon_ty_gia` (`report_ph_doanh_thu`) cho biết dòng dùng tỷ giá nào. Đồng thời từ 08/10/2026
doanh số chỉ lấy phiếu `brand_etl = 9`, phiếu của khách (`partner_type = 'customer'`), thu/hoàn
(`inbound`/`outbound`), ngày thu ≥ `var('ph_go_live_date')` (mặc định 2026-09-10).

## 2. `brand_etl = 9`

Schema `ph` là ERP riêng của Philippines (brand 9), được nhân bản từ ERP Kangnam → **`id` trùng với
brand 1** (vd `m_res_company.id = 4` là BV Kangnam Sài Gòn ở brand 1 nhưng là SUNWOO MEDICAL CENTER
ở brand 9). Model chỉ join các bảng `ph` với nhau; **không join id `ph` với bảng brand 1**.

## 3. Khác biệt so với model Kangnam

- **Cấp dữ liệu CRM**: 1 dòng / lead / loại (KN: lead × dòng DV × phiếu thu). Metric = SĐT → đếm
  `COUNTD(Metric)` cho kết quả tương đương. Nếu Tableau dùng `COUNT` thay vì `COUNTD` sẽ lệch.
- **Múi giờ**: ngày ERP cộng **8 giờ** (Manila); KN cộng 7 giờ.
- **Lọc**: `create_by <> 0`, bỏ booking bảo hành (type_crm_id = 3 /
  `reason_cancel_booking = 'tao_booking_bh'`), bỏ nhóm DV `SAN PHAM`.
- **KHÔNG lọc `active = true`** (khác KN): ở ERP PH, booking đã đến cửa / Won / đã thanh toán và lead
  đã chuyển thành booking đều có `active = false`. Lọc như KN làm mất gần hết DC/TC thật
  (DC còn 2, TC = 0). Dữ liệu test được loại bằng `trang_thai_du_lieu` (đã thống nhất 2026-10-05).
- **Campaign / actor / account_fb / nhom_dv_muc_tieu / page cho dòng khách** (Lead/BKHL/HL/DC/TC/DS):
  lấy qua **Pancake** (từ 08/10/2026) — ERP PH không lưu campaign FB (`ad_id` trống) và ticket
  Caresoft của PH tạo qua API (`ad_id_value = '[]'`), nên KN dùng Caresoft còn PH dùng Pancake:
  `ph.crm_lead.pancake_conversation_id = pancake_conversation.conversation_id` (duy nhất) →
  `first_ad_id` (quảng cáo khách bấm vào) → campaign `sun_` (`stg_frmacph_pancake`). Không khớp →
  `KXĐ`. Lý do KXĐ thường gặp: lead nhập tay không có mã hội thoại, hội thoại chưa được ETL Pancake
  kéo về, khách tự nhắn tin (không từ QC), QC của page chưa có trong `cs_facebook_insight`
  (vd page Hair Growth / Skin Rejuvenation – thiếu tài khoản quảng cáo trong ETL).
- **`nhom_dv` (nhóm DV hệ thống) của dòng khách**: **giữ nguyên theo ERP** (danh mục sản phẩm ERP PH
  hiện chỉ có `Service`; lead chưa có dịch vụ → `KXĐ`) — user chốt 08/10/2026 không map thêm.
  Nhóm DV theo quảng cáo xem cột `nhom_dv_muc_tieu`.
- **`nhom_dv` / `nhom_dv_muc_tieu` của chi phí, inbox** (và `nhom_dv_muc_tieu` của dòng khách có
  campaign): tra token 5 tên campaign qua `stg_frmacph_nhom_dv_map` = seed riêng PH
  **`seeds/ph/campaign_name_split_ph.csv`** (`sandbox_ph`, ưu tiên: `mesohair`, `cayhacollagen`,
  `cchi`) rồi mới tới seed chung `campaign_name_split` (**không sửa bảng chung**). Mã mới của
  Sunwoo → thêm vào seed PH rồi `dbt seed --select campaign_name_split_ph`.
- **`chi_nhanh`** của chi phí/inbox gán cứng `SUNWOO MEDICAL CENTER`.

## 4. Trạng thái dữ liệu test/thật

Quy tắc (`stg_frmacph_trang_thai`, giống view `sandbox_ph.v_lead_trang_thai`), theo ưu tiên:

1. Ghi đè thủ công: `sandbox_ph.danh_dau_thu_cong (lead_id, trang_thai, ghi_chu)`
2. Lead tạo bởi tài khoản trong `sandbox_ph.tk_test` → `TEST`
3. Tên/mô tả/địa chỉ có từ khoá test (`test|aaaa|demo|asdf|thử nghiệm`) → `TEST`
4. Booking (`type_crm_id = 2`) có mã (`crm_lead.name`) **không** bắt đầu bằng `BOOK-` → `TEST`
   (booking thật luôn có mã `BOOK-yymmdd-xxxxx`; không áp cho lead – mã là tên khách – và booking
   bảo hành `BH-`) — thêm 07/10/2026
5. Công ty = Văn phòng thương hiệu (id 54) hoặc quốc gia = Việt Nam (id 241) → `NGHI_TEST`
6. Còn lại → `THAT`

DS kế thừa trạng thái của lead (`crm_id`); phiếu thu không gắn lead → `NGHI_TEST`.
Chi phí & inbox luôn `THAT`.

Hai bảng cấu hình `tk_test`, `danh_dau_thu_cong` do người dùng tự sửa trực tiếp trong DB; sửa xong
cần build lại model.

## 5. Build

Toàn bộ dự án Philippines (2 bảng marketing + `report_ph_sale_online`) mang tag **`phi`**.
**Chỉ chạy theo tag, không chạy cả project:**

```bash
dbt seed --select tag:phi --profiles-dir .   # seed riêng PH (campaign_name_split_ph → sandbox_ph)
dbt run  --select tag:phi --profiles-dir .
dbt test --select tag:phi --profiles-dir .
```
(Windows: đặt `PYTHONUTF8=1` trước khi chạy dbt.)

**Ghi vào `sandbox_ph`** nhờ macro `macros/generate_schema_name.sql`: macro **chỉ** xử lý riêng
schema `sandbox_ph`; mọi trường hợp khác giữ nguyên mặc định dbt. Đã kiểm chứng 07/10/2026 bằng cách
compile toàn bộ project trước/sau: 522 model cũ giống hệt SQL và nơi ghi.

**Phụ thuộc bảng cấu hình tạo tay trong `sandbox_ph`** (không do dbt quản lý, phải tồn tại trên DB):
`tk_test`, `danh_dau_thu_cong` (trạng thái dữ liệu), `team_sale_ph` (team NV Sunwoo cho
`report_ph_sale_online`).

## 6. Lưu ý chồng chéo với báo cáo Kangnam

- **Inbox** `sun_`: từ 06/10/2026 đã tách sang `m_inbox_sunwoo` → không còn trong báo cáo Kangnam
  (sau lần build KN kế tiếp).
- **Chi phí** campaign `sun_`: **đã loại khỏi** chi phí Kangnam từ 08/10/2026 (data_serving PR #106,
  `stg_frmack_fb_insight_v2.sql` và `int_rtds_chi_phi_ads.sql` thêm
  `coalesce(ad_campaign_name, '') NOT ILIKE 'sun\_%'`) → không còn tính trùng giữa 2 báo cáo.
