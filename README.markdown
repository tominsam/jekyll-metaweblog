## jekyll-metaweblog

A stand-alone server that will expose a Jekyll source folder via the Blogger / MT / Wordpress XML-RPC metaweblog interface, allowing you to create/edit/delete posts and pages using a GUI client, such as Marsedit.



### Usage

  ruby jm_server.rb --port 4040 --root /path/to/jekyll/folder

Then point your weblog client to http://localhost:4040/xmlrpc.php and start editing.

By default, the server will publish the `_site` folder inside your root folder as web pages as well. This is for convenience to to convince certain unruly clients that there really is a web page there. Use the `--web` parameter if you want to publish a different folder.

This code doesn't (yet) auto-publish things you save through jekyll, so you'll probably also want to have your `jekyll --auto` command-line process running in a different terminal window.



### Limitations

If you change the slug, date, or the text filter of an entry, you'll need to refresh the blog after you save it. (I use the filename as the post ID, but changing the slug or the filter changes the filename, so the GUI tool will lose the connection).

Not all clients work. Let me know if you're using a weird client and having problems. And by weird, I mean, not Marsedit or Ecto, which are the two I have here.

File upload support is very very new. Might work.


### TODO

* username/password support, so it's safe to run on a remote server.

* run the jekyll processor in the same process, so you can run a single command line that will build your blog _and_ expose it to GUI clients.

* Support for more clients (this mostly consists of trying them and fixing the broken things)

* category support (assuming jekyll does categories and anyone cares)

* Support for wordpress IOS clients. This is _hard_, because they're using undocumented API calls and make assumptions about what IDs look like that I'm not happy with (it assumes they're numbers).

* everything else in the code with "TODO" by it.

* fix all the bugs. AHAHAHAHAHAHAHAH

* Test - can I work around the slug/date changing the ID by responding to getPage( old_id ) and returning a page with the new ID? Most clients seem to call getPage after making changes.

* Draft post/page support. Write things into a _drafts folder or something.
