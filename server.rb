#!/usr/bin/ruby
require 'rubygems'
require 'webrick'
require 'xmlrpc/server'
require 'optparse'

require 'store'
require 'metaweblog'

options = {}

optparse = OptionParser.new do|opts|
    # Set a banner, displayed at the top
    # of the help screen.
    opts.banner = "Usage: #$0 [options] jeykll_blog_root"

    # Define the options, and what they do
    options[:port] = 4040
    opts.on( '-p', '--port', 'Server port' ) do |port|
        options[:port] = port.to_i > 0 ? port.to_i : 4040
    end

    options[:host] = "127.0.0.1"
    opts.on( '-h', '--host', 'Bind to host' ) do |host|
        options[:host] = host
    end

    # This displays the help screen, all programs are
    # assumed to have this option.
    opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        exit
    end
end

optparse.parse!

folder = ARGV[0]

if not folder or folder.size == 0 or not File.directory? folder
    puts "not a folder"
    exit
end

store = Store.new(folder)

# debugging - do this here just to demonstrate that the store can load everything,
# rather than waiting for a method call, where it's harder to get a stack trace.
store.posts
store.pages

metaWeblog = MetaWeblog.new(store)

# test again
metaWeblog.getRecentPosts(nil, nil, nil, 100000)

server = XMLRPC::Server.new(options[:port], options[:host])

# namespaces are for the WEAK
server.add_handler("blogger", metaWeblog)
server.add_handler("metaWeblog", metaWeblog)
server.add_handler("mt", metaWeblog)
server.add_handler("wp", metaWeblog)

server.set_service_hook do |obj, *args|
    puts "calling #{obj.name}(#{args.map{|a| a.inspect}.join(", ")})"
    begin
        ret = obj.call(*args)  # call the original service-method
        puts "   #{obj.name} returned " + ret.inspect[0,80]
        
        if ret.inspect.match(/[^\"]nil[^\"]/)
            puts "found a nil in " + ret.inspect
        end
        ret
    rescue
        puts "  #{obj.name} call exploded"
        puts $!
        raise XMLRPC::FaultException.new(-99, "error calling #{obj.name}: #{$!}")
    end
end

server.set_default_handler do |name, *args|
    puts "** tried to call missing method #{name}( #{args.inspect} )"
    raise XMLRPC::FaultException.new(-99, "Method #{name} missing or wrong number of parameters!")
end
server.serve
