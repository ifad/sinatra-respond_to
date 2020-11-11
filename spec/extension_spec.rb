require File.join(File.dirname(__FILE__), 'spec_helper')

describe Sinatra::RespondTo do
  def mime_type(sym)
    ::Sinatra::Base.mime_type(sym)
  end

  describe "settings" do
    it "should initialize with :default_content set to :html" do
      expect(TestApp.default_content).to eq(:html)
    end

    it "should initialize with :assume_xhr_is_js set to true" do
      TestApp.assume_xhr_is_js == true
    end
  end

  describe "assume_xhr_is_js" do
    it "should set the content type to application/javascript for an XMLHttpRequest" do
      header 'X_REQUESTED_WITH', 'XMLHttpRequest'

      get '/resource'

      expect(last_response['Content-Type']).to match(%r{#{mime_type(:js)}})
    end

    it "should not set the content type to application/javascript for an XMLHttpRequest when assume_xhr_is_js is false" do
      TestApp.disable :assume_xhr_is_js
      header 'X_REQUESTED_WITH', 'XMLHttpRequest'
      get '/resource'

      expect(last_response['Content-Type']).not_to match(%r{#{mime_type(:js)}})

      # Put back the option, no side effects here
      TestApp.enable :assume_xhr_is_js
    end

    it "should not set the content type to application/javascript for an XMLHttpRequest to an explicit extension" do
      header 'X_REQUESTED_WITH', 'XMLHttpRequest'

      get '/resource.json'

      expect(last_response['Content-Type']).to match(%r{#{mime_type(:json)}})
    end
  end

  describe "extension routing" do
    it "should use a format parameter before sniffing out the extension" do
      get "/resource?format=xml"
      expect(last_response.body).to match(%r{\s*<root>Some XML</root>\s*})
      expect(last_response.content_type).to include(mime_type(:xml))
      expect(last_request.env['HTTP_ACCEPT']).to eq(mime_type(:xml))
    end

    it "breaks routes expecting an extension" do
      # In test_app.rb the route is defined as get '/style.css' instead of get '/style'
      get "/style.css"

      expect(last_response).not_to be_ok
    end

    it "should pick the default content option for routes with out an extension, and render haml templates" do
      get "/resource"

      expect(last_response.body).to match(%r{\s*<html>\s*<body>Hello from HTML</body>\s*</html>\s*})
      expect(last_response.content_type).to include(mime_type(:html))
    end

    it "should render for a template using builder" do
      get "/resource.xml"

      expect(last_response.body).to match(%r{\s*<root>Some XML</root>\s*})
      expect(last_response.content_type).to include(mime_type(:xml))
      expect(last_request.env['HTTP_ACCEPT']).to eq(mime_type(:xml))
    end

    it "should render for a template using erb" do
      get "/resource.js"

      expect(last_response.body).to match(%r{'Hiya from javascript'})
      expect(last_response.content_type).to include(mime_type(:js))
      expect(last_request.env['HTTP_ACCEPT']).to eq(mime_type(:js))
    end

    it "should return string literals in block" do
      get "/resource.json"

      expect(last_response.body).to match(%r{We got some json})
      expect(last_response.content_type).to include(mime_type(:json))
      expect(last_request.env['HTTP_ACCEPT']).to eq(mime_type(:json))
    end

    # This will fail if the above is failing
    it "should set the appropriate content-type for route with an extension" do
      get "/resource.xml"

      expect(last_response['Content-Type']).to match(%r{#{mime_type(:xml)}})
    end

    it "should honor a change in character set in block" do
      get "/iso-8859-1"

      expect(last_response['Content-Type']).to match(%r{charset=iso-8859-1})
    end

    it "should return not found when path does not exist" do
      get "/nonexistant-path.txt"

      expect(last_response.status).to eq(404)
    end

    describe "for static files" do
      before(:all) do
        TestApp.enable :static
      end

      after(:all) do
        TestApp.disable :static
      end

      it "should allow serving static files from public directory" do
        get '/static.txt'

        expect(last_response.body).to eq("A static file")
      end

      it "should only serve files when static routing is enabled" do
        TestApp.disable :static
        get '/static.txt'

        expect(last_response).not_to be_ok
        expect(last_response.body).not_to eq("A static file")

        TestApp.enable :static
      end

      it "should not allow serving static files from outside the public directory" do
        get '/../unreachable_static.txt'

        expect(last_response).not_to be_ok
        expect(last_response.body).not_to eq("Unreachable static file")
      end
    end
  end

  describe "accept routing" do
    it "should use a format parameter before sniffing out the accept header" do
      get "/resource?format=xml", {}, {'HTTP_ACCEPT' => "text/html"}
      expect(last_response.body).to match(%r{\s*<root>Some XML</root>\s*})
      expect(last_response.content_type).to include(mime_type(:xml))
      expect(last_request.env['HTTP_ACCEPT']).to eq(mime_type(:xml))
    end

    it "should use an extension before sniffing out the accept header" do
      get "/resource.xml", {}, {'HTTP_ACCEPT' => "text/html"}

      expect(last_response.body).to match(%r{\s*<root>Some XML</root>\s*})
      expect(last_response.content_type).to include(mime_type(:xml))
      expect(last_request.env['HTTP_ACCEPT']).to eq(mime_type(:xml))
    end

    it "should render for a template using builder" do
      get "/resource", {}, {'HTTP_ACCEPT' => "application/xml"}

      expect(last_response.body).to match(%r{\s*<root>Some XML</root>\s*})
      expect(last_response.content_type).to include(mime_type(:xml))
    end

    it "should render for a template using haml" do
      get "/resource", {}, {'HTTP_ACCEPT' => "text/html"}

      expect(last_response.body).to match(%r{\s*<html>\s*<body>Hello from HTML</body>\s*</html>\s*})
      expect(last_response.content_type).to include(mime_type(:html))
    end

    it "should render for a template using json" do
      get "/resource", {}, {'HTTP_ACCEPT' => "application/json"}

      expect(last_response.body).to match(%r{We got some json})
      expect(last_response.content_type).to include(mime_type(:json))
    end

    it "should render for a template using erb" do
      get "/resource", {}, {'HTTP_ACCEPT' => "application/javascript"}

      expect(last_response.body).to match(%r{'Hiya from javascript'})
      expect(last_response.content_type).to include(mime_type(:js))
    end
  end

  describe "routes not using respond_to" do
    it "should set the default content type when no extension" do
      get "/normal-no-respond_to"

      expect(last_response['Content-Type']).to match(%r{#{mime_type(TestApp.default_content)}})
    end

    it "should set the appropriate content type when given an extension" do
      get "/normal-no-respond_to.css"

      expect(last_response['Content-Type']).to match(%r{#{mime_type(:css)}})
    end
  end

  describe "error pages in production" do
    before(:each) do
      @app = Rack::Builder.new { run ::ProductionErrorApp }
    end

    describe Sinatra::RespondTo::MissingTemplate do
      it "should return 404 status when looking for a missing template in production" do
        get '/missing-template'

        expect(last_response.status).to eq(404)
        expect(last_response.body).not_to match(/Sinatra can't find/)
      end
    end

    describe Sinatra::RespondTo::UnhandledFormat do
      it "should return with a 404 when an extension is not supported in production" do
        get '/missing-template.txt'

        expect(last_response.status).to eq(404)
        expect(last_response.body).not_to match(/respond_to/)
      end
    end
  end

  describe "error pages in development:" do

    it "should allow access to the /__sinatra__/*.png images" do
      get '/__sinatra__/404.png'

      expect(last_response).to be_ok
    end

    describe Sinatra::RespondTo::MissingTemplate do
      it "should return 500 status when looking for a missing template" do
        get '/missing-template'

        expect(last_response.status).to eq(500)
      end

      it "should provide a helpful generic error message for a missing template when in development" do
        get '/missing-template.css'

        expect(last_response.body).to match(/missing-template\.html\.haml/)
        expect(last_response.body).to match(%r{get '/missing-template' do respond_to do |wants| wants.html \{ haml :missing-template, layout => :app \} end end})
      end

      it "should show the /__sinatra__/500.png" do
        get '/missing-template'

        expect(last_response.body).to match(%r{src=(?<quote>['"'])/__sinatra__/500.png\k<quote>})
      end

      it "should provide a contextual code example for the template engine" do
        # Haml
        get '/missing-template'

        expect(last_response.body).to match(%r{app.html.haml})
        expect(last_response.body).to match(%r{missing-template.html.haml})
        expect(last_response.body).to match(%r{get '/missing-template' do respond_to do |wants| wants.html \{ haml :missing-template, layout => :app \} end end})

        # ERB
        get '/missing-template.js'

        expect(last_response.body).to match(%r{app.html.erb})
        expect(last_response.body).to match(%r{missing-template.html.erb})
        expect(last_response.body).to match(%r{get '/missing-template' do respond_to do |wants| wants.html \{ erb :missing-template, layout => :app \} end end})

        # Builder
        get '/missing-template.xml'

        expect(last_response.body).to match(%r{app.xml.builder})
        expect(last_response.body).to match(%r{missing-template.xml.builder})
        expect(last_response.body).to match(%r{get '/missing-template' do respond_to do |wants| wants.xml \{ builder :missing-template, layout => :app \} end end})
      end
    end

    describe Sinatra::RespondTo::UnhandledFormat do
      it "should return with a 404 when an extension is not supported" do
        get '/missing-template.txt'

        expect(last_response.status).to eq(404)
      end

      it "should provide a helpful error message for an unhandled format" do
        get '/missing-template.txt'

        expect(last_response.body).to match(%r{get '/missing-template' do respond_to do |wants| wants.txt \{ "Hello World" \} end end})
      end

      it "should show the /__sinatra__/404.png" do
        get '/missing-template.txt'

        expect(last_response.body).to match(%r{src='/__sinatra__/404.png'})
      end
    end
  end

  describe "helpers:" do
    include Sinatra::Helpers
    include Sinatra::RespondTo::Helpers

    let(:response) { {'Content-Type' => 'text/html'} }

    describe "charset" do
      it "should set the working charset when called with a non blank string" do
        expect(response['Content-Type']).not_to match(/charset/)

        charset 'utf-8'

        expect(response['Content-Type'].split(';')).to include("charset=utf-8")
      end

      it "should remove the charset when called with a blank string" do
        charset 'utf-8'
        charset ''

        expect(response['Content-Type']).not_to match(/charset/)
      end

      it "should return the current charset when called with nothing" do
        charset 'utf-8'

        expect(charset).to eq('utf-8')
      end

      it "should fail when the response does not have a Content-Type" do
        response.delete('Content-Type')

        expect { charset }.to raise_error RuntimeError
      end

      it "should not modify the Content-Type when given no argument" do
        response['Content-Type'] = "text/html;charset=iso-8859-1"

        charset

        expect(response['Content-Type']).to eq("text/html;charset=iso-8859-1")
      end
    end

    describe "format" do
      let(:request) { Sinatra::Request.new({}) }
      let(:settings) { double('settings').as_null_object }

      it "should set the correct mime type when given an extension" do
        format :xml

        expect(response['Content-Type'].split(';')).to include(mime_type(:xml))
      end

      it "should fail when set to an unknown extension type" do
        expect { format :bogus }.to raise_error RuntimeError
      end

      it "should return the current mime type extension" do
        format :js

        expect(format).to eq(:js)
      end

      it "should not modify the Content-Type when given no argument" do
        response['Content-Type'] = "application/xml;charset=utf-8"

        format

        expect(response['Content-Type']).to eq("application/xml;charset=utf-8")
      end

      it "should not return nil when only content_type sets headers" do
        content_type :xhtml

        expect(format).to eq(:xhtml)
      end
    end

    describe "static_file?" do
      before(:all) do
        TestApp.enable :static
        @static_folder = "/static folder/"
        @reachable_static_file = "/static.txt"
        @unreachable_static_file = "/../unreachable_static.txt"
      end

      after(:all) do
        TestApp.disable :static
      end

      def settings
        TestApp
      end

      def unescape(path)
        Rack::Utils.unescape(path)
      end

      it "should return true if the request path points to a file in the public directory" do
        expect(static_file?(@reachable_static_file)).to be true
      end

      it "should return false when pointing to files outside of the public directory" do
        expect(static_file?(@unreachable_static_file)).to be false
      end

      it "should return false when the path is for a folder" do
        expect(static_file?(@static_folder)).to be false
      end
    end

    describe "respond_to" do
      let(:request) { Sinatra::Request.new({}) }

      it "should fail for an unknown extension" do
        expect do
          respond_to do |wants|
            wants.bogus
          end
        end.to raise_error RuntimeError
      end

      it "should call the block corresponding to the current format" do
        format :html

        expect(respond_to do |wants|
          wants.js { "Some JS" }
          wants.html { "Some HTML" }
          wants.xml { "Some XML" }
        end).to eq("Some HTML")
      end
    end
  end
end
