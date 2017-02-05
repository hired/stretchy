require 'stretchy/utils'

module Stretchy
  class API
    DEFAULT_BOOST     = 2.0
    DEFAULT_PER_PAGE  = 10

    extend  Forwardable
    include Enumerable
    include Utils::Methods

    attr_reader :collector, :opts, :root, :body, :context

    delegate [:with_context, :json, :as_json] => :collector

    delegate [
      :total, :total_count, :length, :size, :total_pages, :results, :hits,
      :to_a, :ids, :scores, :explanations, :aggregations, :each
    ] => :results_obj

    def initialize(opts = {})
      @opts       = opts
      @collector  = AndCollector.new(opts[:nodes] || [], query: true)
      @root       = opts[:root]     || {}
      @body       = opts[:body]     || {}
      @context    = opts[:context]  || {}
    end

    def context?(*args)
      (args - context.keys).empty?
    end

    def limit(size = nil)
      return @root[:size] || DEFAULT_PER_PAGE unless size
      add_root size: size.to_i
    end
    alias :limit_value :limit

    def offset(from = nil)
      return @root[:from] || 0 unless from
      add_root from: from.to_i
    end

    # page 1 = from: 0, size: per_page
    # page 2 = from: per_page, size: per_page
    def page(num = nil, params = {})
      return current_page if num.nil?
      per   = params[:limit] || params[:per_page] || limit
      per   = per.to_i > 0 ? per.to_i : 1
      start = [num.to_i - 1, 0].max
      add_root from: start * per, size: per
    end

    def per(num = nil)
      return limit if num.nil?
      add_root size: [num.to_i, 1].max
    end
    alias :per_page :per

    def current_page
      Utils.current_page(offset, limit)
    end

    def explain
      add_root explain: true
    end

    def fields(*list)
      add_root fields: list
    end

    def aggs(params = {})
      add_body aggs: params
    end

    def highlight(params = {})
      add_body highlight: params
    end

    def where(params = {})
      subcontext = {filter: true}
      subcontext[:nested] = params.delete(:nested) if params[:nested]
      add_params params, subcontext, :context_nodes
    end

    def match(params = {})
      if params.is_a? Hash
        subcontext = {query: true}
        subcontext[:nested] = true if params.delete(:nested)
        add_params params, subcontext, :context_nodes
      else
        add_params Hash[_all: params], :query, :context_nodes
      end
    end

    def more_like(params = {})
      params[:ids] = Array(params[:ids]) if params[:ids]
      add_params params, :query, :more_like_node
    end

    def fulltext(params = '')
      unless params.is_a?(String)
        raise Errors::InvalidParamsError.new('.fulltext only takes a string')
      end
      add_nodes Factory.fulltext_nodes_from_string(params, context)
    end

    def sort(*list)
      add_body sort: list
    end

    def query(params = {})
      add_params params, :query, :raw_node
    end

    def filter(params = {})
      add_params params, :filter, :raw_node
    end

    def should(params = {})
      add_params params, :should, :context_nodes
    end

    def not(params = {})
      add_params params, :must_not, :context_nodes
    end

    def range(params = {})
      add_params params, nil, :range_node
    end

    def geo_distance(params = {})
      add_params params, nil, :geo_distance_node
    end

    def boost(params = {}, options = {})
      return add_context(:boost) if Utils.is_empty? params

      subcontext = context.merge(boost: true)
      if params.is_a? self.class
        boost_json = options.merge(filter: params.json)
        add_nodes Node.new(boost_json, subcontext)
      else
        add_nodes Factory.raw_boost_node(params, subcontext)
      end
    end

    def field_value(params = {})
      add_params params, :boost, :field_value_function_node
    end

    def random(params)
      if params.is_a? Hash
        add_params params, :boost, :random_score_function_node
      else
        add_params Hash[seed: params], :boost, :random_score_function_node
      end
    end

    def near(params = {})
      add_params params, :boost, :decay_function_node
    end

    def request
      @request ||= begin
        root.merge(body: body.merge(query: collector.as_json))
      end
    end

    def response
      @response ||= Stretchy.search(request)
    end

    def results_obj
      @results ||= Results.new request, response
    end

    def count
      results_obj.ids.count
    end

    private

      def args_to_context(*args)
        args.reduce({}) do |ctx, item|
          next ctx if item.nil?
          item.is_a?(Hash) ? ctx.merge(item) : ctx.merge({item => true})
        end
      end

      def add_params(params = {}, new_context, factory_method)
        return add_context(new_context) if is_empty?(params)
        subcontext = context.merge(args_to_context(new_context))

        if params.is_a? self.class
          add_nodes params.with_context(subcontext)
        else
          add_nodes Factory.send(factory_method, params, subcontext)
        end
      end

      def add_nodes(additional)
        self.class.new(opts.merge(
          nodes: collector.nodes + Array(additional),
          root:  root,
          body:  body,
          context: {}
        ))
      end

      def add_root(options = {})
        self.class.new(opts.merge(
          nodes:    collector.nodes,
          root:     root.merge(options),
          body:     body,
          context:  context
        ))
      end

      def add_body(options = {})
        self.class.new(opts.merge(
          nodes:    collector.nodes,
          root:     root,
          body:     body.merge(options),
          context:  context
        ))
      end

      def add_context(*args)
        self.class.new(opts.merge(
          nodes:   collector.nodes,
          root:    root,
          body:    body,
          context: context.merge(args_to_context(*args))
        ))
      end

  end
end
