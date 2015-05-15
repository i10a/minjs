# coding: utf-8
require 'spec_helper'

describe 'Compression' do
  describe 'BlockToStatement' do
    it 'convert block to statement' do
      c = test_compressor
      c.parse <<-EOS
if(true){;a=1}
while(true){break}
// try-catch require Block
try{'try'}catch(e){'catch'}finally{'fin'}
EOS
      js = c.block_to_statement.to_js
      expect(js).to eq "if(true)a=1;while(true)break;try{\"try\"}catch(e){\"catch\"}finally{\"fin\"};"
    end

    it 'does not convert block to statement' do
      c = test_compressor
      c.parse <<-EOS
if(a){
    while(true)
	if(b){
	    d();
	}
}
else{
    c();
}
EOS
      js = c.block_to_statement.to_js
      expect(js).to eq "if(a){while(true)if(b)d()}else c();"
    end
  end
end

