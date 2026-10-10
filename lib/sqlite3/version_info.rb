module SQLite3
  version_info = {
    ruby: RUBY_DESCRIPTION,
    gem: {
      version: SQLite3::VERSION
    },
    sqlite: {
      compiled: SQLite3::SQLITE_VERSION,
      loaded: SQLite3::SQLITE_LOADED_VERSION,
      packaged: SQLite3::SQLITE_PACKAGED_LIBRARIES,
      precompiled: SQLite3::SQLITE_PRECOMPILED_LIBRARIES,
      sqlcipher: SQLite3.sqlcipher?,
      threadsafe: SQLite3.threadsafe?
    }
  }
  # a hash of descriptive metadata about the current version of the sqlite3 gem,
  # deeply frozen so that it can be read from any Ractor
  VERSION_INFO = defined?(Ractor.make_shareable) ? Ractor.make_shareable(version_info) : version_info.freeze
end
