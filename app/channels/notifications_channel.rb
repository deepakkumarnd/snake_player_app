class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "game_notifications"
  end
end