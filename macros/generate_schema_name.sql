{#
  Ghi đè macro mặc định của dbt – CHỈ cho dự án Philippines (schema 'sandbox_ph').
    * Model khai báo schema = 'sandbox_ph' → ghi đúng vào 'sandbox_ph'
      (mặc định dbt sẽ nối thành '<target_schema>_sandbox_ph').
    * MỌI trường hợp khác giữ NGUYÊN hành vi mặc định của dbt:
        - không khai báo schema  → target.schema
        - schema tuỳ chỉnh khác  → '<target_schema>_<custom_schema>'
  → Các model hiện có và model người khác viết sau này không bị ảnh hưởng.
  Thêm 2026-10-07 (nhánh phi).
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- elif custom_schema_name | trim == 'sandbox_ph' -%}
        sandbox_ph
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
