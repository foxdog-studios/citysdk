# encoding: utf-8

class SequelUser
  set_primary_key :id
  one_to_many :layers, class: CitySDK::Layer, key: :owner_id

  def create_layer?()
    true
  end # def

  def retrieve_layer?(layer)
    true
  end # def

  def update_layer?(layer)
    effectively_owns_layer?(layer)
  end # def

  def delete_layer?(layer)
    layer.deletable? && effectively_owns_layer?(layer)
  end # def

  private

  def effectively_owns_layer?(layer)
    layer.owner == self || admin?()
  end # def
end # class

