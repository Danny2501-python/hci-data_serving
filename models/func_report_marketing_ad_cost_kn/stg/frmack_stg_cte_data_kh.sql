with cte_crm_lead as (
    select cl.*
    from {{ source('erp', 'crm_lead') }} cl
    where cl.brand_etl = 1 and cl.create_by_department is not null
),

cte_data_kh as (
    with x as (
        select
            stks.*,
            extract(month from nullif(stks.date_time::text, '')::timestamp) as month_date,
            case
                when stks.nguon_moi ~~ '%Facebook%'::text then 'FB'::text
                when stks.nguon_moi ~~ '%Seo%'::text then 'Web'::text
                when stks.nguon_moi ~~ '%Google%'::text then 'Web'::text
                when stks.nguon_moi ~~ '%Hotline%'::text then 'Web'::text
                else 'Khác'::text
            end as kenh,
            case
                when rcs.name::text = 'Thành phố Hồ Chí Minh'::text then 'SÀI GÒN'::character varying
                when rcs.name::text = 'Thành phố Hà Nội'::text then 'Hà Nội'::character varying
                when rcs.name is null then 'KXĐ'::character varying
                when rcs.code::text !~~ '%VN-%'::text then 'VIỆT KIỀU'::character varying
                else rcs.name
            end as local_k,
            rc.name as quoc_gia,
            cl.ticket_id
        from {{ source('master_data', 'stag_tongquan_khachhang_sm') }} stks
        join cte_crm_lead cl on cl.id = stks.id
        left join {{ source('master_data', 'res_country_state') }} rcs on rcs.id = cl.state_id and rcs.brand_etl = 1
        left join {{ source('master_data', 'res_country') }} rc on rc.id = cl.country_id and rc.brand_etl = 1
    )
    select
        x.*,
        x.nguon_moi as "Nguon",
        x.nhom_nguon_moi as "Nhom_nguon",
        case
            when x.chi_nhanh::text = 'VIỆN THẨM MỸ KANGNAM BẠCH MAI'::text then 'BỆNH VIỆN KANGNAM HÀ NỘI'::character varying
            when x.chi_nhanh::text = 'BỆNH VIỆN KANGNAM NGUYỄN TRÃI'::text then 'BỆNH VIỆN KANGNAM SÀI GÒN'::character varying
            when x.chi_nhanh::text = 'BỆNH VIỆN KANGNAM SÀI GÒN'::text then 'BỆNH VIỆN KANGNAM SÀI GÒN'::character varying
            else x.chi_nhanh
        end as chi_nhanh_new
    from x
),

base_metrics as (
    select
        vk,
        ten_dv,
        "Nguon",
        "Nhom_nguon",
        kenh,
        ngay_den_cua as date,
        nhom_dv,
        chi_nhanh_new as chi_nhanh,
        local_k,
        quoc_gia,
        sdt as "Metric",
        'DC'::text as type_data,
        ticket_id
    from cte_data_kh
    where nullif(ngay_den_cua::text, '')::timestamp >= TIMESTAMP '2025-08-01 00:00:00' 
    and nhom_dv <> 'SAN PHAM' and loai_ban_ghi = 2

    union all

    select
        vk,
        ten_dv,
        "Nguon",
        "Nhom_nguon",
        kenh,
        ngay_den_cua as date,
        nhom_dv,
        chi_nhanh_new as chi_nhanh,
        local_k,
        quoc_gia,
        sdt as "Metric",
        'TC'::text as type_data,
        ticket_id 
    from cte_data_kh
    where nullif(ngay_den_cua::text, '')::timestamp >= TIMESTAMP '2025-08-01 00:00:00' 
    and nhom_dv <> 'SAN PHAM' and tong_tien > 0 and loai_ban_ghi = 2

    union all

    select
        vk,
        ten_dv,
        "Nguon",
        "Nhom_nguon",
        kenh,
        ngay_tao as date,
        nhom_dv,
        chi_nhanh_new as chi_nhanh,
        local_k,
        quoc_gia,
        sdt as "Metric",
        'Lead'::text as type_data,
        ticket_id 
    from cte_data_kh
    where nullif(ngay_tao::text, '')::timestamp >= TIMESTAMP '2025-08-01 00:00:00' 
    and nhom_dv <> 'SAN PHAM' and loai_ban_ghi = 1

    union all

    select
        vk,
        ten_dv,
        "Nguon",
        "Nhom_nguon",
        kenh,
        ngay_tao as date,
        nhom_dv,
        chi_nhanh_new as chi_nhanh,
        local_k,
        quoc_gia,
        sdt as "Metric",
        'BKHL'::text as type_data,
        ticket_id 
    from cte_data_kh
    where nullif(ngay_tao::text, '')::timestamp >= TIMESTAMP '2025-08-01 00:00:00' 
    and nhom_dv <> 'SAN PHAM' and loai_ban_ghi = 2

    union all

    select
        vk,
        ten_dv,
        "Nguon",
        "Nhom_nguon",
        kenh,
        ngay_hl as date,
        nhom_dv,
        chi_nhanh_new as chi_nhanh,
        local_k,
        quoc_gia,
        sdt as "Metric",
        'HL'::text as type_data,
        ticket_id 
    from cte_data_kh
    where nullif(ngay_hl::text, '')::timestamp >= TIMESTAMP '2025-08-01 00:00:00' 
    and nhom_dv <> 'SAN PHAM' and loai_ban_ghi = 2
)

select * from base_metrics


