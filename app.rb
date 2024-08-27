require "sinatra"
require "sinatra/reloader"
require "openai"
require "http"
require "json"



get("/") do
 erb(:chat, {:layout => :layout})
end

get("/list") do
  

 

  erb(:events_chat, {:layout => :layout})
end

post("/list")do
  # Call the API to get the next message from GPT
  # client = OpenAI::Client.new(:api_key => ("OPENAI_API_KEY"))
  request_headers_hash = {
  "Authorization" => "Bearer #{ENV.fetch("OPENAI_API_KEY")}",
  "content-type" => "application/json"
}

request_body_hash = {
  "model" => "gpt-3.5-turbo",
  "messages" => [
    {
      "role" => "system",
      "content" => "You help food and craft vendors find events that are currently accepting applications for vendors. You provide an item with clickable links to the event pages and applications. The list item needs to have the following keys: Event, Location, Date, Website, Application Link. You output them as list items in an <li> tag. Show 5 list items."
    },
    {
      "role" => "user",
      "content" => "Generate a list of events to choose from within a certain date and geogrphical region."
    }
  ]
}

question = params.fetch("user_question") 
@asked_question = question 

request_body_json = JSON.generate(request_body_hash)

raw_response = HTTP.headers(request_headers_hash).post(
  "https://api.openai.com/v1/chat/completions",
  :body => request_body_json
).to_s

parsed_response = JSON.parse(raw_response)
@info_string = parsed_response.fetch("choices")

 info_string = parsed_response.fetch("choices")
  information = info_string.at(0)
  message = information.fetch("message")
  @reply = message.fetch("content")
  reply = message.fetch("content")
  reply2 = reply.gsub("\n","")

  

  @item1 = reply2
 




erb(:events_chat, {:layout => :layout})











  # message_list = [
  #   { "role" => "system", "content" => "You help food and craft vendors find events that are currently accepting applications for vendors. You provide a list of 5 items to start with clickable links to the event pages and applications. You ask them is they are interested in a specific type of event or any. You ask if they have a location preference or not. You ask them if they have a specific date range in mind or not." },
  #   { "role" => "user", "content" => "Generate a list of events to choose from." }
  # ]

  # api_response = client.chat(
  #   parameters: {
  #     model: "gpt-3.5-turbo",
  #     messages:  message_list
  #   }
  # )  
  
  
end
