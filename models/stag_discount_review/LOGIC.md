# Logic: stag_discount_review

Port 1:1 function Postgres `public.func_stag_discount_review_new_new()` (Dungtv,
cập nhật 2025/04/15 — thêm chiến dịch coupon/voucher) sang dbt.
**BÁO CÁO TỔNG KHUYẾN MẠI (bóc tách SM - CS)**.
Tag dbt: `stag_discount_review` (`int`/`stag` = ephemeral, `mart` = table).

Output vật lý (cùng tên bảng function cũ ghi):
- **`stag_discount_review_new_new`** — KM từng line (dịch vụ + sản phẩm), tách KM
  marketing / KM cơ sở, vượt trần giá sàn, chi nhánh phân quyền.
- **`stag_discount_review_camp`** — số tiền KM coupon/voucher theo chiến dịch.

Function cũ: `delete` + `insert` vào bảng có sẵn. dbt: `create table` lại mỗi lần
build (cột/thứ tự cột = đúng `select *` của temp table cuối trong function).

---

## Kiến trúc (map temp table của function → model)

```
int/sdr_coupon        (cte_coupon)      ─┐
int/sdr_voucher       (cte_voucher)     ─┤
int/sdr_walkin        (pk)              ─┤
int/sdr_lead          (lead_data)       ─┤
                                         │
int/sdr_service_data  (service_data)  ──┐│
int/sdr_product_data  (product_data)  ──┤│
  └── stag/sdr_line_union (temp_view_stag_discount)
        └── stag/sdr_line_discount (promo_discount → over_discount → permission_table → data_other)
              └── mart/stag_discount_review_new_new (output_data_1)

int/sdr_camp_service_coupon  (camp_service_data_1) ─┐
int/sdr_camp_service_voucher (camp_service_data_2) ─┤
int/sdr_camp_product_coupon  (camp_product_data_1) ─┤
int/sdr_camp_product_voucher (camp_product_data_2) ─┤
  └── stag/sdr_camp_union (union_data_2)
        └── mart/stag_discount_review_camp (output_data_2, no_tt = 1, bỏ cancel)
```

`stag_products`, `stag_payment_transfer` dùng `ref()` (model erp_staging),
các bảng ERP còn lại khai báo source `sdr_base` (`int/source.yml`).

## Ghi chú logic (giữ nguyên như function, không sửa)

- **pk / `sdr_walkin`**: dùng logic diempl — `duration = row_number()` theo
  `(booking_id, crm_line_id)` order by `close_walkin`, join `duration = 1`.
  Logic dungtv cũ (`duration = 0` theo chênh lệch ngày) đã bị comment trong function.
- `sdr_lead`: `row_number() over (partition by id)` không có `order by` — chỉ để
  khử trùng lặp booking type_crm_id = 3 (mọi dòng cùng id giống nhau ở các cột lấy ra).
- `stag_discount_review_camp`: `order by dim_date, id` của `no_tt` — `id` thực chất
  là `company_new.id` (union camp không có cột id). Giữ nguyên.
- Các `row_number()` có order by không duy nhất (vd `no_tt` theo `dim_date, id`) có
  thể chọn dòng khác nhau giữa các lần chạy khi trùng khoá — giống function gốc.

## Chạy

```
dbt build --select tag:stag_discount_review
```

Cutover: sau khi đối chiếu xong, tắt job đang gọi `select func_stag_discount_review_new_new()`
và thay bằng lệnh dbt trên. Bảng function cũ (nếu nằm ở DB khác) không bị dbt đụng tới.
