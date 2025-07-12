class SnakeBoard
  FOOD = 3
  HEAD = 2
  TAIL = 1
  EMPTY = 0

  attr_reader :grid, :rows, :cols
  def self.from_array(grid)
    validate_grid(grid)
    new(grid)
  end

  def self.empty_grid(rows:, cols:)
    new(Array.new(rows) {  Array.new(cols) { EMPTY }})
  end

  def self.validate_grid(grid)
    raise "Not an array" unless grid.instance_of?(Array)
    raise "One of the row is not an array" unless grid.all? { |row| row.instance_of?(Array) }
    raise "In consistent row lengths" if grid.map { |row| row.size }.uniq.count > 1

    grid.each do |row|
      row.each do |val|
        raise "Invalid cell value" unless [FOOD, HEAD, TAIL, EMPTY].include?(val)
      end
    end
  end

  def to_json
    @grid.to_json
  end

  private_class_method :new

  private
  def initialize(grid)
    @grid = grid
    @rows = grid.length
    @cols = grid[0].length
  end
end