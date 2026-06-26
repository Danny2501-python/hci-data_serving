-- Tương đương bảng tạm data_final trong func_data_vong_doi_khach_hang
-- brand_etl = 1 đã được lọc tại tầng stg
-- stag_products không có brand_etl filter (đúng như gốc)
-- crm_information_consultant lọc thêm role = 'recept' tại đây (brand_etl đã lọc ở stg)

with tv1 as (
    select * from {{ ref('int_rvdkk_tu_van1') }}
)

select
    cl.id                                                                               as id_lead,
    cl.partner_id,
    cl."name"                                                                           as booking,
    cl.contact_name                                                                     as ten_kh,
    cl.code_customer                                                                    as ma_kh,
    cl.phone,
    cl.company_id                                                                       as chinhanh_id_book,
    ccs."name"                                                                          as nhom_nguon,
    us."source"                                                                         as nguon_booking,
    cl.arrival_date + '7hours'::interval                                                as ngay_den_cua,
    cs.name                                                                             as trang_thai_book,
    cl.brand_id                                                                         as brand_id_book,
    cl.type_crm_id,
    ct."name"                                                                           as crm_type,
    cl2.id                                                                              as id_line,
    cl2.product_id,
    cl2.stage                                                                           as trang_thai_dv,
    sp.product,
    sp.product_category,
    sp.his_service_type,
    spt.id                                                                              as id_tt,
    spt.ma_phieu,
    spt.payment                                                                         as doanh_so,
    spt.payment_date                                                                    as ngay_tt,
    spt.company_id                                                                      as chinhanh_tt,
    mrc."name"                                                                          as chi_nhanh,
    mrc.brand_id,
    rb."name"                                                                           as thuong_hieu,
    case when cl2.consultants_1 is null then cic.user_id else cl2.consultants_1 end     as tu_van1_id,
    case when tv2.nv is null then tv3.nv else tv2.nv end                                as tu_van1,
    case when tv2.pb is null then tv3.pb else tv2.pb end                                as pb_tu_van1,
    case when tv2.id_pb is null then tv3.id_pb else tv2.id_pb end                       as pb_tu_van1_id,
    cl2.total_received,
    case when sum(spt.payment) over (partition by cl2.id) > 0
         then 'DV thành công'
    end                                                                                 as dv_tc
from {{ ref('stg_rvdkk_crm_lead') }}                   cl
left join {{ ref('stg_rvdkk_crm_category_source') }}   ccs on ccs.id = cl.category_source_id
left join {{ ref('stg_rvdkk_stag_sources') }}          us  on us.old_id = cl.source_id
left join {{ ref('stg_rvdkk_crm_stage') }}             cs  on cs.id = cl.stage_id
left join {{ ref('stg_rvdkk_crm_line') }}              cl2 on cl2.crm_id = cl.id
left join {{ ref('stg_rvdkk_stag_products') }}         sp  on sp.product_id = cl2.product_id
left join {{ ref('stg_rvdkk_crm_type') }}              ct  on ct.id = cl.type_crm_id
left join {{ ref('stg_rvdkk_stag_payment_transfer') }} spt on spt.crm_id = cl.id and spt.clineid = cl2.id
left join tv1                                          tv2 on tv2.id = cl2.consultants_1
left join {{ ref('stg_rvdkk_crm_information_consultant') }} cic on cic.crm_line_id = cl2.id
left join tv1                                          tv3 on tv3.id = cic.user_id
left join {{ ref('stg_rvdkk_m_res_company') }}         mrc on mrc.id = spt.company_id
left join {{ ref('stg_rvdkk_res_brand') }}             rb  on rb.id = mrc.brand_id
