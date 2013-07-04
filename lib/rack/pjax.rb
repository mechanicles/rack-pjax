require 'nokogiri'

module Rack
  class Pjax
    include Rack::Utils

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      return [status, headers, body] unless pjax?(env)

      headers = HeaderHash.new(headers)

      controller_name = env["action_dispatch.request.parameters"]["controller"]

      new_body = ""
      body.each do |b|
        b.force_encoding('UTF-8') if RUBY_VERSION > '1.9.0'

        parsed_body = Nokogiri::HTML(b)
        container = parsed_body.at(container_selector(env))

        new_body << begin
          if container
            title = parsed_body.at("title")

            script = <<-EOS
              <script type="text/javascript">
                $(document).ready(function(event) {
                    $('#pjax-controller-css').attr('href', "/assets/#{controller_name}.css?body=1");

                    var script  = document.createElement('script');
                    script.type = "text/javascript";
                    script.src  = "/assets/#{controller_name}.js";
                    $("head").append(script);
                  });
              </script>
            EOS

            "%s%s%s" % [title, container.inner_html, script]
          else
            b
          end
        end
      end

      body.close if body.respond_to?(:close)

      headers['Content-Length'] &&= bytesize(new_body).to_s
      headers['X-PJAX-URL'] = Rack::Request.new(env).fullpath

      [status, headers, [new_body]]
    end

    protected
      def pjax?(env)
        env['HTTP_X_PJAX']
      end

      def container_selector(env)
        env['HTTP_X_PJAX_CONTAINER'] || "[@data-pjax-container]"
      end
  end
end
