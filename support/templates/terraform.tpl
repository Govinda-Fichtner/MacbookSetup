"{{ server.id }}": {
  "command": "docker",
  "args": [
    "run", "--rm", "-i", "--env-file", "{{ server.env_file }}"
    {%- if server.cmd_args and server.cmd_args|length > 0 -%},
    {%- for arg in server.cmd_args -%}"{{ arg }}"{%- if not loop.last -%},{%- endif -%}{%- endfor -%}
    {%- endif -%},
    "{{ server.image }}"
  ]
}
