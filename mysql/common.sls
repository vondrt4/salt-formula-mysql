{%- from "mysql/map.jinja" import server with context %}


{%- if pillar.mysql.cluster is defined %}
{%- from "mysql/map.jinja" import cluster with context %}


mysql_packages:
  pkg.installed:
  - names: {{ cluster.pkgs }}
  - reload_modules: true

mysql_log_dir:
  file.directory:
  - name: /var/log/mysql
  - makedirs: true
  - mode: 755
  - require:
    - pkg: mysql_packages

{%- if server.admin is defined %}
mariadb_debconf:
  debconf.set:
  - name: mysql-server-wsrep
  - data:
      'mysql-server/root_password': {'type':'string','value':'{{ server.admin.password }}'}
      'mysql-server/root_password_again': {'type':'string','value':'{{ server.admin.password }}'}
  - require_in:
    - pkg: mysql_packages
{%- endif %}

{%- else %} #not cluster

{%- if server.admin is defined %}
mariadb_debconf:
  debconf.set:
  - name: mysql-server-{{ server.version }}
  - data:
   'mysql-server/root_password': {'type':'string','value':'{{ server.admin.password }}'}
   'mysql-server/root_password_again': {'type':'string','value':'{{ server.admin.password }}'}
  - require_in:
 - pkg: mysql_packages
{%- endif %}

mysql_packages:
  pkg.installed:
  - names: {{ server.pkgs }}
  - reload_modules: true

{%- endif %} #endif cluster

mysql_config:
  file.managed:
  - name: {{ server.config }}
  - source: salt://mysql/conf/my.cnf.{{ grains.os_family }}
  - mode: 644
  - template: jinja
  - require:
    - pkg: mysql_packages

{%- if not grains.get('noservices', False) %}
mysql_service:
  service.running:
  - name: {{ server.service }}
  - enable: true
  - watch:
    - file: mysql_config
{%- endif %}


{%- if grains.get('virtual_subtype', None) == "Docker" %}
mysql_entrypoint:
  file.managed:
  - name: /entrypoint.sh
  - template: jinja
  - source: salt://mysql/files/entrypoint.sh
  - mode: 755
{%- endif %}

mysql_config_dir:
  file.directory:
  - name: /etc/mysql/conf.d
  - makedirs: true
  - mode: 755

mysql_dirs:
  file.directory:
  - names:
    - /root/mysql/scripts
    - /root/mysql/flags
    - /root/mysql/data
  - mode: 700
  - user: root
  - group: root
  - makedirs: true
  - require:
    - pkg: mysql_packages

{#
{%- if grains.os_family == "RedHat" %}

mysql_setup:
  cmd.run:
  - name: mysql_install_db
  - unless: test -e /var/lib/mysql/mysql.sock
  - require:
    - file: mysql_config_dir
  - require_in:
    - service: mysql_service

{%- if cluster.enabled %}

{%- else %}

{%- if server.admin is defined %}

mysql_set_root_password:
  cmd.run:
  - name: 'echo "update user set password=PASSWORD(''{{ pillar.mysql.server.admin.password }}'') where User=''{{ pillar.mysql.server.admin.user }}'';flush privileges; exit;" | /usr/bin/env HOME=/ mysql -uroot mysql'
  - unless: 'mysql -u root -e "show databases;" | grep mysql'
  - require:
    - file: /root/mysql/flags
    - pkg: mysql_packages

mysql_change_root_password:
  cmd.run:
  - name: 'echo "update user set password=PASSWORD(''{{ pillar.mysql.server.admin.password }}'') where User=''{{ pillar.mysql.server.admin.user }}'';flush privileges; exit;" | mysql -uroot mysql'
  - onlyif: '(echo | mysql -u root) && [ -f /root/.my.cnf ] && ! fgrep -q ''{{ pillar.mysql.server.admin.password }}'' /root/.my.cnf'
  - require:
    - cmd: mysql_set_root_password

{%- endif %}

{%- endif %}

{%- endif %}
#}

/root/mysql/flags:
  file.directory:
  - mode: 700
  - user: root
  - group: root
  - makedirs: true
  - require:
    - pkg: mysql_packages

{#
# 	Backup part - automysqlbackup
#}

{% for backup_engine in pillar.mysql.server.get("backup_engine", []) %}

{%- if backup_engine.get("name", []) == "automysqlbackup" %}

{%- if grains.osfullname in ['CentOS'] %}

mysql_backup1_pkgs:
  pkg.installed:
  - names:
    - pigz
    - pbzip2
    - cronie
    - mailx

{%- elif grains.osfullname in ['Ubuntu'] %}

mysql_backup2_pkgs:
  pkg.installed:
  - names:
    - mailutils
    - pigz
    - pbzip2

{%- endif %}

{%- if grains.osfullname in ['CentOS'] or grains.osfullname in ['Ubuntu'] %}

mysql_backup_dirs:
  file.directory:
  - names:
    - /root/mysql/scripts
    - /root/mysql/data
    - /etc/automysqlbackup
  - mode: 700
  - user: root
  - group: root
  - makedirs: true
  - require:
{%- if grains.osfullname in ['CentOS'] %}
    - pkg: mysql_backup1_pkgs
{%- elif grains.osfullname in ['Ubuntu'] %}
    - pkg: mysql_backup2_pkgs
{%- endif %}

mysql_automysqlbackup_conf:
  file.managed:
  - name: /etc/automysqlbackup/automysqlbackup.conf
  - source: salt://mysql/conf/automysqlbackup.conf
  - mode: 644
  - template: jinja
  - require:
    - file: mysql_backup_dirs

mysql_automysqlbackup_script:
  file.managed:
  - name: /root/mysql/scripts/automysqlbackup
  - source: salt://mysql/conf/automysqlbackup
  - mode: 755
  - require:
    - file: mysql_backup_dirs

mysql_automysqlbackup_cron:
  file.managed:
  - name: /etc/cron.daily/automysqlbackup
  - source: salt://mysql/conf/automysqlbackup.cron
  - mode: 755
  - template: jinja
  - require:
    - file: mysql_backup_dirs

{%- endif %}

{%- endif %}

{%- endfor %}
