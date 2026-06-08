with ds as (
select a.*,
	row_number() over (partition by  booking, clineid, id_phieu, payment_date
	order by role) as no_clineid
from {{ref('stg_prs_combine')}} a
left join  (select  *  from m_res_company where brand_etl = 3) mrc2 
on a.company_id = mrc2.id 
----where mrc2.brand_id = 3 or thuonghieu =3
),
ds1 as (
select *,
case 
	when cancel_user is not null and cty_cancel <>1 and cty_tv is null then cty_cancel 
	---when cty_tv is not null  then cty_tv
	when cty_tv = company_id then company_id 
	when /*( cty_tv is  1 or cty_tv =2 or cty_tv =37 or  cty_tv =10 )*/ 
	cty_tv in (1,2,4,5,6,7,8,10,11,12,27,29,30,34,37,40,50) and  cty_tv <> lead_company then lead_company
	
	when /*( cty_tv is  1 or cty_tv =2 or cty_tv =37 or  cty_tv =10 )*/ 
	cty_tv in (1,2,4,5,6,7,8,10,11,12,27,29,30,34,37,40,50) and  cty_tv = lead_company then company_id
	
	when cty_tv is not null and /*(cty_tv <> 1 or cty_tv <>2 or  cty_tv <>37 or  cty_tv <> 10) */ cty_tv not in  (1,2,4,5,6,7,8,10,11,12,27,29,30,34,37,40,50) then cty_tv
	when cty_tv <> company_id and company_id = lead_company then company_id 
	when cty_tv is null and company_id is not null then company_id 
	when cty_tv is null and (cty_cancel is null or cty_cancel = 100 )and  lead_company is not null and company_id is null then lead_company
	--when cty_tv is not null and lead_company is not null and company_id is null then  lead_company
end  chinhanhphanquyen

from ds
),
 ds2 as (
(select 'hl' as type,
		booking_date dim_date,
		 extract('week' from booking_date) as week,
		ds1.*
from ds1
where booking_date is not null

) union all
 (
select 'dc' as type,
		arrival_date dim_date,
		 extract('week' from arrival_date ) as week,
		ds1.*
from ds1 
where arrival_date is not null
)
union all
(
select 'pm' as type,
		payment_date dim_date,
		 extract('week' from payment_date ) as week,
		ds1.*
from ds1 
where payment_date is not null
))
select ds2.*, /*rb.id thuonghieuphanquyen,*/ mrc.name "chinhanh",
case when cty_cancel is null then 'G'
	when cty_cancel  = 100 then 'K'
	else 'G'
	end

from ds2 
left join (
    select 
      * 
    from 
      {{source('prs_raw_data','m_res_company')}} mrc 
    where 
      brand_etl = 3
  )  mrc  on ds2.chinhanhphanquyen = mrc.id