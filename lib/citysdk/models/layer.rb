# encoding: utf-8

module CitySDK
  class Layer < Sequel::Model
    plugin :validation_helpers

    many_to_one :owner, class: :SequelUser
    one_to_many :layer_properties
    one_to_many :node_data
    one_to_one :import

    def deletable?
      !UNDELETABLE_IDS.include?(id)
    end # def

    def root_domain
      parts = name.split('.')
      return parts.first if parts.length > 1
    end # def

    def validate
      super
      validate_domain
      validate_name
      validate_presence
    end # def

    def self.for_name(name)
      where(name: name).first
    end # def

    private

    # As of 8th Feb 2014, the layers with IDs 0, 1, and 2 are required
    # and cannot be deleted.
    UNDELETABLE_IDS = Set.new([0, 1, 2]).freeze

    def validate_domain
      return if owner.site_admin?
      domain = root_domain
      if domain.nil?
        errors.add(:domain, 'cannot be empty')
      elsif !owner.domains.include?(domain)
        errors.add(:domain, 'user must be a memeber of the domain')
      end # if
    end # def

    def validate_name
      validates_format(/^\w+(\.\w+)*$/, :name)
      validates_unique(:name)
    end # def

    def validate_presence
      validates_presence([
        :category,
        :description,
        :name,
        :organization
      ])
    end # def
  end # class
end # module

