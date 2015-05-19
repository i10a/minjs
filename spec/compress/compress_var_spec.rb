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

      expect(js).to eq "function xxxx(){var e,f;function h(){var c,d,e,f}function g(e,f){var h,i,j,k}function j(a,b){var g,h}function k(a,b){e,f;function g(){}e:while(true);}}"
    end
    it 'compress try-catch var name' do
      c = test_compressor
      c.parse <<-EOS
function zzz(){
var aaaa;
try{
}
catch(aaaa){
var bbb;
console.log(aaaa);
}
finally{
}
}
EOS
      js = c.compress_var.to_js
      expect(js).to eq "function zzz(){var a;try{}catch(a){var b;console.log(a)}finally{}}"
    end

    it 'compress var name' do
      c = test_compressor
      c.parse <<-EOS
function x()
{
    var a;
    function b(xxx,yyy,zzz){
	var b;
    }
}
EOS
      js = c.compress_var.to_js
      expect(js).to eq "function x(){var d;function c(e,d,b){var a}}"
    end

    it 'compress var name' do
      c = test_compressor
      c.parse <<-EOS
function zz()
{
    var a = function b(){
	console.log(b);
    }
    console.log(b);
}
EOS
      js = c.compress_var.to_js
      expect(js).to eq "function zz(){var c=function a(){console.log(a)};console.log(b)}"
    end
  end
end

