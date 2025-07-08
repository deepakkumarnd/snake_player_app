class GamesController < ApplicationController
  def index
    @game_board = SnakeBoard.new(
      rows: 8,
      cols: 8,
      food: Position.new(3, 3),
                head: Position.new(6,2), tails: [Position.new(6,1)])
  end
end