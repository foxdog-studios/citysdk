require 'rgeo'

module CitySDK
  module CitySDKServerDBUtils

    @@wkb_generator = RGeo::WKRep::WKBGenerator.new(
      type_format: :ewkb,
      hex_format: true,
      emit_ewkb_srid: true
    )

    def self.generate_wkb(rgeo_geom)
      @@wkb_generator.generate(rgeo_geom)
    end

    ##############################################################################
    # cdk_id generation                                                          #
    ##############################################################################

    # Create alphanumeric hashes, 22 characters long
    # base62 = numbers + lower case + upper case = 10 + 26 + 26 = 62
    # Example hash: 22pOqosrbX0KF6zCQiPj49
    def self.md5_base62(s)
      Digest::MD5.hexdigest(s).to_i(16).base62_encode
    end

    def self.generate_cdk_id_from_text(layer, text)
      # Normalize text:
      #  downcase, strip,
      #  normalize (é = e, ü = u),
      #  remove ', ", `,
      #  replace sequences of non-word characters by '.',
      #  Remove leading and trailing '.'

      n = text.to_s.downcase.strip
        .gsub(/['"`]/, '')
        .gsub(/\W+/, '.')
        .gsub(/((\.$)|(^\.))/, '')

      [layer, n].join('.')
    end

    def self.generate_cdk_id_with_hash(layer, id)
      return self.md5_base62(layer + "::" + id.to_s)
    end

    def self.generate_route_cdk_id(cdk_ids)
      if cdk_ids.nil? or cdk_ids.length == 0
        return nil
      else
        return self.md5_base62(cdk_ids.join)
      end
    end

    def self.bulk_insert_nodes(json, layer)
      layer_name = layer.name
      # Halt if nodes have not been supplied.
      nodes = json['nodes']
      fail ArgumentError, 'No node have been supplied' if nodes.nil?

      # Get parameters. Halt if no parameters have been supplied.
      create = json['create']
      if create.nil? || create['params'].nil?
        fail ArgumentError, 'No create/params object supplied'
      end # if
      params = create.fetch('params')
      create_type = params.fetch('create_type')
      node_type = params.fetch('node_type')

      results = {
        status: 'success',
          create: {
          params: params,
          results: {
            created: [],
            updated: [],
            totals: { created: 0, updated: 0 }
          }
        }
      }

      # Get the SRID to use if it has been supplied.
      raw_srid = params.fetch('srid', 4326)
      srid = raw_srid.to_i
      if srid.zero?
        fail ArgumentError, "Invalid SRID #{ raw_srid.inspectl }"
      end # if

      # Get modalities, if they have been supplied, and covert them to IDs.
      modalities = params.fetch('modalities', [])
      unless modalities.kind_of?(Array)
        fail ArgumentError, 'modalities parameter must be an array'
      end # unless
      modalities.map! { |name| Modality.where(name: name).get(:id) }
      modalities = modalities.empty? ? nil : Sequel.pg_array(modalities)

      new_nodes = []
      updated_nodes = []
      node_data = []
      node_data_cdk_ids = []

      nodes.each do |node|
        cdk_id = node['cdk_id']
        cdk_ids = node['cdk_ids']

        unless cdk_id.nil? || cdk_ids.nil?
          fail ArgumentError, 'node with both cdk_id and cdk_ids fields'
        end # unless

        members = nil

        unless cdk_ids.nil?
          if !cdk_ids.is_a?(Array) || cdk_ids.empty?
            fail ArgumentError, 'invalid cdk_ids, must be array'
          end # if
          if cdk_ids.length == 1
            cdk_id = cdk_ids[0]
          else
            # Node to be added is a route
            members = cdk_ids.map do |cdk_id|
              Sequel.function(:cdk_id_to_internal, cdk_id)
            end # do
            members = Sequel.pg_array(members)
          end # else
        end # unless

        id = node['id']

        unless id || cdk_id || cdk_ids
          fail ArgumentError, 'node without id, cdk_id or cdk_ids'
        end # unless

        geom = nil
        if !node['geometry'].nil? && cdk_id.nil?
          geom = node.fetch('geometry')

          # geom must be present if a new node is created,
          # (e.g. when cdk_id and cdk_ids is empty)
          # and must be empty when either of cdk_id or cdk_ids is provided

          # PostGIS can convert GeoJSON to geometry with ST_GeomFromGeoJSON
          # function: geom = Sequel.function(:ST_Transform,
          # Sequel.function(:ST_SetSRID, Sequel.function(:ST_GeomFromGeoJSON,
          # node["geom"].to_json), srid), 4326) But on server this does not work:
          # ERROR:  You need JSON-C for ST_GeomFromGeoJSON
          # TODO: find out why, and maybe update PostgreSQL/PostGIS.

          if geom['type'] == 'wkb'
            # The geometry is already in WKB format with correct SRID.
            wkb = geom.fetch('wkb')
            wkb = Sequel.lit("'#{ wkb }'").cast(:geometry)
          else
            rgeo_geom = RGeo::GeoJSON.decode(geom)
            wkb = self.generate_wkb(rgeo_geom)
            wkb = Sequel.function(
              :ST_SetSRID,
              Sequel.lit("'#{ wkb }'").cast(:geometry),
              srid
            )
          end # else
          geom = Sequel.function(:ST_Transform, wkb, 4326)
        elsif !members.nil?
          # Compute derived geometry from the geometry of members.
          geom = Sequel.function(:route_geometry, members)
        end

        data = node['data']
        if data.nil?
          fail ArgumentError, 'node without data encountered'
        end # if
        data = Sequel.hstore(data)

        validity = node['validity']
        if !validity.nil?
          unless validity.is_a?(Array) && validity.length == 2
            fail ArgumentError, \
                 "Object with cdk_id=#{cdk_id} submitted with incorrect " \
                 "validity field, must be array with two datetime values, " \
                 "with value 1 < value 2"
          end # unless
          valid_from = DateTime.parse(validity.fetch(0))
          valid_to = DateTime.parse(validity.fetch(1))
          validity = (valid_from..valid_to).pg_range(:tstzrange)
        end # if

        # Create new node and add data when:
        #   - create_type = create
        #   - cdk_id and cdk_ids is empty
        #   - geom is not empty
        check_1 = \
            create_type == 'create' \
            && cdk_id.nil? \
            && cdk_ids.nil? \
            && !geom.nil?

        # Or when:
        #   - create_type = routes (or create_type = create)
        #   - cdk_id is empty
        #   - cdk_ids is not empty
        check_2 = \
            !cdk_id \
            && cdk_ids \
            && %w{create routes}.includes?(create_type)

        # Otherwise, do not create new node, only add data.

        name = node['name']
        if (check_1 || check_2) && !cdk_id
          cdk_id =
            if id
              cdk_id = self.generate_cdk_id_from_text(layer_name, id)
            elsif name
              cdk_id = self.generate_cdk_id_from_text(layer_name, name)
            elsif cdk_ids
              cdk_id = self.generate_route_cdk_id(cdk_ids)
            else
              fail ArgumentError, 'No id, name or cdk_ids for new node'
            end # else
        end # if

        if Node.where(cdk_id: cdk_id).count.zero?
          node_type_id =
            if node_type
              case node_type
              when 'route'  then 1
              when 'ptstop' then 2
              when 'ptline' then 3
              end # case
            elsif members
              1
            else
              0
            end # else

          new_nodes << {
            cdk_id: cdk_id,
            name: name,
            members: members,
            layer_id: layer.id,
            node_type: node_type_id,
            modalities: modalities,
            geom: geom
          }
        elsif node_type == 'ptstop'
          # node with cdk_id already exist.
          # cdk_id is available, data is added to existing node.
          # If existing node has node_type 'node' and new node is 'ptstop'
          # convert node to ptstop:
          updated_nodes << cdk_id
        end # elsif

        # See if there is node_data to add/update. Otherwise, skip
        if cdk_id
          node_data << {
            node_id: Sequel.function(:cdk_id_to_internal, cdk_id),
            layer_id: layer.id,
            data: data,
            modalities: modalities,
            node_data_type: 0,
            validity: validity
          }
          node_data_cdk_ids << cdk_id
        end # if
      end # do

      db = Sequel::Model.db
      db.transaction do
        db[:nodes].multi_insert(new_nodes)
        Node.where(cdk_id: updated_nodes).update(node_type: 2)
        NodeDatum.where(
          node_id: Sequel.function(
            :any,
            Sequel.function(
              :cdk_ids_to_internal,
              Sequel.pg_array(node_data_cdk_ids)
            )
          )
        ).where(layer_id: layer.id).delete
        db[:node_data].multi_insert(node_data)
      end # do
    end # def
  end # module
end # module

