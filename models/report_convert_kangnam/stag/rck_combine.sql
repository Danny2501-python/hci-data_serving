--- gộp 10 loại report, tương đương temp_output trong function op_convert_kangnam gốc

with new_cus as (
    select * from {{ ref('rck_new_cus') }}
),
chat as (
    select * from {{ ref('rck_chat') }}
),
dv_moi as (
    select * from {{ ref('rck_dv_moi') }}
),
custom_fields as (
    select * from {{ ref('rck_custom_fields') }}
),
deal as (
    select * from {{ ref('rck_deal') }}
),
inbox_all as (
    select * from {{ ref('rck_inbox_all') }}
),
crm_lead as (
    select * from {{ ref('rck_crm_lead') }}
),

inbox_new as (
    select
        'inbox_new' as type_report,
        date(vcnc.ngay_tao_khach) as ngay_tao_khach,
        vcnc.ticket_id as ticket_id,
        vcnc.ticket_source,
        vcnc.requester_id,
        vcnc.chi_nhanh,
        vcdm.nhom_dv,
        c.agent_name as agent_name,
        c.group_name as group_name,
        ccf.value_lable as chinhanh
    from new_cus vcnc
    left join chat c on c.ticket_id = vcnc.ticket_id
    left join dv_moi vcdm on vcdm.ticket_id = vcnc.ticket_id
    left join custom_fields ccf on ccf.value_id = vcnc.chi_nhanh
),

convert_new as (
    select
        'convert_new' as type_report,
        date(vcnc.ngay_tao_khach) as ngay_tao_khach,
        cdda.id as ticket_id,
        vcnc.ticket_source,
        vcnc.requester_id,
        vcnc.chi_nhanh,
        vcdm.nhom_dv,
        cdda.convert_by1 as agent_name,
        cdda.group_name_convert as group_name,
        ccf.value_lable as chinhanh
    from new_cus vcnc
    left join dv_moi vcdm on vcdm.ticket_id = vcnc.ticket_id
    left join deal cdda on cdda.id = vcnc.ticket_id
    left join custom_fields ccf on ccf.value_id = vcnc.chi_nhanh
    where cdda.id is not null
),

inbox_all_r as (
    select
        'inbox_all' as type_report,
        date(vcnc.created_at) as ngay_tao_khach,
        vcnc.ticket_id as ticket_id,
        vcnc.ticket_source,
        vcnc.requester_id,
        vcnc.chi_nhanh,
        vcdm.nhom_dv,
        c.agent_name as agent_name,
        c.group_name as group_name,
        ccf.value_lable as chinhanh
    from inbox_all vcnc
    left join chat c on c.ticket_id = vcnc.ticket_id
    left join dv_moi vcdm on vcdm.ticket_id = vcnc.ticket_id
    left join custom_fields ccf on ccf.value_id = vcnc.chi_nhanh
),

convert_all_r as (
    select
        'convert_all' as type_report,
        date(vcnc.created_at) as ngay_tao_khach,
        cdda.id as ticket_id,
        vcnc.ticket_source,
        vcnc.requester_id,
        vcnc.chi_nhanh,
        vcdm.nhom_dv,
        cdda.convert_by1 as agent_name,
        cdda.group_name_convert as group_name,
        ccf.value_lable as chinhanh
    from inbox_all vcnc
    left join deal cdda on cdda.id = vcnc.ticket_id
    left join dv_moi vcdm on vcdm.ticket_id = vcnc.ticket_id
    left join custom_fields ccf on ccf.value_id = vcnc.chi_nhanh
    where cdda.id is not null
),

sdt_ketnoi as (
    select
        'sdt_ketnoi' as type_report,
        date(vcnc.created_at) as ngay_tao_khach,
        cl.ticket_id as ticket_id,
        vcnc.ticket_source,
        vcnc.requester_id,
        vcnc.chi_nhanh,
        vcdm.nhom_dv,
        cdda.convert_by1 as agent_name,
        cdda.group_name_convert as group_name,
        ccf.value_lable as chinhanh
    from inbox_all vcnc
    left join deal cdda on cdda.id = vcnc.ticket_id
    left join dv_moi vcdm on vcdm.ticket_id = cdda.id
    left join custom_fields ccf on ccf.value_id = vcnc.chi_nhanh
    left join (select * from crm_lead where stage_id in (7, 8, 18)) cl on cl.ticket_id = cdda.id
    where cdda.id is not null
    and cl.ticket_id is not null
),

sdt_henlich as (
    select
        'sdt_henlich' as type_report,
        date(vcnc.created_at) as ngay_tao_khach,
        cl2.ticket_id as ticket_id,
        vcnc.ticket_source,
        vcnc.requester_id,
        vcnc.chi_nhanh,
        vcdm.nhom_dv,
        cdda.convert_by1 as agent_name,
        cdda.group_name_convert as group_name,
        ccf.value_lable as chinhanh
    from inbox_all vcnc
    left join deal cdda on cdda.id = vcnc.ticket_id
    left join dv_moi vcdm on vcdm.ticket_id = cdda.id
    left join custom_fields ccf on ccf.value_id = vcnc.chi_nhanh
    left join (
        select ticket_id from crm_lead
        where type_crm_id = 2
        and stage_id not in (23)
    ) cl2 on cl2.ticket_id = cdda.id
    where cdda.id is not null
    and cl2.ticket_id is not null
),

convert_new1 as (
    select
        'convert_new1' as type_report,
        date(cdda.convert_at) as ngay_tao_khach,
        cdda.id as ticket_id,
        vcnc.ticket_source,
        vcnc.requester_id,
        vcnc.chi_nhanh,
        vcdm.nhom_dv,
        cdda.convert_by1 as agent_name,
        cdda.group_name_convert as group_name,
        ccf.value_lable as chinhanh
    from new_cus vcnc
    left join dv_moi vcdm on vcdm.ticket_id = vcnc.ticket_id
    left join deal cdda on cdda.id = vcnc.ticket_id
    left join custom_fields ccf on ccf.value_id = vcnc.chi_nhanh
    where cdda.id is not null
),

convert_all1 as (
    select
        'convert_all1' as type_report,
        date(cdda.convert_at) as ngay_tao_khach,
        cdda.id as ticket_id,
        vcnc.ticket_source,
        vcnc.requester_id,
        vcnc.chi_nhanh,
        vcdm.nhom_dv,
        cdda.convert_by1 as agent_name,
        cdda.group_name_convert as group_name,
        ccf.value_lable as chinhanh
    from inbox_all vcnc
    left join deal cdda on cdda.id = vcnc.ticket_id
    left join dv_moi vcdm on vcdm.ticket_id = vcnc.ticket_id
    left join custom_fields ccf on ccf.value_id = vcnc.chi_nhanh
    where cdda.id is not null
),

sdt_ketnoi1 as (
    select
        'sdt_ketnoi1' as type_report,
        date(cl.create_date_new) as ngay_tao_khach,
        cl.ticket_id as ticket_id,
        vcnc.ticket_source,
        vcnc.requester_id,
        vcnc.chi_nhanh,
        vcdm.nhom_dv,
        cdda.convert_by1 as agent_name,
        cdda.group_name_convert as group_name,
        ccf.value_lable as chinhanh
    from inbox_all vcnc
    left join deal cdda on cdda.id = vcnc.ticket_id
    left join dv_moi vcdm on vcdm.ticket_id = cdda.id
    left join custom_fields ccf on ccf.value_id = vcnc.chi_nhanh
    left join (select * from crm_lead where stage_id in (7, 8, 18)) cl on cl.ticket_id = cdda.id
    where cdda.id is not null
    and cl.ticket_id is not null
),

sdt_henlich1 as (
    select
        'sdt_henlich1' as type_report,
        date(cl2.create_date_new) as ngay_tao_khach,
        cl2.ticket_id as ticket_id,
        vcnc.ticket_source,
        vcnc.requester_id,
        vcnc.chi_nhanh,
        vcdm.nhom_dv,
        cdda.convert_by1 as agent_name,
        cdda.group_name_convert as group_name,
        ccf.value_lable as chinhanh
    from inbox_all vcnc
    left join deal cdda on cdda.id = vcnc.ticket_id
    left join dv_moi vcdm on vcdm.ticket_id = cdda.id
    left join custom_fields ccf on ccf.value_id = vcnc.chi_nhanh
    left join (
        select ticket_id, create_date_new from crm_lead
        where type_crm_id = 2
        and stage_id not in (23)
    ) cl2 on cl2.ticket_id = cdda.id
    where cdda.id is not null
    and cl2.ticket_id is not null
)

select * from inbox_new
union all
select * from convert_new
union all
select * from inbox_all_r
union all
select * from convert_all_r
union all
select * from sdt_ketnoi
union all
select * from sdt_henlich
union all
select * from convert_new1
union all
select * from convert_all1
union all
select * from sdt_ketnoi1
union all
select * from sdt_henlich1
