#!/bin/bash
find /var/lib/mysql -type f -exec touch {} \; && mysqld_safe --character-set-server=utf8 --collation-server=utf8_general_ci
