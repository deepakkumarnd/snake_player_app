class GamesController < ApplicationController

  before_action :set_game_id, except: [:index]
  def index
    @game_board = SnakeBoard.empty_grid(rows: 4, cols: 4)
    @game_id = session[:game_id] = SecureRandom.uuid
  end

  def next_move
    board = SnakeBoard.from_array(params[:grid])
    service = SnakesGameService.new(@game_id, board, nil)
    direction = service.next_move
    render json: { direction: direction }
  end

  def feedback
    current_grid = SnakeBoard.from_array(params[:grid])
    prev_grid = SnakeBoard.from_array(params[:old_grid])
    service = SnakesGameService.new(@game_id, current_grid, prev_grid)
    service.feedback(params[:move], params[:outcome])
    render json: {}
  end

  def stats
    service = SnakesGameService.new(@game_id, nil, nil)
    @stats = service.stats
  end

  private

  def set_game_id
    @game_id = session[:game_id]
  end
end
