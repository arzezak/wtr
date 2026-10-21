module Wtr
  module Log
    def self.puts(message)
      warn message
    end

    def self.print(message)
      $stderr.print message
    end

    def self.step(label, subject)
      warn "🌳 #{label}: #{subject}"
    end
  end
end
