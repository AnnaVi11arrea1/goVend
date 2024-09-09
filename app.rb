require "sinatra"
require "sinatra/reloader"
require "openai"
require "http"
require "json"
require "sinatra/cookies"
require "thin"
require "net/http"
require "uri"

set :server, 'thin'
set :public_folder, 'public'
# Endpoint for handling the search

get("/") do
  erb(:index, {:layout => :layout})
 end

get('/index.js') do
  content_type 'application/javascript'
  File.read(File.join('public', 'index.js'))
end

get('/styles.css') do
  content_type 'text/css'
  File.read(File.join('public', 'styles.css'))
end

post('/search') do
  content_type :json
  request_body = JSON.parse(request.body.read)
  query = request_body["query"]
  results = search_web(query)
  { response: result }.to_json
end

def fetch_from_openai(query, search_results)
  if search_results.empty?
    return "No search results found."
  end

  formatted_results = format_search_results(search_results)
  prompt = "Here are some search results for your query: #{query}\n\n#{formatted_results}\n\nPlease provide a refined response based on these results."

  uri = URI.parse('https://api.openai.com/v1/chat/completions')
  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  request['Authorization'] = "Bearer #{ENV['OPENAI_API_KEY']}"
  request.body = {
    model: "gpt-4-turbo",
    messages: [
      { role: "system", content: "You are a helpful assistant." },
      { role: "user", content: prompt }
    ],
    max_tokens: 2000
  }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    response_body = JSON.parse(response.body)
    response_body['choices'][0]['message']['content']
end
  
def search_web(query)
  api_key = ENV['GOOGLE_SEARCH_API_KEY']
  cx = ENV['GOOGLE_CX_KEY'] # Custom Search Engine ID
  uri = URI.parse("https://www.googleapis.com/customsearch/v1?q=#{URI.encode_www_form_component(query)}&key=#{api_key}&cx=#{cx}")
 
  search_results = ["Result 1", "Result 2", "Result 3"]
  fetch_from_openai(query, search_results)
end

def format_search_results(search_results)
  if search_results == [] then
  search_results.map.with_index(1) do |result, index|
    "#{index}. #{result['title']}\n#{result['link']}\n#{result['snippet']}\n\n"
  end.join
  end
end

get("/events") do
  content_type 'text/event-stream'
  headers 'Cache-Control' => 'no-cache', 'Connection' => 'keep-alive'

  stream(:keep_open) do |out|
    messages = params[:messages]
    if messages.nil? || !messages.is_a?(Array)
      out << "data: Invalid messages parameter\n\n"
      next
    end

    assistant_message = messages.find { |msg| msg[:role] == "assistant" }
    user_message = messages.find { |msg| msg[:role] == "user" }

    if assistant_message.nil? || user_message.nil?
      out << "data: Missing required messages\n\n"
      next
    end

    query = assistant_message[:content]
    prompt = user_message[:content]

    puts "Received message: #{prompt}"

    if prompt.nil? || prompt.strip.empty?
      out << "data: Invalid prompt\n\n"
      next
    end

    begin
      response = HTTP.post("https://api.openai.com/v1/chat/completions",
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{ENV['OPENAI_API_KEY']}"
        },
        body: {
          model: "gpt-4",
          messages: [
            { role: "assistant", content: "You find real events that are currently accepting applications for the current year. Provide information with clickable links to the event pages and applications. The list items need to have the following: Event, Location, Date, Website, Application Link. Show 5 list items. List item dates must have the current year included. Each list item is wrapped in the Following HTML: <li>, and has the following HMTL after the <li> tag: <input type='checkbox' class='item-checkbox'><button class='add-to-list'>Add to List</button> Only include item 'content' relevent to item list:" },
            { role: "user", content: prompt }
          ],
          max_tokens: 2000,
          n: 1
        }.to_json
      )

      parsed_response = JSON.parse(response.body)
      puts "API Response: #{parsed_response}"
      
      if parsed_response.key?('choices') && parsed_response['choices'].is_a?(Array) && !parsed_response['choices'].empty?
        choices = parsed_response.fetch("choices")
        listitems = choices.at(0)
        messages = listitems.fetch("message")
        content = messages.fetch("content")
        out << "data: #{content}\n\n"

      if response.status.success?
        content_string = content.to_s
        new_content_string = content_string.split('\n').join('<br>')
        out << "data: #{new_content_string}\n\n"
      else
        out << "data: Unexpected API response: #{parsed_response}\n\n"
      end
    else
      out << "data: Unexpected API response: #{parsed_response}\n\n"
    end
    rescue StandardError => e
      out << "data: Error: #{e.message}\n\n"
    ensure
      out.close rescue nil
    end
  end
end

# Add the /chat endpoint
get("/chat") do
  content_type 'text/event-stream'
  query = params[:message]

  search_results = search_web(query)
  openai_response = fetch_from_openai(query, search_results)

   stream do |out|
    begin
      search_results = search_web(query)
      openai_response = fetch_from_openai(query, search_results)

      parsed_response = JSON.parse(openai_response)
      puts "API Response: #{parsed_response}"

      if parsed_response.key?('choices') && parsed_response['choices'].is_a?(Array) && !parsed_response['choices'].empty?
        choices = parsed_response.fetch("choices")
        listitems = choices.at(0)
        messages = listitems.fetch("message")
        content = messages.fetch("content")
        out << "data: #{content}\n\n"

        if response.status.success?
          content_string = content.to_s
          new_content_string = content_string.split('\n').join('<br>')
          out << "data: #{new_content_string}\n\n"
        else
          out << "data: Unexpected API response: #{parsed_response}\n\n"
        end
      end
        # Handle mixed data types
      if parsed_response.is_a?(Array)
        parsed_response.each do |item|
          formatted_item = item.is_a?(String) ? item : item.to_s
          out << "data: #{formatted_item}\n\n"
        end

      else
        content = parsed_response.is_a?(String) ? parsed_response : parsed_response.to_s
        out << "data: #{content}\n\n"
      end
    rescue StandardError => e
      out << "data: Error: #{e.message}\n\n"
    ensure
      out.close rescue nil
    end
  end
end
