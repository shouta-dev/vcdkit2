#!/bin/sh

yum install \
  ruby ruby-devel rubygems \
  make gcc mysql-devel libxml2-devel libxslt-devel vixie-cron perl-CPAN wget

gem install bundler
bundle install