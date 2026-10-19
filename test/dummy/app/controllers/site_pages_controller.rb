class SitePagesController < ApplicationController
  skip_before_action :authenticate_user!
  layout "application"

  def show
    @site_page = true
  end
end
