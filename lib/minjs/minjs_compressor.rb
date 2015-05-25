require 'tilt'
require 'logger'

module Minjs
  class MinjsCompressor < Tilt::Template
    attr_reader :logger

    def self.engine_initialized?
      defined?(::Minjs)
    end

    def initialize_engine
    end

    def prepare
      @logger = Logger.new(STDERR)
      @logger.level = Logger::WARN
    end

    def evaluate(context, locals, &block)
      case context.content_type
      when 'application/javascript'
        if logger.info?
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
        #TODO
        t = Minjs::Compressor.new(:logger => logger).compress(data).to_js
        if logger.info?
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


