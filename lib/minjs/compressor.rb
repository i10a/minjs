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
              if st2.kind_of? ECMA262::StVar and st2.context == @context
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
              elsif st2.kind_of? ECMA262::StForVar and st2.context == @context
                parent2.replace(st2, st2.to_st_for)
              elsif st2.kind_of? ECMA262::StForInVar and st2.context == @context
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
    end

    def remove_paren(node = @prog)
      node.traverse(nil) {|st, parent|
        if st.respond_to? :remove_paren
          st.remove_paren
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
    end

    def block_to_statement(node = @prog)
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::StBlock and !parent.kind_of?(ECMA262::StTry)
          if st.to_statement?
            parent.replace(st, st.to_statement)
          end
        end
      }
      self
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
    end

    def compress_var(node = @prog)
      #
      #traverse all statemtns and expression
      #
      node.traverse(nil) {|st, parent|
        if st.kind_of? ECMA262::StFunc and st.context.var_env.outer
          var_sym = :a
          #
          # collect all variables under this function
          #
          vars = {}
          st.traverse(parent) {|st2|
            if st2.kind_of? ECMA262::IdentifierName
              vars[st2.val.to_sym] ||= 0
              vars[st2.val.to_sym] += 1
            end
          }
          #
          # collect all var variables under this function
          #
          var_vars = {}
          st.context.var_env.record.binding.each do|k, v|
            var_vars[k] = vars[k]
          end
          st.traverse(parent) {|st2|
            if st2.kind_of? ECMA262::StFunc
              st2.context.var_env.record.binding.each do|k, v|
                var_vars[k] = vars[k]
              end
            end
          }
          #
          # check `eval' function is exist under this function
          #
          unless var_vars[:eval]
            eval_flag = false
            st.traverse(parent) {|st2|
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
              st.traverse(parent){|st2|
                if st2.kind_of? ECMA262::IdentifierName and st2.context and st2.context.var_env == st.context.var_env.outer
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
    end

    def simple_replacement(node = @prog)
      node.traverse(nil) {|st, parent|
        #true => !0
        #false => !1
        if st.kind_of? ECMA262::Boolean
          if st.true?
            parent.replace(st, ECMA262::ExpParen.new(ECMA262::ExpLogicalNot.new(ECMA262::ECMA262Numeric.new(0))))
          else
            parent.replace(st, ECMA262::ExpParen.new(ECMA262::ExpLogicalNot.new(ECMA262::ECMA262Numeric.new(1))))
          end
        #if(true){<then>}else{<else>} => then
        elsif st.kind_of? ECMA262::StIf
          if st.cond.kind_of? ECMA262::Boolean
            if st.cond.true?
              parent.replace(st, st.then_st)
            elsif st.else_st
              parent.replace(st, st.else_st)
            else
              parent.replace(st, ECMA262::StEmpty.new())
            end
          end
        end
      }
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
    def assignment_after_var(node = @prog)
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
