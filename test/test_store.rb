require "test/unit"
require 'store'
require 'metaweblog'
require 'post'
require "fileutils"

class TestStore < Test::Unit::TestCase
    
    def setup
        @base = "_testdata"
        if File.directory? @base
            FileUtils.rm_rf @base
        end
        FileUtils.mkdir_p @base
        
        @store = Store.new(@base)
    end
    
    def test_list
        assert_equal(0, @store.posts.size)
        assert_equal(0, @store.pages.size)
        
        page = Post.new(@base, "test.html")
        page.body = "body"
        page.title = "title"
        page.write
        
        assert_equal(0, @store.posts.size)
        assert_equal(1, @store.pages.size)
        
        page = @store.pages[0]
        assert_equal("title", page.title)
        assert_equal("body\n", page.body)
        
    end
    
    def test_recursive
        FileUtils.mkdir_p(File.join(@base, "foo", "bar", "baz"))
        File.open(File.join(@base, "foo", "bar", "baz", "ning.html"), "w"){|f|
            f.write("---\n")
            f.write("title: title\n")
            f.write("---\n\n")
            f.write("body here\n")
        }

        assert_equal(1, @store.pages.size)
        
        page = @store.pages[0]
        assert_equal("title", page.title)
        assert_equal("body here\n", page.body)
        assert_equal("foo/bar/baz/ning.html", page.slug)
    end
    
    def test_get
        assert_nil @store.get("foo.html")

        page = Post.new(@base, "test.html")
        page.body = "body"
        page.title = "title"
        page.write

        page = @store.get("test.html")
        assert_equal("title", page.title)
        assert_equal("body\n", page.body)
        
        
        assert_nil @store.get("_posts/bar.html")
        
        post = Post.new(@base, "_posts/2010-01-01-test.html")
        post.write

        post = @store.get("_posts/2010-01-01-test.html")
        assert( post )
        
    end
    
    def test_create
        page = @store.create(:post, "foo.html", Date.civil(2011, 2, 3))
        page.title = "post title"
        @store.write(page)
        page = @store.get("_posts/2011-02-03-foo.html")
        assert_equal("foo.html", page.slug)
        assert_equal(:post, page.type)

        page = @store.create(:page, "page.html")
        page.title = "page title"
        @store.write(page)
        page = @store.get("page.html")
        assert_equal("page title", page.title)
        assert_equal(:page, page.type)
        
    end

    def test_delete
        assert_nil @store.get("foo.html")

        page = @store.create(:post, "page.html", Date.civil(2011,1,2))
        @store.write(page)
        assert(File.exists?(File.join(@base, "_posts", "2011-01-02-page.html")))
        @store.delete("_posts/2011-01-02-page.html")
        assert(!File.exists?(File.join(@base, "_posts", "2011-01-02-page.html")))

        page = @store.create(:page, "page.html")
        @store.write(page)
        assert(File.exists?(File.join(@base, "page.html")))
        @store.delete("page.html")
        assert(!File.exists?(File.join(@base, "page.html")))
        

    end
    
 
end
