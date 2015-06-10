module Minjs
  module ECMA262
    # Base class of ECMA262 statement element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12
    class Statement < Base
      # return true if statement can convert to expression.
      def to_exp?
        false
      end

      # return true if statement can convert to return statement.
      def to_return?
        false
      end

      # @return [Fixnum] expression priority
      def priority
        999
      end

      # return true if statement can convert to empty statement.
      def empty?
        false
      end
    end

    # Base class of ECMA262 Block element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.1
    class StBlock < Statement
      attr_reader :statement_list

      # @param statement_list [StatementList] statement list
      def initialize(statement_list)
        if statement_list.kind_of? Array
          @statement_list = StatementList.new(statement_list)
        else
          @statement_list = statement_list
        end
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@statement_list.deep_dup)
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if from == @statement_list
          @statement_list = to
        end
      end

      # Traverses this children and itself with given block.
      #
      # @see Base#traverse
      def traverse(parent, &block)
        @statement_list.traverse(self, &block)
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and
          @statement_list == obj.statement_list
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        concat(options, "{", @statement_list, "}")
      end

      # true if statement can convert to expression
      def to_exp?
        t = @statement_list.statement_list.select{|s|
          s.class != StEmpty
        }
        t.length == 1 and t[0].to_exp?
      end

      # Converts block to expression and returns it.
      def to_exp(options = {})
        @statement_list.statement_list.select{|s|
          s.class != StEmpty
        }[0].to_exp.deep_dup

      end

      def to_statement?
        t = @statement_list.statement_list.select{|s|
          s.class != StEmpty
        }
        t.length == 1 || t.length == 0
      end

      def to_statement
        t = @statement_list.statement_list.select{|s|
          s.class != StEmpty
        }

        if t[0]
          t[0].deep_dup
        else
          StEmpty.new
        end
      end

      def to_return?
        to_statement? and to_statement.to_return?
      end

      def to_return
        to_statement.to_return
      end

      def empty?
        @statement_list.statement_list.select{|s|
          s.class != StEmpty
        }.length == 0
      end

      def [](i)
        @statement_list[i]
      end

      def remove_empty_statement
        statement_list.remove_empty_statement
      end
    end
    # Base class of ECMA262 VariableStatement element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.2
    class StVar < Statement
      attr_reader :vars
      attr_reader :context
      #
      # vars:
      #  [[name0,init0],[name1,init1],...]
      #
      def initialize(context, vars)
        @vars = vars
        @context = context
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@context,
                       @vars.collect{|x,y|
                         [x.deep_dup, y ? y.deep_dup : nil]
                       })
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        @vars.each do |x|
          if x[0] .eql? from
            x[0] = to
            break
          elsif x[1] and x[1] .eql? from
            x[1] = to
            break
          end
        end
      end

      # Traverses this children and itself with given block.
      def traverse(parent, &block)
        @vars.each do |x|
          x[0].traverse(self, &block)
          if x[1]
            x[1].traverse(self, &block)
          end
        end
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and @vars == obj.vars
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
          t = concat(options, :var, @vars.collect{|x|
                       if x[1]
                         concat options, x[0], '=', x[1]
                       else
                         concat options, x[0]
                       end
                     }.join(","))
        if t.length > 0
          concat(options, t, ";")
        else
          ""
        end
      end

      def normalization
        # if var has no initializer, move it to latter
        v1 = []
        v2 = []
        @vars.each do |x|
          if x[1].nil?
            v2.push(x)
          else
            v1.push(x)
          end
        end
        @vars = v1.concat(v2)
      end

      def remove_paren
        @vars.each do |x|
          if x[1] and x[1].kind_of? ExpParen and x[1].val.priority <= PRIORITY_ASSIGNMENT
            x[1] = x[1].val
          end
        end
        self
      end

      def add_paren
        @vars.each do |x|
          if x[1] and x[1].priority > PRIORITY_ASSIGNMENT
            x[1] = ExpParen.new(x[1])
          end
        end
        self
      end
    end

    # Base class of ECMA262 EmptyStatement element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.2
    class StEmpty < Statement
      def initialize()
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new()
      end

      # Traverses this children and itself with given block.
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
        ";;"
      end

      def empty?
        true
      end
    end

    # Base class of ECMA262 ExpressionStatement element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.4
    class StExp < Statement
      attr_reader :exp

      def initialize(exp)
        @exp = exp
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@exp.deep_dup)
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if @exp .eql? from
          @exp = to
        end
      end

      # Traverses this children and itself with given block.
      def traverse(parent, &block)
        @exp.traverse(self, &block)
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and @exp == obj.exp
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        concat(options, @exp, ";")
      end

      # Converts statement to expression and returns it.
      def to_exp(options = {})
        @exp.deep_dup
      end

      # true if statement can convert to expression
      def to_exp?
        true
      end

      def remove_paren
        if @exp.kind_of? ExpParen
          @exp = @exp.val if @exp.remove_paren?
        end
        self
      end

      def add_paren
        self
      end
    end

    # Base class of ECMA262 IfStatement element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.5
    class StIf < Statement
      attr_reader :then_st, :else_st, :cond

      def initialize(cond, then_st, else_st)
        @cond = cond
        @then_st = then_st
        @else_st = else_st
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if from .eql? @cond
          @cond = to
        elsif from .eql? @then_st
          @then_st = to
        elsif from .eql? @else_st
          @else_st = to
        end
      end

      # Traverses this children and itself with given block.
      def traverse(parent, &block)
        @cond.traverse(self, &block)
        @then_st.traverse(self, &block)
        if @else_st
          @else_st.traverse(self, &block)
        end
        yield parent, self
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@cond.deep_dup, @then_st.deep_dup, @else_st ? @else_st.deep_dup : nil)
      end

      # compare object
      def ==(obj)
        self.class == obj.class and
          @cond == obj.cond and
          @then_st == obj.then_st and
          @else_st == obj.else_st
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        if @else_st
          concat options, :if, "(", @cond, ")", @then_st, :else, @else_st
        else
          concat options, :if, "(", @cond, ")", @then_st
        end
      end

      def to_return?
        if !@else_st
          return false
        else
          return true if @then_st.class == StReturn and @else_st.class == StReturn
        end
      end

      def to_return
        then_exp = then_st.exp;
        if @else_st
          else_exp = else_st.exp;
        end

        if then_exp.nil?
          then_exp = ExpVoid.new(ECMA262Numeric.new(0))
        end
        if @else_st and else_exp.nil?
          else_exp = ExpVoid.new(ECMA262Numeric.new(0))
        end
        if @else_st
          ret = add_remove_paren StReturn.new(ExpCond.new(@cond, then_exp, else_exp))
        else
          ret = add_remove_paren StReturn.new(ExpLogicalAnd.new(@cond, then_exp))
        end
        ret
      end

      # true if statement can convert to expression
      def to_exp?
        if !@else_st
          return false if @then_st.to_exp? == false
        else
          return false if @then_st.to_exp? == false
          return false if @else_st.to_exp? == false
        end
        return true
      end

      # Converts statement to expression and returns it.
      def to_exp(options = {})
        cond = @cond.deep_dup
        if !@else_st
          then_exp = @then_st.to_exp(options)
          if(options[:cond])
            if cond.kind_of? ExpLogicalNot
              add_remove_paren ExpCond.new(cond.val, ECMA262Numeric.new(0), then_exp)
            else
              add_remove_paren ExpCond.new(cond, then_exp, ECMA262Numeric.new(0))
            end
          else
            if cond.kind_of? ExpLogicalNot
              add_remove_paren ExpLogicalOr.new(cond.val, then_exp)
            else
              add_remove_paren ExpLogicalAnd.new(cond, then_exp)
            end
          end
        else
          then_exp = @then_st.to_exp(options)
          else_exp = @else_st.to_exp(options)

          if cond.kind_of? ExpLogicalNot
            add_remove_paren ExpCond.new(cond.val, else_exp, then_exp)
          else
            add_remove_paren ExpCond.new(cond, then_exp, else_exp)
          end
        end
      end

      def remove_paren
        if @cond.kind_of? ExpParen
          @cond = @cond.val
        end
        self
      end

      def add_paren
        self
      end

      def remove_empty_statement
        if @then_st.kind_of? StBlock
          @then_st.remove_empty_statement
        end
        if @else_st.kind_of? StBlock
          @else_st.remove_empty_statement
        end
      end
    end

    # Base class of ECMA262 'while' IterationStatement element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.6.2
    class StWhile < Statement
      attr_reader :exp, :statement

      def initialize(exp, statement)
        @exp, @statement = exp, statement
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@exp.deep_dup, @statement.deep_dup)
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if from .eql? @statement
          @statement = to
        end
      end

      # Traverses this children and itself with given block.
      def traverse(parent, &block)
        @exp.traverse(self, &block)
        @statement.traverse(self, &block)
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and
          @exp == obj.exp and
          @statement == obj.statement
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        if @statement.kind_of? StBlock and @statement.statement_list.length == 1
          statement = @statement.statement_list.statement_list[0]
        else
          statement = @statement
        end

        concat(options, :while, "(", @exp, ")", statement)
      end

      def remove_paren
        if @exp.kind_of? ExpParen
          @exp = @exp.val
        end
        self
      end

      def add_paren
        self
      end
    end

    # Base class of ECMA262 'do-while' IterationStatement element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.6.1
    class StDoWhile < Statement
      attr_reader :exp, :statement

      def initialize(exp, statement)
        @exp, @statement = exp, statement
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@exp.deep_dup, @statement.deep_dup)
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if from .eql? @statement
          @statement = to
        end
      end

      # Traverses this children and itself with given block.
      def traverse(parent, &block)
        @exp.traverse(self, &block)
        @statement.traverse(self, &block)
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and
          @exp == obj.exp and
          @statement == obj.statement
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        if @statement.kind_of? StBlock and @statement.statement_list.length == 1
          statement = @statement.statement_list.statement_list[0]
        else
          statement = @statement
        end

        concat options, :do, statement, :while, "(", @exp, ")", ";"
      end

      def remove_paren
        if @exp.kind_of? ExpParen
          @exp = @exp.val
        end
        self
      end

      def add_paren
        self
      end
    end

    # Base class of ECMA262 'for(;;)' IterationStatement element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.6.3
    class StFor < Statement
      attr_reader :exp1, :exp2, :exp3, :statement

      def initialize(exp1, exp2, exp3, statement)
        @exp1 = exp1
        @exp2 = exp2
        @exp3 = exp3
        @statement = statement
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@exp1 && @exp1.deep_dup,
                       @exp2 && @exp2.deep_dup,
                       @exp3 && @exp3.deep_dup,
                       @statement.deep_dup)
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if from .eql? @exp1
          @exp1 = to
        elsif from .eql? @exp2
          @exp2 = to
        elsif from .eql? @exp3
          @exp3 = to
        elsif from .eql? @statement
          @statement = to
        end
      end

      # Traverses this children and itself with given block.
      def traverse(parent, &block)
        @exp1.traverse(self, &block) if @exp1
        @exp2.traverse(self, &block) if @exp2
        @exp3.traverse(self, &block) if @exp3
        @statement.traverse(self, &block)
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and
          @exp1 == obj.exp1 and
          @exp2 == obj.exp2 and
          @exp3 == obj.exp3 and
          @statement == obj.statement
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        if @statement.kind_of? StBlock and @statement.statement_list.length == 1
          statement = @statement.statement_list.statement_list[0]
        else
          statement = @statement
        end

        concat options, :for, "(", @exp1, ";;", @exp2, ";;", @exp3, ")", statement
      end

      def remove_paren
        if @exp1.kind_of? ExpParen
          @exp1 = @exp1.val
        end
        if @exp2.kind_of? ExpParen
          @exp2 = @exp2.val
        end
        if @exp3.kind_of? ExpParen
          @exp3 = @exp3.val
        end
        self
      end

      def add_paren
        self
      end
    end

    # Base class of ECMA262 'for(var;;)' IterationStatement element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.6.3
    class StForVar < Statement
      attr_reader :context
      attr_reader :var_decl_list, :exp2, :exp3, :statement

      #
      # var_decl_list
      #  [[name0, init0],[name1, init1], ...]
      #
      def initialize(context, var_decl_list, exp2, exp3, statement)
        @context = context
        @var_decl_list = var_decl_list
        @exp2 = exp2
        @exp3 = exp3
        @statement = statement
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@context,
                       @var_decl_list.collect{|x,y|
                         [x.deep_dup, y.deep_dup]
                       },
                       @exp2 && @exp2.deep_dup,
                       @exp3 && @exp3.deep_dup,
                       @statement.deep_dup)
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if from .eql? @statement
          @statement = to
        end
      end

      # Traverses this children and itself with given block.
      def traverse(parent, &block)
        @var_decl_list.each do |x|
          x[0].traverse(self, &block)
          if x[1]
            x[1].traverse(self, &block)
          end
        end
        @exp2.traverse(self, &block) if @exp2
        @exp3.traverse(self, &block) if @exp3
        @statement.traverse(self, &block)
        yield parent, self
      end

      #
      # for(var ...; ; ) => for(...; ; )
      #
      def to_st_for
        tt = nil
        @var_decl_list.each{|x|
          if x[1]
            t = ExpAssign.new(x[0], x[1])
          else
            t = x[0]
          end
          if tt.nil?
            tt = t
          else
            tt = ExpComma.new(tt, t)
          end
        }
        StFor.new(tt, @exp2, @exp3, @statement)
      end

      # compare object
      def ==(obj)
        self.class == obj.class and
          @var_decl_list == obj.var_decl_list and
          @exp2 == obj.exp2 and
          @exp3 == obj.exp3 and
          @statement == obj.statement
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        if @statement.kind_of? StBlock and @statement.statement_list.length == 1
          statement = @statement.statement_list.statement_list[0]
        else
          statement = @statement
        end

        _var_decl_list = @var_decl_list.collect{|x|
          if x[1] #with initialiser
            concat options, x[0], '=', x[1]
          else
            concat options, x[0]
          end
        }.join(",")
        t = concat(options, :for, "(var", _var_decl_list, ";;", @exp2, ";;", @exp3, ")")
        concat options, t, statement
      end

      def remove_paren
        @var_decl_list.each do|x|
          if x[1] and x[1].kind_of? ExpParen
            x[1] = x[1].val
          end
        end
        if @exp2.kind_of? ExpParen
          @exp2 = @exp2.val
        end
        if @exp3.kind_of? ExpParen
          @exp3 = @exp3.val
        end
        self
      end

      def add_paren
        self
      end
    end

    # Base class of ECMA262 'for(in)' IterationStatement element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.6.4
    class StForIn < Statement
      attr_reader :exp1, :exp2, :statement

      def initialize(exp1, exp2, statement)
        @exp1 = exp1
        @exp2 = exp2
        @statement = statement
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@exp1.deep_dup, @exp2.deep_dup, @statement.deep_dup)
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if from .eql? @statement
          @statement = to
        end
      end

      # Traverses this children and itself with given block.
      def traverse(parent, &block)
        @exp1.traverse(self, &block)
        @exp2.traverse(self, &block)
        @statement.traverse(self, &block)
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and
          @exp1 == obj.exp1 and
          @exp2 == obj.exp2 and
          @statement == obj.statement
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        if @statement.kind_of? StBlock and @statement.statement_list.length == 1
          statement = @statement.statement_list.statement_list[0]
        else
          statement = @statement
        end

        concat options, :for, '(', @exp1, :in, @exp2, ')', statement
      end

      def remove_paren
        if @exp1.kind_of? ExpParen and @exp1.val.priority <= PRIORITY_LEFT_HAND_SIDE
          @exp1 = @exp1.val
        end
        if @exp2.kind_of? ExpParen
          @exp2 = @exp2.val
        end
        self
      end

      def add_paren
        if @exp1.priority > PRIORITY_LEFT_HAND_SIDE
          @exp1 = ExpParen.new(@exp1)
        end
        self
      end
    end

    # Base class of ECMA262 'for(var in)' IterationStatement element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.6.4
    class StForInVar < Statement
      attr_reader :context
      attr_reader :var_decl, :exp2, :statement

      def initialize(context, var_decl, exp2, statement)
        @context = context
        @var_decl = var_decl
        @exp2 = exp2
        @statement = statement
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@context,
                       [@var_decl[0].deep_dup, @var_decl[1] ? @var_decl[1].deep_dup : nil],
                       @exp2.deep_dup,
                       @statement.deep_dup)
      end

      # Traverses this children and itself with given block.
      def traverse(parent, &block)
        @var_decl[0].traverse(self, &block)
        @var_decl[1].traverse(self, &block) if @var_decl[1]
        @exp2.traverse(self, &block)
        @statement.traverse(self, &block)
        yield parent, self
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if from .eql? @statement
          @statement = to
        end
      end

      def to_st_for_in
        if @var_decl[1]
          t = ExpAssign.new(@var_decl[0], @var_decl[1])
        else
          t = @var_decl[0]
        end
        StForIn.new(t, @exp2, @statement)
      end

      # compare object
      def ==(obj)
        self.class == obj.class and
          @var_decl == obj.var_decl and
          @exp2 == obj.exp2 and
          @statement == obj.statement
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        if @statement.kind_of? StBlock and @statement.statement_list.length == 1
          statement = @statement.statement_list.statement_list[0]
        else
          statement = @statement
        end

        if @var_decl[1] #with initialiser
          _var_decl = concat(options, @var_decl[0], '=', @var_decl[1])
        else
          _var_decl = concat(options, @var_decl[0])
        end

        concat options, :for, "(", :var, _var_decl, :in, @exp2, ")", statement
      end

      def remove_paren
        if @var_decl[1] and @var_decl[1].kind_of? ExpParen
          @var_decl[1] = @var_decl[1].val
        end
        if @exp2.kind_of? ExpParen
          @exp2 = @exp2.val
        end
        self
      end

      def add_paren
        self
      end
    end


    # Base class of ECMA262 ContinueStatement element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.7
    class StContinue < Statement
      attr_reader :exp

      def initialize(exp = nil)
        @exp = exp
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@exp ? @exp.deep_dup : nil)
      end

      # Traverses this children and itself with given block.
      def traverse(parent, &block)
        @exp.traverse(self, &block) if @exp
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and
          @exp == obj.exp
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        if @exp
          concat options, :continue, @exp, ";"
        else
          concat options, :continue, ";"
        end
      end
    end

    # Base class of ECMA262 BreakStatement element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.8
    class StBreak < Statement
      attr_reader :exp

      def initialize(exp = nil)
        @exp = exp
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@exp ? @exp.deep_dup : nil)
      end

      # Traverses this children and itself with given block.
      def traverse(parent, &block)
        @exp.traverse(self, &block) if @exp
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and
          @exp == obj.exp
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        if @exp
          concat options, :break, @exp, ";"
        else
          concat options, :break, ";"
        end
      end
    end

    # Base class of ECMA262 ReturnStatement element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.9
    class StReturn < Statement
      attr_reader :exp

      def initialize(exp = nil)
        @exp = exp
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(exp ? exp.deep_dup : nil)
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if from .eql? @exp
          @exp = to
        end
      end

      # Traverses this children and itself with given block.
      def traverse(parent, &block)
        @exp.traverse(self, &block) if @exp
        yield parent, self
      end

      def to_return?
        true
      end

      def to_return
        self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and @exp == obj.exp
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        if @exp
          concat options, :return, @exp, ";"
        else
          concat options, :return, ";"
        end
      end

      def remove_paren
        if @exp.kind_of? ExpParen
          @exp = @exp.val
        end
        self
      end

      def add_paren
        self
      end
    end

    # Base class of ECMA262 WithStatement element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.10
    class StWith < Statement
      attr_reader :exp, :statement, :context

      def initialize(context, exp, statement)
        @context = context
        @exp = exp
        @statement = statement
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@context, @exp.deep_dup, @statement.deep_dup)
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if @exp .eql? from
          @exp = to
        elsif @statement = to
          @statement = to
        end
      end

      # Traverses this children and itself with given block.
      def traverse(parent, &block)
        @exp.traverse(self, &block)
        @statement.traverse(self, &block)
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and
          @exp == obj.exp and
          @statement == obj.statement
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        concat options, :with, "(", @exp, ")", @statement
      end

      def remove_paren
        if @exp.kind_of? ExpParen
          @exp = @exp.val
        end
        self
      end

      def add_paren
        self
      end
    end

    # Base class of ECMA262 SwitchStatement element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.11
    class StSwitch < Statement
      attr_reader :exp, :blocks

      #
      # block: [condition, blocks]
      #
      def initialize(exp, blocks)
        @exp = exp
        @blocks = blocks
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@exp.deep_dup,
                       @blocks.collect{|x, y|
                         [
                           x ? x.deep_dup : nil,
                           y ? y.deep_dup : nil
                         ]
                       })
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if @exp .eql? from
          @exp = to
        elsif @blocks .eql? from
          @blocks = to
        end
      end

      # Traverses this children and itself with given block.
      def traverse(parent, &blocks)
        @exp.traverse(self, &blocks)
        @blocks.each do |b|
          if b[0]
            b[0].traverse(self, &blocks)
          end
          b[1].traverse(self, &blocks)
        end
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and
          @exp == obj.exp and
          @blocks == obj.blocks
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        t = concat(options, :switch, "(", @exp, ")", "{")
        @blocks.each do |b|
          if b[0]
            t = concat(options, t, :case, b[0], ":", b[1])
          else
            t = concat(options, t, :default, ":", b[1])
          end
        end
        t = concat(options, t, "}")
      end

      def remove_paren
        if @exp.kind_of? ExpParen
          @exp = @exp.val
        end
        @blocks.each do |b|
          if b[0] and b[0].kind_of? ExpParen
            b[0] = b[0].val
          end
        end
        self
      end

      def add_paren
        self
      end
    end
    # Base class of ECMA262 LabelledStatement element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.12
    class StLabelled < Statement
      attr_reader :label, :statement

      def initialize(label, statement)
        @label = label
        @statement = statement
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@label.deep_dup, @statement.deep_dup)
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if from .eql? @label
          @label = to
        elsif from .eql? @statement
          @statement = to
        end
      end

      # Traverses this children and itself with given block.
      def traverse(parent, &block)
        @label.traverse(self, &block)
        @statement.traverse(self, &block)
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and
          @label == obj.label and
          @statement == obj.statement
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        concat options, @label, ":", @statement
      end
    end

    # Base class of ECMA262 ThrowStatement element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.13
    class StThrow < Statement
      attr_reader :exp

      def initialize(exp)
        @exp = exp
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@exp.deep_dup)
      end

      # Traverses this children and itself with given block.
      def traverse(parent, &block)
        @exp.traverse(self, &block)
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and
          @exp == obj.exp
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        concat options, :throw, @exp, ";"
      end
    end

    # Base class of ECMA262 TryStatement element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.14
    class StTry < Statement
      attr_reader :context
      attr_reader :try, :catch, :finally

      def initialize(context, try, catch, finally)
        @context = context
        @try = try
        @catch = catch
        @finally = finally
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@context,
                       @try.deep_dup,
                       @catch ? [@catch[0].deep_dup, @catch[1].deep_dup] : nil,
                       @finally ? @finally.deep_dup : nil)
      end

      # Replaces children object.
      # @see Base#replace
      def replace(from, to)
        if from .eql? @try
          @try = to
        elsif from .eql? @catch[0]
          @catch[0] = to
        elsif from .eql? @catch[1]
          @catch[1] = to
        elsif from .eql? @finally
          @finally = to
        end
      end

      # Traverses this children and itself with given block.
      def traverse(parent, &block)
        @try.traverse(self, &block)
        if @catch
          @catch[0].traverse(self, &block)
          @catch[1].traverse(self, &block)
        end
        @finally.traverse(self, &block) if @finally
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and
          self.try == obj.try and
          self.catch == obj.catch and
          self.finally == obj.finally
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        if @catch and @finally
          concat(options, :try, @try, :catch, "(", @catch[0], ")", @catch[1], :finally, @finally)
        elsif @catch
          concat(options, :try, @try, :catch, "(", @catch[0], ")", @catch[1])
        else
          concat(options, :try, @try, :finally, @finally)
        end
      end
    end

    # Base class of ECMA262 DebuggerStatement element.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.15
    class StDebugger < Statement
      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new
      end

      # Traverses this children and itself with given block.
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
        concat options, :debugger, ";"
      end
    end

    # Base class of ECMA262 FunctionDeclaration / FunctionExpression
    # element
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 13, 11.1.5
    class StFunc < Statement
      attr_reader :name
      attr_reader :args
      attr_reader :statements
      attr_reader :context

      def initialize(context, name, args, statements, options = {})
        @context = context
        @name = name
        @args = args #=> array
        @statements = statements #=> Prog
        @decl = options[:decl]
        @getter = options[:getter]
        @setter = options[:setter]
      end

      # @return [Fixnum] expression priority
      def priority
        PRIORITY_PRIMARY
      end

      # duplicate object
      # @see Base#deep_dup
      def deep_dup
        self.class.new(@context, @name ? @name.deep_dup : nil,
                       @args.collect{|args|args.deep_dup},
                       @statements.deep_dup,
                       {decl: @decl, getter: @getter, setter: @setter})
      end

      # Traverses this children and itself with given block.
      def traverse(parent, &block)
        @name.traverse(self, &block) if @name
        @args.each do |arg|
          arg.traverse(self, &block)
        end
        @statements.traverse(self, &block)
        yield parent, self
      end

      # compare object
      def ==(obj)
        self.class == obj.class and
          @name == obj.name and
          @args == obj.args and
          @statements == obj.statements
      end

      # Returns a ECMAScript string containg the representation of element.
      # @see Base#to_js
      def to_js(options = {})
        _args = @args.collect{|x|x.to_js(options)}.join(",")
        if @getter
          concat options, :get, @name, "()", "{", @statements, "}"
        elsif @setter
          concat options, :set, @name, '(', _args, ")", "{", @statements, "}"
        else
          concat options, :function, @name, '(', _args, ")", "{", @statements, "}"
        end
      end

      # @return [Boolean] true if expression is kind of LeftHandSideExpression.
      def left_hand_side_exp?
        true
      end

      # Returns true if this object is setter in object
      def getter?
        @getter
      end

      # Returns true if this object is setter in object
      def setter?
        @setter
      end

      # Returns true if this object is function declaration
      def decl?
        @decl
      end
    end
  end
end
