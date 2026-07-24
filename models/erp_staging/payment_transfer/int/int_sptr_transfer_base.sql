-- Tương đương query_tf. Bản Python hard-code brand_etl = idb_kn (=1) vào mọi điều kiện join/where rồi
-- .replace('brand_etl = 1', f'brand_etl = {idb}') theo từng vòng lặp brand — ở đây dùng thẳng
-- ctpl.brand_etl (giá trị thật của dòng) cho mọi so khớp, tương đương 100% vì mọi bảng liên quan trong
-- 1 dòng transfer luôn cùng 1 brand_etl.
with raw as (
select
    ctpl.id,
    ctp.name as ma_phieu,
    ctp.crm_id,
    case when coalesce(ctpl.from_crm_line_id, 0) = 0 then 'cosmetic' else 'service' end as product_typef,
    case when coalesce(ctpl.to_crm_line_id, 0) = 0 then 'cosmetic' else 'service' end as product_typet,
    coalesce(nullif(ctpl.from_crm_line_id, 0), ctpl.from_crm_line_product_id) as clineidf,
    coalesce(nullif(ctpl.to_crm_line_id, 0), ctpl.to_crm_line_product_id) as clineidt,
    ctp.payment_date,
    ctp.company_id as orgcompany_id,
    coalesce(nullif(clinef.product_id, 0), clinepf.product_id) as product_idf,
    coalesce(nullif(clinet.product_id, 0), clinept.product_id) as product_idt,
    ctpl.from_company_id as company_idf,
    coalesce(nullif(ctpl.to_company_id, 0), ctpl.from_company_id) as company_idt,
    coalesce(nullif(clinef.quantity, 0), clinepf.product_uom_qty) as quantityf,
    clinef.uom_price as uom_pricef,
    coalesce(nullif(clinef.number_used, 0), case when clinepf.stage_line_product = 'sold' then clinepf.product_uom_qty else 0 end)
        as number_usedf,
    coalesce(clinef.stage, clinepf.stage_line_product) as stage_productf,
    coalesce(nullif(clinef.consultants_1, 0), clinepf.consultants_1) as consultants_1f,
    coalesce(clinef.consulting_role_1, clinepf.consulting_role_1) as consulting_role_1f,
    coalesce(nullif(clinef.consultants_2, 0), clinepf.consultants_2) as consultants_2f,
    coalesce(clinef.consulting_role_2, clinepf.consulting_role_2) as consulting_role_2f,
    clinef.ho_tro as ho_trof,
    coalesce(nullif(clinet.quantity, 0), clinept.product_uom_qty) as quantityt,
    clinet.uom_price as uom_pricet,
    coalesce(nullif(clinet.number_used, 0), case when clinept.stage_line_product = 'sold' then clinept.product_uom_qty else 0 end)
        as number_usedt,
    coalesce(clinet.stage, clinept.stage_line_product) as stage_productt,
    coalesce(nullif(clinet.consultants_1, 0), clinept.consultants_1) as consultants_1t,
    coalesce(clinet.consulting_role_1, clinept.consulting_role_1) as consulting_role_1t,
    coalesce(nullif(clinet.consultants_2, 0), clinept.consultants_2) as consultants_2t,
    coalesce(clinet.consulting_role_2, clinept.consulting_role_2) as consulting_role_2t,
    clinet.ho_tro as ho_trot,
    case when clinef.gia_truoc_huy > 0 then clinef.gia_truoc_huy else coalesce(clinef.total, clinepf.total) end as totalf,
    case
        when clinet.gia_truoc_huy > 0 then clinet.gia_truoc_huy
        when clinet.total is null then clinept.total
        else clinet.total
    end as totalt,
    ctpl.transfer_amount,
    cast(null as varchar) as payment_type,
    ctpl.total_received as total_receivedf,
    ctplt.total_received as total_receivedt,
    clinef.total_received as total_received_clinef,
    clinet.total_received as total_received_clinet,
    coalesce(nullif(clinef.price_list_id, 0), clinepf.product_pricelist_id) as price_list_idf,
    coalesce(nullif(clinet.price_list_id, 0), clinept.product_pricelist_id) as price_list_idt,
    'pdc' as payment_method,
    ctp.communication,
    ctp.write_date + interval '7 hours' as write_date,
    ctp.brand_id, ctpl.brand_etl
from {{ ref('stg_sptr_crm_transfer_payment_line') }} ctpl
left join {{ ref('stg_sptr_crm_transfer_payment') }} ctp on ctpl.crm_transfer_payment_id = ctp.id and ctp.brand_etl = ctpl.brand_etl
left join {{ ref('stg_sptr_crm_line') }} clinef on ctpl.from_crm_line_id = clinef.id and clinef.brand_etl = ctpl.brand_etl
left join {{ ref('stg_sptr_crm_line') }} clinet on ctpl.to_crm_line_id = clinet.id and clinet.brand_etl = ctpl.brand_etl
left join {{ ref('stg_sptr_crm_line_product') }} clinepf on ctpl.from_crm_line_product_id = clinepf.id and clinepf.brand_etl = ctpl.brand_etl
left join {{ ref('stg_sptr_crm_line_product') }} clinept on ctpl.to_crm_line_product_id = clinept.id and clinept.brand_etl = ctpl.brand_etl
left join {{ ref('stg_sptr_crm_transfer_payment_line') }} ctplt
    on ctpl.crm_transfer_payment_id = ctplt.crm_transfer_payment_id
    and ctpl.to_crm_line_id = ctplt.from_crm_line_id
    and ctplt.brand_etl = ctpl.brand_etl
where ctpl.brand_etl in (1, 3, 4)
    and ctpl.transfer_amount <> 0 and ctp.state = 'done'
    and exists (
        select 1 from {{ ref('int_sptr_recent_crm_scope') }} s
        where s.crm_id = ctp.crm_id and s.brand_etl = ctpl.brand_etl
    )
)
-- Tương đương dftf.drop_duplicates('id'): self-join ctplt (tìm dòng transfer kế tiếp cùng phiếu, có
-- from_crm_line_id = to_crm_line_id của dòng hiện tại) có thể khớp > 1 dòng nếu 1 phiếu điều chuyển có
-- nhiều dòng cùng from_crm_line_id -- chỉ ảnh hưởng total_receivedt (cột duy nhất lấy từ ctplt), chọn
-- 1 dòng theo thứ tự cố định để kết quả build lại được (bản Python không có ORDER BY, thứ tự "đầu tiên"
-- không xác định rõ ràng).
select *
from (
    select raw.*, row_number() over (partition by id order by total_receivedt nulls last) as rn
    from raw
) t
where rn = 1
