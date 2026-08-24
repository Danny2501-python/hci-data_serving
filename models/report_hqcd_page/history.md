# history.md — Nhật ký điều tra & fix hiệu năng/lock của `report_hqcd_page`

Ghi lại các lần điều tra sự cố (lock/deadlock, chạy chậm) và fix đã áp dụng cho
nhóm model `report_hqcd_page` (`mart_rhp_page` → alias `report_hqcd_page`), để
tra cứu lại khi gặp lại triệu chứng tương tự.

## 2026-08-11 — Block chain khi chạy `mart_rhp_page`, model chạy 50+ phút

### Triệu chứng
`dbt run` bị treo lâu, model `mart_rhp_page` chạy 50+ phút, kéo theo các model
khác (`mart_report_marketing_ad_cost_kn`, `stag_employees`, 1 query ad-hoc)
xếp hàng chờ lock tới 15-29 phút. Check `pg_stat_database.deadlocks` không có
deadlock mới (chỉ có 1 lần cũ từ tháng 2, không liên quan).

### Nguyên nhân #1 — DAG sai vì dùng `source()` thay vì `ref()`
`int_rhp_page_cost.sql` đọc bảng `report_marketing_ad_cost_kn_v2` qua
`{{ source('rhp', 'report_marketing_ad_cost_kn_v2') }}`, nhưng bảng đó thực
chất là **output** của model khác: `mart_report_marketing_ad_cost_kn`
(`materialized: table`, `alias: report_marketing_ad_cost_kn_v2`). Vì khai báo
bằng `source()`, dbt không biết `mart_rhp_page` phụ thuộc vào
`mart_report_marketing_ad_cost_kn` → DAG không serialize thứ tự chạy, 2 model
này chạy song song, đụng lock: 1 bên đang đọc bảng (AccessShareLock) lúc bên
kia đang `ALTER TABLE RENAME` để swap bảng mới vào (AccessExclusiveLock).

**Fix:** đổi `source('rhp', 'report_marketing_ad_cost_kn_v2')` →
`ref('mart_report_marketing_ad_cost_kn')` trong `int/int_rhp_page_cost.sql`.

### Nguyên nhân #2 — `int_rhp_page_inbox` bị tính lại nhiều lần
`int_rhp_page_inbox` (dedup `cs_ticket_api` bằng
`row_number() over (partition by ticket_id)`) được `ref()` ở 3 chỗ trong cùng
1 câu SQL cuối cùng: trực tiếp trong `mart_rhp_page`, trong
`int_rhp_page_lead`, trong `int_rhp_page_ds`. Model này không có config riêng
nên dùng default `ephemeral` của folder `int` (`dbt_project.yml`) → dbt
inline lại y hệt logic dedup **3 lần** trong 1 câu query duy nhất, không có
gì được cache.

Đã kiểm tra: `stg_rhp_mv_cline.sql`/`stg_rhp_mv_ecl.sql` **đã có sẵn**
`materialized = 'table'` ngay trong file (override default `ephemeral` của
folder) từ trước — không bị lỗi tương tự, khỏi cần sửa.

**Fix:** thêm config block vào `int/int_rhp_page_inbox.sql`:
```sql
{{ config(materialized = 'table') }}
```
(Lưu ý: cân nhắc `view` trước nhưng bỏ — `view` trong Postgres không cache kết
quả, mỗi lần `SELECT` từ view vẫn bị expand lại y như ephemeral, không giải
quyết được vấn đề tính lại 3 lần. Phải là `table` mới thực sự chỉ tính 1 lần.)

### Nguyên nhân #3 (phát hiện sau khi fix #1/#2, KHÔNG phải bug code)
Chạy `dbt run --select report_hqcd_page` (v1.12.0b1) vẫn bị treo ở bước 1
(`stg_rhp_mv_cline`). Kiểm tra `pg_stat_activity` phát hiện có **1 tiến trình
dbt khác** (version cũ hơn 1.11.4, kết nối từ 1 IP nội bộ khác — không phải
máy chạy lệnh) đang chạy `mart_rhp_page` cùng lúc, khởi động trước ~11 phút,
giữ lock đọc `stg_rhp_mv_cline` khiến run mới không rename/swap được bảng đó.

→ Đây là **2 lần chạy dbt riêng biệt đụng nhau cùng lúc** trên cùng
target/schema (có khả năng là job lịch tự động chạy song song với lần chạy
thủ công), không phải lỗi trong code model. Cách nhận diện: so `client_addr`
+ `application_name` + `backend_start` trong `pg_stat_activity` giữa các PID
đang tranh chấp lock.

### Cách check nhanh khi nghi có lock/deadlock (dùng lại được)
Query blocking chain kèm PID/model/thời gian chờ qua `pg_locks` join
`pg_stat_activity` (self-join theo `locktype`/`relation`/... để tìm ai đang
giữ lock mà PID khác đang chờ). Bổ sung thêm `client_addr`, `application_name`,
`backend_start` khi nghi ngờ có nhiều tiến trình dbt chạy song song từ nhiều
máy/job khác nhau.

### Việc còn tồn đọng (chưa làm, xem thêm ở lần trao đổi liên quan)
- `int_rhp_page_deal.sql`: `cross join lateral jsonb_array_elements(...)` nổ
  hết mảng JSON rồi mới filter `cf_id = '9794'` — nên filter trước khi explode
  nếu bảng `cs_deal_detail_api_v2` lớn.
- `int_rhp_page_ds.sql`: subquery `sum(sub_mt)` tính tổng riêng (cross join)
  có thể gộp bằng window function để đỡ quét bảng 2 lần.
- Cân nhắc incremental cho `mart_rhp_page` thay vì full-refresh mỗi lần (khó
  vì logic `page_rate` cần tổng toàn lịch sử — chưa có thiết kế cụ thể).
