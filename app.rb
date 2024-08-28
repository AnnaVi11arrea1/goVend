require "sinatra"
require "sinatra/reloader"
require "openai"
require "http"
require "json"
require "sinatra/cookies"
require "thin"
require "net/http"
require "uri"

set :public_folder, 'public'
# Endpoint for handling the search
post('/search') do
  content_type :json
  query = params[:query]
 
    # Step 2: Use refined query to search the web
    search_results = search_web(query)

    openai_response = fetch_from_openai(query, search_results)
    chat_messages = [
      { role: "user", content: query },
      { role: "assistant", content: openai_response }
     ]
  
    { chat: chat_messages, results: search_results }.to_json
end

def fetch_from_openai(query, search_results)
  formatted_results = format_search_results(search_results)
  prompt = "Here are some search results for your query: #{query}\n\n#{formatted_results}\n\nPlease provide a refined response based on these results."


  uri = URI('https://api.openai.com/v1/engines/davinci-codex/completions')
  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  request['Authorization'] = "Bearer #{ENV['OPENAI_API_KEY']}"
  request.body = {
    model: "gpt-4",
    messages: [
      { role: "assistant", content: "You find real events that are currently accepting applications for the current year. Provide information with clickable links to the event pages and applications. The list items need to have the following: Event, Location, Date, Website, Application Link. Show 5 list items. List item dates must have the current year included. Each list item is wrapped in the Following HTML: <li>, and has the following HMTL after the <li> tag: <input type='checkbox' class='item-checkbox'><button class='add-to-list'>Add to List</button> Only include item 'content' relevent to item list:" },
      { role: "user", content: query }
    ],
    max_tokens: 2000
  }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    parsed_response = JSON.parse(response.body)['choices'][0]['text'].strip
    parsed_response
end

def search_web(query)
  api_key = ENV['GOOGLE_SEARCH_API_KEY']
  cx = ENV['GOOGLE_CX_KEY'] # Custom Search Engine ID
  uri = URI("https://www.googleapis.com/customsearch/v1?q=#{URI.encode(query)}&key=#{api_key}&cx=#{cx}")
  request = Net::HTTP::Get.new(uri)

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request)
  end

  JSON.parse(response.body)['items']
end

def format_search_results(results)
  results.map do |result|
    "Title: #{result['title']}\nLink: #{result['link']}\nSnippet: #{result['snippet']}"
  end.join("\n\n")
end

get('/styles.css') do
  content_type 'text/css'
  File.read(File.join('public', 'styles.css'))
end

get("/") do
 erb(:index, {:layout => :layout})
end

get("/chat") do
  content_type 'text/event-stream'
  prompt = params[:message]
  query = params[:content]
  puts "Received message: #{prompt}"
  
  headers 'Cache-Control' => 'no-cache', 'Connection' => 'keep-alive'

  stream(:keep_open) do |out|
    
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
    begin
      parsed_response = response.parse
      puts "API Response: #{parsed_response}"
      choices = parsed_response.fetch("choices")
      listitems = choices.at(0)
      messages = listitems.fetch("message")
      content = messages.fetch("content")


      if response.status.success? 
        contentString = content.to_s
        newContentString = contentString.split('\n').to_s
        newContentString2 = newContentString.gsub(/\\n/, "<br>")
      
        out << "data: #{newContentString2}\n\n"
      else
        out << "data: Error: Failed to fetch data\n\n"
      end
    rescue StandardError => e
      out << "data: Error: #{e.message}\n\n"
    ensure
      out.close rescue nil
    end
    
      
  end
end

get("/events") do
  content_type 'text/event-stream'
  headers 'Cache-Control' => 'no-cache', 'Connection' => 'keep-alive'
  stream do |out|
    begin
      response = fetch_from_openai("Your query here", "search_results")
      parsed_response = JSON.parse(response)
      puts "API Response: #{parsed_response}"
      choices = parsed_response.fetch("choices")
      listitems = choices.at(0)
      messages = listitems.fetch("message")
      content = messages.fetch("content")

      if response.status.success?
        content_string = content.to_s
        new_content_string = content_string.split('\n').join('<br>')
        out << "data: #{new_content_string}\n\n"
      else
        out << "data: Error: Failed to fetch data\n\n"
      end
    rescue StandardError => e
      out << "data: Error: #{e.message}\n\n"
    ensure
      out.close rescue nil
    end
  end
end

set :server, 'thin'
