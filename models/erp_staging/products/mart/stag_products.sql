{{ config(alias='stag_products_dbt') }}

-- Tương đương write_stag_products() trong quentk_1_stag_crm_New_sys_v2.py.
-- Alias 'stag_products_dbt' để không ghi đè bảng stag_products đang chạy Python cho tới khi được đối chiếu/duyệt.
-- v2: pr/hh/thv/sci_{product_tmpl_id,product_ctg_id,smhcsid} giờ tính thẳng trong int_stps_product_map
-- (cùng lúc với {br}_product_id, theo đúng logic dfmap1(dfo)/dfmap2(dfmerge_code)/dfmap3 mới), không cần
-- join ngược lại int_stps_flags theo {br}_product_id như bản v1 nữa.
with combined as (
    select * from {{ ref('int_stps_product_map') }}
)

select
    combined.smhcsid,
    combined.product_id,
    -- NULLIF(..,'') trên mọi cột varchar: bảng gốc do Python nạp qua df.to_csv() -> COPY ... CSV,
    -- và COPY CSV mặc định coi field rỗng KHÔNG quote là NULL (không phải chuỗi rỗng ''). TRIM()/regex
    -- ở đây có thể ra '' hợp lệ về SQL nhưng khác với dữ liệu gốc nếu không bù lại. Xem knowledge.md.
    nullif(combined.his_service_type, '') as his_service_type,
    nullif(combined.surgery_type, '') as surgery_type,
    nullif(combined.product_category, '') as product_category,
    nullif(combined.product_category_paris, '') as product_category_paris,
    nullif(combined.product_category_new, '') as product_category_new,
    nullif(combined.default_code, '') as default_code,
    nullif(combined.product, '') as product,
    combined.list_price,
    nullif(combined.group_id::text, '') as group_id,
    combined.kpi_point,
    combined.kpi_point_num,
    nullif(combined.product_id_kn, '') as product_id_kn,
    combined.product_ctg_id,
    combined.is_main_service,
    combined.uom_id,
    nullif(combined.uom, '') as uom,
    combined.is_no_kpi,
    combined.kdtc_product_ctg_id,
    combined.create_date,
    combined.write_date,
    combined.is_vip,
    combined.kpi_first_time,
    combined.gr_bh_id,
    combined.qty_service,
    combined.pr_product_id,
    combined.hh_product_id,
    combined.sci_product_id,
    combined.thv_product_id,
    combined.product_tmpl_id,
    combined.pr_product_tmpl_id,
    combined.hh_product_tmpl_id,
    combined.sci_product_tmpl_id,
    combined.thv_product_tmpl_id,
    combined.pr_product_ctg_id,
    combined.hh_product_ctg_id,
    combined.sci_product_ctg_id,
    combined.thv_product_ctg_id,
    combined.pr_smhcsid,
    combined.hh_smhcsid,
    combined.sci_smhcsid,
    combined.thv_smhcsid
from combined
