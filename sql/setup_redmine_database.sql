-- https://github.com/deoren/redmine-testing

-- NOTE: This should probably be utf8mb4 for full Unicode support
CREATE DATABASE redmine_trunk CHARACTER SET utf8;

-- Matching values set within /path/to/redmine/config/database.yml
CREATE USER 'redmine_trunk'@'localhost' IDENTIFIED BY 'redmine';
GRANT ALL PRIVILEGES ON redmine_trunk.* TO 'redmine_trunk'@'localhost';
