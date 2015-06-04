require 'stretchy/clauses/base'

module Stretchy
  module Clauses
      # 
      # A Match clause inherits the same state as any clause.
      # There aren't any more specific methods to chain, as
      # this clause only handles basic full-text searches.
      # 
      # @author [atevans]
      # 
    class MatchClause < Base

      # 
      # Creates a temporary MatchClause outside the main
      # query scope by using a new {Base}. Primarily
      # used in {BoostClause} for boosting on full-text
      # matches.
      # 
      # @param params = {} [Hash] Params to pass to the full-text match
      # @param options = {} [Hash] Options to be passed to the underlying {MatchQuery}
      # 
      # @return [MatchClause] Temporary clause outside current state
      def self.tmp(params = {}, options = {})
        self.new(Builders::ShellBuilder.new, params, options)
      end

      # 
      # Creates a new state with a match query applied.
      # 
      # @overload initialize(base, params)
      #   @param [Base] Base clause to copy data from
      #   @param [String] Performs a full-text query for this string on all fields in the document.
      # 
      # @overload initialize(base, params)
      #   @param [Base] Base clause to copy data from
      #   @param [Hash] A hash of fields and values to perform full-text matches with
      # 
      # @overload initialize(base, params, options)
      #   @param [Base] Builder to use
      #   @param [Hash] A hash of fields and values to perform full-text matches with
      #   @param [Hash] A hash of options to pass to the generated {MatchQuery}
      # 
      # @example A basic full-text match
      #   query.match("anywhere in document")
      # 
      # @example A full-text search on specific fields
      #   query.match(
      #     my_field: "match in my_field",
      #     other_field: "match in other_field"
      #   )
      # 
      # @example A full-text search using the 'or' operator
      #   query.match(
      #     my_field: 'match any of these',
      #     other_field: 'other words',
      #     operator: 'or'
      #   )
      # 
      # @see http://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-match-query.html Elastic Docs - Match Query
      def initialize(base, params = {}, options = {})
        super(base)
        add_params(params, options)
      end

      # 
      # Specifies that values for this field should be
      # matched with a proximity boost, rather than as
      # a generic match query.
      # 
      # This means searching for "quick brown fox" will
      # return matches in the following order:
      # 
      # * "the quick brown fox jumped over"
      # * "the brown quick fox jumped over"
      # * "the fox, brown & quick jumped over"
      # * "the quick fox jumped over"
      # * "the quick green and purple sparkly fox jumped over"
      # * "the quick dog jumped over"
      # * "the adoreable puppy jumped over" **not returned**
      # 
      # @overload phrase(opts_or_str)
      #   @param opts_or_str = {} [String] A phrase that will 
      #     be matched anywhere in the document
      # 
      # @overload phrase(opts_or_str)
      #   @param opts_or_str = {} [Hash] A hash of fields and phrases
      #     that should be matched in those fields
      # 
      # @example Matching multiple words together
      #   query.match.phrase('hugs and love')
      # 
      # @example Not matching a phrase
      #   query.match.not.phrase(comment: 'offensive words to hide')
      # 
      # @return [self] Allows continuing the query chain
      # 
      # @see https://www.elastic.co/guide/en/elasticsearch/guide/current/proximity-relevance.html Elasticsearch guide: proximity for relevance
      def fulltext(opts_or_str = {})
        add_params(opts_or_str, min: 1)
        add_params(opts_or_str, should: true, slop: 50)
        self
      end

      # 
      # Switches to inverted context. Matches applied here work the same way as
      # {#initialize}, but returned documents must **not** match these filters.
      # 
      # @overload not(opts_or_str)
      #   @param [String] A string that must not be matched anywhere in the document
      # @overload not(opts_or_str)
      #   @param [Hash] A hash of fields and strings that must not be matched in those fields
      # 
      # @return [MatchClause] inverted query state with match filters applied
      # 
      # @example Inverted full-text
      #   query.match.not("hello")
      # 
      # @example Inverted full-text matching for specific fields
      #   query.match.not(
      #     my_field: "not_match_1",
      #     other_field: "not_match_2"
      #   )
      def not(opts_or_str = {})
        @inverse = true
        add_params(opts_or_str)
        self
      end

      # 
      # Switches to `should` context. Applies full-text matches
      # that are not required, but boost the relevance score for
      # matching documents.
      # 
      # Can be chained with {#not}
      # 
      # @overload should(opts_or_str)
      #   @param [String] A string that should be matched anywhere in the document
      # @overload should(opts_or_str)
      #   @param [Hash] A hash of fields and strings that should be matched in those fields
      # 
      # @return [MatchClause] query state with should filters added
      # 
      # @example Should match with full-text
      #   query.match.should("anywhere")
      # 
      # @example Should match specific fields
      #   query.match.should(
      #     field_one: "one",
      #     field_two: "two"
      #   )
      # 
      # @example Should not match
      #   query.match.should.not(
      #     field_one: "one",
      #     field_two: "two"
      #   )
      # 
      # @see http://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-bool-query.html Elastic Docs - Bool Query
      def should(opts_or_str = {})
        @should  = true
        @inverse = false
        add_params(opts_or_str)
        self
      end

      # 
      # Converts this match context to a set of boosts
      # to use in a {Stretchy::Queries::FunctionScoreQuery}
      # 
      # @param weight = nil [Numeric] Weight of generated boost
      # 
      # @return [Stretchy::Boosts::FilterBoost] boost containing these match parameters
      def to_boost(weight = nil)
        weight ||= Stretchy::Boosts::FilterBoost::DEFAULT_WEIGHT
        
        Stretchy::Boosts::FilterBoost.new(
          filter: Stretchy::Filters::QueryFilter.new(
            base.match_builder.to_query
          ),
          weight: weight
        )
      end

      # 
      # Accessor for `@should`
      # 
      # @return [true, false] `@should`
      def should?
        !!@should
      end

      private

        def add_params(params = {}, options = {})
          case params
          when Hash
            params.each do |field, params|
              add_param(field, params, options)
            end
          else
            add_param('_all', params, options)
          end
        end

        def add_param(field, param, options = {})
          options[:inverse] = true if inverse?
          options[:should]  = true if should?
          base.match_builder.add_matches(field, param, options)
        end

    end
  end
end