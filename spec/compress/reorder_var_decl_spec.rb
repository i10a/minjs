# coding: utf-8
require 'spec_helper'

describe 'Compression' do
  describe 'ReorderVarDeclaration' do
    it 'reorder var declaration' do
      c = test_compressor
      c.parse <<-EOS
function z()
{
a=1;
b=2;
c=3;
d=4;
var b;
}
EOS
      js = c.reorder_var.to_js
      expect(js).to eq "function z(){a=1;var b;b=2;c=3;d=4}"
    end
    it 'reorder var declaration' do
      c = test_compressor
      c.parse <<-EOS
function z()
{
t={
get getter(){a=1;b=2;c=3;var b;},// 'b' is in the getter scope
set setter(val){a=1;b=2;c=3;var b;}// 'b' is in the setter scope
}
}
EOS
      js = c.reorder_var.to_js
      expect(js).to eq "function z(){t={get getter(){a=1;var b;b=2;c=3},set setter(val){a=1;var b;b=2;c=3}}}"
    end
  end
end

