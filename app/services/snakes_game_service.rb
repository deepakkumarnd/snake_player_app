require 'net/http'
require 'json'
require 'uri'

class SnakesGameService

  VALID_MOVES = [1, 2, 3, 4]
  UPSTREAM_SERVICE = "http://localhost:4000/snakes/next-move"
  def initialize(snake_board)
    @snake_board = snake_board
  end

  def next_move
    move = get_next_move

    if move.nil? || move[:direction].nil?
      Rails.logger.error "Error from upstream connection"
      return nil
    end

    unless VALID_MOVES.include?(move[:direction])
      Rails.logger.error "Error from upstream connection, invalid move"
      return nil
    end

    move
  end

  private

  def get_next_move
    uri = URI.parse(UPSTREAM_SERVICE)
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.request_uri)

    request['Content-Type'] = 'application/json'
    request['Accept'] = 'application/json'

    # Convert the Ruby hash into a JSON string for the request body
    request.body = @snake_board.to_json

    # 4. Send the request and handle the response
    begin
      response = http.request(request)

      # 5. Check if the request was successful (HTTP status 200-299)
      if response.is_a?(Net::HTTPSuccess)
        # Check if the response body is empty before parsing
        return {} if response.body.nil? || response.body.empty?

        # Parse the JSON response body into a Ruby hash
        JSON.parse(response.body)
      else
        # Handle non-successful HTTP statuses (like 404, 500, etc.)
        Rails.logger.error "Error: Received a non-successful HTTP status."
        Rails.logger.error "Status Code: #{response.code}"
        Rails.logger.error "Response Body: #{response.body}"
        nil # Return nil to indicate failure
      end

      # 6. Handle potential errors gracefully
    rescue JSON::ParserError => e
      Rails.logger.error "Error: Failed to parse the JSON response."
      Rails.logger.error "Details: #{e.message}"
      nil
    rescue StandardError => e
      Rails.logger.error "An unexpected error occurred: #{e.class}"
      Rails.logger.error "Details: #{e.message}"
      nil
    end
  end

end