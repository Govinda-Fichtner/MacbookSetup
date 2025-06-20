{
  "mcpServers": {
    {% for server in servers %}
      {% include server.id + '.tpl' %}
      {% if not loop.last %},{% endif %}
    {% endfor %}
  }
}
