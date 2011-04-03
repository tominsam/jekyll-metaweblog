#!/usr/bin/ruby
require 'rubygems'
require 'webrick'
require 'xmlrpc/server'
require 'optparse'
require 'store'
require 'metaweblog'
require 'monkeypatch'

options = {}

optparse = OptionParser.new do|opts|
    # Set a banner, displayed at the top
    # of the help screen.
    opts.banner = "Usage: #$0 [options] jeykll_blog_root"

    # Define the options, and what they do
    options[:port] = 4040
    opts.on( '-p', '--port PORT', Integer, 'Server port (default 4040)' ) do |port|
        options[:port] = port
    end

    options[:host] = "localhost"
    opts.on( '--host HOST', 'Bind to host (default localhost)' ) do |host|
        options[:host] = host
    end

    options[:root] = nil
    opts.on( '-r', '--root FOLDER', 'Define the jekyll input folder (required)' ) do |root|
        options[:root] = root
    end

    options[:web] = nil
    opts.on( '-w', '--web FOLDER', 'Define the jekyll output folder (will be served by internal web server)' ) do |web|
        options[:web] = web
    end

    # This displays the help screen, all programs are
    # assumed to have this option.
    opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        exit 1
    end

end

optparse.parse!



if options[:root].nil? or not File.directory? options[:root]
    puts "option --root must be a folder"
    exit 1
end

if options[:web].nil?
    options[:web] = File.join(options[:root], "_site")
end


puts "Starting up with jekyll folder #{options[:root]}"
puts "Serving web root #{options[:web]}"

store = Store.new(options[:root])

# debugging - do this here just to demonstrate that the store can load everything,
# rather than waiting for a method call, where it's harder to get a stack trace.
store.posts
store.pages

server = XMLRPC::WEBrickServlet.new

# namespaces are for the WEAK
metaWeblog = MetaWeblog.new(store, options[:host], options[:port])
server.add_handler("blogger", metaWeblog)
server.add_handler("metaWeblog", metaWeblog)
server.add_handler("mt", metaWeblog)
server.add_handler("wp", metaWeblog)
server.add_introspection # the wordpress IOS client requires this

server.set_service_hook do |obj, *args|
    name = (obj.respond_to? :name) ? obj.name : obj.to_s
    puts "calling #{name}(#{args.map{|a| a.inspect}.join(", ")})"
    begin
        ret = obj.call(*args)  # call the original service-method
        puts "   #{name} returned " + ret.inspect[0,2000]
        
        if ret.inspect.match(/[^\"]nil[^\"]/)
            puts "found a nil in " + ret.inspect
        end
        ret
    rescue
        puts "  #{name} call exploded"
        puts $!
        puts $!.backtrace
        raise XMLRPC::FaultException.new(-99, "error calling #{name}: #{$!}")
    end
end

server.set_default_handler do |name, *args|
    puts "** tried to call missing method #{name}( #{args.inspect} )"
    raise XMLRPC::FaultException.new(-99, "Method #{name} missing or wrong number of parameters!")
end


httpserver = WEBrick::HTTPServer.new(
    :Port => options[:port],
    :Host => options[:host],
    :DocumentRoot => options[:web]
)

httpserver.mount("/xmlrpc.php", server)

['INT', 'TERM', 'HUP'].each { |signal|
  trap(signal) { httpserver.shutdown }
}

httpserver.start

