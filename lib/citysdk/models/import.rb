# -*- encoding: utf-8 -*-

require 'pg'
require 'sequel'

module CitySDK
  class Import < Sequel::Model
    unrestrict_primary_key
    many_to_one :layer
  end # class
end # module

