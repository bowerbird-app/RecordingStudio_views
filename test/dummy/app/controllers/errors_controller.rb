class ErrorsController < ApplicationController
  skip_before_action :authenticate_user!
  layout "application"

  def not_found
    render :show, status: :not_found
  end

  def crash
    render :show, status: :internal_server_error
  end
end
