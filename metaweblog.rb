require 'json'

# not just the metaweblog API - this is _all_ the APIs crammed into one namespace. Ugly.

# references:
#
# http://txp.kusor.com/rpc-api/blogger-api
#
# http://codex.wordpress.org/XML-RPC_wp
#


class MetaWeblog
    attr_accessor :store
    
    def initialize(store)
        self.store = store
    end
    
    # convert a post into a structure that we expect to return from metaweblog. Some repetition
    # here to convince stroppy clients that we really do mean these things.
    def post_response(post)
        return {
            :postId => post.filename,
            :title => post.title || "",
            :description => post.body || "",
            :dateCreated => post.date,
            :categories => [],
            :link => post.data["link"] || "",
            :mt_basename => post.slug,
            :mt_tags => post.tags.join(", "),
            :mt_keywords => post.tags.join(", "),
            :custom_fields => custom_fields(post),
        }
    end
    
    # return a custom post data structure. Can't just return eveything, because if the
    # client returns it all, it'll overwrite things like the title.
    # TODO - this needs to be a configurable list. Maybe just remove the known ones
    # and return everything else? but then we're coercing everything down to a string.
    def custom_fields(post)
        fields = [ :layout, :textlink ]
        return fields.map{|k| { :key => k, :value => post.data[k.to_s] ? post.data[k.to_s].to_s : "" } }
    end
    
    
    # given a post object, and an incoming metaweblog data structure, populate the post from the data.
    def populate(post, data)
        post.title = data["title"]
        post.body = data["description"].strip
        post.data["link"] = data["link"]

        if data.include? "mt_basename"
            post.slug = data["mt_basename"]
        end
        
        # try not to destroy post tags if the client doens't send any tag information.
        # otherwise, combine tags and keywords (clients aren't consistent)
        tags = nil
        if data.include? "mt_tags"
            tags ||= []
            tags << data["mt_tags"].split(/\s*,\s*/)
        end
        if data.include? "mt_keywords"
            tags ||= []
            tags << data["mt_keywords"].split(/\s*,\s*/)
        end
        if not tags.nil?
            post.tags = tags.sort.uniq
        end

        # this (in theory) will map directly to file extension
        if data.include? "mt_convert_breaks"
            conv = data["mt_convert_breaks"]
            if [ "markdown", "html" ].include? conv
                post.filetype = conv
            end
        end

        
        if data.include? "custom_fields"
            for field in data["custom_fields"]
                post.data[ field["key"] ] = field["value"]
            end
        end
        
    end
    

    def getPostOrDie(postId)
        post = store.getPost(postId)
        if not post
            raise XMLRPC::FaultException.new(-99, "post not found")
        end
        return post
    end

    ###################################################
    # API implementations follow

    # BLogger API
 
    def deletePost(apikey, postId, user, pass, publish)
        # weird method sig, this.
        store.deletePost(postId)
        return true
    end


    # Metaweblog API
    
    def getRecentPosts(blogId, user, password, limit)
        posts = store.posts[0,limit]
        return posts.map{|p| post_response(p) }
    end
    
    def getCategories(blogId, user, password)
        return []
        return store.posts.map{|p| p.tags }.flatten.uniq
    end
    
    def getPost(postId, username, password)
        return post_response(getPostOrDie(postId))
    end

    def editPost(postId, username, password, data, publish)
        post = getPostOrDie(postId)
        populate(post, data)
        post.write
        return true
    end

    def newPost(blogId, username, password, data, publish)
        date = Date.today
        post = store.newPost(date)
        populate(post, data)
        post.write
        return post.filename
    end




    
    # MoveableType API

    def supportedTextFilters()
        # keys should map to file extensions. TODO - reuse same list in populate.
        return [
            { "key" => "markdown", "label" => "Markdown" },
            { "key" => "html", "label" => "HTML" },
        ]
    end
    
    def getCategoryList(blogId, user, pass)
        return []
    end
    
    def getPostCategories(postId, user, pass)
        return []
    end
    
    def setPostCategories(postId, user, pass, categories)
        return true
    end
    
    
    
    
    
    # wordpress API
    
    def getPages(blogId, user, pass, limit)
        return []
    end


end