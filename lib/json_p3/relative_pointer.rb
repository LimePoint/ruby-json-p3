# frozen_string_literal: true

module JSONP3
  # A relative JSON Pointer.
  # See https://datatracker.ietf.org/doc/html/draft-hha-relative-json-pointer
  class RelativePointer
    RE_RELATIVE_POINTER = /\A(?<ORIGIN>\d+)(?<INDEX_G>(?<SIGN>[+-])(?<INDEX>\d))?(?<POINTER>.*)\z/m
    RE_INT = /\A(0|[1-9][0-9]*)\z/

    # @param rel [String]
    def initialize(rel)
      match = RE_RELATIVE_POINTER.match(rel)

      raise JSONP3::Pointer::SyntaxError, "failed to parse relative pointer" if match.nil?

      @origin = parse_int(match[:ORIGIN] || raise)
      @index = 0

      if match[:INDEX_G]
        @index = parse_int(match[:INDEX] || raise)
        raise JSONP3::Pointer::SyntaxError, "index offset can't be zero" if @index.zero?

        @index = -@index if match[:SIGN] == "-"
      end

      @pointer = match[:POINTER] == "#" ? "#" : Pointer.new(match[:POINTER] || raise)
    end

    def to_s
      sign = @index.positive? ? "+" : ""
      index = @index.zero? ? "" : "#{sign}#{@index}"
      "#{@origin}#{index}#{@pointer}"
    end

    # Return a new JSON Pointer by applying this relative pointer to _pointer_.
    # @param pointer [String | Pointer]
    # @return [Pointer]
    def to(pointer)
      p = pointer.is_a?(String) ? Pointer.new(pointer) : pointer

      if @origin > p.tokens.length
        raise JSONP3::Pointer::IndexError,
              "origin (#{@origin}) exceeds root (#{p.tokens.length})"
      end

      tokens = @origin < 1 ? p.tokens[0..] || raise : p.tokens[0...-@origin] || raise

      if @index != 0
        last = tokens.last
        unless last.is_a?(Integer)
          raise JSONP3::Pointer::IndexError,
                "an index offset can only be applied to an array item"
        end

        tokens[-1] = last + @index
      end

      if @pointer == "#"
        raise JSONP3::Pointer::IndexError, "the document root has no member name or array index" if tokens.empty?

        tokens[-1] = "##{tokens[-1]}"
        return IndexPointer.new(Pointer.encode(tokens), item: @index != 0)
      end

      depth = tokens.length - 1
      tokens.concat(@pointer.tokens) # steep:ignore
      return Pointer.new(Pointer.encode(tokens)) if @index.zero?

      ItemPointer.new(Pointer.encode(tokens), depth)
    end

    private

    # @param token [String]
    # @return [Integer]
    def parse_int(token)
      raise JSONP3::Pointer::SyntaxError, "unexpected leading zero" if token.start_with?("0") && token.length > 1
      raise JSONP3::Pointer::SyntaxError, "expected an integer, found '#{token}'" unless RE_INT.match?(token)

      token.to_i
    end

    # The result of applying a relative JSON Pointer ending in "#". Its last token is
    # the "#" prefixed name or index of the target, which resolves to that name or index.
    class IndexPointer < Pointer
      # @param pointer [String]
      # @param item [bool] true if the target must be an array item.
      def initialize(pointer, item: false)
        super(pointer)
        @item = item
      end

      # @param value [Object]
      # @param default [Object]
      def resolve(value, default: UNDEFINED)
        container = parent.resolve(value)
        name = (@tokens.last || raise).to_s[1..] || raise

        if container.is_a?(Array) && RE_INT.match?(name) && name.to_i < container.length
          name.to_i
        elsif container.is_a?(Hash) && !@item && container.key?(name)
          name
        else
          default
        end
      end

      # @param value [Object]
      # @return [Array<Object>]
      def resolve_with_parent(value)
        [parent.resolve(value), resolve(value)]
      end
    end

    # The result of applying a relative JSON Pointer with an index offset and a JSON
    # Pointer remainder. It resolves only if the token at _depth_ is an array item.
    class ItemPointer < Pointer
      # @param pointer [String]
      # @param depth [Integer] the index of the token that must be an array item.
      def initialize(pointer, depth)
        super(pointer)
        @depth = depth
      end

      # @param value [Object]
      # @param default [Object]
      def resolve(value, default: UNDEFINED)
        array_item?(value) ? super : default
      end

      # @param value [Object]
      # @return [Array<Object>]
      def resolve_with_parent(value)
        array_item?(value) ? super : [UNDEFINED, UNDEFINED]
      end

      private

      # @param value [Object]
      def array_item?(value)
        Pointer.new(Pointer.encode(@tokens[...@depth] || raise)).resolve(value).is_a?(Array)
      end
    end
  end
end
