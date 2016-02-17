# coding: utf-8
require 'set'
module Minjs
  module ECMA262
    # Base class of ECMA262 Literal
    class Literal < Base
      #true if literal is white space
      def ws?
        false
      end

      #true if literal is line terminator
      def lt?
        false
      end

      # Returns this node has side effect or not.
      # @return [Boolean]
      def side_effect?
        true
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_PRIMARY
      end
    end

    # Class of psedo element.
    #
    # This class means element is division punctuator or regular expression literal,
    # but lexical parser cannot determine which of them.
    #
    class DivOrRegexpLiteral < Literal
      # Traverses this children and itself with given block.
      #
      # @see Base#traverse
      def traverse(parent, &block)
      end

      # compare object
      def ==(obj)
        self.class == obj.class and self.val == obj.val
      end

      @@instance = self.new()

      # get instance
      def self.get
        @@instance
      end
      private_class_method :new
    end

    # DivOrRegexpLiteral
    LIT_DIV_OR_REGEXP_LITERAL = DivOrRegexpLiteral.get

    # Class of ECMA262 WhiteSpace element
    #
    # Every WhiteSpace characters in source elements is
    # converted to this class object.
    #
    # This class is singleton and representation string is \u0020.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.2
    class WhiteSpace < Literal
      # Traverses this children and itself with given block.
      #
      # @see Base#traverse
      def traverse(parent, &block)
      end

      #true if literal is white space
      def ws?
        true
      end

      # compare object
      def ==(obj)
        self.class == obj.class
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        " "
      end

      @@instance = self.new()

      # get instance
      def self.get
        @@instance
      end
      private_class_method :new
    end

    # Class of ECMA262 LineTerminator element
    #
    # Every LineTerminator characters in source elements is
    # converted to this class object.
    #
    # This class is singleton and representation string is \u000A.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.3
    class LineTerminator < Literal
      # Traverses this children and itself with given block.
      #
      # @see Base#traverse
      def traverse(parent, &block)
      end

      #true if literal is line terminator
      def lt?
        true
      end

      # compare object
      def ==(obj)
        self.class == obj.class
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        "\n"
      end

      @@instance = self.new()

      # get instance
      def self.get
        @@instance
      end
      private_class_method :new
    end

    # line feed ("\n") element
    LIT_LINE_TERMINATOR = LineTerminator.get

    # Class of ECMA262 'this' element
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.1.1
    class This < Literal
      def initialize
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new
      end

      # Traverses this children and itself with given block.
      #
      # @see Base#traverse
      def traverse(parent, &block)
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        "this"
      end

      # @return [Boolean] true if expression is kind of LeftHandSideExpression.
      def left_hand_side_exp?
        true
      end
    end

    # Class of ECMA262 Null element
    #
    # Every Null literal in source elements is
    # converted to this class object.
    #
    # This class is singleton
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.8.1
    class Null < Literal
      def initialize(val)
        @val = :null
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self #not dup
      end

      # Traverses this children and itself with given block.
      #
      # @see Base#traverse
      def traverse(parent, &block)
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        "null"
      end

      # @return [Boolean] true if expression is kind of LeftHandSideExpression.
      def left_hand_side_exp?
        true
      end

      @@instance = self.new(nil)

      # get instance
      def self.get
        @@instance
      end

      # Returns results of ToBoolean()
      #
      # Returns _true_ or _false_ if trivial,
      # otherwise nil.
      #
      # @return [Boolean]
      #
      # @see http://www.ecma-international.org/ecma-262 ECMA262 9.2
      def to_ecma262_boolean
        false
      end

      # Returns results of ToString()
      #
      # Returns string if value is trivial,
      # otherwise nil.
      #
      # @return [Numeric]
      #
      # @see http://www.ecma-international.org/ecma-262 ECMA262 9.8
      def to_ecma262_string
        "null"
      end

      # Returns results of ToNumber()
      #
      # Returns number if value is trivial,
      # otherwise nil.
      #
      # @return [Numeric]
      #
      # @see http://www.ecma-international.org/ecma-262 ECMA262 9.3
      def to_ecma262_number
        0
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :boolean
      def ecma262_typeof
        :boolean
      end
      private_class_method :new
    end

    # Class of ECMA262 Boolean element
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.8.2
    class Boolean < Literal
      attr_reader :val

      def initialize(val)
        if val.to_s == "true"
          @val = :"true"
        else
          @val = :"false"
        end
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self #//not dup
      end

      # Traverses this children and itself with given block.
      #
      # @see Base#traverse
      def traverse(parent, &block)
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and
          @val == obj.val
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        @val.to_s
      end

      # @return [Boolean] true if expression is kind of LeftHandSideExpression.
      def left_hand_side_exp?
        true
      end

      def true?
        @val == :true
      end

      # Returns results of ToString()
      #
      # Returns string if value is trivial,
      # otherwise nil.
      #
      # @return [Numeric]
      #
      # @see http://www.ecma-international.org/ecma-262 ECMA262 9.8
      def to_ecma262_string
        if @val == :false
          "false"
        else
          "true"
        end
      end

      # Returns results of ToBoolean()
      #
      # Returns _true_ or _false_ if trivial,
      # otherwise nil.
      #
      # @return [Boolean]
      #
      # @see http://www.ecma-international.org/ecma-262 ECMA262 9.2
      def to_ecma262_boolean
        if @val == :false
          false
        else
          true
        end
      end

      # Returns results of ToNumber()
      #
      # Returns number if value is trivial,
      # otherwise nil.
      #
      # @return [Numeric]
      #
      # @see http://www.ecma-international.org/ecma-262 ECMA262 9.3
      def to_ecma262_number
        if @val == :false
          0
        else
          1
        end
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :boolean
      def ecma262_typeof
        :boolean
      end

      @@true = self.new(:true)
      @@false = self.new(:false)

      # get instance
      def self.get(val)
        if val.to_sym == :true || val == true
          @@true
        else
          @@false
        end
      end
    end
    # *true* literal
    LITERAL_TRUE = Boolean.new(:true)
    # *false* literal
    LITERAL_FALSE = Boolean.new(:false)
    Boolean.class_eval {
      private_class_method :new
    }

    # Class of ECMA262 String element
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.8.4
    class ECMA262String < Literal
      include Ctype
      attr_reader :val

      def initialize(val)
        @val = val
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@val)
      end

      # Traverses this children and itself with given block.
      #
      # @see Base#traverse
      def traverse(parent)
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and @val == obj.val
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        dq = @val.to_s.each_codepoint.select{|x| x == 0x22}.length
        sq = @val.to_s.each_codepoint.select{|x| x == 0x27}.length
        if dq <= sq
          t = "\"".dup
        else
          t = "\'".dup
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

      # @return [Boolean] true if expression is kind of LeftHandSideExpression.
      def left_hand_side_exp?
        true
      end

      # Returns results of ToBoolean()
      #
      # Returns _true_ or _false_ if trivial,
      # otherwise nil.
      #
      # @return [Boolean]
      #
      # @see http://www.ecma-international.org/ecma-262 ECMA262 9.2
      def to_ecma262_boolean
        if @val.length == 0
          false
        else
          true
        end
      end

      # Returns results of ToString()
      #
      # Returns string if value is trivial,
      # otherwise nil.
      #
      # @return [Numeric]
      #
      # @see http://www.ecma-international.org/ecma-262 ECMA262 9.8
      def to_ecma262_string
        @val.dup
      end
      # Returns results of ToNumber()
      #
      # Returns number if value is trivial,
      # otherwise nil.
      #
      # @return [Numeric]
      #
      # @see http://www.ecma-international.org/ecma-262 ECMA262 9.3
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

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :string
      def ecma262_typeof
        :string
      end

      # Returns this node has side effect or not.
      # @return [Boolean]
      def side_effect?
        return false
      end
    end

    # Class of ECMA262 Numeric element
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
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.8.3
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

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@number)
      end

      # Traverses this children and itself with given block.
      #
      # @see Base#traverse
      def traverse(parent, &block)
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and self.to_ecma262_string == obj.to_ecma262_string
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
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

      # @return [Boolean] true if expression is kind of LeftHandSideExpression.
      def left_hand_side_exp?
        true
      end

      # to integer
      def to_i
        to_ecma262_string.to_i
      end

      # to float
      def to_f
        to_ecma262_string.to_f
      end

      # True if number is NaN
      def nan?
        @number.kind_of? Float and @number.nan?
      end

      # True if number is Infinity
      def infinity?
        @number == Float::INFINITY || @number == -Float::INFINITY
      end

      # True if number not Infinity nor NaN
      def number?
        !nan? and !infinity?
      end

      # Returns results of ToString()
      #
      # Returns string if value is trivial,
      # otherwise nil.
      #
      # @return [Numeric]
      #
      # @see http://www.ecma-international.org/ecma-262 ECMA262 9.8
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

      # Returns results of ToBoolean()
      #
      # Returns _true_ or _false_ if value is trivial,
      # otherwise nil.
      #
      # @return [Boolean]
      #
      # @see http://www.ecma-international.org/ecma-262 ECMA262 9.2
      def to_ecma262_boolean
        if @val == :nan or to_ecma262_string == "0"
          false
        else
          true
        end
      end

      # Returns this node has side effect or not.
      # @return [Boolean]
      def side_effect?
        return false
      end

      # Returns results of ToNumber()
      #
      # Returns number if value is trivial,
      # otherwise nil.
      #
      # @return [Numeric]
      #
      # @see http://www.ecma-international.org/ecma-262 ECMA262 9.3
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

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :number
      def ecma262_typeof
        :number
      end

#      def ecma262_eval(type)
#        case type
#        when :boolean
#          to_ecma262_boolean
#        else
#          nil
#        end
#      end
    end

    #NaN element
    NUMERIC_NAN = ECMA262Numeric.new(:nan)

    # Class of ECMA262 RegExp element
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.8.5
    class ECMA262RegExp < Literal
      attr_reader :body, :flags

      def initialize(body, flags)
        @body = body
        @flags = flags
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@body, @flags)
      end

      # Traverses this children and itself with given block.
      #
      # @see Base#traverse
      def traverse(parent)
        yield parent, self
      end

      # Returns results of ToBoolean()
      #
      # Returns _true_ or _false_ if trivial,
      # otherwise nil.
      #
      # @return [Boolean]
      #
      # @see http://www.ecma-international.org/ecma-262 ECMA262 9.2
      def to_ecma262_boolean
        true
      end

      # compare object
      def ==(obj)
        self.class == obj.class and @body == obj.body and @flags == obj.flags
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        "/#{@body}/#{@flags}"
      end

      # @return [Boolean] true if expression is kind of LeftHandSideExpression.
      def left_hand_side_exp?
        true
      end
    end

    # Class of ECMA262 Array element
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.1.4
    class ECMA262Array < Literal
      attr_reader :val

      def initialize(val)
        @val = val # val is Array
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@val.collect{|x| x ? x.deep_dup : nil})
      end

      # Traverses this children and itself with given block.
      #
      # @see Base#traverse
      def traverse(parent, &block)
        yield parent, self
        @val.each do |k|
          k.traverse(parent, &block) if k
        end
      end

      # compare object
      def ==(obj)
        self.class == obj.class and @val == obj.val
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        "[" + @val.collect{|x| x ? x.to_js : ""}.join(",") + "]"
      end

      # @return [Boolean] true if expression is kind of LeftHandSideExpression.
      def left_hand_side_exp?
        true
      end

      # Returns results of ToBoolean()
      #
      # Returns _true_ or _false_ if trivial,
      # otherwise nil.
      #
      # @return [Boolean]
      #
      # @see http://www.ecma-international.org/ecma-262 ECMA262 9.2
      def to_ecma262_boolean
        true
      end
    end

    # Class of ECMA262 Array element
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.1.5
    class ECMA262Object < Literal
      include Ctype
      attr_reader :val

      #val is tupple [[k,v],[k,v],...]
      def initialize(val)
        @val = val
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@val.collect{|x, y| [x.deep_dup, y ? y.deep_dup : y]})
      end

      # Traverses this children and itself with given block.
      #
      # @see Base#traverse
      def traverse(parent, &block)
        yield parent, self
        @val.each do |k, v|
          k.traverse(parent, &block)
          v.traverse(parent, &block)
        end
      end

      # compare object
      def ==(obj)
        self.class == obj.class and @val == obj.val
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
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

      # @return [Boolean] true if expression is kind of LeftHandSideExpression.
      def left_hand_side_exp?
        true
      end

      # Returns results of ToBoolean()
      #
      # Returns _true_ or _false_ if trivial,
      # otherwise nil.
      #
      # @return [Boolean]
      #
      # @see http://www.ecma-international.org/ecma-262 ECMA262 9.2
      def to_ecma262_boolean
        true
      end
    end

    # Class of ECMA262 SingleLineComment Element
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.4
    class SingleLineComment < Literal
      def initialize(comment)
        @comment = comment
      end

      # Traverses this children and itself with given block.
      #
      # @see Base#traverse
      def traverse(parent, &block)
      end

      # compare object
      def ==(obj)
        self.class == obj.class and
          @comment == obj.comment
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options)
        "//#{@comment}"
      end

      #true if literal is white space
      def ws?
        true
      end
    end

    # Class of ECMA262 MultiLineComment Element
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.4
    class MultiLineComment < Literal
      attr_reader :comment, :has_lf
      include Ctype

      def initialize(comment)
        @comment = comment
      end

      # Traverses this children and itself with given block.
      #
      # @see Base#traverse
      def traverse(parent, &block)
      end

      # compare object
      def ==(obj)
        self.class == obj.class and @comment == obj.comment
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options)
        "/*#{@comment}*/"
      end

      #true if literal is white space
      def ws?
        !lt?
      end

      #true if literal is line terminator
      #
      # If MultiLineComment has one more LineTerminator,
      # This comment is kind of line terminator.
      # otherwise, this comment is kind of white space.
      def lt?
        @comment.codepoints.each{|char|
          return true if line_terminator?(char)
        }
        false
      end
    end

    # Class of ECMA262 IdentifierName Element
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 7.6
    class IdentifierName < Literal
      attr_accessor :exe_context
      attr_reader :val

      @@sym = {}

      def initialize(val)
        @val = val.to_sym
      end

      # get instance
      def self.get(val)
        if reserved?(val)
          @@sym[val] ||= self.new(val)
        else
          self.new(val)
        end
      end

      # reserved word list
      #
      # @see http://www.ecma-international.org/ecma-262 ECMA262 7.6.1
      RESERVED_WORD = Set.new [
        #keywords
        :break, :do, :instanceof, :typeof,
        :case, :else, :new, :var,
        :catch, :finally, :return, :void,
        :continue, :for, :switch, :while,
        :debugger, :function, :this, :with,
        :default, :if, :throw,
        :delete, :in, :try,
        #future reserved words
        :class, :enum, :extends, :super,
        :const, :export, :import,
        #future reserved words(strict mode) (TODO)
        #:implements, :let, :private, :public, :yield,
        #:interface, :package, :protected, :static,
        :null, :false, :true
      ]

      # Returns true if this literal is reserved word.
      def reserved?
        RESERVED_WORD.include?(val)
      end

      # Returns true if *val* is reserved word.
      # @param val [String] value
      def self.reserved?(val)
        RESERVED_WORD.include?(val)
      end

      # Traverses this children and itself with given block.
      #
      # @see Base#traverse
      def traverse(parent)
        yield parent, self
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@val)
      end

      # compare object
      def ==(obj)
        self.class == obj.class and self.val == obj.val
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        val.to_s
      end

      def to_s
        val.to_s
      end

      # @return [Boolean] true if expression is kind of LeftHandSideExpression.
      def left_hand_side_exp?
        true
      end

      # @return [EnvRecord] binding environment
      def binding_env(lex_env)
        return nil if lex_env.nil?
        v = lex_env

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

    # reserved word "this"
    ID_THIS = IdentifierName.get(:this)
    # reserved word "var"
    ID_VAR = IdentifierName.get(:var)
    # reserved word "in"
    ID_IN = IdentifierName.get(:in)
    # reserved word "instanceof"
    ID_INSTANCEOF = IdentifierName.get(:instanceof)
    # reserved word "function"
    ID_FUNCTION = IdentifierName.get(:function)
    # reserved word "null"
    ID_NULL = IdentifierName.get(:null)
    # reserved word "true"
    ID_TRUE = IdentifierName.get(:true)
    # reserved word "false"
    ID_FALSE = IdentifierName.get(:false)
    # reserved word "new"
    ID_NEW = IdentifierName.get(:new)
    # reserved word "delete"
    ID_DELETE = IdentifierName.get(:delete)
    # reserved word "void"
    ID_VOID = IdentifierName.get(:void)
    # reserved word "typeof"
    ID_TYPEOF = IdentifierName.get(:typeof)
    # reserved word "if"
    ID_IF = IdentifierName.get(:if)
    # reserved word "else"
    ID_ELSE = IdentifierName.get(:else)
    # reserved word "for"
    ID_FOR = IdentifierName.get(:for)
    # reserved word "while"
    ID_WHILE = IdentifierName.get(:while)
    # reserved word "do"
    ID_DO = IdentifierName.get(:do)
    # reserved word "continue"
    ID_CONTINUE = IdentifierName.get(:continue)
    # reserved word "break"
    ID_BREAK = IdentifierName.get(:break)
    # reserved word "return"
    ID_RETURN = IdentifierName.get(:return)
    # reserved word "with"
    ID_WITH = IdentifierName.get(:with)
    # reserved word "switch"
    ID_SWITCH = IdentifierName.get(:switch)
    # reserved word "throw"
    ID_THROW = IdentifierName.get(:throw)
    # reserved word "try"
    ID_TRY = IdentifierName.get(:try)
    # reserved word "catch"
    ID_CATCH = IdentifierName.get(:catch)
    # reserved word "finally"
    ID_FINALLY = IdentifierName.get(:finally)
    # reserved word "debugger"
    ID_DEBUGGER = IdentifierName.get(:debugger)
    # reserved word "case"
    ID_CASE = IdentifierName.get(:case)
    # reserved word "default"
    ID_DEFAULT = IdentifierName.get(:default)
    # get (non-reserved word)
    ID_GET = IdentifierName.get(:get)
    # set (non-reserved word)
    ID_SET = IdentifierName.get(:set)

  end
end
