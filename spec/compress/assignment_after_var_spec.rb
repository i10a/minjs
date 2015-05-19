# coding: utf-8
require 'spec_helper'

describe 'Compression' do
  describe 'AssignmentAfterVar' do
    it 'move assignment expression to var statement' do
      c = test_compressor
      c.parse <<-EOS
a=1;b=1;
var c,b,a;
EOS
      js = c.reorder_var.assignment_after_var.to_js
      expect(js).to eq "var a=1,b=1,c;"
    end

    it 'move assignment expression to var statement' do
      c = test_compressor
      c.parse <<-EOS
break;
a=1;b=1;
var c,b,a;
EOS
      js = c.reorder_var.assignment_after_var.to_js
      expect(js).to eq "break;var a=1,b=1,c;"
    end

    it 'move assignment expression to var statement' do
      c = test_compressor
      c.parse <<-EOS
var a,b,c,d,e,f,g;

c = x;
l = y,f=(z,g=y),m=time();
a = x+z;
n = k, ++i, j=1;

var h,i,j,k,l,m,n
EOS
      js = c.reorder_var.assignment_after_var.to_js
      expect(js).to eq "var c=x,l=y,f=(z,g=y),m=time(),a=x+z,n=k,b,d,e,g,h,i,j,k;++i,j=1;"
    end
    it 'move assignment expression to var statement' do
      c = test_compressor
      c.parse <<-EOS
var $ = function()
{
    var a=0,b=0,c=0,d;//function expression is in the var's initializer
}
EOS
      js = c.reorder_var.assignment_after_var.to_js
      expect(js).to eq "var $=function(){var a=0,b=0,c=0,d};"
    end
  end
end
