# coding: utf-8
require 'spec_helper'

describe 'Compression' do
  describe 'ReorderFunctionDeclaration' do
    it 'reorder function declaration' do
      c = test_compressor
      c.parse <<-EOS
foo;
var a=function aa(){} // => is expression.
var b=function (){} // => is expression.
function cc(){} // => is declaration, move to top.
EOS
      js = c.reorder_function_decl.to_js
      expect(js).to eq "function cc(){}foo;var a=function aa(){};var b=function(){};"
    end
  end
end

