class GameChannel < ApplicationCable::Channel
  def subscribed
    stream_from "game_#{params[:room]}"
  end
end