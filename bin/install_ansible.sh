#!/bin/bash

# https://github.com/deoren/redmine-testing

# Purpose: Install Ansible from Ubuntu PPA

# https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#latest-releases-via-apt-ubuntu
# https://www.cyberciti.biz/faq/how-to-install-and-configure-latest-version-of-ansible-on-ubuntu-linux/

sudo apt-get update
sudo apt-get install -y software-properties-common
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt-get install -y ansible

# Install additional common support packages
sudo apt-get install \
    python-apt \
    python-pycurl \
    python-mysqldb \
