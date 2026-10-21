module Wtr
  module Log
    def self.puts(message)
      warn message
    end

    def self.print(message)
      $stderr.print message
    end

    # Announces a hook step (e.g. "copy", "run"), tree-prefixed so it's easy
    # to spot among the hooks' own output.
    def self.step(label, subject)
      warn "🌳 #{label}: #{subject}"
    end
  end
end
