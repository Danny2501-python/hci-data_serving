with d as (
select 
    r.walkin_id,
    r.pk,
    r.ngay_lam_dv,
    r.booking_id,
    r.bk,
    r.crm_line_id,
    r.sp,
    r.product_id,
    r.number_used,
    r.product_category,
    r.stage,
    r.tien_phai_thu,
    r.tien_da_thu,
    r.brand_etl,
    r.rnk,
    spt.payment,
    spt.payment_date as max_tt_trc_dv,
    row_number() over(partition by crm_line_id order by spt.payment_date desc) rk2,
    sum(spt.payment) over(partition by r.crm_line_id) as tien_tra_trc_dv
from {{ref('stag_dps_transfer_revenue_service')}} r
left join {{ref('dps_payment')}} spt on spt.crm_id = r.booking_id and spt.clineid = r.crm_line_id
and spt.brand_etl = r.brand_etl
where r.rnk =1 and date(r.ngay_lam_dv) > spt.payment_date
)
select d.walkin_id as walkin_id_2, 
d.crm_line_id as line_id,
d.max_tt_trc_dv
, d.tien_tra_trc_dv,
d.brand_etl
from d
where rk2 = 1