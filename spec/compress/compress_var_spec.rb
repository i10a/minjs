# coding: utf-8
require 'spec_helper'

describe 'Expression' do
  describe 'CompressVar' do
    it 'compress var name' do
      c = Minjs::Compressor.new
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
      expect(js).to eq "function xxxx(){var v,t;function l(){var c,d,a,b}function m(c,d){var g,h,a,b}function n(c,d){var e,f}function r(c,d){v,t;function i(){}v:while(true)}};"
    end
  end
end

