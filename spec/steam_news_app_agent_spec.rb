require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::SteamNewsAppAgent do
  before(:each) do
    @valid_options = Agents::SteamNewsAppAgent.new.default_options
    @checker = Agents::SteamNewsAppAgent.new(:name => "SteamNewsAppAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
