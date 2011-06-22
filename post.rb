require 'yaml'

class Post
    attr_accessor :base, :filename, :date, :body, :data, :type, :slug
    
    def initialize(base, filename)
        self.base = base
        self.filename = filename
        
        self.slug = filename
        self.date = Date.today
        self.type = :page

        # the page itself
        self.data = {}
        self.data["layout"] = "post"
        self.body = ""

        # page filenames need to start with a date
        m = self.filename.match(/^_posts\/(\d{4})-(\d\d)-(\d\d)-(.*)$/)
        if m
            self.date = Date.civil(m[1].to_i, m[2].to_i, m[3].to_i)
            self.slug = m[4]
            self.type = :post
        end
    end
    
    
    # return bool true iff this file is actually a Jekyll source file
    def read
        # note to self - the better long-term way of doing this is to read the first
        # 4 bytes, look fior '---\n', then read till we have the preamble and parse it,
        # then read the rest, rather than always reading Xk of the file and splitting it
        # up. But this works.
        
        if not File.exists? File.join(self.base, self.filename)
            return false
        end

        # read the first 500k from the file. If the post is longer than this, it'll be truncated.
        # but we need to limit to a certain point or we'll slurp in the entirety of every file
        # in the folder.
        content = File.open(File.join(self.base, self.filename), "r") {|f| f.read(500 * 1024) }
        
        if not content
            # 0-length file
            return false
        end
        
        # file must begin with YAML
        preamble = content.split(/---\s*\n/)[1]
        if not preamble
            #puts "#{ self.filename } looks like a post but doesn't start with YAML preamble!"
            return false
        end
        begin
            self.data = YAML.load(preamble)
        rescue Exception => e
            STDERR.puts("can't load YAML from #{self.filename}\n\n#{preamble}")
            raise
        end

        # so, this is tricky. Should body contain preamble? not sure. Tilting
        # towards no right now - if you want something clever, do it with a
        # text editor.
        self.body = content.split(/---\s*\n/, 3)[2]
        
        return true
    end


    def write
        # if the format type has changed, the file on disk will have a different filename
        # (because the format type is the file extension).

        if self.type == :post
            new_filename = sprintf("_posts/%04d-%02d-%02d-%s", self.date.year, self.date.month, self.date.day, self.slug)
        else
            new_filename = self.slug
        end
        
        # create surrounding folder.
        folder = File.dirname File.join(self.base, new_filename)
        if not File.directory? folder
            # TODO - fix for recursive mkdir
            Dir.mkdir folder
        end
        
        # write a .temp file rather than overwriting the old file, in case something
        # goes wrong. TODO - Write a hidden file to avoid confusing jekyll
        tempname = File.join(self.base, new_filename + ".temp")
        File.open(tempname, "w") do |f|
            f.write YAML.dump( self.data )
            f.write "---\n\n"
            f.write self.body.strip + "\n"
        end

        # if the file extension changed, remove the old file.
        if new_filename != self.filename and File.exist? File.join(self.base, self.filename)
            File.delete File.join(self.base, self.filename)
        end

        # replace the file with the temp file we wrote.
        File.rename( tempname, File.join(self.base, new_filename) )

        self.filename = new_filename
    end

    def to_s
        return "#<Post (#{self.type}) #{self.filename}>"
    end
    
    
    # some utility accessors to get/set standard values out of the data hash
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
