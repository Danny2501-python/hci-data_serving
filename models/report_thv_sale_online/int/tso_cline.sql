with cline as  (
select
        ecl2.id clineid,
        ecl2.total_received,
        ecl2.product_id,
        ecl2.crm_id,
        ecl2.brand_etl,
        ecl2.stage
from {{source('thv','crm_line')}} ecl2
where ecl2.brand_etl = 8
union all
select
        clp.id clineid,
        clp.total_received,
        clp.product_id,
        clp.booking_id as crm_id,
        clp.brand_etl,
        clp.stage_line_product as stage
from {{source('thv','crm_line_product')}} clp
where clp.brand_etl = 8
), 
product as (
select 
pp.id product_id, 
pp.default_code , 
pp.product_tmpl_id ,
pt.name product,
pc.name product_ctg
from (select * from {{source('thv','product_product')}} where brand_etl =8) pp
left join (select * from  {{source('thv','product_template')}} where brand_etl =8) pt on pt.id = pp.product_tmpl_id
left join (select * from {{source('thv','product_category')}} where brand_etl =8) pc
on pc.id = pt.categ_id 
)
select row_number() over(partition by crm_id  order  by  clineid) rnk_line ,
cl2.* ---, p.product
, p.product_ctg
from cline cl2
left join product p on p.product_id = cl2.product_id