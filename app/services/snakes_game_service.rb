require "net/http"
require "json"
require "uri"

class SnakesGameService

  HIT_BOUNDARY = "hit_wall"
  HIT_TAIL = "hit_tail"
  EAT_FOOD = "eat_food"
  MOVE_OK = "move_ok"

  VALID_MOVES = [1, 2, 3, 4]
  UPSTREAM_SERVICE_NEXT_MOVE = "http://localhost:8000/snakes/next-move"
  UPSTREAM_SERVICE_FEEDBACK = "http://localhost:8000/snakes/feedback"
  UPSTREAM_SERVICE_STATS = "http://localhost:8000/snakes/stats"

  def initialize(current, previous)
    @snake_board = current
    @prev_snake_board = previous
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

  def feedback(move, outcome)
    case outcome
    when HIT_TAIL
      send_feedback(move, -10, true)
    when HIT_BOUNDARY
      send_feedback(move, -10, true)
    when EAT_FOOD
      send_feedback(move, 10, false)
    when MOVE_OK
      reward = compute_reward
      send_feedback(move, reward, false)
    else
      raise "Illegal outcome #{outcome}"
    end
  end

  def stats
    uri = URI.parse(UPSTREAM_SERVICE_STATS)
    response = Net::HTTP.get_response(uri)

    case response
    when Net::HTTPSuccess
      begin
        JSON.parse(response.body)
      rescue JSON::ParserError => e
        puts "JSON parsing failed: #{e.message}"
      end
    else
      puts "HTTP Error: #{response.code} #{response.message}"
    end
  rescue SocketError => e
    puts "Network error: #{e.message}"
  rescue StandardError => e
    puts "Unexpected error: #{e.message}"
  end

  private

  def man_distance(position1, position2)
    (position1.y_pos - position2.y_pos).abs + (position1.x_pos - position2.x_pos).abs
  end

  def compute_reward
    reward = 0

    reward -= 1 if moving_towards_the_wall?
    reward += 2 if moving_towards_the_food?

    reward
  end

  def moving_towards_the_wall?
    # top, right, bottom, left distances from the wall
    prev_distances_from_wall = [
      @prev_snake_board.head_position.x_pos,
      @prev_snake_board.cols - @prev_snake_board.head_position.y_pos - 1,
      @prev_snake_board.rows - @prev_snake_board.head_position.x_pos - 1,
      @prev_snake_board.head_position.y_pos
    ]

    shortest = prev_distances_from_wall.min

    return false if shortest > 2

    indices = prev_distances_from_wall.each_with_index.map do |distance, index|
      index if distance == shortest
    end.compact

    curr_distances_from_wall = [
      @snake_board.head_position.x_pos,
      @snake_board.cols - @snake_board.head_position.y_pos - 1,
      @snake_board.rows - @snake_board.head_position.x_pos - 1,
      @snake_board.head_position.y_pos
    ]

    # moved closer to any of the wall
    indices.map do |index|
      curr_distances_from_wall[index] < shortest
    end.any?
  end

  def moving_towards_the_food?
    food_position = @snake_board.food_position
    distance1 = man_distance(@prev_snake_board.head_position, food_position)
    distance2 = man_distance(@snake_board.head_position, food_position)
    Rails.logger.info("Distance #{distance1}, #{distance2}")
    distance2 < distance1
  end

  def moved_closer_in_same_row?
    food_position = @snake_board.food_position
    (@prev_snake_board.head_position.x_pos == @snake_board.head_position.x_pos) && (@snake_board.head_position.x_pos == food_position.x_pos) && moved_closer_to_food_horizontally?
  end

  def moved_away_in_same_row?
    food_position = @snake_board.food_position
    (@prev_snake_board.head_position.x_pos == @snake_board.head_position.x_pos) && (@snake_board.head_position.x_pos == food_position.x_pos) && moved_away_from_food_horizontally?
  end

  def moved_away_in_same_column?
    food_position = @snake_board.food_position
    (@prev_snake_board.head_position.y_pos == @snake_board.head_position.y_pos) && (@snake_board.head_position.y_pos == food_position.y_pos) && moved_away_from_food_vertically?
  end

  def moved_closer_in_same_column?
    food_position = @snake_board.food_position
    (@prev_snake_board.head_position.y_pos == @snake_board.head_position.y_pos) && (@snake_board.head_position.y_pos == food_position.y_pos) && moved_closer_to_food_vertically?
  end

  def moved_closer_to_food?
    moved_closer_to_food_horizontally? || moved_closer_to_food_vertically?
  end

  def moved_away_from_food?
    moved_away_from_food_horizontally? || moved_away_from_food_vertically?
  end

  def moved_away_from_food_horizontally?
    food_position = @snake_board.food_position
    (@snake_board.head_position.y_pos - food_position.y_pos).abs > (@prev_snake_board.head_position.y_pos - food_position.y_pos).abs
  end

  def moved_away_from_food_vertically?
    food_position = @snake_board.food_position
    (@snake_board.head_position.x_pos - food_position.x_pos).abs > (@prev_snake_board.head_position.x_pos - food_position.x_pos).abs
  end

  def moved_closer_to_food_horizontally?
    food_position = @snake_board.food_position
    (@snake_board.head_position.y_pos - food_position.y_pos).abs < (@prev_snake_board.head_position.y_pos - food_position.y_pos).abs
  end

  def moved_closer_to_food_vertically?
    food_position = @snake_board.food_position
    (@snake_board.head_position.x_pos - food_position.x_pos).abs < (@prev_snake_board.head_position.x_pos - food_position.x_pos).abs
  end

  def send_feedback(move, reward, game_over)
    request_body = {
      current_grid: @snake_board.grid,
      previous_grid: @prev_snake_board.grid,
      game_over: game_over,
      reward: reward,
      move: move
    }

    send_request(UPSTREAM_SERVICE_FEEDBACK, request_body.to_json)
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
