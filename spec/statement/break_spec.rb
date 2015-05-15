require 'spec_helper'

describe 'Statement' do
  describe 'Break' do
    it 'is break statement' do
      js = test_parse <<-EOS
i=0;
while(i<10){
  i+=1
  if(i>5)
    break;
  console.log(i)
}
EOS
      expect(js).to eq "i=0;while(i<10){i+=1;if(i>5)break;console.log(i)};"
    end

    it 'is break statement with label' do
      js = test_parse <<-EOS
j=0
undefined:
while(j<10){
    ++j;
    i=0;
    while(i<10){
	++i;
	if(i<5)
	    break undefined;
        console.log(i, j)
    }
}
EOS
      expect(js).to eq "j=0;undefined:while(j<10){++j;i=0;while(i<10){++i;if(i<5)break undefined;console.log(i,j)}};"
    end

    it 'is break statement with automatic semicolon insertion' do
      js = test_parse <<-EOS
j=0;
undefined:
while(j<10){
    ++j;
    i=0;
    while(i<10){
        ++i;
	if(i<5)
	    break
		 undefined;//ignored
        console.log(j)
    }
}
EOS
      expect(js).to eq "j=0;undefined:while(j<10){++j;i=0;while(i<10){++i;if(i<5)break;undefined;console.log(j)}};"
    end

    it 'cause syntax error' do
      expect {
        js = test_parse <<-EOS
break 0//0 is not identifier
EOS
      }.to raise_error(Minjs::ParseError)
    end
  end
end
