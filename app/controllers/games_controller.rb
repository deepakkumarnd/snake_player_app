class GamesController < ApplicationController
  def index
    @game_board = SnakeBoard.empty_grid(rows: 8, cols: 8)
  end

  def next_move
    board = SnakeBoard.from_array(params[:grid])
    service = SnakesGameService.new(board)
    direction = service.next_move
    render json: { direction: direction }
  end
end