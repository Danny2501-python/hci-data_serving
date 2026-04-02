with re_map as (
    select 
        *, 
        case 
            when vung ilike '%thành phố%' then REGEXP_REPLACE(vung::text, '^Thành phố\s*', '') 
            when vung ilike '%Tỉnh%' then REGEXP_REPLACE(vung::text, '^Tỉnh\s*', '') 
            when vung ilike '%Bà Rịa%' then 'Bà Rịa – Vũng Tàu' 
            when vung ilike '%VIỆT KIỀU%' then 'VIỆT KIỀU' 
            else vung::text
        end as tinh_noi
    from {{ ref('frmack_stg_cost_fb_1') }}
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
    left join {{ source('master_data', 'ggs_region_map') }} grm on grm.location = r.tinh_noi
),

cost as (
    select 
        fr.vk,
        fr.dv,
        fr."Nguon",
        fr."Nhom_nguon",
        'FB'::text as kenh,
        fr.ngay_chi_phi as ngay,
        fr.nhom_dv,
        case
            when upper(fr.chi_nhanh_no_camp) = 'HCM'::text then 'BỆNH VIỆN KANGNAM SÀI GÒN'::text
            when upper(fr.chi_nhanh_no_camp) = 'HỒ CHÍ MINH'::text then 'BỆNH VIỆN KANGNAM SÀI GÒN'::text
            when upper(fr.chi_nhanh_no_camp) = 'HÀ NỘI'::text then 'BỆNH VIỆN KANGNAM HÀ NỘI'::text
            when fr.chi_nhanh_no_camp = 'VIỆT KIỀU'::text then 'VIỆT KIỀU'::text
            when upper(fr.chi_nhanh_no_camp) = 'BẮC NINH'::text then 'VIỆN THẨM MỸ KANGNAM BẮC NINH'::text
            when upper(fr.chi_nhanh_no_camp) = 'HẢI PHÒNG'::text then 'VIỆN THẨM MỸ KANGNAM HẢI PHÒNG'::text
            when upper(fr.chi_nhanh_no_camp) = 'BUÔN MÊ THUỘT'::text then 'VIỆN THẨM MỸ KANGNAM BUÔN MA THUỘT'::text
            when upper(fr.chi_nhanh_no_camp) = 'ĐÀ NẴNG'::text then 'VIỆN THẨM MỸ KANGNAM ĐÀ NẴNG'::text
            when upper(fr.chi_nhanh_no_camp) = 'CẦN THƠ'::text then 'VIỆN THẨM MỸ KANGNAM CẦN THƠ'::text
            when upper(fr.chi_nhanh_no_camp) = 'NGHỆ AN'::text then 'VIỆN THẨM MỸ KANGNAM NGHỆ AN'::text
            when upper(fr.chi_nhanh_no_camp) = 'THÁI NGUYÊN'::text then 'VIỆN THẨM MỸ KANGNAM THÁI NGUYÊN'::text
            when upper(fr.chi_nhanh_no_camp) = 'THANH HÓA'::text then 'VIỆN THẨM MỸ KANGNAM THANH HÓA'::text
            when upper(fr.chi_nhanh_no_camp) = 'BÌNH DƯƠNG'::text then 'VIỆN THẨM MỸ KANGNAM BÌNH DƯƠNG'::text
            else fr.chi_nhanh_no_camp
        end as chi_nhanh,
        fr.vung as local_k,
        case
            when fr.chi_nhanh_no_camp = 'VIỆT KIỀU'::text then 'VIỆT KIỀU'::text
            when fr.chi_nhanh_no_camp = 'QUỐC TẾ'::text then 'QUỐC TẾ'::text
            else 'Việt Nam'::text
        end as quoc_gia,
        fr.chi_phi::text as "Metric",
        fr.type_data,
        mcp.service_name as page,
        fr.page_id,
        fr.region,
        fr.tinh_noi,
        fr.camp_name as campaign,
        fr.account_fb
    from final_rep fr
    left join (
        select *, row_number() over(partition by page_id order by created_at desc ) rnk
        from {{ ref('frmack_stg_cs_service_mapping') }}
    ) mcp on text(fr.page_id) = text(mcp.page_id) and mcp.rnk = 1
)

select * from cost
