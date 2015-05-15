# coding: utf-8
require 'spec_helper'

describe 'Compression' do
  describe 'CompressVar' do
    it 'compress var name' do
      c = test_compressor
      c.parse <<-EOS
function xxxx()
{
    var aaaa, bbbb;// => j,k
    function yyyy(){
	var cccc, dddd, a, b; // => c,d,a,b
    }
    function wwww(c, d){
	var cccc, dddd, a, b; // => g,h,a,b
    }
    function eeee(c, d){
	var aaaa, bbbb; // => e,f
    }
    function rrrr(c, d){
	aaaa, bbbb; // => j,k
	function i(){
	}
	aaaa:while(true);
    }
}
EOS
      js = c.compress_var.to_js

      expect(js).to eq "function xxxx(){var l,m;function s(){var c,d,a,b}function r(c,d){var g,h,a,b}function q(c,d){var e,f}function p(c,d){l,m;function i(){}l:while(true)}};"
    end
    it 'compress var name' do
      c = test_compressor
      c.parse <<-EOS
function zzz(){
var aaaa;
try{
}
catch(aaaa){
var bbb;
}
finally{
}
}
EOS
      js = c.compress_var.to_js
      expect(js).to eq "function zzz(){var b;try{}catch(a){var c}finally{}};"
    end
  end
end

