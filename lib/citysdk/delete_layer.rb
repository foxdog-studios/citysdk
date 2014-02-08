module CitySDK
  def self.delete_layer!(layer)
    unless layer.deletable?
      fail "The #{ layer.name } layer cannot be deleted."
    end # unless

    id = layer.id

    # Remove all data attached to this layer.
    NodeDatum.where(layer_id: id).delete

    node_ids = Node.select(:id).where(layer_id: id)
    node_data_set_ids = NodeDatum.select(:node_id).where(node_id: node_ids)

    # Remove nodes that only have data from this layer attatched.
    Node.where(layer_id: id).exclude(id: node_data_set_ids).delete

    # Ophan nodes that have data attatch to them from other layers.
    Node.where(layer_id: id).update(layer_id: -1)

    layer.delete
    return
  end # def
end # module

