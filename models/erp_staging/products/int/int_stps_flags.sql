-- Tương đương phần đầu get_data_product(): cvl_unique/cvl_iunique/cpname, is_no_kpi,
-- điền kpi_point còn thiếu từ product_id_kn (chuỗi id cách nhau dấu phẩy), và gr_bh_id (nhóm bảo hành).
with base as (
    select * from {{ ref('int_stps_base') }}
),

-- Postgres không hỗ trợ COUNT(DISTINCT ..) OVER(..), nên tính riêng qua GROUP BY rồi join lại
cvl_unique_agg as (
    select default_code, count(distinct product) as cvl_unique
    from base
    group by default_code
),
-- v2: cvl_iunique đổi nghĩa từ "số tên product khác nhau trong (default_code, product_id)"
-- sang "số product_id khác nhau trong (default_code, br)" -- tức độ ổn định của default_code
-- TRONG PHẠM VI 1 THƯƠNG HIỆU (br), dùng làm điều kiện có nên tự động gộp qua default_code hay không.
cvl_iunique_agg as (
    select default_code, br, count(distinct product_id) as cvl_iunique
    from base
    group by default_code, br
),

flagged as (
    select
        base.*,
        cvl_unique_agg.cvl_unique,
        cvl_iunique_agg.cvl_iunique,
        count(*) over (partition by base.default_code, base.product) as cpname,
        case when base.product_id in (
            10801, 8207, 8194, 10252, 10254, 10255, 10716, 16836, 17097,
            20306, 20881, 20890, 20090, 20290, 20279, 20280, 20282
        ) then true end as is_no_kpi
    from base
    left join cvl_unique_agg on cvl_unique_agg.default_code = base.default_code
    left join cvl_iunique_agg
        on cvl_iunique_agg.default_code = base.default_code
        and cvl_iunique_agg.br = base.br
),

-- Sản phẩm chưa có kpi_point riêng nhưng có product_id_kn (map sang 1 hoặc nhiều id Kangnam)
fkpi_source as (
    select distinct on (product_id)
        product_id, product_id_kn
    from flagged
    where kpi_point is null
        and product_id is not null
        and coalesce(nullif(trim(product_id_kn), ''), '0') not in ('0', '0.0')
    order by product_id, default_code, brand_etl
),

-- Điểm kpi_point của từng product_id (lấy dòng đầu tiên theo default_code/brand_etl nếu trùng id)
kpi_lookup as (
    select distinct on (product_id)
        product_id, kpi_point
    from flagged
    where product_id is not null
    order by product_id, default_code, brand_etl
),

fkpi_exploded as (
    select
        s.product_id,
        nullif(trim(regexp_replace(pid_kn_txt, '\.0', '', 'g')), '')::int as product_id_kn_single
    from fkpi_source s
    cross join lateral unnest(string_to_array(s.product_id_kn, ',')) as pid_kn_txt
),

kpi_fill as (
    -- COALESCE(SUM(..),0): pandas Series.sum() trên nhóm toàn NaN trả về 0.0 (không phải NaN như Postgres
    -- SUM() trên nhóm toàn NULL) -- xảy ra khi product_id_kn trỏ tới 1 product_id không tồn tại/không tìm thấy.
    select
        e.product_id,
        coalesce(sum(kl.kpi_point), 0) as kpi_point_filled
    from fkpi_exploded e
    left join kpi_lookup kl on kl.product_id = e.product_id_kn_single
    group by e.product_id
),

with_kpi as (
    select
        flagged.*,
        case
            when coalesce(flagged.kpi_point, 0) = 0 then kpi_fill.kpi_point_filled
            else flagged.kpi_point
        end as kpi_point_filled
    from flagged
    left join kpi_fill on kpi_fill.product_id = flagged.product_id
)

select
    smhcsid, his_service_type, surgery_type, product_ctg_id, kpi_first_time,
    product_category, product_category_paris, product_category_new,
    product_id, default_code, product, list_price, product_tmpl_id,
    is_main_service, group_id, product_id_kn, is_vip, qty_service,
    kpi_point_filled as kpi_point,
    kpi_point_num, uom_id, uom, create_date, write_date, kdtc_product_ctg_id,
    brand_etl, br, cvl_unique, cvl_iunique, cpname, is_no_kpi,
    -- Gắn id nhóm Bảo hành DV laser-Spa theo cơ chế Doanh thu (ưu tiên theo thứ tự các nhóm dưới đây).
    -- Regex chạy trên split_part(product, chr(10), 1) (chỉ dòng đầu) chứ không phải product gốc:
    -- bản Python dùng product.str.match('.*(...).*') (re.match, KHÔNG có DOTALL) -> '.' không khớp '\n',
    -- nên nếu product có xuống dòng, phần match chỉ "nhìn thấy" được đến hết dòng đầu tiên. Postgres ~*
    -- không có giới hạn này nên phải mô phỏng thủ công, nếu không sẽ match được cả phần sau '\n' mà bản
    -- gốc bỏ sót (case thực tế: product_id=10506 "Phun xăm...\n(CB+NC+CS)...điêu khắc" -> gr_bh_id phải
    -- là NULL vì "điêu khắc" nằm sau dấu xuống dòng, không phải 4).
    coalesce(
        case when product_ctg_id in (411, 454, 1334, 1336, 1394)
            or split_part(product, chr(10), 1) ~* '(tàn nhang| nám |ban vàng| chàm |u tuyến bã|trị.*đồi mồi|bớt (sùi)?)' then 2 end,
        case when product_ctg_id in (419, 466, 1345, 1396)
            or split_part(product, chr(10), 1) ~* '(mụn (thịt|cơm)|tẩy nốt ruồi)' then 3 end,
        case when product_ctg_id in (424, 425, 475, 485, 1344, 1361, 426, 1302, 1351)
            or split_part(product, chr(10), 1) ~* '(xóa (hình )?xăm|phun (môi|mày|mí|thêu)|điêu khắc|hair stro)' then 4 end,
        case when product_ctg_id in (428, 484, 1350)
            or split_part(product, chr(10), 1) ~* '(triệt (lông|râu|ria))' then 5 end,
        case when split_part(product, chr(10), 1) ~* '(botox|botul|(nhăn|mặt).*aller)' then 6 end,
        case when his_service_type in ('Laser', 'Spa') then 1 end
    ) as gr_bh_id
from with_kpi
