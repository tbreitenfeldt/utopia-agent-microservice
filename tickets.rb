require 'jwt'
require 'json'
require 'mysql2'
require 'sequel'

begin

  $DB = Sequel.connect(

    :adapter  => 'mysql2',
    :host     => ENV["DB_HOST"],
    :port     => ENV["DB_PORT"],
    :database => ENV["DB_NAME"],
    :user     => ENV["DB_USER"],
    :password => ENV["DB_PASSWORD"])

  class Tickets < Sequel::Model($DB[:ticket]); end

rescue
  @error_message="#{$!}"
  print @error_message
end


# Handler function returned to the Lambda runtime environment
def lambda_handler(event:, context:)

  # Uncomment for token authorization
  begin
    hmac_secret = ENV["JWT_SECRET"]    
    token = event['headers']['Authorization']
    token.slice! "Bearer "
    token_data = JWT.decode(token, hmac_secret, true, { algorithm: 'HS256' })[0]

    if !token_data.key?('role')
      raise 'Authorization token invalid'
    end

  rescue
    @error_message="#{$!}"
    return {
      statusCode: 403,
      headers: { 'Content-Type': 'application/json' },
      body: @error_message
    }
  end

  # Query processing
  data        = Array.new
  tickets     = Array.new

  case event["httpMethod"]
    when "GET"

      Tickets.where(id: event['pathParameters']['id']).each{|t| data.push(t.values) }

      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: data.to_json
      }

      # return {
      #   statusCode: 200,
      #   headers: { 'Content-Type': 'application/json' },
      #   body: "GET COMPLETE".to_json
      # }

    when "DELETE"

      ticket_id = event['pathParameters']['id']
      Tickets.where(id: ticket_id).each{ |t| tickets.push(t) }

      $DB.transaction do
        tickets.each do |t|
          t.set(status: "CANCELED")
          t.save
        end
      end

      tickets.each{ |t| data.push(t.values) }

      return {
        statusCode: 201,
        headers: { 'Content-Type': 'application/json' },
        body: data.to_json
      }
  end
end
