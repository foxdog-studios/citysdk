module CitySDK
  module WebService
    def self.load_from_ws(url, data)
      connection = Faraday.new(url: url)
      response = connection.post('', data.to_json)
      if response.status != 200
        fail "Failed to retrieve data from webservice url: #{url}"
      end # if
      nodes = JSON.parse(response.body)
      nodes.fetch('data')
    end

    def self.load(layer_id, cdk_id, hstore)
      layer = Layer[layer_id]
      fail "No layer with id: #{layer_id}" if layer.nil?
      webservice_url = layer.webservice
      load_from_ws(webservice_url, hstore)
    end # def

  end # module
end # module

