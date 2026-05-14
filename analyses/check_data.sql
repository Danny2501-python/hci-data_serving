{% set old_etl_relation = adapter.get_relation(
      database=target.database,
      schema='public',
      identifier='stag_payment_transfer'
) %}

{% set dbt_relation = ref('stag_payment_transfer_test_dbt') %}

{{ audit_helper.compare_relations(
    a_relation = old_etl_relation,
    b_relation = dbt_relation,
    primary_key = "crm_id,brand_etl"
) }}