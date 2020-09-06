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
  class Itineraries < Sequel::Model($DB[:itinerary]); end

rescue
  @error_message="#{$!}"
  print @error_message

  return {
    statusCode: 500,
    headers: { 'Content-Type': 'application/json' },
    body: @error_message.to_json
  }
end


def lambda_handler(event:, context:)

  # Token processing
  begin

    hmac_secret = ENV["JWT_SECRET"]
    token = event['headers']['Authorization']
    token.slice! "Bearer "
    token_data = JWT.decode(token, hmac_secret, true, { algorithm: 'HS256' })[0]

    if !token_data.key?('role') || token_data['role'] != 'AGENT' # Should also be checking expiry...
      raise 'Authorization token invalid'
    end

    agency_id = token_data['id']

  rescue
    @error_message="#{$!}"
    return {
      statusCode: 403,
      headers: { 'Content-Type': 'application/json' },
      body: "Authorization token misisng or invalid".to_json
    }
  end

  data        = Array.new
  tickets     = Array.new
  itineraries = Array.new

  case event['httpMethod']
    when "GET"

      if event['pathParameters']

        itinerary_id = event['pathParameters']['id']
        Itineraries.where(agency_id: agency_id, id: itinerary_id ).each{ |i| itineraries.push(i.values) }

        itineraries.each do |i, index|

          i['tickets'] = Array.new
          Tickets.where(itinerary_id: itinerary_id ).each{ |t| tickets.push(t.values) }
          tickets.each do |t|
            i['tickets'].push(t)
          end
          data.push(i)
        end

        return {
          statusCode: 200,
          headers: { 'Content-Type': 'application/json' },
          body: data.to_json
        }

      else

        Itineraries.where(agency_id: agency_id).each{ |i| data.push(i.values) }
        return {
          statusCode: 200,
          headers: { 'Content-Type': 'application/json' },
          body: data.to_json
        }

      end

    when "POST"

      body = JSON.parse(event['body'])

      $DB.transaction do

        itinerary = Itineraries. new(
          user_id:     body['user_id'],
          agency_id:   body['agency_id'],
          traveler_id: body['traveler_id'],
          price_total: body['price_total'])
        itinerary.save

        body['tickets'].each { |ticket|
          ticket = Tickets. new(
            itinerary_id:  itinerary.pk,
            status:        ticket['status'],
            seat_number:   ticket['seat_number'],
            flight_number: ticket['flight_number'])
            ticket.save
        }

        Tickets.where(itinerary_id: itinerary.id).each{|t| data.push(t.values) }
      end

      return {
        statusCode: 201,
        headers: { 'Content-Type': 'application/json' },
        body: data.to_json
      }

    when "DELETE"

      itinerary_id = event['pathParameters']['id']
      Tickets.where(itinerary_id: itinerary_id).each{ |t| tickets.push(t) }
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
