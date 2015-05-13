# coding: utf-8
require 'spec_helper'

describe 'Expression' do
  describe 'BlockToStatement' do
    it 'convert block to statement' do
      c = Minjs::Compressor.new
      c.parse <<-EOS
if(true){;a=1}
while(true){break}
// try-catch require Block
try{'try'}catch(e){'catch'}finally{'fin'}
EOS
      js = c.block_to_statement.to_js
      expect(js).to eq "if(true)a=1;while(true)break;try{\"try\"}catch(e){\"catch\"}finally{\"fin\"};"
    end
  end
end

