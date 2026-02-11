{% macro drop_specific_relations(relation_names) %}
    -- Macro này nhận vào danh sách tên bảng/view cần xóa
    -- Ví dụ: dbt run-operation drop_specific_relations --args '{relation_names: [my_table, my_view]}'
    
    {% set target_schema = target.schema %}
    
    {% if not relation_names %}
        {{ log("No relation names provided. Skipping...", info=True) }}
    {% endif %}

    {% for rel_name in relation_names %}
        
        -- Kiểm tra xem relation này có tồn tại trong database không
        {% set existing_relation = adapter.get_relation(
            database=target.database,
            schema=target.schema,
            identifier=rel_name
        ) %}

        {% if existing_relation %}
            -- Nếu tồn tại -> Xóa nó
            {% set drop_query %}
                DROP {{ existing_relation.type }} IF EXISTS {{ existing_relation }} CASCADE;
            {% endset %}
            
            {{ log("Dropping " ~ existing_relation.type ~ ": " ~ existing_relation, info=True) }}
            {% do run_query(drop_query) %}
        {% else %}
            {{ log("Relation '" ~ rel_name ~ "' does not exist in schema '" ~ target_schema ~ "'. Skipping.", info=True) }}
        {% endif %}

    {% endfor %}

{% endmacro %}
