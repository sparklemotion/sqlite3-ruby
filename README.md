# Ruby Interface for SQLite3

* Source code: https://github.com/sparklemotion/sqlite3-ruby
* Mailing list: http://groups.google.com/group/sqlite3-ruby
* Download: http://rubygems.org/gems/sqlite3
* Documentation: http://www.rubydoc.info/gems/sqlite3

[![Unit tests](https://github.com/sparklemotion/sqlite3-ruby/actions/workflows/sqlite3-ruby.yml/badge.svg)](https://github.com/sparklemotion/sqlite3-ruby/actions/workflows/sqlite3-ruby.yml)
[![Native packages](https://github.com/sparklemotion/sqlite3-ruby/actions/workflows/gem-install.yml/badge.svg)](https://github.com/sparklemotion/sqlite3-ruby/actions/workflows/gem-install.yml)


## Description

This library allows Ruby programs to use the SQLite3 database engine (http://www.sqlite.org).

Note that this module is only compatible with SQLite 3.6.16 or newer.


## Synopsis

``` ruby
require "sqlite3"

# Open a database
db = SQLite3::Database.new "test.db"

# Create a table
rows = db.execute <<-SQL
  create table numbers (
    name varchar(30),
    val int
  );
SQL

# Execute a few inserts
{
  "one" => 1,
  "two" => 2,
}.each do |pair|
  db.execute "insert into numbers values ( ?, ? )", pair
end

# Find a few rows
db.execute( "select * from numbers" ) do |row|
  p row
end
# => ["one", 1]
#    ["two", 2]

# Create another table with multiple columns
db.execute <<-SQL
  create table students (
    name varchar(50),
    email varchar(50),
    grade varchar(5),
    blog varchar(50)
  );
SQL

# Execute inserts with parameter markers
db.execute("INSERT INTO students (name, email, grade, blog)
            VALUES (?, ?, ?, ?)", ["Jane", "me@janedoe.com", "A", "http://blog.janedoe.com"])

db.execute( "select * from students" ) do |row|
  p row
end
# => ["Jane", "me@janedoe.com", "A", "http://blog.janedoe.com"]
```

## Installation

### Native Gems (recommended)

As of v1.5.0 of this library, native (precompiled) gems are available for Ruby 2.6, 2.7, 3.0, and 3.1 on all these platforms:

- `aarch64-linux`
- `arm-linux`
- `arm64-darwin`
- `x64-mingw32` / `x64-mingw-ucrt`
- `x86-linux`
- `x86_64-darwin`
- `x86_64-linux`

If you are using one of these Ruby versions on one of these platforms, the native gem is the recommended way to install sqlite3-ruby.

For example, on a linux system running Ruby 3.1:

``` text
$ ruby -v
ruby 3.1.2p20 (2022-04-12 revision 4491bb740a) [x86_64-linux]

$ time gem install sqlite3
Fetching sqlite3-1.5.0-x86_64-linux.gem
Successfully installed sqlite3-1.5.0-x86_64-linux
1 gem installed

real    0m4.274s
user    0m0.734s
sys     0m0.165s
```

#### Avoiding the precompiled native gem

The maintainers strongly urge you to use a native gem if at all possible. It will be a better experience for you and allow us to focus our efforts on improving functionality rather than diagnosing installation issues.

If you're on a platform that supports a native gem but you want to avoid using it in your project, do one of the following:

- If you're not using Bundler, then run `gem install sqlite3 --platform=ruby`
- If you are using Bundler
  - version 2.3.18 or later, you can specify [`gem "sqlite3", force_ruby_platform: true`](https://bundler.io/v2.3/man/gemfile.5.html#FORCE_RUBY_PLATFORM)
  - version 2.1 or later, then you'll need to run `bundle config set force_ruby_platform true`
  - version 2.0 or earlier, then you'll need to run `bundle config force_ruby_platform true`


### Compiling the source gem

If you are on a platform or version of Ruby that is not covered by the Native Gems, then the vanilla "ruby platform" (non-native) gem will be installed by the `gem install` or `bundle` commands.


#### Packaged libsqlite3

By default, as of v1.5.0 of this library, the latest available version of libsqlite3 is packaged with the gem and will be compiled and used automatically. This takes a bit longer than the native gem, but will provide a modern, well-supported version of libsqlite3.

For example, on a linux system running Ruby 2.5:

``` text
$ ruby -v
ruby 2.5.9p229 (2021-04-05 revision 67939) [x86_64-linux]

$ time gem install sqlite3
Building native extensions. This could take a while...
Successfully installed sqlite3-1.5.0
1 gem installed

real    0m20.620s
user    0m23.361s
sys     0m5.839s
```


#### System libsqlite3

If you would prefer to build the sqlite3-ruby gem against your system libsqlite3, which requires that you install libsqlite3 and its development files yourself, you may do so by using the `--enable-system-libraries` flag at gem install time.

PLEASE NOTE:

- you must avoid installing a precompiled native gem (see [previous section](#avoiding-the-precompiled-native-gem))
- only versions of libsqlite3 `>= 3.5.0` are supported,
- and some library features may depend on how your libsqlite3 was compiled.

For example, on a linux system running Ruby 2.5:

``` text
$ time gem install sqlite3 -- --enable-system-libraries
Building native extensions with: '--enable-system-libraries'
This could take a while...
Successfully installed sqlite3-1.5.0
1 gem installed

real    0m4.234s
user    0m3.809s
sys     0m0.912s
```

If you're using bundler, you can opt into system libraries like this:

``` sh
bundle config build.sqlite3 --enable-system-libraries
```

If you have sqlite3 installed in a non-standard location, you may need to specify the location of the include and lib files by using `--with-sqlite-include` and `--with-sqlite-lib` options (or a `--with-sqlite-dir` option, see [MakeMakefile#dir_config](https://ruby-doc.org/stdlib-3.1.1/libdoc/mkmf/rdoc/MakeMakefile.html#method-i-dir_config)). If you have pkg-config installed and configured properly, this may not be necessary.

``` sh
gem install sqlite3 -- \
  --enable-system-libraries \
  --with-sqlite3-include=/opt/local/include \
  --with-sqlite3-lib=/opt/local/lib
```


#### System libsqlcipher

If you'd like to link against a system-installed libsqlcipher, you may do so by using the `--with-sqlcipher` flag:

``` text
$ time gem install sqlite3 -- --with-sqlcipher
Building native extensions with: '--with-sqlcipher'
This could take a while...
Successfully installed sqlite3-1.5.0
1 gem installed

real    0m4.772s
user    0m3.906s
sys     0m0.896s
```

If you have sqlcipher installed in a non-standard location, you may need to specify the location of the include and lib files by using `--with-sqlite-include` and `--with-sqlite-lib` options (or a `--with-sqlite-dir` option, see [MakeMakefile#dir_config](https://ruby-doc.org/stdlib-3.1.1/libdoc/mkmf/rdoc/MakeMakefile.html#method-i-dir_config)). If you have pkg-config installed and configured properly, this may not be necessary.


## Support

### Something has gone wrong! Where do I get help?

You can ask for help or support from the
[sqlite3-ruby mailing list](http://groups.google.com/group/sqlite3-ruby) which
can be found here:

> http://groups.google.com/group/sqlite3-ruby


### I've found a bug! How do I report it?

After contacting the mailing list, you've found that you've uncovered a bug. You can file the bug at the [github issues page](https://github.com/sparklemotion/sqlite3-ruby/issues) which can be found here:

> https://github.com/sparklemotion/sqlite3-ruby/issues


## Usage

For help figuring out the SQLite3/Ruby interface, check out the SYNOPSIS as well as the RDoc. It includes examples of usage. If you have any questions that you feel should be addressed in the FAQ, please send them to [the mailing list](http://groups.google.com/group/sqlite3-ruby).


## Contributing

See [`CONTRIBUTING.md`](./CONTRIBUTING.md).


## License

This library is licensed under `BSD-3-Clause`, see [`LICENSE`](./LICENSE).


### Dependencies

The source code of `sqlite` is distributed in the "ruby platform" gem. This code is public domain, see [`LICENSE-DEPENDENCIES`](./LICENSE-DEPENDENCIES) for details.
