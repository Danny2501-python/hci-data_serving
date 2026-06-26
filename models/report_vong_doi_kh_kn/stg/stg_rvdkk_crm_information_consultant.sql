select * from {{ source('rvdkk_source', 'crm_information_consultant') }} where "role" = 'recept' and brand_etl = 1
