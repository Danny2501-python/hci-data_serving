{{ config(alias='stag_products') }}

-- Tương đương write_stag_products() trong quentk_1_stag_crm_New_sys_v2.py.
-- Alias 'stag_products_dbt' để không ghi đè bảng stag_products đang chạy Python cho tới khi được đối chiếu/duyệt.
-- v2: pr/hh/thv/sci_{product_tmpl_id,product_ctg_id,smhcsid} giờ tính thẳng trong int_stps_product_map
-- (cùng lúc với {br}_product_id, theo đúng logic dfmap1(dfo)/dfmap2(dfmerge_code)/dfmap3 mới), không cần
-- join ngược lại int_stps_flags theo {br}_product_id như bản v1 nữa.
with combined as (
    select * from {{ ref('int_stps_product_map') }}
),

-- Backfill thủ công (xem seeds/seeds.yml: stag_product_backfill_sandbox) cho ~9.209 sản phẩm brand EHC
-- bị int_stps_product_map loại khỏi output trên target new_product vì thiếu dòng brand_etl=1 (kn) tương
-- ứng trong public.product_product của new_product (gap đồng bộ ERP, xem knowledge.md). Anti-join theo
-- product_id: một khi new_product được đồng bộ đủ, dòng thật từ combined sẽ tự thắng, dòng backfill này
-- tự động không còn được chọn -> không sợ trùng/đè dữ liệu thật.
backfill as (
    select b.*
    from {{ ref('stag_product_backfill_sandbox') }} b
    where b.product_id not in (
        select product_id from combined where product_id is not null
    )
),

unioned as (
    -- group_id::text: combined.group_id là integer (xem int_stps_base.sql: pimp.group_id::int), còn
    -- backfill.group_id đã là varchar (seed) -> ép kiểu cho khớp trước khi union all.
    select
        smhcsid, product_id, his_service_type, surgery_type, product_category,
        product_category_paris, product_category_new, default_code, product,
        list_price, group_id::text as group_id, kpi_point, kpi_point_num, product_id_kn,
        product_ctg_id, is_main_service, uom_id, uom, is_no_kpi, kdtc_product_ctg_id,
        create_date, write_date, is_vip, kpi_first_time, gr_bh_id, qty_service,
        pr_product_id, hh_product_id, sci_product_id, thv_product_id,
        product_tmpl_id, pr_product_tmpl_id, hh_product_tmpl_id, sci_product_tmpl_id, thv_product_tmpl_id,
        pr_product_ctg_id, hh_product_ctg_id, sci_product_ctg_id, thv_product_ctg_id,
        pr_smhcsid, hh_smhcsid, sci_smhcsid, thv_smhcsid,
        da_product_id, da_product_tmpl_id, da_product_ctg_id, da_smhcsid
    from combined
    union all
    select
        smhcsid, product_id, his_service_type, surgery_type, product_category,
        product_category_paris, product_category_new, default_code, product,
        list_price, group_id, kpi_point, kpi_point_num, product_id_kn,
        product_ctg_id, is_main_service, uom_id, uom, is_no_kpi, kdtc_product_ctg_id,
        create_date, write_date, is_vip, kpi_first_time, gr_bh_id, qty_service,
        pr_product_id, hh_product_id, sci_product_id, thv_product_id,
        product_tmpl_id, pr_product_tmpl_id, hh_product_tmpl_id, sci_product_tmpl_id, thv_product_tmpl_id,
        pr_product_ctg_id, hh_product_ctg_id, sci_product_ctg_id, thv_product_ctg_id,
        pr_smhcsid, hh_smhcsid, sci_smhcsid, thv_smhcsid,
        -- Seed backfill không có cột Đông Á (brand_etl=2, thêm 2026-10-14).
        cast(null as int) as da_product_id, cast(null as int) as da_product_tmpl_id,
        cast(null as int) as da_product_ctg_id, cast(null as int) as da_smhcsid
    from backfill
)

select
    unioned.smhcsid,
    unioned.product_id,
    -- NULLIF(..,'') trên mọi cột varchar: bảng gốc do Python nạp qua df.to_csv() -> COPY ... CSV,
    -- và COPY CSV mặc định coi field rỗng KHÔNG quote là NULL (không phải chuỗi rỗng ''). TRIM()/regex
    -- ở đây có thể ra '' hợp lệ về SQL nhưng khác với dữ liệu gốc nếu không bù lại. Xem knowledge.md.
    -- Áp dụng luôn cho nhánh backfill (vô hại, đã sạch từ seed) để giữ 1 logic chung cho cả 2 nguồn.
    nullif(unioned.his_service_type, '') as his_service_type,
    nullif(unioned.surgery_type, '') as surgery_type,
    nullif(unioned.product_category, '') as product_category,
    nullif(unioned.product_category_paris, '') as product_category_paris,
    nullif(unioned.product_category_new, '') as product_category_new,
    nullif(unioned.default_code, '') as default_code,
    nullif(unioned.product, '') as product,
    unioned.list_price,
    nullif(unioned.group_id, '') as group_id,
    unioned.kpi_point,
    unioned.kpi_point_num,
    nullif(unioned.product_id_kn, '') as product_id_kn,
    unioned.product_ctg_id,
    unioned.is_main_service,
    unioned.uom_id,
    nullif(unioned.uom, '') as uom,
    unioned.is_no_kpi,
    unioned.kdtc_product_ctg_id,
    unioned.create_date,
    unioned.write_date,
    unioned.is_vip,
    unioned.kpi_first_time,
    unioned.gr_bh_id,
    unioned.qty_service,
    unioned.pr_product_id,
    unioned.hh_product_id,
    unioned.sci_product_id,
    unioned.thv_product_id,
    unioned.product_tmpl_id,
    unioned.pr_product_tmpl_id,
    unioned.hh_product_tmpl_id,
    unioned.sci_product_tmpl_id,
    unioned.thv_product_tmpl_id,
    unioned.pr_product_ctg_id,
    unioned.hh_product_ctg_id,
    unioned.sci_product_ctg_id,
    unioned.thv_product_ctg_id,
    unioned.pr_smhcsid,
    unioned.hh_smhcsid,
    unioned.sci_smhcsid,
    unioned.thv_smhcsid,
    unioned.da_product_id,
    unioned.da_product_tmpl_id,
    unioned.da_product_ctg_id,
    unioned.da_smhcsid
from unioned
