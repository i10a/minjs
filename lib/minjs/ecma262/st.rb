module Minjs
  module ECMA262
    class St < Base
      def to_exp?
        false
      end
    end

    #statement_list
    class StList < St
      attr_reader :statement_list
      #
      # statement_list: [statement, statement, ...]
      #
      def initialize(statement_list)
        @statement_list = statement_list
      end

      def grouping
        sl = @statement_list
        i = 0
        while i < sl.length
          st = sl[i]
          i0 = i
          prev = nil
          t = nil
          while st and st.to_exp?
            if prev and prev.to_exp?
              t = ECMA262::ExpComma.new(t, st.to_exp({}))
            elsif prev.nil?
              t = st.to_exp({})
            else
              break
            end
            prev = st
            i += 1
            st = sl[i]
          end
          if i0 != i and i - i0 >= 2
            sl[i0...i] = StExp.new(t)
            i = (i - i0 + 1)
          else
            i += 1
          end
        end
      end

      def replace(from, to)
        idx = @statement_list.index(from)
        if idx
          @statement_list[idx] = to
        end
      end

      def remove(st)
        @statement_list.delete(st)
      end

      def traverse(parent, &block)
        @statement_list.each do|st|
          st.traverse(self, &block)
        end
        yield self, parent
      end

      def to_js(options = {})
        concat options, @statement_list
      end

      def length
        @statement_list.length
      end

      def to_exp?
        @statement_list.each do |s|
          return false if s.to_exp? == false
        end
        return true
      end

      def to_exp(options)
        return nil if to_exp? == false
        t = @statement_list[0].to_exp(options)
        return t.to_exp(options) if @statement_list.length <= 1
        i = 1
        while(i < @statement_list.length)
          t = ExpComma.new(t, @statement_list[i])
          i += 1
        end
        t
      end

      def each(&block)
        @statement_list.each(&block)
      end

      def [](i)
        @statement_list[i]
      end

      def index(st)
        @statement_list.index(st)
      end
    end
    #
    # 12.1
    #
    class StBlock < St
      attr_reader :statement_list

      #statement_list:StList
      def initialize(statement_list)
        if statement_list.class == Array
          raise 'bad class'
        end
        @statement_list = statement_list
      end

      def traverse(parent, &block)
        @statement_list.traverse(self, &block)
        yield self, parent
      end

      def to_js(options = {})
        concat(options, "{", @statement_list, "}")
      end
      def to_exp?
        @statement_list.length == 1 and @statement_list[0].to_exp?
      end
      def to_exp(options)
        @statement_list[0].to_exp({})
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
    end

    #12.3 empty
    class StEmpty < St
      def initialize()
      end
      def traverse(parent, &block)
        yield self, parent
      end
      def to_js(options = {})
        ";"
      end
    end

    #12.4
    class StExp < St
      attr_reader :exp

      def initialize(exp)
        @exp = exp
      end
      def traverse(parent, &block)
        @exp.traverse(self, &block)
        yield self, parent
      end
      def to_js(options = {})
        concat(options, @exp, ";")
      end

      def to_exp(options)
        @exp
      end

      def to_exp?
        true
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

      def replace(from, to)
        if from == @then_st
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

      def to_js(options = {})
        if @else_st
          concat options, :if, "(", @cond, ")", @then_st, :else, @else_st
        else
          concat options, :if, "(", @cond, ")", @then_st
        end
      end

      def to_exp?
        return false if @then_st.to_exp? == false
        return false if @else_st and @else_st.to_exp? == false
        return true
      end

      def to_exp(options)
        return nil if to_exp? == false
        if @else_st
          then_exp = @then_st.to_exp(options)
          else_exp = @else_st.to_exp(options)
        else
          then_exp = @then_st.to_exp(options)
          else_exp = ECMA262Numeric.new(0)
        end
        if then_exp.kind_of? ExpComma
          then_exp = ExpParen.new(then_exp)
        end
        if else_exp.kind_of? ExpComma
          else_exp = ExpParen.new(else_exp)
        end

        if @cond.kind_of? ExpComma
          ExpCond.new(ExpParen.new(@cond), then_exp, else_exp)
        elsif @cond.kind_of? ExpAssign
          ExpCond.new(ExpParen.new(@cond), then_exp, else_exp)
        else
          ExpCond.new(@cond, then_exp, else_exp)
        end
      end
    end

    #12.6
    class StWhile < St
      def initialize(exp, statement)
        @exp, @statement = exp, statement
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
    end

    class StDoWhile < St
      def initialize(exp, statement)
        @exp, @statement = exp, statement
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
    end

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
        @exp2.traverse(self, &block)
        @exp3.traverse(self, &block)
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
#        if options[:compress_var]
#          t = concat({:for_args => true}.merge(options), :for, "(", _var_decl_list, ";", @exp2, ";", @exp3, ")")
#        else
          t = concat({:for_args => true}.merge(options), :for, "(", _var_decl_list, ";", @exp2, ";", @exp3, ")")
#        end
        concat options, t, statement
      end
    end

    class StFor < St
      def initialize(exp1, exp2, exp3, statement)
        @exp1 = exp1
        @exp2 = exp2
        @exp3 = exp3
        @statement = statement
      end

      def replace(from, to)
        if from == @statement
          @statement = to
        end
      end

      def traverse(parent, &block)
        @exp1.traverse(self, &block)
        @exp2.traverse(self, &block)
        @exp3.traverse(self, &block)
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
    end

    class StForInVar < St
      attr_reader :context

      def initialize(context, var_decl, exp2, statement)
        @context = context
        @var_decl = var_decl
        @exp2 = exp2
        @statement = statement
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

#        if options[:compress_var]
#          concat options, :for, "(", _var_decl, :in, @exp2, ")", statement
#        else
        concat options, :for, "(", :var, _var_decl, :in, @exp2, ")", statement
#        end
      end
    end

    class StForIn < St
      def initialize(exp1, exp2, statement)
        @exp1 = exp1
        @exp2 = exp2
        @statement = statement
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
    end

    #12.7
    class StContinue < St
      def initialize(exp = nil)
        @exp = exp
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
    end

    #12.8
    class StBreak < St
      def initialize(exp = nil)
        @exp = exp
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
    end

    #12.9
    class StReturn < St
      def initialize(exp = nil)
        @exp = exp
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

      def to_js(options = {})
        if @exp
          concat options, :return, @exp, ";"
        else
          concat options, :return, ";"
        end
      end
    end
    #12.10
    class StWith < St
      def initialize(exp, statement)
        @exp = exp
        @statement = statement
      end

      def traverse(parent, &block)
        @exp.traverse(self, &block)
        @statement.traverse(self, &block)
        yield self, parent
      end

      def to_js(options = {})
        concat options, :with, "(", @exp, ")","{", @statement, "}"
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
    end
    #12.12
    class StLabelled < St
      def initialize(id, statement)
        @id = id
        @statement = statement
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
    end

    #12.13
    class StThrow < St
      def initialize(exp)
        @exp = exp
      end

      def traverse(parent, &block)
        @exp.traverse(self, &block)
        yield self, parent
      end

      def to_js(options = {})
        concat options, :throw, @exp, ";"
      end
    end

    #12.14
    class StTry < St
      def initialize(try, catch, finally)
        @try = try
        @catch = catch
        @finally = finally
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
        else
          raise 'unknown'
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
    end
    #12.15
    class StDebugger < St
      def traverse
        yield self, parent
      end
      def to_js(options = {})
        concat options, :debugger, ";"
      end
    end
    #13 function
    class StFunc < St
      attr_reader :name
      attr_reader :args
      attr_reader :statement
      attr_reader :context
      attr_reader :decl

      def initialize(context, name, args, statements, decl = false)
        @name = name
        @args = args
        @statements = statements #=> Prog
        @context = context
        @decl = decl
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
        concat options, :function, @name, '(', _args, ")", "{", @statements, "}"
      end
    end
  end
end
