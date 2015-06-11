module Minjs
  module ECMA262
    #priority
    PRIORITY_PRIMARY = 10
    #priority
    PRIORITY_LEFT_HAND_SIDE = 20
    #priority
    PRIORITY_POSTFIX = 30
    #priority
    PRIORITY_UNARY = 40
    #priority
    PRIORITY_MULTIPLICATIVE = 50
    #priority
    PRIORITY_ADDITIVE = 60
    #priority
    PRIORITY_SHIFT = 70
    #priority
    PRIORITY_RELATIONAL = 80
    #priority
    PRIORITY_EQUALITY = 90
    #priority
    PRIORITY_BITWISE_AND = 100
    #priority
    PRIORITY_BITWISE_XOR = 106
    #priority
    PRIORITY_BITWISE_OR = 108
    #priority
    PRIORITY_LOGICAL_AND = 110
    #priority
    PRIORITY_LOGICAL_OR = 116
    #priority
    PRIORITY_CONDITIONAL = 120
    #priority
    PRIORITY_ASSIGNMENT = 130
    #priority
    PRIORITY_COMMA = 140

    # Base class of ECMA262 expression element
    class Expression < Base
      # reduce expression if available
      # @param parent [Base] parent element
      def reduce(parent)
      end

      # @return [Boolean] true if expression is kind of LeftHandSideExpression.
      def left_hand_side_exp?
        false
      end

      # @return [Fixnum] expression priority
      def priority
        999
      end

      def side_effect?
        return true
      end
    end

    # Module of typically binary operation expression.
    #
    # Typically binary operation expression has two
    # values(val, val2) and operation symbol.
    module BinaryOperation
      attr_reader :val, :val2

      # remove parenthesis if possible
      def remove_paren
        if @val.kind_of? ExpParen and @val.val.priority <= self.priority
          @val = @val.val if @val.remove_paren?
        end
        if @val2.kind_of? ExpParen and @val2.val.priority < self.priority
          @val2 = @val2.val
        end
        self
      end

      # add parenthesis if need
      def add_paren
        if @val.priority > self.priority
          @val = ExpParen.new(@val)
        end
        if @val2.priority > self.priority
          @val2 = ExpParen.new(@val2)
        end

        self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and self.val == obj.val and self.val2 == obj.val2
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@val.deep_dup, @val2.deep_dup)
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if @val .eql? from
          @val = to
        elsif @val2 .eql? from
          @val2 = to
        end
      end

      # Traverses this children and itself with given block.
      # @see Base#traverse
      def traverse(parent, &block)
        @val.traverse(self, &block)
        @val2.traverse(self, &block)
        yield parent, self
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        concat options, @val, sym, @val2
      end
    end

    # Module of typically unary operation expression.
    #
    # Typically unary operation expression has one
    # values(val) and operation symbol.
    #
    module UnaryOperation
      attr_reader :val

      # remove parenthesis if possible
      def remove_paren
        if @val.kind_of? ExpParen and @val.val.priority <= self.priority
          @val = @val.val
        end
        self
      end

      # add parenthesis if need
      def add_paren
        if @val.priority > self.priority
          @val = ExpParen.new(@val)
        end

        self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and self.val == obj.val
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@val.deep_dup)
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if @val .eql? from
          @val = to
        end
      end

      # Traverses this children and itself with given block.
      # @see Base#traverse
      def traverse(parent, &block)
        @val.traverse(self, &block)
        yield parent, self
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        concat options, sym, @val
      end

      # Returns this element has side effect or not.
      # @return [Boolean]
      def side_effect?
        @val.side_effect?
      end
    end

    # Module of typically Assignment operation.
    #
    # Typically unary operation expression has left-hand value(val)
    # and right-hand value(val2)
    module AssignmentOperation
      attr_reader :val, :val2

      # remove parenthesis if possible
      def remove_paren
        if @val.kind_of? ExpParen and @val.val.priority <= PRIORITY_LEFT_HAND_SIDE
          @val = @val.val if @val.remove_paren?
        end
        if @val2.kind_of? ExpParen and @val2.val.priority <= PRIORITY_ASSIGNMENT
          @val2 = @val2.val
        end
        self
      end

      # add parenthesis if need
      def add_paren
        if @val.priority > PRIORITY_LEFT_HAND_SIDE
          @val = ExpParen.new(@val)
        end
        if @val2.priority > PRIORITY_ASSIGNMENT
          @val2 = ExpParen.new(@val2)
        end
        self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and self.val == obj.val and self.val2 == obj.val2
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] type of right-side-hand expression
      #   or nil if typeof value is undetermined.
      def ecma262_typeof
        if @val2.respond_to? :ecma262_typeof
          @val2.ecma262_typeof
        else
          nil
        end
      end
      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@val.deep_dup, @val2.deep_dup)
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if @val .eql? from
          @val = to
        elsif @val2 .eql? from
          @val2 = to
        end
      end

      # Traverses this children and itself with given block.
      # @see Base#traverse
      def traverse(parent, &block)
        @val.traverse(self, &block)
        @val2.traverse(self, &block)
        yield parent, self
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        concat options, @val, sym, @val2
      end

      # reduce expression if available
      # @param parent [Base] parent element
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
    # Class of the Grouping operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.1.6
    class ExpParen < Expression
      attr_reader :val

      def initialize(val)
        @val = val
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_PRIMARY
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@val.deep_dup)
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if @val .eql? from
          @val = to
        end
      end

      # Traverses this children and itself with given block.
      # @see Base#traverse
      def traverse(parent, &block)
        @val.traverse(self, &block)
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and @val == obj.val
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        "(#{@val.to_js(options)})"
      end

      # @return [Boolean] true if expression is kind of LeftHandSideExpression.
      def left_hand_side_exp?
        true
      end

      # returns removing parenthesis is possible or not
      #
      # ECMA262 expression-statement should not start with
      # "function" or "{".
      # This method checks inner of the parenthesis' first literal.
      #
      # @return [Boolean] true if possible
      def remove_paren?
        js = @val.to_js
        if js.match(/^function/) or js.match(/^{/)
          false
        else
          true
        end
      end

      # remove parenthesis if possible
      def remove_paren
        if @val.kind_of? ExpParen
          @val = @val.val if @val.remove_paren?
        end
        self
      end

      # add parenthesis if need
      def add_paren
        self
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
        return nil unless @val.respond_to? :to_ecma262_boolean
        return nil if @val.to_ecma262_boolean.nil?
        @val.to_ecma262_boolean
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] type of val
      def ecma262_typeof
        if @val.respond_to? :ecma262_typeof
          @val.ecma262_typeof
        else
          nil
        end
      end
    end
    # Class of the Property Accessors expression element.
    #
    # This is another expression of ExpProp.
    # This class uses bracket instead of period.
    #
    # @see ExpProp
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.2.1
    class ExpPropBrac < Expression
      attr_reader :val, :val2

      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@val.deep_dup, @val2.deep_dup)
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if @val .eql? from
          @val = to
        elsif @val2 .eql? from
          @val2 = to
        end
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_LEFT_HAND_SIDE
      end

      # Traverses this children and itself with given block.
      # @see Base#traverse
      def traverse(parent, &block)
        @val.traverse(self, &block)
        @val2.traverse(self, &block)
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and
          @val == obj.val and
          @val2 == obj.val2
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        "#{@val.to_js(options)}[#{@val2.to_js(options)}]"
      end

      # @return [Boolean] true if expression is kind of LeftHandSideExpression.
      def left_hand_side_exp?
        true
      end

      # remove parenthesis if possible
      def remove_paren
        if @val.kind_of? ExpParen and @val.val.priority <= PRIORITY_LEFT_HAND_SIDE
          @val = @val.val if @val.remove_paren?
        end
        if @val2.kind_of? ExpParen
          @val2 = @val2.val
        end
        self
      end

      # add parenthesis if need
      def add_paren
        if @val.priority > PRIORITY_LEFT_HAND_SIDE
          @val = ExpParen.new(@val)
        end
        self
      end
    end
    # Class of the Property Accessors expression element.
    #
    # This is another expression of ExpPropBrac.
    # This class uses period insted of bracket.
    #
    # @see ExpPropBrac
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.2.1
    class ExpProp < Expression
      attr_reader :val, :val2

      def initialize(val, val2)
        @val = val
        if val2.kind_of? IdentifierName
          @val2 = ECMA262::ECMA262String.new(val2.val)
        elsif val2.kind_of? ECMA262String
          @val2 = val2
        end
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@val.deep_dup, @val2.deep_dup)
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_LEFT_HAND_SIDE
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if @val .eql? from
          @val = to
        elsif @val2 .eql? from
          @val2 = to
        end
      end

      # Traverses this children and itself with given block.
      # @see Base#traverse
      def traverse(parent, &block)
        @val.traverse(self, &block)
        @val2.traverse(self, &block)
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and
          @val == obj.val and
          @val2 == obj.val2
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        "#{@val.to_js(options)}.#{@val2.val}"
      end

      # @return [Boolean] true if expression is kind of LeftHandSideExpression.
      def left_hand_side_exp?
        true
      end

      # remove parenthesis if possible
      def remove_paren
        if @val.kind_of? ExpParen and @val.val.priority <= PRIORITY_LEFT_HAND_SIDE
          @val = @val.val if @val.remove_paren?
        end
        self
      end

      # add parenthesis if need
      def add_paren
        if @val.priority > PRIORITY_LEFT_HAND_SIDE
          @val = ExpParen.new(@val)
        end
        self
      end
    end
    # Class of the Call expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.2
    class ExpCall < Expression
      attr_reader :name
      attr_reader :args

      def initialize(name, args)
        @name = name
        @args = args
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_LEFT_HAND_SIDE
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@name.deep_dup,
                       @args ? @args.collect{|x| x.deep_dup} : nil)
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if @name .eql? from
          @name = to
        else
          @args.each_index do |i|
            arg = @args[i]
            if arg .eql? from
              @args[i] = to
              break
            end
          end
        end
      end

      # Traverses this children and itself with given block.
      def traverse(parent, &block)
        @name.traverse(self, &block)
        @args.each do |x|
          x.traverse(self, &block)
        end
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and @name == obj.name and @args == obj.args
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        args = @args.collect{|x| x.to_js(options)}.join(",")
        "#{@name.to_js(options)}(#{args})"
      end

      # @return [Boolean] true if expression is kind of LeftHandSideExpression.
      def left_hand_side_exp?
        true
      end

      # remove parenthesis if possible
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

      # add parenthesis if need
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

    # Class of the New expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.2
    class ExpNew < Expression
      attr_reader :name, :args

      def initialize(name, args)
        @name = name
        @args = args
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_LEFT_HAND_SIDE + ((args == nil) ? 1 : 0)
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@name,
                       @args ? @args.collect{|x| x.deep_dup} : nil)
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if @name .eql? from
          @name = from
        elsif @args .eql? from
          @args = to
        elsif @args and (idx = @args.index(from))
          @args[idx] = to
        end
      end

      # Traverses this children and itself with given block.
      # @see Base#traverse
      def traverse(parent, &block)
        @name.traverse(self, &block)
        if @args
          @args.each do |arg|
            arg.traverse(self, &block)
          end
        end
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and @name == obj.name and @args == obj.args
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        if @args
          args = @args.collect{|x| x.to_js(options)}.join(",")
          concat options, :new, @name, '(', args, ')'
        else
          concat options, :new, @name
        end
      end

      # @return [Boolean] true if expression is kind of LeftHandSideExpression.
      def left_hand_side_exp?
        true
      end

      # remove parenthesis if possible
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

      # add parenthesis if need
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

    # Class of the Postfix increment operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.3.1
    class ExpPostInc < Expression
      include UnaryOperation
      def initialize(val)
        @val = val
      end

      # symbol of expression
      def sym
        "++"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_POSTFIX
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        concat options, @val, sym
      end
    end

    # Class of the Postfix decrement operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.3.2
    class ExpPostDec < Expression
      include UnaryOperation
      def initialize(val)
        @val = val
      end

      # symbol of expression
      def sym
        "--"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_POSTFIX
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        concat options, @val, sym
      end
    end
    # Class of the Delete operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.4
    class ExpDelete < Expression
      include UnaryOperation
      def initialize(val)
        @val = val
      end

      # symbol of expression
      def sym
        "delete"
      end
      # @return [Fixnum] expression priority
      def priority
        PRIORITY_UNARY
      end
    end
    # Class of the Void operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.4
    class ExpVoid < Expression
      include UnaryOperation

      def initialize(val)
        @val = val
      end
      # symbol of expression
      def sym
        "void"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_UNARY
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :undefined
      def ecma262_typeof
        :undefined
      end
    end

    # Class of the Typeof operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.4
    class ExpTypeof < Expression
      include UnaryOperation
      def initialize(val)
        @val = val
      end

      # symbol of expression
      def sym
        "typeof"
      end
      # @return [Fixnum] expression priority
      def priority
        PRIORITY_UNARY
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :string
      def ecma262_typeof
        :string
      end
    end

    # Class of the Prefix Increment operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.4
    class ExpPreInc < Expression
      include UnaryOperation
      def initialize(val)
        @val = val
      end

      # symbol of expression
      def sym
        "++"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_UNARY
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :number
      def ecma262_typeof
        :number
      end
    end

    # Class of the Prefix Decrement operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.4
    class ExpPreDec < Expression
      include UnaryOperation
      def initialize(val)
        @val = val
      end

      # symbol of expression
      def sym
        "--"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_UNARY
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :number
      def ecma262_typeof
        :number
      end
    end

    # Class of the Positive operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.4
    class ExpPositive < Expression
      include UnaryOperation
      def initialize(val)
        @val = val
      end

      # symbol of expression
      def sym
        "+"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_UNARY
      end

      # reduce expression if available
      # @param parent [Base] parent element
      def reduce(parent)
        if @val.kind_of? ECMA262Numeric
          parent.replace(self, @val)
        end
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :number
      def ecma262_typeof
        :number
      end
    end

    # Class of the Negative operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.4
    class ExpNegative < Expression
      include UnaryOperation
      def initialize(val)
        @val = val
      end

      # symbol of expression
      def sym
        "-"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_UNARY
      end

      # reduce expression if available
      # @param parent [Base] parent element
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

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :number
      def ecma262_typeof
        :number
      end
    end

    # Class of the Bitwise Not operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.4
    class ExpBitwiseNot < Expression
      include UnaryOperation
      def initialize(val)
        @val = val
      end

      # symbol of expression
      def sym
        "~"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_UNARY
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :number
      def ecma262_typeof
        :number
      end
    end

    # Class of the Logical Not operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.4
    class ExpLogicalNot < Expression
      include UnaryOperation
      def initialize(val)
        @val = val
      end

      # symbol of expression
      def sym
        "!"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_UNARY
      end

      # reduce expression if available
      # @param parent [Base] parent element
      def reduce(parent)
        if @val.kind_of? ECMA262Numeric and (@val.to_js == "0" || @val.to_js == "1")
          return
        end

        if (e = to_ecma262_boolean) != nil and @val.side_effect? == false
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

      # Returns results of ToBoolean()
      #
      # Returns _true_ or _false_ if trivial,
      # otherwise nil.
      #
      # @return [Boolean]
      #
      # @see http://www.ecma-international.org/ecma-262 ECMA262 9.2
      def to_ecma262_boolean
        return nil unless @val.respond_to? :to_ecma262_boolean
        return nil if @val.to_ecma262_boolean.nil?
        !@val.to_ecma262_boolean
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
        if @val.respond_to? :to_ecma262_number
          v = @val.to_ecma262_number
          return nil if v.nil?
          v == 0 ? 1 : 0
        end
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :boolean
      def ecma262_typeof
        :boolean
      end
    end

    # Class of the Multiprication operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.5
    class ExpMul < Expression
      include BinaryOperation

      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "*"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_MULTIPLICATIVE
      end

      # reduce expression if available
      # @param parent [Base] parent element
      def reduce(parent)
        # A * B
        if @val.respond_to? :to_ecma262_number and @val2.respond_to? :to_ecma262_number
          v = @val.to_ecma262_number
          v2 = @val2.to_ecma262_number
          if !v.nil? and !v2.nil?
            parent.replace(self, ECMA262Numeric.new(v * v2))
          end
        end
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :number
      def ecma262_typeof
        :number
      end
    end

    # Class of the Division operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.5
    class ExpDiv < Expression
      include BinaryOperation

      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "/"
      end
      # @return [Fixnum] expression priority
      def priority
        PRIORITY_MULTIPLICATIVE
      end
    end

    # Class of the Remainder operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.5
    class ExpMod < Expression
      include BinaryOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "%"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_MULTIPLICATIVE
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :number
      def ecma262_typeof
        :number
      end
    end

    # Class of the Additionr operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.6
    class ExpAdd < Expression
      include BinaryOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "+"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_ADDITIVE
      end

      # reduce expression if available
      # @param parent [Base] parent element
      def reduce(parent)
        #
        # String + String/
        # a + b = a.concat(b)
        if @val.kind_of? ECMA262String or @val2.kind_of? ECMA262String
          if @val.respond_to? :to_ecma262_string and @val2.respond_to? :to_ecma262_string
            v = @val.to_ecma262_string
            v2 = @val2.to_ecma262_string
            if !v.nil? and !v2.nil?
              new_str = ECMA262String.new(v + v2)
              parent.replace(self, new_str)
            end
          end
        #
        # Numeric + Numeric
        #
        elsif @val.respond_to? :to_ecma262_number and @val2.respond_to? :to_ecma262_number
          #
          #11.6.3 Applying the Additive Operators to Numbers(TODO)
          #
          # N + M => (N + M)
          v = @val.to_ecma262_number
          v2 = @val2.to_ecma262_number
          if !v.nil? and !v2.nil?
            parent.replace(self, ECMA262Numeric.new(v + v2))
          end
        end
      end
    end
    # Class of the Subtraction operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.6
    class ExpSub < Expression
      include BinaryOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "-"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_ADDITIVE
      end

      # reduce expression if available
      # @param parent [Base] parent element
      def reduce(parent)
        # A - B
        if @val.respond_to? :to_ecma262_number and @val2.respond_to? :to_ecma262_number
          v = @val.to_ecma262_number
          v2 = @val2.to_ecma262_number
          if !v.nil? and !v2.nil?
            parent.replace(self, ECMA262Numeric.new(v - v2))
          end
        end
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :number
      def ecma262_typeof
        :number
      end
    end

    # Class of the Left Shift operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.7
    class ExpLShift < Expression
      include BinaryOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "<<"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_SHIFT
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :number
      def ecma262_typeof
        :number
      end
    end
    # Class of the Right Shift operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.7
    class ExpRShift < Expression
      include BinaryOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        ">>"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_SHIFT
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :number
      def ecma262_typeof
        :number
      end
    end
    # Class of the Unsigned Right Shift operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.7
    class ExpURShift < Expression
      include BinaryOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        ">>>"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_SHIFT
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :number
      def ecma262_typeof
        :number
      end
    end
    # Class of the Less-than operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.8
    class ExpLt < Expression
      include BinaryOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "<"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_RELATIONAL
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :boolean
      def ecma262_typeof
        :boolean
      end
    end

    # Class of the Greater-than operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.8
    class ExpGt < Expression
      include BinaryOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        ">"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_RELATIONAL
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :boolean
      def ecma262_typeof
        :boolean
      end
    end
    # Class of the Less-than-or-equal operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.8
    class ExpLtEq < Expression
      include BinaryOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "<="
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_RELATIONAL
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :boolean
      def ecma262_typeof
        :boolean
      end
    end
    # Class of the Greater-than-or-equal operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.8
    class ExpGtEq < Expression
      include BinaryOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        ">="
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_RELATIONAL
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :boolean
      def ecma262_typeof
        :boolean
      end
    end
    # Class of the instanceof operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.8
    class ExpInstanceOf < Expression
      include BinaryOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "instanceof"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_RELATIONAL
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :boolean
      def ecma262_typeof
        :boolean
      end
    end
    # Class of the in operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.8
    class ExpIn < Expression
      include BinaryOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "in"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_RELATIONAL
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :boolean
      def ecma262_typeof
        :boolean
      end
    end
    # Class of the Equals operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.9
    class ExpEq < Expression
      include BinaryOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "=="
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_EQUALITY
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :boolean
      def ecma262_typeof
        :boolean
      end
    end
    # Class of the Does-not-equals operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.9
    class ExpNotEq < Expression
      include BinaryOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "!="
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_EQUALITY
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :boolean
      def ecma262_typeof
        :boolean
      end
    end
    # Class of the Strict Equals operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.9
    class ExpStrictEq < Expression
      include BinaryOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "==="
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_EQUALITY
      end

      # reduce expression if available
      # @param parent [Base] parent element
      def reduce(parent)
        if @val.respond_to?(:ecma262_typeof) and @val2.respond_to?(:ecma262_typeof) and
           (t = @val.ecma262_typeof) == @val2.ecma262_typeof and !t.nil?
          parent.replace(self, ExpEq.new(@val, @val2))
        end
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :boolean
      def ecma262_typeof
        :boolean
      end
    end
    # Class of the Strict Does-not-equals operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.9
    class ExpStrictNotEq < Expression
      include BinaryOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "!=="
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_EQUALITY
      end

      # reduce expression if available
      # @param parent [Base] parent element
      def reduce(parent)
        if @val.respond_to?(:ecma262_typeof) and @val2.respond_to?(:ecma262_typeof) and
           (t = @val.ecma262_typeof) == @val2.ecma262_typeof and !t.nil?
          parent.replace(self, ExpNotEq.new(@val, @val2))
        end
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :boolean
      def ecma262_typeof
        :boolean
      end
    end
    # Class of the Bitwise And operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.10
    class ExpAnd < Expression
      include BinaryOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "&"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_BITWISE_AND
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :number
      def ecma262_typeof
        :number
      end
    end

    # Class of the Bitwise Xor operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.10
    class ExpXor < Expression
      include BinaryOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "^"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_BITWISE_XOR
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :number
      def ecma262_typeof
        :number
      end
    end

    # Class of the Bitwise Or operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.10
    class ExpOr < Expression
      include BinaryOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "|"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_BITWISE_OR
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] :number
      def ecma262_typeof
        :number
      end
    end

    # Class of the Bitwise Logical And operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.11
    class ExpLogicalAnd < Expression
      include BinaryOperation

      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "&&"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_LOGICAL_AND
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
        return nil if !(@val.respond_to? :to_ecma262_boolean)
        return nil if @val.to_ecma262_boolean == nil
        return false if @val.to_ecma262_boolean == false
        return nil if !(@val2.respond_to? :to_ecma262_boolean)
        return nil if @val2.to_ecma262_boolean == nil
        return false if @val2.to_ecma262_boolean == false
        true
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] typeof val if typeof val equals to val2
      def ecma262_typeof
        if @val.respond_to? :ecma262_typeof and @val2.respond_to? :ecma262_typeof
           if @val.ecma262_typeof == @val2.ecma262_typeof
             return @val.ecma262_typeof
           end
        end
        nil
      end
    end
    # Class of the Bitwise Logical Or operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.11
    class ExpLogicalOr < Expression
      include BinaryOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "||"
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_LOGICAL_OR
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
        return nil if !(@val.respond_to? :to_ecma262_boolean)
        return nil if @val.to_ecma262_boolean == nil
        return true if @val.to_ecma262_boolean == true
        return nil if !(@val2.respond_to? :to_ecma262_boolean)
        return nil if @val2.to_ecma262_boolean == nil
        return true if @val2.to_ecma262_boolean == true
        false
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] typeof val if typeof val equals to val2
      def ecma262_typeof
        if @val.respond_to? :ecma262_typeof and @val2.respond_to? :ecma262_typeof
          if @val.ecma262_typeof == @val2.ecma262_typeof
            return @val.ecma262_typeof
          end
        end
        nil
      end
    end
    # Class of the Conditional operator expression element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.12
    class ExpCond < Expression
      attr_reader :val, :val2, :val3
      alias :cond :val

      def initialize(val, val2, val3)
        @val = val
        @val2 = val2
        @val3 = val3
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_CONDITIONAL
      end

      # remove parenthesis if possible
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

      # add parenthesis if need
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

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@val.deep_dup, @val2.deep_dup, @val3.deep_dup)
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if from .eql? @val
          @val = to
        elsif from .eql? @val2
          @val2 = to
        elsif from .eql? @val3
          @val3 = to
        end
      end

      # Traverses this children and itself with given block.
      # @see Base#traverse
      def traverse(parent, &block)
        @val.traverse(self, &block)
        @val2.traverse(self, &block)
        @val3.traverse(self, &block)
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and
          @val == obj.val and
          @val2 == obj.val2 and
          @val3 == obj.val3
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        "#{@val.to_js(options)}?#{@val2.to_js(options)}:#{@val3.to_js(options)}"
      end

      # return results of 'typeof' operator.
      #
      # @return [Symbol] typeof val2 if typeof val2 equals to val3
      def ecma262_typeof
        if @val2.respond_to? :ecma262_typeof and @val3.respond_to? :ecma262_typeof
          if @val2.ecma262_typeof == @val3.ecma262_typeof
            return @val2.ecma262_typeof
          end
        end
        nil
      end
    end

    # Class of '=' operator
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.13
    class ExpAssign < Expression
      include AssignmentOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "="
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_ASSIGNMENT
      end
    end

    # Class of '/=' operator
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.13
    class ExpDivAssign < Expression
      include AssignmentOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "/="
      end
      # @return [Fixnum] expression priority
      def priority
        PRIORITY_ASSIGNMENT
      end
    end

    # Class of '*=' operator
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.13
    class ExpMulAssign < Expression
      include AssignmentOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "*="
      end
      # @return [Fixnum] expression priority
      def priority
        PRIORITY_ASSIGNMENT
      end
    end

    # Class of '%=' operator
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.13
    class ExpModAssign < Expression
      include AssignmentOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "%="
      end
      # @return [Fixnum] expression priority
      def priority
        PRIORITY_ASSIGNMENT
      end
    end

    # Class of '+=' operator
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.13
    class ExpAddAssign < Expression
      include AssignmentOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "+="
      end
      # @return [Fixnum] expression priority
      def priority
        PRIORITY_ASSIGNMENT
      end
    end

    # Class of '-=' operator
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.13
    class ExpSubAssign < Expression
      include AssignmentOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "-="
      end
      # @return [Fixnum] expression priority
      def priority
        PRIORITY_ASSIGNMENT
      end
    end

    # Class of '<<=' operator
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.13
    class ExpLShiftAssign < Expression
      include AssignmentOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "<<="
      end
      # @return [Fixnum] expression priority
      def priority
        PRIORITY_ASSIGNMENT
      end
    end

    # Class of '>>=' operator
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.13
    class ExpRShiftAssign < Expression
      include AssignmentOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        ">>="
      end
      # @return [Fixnum] expression priority
      def priority
        PRIORITY_ASSIGNMENT
      end
    end

    # Class of '>>>=' operator
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.13
    class ExpURShiftAssign < Expression
      include AssignmentOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        ">>>="
      end
      # @return [Fixnum] expression priority
      def priority
        PRIORITY_ASSIGNMENT
      end
    end

    # Class of '&=' operator
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.13
    class ExpAndAssign < Expression
      include AssignmentOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "&="
      end
      # @return [Fixnum] expression priority
      def priority
        PRIORITY_ASSIGNMENT
      end
    end

    # Class of '|=' operator
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.13
    class ExpOrAssign < Expression
      include AssignmentOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "|="
      end
      # @return [Fixnum] expression priority
      def priority
        PRIORITY_ASSIGNMENT
      end
    end

    # Class of '^=' operator
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.13
    class ExpXorAssign < Expression
      include AssignmentOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        "^="
      end
      # @return [Fixnum] expression priority
      def priority
        PRIORITY_ASSIGNMENT
      end
    end
    # Class of comma operator ( , )
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 11.14
    class ExpComma < Expression
      include BinaryOperation
      def initialize(val, val2)
        @val = val
        @val2 = val2
      end

      # symbol of expression
      def sym
        ","
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_COMMA
      end
    end
  end
end
