---xác định ad_name và page của ticket
with a as (
	select cca.ticket_id ,
cca.facebook_page_id , 
dp.page_name 
from {{source('data','cs_chat_api')}} cca
left join {{source('data','dim_page')}} dp on trim(dp.page_id::text)  = trim(cca.facebook_page_id)
where cca.brand_id =1   --- and  dp.brand_etl=1   
  and       cca.facebook_page_id is not null  
and cca.start_time >='20250101'--- and cca.ticket_id  = 697744558
group by 1, 2, 3
),
b as (
select *,
row_number() over(partition by ticket_id order by facebook_page_id ) rnk
from a 
)
select *
from b where rnk=1
