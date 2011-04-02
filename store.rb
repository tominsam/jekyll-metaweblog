require "post"

class Store
    attr_accessor :base, :posts
  
    def initialize(base)
        self.base = base
    end
  
    def posts
        post_root = File.join(self.base, "_posts")

        posts = []
        
        # not having any posts is a valid thing
        return posts unless File.directory? post_root
        
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

        # recursive folder walk
        pages = []
        def walk(base, folder)
            #puts "walking #{ folder } under #{ base }"
            pages = []
            Dir.open(File.join(base,folder)).each{|file|
                # drop hidden files and the system jekyll stuff
                next if file.match(/^[\.\_]/)

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
  
    def getPage(id)
        post = Post.new(self.base, id)
        if post.read
            return post
        end
        return nil
    end

    def deletePage(id)
        File.delete(File.join(self.base, id))
    end
  
    def newPost(date, permalink = nil)
        permalink ||= (Time.now.to_i * 3).to_s
        filename = sprintf("%04d-%02d-%02d-%s.markdown", date.year, date.month, date.day, permalink)
        return Post.new(File.join(self.base, "_posts"), filename)
    end
  
end


  