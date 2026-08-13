{{
  config(
    materialized = 'view',
    alias        = 'view_his_evaluation_survey'
  )
}}
-- =============================================================================
-- view_his_evaluation_survey
-- Backup logic từ view cũ trên sandbox (staging_sci @ 10.10.10.226) vào dbt để
-- có chỗ tra cứu lại nếu sau này bị mất/sửa nhầm ở nguồn. Sandbox là bản lưu
-- tĩnh (dbt không chạy ở đó) nên không có rủi ro DROP CASCADE, nhưng đưa vào
-- dbt/git để có version control + không phụ thuộc 1 bản duy nhất trên sandbox.
-- Logic giữ NGUYÊN VẸN so với view gốc, chỉ thay tên bảng thô bằng macro
-- source()/ref(), không sửa bất kỳ điều kiện lọc nào.
-- =============================================================================

 SELECT seshmdr.surgery_history_id,
    sme.id AS evaluation_id,
    sme.name AS form_name,
    sp.product,
    se.employee AS main_doctor,
    se.job AS main_doctor_job,
    ses.employee AS sub_doctor,
    ses.job AS sub_doctor_job,
    smeshs.doctor_attitude,
    smeshs.satisfaction_level,
    smesh.surgery_date,
    sp.product_id,
    smhcs.id AS service_id,
    se.id AS main_doctor_id,
    se.employee_code AS main_doctor_code,
    ses.id AS sub_doctor_id,
    ses.employee_code AS sub_doctor_code,
    sme.his_company
   FROM {{ source('ovs_source', 'sh_medical_evaluation_surgery_history_survey') }} smeshs
     LEFT JOIN {{ source('ovs_source', 'sh_medical_evaluation') }} sme ON smeshs.sh_evaluation_surgery_id = sme.id
     LEFT JOIN {{ source('ovs_source', 'sh_medical_evaluation_surgery_history') }} smesh ON smeshs.evaluation_surgery_history_id = smesh.id
     LEFT JOIN {{ source('ovs_source', 'sh_medical_health_center_service') }} smhcs ON smesh.service_performances = smhcs.id
     LEFT JOIN {{ ref('stag_products') }} sp ON smhcs.product_id = sp.product_id
     LEFT JOIN {{ source('ovs_source', 'sh_evaluation_surgery_history_main_doctor_rel') }} seshmdr ON smesh.id = seshmdr.surgery_history_id
     LEFT JOIN {{ source('ovs_source', 'sh_medical_physician') }} smpm ON seshmdr.main_doctor_id = smpm.id
     LEFT JOIN {{ ref('stag_employees') }} se ON smpm.employee_id = se.id
     LEFT JOIN {{ source('ovs_source', 'sh_evaluation_surgery_history_sub_doctor_rel') }} seshsd ON smesh.id = seshsd.surgery_history_id
     LEFT JOIN {{ source('ovs_source', 'sh_medical_physician') }} smpms ON seshsd.sub_doctor_id = smpms.id
     LEFT JOIN {{ ref('stag_employees') }} ses ON smpms.employee_id = ses.id
