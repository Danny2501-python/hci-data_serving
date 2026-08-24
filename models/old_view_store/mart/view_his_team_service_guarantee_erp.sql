{{
  config(
    materialized = 'view',
    alias        = 'view_his_team_service_guarantee_erp'
  )
}}
-- =============================================================================
-- view_his_team_service_guarantee_erp
-- Backup logic từ view cũ trên sandbox (staging_sci @ 10.10.10.226) vào dbt để
-- có chỗ tra cứu lại nếu sau này bị mất/sửa nhầm ở nguồn. Sandbox là bản lưu
-- tĩnh (dbt không chạy ở đó) nên không có rủi ro DROP CASCADE, nhưng đưa vào
-- dbt/git để có version control + không phụ thuộc 1 bản duy nhất trên sandbox.
-- Logic giữ NGUYÊN VẸN so với view gốc, chỉ thay tên bảng thô bằng macro
-- source()/ref(), không sửa bất kỳ điều kiện lọc nào.
-- =============================================================================

 SELECT shts.id,
    shts.ck_pttt,
    shts.services_date,
    shts.services_end_date,
    shts.product_id,
    shts.rn_walkin_product,
    shts.state_ckpttt,
    shts.walkinid,
    shts.walkin,
    shts.state_walkin,
    shts.employee_id,
    shts.roleid,
    shts.order_priorole,
    shts.dr_order_role,
    shts.department,
    shts.room,
    shts.company_id,
    shts.crm_id,
    shts.partner_id,
    shts.sale_order_id,
    shts.is_new_request,
    shts.team_service_id,
    shts.min_order_priorole,
    shts.form_id,
    shts.rn_walkin_product_fix,
    sp.product_ctg_id,
    concat(shts.sale_order_id, '-', shts.product_id) AS order_product_id
   FROM {{ source('ovs_source', 'stag_his_team_service') }} shts
     LEFT JOIN {{ ref('stag_products') }} sp ON shts.product_id = sp.product_id
  WHERE (shts.crm_id IN ( SELECT DISTINCT crm_lead.lead_id
           FROM {{ source('ovs_source', 'crm_lead') }}
          WHERE crm_lead.type_crm_id = 3)) AND (shts.dr_order_role::numeric = 1::numeric OR shts.roleid::numeric = 1::numeric)
