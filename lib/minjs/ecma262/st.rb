module Minjs
  module ECMA262
    class St < Base
      def to_exp?
        false
      end

      def to_return?
        false
      end

      def priority
        999
      end

      def last_statement
        puts "warning: #{self.class}: last_statement not implement"
      end
    end

    #
    # 12.1
    #
    class StBlock < St
      attr_reader :statement_list

      #statement_list:StList
      def initialize(statement_list)
        @statement_list = statement_list
      end

      def deep_dup
        self.class.new(@statement_list.deep_dup)
      end

      def traverse(parent, &block)
        @statement_list.traverse(self, &block)
        yield self, parent
      end

      def to_js(options = {})
        concat(options, "{", @statement_list, "}")
      end

      def to_exp?
        t = @statement_list.statement_list.select{|s|
          s.class != StEmpty
        }
        t.length == 1 and t[0].to_exp?
      end

      def to_exp(options = {})
        statement_list.remove_empty_statement
        @statement_list[0].to_exp({})
      end

      def to_statement?
        t = @statement_list.statement_list.select{|s|
          s.class != StEmpty
        }
        t.length == 1
      end

      def to_statement
        statement_list.remove_empty_statement
        @statement_list[0]
      end

      def last_statement
        list = [self]
        t = @statement_list.statement_list.select{|s|
          s.class != StEmpty
        }
        return [nil] if t[-1].nil?
        list.concat(t[-1].last_statement)
      end
    end
    #
    # 12.2
    #
    class StVar < St
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

      def deep_dup
        self.class.new(@context,
                       @vars.collect{|x,y|
                         [x.deep_dup, y ? y.deep_dup : nil]
                       })
      end

      def replace(from, to)
        @vars.each do |x|
          if x[0] == from
            x[0] = to
            break
          elsif x[1] and x[1] == from
            x[1] = to
            break
          end
        end
      end

      def traverse(parent, &block)
        @vars.each do |x|
          x[0].traverse(self, &block)
          if x[1]
            x[1].traverse(self, &block)
          end
        end
        yield self, parent
      end

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
      end

      def add_paren
        @vars.each do |x|
          if x[1] and x[1].priority > PRIORITY_ASSIGNMENT
            x[1] = ExpParen.new(x[1])
          end
        end
        self
      end

      def last_statement
        [self]
      end
    end

    #12.3 empty
    class StEmpty < St
      def initialize()
      end

      def deep_dup
        self.class.new()
      end

      def traverse(parent, &block)
        yield self, parent
      end

      def to_js(options = {})
        ";"
      end
      def last_statement
        [nil]
      end
    end

    #12.4
    class StExp < St
      attr_reader :exp

      def initialize(exp)
        @exp = exp
      end

      def deep_dup
        self.class.new(@exp.deep_dup)
      end

      def replace(from, to)
        if @exp == from
          @exp = to
        end
      end

      def traverse(parent, &block)
        @exp.traverse(self, &block)
        yield self, parent
      end

      def to_js(options = {})
        concat(options, @exp, ";")
      end

      def to_exp(options = {})
        @exp
      end

      def to_exp?
        true
      end

      def remove_paren
        if @exp.kind_of? ExpParen
          @exp = @exp.val if @exp.remove_paren?
        end
      end

      def add_paren
        self
      end

      def last_statement
        [self]
      end
    end

    #12.5
    class StIf < St
      attr_reader :then_st, :else_st, :cond

      def initialize(cond, then_st, else_st)
        @cond = cond
        @then_st = then_st
        @else_st = else_st
      end

      def deep_dup
        self.class.new(@cond.deep_dup, @then_st.deep_dup, @else_st.deep_dup)
      end

      def replace(from, to)
        if from == @cond
          @cond = to
        elsif from == @then_st
          @then_st = to
        elsif from == @else_st
          @else_st = to
        end
      end

      def traverse(parent, &block)
        @cond.traverse(self, &block)
        @then_st.traverse(self, &block)
        if @else_st
          @else_st.traverse(self, &block)
        end
        yield self, parent
      end

      def deep_dup
        self.class.new(@cond.deep_dup, @then_st.deep_dup, @else_st ? @else_st.deep_dup : nil)
      end

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
        cond = ExpParen.new(@cond)
        then_exp = ExpParen.new(then_st.exp ? then_st.exp : ExpVoid.new(ExpParen.new(ECMA262Numeric.new(0))))
        else_exp = ExpParen.new(else_st.exp ? else_st.exp : ExpVoid.new(ExpParen.new(ECMA262Numeric.new(0))))
        StReturn.new(ExpCond.new(cond, then_exp, else_exp))
      end

      def to_exp?
        if !@else_st
          return false if @then_st.to_exp? == false
        else
          return false if @then_st.to_exp? == false
          return false if @else_st.to_exp? == false
        end
        return true
      end

      def to_exp(options = {})
        return nil if to_exp? == false
        if !@else_st
          then_exp = @then_st.to_exp(options)
          if @cond.kind_of? ExpLogicalNot
            return ExpParen.new(ExpLogicalOr.new(ExpParen.new(@cond.val), ExpParen.new(then_exp)))
          else
            return ExpParen.new(ExpLogicalAnd.new(ExpParen.new(@cond), ExpParen.new(then_exp)))
          end
        else
          then_exp = ExpParen.new(@then_st.to_exp(options))
          else_exp = ExpParen.new(@else_st.to_exp(options))
        end

        if @cond.kind_of? ExpLogicalNot
          ExpCond.new(ExpParen.new(@cond.val), else_exp, then_exp)
        else
          ExpCond.new(ExpParen.new(@cond), then_exp, else_exp)
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

      def last_statement
        list = [self]
        if @else_st
          list.concat @else_st.last_statement
        else
          list.concat @then_st.last_statement
        end
      end
    end

    #12.6
    class StWhile < St
      attr_reader :exp, :statement

      def initialize(exp, statement)
        @exp, @statement = exp, statement
      end

      def deep_dup
        self.class.new(@exp.deep_dup, @statement.deep_dup)
      end

      def replace(from, to)
        if from == @statement
          @statement = to
        end
      end

      def traverse(parent, &block)
        @exp.traverse(self, &block)
        @statement.traverse(self, &block)
        yield self, parent
      end

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

      def last_statement
        list = [self]
        list.concat @statement.last_statement
      end
    end

    class StDoWhile < St
      def initialize(exp, statement)
        @exp, @statement = exp, statement
      end

      def deep_dup
        self.class.new(@exp.deep_dup, @statement.deep_dup)
      end

      def replace(from, to)
        if from == @statement
          @statement = to
        end
      end

      def traverse(parent, &block)
        @exp.traverse(self, &block)
        @statement.traverse(self, &block)
        yield self, parent
      end

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

      def last_statement
        list = [self]
        list.concat @statement.last_statement
      end
    end

    #
    # 12.6.3 the for statement
    #
    class StFor < St
      attr_reader :exp1, :exp2, :exp3, :statement

      def initialize(exp1, exp2, exp3, statement)
        @exp1 = exp1
        @exp2 = exp2
        @exp3 = exp3
        @statement = statement
      end

      def deep_dup
        self.class.new(@exp1 && @exp1.deep_dup,
                       @exp2 && @exp2.deep_dup,
                       @exp3 && @exp3.deep_dup,
                       @statement.deep_dup)
      end

      def replace(from, to)
        if from == @exp1
          @exp1 = to
        elsif from == @exp2
          @exp2 = to
        elsif from == @exp3
          @exp3 = to
        elsif from == @statement
          @statement = to
        end
      end

      def traverse(parent, &block)
        @exp1.traverse(self, &block) if @exp1
        @exp2.traverse(self, &block) if @exp2
        @exp3.traverse(self, &block) if @exp3
        @statement.traverse(self, &block)
        yield self, parent
      end

      def to_js(options = {})
        if @statement.kind_of? StBlock and @statement.statement_list.length == 1
          statement = @statement.statement_list.statement_list[0]
        else
          statement = @statement
        end

        concat options, :for, "(", @exp1, ";", @exp2, ";", @exp3, ")", statement
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

      def last_statement
        list = [self]
        list.concat @statement.last_statement
      end
    end

    #
    # for(var i=0,... ; ; )
    #
    class StForVar < St
      attr_reader :context

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

      def deep_dup
        self.class.new(@context,
                       @var_decl_list.collect{|x,y|
                         [x.deep_dup, y.deep_dup]
                       },
                       @exp2 && @exp2.deep_dup,
                       @exp3 && @exp3.deep_dup,
                       @statement.deep_dup)
      end

      def replace(from, to)
        if from == @statement
          @statement = to
        end
      end

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
        yield self, parent
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
        t = concat({:for_args => true}.merge(options), :for, "(var", _var_decl_list, ";", @exp2, ";", @exp3, ")")
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

      def last_statement
        list = [self]
        list.concat @statement.last_statement
      end
    end

    class StForIn < St
      def initialize(exp1, exp2, statement)
        @exp1 = exp1
        @exp2 = exp2
        @statement = statement
      end

      def deep_dup
        self.class.new(@exp1.deep_dup, @exp2.deep_dup, @statement.deep_dup)
      end

      def replace(from, to)
        if from == @statement
          @statement = to
        end
      end

      def traverse(parent, &block)
        @exp1.traverse(self, &block)
        @exp2.traverse(self, &block)
        @statement.traverse(self, &block)
        yield self, parent
      end

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

      def last_statement
        list = [self]
        list.concat @statement.last_statement
      end
    end

    class StForInVar < St
      attr_reader :context

      def initialize(context, var_decl, exp2, statement)
        @context = context
        @var_decl = var_decl
        @exp2 = exp2
        @statement = statement
      end

      def deep_dup
        self.class.new(@context,
                       [@var_decl[0].deep_dup, @var_decl[1] ? @var_decl[1].deep_dup : nil],
                       @exp2.deep_dup,
                       @statement.deep_dup)
      end

      def traverse(parent, &block)
        @var_decl[0].traverse(self, &block)
        @var_decl[1].traverse(self, &block) if @var_decl[1]
        @exp2.traverse(self, &block)
        @statement.traverse(self, &block)
        yield self, parent
      end

      def replace(from, to)
        if from == @statement
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

      def last_statement
        list = [self]
        list.concat @statement.last_statement
      end
    end


    #12.7
    class StContinue < St
      def initialize(exp = nil)
        @exp = exp
      end

      def deep_dup
        self.class.new(@exp)
      end

      def traverse(parent, &block)
        @exp.traverse(self, &block) if @exp
        yield self, parent
      end

      def to_js(options = {})
        if @exp
          concat options, :continue, @exp, ";"
        else
          concat options, :continue, ";"
        end
      end

      def last_statement
        [self]
      end
    end

    #12.8
    class StBreak < St
      def initialize(exp = nil)
        @exp = exp
      end

      def deep_dup
        self.class.new(@exp)
      end

      def traverse(parent, &block)
        @exp.traverse(self, &block) if @exp
        yield self, parent
      end

      def to_js(options = {})
        if @exp
          concat options, :break, @exp, ";"
        else
          concat options, :break, ";"
        end
      end

      def last_statement
        [self]
      end
    end

    #12.9
    class StReturn < St
      attr_reader :exp

      def initialize(exp = nil)
        @exp = exp
      end

      def deep_dup
        self.class.new(@exp)
      end

      def deep_dup
        self.class.new(exp ? exp.deep_dup : nil)
      end

      def replace(from, to)
        if from == @exp
          @exp = to
        end
      end

      def traverse(parent, &block)
        @exp.traverse(self, &block) if @exp
        yield self, parent
      end

      def to_return?
        true
      end

      def to_return
        self
      end

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

      def last_statement
        [self]
      end
    end
    #12.10
    class StWith < St
      def initialize(exp, statement)
        @exp = exp
        @statement = statement
      end

      def deep_dup
        self.class.new(@exp)
      end

      def traverse(parent, &block)
        @exp.traverse(self, &block)
        @statement.traverse(self, &block)
        yield self, parent
      end

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

      def last_statement
        list = [self]
        list.concat @statement.last_statement
      end
    end
    #12.11
    class StSwitch < St
      #
      # block: [condition, blocks]
      #
      def initialize(exp, blocks)
        @exp = exp
        @blocks = blocks
      end

      def deep_dup
        self.class.new(@exp,
                       @blocks.collect{|x, y|
                         [x.deep_dup, y.deep_dup]
                       })
      end

      def replace(from, to)
        if @exp == from
          @exp = to
        elsif @blocks == from
          @blocks = to
        end
      end

      def traverse(parent, &blocks)
        @exp.traverse(self, &blocks)
        @blocks.each do |b|
          if b[0]
            b[0].traverse(self, &blocks)
          end
          b[1].traverse(self, &blocks)
        end
        yield self, parent
      end

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

      def last_statement
        list = [self]
      end
    end
    #12.12
    class StLabelled < St
      def initialize(id, statement)
        @id = id
        @statement = statement
      end

      def deep_dup
        self.class.new(@id, @statement)
      end

      def replace(from, to)
        if from == @id
          @id = to
        elsif from == @statement
          @statement = to
        end
      end

      def traverse(parent, &block)
        @id.traverse(self, &block)
        @statement.traverse(self, &block)
        yield self, parent
      end

      def to_js(options = {})
        concat options, @id, ":", @statement
      end

      def last_statement
        list = [self]
        list.concat @statement.last_statement
      end
    end

    #12.13
    class StThrow < St
      def initialize(exp)
        @exp = exp
      end

      def deep_dup
        self.class.new(@exp)
      end

      def traverse(parent, &block)
        @exp.traverse(self, &block)
        yield self, parent
      end

      def to_js(options = {})
        concat options, :throw, @exp, ";"
      end

      def last_statement
        [self]
      end
    end

    #12.14
    class StTry < St
      attr_reader :context
      attr_reader :catch_context
      attr_reader :try, :catch, :finally

      def initialize(context, catch_context, try, catch, finally)
        @context = context
        @catch_context = catch_context
        @try = try
        @catch = catch
        @finally = finally
      end

      def deep_dup
        self.class.new(@try, @catch, @finally)
      end

      def replace(from, to)
        if from == @try
          @try = to
        elsif from == @catch[0]
          @catch[0] = to
        elsif from == @catch[1]
          @catch[1] = to
        elsif from == @finally
          @finally = to
        end
      end

      def traverse(parent, &block)
        @try.traverse(self, &block)
        if @catch
          @catch[0].traverse(self, &block)
          @catch[1].traverse(self, &block)
        end
        @finally.traverse(self, &block) if @finally
        yield self, parent
      end

      def to_js(options = {})
        if @catch and @finally
          concat(options, :try, @try, :catch, "(", @catch[0], ")", @catch[1], :finally, @finally)
        elsif @catch
          concat(options, :try, @try, :catch, "(", @catch[0], ")", @catch[1])
        else
          concat(options, :try, @try, :finally, @finally)
        end
      end
      def last_statement
        [self]
      end
    end

    #12.15
    class StDebugger < St
      def deep_dup
        self.class.new
      end

      def traverse
        yield self, parent
      end
      def to_js(options = {})
        concat options, :debugger, ";"
      end
      def last_statement
        [self]
      end
    end

    #
    # 13 function / function expression
    #
    # 11.1.5 getter/setter
    #
    class StFunc < St
      attr_reader :name
      attr_reader :args
      attr_reader :statements
      attr_reader :context

      def initialize(context, name, args, statements, options = {})
        @name = name
        @args = args #=> array
        @statements = statements #=> Prog
        @context = context
        @decl = options[:decl]
        @getter = options[:getter]
        @setter = options[:setter]
      end

      def priority
        10
      end

      def deep_dup
        self.class.new(@context, @name ? @name.deep_dup : nil,
                       @args.collect{|args|args.deep_dup},
                       @statements.deep_dup,
                       {decl: @decl, getter: @getter, setter: @setter})
      end

      def traverse(parent, &block)
        @name.traverse(self, &block) if @name
        @args.each do |arg|
          arg.traverse(self, &block)
        end
        @statements.traverse(self, &block)
        yield self, parent
      end

      def to_js(options = {})
        _args = @args.collect{|x|x.to_js(options)}.join(",")
        if @getter
          concat options, :get, @name, '(', _args, ")", "{", @statements, "}"
        elsif @setter
          concat options, :set, @name, '(', _args, ")", "{", @statements, "}"
        else
          concat options, :function, @name, '(', _args, ")", "{", @statements, "}"
        end
      end

      def getter?
        @getter
      end

      def setter?
        @setter
      end

      def decl?
        @decl
      end

      def last_statement
        [self]
      end
    end
  end
end
