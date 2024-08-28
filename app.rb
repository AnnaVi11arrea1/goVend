require "sinatra"
require "sinatra/reloader"
require "openai"
require "http"
require "json"
require "sinatra/cookies"
require "thin"
require "net/http"
require "uri"
require "logger"

# Initialize logger
logger = Logger.new(STDOUT)

# Serve static files from the public directory
set :public_folder, 'public'

# Endpoint for handling the search
post('/search') do
  content_type :json
  query = params[:query]

  # Increment the request count for the given query
  request_counts[query] += 1

  # Check if the request count exceeds the limit, because i accidentally sent like 10,000 requests to the API
  if request_counts[query] > 3
    status 429
    return { error: "Too Many Requests", message: "You have exceeded the maximum number of API requests for this search." }.to_json
  end

  begin
    # Step 2: Use refined query to search the web
    search_results = search_web(query)
    logger.info("Search results: #{search_results}")

    # Step 1: Send query to OpenAI to refine or process
    openai_response = fetch_from_openai(query, search_results)
    logger.info("OpenAI response: #{openai_response}")
  
    # Step 3: Add OpenAI response to chat messages
    chat_messages = [
      { role: "user", content: query },
      { role: "assistant", content: openai_response }
      
    ]
  
    { chat: chat_messages, results: search_results }.to_json
  rescue => e
    status 502
    { error: "Bad Gateway", message: e.message }.to_json
  end

end

def fetch_from_openai(query, search_results)
  formatted_results = format_search_results(search_results)
  prompt = "Here are some search results for your query: #{query}\n\n#{formatted_results}\n\nPlease provide a refined response based on these results."


  uri = URI("https://api.openai.com/v1/completions")
  request = Net::HTTP::Post.new(uri, {
    'Content-Type' => 'application/json', 
    'Authorization' => "Bearer #{ENV['OPENAI_API_KEY']}"
    })
  request.body = {
    model: "gpt-4",
    prompt: prompt,
    max_tokens: 2000
  }.to_json

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request)
  end

  if response.code.to_i != 200
    raise "OpenAI API request failed with status #{response.code}: #{response.body}"
  end

  JSON.parse(response.body)['choices'][0]['text'].strip
end

def search_web(query)
  api_key = ENV['GOOGLE_SEARCH_API_KEY']
  cx = ENV['GOOGLE_CX_KEY'] # Custom Search Engine ID
  uri = URI("https://www.googleapis.com/customsearch/v1?q=#{URI.encode(query)}&key=#{api_key}&cx=#{cx}")
  request = Net::HTTP::Get.new(uri)

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request)
  end

  if response.code.to_i != 200
    raise "Google Search API request failed with status #{response.code}: #{response.body}"
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
     end
      out << "data: #{newContentString2}\n\n"

   
    rescue StandardError => e
      out << "data: Error: #{e.message}\n\n"
    end
      
  end
end

get("/events") do
    content_type 'text/event-stream'
    headers 'Cache-Control' => 'no-cache', 'Connection' => 'keep-alive'
    stream do |out|
     begin
      out << "data: Hello World\n\n"
      sleep 1
    rescue => e
      puts "Error: #{e.message}"
    ensure
      out.close rescue nil
    end
    end
 end


set :server, 'thin'
