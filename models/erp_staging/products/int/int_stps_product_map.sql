-- Tương đương phần sau get_data_product() trong quentk_1_stag_crm_New_sys_v2.py: 3 nhánh dfmap1(dfo)/dfmap2(dfmerge_code)/dfmap3
-- (thay cho 4 nhánh dfmap1..dfmap4 + map_productid() ở bản v1 -- xem git history) gộp id sản phẩm
-- (product_id, product_ctg_id, product_tmpl_id, smhcsid) qua 5 brand (kn/pr/hh/thv/sci) theo default_code.
-- map_productid() vẫn còn định nghĩa trong file Python v2 nhưng KHÔNG còn được gọi ở đâu (dead code, không dịch).
with base as (
    select
        *,
        coalesce(
            product_id in (13083, 13077, 13096, 13106, 25446, 30368, 30369)
            or default_code in (
                'TH001002', 'TH001004', 'VT003539', 'VT003758', 'VT003769', 'VT003770',
                'EHC-NSTHTNT0025', 'EHC-NSTHTNT0033', 'EHC-NSTHTNT0038',
                'TH001005', 'TH001006', 'TH001007', 'TH001008', 'TH001009', 'TH001010', 'TH001011',
                'TH001012', 'TH001013', 'TH001014', 'TH001015', 'TH001016', 'TH001017', 'TH001018',
                'TH001019', 'TH001020', 'TH001021',
                'VT003761', 'VT003762', 'VT003763', 'VT003764', 'VT003765', 'VT003766',
                'VT003832', 'VT003833', 'VT003834', 'VT003835', 'VT003836', 'VT003837', 'VT003838',
                'VT003839', 'VT003840', 'VT003841', 'VT003842', 'VT003843', 'VT003844', 'VT003845',
                'VT003846', 'VT003847', 'VT003848', 'VT003849', 'VT003850', 'VT003851', 'VT003852',
                'VT003853', 'VT003854', 'VT003855', 'VT003856', 'VT003857', 'VT003858', 'VT003859',
                'VT003860', 'VT003861', 'VT003862', 'VT003863', 'VT003864', 'VT003865', 'VT003866',
                'VT003867', 'VT003868', 'VT003869', 'VT003870', 'VT003871', 'VT003872', 'VT003873',
                'VT003874', 'VT003875',
                'VT003915', 'VT003916', 'VT003917', 'VT003918', 'VT003919', 'VT003920', 'VT003921', 'VT003922'
            ),
            false
        ) as is_difn
    from {{ ref('int_stps_flags') }}
),

-- dfo (Python: dfmap1 = product_id <= 31842, lọc tiếp br = 'kn'): product_id "cũ" dùng chung giữa các brand
-- trước 01/08/2025 -> 1 product_id = 1 Product của mọi brand. Chỉ dòng br='kn' được giữ làm output; dòng
-- brand khác cùng product_id cũ bị loại bỏ hẳn khỏi kết quả (không rơi vào dfmap3, vì dfmap3 chỉ lấy phần
-- product_id > 31842).
dfo as (
    select
        base.*,
        product_id      as kn_product_id,  product_ctg_id  as kn_product_ctg_id,  product_tmpl_id as kn_product_tmpl_id,  smhcsid as kn_smhcsid,
        product_id      as pr_product_id,  product_ctg_id  as pr_product_ctg_id,  product_tmpl_id as pr_product_tmpl_id,  smhcsid as pr_smhcsid,
        product_id      as hh_product_id,  product_ctg_id  as hh_product_ctg_id,  product_tmpl_id as hh_product_tmpl_id,  smhcsid as hh_smhcsid,
        product_id      as thv_product_id, product_ctg_id  as thv_product_ctg_id, product_tmpl_id as thv_product_tmpl_id, smhcsid as thv_smhcsid,
        product_id      as sci_product_id, product_ctg_id  as sci_product_ctg_id, product_tmpl_id as sci_product_tmpl_id, smhcsid as sci_smhcsid,
        product_id      as da_product_id,  product_ctg_id  as da_product_ctg_id,  product_tmpl_id as da_product_tmpl_id,  smhcsid as da_smhcsid
    from base
    where product_id <= 31842 and br = 'kn'
),

-- dfmap2_src (Python dfmap2 điều kiện): id mới (> 31842), không đặc thù, có default_code, và default_code
-- ổn định trong phạm vi từng brand (cvl_iunique = 1) -> đủ tin cậy để tự động gộp theo default_code.
-- (điều kiện `df.cpname` trong Python luôn đúng vì cpname = size nhóm luôn >= 1 -- vô nghĩa, không dịch.)
dfmap2_src as (
    select *
    from base
    where product_id > 31842
        and not is_difn
        and default_code is not null
        and cvl_iunique = 1
),
-- dfgr_code: 1 dòng "đại diện" mỗi default_code, mang các cột mô tả (kpi_point, category...) vào output,
-- ưu tiên brand_etl nhỏ nhất (kn=1 < pr=3 < hh=4 < sci=7 < thv=8); Đông Á (2, thêm 2026-10-14) xếp CUỐI
-- để không đổi dòng đại diện của các brand cũ.
-- Python: dfmap2.sort_values('brand_etl').drop_duplicates('default_code', keep='first').
dfgr_code as (
    select *
    from (
        select *, row_number() over (partition by default_code order by (brand_etl = 2), brand_etl, product_id) as rn
        from dfmap2_src
    ) t
    where rn = 1
),
-- {br}_{id}: MIN() độc lập theo (default_code, br) -- không phụ thuộc dòng nào được chọn làm đại diện ở dfgr_code.
dfmap2_kn as (
    select default_code, min(product_id) as kn_product_id, min(product_ctg_id) as kn_product_ctg_id, min(product_tmpl_id) as kn_product_tmpl_id, min(smhcsid) as kn_smhcsid
    from dfmap2_src where br = 'kn' group by default_code
),
dfmap2_pr as (
    select default_code, min(product_id) as pr_product_id, min(product_ctg_id) as pr_product_ctg_id, min(product_tmpl_id) as pr_product_tmpl_id, min(smhcsid) as pr_smhcsid
    from dfmap2_src where br = 'pr' group by default_code
),
dfmap2_hh as (
    select default_code, min(product_id) as hh_product_id, min(product_ctg_id) as hh_product_ctg_id, min(product_tmpl_id) as hh_product_tmpl_id, min(smhcsid) as hh_smhcsid
    from dfmap2_src where br = 'hh' group by default_code
),
dfmap2_thv as (
    select default_code, min(product_id) as thv_product_id, min(product_ctg_id) as thv_product_ctg_id, min(product_tmpl_id) as thv_product_tmpl_id, min(smhcsid) as thv_smhcsid
    from dfmap2_src where br = 'thv' group by default_code
),
dfmap2_sci as (
    select default_code, min(product_id) as sci_product_id, min(product_ctg_id) as sci_product_ctg_id, min(product_tmpl_id) as sci_product_tmpl_id, min(smhcsid) as sci_smhcsid
    from dfmap2_src where br = 'sci' group by default_code
),
dfmap2_da as (
    select default_code, min(product_id) as da_product_id, min(product_ctg_id) as da_product_ctg_id, min(product_tmpl_id) as da_product_tmpl_id, min(smhcsid) as da_smhcsid
    from dfmap2_src where br = 'da' group by default_code
),
dfmerge_code as (
    select
        g.*,
        kn.kn_product_id,   kn.kn_product_ctg_id,   kn.kn_product_tmpl_id,   kn.kn_smhcsid,
        pr.pr_product_id,   pr.pr_product_ctg_id,   pr.pr_product_tmpl_id,   pr.pr_smhcsid,
        hh.hh_product_id,   hh.hh_product_ctg_id,   hh.hh_product_tmpl_id,   hh.hh_smhcsid,
        thv.thv_product_id, thv.thv_product_ctg_id, thv.thv_product_tmpl_id, thv.thv_smhcsid,
        sci.sci_product_id, sci.sci_product_ctg_id, sci.sci_product_tmpl_id, sci.sci_smhcsid,
        da.da_product_id,   da.da_product_ctg_id,   da.da_product_tmpl_id,   da.da_smhcsid
    from dfgr_code g
    left join dfmap2_kn  kn  on kn.default_code = g.default_code
    left join dfmap2_pr  pr  on pr.default_code = g.default_code
    left join dfmap2_hh  hh  on hh.default_code = g.default_code
    left join dfmap2_thv thv on thv.default_code = g.default_code
    left join dfmap2_sci sci on sci.default_code = g.default_code
    left join dfmap2_da  da  on da.default_code = g.default_code
),

-- dfmap3 (Python): phần còn lại (id mới nhưng đặc thù / default_code null / không ổn định trong 1 brand)
-- -> KHÔNG gộp, mỗi dòng chỉ giữ id của chính brand mình, brand khác NULL.
dfmap3 as (
    select
        base.*,
        case when br = 'kn'  then product_id end as kn_product_id,  case when br = 'kn'  then product_ctg_id end as kn_product_ctg_id,  case when br = 'kn'  then product_tmpl_id end as kn_product_tmpl_id,  case when br = 'kn'  then smhcsid end as kn_smhcsid,
        case when br = 'pr'  then product_id end as pr_product_id,  case when br = 'pr'  then product_ctg_id end as pr_product_ctg_id,  case when br = 'pr'  then product_tmpl_id end as pr_product_tmpl_id,  case when br = 'pr'  then smhcsid end as pr_smhcsid,
        case when br = 'hh'  then product_id end as hh_product_id,  case when br = 'hh'  then product_ctg_id end as hh_product_ctg_id,  case when br = 'hh'  then product_tmpl_id end as hh_product_tmpl_id,  case when br = 'hh'  then smhcsid end as hh_smhcsid,
        case when br = 'thv' then product_id end as thv_product_id, case when br = 'thv' then product_ctg_id end as thv_product_ctg_id, case when br = 'thv' then product_tmpl_id end as thv_product_tmpl_id, case when br = 'thv' then smhcsid end as thv_smhcsid,
        case when br = 'sci' then product_id end as sci_product_id, case when br = 'sci' then product_ctg_id end as sci_product_ctg_id, case when br = 'sci' then product_tmpl_id end as sci_product_tmpl_id, case when br = 'sci' then smhcsid end as sci_smhcsid,
        case when br = 'da'  then product_id end as da_product_id,  case when br = 'da'  then product_ctg_id end as da_product_ctg_id,  case when br = 'da'  then product_tmpl_id end as da_product_tmpl_id,  case when br = 'da'  then smhcsid end as da_smhcsid
    from base
    where product_id > 31842
        and (is_difn or default_code is null or cvl_iunique <> 1)
),

unioned as (
    select
        smhcsid, his_service_type, surgery_type, product_ctg_id, kpi_first_time, product_category,
        product_category_paris, product_category_new, product_id, default_code, product, list_price,
        product_tmpl_id, is_main_service, group_id, product_id_kn, is_vip, qty_service, kpi_point,
        kpi_point_num, uom_id, uom, create_date, write_date, kdtc_product_ctg_id, brand_etl, br,
        cvl_unique, cvl_iunique, cpname, is_no_kpi, gr_bh_id,
        kn_product_id, kn_product_ctg_id, kn_product_tmpl_id, kn_smhcsid,
        pr_product_id, pr_product_ctg_id, pr_product_tmpl_id, pr_smhcsid,
        hh_product_id, hh_product_ctg_id, hh_product_tmpl_id, hh_smhcsid,
        thv_product_id, thv_product_ctg_id, thv_product_tmpl_id, thv_smhcsid,
        sci_product_id, sci_product_ctg_id, sci_product_tmpl_id, sci_smhcsid,
        da_product_id, da_product_ctg_id, da_product_tmpl_id, da_smhcsid
    from dfo
    union all
    select
        smhcsid, his_service_type, surgery_type, product_ctg_id, kpi_first_time, product_category,
        product_category_paris, product_category_new, product_id, default_code, product, list_price,
        product_tmpl_id, is_main_service, group_id, product_id_kn, is_vip, qty_service, kpi_point,
        kpi_point_num, uom_id, uom, create_date, write_date, kdtc_product_ctg_id, brand_etl, br,
        cvl_unique, cvl_iunique, cpname, is_no_kpi, gr_bh_id,
        kn_product_id, kn_product_ctg_id, kn_product_tmpl_id, kn_smhcsid,
        pr_product_id, pr_product_ctg_id, pr_product_tmpl_id, pr_smhcsid,
        hh_product_id, hh_product_ctg_id, hh_product_tmpl_id, hh_smhcsid,
        thv_product_id, thv_product_ctg_id, thv_product_tmpl_id, thv_smhcsid,
        sci_product_id, sci_product_ctg_id, sci_product_tmpl_id, sci_smhcsid,
        da_product_id, da_product_ctg_id, da_product_tmpl_id, da_smhcsid
    from dfmerge_code
    union all
    select
        smhcsid, his_service_type, surgery_type, product_ctg_id, kpi_first_time, product_category,
        product_category_paris, product_category_new, product_id, default_code, product, list_price,
        product_tmpl_id, is_main_service, group_id, product_id_kn, is_vip, qty_service, kpi_point,
        kpi_point_num, uom_id, uom, create_date, write_date, kdtc_product_ctg_id, brand_etl, br,
        cvl_unique, cvl_iunique, cpname, is_no_kpi, gr_bh_id,
        kn_product_id, kn_product_ctg_id, kn_product_tmpl_id, kn_smhcsid,
        pr_product_id, pr_product_ctg_id, pr_product_tmpl_id, pr_smhcsid,
        hh_product_id, hh_product_ctg_id, hh_product_tmpl_id, hh_smhcsid,
        thv_product_id, thv_product_ctg_id, thv_product_tmpl_id, thv_smhcsid,
        sci_product_id, sci_product_ctg_id, sci_product_tmpl_id, sci_smhcsid,
        da_product_id, da_product_ctg_id, da_product_tmpl_id, da_smhcsid
    from dfmap3
)

-- dfnew[lsid] = dfnew['kn_'+lsid] với lsid = [product_id, product_ctg_id, product_tmpl_id, smhcsid] (v2 mở
-- rộng so với v1 -- v1 chỉ ghi đè product_id, còn product_ctg_id/product_tmpl_id/smhcsid vẫn giữ giá trị gốc
-- của dòng): output 4 cột này LUÔN LÀ giá trị bên KangNam (canonical); NULL nếu dòng không xác định được
-- kn_* (dfmap2/dfmap3 không có dòng kn cho default_code/id đó).
select
    his_service_type, surgery_type, kpi_first_time, product_category, product_category_paris,
    product_category_new, default_code, product, list_price, is_main_service, group_id, product_id_kn,
    is_vip, qty_service, kpi_point, kpi_point_num, uom_id, uom, create_date, write_date,
    kdtc_product_ctg_id, brand_etl, br, cvl_unique, cvl_iunique, cpname, is_no_kpi, gr_bh_id,
    kn_product_id as product_id,
    kn_product_ctg_id as product_ctg_id,
    kn_product_tmpl_id as product_tmpl_id,
    kn_smhcsid as smhcsid,
    pr_product_id, pr_product_ctg_id, pr_product_tmpl_id, pr_smhcsid,
    hh_product_id, hh_product_ctg_id, hh_product_tmpl_id, hh_smhcsid,
    thv_product_id, thv_product_ctg_id, thv_product_tmpl_id, thv_smhcsid,
    sci_product_id, sci_product_ctg_id, sci_product_tmpl_id, sci_smhcsid,
    da_product_id, da_product_ctg_id, da_product_tmpl_id, da_smhcsid
from unioned
