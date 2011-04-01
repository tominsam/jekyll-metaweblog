#!/usr/bin/ruby
require 'rubygems'
require 'webrick'
require 'xmlrpc/server'

require 'store'
require 'metaweblog'

folder = ARGV[0] || "../blogtest"

store = Store.new(folder)

# do this here just to demonstrate that the store can load everything, rather than 
# waiting for a method call, where it's harder to get a stack trace.
store.posts
store.pages

metaWeblog = MetaWeblog.new(store)

# test again
metaWeblog.getRecentPosts(nil, nil, nil, 100000)

server = XMLRPC::Server.new(4040) # , "0.0.0.0")

# namespaces are for the WEAK
server.add_handler("blogger", metaWeblog)
server.add_handler("metaWeblog", metaWeblog)
server.add_handler("mt", metaWeblog)
server.add_handler("wp", metaWeblog)

server.set_service_hook do |obj, *args|
    puts "calling #{obj.name}(#{args.map{|a| a.inspect}.join(", ")})"
    begin
        ret = obj.call(*args)  # call the original service-method
        puts "   " + ret.inspect[0,80]
        ret
    rescue
        puts "  call exploded"
        puts $!
        raise XMLRPC::FaultException.new(-99, "error calling #{obj.name}: #{$!}")
    end
end

server.set_default_handler do |name, *args|
    puts "** tried to call missing method #{name}( #{args.inspect} )"
    raise XMLRPC::FaultException.new(-99, "Method #{name} missing or wrong number of parameters!")
end
server.serve
