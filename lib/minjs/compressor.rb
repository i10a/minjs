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
require 'logger'

module Minjs
  class Compressor
    include Literal
    include Statement
    include Exp
    include Func
    include Program

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
      @prog.to_js(options)
    end

    def compress(data, options = {})
      @logger.info '* parse'
      parse(data)

      @logger.info '* reorder_function_decl'
      reorder_function_decl

      @logger.info '* simple_replacement'
      simple_replacement

      @logger.info '* reorder_var'
      reorder_var

      @logger.info '* assignment_after_var'
      assignment_after_var

      @logger.info '* grouping_statement'
      grouping_statement

      @logger.info '* block_to_statement'
      block_to_statement

      @logger.info '* reduce_if'
      reduce_if

      @logger.info '* if_to_cond'
      if_to_cond

      @logger.info '* compress_var'
      compress_var

      @logger.info '* reduce_exp'
      reduce_exp

      @logger.info '* remove_paren'
      remove_paren

      @logger.info '* return_to_exp'
      return_to_exp

      @heading_comments.reverse.each do |c|
        @prog.source_elements.source_elements.unshift(c)
      end
      to_js(options)
    end

    def parse(data)
      @lex = Minjs::Lex.new(data, :logger => @logger)
      @global_context = ECMA262::Context.new

      @heading_comments = []
      @lex.eval_lit{
        while a = @lex.ws_lit
          @heading_comments.push(a)
        end
        nil
      }
      @prog = source_elements(@lex, @global_context)
      @prog
    end

#    def traverse(&block)
#      @prog.traverse(nil, &block)
#    end

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
      remove_paren
      self
    end

    def reorder_function_decl(node = @prog)
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::StFunc and parent.kind_of? ECMA262::StatementList and st.decl?
          if parent.index(st)
            parent.remove(st)
            parent.source_elements.unshift(st)
          end
        end
      }
      self
    end

    def reorder_var(node = @prog)
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::Prog
          vars = nil
          context = nil
          st.instance_eval{
            #
            # collect all of var variable in this function
            #
            vars = @context.var_env.record.binding.find_all {|k, v|
              v and v[:_parameter_list].nil? and !v[:value].kind_of?(ECMA262::StFunc)
            }.collect{|x|
              [
                ECMA262::IdentifierName.new(@context, x[0])
              ]
            }
            st.traverse(parent) {|st2, parent2|
              if st2.kind_of? ECMA262::StVar and st2.context.var_env == @context.var_env
                st2.instance_eval{
                  blk = []
                  @vars.each do |vl|
                    if vl[1]
                      blk.push(ECMA262::StExp.new(ECMA262::ExpAssign.new(vl[0], vl[1])))
                    else
                    end
                  end
                  parent2.replace(st2, ECMA262::StBlock.new(ECMA262::StatementList.new(blk)))
                }
              elsif st2.kind_of? ECMA262::StForVar and st2.context.var_env == @context.var_env
                parent2.replace(st2, st2.to_st_for)
              elsif st2.kind_of? ECMA262::StForInVar and st2.context.var_env == @context.var_env
                parent2.replace(st2, st2.to_st_for_in)
              end
            }
            if vars.length > 0
              @source_elements.source_elements.unshift ECMA262::StVar.new(@context, vars)
            end
          }
        end
      }
      remove_block_in_block
      self
    end

    def remove_paren(node = @prog)
      node.traverse(nil) {|st, parent|
        if st.respond_to? :remove_paren
          st.remove_paren
          st.add_paren
        end
      }
      self
    end

    def remove_block_in_block(node = @prog)
      while true
        _retry = false
        node.traverse(nil) {|st, parent|
          if parent.kind_of? ECMA262::StatementList and st.kind_of? ECMA262::StBlock
            idx = parent.index(st)
            parent.statement_list[idx..idx] = st.statement_list.statement_list
            _retry = true
            break
          elsif st.kind_of? ECMA262::StBlock
            ;
          end
        }
        break if !_retry
      end
      self
    end

    def block_to_statement(node = @prog)
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::StIf
          #
          # To determine removing "if block" is available or not is difficult.
          # For example, next codes block must not be removed, because
          # "else" cluase combined to second "if" statement.
          #
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

          # The "else" cluase's block can be removed without condition.
          if st.else_st and st.else_st.kind_of? ECMA262::StBlock and st.else_st.to_statement?
            st.replace(st.else_st, st.else_st.to_statement)
          end
          #
          # if "if" statement has no "else" clause, its block can be removed.
          #
          if st.else_st.nil? and st.then_st.kind_of? ECMA262::StBlock and st.then_st.to_statement?
            st.replace(st.then_st, st.then_st.to_statement)
          #
          # if "if" statement has "else" clause, check "then" caluse's
          # last statement. If last statement is not "if" statement or
          # has "else" caluase, its block can be removed.
          #
          elsif st.else_st and st.then_st.kind_of? ECMA262::StBlock and st.then_st.to_statement?
            last_st = st.then_st.last_statement[-2]
            if !last_st.kind_of? ECMA262::StIf or last_st.else_st
              st.replace(st.then_st, st.then_st.to_statement)
            end
          end
        end
      }
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::StBlock and !parent.kind_of?(ECMA262::StTry) and !parent.kind_of?(ECMA262::StIf)
            if st.to_statement?
              parent.replace(st, st.to_statement)
            end
        end
      }
      self
    end

    def if_block_to_statemet(node = @prog)
    end

    def if_to_cond(node = nil)
      node = @prog if node.nil?
      node.traverse(nil) {|st, parent|
        #
        #feature
        #
        # if(a)return a;
        # return b;
        # => if(a)return a;else return b;
        #

        if st.kind_of? ECMA262::StIf and parent.kind_of? ECMA262::StatementList
          i = parent.index(st)
          if parent[i+1].nil? and !parent.kind_of?(ECMA262::SourceElements)
            next
          end
          if parent[i+1].nil? or parent[i+1].to_return?
            s = st
            while s.kind_of? ECMA262::StIf and s.else_st and s.then_st.to_return?
              s = s.else_st
            end
            if s and s.kind_of? ECMA262::StIf and s.then_st.to_return?
              if parent[i+1]
                s.replace(s.else_st, parent[i+1])
                parent.replace(parent[i+1], ECMA262::StEmpty.new)
              else
                s.replace(s.else_st, ECMA262::StReturn.new(ECMA262::ExpVoid.new(ECMA262::ECMA262Numeric.new(0))))
              end
            end
          end
        end
      }
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::StIf and st.to_exp?
          if t = ECMA262::StExp.new(st.to_exp({}))
            parent.replace(st, t)
          end
        elsif st.kind_of? ECMA262::StIf and st.to_return?
          t = st.to_return
          if t.to_js().length < st.to_js().length
            parent.replace(st, st.to_return)
          end
        end
      }
      remove_paren
      self
    end

    def compress_var(node = @prog)
      #
      #traverse all statemtns and expression
      #
      node.traverse(nil) {|st, parent|
        var_sym = :a
        if st.kind_of? ECMA262::StTry and st.catch
          _context = st.catch_context
          _parent = st
          _st = st.catch[1]
        elsif st.kind_of? ECMA262::StFunc #and st.context.var_env.outer
          _context = st.context
          _parent = parent
          _st = st
        else
          _parent = nil
          _context = nil
          _st = nil
        end
        if _parent and _context and _st
          #
          # collect all variables under this function/catch
          #
          vars = {}
          if st.kind_of? ECMA262::StTry
            vars[st.catch[0].val.to_sym] = 1
          end
          _st.traverse(_parent) {|st2|
            if st2.kind_of? ECMA262::IdentifierName
              vars[st2.val.to_sym] ||= 0
              vars[st2.val.to_sym] += 1
            end
          }
          #
          # collect all var variables under this function
          #
          var_vars = {}
          if st.kind_of? ECMA262::StFunc
            _context.var_env.record.binding.each do|k, v|
              var_vars[k] = (vars[k] || 1)
            end
            _st.traverse(parent) {|st2|
              if st2.kind_of? ECMA262::StFunc
                st2.context.var_env.record.binding.each do|k, v|
                  var_vars[k] = (vars[k] || 1)
                end
              end
            }
          end
          #
          # collect all lexical variables under this catch clause
          #
          # currently, only catch's args is lex_var
          #
          lex_vars = {}
          if st.kind_of? ECMA262::StTry
            _context.lex_env.record.binding.each do|k, v|
              lex_vars[k] = (vars[k] || 1)
            end
          end
          #
          # check `eval' function is exist under this function/catch
          #
          unless var_vars[:eval]
            eval_flag = false
            _st.traverse(_parent) {|st2|
              if st2.kind_of? ECMA262::ExpCall and st2.name.to_js({}) == "eval"
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
          var_vars = var_vars.sort {|(k1,v1), (k2,v2)| v2 <=> v1}
          #
          # check var_vars
          #
          var_vars.each {|name, count|
            if name.nil?
              next
            end
            while(vars[var_sym])
              var_sym = next_sym(var_sym)
            end
            if name.to_s.bytesize > var_sym.to_s.bytesize
              #
              # rename `name' to `var_sym'
              #
              _st.traverse(_parent){|st2|
                if st2.kind_of? ECMA262::IdentifierName and st2.context.nil?
                  ;# TODO, currently special identifier such as 'this' has no context
                elsif st2.kind_of? ECMA262::IdentifierName and st2.context.var_env.outer == nil # global scope
                  ;
                elsif st2.kind_of? ECMA262::IdentifierName and st2.val == name
                  st2.instance_eval{
                    @val = var_sym
                  }
                elsif st2.kind_of? ECMA262::StFunc
                  st2.context.var_env.record.binding[var_sym] = st2.context.var_env.record.binding[name]
                  st2.context.var_env.record.binding.delete(name)
                end
              }
            end
            var_sym = next_sym(var_sym)
          }
          lex_vars.each {|name, count|
            if name.nil?
              next
            end
            while(vars[var_sym])
              var_sym = next_sym(var_sym)
            end
            if name.to_s.bytesize > var_sym.to_s.bytesize
              #
              # rename `name' to `var_sym'
              #
              _st.traverse(_parent){|st2|
                if st2.kind_of? ECMA262::IdentifierName and st2.context.nil?
                  ;# TODO, currently special identifier such as 'this' has no context
                elsif st2.kind_of? ECMA262::IdentifierName and st2.context.lex_env.outer == nil # global scope
                  ;
                elsif st2.kind_of? ECMA262::IdentifierName and st2.val == name
                  st2.instance_eval{
                    @val = var_sym
                  }
                end
              }
              if st.kind_of? ECMA262::StTry
                if st.catch[0].kind_of? ECMA262::IdentifierName
                  st.catch[0].instance_eval{
                    @val = var_sym
                  }
                end
              end
            end
            var_sym = next_sym(var_sym)
          }
        end
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
        #if(true){<then>}else{<else>} => then
        #
        elsif st.kind_of? ECMA262::StIf
          if st.cond.respond_to? :to_ecma262_boolean
            if st.cond.to_ecma262_boolean
              parent.replace(st, st.then_st)
            elsif st.else_st
              parent.replace(st, st.else_st)
            else
              parent.replace(st, ECMA262::StEmpty.new())
            end
          end
        #
        # while(true) => for(;;)
        # while(false) => remove
        #
        elsif st.kind_of? ECMA262::StWhile and st.exp.respond_to? :to_ecma262_boolean
          if st.exp.to_ecma262_boolean
            parent.replace(st, ECMA262::StFor.new(nil,nil,nil, st.statement))
          else
            parent.replace(st, ECMA262::StEmpty.new)
          end
        end
      }
      self
    end

    def return_to_exp(node = @prog)
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::StReturn
          if parent.kind_of? ECMA262::StatementList
            parent.remove_empty_statement
            if parent.statement_list[-1] == st and (prev=parent.statement_list[-2]).class == ECMA262::StExp
              if st.exp
                st.replace(st.exp, ECMA262::ExpComma.new(prev.exp, st.exp))
                parent.replace(prev, ECMA262::StEmpty.new())
              end
            end
            parent.remove_empty_statement
          end
        end
      }
      block_to_statement
      if_to_cond
      self
    end
    #
    # var a; a=1
    # => var a=1
    #
    def assignment_after_var_old(node = @prog)
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::StExp and parent.kind_of? ECMA262::SourceElements
          if st.exp.kind_of? ECMA262::ExpAssign
            idx = parent.index(st)
            while idx > 0
              idx -= 1
              prevst = parent[idx]
              if prevst.kind_of? ECMA262::StEmpty
                next
              elsif prevst.kind_of? ECMA262::StVar
                i = 0
                prevst.normalization
                prevst.vars.each do |name, init|
                  if st.exp.val == name and init.nil?
                    prevst.vars[i] = [name, st.exp.val2]
                    parent.replace(st, ECMA262::StEmpty.new())
                    break
                  end
                  i += 1
                end
                prevst.normalization
                break
              else
                break
              end
            end
          end
        end
      }
      self
    end
    #
    # reduce_if
    #
    # 1) rewrite nested "if" statemet such as:
    # if(a)
    #   if(b) ...;
    #
    # to:
    #
    # if(a && b) ...;
    #
    # NOTE:
    # both if must not have "else" clause
    #
    def reduce_if(node = @prog)
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::StIf
          if st.else_st.nil? and
            st.then_st.kind_of? ECMA262::StIf and st.then_st.else_st.nil?
            st.replace(st.cond, ECMA262::ExpLogicalAnd.new(st.cond, st.then_st.cond))
            st.replace(st.then_st, st.then_st.then_st)
          end
        end
      }
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
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::StVar and parent.kind_of? ECMA262::SourceElements
          #
          # index of 'var statement' is 0, after calling reorder_var
          #
          catch(:break){
            idx = 1
            while true
              st2 = parent[idx]
              if st2.kind_of? ECMA262::StEmpty
                idx +=1
                next
              elsif st2.kind_of? ECMA262::StExp and st2.exp.kind_of? ECMA262::ExpAssign
                if rewrite_var(st, st2.exp.val, st2.exp.val2)
                  parent.replace(st2, ECMA262::StEmpty.new())
                else
                  throw :break
                end
                idx += 1
                next
              elsif st2.kind_of? ECMA262::StFor and st2.exp1.kind_of? ECMA262::ExpAssign
                if rewrite_var(st, st2.exp1.val, st2.exp1.val2)
                  st2.replace(st2.exp1, nil)
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
      self
    end
  end
end

if $0 == __FILE__
  argv = ARGV.dup
  f = []
  argv.each do |x|
    f.push(open(x.to_s).read())
  end
  prog = Minjs::Compressor.new(:debug => false)
  prog.compress(f.join("\n"))
  puts prog.to_js({})
end
