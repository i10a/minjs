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

      def priority(exp)
        9999
      end
    end

    class ExpArg1 < Exp
      def initialize(val)
        @val = val
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

    # ""
    class ExpEmpty < Exp
      def traverse(parent, &block)
      end
      def to_js(options = {})
        ""
      end
    end

    # ( exp )
    class ExpParen < Exp
      attr_reader :val

      def initialize(val)
        @val = val
      end

      def priority(exp)
        0
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
    end

    # val = val2
    class ExpAssign < ExpArg2
      def sym
        "="
      end
      def priority(exp)
        130
      end
    end
    class ExpDivAssign < ExpAssign
      def sym
        "/="
      end
      def priority(exp)
        130
      end
    end
    class ExpMulAssign < ExpAssign
      def sym
        "*="
      end
      def priority(exp)
        130
      end
    end
    class ExpModAssign < ExpAssign
      def sym
        "%="
      end
      def priority(exp)
        130
      end
    end
    class ExpAddAssign < ExpAssign
      def sym
        "+="
      end
      def priority(exp)
        130
      end
    end
    class ExpSubAssign < ExpAssign
      def sym
        "-="
      end
      def priority(exp)
        130
      end
    end
    class ExpLShiftAssign < ExpAssign
      def sym
        "<<="
      end
      def priority(exp)
        130
      end
    end
    class ExpRShiftAssign < ExpAssign
      def sym
        ">>="
      end
      def priority(exp)
        130
      end
    end
    class ExpURShiftAssign < ExpAssign
      def sym
        ">>>="
      end
      def priority(exp)
        130
      end
    end
    class ExpAndAssign < ExpAssign
      def sym
        "&="
      end
      def priority(exp)
        130
      end
    end
    class ExpOrAssign < ExpAssign
      def sym
        "|="
      end
      def priority(exp)
        130
      end
    end
    class ExpXorAssign < ExpAssign
      def sym
        "^="
      end
      def priority(exp)
        130
      end
    end

    # a ? b : c
    class ExpCond < Exp
      def initialize(val, val2, val3)
        @val = val
        @val2 = val2
        @val3 = val3
      end

      def priority(exp)
        120
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

    # ||
    class ExpLogicalOr < ExpArg2
      def sym
        "||"
      end
      def priority(exp)
        118
      end
    end

    # &&
    class ExpLogicalAnd < ExpArg2
      def sym
        "&&"
      end
      def priority(exp)
        116
      end
    end

    # |
    class ExpOr < ExpArg2
      def sym
        "|"
      end
      def priority(exp)
        108
      end
    end

    # ^
    class ExpXor < ExpArg2
      def sym
        "^"
      end
      def priority(exp)
        106
      end
    end

    # &
    class ExpAnd < ExpArg2
      def sym
        "&"
      end
      def priority(exp)
        104
      end
    end

    # 11.9
    # ==
    class ExpEq < ExpArg2
      def sym
        "=="
      end
      def priority(exp)
        90
      end
    end
    # !=
    class ExpNotEq < ExpArg2
      def sym
        "!="
      end
      def priority(exp)
        90
      end
    end
    # ===
    class ExpStrictEq < ExpArg2
      def sym
        "==="
      end
      def priority(exp)
        90
      end
    end
    # !==
    class ExpStrictNotEq < ExpArg2
      def sym
        "!=="
      end
      def priority(exp)
        90
      end
    end

    class ExpLt < ExpArg2
      def sym
        "<"
      end
      def priority(exp)
        80
      end
    end

    class ExpGt < ExpArg2
      def sym
        ">"
      end
      def priority(exp)
        80
      end
    end

    class ExpLtEq < ExpArg2
      def sym
        "<="
      end
      def priority(exp)
        80
      end
    end

    class ExpGtEq < ExpArg2
      def sym
        ">="
      end
      def priority(exp)
        80
      end
    end

    #+
    class ExpAdd < ExpArg2
      def sym
        "+"
      end
      def priority(exp)
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
      end

    end

    class ExpSub < ExpArg2
      def sym
        "-"
      end
      def priority(exp)
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
      end

    end

    class ExpInstanceOf < ExpArg2
      def sym
        "instanceof"
      end
      def priority(exp)
        80
      end
    end

    class ExpIn < ExpArg2
      def sym
        "in"
      end
      def priority(exp)
        80
      end
    end

    class ExpLShift < ExpArg2
      def sym
        "<<"
      end
      def priority(exp)
        70
      end
    end
    class ExpRShift < ExpArg2
      def sym
        ">>"
      end
      def priority(exp)
        70
      end
    end
    class ExpURShift < ExpArg2
      def sym
        ">>>"
      end
      def priority(exp)
        70
      end
    end

    class ExpMul < ExpArg2
      def sym
        "*"
      end
      def priority(exp)
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
      end
    end
    class ExpDiv < ExpArg2
      def sym
        "/"
      end
      def priority(exp)
        50
      end
    end
    class ExpMod < ExpArg2
      def sym
        "%"
      end
      def priority(exp)
        50
      end
    end
    #
    # 11.4
    # unary expression
    #
    class ExpDelete < ExpArg1
      def sym
        "delete"
      end
      def priority(exp)
        40
      end
    end
    class ExpVoid < ExpArg1
      def sym
        "void"
      end
      def priority(exp)
        40
      end
    end
    class ExpTypeof < ExpArg1
      def sym
        "typeof"
      end
      def priority(exp)
        40
      end
    end
    class ExpPostInc < ExpArg1
      def sym
        "++"
      end
      def priority(exp)
        30
      end
      def to_js(options = {})
        concat options, @val, sym
      end
    end
    class ExpPostDec < ExpArg1
      def sym
        "--"
      end
      def priority(exp)
        30
      end
      def to_js(options = {})
        concat options, @val, sym
      end
    end
    class ExpPreInc < ExpArg1
      def sym
        "++"
      end
      def priority(exp)
        40
      end
    end
    class ExpPreDec < ExpArg1
      def sym
        "--"
      end
      def priority(exp)
        40
      end
    end
    class ExpPositive < ExpArg1
      def sym
        "+"
      end
      def priority(exp)
        40
      end

      def reduce(parent)
        if @val.kind_of? ECMA262Numeric
          parent.replace(self, @val)
        end
      end
    end

    class ExpNegative < ExpArg1
      def sym
        "-"
      end
      def priority(exp)
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
      def sym
        "~"
      end
      def priority(exp)
        40
      end
    end
    class ExpLogicalNot < ExpArg1
      def sym
        "!"
      end
      def priority(exp)
        40
      end
    end

    class ExpNew < Exp
      def initialize(name, args)
        @name = name
        @args = args
      end

      def priority(exp)
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

      def priority(exp)
        if @args.index(exp)
          999
        else
          20
        end
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
          raise "internal error: val2 must be kind_of ItentiferName"
        end
      end

      def priority(exp)
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
    end
    #
    # => val[val2]
    #
    class ExpPropBrac < ExpArg2
      def priority(exp)
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
    end

    class ExpComma < ExpArg2
      def sym
        ","
      end
      def priority(exp)
        140
      end
    end
  end
end
