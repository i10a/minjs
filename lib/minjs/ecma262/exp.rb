module Minjs
  module ECMA262
    PRIORITY_PRIMARY = 10
    PRIORITY_LEFT_HAND_SIDE = 20
    PRIORITY_POSTFIX = 30
    PRIORITY_UNARY = 40
    PRIORITY_MULTIPLICATIVE = 50
    PRIORITY_ADDITIVE = 60
    PRIORITY_SHIFT = 70
    PRIORITY_RELATIONAL = 80
    PRIORITY_EQUALITY = 90
    PRIORITY_BITWISE_AND = 100
    PRIORITY_BITWISE_XOR = 106
    PRIORITY_BITWISE_OR = 108
    PRIORITY_LOGICAL_AND = 110
    PRIORITY_LOGICAL_OR = 116
    PRIORITY_CONDITIONAL = 120
    PRIORITY_ASSIGNMENT = 130
    PRIORITY_COMMA = 140

    class Exp < Base
      def traverse
        yield(self)
      end

      def to_js(options = {})
        raise "internal error"
      end

      def reduce(parent)
      end

      def priority
        9999
      end

    end

    module BinaryOperation
      def remove_paren
        if @val.kind_of? ExpParen and @val.val.priority <= self.priority
          @val = @val.val if @val.remove_paren?
        end
        if @val2.kind_of? ExpParen and @val2.val.priority < self.priority
          @val2 = @val2.val
        end
        self
      end
      def add_paren
        if @val.priority > self.priority
          @val = ExpParen.new(@val)
        end
        if @val2.priority > self.priority
          @val2 = ExpParen.new(@val2)
        end

        self
      end

      def ==(obj)
        self.class == obj.class and self.val == obj.val and self.val2 == obj.val2
      end
    end

    module UnaryOperation
      def remove_paren
        if @val.kind_of? ExpParen and @val.val.priority <= self.priority
          @val = @val.val if @val.remove_paren?
        end
        self
      end

      def add_paren
        if @val.priority > self.priority
          @val = ExpParen.new(@val)
        end

        self
      end

      def ==(obj)
        self.class == obj.class and self.val == obj.val
      end
    end

    module AssignmentOperation
      def remove_paren
        if @val.kind_of? ExpParen and @val.val.priority <= PRIORITY_LEFT_HAND_SIDE
          @val = @val.val if @val.remove_paren?
        end
        if @val2.kind_of? ExpParen and @val2.val.priority <= PRIORITY_ASSIGNMENT
          @val2 = @val2.val
        end
        self
      end

      def add_paren
        if @val.priority > PRIORITY_LEFT_HAND_SIDE
          @val = ExpParen.new(@val)
        end
        if @val2.priority > PRIORITY_ASSIGNMENT
          @val2 = ExpParen.new(@val2)
        end
        self
      end

      def ==(obj)
        self.class == obj.class and self.val == obj.val and self.val2 == obj.val2
      end

      def ecma262_typeof
        if @val2.respond_to? :ecma262_typeof
          @val2.ecma262_typeof
        else
          nil
        end
      end
    end

    class ExpArg1 < Exp
      attr_reader :val

      def initialize(val)
        @val = val
      end

      def deep_dup
        self.class.new(@val.deep_dup)
      end

      def replace(from, to)
        if @val .eql? from
          @val = to
        end
      end

      def traverse(parent, &block)
        @val.traverse(self, &block)
        yield self, parent
      end

      def to_js(options = {})
        concat options, sym, @val
      end
    end

    class ExpArg2 < Exp
      attr_reader :val, :val2

      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      def deep_dup
        self.class.new(@val.deep_dup, @val2.deep_dup)
      end

      def replace(from, to)
        if @val .eql? from
          @val = to
        elsif @val2 .eql? from
          @val2 = to
        end
      end

      def traverse(parent, &block)
        @val.traverse(self, &block)
        @val2.traverse(self, &block)
        yield self, parent
      end

      def to_js(options = {})
        concat options, @val, sym, @val2
      end
    end

    #
    # 11.1 primary expression
    #
    class ExpParen < Exp
      attr_reader :val

      def initialize(val)
        @val = val
      end

      def priority
        PRIORITY_PRIMARY
      end

      def deep_dup
        self.class.new(@val.deep_dup)
      end

      def replace(from, to)
        if @val .eql? from
          @val = to
        end
      end

      def traverse(parent, &block)
        @val.traverse(self, &block)
        yield self, parent
      end

      def ==(obj)
        self.class == obj.class and @val == obj.val
      end

      def to_js(options = {})
        "(#{@val.to_js(options)})"
      end

      def remove_paren?
        js = @val.to_js
        if js.match(/^function/) or js.match(/^{/)
          false
        else
          true
        end
      end

      def remove_paren
        if @val.kind_of? ExpParen
          @val = @val.val if @val.remove_paren?
        end
        self
      end

      def add_paren
        self
      end

      def ecma262_typeof
        if @val.respond_to? :ecma262_typeof
          @val.ecma262_typeof
        else
          nil
        end
      end
    end
    #
    # 11.2 Left-Hand-Side Expressions
    #
    # function expression: see st.rb:StFunc
    #
    # 11.2.1 Property Accessors val[val2]
    #
    class ExpPropBrac < ExpArg2
      def priority
        PRIORITY_LEFT_HAND_SIDE
      end

      def traverse(parent, &block)
        @val.traverse(self, &block)
        @val2.traverse(self, &block)
        yield self, parent
      end

      def ==(obj)
        self.class == obj.class and
          @val == obj.val and
          @val2 == obj.val2
      end

      def to_js(options = {})
        "#{@val.to_js(options)}[#{@val2.to_js(options)}]"
      end

      def remove_paren
        if @val.kind_of? ExpParen and @val.val.priority <= PRIORITY_LEFT_HAND_SIDE
          @val = @val.val if @val.remove_paren?
        end
        if @val2.kind_of? ExpParen
          @val2 = @val2.val
        end
        self
      end

      def add_paren
        if @val.priority > PRIORITY_LEFT_HAND_SIDE
          @val = ExpPare.new(@val)
        end
        self
      end
    end
    #
    # => val.val2
    #
    class ExpProp < ExpArg2
      def initialize(val, val2)
        @val = val
        if val2.kind_of? IdentifierName
          @val2 = ECMA262::ECMA262String.new(val2.val)
        elsif val2.kind_of? ECMA262String
          @val2 = val2
        end
      end

      def priority
        PRIORITY_LEFT_HAND_SIDE
      end

      def traverse(parent, &block)
        @val.traverse(self, &block)
        @val2.traverse(self, &block)
        yield self, parent
      end

      def ==(obj)
        self.class == obj.class and
          @val == obj.val and
          @val2 == obj.val2
      end

      def to_js(options = {})
        "#{@val.to_js(options)}.#{@val2.val}"
      end

      def remove_paren
        if @val.kind_of? ExpParen and @val.val.priority <= PRIORITY_LEFT_HAND_SIDE
          @val = @val.val if @val.remove_paren?
        end
        self
      end

      def add_paren
        if @val.priority > PRIORITY_LEFT_HAND_SIDE
          @val = ExpParen.new(@val)
        end
        self
      end
    end
    #11.2
    #  => name(args)
    #
    class ExpCall < Exp
      attr_reader :name
      attr_reader :args

      def initialize(name, args)
        @name = name
        @args = args
      end

      def priority
        PRIORITY_LEFT_HAND_SIDE
      end

      def deep_dup
        self.class.new(@name.deep_dup,
                       @args ? @args.collect{|x| x.deep_dup} : nil)
      end

      def replace(from, to)
        @args.each_index do |i|
          arg = @args[i]
          if arg .eql? from
            @args[i] = to
            break
          end
        end
      end

      def traverse(parent, &block)
        @name.traverse(self, &block)
        @args.each do |x|
          x.traverse(self, &block)
        end
        yield self, parent
      end

      def ==(obj)
        self.class == obj.class and @name == obj.name and @args == obj.args
      end

      def to_js(options = {})
        args = @args.collect{|x| x.to_js(options)}.join(",")
        "#{@name.to_js(options)}(#{args})"
      end

      def remove_paren
        if @name.kind_of? ExpParen and @name.val.priority <= PRIORITY_LEFT_HAND_SIDE
          @name = @name.val if @name.remove_paren?
        end
        if @args
          @args.map! do |arg|
            if arg.kind_of? ExpParen and arg.val.priority <= PRIORITY_ASSIGNMENT #AssignmentOperators
              arg.val if arg.remove_paren?
            else
              arg
            end
          end
        end
        self
      end

      def add_paren
        if @name.priority > PRIORITY_LEFT_HAND_SIDE
          @name = ExpPare.new(@name)
        end
        if @args
          @args.map! do |arg|
            if arg.priority > PRIORITY_ASSIGNMENT
              ExpParen.new(arg)
            else
              arg
            end
          end
        end
        self
      end

    end

    #
    # new M
    # new M(a,b,c...)
    #
    class ExpNew < Exp
      attr_reader :name, :args

      def initialize(name, args)
        @name = name
        @args = args
      end

      def priority
        PRIORITY_LEFT_HAND_SIDE + ((args == nil) ? 1 : 0)
      end

      def deep_dup
        self.class.new(@name,
                       @args ? @args.collect{|x| x.deep_dup} : nil)
      end

      def replace(from, to)
        if @name .eql? from
          @name = from
        elsif @args .eql? from
          @args = to
        elsif @args and (idx = @args.index(from))
          @args[idx] = to
        end
      end

      def traverse(parent, &block)
        @name.traverse(self, &block)
        if @args
          @args.each do |arg|
            arg.traverse(self, &block)
          end
        end
        yield self, parent
      end

      def ==(obj)
        self.class == obj.class and @name == obj.name and @args == obj.args
      end

      def to_js(options = {})
        #TODO => simple_replacement
        if @args# and @args.length > 0
          args = @args.collect{|x| x.to_js(options)}.join(",")
          concat options, :new, @name, '(', args, ')'
        else
          concat options, :new, @name
        end
      end

      def remove_paren
        if @name.kind_of? ExpParen and @name.val.priority <= PRIORITY_LEFT_HAND_SIDE
          @name = @name.val if @name.remove_paren?
        end
        if @args
          @args.map! do |arg|
            if arg.kind_of? ExpParen and arg.val.priority <= PRIORITY_ASSIGNMENT
              arg.val if arg.remove_paren?
            else
              arg
            end
          end
        end
        self
      end

      def add_paren
        if @name.priority > PRIORITY_LEFT_HAND_SIDE
          @name = ExpParen.new(@name)
        end
        if @args
          @args.map! do |arg|
            if arg.priority > PRIORITY_ASSIGNMENT
              ExpParen.new(arg)
            else
              arg
            end
          end
        end
        self
      end
    end

    #
    # 11.3 Postfix Expressions
    #
    class ExpPostInc < ExpArg1
      include UnaryOperation
      def sym
        "++"
      end

      def priority
        PRIORITY_POSTFIX
      end

      def to_js(options = {})
        concat options, @val, sym
      end
    end
    class ExpPostDec < ExpArg1
      include UnaryOperation
      def sym
        "--"
      end

      def priority
        PRIORITY_POSTFIX
      end

      def to_js(options = {})
        concat options, @val, sym
      end
    end
    #
    # 11.4
    # unary expression
    #
    class ExpDelete < ExpArg1
      include UnaryOperation
      def sym
        "delete"
      end
      def priority
        PRIORITY_UNARY
      end
    end
    class ExpVoid < ExpArg1
      include UnaryOperation

      def sym
        "void"
      end

      def priority
        PRIORITY_UNARY
      end

      def ecma262_typeof
        :undefined
      end

    end
    class ExpTypeof < ExpArg1
      include UnaryOperation
      def sym
        "typeof"
      end
      def priority
        PRIORITY_UNARY
      end

      def ecma262_typeof
        :string
      end
    end

    class ExpPreInc < ExpArg1
      include UnaryOperation
      def sym
        "++"
      end

      def priority
        PRIORITY_UNARY
      end

      def ecma262_typeof
        :number
      end
    end
    class ExpPreDec < ExpArg1
      include UnaryOperation
      def sym
        "--"
      end

      def priority
        PRIORITY_UNARY
      end

      def ecma262_typeof
        :number
      end
    end
    class ExpPositive < ExpArg1
      include UnaryOperation
      def sym
        "+"
      end

      def priority
        PRIORITY_UNARY
      end

      def reduce(parent)
        if @val.kind_of? ECMA262Numeric
          parent.replace(self, @val)
        end
      end

      def ecma262_typeof
        :number
      end
    end

    class ExpNegative < ExpArg1
      include UnaryOperation
      def sym
        "-"
      end

      def priority
        PRIORITY_UNARY
      end

      def reduce(parent)
        if @val.kind_of? ECMA262Numeric
          if @val.integer.match(/^\-/)
            integer = $'
          else
            integer = "-#{@val.integer}"
          end
          val = ECMA262Numeric.new(integer, @val.decimal, @val.exp)
          parent.replace(self, val)
        end
      end

      def ecma262_typeof
        :number
      end
    end

    class ExpBitwiseNot < ExpArg1
      include UnaryOperation
      def sym
        "~"
      end

      def priority
        PRIORITY_UNARY
      end

      def ecma262_typeof
        :number
      end
    end
    class ExpLogicalNot < ExpArg1
      include UnaryOperation
      def sym
        "!"
      end

      def priority
        PRIORITY_UNARY
      end

      #feature
      def reduce(parent)
        if @val.kind_of? ECMA262Numeric and (@val.to_js == "0" || @val.to_js == "1")
          return
        end

        if (e = ecma262_eval(:boolean)) != nil
          if e
            parent.replace(self, ExpLogicalNot.new(ECMA262Numeric.new(0)))
          else
            parent.replace(self, ExpLogicalNot.new(ECMA262Numeric.new(1)))
          end
        elsif @val.kind_of? ExpLogicalNot and
           @val.val.respond_to?(:ecma262_typeof) and
           @val.val.ecma262_typeof == :boolean
            parent.replace(self, @val.val)
        end
      end

      def ecma262_eval(type)
        if @val.respond_to? :ecma262_eval
          e = @val.ecma262_eval(type)
          if e.nil?
            return nil
          else
            return !e
          end
        else
          nil
        end
      end

      def ecma262_typeof
        :boolean
      end
    end
    #
    # 11.5.1 Applying the * Operator
    #
    class ExpMul < ExpArg2
      include BinaryOperation

      def sym
        "*"
      end

      def priority
        PRIORITY_MULTIPLICATIVE
      end

      def swap
        t = @val
        @val = @val2
        @val2 = t
      end

      def reduce(parent)
        # a * 1 => a
        if @val.kind_of? ECMA262Numeric and @val2.kind_of? ECMA262Numeric and @val.to_num == 1
          parent.replace(self, @val2)
        end
        # 1 * b => b
        if @val.kind_of? ECMA262Numeric and @val2.kind_of? ECMA262Numeric and @val2.to_num == 1
          parent.replace(self, @val)
        end
        # N * M => (N * M)
        if @val.kind_of? ECMA262Numeric and @val2.kind_of? ECMA262Numeric and @val.integer? and @val2.integer?
          parent.replace(self, ECMA262Numeric.new(@val.to_num * @val2.to_num))
        end
=begin
        # ((a * N) * M) or ((N * a) * M)
        if @val2.kind_of? ECMA262Numeric and @val2.integer? and @val.kind_of? ExpMul
          if @val.val2.kind_of? ECMA262Numeric and @val.val2.integer?
            @val2 = ECMA262Numeric.new(@val.val2.to_num * @val2.to_num)
            @val = @val.val
          elsif @val.val.kind_of? ECMA262Numeric and @val.val.integer?
            @val2 = ECMA262Numeric.new(@val.val.to_num * @val2.to_num)
            @val = @val.val2
          end
        end
=end
      end

      def ecma262_typeof
        :number
      end
    end

    #
    # 11.5.2 Applying the / Operator
    #
    class ExpDiv < ExpArg2
      include BinaryOperation
      def sym
        "/"
      end
      def priority
        PRIORITY_MULTIPLICATIVE
      end
    end

    #
    # 11.5.3 Applying the % Operator
    #
    class ExpMod < ExpArg2
      include BinaryOperation
      def sym
        "%"
      end

      def priority
        PRIORITY_MULTIPLICATIVE
      end

      def ecma262_typeof
        :number
      end
    end

    #
    #11.6.1 The Addition operator ( + )
    #
    class ExpAdd < ExpArg2
      include BinaryOperation
      def sym
        "+"
      end

      def priority
        PRIORITY_ADDITIVE
      end

      def swap
        t = @val
        @val = @val2
        @val2 = t
      end

      def reduce(parent)
        # a + 0 => a
        if @val.kind_of? ECMA262Numeric and @val2.kind_of? ECMA262Numeric and @val.to_num == 0
          parent.replace(self, @val2)
        end
        # 0 + b => b
        if @val.kind_of? ECMA262Numeric and @val2.kind_of? ECMA262Numeric and @val2.to_num == 0
          parent.replace(self, @val)
        end
        # N + M => (N + M)
        if @val.kind_of? ECMA262Numeric and @val2.kind_of? ECMA262Numeric and @val.integer? and @val2.integer?
          parent.replace(self, ECMA262Numeric.new(@val.to_num + @val2.to_num))
        end
      end
    end
    #
    # 11.6.2 The Subtraction Operator ( - )
    #
    class ExpSub < ExpArg2
      include BinaryOperation

      def sym
        "-"
      end

      def priority
        PRIORITY_ADDITIVE
      end

      def reduce(parent)
        # a - 0 => a
        if @val.kind_of? ECMA262Numeric and @val2.kind_of? ECMA262Numeric and @val.to_num == 0
          parent.replace(self, @val2)
        end
        # 0 - b => b
        if @val2.kind_of? ECMA262Numeric and @val.kind_of? ECMA262Numeric and @val2.to_num == 0
          parent.replace(self, @val)
        end
        # N - M => (N - M)
        if @val.kind_of? ECMA262Numeric and @val2.kind_of? ECMA262Numeric and @val.integer? and @val2.integer?
          parent.replace(self, ECMA262Numeric.new(@val.to_num - @val2.to_num))
        end
      end

      def ecma262_typeof
        :number
      end
    end

    #
    # 11.7.1 The Left Shift Operator ( << )
    #
    class ExpLShift < ExpArg2
      include BinaryOperation
      def sym
        "<<"
      end

      def priority
        PRIORITY_SHIFT
      end

      def ecma262_typeof
        :number
      end
    end
    #
    # 11.7.2 The Signed Right Shift Operator ( >> )
    #
    class ExpRShift < ExpArg2
      include BinaryOperation
      def sym
        ">>"
      end

      def priority
        PRIORITY_SHIFT
      end

      def ecma262_typeof
        :number
      end
    end
    #
    # 11.7.3 The Unsigned Right Shift Operator ( >>> )
    #
    class ExpURShift < ExpArg2
      include BinaryOperation
      def sym
        ">>>"
      end

      def priority
        PRIORITY_SHIFT
      end

      def ecma262_typeof
        :number
      end
    end
    #
    # 11.8.1 The Less-than Operator ( < )
    #
    class ExpLt < ExpArg2
      include BinaryOperation
      def sym
        "<"
      end

      def priority
        PRIORITY_RELATIONAL
      end

      def ecma262_typeof
        :boolean
      end
    end

    #
    # 11.8.2 The Greater-than Operator ( > )
    #
    class ExpGt < ExpArg2
      include BinaryOperation
      def sym
        ">"
      end

      def priority
        PRIORITY_RELATIONAL
      end

      def ecma262_typeof
        :boolean
      end
    end
    #
    # 11.8.3 The Less-than-or-equal Operator ( <= )
    #
    class ExpLtEq < ExpArg2
      include BinaryOperation
      def sym
        "<="
      end

      def priority
        PRIORITY_RELATIONAL
      end

      def ecma262_typeof
        :boolean
      end
    end
    #
    # 11.8.4 The Greater-than-or-equal Operator ( >= )
    #
    class ExpGtEq < ExpArg2
      include BinaryOperation
      def sym
        ">="
      end

      def priority
        PRIORITY_RELATIONAL
      end

      def ecma262_typeof
        :boolean
      end
    end
    #
    # 11.8.6 The instanceof operator
    #
    class ExpInstanceOf < ExpArg2
      include BinaryOperation
      def sym
        "instanceof"
      end

      def priority
        PRIORITY_RELATIONAL
      end

      def ecma262_typeof
        :boolean
      end
    end
    #
    # 11.8.7 The in operator
    #
    class ExpIn < ExpArg2
      include BinaryOperation
      def sym
        "in"
      end

      def priority
        PRIORITY_RELATIONAL
      end

      def ecma262_typeof
        :boolean
      end
    end
    #
    # 11.9.1 The Equals Operator ( == )
    #
    class ExpEq < ExpArg2
      include BinaryOperation
      def sym
        "=="
      end

      def priority
        PRIORITY_EQUALITY
      end

      def ecma262_typeof
        :boolean
      end
    end
    #
    # 11.9.2 The Does-not-equals Operator ( != )
    #
    class ExpNotEq < ExpArg2
      include BinaryOperation
      def sym
        "!="
      end

      def priority
        PRIORITY_EQUALITY
      end

      def ecma262_typeof
        :boolean
      end
    end
    #
    # 11.9.4 The Strict Equals Operator ( === )
    #
    class ExpStrictEq < ExpArg2
      include BinaryOperation
      def sym
        "==="
      end

      def priority
        PRIORITY_EQUALITY
      end

      def reduce(parent)
        if @val.respond_to?(:ecma262_typeof) and @val2.respond_to?(:ecma262_typeof) and
           (t = @val.ecma262_typeof) == @val2.ecma262_typeof and !t.nil?
          parent.replace(self, ExpEq.new(@val, @val2))
        end
      end

      def ecma262_typeof
        :boolean
      end
    end
    #
    # 11.9.5 The Strict Does-not-equal Operator ( !== )
    #
    class ExpStrictNotEq < ExpArg2
      include BinaryOperation
      def sym
        "!=="
      end

      def priority
        PRIORITY_EQUALITY
      end

      def reduce(parent)
        if @val.respond_to?(:ecma262_typeof) and @val2.respond_to?(:ecma262_typeof) and
           (t = @val.ecma262_typeof) == @val2.ecma262_typeof and !t.nil?
          parent.replace(self, ExpNotEq.new(@val, @val2))
        end
      end

      def ecma262_typeof
        :boolean
      end
    end
    #
    # 11.10 Binary Bitwise Operators
    #
    class ExpAnd < ExpArg2
      include BinaryOperation
      def sym
        "&"
      end

      def priority
        PRIORITY_BITWISE_AND
      end

      def swap
        t = @val
        @val = @val2
        @val2 = t
      end

      def ecma262_typeof
        :number
      end
    end
    # ^
    class ExpXor < ExpArg2
      include BinaryOperation
      def sym
        "^"
      end

      def priority
        PRIORITY_BITWISE_XOR
      end

      def swap
        t = @val
        @val = @val2
        @val2 = t
      end

      def ecma262_typeof
        :number
      end
    end

    # |
    class ExpOr < ExpArg2
      include BinaryOperation
      def sym
        "|"
      end

      def priority
        PRIORITY_BITWISE_OR
      end

      def swap
        t = @val
        @val = @val2
        @val2 = t
      end

      def ecma262_typeof
        :number
      end
    end
    #
    # 11.11 Binary Logical Operators
    #
    # &&
    class ExpLogicalAnd < ExpArg2
      include BinaryOperation

      def sym
        "&&"
      end

      def priority
        PRIORITY_LOGICAL_AND
      end

      def ecma262_typeof
        if @val.respond_to? :ecma262_typeof and @val2.respond_to? :ecma262_typeof
           if @val.ecma262_typeof == @val2.ecma262_typeof
             return @val.ecma262_typeof
           end
        end
        nil
      end
    end
    # ||
    class ExpLogicalOr < ExpArg2
      include BinaryOperation
      def sym
        "||"
      end

      def priority
        PRIORITY_LOGICAL_OR
      end

      def ecma262_typeof
        if @val.respond_to? :ecma262_typeof and @val2.respond_to? :ecma262_typeof
          if @val.ecma262_typeof == @val2.ecma262_typeof
            return @val.ecma262_typeof
          end
        end
        nil
      end
    end
    #
    # 11.12 Conditional Operator ( ? : )
    #
    # val ? val2 : val3
    #
    class ExpCond < Exp
      attr_reader :val, :val2, :val3

      def initialize(val, val2, val3)
        @val = val
        @val2 = val2
        @val3 = val3
      end

      def priority
        PRIORITY_CONDITIONAL
      end

      def remove_paren
        if @val.kind_of? ExpParen and @val.val.priority < PRIORITY_CONDITIONAL
          @val = @val.val if @val.remove_paren?
        end
        if @val2.kind_of? ExpParen and @val2.val.priority <= PRIORITY_ASSIGNMENT
          @val2 = @val2.val
        end
        if @val3.kind_of? ExpParen and @val3.val.priority <= PRIORITY_ASSIGNMENT
          @val3 = @val3.val
        end
        self
      end

      def add_paren
        if @val.priority > PRIORITY_CONDITIONAL
          @val = ExpParen.new(@val)
        end
        if @val2.priority > PRIORITY_ASSIGNMENT
          @val2 = ExpParen.new(@val2)
        end
        if @val3.priority > PRIORITY_ASSIGNMENT
          @val3 = ExpParen.new(@val3)
        end
        self
      end

      def deep_dup
        self.class.new(@val.deep_dup, @val2.deep_dup, @val3.deep_dup)
      end

      def replace(from, to)
        if from .eql? @val
          @val = to
        elsif from .eql? @val2
          @val2 = to
        elsif from .eql? @val3
          @val3 = to
        end
      end

      def traverse(parent, &block)
        @val.traverse(self, &block)
        @val2.traverse(self, &block)
        @val3.traverse(self, &block)
        yield self, parent
      end

      def ==(obj)
        self.class == obj.class and
          @val == obj.val and
          @val2 == obj.val2 and
          @val3 == obj.val3
      end

      def to_js(options = {})
        "#{@val.to_js(options)}?#{@val2.to_js(options)}:#{@val3.to_js(options)}"
      end

      def ecma262_typeof
        if @val2.respond_to? :ecma262_typeof and @val3.respond_to? :ecma262_typeof
          if @val2.ecma262_typeof == @val3.ecma262_typeof
            return @val2.ecma262_typeof
          end
        end
        nil
      end
    end
    #
    # 11.13 Assignment Operators
    #
    class ExpAssign < ExpArg2
      include AssignmentOperation
      def sym
        "="
      end

      def priority
        PRIORITY_ASSIGNMENT
      end

      def reduce(parent)
        #
        # a = a / b => a /= b
        #
        if @val2.kind_of? ExpDiv and @val2.val == @val
          parent.replace(self,
                         ExpParen.new(
                           ExpDivAssign.new(@val, @val2.val2)))
        elsif @val2.kind_of? ExpMul and @val2.val == @val
          parent.replace(self,
                         ExpParen.new(
                           ExpMulAssign.new(@val, @val2.val2)))
        elsif @val2.kind_of? ExpMod and @val2.val == @val
          parent.replace(self,
                         ExpParen.new(
                           ExpModAssign.new(@val, @val2.val2)))
        elsif @val2.kind_of? ExpAdd and @val2.val == @val
          parent.replace(self,
                         ExpParen.new(
                           ExpAddAssign.new(@val, @val2.val2)))
        elsif @val2.kind_of? ExpSub and @val2.val == @val
          parent.replace(self,
                         ExpParen.new(
                           ExpSubAssign.new(@val, @val2.val2)))
        elsif @val2.kind_of? ExpLShift and @val2.val == @val
          parent.replace(self,
                         ExpParen.new(
                           ExpLShiftAssign.new(@val, @val2.val2)))
        elsif @val2.kind_of? ExpRShift and @val2.val == @val
          parent.replace(self,
                         ExpParen.new(
                           ExpRShiftAssign.new(@val, @val2.val2)))
        elsif @val2.kind_of? ExpURShift and @val2.val == @val
          parent.replace(self,
                         ExpParen.new(
                           ExpURShiftAssign.new(@val, @val2.val2)))
        elsif @val2.kind_of? ExpAnd and @val2.val == @val
          parent.replace(self,
                         ExpParen.new(
                           ExpAndAssign.new(@val, @val2.val2)))
        elsif @val2.kind_of? ExpOr and @val2.val == @val
          parent.replace(self,
                         ExpParen.new(
                           ExpOrAssign.new(@val, @val2.val2)))
        elsif @val2.kind_of? ExpXor and @val2.val == @val
          parent.replace(self,
                         ExpParen.new(
                           ExpXorAssign.new(@val, @val2.val2)))
        end
      end
    end
    class ExpDivAssign < ExpAssign
      include AssignmentOperation
      def sym
        "/="
      end
      def priority
        PRIORITY_ASSIGNMENT
      end
    end
    class ExpMulAssign < ExpAssign
      include AssignmentOperation
      def sym
        "*="
      end
      def priority
        PRIORITY_ASSIGNMENT
      end
    end
    class ExpModAssign < ExpAssign
      include AssignmentOperation
      def sym
        "%="
      end
      def priority
        PRIORITY_ASSIGNMENT
      end
    end
    class ExpAddAssign < ExpAssign
      include AssignmentOperation
      def sym
        "+="
      end
      def priority
        PRIORITY_ASSIGNMENT
      end
    end
    class ExpSubAssign < ExpAssign
      include AssignmentOperation
      def sym
        "-="
      end
      def priority
        PRIORITY_ASSIGNMENT
      end
    end
    class ExpLShiftAssign < ExpAssign
      include AssignmentOperation
      def sym
        "<<="
      end
      def priority
        PRIORITY_ASSIGNMENT
      end
    end
    class ExpRShiftAssign < ExpAssign
      include AssignmentOperation
      def sym
        ">>="
      end
      def priority
        PRIORITY_ASSIGNMENT
      end
    end
    class ExpURShiftAssign < ExpAssign
      include AssignmentOperation
      def sym
        ">>>="
      end
      def priority
        PRIORITY_ASSIGNMENT
      end
    end
    class ExpAndAssign < ExpAssign
      include AssignmentOperation
      def sym
        "&="
      end
      def priority
        PRIORITY_ASSIGNMENT
      end
    end
    class ExpOrAssign < ExpAssign
      include AssignmentOperation
      def sym
        "|="
      end
      def priority
        PRIORITY_ASSIGNMENT
      end
    end
    class ExpXorAssign < ExpAssign
      include AssignmentOperation
      def sym
        "^="
      end
      def priority
        PRIORITY_ASSIGNMENT
      end
    end
    #
    # Comma Operator ( , )
    #
    class ExpComma < ExpArg2
      include BinaryOperation
      def sym
        ","
      end

      def priority
        PRIORITY_COMMA
      end
    end
  end
end
