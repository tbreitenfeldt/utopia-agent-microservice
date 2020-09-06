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

  class Travelers < Sequel::Model($DB[:traveler]); end

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

  travelers = Travelers.where(
        first_name:  body['first_name']  ).
    or( last_name:   body['last_name']   ).
    or( dob:         body['dob']         ).
    or( phone:       body['phone']       ).
    or( email:       body['email']       ).
    or( street:      body['street']      ).
    or( city:        body['city']        ).
    or( state:       body['state']       ).
    or( postal_code: body['postal_code'] ).
    or( country:     body['country']     ).

    each do |t|
     data.push(t.values)
    end

  return {
    statusCode: 200,
    headers: { 'Content-Type': 'application/json' },
    body: data.to_json
  }

end
