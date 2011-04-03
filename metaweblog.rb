require 'rubygems'
require 'json'
require 'xmlrpc/server'

# not just the metaweblog API - this is _all_ the APIs crammed into one namespace. Ugly.

# references:
#
# http://txp.kusor.com/rpc-api/blogger-api
#
# http://codex.wordpress.org/XML-RPC_wp
#


class MetaWeblog
    attr_accessor :store, :filters, :custom_field_names, :host, :port
    

    def initialize(store, host, port)
        self.store = store
        self.host = host
        self.port = port


        # keys should map to file extensions. We rename the file if the filter is changed.
        self.filters = [
            { "key" => "markdown", "label" => "Markdown" },
            { "key" => "html", "label" => "HTML" },
        ]
        
        self.custom_field_names = [ :layout, :textlink, :permalink ]
    end
    
    # convert a post into a structure that we expect to return from metaweblog. Some repetition
    # here to convince stroppy clients that we really do mean these things. Be careful to not
    # return any nils, XML-RPC can't cope with them.
    def post_response(post)
        # if the file extension is one of the permitted filters, treat it as a filter
        m = post.slug.match(/^(.*)\.(.*?)$/)
        if m and self.filters.map{|f| f["key"] }.include? m[2]
            basename = m[1]
            filter_key = m[2]
        else
            basename = post.slug
            filter_key = "0" # means 'no filter'
        end
        
        # always return _something_ as a title, rather than a blank string. Not totally
        # happy about this, but lots of clients insist on a title.
        title = post.title || ""
        if title.size == 0
            title = post.slug
        end
        
        return {
            :postId => post.filename,
            :title => title,
            :description => post.body || "",
            :dateCreated => post.date || Date.today,
            :categories => [],
            :link => post.data["link"] || "",
            :mt_basename => basename,
            :mt_tags => post.tags.join(", "),
            :mt_keywords => post.tags.join(", "),
            :custom_fields => custom_fields(post),
            :mt_convert_breaks => filter_key,
            :post_status => "publish",
        }
    end
    
    # wordpress pages have all the stuff posts have, and also some extra things.
    # These must be present, or Marsedit will just dump them in with the posts.
    def page_response(post)
        return post_response(post).merge({
            :page_id => post.filename, # spec says this is an integer, but most clients I've tried can cope.
            :dateCreated => Date.today, # Not happy about this.
            :page_status => "publish",
            :wp_page_template => post.data["layout"] || "",
        })
    end
    
    # return a custom post data structure. Can't just return eveything, because if the
    # client returns it all, it'll overwrite things like the title.
    def custom_fields(post)
        return self.custom_field_names.map{|k| { :key => k, :value => post.data[k.to_s] ? post.data[k.to_s].to_s : "" } }
    end
    
    
    # given a post object, and an incoming metaweblog data structure, populate the post from the data.
    def populate(post, data)
        # we send the slug as the title if there's no title. Don't take it back.
        if data["title"] != post.slug
            post.title = data["title"]
        end

        if data["description"]
            post.body = data["description"].strip
        end

        post.data["link"] = data["link"]
        
        if d = data["dateCreated"]
            if d.instance_of? XMLRPC::DateTime
                post.date = Date.civil(d.year, d.month, d.day)
            else
                puts "Can't deal with date #{d}"
            end
        end

        # try not to destroy post tags if the client doens't send any tag information.
        # otherwise, combine tags and keywords (clients aren't consistent). Will this
        # make it hard to remove tags? Needs testing.
        tags = nil
        if data.include? "mt_tags"
            tags ||= []
            tags += data["mt_tags"].split(/\s*,\s*/)
        end
        if data.include? "mt_keywords"
            tags ||= []
            tags += data["mt_keywords"].split(/\s*,\s*/)
        end
        if not tags.nil?
            post.tags = tags.sort.uniq
        end


        if data.include? "mt_convert_breaks" or data.include? "mt_basename"
            # if the file extension is one of the permitted filters, treat it as a filter
            m = post.slug.match(/^(.*)\.(.*?)$/)
            if m and self.filters.map{|f| f["key"] }.include? m[2]
                basename = m[1]
                filter_key = m[2]
            else
                basename = post.slug
                filter_key = "0" # means 'no filter'
            end 
            
            if data.include? "mt_basename"
                basename = data["mt_basename"]
            end

            if data.include? "mt_convert_breaks"
                filter_key = data["mt_convert_breaks"]
            end
            
            # have to have _something_
            if not basename.match(/\./) and filter_key == "0"
                filter_key = "html"
            end
        
            post.slug = basename
            if filter_key != "0"
                post.slug += "." + filter_key
            end
        end

        if data.include? "custom_fields"
            for field in data["custom_fields"]
                post.data[ field["key"] ] = field["value"]
            end
        end
        
    end
    

    def getPostOrDie(postId)
        post = store.get(postId)
        if not post
            raise XMLRPC::FaultException.new(-99, "post not found")
        end
        return post
    end

    ###################################################
    # API implementations follow

    # Blogger API
 
    # weird method sig, this.
    def deletePost(apikey, postId, user, pass, publish)
        return store.delete(postId)
    end


    # Metaweblog API
    
    def getRecentPosts(blogId, user, password, limit)
        posts = store.posts[0,limit.to_i]
        return posts.map{|p| post_response(p) }
    end
    
    def getCategories(blogId, user, password)
        # later blogging engines have actual tag support, and we
        # don't have to fake things with cstegories. I think jekyll has proper
        # category support, though, so it might be worth looking at that some
        # time..
        return []
        
        #return store.posts.map{|p| p.tags }.flatten.uniq
    end
    
    def getPost(postId, username, password, extra = {})
        return post_response(getPostOrDie(postId))
    end

    def editPost(postId, username, password, data, publish)
        post = getPostOrDie(postId)
        populate(post, data)
        store.write(post)
        return true
    end

    def newPost(blogId, username, password, data, publish = true)
        post = store.create(:post, nil, Date.today) # date is just default
        populate(post, data)
        store.write(post)
        return post.filename
    end




    
    # MoveableType API
    
    def supportedTextFilters()
        return self.filters
    end
    
    # no categories yet.

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
    
    def getPage(blogId, pageId, user, pass)
        page = store.get(pageId)
        return page_response(page)
    end
    
    def getPages(blogId, user, pass, limit)
        pages = store.pages[0,limit]
        return pages.map{|p| page_response(p) }
    end
    
    def getTags(blogId, user, pass)
        all_tags = ( store.posts + store.pages ).map{|p| p.tags }.flatten
        grouped = {}
        all_tags.each_with_index{|t, i|
            grouped[t] ||= {
                :tag_id => t, # TODO - spec says this is an int. But I can't do that.
                :name => t,
                :count => 0,
                :slug => t,
            }
            grouped[t][:count] += 1
        }
        return grouped.values
    end
    
    def editPage(blogId, pageId, user, pass, data, publish)
        page = @store.get(pageId)
        populate(page, data)
        @store.write(page)
        return true
    end
    
    def getUsersBlogs(something, user, pass = nil) # TODO - it's the _first_ param that is optional
        return [
            { :isAdmin => true,
                :url => "http://#{self.host}:#{self.port}/",
                :blogId => 1,
                :blogName => "jekyll",
                :xmlrpc => "http://#{self.host}:#{self.port}/xmlrpc.php",
            }
        ]
    end
    
    def getComments(postId, user, pass, extra)
        return []
    end



end