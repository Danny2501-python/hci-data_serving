# common — Knowledge (bug đã phát hiện & fix)

Ghi lại trong quá trình build `stg_crm_line_ecosystem.sql` và `stg_booking_nhom_dich_vu_chinh.sql`.
Các gotcha này áp dụng chung cho mọi model mới join vào các bảng nguồn liên quan trong
`data_serving` (không riêng 2 model trên).

## 1. `id` trùng chéo giữa các `brand_etl`

Kho dữ liệu này gộp nhiều thương hiệu về cùng 1 cấu trúc bảng, nên cột `id` (khóa chính) của rất
nhiều bảng **KHÔNG unique toàn cục** — cùng 1 giá trị `id` có thể thuộc nhiều `brand_etl` khác
nhau, với dữ liệu hoàn toàn khác nhau. Đã xác nhận với: `crm_line.id`, `crm_lead.id`, `product_id`
và `service_id` trong `view_stag_products` (99,010 dòng nhưng chỉ 4,850 `service_id` distinct),
`sh_medical_appointment_register_walkin.id` (trùng tới 5 brand), `m_res_company.id`.

**Hệ quả:** mọi join dùng `id` phải kèm điều kiện `brand_etl` khớp đúng, nếu không sẽ âm thầm lấy
nhầm dữ liệu chéo brand (không báo lỗi, chỉ ra kết quả sai/thiếu/fan-out).

**Cạm bẫy phụ:** cột `brand_etl` nằm TRÊN CHÍNH bảng cầu/rel (vd
`crm_line_sh_medical_appointment_register_walkin_rel`, `sh_walkin_service_rel`,
`crm_lead_product_category_rel`) có thể tự nó không đáng tin cậy để dùng làm điều kiện lọc — hoặc
NGƯỢC LẠI, có thể bị hiểu NHẦM là "không đáng tin" nếu test bằng 1 join khác THIẾU brand_etl ở
bước trước đó (id phía kia cũng trùng chéo brand → join thiếu brand_etl tạo ra kết quả chéo giả
trông giống brand_etl bảng rel bị sai). Cách xử lý an toàn: luôn dùng `brand_etl` của bảng **gốc,
đáng tin nhất trong chuỗi** (vd `sh_medical_appointment_register_walkin.brand_etl`, đã verify khớp
đúng `crm_lead.brand_etl` qua `booking_id`) làm mốc so sánh cho MỌI bảng join tiếp theo, thay vì
tin brand_etl của từng bảng rel riêng lẻ.

Ví dụ đo được: join `sh_walkin_service_rel → view_stag_products` theo `service_id` mà thiếu
`brand_etl` sẽ fan-out ~5 lần (586,402 dòng thay vì 121,780 dòng đúng).

## 2. `stag_payment_transfer` không phải 1-dòng-1-`clineid`

1 `clineid` có thể có nhiều dòng trong `stag_payment_transfer` (trả góp/nhiều đợt thanh toán —
xác nhận qua cột `rnk_clineid_pmdate` có sẵn trong bảng, cho thấy grain gốc là nhiều dòng/clineid).
Join thẳng không dedupe sẽ nhân bản dòng cline, làm sai mọi `ROW_NUMBER()`/`FIRST_VALUE()` tính
theo cline. Đo được ~17% cline trong scope bị nhân bản.

**Fix:** luôn `GROUP BY clineid, brand_etl` trước khi join, lấy `MIN(payment_date)` (ngày thanh
toán đầu) và `SUM(payment)` (tổng payment) — xem CTE `cline` trong
`stg_crm_line_ecosystem.sql`.

## 3. `ORDER BY` trên timestamp không có tie-break → kết quả không tái lập được

Nhiều dòng `crm_line` trong cùng 1 booking có `create_date` **giống hệt nhau tới mili-giây**
(insert cùng batch). `ROW_NUMBER()`/`FIRST_VALUE() OVER (... ORDER BY cline_created_date)` không
tiêu chí phụ sẽ cho kết quả khác nhau giữa các lần chạy (Postgres chọn ngẫu nhiên thứ tự trong
nhóm trùng giờ). Từng verify bằng cách chạy lại cùng 1 query 2 lần trên cùng dữ liệu và ra
`main_bl_customer` khác nhau cho cùng 1 khách hàng.

**Fix:** luôn thêm `cline_id` (hoặc id riêng của bảng) làm tiêu chí phụ cuối `ORDER BY`:
`ORDER BY cline_created_date, cline_id`.

## 4. `view_stag_products` có CẢ `service_id` lẫn `product_id` — 2 cột khác nhau

Không nhầm với bảng tên gần giống `stag_products` (43 cột, có `smhcsid`, KHÔNG có `service_id`).

- `crm_line.product_id` → nối `view_stag_products.product_id` (đúng).
- `sh_walkin_service_rel.service_id` → phải nối `view_stag_products.service_id`, KHÔNG PHẢI
  `product_id` (2 hệ id riêng biệt dù cùng nằm trên 1 dòng — vd `service_id=1094` có
  `product_id=1161` khác hẳn).

Join nhầm cột khiến rất nhiều `service_id` hợp lệ bị coi là "không map được sản phẩm" →
`main_bl_completed_date` NULL sai hàng loạt (độ phủ tăng từ ~42% lên ~76.5% sau khi sửa).

**Bài học chung:** trước khi join `*_id` vào bảng lạ, luôn đọc `information_schema.columns` thật
để xác nhận đúng tên cột đích, không suy đoán theo tên cột nguồn.

## 5. `crm_lead.code_booking` rỗng 100% — mã booking thật nằm ở `crm_lead.name`

Cột `code_booking` không được populate cho `brand_etl=1` (0/249,828 dòng có giá trị). Mã booking
dạng `BOOK-YYMMDD-NNNNN` (vd `BOOK-260325-00049`) thực chất nằm ở cột `crm_lead.name`.

## 6. custom_fields id=9794 — `value` trong JSON là `value_id`, không phải `custom_field_id`

`cs_deal_detail_api_v2.custom_fields` là JSON array `[{id, value}, ...]`. Với phần tử
`id=9794` ("Nhóm dịch vụ chính"), `value` là **`cs_custom_fields.value_id`** (một mã lựa chọn cụ
thể, vd `151797`), không phải `custom_field_id` (luôn là hằng số `'9794'` cho mọi lựa chọn của
field này). Join đúng: `ccf.value_id = (cf_elem->>'value') AND ccf.custom_field_id = '9794'`.

Phần lớn `value_lable` có định dạng `"[MÃ] Tên dịch vụ"` (cần bóc mã bằng
`SPLIT_PART(value_lable, ']', 2)`), nhưng có ngoại lệ không có dấu `]` (vd `"NHA KHOA"`) — phải
`CASE WHEN value_lable LIKE '%]%' THEN ... ELSE value_lable END`, nếu không sẽ mất dữ liệu (ra
chuỗi rỗng).

## 7. Map category → `his_service_type`: PHẢI join theo ID (`product_ctg_id`), không match theo text

Cách làm ban đầu (`stg_booking_nhom_dich_vu_chinh` bản đầu) map `nhom_dich_vu_chinh` (text đã
resolve, vd "PTTM MẮT") sang `his_service_type` bằng cách so `UPPER(TRIM(product_category))`
với `view_stag_products.product_category` — **sai hướng**: nhiều category hợp lệ (từ
`crm_lead_product_category_rel`/custom field 9794) không match được text nào trong
`view_stag_products` (dù category đó thực sự tồn tại trong hệ product), khiến `business_line`
ra `NULL` sai hàng loạt — đo được 12/52 category tier-1 (23%) "mất" business_line theo cách này,
dù đa số trong đó THẬT SỰ có tồn tại đúng category, chỉ là join sai kiểu.

**Nguyên nhân gốc (theo nghiệp vụ):** `crm_lead_product_category_rel.product_category_id` và mã
trong ngoặc vuông của custom field 9794 (vd `"KNP00001"`) đều **tham chiếu trực tiếp đến cùng hệ
`product_category`/`stag_products` bằng ID**, không phải bằng tên text:

- `crm_lead_product_category_rel.product_category_id` → join thẳng
  `stag_products_dbt.product_ctg_id` (hoặc `stag_products.product_ctg_id`, 2 bảng hiện đồng bộ
  dữ liệu) — khớp 1-1 chính xác (tên category ở 2 phía trùng khớp tuyệt đối trên mọi sample đã
  kiểm tra).
- Mã trong ngoặc vuông của custom field 9794 → khớp THẲNG `product_category.code` (kèm đúng
  `brand_etl` của lead — cột `code` cũng bị trùng chéo giữa các brand giống mọi bảng khác, xem
  mục 1) → `product_category.id` → `stag_products_dbt.product_ctg_id`. Đã verify **73/73 mã
  khớp 100%** trên dữ liệu thật.

**Fix:** luôn resolve `product_category_id` (có sẵn ở tier 1, tra qua `code` ở tier 2, có sẵn từ
`view_stag_products.product_ctg_id` ở tier 3) rồi join ID sang `stag_products_dbt` để lấy
`his_service_type` — không bao giờ so tên category giữa 2 hệ bảng khác nhau bằng text nếu có
đường ID trực tiếp. Sau khi sửa, 12 category "mất" business_line ở trên vẫn NULL — nhưng lần này
là NULL **đúng** (category đó thực sự không gắn sản phẩm nào trong catalog, không phải lỗi join)
— khác bản chất với NULL do join sai text.

**Lưu ý phụ:** `stag_products_dbt` (không phải `stag_products`) là bảng nên dùng cho các map
mới — bảng dbt-managed, cập nhật định kỳ; tại thời điểm viết, dữ liệu 2 bảng giống hệt nhau
(cùng row count, cùng `max(write_date)`) nhưng `_dbt` là hướng đi bền hơn về lâu dài.

**[Cập nhật 2026-08-05]** Cách join theo ID ở mục này đã **không còn dùng** trong
`stg_booking_nhom_dich_vu_chinh` — model đã đổi sang lấy trực tiếp `view_stag_products.product_group`
(xem mục 8 dưới), đơn giản hơn và khớp sandbox chính xác hơn. Bài học "join theo ID, không so
text" ở mục này vẫn đúng và áp dụng chung cho các model khác.

## 8. Đối chiếu với DB sandbox (`staging_sci`) — nguồn xác nhận nghiệp vụ đáng tin

Kho dữ liệu này có 1 DB "sandbox" riêng (`staging_sci`), có các view nghiệp vụ đã được xác nhận
đúng chuẩn, dùng làm nguồn đối chiếu khi nghi ngờ logic tự viết bị sai/trôi khỏi chuẩn nghiệp vụ.
Kết nối lưu ở `HciCode/connection/profiles_connections.yml` (không commit vào git — chứa
credentials). Không có `psql` CLI, dùng `psycopg2` (Python) để query trực tiếp khi cần đối chiếu
số liệu chéo 2 DB (không thể JOIN thẳng qua dblink/fdw giữa `new_product` và `staging_sci`).

**View đối chiếu đã dùng:** `view_stag_crm_lead_first_product_group` (sandbox) — nhóm dịch vụ
khách hàng quan tâm đầu tiên theo booking (`crm_id`), lấy `product_group` của cline có `cln.id`
**nhỏ nhất** (không phải `cline_created_date` sớm nhất) trong booking, qua
`view_stag_products.product_group` (CASE WHEN đã bake sẵn trong view, xem mục dưới).

**Phát hiện quan trọng:** `view_stag_products` (bảng nguồn `stag_products`) trên `new_product` và
`staging_sci` có **định nghĩa view giống hệt nhau 100%** (đã diff nguyên văn `information_schema.
views.view_definition`, không lệch 1 ký tự) — kể cả cột `product_group` (CASE WHEN 10 nhánh: SẢN
PHẨM/BEAUTY & SPA/PTTM HÀM MẶT/WELLNESS/BÉO ĐA CHUYÊN KHOA/PTTM MẮT/PTTM MŨI/CẤY MỠ/
PTTM NGỰC-MÔNG/DỊCH VỤ KHÁC). Số dòng theo từng `product_group` (trừ nhóm "SẢN PHẨM" — catalog sản
phẩm vật lý, đồng bộ chậm hơn/kém đầy đủ hơn nhiều giữa 2 DB) cũng khớp tuyệt đối. → nên **lấy
trực tiếp cột `product_group`** thay vì tự viết lại CASE WHEN riêng trong model dbt (tránh drift
theo thời gian, và đảm bảo khớp sandbox bằng thiết kế thay vì bằng maintenance thủ công).

**Đã áp dụng cho 2 model:**
- `stg_booking_nhom_dich_vu_chinh`: đổi từ 3 tầng ưu tiên (category_rel/custom field 9794/fallback
  cline) sang 1 nguồn duy nhất (cline có `cln.id` nhỏ nhất trong booking), lấy thẳng
  `view_stag_products.product_group`.
- `stg_dv_khach_hang_quan_tam`: bỏ CASE WHEN tự viết (9 nhóm tiền tố số `1.MẮT`...`9.WELLNESS`,
  có điều kiện phụ `category_source_code='MBS'`), lấy thẳng `sp.product_group` (nhãn đổi sang dạng
  sandbox: `PTTM MẮT`, `BEAUTY & SPA`... không tiền tố số, không còn điều kiện MBS).

**Đo mức khớp trên dữ liệu thật (tháng 7/2026, so doanh số theo nhóm giữa `new_product` và
sandbox):** trước khi sửa `stg_dv_khach_hang_quan_tam`, tổng doanh số khớp 99.9% nhưng lệch theo
từng nhóm (BÉO ĐA CHUYÊN KHOA +4.9%, DỊCH VỤ KHÁC −4.2%...) do 3 khác biệt logic: (1) sandbox có
riêng nhánh `product_category='SAN PHAM'→'SẢN PHẨM'`, bản cũ không có; (2) sandbox bắt buộc
`product_category ~* 'HÚT MỠ'` cho CẢ `weight_loss` lẫn `Surgery` mới vào nhóm BÉO ĐA CHUYÊN KHOA,
bản cũ cho `weight_loss` vào thẳng không cần match; (3) điều kiện `category_source_code='MBS'`
(theo nguồn khách) chỉ có ở bản cũ. Sau khi đổi sang lấy thẳng `product_group`: **DỊCH VỤ KHÁC và
WELLNESS khớp tuyệt đối 100%**, BÉO ĐA CHUYÊN KHOA cải thiện 104.9%→101.9%, các nhóm còn lại trong
khoảng 99.8–101.5%.

**Đào sâu phần chênh còn lại (đã xác định root cause chính xác, không phải tie-break):** so từng
`crm_id` 1-1 giữa `new_product` và sandbox (không chỉ so tổng theo nhóm) cho thấy **0 booking bị
lệch NHÓM** khi cả 2 bên cùng resolve được — 100% khớp tuyệt đối. Toàn bộ phần doanh số chênh trước
đó (~0.5% tổng, tháng 7/2026) đến từ **15 booking mà sandbox không trả về dòng nào** cho
`brand_etl=1`, do lỗi thiết kế trong chính view sandbox:

```sql
-- view_stag_crm_lead_first_product_group (sandbox)
SELECT DISTINCT ON (cl.id) cl.id AS crm_id, ...
FROM crm_line cln
    LEFT JOIN crm_lead cl ON cl.id = cln.crm_id AND cl.brand_etl = cln.brand_etl
    ...
ORDER BY cl.id, cln.id   -- KHÔNG partition theo brand_etl trước khi DISTINCT ON!
```

`cl.id` (số booking) **trùng chéo giữa nhiều `brand_etl`** (đúng gotcha mục 1) — vd `crm_id=2182579`
tồn tại đồng thời ở `brand_etl=1` (Kangnam thật) và `brand_etl=3` (thương hiệu khác, trùng số ID).
`DISTINCT ON (cl.id) ... ORDER BY cln.id` chọn dòng có `cln.id` **nhỏ nhất trên toàn bộ mọi brand**,
không tách riêng brand trước → có thể chọn nhầm cline của brand khác nếu `cln.id` của nó tình cờ
nhỏ hơn (đã verify: brand 3 tạo **sau** brand 1 nhưng `cln.id` lại **nhỏ hơn** — 2 hệ ID theo brand
không đồng bộ tuyến tính với nhau). Khi lọc `WHERE brand_etl=1` ở downstream, dòng bị chọn nhầm
(brand khác) bị loại → nhìn như "sandbox không có dữ liệu", thực ra có nhưng gán nhầm brand.

**Kết luận:** `stg_booking_nhom_dich_vu_chinh`/`stg_dv_khach_hang_quan_tam` (lọc `WHERE
cln.brand_etl = 1` **trước** `DISTINCT ON`/`ROW_NUMBER()`) làm đúng hơn view sandbox ở điểm này —
không cần sửa gì thêm bên model dbt. Đây là bài học chung: `DISTINCT ON`/`ROW_NUMBER()
PARTITION BY` trên 1 cột ID có khả năng trùng chéo brand **luôn phải kèm điều kiện brand trong
chính partition/filter đó**, không được lọc brand sau khi đã chọn "dòng đầu tiên" — thứ tự làm sai
(chọn trước, lọc brand sau) sẽ cho kết quả sai âm thầm giống hệt case này.

**Bonus fix phát hiện trong lúc đối chiếu:** `stg_dv_khach_hang_quan_tam`'s CTE `cline_rank` thiếu
tie-break `cline_id` (chỉ `ORDER BY cline_created_date`) — đúng gotcha mục 3 ở trên. Khi test lần
đầu (chưa fix tie-break) kết quả doanh số theo nhóm dao động thất thường giữa các lần chạy song
song với việc đổi sang `product_group` — tưởng nhầm là do logic `product_group` sai, thực ra là do
kết quả tự nó không ổn định. Luôn thêm tie-break trước khi bắt đầu so sánh/debug số liệu, nếu
không sẽ nhầm lẫn giữa "logic sai" và "kết quả không tái lập được".

**Coverage gap `new_product` vs `staging_sci` cho `crm_lead` (brand_etl=1) theo tháng, đo 2026:**
tháng 1–5/2026 chỉ đạt 19.6%–49.2% (dữ liệu backlog/cũ đồng bộ thiếu), nhưng **tháng 6/2026 trở đi
đạt đúng 100%** (có vẻ đã có 1 đợt đồng bộ bù đầu tháng 6). Khi cần dùng `new_product` cho báo cáo
dữ liệu gần đây (từ tháng 6/2026 trở đi), coverage đáng tin cậy; dữ liệu lịch sử xa hơn (đầu 2026
trở về trước) cần thận trọng, có thể thiếu đáng kể.

## 9. `sh_walkin_service_rel` có dòng "orphan" — đã xóa ở nguồn nhưng ETL không dọn ở target

**[2026-08-28]** Phát hiện qua case thật: `crm_id=2363791`/`cline_id=4277370` (`crm_line.stage =
'new'`, chưa đi khám) vẫn bị gán `cline_walkin_finish_date` sai trong `stg_crm_line_ecosystem.sql`.

**Root cause:** pipeline ETL nạp `sh_walkin_service_rel` từ ERP (`data_ops/app/call_functions/
direct_postgres_ingestion.py`, DAG `call_functions_erp_direct_dag`) dùng cơ chế UPSERT theo PK:
mỗi lần chạy chỉ `DELETE` + `INSERT` lại đúng những dòng khớp trong batch đồng bộ hiện tại (dựa
trên filter incremental phía nguồn). **Không có bước nào xóa dòng đã biến mất hẳn khỏi nguồn** —
nếu 1 dòng `(walkin_id, service_id)` từng tồn tại ở ERP rồi bị sửa/xóa sau đó, dòng cũ kẹt lại
**vĩnh viễn** ở target, không bao giờ được touch lại.

**Cách nhận diện dòng orphan:** pipeline luôn ghi `snapshot_date`/`ingestion_timestamp`/
`source_server` cùng lúc cho mọi dòng nó chèn/đè (xem code, không có nhánh nào cố tình để trống)
→ dòng nào có **3 cột này NULL** chắc chắn chưa từng được pipeline ghi/đè kể từ khi 3 cột metadata
tồn tại, tức nhiều khả năng là orphan.

**Đã verify 100% bằng data thật:** đối chiếu toàn bộ 75 dòng NULL trong `sh_walkin_service_rel` ở
sandbox (`staging_sci`, tổng 171,631 dòng) với DB `new_product` (nguồn "gần ERP" hơn, cùng cấu
trúc bảng) — **cả 75/75 dòng đều không còn tồn tại** ở `new_product`. Case cụ thể: walkin_id
`699905` (phiếu `PK-2026-116196`) ở sandbox có 2 dòng service (`23025` NULL metadata, `27248` có
metadata mới); ở `new_product` chỉ còn đúng 1 dòng — `27248`. `service_id=23025` không tồn tại ở
nguồn nữa nhưng vẫn kẹt lại ở sandbox, trùng ngẫu nhiên với `service_id` sản phẩm của cline
`4277370` trong cùng booking → gây gắn sai `has_completed_walkin`/`cline_walkin_finish_date`.

**Fix áp dụng (2026-08-28):** thêm điều kiện `wsr.snapshot_date IS NOT NULL` khi join
`sh_walkin_service_rel` ở **cả 2 chỗ** dùng trong `stg_crm_line_ecosystem.sql` (CTE
`service_walkin_completed` và `main_bl_walkin_ranked`) và ở procedure `func_stag_crm_line_ecosystem()`
(bước 1.5 và bước 7) — xem `LOGIC.md` mục 3 và `func_stag_crm_line_ecosystem.md`.

**Lưu ý:** đây là fix ở tầng lọc dữ liệu bẩn (phòng vệ), **không phải fix root cause** — root cause
thật nằm ở pipeline `data_ops` thiếu cơ chế dọn dẹp dòng đã mất ở nguồn (chưa xử lý, ngoài phạm vi
`data_serving`). Dòng orphan mới phát sinh sau này (nếu ETL không được sửa) sẽ tiếp tục tích lũy và
tiếp tục được lọc đúng bởi điều kiện `snapshot_date IS NOT NULL` này, miễn pipeline vẫn giữ cách
ghi metadata như hiện tại.

**Phạm vi áp dụng:** filter này chỉ nên đặt trên `sh_walkin_service_rel` — **không** áp dụng tương
tự cho bảng cha `sh_medical_appointment_register_walkin`: bảng đó có tỷ lệ NULL `snapshot_date` rất
cao (~82%, do phần lớn dữ liệu lịch sử cũ không được touch lại gần đây, không phải orphan) — lọc
theo `snapshot_date` ở bảng này sẽ loại nhầm phần lớn walkin hợp lệ.
