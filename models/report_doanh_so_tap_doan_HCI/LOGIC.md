# Logic: report_doanh_so_tap_doan_HCI

Gom doanh số 4 đơn vị trong tập đoàn HCI vào 1 bảng UNION ALL, 1 dòng = 1 giao
dịch thu tiền của brand tương ứng:

| Brand | Hệ nguồn | Nguồn dữ liệu | Điều kiện |
|---|---|---|---|
| Kangnam | CRM | `source('crm_base','stag_payment_transfer')`, cột `payment` | `brand_etl = 1` |
| Paris | CRM | `source('crm_base','stag_payment_transfer')`, cột `payment` | `brand_etl = 3` |
| Hồng Hà | EHC | `{{ ref('fct_doanhso_ehc_theo_nguon') }}` | (đã lọc sẵn trong model gốc) |
| Tiêu Hóa Việt (VDE) | EHC | `{{ ref('fct_doanhso_ehc_vde_theo_nguon') }}` (bảng `_thv`) | (đã lọc sẵn trong model gốc) |

Dùng `stag_payment_transfer` **thật** (source `crm_base`), không dùng
`stag_payment_transfer_dbt` (mart trong `erp_staging/payment_transfer`) vì
theo `erp_staging/payment_transfer/LOGIC.md` bảng dbt **chưa cutover**, chỉ
dùng để đối chiếu — chưa phải nguồn production đáng tin cậy.

## Cột output

`brand`, `nguon_he_thong` ('CRM'|'EHC'), `ma_giao_dich`, `ma_khach_hang`,
`ten_khach_hang`, `ngay`, `so_tien`, `nguon`, `nhom_nguon_khach`, `chi_nhanh`.

**`chi_nhanh`** (thêm 2026-08-06): Kangnam/Paris join `stag_payment_transfer.company_id`
→ `m_res_company.name` (PHẢI lọc `m_res_company.brand_etl` trước khi join —
đã verify join không lọc brand bị **fan-out gấp đôi số dòng** do `id` trùng
chéo giữa các brand, giống hệt vấn đề đã gặp với `crm_lead`). Sau khi lọc
đúng brand: match 100%, không có `chi_nhanh` NULL. Hồng Hà/VDE là bệnh viện
1 địa điểm duy nhất (`ehc_tb_room.hospitalunitid` luôn = 0, không có bảng chi
nhánh trong EHC) nên gán cứng `chi_nhanh` = tên brand.

**`nguon`/`nhom_nguon_khach`** (2026-08-06, cập nhật): Hồng Hà/VDE lấy từ
"người giới thiệu" EHC (như trước). Kangnam/Paris lấy qua
`crm_lead.source_id -> stag_sources.old_id` (`source` = Nguồn,
`newcat_source` = Nhóm nguồn khách) — **không** join thẳng
`utm_source.category_id -> crm_category_source` như hướng ban đầu user đề
xuất: đã thử và 2 cột `category_id` này không cùng hệ id (~99.7% miss).
`stag_sources` là bảng tổng hợp sẵn cùng nội dung từ `utm_source`
(`brand_etl` luôn NULL — nguồn dùng chung mọi brand, không cần lọc brand khi
join; `old_id` duy nhất, không fan-out).

**Giới hạn đã biết:** vì `nguon`/`nhom_nguon_khach` của Kangnam/Paris đi qua
CTE `cl` (`crm_lead` đã lọc brand) — cùng join đang gây NULL cao ở
`ma_khach_hang` (xem `knowledge.md` mục 2) — nên 2 cột này **thừa hưởng đúng
tỷ lệ NULL đó** (~65% Kangnam, ~71% Paris), không phải lỗi mới phát sinh.

## Join `crm_lead` lấy mã/tên khách hàng (Kangnam/Paris)

**Bắt buộc lọc `crm_lead.brand_etl` TRƯỚC khi join** `crm_id = id`
([[feedback_hci_dataserving_brand_etl_collision]] — id có thể trùng chéo giữa
các brand). Model lọc `crm_lead` theo đúng brand_etl của từng CTE (kangnam:
1, paris: 3) rồi mới LEFT JOIN — nếu không sẽ lấy nhầm tên/mã khách hàng của
brand khác khi id trùng.

**Hệ quả đã biết (xem `knowledge.md`):** tỷ lệ NULL `ma_khach_hang` ở
Kangnam/Paris khá cao (~65-71%) — không phải lỗi model, mà vì nhiều
`crm_id` trên `stag_payment_transfer` trỏ tới `crm_lead.id` thuộc brand khác
hoặc không tồn tại trong `crm_lead`. `so_tien`/tổng doanh số theo brand không
bị ảnh hưởng (lấy thẳng từ `payment`, không phụ thuộc join này).
