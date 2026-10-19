-- stg_rks_invite_service: gộp dịch vụ của phiếu khảo sát về 1 dòng / invite
-- (1 invite có thể gắn nhiều dịch vụ qua kn_survey_cms_invite_service_rel)
SELECT
    r.invite_id,
    r.brand_etl,
    string_agg(r.service_id::text, ', ' ORDER BY r.service_id)  as service_ids,
    string_agg(sp.product, ', ' ORDER BY r.service_id)          as dich_vu,
    -- nhóm dịch vụ = view_stag_products.product_group (giống common/stg_booking_nhom_dich_vu_chinh), bỏ trùng
    string_agg(DISTINCT sp.product_group, ', ')                 as nhom_dich_vu
FROM {{ source('kn_survey', 'kn_survey_cms_invite_service_rel') }} r
    left join {{ source('kn_survey', 'sh_medical_health_center_service') }} smhcs on smhcs.id = r.service_id and smhcs.brand_etl = r.brand_etl
    left join {{ source('kn_survey', 'view_stag_products') }} sp on sp.product_id = smhcs.product_id and sp.brand_etl = smhcs.brand_etl
GROUP BY r.invite_id, r.brand_etl
