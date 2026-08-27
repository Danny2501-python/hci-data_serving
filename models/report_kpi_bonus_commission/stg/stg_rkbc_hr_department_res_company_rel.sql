select * from {{ source('rkbc_source', 'hr_department_res_company_rel') }}
