with ecl2 as (
select
	*
from
	{{ source('rmkdt', 'crm_lead') }} cl
where
	cl.brand_etl = 1
	and cl.create_by_department is not null
	and cl.create_date::date >= '20250101'),
ecl as (
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
)
,
ao as   
      (
select
	'Ao' as bang,
	--bảng ảo để map chỉ tiêu
          0 as id_source,
	date(gts."time") as "Ngay",
	null "Booking",
	null as dien_thoai,
	null as loai_kh, 
		  null :: integer as "id_lead",
	null :: integer as "ID",
	null as "Phieu",
	gts.kenh as "Nguon",
	case
		when gts.nguon = 'Nguồn khác' then 'Khác'
		else gts.nguon
	end as "Nhom_nguon",
	null as "DV/SP",
	null as "service_code",
	null "Loai_DV/SP",
	null as "Nhom_DV",
	gts."thương hiệu" as "Thuong_hieu",
	gts.brand_id as brandid,
	gts."chi nhánh" as "Chi_nhanh",
	gts.company_id as chinhanhphanquyen_nu,
	0 as "Thanh_toan",
	0 as "Tong_tien",
	null as "TT_DV/SP",
	null as "Loai",
	gts.kenh as kenh,
	gts.id_kenh :: integer as ma_kenh,
	case
		when gts.nguon = 'Nguồn khác' then 'Khác'
		else gts.nguon
	end as nguon_moi,
	gts.id_nguon :: integer ma_nguon_moi,
	null as loai_phau_thuat
from
	{{ source('rmkdt', 'target_kangnam_chitieu') }} gts
where
	gts."time" >= '20240101'
      ),
  dv as (
select
	'DV' as bang,
	--Phan bo phieu thu DV
	ecl2.source_id as id_source,
	date(spt.payment_date + '07:00:00' :: interval) as "Ngay",
	ecl2.name as "Booking",
	ecl2.phone as dien_thoai,
	ecl2.type_data_partner as loai_kh,
	ecl2.id as "id_lead",
	ecl.id as "ID",
	spt.ma_phieu as "Phieu",
	ss."source" as "Nguon",
	ss.category_source as "Nhom_nguon",
	sp.product as "DV/SP",
	sp.default_code as "service_code",
	case
		when sp.product_category = 'SAN PHAM' then 'Sản Phẩm'
		else sp.his_service_type
	end as "Loai_DV/SP",
	sp.product_category as "Nhom_DV",
	erb.name as "Thuong_hieu",
	erb.id as brandid,
	mrc.name as "Chi_nhanh",
	mrc.id as chinhanhphanquyen,
	(spt.payment / 1000) as "Thanh_toan",
	ecl.total_received as "Tong_tien",
	ecl.stage as "TT_DV/SP",
	case
		when spt.ma_phieu like '%PDC%' then 'Transfer'
		else spt.ma_phieu
	end as "Loai",
	ss.channel as kenh,
	ss.channel_id as ma_kenh,
	ss.category_channel as nguon_moi,
	case
		when ss.category_channel = 'Marketing Digital' then 1
		when ss.category_channel = 'Marketing Offline' then 2
		when ss.category_channel = 'Marketing Location' then 3
		when ss.category_channel = 'Khác' then 4
	end ma_nguon_moi,
	sp.surgery_type as loai_phau_thuat
from
	{{ source('rmkdt', 'stag_payment_transfer') }} spt
left join {{ source('rmkdt', 'crm_lead') }} ecl2 on
	spt.crm_id = ecl2.id
	and spt.brand_etl = ecl2.brand_etl
left join ecl on
	spt.clineid = ecl.id
	and spt.brand_etl = ecl.brand_etl
left join {{ source('rmkdt', 'm_res_company') }} mrc on
	mrc.id = spt.company_id
	and mrc.brand_id = 1
	and mrc.brand_etl = 1
left join {{ source('rmkdt', 'res_brand') }} erb on
	mrc.brand_id = erb.id
	and erb.brand_etl = 1
left join {{ source('rmkdt', 'stag_products') }} sp on
	sp.product_id = spt.product_id
left join {{ source('rmkdt', 'stag_sources') }} ss on
	ss.old_id = ecl2.source_id
	and ss.brand_id = 1
where
	spt.brand_etl in(0, 1)
		and ecl2.id is not null
		and
			spt.payment_date >= '20250101'
		and mrc.brand_id = 1 
),
b as (
select
	distinct id_lead
from
	dv
where
	"Loai_DV/SP" in ('Card', 'Laser', 'Spa')
	and dv."TT_DV/SP" <> 'cancel'
), rp as (
select
	*
from
	ao
union all
select
	dv.*
from
	dv
join b on
	b.id_lead = dv.id_lead
where
	 "Nhom_DV" = 'SAN PHAM'
union all
select
	*
from
	dv
where
	"Loai_DV/SP" in ('Card', 'Laser', 'Spa')
)
select * from  rp
