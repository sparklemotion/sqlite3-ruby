module SQLite3

  module Version

    MAJOR = 1
    MINOR = 3
    TINY  = 0
    BUILD = "beta.1"

    STRING = [ MAJOR, MINOR, TINY, BUILD ].compact.join( "." )
    #:beta-tag:

    VERSION = '1.3.0.beta.1'
  end

end
