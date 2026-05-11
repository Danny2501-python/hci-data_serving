with ecl as (
select
	*
from
	{{ source('rmkdt', 'crm_lead') }} cl
where
	cl.brand_etl = 1
	and cl.active is true
	and cl.create_by_department is not null
	and cl.create_date::date >= '20250101'),
cline as (
select
	cl.total_received ,
	cl.id,
	cl.crm_id ,
	cl.product_id ,
	cl.stage ,
	cl.create_date ,
	cl.brand_etl,
	1
from
	{{ source('rmkdt', 'crm_line') }} cl
where
	cl.brand_etl = 1
	and cl.create_date::date >= '20250101'
union all
select
	clp.total_received ,
	clp.id,
	clp.booking_id ,
	clp.product_id ,
	clp.stage_line_product ,
	clp.create_date ,
	clp.brand_etl,
	3
from
	{{ source('rmkdt', 'crm_line_product') }} clp
where
	clp.brand_etl = 1
	and clp.create_date::date >= '20250101'
),
tdv_sm as 
(
select
	-- tiền dịch vụ SM 
	ecl.overseas_vietnamese as "Việt Kiều/Nội Địa",
	sp.default_code as code_dv,
	ecl.contact_name as Ten_Khach,
	ecl.id as id,
	ecl.code_customer as Ma_KH,
	ecl.phone as sdt,
	date(
            ecl.arrival_date + '07:00:00' :: interval
          ) as Ngay_den_cua,
	ecl.type_crm_id as Loai_ban_ghi,
	date(
            ecl.create_on + '07:00:00' :: interval
          ) as Ngay_tao,
	date(
            ecl.arrival_date + '07:00:00' :: interval
          ) as Ngay_dc,
	date(
            ecl.booking_date + '07:00:00' :: interval
          ) as Ngay_hl,
	date('9999/01/01') as Ngay_tt,
	case
		when ecl.arrival_date is not null then ecl.arrival_date::Date
		when ecl.arrival_date is null then ecl.create_on::Date
	end as Date_Time,
	ecl.name as Ma_Booking,
	se.employee as Nhan_Vien,
	0 as doanh_so,
	ecl.amount_paid as Tong_tien,
	'not' as vao_so,
	ecs2.name as Trang_Thai,
	ecl2.stage as Line_tt,
	case
		when ecl.arrival_date is not null
			and ecs2.name in(
            'Won', 'Đặt cọc', 'Đang xử lý'
          ) then 'Thành Công'
			when ecl.arrival_date is not null
				and ecs2.name not in(
            'Won', 'Đặt cọc', 'Đang xử lý'
          ) then 'Đến Cửa'
				when ecl.arrival_date is null
					and ecl.type_crm_id = '2' then 'Booking'
					when ecl.arrival_date is null
					and ecl.type_crm_id = '1' then 'Lead'
				end as Phan_Loai_Khach,
				ect.name as Loai_BK,
				erb3."name" as Thuong_hieu,
				sp.product_category as Nhom_DV,
				sp.product as Ten_DV,
				mrc3."name" as Chi_Nhanh,
				mrc3.id as chinhanhphanquyen_notuse,
				ecl.create_by_department as Phong_ban_nguoi_tao,
				ss."source" as Nguon_moi,
				ss.category_source as Nhom_nguon_moi,
				ect.name "LoaiKH",
				ecl.type_data_partner,
				uc."name" as "ten_cd",
				ss.channel as kenh,
				ss.channel_id as ma_kenh,
				ss.category_channel as nguon_moi_new,
				case
					when ss.category_channel = 'Marketing Digital' then 1
					when ss.category_channel = 'Marketing Offline' then 2
					when ss.category_channel = 'Marketing Location' then 3
					when ss.category_channel = 'Nguồn khác' then 4
				end ma_nguon_moi_new,
				ecl2.id clineid,
				case
					when sp.product_category = 'SAN PHAM' then 'Sản Phẩm'
					else sp.his_service_type
				end as his_service_type,
				'abc' as ma_phieu,
				sp.surgery_type as loai_pt,
				ecl.type as lead_or_oppor,
				'abc' as fk_id,
				0 as spt_cline,
				'data' as bang,
				null::float as quantity,
				null::integer as number_used
			from
				ecl
			left join {{ source('rmkdt', 'res_brand') }} erb3 on
				erb3.id = ecl.brand_id
				and erb3.brand_etl = 1
			left join {{ source('rmkdt', 'm_res_company') }} mrc3 on
				mrc3.id = ecl.company_id
				and mrc3.brand_etl = 1
			left join cline ecl2 on
				ecl2.crm_id = ecl.id
			left join {{ source('rmkdt', 'utm_campaign') }} uc on
				uc.id = ecl.campaign_id
				and uc.brand_etl = 1
			left join {{ source('rmkdt', 'crm_stage') }} ecs on
				ecs.id = ecl.stage_id
				and ecs.brand_etl = 1
			left join {{ source('rmkdt', 'crm_stage') }} ecs2 on
				ecs2.id = ecl.stage_id
				and ecs2.brand_etl = 1
			left join {{ source('rmkdt', 'crm_type') }} ect on
				ect.id = ecl.type_crm_id
				and ect.brand_etl = 1
			left join {{ source('rmkdt', 'view_stag_employees_user') }} se on
				se.user_id = ecl.create_uid and se.brand_etl = 1
			left join {{ source('rmkdt', 'stag_products') }} sp on
				sp.product_id = ecl2.product_id
			left join {{ source('rmkdt', 'stag_sources') }} ss on
				ss.old_id = ecl.source_id
			where
				mrc3.brand_id = 1),
dv as (
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
	spt.total_received,
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
	ss.category_source as nhom_nguon_moi,
	'Booking new',
	'old',
	uc.name,
	ss.org_source,
	ss.channel_id,
	ss.category_channel ,
	case
		when ss.category_channel = 'Marketing Digital' then 1
		when ss.category_channel = 'Marketing Offline' then 2
		when ss.category_channel = 'Marketing Location' then 3
		when ss.category_channel = 'Nguồn khác' then 4
	end ma_nguon_moi_new,
	spt.clineid as line_id,
	case
		when sp.product_category = 'SAN PHAM' then 'Sản Phẩm'
		else sp.his_service_type
	end as his_service_type,
	spt.ma_phieu,
	sp.surgery_type ,
	'opportunity',
	spt.id as fk_id,
	spt.clineid,
	'payment' as bang,
	spt.quantity,
	spt.number_used
from
	{{ source('rmkdt', 'stag_payment_transfer') }} spt
left join {{ source('rmkdt', 'crm_lead') }} ecl on
	ecl.id = spt.crm_id
	and ecl.brand_etl = spt.brand_etl
left join {{ source('rmkdt', 'stag_products') }} sp on
	sp.product_id = spt.product_id
left join {{ source('rmkdt', 'stag_employees') }} se on
	se.kn_user_id = ecl.create_by
left join {{ source('rmkdt', 'm_res_company') }} mrc on
	mrc.id = spt.company_id
	and mrc.brand_id = 1
	and mrc.brand_etl = 1
left join {{ source('rmkdt', 'stag_sources') }} ss on
	ss.old_id = ecl.source_id
left join {{ source('rmkdt', 'utm_campaign') }} uc on
	uc.id = ecl.campaign_id
	and uc.brand_etl = 1
left join {{ source('rmkdt', 'res_brand') }} rb on
	rb.id = mrc.brand_id
	and rb.brand_etl = 1
where
	spt.brand_etl in(0, 1)
		and ecl.id is not null
		and mrc.brand_id = 1
		and payment_date >= '20250101'
),
rp as (
select
	*
from
	tdv_sm
union all
select
	*
from
	dv),
b as (
select
	distinct bang,id
from
	rp
where
	his_service_type in ('Card', 'Laser', 'Spa')
		and line_tt <> 'cancel'
),
p as (
select
	rp.*
from
	rp
join b on
	b.id = rp.id
	and b.bang = rp.bang
where
	his_service_type not in ('Card', 'Laser', 'Spa')
		and nhom_dv = 'SAN PHAM'
union all
	select
		*
	from
		rp
	where
		his_service_type in ('Card', 'Laser', 'Spa')
)
select
	*
from
	p
