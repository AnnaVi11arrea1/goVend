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
  content_type 'text/event-stream'
  prompt = params[:message]
  puts "Received message: #{prompt}"
  
  headers 'Cache-Control' => 'no-cache', 'Connection' => 'keep-alive'

  stream(:keep_open) do |out|
    begin
      response = HTTP.post("https://api.openai.com/v1/chat/completions",
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{ENV['OPENAI_API_KEY']}"
        },
        body: {
          model: "gpt-3.5-turbo",
          messages: [
            { role: "system", content: "You find real events that are currently accepting applications for vendors and provide information with clickable links to the event pages and applications. The list item needs to have the following keys: Event, Location, Date, Website, Application Link. Show 5 list items." },
            { role: "user", content: prompt }
          ],
          max_tokens: 150,
          n: 1
        }.to_json
      )

      parsed_response = response.parse
      puts "API Response: #{parsed_response}"  # Log the full response for debugging

      if parsed_response["choices"]
        parsed_response["choices"].each do |choice|
          out << "data: #{choice["message"]["content"]}\n\n"
        end
      else
        out << "data: An error occurred: No choices found in the response\n\n"
      end


    rescue => e
      out << "data: An error occurred: #{e.message}\n\n"
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
