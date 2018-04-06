module Select
  def take_name (name)
     /.*[1-9]_(.*)\.txt/.match(name)[1]
  end

  def get_json(id)

    array_of_hashes = Dir.glob(
        Rails.root.join("import", "*.txt")
    ).each_with_index.map {
        |e, i| e = {id: i, name: File.basename(e), path: e}
    }.sort_by {|h| h[:name]}
    @hash = {}
    if id.is_i?
      array_of_hashes.each {|x|

        if x[:id].to_i == id.to_i then
          @hash = x
        end
      }
    else
      array_of_hashes.each {|x|
        if take_name(x[:name]) == id then
          @hash = x
        end}
    end

    json = JSON.parse(
        File.read(
            Dir.glob(
                Rails.root.join("import", @hash[:name])
            ).first
        )
    )
    return json

  end

  def taxon_create(master, base_json)
    puts master
    parent =  base_json.select { |s| s['id'] == master['parent_id'] }.first
    unless parent.nil?
          if Spree::Taxon.find_by(name: parent['name']).nil?
            taxon = base_json.select { |s| s['name'] == parent['name'] }.first

            taxon_create(taxon, base_json)

          end

          parent_taxon = Spree::Taxon.find_by(name: parent['name'])
    end



  if Spree::Taxon.find_by(name: master['name']).nil?
    r = Spree::Taxon.create(
        parent_id: (parent.nil?)? nil : parent_taxon.id,
        position: master['position'],
        taxonomy_id: master['taxonomy_id'],
        name: master['name'],
        description: master['description'],
        meta_title: master['meta_title'],
        meta_description: master['meta_description'],
        meta_keywords: master['meta_keywords'],
        permalink: master['permalink'])

    return r.valid?
  else
    return true
  end

  end

end

class String
  def is_i?
    /\A[-+]?\d+\z/ === self
  end
end

module Spree
  module Admin
    class StalnoyImportExportsController < ResourceController

      include Select
      include ActionController::Live

      def index

      end

      def api_get

        fails_array = []

        response.headers['Content-Type'] = 'text/event-stream'
        base_json = get_json(params[:ud])

        case params[:path]
        when 'country'
          json = base_json.first
          t = Spree::Country.exists?(id: json['id'],
                                     'iso_name' => json['iso_name'],
                                     'iso' => json['iso'],
                                     'iso3' => json['iso3'],
                                     'name' => json['name'],
                                     'numcode' => json['numcode'],
                                     'states_required' => json['states_required'],
                                     'zipcode_required' => json['zipcode_required'])

          response.stream.write "data: #{Hash['status' => 'preparing',
                                              'total' => base_json.count,
                                              'action' => 'api_get',
                                              'last_row' => (t == true) ? base_json.count : 0,
                                              'hash' => params[:path],
                                              'id' => params[:ud],
                                              'result' => t
          ].to_json}\n\n"
        when 'states'
          base_json.each_with_index do |h, i|
            t = Spree::State.exists?(name: h["name"], abbr: h['abbr'], country_id: h['country_id'])
            response.stream.write "data: #{Hash['status' => 'preparing',
                                                'action' => 'api_get',
                                                'total' => base_json.count,
                                                'last_row' => i + 1,
                                                'hash' => params[:path],
                                                'id' => params[:ud],
                                                'result' => t
            ].to_json}\n\n"
          end


        when 'taxonomy'
          json = base_json.first
          t = Spree::Taxonomy.exists?(id: json['id'], position: json['position'], name: json['name'])
          response.stream.write "data: #{Hash['status' => 'preparing',
                                              'action' => 'api_get',
                                              'total' => base_json.count,
                                              'last_row' => (t == true) ? base_json.count : 0,
                                              'hash' => params[:path],
                                              'id' => params[:ud],
                                              'result' => t
          ].to_json}\n\n"
        when 'taxons'
          base_json = base_json.sort_by {|h| h['id']}
          base_json.each_with_index do |h, i|
            t = Spree::Taxon.exists?(id: h['id'],
                                     parent_id: h['parent_id'],
                                     position: h['position'],
                                     taxonomy_id: h['taxonomy_id'],
                                     name: h['name'],
                                     description: h['description'],
                                     meta_title: h['meta_title'],
                                     meta_description: h['meta_description'],
                                     meta_keywords: h['meta_keywords'])

            response.stream.write "data: #{Hash['status' => 'preparing',
                                                'action' => 'api_get',
                                                'total' => base_json.count,
                                                'last_row' => i + 1,
                                                'hash' => params[:path],
                                                'id' => params[:ud],

                                                'result' => t
            ].to_json}\n\n"
          end
        when 'sale_rate'
          base_json = base_json.sort_by {|h| h['id']}
          base_json.each_with_index do |h, i|
            t = Spree::SaleRate.exists?(id: h['id'], currency: h['currency'], rate: h['rate'], tag: h['tag'])
            response.stream.write "data: #{Hash['status' => 'preparing',
                                                'action' => 'api_get',
                                                'total' => base_json.count,
                                                'last_row' => i + 1,
                                                'hash' => params[:path],
                                                'id' => params[:ud],
                                                'obj_id' => h['id'],
                                                'result' => t
            ].to_json}\n\n"
          end
        when 'product'
          base_json.each_with_index do |h, i|
            startt = Time.now
            t = Spree::Product.exists?(id: h['id'],
                                       available_on: h['available_on'],
                                       deleted_at: h['deleted_at'],
                                       tax_category_id: h['tax_category_id'],
                                       shipping_category_id: h['shipping_category_id'],
                                       promotionable: h['promotionable'],
                                       discontinue_on: h['discontinue_on'],
                                       name: h['name'],
                                       description: h['description'],
                                       meta_title: h['meta_title'],
                                       meta_description: h['meta_description'],
                                       meta_keywords: h['meta_keywords'],
                                       slug: h['slug'])
            endt = Time.now
            diff = endt - startt
            if diff < 0.03
              sleep(0.03 - diff)
            end
            response.stream.write "data: #{Hash['status' => 'preparing',
                                                'action' => 'api_get',
                                                'total' => base_json.count,
                                                'last_row' => i + 1,
                                                'hash' => params[:path],
                                                'id' => params[:ud],
                                                'obj_id' => h['id'],
                                                'result' => t
            ].to_json}\n\n"
          end
        when 'price'
          base_json.each_with_index do |h, i|
            t = Spree::Price.exists?(id: h['id'], variant_id: h['variant_id'], amount: h['amount'], currency: h['currency'])
            response.stream.write "data: #{Hash['status' => 'preparing',
                                                'action' => 'api_get',
                                                'total' => base_json.count,
                                                'last_row' => i + 1,
                                                'hash' => params[:path],
                                                'id' => params[:ud],
                                                'obj_id' => h['id'],
                                                'result' => t
            ].to_json}\n\n"
          end
        when 'product_taxon'
          #S Spree::Product.find_by(slug: 'propanovyy-reduktor-mimgas-m1000u-do-90-kw')
          # base_json.each_with_index do |h, i|
          #   if h['products'] != nil
          #     products = h['products']
          #     products.each_with_index do |p,pI|
          #       r = Spree::Product.find_by(slug:p['slug']).taxons=Spree::Taxon.where(permalink: h['permalink'])
          #
          #       if !r.first.nil?
          #
          #
          #
          #       end
          #
          #     end
          #   end
          #
          # end

        when 'variant'
          base_json.each_with_index do |h, i|
            a = Spree::Variant.where(product_id: h['product_id']).exists?(sku: h['sku'],
                                                                          weight: h['weight'],
                                                                          height: h['height'],
                                                                          width: h['width'],
                                                                          depth: h['depth'],
                                                                          is_master: h['is_master'],
                                                                          product_id: h['product_id'],
                                                                          cost_price: h['cost_price'],
                                                                          position: h['position'],
                                                                          cost_currency: h['cost_currency'],
                                                                          track_inventory: h['track_inventory'],
                                                                          tax_category_id: h['tax_category_id'],
                                                                          discontinue_on: h['discontinue_on'])
            unless a
              fails_array << h
            end
            response.stream.write "data: #{Hash['status' => 'preparing',
                                                'action' => 'api_get',
                                                'total' => base_json.count,
                                                'last_row' => i + 1,
                                                'hash' => params[:path],
                                                'id' => params[:ud],
                                                'obj_id' => h['id'],
                                                'result' => a
            ].to_json}\n\n"
          end
          response.stream.write "data: #{Hash['status' => 'done',
                                              'action' => 'api_get',
                                              'total' => base_json.count,
                                              'last_row' => base_json.count,
                                              'hash' => params[:path],
                                              'id' => params[:ud],
                                              'fails_array' => fails_array
          ].to_json}\n\n"
        when 'assets'
        when 'properties'
        when 'product_property'
        when 'stalnoy_import'

        else
          json = get_json(params[:ud])

          response.stream.write "data: #{Hash['status' => 'preparing',
                                              'total' => json.count,
                                              'last_row' => 0,
                                              'hash' => params[:path],
                                              'id' => params[:ud]

          ].to_json}\n\n"
        end

        response.stream.write "data: #{Hash['status' => 'done',
                                            'action' => 'api_put',
                                            'total' => base_json.count,
                                            'last_row' => base_json.count,
                                            'hash' => params[:path],
                                            'id' => params[:ud],

        ].to_json}\n\n"


      rescue IOError, ActionController::Live::ClientDisconnected
        logger.info "Stream closed"
      rescue StandardError => e
        response.stream.write "data: #{Hash['status' => 'error',
                                            'content' => e,
                                            'trace' => e.backtrace
        ].to_json}\n\n"
      ensure
        response.stream.close
      end

######################
#
#
      def api_put
        response.headers['Content-Type'] = 'text/event-stream'

        base_json = get_json(params[:ud])

        fails_array = []

        case params[:path]
        when 'country'

          json = base_json.first
          a = Spree::Country.create!(id: json['id'],
                                     'iso_name' => json['iso_name'],
                                     'iso' => json['iso'],
                                     'iso3' => json['iso3'],
                                     'name' => json['name'],
                                     'numcode' => json['numcode'],
                                     'states_required' => json['states_required'],
                                     'zipcode_required' => json['zipcode_required'])

          response.stream.write "data: #{Hash['status' => 'work',
                                              'action' => 'api_put',
                                              'total' => base_json.count,
                                              'last_row' => base_json.count,
                                              'hash' => params[:path],
                                              'id' => params[:ud],
                                              'result' => a.valid?
          ].to_json}\n\n"
          unless a.valid?
            fails_array << h
          end
          response.stream.write "data: #{Hash['status' => 'done',
                                              'action' => 'api_put',
                                              'total' => base_json.count,
                                              'last_row' => base_json.count,
                                              'hash' => params[:path],
                                              'id' => params[:ud],
                                              'fails_array' => fails_array
          ].to_json}\n\n"

        when 'states'

          base_json.each_with_index do |h, i|

            a = Spree::State.create!(name: h['name'], abbr: h['abbr'], country_id: h['country_id'])
            response.stream.write "data: #{Hash['status' => 'work',
                                                'action' => 'api_put',
                                                'total' => base_json.count,
                                                'last_row' => i + 1,
                                                'hash' => params[:path],
                                                'id' => params[:ud],
                                                'obj_id' => h['id'],
                                                'result' => a.valid?
            ].to_json}\n\n"
            unless a.valid?
              fails_array << h
            end
            response.stream.write "data: #{Hash['status' => 'done',
                                                'action' => 'api_put',
                                                'total' => base_json.count,
                                                'last_row' => base_json.count,
                                                'hash' => params[:path],
                                                'id' => params[:ud],
                                                'fails_array' => fails_array
            ].to_json}\n\n"

          end
        when 'taxonomy'
          json = base_json.first
          a = Spree::Taxonomy.create!(id: json['id'], position: json['position'], name: json['name'])
          response.stream.write "data: #{Hash['status' => 'work',
                                              'action' => 'api_put',
                                              'total' => base_json.count,
                                              'last_row' => base_json.count,
                                              'hash' => params[:path],
                                              'id' => params[:ud],
                                              'result' => a.valid?
          ].to_json}\n\n"
          unless a.valid?
            fails_array << h
          end
          response.stream.write "data: #{Hash['status' => 'done',
                                              'action' => 'api_put',
                                              'total' => base_json.count,
                                              'last_row' => base_json.count,
                                              'hash' => params[:path],
                                              'id' => params[:ud],
                                              'fails_array' => fails_array
          ].to_json}\n\n"
        when 'taxons'
          base_json = base_json.each { |h| if h['parent_id'] == nil then h['parent_id'] = 0 end}
          base_json = base_json.sort_by {|h| h['id']}
          base_json = base_json.each_with_index { |h,i| h.merge!('index' => i+1)}
          base_json = base_json.sort_by {|h| h['parent_id']}


          base_json.each_with_index do |h, i|

            ret = taxon_create(h, base_json)

            response.stream.write "data: #{Hash['status' => 'work',
                                                'action' => 'api_put',
                                                'total' => base_json.count,
                                                'last_row' => i + 1,
                                                'hash' => params[:path],
                                                'id' => params[:ud],
                                                'obj_id' => h['id'],
                                                'result' => ret
            ].to_json}\n\n"
            unless ret
              fails_array << h
            end
          end

          response.stream.write "data: #{Hash['status' => 'done',
                                              'action' => 'api_put',
                                              'total' => base_json.count,
                                              'last_row' => base_json.count,
                                              'hash' => params[:path],
                                              'id' => params[:ud],
                                              'fails_array' => fails_array
          ].to_json}\n\n"


        when 'sale_rate'

          base_json = base_json.sort_by {|h| h['id']}
          base_json.each_with_index do |h, i|

            a = Spree::SaleRate.create(id: h['id'], currency: h['currency'], rate: h['rate'], tag: h['tag'])

            response.stream.write "data: #{Hash['status' => 'work',
                                                'action' => 'api_put',
                                                'total' => base_json.count,
                                                'last_row' => i + 1,
                                                'hash' => params[:path],
                                                'id' => params[:ud],
                                                'obj_id' => h['id'],
                                                'result' => a.valid?
            ].to_json}\n\n"

            unless a.valid?
              fails_array << h
            end

            response.stream.write "data: #{Hash['status' => 'done',
                                                'action' => 'api_put',
                                                'total' => base_json.count,
                                                'last_row' => base_json.count,
                                                'hash' => params[:path],
                                                'id' => params[:ud],
                                                'fails_array' => fails_array
            ].to_json}\n\n"

          end
        when 'product'
          variants_json = get_json('variant')
          base_json = base_json.sort_by {|h| h['id']}

          base_json.each_with_index do |h, i|
            startt = Time.now
            a = Spree::Product.create!(
                sku: variants_json.select {|s| s['product_id'] == h['id']}.first['sku'],
                available_on: h['available_on'],
                deleted_at: h['deleted_at'],
                tax_category_id: h['tax_category_id'],
                shipping_category_id: h['shipping_category_id'],
                promotionable: h['promotionable'],
                discontinue_on: h['discontinue_on'],
                name: h['name'],
                description: h['description'],
                meta_title: h['meta_title'],
                meta_description: h['meta_description'],
                meta_keywords: h['meta_keywords'],
                slug: h['slug'],
                price: 0)

            endt = Time.now
            diff = endt - startt
            if diff < 0.03
              sleep(0.03 - diff)
            end

            response.stream.write "data: #{Hash['status' => 'work',
                                                'action' => 'api_put',
                                                'total' => base_json.count,
                                                'last_row' => i + 1,
                                                'hash' => params[:path],
                                                'id' => params[:ud],
                                                'obj_id' => h['id'],
                                                'result' => a.valid?
            ].to_json}\n\n"
            unless a.valid?
              fails_array << h
            end
          end
          response.stream.write "data: #{Hash['status' => 'done',
                                              'action' => 'api_put',
                                              'total' => base_json.count,
                                              'last_row' => base_json.count,
                                              'hash' => params[:path],
                                              'id' => params[:ud],
                                              'fails_array' => fails_array
          ].to_json}\n\n"
        when 'price'
          base_json.each_with_index do |h, i|
            startt = Time.now
            a = Spree::Price.find_by(variant_id: h['variant_id'])
            if a.nil? then
              a = false
              fails_array << h
            else
              a.update(amount: h['amount'], currency: h['currency'])
            end
            endt = Time.now
            diff = endt - startt
            if diff < 0.03
              sleep(0.03 - diff)
            end
            response.stream.write "data: #{Hash['status' => 'work',
                                                'action' => 'api_put',
                                                'total' => base_json.count,
                                                'last_row' => i + 1,
                                                'hash' => params[:path],
                                                'id' => params[:ud],
                                                'obj_id' => h['id'],
                                                'result' => (a == false) ? a : a.valid?
            ].to_json}\n\n"
          end
          response.stream.write "data: #{Hash['status' => 'done',
                                              'action' => 'api_put',
                                              'total' => base_json.count,
                                              'last_row' => base_json.count,
                                              'hash' => params[:path],
                                              'id' => params[:ud],
                                              'fails_array' => fails_array
          ].to_json}\n\n"
        when 'product_taxon'
          count = 0
          base_json.each {|t| count = count + t['products'].count}
          count_index = 0
          base_json.each_with_index do |h, i|
            if h['products'] != nil
              products = h['products']
              products.each_with_index do |p, pI|
                if Spree::Product.find_by(slug: p['slug']).nil?
                  response.stream.write "data: #{Hash['status' => 'work',
                                                      'action' => 'api_put',
                                                      'total' => count,
                                                      'last_row' => count_index,
                                                      'hash' => params[:path],
                                                      'id' => params[:ud],
                                                      'obj_id' => h['id'],
                                                      'fallback'=> 'product nil',
                                                      'result' => false
                  ].to_json}\n\n"
                  next
                end
                r = Spree::Product.find_by(slug: p['slug']).taxons = Spree::Taxon.where(name: h['name'])
                count_index += 1;
                response.stream.write "data: #{Hash['status' => 'work',
                                                    'action' => 'api_put',
                                                    'total' => count,
                                                    'last_row' => count_index,
                                                    'hash' => params[:path],
                                                    'id' => params[:ud],
                                                    'obj_id' => h['id'],
                                                    'result' => !r.first.nil?
                ].to_json}\n\n"
                if r.first.nil?
                  fails_array << p
                end
              end
            end

          end

          response.stream.write "data: #{Hash['status' => 'done',
                                              'action' => 'api_put',
                                              'total' => count,
                                              'last_row' => count_index,
                                              'hash' => params[:path],
                                              'id' => params[:ud],
                                              'fails_array' => fails_array
          ].to_json}\n\n"

        when 'variant'
          base_json = base_json.sort_by {|h| h['id']}
          base_json.each_with_index do |h, i|
            a = Spree::Variant.find_by(product_id: h['product_id'])
            if !a.nil? then
              a.update(weight: h['weight'],
                       height: h['height'],
                       width: h['width'],
                       depth: h['depth'],
                       is_master: h['is_master'],
                       cost_price: h['cost_price'],
                       position: h['position'],
                       cost_currency: h['cost_currency'],
                       track_inventory: h['track_inventory'],
                       tax_category_id: h['tax_category_id'],
                       discontinue_on: h['discontinue_on'])
            else
              fails_array << h
            end
            response.stream.write "data: #{Hash['status' => 'work',
                                                'action' => 'api_put',
                                                'total' => base_json.count,
                                                'last_row' => i + 1,
                                                'hash' => params[:path],
                                                'id' => params[:ud],
                                                'obj_id' => h['id'],
                                                'result' => !a.nil?
            ].to_json}\n\n"
          end
          response.stream.write "data: #{Hash['status' => 'done',
                                              'action' => 'api_put',
                                              'total' => base_json.count,
                                              'last_row' => base_json.count,
                                              'hash' => params[:path],
                                              'id' => params[:ud],
                                              'fails_array' => fails_array
          ].to_json}\n\n"
        when 'assets'
          variants_json = get_json('variant')

          base_json.each_with_index do |h, i|
            select = variants_json.select {|s| s['id'] == h['viewable_id']}.first
            viewable_id = Spree::Variant.find_by(sku: select['sku'])
            unless viewable_id.nil?

              a = Spree::Asset.create!(id: h['id'],
                                       viewable_type: h['viewable_type'],
                                       viewable_id: viewable_id.id,
                                       attachment_width: h['attachment_width'],
                                       attachment_height: h['attachment_height'],
                                       attachment_file_size: h['attachment_file_size'],
                                       position: h['position'],
                                       attachment_content_type: h['attachment_content_type'],
                                       attachment_file_name: h['attachment_file_name'],
                                       attachment_updated_at: h['attachment_updated_at'],
                                       alt: h['alt'])
              if a.valid?
                a.update(type: 'Spree::Image')
              else
                fails_array << h
              end
            end

            response.stream.write "data: #{Hash['status' => 'preparing',
                                                'action' => 'api_get',
                                                'total' => base_json.count,
                                                'last_row' => i + 1,
                                                'hash' => params[:path],
                                                'id' => params[:ud],
                                                'obj_id' => h['id'],
                                                'result' => viewable_id.nil? ? false : a.valid?
            ].to_json}\n\n"
          end
          response.stream.write "data: #{Hash['status' => 'done',
                                              'action' => 'api_get',
                                              'total' => base_json.count,
                                              'last_row' => base_json.count,
                                              'hash' => params[:path],
                                              'id' => params[:ud],
                                              'fails_array' => fails_array
          ].to_json}\n\n"
        when 'properties'
        when 'product_property'
        when 'stalnoy_import'
        else

        end


      rescue IOError, ActionController::Live::ClientDisconnected
        logger.info "Stream closed"
      rescue StandardError => e
        response.stream.write "data: #{Hash['status' => 'error',
                                            'content' => e,
                                            'trace' => e.backtrace.join("\n")
        ].to_json}\n\n"
      ensure
        response.stream.close
      end

#
#
###########################
      def country
        json = get_json(params[:id])
        puts json

      end

    end


  end
end
