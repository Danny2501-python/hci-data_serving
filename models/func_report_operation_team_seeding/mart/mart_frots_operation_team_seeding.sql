{{ config(
    materialized='table',
    alias='report_operation_team_seeding'
) }}

SELECT * FROM {{ ref('int_frots_component_1_3_form_cs') }}
UNION ALL
SELECT * FROM {{ ref('int_frots_component_2_form_odoo') }}
UNION ALL
SELECT * FROM {{ ref('int_frots_component_3_lead') }}
UNION ALL
SELECT * FROM {{ ref('int_frots_component_4_booking') }}
UNION ALL
SELECT * FROM {{ ref('int_frots_component_5_booking_date') }}
UNION ALL
SELECT * FROM {{ ref('int_frots_component_6_arrival') }}
UNION ALL
SELECT * FROM {{ ref('int_frots_component_7_success') }}
UNION ALL
SELECT * FROM {{ ref('int_frots_component_8_sales_erp') }}
