# coding: utf-8
require 'spec_helper'

describe 'Compression' do
  describe 'CompressVar' do
    it 'compress var name' do
      c = test_compressor
      c.parse <<-EOS
function xxxx()
{
    var aaaa, bbbb;// => a,b
    function yyyy(){//=>d
	var cccc, dddd, a, b; // => a,b,c,e
    }
    function wwww(c, d){//=>d(a,b)
	var cccc, dddd, a, b; // => c,d,e,f
    }
    function eeee(c, d){//=>e(a,b)
	var aaaa, bbbb; // => c,d
    }
    function rrrr(c, d){//=>f(c,d)
	aaaa, bbbb; // => a,b
	function i(){
	}
	aaaa:while(true);
    }
}
EOS
      js = c.compress_var.to_js

      expect(js).to eq "function xxxx(){var a,b;function d(){var a,b,c,e}function c(a,b){var d,e,f,g}function e(a,b){var c,d}function f(c,d){a,b;function e(){}a:while(true);}}"
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
      expect(js).to eq "function x(){var c;function d(a,c,e){var f}}"
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

