module Cowtech
  module Lib
    module Version
      MAJOR = 1
      MINOR = 9
      PATCH = 5
      BUILD = 0

      STRING = [MAJOR, MINOR, PATCH, BUILD].compact.join('.')
    end
  end
end
