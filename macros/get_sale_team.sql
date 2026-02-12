{% macro get_sale_team(base_alias, date_column_name) %}
    left join lateral (
        select 
            sc."name",
            sc."group_name",
            sc."group",
            sc.work_email 
        from {{ source('kangnam_source', 'table_team_sale_trans_field') }} sc
        where sc.work_email = {{ base_alias }}.work_email_normalized
          and date(sc.expiration_date) >= date({{ base_alias }}.{{ date_column_name }})
        order by sc.expiration_date asc
        limit 1
    ) tts on true
{% endmacro %}
