with d as (
select 
    r.*,
    spt.payment_date as ngay_tt_sau_dv,
    spt.payment,
    spt.company_id
from {{ref('stag_dps_transfer_revenue_service')}} r
left join {{ref('dps_payment')}} spt on spt.clineid = r.crm_line_id
and spt.brand_etl = r.brand_etl
where r.rnk =1 and date(r.ngay_lam_dv) <= spt.payment_date
)
select d.*,
        mrc.name chi_nhanh, rb.name thuong_hieu, mrc.brand_id
from d 
left join {{source ('raw_data','m_res_company')}} mrc on mrc.id =d.company_id and mrc.brand_etl = d.brand_etl
left join {{source ('raw_data','res_brand')}} rb on rb.id = mrc.brand_id and rb.brand_etl  = mrc.brand_etl 