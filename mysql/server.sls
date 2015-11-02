{%- from "mysql/map.jinja" import server with context %}
{%- if server.enabled %}

include:
- mysql.common

{%- if server.ssl.enabled %}

/etc/mysql/server-cert.pem:
  file.managed:
  - source: salt://pki/{{ server.ssl.authority }}/certs/{{ server.ssl.certificate }}.cert.pem
  - require:
    - pkg: mysql_packages

/etc/mysql/server-key.pem:
  file.managed:
  - source: salt://pki/{{ server.ssl.authority }}/certs/{{ server.ssl.certificate }}.key.pem
  - require:
    - pkg: mysql_packages

{%- if server.replication.role in ['slave', 'both'] %}

/etc/mysql/client-cert.pem:
  file.managed:
  - source: salt://pki/{{ server.ssl.authority }}/certs/{{ server.ssl.client_certificate }}.cert.pem
  - require:
    - pkg: mysql_packages

/etc/mysql/client-key.pem:
  file.managed:
  - source: salt://pki/{{ server.ssl.authority }}/certs/{{ server.ssl.client_certificate }}.key.pem
  - require:
    - pkg: mysql_packages

{%- endif %}

/etc/mysql/cacert.pem:
  file.managed:
  - source: salt://pki/{{ server.ssl.authority }}/{{ server.ssl.authority }}-chain.cert.pem
  - require:
    - pkg: mysql_packages

{%- endif %}


{%- if server.replication.role in ['master', 'both'] %}

{{ server.replication.user }}:
  mysql_user.present:
  - host: '%'
  - password: {{ server.replication.password }}

{{ server.replication.user }}_replication_grants:
  mysql_grants.present:
  - grant: replication slave
  - database: '*.*'
  - user: {{ server.replication.user }}
  - host: '%'

{%- endif %}

{%- if server.replication.role in ['slave', 'both'] %}

{%- if not salt['mysql.get_slave_status'] is defined %}

{%- include "mysql/server/_connect_replication_slave.sls" %}

{%- elif salt['mysql.get_slave_status']() == [] %}

{%- include "mysql/server/_connect_replication_slave.sls" %}

{%- else %}

{%- if salt['mysql.get_slave_status']().get('Slave_SQL_Running', 'No') == 'Yes' and salt['mysql.get_slave_status']().get('Slave_IO_Running', 'No') == 'Yes' %}

{%- else %}

{%- include "mysql/server/_connect_replication_slave.sls" %}

{%- endif %}

{%- endif %}

{%- endif %}


{%- for database_name, database in server.get('database', {}).iteritems() %}

mysql_database_{{ database_name }}:
  mysql_database.present:
  - name: {{ database_name }}
  - require:
    - service: mysql_service
    - pkg: mysql_packages

{%- for user in database.users %}

mysql_user_{{ user.name }}_{{ database_name }}_{{ user.host }}:
  mysql_user.present:
  - host: '{{ user.host }}'
  - name: '{{ user.name }}'
  - password: {{ user.password }}
  - require:
    - service: mysql_service

mysql_grants_{{ user.name }}_{{ database_name }}_{{ user.host }}:
  mysql_grants.present:
  - grant: {{ user.rights }}
  - database: '{{ database_name }}.*'
  - user: '{{ user.name }}'
  - host: '{{ user.host }}'
  - require:
    - mysql_user: mysql_user_{{ user.name }}_{{ database_name }}_{{ user.host }}
    - mysql_database: mysql_database_{{ database_name }}

{%- endfor %}

{%- if database.initial_data is defined %}

/root/mysql/scripts/restore_{{ database_name }}.sh:
  file.managed:
  - source: salt://mysql/conf/restore.sh
  - mode: 770
  - template: jinja
  - defaults:
    database_name: {{ database_name }}
  - require:
    - file: mysql_dirs
    - mysql_database: mysql_database_{{ database_name }}

restore_mysql_database_{{ database_name }}:
  cmd.run:
  - name: /root/mysql/scripts/restore_{{ database_name }}.sh
  - unless: "[ -f /root/mysql/flags/{{ database_name }}-installed ]"
  - cwd: /root
  - require:
    - file: /root/mysql/scripts/restore_{{ database_name }}.sh

{%- endif %}

{%- endfor %}

{%- for user in server.get('users', []) %}

mysql_user_{{ user.name }}_{{ user.host }}:
  mysql_user.present:
  - host: '{{ user.host }}'
  - name: '{{ user.name }}'
  {%- if user.password is defined %}
  - password: {{ user.password }}
  {%- else %}
  - allow_passwordless: True
  {%- endif %}

{%- endfor %}

{%- endif %}
