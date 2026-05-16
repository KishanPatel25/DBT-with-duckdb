-- Helper macro to initialize S3 access in DuckDB
-- Run with: dbt run-operation setup_s3_access

{% macro setup_s3_access() %}
  {% if target.name == 'dev' %}
    {% do log("Setting up S3 access for DuckDB...", info=true) %}

    {% set sql %}
      INSTALL httpfs;
      LOAD httpfs;
    {% endset %}

    {% do run_query(sql) %}

    {% do log("✓ S3 support loaded in DuckDB", info=true) %}
    {% do log("S3 credentials must be set via environment variables:", info=true) %}
    {% do log("  - AWS_ACCESS_KEY_ID", info=true) %}
    {% do log("  - AWS_SECRET_ACCESS_KEY", info=true) %}
    {% do log("  - AWS_REGION", info=true) %}
  {% else %}
    {% do log("S3 setup only applies to DuckDB target", info=true) %}
  {% endif %}
{% endmacro %}
