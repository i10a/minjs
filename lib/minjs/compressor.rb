#!/usr/bin/env ruby
require 'minjs/lex'
require 'minjs/ecma262'
require 'minjs/literal'
require 'minjs/statement'
require 'minjs/expression'
require 'minjs/func'
require 'minjs/program'
require 'minjs/exceptions'

module Minjs
  class Compressor
    include Literal
    include Statement
    include Exp
    include Func
    include Program

    attr_reader :prog

    def initialize(options = {})
      @debug = false
      if options[:debug]
        @debug = true
      end
    end

    def debug
      #@global_context.debug
      puts @prog.to_js()
    end

    def to_js(options = {})
      @prog.to_js(options)
    end

    def compress(data, options = {})
      parse(data)

      reorder_function_decl
      return_after
      simple_replacement
      reorder_var
      assignment_after_var
      grouping_statement
      block_to_exp
      if_to_cond #buggy
      compress_var
      reduce_exp
      @heading_comments.reverse.each do |c|
        @prog.source_elements.unshift(c)
      end

      to_js(options)
    end

    def parse(data)
      @lex = Minjs::Lex.new(data)
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

    def traverse(&block)
      @prog.traverse(nil, &block)
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

    def grouping_statement
      self.traverse {|st, parent|
        if st.kind_of? ECMA262::Prog
          st.grouping
        elsif st.kind_of? ECMA262::StList
          st.grouping
        end
      }
    end

    def reorder_function_decl
      self.traverse {|st, parent|
        if st.kind_of? ECMA262::StFunc and parent.kind_of? ECMA262::Prog and st.decl
          if parent.index(st)
            parent.remove(st)
            parent.source_elements.unshift(st)
          end
        end
      }
    end

    def reorder_var
      #traverse all statemtns and expression
      self.traverse {|st, parent|
        if st.kind_of? ECMA262::Prog
          vars = nil
          context = nil
          st.instance_eval{
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
                      #parent2.replace(st2, ECMA262::StExp.new(ECMA262::ExpAssign.new(vl[0], vl[1])))
                    else
                      #parent2.replace(st2, ECMA262::StEmpty.new())
                    end
                  end
                  parent2.replace(st2, ECMA262::StBlock.new(ECMA262::StList.new(blk)))
                }
              elsif st2.kind_of? ECMA262::StForVar and st2.context == @context
                parent2.replace(st2, st2.to_st_for)
              elsif st2.kind_of? ECMA262::StForInVar and st2.context == @context
                parent2.replace(st2, st2.to_st_for_in)
              end
            }
            if vars.length > 0
              @source_elements.unshift ECMA262::StVar.new(@context, vars)
            end
          }
        end
      }
      remove_block_in_block
    end

    def remove_block_in_block
      while true
        _retry = false
        self.traverse {|st, parent|
          if parent.kind_of? ECMA262::Prog and st.kind_of? ECMA262::StBlock
            idx = parent.index(st)
            parent.source_elements[idx..idx] = st.statement_list.statement_list
            _retry = true
            break
          elsif parent.kind_of? ECMA262::StList and st.kind_of? ECMA262::StBlock
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

    def block_to_exp
      self.traverse {|st, parent|
        if st.kind_of? ECMA262::StBlock and st.to_exp?
          if parent.kind_of? ECMA262::StTry
          else
            t = st.to_exp({})
            parent.replace(st, ECMA262::StExp.new(t))
          end
        end
      }
    end

    def if_to_cond
      #traverse all statemtns and expression
      self.traverse {|st, parent|
        if st.kind_of? ECMA262::StIf and st.to_exp?
          if t = ECMA262::StExp.new(st.to_exp({}))
            parent.replace(st, t)
          end
        end
      }
    end

    def compress_var
      #traverse all statemtns and expression
      self.traverse {|st, parent|
        if st.kind_of? ECMA262::StFunc and st.context.var_env.outer
          var_sym = :a
          #
          # collect all variables under this function
          #
          vars = {}
          st.traverse(parent) {|st2|
            if st2.kind_of? ECMA262::IdentifierName
              vars[st2.val.to_sym] = true
            end
          }
          #
          # collect all var variables under this function
          #
          var_vars = {}
          st.context.var_env.record.binding.each do|k, v|
            var_vars[k] = true
          end
          st.traverse(parent) {|st2|
            if st2.kind_of? ECMA262::StFunc
              st2.context.var_env.record.binding.each do|k, v|
                var_vars[k] = true
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
          # check var_vars
          #
          var_vars.each {|name, v|
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
                  st2.val = var_sym
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
    end
    def reduce_exp
      self.traverse {|st, parent|
        if st.kind_of? ECMA262::Exp
          st.reduce(parent)
        end
      }
    end

    def simple_replacement
      self.traverse {|st, parent|
        #true => !0
        #false => !1
        if st.kind_of? ECMA262::Boolean
          if st.true?
            parent.replace(st, ECMA262::ExpLogicalNot.new(ECMA262::ECMA262Numeric.new('0', 0)))
          else
            parent.replace(st, ECMA262::ExpLogicalNot.new(ECMA262::ECMA262Numeric.new('1', 1)))
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

    def return_after
      self.traverse {|st, parent|
        if st.kind_of? ECMA262::StReturn
          if parent.kind_of? ECMA262::StList
            idx = parent.index(st)
            idx += 1
            while parent.statement_list[idx]
              parent.statement_list[idx] = ECMA262::StEmpty.new;
              idx += 1
            end
          elsif parent.kind_of? ECMA262::Prog
            idx = parent.index(st)
            idx += 1
            while parent.source_elements[idx]
              parent.source_elements[idx] = ECMA262::StEmpty.new;
              idx += 1
            end
            if st.exp.nil?
              parent.replace(st, ECMA262::StEmpty.new)
            end
          end
        end
      }
    end
    #
    # var a; a=1
    # => var a=1
    #
    def assignment_after_var
      self.traverse {|st, parent|
        if st.kind_of? ECMA262::StExp and parent.kind_of? ECMA262::Prog
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
