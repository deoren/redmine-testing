#!/bin/bash

# https://github.com/deoren/redmine-testing

# Purpose: Dump current state of database

echo "* Backing up MariaDB database ..."
sudo mysqldump --no-defaults -u root --databases redmine > redmine-mysql-export.sql
