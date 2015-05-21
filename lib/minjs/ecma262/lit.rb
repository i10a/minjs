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

      def to_ecma262_boolean
        if @val == :false
          false
        else
          true
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

      def to_ecma262_boolean
        if @val.length == 0
          false
        else
          true
        end
      end

      def ecma262_typeof
        :string
      end
    end

    class ECMA262Numeric < Literal
      attr_reader :integer, :decimal, :exp

      def initialize(integer, decimal = nil, exp = nil)
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
          if exp
            @exp = exp.to_i
          end
        end
        @decimal = nil if @decimal == 0
      end

      def deep_dup
        self.class.new(@integer, @decimal, @exp)
      end

      def traverse(parent, &block)
        yield self, parent
      end

      def ==(obj)
        self.class == obj.class and self.to_ecma262_string == obj.to_ecma262_string
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
        d = @decimal
        if d.to_s == ''
          d = '0'
        end
        "#{@integer}.#{d}e#{@exp}".to_f
      end

      #
      # 9.8.1
      #
      def to_ecma262_string
        if @nan
          "NaN"
        elsif @integer == '0' and @decimal.nil? and @exp.nil?
          "0"
        elsif @intinify
          "Infinity"
        else
          f = to_f.to_s
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
        "{" + @val.collect{|x, y|
          if y.kind_of? StFunc and (y.getter? || y.setter?)
            if y.name.val == :get
              t = "get #{x.val.to_s}(){#{y.statements.to_js(options)}}"
            else
              t = "set #{x.val.to_s}(#{y.args[0].to_js(options)}){#{y.statements.to_js(options)}}"
            end
          else
            if x.kind_of? ECMA262Numeric
              a = "#{x.to_ecma262_string}"
              b = "#{x.to_js}"
              if a.length <= b.length || a == "Infinity"
                t = a
              else
                t = b
              end
            elsif idname?(x.val.to_s)
              t = "#{x.val.to_s}"
            else
              t = "#{x.to_js(options)}"
            end
            t << ":#{y.to_js(options)}"
          end
        }.join(",") + "}"
      end
      def to_ecma262_boolean
        true
      end
#      def ecma262_eval(type)
#
#        case type
#        when :boolean
#          to_ecma262_boolean
#        else
#          nil
#        end
#      end
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

      def initialize(comment, has_lf)
        @comment = comment
        @has_lf = has_lf
      end

      def traverse(parent, &block)
      end

      def ==(obj)
        self.class == obj.class and
          @comment == obj.comment and
          @has_lf == obj.has_lf
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
      attr_reader :val

      @@sym = {}

      def initialize(context, val)
        @context = context
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
    ID_GET = IdentifierName.get(nil, :get)
    ID_SET = IdentifierName.get(nil, :set)
    ID_CASE = IdentifierName.get(nil, :case)
    ID_DEFAULT = IdentifierName.get(nil, :default)

  end
end
