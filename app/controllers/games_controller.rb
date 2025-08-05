class GamesController < ApplicationController
  def index
    @game_board = SnakeBoard.empty_grid(rows: 8, cols: 8)
  end

  def next_move
    board = SnakeBoard.from_array(params[:grid])
    service = SnakesGameService.new(board, nil)
    direction = service.next_move
    render json: { direction: direction }
  end

  def feedback
    current_grid = SnakeBoard.from_array(params[:grid])
    prev_grid = SnakeBoard.from_array(params[:old_grid])
    service = SnakesGameService.new(current_grid, prev_grid)
    service.feedback(params[:move], params[:outcome])
    render json: {}
  end
end