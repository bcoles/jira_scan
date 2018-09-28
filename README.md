# JiraScan

## Description

JiraScan is a simple remote scanner for Atlassian Jira.

## Installation

```
bundle install
gem build jira_scan.gemspec
gem install --local jira_scan-0.0.1.gem
```

## Usage (command line)

```
% jira-scan -h
Usage: jira-scan <url> [options]
    -u, --url URL                    Jira URL to scan
    -s, --skip                       Skip check for Jira
    -v, --verbose                    Enable verbose output
    -h, --help                       Show this help

```

## Usage (ruby)

```
require 'jira_scan'
is_jira     = JiraScan::isJira(url)               # Check if a URL is Jira
version     = JiraScan::getVersion(url)           # Get Jira version
dev_mode    = JiraScan::devMode(url)              # Check if dev mode is enabled
register    = JiraScan::userRegistration(url)     # Check if user registration is enabled
user_picker = JiraScan::userPicker(url)           # Check if User Picker is accessible
users       = JiraScan::getUsers(url)             # Retrieve list of first 1,000 users
dashboards  = JiraScan::getDashboards(url)        # Retrieve list of dashboards
filters     = JiraScan::getPopularFilters(url)    # Retrieve list of popular filters
```

