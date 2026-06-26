-- Tương đương bảng tạm tv1 trong func_data_vong_doi_khach_hang
-- brand_etl = 1 đã được lọc tại tầng stg

select
    ru2.id,
    ru2.partner_id,
    rp3."name"                                                                      as nv,
    case when hd2."name" is null then hd3."name" else hd2."name" end                as pb,
    case when hd2."name" is null then hd3.id     else hd2.id     end                as id_pb
from {{ ref('stg_rvdkk_res_users') }}      ru2
left join {{ ref('stg_rvdkk_res_partner') }}    rp3 on rp3.id = ru2.partner_id
left join {{ ref('stg_rvdkk_hr_employee') }}    he  on he.user_id = ru2.id
left join {{ ref('stg_rvdkk_hr_department') }}  hd2 on hd2.id = he.department_id
left join {{ ref('stg_rvdkk_hr_employee') }}    he2 on lower(he2.work_email) = lower(ru2.login)
left join {{ ref('stg_rvdkk_hr_department') }}  hd3 on hd3.id = he2.department_id
