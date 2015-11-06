
include:
{%- if pillar.mysql.cluster is defined %}
- mysql.cluster
{%- endif %}
{%- if pillar.mysql.server is defined %}
- mysql.server
{%- endif %}
