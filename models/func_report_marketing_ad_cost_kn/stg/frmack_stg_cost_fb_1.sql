with b as (
    select 
        cfaai.fb_ad_ad_id as ad_id,
        case
            when cfaai.fb_account_currency::text = 'USD'::text then cfaai.spend * tgt.bidrateck::double precision
            else cfaai.spend
        end as chi_phi,
        nullif(cfaai.date::text, '')::date as ngay_chi_phi,
        cfaai.region as vung,
        cfaa.name as ten_ad,
        cfac2.name as camp_name,
        split_part(cfac2.name::text, '_'::text, 1) as cn,
        split_part(cfac2.name::text, '_'::text, 2) as cn2,
        cfaa2.name as page,
        lka."chi nhánh" as chi_nhanh_no_camp,
        cfaai.id as key,
        case
            when cfaa2.ad_account_id::text = '651294956930454'::text then 'Cost_fb_th'::text
            else 'Cost_fb_cd'::text
        end as type_data,
        split_part(cac.fb_effective_object_story_id::text, '_'::text, 1) as page_id,
        case 
             when cfac2.name ilike '%nh%' then 'VIỆT KIỀU'
             when cfac2.name ilike '%hải ngoại%' then 'VIỆT KIỀU'
             when cfac2.name ilike '%QUOC TE%' then 'QUỐC TẾ'
             else 'no'
        end as vk,
        'DV'::character varying as dv,
        'CP'::character varying as "Nguon",
        'CP'::character varying as "Nhom_nguon",
        cfaa2.name as account_fb
    from {{ source('ads_raw_data', 'core_facebook_ad_ad_insight') }} cfaai
    left join {{ source('ads_raw_data', 'core_facebook_ad_ad') }} cfaa on cfaa.fb_ad_ad_id::text = cfaai.fb_ad_ad_id::text
    left join {{ source('ads_raw_data', 'core_facebook_ad_creative') }} cac on cac.fb_ad_creative_id::text = cfaa.fb_creative_id::text
    left join {{ source('ads_raw_data', 'core_facebook_ad_set') }} cfas on cfas.fb_ad_set_id::text = cfaa.fb_ad_set_id::text
    left join {{ source('ads_raw_data', 'core_facebook_ad_campaign') }} cfac2 on cfac2.fb_ad_campaign_id::text = cfas.fb_ad_campaign_id::text
    left join {{ source('ads_raw_data', 'core_facebook_ad_account') }} cfaa2 on cfaa2.ad_account_id::text = cfac2.fb_ad_account_id::text
    left join lateral ( 
        select 
            tgt_1.bidrateck,
            tgt_1.date
        from {{ source('master_data', 'ty_gia_techcombank') }} tgt_1
        where tgt_1.label::text = 'USD (50,100)'::text and nullif(cfaai.date::text, '')::date >= tgt_1.date
        order by tgt_1.date desc
        limit 1
    ) tgt on true
    left join lateral ( 
        select 
            lka_1.tinh,
            lka_1."chi nhánh",
            lka_1.ngay_hh
        from {{ source('master_data', 'location_kangnam_adnet') }} lka_1
        where lka_1.tinh = cfaai.region::text and nullif(cfaai.date::text, '')::date >= lka_1.ngay_hh
        order by lka_1.ngay_hh desc
        limit 1
    ) lka on true
    where cfaa2.current_brand_id = 1 and nullif(cfaai.date::text, '')::date >= '20250801'
),

final as (
    select 
        b.*,
        upper(trim(both from split_part(b.camp_name::text, '_'::text, 2))) as nhom_dv,
        upper(trim(both from split_part(b.camp_name::text, '_'::text, 3))) as nhom_dv2
    from b
)

select * from final
