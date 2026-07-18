# Model `report_kn_tele_transfer`

Model dbt phục vụ nghiệp vụ **đối soát chuyển giao khách hàng (tele-transfer)** giữa hệ thống chăm sóc khách hàng CS/Caresoft (ticket, deal, comment) và CRM lead của thương hiệu Kangnam (`brand_id` / `brand_etl` = 1). Mục tiêu chính là xác định một lead mới tạo trong CRM có phải **"SĐT mới"** (khách chưa từng được headsale nào chăm sóc, hoặc do đúng người tạo lead chăm sóc lần đầu) hay **"SĐT cũ"** (khách đã có lịch sử chăm sóc trước đó / bị người khác tạo lại lead), phục vụ tính KPI/ghi nhận doanh số cho nhân viên headsale và theo dõi nguồn (nguồn UTM, trang quảng cáo).

## Bài toán nghiệp vụ

- Khi một khách hàng nhắn tin/để lại thông tin trên hệ thống CS (ticket), nhân viên **headsale** đầu tiên tiếp nhận (comment đầu tiên trong nhóm `%head%`) được ghi nhận là người chăm sóc đầu.
- Khi lead được tạo trong CRM (`crm_lead`), cần so sánh người tạo lead hiện tại với headsale đầu tiên của ticket, và khoảng cách thời gian giữa hai mốc, để phân loại **SĐT mới / SĐT cũ / Khác**.
- Đồng thời gắn thêm thông tin: nguồn UTM (`utm_source`), sản phẩm/dịch vụ (`view_stag_products`, `crm_line`), doanh số đã ghi nhận (`stag_payment_transfer`), và số điện thoại thực (qua `cs_deal_detail_api_v2` → `cs_contact_api`).

## Kiến trúc

```
raw_data (sources, khai báo tại mart/source.yml)
      │
      ▼
int/            làm sạch & chuẩn hoá từng bảng nguồn, lọc theo brand = 1
      │
      ▼
stag/ktt_combine   ghép toàn bộ thành 1 bảng phân tích
      │
      ▼
mart/            (chưa có model, hiện chỉ khai báo source.yml — để dành cho báo cáo tổng hợp sau)
```

### `int/` — làm sạch nguồn thô (đều lọc `brand_id`/`brand_etl` = 1)

| Model | Nguồn (`source`) | Vai trò |
|---|---|---|
| `ktt_lead` | `crm_lead` | Lead/booking CRM: người tạo, nguồn, ngày tạo/đến/hẹn (quy đổi +7h), trạng thái, `ticket_id` liên kết CS |
| `ktt_first_headsale` | `cs_deal_api_trans_comments` + `cs_agents_api` | Comment **đầu tiên** trên mỗi ticket do agent thuộc nhóm headsale (`group_name ilike '%head%'`) thực hiện — xác định người & ngày chăm sóc đầu |
| `ktt_deal` | `cs_deal_detail_api_v2` | Chi tiết deal CS: `id` (= ticket_id), `requester_id` (khoá nối sang contact) |
| `ktt_contact` | `cs_contact_api` | Danh bạ khách hàng CS, chứa `phone_no` thực tế |
| `ktt_se` | `view_stag_employees_user` | Nhân viên: `employee`, `work_email`, `user_id` |
| `ktt_payment` | `stag_payment_transfer` | Doanh số ghi nhận: đổi tên cột thành `ngay_tt`, `doanh_so`, `vao_so` |
| `ktt_ad_page` | `cs_ticket_api` + `dim_page_ad` | Ad/Page gốc của ticket (qua `ad_id` trích từ `ad_id_value`) — **hiện chưa được `ktt_combine` sử dụng**, để dành cho phân tích hiệu quả quảng cáo |

### `stag/ktt_combine` — model trung tâm

Ghép toàn bộ các model `int` ở trên (dùng `ref()`) cùng 3 bảng nguồn chưa có model riêng (`utm_source`, `crm_line`, `view_stag_products`, join trực tiếp qua `source()`, lọc `brand_etl = 1`):

1. `ktt_first_headsale` (f) **left join** `ktt_lead` (cl) theo `f.ticket_id = cl.ticket_id`.
2. **left join** `ktt_se` (se) theo `se.user_id = cl.create_uid` — lấy tên người tạo lead hiện tại.
3. **left join** `ktt_deal` (dl) theo `dl.id = f.ticket_id`, rồi **left join** `ktt_contact` (ct) theo `ct.id = dl.requester_id` — lấy `phone_no` thực.
4. **left join** `utm_source` (us) theo `cl.new_source_id = us.id` — tên nguồn.
5. **left join** `crm_line` (cl2) theo `cl.id = cl2.crm_id`, rồi **left join** `view_stag_products` (sp) theo `sp.product_id = cl2.product_id` — thông tin dịch vụ/sản phẩm của line.
6. **left join** `ktt_payment` (spt) theo `crm_id`, `clineid`, `product_id` — doanh số phát sinh trên line/sản phẩm đó.

**Logic phân loại `group_data`:**

| Điều kiện | Kết quả |
|---|---|
| Người tạo lead (`se.employee`) = headsale đầu tiên (`f.username`), và tạo lead trong vòng ≤ 30 ngày kể từ ngày chăm sóc đầu | `SĐT mới` |
| Cùng người, nhưng tạo lead sau > 30 ngày | `SĐT cũ` |
| Khác người tạo, và ngày tạo lead sau ngày chăm sóc đầu | `SĐT cũ` |
| Còn lại | `Khác` |

**Lưu ý:** `where cl.create_date >= '20260524'` là filter cứng theo ngày, không dùng biến (`var('start_date')`) — cần xác nhận đây là chủ đích (ví dụ giới hạn dữ liệu từ thời điểm bắt đầu theo dõi) hay filter tạm thời cần thay bằng biến động.

## Ghi chú kỹ thuật

- Toàn bộ các model `int` lọc cứng theo brand Kangnam (`brand_id = 1` hoặc `brand_etl = 1`) — model này **chỉ phục vụ 1 thương hiệu**, không dùng chung cho các brand khác.
- `mart/source.yml` là nơi khai báo toàn bộ source dùng trong cả model — hiện chưa có model ở tầng `mart`, `ktt_combine` (tầng `stag`) đang là output cuối cùng.
- Nguồn dữ liệu: hệ thống CS/Caresoft (`cs_ticket_api`, `cs_deal_api_trans_comments`, `cs_deal_detail_api_v2`, `cs_contact_api`, `cs_agents_api`, `dim_page_ad`) và hệ thống CRM/ERP nội bộ (`crm_lead`, `crm_line`, `crm_line_product`, `view_stag_products`, `view_stag_employees_user`, `stag_payment_transfer`, `stag_crm_booking_arrival_company`, `utm_source`).
