require 'stretchy/clauses/base'

module Stretchy
  module Clauses
      # 
      # A Boost clause encapsulates the boost query state. It
      # basically says "the next where / range / match filter
      # will be used to boost a document's score instead of
      # selecting documents to return."
      # 
      # Calling `.boost` by itself doesn't do anything, but
      # the next method (`.near`, `.match`, etc) will specify
      # a boost using the same syntax as other clauses. These
      # methods take a `:weight` parameter specifying the weight 
      # to assign that boost.
      # 
      # @author [atevans]
      # 
    class BoostClause < Base

      extend Forwardable

      delegate [:geo, :range] => :where

      # 
      # Switch to the boost state, specifying that
      # the next where / range / etc will be a boost
      # instead of a regular filter / range / etc.
      # 
      # @param base [Base] a clause to copy query state from
      # @param options = {} [Hash] Options for the boost clause
      # @option options [true, false] :inverse (nil) If this boost should also be in the inverse state
      # 
      def initialize(base)
        super(base)
      end

      # 
      # Changes query state to "match" in the context
      # of boosting. Options here work the same way as
      # {MatchClause#initialize}, but the combined query
      # will be applied as a boost function.
      # 
      # @param params = {}  [Hash] Params for full text matching
      # @param options = {} [Hash] Options for the underlying {MatchQuery}
      # 
      # @return [BoostMatchClause] query with boost match state
      def match(params = {}, options = {})
        BoostMatchClause.new(base, params, options)
      end

      # 
      # Changes query state to "where" in the context
      # of boosting. Works the same way as {WhereClause},
      # but applies the generated filters as a boost
      # function. 
      # 
      # @param options = {} [Hash] Filters to use in this boost.
      # 
      # @return [BoostWhereClause] Query state with boost filters applied
      # 
      def where(options = {})
        BoostWhereClause.new(base, options)
      end
      alias :filter :where

      # 
      # Adds a {Boosts::FieldDecayBoost}, which boosts
      # a search result based on how close it is to a 
      # specified value. That value can be a date, time,
      # number, or {Types::GeoPoint}
      # 
      # Required:
      # 
      # * `:field`
      # * `:origin` or `:lat` & `:lng` combo
      # * `:scale`
      # 
      # @option options [Numeric] :field What field to check with this boost
      # @option options [Date, Time, Numeric, Types::GeoPoint] :origin Boost score based on how close the field is to this value. Required unless {Types::GeoPoint} is present (:lat, :lng, etc)
      # @option options [Numeric] :lat Latitude, for a geo point
      # @option options [Numeric] :latitude Latitude, for a geo point
      # @option options [Numeric] :lng Longitude, for a geo point
      # @option options [Numeric] :lon Longitude, for a geo point
      # @option options [Numeric] :longitude Longitude, for a geo point
      # @option options [String] :scale When the field is this distance from origin, the boost will be multiplied by `:decay` . Default is 0.5, so when `:origin` is a geo point and `:scale` is '10mi', then this boost will be twice as much for a point at the origin as for one 10 miles away
      # @option options [String] :offset Anything within this distance of the origin is boosted as if it were at the origin
      # @option options [Symbol] :type (:gauss) What type of decay to use. One of `:linear`, `:exp`, or `:gauss` 
      # @option options [Numeric] :decay_amount (0.5) How much the boost falls off when it is `:scale` distance from `:origin`
      # @option options [Numeric] :weight (1.2) How strongly to weight this boost compared to others
      # 
      # @example Boost near a geo point
      #   query.boost.near(
      #     field: :coords,
      #     distance: '27km',
      #     scale: '3mi',
      #     lat: 33.3,
      #     lng: 28.2
      #   )
      # 
      # @example Boost near a date
      #   query.boost.near(
      #     field: :published_at,
      #     origin: Time.now,
      #     scale: '3d'
      #   )
      # 
      # @example Boost near a number (with options)
      #   query.boost.near(
      #     field: :followers,
      #     origin: 100,
      #     scale: 50,
      #     offset: 2,
      #     type: :linear,
      #     decay: 0.75,
      #     weight: 10
      #   )
      # 
      # @return [Base] Query with field decay filter added
      # 
      # @see http://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-function-score-query.html Elastic Docs - Function Score Query
      def near(options = {})
        if options[:lat] || options[:latitude]  ||
           options[:lng] || options[:longitude] || options[:lon]

          options[:origin] = Stretchy::Types::GeoPoint.new(options)
        end
        base.boost_builder.functions << Stretchy::Boosts::FieldDecayBoost.new(options)
        Base.new(base)
      end
      alias :geo :near

      # 
      # Adds a {Boosts::RandomBoost} to the query, for slightly
      # randomizing search results.
      # 
      # @param seed [Numeric] The seed for the random value
      # @param weight [Numeric] The weight for this random value
      # 
      # @return [Base] Query with random boost applied
      # 
      # @see http://www.elastic.co/guide/en/elasticsearch/guide/master/random-scoring.html Elastic Docs - Random Scoring
      def random(*args)
        base.boost_builder.functions << Stretchy::Boosts::RandomBoost.new(*args)
        Base.new(base)
      end

      # 
      # Defines a global boost for all documents in the query
      # 
      # @param num [Numeric] Boost to apply to the whole query
      # 
      # @return [self] Boost context with overall boost applied
      def all(num)
        base.boost_builder.overall_boost = num
        self
      end

      # 
      # The maximum boost that any document can have
      # 
      # @param num [Numeric] Maximum score a document can have
      # 
      # @return [self] Boost context with maximum score applied
      def max(num)
        base.boost_builder.max_boost = num
        self
      end

      # 
      # Set scoring mode for when a document matches multiple
      # boost functions.
      # 
      # @param mode [Symbol] Score mode. Can be one of `multiply sum avg first max min`
      # 
      # @return [self] Boost context with score mode applied
      def score_mode(mode)
        base.boost_builder.score_mode = mode
        self
      end

      # 
      # Set boost mode for when a document matches multiple
      # boost functions.
      # 
      # @param mode [Symbol] Boost mode. Can be one of `multiply replace sum avg max min`
      # 
      # @return [self] Boost context with boost mode applied
      def boost_mode(mode)
        base.boost_builder.boost_mode = mode
        self
      end

      # 
      # Switches to inverse context - boosts added with {#where} 
      # and #{match} will be applied to documents which *do not*
      # match said filters.
      # 
      # @return [BoostClause] Boost clause in inverse context
      def not(options = {})
        @inverse = true
        self
      end

    end
  end
end