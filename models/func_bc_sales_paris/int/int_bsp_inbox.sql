-- =============================================================================
-- int_bsp_inbox  (Pass 3)
-- Inbox Facebook: lấy rank=1 (cuộc hội thoại đầu tiên mỗi khách),
-- map nhóm dịch vụ qua cs_custom_fields_kh, chi nhánh qua cs_company + m_res_company.
-- phong_ban: nếu là sales thuộc table_team_sale_paris → tên team, ngược lại lấy từ CRM.
-- =============================================================================
SELECT
    a.ad_id,
    'Inbox'::text                                                      AS bang,
    TEXT(a.ticket)                                                     AS ticket_id,
    TEXT(a.khach_id)                                                   AS requester_id,
    UPPER(tts.name)                                                    AS nv,
    tts.work_email,
    a.ngay_tao_khach                                                   AS date,
    a.nguon,
    chi_nhanh.name                                                     AS chi_nhanh,
    ccfk.value_lable                                                   AS nhom_dv,
    a.username                                                         AS ten_khach,
    NULL::text                                                         AS ma_booking,
    CASE WHEN tts.work_email IS NOT NULL
         THEN 'Sales & Marketing Thương hiệu Paris'
         ELSE vseu.department
    END                                                                AS phong_ban
FROM {{ ref('stg_bsp_ranked_contacts') }} a
LEFT JOIN {{ ref('stg_bsp_cs_service_category') }} x
       ON x.id = a.khach_id
LEFT JOIN {{ source('paris', 'cs_custom_fields_kh') }} ccfk
       ON ccfk.value_id = x.extracted_value_not_null
LEFT JOIN {{ ref('stg_bsp_cs_company') }} cc
       ON TEXT(cc.ticket_id) = TEXT(a.ticket)
LEFT JOIN {{ source('paris', 'cs_custom_fields') }} ccf2
       ON cc.extracted_value = ccf2.value_id
LEFT JOIN {{ source('paris', 'm_res_company') }} chi_nhanh
       ON chi_nhanh.brand_etl = 3
      AND chi_nhanh.company_code = REPLACE(
              LEFT(ccf2.value_lable, POSITION(']' IN ccf2.value_lable) - 1),
              '[', '')
LEFT JOIN {{ source('paris', 'table_team_sale_paris') }} tts
       ON tts.work_email = a.mail_nv
LEFT JOIN {{ source('paris', 'view_stag_employees_user') }} vseu
       ON vseu.work_email = a.mail_nv AND vseu.brand_etl = 3
LEFT JOIN {{ source('paris', 'm_facebook_page_kangnam') }} mfpk
       ON mfpk.id = a.page_fb
WHERE a.rank = 1
