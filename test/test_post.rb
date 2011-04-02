require "test/unit"
require 'store'
require 'metaweblog'
require "fileutils"
require 'post'


class TestPost < Test::Unit::TestCase
    
    def setup
        @base = "_testdata"
        if File.directory? @base
            FileUtils.rm_rf @base
        end
        FileUtils.mkdir_p @base
    end
    
    def test_page
        page = Post.new(@base, "test_page.html")
        assert_equal(:page, page.type)
        assert_equal("test_page.html", page.slug, "post slug")
        assert(!page.read, "file doesn't exist")

        page.body = "test body"
        page.title = "test title"
        page.data["foo"] = "foo"
        page.data["list"] = [1,2,3]
        page.tags = ["a", "b", "c"]
        page.write

        assert_equal("test_page.html", page.filename, "page has the correct filename")
        assert(File.exists?(File.join(@base, "test_page.html")), "page is stored on disk")

        page2 = Post.new(@base, "test_page.html")
        assert(page2.read, "can read post now")
        assert_equal("test title", page2.title, "page has title")
        assert_equal("test body\n", page2.body, "body has trailing newline")
        assert_equal("foo", page2.data["foo"], "data is stored properly")
        assert_equal([1,2,3], page2.data["list"], "array data is stored properly")
        assert_equal(["a", "b", "c"], page2.tags, "page tags accessor works")
        
        # rename the page and save again
        page.slug = "rename_page.html"
        page.write
        
        assert_equal("rename_page.html", page.filename)
        assert(!File.exists?(File.join(@base, "test_page.html")), "old file has been removed")
        assert(File.exists?(File.join(@base, page.filename)), "new file now exists")
        
        assert_match(/\(page\)/, page.to_s, "stringification contains page type")
        assert_match(/rename_page.html/, page.to_s, "stringification contains page filename")

    end

    def test_post
        post = Post.new(@base, "_posts/2010-01-01-test.html")
        assert_equal(:post, post.type)
        assert_equal(Date.civil(2010, 1, 1), post.date, "post date")
        assert_equal("test.html", post.slug, "post slug")

        post.body = "test body"
        post.title = "test title"
        post.write

        assert(File.exists?(File.join(@base, "_posts/2010-01-01-test.html")), "post written to disk")

        post2 = Post.new(@base, "_posts/2010-01-01-test.html")
        assert(post2.read, "can read post now")
        assert_equal("test title", post2.title, "page has title")
        assert_equal("test body\n", post2.body, "body has trailing newline")

        # rename the post and save again
        post.slug = "rename.html"
        post.write
        
        assert(!File.exists?(File.join(@base, "_posts/2010-01-01-test.html")), "old post removed from disk")
        assert(File.exists?(File.join(@base, "_posts/2010-01-01-rename.html")), "new post written to disk")

    end
    
    def test_invalid_file
        File.open(File.join(@base,"test.html"),"w"){|f|
            f.write("this is not YAML preamble")
        }
        page = Post.new(@base, "test.html")
        assert(!page.read, "can't read page without preamble")
        
        File.open(File.join(@base,"zero.html"),"w"){|f|
        }
        page = Post.new(@base, "zero.html")
        assert(!page.read, "can't read zero-length file")
        
    end
 
end
