require 'xmlrpc/server'

# IOS wordpress client doesn't send content/type
module XMLRPC::ParseContentType
    alias :broken_parser parse_content_type
    def parse_content_type(str)
        if str.nil?
            return ["text/xml",""]
        end
        return broken_parser(str)
    end
end
