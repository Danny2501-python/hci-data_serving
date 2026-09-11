# Logic: erp_staging/products

Chuyển logic tạo bảng `stag_products` (đang chạy Python/pandas trong Airflow DAG
`quentk_1_stag_crm_New_sys.py`, hàm `get_data_product()` + `write_stag_products()`)
sang dbt. Output: `mart_stag_products`, alias vật lý `stag_products_dbt` (xem
mục "Cutover" bên dưới — **chưa** ghi đè bảng `stag_products` thật).

Đối chiếu ngày build: khớp **tuyệt đối 100%** với `stag_products` (21.224 dòng,
36 cột) tại thời điểm build — xem `knowledge.md` để biết cách đối chiếu và các
lỗi/khác biệt ngữ nghĩa Python-vs-SQL đã tìm ra trong quá trình này.

---

## Bài toán gốc

`get_data_product()` gộp danh mục dịch vụ/sản phẩm của 4 thương hiệu
(kn=brand_etl 1, pr=3, hh=4, sci=7) thành **1 bảng chuẩn hoá**, trong đó mỗi
`default_code` (mã SKU) được map sang 1 bộ `{kn,pr,hh,sci}_product_id` — vì
mỗi thương hiệu có database ERP riêng, cùng 1 sản phẩm có `product_id` khác
nhau ở mỗi brand.

## Cấu trúc model

```
stg/   7 model pass-through 1:1 các bảng ERP nguồn (product_product, product_template,
       product_category, uom_uom, sh_medical_health_center_service(_category),
       import_product_service_analyst) — KHÔNG lọc snapshot_date, xem knowledge.md #1.
int/
  int_stps_base          ← tương đương query_pd, quét cả 4 brand trong 1 lượt
                            (thay vì chạy lại query 4 lần đổi brand_etl)
  int_stps_flags         ← cvl_unique/cvl_iunique/cpname, is_no_kpi, điền kpi_point
                            còn thiếu từ product_id_kn, gr_bh_id (nhóm bảo hành)
  int_stps_product_map   ← dfmap1..dfmap4 + map_productid(): gộp id sản phẩm
                            qua 4 brand theo default_code
mart/
  stag_products           ← SELECT cuối, ép kiểu + đặt tên cột khớp bảng thật,
                             alias 'stag_products_dbt'
```

## dfmap1..dfmap4 — vì sao phải tách 4 nhánh

Không phải `default_code` nào cũng map 1-1 sạch sẽ qua 4 brand. Code gốc định
nghĩa 2 danh sách "đặc thù" (`is_difn`): 7 `product_id` cứng + ~84 `default_code`
cứng (thẻ liệu trình, mã VT/TH/EHC lặp) — các SKU này có lịch sử data lộn xộn
(nhiều `product` khác tên dùng chung `default_code`, hoặc method mapping tự
động không đáng tin) nên phải xử lý thủ công riêng.

| Nhánh | Điều kiện | Cách gán id |
|---|---|---|
| `dfmap1` | đặc thù + brand kn | `kn_product_id` = chính `product_id` của dòng |
| `dfmap2` | đặc thù + không phải kn + `cvl_unique<3` (default_code không lẫn quá nhiều tên sản phẩm) + `cvl_iunique<>1` | `map_productid(['pr','hh','sci'])` — gộp qua default_code |
| `dfmap3` | đặc thù + không phải kn + trùng lặp cao (`cvl_unique>=3` hoặc `cvl_iunique=1`) | mỗi brand giữ `product_id` của chính mình, **không** gộp — đây là lý do 1 `default_code` có thể ra nhiều dòng trong bảng kết quả |
| `dfmap4` | còn lại (không đặc thù) | `map_productid(['kn','pr','hh','sci'])` — nhánh phổ biến nhất |

`map_productid(df, lsbr)`, với mỗi brand `b` trong `lsbr`:
```
broadcast = MAX(product_id) trong cùng default_code, chỉ tính dòng có br = b
fallback  = product_id của chính dòng, NẾU product_id <= 31842 (id "cũ" dùng
            chung trước khi tách hệ thống 01/08/2025) HOẶC dòng đó chính là br=b
{b}_product_id = COALESCE(broadcast, fallback)
```
Sau đó dedup theo **toàn bộ tổ hợp** các cột `{b}_product_id` vừa tính (giữ
dòng đầu theo thứ tự `default_code, brand_etl`).

Cuối cùng: `product_id` (cột output, không phải cột gốc) = `kn_product_id` —
tức **id chính thức/canonical của cả bảng luôn là id bên KangNam**. Dòng nào
không xác định được `kn_product_id` (toàn bộ `dfmap2`/`dfmap3`, vì 2 nhánh này
không tính brand kn) sẽ có `product_id = NULL` — có ý nghĩa, không phải bug.

## group_id, product_id_kn — kiểu dữ liệu

Bảng `stag_products` thật lưu `group_id` và `product_id_kn` dạng
**character varying** dù nội dung là số/chuỗi số phẩy — vì dữ liệu đi qua
`df.to_csv()` rồi `COPY` chứ không có validate kiểu chặt. Model giữ đúng kiểu
`text` cho 2 cột này để khớp hợp đồng (contract) hiện tại của bảng, dù về logic
chúng là số.

## mart/view_stag_products.sql — port view thủ công `public.view_stag_products`

Sau khi `mart/stag_products.sql` đã cutover (alias hiện tại = `stag_products` thật,
xem mục Cutover bên dưới — comment trong file đó còn nhắc `stag_products_dbt` là
**lỗi thời**, chưa cập nhật lại), thêm model `mart/view_stag_products.sql`
(`materialized='view'`, alias `view_stag_products`) port 1:1 view Postgres thủ công
cùng tên đang chạy thật trong DB `new_product` (không do dbt quản lý, DDL gốc do
anh yêu paste trực tiếp, không lưu ở đâu khác trong repo trước đây).

- `ref('stag_products')` (không phải `source()`) → dbt tự xếp model này chạy
  **sau** khi bảng `stag_products` build xong, đúng yêu cầu ban đầu.
- UNION ALL 5 nhánh theo `brand_etl` (0=sci, 1=kn, 3=pr, 4=hh, 8=thv) — **khác**
  bảng mapping brand_etl ở phần "Bài toán gốc" phía trên (kn=1, pr=3, hh=4, sci=7)
  vì đó là brand_etl của **bảng ERP nguồn** (`product_product`...), còn đây là
  brand_etl **output của view**, tự đánh số theo view gốc — giữ nguyên, không sửa.
- Cố ý giữ `service_id`/`product_ctg_id` lấy từ cột chung (`smhcsid`,
  `product_ctg_id`) cho **mọi** nhánh, kể cả nhánh pr/hh/thv — dù bảng
  `stag_products` có sẵn cột theo từng brand (`pr_smhcsid`, `pr_product_ctg_id`...)
  — đúng y hệt view gốc, không "sửa" dù nhìn có vẻ thiếu nhất quán.
- 2 join `product_template`/`product_category` dùng `ref('stg_stps_product_template')`
  / `ref('stg_stps_product_category')` (đã có sẵn, ephemeral) thay vì `source()` trực
  tiếp — không đổi logic, chỉ theo đúng convention layer `stg` của model group này.
- Đã `dbt compile --select view_stag_products` thành công (2026-08-11) — resolve
  ref/join đúng. **Chưa** `dbt run` (chưa tạo view thật trong DB) — cần xác nhận
  trước vì đây là thay đổi schema DB production.

## product_group — CASE phân loại nhóm dịch vụ (sửa 2026-09-10)

Cột `product_group` (SELECT cuối `view_stag_products.sql`) là CASE WHEN theo
thứ tự ưu tiên, dùng để phân loại mọi sản phẩm/dịch vụ vào 9 nhóm nghiệp vụ.
Đây là chỗ nhiều report khác (vd `func_report_marketing_ad_cost_kn` — cột
`nhom_dv_KH_quan_tam`, xem README.md model đó mục #22) join gián tiếp qua
`stg_dv_khach_hang_quan_tam` để suy ra "dịch vụ khách quan tâm/đã đặt".

**Bug đã phát hiện + sửa (2026-09-10):** nhánh `BÉO ĐA CHUYÊN KHOA` bản gốc
chỉ khớp `his_service_type IN ('weight_loss','Surgery') AND product_category
~* 'HÚT MỠ'` — quá hẹp, chỉ bắt đúng case hút mỡ phẫu thuật. Đối chiếu trực
tiếp trên `sh_medical_health_center_service` (DB `new_product`):

| `his_service_type` | Tổng | Ghi chú |
|---|---|---|
| `weight_loss` | 176 | 96 "Giảm béo Dịch vụ lẻ" + 24 "Giảm Béo Trẻ Em (MetaKid)" + 22 "Giảm Béo Người Lớn (Metacore)" + ~34 nhóm phụ khác — **KHÔNG** dòng nào chứa chữ "HÚT MỠ" trong `product_category` |
| `Laser`/`Spa`, category = `'GIẢM BÉO KHÔNG PT'` | 40 (25 Laser + 15 Spa) | Giảm béo không phẫu thuật — `his_service_type` không phải `weight_loss`/`Surgery` |

→ **80% dòng `weight_loss`** (142/176, gồm cả MetaKid — dịch vụ đứng sau
campaign marketing "Metakids"/tên chiến dịch chứa "beokid") bị lọt qua nhánh
này, rơi vào `ELSE 'DỊCH VỤ KHÁC'` — không phải hành vi cố ý.

**Fix:** nới điều kiện thành `his_service_type = 'weight_loss' OR
(his_service_type = 'Surgery' AND product_category ~* 'HÚT MỠ') OR
(product_category = 'GIẢM BÉO KHÔNG PT')`.

**Bẫy thứ 2 khi thêm điều kiện `GIẢM BÉO KHÔNG PT` (đã sửa cùng lúc):**
`CASE WHEN` khớp nhánh đầu tiên thoả rồi dừng — 40 dòng `GIẢM BÉO KHÔNG PT`
đều có `his_service_type IN ('Laser','Spa')`, nên nếu nhánh `BÉO ĐA CHUYÊN
KHOA` đứng **sau** nhánh `BEAUTY & SPA` (`his_service_type IN ('Spa','Laser',
'Card')`) như thứ tự gốc, toàn bộ 40 dòng này luôn bị nhánh `BEAUTY & SPA`
bắt trước — điều kiện `GIẢM BÉO KHÔNG PT` không bao giờ được xét tới (dead
code). **Đã sửa bằng cách đưa nhánh `BÉO ĐA CHUYÊN KHOA` lên TRƯỚC nhánh
`BEAUTY & SPA`** trong CASE (xem comment trong file). Bài học tổng quát về
bẫy thứ tự `CASE WHEN` xem `knowledge.md` mục 9.

## Cutover — kế hoạch chuyển từ Python sang dbt

Model hiện tại build ra bảng riêng `stag_products_dbt` (không đụng
`stag_products` thật) qua `{{ config(alias='stag_products_dbt') }}` trong
`mart/stag_products.sql`. Để "chốt" (cutover):

1. Xoá task Airflow `task_2_stag_products` (`write_stag_products`) khỏi DAG
   `quentk_1_stag_crm_New_sys.py`.
2. Bỏ dòng `config(alias=...)` trong `mart/stag_products.sql` để dbt build
   thẳng ra bảng `stag_products` (cần đảm bảo quyền DROP/CREATE trên bảng đó).
3. Chạy đối chiếu lại đúng quy trình ở `knowledge.md` **ngay trước** bước 2,
   vì dữ liệu ERP là live — kết quả đối chiếu cũ có thể lệch nếu cách xa thời
   điểm cutover quá lâu.
4. Theo dõi các model/report đang `source()` trực tiếp `stag_products` (xem
   `sources_common.yml`, `report_tong_quan_ds_kn/stg`, `report_vong_doi_kh_kn/stg`...)
   sau khi cutover — không đổi tên bảng nên các model này không cần sửa gì.
