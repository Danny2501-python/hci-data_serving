--- gộp 10 loại report, tương đương temp_output trong function op_convert_kangnam gốc
--- bản THV: bỏ cột chi_nhanh (không có custom field tương đương bên cs_custom_fields_thv),
--- dùng deal.assignee_username/assignee_group_name thay cho convert_by1/group_name_convert
--- vì convert_by hầu như rỗng bên THV (chỉ ~16/45276 deal có convert_by), còn assignee thì luôn có

with new_cus as (
    select * from {{ ref('rtc_new_cus') }}
),
chat as (
    select * from {{ ref('rtc_chat') }}
),
dv_moi as (
    select * from {{ ref('rtc_dv_moi') }}
),
deal as (
    select * from {{ ref('rtc_deal') }}
),
inbox_all as (
    select * from {{ ref('rtc_inbox_all') }}
),
crm_lead as (
    select * from {{ ref('rtc_crm_lead') }}
),
employees as (
    select * from {{ ref('rtc_employees') }}
),

inbox_new as (
    select
        'inbox_new' as type_report,
        date(vcnc.ngay_tao_khach) as ngay_tao_khach,
        vcnc.ticket_id as ticket_id,
        vcnc.ticket_source,
        vcnc.requester_id,
        vcdm.nhom_dv,
        c.agent_name as agent_name,
        c.group_name as group_name
    from new_cus vcnc
    left join chat c on c.ticket_id = vcnc.ticket_id
    left join dv_moi vcdm on vcdm.ticket_id = vcnc.ticket_id
),

--- convert_new: giống convert_all (tổng lead từ crm_lead) nhưng chỉ tính lead đầu tiên của mỗi
--- số điện thoại (sđt trước đó chưa từng tạo lead/booking nào khác)
convert_new as (
    select
        'convert_new' as type_report,
        date(cl.create_date_new) as ngay_tao_khach,
        cl.ticket_id as ticket_id,
        vcnc.ticket_source,
        cl.phone,
        vcdm.nhom_dv,
        e.employee as agent_name,
        e.department as group_name
    from (
        select distinct on (phone) *
        from crm_lead 
        where type_crm_id=1
        order by phone, create_date_new
    ) cl
    left join inbox_new vcnc on vcnc.ticket_id = cl.ticket_id
    left join dv_moi vcdm on vcdm.ticket_id = cl.ticket_id
    left join employees e on e.user_id = cl.create_uid
),

inbox_all_r as (
    select
        'inbox_all' as type_report,
        date(vcnc.created_at) as ngay_tao_khach,
        vcnc.ticket_id as ticket_id,
        vcnc.ticket_source,
        vcnc.requester_id,
        vcdm.nhom_dv,
        c.agent_name as agent_name,
        c.group_name as group_name
    from inbox_all vcnc
    left join chat c on c.ticket_id = vcnc.ticket_id
    left join dv_moi vcdm on vcdm.ticket_id = vcnc.ticket_id
),
sdt_ketnoi as (
    select
        'sdt_ketnoi' as type_report,
        date(cl.create_date_new) as ngay_tao_khach,
        cl.ticket_id as ticket_id,
        vcnc.ticket_source,
        cl.phone,
        vcdm.nhom_dv,
        ---cdda.assignee_username as
        se.employee agent_name,
        se.department -- as group_name
    from inbox_all vcnc
    ---left join deal cdda on cdda.id = vcnc.ticket_id
    left join dv_moi vcdm on vcnc.ticket_id = vcdm.ticket_id
    left join (select * from crm_lead where stage_id in (7, 8, 18) and type_crm_id= 1) cl  on cl.ticket_id = vcnc.ticket_id
    left join employees se on se.user_id =cl.create_uid
    where /*cdda.id is not null
    and */cl.ticket_id is not null
),

sdt_henlich as (
    select
        'sdt_henlich' as type_report,
        date(cl2.create_date_new) as ngay_tao_khach,
        cl2.ticket_id as ticket_id,
        vcnc.ticket_source,
        cl2.phone,
        ---vcnc.requester_id,
        vcdm.nhom_dv,
         se.employee agent_name,
        se.department -- as group_name
    from inbox_all vcnc
   --- left join deal cdda on cdda.id = vcnc.ticket_id
    left join dv_moi vcdm on vcdm.ticket_id = vcnc.ticket_id
    left join (
        select ticket_id, create_date_new, create_uid, phone from crm_lead
        where type_crm_id = 2
        and stage_id not in (23)
    ) cl2 on cl2.ticket_id = vcnc.ticket_id
    left join employees se on se.user_id =cl2.create_uid
    where/* cdda.id is not null
    and*/ cl2.ticket_id is not null
),

--- convert_all: tổng tất cả lead tạo ERP, không giới hạn stage_id như sdt_ketnoi/sdt_henlich,
--- thời điểm tạo là thời điểm tạo lead (create_date_new), nhân viên là người tạo lead (create_uid)
--- (thay thế convert_all cũ vốn lấy từ inbox_all+deal)
convert_all as (
    select
        'convert_all' as type_report,
        date(cl.create_date_new) as ngay_tao_khach,
        cl.ticket_id as ticket_id,
        vcnc.ticket_source,
        cl.phone,
        --vcnc.requester_id,
        vcdm.nhom_dv,
        e.employee as agent_name,
        e.department as group_name
    from (select * from crm_lead where type_crm_id=1) cl
    left join inbox_all vcnc on vcnc.ticket_id = cl.ticket_id
    left join dv_moi vcdm on vcdm.ticket_id = cl.ticket_id
    left join employees e on e.user_id = cl.create_uid
)

select * from inbox_new
union all
select * from convert_new
union all
select * from inbox_all_r
union all
select * from sdt_ketnoi
union all
select * from sdt_henlich
union all
select * from convert_all
