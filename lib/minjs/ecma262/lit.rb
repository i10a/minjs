# coding: utf-8
require 'set'
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

      def priority
        PRIORITY_PRIMARY
      end
    end

    class DivOrRegexpLiteral < Literal
      def traverse(parent, &block)
      end

      def ==(obj)
        self.class == obj.class and self.val == obj.val
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

      def ==(obj)
        self.class == obj.class
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

      def ==(obj)
        self.class == obj.class
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

      def deep_dup
        self #not dup
      end

      def traverse(parent, &block)
        yield self, parent
      end

      def to_s
        "null"
      end

      def ==(obj)
        self.class == obj.class
      end

      def to_js(options = {})
        "null"
      end

      @@instance = self.new(nil)
      def self.get
        @@instance
      end

      def to_ecma262_boolean
        false
      end

      def to_ecma262_string
        "null"
      end

      def to_ecma262_number
        0
      end

      def ecma262_typeof
        :boolean
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

      def deep_dup
        self #//not dup
      end

      def traverse(parent, &block)
        yield self, parent
      end

      def ==(obj)
        self.class == obj.class and
          @val == obj.val
      end

      def to_js(options = {})
        @val.to_s
      end

      def true?
        @val == :true
      end

      def to_ecma262_string
        if @val == :false
          "false"
        else
          "true"
        end
      end

      def to_ecma262_boolean
        if @val == :false
          false
        else
          true
        end
      end

      def to_ecma262_number
        if @val == :false
          0
        else
          1
        end
      end

      def ecma262_typeof
        :boolean
      end

      @@true = self.new(:true)
      @@false = self.new(:false)
      def self.get(val)
        if val.to_sym == :true || val == true
          @@true
        else
          @@false
        end
      end
    end

    class ECMA262String < Literal
      include Ctype
      attr_reader :val

      def initialize(val)
        @val = val
      end

      def deep_dup
        self.class.new(@val)
      end

      def traverse(parent)
        yield self, parent
      end

      def ==(obj)
        self.class == obj.class and @val == obj.val
      end

      def to_js(options = {})
        dq = @val.to_s.each_codepoint.select{|x| x == 0x22}.length
        sq = @val.to_s.each_codepoint.select{|x| x == 0x27}.length
        if dq <= sq
          t = "\""
        else
          t = "\'"
        end

        @val.to_s.each_codepoint do |c|
          if c == 0x5c
            t << ('\\\\')
          elsif c == 0x22 and dq <= sq
            t << ('\"')
          elsif c == 0x27 and dq > sq
            t << ('\\\'')
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
        if dq <= sq
          t << "\""
        else
          t << "\'"
        end
      end

      def to_ecma262_boolean
        if @val.length == 0
          false
        else
          true
        end
      end

      def to_ecma262_string
        @val.dup
      end
      # 9.3.1 ToNumber Applied to the String Type
      def to_ecma262_number
        begin
          pos1 = pos0 = pos = 0
          v = @val.codepoints
          while true
            return 0 if v[pos].nil? # ToInteger(empty string) => 0
            if white_space?(v[pos]) or line_terminator?(v[pos])
              pos += 1
            else
              break
            end
          end
          #hex
          if v[pos] == 0x30 and (v[pos+1] == 0x78 || v[pos+1] == 0x58) and hex_digit?(v[pos+2])
            base = 16
            pos += 2
            pos0 = pos
            while true
              break if v[pos].nil?
              if hex_digit?(v[pos])
                pos += 1
              else
                break
              end
            end
          #decimal
          else
            base = 10
            sign = 1
            pos0 = pos
            if v[pos].nil?
              raise :error
            elsif v[pos] == 0x2b #+
              pos += 1
            elsif v[pos] == 0x2d #-
              sign = -1
              pos += 1
            end
            has_decimal = false
            has_exp = false

            while true
              break if v[pos].nil?
              if v[pos] >= 0x30 and v[pos] <= 0x39
                pos += 1
              elsif v[pos] == 0x2e #.
                pos += 1
                has_decimal = true
                break;
              else
                break
              end
            end
            if has_decimal
              while true
                break if v[pos].nil?
                if v[pos] >= 0x30 and v[pos] <= 0x39
                  pos += 1
                elsif v[pos] == 0x45 or v[pos] == 0x65 #E/e
                  pos += 1
                  has_exp = true
                  break;
                else
                  break
                end
              end
            end
            if has_exp
              if v[pos] == 0x2b #+
                pos += 1
              else v[pos] == 0x2d #-
                pos += 1
              end
              while true
                break if v[pos].nil?
                if v[pos] >= 0x30 and v[pos] <= 0x39
                  pos += 1
                else
                  break
                end
              end
            end
          end
          pos1 = pos
          while white_space?(v[pos]) or line_terminator?(v[pos])
            raise :error if v[pos].nil?
            pos += 1
          end
          raise :error unless v[pos].nil?
          if base == 16
            ret = v[pos0...pos1].pack("U*").to_i(base)
          else
            ret = v[pos0...pos1].pack("U*").to_f
          end
        rescue => e
          ret = nil #Float::NAN
        end
        ret
      end

      def ecma262_typeof
        :string
      end
    end

    #
    # 8.5 The Number Type
    #
    # ECMA262 say:
    #
    # The Number type has exactly 18437736874454810627
    # (that is, 264−253+3) values, representing the
    # double-precision 64-bit format IEEE 754 values
    # as specified in the IEEE Standard for Binary
    # Floating-Point Arithmetic
    #
    # To simplify the implementation,
    # Minjs assumes that ruby has IEEE754 dobule precision.
    #
    class ECMA262Numeric < Literal
      attr_reader :integer, :decimal, :exp, :number

      if Float::DIG != 15
        if defined?(@logger)
          @logger.warn{
            "minjs assumes that ruby has IEEE754 dobule precision."
          }
        end
      end

      def initialize(integer, decimal = nil, exp = nil)
        if integer == :nan or integer == "NaN"
          @number = Float::NAN
          @integer = "NaN"
          @decimal = nil
          @exp = nil
        elsif integer == :infinity or integer == Float::INFINITY or integer == "Infinity"
          @number = Float::INFINITY
          @integer = "Infinity"
          @decimal = nil
          @exp = nil
        elsif integer == -Float::INFINITY or integer == "-Infinity"
          @number = -Float::INFINITY
          @integer = "-Infinity"
          @decimal = nil
          @exp = nil
        elsif integer.kind_of? String
          @integer = integer.to_s #String
          @decimal = decimal.to_s #String
          @exp = exp ? exp.to_i : nil
          if @decimal == ""
            d = ""
          else
            d = ".#{@decimal}"
          end
          if @exp
            @number = "#{integer}#{d}e#{exp}".to_f
          else
            @number = "#{integer}#{d}".to_f
          end
          if @number.kind_of? Float and @number.nan?
            @integer = "NaN"
            @decimal = nil
            @exp = nil
          elsif @number == Float::INFINITY
            @integer = "Infinity"
            @decimal = nil
            @exp = nil
          elsif @number == -Float::INFINITY
            @integer = "-Infinity"
            @decimal = nil
            @exp = nil
          end
        elsif integer.kind_of? Numeric
          if integer.kind_of? Float and integer.nan?
            @number = Float::NAN
            @decimal = nil
            @exp = nil
          elsif integer == Float::INFINITY
            @number = Float::INFINITY
            @decimal = nil
            @exp = nil
          elsif integer == -Float::INFINITY
            @number = -Float::INFINITY
            @decimal = nil
            @exp = nil
          else
            @number = integer
            @integer = @number.to_i.to_s
            @decimal = (@number - @integer.to_i).to_s.sub(/0\.?/, '')
            @exp = nil
          end
        else
          raise 'internal error'
        end
      end

      def deep_dup
        self.class.new(@number)
      end

      def traverse(parent, &block)
        yield self, parent
      end

      def ==(obj)
        self.class == obj.class and self.to_ecma262_string == obj.to_ecma262_string
      end

      def to_js(options = {})
        if nan?
          return "NaN"
        elsif @number == Float::INFINITY
          return "Infinity"
        elsif @number == -Float::INFINITY
          return "-Infinity"
        end
        t0 = to_ecma262_string
        t0.sub!(/^0\./, '.')

        t = @integer.nil? ? "" : @integer.dup.to_s

        d = @decimal.to_s
        if d == '0'
          d = ''
        end
        if d.length > 0
          if @integer == '0'
            t = ".#{d}"
          else
            t << ".#{d}"
          end
        end
        if @exp
          t << "e#{@exp}"
        end

        if !t.match(/e/) and !t.match(/\./) and t.match(/0{3,}$/)
          len = $&.length
          t.sub!(/0+$/, "e#{len}")
        end
        t.sub!(/e\+/, 'e')
        t0.sub!(/e\+/, 'e')

        t.length <= t0.length ? t : t0
      end

      def to_i
        to_ecma262_string.to_i
      end

      def to_f
        to_ecma262_string.to_f
      end

      def nan?
        @number.kind_of? Float and @number.nan?
      end

      def infinity?
        @number == Float::INFINITY || @number == -Float::INFINITY
      end

      def number?
        !nan? and !infinity?
      end

      #
      # 9.8.1
      #
      def to_ecma262_string
        if nan?
          "NaN"
        elsif @number == Float::INFINITY
          "Infinity"
        elsif @number == -Float::INFINITY
          "-Infinity"
        elsif @integer == '0' and @decimal.nil? and @exp.nil?
          "0"
        else
          f = @number.to_f.to_s
          _n, _e = f.split('e')
          _i, _d = _n.split('.')

          e = _e.to_i
          if(e == 0)
            if _d.to_i != 0
              return _n
            else
              return _i
            end
          elsif(e > 0 && e < 21)
            _n = _i + _d
            _n += '0' * (21 - _n.length)
            return _n
          elsif(e < 0 && e >= -6)
            _n = "0." + ('0' * (-e-1)) + _i + _d
            return _n
          else
            if e<0
              return "#{_i}.#{_d}e#{e}"
            else
              return "#{_i}.#{_d}e+#{e}"
            end
          end
        end
      end

      def to_ecma262_boolean
        if @val == :nan or to_ecma262_string == "0"
          false
        else
          true
        end
      end

      def to_ecma262_number
        if nan?
          nil
        elsif @number == Float::INFINITY
          nil
        elsif @number == -Float::INFINITY
          nil
        else
          @number
        end
      end

      def ecma262_typeof
        :number
      end

      def ecma262_eval(type)
        case type
        when :boolean
          to_ecma262_boolean
        else
          nil
        end
      end
    end
    NUMERIC_NAN = ECMA262Numeric.new(:nan)

    class ECMA262RegExp < Literal
      attr_reader :body, :flags

      def initialize(body, flags)
        @body = body
        @flags = flags
      end

      def deep_dup
        self.class.new(@body, @flags)
      end

      def traverse(parent)
        yield self, parent
      end

      def to_ecma262_boolean
        true
      end

      def ==(obj)
        self.class == obj.class and @body == obj.body and @flags == obj.flags
      end

      def to_js(options = {})
        "/#{@body}/#{@flags}"
      end
    end

    LITERAL_TRUE = Boolean.new(:true)
    LITERAL_FALSE = Boolean.new(:false)

    class ECMA262Array < Literal
      attr_reader :val

      def initialize(val)
        @val = val # val is Array
      end

      def deep_dup
        self.class.new(@val.collect{|x| x ? x.deep_dup : nil})
      end

      def traverse(parent, &block)
        yield self, parent
        @val.each do |k|
          k.traverse(parent, &block) if k
        end
      end

      def ==(obj)
        self.class == obj.class and @val == obj.val
      end

      def to_js(options = {})
        "[" + @val.collect{|x| x.to_s}.join(",") + "]"
      end
      def to_ecma262_boolean
        true
      end
    end

    class ECMA262Object < Literal
      include Ctype
      attr_reader :val

      #val is tupple [[k,v],[k,v],...]
      def initialize(val)
        @val = val
      end

      def deep_dup
        self.class.new(@val.collect{|x, y| [x.deep_dup, y ? y.deep_dup : y]})
      end

      def traverse(parent, &block)
        yield self, parent
        @val.each do |k, v|
          k.traverse(parent, &block)
          v.traverse(parent, &block)
        end
      end

      def ==(obj)
        self.class == obj.class and @val == obj.val
      end

      def to_js(options = {})
        concat(options, "{" + @val.collect{|x, y|
                 if y.kind_of? StFunc and (y.getter? || y.setter?)
                   if y.name.val == :get
                     t = concat options, "get", x.val, "()", "{", y.statements, "}"
                   else
                     t = concat options, "set", x.val, "(", y.args[0], ")", "{", y.statements, "}"
                   end
                 else
                   if x.kind_of? ECMA262Numeric
                     t = concat options, x.to_ecma262_string, ":", y
                   elsif idname?(x.val.to_s)
                     t = concat options, x.val, ":", y
                   else
                     t = concat options, x, ":", y
                   end
                 end
               }.join(","), "}")
      end
      def to_ecma262_boolean
        true
      end
    end

    class SingleLineComment < Literal
      def initialize(comment)
        @comment = comment
      end

      def traverse(parent, &block)
      end

      def ==(obj)
        self.class == obj.class and
          @comment == obj.comment
      end

      def to_js(options)
        "//#{@comment}"
      end

      def ws?
        true
      end
    end

    class MultiLineComment < Literal
      attr_reader :comment, :has_lf
      include Ctype

      def initialize(comment)
        @comment = comment
      end

      def traverse(parent, &block)
      end

      def ==(obj)
        self.class == obj.class and @comment == obj.comment
      end

      def to_js(options)
        "/*#{@comment}*/"
      end

      def ws?
        !lt?
      end

      def lt?
        @comment.codepoints.each{|char|
          return true if line_terminator?(char)
        }
        false
      end
    end

    class IdentifierName < Literal
      attr_accessor :context
      attr_reader :val

      @@sym = {}

      def initialize(context, val)
        @context = context
        @val = val.to_sym
      end

      def self.get(context, val)
        if reserved?(val)
          @@sym[val] ||= self.new(context, val)
        else
          self.new(context, val)
        end
      end

      RESERVED_WORD = Set.new [
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
        RESERVED_WORD.include?(val)
      end

      def self.reserved?(val)
        RESERVED_WORD.include?(val)
      end

      def traverse(parent)
        yield self, parent
      end

      def deep_dup
        self.class.new(@context, @val)
      end

      def ==(obj)
        self.class == obj.class and self.val == obj.val
      end

      def to_js(options = {})
        val.to_s
      end

      def binding_env(type = :var)
        return nil if context.nil?
        if type == :var
          v = context.var_env
        else
          v = context.lex_env
        end

        while v
          if v.record.binding[val]
            return v
          else
            v = v.outer
          end
        end
        nil
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
    ID_CASE = IdentifierName.get(nil, :case)
    ID_DEFAULT = IdentifierName.get(nil, :default)
    # Note: get and set are not reserved word
    ID_GET = IdentifierName.get(nil, :get)
    ID_SET = IdentifierName.get(nil, :set)

  end
end
