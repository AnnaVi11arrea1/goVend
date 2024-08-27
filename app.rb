require "sinatra"
require "sinatra/reloader"
require "openai"
require "http"
require "json"
require "sinatra/cookies"
require "thin"

get("/") do
 erb(:index, {:layout => :layout})
end

get("/chat") do
  prompt = params[:message]
  puts "Received message: #{prompt}"
  content_type 'text/event-stream'
  headers 'Cache-Control' => 'no-cache', 'Connection' => 'keep-alive'

  client = OpenAI::Client.new(:api_key => ENV["OPENAI_API_KEY"])
  stream(:keep_open) do |out|

  
  begin
    client.chat.completions(
      engine: "davinci",
      parameters: {
        prompt: "You find real events that are currently accepting applications for vendors and provide information with clickable links to the event pages and applications. The list item needs to have the following keys: Event, Location, Date, Website, Application Link. Show 5 list items.\n\nUser: #{prompt}\nAssistant: #{prompt}",
            max_tokens: 150,
            n: 1,
            stream: true
          }
    ) 
    response.body.each do |chunk|
      out << "data: #{chunk}\n\n"
    end

    rescue => e
      out << "An error occurred: #{e.message}"
    ensure
      out.close
    end
  end
end


get("/events") do
    content_type 'text/event-stream'
    headers 'Cache-Control' => 'no-cache', 'Connection' => 'keep-alive'
    stream do |out|
      out << "data: Hello World\n\n"
      sleep 1
    end
 end

 
set :server, 'thin'
