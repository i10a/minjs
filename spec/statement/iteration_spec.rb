require 'spec_helper'

describe 'Statement' do
  describe 'Iteration' do
    it 'is do-while statement' do
      js = test_parse <<-EOS
i=0
do{
  console.log(i)
}while(++i<10);
EOS
      expect(js).to eq "i=0;do console.log(i);while(++i<10);"
    end

    it 'is while statement' do
      js = test_parse <<-EOS
i=0
while(++i<10){
  console.log(i)
}
EOS
      expect(js).to eq "i=0;while(++i<10)console.log(i);"
    end

    it 'is for statement' do
      js = test_parse <<-EOS
for(i=0;i<10;++i){
  console.log(i)
}
for(;i<10;++i){
  console.log(i)
}
for(i=0;;++i){
  if(i<10)
    break;
  console.log(i)
}
for(i=0;i<10;){
  console.log(i)
  ++i
}
EOS
      expect(js).to eq  "for(i=0;i<10;++i)console.log(i);for(;i<10;++i)console.log(i);for(i=0;;++i){if(i<10)break;console.log(i)}for(i=0;i<10;){console.log(i);++i};"
    end

    it 'is for_var statement' do
      js = test_parse <<-EOS
for(var i=0;i<10;++i){
  console.log(i)
}
for(var i=0;;++i){
  if(i<10)
    break;
  console.log(i)
}
for(var i=0,j=0;i<10;){
  console.log(i)
  ++i
}
EOS
      expect(js).to eq "for(var i=0;i<10;++i)console.log(i);for(var i=0;;++i){if(i<10)break;console.log(i)}for(var i=0,j=0;i<10;){console.log(i);++i};"
    end

    it 'is for-in statement' do
      js = test_parse <<-EOS
for(i in [1,2,3]){
  console.log(i)
}
EOS
      expect(js).to eq "for(i in[1,2,3])console.log(i);"
    end

    it 'is for var-in statement' do
      js = test_parse <<-EOS
for(var i in [1,2,3]){
  console.log(i)
}
EOS
      expect(js).to eq "for(var i in[1,2,3])console.log(i);"
    end
  end
end
