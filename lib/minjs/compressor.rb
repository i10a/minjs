#!/usr/bin/env ruby
# coding: utf-8
require 'minjs/lex'
require 'minjs/ecma262'
require 'minjs/literal'
require 'minjs/statement'
require 'minjs/expression'
require 'minjs/func'
require 'minjs/program'
require 'minjs/exceptions'
require 'minjs/version'
require 'logger'

module Minjs
  class Compressor
    include Literal
    include Statement
    include Exp
    include Func
    include Program
    include Ctype

    attr_reader :prog

    def initialize(options = {})
      @logger = options[:logger]
      if !@logger
        @logger = Logger.new(STDERR)
        @logger.level = (options[:debug_level] || Logger::WARN)
        @logger.formatter = proc{|severity, datetime, progname, message|
          "#{message}\n"
        }
      end
    end

    def debug
      puts @prog.to_js()
    end

    def to_js(options = {})
      remove_empty_statement
      @prog.to_js(options).sub(/;;\Z/, ";")
    end

    def remove_empty_statement(node = @prog)
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::StatementList
          st.remove_empty_statement
        end
      }
      self
    end

    def compress(data, options = {})
      @logger.info '* parse'
      parse(data)

      if options[:only_parse]
        return
      end

      algo = [
        :reorder_function_decl,
        :simple_replacement,
        :reorder_var,
        :assignment_after_var,
        :grouping_statement,
        :block_to_statement,
        :reduce_if,
        :if_to_cond,
        :optimize_if_return,
        :compress_var,
        :reduce_exp,
        :grouping_statement,
        :block_to_statement,
        :if_to_cond,
        :optimize_if_return2,
        :block_to_statement,
        :add_remove_paren,
      ]
      algo.each do |a|
        if (options.empty? || options[:all] || options[a]) && !options[("no_" + a.to_s).to_sym]
          @logger.info "* #{a}"
          __send__(a, @prog)
        end
      end

      @heading_comments.reverse.each do |c|
        @prog.source_elements.source_elements.unshift(c)
      end
      self
    end

    def parse(data)
      @lex = Minjs::Lex.new(data, :logger => @logger)
      @global_context = ECMA262::Context.new
      @heading_comments = []
      @lex.eval_lit{
        while a = @lex.next_input_element(nil) and (a.ws? or a.lt?)
          @heading_comments.push(a)
        end
        nil
      }
      @prog = source_elements(@lex, @global_context)

      remove_empty_statement
      self
    end

    def next_sym(s)
      def c2i(c)
        c = c.ord
        if c >= 0x30 and c <= 0x39
          c = c - 0x30
        elsif c >= 0x61 and c <= 0x7a
          c = c - 0x61 + 10
        elsif c >= 0x41 and c <= 0x5a
          c = c - 0x41 + 10 + 26
        elsif c == 0x5f
          c = 62
        elsif c == 0x24
          c = 63
        end
      end
      def i2c(c)
        if c < 10
          c = "%c" % (0x30 + c)
        elsif c < 10 + 26
          c = "%c" % (0x61 + c - 10)
        elsif c < 10 + 26 + 26
          c = "%c" % (0x41 + c - 10 -  26)
        elsif c < 63
          c = "_"
        elsif c < 64
          c = "$"
        end
      end

      v = 0
      s.to_s.split("").each do |x|
        v *= 64
        v += c2i(x)
      end

      while true
        v += 1
        ret = []
        vv = v
        while vv > 0
          ret.unshift(i2c(vv % 64))
          vv /= 64
        end
        ret = ret.join("")
        if ECMA262::IdentifierName.reserved?(ret.to_sym)
          ;
        elsif ret.to_s.match(/^\d/)
          ;
        else
          break
        end
      end
      ret.to_sym

    end

    def grouping_statement(node = @prog)
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::StatementList
          st.grouping
        end
      }
      add_remove_paren
      self
    end

    def reorder_function_decl(node = @prog)
      flist = []
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::StFunc and parent.kind_of? ECMA262::StatementList and st.decl?
          if parent.index(st)
            flist.push([st, parent])
          end
        end
      }
      flist.reverse.each do |st, parent|
        parent.remove(st)
        sl = parent.statement_list
        if sl[0].kind_of? ECMA262::StExp and sl[0].exp.kind_of? ECMA262::ECMA262String and sl[0].exp.val == "use strict"
          sl[1,0] = st
        else
          sl.unshift(st)
        end
      end
      self
    end

    def reorder_var(node = @prog)
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::Prog
          vars = nil
          context = st.context
          #
          # collect all of var variable in this function
          #
          var_vars = {}
          context.var_env.record.binding.each do|k, v|
            if v and v[:_parameter_list].nil? and !v[:value].kind_of?(ECMA262::StFunc)
              var_vars[k] = true
            end
          end
          #
          # traverse block and convert var statement to assignment expression
          # if variable has initializer
          #
          st.traverse(parent){|st2, parent2|
            if st2.kind_of? ECMA262::StVar and st2.context.var_env == context.var_env
              exp = nil
              st2.vars.each do |name, initializer|
                if initializer
                  if exp.nil?
                    exp = ECMA262::ExpAssign.new(name, initializer)
                  else
                    exp = ECMA262::ExpComma.new(exp, ECMA262::ExpAssign.new(name, initializer))
                  end
                end
              end
              if exp
                parent2.replace(st2, ECMA262::StExp.new(exp))
              else
                parent2.replace(st2, ECMA262::StEmpty.new())
              end
            elsif st2.kind_of? ECMA262::StForVar and st2.context.var_env == context.var_env
              parent2.replace(st2, st2.to_st_for)
            elsif st2.kind_of? ECMA262::StForInVar and st2.context.var_env == context.var_env
              parent2.replace(st2, st2.to_st_for_in)
            end
          }
          if var_vars.length > 0
            elems = st.source_elements.source_elements
            v = ECMA262::StVar.new(
              context,
              var_vars.collect do |k, v|
                [ECMA262::IdentifierName.new(context, k)]
              end
            )

            idx = 0
            elems.each do |e|
              found = false
              if e.kind_of? ECMA262::StFunc and e.decl?
                ;
              elsif e.kind_of? ECMA262::StExp and e.exp.kind_of? ECMA262::ECMA262String and e.exp.val == "use strict"
                ;
              else
                e.traverse(nil){|ee, pp|
                  if ee.kind_of? ECMA262::IdentifierName and var_vars[ee.val.to_sym]
                    found = true
                    break
                  end
                }
              end
              break if found
              idx += 1
            end

            if idx == 0
              elems.unshift(v)
            else
              elems[idx..0] = v
            end
            st.source_elements.remove_empty_statement
          end
        end
        self
      }
      self
    end

    def add_remove_paren(node = @prog)
      node.traverse(nil) {|st, parent|
        if st.respond_to? :remove_paren
          st.remove_paren
          st.add_paren
        end
      }
      self
    end

    def remove_paren(node = @prog)
      add_remove_paren(node)
    end

    #
    # To determine removing "block" is available or not is difficult.
    # For example, next code's if-block must not be removed, because
    # "else" cluase combined to second "if" statement.
    #
    #  if(a){ //<= this block must not be removed
    #    while(true)
    #      if(b){
    #        ;
    #      }
    #  }
    #  else{
    #   ;
    #  }
    #
    # The next code's while-block must not be removed, because
    # "else" cluase combined to second "if" statement.
    #
    #  if(a)
    #    while(true){ //<= this block must not be removed
    #      if(b){
    #        ;
    #      }
    #    }
    #  else{
    #   ;
    #  }
    #
    # To solve this problem, first, every then-clause without block
    # converts to block statement. After converted, all blocks 
    # except then-clause can be removed safety.
    #
    def then_to_block(node = @prog)
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::StIf
          if !st.then_st.kind_of?(ECMA262::StBlock)
            st.replace(st.then_st, ECMA262::StBlock.new([st.then_st]))
          end
        end
      }
    end

    def block_to_statement(node = @prog)
      remove_empty_statement
      then_to_block
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::StBlock and !parent.kind_of?(ECMA262::StTry) and !parent.kind_of?(ECMA262::StIf)
            if st.to_statement?
              parent.replace(st, st.to_statement)
            end
        end
      }
      if_block_to_statement
    end

    def if_block_to_statement(node = @prog)
      remove_empty_statement
      # The "else" cluase's block can be removed always
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::StIf
          if st.else_st and st.else_st.kind_of? ECMA262::StBlock
            st.else_st.remove_empty_statement
          end

          if st.else_st and st.else_st.kind_of? ECMA262::StBlock and st.else_st.to_statement?
            st.replace(st.else_st, st.else_st.to_statement)
          end
        end
      }
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::StIf
          if st.then_st and st.then_st.kind_of? ECMA262::StBlock
            st.then_st.remove_empty_statement
          end
          if !st.else_st and st.then_st.kind_of? ECMA262::StBlock and st.then_st.to_statement?
            st.replace(st.then_st, st.then_st.to_statement)
          elsif st.then_st.kind_of? ECMA262::StBlock and st.then_st.to_statement?
            _st = st.then_st
            st2 = st.then_st.to_statement
            while true
              if st2.kind_of? ECMA262::StVar or st2.kind_of? ECMA262::StEmpty or
                st2.kind_of? ECMA262::StExp or st2.kind_of? ECMA262::StBlock or
                st2.kind_of? ECMA262::StDoWhile or st2.kind_of? ECMA262::StSwitch or
                st2.kind_of? ECMA262::StContinue or st2.kind_of? ECMA262::StBreak or
                st2.kind_of? ECMA262::StReturn or st2.kind_of? ECMA262::StThrow or
                st2.kind_of? ECMA262::StTry or st2.kind_of? ECMA262::StDebugger
                st.replace(st.then_st, st.then_st.to_statement)
                break;
              elsif st2.kind_of? ECMA262::StWhile or
                   st2.kind_of? ECMA262::StFor or
                   st2.kind_of? ECMA262::StForIn or
                   st2.kind_of? ECMA262::StForVar or
                   st2.kind_of? ECMA262::StForInVar or
                   st2.kind_of? ECMA262::StWith or
                   st2.kind_of? ECMA262::StLabelled
                st2 = st2.statement
              elsif st2.kind_of? ECMA262::StIf
                if st2.else_st
                  st2 = st2.else_st
                else
                  break
                end
              else #?
                break
              end
            end
          end
        end
      }
=begin
      node.traverse(nil) {|st0, parent|
        st = st0.deep_dup
        if st.kind_of? ECMA262::StIf
          if st.then_st and st.then_st.kind_of? ECMA262::StBlock
            st.then_st.remove_empty_statement
          end

          if st.then_st and st.then_st.kind_of? ECMA262::StBlock and st.then_st.to_statement?
            st.replace(st.then_st, st.then_st.to_statement)
          end

          _lex = Minjs::Lex.new(st.to_js)
          _context = ECMA262::Context.new
          _if = if_statement(_lex, _context)
          reduce_exp(_if)
          if _if == st #
            if st0.then_st and st0.then_st.kind_of? ECMA262::StBlock
              st0.then_st.remove_empty_statement
            end
            if st0.then_st and st0.then_st.kind_of? ECMA262::StBlock and st0.then_st.to_statement?
              st0.replace(st0.then_st, st0.then_st.to_statement)
            end
          else
            p '!='
            puts st.to_js
            puts _if.to_js
          end
        end
      }
=end
      self
    end

    #
    # if(a)b;else c;
    # =>
    # a?b:c
    #
    # if(a)b
    # =>
    # a&&b; or a?b:0;
    #
    # NOTE:
    # Sometimes, "conditional operator" will be shorter than
    # "logical and operator", because "conditional operator"'s
    # priority is lower than almost all other expressions.
    #
    def if_to_cond(node = @prog)
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::StIf
          if st.to_exp?
            t = ECMA262::StExp.new(st.to_exp({}))
            t2 = ECMA262::StExp.new(st.to_exp({cond: true}))
            if t2.to_js.length < t.to_js.length
              t = t2
            end
            add_remove_paren(t)
            simple_replacement(t)

            if t.to_js.length <= st.to_js.length
              parent.replace(st, t)
            end
          end
        end
      }
      if_to_return(node)
      self
    end
    #
    # if(a)return b;else return c;
    # => return a?b:c;
    #
    def if_to_return(node = @prog)
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::StIf
          if st.to_return?
            t = st.to_return
            add_remove_paren(t)
            simple_replacement(t)
            if t.to_js.length <= st.to_js.length
              parent.replace(st, t)
            end
          end
        end
      }
      self
    end

    #
    # if(a)return b;
    # return c;
    #
    # => return a?b:c;
    #
    def optimize_if_return(node = @prog)
      node.traverse(nil) {|st0, parent0|
        if st0.kind_of? ECMA262::StatementList
          st0.remove_empty_statement
          st = st0.deep_dup
          while true
            #check last statement
            ls = st.statement_list[-1]
            ls2 = st.statement_list[-2]
            if st.kind_of? ECMA262::SourceElements and !(ls.kind_of? ECMA262::StReturn)
              ls2 = ls
              ls = ECMA262::StReturn.new(ECMA262::ExpVoid.new(ECMA262::ECMA262Numeric.new(0)))
            end
            break if ls.nil?
            break if ls2.nil?
            break if !ls.to_return?
            break if !ls2.kind_of?(ECMA262::StIf)
            break if ls2.else_st
            break if !ls2.then_st.to_return?

#            if !ls2.then_st.kind_of? ECMA262::StIf and !ls2.then_st.to_return?
#              break
#            end
#            if ls2.then_st.kind_of? ECMA262::StIf and !ls2.then_to_return?
#              break
#            end

            then_exp = ls2.then_st.to_return.exp
            else_exp = ls.to_return.exp
            then_exp = ECMA262::ExpVoid.new(ECMA262::ECMA262Numeric.new(0)) if then_exp.nil?
            else_exp = ECMA262::ExpVoid.new(ECMA262::ECMA262Numeric.new(0)) if else_exp.nil?
            if ls2.cond.kind_of? ECMA262::ExpLogicalNot
              cond = ECMA262::ExpCond.new(ls2.cond.val, else_exp, then_exp)
            else
              cond = ECMA262::ExpCond.new(ls2.cond, then_exp, else_exp)
            end
            ret = ECMA262::StReturn.new(cond)
            #puts ret.to_js
            #puts ls2.to_js
            st.replace(ls2, ret)
            st.remove(ls)
          end
          if st0.to_js.length > st.to_js.length 
            parent0.replace(st0, st)
          end
        end
      }
      self
    end

    #
    # if(a)return b;else c;
    # =>
    # if(a)return b;c;
    #
    def optimize_if_return2(node = @prog)
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::StIf and st.else_st and parent.kind_of? ECMA262::StatementList
          st.remove_empty_statement
          if (st.then_st.kind_of? ECMA262::StBlock and st.then_st[-1].kind_of? ECMA262::StReturn) or
             st.then_st.kind_of? ECMA262::StReturn
            idx = parent.index(st)
            parent[idx+1..0] = st.else_st
            st.replace(st.else_st, nil)
          elsif (st.else_st.kind_of? ECMA262::StBlock and st.else_st[-1].kind_of? ECMA262::StReturn) or
             st.else_st.kind_of? ECMA262::StReturn
            idx = parent.index(st)
            parent[idx+1..0] = st.then_st
            st.instance_eval{
              @then_st = @else_st
              @else_st = nil
              @cond = ECMA262::ExpLogicalNot.new(@cond)
            }
          end
        end
      }
      self
    end

    def compress_var(node = @prog, options = {})
      func_scopes = []
      catch_scopes = []
      with_scopes = []
      #
      # ECMA262 10.2:
      #
      #  Usually a Lexical Environment is associated with some
      #  specific syntactic structure of ECMAScript code such as a
      #  FunctionDeclaration, a WithStatement, or a Catch clause of a
      #  TryStatement and a new Lexical Environment is created each
      #  time such code is evaluated.
      #
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::StFunc
          func_scopes.push([st, parent])
        elsif st.kind_of? ECMA262::StTry
          catch_scopes.push([st, parent])
        elsif st.kind_of? ECMA262::StWith
          with_scopes.push([st, parent])
        end
      }
      #
      # 10.2, 12.14
      #
      #eee = 'global';
      #function test()
      #{
      #  /*
      #    "eee" is local variable(belongs to this function)
      #    because var declaration is exist in this function.
      #    (see also catch's scope comment)
      #    So, global variable 'eee' is not changed.
      #  */
      #  eee = 'function';
      #  try{
      #    console.log(eee);	//=>function
      #    throw "exception";
      #  }
      #  catch(eee){
      #  /*
      #    The catch's variable scope will be created at execution time.
      #    so next var declaration should belong to "test" function.
      #  */
      #    var eee;
      #  /*
      #    In execution time, "eee" belongs to this 
      #    catch-clause's scope.
      #  */
      #    console.log(eee);	//=>exception
      #  /*
      #    Next function has its own scope and 'eee' belongs to its.
      #  */
      #    (function(){
      #      var eee;
      #      console.log(eee);	//=>undefined
      #    })();
      #  }
      #}
      #console.log(eee); 	//=>global
      #test();
      #
      catch_scopes.each{|st, parent|
        catch_context = ECMA262::Context.new
        catch_context.lex_env = st.context.lex_env.new_declarative_env()
        catch_context.var_env = st.context.var_env
        catch_context.lex_env.record.create_mutable_binding(st.catch[0], nil)
        catch_context.lex_env.record.set_mutable_binding(st.catch[0], :undefined, nil)
        st.catch[0].context = catch_context

        st.catch[1].traverse(parent){|st2|
          if st2.kind_of? ECMA262::IdentifierName and st2 == st.catch[0] and st2.binding_env == st.catch[0].binding_env
            st2.context = catch_context
          end
        }
        func_scopes.unshift([st, parent])
      }
#      with_scopes.each{|st, parent|
#        with_context = ECMA262::Context.new
#        with_context.lex_env = st.context.lex_env.new_declarative_env()
#        with_context.var_env = st.context.var_env
#        st.statement.traverse(st) {|st2|
#          if st2.kind_of? ECMA262::IdentifierName and st2.binding_env == st.context.var_env
#            st2.context = with_context
#            with_context.lex_env.record.create_mutable_binding(st2, nil)
#            with_context.lex_env.record.set_mutable_binding(st2, :undefined, nil)
#          end
#        }
#      }
      func_scopes.reverse!
      func_scopes.each {|st, parent|
        if st.kind_of? ECMA262::StFunc
          context = st.context
        elsif st.kind_of? ECMA262::StTry
          context = st.catch[0].context
        end
        var_sym = :a
        #
        # collect and counting all variables under this function
        #
        all_vars = {}
        var_vars = {}
        var_vars_list = []
        outer_vars = {}
        nesting_vars = {}
        nesting_vars_list = []

        st.traverse(parent) {|st2|
          #
          # Next, tring to rename var_vars(see bellow) to
          # new name.
          #
          # 1. outer_vars:
          #    Variables which locate out of this function(or global variable)
          #    Them name cannot be renamed
          # 2. nesting_vars:
          #    Variables which locate in the function of this function.
          #    Them name cannot be renamed
          # 3. var_vars:
          #    Variables which have same scope in this function.
          # 4. all_vars:
          #    All variables under this function.
          #
          #   a. If the new name is not in all_vars, the name can be renamed to it.
          #   b. If the new name belongs to var_vars, the name cannot be renamed.
          #   c. If the new name belongs to outer_vars the name cannot be renamed.
          #   d. If the new name belongs to nesting_vars, the name can be rename
          #      to it after renaming nesting_vars's name to another name.
          #
          if st2.kind_of? ECMA262::IdentifierName
            var_name = st2.val.to_sym
            #st2_var_env = st2.binding_env
            st2_lex_env = st2.binding_env(:lex)
            all_vars[var_name] ||= 0
            all_vars[var_name] += 1
            if st2_lex_env == nil #global
              outer_vars[var_name] ||= 0
              outer_vars[var_name] += 1
            elsif st2_lex_env == @global_context.lex_env #global
              outer_vars[var_name] ||= 0
              outer_vars[var_name] += 1
            elsif st2_lex_env == context.lex_env
              var_vars[var_name] ||= 0
              var_vars[var_name] += 1
              var_vars_list.push(st2)
            else
              e = st2.binding_env(:lex)
              while e
                e = e.outer
                if e == context.lex_env
                  nesting_vars[var_name] ||= 0
                  nesting_vars[var_name] += 1
                  nesting_vars_list.push(st2)
                  break
                end
                if e.nil?
                  outer_vars[var_name] ||= 0
                  outer_vars[var_name] += 1
                  break
                end
              end
            end
          end
        }
        unless var_vars[:eval]
          eval_flag = false
          st.traverse(parent) {|st2|
            if st2.kind_of? ECMA262::ExpCall and st2.name.to_js({}) == "eval"
              eval_flag = true
              break
            end
            if st2.kind_of? ECMA262::StWith
              eval_flag = true
              break
            end
          }
          if eval_flag
            next
          end
        end
        #
        # sort var_vars
        #
        var_vars_array = var_vars.sort {|(k1,v1), (k2,v2)| v2 <=> v1}
        #
        # create renaming table
        #
        rename_table = {}
        var_vars_array.each {|name, count|
          if name.nil?
            next #bug?
          end
          if name.length == 1
            #STDERR.puts "#{name}=>#{count}"
            next
          end
          #STDERR.puts "trying to rename #{name}(#{count})"
          while true
            #condition b
            if outer_vars[var_sym]
              #STDERR.puts "outer_vars has #{var_sym}"
            elsif var_vars[var_sym]
              #STDERR.puts "var_vars has #{var_sym}(#{var_vars[var_sym]})"
            #condigion c
            else #condition a&d
              #STDERR.puts "->#{var_sym}"
              break
            end
            var_sym = next_sym(var_sym)
          end
          #rename nesting_vars
          if nesting_vars[var_sym]
            #STDERR.puts "nesting_vars has #{var_sym}"
            nesting_vars_list.each do |x|
              #raise 'error' if x.binding_env(:var).nil?
              raise 'error' if x.binding_env(:lex).nil?
            end

            var_sym2 = "XXX#{var_sym.to_s}".to_sym
            while all_vars[var_sym2]
              var_sym2 = next_sym(var_sym2)
            end
            #STDERR.puts "#{var_sym}->#{var_sym2}"
            rl = {}
            nesting_vars_list.each do |x|
              if x.val.to_sym == var_sym
                _var_env = x.binding_env(:var)
                _lex_env = x.binding_env(:lex)
                rl[_var_env] = true
                rl[_lex_env] = true
              end
            end
            rl.keys.each do |_env|
              if _env && _env.record.binding[var_sym]
                _env.record.binding[var_sym2] = _env.record.binding[var_sym]
                _env.record.binding.delete var_sym
              end
            end

            nesting_vars_list.each do |x|
              if x.val.to_sym == var_sym
                x.instance_eval{
                  @val = var_sym2
                }
              end
              #raise 'error' if x.binding_env(:var).nil?
              raise x.to_js if x.binding_env(:lex).nil?
            end
          end
          rename_table[name] = var_sym
          var_sym = next_sym(var_sym)
        }
        var_vars_list.each {|st2|
          raise st2.to_js if st2.binding_env(:lex).nil?
        }

        rename_table.each do |name, new_name|
          if name != new_name
            if context.var_env.record.binding[name]
              context.var_env.record.binding[new_name] = context.var_env.record.binding[name]
              context.var_env.record.binding.delete(name)
            end
            if context.lex_env.record.binding[name]
              context.lex_env.record.binding[new_name] = context.lex_env.record.binding[name]
              context.lex_env.record.binding.delete(name)
            end
          end
        end

        var_vars_list.each {|st2|
            st2.instance_eval{
              if rename_table[@val]
                @val = rename_table[@val]
                #raise 'error' if st2.binding_env(:var).nil?
                raise st2.to_js if st2.binding_env(:lex).nil?
              end
            }
        }
      }
      self
    end

    def reduce_exp(node = @prog)
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::Exp
          st.reduce(parent)
        end
      }
      self
    end

    def simple_replacement(node = @prog)
      node.traverse(nil) {|st, parent|
        #
        #true => !0
        #false => !1
        #
        if st.kind_of? ECMA262::Boolean
          if st.true?
            parent.replace(st, ECMA262::ExpParen.new(ECMA262::ExpLogicalNot.new(ECMA262::ECMA262Numeric.new(0))))
          else
            parent.replace(st, ECMA262::ExpParen.new(ECMA262::ExpLogicalNot.new(ECMA262::ECMA262Numeric.new(1))))
          end
        #
        #if(true){<then>}else{<else>} => <then>
        #if(false){<then>}else{<else>} => <else>
        #
        elsif st.kind_of? ECMA262::StIf
          if st.cond.respond_to? :to_ecma262_boolean
            if st.cond.to_ecma262_boolean.nil?
              ;
            elsif st.cond.to_ecma262_boolean == true
              parent.replace(st, st.then_st)
            elsif st.cond.to_ecma262_boolean == false and st.else_st
              parent.replace(st, st.else_st)
            elsif st.cond.to_ecma262_boolean == false
              parent.replace(st, ECMA262::StEmpty.new)
            end
          end
        #
        # while(true) => for(;;)
        # while(false) => remove
        #
        elsif st.kind_of? ECMA262::StWhile and st.exp.respond_to? :to_ecma262_boolean
          if st.exp.to_ecma262_boolean.nil?
            ;
          elsif st.exp.to_ecma262_boolean
            parent.replace(st, ECMA262::StFor.new(nil,nil,nil, st.statement))
          else
            parent.replace(st, ECMA262::StEmpty.new)
          end
        #
        # new A() => (new A)
        #
        elsif st.kind_of? ECMA262::ExpNew and st.args and st.args.length == 0
          st.replace(st.args, nil)
          parent.add_paren.remove_paren
        #
        # !c?a:b => c?b:a
        # true?a:b => a
        # false?a:b => b
        #
        elsif st.kind_of? ECMA262::ExpCond
          if st.val.kind_of? ECMA262::ExpLogicalNot
            st.instance_eval{
              @val = @val.val
              t = @val2
              @val2 = @val3
              @val3 = t
            }
            simple_replacement(st)
          end

          if st.val.respond_to? :to_ecma262_boolean
            if st.val.to_ecma262_boolean.nil?
              ;
            elsif st.val.to_ecma262_boolean
              parent.replace(st, st.val2)
            else
              parent.replace(st, st.val3)
            end
          end
        #
        # A["B"] => A.N
        #
        elsif st.kind_of? ECMA262::ExpPropBrac and st.val2.kind_of? ECMA262::ECMA262String
          if idname?(st.val2.val)
            parent.replace(st, ECMA262::ExpProp.new(st.val, st.val2))
          elsif !st.val2.to_ecma262_number.nil? and (v=ECMA262::ECMA262Numeric.new(st.val2.to_ecma262_number)).to_ecma262_string == st.val2.to_ecma262_string
            st.replace(st.val2, v)
          end
        end
      }
      self
    end

    #
    # reduce_if
    #
    def reduce_if(node = @prog)
      retry_flag = true
      while retry_flag
        retry_flag = false
        node.traverse(nil) {|st, parent|
          if st.kind_of? ECMA262::StIf
            # if(a)
            #   if(b) ...;
            # if(a && b) ...;
            #
            if st.else_st.nil? and
              st.then_st.kind_of? ECMA262::StIf and st.then_st.else_st.nil?
              st.replace(st.cond, ECMA262::ExpLogicalAnd.new(st.cond, st.then_st.cond))
              st.replace(st.then_st, st.then_st.then_st)
            end
            #if(a)z;else;
            #if(a)z;else{}
            # => {if(a)z;}
            if st.else_st and st.else_st.empty?
              st.replace(st.else_st, nil)
              parent.replace(st, ECMA262::StBlock.new([st]))
              retry_flag = true
              break
            end
            #if(a);else z;
            #=>{if(!a)z};
            #if(a){}else z;
            #=>{if(!a)z};
            if st.then_st.empty? and st.else_st
              st.replace(st.cond, ECMA262::ExpLogicalNot.new(st.cond));
              else_st = st.else_st
              st.replace(st.else_st, nil)
              st.replace(st.then_st, else_st)
              parent.replace(st, ECMA262::StBlock.new([st]))
              retry_flag = true
              break
            end
            #if(a);
            # => a
            #if(a){}
            # => a
            if st.then_st.empty? and st.else_st.nil?
              parent.replace(st, ECMA262::StExp.new(st.cond))
            end
=begin
            #if(!(a&&b))
            #=>
            #if(!a||!b)
            if st.cond.kind_of? ECMA262::ExpLogicalNot and st.cond.val.kind_of? ECMA262::ExpParen and
              st.cond.val.val.kind_of? ECMA262::ExpLogicalAnd
              a = ECMA262::ExpLogicalNot.new(st.cond.val.val.val)
              b = ECMA262::ExpLogicalNot.new(st.cond.val.val.val2)
              r = ECMA262::ExpLogicalOr.new(a,b).add_remove_paren
              if r.to_js.length <= st.cond.to_js.length
                st.replace(st.cond, r)
              end
            end
            #if(!(a||b))
            #=>
            #if(!a&&!b)
            if st.cond.kind_of? ECMA262::ExpLogicalNot and st.cond.val.kind_of? ECMA262::ExpParen and
              st.cond.val.val.kind_of? ECMA262::ExpLogicalOr
              a = ECMA262::ExpLogicalNot.new(st.cond.val.val.val)
              b = ECMA262::ExpLogicalNot.new(st.cond.val.val.val2)
              r = ECMA262::ExpLogicalAnd.new(a,b).add_remove_paren
              if r.to_js.length <= st.cond.to_js.length
                st.replace(st.cond, r)
              end
            end
=end
            #if((a))
            if st.cond.kind_of? ECMA262::ExpParen
              st.replace(st.cond, st.cond.val)
            end
            #if(!!a)
            if st.cond.kind_of? ECMA262::ExpLogicalNot and st.cond.val.kind_of? ECMA262::ExpLogicalNot
              st.replace(st.cond, st.cond.val.val)
            end
          end
        }
      end
      block_to_statement
      self
    end

    def assignment_after_var(node = @prog)
      def rewrite_var(var_st, name, initializer)
        var_st.normalization
        i = 0
        var_st.vars.each do |_name, _initializer|
          if _name == name and _initializer.nil?
            var_st.vars[i] = [name, initializer]
            var_st.normalization
            return true
          end
          i += 1
        end
        false
      end

      retry_flag = true
      while retry_flag
        retry_flag = false
        node.traverse(nil) {|st, parent|
          if st.kind_of? ECMA262::StVar and parent.kind_of? ECMA262::SourceElements
            catch(:break){
              idx = parent.index(st) + 1
              while true
                st2 = parent[idx]
                if st2.kind_of? ECMA262::StEmpty or (st2.kind_of? ECMA262::StFunc and st2.decl?)
                  idx +=1
                  next
                elsif st2.kind_of? ECMA262::StExp and st2.exp.kind_of? ECMA262::ExpAssign
                  if rewrite_var(st, st2.exp.val, st2.exp.val2)
                    parent.replace(st2, ECMA262::StEmpty.new())
                    retry_flag = true
                  else
                    throw :break
                  end
                  idx += 1
                  next
                elsif st2.kind_of? ECMA262::StFor and st2.exp1.kind_of? ECMA262::ExpAssign
                  if rewrite_var(st, st2.exp1.val, st2.exp1.val2)
                    st2.replace(st2.exp1, nil)
                    retry_flag = true
                  else
                    throw :break
                  end
                  throw  :break
                elsif st2.kind_of? ECMA262::StExp and st2.exp.kind_of? ECMA262::ExpComma
                  exp_parent = st2
                  exp = st2.exp

                  while exp.val.kind_of? ECMA262::ExpComma
                    exp_parent = exp
                    exp = exp.val
                  end

                  if exp.val.kind_of? ECMA262::ExpAssign
                    if rewrite_var(st, exp.val.val, exp.val.val2)
                      exp_parent.replace(exp, exp.val2)
                      retry_flag = true
                    else
                      throw :break
                    end
                  else
                    throw :break
                  end
                else
                  throw :break
                end
              end
            }
          end
        }
      end
      self
    end
  end
end

if $0 == __FILE__
  argv = ARGV.dup
  f = []
  options = {}
  argv.each do |x|
    if x.match(/^--?version/)
      puts Minjs::VERSION
      exit(0)
    elsif x.match(/^--?/)
      opt = $'.gsub(/-/, '_').to_sym
      options[opt] = true
    else
      f.push(open(x.to_s).read())
    end
  end

  js = f.join("\n")

  comp = Minjs::Compressor.new(:debug => false)
  comp.compress(js, options)
  comp_js = comp.to_js(options)
  #p comp_js.length
  js = comp_js
  puts js

end
