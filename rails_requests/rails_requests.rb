require "time"

class RailsRequests < Scout::Plugin
  
  TEST_USAGE = "#{File.basename($0)} log LOG max_request_length MAX_REQUEST_LENGTH last_run LAST_RUN"
  
  def run
    begin
      require "elif"
    rescue LoadError
      begin
        require "rubygems"
        require "elif"
      rescue LoadError
        return { :error => { :subject => "Couldn't load Elif.",
                             :body    => "The Elif library is required by " +
                                         "this plugin." } }
      end
    end
    
    if @options["log"].strip.length == 0
      return { :error => { :subject => "A path to the Rails log file wasn't provided." } }
    end

    report = { :report => { :slow_request_count => 0,
                            :request_count => 0,
                            :average_request_length => nil},
               :alerts => Array.new }
    
    last_completed = nil
    slow_requests = ''
    total_request_time = 0.0

    last_run = if @options["last_run"] 
                  Time.parse(@options["last_run"])
               else
                  @last_run || Time.now
               end

    Elif.foreach(@options["log"]) do |line|
      if line =~ /\ACompleted in (\d+)ms .+ \[(\S+)\]\Z/
        last_completed = [$1.to_f, $2]
      elsif last_completed and
            line =~ /\AProcessing .+ at (\d+-\d+-\d+ \d+:\d+:\d+)\)/
        time_of_request = Time.parse($1)
        if time_of_request < last_run
          break
        else
          report[:report][:request_count] += 1
          total_request_time += last_completed.first.to_f
          if @options["max_request_length"].to_f > 0 and last_completed.first.to_f > @options["max_request_length"].to_f
            report[:report][:slow_request_count] += 1
            slow_requests += "#{last_completed.last}\n"
            slow_requests += "Time: " + last_completed.first.to_s + " ms" + "\n\n"
          end
        end # request should be analyzed
      end
    end
    
    # Create a single alert that holds all of the requests that exceeded the +max_request_length+.
    if report[:report] and (count = report[:report][:slow_request_count].to_i and count > 0)
      report[:alerts] << {:subject => "Maximum Time(#{@options["max_request_length"].to_s} ms) exceeded on #{count} #{count > 1 ? 'requests' : 'request'}",
                          :body => slow_requests}
    end
    # Calculate the average request time if there are any requests
    if report[:report][:request_count] > 0
      avg = total_request_time/report[:report][:request_count]
      report[:report][:average_request_length] = sprintf("%.2f", avg)
    end
    report
  rescue
    if $!.message == "undefined method `strip' for nil:NilClass"
      { :error => {:subject => "Please provide the full path to the log file.",
                   :body => "A full path to the Rails log file wasn't provided - you can specify the path in the plugin options."}}
    else
      { :error => { :subject => "Couldn't parse log file.",
                  :body    => $!.message } }
    end
  end
end
