"{{ server.id }}": {
  "command": "npx",
  "args": ["-y", "{{ server.proxy_command }}", "{{ server.url }}"]
}
