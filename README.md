# JiraScan

## Description

JiraScan is a simple remote scanner for Atlassian Jira.

## Installation

Install from RubyGems.org:

```
gem install jira_scan
```

Install from GitHub:

```
git clone https://github.com/bcoles/jira_scan
cd jira_scan
bundle install
gem build jira_scan.gemspec
gem install --local jira_scan-0.0.2.gem
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
JiraScan::isJira(url)                         # Check if a URL is Jira
JiraScan::getVersion(url)                     # Retrieve Jira version
JiraScan::devMode(url)                        # Check if dev mode is enabled
JiraScan::userRegistration(url)               # Check if user registration is enabled
JiraScan::userPickerBrowser(url)              # Check if User Picker Browser is accessible
JiraScan::restUserPicker(url)                 # Check if REST User Picker is accessible
JiraScan::restGroupUserPicker(url)            # Check if REST Group User Picker is accessible
JiraScan::viewUserHover(url)                  # Check if View User Hover is accessible
JiraScan::metaInf(url)                        # Check if META-INF contents are accessible
JiraScan::getUsersFromUserPickerBrowser(url)  # Retrieve list of first 1,000 users from User Picker Browser
JiraScan::getDashboards(url)                  # Retrieve list of dashboards
JiraScan::getPopularFilters(url)              # Retrieve list of popular filters
JiraScan::getFieldNames(url)                  # Retrieve list of field names
```

