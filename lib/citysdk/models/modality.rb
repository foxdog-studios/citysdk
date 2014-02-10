# -*- encoding: utf-8 -*-

module CitySDK
  class Modality < Sequel::Model
    plugin :json_serializer

    def serialize(params)
      { id: id, name: name }
    end # def

    def self.name_for_id(modality_id)
      where(id: modality_id).get(:name)
    end # def
  end #class
end # module

