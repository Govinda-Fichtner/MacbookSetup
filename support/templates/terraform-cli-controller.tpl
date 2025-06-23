"terraform-cli-controller": {
  "command": "docker",
  "args": [
    "run", "--rm", "-i",
    {%- if server.privileged_networks and server.privileged_networks|length > 0 %}
      {%- for network in server.privileged_networks %}
    "--network", "{{ network }}",
      {%- endfor %}
    {%- endif %}
    {%- if server.privileged_volumes and server.privileged_volumes|length > 0 %}
      {%- for volume in server.privileged_volumes %}
    "--volume", "{{ volume }}",
      {%- endfor %}
    {%- endif %}
    "--env-file", "{{ server.env_file }}",
    "{{ server.image }}"
    {%- if server.cmd_args and server.cmd_args|length > 0 %},
      {%- for arg in server.cmd_args %}
    "{{ arg }}"
        {%- if not loop.last %},{%- endif %}
      {%- endfor %}
    {%- endif %}
  ]
}
