require "post"

class Store
    attr_accessor :base, :posts
  
    def initialize(base)
        self.base = base
    end
  
    def posts
        read_all_files.select{|p| p.type == :post }.sort_by{|p| p.date }.reverse
    end
    
    def pages
        read_all_files.select{|p| p.type == :page }.sort_by{|p| p.filename }
    end
  
    def read_all_files
        page_root = File.join(self.base)

        # recursive folder walk
        pages = []
        def walk(base, folder)
            #puts "walking #{ folder } under #{ base }"
            pages = []
            Dir.open(File.join(base,folder)).each{|file|
                # drop hidden files
                next if file.match(/^[\.]/)
                
                # don't walk into any magic folders other than _posts
                next if file.match(/^_/) and file != "_posts"

                full = File.join(base, folder, file)
                if File.directory? full
                    pages += walk(base, File.join(folder, file))
                elsif File.file? full
                    # the relative path of this file from the base
                    file = File.join(folder, file).gsub(/^\//,'')
                    page = Post.new(base, file)
                    if page and page.read
                        pages << page
                    end
                end
            }
            return pages
        end
        pages = walk(page_root, "")
        return pages
    end
  
    def get(filename)
        post = Post.new(self.base, filename)
        if post.read
            return post
        end
        return nil
    end
    
    def delete(filename)
        if File.exists?(File.join(self.base, filename))
            File.delete(File.join(self.base, filename))
            return true
        end
        return false
    end
 
    def write(post)
        post.write
    end

    def create(type = :page, slug = nil, date = nil)
        slug ||= (Time.now.to_i * 3).to_s + ".markdown" # TODO - default extension should be configurable
        if type == :page
            return Post.new(self.base, slug)
        else
            date ||= Date.today
            filename = sprintf("_posts/%04d-%02d-%02d-%s", date.year, date.month, date.day, slug)
            return Post.new(self.base, filename)
        end
    end
    
    
    def saveFile(name, data)
        filename = File.join(self.base, "uploads", name)
        if not File.directory?(File.dirname(filename))
            FileUtils.mkdir_p(File.dirname(filename))
        end
        File.open(filename, "wb") {|f|
            f.write(data)
        }
        return "uploads/#{name.gsub(/^\//,'')}"
    end
    
  
end


  