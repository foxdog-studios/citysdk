# encoding: utf-8

module CitySDK
  class NodeDatum < Sequel::Model
    many_to_one :layer
    many_to_one :node
    plugin :validation_helpers
  end # class
end # module

