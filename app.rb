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

get("/list") do
  erb(:events_chat, {:layout => :layout})
end

get("/chat") do
  stream(:keep_open) do |out|
  client = OpenAI::Client.new(:api_key => ("OPENAI_API_KEY"))

    client.chat(
      parameters: {
        model: 'gpt-3.5-turbo',
        messages: [
          { role: 'system', content: 'You find real events that are currently accepting applications for vendors and provide information with clickable links to the event pages and applications. The list item needs to have the following keys: Event, Location, Date, Website, Application Link. You output them as list items in an <li> tag. Show 5 list items.' },
          { role: 'user', content: prompt }
        ],
        stream: true
      }
    ) do |chunk|
      # Process each chunk as it's received
      chunk['choices'].each do |choice|
        content = choice['delta']['content']
        print content unless content.nil?
      end
    end
    out.close
  end



  loop do
    print "You: "
    user_input = gets.chomp

    break if user_input.downcase == 'exit'

    print "GPT-3.5 Turbo: "
    chat_with_gpt(user_input)
    
    puts "\n\n"
  end
  puts "Goodbye!"

  # Call the API to get the next message from GPT
  # client = OpenAI::Client.new(:api_key => ("OPENAI_API_KEY"))
#   request_headers_hash = {
#   "Authorization" => "Bearer #{ENV.fetch("OPENAI_API_KEY")}",
#   "content-type" => "application/json"
# }

# request_body_hash = {
#   "model" => "gpt-3.5-turbo",
#   "messages" => [
#     {
#       "role" => "system",
#       "content" => "You find real events that are currently accepting applications for vendors and provide information with clickable links to the event pages and applications. The list item needs to have the following keys: Event, Location, Date, Website, Application Link. You output them as list items in an <li> tag. Show 5 list items."
#     },
#     {
#       "role" => "user",
#       "content" => "Reads the list that you provide."
#     }
#   ]
# }

# question = params.fetch("user_question") 
# @asked_question = question 


# request_body_json = JSON.generate(request_body_hash)

# raw_response = HTTP.headers(request_headers_hash).post(
#   "https://api.openai.com/v1/chat/completions",
#   :body => request_body_json
# ).to_s

# parsed_response = JSON.parse(raw_response)
# @info_string = parsed_response.fetch("choices")

# info_string = parsed_response.fetch("choices")
# information = info_string.at(0)
# message = information.fetch("message")
# @reply = message.fetch("content")
# reply = message.fetch("content")
# reply2 = reply.gsub("\n","")
# @item1 = reply2

# cookies["Events"] = reply2

erb(:index, {:layout => :layout})
end

set :server, 'thin'
set :sockets, []


get("/event_searches") do
  erb(:past_searches)
end
