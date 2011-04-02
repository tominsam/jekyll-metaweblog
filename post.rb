require 'yaml'

class Post
    attr_accessor :base, :filename, :date, :body, :data, :slug, :filetype
    
    def initialize(base, filename)
        self.base = base
        self.filename = filename
        self.data = {}
        self.data["layout"] = "post"

        # filenames need to start with a date
        m = self.filename.match(/^(\d{4})-(\d\d)-(\d\d)-(.+?).(\w+)$/)
        if m
            self.date = Date.civil(m[1].to_i, m[2].to_i, m[3].to_i)
            self.slug = m[4]
            self.filetype = m[5]
        elsif m = self.filename.match(/^(.*)\.([^\.]+)$/)
            #puts "Can't parse #{ self.filename } as date"
            self.date = nil
            self.slug = self.filename
            self.filetype = nil
        else
            puts "Can't parse #{self.filename} at all"
        end
    end
    
    
    # return bool true iff this file is actually a Jekyll post file
    def read
        if not self.slug
            # didn't pass init
            return false
        end

        # read the first 100k from the file. If the post is longer than this, it'll be truncated.
        # but we need to limit to a certain point or we'll slurp in the entirety of every file
        # in the folder.
        content = File.open(File.join(self.base, self.filename), "r") {|f| f.read(100 * 1024) }
        
        if not content
            puts "can't read #{self.filename}"
            return false
        end
        
        # file must begin with YAML
        preamble = content.split(/---\s*\n/)[1]
        if not preamble
            #puts "#{ self.filename } looks like a post but doesn't start with YAML preamble!"
            return false
        end
        self.data = YAML.load(preamble)

        # so, this is tricky. Should body contain preamble? not sure. Tilting
        # towards no right now - if you want something clever, do it with a
        # text editor.
        self.body = content.split(/---\s*\n/, 3)[2]
        
        if not self.data["layout"]
            puts "#{ self.filename } doesn't have a layout - probably not a post"
            return false
        end

        return true
    end
    
    def write
        # TODO - create _posts folder.
        # TODO - move this to the store.
        
        old_file = File.join(self.base, self.filename)
        if self.date
            new_file = File.join(self.base, sprintf("%04d-%02d-%02d-%s.%s", self.date.year, self.date.month, self.date.day, self.slug, self.filetype))
        else
            new_file = File.join(self.base, self.slug)
        end
        
        puts "** new_file #{ new_file }"
        puts "   old_file #{ old_file }"
        
        File.open(new_file + ".temp", "w") do |f|
            f.write YAML.dump( self.data )
            f.write "---\n"
            f.write self.body.strip + "\n"
        end

        if new_file != old_file and File.exist? old_file
            File.delete old_file
        end

        File.rename( new_file + ".temp", new_file )
    end

    def to_s
        return "#<Post #{self.title}>"
    end
    
    def title
        return self.data["title"]
    end
    
    def title=(t)
        self.data["title"] = t
    end
    
    def tags
        return self.data["tags"] || []
    end
    
    def tags=(t)
        self.data["tags"] = t
    end
    
end
