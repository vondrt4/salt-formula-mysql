{%- from "mysql/map.jinja" import cluster with context %}
{%- from "mysql/map.jinja" import server with context %}
{%- if pillar.mysql.cluster.enabled %}

include:
- mysql.common

{%- if cluster.config is defined %}

mysql_cluster_config:
  file.absent:
  - name: {{ cluster.config }}

{%- endif %}

{%- if grains.os_family == 'Debian' %}

mysql_cluster_debian_config:
  file.managed:
  - name: /etc/mysql/debian.cnf
  - source: salt://mysql/conf/debian.cnf
  - mode: 644
  - template: jinja
  - require:
    - pkg: mysql_packages

mysql_default_config:
  file.managed:
  - name: /etc/mysql/my.cnf
  - source: salt://mysql/conf/my.cnf.Debian
  - template: jinja
  - mode: 644
  - require: 
    - pkg: mysql_packages

{%- endif %}

{% if cluster.get('role', 'slave') == 'master' %}

{%- if grains.os_family == 'Debian' %}

mysql_cluster_init:
  cmd.run:
  - names:
{#tvondra: debconf does not work with mysql_server_wsrep
    -  mysql -u root -p{{ server.admin.password }} -e "GRANT ALL PRIVILEGES ON *.* TO 'debian-sys-maint'@'localhost' IDENTIFIED BY '{{ server.maintenance_password }}';"
#}
    -  mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'debian-sys-maint'@'localhost' IDENTIFIED BY '{{ server.maintenance_password }}';"
    -  mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY '{{ server.admin.password }}'; GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' IDENTIFIED BY '{{ server.admin.password }}'; GRANT ALL PRIVILEGES ON *.* TO 'root'@'::1' IDENTIFIED BY '{{ server.admin.password }}'; GRANT ALL PRIVILEGES ON *.* TO 'root'@'{{ pillar.linux.system.name }}' IDENTIFIED BY '{{ server.admin.password }}';"
    -  service mysql stop
{#this does not work as well on Ubuntu 14
    -  service mysql start --wsrep-new-cluster
#}
    -  touch /root/mysql/flags/cluster-installed
  - unless: test -e /root/mysql/flags/cluster-installed
  - require:
    - pkg: mysql_packages
    - file: /root/mysql/flags

{%- endif %}

{% else %}

mysql_cluster_init:
  cmd.run:
  - names:
    - service mysql stop
    - service mysql start
    - touch /root/mysql/flags/cluster-installed
  - unless: test -e /root/mysql/flags/cluster-installed
  - require:
    - pkg: mysql_packages
    - file: /root/mysql/flags

{%- endif %}

{%- endif %}