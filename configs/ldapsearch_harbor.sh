#!/bin/bash
set -e
ldapsearch -H ldap://dc01.company.com -x -D "$HARBOR_SVC_USER" -w "$HARBOR_SVC_PASSWORD" -b "dc=company,dc=com" "(sAMAccountName=$harbor_group_name)" | grep "^dn:" | awk '{print $2;}'