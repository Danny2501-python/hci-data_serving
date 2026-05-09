with ecl as (
    select * from {{ ref('stg_rtqdp_crm_lead') }} cl where cl.brand_etl = 3 
), 
cline as (
    select * from {{ ref('stg_rtqdp_crm_line') }} cl where cl.brand_etl = 3
), 
tdv_sm as (
  select 
    ecl.overseas_vietnamese as "Việt Kiều/Nội Địa", 
    sp.default_code as code_dv, 
    ecl.contact_name as Ten_Khach, 
    ecl.id as id, 
    ecl.code_customer as Ma_KH, 
    ecl.phone as sdt, 
    date(ecl.arrival_date + '07:00:00' :: interval) as Ngay_den_cua, 
    ecl.type_crm_id as Loai_ban_ghi, 
    date(ecl.create_on + '07:00:00' :: interval) AS Ngay_tao, 
    date(ecl.arrival_date + '07:00:00' :: interval) AS Ngay_dc, 
    date(ecl.booking_date + '07:00:00' :: interval) AS Ngay_hl, 
    date('9999/01/01') AS Ngay_tt, 
    case when ecl.arrival_date is not null then ecl.arrival_date :: Date when ecl.arrival_date is null then ecl.create_on :: Date end as Date_Time, 
    ecl.name as Ma_Booking, 
    erp."name" as Nhan_Vien, 
    0 as doanh_so, 
    ecl.amount_paid as Tong_tien, 
    'not' as vao_so, 
    ecs2.name as Trang_Thai, 
    ecl2.stage as Line_tt, 
    case 
        when ecl.arrival_date is not null and ecs2.name IN('Won', 'Đặt cọc', 'Đang xử lý') then 'Thành Công' 
        when ecl.arrival_date is not null and ecs2.name not in('Won', 'Đặt cọc', 'Đang xử lý') then 'Đến Cửa' 
        when ecl.arrival_date is null and ecl.type_crm_id = '2' then 'Booking' 
        when ecl.arrival_date is null and ecl.type_crm_id = '1' then 'Lead' 
    END as Phan_Loai_Khach, 
    ect.name as Loai_BK, 
    erb3."name" as Thuong_hieu, 
    sp.product_category as Nhom_DV, 
    sp.product as Ten_DV, 
    mrc3."name" as Chi_Nhanh, 
    mrc3.id as chinhanhphanquyen_notuse, 
    ecl.create_by_department as Phong_ban_nguoi_tao, 
    ss.org_source as Nguon_moi, 
    ss.org_category_source as Nhom_nguon_moi, 
    ect.name "LoaiKH", 
    ecl.type_data_partner, 
    uc."name" as "ten_cd", 
    ss.org_source as kenh, 
    ss.channel_id as ma_kenh, 
    ss.org_category_source as nguon_moi_new, 
    case when ss.org_category_source = 'Marketing Digital' then 1 when ss.org_category_source = 'Marketing Offline' then 2 when ss.org_category_source = 'Marketing Location' then 3 when ss.org_category_source = 'Nguồn khác' then 4 end ma_nguon_moi_new, 
    ecl2.id clineid, 
    case when sp.product_category = 'SAN PHAM' then 'Sản Phẩm' else sp.his_service_type end as his_service_type, 
    'abc' as ma_phieu, 
    sp.surgery_type as loai_pt, 
    ecl.type as lead_or_oppor, 
    'abc' as fk_id, 
    0 as spt_cline, 
    'data' as bang
  from ecl 
    left join {{ ref('stg_rtqdp_res_brand') }} erb3 on erb3.id = ecl.brand_id and erb3.brand_etl = 3 
    left join {{ ref('stg_rtqdp_m_res_company') }} mrc3 on mrc3.id = ecl.company_id and mrc3.brand_etl = 3 
    left join cline ecl2 on ecl2.crm_id = ecl.id 
    left join {{ ref('stg_rtqdp_utm_campaign') }} uc on uc.id = ecl.campaign_id and uc.brand_etl = 3 
    left join {{ ref('stg_rtqdp_crm_stage') }} ecs on ecs.id = ecl.stage_id and ecs.brand_etl = 3 
    left join {{ ref('stg_rtqdp_hr_department') }} ehd on ecl.department_id = ehd.id and ehd.brand_etl = 3 
    left join {{ ref('stg_rtqdp_crm_stage') }} ecs2 on ecs2.id = ecl.stage_id and ecs2.brand_etl = 3 
    left join {{ ref('stg_rtqdp_crm_type') }} ect on ect.id = ecl.type_crm_id and ect.brand_etl = 3 
    left join {{ ref('stg_rtqdp_sources') }} eus on eus.old_id = ecl.source_id 
    left join {{ ref('stg_rtqdp_res_users') }} eru on eru.id = ecl.create_by and eru.brand_etl = 3 
    left join {{ ref('stg_rtqdp_products') }} sp on sp.product_id = ecl2.product_id 
    left join {{ ref('stg_rtqdp_res_partner') }} erp on erp.id = eru.partner_id and erp.brand_etl = 3 
    left join {{ ref('stg_rtqdp_sources') }} ss on ss.old_id = ecl.source_id 
  where mrc3.brand_id = 3
), 
rp as (
  select * from tdv_sm tsm 
  union all 
  select 
    ecl.overseas_vietnamese, 
    sp.default_code, 
    ecl.contact_name, 
    ecl.id, 
    ecl.code_customer, 
    ecl.phone, 
    ecl.arrival_date, 
    ecl.type_crm_id, 
    ecl.create_date, 
    ecl.arrival_date as ngay_dc, 
    ecl.booking_date, 
    spt.payment_date, 
    spt.payment_date as date_time, 
    ecl.name, 
    se.employee, 
    spt.payment, 
    cline.total_received, 
    'posted', 
    'Won', 
    'done', 
    'Booking', 
    'Paid', 
    rb.name, 
    sp.product_category, 
    sp.product, 
    mrc.name as chi_nhanh, 
    mrc.id as chinhanhphanquyen_nu, 
    se.department, 
    ss.org_source as nguon, 
    ss.org_category_source as nhom_nguon_moi, 
    'Booking new', 
    'old', 
    uc.name, 
    ss.org_source, 
    ss.channel_id, 
    ss.org_category_source, 
    case when ss.org_category_source = 'Marketing Digital' then 1 when ss.org_category_source = 'Marketing Offline' then 2 when ss.org_category_source = 'Marketing Location' then 3 when ss.org_category_source = 'Nguồn khác' then 4 end ma_nguon_moi_new, 
    cline.id as line_id, 
    sp.his_service_type, 
    spt.ma_phieu, 
    sp.surgery_type, 
    'opportunity', 
    spt.id as fk_id, 
    spt.clineid, 
    'payment' as bang
  from {{ ref('stg_rtqdp_payment_transfer') }} spt 
    left join ecl on ecl.id = spt.crm_id 
    left join cline cline on cline.id = spt.clineid 
    left join {{ ref('stg_rtqdp_products') }} sp on sp.product_id = cline.product_id 
    left join {{ ref('stg_rtqdp_employees') }} se on se.user_id = ecl.create_by 
    left join {{ ref('stg_rtqdp_m_res_company') }} mrc on mrc.id = spt.company_id and mrc.brand_id = 3 and mrc.brand_etl = 3 
    left join {{ ref('stg_rtqdp_sources') }} ss on ss.old_id = ecl.source_id 
    left join {{ ref('stg_rtqdp_utm_campaign') }} uc on uc.id = ecl.campaign_id and uc.brand_etl = 3 
    left join {{ ref('stg_rtqdp_res_brand') }} rb on rb.id = mrc.brand_id and rb.brand_etl = 3 
  where spt.brand_etl in(0, 3) 
    and ecl.id is not null 
    and mrc.brand_id = 3 
    and payment_date >= '20250801'
) 
select * from rp
