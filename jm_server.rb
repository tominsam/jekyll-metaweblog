#!/usr/bin/ruby
require 'rubygems'
require 'webrick'
require 'xmlrpc/server'
require 'optparse'
require 'metaweblog'

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

server = XMLRPC::WEBrickServlet.new
attach_metaweblog_methods(server, options)

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

