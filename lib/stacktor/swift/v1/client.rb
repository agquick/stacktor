module Stacktor

  module Swift

    module V1

      class Client < Stacktor::Core::Client

        def list_containers(opts={})
          path = "/"
          opts[:format] = 'json'
          resp = self.execute_request(
            path: path,
            method: "GET",
            data: opts
          )
          parse_containers(resp)
          return resp
        end

        def list_objects(opts)
          ctn = opts[:container_name]
          data = {}
          data[:limit] = opts[:limit] || 1000
          data[:marker] = opts[:marker] if opts[:marker]
          data[:end_marker] = opts[:end_marker] if opts[:end_marker]
          data[:prefix] = opts[:prefix] if opts[:prefix]
          data[:format] = 'json'
          data[:delimiter] = opts[:delimiter] if opts[:delimiter]
          data[:path] = opts[:path] if opts[:path]
          result = self.execute_request(
            path: "/#{ctn}",
            method: "GET",
            data: data
          )
          parse_objects(result, {'container_name' => ctn})
          return result
        end


        def get_object_content(opts, &resp_fn)
          ctn = opts[:container_name]
          obn = opts[:object_name]

          resp = self.execute_request(
            path: "/#{ctn}/#{obn}",
            method: "GET",
            response_handler: resp_fn
          )
          parse_object(resp, {'name' => obn, 'container_name' => ctn})
          return resp
        end

        ##
        # Stores object in Swift container
        #
        # @param opts [Hash] the options hash
        # @option opts [String] :container_name - name of the container
        # @option opts [String] :object_name - name of the new object
        # @option opts [File, String] :content - contents of the object
        # @option opts [String] :content_type - content type for the object
        # @option opts [Hash] :headers - default headers for storing object
        # @option opts [Hash] :metadata - metadata to store with the object
        #
        # @return [Hash] Result object
        #
        def create_object(opts)
          ctn = opts[:container_name]
          obn = opts[:object_name]
          if opts[:content].is_a?(String)
            body = StringIO.new(opts[:content])
          else
            body = opts[:content]
          end

          headers = opts[:headers] || {}
          if opts[:content_type].nil?
            headers['X-Detect-Content-Type'] = 'true'
          else
            headers['Content-Type'] = opts[:content_type]
          end
          if !opts[:metadata].nil?
            opts[:metadata].each do |k,v|
              headers["X-Object-Meta-#{k}"] = v
            end
          end
          resp = self.execute_request(
            path: "/#{ctn}/#{obn}",
            method: "PUT",
            headers: headers,
            data: body
          )
          parse_object(resp, {'name' => obn, 'container_name' => ctn})
          resp[:object].reload if resp[:object]
          return resp
        end

        def delete_object(opts)
          ctn = opts[:container_name]
          obn = opts[:object_name]

          resp = self.execute_request(
            path: "/#{ctn}/#{obn}",
            method: "DELETE"
          )
          parse_object(resp, {'name' => obn, 'container_name' => ctn})
          return resp
        end

        def get_object_metadata(opts)
          ctn = opts[:container_name]
          obn = opts[:object_name]

          resp = self.execute_request(
            path: "/#{ctn}/#{obn}",
            method: "HEAD"
          )
          parse_object(resp, {'name' => obn, 'container_name' => ctn})
          return resp
        end

        ## HELPERS
        
        def token=(val)
          @settings[:token] = val
        end
        def token
          @settings[:token]
        end
        def has_valid_token?
          @settings[:token] && @settings[:token].valid?
        end

        private

        def parse_containers(resp)
          if resp[:success]
            resp[:containers] = JSON.parse(resp[:body]).collect {|c| Container.new(c, self)}
          end
        end

        def parse_object(resp, data={})
          r = resp[:response]
          if resp[:success]
            resp[:object] = ContainerObject.new(data, self, headers: r)
          end
        end

        def parse_objects(resp, data={})
          if resp[:success]
            resp[:objects] = JSON.parse(resp[:body]).collect{|obj_data|
              ContainerObject.new(obj_data, self)
            }
          end
        end

        def build_headers
          {
            'X-Auth-Token' => self.settings[:token].id
          }
        end

      end

    end

  end

end
