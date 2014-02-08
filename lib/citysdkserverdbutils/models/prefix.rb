# encoding: utf-8

module CitySDK
  class Prefix < Sequel::Model(:ldprefix)
    plugin :validation_helpers
  end # class
end # module

