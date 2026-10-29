# func_report_marketing_ad_cost_da — Báo cáo marketing Đông Á

Bản Đông Á (`brand_etl = 2`) của `func_report_marketing_ad_cost_kn`.
Output: bảng `report_marketing_ad_cost_da`, cùng bộ cột với
`report_marketing_ad_cost_kn_v2` và thêm cột `brand_etl` ở cuối.

## Luồng

```
common/stg_common_tongquan_khachhang_da ─┐
common/stg_dv_khach_hang_quan_tam_da ────┼─► stg_frmacda_crm_base ─┐
common/stg_booking_nhom_dich_vu_chinh_da ┤                         ├─► int_frmacda_union ─► int_frmacda_region ─► mart_report_marketing_ad_cost_da
                                         └─► stg_frmacda_doanh_so ─┘
```

Tất cả model là `ephemeral`, chỉ riêng mart là `table`. Model không đọc hay sửa bảng nào của Kangnam.

## Đã có

| type_data | Nguồn | Ngày lấy theo |
|---|---|---|
| Lead | crm_lead type 1 | ngày tạo |
| BKHL | crm_lead type 2 | ngày tạo |
| HL | crm_lead type 2 | ngày hẹn |
| DC | crm_lead type 2 | ngày đến cửa |
| TC | crm_lead type 2, tong_tien > 0 | ngày đến cửa |
| DS | stag_payment_transfer brand 2 | ngày thanh toán |

## Dữ liệu đã kiểm tra trên staging_sci (21/10/2026)

- 673 bản ghi CRM, có từ 09/08/2026. Toàn bộ thuộc chi nhánh 12 – Bệnh viện Thẩm mỹ Đông Á.
- type_crm_id (1 = Lead new, 2 = Booking new) và tên stage (Won / Đặt cọc / Đang xử lý) giống Kangnam.
- 100% crm_line khớp `view_stag_products` brand 2.
- Doanh số có 1.543 dòng, **chỉ có từ 06/09/2026**.
- Không lead nào có `new_source_id`. ERP Đông Á nhân bản từ Kangnam nên `source_id` giống hệt
  (219 = K - Cho thuê phòng Mổ, chiếm 638/673 lead): `utm_source` brand_etl 1 và 2 cùng id, cùng tên.
- `stag_sources` chỉ có dòng brand_id = 1, nên model lấy Nguồn / Nhóm nguồn từ đó (giữ đúng bộ tên như
  báo cáo Kangnam). Nguồn nào không có ở đó thì lấy từ danh mục riêng của Đông Á (`utm_source` /
  `crm_category_source` brand_etl = 2). `nguon_moi_v2` ưu tiên mapping brand 2, sau đó tới brand 1.
- **`utm_source` phải lọc theo `brand_etl`, KHÔNG phải `brand_id`.** `brand_id` là mã thương hiệu bên
  trong từng ERP (= 1 ở mọi brand_etl 0/1/2/3/4/7), lọc theo nó sẽ khớp nhiều dòng của các brand khác.
- Rủi ro: nếu sau này Đông Á tạo nguồn mới mà id trùng một nguồn khác bên Kangnam, `stag_sources`
  (brand 1) sẽ trả tên của Kangnam. Khi có `stag_sources` brand 2 thì đổi sang dùng brand 2.
- `stag_employees` đã có cột `da_user_id`.
- **Khác Kangnam:** điều kiện `nhom_dv <> 'SAN PHAM'` của Kangnam loại luôn dòng có `nhom_dv` NULL
  (lead/booking chưa có crm_line). Với Đông Á, cách lọc đó chỉ còn 6 SĐT Lead trên 335 lead thật. Bản Đông Á
  dùng `COALESCE(nhom_dv, '') <> 'SAN PHAM'` và gán `nhom_dv = 'KXĐ'`.
- Kết quả chạy thử logic model trên staging_sci (21/10/2026, trước khi sửa lỗi Lead): DS = 4.170.397.907 (khớp tổng
  stag_payment_transfer brand 2); BKHL 327 SĐT, DC 323, TC 310; không thiếu nguồn hay nhóm DV.

## Chưa có

| Phần | Cần gì |
|---|---|
| Chi phí FB (Stream 1), Inbox, DealCS, campaign/page/actor | Domain và token CareSoft Đông Á |
| Chi phí Google (GG) | Xác nhận Đông Á có chạy Google Ads, customer ID |
| actor → tên người chạy | Danh sách nhân sự MKT Đông Á cho `ucbt_camp_actor` |
| Sale online | Danh sách sale online Đông Á cho `stag_employees` |

Khi có ticket CareSoft Đông Á: thêm join `cs_ticket_api` (brand_id của domain mới) vào
`stg_frmacda_crm_base` / `stg_frmacda_doanh_so` để lấy `ad_id`, rồi mở lại các join
`dim_camp_adset_ad` / `dim_campaign` / `dim_account` / `ucbt_page_config` như bản Kangnam.
