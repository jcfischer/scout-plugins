require 'net/http'
require 'uri'

class UrlMonitor < Scout::Plugin
  include Net
  
  TEST_USAGE = "#{File.basename($0)} url URL last_run LAST_RUN"
  TIMEOUT_LENGTH = 50 # seconds
  
  def run
    if @options["url"].strip.length == 0
      return { :error => { :subject => "A url wasn't provided." } }
    end
    
    unless (@options["url"].index("http://") == 0 || @options["url"].index("https://") == 0)
      @options["url"] = "http://" + @options["url"]
    end

    report = { :report => { :up     => 0, # 1 if working, 0 if not
                            :status => nil # the HTTP status
                          },
               :alerts => Array.new }
    
    response = http_response
    report[:report][:status] = response.class.to_s
    body = response.body


    if valid_http_response?(response)
      report[:report][:up] = 1
      if body =~ /#{pattern}/
        report[:report][:match] = 1
      else
        report[:report][:match] = 0
      end
    else 
      report[:report][:up] = 0
      report[:alerts] << {:subject => "The URL [#{@options['url']}] is not responding",
                          :body => "URL: #{@options['url']}\n\nStatus: #{report[:report][:status]}"}
    end
    report
  rescue
    { :error => { :subject => "Error monitoring url [#{@options['url']}]",
                  :body    => $!.message } }
  end
  
  def valid_http_response?(result)
    [HTTPOK,HTTPFound].include?(result.class) 
  end
  
  # returns the http response (string) from a url
  def http_response  
    url = @options['url']

    uri = URI.parse(url)

    response = nil
    retry_url_trailing_slash = true
    retry_url_execution_expired = true
    begin
      Net::HTTP.start(uri.host) {|http|
            http.open_timeout = TIMEOUT_LENGTH
            req = Net::HTTP::Get.new((uri.path != '' ? uri.path : '/' ) + (uri.query ? ('?' + uri.query) : ''))
            if uri.user && uri.password
              req.basic_auth uri.user, uri.password
            end
            response = http.request(req)
      }
    rescue Exception => e
      # forgot the trailing slash...add and retry
      if e.message == "HTTP request path is empty" and retry_url_trailing_slash
        url += '/'
        uri = URI.parse(url)
        h = Net::HTTP.new(uri.host)
        retry_url_trailing_slash = false
        retry
      elsif e.message =~ /execution expired/ and retry_url_execution_expired
        retry_url_execution_expired = false
        retry
      else
        response = e.to_s
      end
    end
        
    return response
  end
  
  
end

