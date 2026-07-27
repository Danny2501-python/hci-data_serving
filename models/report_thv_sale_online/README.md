# Model `report_thv_sale_online`

Model dbt phục vụ báo cáo **bán hàng online** cho thương hiệu THV (`brand_etl = 8`). Model ghép dữ liệu lead/booking từ CRM (`crm_lead`, `crm_line`) với dữ liệu thanh toán từ hệ thống bệnh viện/phòng khám EHC (`ehc_tb_invoice`, `ehc_tb_patientrecord`, `ehc_tb_nguoigioithieu`), nhằm theo dõi nguồn khách hàng (UTM/nguồn giới thiệu), sản phẩm/dịch vụ, chi nhánh, và doanh số phát sinh theo từng booking/line.

## Kiến trúc

```
raw_data (sources, khai báo tại int/source.yml)
      │
      ▼
int/            làm sạch & chuẩn hoá từng bảng nguồn, lọc theo brand_etl = 8
      │
      ▼
stag/tso_combine   ghép toàn bộ thành 1 bảng phân tích (lead + line + payment EHC)
      │
      ▼
mart/            report_thv_sale_online — thêm cột dedup (row_number) phục vụ báo cáo
```

### `int/` — làm sạch nguồn thô

| Model | Nguồn (`source`/`ref`) | Vai trò |
|---|---|---|
| `tso_lead` | `crm_lead` (brand_etl = 8, active) | Lead/booking CRM: người tạo, nguồn, ngày tạo/đến/hẹn (quy đổi +7h), trạng thái, chi nhánh, lý do huỷ |
| `tso_cline` | `crm_line` (brand_etl = 8) **union all** `crm_line_product` (brand_etl = 8) | Chi tiết line của booking (`clineid`, `total_received`, `product_id`, `crm_id`, `stage`), join thêm `product_product`/`product_template`/`product_category` để lấy `product_ctg`; đánh `rnk_line` theo `crm_id` |
| `tso_payment` | `stag_payment_transfer` (brand_etl = 8) | Doanh số ghi nhận theo `crm_id`/`clineid`/`product_id` |
| `tso_ehc_payment` | `ehc_tb_invoice_thv` + `ehc_tb_patientrecord_thv` + `ehc_tb_nguoigioithieu_thv` | Phiếu thu/chi từ hệ thống bệnh viện EHC: chuẩn hoá dấu tiền theo loại phiếu (hoàn tiền/hoàn ứng → âm), map `dm_invoice_typeid` sang tên loại phiếu, lấy `id_booking`, `patientphone`, `patientname`, nguồn giới thiệu (`source_ehc`); lọc `huyphieu_status = 0` (chưa huỷ phiếu) |
| `tso_se` | `hr_employee` (brand_etl = 8) | Nhân viên: `employee` (alias từ `name`), `work_email`, `user_id` — **lưu ý**: có block code cũ (comment) từng lấy từ `view_stag_employees_user`, hiện đã đổi sang `hr_employee` |
| `tso_company` | `m_res_company` (brand_etl = 8) | Danh sách chi nhánh/công ty |
| `tso_contact` | `cs_contact_api_thv` | Danh bạ khách hàng CS (hiện **chưa được `tso_combine` sử dụng**) |
| `tso_country_state` | `res_country_state` (brand_etl = 8) | Tỉnh/thành (`tinh`) theo `state_id` |

### `stag/tso_combine` — model trung tâm

Ghép các model `int` (dùng `ref()`) cùng các bảng nguồn chưa có model riêng (`utm_source`, `view_stag_products`, `stag_sources`, `crm_category_source`, join trực tiếp qua `source()`):

1. `tso_lead` (cl) **left join** `tso_se` (se) theo `se.user_id = cl.create_uid` — người tạo lead.
2. **left join** `tso_company` (c) theo `c.id = cl.company_id` — chi nhánh.
3. **left join** `stag_sources` (ss) theo `ss.old_id = cl.source_id`, **left join** `utm_source` (us) theo `cl.new_source_id = us.id`, **left join** `crm_category_source` (cs) theo `cs.id = us.category_id` — phân loại nguồn khách hàng ở nhiều tầng (nguồn cũ, UTM, nhóm nguồn).
4. **left join** `tso_cline` (cl2) theo `cl.id = cl2.crm_id`, **left join** `view_stag_products` (sp) theo `sp.product_id = cl2.product_id` — dịch vụ/sản phẩm của line.
5. **full outer join** `tso_ehc_payment` (ep) theo `ep.id_booking = cl.lead_booking` — gộp phiếu thu/chi EHC vào booking; do là `full outer join`, các phiếu EHC không khớp booking nào trong CRM vẫn xuất hiện (với các cột lead = null).
6. **left join** `tso_country_state` (rcs) theo `rcs.id = cl.state_id` — tỉnh/thành khách hàng.

**Lưu ý:**
- CTE `payment` (từ `tso_payment`) và `team_group` (từ `table_team_sale_trans_field`) được khai báo nhưng **không được join/sử dụng** trong câu lệnh `select` cuối — cần xác nhận đây là code dở dang hay cột thừa cần dọn.
- `crm_category_source` đang lọc `brand_etl = 1` trong khi toàn bộ model còn lại lọc `brand_etl = 8` — cần kiểm tra lại vì có thể là copy nhầm từ model brand khác (Kangnam).

### `mart/report_thv_sale_online` — output cuối

Thêm 2 cột `row_number()` phục vụ khử trùng lặp khi báo cáo:
- `rnk_ds`: đánh số theo `partition by patientphone, sophieu` — dùng để lọc phiếu thu trùng theo khách hàng/số phiếu EHC.
- `rnk_line_new`: đánh số theo `partition by clineid` (không có `order by` tường minh) — dùng để lấy 1 dòng đại diện cho mỗi line khi 1 line bị nhân bản do `full outer join` với EHC.

## Ghi chú kỹ thuật

- Toàn bộ model lọc cứng theo `brand_etl = 8` (trừ `tso_contact` và ngoại lệ `crm_category_source` nêu trên) — model này **chỉ phục vụ 1 thương hiệu (THV)**.
- Nguồn dữ liệu gồm 2 hệ thống: CRM/ERP nội bộ (`crm_lead`, `crm_line`, `crm_line_product`, `utm_source`, `stag_sources`, `crm_category_source`, `view_stag_products`, `hr_employee`, `stag_payment_transfer`, `m_res_company`, `res_country_state`) và hệ thống bệnh viện/phòng khám EHC (`ehc_tb_invoice_thv`, `ehc_tb_patientrecord_thv`, `ehc_tb_nguoigioithieu_thv`).
- `int/source.yml` khai báo nhiều bảng chưa được model nào sử dụng (`dim_page_ad`, `cs_ticket_api_thv`, `cs_agents_api_thv`, `cs_chat_api_thv`, `dim_page`, `crm_stage`, `table_team_sale_trans_field`) — có thể để dành cho các phần báo cáo mở rộng sau (ví dụ hiệu quả quảng cáo, luồng chat CS).
