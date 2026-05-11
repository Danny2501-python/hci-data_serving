SELECT ('m_res_company'::text) AS "Table Name",
  "m_res_company+"."brand_etl" AS "brand_etl",
  "m_res_company+"."brand_id" AS "brand_id",
  "m_res_company+"."company_code" AS "company_code",
  "m_res_company+"."id" AS "id",
  "m_res_company+"."location" AS "location",
  "m_res_company+"."name" AS "name",
  "m_res_company+"."write_date" AS "write_date"
FROM {{ source('rmkdt', 'm_res_company') }} "m_res_company+"
