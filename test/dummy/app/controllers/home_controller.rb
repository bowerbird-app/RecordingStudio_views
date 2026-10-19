class HomeController < ApplicationController
  def index
    record_page_view(resource_type: "Page")
  end
end
