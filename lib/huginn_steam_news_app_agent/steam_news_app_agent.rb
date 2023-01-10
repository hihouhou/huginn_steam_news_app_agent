module Agents
  class SteamNewsAppAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_1h'

    description <<-MD
      The Steam News App Agent interacts with the API from Callisto for checking news from an app.

      The `debug` option is for adding.

      The `app_id` option the id of the app.

      The `limit` options is for limiting the results.

      The `max_length` options is for limiting the length.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.

    MD

    event_description <<-MD
      Events look like this:

          {
            "gid": "5623338145768332949",
            "title": "Patch 0.212.9",
            "url": "https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5623338145768332949",
            "is_external_url": true,
            "author": "IronMontilyet",
            "contents": "Before the holiday season truly kicks off we have a few more bugs that we wanted to address! In this patch you can expect some adjustments to various crafting recipes, further fishing fixes, as well as tweaks to several Mistlands enemies. We also found a way to optimise the game to make your RAM a w...",
            "feedlabel": "Community Announcements",
            "date": 1671526854,
            "feedname": "steam_community_announcements",
            "feed_type": 1,
            "appid": 892970,
            "tags": [
              "patchnotes"
            ]
          }
    MD

    def default_options
      {
        'debug' => 'false',
        'emit_events' => 'true',
        'expected_receive_period_in_days' => '2',
        'changes_only' => 'true',
        'app_id' => '',
        'limit' => '',
        'max_length' => '',
        'patchnotes_only' => 'true'
      }
    end

    form_configurable :debug, type: :boolean
    form_configurable :emit_events, type: :boolean
    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :changes_only, type: :boolean
    form_configurable :app_id, type: :string
    form_configurable :limit, type: :string
    form_configurable :max_length, type: :string
    form_configurable :patchnotes_only, type: :boolean
    def validate_options
      unless options['app_id'].present?
        errors.add(:base, "app_id is a required field")
      end
      unless options['limit'].present?
        errors.add(:base, "limit is a required field")
      end
      unless options['max_length'].present?
        errors.add(:base, "max_length is a required field")
      end
      if options.has_key?('patchnotes_only') && boolify(options['patchnotes_only']).nil?
        errors.add(:base, "if provided, patchnotes_only must be true or false")
      end
      if options.has_key?('emit_events') && boolify(options['emit_events']).nil?
        errors.add(:base, "if provided, emit_events must be true or false")
      end

      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      query_steam
    end

    private

    def log_curl_output(code,body)

      log "request status : #{code}"

      if interpolated['debug'] == 'true'
        log "body"
        log body
      end

    end

    def query_steam()
      url = URI("https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/")
      params = { :appid => interpolated['app_id'], :count => interpolated['limit'], :maxlength => interpolated['max_length'] }
      url.query = URI.encode_www_form(params)
      
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      
      request = Net::HTTP::Get.new(url)
      response = http.request(request)

      log_curl_output(response.code,response.body)

      payload = JSON.parse(response.body)

      if interpolated['changes_only'] == 'true'
        if payload.to_s != memory['last_status']
          if "#{memory['last_status']}" == ''
            payload['appnews']['newsitems'].each do |item|
			  if interpolated['patchnotes_only'] == 'false' || ( !item['tags'].nil? && item['tags'].include?("patchnotes") && interpolated['patchnotes_only'] == 'true')
                create_event payload: item
			  end
            end
          else
            last_status = memory['last_status'].gsub("=>", ": ").gsub(": nil", ": null")
            last_status = JSON.parse(last_status)
            payload['appnews']['newsitems'].each do | item |
              found = false
              if interpolated['debug'] == 'true'
                log item
                log "found is #{found}"
              end
              last_status['appnews']['newsitems'].each do | itembis|
                if item == itembis
                  found = true
                end
                if interpolated['debug'] == 'true'
                  log "found is #{found}"
                end
              end
              if found == false && (interpolated['patchnotes_only'] == 'false' || ( !item['tags'].nil? && item['tags'].include?("patchnotes") && interpolated['patchnotes_only'] == 'true'))
                if interpolated['debug'] == 'true'
                  log "event created"
                end
                create_event payload: item
              else
                if interpolated['debug'] == 'true'
                  log "event not created"
                end
              end
            end
          end
          memory['last_status'] = payload.to_s
        end
      else
        if payload.to_s != memory['last_status']
          memory['last_status']= payload.to_s
        end
        payload['appnews']['newsitems'].each do |item|
          create_event payload: item
        end
      end
    end
  end
end
