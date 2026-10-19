# frozen_string_literal: true

RecordingStudioViews::Engine.routes.draw do
  post "views", to: "ingestions#create", as: :views
end
