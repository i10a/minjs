# coding: utf-8
require 'spec_helper'

describe 'Compression' do
  describe 'ReorderFunctionDeclaration' do
    it 'reorder function declaration' do
      c = test_compressor
      c.parse <<-EOS
foo;
var a=function aa(){} // => is expression.
function cc(){} // => is declaration, move to top.
var b=function (){} // => is expression.
function dd(){} // => is declaration, move to top too.
EOS
      js = c.reorder_function_decl.to_js
      expect(js).to eq "function cc(){}function dd(){}foo;var a=function aa(){};var b=function(){};"
    end
  end
end

