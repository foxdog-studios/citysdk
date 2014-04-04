# encoding: utf-8

module CitySDK
  class Node < Sequel::Model
    one_to_many :node_data

    def getLayer(n)
      if n.is_a?(String)
        self.node_data.each do |nd|
          return nd if nd.layer.name == n
        end
      else
        self.node_data.each do |nd|
          return nd if nd.layer_id == n
        end
      end
      nil
    end


  end # class
end # module

