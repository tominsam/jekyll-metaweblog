#!/usr/bin/ruby
require 'rubygems'
require 'xmlrpc/server'
require 'metaweblog'

root = "/Users/tomi/Sites/movieos/blog"
ouput = "/archive/web/blog.movieos.org"

password = "server password"

server = XMLRPC::CGIServer.new

attach_metaweblog_methods(server, :root => root, :password => password, :output => output)

server.serve
