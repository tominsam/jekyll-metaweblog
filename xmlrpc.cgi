#!/usr/bin/ruby
require 'rubygems'
require 'xmlrpc/server'
require 'metaweblog'

root = "/Users/tomi/Sites/movieos/blog"
password = "server password"

server = XMLRPC::CGIServer.new

attach_metaweblog_methods(server, :root => root, :password => password)

server.serve
