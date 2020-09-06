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

  class Flights < Sequel::Model($DB[:flight]); end
  class Airports < Sequel::Model($DB[:airport]); end

rescue
  @error_message="#{$!}"
  return {
    statusCode: 400,
    headers: {
      'Content-Type': 'application/json',
    },
    body: @error_message.to_json
  }
end

# Handler function returned to the Lambda runtime environment
def lambda_handler(event:, context:)

  # Uncomment for token authorization
  begin
    hmac_secret = ENV["JWT_SECRET"]
    token = event['headers']['Authorization']
    token.slice! "Bearer "
    token_data = JWT.decode(token, hmac_secret, true, { algorithm: 'HS256' })[0]

     if !token_data.key?('role') || token_data['role'] != 'AGENT'
       raise 'Authorization token invalid'
     end

  rescue
    @error_message="#{$!}"
    return {
      statusCode: 403,
      headers: {
        'Content-Type': 'application/json',
      },
      body: @error_message.to_json
    }
  end

  # Query processing
  data = Array.new

  body = JSON.parse(event['body'])

  print "\n\n#{body}\n\n"

  origin = Airports.where( name: body['origin']).each{ |a| origin_airport.push(a.values) }
  # origin_airport = []
  # dest_airport = []
  #
  # Airports.where( name: "Ambrose").each{ |a| origin_airport.push(a.values) }
  #
  # print "\n\n#{origin_airport}\n\n"

  # airport.each do |a|
  #   print "\n\n#{a.values}\n\n"
  # end


  flights = Flights.where(
        departure_date: body['departure_date'] ).
    or( arrival_date:   body['arrival_date']   ).
    or( dest:           body['destination']    ).
    or( origin:         body['origin']         ).
    or( capacity:       body['capacity']       ).
    or( price:          body['price']          ).

    each do |f|
     data.push(f.values)
    end

  return {
    statusCode: 200,
    headers: { 'Content-Type': 'application/json' },
    body: data.to_json
  }

end
