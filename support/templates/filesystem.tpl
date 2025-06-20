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
    {%- if server.container_paths and server.container_paths|length > 0 %},
      {%- for path in server.container_paths %}
    "{{ path }}"
        {%- if not loop.last %},{%- endif %}
      {%- endfor %}
    {%- endif %}
    {%- if server.cmd_args and server.cmd_args|length > 0 -%},
    {%- for arg in server.cmd_args -%}"{{ arg }}"{%- if not loop.last -%},{%- endif -%}{%- endfor -%}
    {%- endif -%}
  ]
}
