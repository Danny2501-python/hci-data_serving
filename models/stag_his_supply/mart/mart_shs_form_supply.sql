{{ config(
    materialized='incremental',
    incremental_strategy='append',
    alias='stag_his_form_supply_2',
    pre_hook="{% if is_incremental() %}delete from {{ this }} where brand_etl <> 0{% endif %}"
) }}

select * from {{ ref('int_shs_form_supply') }}
