{{
  config(
    materialized = 'table',
    alias        = 'stag_employees_test_dbt'
  )
}}
-- =============================================================================
-- stag_employees_test_dbt (Final output)
-- Ghi đè toàn bộ bảng stag_employees_test_dbt mỗi lần chạy.
-- =============================================================================
WITH hr_employee AS (
SELECT 
  he.id::int as id
  , he.user_id::int as user_id
  , he.employee_code
  , he.name employee
  , he.gender 
  , he.job_id::int as job_id, hj.name job
  , he.group_job::int group_job_id, hgj.name group_job
  , hd.name department
  , he.team_id::int as team_id, ht.name team
  , he.sector_id::int as sector_id, hds.name sector
  , COALESCE(hdc.id, he.department_id)::int as department_id
  , he.department_id::int old_department_id
  , he.company_id::int    --- , he.department_id phongbanphanquyen
  , he.staff_level
  , he.area
  , he.birthday::date
  , he.place_of_birth
  , he.identification_id::text
  , he.barcode
  , he.mobile_phone
  , he.work_email
  , he.create_date + interval '7 hours' as create_date
  , he.write_date + interval '7 hours' as write_date
  , he.active
  , he.resign_date
  , he.reason_resign 
  , rc.name company
  , he.brand_id::int as brand_id
  , rb.name brand
  , CASE   
      WHEN hekn.id::int IS NULL AND he.user_id < 10 THEN he.id::int 
      ELSE hekn.id::int
    END as kn_id
  , CASE
      WHEN hekn.user_id::int IS NULL AND he.user_id < 10 THEN he.user_id::int 
      ELSE hekn.user_id::int
    END as kn_user_id 
  , CASE 
      WHEN hepr.id::int IS NULL AND he.user_id < 10 THEN he.id::int 
      ELSE hepr.id::int
    END as pr_id
  , CASE
      WHEN hepr.user_id::int IS NULL AND he.user_id < 10 THEN he.user_id::int 
      ELSE hepr.user_id::int
    END as pr_user_id
  , CASE 
      WHEN hehh.id::int IS NULL AND he.user_id < 10 THEN he.id::int 
      ELSE hehh.id::int
    END as hh_id
  , CASE
      WHEN hehh.user_id::int IS NULL AND he.user_id < 10 THEN he.user_id::int 
      ELSE hehh.user_id::int
    END as hh_user_id
  , CASE
      WHEN COALESCE(hdc.id, he.department_id)::int = 2635 
        OR he.id = 3337 
        OR (he.company_id = 4 AND COALESCE(hdc.id, he.department_id)::int = 2599) THEN 2602
      ELSE COALESCE(hdc.id, he.department_id)::int
  END AS phongbanphanquyen
  , CASE 
      WHEN hedoc.id IS NOT NULL THEN hedoc.job_name 
      ELSE hj.name 
  END as job_lv2
  , row_number() over (partition by he.employee_code order by he.active,he.create_date asc) as row_num 
FROM {{source('pre_tns','hr_employee')}} he 
LEFT JOIN {{source('pre_tns','m_res_company')}} rc ON he.company_id = rc.id AND rc.brand_etl = he.brand_etl 
LEFT JOIN {{source('pre_tns','res_brand')}} rb ON rc.brand_id = rb.id AND rb.brand_etl = rc.brand_etl 
LEFT JOIN {{source('pre_tns','res_users')}} ru ON ru.id = he.user_id AND he.brand_etl = ru.brand_etl 
LEFT JOIN {{source('pre_tns','res_partner')}} rp ON rp.id = ru.partner_id AND ru.brand_etl = rp.brand_etl 
LEFT JOIN {{source('pre_tns','hr_department_sector')}} hds ON he.sector_id = hds.id AND he.brand_etl = hds.brand_etl 
LEFT JOIN {{source('pre_tns','hr_team')}} ht ON he.team_id = ht.id AND ht.brand_etl = he.brand_etl 
LEFT JOIN {{source('pre_tns','hr_job')}} hj ON he.job_id = hj.id AND he.brand_etl = hj.brand_etl 
LEFT JOIN {{source('pre_tns','hr_group_job')}} hgj ON he.group_job = hgj.id AND he.brand_etl = hgj.brand_etl 
LEFT JOIN {{source('pre_tns','stag_phongbanphanquyen_id')}} spi ON he.department_id = spi.department_id 
LEFT JOIN {{ref ('stg_pts_stag_employee_hdc')}} hdc ON spi.new_name = hdc.name
LEFT JOIN {{source('pre_tns','hr_department')}} hd ON COALESCE(hdc.id, he.department_id) = hd.id AND hd.brand_etl = 7
LEFT JOIN {{ref ('stg_pts_stag_employee_hekn')}} hekn ON he.employee_code = hekn.employee_code
LEFT JOIN {{ref ('stg_pts_stag_employee_hepr')}} hepr ON he.employee_code = hepr.employee_code
LEFT JOIN {{ref ('stg_pts_stag_employee_hehh')}} hehh ON he.employee_code = hehh.employee_code
LEFT JOIN {{ref('import_stag_employee_doctor')}} hedoc ON he.id = hedoc.id
--LEFT join lateral (select id, user_id, employee_code from hr_employee hehh where hehh.brand_etl = 4 and he.employee_code = hehh.employee_code order by active desc limit 1) hehh ON true
WHERE rc.brand_etl = 7 AND rb.brand_etl = 7 
	AND he.brand_etl = 7
)
SELECT * FROM hr_employee WHERE row_num = 1