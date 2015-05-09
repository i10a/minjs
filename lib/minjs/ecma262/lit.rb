# coding: utf-8
module Minjs
  module ECMA262
    class Literal < Base
      def ws?
        false
      end

      def lt?
        false
      end

      def to_exp?
        false
      end
    end

    class DivOrRegexpLiteral < Literal
      def traverse(parent, &block)
      end

      def to_js(options = {})
        "??"
      end

      @@instance = self.new()
      def self.get
        @@instance
      end
    end

    LIT_DIV_OR_REGEXP_LITERAL = DivOrRegexpLiteral.get

    class WhiteSpace < Literal
      def traverse(parent, &block)
      end

      def ws?
        true
      end

      def to_js(options = {})
        " "
      end

      @@instance = self.new()
      def self.get
        @@instance
      end
    end

    class LineFeed < Literal
      def traverse(parent, &block)
      end

      def lt?
        true
      end

      def to_js(options = {})
        "\n"
      end

      @@instance = self.new()
      def self.get
        @@instance
      end
    end

    LIT_LINE_FEED = LineFeed.get

    class Null < Literal
      def initialize(val)
        @val = :null
      end

      def traverse(parent, &block)
        yield self, parent
      end

      def to_s
        "null"
      end

      def to_js(options = {})
        "null"
      end

      @@instance = self.new(nil)
      def self.get
        @@instance
      end
    end

    class Boolean < Literal
      attr_reader :val

      def initialize(val)
        if val.to_s == "true"
          @val = :"true"
        else
          @val = :"false"
        end
      end

      def traverse(parent, &block)
        yield self, parent
      end

      def to_js(options = {})
        @val.to_s
      end

      def true?
        @val == :true
      end

      @@true = self.new(:true)
      @@false = self.new(:false)
      def self.get(val)
        if val.to_sym == :true
          @@true
        else
          @@false
        end
      end
    end

    class ECMA262String < Literal
      attr_reader :val

      def initialize(val)
        @val = val
      end
      def traverse(parent)
        yield self, parent
      end
      def to_js(options = {})
        t = "\""
        @val.to_s.each_codepoint do |c|
          if c == 0x5c
            t << ('\\\\')
          elsif c == 0x22
            t << ('\"')
          elsif c >= 0x20 and c <= 0x7f
            t << ("%c" % c)
          elsif c == 8
            t << '\\b'
          elsif c == 9
            t << '\\t'
          elsif c == 0xa
            t << '\\n'
          elsif c == 0xb
            t << '\\v'
          elsif c == 0xc
            t << '\\v'
          elsif c == 0xd
            t << '\\r'
          elsif c == 0
            t << '\\0'
          elsif c < 0x20
            t << "\\x#{"%02x" % c}"
          else
            t << [c].pack("U*")
          end
        end
        t << "\""
      end
    end

    class ECMA262Numeric < Literal
      attr_reader :integer, :decimal, :exp, :raw

      def initialize(raw, integer, decimal = nil, exp = nil)
        @raw = raw
        if integer == :nan
          integer = nil
          @nan = true
        elsif integer == :infinity
          integer = nil
          @infinity = true
        elsif integer.kind_of? Float
          @integer, @decimal = integer.to_i.to_s
          @decimal = (integer - @integer).to_s.sub(/^.*0\./, '')
        else
          @integer = integer.to_s
          if decimal
            @decimal = decimal.to_s
          end
          @exp = exp
        end
        @decimal = nil if @decimal == 0
        @exp = nil if @exp == 1
      end

      def traverse(parent, &block)
        yield self, parent
      end

      def to_js(options = {})
        if @nan
          return "NaN"
        end
        t = @integer.dup.to_s

        if @decimal
          if @integer == '0'
            t = ".#{@decimal}"
          else
            t << ".#{@decimal}"
          end
        end
        if @exp
          t << "e#{@exp}"
        end

        if @decimal.nil? and @exp.nil? and t.match(/0{3,}$/)
          len = $&.length
          t.sub!(/0+$/, "e#{len}")
        end
        t
      end

      def integer?
        @decimal.nil?
      end

      def to_num
        if @decimal
          to_f
        else
          to_i
        end
      end

      def to_i
        if @exp
          @integer.to_i * (10 ** @exp.to_i)
        else
          @integer.to_i
        end
      end

      def to_f
        "#{@integer}.#{@decimal}e#{@exp}".to_f
      end
=begin
TODO
      #
      # 9.8.1
      #
      def to_ecma262_string
        if @nan
          "NaN"
        elsif @integer == 0 and @decimal.nil? and @exp.nil?
          "0"
        elsif @integer.to_i < 0
          ECMA262Numeric.new(-@integer, @decimal, @exp).to_string
        elsif @intinify
          "Infinity"
        else
          #puts "to_f:"
          #puts to_f
          _i = @integer
          _d = @decimal
          _e = @exp.to_i || 0

          if _d
            _e -= _d.length
            _i += _d
            _d = nil
          end

          if _i.match(/^0/) and _i != '0'
            _i = _i.sub(/^0/, '')
          end
          #puts "i,d,e:"
          #p _i
          #p _d
          #p _e

          while(_i % 10 == 0)
            _i /= 10
            _e += 1
          end
          k = _i.to_s.length
          s = _i
          n = k + _e
          #
          # Otherwise, let n, k, and s be integers such that k ≥ 1,
          # 10k−1 ≤ s < 10k, the Number value for s × 10n−k is m,
          # and k is as small as possible. Note that k is the number
          # of digits in the decimal representation of s, that s is
          # not divisible by 10, and that the least significant digit
          # of s is not necessarily uniquely determined by these
          # criteria.
          #
          #puts "k=#{k}"
          #puts "s=#{s}"
          #puts "n=#{n}"
          #puts "#{s}e#{n-k}"
          #puts eval("#{s}e#{n-k}")
          #
          # If k ≤ n ≤ 21, return the String consisting of the k digits
          # of the decimal representation of s (in order, with no
          # leading zeroes), followed by n−k occurrences of the
          # character ‘0’.
          #
          if k <= n and n <= 21
            "#{s * 10 ** (n-k)}"
          #
          # If 0 < n ≤ 21, return the String consisting of the most
          # significant n digits of the decimal representation of s,
          # followed by a decimal point ‘.’, followed by the
          # remaining k−n digits of the decimal representation of s.
          #
          elsif 0 < n and n <= 21
            "#{s[0...n]}.#{s[n..-1]}"
          #
          # If −6 < n ≤ 0, return the String consisting of the
          # character ‘0’, followed by a decimal point ‘.’,
          # followed by −n occurrences of the character ‘0’,
          # followed by the k digits of the decimal representation of
          # s.
          #
          elsif -6 < n and n <= 0
            to_f.to_s #TODO
            #"0.#{'0' * -n}#{s}"
          #
          # Otherwise, if k = 1, return the String consisting of the
          # single digit of s, followed by lowercase character ‘e’,
          # followed by a plus sign ‘+’ or minus sign ‘−’
          # according to whether n−1 is positive or negative,
          # followed by the decimal representation of the integer
          # abs(n−1) (with no leading zeroes).
          #
          elsif k == 1
            to_f.to_s #TODO
            #"#{s}e#{n-1 > 0 ? '+' : '-'}#{(n-1).abs}"
          #
          # Return the String consisting of the most significant digit
          # of the decimal representation of s, followed by a decimal
          # point ‘.’, followed by the remaining k−1 digits of the
          # decimal representation of s, followed by the lowercase
          # character ‘e’, followed by a plus sign ‘+’ or minus
          # sign ‘−’ according to whether n−1 is positive or
          # negative, followed by the decimal representation of the
          # integer abs(n−1) (with no leading zeroes).
          #
          else
            to_f.to_s #TODO
          end
        end
      end
=end

      NUMERIC_NAN = ECMA262Numeric.new('NaN', :nan)
    end

    class ECMA262RegExp < Literal
      def initialize(body, flags)
        @body = body
        @flags = flags
      end

      def traverse(parent)
        yield self, parent
      end

      def to_js(options = {})
        "/#{@body}/#{@flags}"
      end
    end

    LITERAL_TRUE = Boolean.new(:true)
    LITERAL_FALSE = Boolean.new(:false)

    class ECMA262Array < Literal
      def initialize(val)
        @val = val
      end
      def traverse(parent, &block)
        yield self, parent
        @val.each do |k|
          k.traverse(parent, &block)
        end
      end
      def to_js(options = {})
        "[" + @val.collect{|x| x.to_s}.join(",") + "]"
      end
    end

    class ECMA262Object < Literal
      include Ctype
      private
      def idname?(name)
        return false if name.length == 0
        s = name.codepoints
        return false unless identifier_start?(s[0])
        s.unshift
        s.each do |code|
          return false unless identifier_part?(code)
        end
        return true
      end

      public
      def initialize(val)
        @val = val
      end
      def traverse(parent, &block)
        yield self, parent
        @val.each do |k, v|
          k.traverse(parent, &block)
          v.traverse(parent, &block)
        end
      end
      def to_js(options = {})
        "{" + @val.collect{|x, y|
          if x.kind_of? ECMA262Numeric
            "#{x.raw}:#{y.to_js(options)}"
          elsif idname?(x.val.to_s)
            "#{x.val.to_s}:#{y.to_js(options)}"
          else
            "#{x.to_js(options)}:#{y.to_js(options)}"
          end
        }.join(",") + "}"
      end
    end

    class SingleLineComment < Literal
      def initialize(comment)
        @comment = comment
      end

      def traverse(parent, &block)
      end

      def to_js(options)
        "//#{@comment}"
      end

      def ws?
        true
      end
    end

    class MultiLineComment < Literal
      def initialize(comment, has_lf)
        @comment = comment
        @has_lf = has_lf
      end

      def traverse(parent, &block)
      end

      def to_js(options)
        if lt?
          "/*#{@comment}*/"
        else
          "/*#{@comment}*/"
        end
      end

      def ws?
        !lt?
      end

      def lt?
        @has_lf ? true : false
      end
    end

    class IdentifierName < Literal
      attr_accessor :context
      attr_accessor :val

      @@sym = {}

      def initialize(context, val)
        @val = val.to_sym
      end

      def self.get(context, val)
        @@sym[val] ||= self.new(context, val)
      end

      RESERVED_WORD = [
        :break, :do, :instanceof, :typeof, :case, :else,
        :new, :var, :catch, :finally, :return, :void, :continue,
        :for, :switch, :while,:debugger, :function, :this, :with,
        :default, :if, :throw, :delete, :in, :try,
        :class, :enum, :extends, :super, :const, :export, :import,
        :implements, :let, :private, :public, :yield,
        :interface, :package, :protected, :static,
        :null, :false, :true
      ]
      def reserved?
        RESERVED_WORD.index(val)
      end

      def self.reserved?(val)
        RESERVED_WORD.index(val)
      end

      def traverse(parent)
        yield self, parent
      end

      def to_js(options = {})
        val.to_s
      end

      def ==(obj)
        self.class == obj.class and self.val == obj.val
      end
    end

    ID_THIS = IdentifierName.get(nil, :this)
    ID_VAR = IdentifierName.get(nil, :var)
    ID_IN = IdentifierName.get(nil, :in)
    ID_INSTANCEOF = IdentifierName.get(nil, :instanceof)
    ID_FUNCTION = IdentifierName.get(nil, :function)
    ID_NULL = IdentifierName.get(nil, :null)
    ID_TRUE = IdentifierName.get(nil, :true)
    ID_FALSE = IdentifierName.get(nil, :false)
    ID_NEW = IdentifierName.get(nil, :new)
    ID_DELETE = IdentifierName.get(nil, :delete)
    ID_VOID = IdentifierName.get(nil, :void)
    ID_TYPEOF = IdentifierName.get(nil, :typeof)
    ID_IF = IdentifierName.get(nil, :if)
    ID_ELSE = IdentifierName.get(nil, :else)
    ID_FOR = IdentifierName.get(nil, :for)
    ID_WHILE = IdentifierName.get(nil, :while)
    ID_DO = IdentifierName.get(nil, :do)
    ID_CONTINUE = IdentifierName.get(nil, :continue)
    ID_BREAK = IdentifierName.get(nil, :break)
    ID_RETURN = IdentifierName.get(nil, :return)
    ID_WITH = IdentifierName.get(nil, :with)
    ID_SWITCH = IdentifierName.get(nil, :switch)
    ID_THROW = IdentifierName.get(nil, :throw)
    ID_TRY = IdentifierName.get(nil, :try)
    ID_CATCH = IdentifierName.get(nil, :catch)
    ID_FINALLY = IdentifierName.get(nil, :finally)
    ID_DEBUGGER = IdentifierName.get(nil, :debugger)
    ID_GET = IdentifierName.get(nil, :get)
    ID_SET = IdentifierName.get(nil, :set)
    ID_CASE = IdentifierName.get(nil, :case)
    ID_DEFAULT = IdentifierName.get(nil, :default)

  end
end
