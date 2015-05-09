require 'tilt'

module Minjs
  class MinjsCompressor < Tilt::Template
    DEBUG = false

    def self.engine_initialized?
      defined?(::Minjs)
    end

    def initialize_engine
    end

    def prepare
    end

    def evaluate(context, locals, &block)
      case context.content_type
      when 'application/javascript'
        if DEBUG
          @@c = 0 unless defined?(@@c)
          puts "start: compressing"
          file = "tmp#{@@c}.js"
          output = "tmp#{@@c}.js.min"
          @@c += 1
          puts "source: #{file}"
          puts "output: #{output}"
          tmp = open(file, "w")
          tmp.write(data)
          tmp.close
        end
        t = Minjs::Compressor.new.compress(data)
        if DEBUG
          tmp = open(output, "w")
          tmp.write(t)
          tmp.close
        end
        t
      else
        data
      end
    end
  end

end


