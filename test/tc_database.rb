$:.unshift "../lib"

require 'sqlite3/database'
require 'test/unit'

require 'mocks'

class TC_Database_Init < Test::Unit::TestCase
  def test_new
    db = SQLite3::Database.new( "foo.db", :driver => Driver )
    assert_equal 1, Driver.instance.mock_count(:open)
    assert !db.closed?
    assert_equal [["foo.db",false]], Driver.instance.mock_args[:open]
    assert !db.results_as_hash
    assert !db.type_translation
  end

  def test_open
    db = SQLite3::Database.open( "foo.db", :driver => Driver )
    assert_equal 1, Driver.instance.mock_count(:open)
    assert !db.closed?
    assert_equal [["foo.db",false]], Driver.instance.mock_args[:open]
    assert !db.results_as_hash
    assert !db.type_translation
  end
  
  def test_with_type_translation
    db = SQLite3::Database.open( "foo.db", :driver => Driver,
      :type_translation => true )
    assert db.type_translation
  end
  
  def test_with_results_as_hash
    db = SQLite3::Database.open( "foo.db", :driver => Driver,
      :results_as_hash => true )
    assert db.results_as_hash
  end
  
  def test_with_type_translation_and_results_as_hash
    db = SQLite3::Database.open( "foo.db", :driver => Driver,
      :results_as_hash => true,
      :type_translation => true )
    assert db.results_as_hash
    assert db.type_translation
  end
end

class TC_Database < Test::Unit::TestCase
  def setup
    @db = SQLite3::Database.open( "foo.db",
      :driver => Driver, :statement_factory => Statement )
  end

  def test_quote
    assert_equal "''one''two''three''", SQLite3::Database.quote(
      "'one'two'three'" )
  end

  def test_complete
    @db.complete? "foo"
    assert_equal 1, Driver.instance.mock_count( :complete? )
  end

  def test_errmsg
    @db.errmsg
    assert_equal 1, Driver.instance.mock_count( :errmsg )
  end

  def test_errcode
    @db.errcode
    assert_equal 1, Driver.instance.mock_count( :errcode )
  end

  def test_translator
    translator = @db.translator
    assert_instance_of SQLite3::Translator, translator
  end

  def test_close
    @db.close
    assert_equal 1, Driver.instance.mock_count( :close )
    assert @db.closed?
    @db.close
    assert_equal 1, Driver.instance.mock_count( :close )
  end

  def test_trace
    @db.trace( 15 ) { "foo" }
    driver = Driver.instance
    assert_equal 1, driver.mock_count( :trace )
    assert_equal [[ "cookie", 15 ]], driver.mock_args[:trace]
    assert_equal 1, driver.mock_blocks[:trace].length
  end

  def test_authorizer
    @db.authorizer( 15 ) { "foo" }
    driver = Driver.instance
    assert_equal 1, driver.mock_count( :set_authorizer )
    assert_equal [[ "cookie", 15 ]], driver.mock_args[:set_authorizer]
    assert_equal 1, driver.mock_blocks[:set_authorizer].length
  end

  def test_prepare_no_block
    assert_nothing_raised { @db.prepare( "foo" ) }
    assert_equal 0, Statement.instance.mock_count( :close )
  end

  def test_prepare_with_block
    called = false
    @db.prepare( "foo" ) { |stmt| called = true }
    assert called
    assert_equal 1, Statement.instance.mock_count( :close )
  end

  def test_execute_no_block
    result = @db.execute( "foo", "bar", "baz" )
    stmt = Statement.instance
    assert_equal [["foo"]], result
    assert_equal [["bar", "baz"]], stmt.mock_args[:execute]
  end

  def test_execute_with_block
    called = false
    @db.execute( "foo", "bar", "baz" ) do |row|
      called = true
      assert_equal ["foo"], row
    end

    stmt = Statement.instance
    assert called
    assert_equal [["bar", "baz"]], stmt.mock_args[:execute]
  end

  def test_execute2_no_block
    result = @db.execute2( "foo", "bar", "baz" )
    stmt = Statement.instance
    assert_equal [["name"],["foo"]], result
    assert_equal [["bar", "baz"]], stmt.mock_args[:execute]
  end

  def test_execute2_with_block
    called = false
    parts = [ ["name"],["foo"] ]
    @db.execute2( "foo", "bar", "baz" ) do |row|
      called = true
      assert_equal parts.shift, row
    end

    stmt = Statement.instance
    assert called
    assert_equal [["bar", "baz"]], stmt.mock_args[:execute]
  end

  def test_execute_batch
    @db.execute_batch( "foo", "bar", "baz" )
    stmt = Statement.instance
    assert_equal [["bar", "baz"]], stmt.mock_args[:execute]
  end

  def test_get_first_row
    result = @db.get_first_row( "foo", "bar", "baz" )
    assert_equal ["foo"], result
  end

  def test_get_first_value
    result = @db.get_first_value( "foo", "bar", "baz" )
    assert_equal "foo", result
  end

  def test_changes
    assert_equal 14, @db.changes
    assert_equal 1, Driver.instance.mock_count(:changes)
  end

  def test_total_changes
    assert_equal 28, @db.total_changes
    assert_equal 1, Driver.instance.mock_count(:total_changes)
  end

  def test_interrupt
    @db.interrupt
    assert_equal 1, Driver.instance.mock_count(:interrupt)
  end
end
