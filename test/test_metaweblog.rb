require "test/unit"
require 'store'
require 'metaweblog'
require "fileutils"
require 'post'


class TestMetaWeblog < Test::Unit::TestCase
    
    def setup
        @base = "_testdata"
        if File.directory? @base
            FileUtils.rm_rf @base
        end
        FileUtils.mkdir_p @base
        
        @store = Store.new(@base)

        @meta = MetaWeblog.new(@store, "localhost", 4040)
        
        @blogId = 1
        @user = "user"
        @pass = "pass"
        
    end
    
    def test_deletePost
        # deleting non-existant post fails
        assert(!@meta.deletePost("apikey", "_posts/2030-01-01-something.html", @user, @pass, "publish"))

        @store.create(:post, "something.html", Date.civil(1999,1,1)).write
        
        assert(@store.get("_posts/1999-01-01-something.html")) # psot exists

        assert(@meta.deletePost("apikey", "_posts/1999-01-01-something.html", @user, @pass, "publish"))
        
        assert_nil(@store.get("_posts/1999-01-01-something.html")) # post no longer exists
    end
    
    def test_getRecentPosts
        posts = @meta.getRecentPosts(1, @user, @pass, 20)
        assert_equal(0, posts.size)
        
        @store.create(:post, "something.html", Date.civil(1999,1,1)).write
        
        posts = @meta.getRecentPosts(1, @user, @pass, 20)
        assert_equal(1, posts.size)
        assert_equal( "something", posts[0][:mt_basename] )
        
        # more posts
        @store.create(:post, "two.html", Date.civil(1999,1,2)).write
        @store.create(:post, "four.html", Date.civil(1999,1,4)).write
        @store.create(:post, "three.html", Date.civil(1999,1,3)).write

        # recent posts are sorted
        posts = @meta.getRecentPosts(1, @user, @pass, 20)
        assert_equal(4, posts.size)
        assert_equal( "four", posts[0][:mt_basename] )

        # limit works
        posts = @meta.getRecentPosts(1, @user, @pass, 2)
        assert_equal(2, posts.size)
        assert_equal( "four", posts[0][:mt_basename] ) # sort still correct
    end
    
    def test_getCategories
        cats = @meta.getCategories(@blogid, @user, @pass)
        assert_equal( [], cats, "no categories" )
    end
    
    def test_getPost
        # can't get posts that don't exist
        assert_raise( XMLRPC::FaultException, "can't get post that doesn't exist") {
            post = @meta.getPost("id", @user, @pass)
        }
        
        # can get a post by ID, which is the same as the filename
        post = @store.create(:post, "page.html", Date.civil(1999,1,1))
        post.body = "test body"
        @store.write(post)
        post = @meta.getPost("_posts/1999-01-01-page.html", @user, @pass)
        assert_equal("page", post[:mt_basename])
        assert_equal("html", post[:mt_convert_breaks])
        assert_equal("test body\n", post[:description])
        
        # for page names with non-supported extensions, we just put the whole thing in the slug.
        post = @store.create(:post, "style.css", Date.civil(1999,1,2))
        post.body = "css body"
        @store.write(post)
        post = @meta.getPost("_posts/1999-01-02-style.css", @user, @pass)
        assert_equal("style.css", post[:mt_basename])
        assert_equal("0", post[:mt_convert_breaks])
        assert_equal("css body\n", post[:description])
    end

    def test_editPost
        @store.create(:post, "something.html", Date.civil(1999,1,1)).write
        post = @store.get("_posts/1999-01-01-something.html")
        assert_equal("", post.body)
        assert_equal(nil, post.title)
        
        @meta.editPost( post.filename, @user, @pass, { "title" => "new title", "description" => "new body" }, true )

        post = @store.get("_posts/1999-01-01-something.html")
        assert_equal("new body\n", post.body)
        assert_equal("new title", post.title)
        
        # now try editing more interesting properties

        # can change filter, and file is renamed
        @meta.editPost( post.filename, @user, @pass, { "mt_convert_breaks" => "markdown" }, true )
        assert_equal(1, @store.posts.size)
        assert_nil @store.get("_posts/1999-01-01-something.html")
        post = @store.get("_posts/1999-01-01-something.markdown")
        assert_equal("something.markdown", post.slug)
        
        # can change slug, and file is renamed
        @meta.editPost( post.filename, @user, @pass, { "mt_basename" => "renamed" }, true )
        assert_equal(1, @store.posts.size)
        assert_nil @store.get("_posts/1999-01-01-something.markdown")
        assert post = @store.get("_posts/1999-01-01-renamed.markdown")
        assert_equal("renamed.markdown", post.slug)
        
        # can remove filter and control filename directly
        @meta.editPost( post.filename, @user, @pass, { "mt_basename" => "style.css", "mt_convert_breaks" => "0" }, true )
        assert_equal(1, @store.posts.size)
        assert post = @store.get("_posts/1999-01-01-style.css")
        
        # can restore a filter to a direct file.
        @meta.editPost( post.filename, @user, @pass, { "mt_basename" => "foo", "mt_convert_breaks" => "html" }, true )
        assert_equal(1, @store.posts.size)
        assert post = @store.get("_posts/1999-01-01-foo.html")
        
        # can change custom fields
        custom = [ { "key" => "layout", "value" => "base" } ]
        @meta.editPost( post.filename, @user, @pass, { "custom_fields" => custom }, true )
        post = @store.get(post.filename)
        assert_equal("base", post.data["layout"])
        
        # change tags
        @meta.editPost( post.filename, @user, @pass, { "mt_tags" => "a,c  , b" }, true )
        post = @store.get(post.filename)
        assert_equal(["a", "b", "c"], post.tags)

        @meta.editPost( post.filename, @user, @pass, { "mt_keywords" => "foo, bar, baz" }, true )
        post = @store.get(post.filename)
        assert_equal(["bar", "baz", "foo"], post.tags)
        
        
    end

    def test_newPost
        assert_equal(0, @store.posts.size)
        
        assert @meta.newPost(@blogId, @user, @pass, {
            "title" => "new post",
            "description" => "new post body",
        }, true)

        assert_equal(1, @store.posts.size)
        post = @store.posts[0]
        assert_equal("new post", post.title)
        assert_equal(Date.today, post.date)
    end




    
    # MoveableType API

    def test_supportedTextFilters
        filters = @meta.supportedTextFilters
        assert_equal(2, filters.size)
    end
    
    def test_getCategoryList
        list = @meta.getCategoryList(@blogId, @user, @pass)
        assert_equal(0, list.size)
    end
    
    def test_getPostCategories
        list = @meta.getPostCategories("meaningless id", @user, @pass)
        assert_equal(0, list.size)
    end
    
    def test_setPostCategories
        assert @meta.setPostCategories("meaningless id", @user, @pass, [ "a", "b", "c" ])
    end
    
    
    
    
    
    # wordpress API
    
    def test_getPages
        pages = @meta.getPages(@blogId, @user, @pass, 20)
        assert_equal(0, pages.size)
        
        @store.create(:page, "new_page.html").write

        pages = @meta.getPages(@blogId, @user, @pass, 20)
        assert_equal(1, pages.size)
        assert_equal("new_page", pages[0][:mt_basename])
        assert_equal("new_page.html", pages[0][:page_id])
    end
    
    def test_getTags
        tags = @meta.getTags(@blogId, @user, @pass)
        assert_equal(0, tags.size)

        page = @store.create(:page, "new_page.html")
        page.tags = ["a", "b", "c"]
        @store.write(page)

        tags = @meta.getTags(@blogId, @user, @pass)
        assert_equal(3, tags.size)
        assert_equal(1, tags[0][:count])
        assert_equal(1, tags[1][:count])
        assert_equal(1, tags[2][:count])

        page = @store.create(:page, "another_new_page.html")
        page.tags = ["b", "c", "d"]
        @store.write(page)

        tags = @meta.getTags(@blogId, @user, @pass)
        assert_equal(4, tags.size)
        assert_equal(1, tags[0][:count])
        assert_equal(2, tags[1][:count])
        assert_equal(2, tags[2][:count])
        assert_equal(1, tags[3][:count])
    end
    
    def test_editPage
        page = @store.create(:page, "new_page.html")
        @store.write(page)
        
        @meta.editPage(@blogId, "new_page.html", @user, @pass, {
            "title" => "new page title",
        }, true)
        
        page = @store.get("new_page.html")
        assert_equal("new page title", page.title)
    end



end