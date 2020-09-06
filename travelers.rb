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

  case event["httpMethod"]

    when "GET"

      traveler_id = event['pathParameters']['id']

      Travelers.where(id: traveler_id).each{ |t| data.push(t.values) }

      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: data.to_json
      }

    when "POST"
      
      body = JSON.parse(event['body'])

      $DB.transaction do

        traveler = Travelers. new(
          first_name:  body['first_name'],
          last_name:   body['last_name'],
          dob:         body['dob'],
          phone:       body['phone'],
          email:       body['email'],
          street:      body['street'],
          city:        body['city'],
          state:       body['state'],
          postal_code: body['postal_code'],
          country:     body['country'])
        traveler.save

        traveler = Travelers.where(id: traveler.id).first.values

        data.push(traveler)
      end

      return {
        statusCode: 201,
        headers: { 'Content-Type': 'application/json' },
        body: data.to_json
      }

    when "PUT"

      body = JSON.parse(event['body'])

      $DB.transaction do

        Travelers.where(id: body['id']).update(
            first_name:  body['first_name'],
            last_name:   body['last_name'],
            dob:         body['dob'],
            phone:       body['phone'],
            email:       body['email'],
            street:      body['street'],
            city:        body['city'],
            state:       body['state'],
            postal_code: body['postal_code'],
            country:     body['country'])

        traveler = Travelers.where(id: body['id']).first.values

        data.push(traveler)
      end

      return {
        statusCode: 201,
        headers: { 'Content-Type': 'application/json' },
        body: data.to_json
      }

  end
end
