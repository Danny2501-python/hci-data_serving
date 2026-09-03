Câu Query trong code sql
```with data_nhomdichvu as 
(with a as (select
	a.id,
	pc."name",
	pc.code,
	b.product_cat_id as "product_cat_id/id",
	pc."name" as "product_cat_id/name",
	'shealth_all_in_one.sh_services' as "parent_id/id",
	'standard' as property_cost_method,
	c.brand_id  as "brand_id/id",
	c.brand_name  as "brand_id/name",
	'manual_periodic' as property_valuation
from
	(select * from sh_medical_health_center_service_category a where exists (select 1 from product_category pc where pc.id = a.product_cat_id)) smhcsc
join product_category pc on
	pc.id = smhcsc.product_cat_id
left join (
	select
		imd.res_id ,
		concat(imd."module",'.',imd."name") as id
	from
		ir_model_data imd
	where
		model = 'sh.medical.health.center.service.category' and imd."module" not ilike '%export%') a on a.res_id = smhcsc.id
left join (
select
	imd.res_id ,
	concat(imd."module",'.',imd."name") as product_cat_id
from
	ir_model_data imd
where
	model = 'product.category'
) b on b.res_id = pc.id 
left join (select
	rb.id,
	rb."name" as brand_name,
	concat(imd."module",'.',imd."name") as brand_id
from
	res_brand rb
join ir_model_data imd on
	rb.id = imd.res_id
where
	imd.model = 'res.brand') c on c.id = pc.brand_id),
b as (
select a.code, count(*) as prod_cat_nam_ct
from a group by a.code),
c as (select a.*, b.prod_cat_nam_ct from a
join b on a.code = b.code
where a.id is not null)
select a.*,
	case 
		when c.prod_cat_nam_ct > 1 then true
		when c.prod_cat_nam_ct = 1 and a.code is not null and a.id is null and a."product_cat_id/id" is null then true
		else false
	end as is_prod_cat_duplicate
from a
join c on a.code = c.code
where a.id is not null),
nhom_dichvu as (
select
	case
		when a.code is null then null
		else a.id
	end as id,
	case 
		when idns."name" is null then a."name"
		else idns."name"
	end as "name",
	idns.code,
	case
		when a.code is null then null
		else a."product_cat_id/id"
	end as "product_cat_id/id",
	case 
		when idns."name" is null then a."name"
		else idns."name"
	end as "product_cat_id/name",
	'shealth_all_in_one.sh_services' as "parent_id/id",
	'standard' as property_cost_method,
	c.brand_id as "brand_id/id",
	idns."brand_id/name",
	'manual_periodic' as property_valuation,
	a.is_prod_cat_duplicate
from
	import_danhmuc_nhomdichvu_sci idns
left join data_nhomdichvu a on a.code = idns.code
left join (select
	rb."name" as brand_name,
	concat(imd."module",'.',imd."name") as brand_id
from
	res_brand rb
join ir_model_data imd on
	rb.id = imd.res_id
where
	imd.model = 'res.brand') c on c.brand_name = idns."brand_id/name"),
output_data as (
select 
	case
		when a.id is null and not exists (select 1 from product_category pc where pc.code = a.code) then concat('__import__.',a.code)
		else a.id
	end as id,
	a."name",
	a.code,
	a."product_cat_id/id",
	a."product_cat_id/name",
	a."parent_id/id",
	a.property_cost_method,
	a."brand_id/id",
	a."brand_id/name",
	a.property_valuation,
	a.is_prod_cat_duplicate
from nhom_dichvu a
),
note_data as (
select
	a.id,
	a."name",
	a.code,
	a."product_cat_id/id",
	a."product_cat_id/name",
	a."parent_id/id",
	a.property_cost_method,
	a."brand_id/id",
	a."brand_id/name",
	a.property_valuation,
	case
		when a.code is null then null
		when not exists (select 1 from product_category pc where pc.code = a.code) then true
		else false
	end as is_prod_cat_new
from
	output_data a),
type_data_nhomdichvu as (
select
	nd.*,
	case
		when a.is_prod_cat_new is null then 'Error: Không nhập Code cho nhóm dịch vụ'
		when a.is_prod_cat_new is false then 'Nhóm dịch vụ cũ'|| false_id || f.false_prod_cat_duplicate || f.false_brand_id
		else 'Nhóm dịch vụ mới' || false_id || f.false_name || f.false_product_cat_id || f.false_brand_id
	end as data_status
from
	output_data nd
left join (
	select
		nd.code,
		case
			when nd.id is null then ' | thiếu id cho nhóm dịch vụ'
			else ''
		end as false_id,
		case
			when nd."name" is null then ' | thiếu tên nhóm dịch vụ'
			else ''
		end as false_name,
		case
			when nd."product_cat_id/name" is null then ' | thiếu product_cat_id/name'
			else ''
		end as false_product_cat_id,
		case 
			when not exists (select 1 from res_brand rb where nd."brand_id/name" = rb."name") then ' | Sai tên "brand_id/name"'
			else ''
		end false_brand_id,
		case 
			when nd.is_prod_cat_duplicate is true then ' | Dữ liệu đang bị có 2 nhóm dịch vụ'
			else ''
		end as false_prod_cat_duplicate
	from
		output_data nd ) f on
	nd.code = f.code
left join note_data a on a.code = nd.code
),
output_nhomdichvu as (
select tdn.id,
	tdn."name",
	tdn.code,
	tdn."product_cat_id/id",
	tdn."product_cat_id/name",
	tdn."parent_id/id",
	tdn.property_cost_method,
	tdn."brand_id/id",
	tdn."brand_id/name",
	tdn.property_valuation,
	tdn.data_status,
	case 
		when tdn.data_status in ('Nhóm dịch vụ cũ', 'Nhóm dịch vụ mới') then false 
		when tdn.is_prod_cat_duplicate is true then false
		else true 
	end as is_record_false
from type_data_nhomdichvu tdn
)
select * from output_nhomdichvu```