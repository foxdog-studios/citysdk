# encoding: utf-8

module CitySDK
  class Modality < Sequel::Model
    plugin :json_serializer

    def serialize(params)
      { id: id, name: name}
    end # def
  end #class
end # module

