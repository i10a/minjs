module Minjs
  module ECMA262
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
      end
    end

    module UnaryOperation
      def remove_paren
        if @val.kind_of? ExpParen and @val.val.priority <= self.priority
          @val = @val.val if @val.remove_paren?
        end
      end
    end

    module AssignmentOperation
      def remove_paren
        if @val.kind_of? ExpParen and @val.val.priority <= 20
          @val = @val.val if @val.remove_paren?
        end
        if @val2.kind_of? ExpParen and @val2.val.priority <= 130
          @val2 = @val2.val
        end
      end
    end

    class ExpArg1 < Exp
      def initialize(val)
        @val = val
      end

      def deep_dup
        self.class.new(@val.deep_dup)
      end

      def replace(from, to)
        if @val == from
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
        if @val == from
          @val = to
        elsif @val2 == from
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
    # ""
    #
    class ExpEmpty < Exp
      def traverse(parent, &block)
      end
      def to_js(options = {})
        ""
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
        10
      end

      def replace(from, to)
        if @val == from
          @val = to
        end
      end

      def traverse(parent, &block)
        @val.traverse(self, &block)
        yield self, parent
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
        20
      end

      def traverse(parent, &block)
        @val.traverse(self, &block)
        @val2.traverse(self, &block)
        yield self, parent
      end

      def to_js(options = {})
        "#{@val.to_js(options)}[#{@val2.to_js(options)}]"
      end

      def remove_paren
        if @val.kind_of? ExpParen and @val.val.priority <= 20
          @val = @val.val if @val.remove_paren?
        end
        if @val2.kind_of? ExpParen
          @val2 = @val2.val
        end
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
        else
          #=>deep_dup
          #raise "internal error: val2 must be kind_of ItentiferName"
        end
      end

      def priority
        20
      end

      def traverse(parent, &block)
        @val.traverse(self, &block)
        @val2.traverse(self, &block)
        yield self, parent
      end

      def to_js(options = {})
        "#{@val.to_js(options)}.#{@val2.val}"
      end

      def remove_paren
        if @val.kind_of? ExpParen and @val.val.priority <= 20
          @val = @val.val if @val.remove_paren?
        end
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
        20
      end

      def replace(from, to)
        @args.each_index do |i|
          arg = @args[i]
          if arg == from
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

      def to_js(options = {})
        args = @args.collect{|x| x.to_js(options)}.join(",")
        "#{@name.to_js(options)}(#{args})"
      end

      def remove_paren
        if @name.kind_of? ExpParen and @name.val.priority <= 20
          @name = @name.val if @name.remove_paren?
        end
        if @args
          @args.map! do |arg|
            if arg.kind_of? ExpParen and arg.val.priority <= 130 #AssignmentOperators
              arg.val if arg.remove_paren?
            else
              arg
            end
          end
        end
      end

    end

    #
    # new M
    # new M(a,b,c...)
    #
    class ExpNew < Exp
      def initialize(name, args)
        @name = name
        @args = args
      end

      def priority
        20
      end

      def replace(from, to)
        if @name == from
          @name = from
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

      def to_js(options = {})
        if @args
          args = @args.collect{|x| x.to_js(options)}.join(",")
          concat options, :new, @name, '(', args, ')'
        else
          concat options, :new, @name
        end
      end

      def remove_paren
        if @name.kind_of? ExpParen and @name.val.priority <= 20
          @name = @name.val if @name.remove_paren?
        end
        if @args
          @args.map! do |arg|
            if arg.kind_of? ExpParen and arg.val.priority <= 130 #AssignmentOperators
              arg.val if arg.remove_paren?
            else
              arg
            end
          end
        end
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
        30
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
        30
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
        40
      end
    end
    class ExpVoid < ExpArg1
      include UnaryOperation
      def sym
        "void"
      end
      def priority
        40
      end
    end
    class ExpTypeof < ExpArg1
      include UnaryOperation
      def sym
        "typeof"
      end
      def priority
        40
      end
    end

    class ExpPreInc < ExpArg1
      include UnaryOperation
      def sym
        "++"
      end
      def priority
        40
      end
    end
    class ExpPreDec < ExpArg1
      include UnaryOperation
      def sym
        "--"
      end
      def priority
        40
      end
    end
    class ExpPositive < ExpArg1
      include UnaryOperation
      def sym
        "+"
      end
      def priority
        40
      end

      def reduce(parent)
        if @val.kind_of? ECMA262Numeric
          parent.replace(self, @val)
        end
      end
    end

    class ExpNegative < ExpArg1
      include UnaryOperation
      def sym
        "-"
      end
      def priority
        40
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
    end
    class ExpBitwiseNot < ExpArg1
      include UnaryOperation
      def sym
        "~"
      end
      def priority
        40
      end
    end
    class ExpLogicalNot < ExpArg1
      include UnaryOperation
      def sym
        "!"
      end
      def priority
        40
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
        50
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
        50
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
        50
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
        60
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
=begin
        if @val2.kind_of? ECMA262Numeric and @val2.integer?
          # ((a + N) + M) or ((N + a) + M)
          if @val.kind_of? ExpAdd
            if @val.val2.kind_of? ECMA262Numeric and @val.val2.integer?
              @val2 = ECMA262Numeric.new(@val.val2.to_num + @val2.to_num)
              @val = @val.val
            elsif @val.val.kind_of? ECMA262Numeric and @val.val.integer?
              @val2 = ECMA262Numeric.new(@val.val.to_num + @val2.to_num)
              @val = @val.val2
            end
          # ((a - N) + M) or ((N - a) + M)
          elsif @val.kind_of? ExpSub
            if @val.val2.kind_of? ECMA262Numeric and @val.val2.integer?
              @val2 = ECMA262Numeric.new(-(@val.val2.to_num - @val2.to_num))
              @val = @val.val
            elsif @val.val.kind_of? ECMA262Numeric and @val.val.integer?
              @val2 = ECMA262Numeric.new(-(@val.val.to_num - @val2.to_num))
              @val = @val.val2
            end
          end
        end
=end
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
        60
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
=begin
        if @val2.kind_of? ECMA262Numeric and @val2.integer?
          # ((a - N) - M) or ((N - a) - M)
          if @val.kind_of? ExpSub
            if @val.val2.kind_of? ECMA262Numeric and @val.val2.integer?
              @val2 = ECMA262Numeric.new(@val.val2.to_num + @val2.to_num)
              @val = @val.val
            elsif @val.val.kind_of? ECMA262Numeric and @val.val.integer?
              @val2 = ECMA262Numeric.new(@val.val.to_num + @val2.to_num)
              @val = @val.val2
            end
          # ((a + N) - M) or ((N + a) - M)
          elsif @val.kind_of? ExpAdd
            if @val.val2.kind_of? ECMA262Numeric and @val.val2.integer?
              @val2 = ECMA262Numeric.new(-(@val.val2.to_num - @val2.to_num))
              @val = @val.val
            elsif @val.val.kind_of? ECMA262Numeric and @val.val.integer?
              @val2 = ECMA262Numeric.new(-(@val.val.to_num - @val2.to_num))
              @val = @val.val2
            end
          end
        end
=end
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
        70
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
        70
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
        70
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
        80
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
        80
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
        80
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
        80
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
        80
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
        80
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
        90
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
        90
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
        90
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
        90
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
        100
      end
    end
    # ^
    class ExpXor < ExpArg2
      include BinaryOperation
      def sym
        "^"
      end
      def priority
        106
      end
    end

    # |
    class ExpOr < ExpArg2
      include BinaryOperation
      def sym
        "|"
      end
      def priority
        108
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
        110
      end
    end
    # ||
    class ExpLogicalOr < ExpArg2
      include BinaryOperation
      def sym
        "||"
      end
      def priority
        116
      end
    end
    #
    # 11.12 Conditional Operator ( ? : )
    #
    # val ? val2 : val3
    #
    class ExpCond < Exp
      def initialize(val, val2, val3)
        @val = val
        @val2 = val2
        @val3 = val3
      end

      def priority
        120
      end

      def remove_paren
        if @val.kind_of? ExpParen and @val.val.priority < 120
          @val = @val.val if @val.remove_paren?
        end
        if @val2.kind_of? ExpParen and @val2.val.priority <= 130
          @val2 = @val2.val
        end
        if @val3.kind_of? ExpParen and @val3.val.priority <= 130
          @val3 = @val3.val
        end
      end

      def deep_dup
        self.class.new(@val.deep_dup, @val2.deep_dup, @val3.deep_dup)
      end

      def replace(from, to)
        if from == @val
          @val = to
        elsif from == @val2
          @val2 = to
        elsif from == @val3
          @val3 = to
        end
      end

      def traverse(parent, &block)
        @val.traverse(self, &block)
        @val2.traverse(self, &block)
        @val3.traverse(self, &block)
        yield self, parent
      end

      def to_js(options = {})
        "#{@val.to_js(options)}?#{@val2.to_js(options)}:#{@val3.to_js(options)}"
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
        130
      end
    end
    class ExpDivAssign < ExpAssign
      include AssignmentOperation
      def sym
        "/="
      end
      def priority
        130
      end
    end
    class ExpMulAssign < ExpAssign
      include AssignmentOperation
      def sym
        "*="
      end
      def priority
        130
      end
    end
    class ExpModAssign < ExpAssign
      include AssignmentOperation
      def sym
        "%="
      end
      def priority
        130
      end
    end
    class ExpAddAssign < ExpAssign
      include AssignmentOperation
      def sym
        "+="
      end
      def priority
        130
      end
    end
    class ExpSubAssign < ExpAssign
      include AssignmentOperation
      def sym
        "-="
      end
      def priority
        130
      end
    end
    class ExpLShiftAssign < ExpAssign
      include AssignmentOperation
      def sym
        "<<="
      end
      def priority
        130
      end
    end
    class ExpRShiftAssign < ExpAssign
      include AssignmentOperation
      def sym
        ">>="
      end
      def priority
        130
      end
    end
    class ExpURShiftAssign < ExpAssign
      include AssignmentOperation
      def sym
        ">>>="
      end
      def priority
        130
      end
    end
    class ExpAndAssign < ExpAssign
      include AssignmentOperation
      def sym
        "&="
      end
      def priority
        130
      end
    end
    class ExpOrAssign < ExpAssign
      include AssignmentOperation
      def sym
        "|="
      end
      def priority
        130
      end
    end
    class ExpXorAssign < ExpAssign
      include AssignmentOperation
      def sym
        "^="
      end
      def priority
        130
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
        140
      end
    end
  end
end
