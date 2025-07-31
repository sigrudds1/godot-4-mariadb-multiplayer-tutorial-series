#!/usr/bin/env bash

# sudo mariadb-dump --user=username -p --no-data --lock-tables --databases DbName > DbName_no_data_dump_$(date +'%Y%m%d_%H%M%S').sql
sudo mariadb-dump --user=root --password=supersecret --no-data --lock-tables --databases GameSrvrTemplate > GameSrvrTemplate_no_data_dump_$(date +'%Y%m%d_%H%M%S').sql