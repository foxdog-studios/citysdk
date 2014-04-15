# encoding: utf-8

module CitySDK
  class NodeDatum < Sequel::Model
    many_to_one :layer
    many_to_one :node
  end # class
end # module

