class SkippedPagesController < ApplicationController
  skip_before_action :authenticate_user!
  layout "application"

  def show
  end
end
