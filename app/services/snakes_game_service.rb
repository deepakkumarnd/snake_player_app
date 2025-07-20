require "net/http"
require "json"
require "uri"

class SnakesGameService

  HIT_BOUNDARY = "hit_wall";
  HIT_TAIL = "hit_tail";
  EAT_FOOD = "eat_food";
  MOVE_OK = "move_ok";

  VALID_MOVES = [1, 2, 3, 4]
  UPSTREAM_SERVICE_NEXT_MOVE = "http://localhost:8000/snakes/next-move"
  UPSTREAM_SERVICE_FEEDBACK = "http://localhost:8000/snakes/feedback"

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
      Rails.logger.error "Error from upstream connection, invalid move #{move[:direction]}"
      return nil
    end

    move[:direction]
  end

  def feedback(outcome)
    case outcome
    when HIT_TAIL
      send_feedback(-10)
    when HIT_BOUNDARY
      send_feedback(-10)
    when EAT_FOOD
      send_feedback(10)
    when MOVE_OK
      send_feedback(0)
    else
      raise "Illegal outcome #{outcome}"
    end
  end

  private

  def send_feedback(reward)
    request_body = @snake_board.to_json
    send_request(UPSTREAM_SERVICE_FEEDBACK + "?reward=#{reward}", request_body)
  end

  def get_next_move
    request_body = @snake_board.to_json
    send_request(UPSTREAM_SERVICE_NEXT_MOVE, request_body)
  end

  def send_request(url, request_body)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.request_uri)

    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"

    # Convert the Ruby hash into a JSON string for the request body
    request.body = request_body

    # 4. Send the request and handle the response
    begin
      response = http.request(request)

      # 5. Check if the request was successful (HTTP status 200-299)
      if response.is_a?(Net::HTTPSuccess)
        # Check if the response body is empty before parsing
        return {} if response.body.nil? || response.body.empty?

        # Parse the JSON response body into a Ruby hash
        parsed_response = JSON.parse(response.body)
        parsed_response.symbolize_keys
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
