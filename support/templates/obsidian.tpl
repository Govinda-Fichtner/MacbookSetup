"{{ server.id }}": {
  "command": "docker",
  "args": [
    "run", "--rm", "-i", "--env-file", "{{ server.env_file }}",
    "{{ server.image }}"
  ]
}
