with data_union as (
    select vk, ten_dv as dv, "Nguon", "Nhom_nguon", kenh, date, nhom_dv, chi_nhanh, local_k, quoc_gia, "Metric", type_data, ticket_id, 'campaign'::text as campaign
    from {{ ref('frmack_stg_cte_data_kh') }}
    
    union all
    
    select vk, "DV/SP" as dv, "Nguon", "Nhom_nguon", channel as kenh, date_ds as date, nhom_dv, location as chi_nhanh, local_k, quoc_gia, "Metric", type_data, ticket_id, 'campaign'::text as campaign
    from {{ ref('frmack_stg_data_ds') }}
    
    union all
    
    select vk, dv as dv, "Nguon", "Nhom_nguon", kenh, date, nhom_dv, chi_nhanh, local_k, quoc_gia, "Metric", type_data, ticket_id, 'campaign'::text as campaign
    from {{ ref('frmack_stg_data_inbox') }}
    
    union all
    
    select vk, dv as dv, "Nguon", "Nhom_nguon", channel as kenh, ngay as date, nhom_dv, chi_nhanh, local_k, quoc_gia, "Metric", data_type as type_data, ticket_id, campaign
    from {{ ref('frmack_stg_data_gg') }}
),

re_map as (
    select 
        *, 
        case 
            when local_k ilike '%thành phố%' then REGEXP_REPLACE(local_k::text, '^Thành phố\s*', '') 
            when local_k ilike '%Tỉnh%' then REGEXP_REPLACE(local_k::text, '^Tỉnh\s*', '') 
            when local_k ilike '%Bà Rịa%' then 'Bà Rịa – Vũng Tàu' 
            when local_k ilike '%VIỆT KIỀU%' then 'VIỆT KIỀU' 
            else local_k::text 
        end as tinh_noi
    from data_union
),

final_rep as (
    select 
        r.*, 
        case 
            when r.tinh_noi = 'Bà Rịa - Vũng Tàu' then 'Hồ Chí Minh và lân cận' 
            when r.tinh_noi = 'Lào Cai' then 'Miền Bắc mở rộng' 
            when r.tinh_noi = 'Yên Bái' then 'Miền Bắc mở rộng' 
            when r.tinh_noi = 'Thừa Thiên - Huế' then 'Đà nẵng lân cận' 
            when r.tinh_noi = 'KXĐ' then 'KXĐ' 
            else grm.region 
        end as region 
    from re_map r 
    left join {{ source('master_data', 'ggs_region_map') }} grm on grm.location = r.tinh_noi::text
),

ss as (
    select
        fr.vk,
        fr.dv,
        fr."Nguon",
        fr."Nhom_nguon",
        fr.kenh,
        fr.date as ngay,
        fr.nhom_dv,
        fr.chi_nhanh,
        fr.local_k,
        fr.quoc_gia,
        fr."Metric",
        fr.type_data,
        mms.service_name as page,
        mms.page_id,
        fr.region,
        fr.tinh_noi,
        fr.campaign,
        null::text as account_fb
    from (select * from final_rep where ticket_id <> 0) fr
    left join {{ ref('frmack_stg_cs_ticket_mapping') }} mcp on mcp.ticket_id = fr.ticket_id
    left join {{ ref('frmack_stg_cs_service_mapping') }} mms on mms.service_id = mcp.service_id
    
    union all
    
    select
        fr.vk,
        fr.dv,
        fr."Nguon",
        fr."Nhom_nguon",
        fr.kenh,
        fr.date as ngay,
        fr.nhom_dv,
        fr.chi_nhanh,
        fr.local_k,
        fr.quoc_gia,
        fr."Metric",
        fr.type_data,
        'KXĐ' as page,
        'KXĐ' as page_id,
        fr.region,
        fr.tinh_noi,
        fr.campaign,
        null::text as account_fb
    from final_rep fr 
    where (fr.ticket_id = 0 or fr.ticket_id is null )
)

select * from ss
