{% from "mysql/map.jinja" import server with context %}

mysql_config:
  file.managed:
  - name: {{ server.config }}
  - source: salt://mysql/conf/my.cnf.bootstrap
  - mode: 644
  - template: jinja
