"{{ server.id }}": {
  "command": "docker",
  "args": [
    "run", "--rm", "-i",
    "--env-file", "{{ server.env_file }}",
    {%- if server.volumes and server.volumes|length > 0 %}
    {%- for volume in server.volumes %}
    "--volume", "{{ volume }}",
    {%- endfor %}
    {%- endif %}
    "{{ server.image }}"
  ]
}
