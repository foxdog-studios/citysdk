# encoding: utf-8

module CitySDK
  class Layer < Sequel::Model
    # As of 8th Feb 2014, the layers with IDs 0, 1, and 2 are required
    # and cannot be deleted.
    UNDELETABLE_IDS = Set.new([0, 1, 2])

    many_to_one :owner, class: :SequelUser
    one_to_many :layer_properties
    one_to_many :node_data

    def deletable?
      !UNDELETABLE_IDS.include?(id)
    end # def

    def root_domain
      parts = name.split('.')
      if parts.length == 1
        nil
      else
        parts.first
      end # if
    end # def

    def self.for_name(name)
      where(name: name).first
    end # def

    def self.get_layers_in_category(category)
      where(Sequel.like(:category, "#{ category }%"))
    end # def
  end # class


  # Stuff Peter has not looked at.
  class Layer < Sequel::Model
    plugin :validation_helpers
    plugin :json_serializer

    KEY_LAYER_NAMES = 'layer_names'
    KEY_LAYERS_AVAILABLE = 'layers_available'

    def validate
      super
      validates_presence [
        :category,
        :description,
        :name,
        :organization
      ]
      validates_unique :name
      validates_format /^\w+(\.\w+)*$/, :name

      domain = root_domain()

      if !owner.site_admin?
        if domain.nil?
          errors.add(:domain, 'cannot be empty')
        elsif !owner.domains.include?(domain)
          errors.add(:domain, 'user must be a memeber of the domain')
        end # if
      end # if
    end

    def self.memcache_key(id)
      "layer!!#{ id }"
    end

    def self.get_layer(id)
      self[id]
    end

    def self.get_layer_names
      name_to_id_map = {}
      self.select(:id, :name).each do |layer|
        name_to_id_map[layer.name] = layer.id
      end
      name_to_id_map
    end

    def self.get_validity(id)
      layer = self.get_layer(id)
      if layer[:realtime]
        return true, layer[:update_rate]
      else
        return false, layer[:validity]
      end
    end
  end # class
end # module

