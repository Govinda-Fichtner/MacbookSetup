# MCP Server Environment Variables
# Generated: {{ timestamp }}
{% for server in servers %}
{% if server.env_vars or server.mount_env_var %}

# {{ server.id }} server configuration
{% for var in server.env_vars %}
{{ var }}={{ server.placeholders[var] }}
{% endfor %}
{% if server.mount_env_var %}
{{ server.mount_env_var }}={{ server.mount_default }}
{% endif %}
{% endif %}
{% endfor %}
