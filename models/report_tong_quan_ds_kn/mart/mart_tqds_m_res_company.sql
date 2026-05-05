{{ config(alias='mart_m_res_company') }}

SELECT ('m_res_company'::text) AS "Table Name",
  mrc."brand_etl" AS "brand_etl",
  mrc."brand_id" AS "brand_id",
  mrc."company_code" AS "company_code",
  mrc."id" AS "id",
  mrc."location" AS "location",
  mrc."name" AS "name",
  mrc."write_date" AS "write_date"
FROM {{ ref('stg_tqds_m_res_company') }} mrc
