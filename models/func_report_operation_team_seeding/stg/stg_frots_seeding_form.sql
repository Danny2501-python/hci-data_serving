-- Pass 1.1: Seeding Form từ Odoo (dịch thẳng từ v1 cte_seeding_form)
{% set start_date = var('start_date', '2025-08-01') %}

SELECT
    a.*,
    ifps.page_name,
    ifps.doctor,
    ifps.page_link
FROM {{ source('frots', 'seeding_form') }} a
LEFT JOIN {{ source('frots', 'import_fb_page_seeding') }} ifps
    ON a.interactive_proof = ifps.page_link
WHERE a.response ILIKE '%Seeding%'
  AND a.create_day::DATE >= '{{ start_date }}'
  AND a.user_id <> 25
