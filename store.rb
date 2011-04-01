require "post"

class Store
    attr_accessor :base, :posts
  
    def initialize(base)
        self.base = base
    end
  
    def pages
    end

    def posts
        post_root = File.join(self.base, "_posts")

        posts = []
        Dir.open(post_root).each{|file|
            if file.match(/^\./)
                next
            end
            if !File.file? File.join(post_root, file)
                next
            end
            post = Post.new(post_root, file)
            if post and post.read
                posts << post
            end
        }
        posts = posts.sort_by{|p| p.date }.reverse
        posts
    end
  
    def pages
        page_root = File.join(self.base)

        pages = []
        def walk(base, folder)
            puts "walking #{ folder } under #{ base }"
            files = []
            Dir.open(File.join(base,folder)).each{|file|
                # drop hidden files and the system jekyll stuff
                if file.match(/^[\.\_]/)
                    next
                end
                full = File.join(base, folder, file)
                if File.directory? full
                    files += walk(base, File.join(folder, file))
                elsif File.file? full
                    files << File.join(folder, file).gsub(/^\//,'')
                end
            }
            return files
        end
        pages = walk(page_root, "")
        p pages
        
        pages = pages.map{|full|
            path = full.split(page_root,2)[1]
            puts path
        }
        
        p pages
    end
  
    def getPost(id)
        post = Post.new(File.join(self.base, "_posts"), id)
        if post.read
            return post
        end
        return nil
    end

    def deletePost(id)
        File.delete(File.join(self.base, "_posts", id))
    end
  
    def newPost(date, permalink = nil)
        permalink ||= (Time.now.to_i * 3).to_s
        filename = sprintf("%04d-%02d-%02d-%s.markdown", date.year, date.month, date.day, permalink)
        return Post.new(File.join(self.base, "_posts"), filename)
    end
  
end


  