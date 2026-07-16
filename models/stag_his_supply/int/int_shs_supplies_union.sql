select * from {{ ref('int_shs_specialty_supply') }}
union all
select * from {{ ref('int_shs_surgery_supply') }}
union all
select * from {{ ref('int_shs_evaluation_supply') }}
union all
select * from {{ ref('int_shs_inpatient_supply') }}
union all
select * from {{ ref('int_shs_lab_test_supply') }}
