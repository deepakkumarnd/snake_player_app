class SnakeBoard
  include ActiveModel::API

  attr_reader :rows, :cols, :food, :head, :tails
  def initialize(rows: nil, cols: nil, food: nil, head: nil, tails: [])
    @rows = rows
    @cols = cols
    @food = food
    @head = head
    @tails = tails
  end
end